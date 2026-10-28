#!/usr/bin/env bash
set -e

## AgentsUniversalHarness.sh -- the universal tool-calling harness: all of the
## logic, none of the provider specifics. Never invoked directly: a provider stub
## sets the HARNESS_* variables and execs this file, so the core becomes that
## process. Endpoint-shaped code lives in the wire adapter named by HARNESS_WIRE.
## AgentsHarnessSelfCheck.test.awk and AgentsHarnessContainmentCheck.test.sh locate code here
## by exact spellings, so renaming anything is a coordinated change to both.
## DESIGN DECISION 1 -- a mid-stream disconnect discards partial state and retries
## the whole round; a partial stream is never spliced. DESIGN DECISION 2 -- such a
## retry never consumes a round against the cap. DESIGN DECISION 3 -- a full context
## is met by summarise-and-restart, never by eviction. DESIGN DECISION 4 -- a spawned
## session keeps the exact message array it sends in its sandbox (context.jsonl,
## AgentsHarnessContext.include), and MDAT_HARNESS_RESUME_CONTEXT resumes a session
## from it: the stored array byte for byte, then the corrections as a new user turn.
## MAGIC.md carries the reasoning.

## Where the PATH holds no `bash`, the directory of the bash this runs in goes at its END, once, so every child
## that names `bash` finds this one; where one is found nothing changes, and nothing on the PATH is ever shadowed.
case "$BASH" in /*/bash) command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; } ;; esac

harnessHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

## THE FULL MANUAL TYPE. This file is also the leg `universal`, and the one way to run it with no
## thin stub in front: every value comes from the environment its preset supplies. A stub still
## wins, because each of these is filled only where it is empty. The endpoint, the wire and the
## host come from HARNESS_ENDPOINT_URL, which the console reads out of PRESET_ENDPOINT_URL: a base
## ending /v1 speaks the OpenAI chat wire, one ending /anthropic the Anthropic Messages wire.
HARNESS_PROVIDER_NAME="${HARNESS_PROVIDER_NAME:-Universal}"
HARNESS_SELF_NAME="${HARNESS_SELF_NAME:-AgentsUniversalHarness.sh}"
HARNESS_CREDENTIAL_NAMES="${HARNESS_CREDENTIAL_NAMES:-ANTHROPIC_API_KEY OPENAI_API_KEY}"
HARNESS_TOKEN_LIGHT="${HARNESS_TOKEN_LIGHT:-${ANTHROPIC_API_KEY:-${OPENAI_API_KEY:-}}}"
HARNESS_TOKEN_MAIN="${HARNESS_TOKEN_MAIN:-${ANTHROPIC_API_KEY:-${OPENAI_API_KEY:-}}}"
export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_CREDENTIAL_NAMES HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN

## Set before the HARNESS_* validation below, whose own messages use these.
harnessDim=""
harnessTool=""
harnessValue=""
harnessWarn=""
harnessBad=""
harnessOff=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ -n "${TERM-}" ] && [ "$TERM" != dumb ] && tput colors >/dev/null 2>&1 && [ "$( tput colors )" -ge 8 ] ; then
	harnessDim=$'\033[2m'
	harnessTool=$'\033[1;36m'
	harnessValue=$'\033[32m'
	harnessWarn=$'\033[1;33m'
	harnessBad=$'\033[1;31m'
	harnessOff=$'\033[0m'
fi

## Width for every wrapped rendering below, resolved once, beside the colour test
## that already asks the same question of the same stream. bash sets COLUMNS only in
## an interactive shell and never exports it, and this core is exec'd from a provider
## stub -- so without this the wraps fall to their own default and a comment claiming
## "wrapped to the terminal" is false on every host. Exported because the awk
## renderers read it from ENVIRON, which a shell variable never reaches.
if [ -z "${COLUMNS:-}" ] && [ -t 2 ] ; then
	COLUMNS="$( tput cols 2>/dev/null )"
fi
case "${COLUMNS:-}" in ''|*[!0-9]*) COLUMNS=100 ;; esac
[ "$COLUMNS" -ge 40 ] || COLUMNS=100
export COLUMNS

## One source for the progress-line shape, so a continuation cannot drift from the
## line it continues. The announce printf is '   %s %s%-Ns%s %s': three leading
## spaces, a two-column emoji, a space, the label, a space. The wire reads the
## gutter from the environment because it is a separate file rendering into the
## same column.
harnessLabelWidth=11
harnessProgressGutter=$(( 3 + 2 + 1 + harnessLabelWidth + 1 ))
export harnessProgressGutter

## The final answer is the model's own prose, written as markdown, so it renders
## through the family's own MD->ANSI filter where a person is reading it. Gated on
## STDOUT being a terminal -- the mirror of the colour gate on stderr above -- because
## that stream carries the machine-readable result: piped into a file or a caller,
## escape codes in it are corruption rather than colour. Resolved once, and absent or
## unusable it stays empty, in which case the answer prints exactly as it always did.
harnessMarkdownFilter=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] ; then
	harnessMarkdownFilter="$( myx.common which lib/catMarkdown 2>/dev/null )" || harnessMarkdownFilter=""
	[ -n "$harnessMarkdownFilter" ] && [ -x "$harnessMarkdownFilter" ] || harnessMarkdownFilter=""
fi

## Window title, and the status line where it is switched on below. Both address the
## terminal from stderr, so both are gated on stderr being a terminal and on nothing
## else: NO_COLOR is a preference about colour, which a title does not carry, and the
## colour variables the status line reuses are already empty wherever it is set.
## The host name is captured for the restore, because there is nothing to restore from:
## measured on Terminal.app here, the title stack (CSI 22;2t / 23;2t) is not implemented
## and CSI 21t returns nothing where CSI 6n returns six bytes through the same reader --
## so a title this run overwrites can be neither pushed nor read back. Blanking it is
## not free either: the window then stays unlabelled for the rest of its life, the
## shell not repainting it at the next prompt, and the host name is what it carried.
harnessTitleActive=""
harnessStatusRows=""
harnessHostName=""
if [ -t 2 ] && [ -n "${TERM-}" ] && [ "$TERM" != dumb ] ; then
	harnessTitleActive=1
	harnessHostName="$( uname -n )"
fi

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessDisplay.include"



## Checked rather than trusted: a missing one otherwise fails silently and far away.
harnessSelfName="${HARNESS_SELF_NAME:-AgentsUniversalHarness.sh}"
harnessProviderName="${HARNESS_PROVIDER_NAME:-}"
harnessEndpoint="${HARNESS_ENDPOINT:-}"
harnessHost="${HARNESS_HOST:-}"
harnessWire="${HARNESS_WIRE:-}"
## THE ENDPOINT A PRESET NAMES, IN THE TWO PATH STYLES OF THE PAIR (F10.1). The console reads PRESET_ENDPOINT_URL as
## HARNESS_ENDPOINT_URL: a base URL, or a whole request URL. A base ending `/anthropic` speaks the Anthropic Messages
## wire and gains `/v1/messages`; one ending `/v1` speaks the OpenAI chat wire and gains `/chat/completions`; any other
## base gains the path its leg's wire asks for. A whole request URL is used as it is, and its wire is the leg's.
if [ -n "${HARNESS_ENDPOINT_URL:-}" ] ; then
	harnessEndpointUrl="${HARNESS_ENDPOINT_URL%/}"
	case "$harnessEndpointUrl" in
		*/v1/chat/completions|*/chat/completions|*/v1/messages|*/messages)
			harnessEndpoint="$harnessEndpointUrl"
		;;
		*/anthropic)
			harnessEndpoint="$harnessEndpointUrl/v1/messages"
			harnessWire="AnthropicMessages"
		;;
		*/v1)
			harnessEndpoint="$harnessEndpointUrl/chat/completions"
			harnessWire="OpenAiChat"
		;;
		*)
			case "${harnessWire:-OpenAiChat}" in
				AnthropicMessages) harnessEndpoint="$harnessEndpointUrl/v1/messages" ;;
				*) harnessEndpoint="$harnessEndpointUrl/v1/chat/completions" ; harnessWire="OpenAiChat" ;;
			esac
		;;
	esac
	harnessHost="${harnessEndpoint#*://}"
	harnessHost="${harnessHost%%/*}"
fi
harnessCredentialNames="${HARNESS_CREDENTIAL_NAMES:-}"

## One tool, no model round: the MCP mirror serves the tool floor this file declares,
## and a served call runs the tool HERE rather than through a second implementation.
## No provider is involved, so the provider contract, the prompt, the credential and
## the model are all skipped. First argument only -- a prompt is trailing argv.
harnessToolOnly=""
harnessToolOnlyName=""
harnessServedWaitBound=""
## --intern-checklist-place: where the checklist of the session this process runs for would be
## kept, or why it has no place -- the served identity, then AgentsHarnessCheckListPlace -- and
## nothing run, logged or written: one line, `CHECKLIST-PLACE: <folder>` or `ERROR: <why>`.
## The native TodoWrite hook asks it before pointing a client at CheckList.
harnessPlaceOnly=""
if [ "${1:-}" = --intern-checklist-place ] ; then
	harnessPlaceOnly=1
	set -- --intern-tool CheckList
fi
## Read and Skill return whole lines up to this many bytes; a served result stays under the MCP client's own limit.
## Both values are stated once, in AgentsHarnessReadCap.include, which also fills them into the descriptions.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReadCap.include"
harnessReadCap="$agentsReadCapWire"
harnessWebAllowDefaults="https://wikipedia.org/ https://freebsd.org/"
if [ "${1:-}" = --intern-tool ] ; then
	if [ -z "${2:-}" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --intern-tool: tool name required" >&2
		exit 1
	fi
	harnessToolOnly=1
	harnessToolOnlyName="$2"
	## Read once and unset, so no child this harness starts can overwrite the caller's head or image file.
	harnessHeadFile="${MDAT_MCP_RESULT_HEAD_FILE:-}" ; unset MDAT_MCP_RESULT_HEAD_FILE
	harnessImageFile="${MDAT_MCP_RESULT_IMAGE_FILE:-}" ; unset MDAT_MCP_RESULT_IMAGE_FILE
	harnessReadCap="$agentsReadCapMcp"
	## The return bound of a Wait with no timeout of its own on this served path: the MCP
	## request handler passes the one it chose (higher while it sends progress), else the
	## safe default under a native client cutoff of about 1800s with no progress. Unset here
	## so no child inherits it.
	harnessServedWaitBound="${MDAT_MCP_WAIT_SERVED_BOUND:-${MDAT_MCP_WAIT_BOUND:-1700}}" ; unset MDAT_MCP_WAIT_SERVED_BOUND
	case "$harnessServedWaitBound" in ''|*[!0123456789]*) harnessServedWaitBound=1700 ;; esac
	shift 2
	## The wire IS needed, and reaching an endpoint is not why: AgentsHarnessMcpClient.sh
	## builds its declarations through the wire's own AgentsWireToolDeclaration, so the
	## three MCP resource tools and ToolSearch fail without an adapter in scope. Sourcing one costs
	## nothing -- the adapter's whole top level is a JSON literal and two variables.
	## A stub that named a wire keeps it; otherwise this is the same default
	## AgentsHarnessMcpMirror.sh renders the floor from.
	harnessWire="${harnessWire:-OpenAiChat}"
fi

harnessMissing=""
[ -n "$harnessProviderName" ]    || harnessMissing="$harnessMissing HARNESS_PROVIDER_NAME"
[ -n "$harnessEndpoint" ]        || harnessMissing="$harnessMissing HARNESS_ENDPOINT"
[ -n "$harnessHost" ]            || harnessMissing="$harnessMissing HARNESS_HOST"
[ -n "$harnessWire" ]            || harnessMissing="$harnessMissing HARNESS_WIRE"
[ -n "$harnessCredentialNames" ] || harnessMissing="$harnessMissing HARNESS_CREDENTIAL_NAMES"
[ -n "${HARNESS_MODEL_LIGHT:-}" ] || harnessMissing="$harnessMissing HARNESS_MODEL_LIGHT"
[ -n "${HARNESS_MODEL_MAIN:-}" ]  || harnessMissing="$harnessMissing HARNESS_MODEL_MAIN"
if [ -n "$harnessMissing" ] && [ -z "$harnessToolOnly" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: a value this run needs is not set. A thin stub sets these and execs the core; run as the universal type, the preset supplies them. Not set:$harnessMissing" >&2
	exit 1
fi

## Becomes a path segment below, so it is gated by explicit character enumeration.
case "$harnessWire" in
	''|.|..)
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE is not a bare wire name: $harnessWire" >&2
		exit 1
	;;
esac
harnessWireRest="$harnessWire"
while [ -n "$harnessWireRest" ] ; do
	harnessWireChar="${harnessWireRest%"${harnessWireRest#?}"}"
	harnessWireRest="${harnessWireRest#?}"
	case "$harnessWireChar" in
		a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
		A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
		0|1|2|3|4|5|6|7|8|9) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE is not a bare wire name: $harnessWire" >&2
			exit 1
		;;
	esac
done

## Names a credential-exchange adapter the way HARNESS_WIRE names a wire; empty or unset
## means the stored credential is itself the bearer. Same bare-name gate, same reason.
harnessTokenExchange="${HARNESS_TOKEN_EXCHANGE:-}"
case "$harnessTokenExchange" in
	.|..)
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_TOKEN_EXCHANGE is not a bare exchange name: $harnessTokenExchange" >&2
		exit 1
	;;
esac
harnessExchangeRest="$harnessTokenExchange"
while [ -n "$harnessExchangeRest" ] ; do
	harnessExchangeChar="${harnessExchangeRest%"${harnessExchangeRest#?}"}"
	harnessExchangeRest="${harnessExchangeRest#?}"
	case "$harnessExchangeChar" in
		a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
		A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
		0|1|2|3|4|5|6|7|8|9) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_TOKEN_EXCHANGE is not a bare exchange name: $harnessTokenExchange" >&2
			exit 1
		;;
	esac
done

## Complete header lines, one per line, empty meaning no change. Checked here rather than
## at the first request: curl sends a header line verbatim, so a malformed one becomes an
## endpoint refusal that reads exactly like an auth failure.
harnessExtraHeaders="${HARNESS_EXTRA_HEADERS:-}"
if [ -n "$harnessExtraHeaders" ] ; then
	while IFS= read -r harnessHeaderLine ; do
		case "$harnessHeaderLine" in
			''|*$'\r'*)
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_EXTRA_HEADERS holds an empty line, or one carrying a carriage return -- a trailing newline on the declared value leaves an empty last line, and is the usual cause" >&2
				exit 1
			;;
			:*)
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_EXTRA_HEADERS holds a line whose field name is empty: $harnessHeaderLine" >&2
				exit 1
			;;
			*:*) ;;
			*)
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_EXTRA_HEADERS holds a line with no colon: $harnessHeaderLine" >&2
				exit 1
			;;
		esac
	done <<< "$harnessExtraHeaders"
fi

harnessTier="normal"
harnessAccessRoots=()
harnessWriteAccessRoots=()
harnessSessionId=""
harnessAgent=""
harnessAgentMissing=""
harnessMcpServers=()
## The root flags as given, in their order: each call of a batch is made with them (AgentsHarnessBatchCall).
harnessRootFlags=()
while [ $# -gt 0 ] ; do
	case "$1" in
		--tier)
			case "${2:-}" in
				light|normal|heavy) harnessTier="$2" ;;
				*)
					echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --tier must be light, normal or heavy, got: ${2:-<none>}" >&2
					exit 1
				;;
			esac
			shift 2
		;;
		--access-read-root)
			if [ -z "${2:-}" ] ; then
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: $1: value required" >&2
				exit 1
			fi
			harnessAccessRoots+=( "$2" )
			harnessRootFlags+=( "$1" "$2" )
			shift 2
		;;
		--access-write-root|--access-root)
			## A write root is readable by definition, so it joins both sets; --access-root is its alias, which is that flag's original read+write meaning.
			if [ -z "${2:-}" ] ; then
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: $1: value required" >&2
				exit 1
			fi
			harnessWriteAccessRoots+=( "$2" )
			harnessAccessRoots+=( "$2" )
			harnessRootFlags+=( "$1" "$2" )
			shift 2
		;;
		--mcp-server)
			## Naming any replaces the workspace default set below with exactly these;
			## AgentsHarnessMcpClient.sh resolves the name among the servers the installer registers.
			if [ -z "${2:-}" ] ; then
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --mcp-server: value required" >&2
				exit 1
			fi
			harnessMcpServers+=( "$2" )
			shift 2
		;;
		--session-id)
			## A value is required and nothing more: the uuid contract is the minter's.
			if [ -z "${2:-}" ] ; then
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --session-id: value required" >&2
				exit 1
			fi
			harnessSessionId="$2"
			shift 2
		;;
		--agent)
			## Becomes a path segment fed to cd, so '.' and '..' are rejected outright.
			case "${2:-}" in
				''|.|..)
					echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --agent is not a bare member name: ${2:-<none>}" >&2
					exit 1
				;;
			esac
			harnessAgentCheckRest="${2:-}"
			while [ -n "$harnessAgentCheckRest" ] ; do
				harnessAgentCheckChar="${harnessAgentCheckRest%"${harnessAgentCheckRest#?}"}"
				harnessAgentCheckRest="${harnessAgentCheckRest#?}"
				case "$harnessAgentCheckChar" in
					a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
					A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
					0|1|2|3|4|5|6|7|8|9) ;;
					-|_|.) ;;
					*)
						echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --agent is not a bare member name: ${2:-<none>}" >&2
						exit 1
					;;
				esac
			done
			harnessAgent="$2"
			shift 2
		;;
		--)
			shift
			break
		;;
		*)
			break
		;;
	esac
done

## A served call names no --agent: its identity is resolved HERE, on every call, so the
## MCP server that launched it carries none and nothing depends on when it started.
## A spawned session's MDAT_SPAWN_AGENT, else the root session's magic-coordinator,
## and only when that member is in the skillset -- otherwise it stays empty, the four
## tools that send refuse, and every other tool is still served.
if [ -n "$harnessToolOnly" ] && [ -z "$harnessAgent" ] ; then
	harnessAgent="${MDAT_SPAWN_AGENT:-magic-coordinator}"
	## The same bare-name gate --agent applies, by explicit enumeration: a bracket range
	## is collation-dependent.
	case "$harnessAgent" in
		.|..) harnessAgent="" ;;
	esac
	harnessAgentCheckRest="$harnessAgent"
	while [ -n "$harnessAgentCheckRest" ] ; do
		harnessAgentCheckChar="${harnessAgentCheckRest%"${harnessAgentCheckRest#?}"}"
		harnessAgentCheckRest="${harnessAgentCheckRest#?}"
		case "$harnessAgentCheckChar" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
			0|1|2|3|4|5|6|7|8|9) ;;
			-|_|.) ;;
			*) harnessAgent="" ; harnessAgentCheckRest="" ;;
		esac
	done
	## The skillset root the Skill tool also falls back to, so a served call resolves its
	## member where MDAT_SKILLSET_ROOT is unset: this workspace's member index view
	## (AgentsTools.TeamRegistry.include), never a vendor link folder. One it still cannot
	## find is said, not dropped.
	harnessServedSkillset="${MDAT_SKILLSET_ROOT:-${MMDAPP:+$MMDAPP/.local/agents/members}}"
	## Announced, then exported, so every later check and every child the call runs reads the same root.
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] ; then
		printf 'WARNING: MDAT_SKILLSET_ROOT is not set in this process, so the served identity is read from the fallback %s\n' "${harnessServedSkillset:-<MMDAPP unset too>}" >&2
		[ -z "$harnessServedSkillset" ] || export MDAT_SKILLSET_ROOT="$harnessServedSkillset"
	fi
	if [ -n "$harnessAgent" ] && [ ! -r "$harnessServedSkillset/$harnessAgent/$harnessAgent.basic.md" ] ; then
		harnessAgentMissing="no team identity resolved: ${harnessServedSkillset:-<MDAT_SKILLSET_ROOT and MMDAPP unset>}/$harnessAgent/$harnessAgent.basic.md is not readable -- set MDAT_SKILLSET_ROOT in the MCP server environment"
		harnessAgent=""
	fi
fi

## This leg has no external hook observer, so this line is the only session join.
if [ -n "$harnessSessionId" ] ; then
	printf '%s\n' "🔗 ${harnessDim}session${harnessOff} ${harnessValue}$harnessSessionId${harnessOff}" >&2
fi

## Missing or unreadable is loud: a silent fall back to the generic prompt would
## look like a successful --agent spawn while running as nobody in particular.
harnessAgentBasicText=""
harnessAgentRealDir=""
if [ -n "$harnessAgent" ] ; then
	harnessAgentDir="${MDAT_SKILLSET_ROOT:-}/$harnessAgent"
	harnessAgentBasicFile="$harnessAgentDir/$harnessAgent.basic.md"
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] || [ ! -f "$harnessAgentBasicFile" ] || [ ! -r "$harnessAgentBasicFile" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --agent $harnessAgent: no such file, or unreadable: ${MDAT_SKILLSET_ROOT:-<MDAT_SKILLSET_ROOT unset>}/$harnessAgent/$harnessAgent.basic.md" >&2
		exit 1
	fi
	harnessAgentBasicText="$( cat "$harnessAgentBasicFile" )"
	## Resolved so the sentence handed to the model names the real file.
	harnessAgentRealDir="$( cd "$harnessAgentDir" 2>/dev/null && pwd -P )" || harnessAgentRealDir="$harnessAgentDir"
fi

## THE TEAM'S COMMON INSTRUCTION (F10.7): magic-team/magic-team.basic.md, read as the member's own basic is, and carried FIRST in the
## system text of every team-member run of the model path, so the system text of all of them opens with the same bytes: the prefix
## the input token cache shares among them. It is MOVED there, not added beside itself: a run that carries it does not read it
## again in the default skill bundle (the Skill tool below), while a served call, which is a native client's, keeps it in its bundle.
## Not read for magic-team itself, nor for a run that names no agent.
harnessSystemShared=""
if [ -z "$harnessToolOnly" ] && [ -n "$harnessAgent" ] && [ "$harnessAgent" != "magic-team" ] && [ -r "${MDAT_SKILLSET_ROOT:-}/magic-team/magic-team.basic.md" ] ; then
	harnessSystemShared="$( cat "$MDAT_SKILLSET_ROOT/magic-team/magic-team.basic.md" )"
fi

## Remaining argv joined into one prompt; stdin when no argv prompt was given.
## --intern-tool takes neither: its argument object is on stdin and is read where the
## call is made, so reading a prompt here would swallow it.
harnessPrompt=""
if [ -z "$harnessToolOnly" ] ; then
	harnessPrompt="$*"
	if [ -z "$harnessPrompt" ] ; then
		harnessPrompt="$( cat )"
	fi
	if [ -z "$harnessPrompt" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no prompt given -- pass it as trailing argv, or on stdin" >&2
		exit 1
	fi
fi

## The stub decides which model and which key; the core owns only the mapping's shape.
## A model's own limits travel with it: output tokens empty leaves the wire to send none
## where it may, and a context window empty leaves the core's own floor below in place.
## The threshold is the window less the output maximum, so a round leaves room for the reply.
## THE RESTART THRESHOLD, in the order it is taken: MDAT_HARNESS_CONTEXT_TOKENS, an
## operator's own override; then PRESET_CONTEXT_MAX_SIZE, the context size the preset of
## this spawn names (F10.2, exported by the console); then this tier's own window less its
## output maximum. The preset's key used to be STORED ONLY -- a person set a context size
## and the restart ignored it, so a run kept paying for a prefix past the size asked for.
## It is the override the restart below reads now. 0 turns the threshold off entirely.
## The limits and the effort are judged for the model chosen, in AgentsHarnessLimits.include: a wrapper's
## family table (HARNESS_MODEL_TABLE), else, for a leg with no table, the pair it declares for the tier.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessLimits.include"
harnessReasoningEffort=""
harnessWindowTokens=""
## The effort the preset asks (HARNESS_EFFORT, exported by the console): unset none low normal high. The heavy tier is
## the main model at effort high, unless the preset asked an effort of its own.
harnessEffort="${HARNESS_EFFORT:-unset}"
case "$harnessTier" in
	light)
		harnessModel="$HARNESS_MODEL_LIGHT"
		harnessToken="${HARNESS_TOKEN_LIGHT:-}"
		harnessFallbackOutput="${HARNESS_OUTPUT_TOKENS_LIGHT:-}"
		harnessFallbackWindow="${HARNESS_CONTEXT_TOKENS_LIGHT:-}"
		harnessModelHow="macro low, resolved by this leg" ; [ "${HARNESS_MODEL_FROM_LIGHT:-}" != name ] || harnessModelHow="the model the preset names"
	;;
	normal)
		harnessModel="$HARNESS_MODEL_MAIN"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
		harnessFallbackOutput="${HARNESS_OUTPUT_TOKENS_MAIN:-}"
		harnessFallbackWindow="${HARNESS_CONTEXT_TOKENS_MAIN:-}"
		harnessModelHow="macro normal, resolved by this leg" ; [ "${HARNESS_MODEL_FROM_MAIN:-}" != name ] || harnessModelHow="the model the preset names"
	;;
	heavy)
		harnessModel="$HARNESS_MODEL_MAIN"
		[ "$harnessEffort" != unset ] || harnessEffort="high"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
		harnessFallbackOutput="${HARNESS_OUTPUT_TOKENS_MAIN:-}"
		harnessFallbackWindow="${HARNESS_CONTEXT_TOKENS_MAIN:-}"
		harnessModelHow="macro high, resolved by this leg" ; [ "${HARNESS_MODEL_FROM_MAIN:-}" != name ] || harnessModelHow="the model the preset names"
	;;
esac
## A tool call serves no model, so --intern-tool judges nothing and refuses nothing here.
harnessContextTokens="" harnessNoneForm="" harnessLimitsSource="" harnessThresholdSource="" harnessEffortNote="" harnessThinkingOff=""
if [ -z "$harnessToolOnly" ] ; then
	AgentsHarnessLimitsResolve "$harnessModel" "$harnessFallbackWindow" "$harnessFallbackOutput" || exit 1
else
	harnessWindowTokens="$harnessFallbackWindow" harnessOutputTokens="$harnessFallbackOutput"
	harnessContextTokens="${MDAT_HARNESS_CONTEXT_TOKENS:-${PRESET_CONTEXT_MAX_SIZE:-$(( ${harnessWindowTokens:-400000} - ${harnessOutputTokens:-0} ))}}"
fi
AgentsHarnessEffortApply || exit 1

## A tool call reaches no endpoint and is not metered, so --intern-tool needs neither.
if [ -z "$harnessToolOnly" ] ; then
	if [ -z "$harnessToken" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no credential -- $harnessCredentialNames must be set in this process's own environment. This leg reads those names itself, exactly as claude reads ANTHROPIC_API_KEY" >&2
		exit 1
	fi
	## What this run costs, said once: the tier picked the model, and the model is metered.
	printf '%s\n' "🤖 ${harnessDim}$harnessProviderName${harnessOff} ${harnessTool}$harnessModel${harnessOff} ${harnessDim}· $harnessTier tier, $harnessModelHow · context window ${harnessWindowTokens:-unknown}, output ${harnessOutputTokens:-unset}, restart at $harnessContextTokens tokens from $harnessThresholdSource; limits from $harnessLimitsSource · $harnessEffortNote${harnessOff}" >&2
fi

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessAccess.include"


## No root flags, whoever asked: the set comes from THIS package's own access-root
## mechanism. AgentsTools.ClientAccessRoots.include is the one place it is defined, so a
## caller takes what that yields and never a rendered copy downstream of it.
## .claude/copilot-add-dir.fragment is exactly such a copy -- one of that include's own
## consumers. It stays generated and stays copilot's own integration, and nothing here
## reads it: it is output we publish, not a source anything of ours consults, which is
## the rule mcp.servers.json already follows beside it. Sourced rather than re-entered
## through a command script, because an internal caller already holds the context.
## One block and no branch on which caller this is: yielding the set is one job.
## The name the access-root include and every Bash command reach the tooling through,
## as in the console. Exported so a `bash -c` child (a timed Bash call) has it too.
if ! type DistroAgentsTools >/dev/null 2>&1 ; then
	DistroAgentsTools(){ "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
fi
export -f DistroAgentsTools
## The grants index and the session permission index (AgentsTools.Grants.include): functions only.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.Grants.include"
harnessGateIndexed=""
## What a named member's file gate admits beside its permission index: what is known only
## at run time -- its children's input and output -- and its own member directory.
harnessRuntimeRoots=""
harnessRuntimeWriteRoots=""
harnessSandboxInReal=""
harnessSandboxOutReal=""
if [ "${#harnessAccessRoots[@]}" -eq 0 ] ; then
	harnessRootsInclude="$harnessHere/client/AgentsTools.ClientAccessRoots.include"
	if [ ! -f "$harnessRootsInclude" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the access-root mechanism is missing from this package: $harnessRootsInclude" >&2
		exit 1
	fi
	. "$harnessRootsInclude"
	## The installer's own index of this same set, already resolved, when it vouches for
	## this run (AgentsHarnessRootsIndex.include says when); the producer below otherwise.
	harnessRootsFromIndex=""
	harnessWriteFromIndex=""
	harnessWriteGiven="${#harnessWriteAccessRoots[@]}"
	## The index holds every member's declared grants as one union, so a named member's
	## read and write sets are never taken from it: they are that member's own, computed below.
	harnessWriteIndexable="$harnessWriteGiven"
	## A served call with no MDAT_SPAWN_AGENT is the human-owner's own session under the
	## default identity: it keeps every member's declared grants, as before.
	harnessGrantMember="$harnessAgent"
	[ -z "$harnessToolOnly" ] || [ -n "${MDAT_SPAWN_AGENT:-}" ] || harnessGrantMember=""
	[ -z "$harnessGrantMember" ] || harnessWriteIndexable=1
	## A named member with no root flags given: its file tools are decided by its session
	## permission index (AgentsHarnessFileGate), never by the roots computed below.
	[ -z "$harnessGrantMember" ] || harnessGateIndexed=1
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessRootsIndex.include"
	if [ -z "$harnessGrantMember" ] && AgentsHarnessRootsIndexUse "${MMDAPP:-}" "$harnessAgent" "$harnessWriteIndexable" ; then
		harnessRootsFromIndex=1
		[ "$harnessWriteIndexable" != 0 ] || harnessWriteFromIndex=1
	fi
	## Captured on its own line so a failed producer refuses the run: read through the
	## herestring directly, its status is lost and a short set passes as the whole one.
	## stderr is captured with it, so the reason travels with the refusal; the loop
	## below keeps absolute paths only. Under --intern-tool stdout is all a caller sees.
	## A named member reads its floor and its own Edit and Read rows only; a read outside
	## them is asked of the grants and, refused, recorded (AgentsHarnessReadGate).
	if [ -n "$harnessRootsFromIndex" ] ; then
		:
	elif ! harnessOwnRoots="$( AgentsToolsClientAccessRoots "${MMDAPP:-}" "$harnessAgent" "$harnessGrantMember" 2>&1 )" ; then
		[ -z "$harnessToolOnly" ] || printf 'ERROR: the access-root set could not be computed, so nothing was done: %s\n' "$harnessOwnRoots"
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the access-root set could not be computed, refusing rather than running on a partial set: $harnessOwnRoots" >&2
		exit 1
	else
		while IFS= read -r harnessOwnRoot ; do
			case "$harnessOwnRoot" in
				/*) harnessAccessRoots+=( "$harnessOwnRoot" ) ;;
			esac
		done <<< "$harnessOwnRoots"
	fi
	## Writes narrow the way the console narrows them: the write reference roots plus the
	## declared Edit grants, never the whole read set, so the skills root stays read-only.
	## A named member's declared grants are its own rows only, never every member's.
	if [ "${#harnessWriteAccessRoots[@]}" -eq 0 ] || [ -n "$harnessWriteFromIndex" ] ; then
		if [ -n "$harnessWriteFromIndex" ] ; then
			:
		elif ! harnessOwnRoots="$( { AgentsToolsClientAccessReferenceRoots write "${MMDAPP:-}" "$harnessAgent" && AgentsToolsClientAccessGrantRoots "$harnessGrantMember" ; } 2>&1 )" ; then
			[ -z "$harnessToolOnly" ] || printf 'ERROR: the write-root set could not be computed, so nothing was done: %s\n' "$harnessOwnRoots"
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the write-root set could not be computed, refusing rather than writing wherever reads reach: $harnessOwnRoots" >&2
			exit 1
		else
			while IFS= read -r harnessOwnRoot ; do
				case "$harnessOwnRoot" in
					/*) harnessWriteAccessRoots+=( "$harnessOwnRoot" ) ;;
				esac
			done <<< "$harnessOwnRoots"
		fi
		if [ "${#harnessWriteAccessRoots[@]}" -eq 0 ] ; then
			[ -z "$harnessToolOnly" ] || printf 'ERROR: no write roots resolved, so nothing was done -- check MMDAPP in the MCP server environment\n'
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no write roots resolved, refusing rather than writing wherever reads reach -- check MMDAPP" >&2
			exit 1
		fi
	fi
	## Said because a partial set is otherwise silent: the member roots drop out when the
	## skillset root is unresolved, and a narrower grant then looks exactly like a full one.
	printf '%s\n' "🔐 ${harnessDim}access roots${harnessOff} ${harnessValue}${#harnessAccessRoots[@]}${harnessOff} ${harnessDim}from this package's own access-root mechanism${harnessOff}" >&2
fi

## A root the index resolved at install, and still a directory, keeps that resolution;
## every other one is resolved here, one subshell each, as always.
harnessRoots=""
harnessRootIdx=0
for harnessRoot in "${harnessAccessRoots[@]}" ; do
	if [ -n "${harnessRootsFromIndex:-}" ] && [ -n "${harnessAccessRootsReal[$harnessRootIdx]-}" ] ; then
		harnessRoots="${harnessRoots}${harnessAccessRootsReal[$harnessRootIdx]}"$'\n'
	else
		harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessRoot" )"$'\n'
	fi
	harnessRootIdx=$(( harnessRootIdx + 1 ))
done
if [ -z "$harnessRoots" ] ; then
	[ -z "$harnessToolOnly" ] || printf 'ERROR: no access roots resolved, so nothing was done -- sh-lib/client/AgentsTools.ClientAccessRoots.include yielded an empty set; check MDAT_SKILLSET_ROOT, HOME and MMDAPP in the MCP server environment\n'
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-write-root for a root it may both read and write, or --access-read-root for one it may only read. With no flag at all the set comes from sh-lib/client/AgentsTools.ClientAccessRoots.include, so an empty set means that mechanism yielded nothing -- check MDAT_SKILLSET_ROOT and MMDAPP." >&2
	exit 1
fi

## Reads keep the generous set above. Writes narrow to their own where one is given, or
## where no root flag was given at all; with read flags only, they stay exactly as wide as reads, which is what every console
## generated before this flag passes, so no existing spawn loses a write.
harnessWriteRoots=""
if [ "${#harnessWriteAccessRoots[@]}" -gt 0 ] ; then
	harnessRootIdx=0
	for harnessWriteRoot in "${harnessWriteAccessRoots[@]}" ; do
		if [ -n "${harnessWriteFromIndex:-}" ] && [ -n "${harnessWriteAccessRootsReal[$harnessRootIdx]-}" ] ; then
			harnessWriteRoots="${harnessWriteRoots}${harnessWriteAccessRootsReal[$harnessRootIdx]}"$'\n'
		else
			harnessWriteRoots="${harnessWriteRoots}$( AgentsHarnessResolveDir "$harnessWriteRoot" )"$'\n'
		fi
		harnessRootIdx=$(( harnessRootIdx + 1 ))
	done
	## A named member writes its own directory by definition, without being granted it.
	[ -z "$harnessAgentRealDir" ] || harnessWriteRoots="${harnessWriteRoots}$harnessAgentRealDir"$'\n'
fi
[ -n "$harnessWriteRoots" ] || harnessWriteRoots="$harnessRoots"
[ -z "$harnessAgentRealDir" ] || harnessRuntimeWriteRoots="${harnessRuntimeWriteRoots}$harnessAgentRealDir"$'\n'

## What the member layer names (F10.7): the roots of the workspace and of the member, the same for every run of a member. What is added below is of
## this run alone -- its sandbox, its results folder, the sandboxes of its children -- and goes to the task block of the first message
## (harnessRunNotes), so the member layer and the prefetch block are the same bytes for every spawn of a member. The two sets the gate reads,
## harnessRoots and harnessWriteRoots, are the whole of them, as they were.
##
## The spawn's own sandbox is resolved FIRST and taken out of the two sets: the console hands it in on the access-root flags as well, and a
## path of this run alone in the system text ends the cached prefix at it. Measured from two identical spawns of one member, the two requests
## first differed inside the system message, at the sandbox path -- with the tools and the whole prefetched skill behind that point, so they
## were never read from the cache. It is added back just below, after the system text has taken its own, so the gate reads the same set it did
## and the task block names the roots (harnessRunNotes).
harnessSandboxInReal="" harnessSandboxOutReal=""
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
	if [ -n "${MDAT_SPAWN_SANDBOX_ROOT_REAL:-}" ] && [ "${MDAT_SPAWN_SANDBOX_ROOT_REAL#/}" != "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ "$MDAT_SPAWN_SANDBOX_ROOT" -ef "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] ; then
		harnessSandboxInReal="$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" harnessSandboxOutReal="$MDAT_SPAWN_SANDBOX_ROOT_REAL/output"
	else
		harnessSandboxInReal="$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/input" )" harnessSandboxOutReal="$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/output" )"
	fi
	harnessRootsStable="$( AgentsHarnessRootsWithout "$harnessRoots" "$harnessSandboxInReal" "$harnessSandboxOutReal" )"
	harnessWriteRootsStable="$( AgentsHarnessRootsWithout "$harnessWriteRoots" "$harnessSandboxInReal" "$harnessSandboxOutReal" )"
	harnessRoots="" ; [ -z "$harnessRootsStable" ] || harnessRoots="$harnessRootsStable"$'\n'
	harnessWriteRoots="" ; [ -z "$harnessWriteRootsStable" ] || harnessWriteRoots="$harnessWriteRootsStable"$'\n'
fi
harnessSystemRoots="$harnessRoots" harnessSystemWriteRoots="$harnessWriteRoots"

## The spawn's own sandbox is added here, after the write set is final: resolved above, and taken out of the two sets there, so the system
## text names no path of this run alone. The spawn op hands over the sandbox already resolved, as MDAT_SPAWN_SANDBOX_ROOT_REAL.
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
	harnessRoots="${harnessRoots}$harnessSandboxInReal"$'\n'"$harnessSandboxOutReal"$'\n'
	harnessWriteRoots="${harnessWriteRoots}$harnessSandboxOutReal"$'\n'
	harnessRuntimeRoots="${harnessRuntimeRoots}$harnessSandboxInReal"$'\n'"$harnessSandboxOutReal"$'\n'
	harnessRuntimeWriteRoots="${harnessRuntimeWriteRoots}$harnessSandboxOutReal"$'\n'
fi

## A result too long for its reply is kept in the session's own results/ folder (AgentsTranscriptReplyLong,
## AgentsTools.SessionTranscript.include), and the reply says to read the rest there: the session reads
## that one folder and writes nothing in it. Named, never made here: the first result kept makes it.
harnessResultsKey="${harnessSessionId:-${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}}"
case "$harnessResultsKey" in
	''|*/*|.|..|*' '*) ;;
	*)
		if [ -n "${MMDAPP:-}" ] ; then
			harnessResultsReal="$( AgentsHarnessResolveDir "$MMDAPP/.local/agents/sessions" )/$harnessResultsKey/results"
			harnessRoots="${harnessRoots}$harnessResultsReal"$'\n'
			harnessRuntimeRoots="${harnessRuntimeRoots}$harnessResultsReal"$'\n'
		fi
	;;
esac

## A parent session reads its children's output and writes their input, by parent-spawn-id.
harnessParentKey="${harnessSessionId:-${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}}"
## Where every spawn since the install has listed itself in its parent's own
## .local/agents/children/<id> -- the main loop re-lists them all from the records and
## then marks the store with children/.indexed -- only the records that file names are read,
## taken in the order the full scan meets them and still checked line for line; a
## parent with no such file has no children. Anywhere else, every record is scanned.
if [ -n "$harnessParentKey" ] && [ -n "${MMDAPP:-}" ] ; then
	harnessChildRecords=""
	case "$harnessParentKey" in
		*/*|.|..) harnessChildIndexed="" ;;
		*) harnessChildIndexed="$MMDAPP/.local/agents/children/.indexed" ; [ -f "$harnessChildIndexed" ] || harnessChildIndexed="" ;;
	esac
	if [ -n "$harnessChildIndexed" ] ; then
		harnessChildNames=""
		[ ! -f "$MMDAPP/.local/agents/children/$harnessParentKey" ] || IFS= read -r -d '' harnessChildNames < "$MMDAPP/.local/agents/children/$harnessParentKey" || :
		if [ -n "$harnessChildNames" ] ; then
			harnessChildFiles=()
			for harnessChildRecord in "$MMDAPP"/.local/agents/spawned/*/*.spawn.md ; do
				case $'\n'"$harnessChildNames" in
					*$'\n'"${harnessChildRecord#"$MMDAPP/.local/agents/spawned/"}"$'\n'*) harnessChildFiles+=( "$harnessChildRecord" ) ;;
				esac
			done
			[ "${#harnessChildFiles[@]}" -eq 0 ] || harnessChildRecords="$( LC_ALL=C grep -l -x -F "parent-spawn-id: $harnessParentKey" "${harnessChildFiles[@]}" 2>/dev/null )" || harnessChildRecords=""
		fi
	else
		harnessChildRecords="$( LC_ALL=C grep -l -x -F "parent-spawn-id: $harnessParentKey" "$MMDAPP"/.local/agents/spawned/*/*.spawn.md 2>/dev/null )" || harnessChildRecords=""
	fi
	## The spawned/ directory is resolved once; a child's own folder and its input/ and
	## output/ that are real directories, not links, resolve under it to exactly what
	## `cd && pwd -P` gives, so only a child with a link or a missing folder is resolved
	## on its own.
	harnessSpawnedDir="$MMDAPP/.local/agents/spawned"
	harnessSpawnedReal=""
	harnessRootsBeforeChildren="$harnessRoots" harnessWriteRootsBeforeChildren="$harnessWriteRoots"
	while IFS= read -r harnessChildRecord ; do
		[ -n "$harnessChildRecord" ] || continue
		harnessChildRoot="${harnessChildRecord%/*}"
		harnessChildName="${harnessChildRoot#"$harnessSpawnedDir/"}"
		if [ "$harnessChildName" != "$harnessChildRoot" ] && [ -n "$harnessChildName" ] && [ "${harnessChildName%/*}" = "$harnessChildName" ] \
			&& [ ! -L "$harnessChildRoot" ] && [ -d "$harnessChildRoot/output" ] && [ ! -L "$harnessChildRoot/output" ] && [ -d "$harnessChildRoot/input" ] && [ ! -L "$harnessChildRoot/input" ] ; then
			[ -n "$harnessSpawnedReal" ] || harnessSpawnedReal="$( AgentsHarnessResolveDir "$harnessSpawnedDir" )"
			harnessRoots="${harnessRoots}$harnessSpawnedReal/$harnessChildName/output"$'\n'
			harnessWriteRoots="${harnessWriteRoots}$harnessSpawnedReal/$harnessChildName/input"$'\n'
		else
			harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessChildRoot/output" )"$'\n'
			harnessWriteRoots="${harnessWriteRoots}$( AgentsHarnessResolveDir "$harnessChildRoot/input" )"$'\n'
		fi
	done <<< "$harnessChildRecords"
	## The same roots, for a named member's file gate: the two sets grew by exactly these.
	harnessRuntimeRoots="${harnessRuntimeRoots}${harnessRoots#"$harnessRootsBeforeChildren"}"
	harnessRuntimeWriteRoots="${harnessRuntimeWriteRoots}${harnessWriteRoots#"$harnessWriteRootsBeforeChildren"}"
fi
## The roots of this run alone: all that was appended to the two sets after the system's own were taken.
harnessRunRoots="${harnessRoots#"$harnessSystemRoots"}" harnessRunWriteRoots="${harnessWriteRoots#"$harnessSystemWriteRoots"}"

## Claude Code saves a tool result too large to return under its own session folder, outside
## every workspace root -- member folders live inside the workspace only, so no grant reaches
## there. AgentsHarnessDeniedHint below names the real fix on that one refusal: reread the
## original tool with a narrower offset/limit.

## The run's scratch is the workspace's own, never the system's temp folder, by the owner's rule:
## the spawn's sandbox tmp/ where it has one, else $MMDAPP/.local/agents/scratch, which
## no member's floor grants (AgentsTools.Grants.include). With no workspace there is no scratch,
## and no run: a served call says so on stdout, where its caller reads every refusal.
harnessScratchBase=""
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] && mkdir -p "$MDAT_SPAWN_SANDBOX_ROOT/tmp" 2>/dev/null ; then
	harnessScratchBase="$MDAT_SPAWN_SANDBOX_ROOT/tmp"
elif [ -n "${MMDAPP:-}" ] && [ -d "$MMDAPP" ] && mkdir -p "$MMDAPP/.local/agents/scratch" 2>/dev/null ; then
	harnessScratchBase="$MMDAPP/.local/agents/scratch"
else
	[ -z "$harnessToolOnly" ] || printf 'ERROR: no workspace to keep the scratch of this call in -- MMDAPP names none, so nothing was done\n'
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no workspace to keep the scratch of this run in -- MMDAPP names none, and the system temp folder is never used" >&2
	exit 1
fi
harnessScratch="$( mktemp -d "$harnessScratchBase/AgentsUniversalHarness.XXXXXX" )" || {
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: could not create a scratch directory" >&2
	exit 1
}

## The status the run exits with is kept through the cleanup, so a failure never leaves as
## 0. Under set -e, bash 3.2 hands this trap $?=0 on a syntax error, so a 0 counts only
## when the run reached one of its own two successful exits, which set harnessExitClean.
harnessExitClean=""
trap 'harnessExitStatus=$? ; [ "$harnessExitStatus" != 0 ] || [ -n "$harnessExitClean" ] || harnessExitStatus=2 ; trap "" INT TERM ; AgentsHarnessRestoreTerminal ; AgentsHarnessReapChildren ; rm -rf -- "$harnessScratch" ; exit "$harnessExitStatus"' EXIT

## Reserved only once the cleanup above is armed, never before it: a scroll region set
## with nothing to undo it outlives this process and confines the next shell to the top
## of its own window. The LAST row is the only row reservable at no cost -- measured on
## Terminal.app here, a 1;rows-1 region leaves all 120 of 120 scrolled-out lines in the
## tab's own scrollback, where a 2;rows region, which is what a line pinned to the TOP
## needs, leaves 21 of them. Two blank lines first so the reservation covers nothing
## already on screen, then the cursor onto the region's own last row, because DECSTBM
## homes it and output from the top would overwrite history that has not scrolled yet.
## Off unless asked for: the human-owner judges this by eye before it is anyone's default.
if [ -n "${MDAT_HARNESS_STATUS_LINE:-}" ] && [ -n "$harnessTitleActive" ] ; then
	harnessStatusRows="$( tput lines 2>/dev/null )"
	case "$harnessStatusRows" in ''|*[!0-9]*) harnessStatusRows="" ;; esac
	[ -z "$harnessStatusRows" ] || [ "$harnessStatusRows" -ge 10 ] || harnessStatusRows=""
	[ -z "$harnessStatusRows" ] || printf '\n\n\033[1;%dr\033[%d;1H' "$(( harnessStatusRows - 1 ))" "$(( harnessStatusRows - 1 ))" >&2
fi

## Wall-clock bound on Bash and on an MCP call. 0, the default, is no bound: a hung
## command stays visible in its own announce line and Ctrl-C still reaches it.
harnessRunTimeout="${MDAT_HARNESS_RUN_TIMEOUT:-0}"
## Whole seconds, by explicit enumeration rather than a collation-dependent range.
harnessRunTimeoutRest="$harnessRunTimeout"
while [ -n "$harnessRunTimeoutRest" ] ; do
	harnessRunTimeoutChar="${harnessRunTimeoutRest%"${harnessRunTimeoutRest#?}"}"
	harnessRunTimeoutRest="${harnessRunTimeoutRest#?}"
	case "$harnessRunTimeoutChar" in
		0|1|2|3|4|5|6|7|8|9) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_RUN_TIMEOUT must be whole seconds, got: $harnessRunTimeout" >&2
			exit 1
		;;
	esac
done
## Optional ceiling on one Wait call, its own knob beside Bash's. Unset is no ceiling:
## a Wait with no timeout of its own waits until something arrives, because every quiet
## return costs a whole model round that re-reads the context only to call Wait again.
## A served call (--intern-tool, the MCP path) is bounded by harnessServedWaitBound instead.
harnessWaitTimeout="${MDAT_HARNESS_WAIT_TIMEOUT:-}"
harnessWaitTimeoutRest="$harnessWaitTimeout"
while [ -n "$harnessWaitTimeoutRest" ] ; do
	harnessWaitTimeoutChar="${harnessWaitTimeoutRest%"${harnessWaitTimeoutRest#?}"}"
	harnessWaitTimeoutRest="${harnessWaitTimeoutRest#?}"
	case "$harnessWaitTimeoutChar" in
		0|1|2|3|4|5|6|7|8|9) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_WAIT_TIMEOUT must be whole seconds, got: $harnessWaitTimeout" >&2
			exit 1
		;;
	esac
done
## macOS ships no `timeout` in base; coreutils installs it as `gtimeout` there.
harnessTimeoutCmd=""
if command -v timeout >/dev/null 2>&1 ; then
	harnessTimeoutCmd="timeout"
elif command -v gtimeout >/dev/null 2>&1 ; then
	harnessTimeoutCmd="gtimeout"
fi
## No startup refusal where neither exists: Bash enforces the bound itself.

## Published by AgentsHarnessPathAllowed for its caller.
harnessResolvedPath=""







## A granted call for this session, tool and resolved target; an Allow once is used up here.
## Not granted, the asks still open that would allow the call (`OPEN-ASK:` lines of the read)
## are kept for the refusal of this very call, as `<id> <kind> <who it waits on>` lines, with
## the call they are for: AgentsHarnessRefusal says them, and only for that same call.
harnessGrantOpen=""
harnessGrantOpenFor=""
## And what granted it, as the read says it (`standing floor`, `task <item>`, ...), for the gate.
harnessGrantLayer=""


## The gate of every file tool, reading or writing. A named member with no root flags given
## (harnessGateIndexed): the ceiling first -- a write in a read-only place is refused and the
## route named, never recorded, since no grant opens it -- then its session permission index
## (AgentsTools.Grants.include), by builtins only, rebuilt only when the grants index or the
## grants of a store it joins are newer: one awk, and for a session with a spawn record one
## more over the spawn records. Then what only this run knows, its children's folders and its
## sandbox, and its own member directory. Anyone else: the roots computed or given at start.
## Last, and only on the way to a refusal, the layers no index holds -- a routine's allows, a
## dispatch's planned allows -- through AgentsHarnessGranted, which forks.
## rc 0 admitted, $harnessResolvedPath published; 1 refused, said here; 2 not admitted, for
## the caller to record as a refusal; 4 held for approval, for a write tool to keep and show,
## never to apply (AgentsHarnessChangeHold): an approve row of the index covers the call, and
## no grant given for the task, the session, the routine or the one call admits it. What the
## member holds standing or by the floor, its own directory and its sandbox among them, does
## not come ahead of the approval.
harnessGateOrigin="${MDLT_ORIGIN:+$MDLT_ORIGIN/myx/myx.distro-agents/skillset}"


. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessToolsFile.include"




## A CHANGE HELD FOR APPROVAL (AgentsTools.InternOpChange.include). A call of Write or Edit
## that an approve grant covers, and no grant given for the work admits (the gate's rc 4), is
## neither refused nor applied: its change is kept, shown to the human-owner and applied when he approves, exactly
## as it was shown. Two more ways a call of these tools is made, each set by the tooling:
##   MDAT_CHANGE_APPLY=<folder of a kept change>: this call IS that change, approved, made
##       again by the operation that read his verdict, as the member, in its session. It is
##       applied like any call, where the gate admits it or still answers approve, and only
##       where each edit matches what it matched when it was shown; else nothing is written
##       and a `STALE:` line says why.
##   MDAT_CHANGE_HOLD_ONLY=<a file>: the call of a native client's own tool, put here by its
##       permission hook (--intern-op-permission-hook), which decides that call itself. It is
##       held where the gate answers approve, and that file is created to say so; anything
##       else changes nothing and is said in a `NOT-HELD:` line.
harnessChangeApply="${MDAT_CHANGE_APPLY:-}"
harnessChangeHoldOnly="${MDAT_CHANGE_HOLD_ONLY:-}"











. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessToolsBash.include"





. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessSearch.include"










## The one addressee rule of every send tool. The two names below are the only place a session's address is spelled
## here. What each names, and why one names nowhere, is the one address resolver's to say (DistroAgentsToolsResolveTarget).
harnessParentName="session-parent"
harnessCurrentName="session-current"

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessMessages.include"




## A DISMISSAL ENDS THE RUN, whatever its model then tries. A spawned session whose Wait
## returned DISMISSED keeps that as a mark in its own store, sessions/<spawn-id>/dismissed:
## who dismissed it. From then on its Wait never waits again (AgentsHarnessToolWait), the last
## line of its handback says to end and not to wait (AgentsHarnessToolSendMessage), and once
## that handback is given, marked beside it as dismissed.handback, the harness ends the
## session itself (AgentsHarnessDismissedAfter). Before this a session that was dismissed and
## handed back was told by that handback to wait until dismissed, did, and lived on.
## Only a spawned session keeps the mark: one never spawned has nobody who ends it, and a
## DISMISSED that reaches it by its member's name changes nothing in it. A spawn id is not
## run again once it was dismissed, so the mark is never taken back.

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessWait.include"
## After a tool ran: a session that was dismissed and has given its handback since is ended by
## the harness itself. Its own model loop stops at the end of the round (harnessDismissedEnd).
## A served call belongs to the run of another CLI, which this cannot stop from inside: that
## run is given MDAT_DISMISSED_END_GRACE seconds (default 60) after its handback to end by
## itself, and two where it waits again, and is then sent TERM, as TaskStop sends it, by a
## process of its own that outlives this call. The run is recognised by its own word on its
## own command line, the one rule (AgentsToolsRegistryRunWords), so a command line that only
## quotes the id is never signalled; where no process runs as it by that word, whatever line
## quotes the id, it is the process its launch started, with what that started
## (AgentsHarnessSessionPids).
harnessDismissedEnd=""

## ---- THE SEAT AND WHEN A RUN IS DISMISSED (F6.9; AgentsTools.SpawnSandbox.include) ----
## A member is active once in a session: of its runs there, the one that holds its seat reads the
## session and posts in it. The served Wait and SendMessage of a spawned run take its seat at its
## first read of the session or post to it. There is no seatless run: a run that finds the seat
## held by a live run is refused outright, at that read or post, naming the holder and
## <session>:<member>, and ends (AgentsHarnessSeatRefuse). A run whose seat passed to the run that
## restarts it is dismissed by the tooling. A dismissal of
## a run waits while runs that need it still run (AgentsToolsSessionDismissHeld), and is given at
## its first Wait once they have ended.













. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessBatch.include"


## Whether the harness knows the caller's checklist, and where: the member is the caller as the
## harness knows it; the session is the coworking session it works in (the one the spawn proxy
## named, else the one its own spawn record names, else its own); the place is the sandbox root
## of the spawn that founded the session, where a spawn founded it, else the session folder,
## sessions/<id>, where a root session founded it. Both are fixed from the session's start, so
## every run of every participant finds the one place. Sets checkListMember, checkListSession and
## checkListFolder; returns 1 with the refusal in checkListWhy where the member or the place is
## not known -- the tool stays listed, and the call is refused with that hint.
checkListMember="" checkListSession="" checkListFolder="" checkListWhy=""



## Helpers behind Agent, TaskStop and TaskOutput. Deliberately NOT named
## AgentsHarnessTool*: that family is the static tool class AgentsHarnessSelfCheck.test.awk
## matches site by site, and a helper with no tool behind it is an orphan there.

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessSpawn.include"















. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReports.include"














. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessAsk.include"









## The name the ask tool was called by, which every message of it carries: one of the names
## in AgentsTools.AskPost.include, which all run the one ask function below.
harnessAskName="AskQuestion"























. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessMcpResources.include"







## The floor is rendered by the mirror once per process and kept in this scratch file --
## the call runs in a command substitution, so a variable would not outlive it -- and both
## wires search that one literal. Only a rendering that succeeded is kept: a failed one
## is tried again, and says why, on the next call. The MCP entries are this round's
## $harnessMcpToolsJson, each already carrying its separating comma.
harnessToolSearchFloorFile="$harnessScratch/toolsearch.floor"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessSkills.include"




## THE PREFETCH (F10.8). What a harness member of a spawned session is told to read on its way to armed -- its own armed file, the
## sections of the team's armed file that its task names (the brief the spawner puts first in a dispatch, spawn-brief.document.format.md,
## gives them as `{name: .., file: .., section: ..}`), and, where the spawn record asks for the prefix of the routine, the routine's
## text mixed with its kind routine -- is read for it before its task: the text goes first in the first message of the run, as a block
## of its own, with the cache marker of the wire at its end (AgentsWireInitMessages). Exactly those reads and nothing more: the Skill
## tool's own answers to them, called here, so the skillset stays the one source and nothing is copied for an agent to read; the whole
## skill bundle stays what a default Skill load serves. Each read is kept in an internal cache under .local/agents/prefetch/, an
## entry for a read and one for a routine's text. An entry carries a stamp, the checksum, size and path of every file the text is
## made from and of the code that makes it, and it is used only where the stamp is the stamp of the files as they are now: an edited
## file is picked up by the very next spawn, and an entry made before a change is never served. Where the entry is not good, the text
## is built, and the entry written beside itself and renamed over. The run is armed at once, as the read of its armed file would have
## armed it (AgentsHarnessArmNote), and the same read asked later is answered in one line (AgentsHarnessToolSkill, and
## --get-routine-text for the routine's text, AgentsTools.PrefetchRoutine.include): in the first message already, unchanged. And the
## member layer says so instead of asking for the read (harnessArmedSentence): it is the harness's own text, and with no prefetch it is
## the same conditional sentence.
## Only a spawned member's harness run does it: a served call, a native client's, a run with no spawn, a resumed context, and a
## member with no armed file are as they were, and so is any run started with MDAT_HARNESS_PREFETCH=off (as MDAT_HARNESS_CONTEXT=off
## keeps no context). Nothing is written into the dispatch, its input/ or the spawn record; the routine's text leaves a marker in the
## root of the sandbox (AgentsToolsPrefetchMarkerWrite) for the process that prints it.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsTools.PrefetchRoutine.include"
harnessPrefetch="" harnessPrefetchWhat="" harnessPrefetchReads="" harnessPrefetchRoutineSum="" harnessPrefetchRoutineFiles="" harnessSkillWhole=""
## The prefix layers are the team layer (the team's basic and armed files in the system text), the tool floor, the member
## layer, and the session layer. A work-duty has two more (sketch 8: "Team+ layer ... -extended (for work-duty sessions) - more preloaded team
## static skill/knowledge", the same for the member): the Team+ layer, the optional skillset file magic-team/magic-team.armed-extended.md, after
## the team layer, and the Member+ layer, <member>/<member>.armed-extended.md, after the member's armed content. A skillset without those files
## has no such layer, and a run that is no work-duty never has one. A work-duty's routine and member static guidance are carried by its
## dispatch (the session layer). The routine's own `cache-prefix: routine` remains the one policy that preloads a routine.
harnessPrefetchOneLine="$( AgentsToolsPrefetchOneLine )"
## One read as the Skill tool answers it: the file of a skill, or the sections of it, whole whatever the cap of a result.
agentsPrefetchReadName="" agentsPrefetchReadFile="" agentsPrefetchReadSections=""
agentsPrefetchRoutineFile=""


## A tool_call's own `function.arguments` is itself a JSON document. It is parsed ONCE
## per call, by AgentsHarnessArgTable.awk -- the field reader's own engine, emitting every
## leaf at once -- and each lookup after that is builtins only. The table belongs to one
## raw argument string: AgentsHarnessArgParse on the same string again is a no-op, and
## any other string replaces it.
## Each top-level key spelled [A-Za-z0-9_] is also held as harnessArgV_<key>, and each
## `-<letters>` key (Grep's -n, -A ...) as harnessArgD_<letters>, holding exactly what
## "$( AgentsHarnessArgValue raw key )" yields: unset where that is empty, every
## trailing newline dropped as a command substitution drops it.
harnessArgRaw=""
harnessArgParsed=0
harnessArgPaths=()
harnessArgEncs=()
harnessArgFound=""
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessRun.include"



## The same value byte for byte, into harnessArgExact: a command substitution drops every
## trailing newline, so content ending in one would be written without it.
harnessArgExact=""
harnessArgOld=""



## One dispatch, two callers: the model loop below and the --intern-tool arm
## above it. The arms keep their own spelling because AgentsHarnessSelfCheck.test.awk
## locates them by it, and harnessResult stays global so the loop reads the
## result exactly where it always did.
## Arm before acting: a spawned session's model loop is redirected from any acting call until it
## has read its own duty file through Skill. Loading stays deferred. MAGIC.md, "Arm before acting".
harnessArmedAt="" harnessArmRedirectLogged="" harnessArmRanges=""


## The reply its caller is given for a result, by the one reply layer (AgentsTranscriptReplyFinish,
## AgentsTools.SessionTranscript.include): a long result kept in the session's results/ folder and
## named. The host's time is not inside it: harnessReplyDate is the part the model loop gives beside
## it (AgentsWireToolResultRecord), and the served exit prints the reply alone. harnessResult stays
## the result itself, for every check made on it. Nothing is added to a result that goes to the
## tooling rather than to a caller: a change applied or held for another call (MDAT_CHANGE_APPLY,
## MDAT_CHANGE_HOLD_ONLY), and the NOT-HELD of a native client's own tool.
harnessReply=""
harnessReplyDate=""

## One file's whole content, as `$( cat file )` gives it -- every trailing newline
## dropped, empty when it is absent -- into harnessFileText, with builtins only.
harnessFileText=""

## Includes load only on the path that uses them. A served --intern-tool call needs the
## wire and the MCP client only for the tools that reach an MCP server -- the client
## declares what a server lists through the wire's own AgentsWireToolDeclaration -- and
## every other served tool runs without either; the model path needs both. The hooks
## load for every path: a served call of any tool is put to them, as a model call is.
harnessNeedsMcp=1
if [ -n "$harnessToolOnly" ] ; then
	case "$harnessToolOnlyName" in
		ListMcpResourcesTool|ReadMcpResourceTool|ReadMcpResourceDirTool|ToolSearch|mcp__*) ;;
		*) harnessNeedsMcp="" ;;
	esac
fi

## THE LIFETIME OF THE INPUT CACHE (F10.7): what the preset of the spawn asks the cache markers of the Anthropic wire for, which the console passes as
## HARNESS_INPUT_CACHE_TIME. Unset is 5m, the provider's own, and the markers are what they were; 1h puts its ttl in every one. Checked here as it was at the
## setting and at the spawn, and on the model path alone: a value that is neither is refused before any request, not carried to the provider to be refused there.
harnessInputCacheTime="${HARNESS_INPUT_CACHE_TIME:-}"
if [ -z "$harnessToolOnly" ] ; then
	case "$harnessInputCacheTime" in
		''|5m|1h) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_INPUT_CACHE_TIME is none of 5m, 1h -- the preset of this run asks the input cache for a lifetime this wire does not know, so nothing was sent" >&2
			exit 1
		;;
	esac
fi

## Sourced, not exec'd: its functions run in this process and share everything above.
## Checked on every path, so a misnamed wire is refused exactly as it always was.
harnessWireFile="$harnessHere/harness/Agents${harnessWire}Wire.sh"
if [ ! -f "$harnessWireFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE=$harnessWire names no adapter in this package: $harnessWireFile" >&2
	exit 1
fi
if [ -n "$harnessNeedsMcp" ] ; then
	. "$harnessWireFile"
	## The declarations a hosted model is given state the cap this process applies.
	[ -z "${harnessToolsJson:-}" ] || harnessToolsJson="$( printf '%s\n' "$harnessToolsJson" | AgentsReadCapFill "$harnessReadCap" )"
	## Every tool takes background, timeout and timeout_action (epic S20): the declarations say so.
	[ -z "${harnessToolsJson:-}" ] || harnessToolsJson="$( printf '%s\n' "$harnessToolsJson" | LC_ALL=C awk -f "$harnessHere/harness/AgentsHarnessTaskArgsFill.awk" )"
	## The declarations are UNCONDITIONAL, CheckList among them: it is a basic tool, listed
	## wherever the wire declares it, and it refuses at execution where the harness knows no
	## member or no place for its list (AgentsHarnessCheckListPlace) -- never by being absent.
fi

## The bearer the auth header is built from. With no exchange declared it is the stored
## credential, seeded once here, and no exchange code runs anywhere in this process.
harnessBearer="$harnessToken"
if [ -n "$harnessTokenExchange" ] ; then
	harnessExchangeFile="$harnessHere/harness/Agents${harnessTokenExchange}Exchange.sh"
	if [ ! -f "$harnessExchangeFile" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_TOKEN_EXCHANGE=$harnessTokenExchange names no adapter in this package: $harnessExchangeFile" >&2
		exit 1
	fi
	## Sourced like the wire. AgentsExchangeBearer takes the stored credential on stdin --
	## the reason the token reaches curl that way -- and prints one line: the bearer, a
	## space, and its absolute expiry epoch, or a zero where it cannot say.
	. "$harnessExchangeFile"
	## A name is not a function: sourcing proves the file is there, never that it defines this.
	if [ "$( type -t AgentsExchangeBearer 2>/dev/null )" != function ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: $harnessExchangeFile defines no AgentsExchangeBearer -- the one function an exchange adapter owes" >&2
		exit 1
	fi
	harnessBearer=""
	harnessBearerGoodUntil=0
fi

## Sourced the same way, and after the wire so its refusals can name this run's tools.
## Absent, this refuses to start: a harness that cannot consult its hooks must not run
## unguarded, which is the same rule its hooks are held to.
harnessHooksFile="$harnessHere/harness/AgentsHarnessHooks.sh"
if [ ! -f "$harnessHooksFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the PreToolUse hook support is missing from this package: $harnessHooksFile" >&2
	exit 1
fi
. "$harnessHooksFile"

## Which servers a served call may reach is the tool's own business, not its caller's,
## so it is settled here rather than by whoever invoked this arm. Only the three
## resource tools and ToolSearch reach one at all, so only they pay for one being spawned. The set is
## the servers our installer registers for this workspace (its mcp.servers.index, or the
## same composed from our primary sources), minus this package's own server: our
## registered key and our serverInfo.name are both the literal myx.distro, and
## enumerating ourselves is how a walk descends into a copy of itself. Self-exclusion
## terminates only if every participant excludes itself, so the marker below travels
## to every child as well -- a copy of us reached through a foreign server sees it and
## declines. Named after the caller has parsed argv, and before the client is sourced,
## because that file enumerates as it loads. A model run that named no --mcp-server
## takes the same set, the empty name being that run: this harness is the myx.distro
## destination for it too. No registered server means no set, and nothing is printed.
## A set named on argv is the run's own and stays. With none named, the set is read
## again on every enumeration -- the client enumerates on load and again before any
## round that finds mcp.servers.index changed -- so a server the installer registers or
## removes reaches the next round rather than the next run.
case "$harnessToolOnlyName" in
	ListMcpResourcesTool|ReadMcpResourceTool|ReadMcpResourceDirTool|ToolSearch)
		export MDAT_MCP_SERVED_MARKER=1
	;;
esac
harnessMcpServersNamed="${#harnessMcpServers[@]}"

## Sourced on the same terms, and after the hooks so a server this enumerates is
## already subject to them. It enumerates only what harnessMcpServers holds by now,
## so a run holding none reads no file and starts no process.
harnessMcpFile="$harnessHere/harness/AgentsHarnessMcpClient.sh"
if [ ! -f "$harnessMcpFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the MCP client support is missing from this package: $harnessMcpFile" >&2
	exit 1
fi
[ -z "$harnessNeedsMcp" ] || . "$harnessMcpFile"
## The local lock primitive Write and Edit take; absent, every write is refused as unlockable.
[ ! -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.LocalLock.include" ] || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.LocalLock.include"
## The session transcript and token hooks; every one returns 0, and is called with || : besides.
[ ! -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include" ] || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"

## --intern-tool ends here: the tools, the hooks and, for a tool that reaches an MCP
## server, the MCP client are all in scope by now, and everything below this point is the
## model path -- which bash, reading a script as it runs it, never even parses on a
## served call. The argument object arrives
## on stdin as the same raw JSON a tool_call carries, so a served call and a model call
## read their arguments through one reader. stdout carries the result and nothing else.
if [ -n "$harnessToolOnly" ] ; then
	if [ -n "$harnessPlaceOnly" ] ; then
		if AgentsHarnessCheckListPlace ; then
			printf 'CHECKLIST-PLACE: %s\n' "$checkListFolder"
		else
			printf 'ERROR: %s\n' "$checkListWhy"
		fi
		harnessExitClean=1 ; exit 0
	fi
	harnessToolOnlyArgs="$( cat )"
	[ -n "$harnessToolOnlyArgs" ] || harnessToolOnlyArgs="{}"
	AgentsTranscriptToolStart "$harnessToolOnlyName" || :
	AgentsHarnessAnnounceTool "$harnessToolOnlyName" "$harnessToolOnlyArgs"
	## Every hook gets its say here exactly as it does in the loop: a surface that skips
	## them is a way around them.
	harnessResult="$( AgentsHarnessHooksRefusal "$harnessToolOnlyName" "$harnessToolOnlyArgs" )"
	harnessTranscriptOutcome="" ; [ -z "$harnessResult" ] || harnessTranscriptOutcome="refused"
	[ -n "$harnessResult" ] || AgentsHarnessRunTool "$harnessToolOnlyName" "$harnessToolOnlyArgs"
	## The call's tool line, to the daemon log and to the session's transcript. Not for the call
	## of a native client's own tool that this one did nothing about (NOT-HELD): its line is the client's.
	case "$harnessResult" in
		NOT-HELD:*) ;;
		*) AgentsTranscriptToolDone "$harnessToolOnlyName" "$harnessToolOnlyArgs" "$harnessResult" mcp "$harnessTranscriptOutcome" || : ;;
	esac
	## Served path tools also hand the server a request line and a one-line result summary, as a separate content part; stdout stays the plain result.
	case "$harnessHeadFile:$harnessToolOnlyName" in
		:*) ;;
		*:Read|*:Write|*:Edit|*:Glob|*:Grep)
			case "$harnessResult" in
				ERROR:*|OK:*|HELD:*) harnessHeadSummary="$( AgentsHarnessTruncateArg "${harnessResult%%$'\n'*}" )" ;;
				*) harnessHeadSummary="$( printf '%s' "$harnessResult" | LC_ALL=C awk '{ b += length($0) + 1 ; } END { printf "%d lines, %d bytes", NR, ( NR ? b - 1 : 0 ) ; }' )" ;;
			esac
			( harnessTool='' harnessValue='' harnessDim='' harnessOff='' harnessTitleActive='' ; AgentsHarnessAnnounceTool "$harnessToolOnlyName" "$harnessToolOnlyArgs" 2>&1 >/dev/null ; printf '      result %s\n' "$harnessHeadSummary" ) > "$harnessHeadFile" || :
		;;
	esac
	AgentsHarnessReply "$harnessToolOnlyName" "$harnessResult"
	printf '%s\n' "$harnessReply"
	## A refused or unknown tool leaves a caller's status check dead otherwise.
	case "$harnessResult" in
		ERROR:*)
			printf '%s\n' "   ${harnessBad}🚫 refused:${harnessOff} ${harnessDim}$( AgentsHarnessTruncateArg "$harnessResult" )${harnessOff}" >&2
			exit 1
		;;
	esac
	harnessExitClean=1 ; exit 0
fi

## The model path's own functions -- the bearer refresh and the per-round tool-call
## reader -- live in an include no served call loads.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessModelRound.include"
## The kept model context and its resume, on the model path only.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessContext.include"
## Its snapshots and rewinds (F10.5), on the model path only.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessCheckpoint.include"

## A spawned session run by this loop is one whose arming can be observed: said beside its record.
[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || : > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.harness" 2>/dev/null || :

## Said only when the two sets differ, so an ungranted run reads exactly as it did. The member layer names the roots of the workspace and of
## the member alone (harnessSystemRoots): what is of this run alone is told in the task block of its first message (AgentsHarnessRunNotesBuild).
harnessWriteNote=""
if [ "$harnessSystemWriteRoots" != "$harnessSystemRoots" ] ; then
	if [ -n "$harnessSystemWriteRoots" ] ; then
		harnessWriteNote="Writing is narrower than reading. Write and Edit may only write under these roots:
$harnessSystemWriteRoots
Everything else above you may read, list, search and run commands in, but not write to. Do not try to work around that -- report it instead.
"
	else
		## Where every writable root of this run is its own sandbox, there is no root of the member layer to list: the task block names them.
		harnessWriteNote="Writing is narrower than reading: the only roots Write and Edit may write are the ones this run's own instructions name with its task. Everything above you may read, list, search and run commands in, but not write to. Do not try to work around that -- report it instead.
"
	fi
fi

## A spawned session never ends on its own, its work done or not: its spawner dismisses it.
## Not one whose caller blocks on it (MDAT_SPAWN_CALLER_WAITS): that caller cannot send DISMISSED.
harnessSpawnedWaitNote=""
## Nor one that reports to no one, which ends on its report (AgentsHarnessReportsNone).
[ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || [ "${MDAT_SPAWN_CALLER_WAITS:-}" = "true" ] || AgentsHarnessReportsNone || harnessSpawnedWaitNote=" You are a spawned session: you never end on your own, not even when your work is done. When it is done, report that to whoever started you with SubagentHandback, saying you are done and waiting for further instructions, then keep waiting with Wait on your session thread and keep obeying what arrives there. End your run only when a Wait returns DISMISSED."

## THE TEXT OF THIS RUN ALONE (F10.7), told in the task block of the first message, after the marker of the prefetch block, and in no other place:
## the roots only this run has (its sandbox's input/ and output/, its results folder, its children's sandboxes), the sentence of a spawned session,
## and the note of an MCP server that is unavailable. None of it is in the member layer, which is then the same bytes for every run of a member,
## and so is the prefetch block behind it (the input token cache). Built at the start, so a rewind to the armed state renders the first message it was
## taken with, and again at a restart, whose first message carries the note as the latest enumeration left it. A root that appears later (a child's,
## on a resumed leg) is told by the message that brings it (AgentsHarnessContextResume), never written back into the system text or an earlier message.
harnessRunNotes=""
## THE LAYERS OF THE REQUEST (F10.7, the input token cache). The provider caches the request's exact prefix, so the request is ordered
## most-shared first, and each layer opens with a label that says whose words these are: the tool floor (the same for every member), the
## team layer in the system message (identical for every member and every session of the team), the member layer that opens the first user
## message (identical for every session of that member), then the run's own text in the task block. The system message is the team layer
## and nothing else: a member byte there would end the tool floor's shared prefix (measured). The generic harness paragraph travels with
## the team layer; it is the longest passage that was the same for every member. The provider and the access roots stay with the member
## layer: both are that leg's and that member's, not the team's.
harnessSystemCommon="Use the given tools to accomplish the request, then reply with a final plain-text message once done. A plain-text reply with no tool call ends your run, so never give one while the work is still open: waiting for an answer, a reply, another session or any other event is not done. Wait for it with the Wait tool (mcp__myx_distro__Wait over MCP), and after a TIMEOUT wait again, look elsewhere or escalate -- never end the run just to wait. Then carry on obeying your instructions. Nobody is reading this terminal, so a question written into your own answer reaches no one: where you genuinely need a decision only a person can make, AskQuestion is the one way to ask for one. Otherwise make the most reasonable choice and state what you did."
harnessSystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$harnessSystemRoots
$harnessWriteNote"
harnessSystemTeamFirst="" harnessSystemTeamRest="" harnessSystemTeam="" harnessMemberText=""

## The skill of a spawned member, read for it ahead of its task (F10.8), and the run armed by it: made before the member text, which
## says whether the member has its skill files in its first message or is to read them. A resumed run holds them in its kept context.
AgentsHarnessPrefetchBuild

## --agent given: the member's own identity replaces the generic opener entirely.
## Skill below is a tool name in prose, which no structural check can see.
if [ -n "$harnessAgent" ] ; then
	## ONE sentence for every session of the member. It says both cases conditionally -- where the tooling prefetched what the read would
	## give (a spawned session, F10.8) that is in the first message and the run is armed; otherwise it reads the file -- because a
	## sentence that differs with the prefetch, or that names what the prefetch carried (harnessPrefetchWhat: the task's section reads,
	## the routine), would differ between two sessions of one member inside the member layer, before the session layer the cache shares
	## (F10.7). The prefetch block itself names what it carries; --get-routine-text's line names the routine.
	harnessArmedSentence="Your own $harnessAgent.armed.md is what arms you. Where the tooling has already put what that read would give you into your first message, ahead of your task, you are armed and do not read it again. Otherwise read it with the Skill tool, name $harnessAgent and file $harnessAgent.armed.md, before your first acting call. In a spawned session, Write, Edit, Bash, execute, SendMessage, AskQuestion, ConfirmReadback, EscalateDecision, RequestPermission, ProposeApprove and Agent are redirected until you are armed. Every skillset file is read with Skill, which works even where Read is denied."
	## THE TEAM LAYER, and nothing else, is the system message (F10.7). The provider renders the system before the tool definitions, so
	## the team layer is the one part of the prompt every member can share; the floor behind it is then shared by every member too. The
	## system is one string: the team's identity/basic, the team's armed file -- the armed floor of every session kind, so a
	## standalone, a coworking and a work-duty run open with the same bytes -- and the harness paragraph every run carries.
	harnessSystemTeamFirst="## Team-wide -- the same for every member and every session of this team"
	if [ -n "$harnessSystemShared" ] ; then
		printf -v harnessSystemTeamFirst '%s\n\n%s' "$harnessSystemTeamFirst" "$harnessSystemShared"
	elif [ "$harnessAgent" = "magic-team" ] ; then
		printf -v harnessSystemTeamFirst '%s\n\n%s' "$harnessSystemTeamFirst" "$harnessAgentBasicText"
	fi
	## THE TEAM'S ARMED FILE (P2): it joins the team layer for every member run, whatever its session kind, after the team's
	## basic and before the tools. It is the team's own text, never a member's, so it does not end the shared prefix; and
	## because it is here, a work-duty's dispatch carries no second copy of it.
	if [ -r "${MDAT_SKILLSET_ROOT:-}/magic-team/magic-team.armed.md" ] ; then
		printf -v harnessSystemTeamFirst '%s\n\n%s' "$harnessSystemTeamFirst" "$( cat "$MDAT_SKILLSET_ROOT/magic-team/magic-team.armed.md" )"
	fi
	harnessSystemTeamRest="$harnessSystemCommon"
	harnessSystemTeam="$harnessSystemTeamFirst"$'\n\n'"$harnessSystemTeamRest"
	harnessSystemText="$harnessSystemTeam"
	## THE MEMBER LAYER, before the prefetch: this member's own words, the sentence of its armed file, and the roots this leg names.
	## It is identical for every session of the member; another member's run shares the team layer and the tool floor above and
	## diverges at this label. Kept out of the system message on purpose: a member byte there would end the tool floor's shared
	## prefix for every other member (measured; see AgentsPromptCacheLayersCheck).
	harnessMemberText="## Your role -- the same for every session of $harnessAgent"
	[ "$harnessAgent" = "magic-team" ] || printf -v harnessMemberText '%s\n\n%s' "$harnessMemberText" "$harnessAgentBasicText"
	printf -v harnessMemberText '%s\n\n%s\n\n%s' "$harnessMemberText" "$harnessArmedSentence" \
		"You are running through a bespoke $harnessProviderName harness$harnessSystemTail"
	## THE TEAM+ LAYER (S7.1), a work-duty's alone: the team's extended text, between the team layer above and the member layer, so every work-duty
	## session of every member shares it, and a session of any other kind is left as it was. It is the optional skillset file
	## magic-team/magic-team.armed-extended.md; a skillset without it has no such layer. In the first message and not in the system message, so the tool floor
	## stays shared by every session.
	if [ -r "${MDAT_SKILLSET_ROOT:-}/magic-team/magic-team.armed-extended.md" ] && AgentsHarnessWorkDuty ; then
		printf -v harnessMemberText '%s\n\n%s\n\n%s' "## Team+ -- more of the team's own text, the same for every work-duty session of this team" \
			"$( cat "$MDAT_SKILLSET_ROOT/magic-team/magic-team.armed-extended.md" )" "$harnessMemberText"
	fi
else
	harnessSystemText="You are an autonomous coding agent running through a bespoke $harnessProviderName harness$harnessSystemTail"
fi

## A named-but-unavailable MCP server owes the model a sentence: its tools are absent
## from the declarations, and nothing else in the run says why. It is told with the text of this run alone (F10.7), not in the system or
## member text.
AgentsHarnessRunNotesBuild
harnessMcpNoteTold="$harnessMcpUnavailableNote"

## A resume continues a kept context, or ends here, before any request: rc 7 tells the
## spawn proxy to start a new process instead (AgentsToolsSpawnProxyHarnessResumeRun).
if [ -n "${MDAT_HARNESS_RESUME_CONTEXT:-}" ] ; then
	AgentsHarnessContextResume || exit 7
else
	AgentsWireInitMessages
fi
AgentsHarnessContextInit
AgentsHarnessContextBegin "$harnessContextResumed"
## The armed state of a run the prefetch armed (F10.8) is a boundary already, before its first request: the system text and the first
## message with the member layer and the prefetch block, which a rewind to it renders again with the next input in place of the task (F10.5).
AgentsHarnessCheckpointInit
[ -z "$harnessPrefetch" ] || [ -z "$harnessArmedAt" ] || ! AgentsHarnessSnapshotTake armed init || harnessCheckpointArmedTaken=1

## THE INPUT TOKEN CACHE WATCH (F10.7, Constraint 12 of the epic), called before every request is built. It does two things.
## EFFORT WHILE THE RUN GOES ON: sessions/<key>/effort (unset, none, low, normal or high; --manager-session-effort writes it) is read each round, run's store first.
## Unset is the model's default, nothing sent; none is a level of its own, sent as the model's family says (AgentsHarnessEffortApply).
## Changing effort mid-conversation silently invalidates the input token cache; the first bullet of Constraint 12 (effort in a system message)
## needs a measured trial with a real key, so it is not tried here and the change is SAID. Before the first round an effort asked is simply the starting one.
## A PREFIX THAT CHANGED: the tools (the MCP set) or the system text differing from the last request's discards the cache the same
## way, and is said the same way. Nothing degrades silently.
harnessCacheSeenTools="" ; harnessCacheSeenSystem=""
AgentsHarnessCacheWatch(){
	local watchFile watchValue="" watchAsked="" watchOld watchNew watchTools watchSystem watchWhy=""
	if [ -n "${MMDAPP:-}" ] ; then
		for watchFile in "$( AgentsHarnessSessionKey )" "${MDAT_SESSION_ID:-}" ; do
			[ -n "$watchFile" ] && AgentsHarnessBareName "$watchFile" || continue
			[ -s "$MMDAPP/.local/agents/sessions/$watchFile/effort" ] || continue
			IFS= read -r watchValue < "$MMDAPP/.local/agents/sessions/$watchFile/effort" || :
			watchAsked="yes" ; break
		done
	fi
	if [ -n "$watchAsked" ] ; then
		case "$watchValue" in
			unset|none|low|normal|high) ;;
			*) watchAsked="" ;;
		esac
	fi
	if [ -n "$watchAsked" ] && [ "$watchValue" != "$harnessEffort" ] && [ "$watchValue" != "${harnessEffortRefused:-}" ] ; then
		watchOld="$harnessEffort" ; watchNew="$watchValue"
		harnessEffort="$watchValue"
		if ! AgentsHarnessEffortApply ; then
			## refused by the model (an error already said): the run goes on at the effort it had, and says so
			harnessEffort="$watchOld"
			AgentsHarnessEffortApply || :
			printf '%s\n' "${harnessWarn}⚠️ effort${harnessOff} ${harnessDim}-- $watchNew was refused for $harnessModel; the run stays at $watchOld${harnessOff}" >&2
			harnessEffortRefused="$watchNew"
			watchNew="$watchOld"
		fi
		[ "$harnessRound" -le 1 ] || [ "$watchNew" = "$watchOld" ] || watchWhy="effort changed from $watchOld to $watchNew"
	fi
	watchTools="$( printf '%s' "${harnessMcpToolsJson:-}" | cksum )" ; watchSystem="$( printf '%s' "$harnessSystemText" | cksum )"
	if [ "$harnessRound" -gt 1 ] ; then
		[ "$watchTools" = "$harnessCacheSeenTools" ] || watchWhy="${watchWhy}${watchWhy:+, }the tool set changed"
		[ "$watchSystem" = "$harnessCacheSeenSystem" ] || watchWhy="${watchWhy}${watchWhy:+, }the system text changed"
	fi
	harnessCacheSeenTools="$watchTools" ; harnessCacheSeenSystem="$watchSystem"
	[ -z "$watchWhy" ] || printf '%s\n' "${harnessWarn}💾 input cache${harnessOff} ${harnessDim}-- $watchWhy: the cached prefix of this session is discarded, so the next request pays its whole prompt again${harnessOff}" >&2
	return 0
}

## No round ceiling by default: a round is one model turn, which tracks neither
## cost nor progress, and a task is not finished by being cut off at one.
## MDAT_HARNESS_MAX_ROUNDS sets one where a caller wants it; unset means none.
harnessRound=0
## The rounds of the leg being run: back to 0 where the conversation is replaced (a restart, a rewind) and where a wait ends in an arrival, so that
## round 1 of a leg is the first model call of a wake, whose prompt-cache line (AgentsAnthropicMessagesWire) is the figure of that wake.
harnessLegRound=0
harnessMaxRounds="${MDAT_HARNESS_MAX_ROUNDS:-}"
## Whole rounds, by explicit enumeration rather than a collation-dependent range.
harnessMaxRoundsRest="$harnessMaxRounds"
while [ -n "$harnessMaxRoundsRest" ] ; do
	harnessMaxRoundsChar="${harnessMaxRoundsRest%"${harnessMaxRoundsRest#?}"}"
	harnessMaxRoundsRest="${harnessMaxRoundsRest#?}"
	case "$harnessMaxRoundsChar" in
		0|1|2|3|4|5|6|7|8|9) ;;
		*)
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_MAX_ROUNDS must be a whole number of rounds, got: $harnessMaxRounds" >&2
			exit 1
		;;
	esac
done
## At this many tokens in one round the leg asks the model to summarise its own work
## and restarts from that summary plus the original task, so nothing is dropped by age
## or by eviction -- the model judges what is worth carrying. 0 turns it off entirely.
## $harnessContextTokens is resolved with the tier above: the stub's own window for that
## model less its output maximum, and the core's 400000 only for a stub that declares none.
## No restart bound by default, as there is no round cap: MDAT_HARNESS_MAX_RESTARTS sets
## one where a caller wants it. Every restart is announced, so a cycle stays visible.
harnessMaxRestarts="${MDAT_HARNESS_MAX_RESTARTS:-}"
if ! AgentsHarnessWholeNumber "$harnessContextTokens" ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the restart threshold (MDAT_HARNESS_CONTEXT_TOKENS or PRESET_CONTEXT_MAX_SIZE) must be a whole number of tokens, got: $harnessContextTokens" >&2
	exit 1
fi
if [ -n "$harnessMaxRestarts" ] && ! AgentsHarnessWholeNumber "$harnessMaxRestarts" ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_MAX_RESTARTS must be a whole number of restarts, got: $harnessMaxRestarts" >&2
	exit 1
fi
if [ -n "$harnessOutputTokens" ] && ! AgentsHarnessWholeNumber "$harnessOutputTokens" ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_OUTPUT_TOKENS_* for the $harnessTier tier must be a whole number of tokens, got: $harnessOutputTokens" >&2
	exit 1
fi
## A THRESHOLD FAR BELOW THE SERVICE'S OWN WINDOW IS A BUDGET FAULT, SAID AT START.
## A run that restarts at a fraction of the window re-sends its whole prompt at every leg
## and finishes far later than one left to the window -- the class that made an old
## DeepSeek pair restart at 62K against a 1M window. Both numbers are printed, before the
## first request, so a preset's stale or copied context size is visible before it costs a
## session. The rule is "less than half": an ordinary threshold sits near the window.
case "${harnessWindowTokens:-}" in
	''|0|*[!0123456789]*) ;;
	*)
		if [ "$harnessContextTokens" != 0 ] && [ "$(( harnessContextTokens * 2 ))" -lt "$harnessWindowTokens" ] ; then
			printf '%s\n' "${harnessWarn}⚠️  restart threshold far below the service's window${harnessOff} ${harnessDim}-- $harnessContextTokens tokens against $harnessWindowTokens for $harnessModel ($harnessTier tier), less than half; this run will summarise-and-restart early, and every restart pays its whole prompt again -- raise PRESET_CONTEXT_MAX_SIZE (or MDAT_HARNESS_CONTEXT_TOKENS) to the window this service really gives, or unset it${harnessOff}" >&2
		fi
	;;
esac
harnessRestartCount=0
harnessSummariseRound=0
## Read by the wire adapter; empty leaves that wire's own default in place.
harnessToolChoice=""
## Recorded and displayed, never enforced: this leg carries no budget.
harnessUsagePrompt="" harnessUsageCompletion="" harnessUsageTotal=""
harnessClosingRound=0
## The session transcript's MODEL line, where the spawn proxy opened one.
AgentsTranscriptHarnessStart || :

while : ; do
	harnessRound=$(( harnessRound + 1 ))
	harnessLegRound=$(( harnessLegRound + 1 ))
	## At a cap the run keeps its work: one last round, tools still declared but
	## unusable, so what was read and run is reported instead of discarded.
	if [ -n "$harnessMaxRounds" ] && [ "$harnessRound" -gt "$harnessMaxRounds" ] ; then
		harnessMessages+=( "$( AgentsWireUserRecord "Your round limit is reached and no further tool call can run. Reply now, in plain text, with what you did, what you found, and what is left unfinished." )" )
		harnessToolChoice="none"
		harnessClosingRound=1
		printf '%s\n' "${harnessWarn}⚠️  round cap reached${harnessOff} ${harnessDim}-- closing round, tools off; MDAT_HARNESS_MAX_ROUNDS raises the cap${harnessOff}" >&2
	## The signal is the last round's own total, never the running sum: every round
	## re-sends the whole conversation, so the sum counts the same context once per
	## round while one round's prompt plus completion is what actually sat in the
	## window. A restart zeroes it, so the summarise round's own total cannot re-trip it.
	elif [ "$harnessContextTokens" != 0 ] && [ "${harnessRoundTotal:-0}" -ge "$harnessContextTokens" ] ; then
		if [ -n "$harnessMaxRestarts" ] && [ "$harnessRestartCount" -ge "$harnessMaxRestarts" ] ; then
			harnessMessages+=( "$( AgentsWireUserRecord "Your context is full and your restart budget is spent, so no further tool call can run. Reply now, in plain text, with what you did, what you found, and what is left unfinished." )" )
			harnessToolChoice="none"
			harnessClosingRound=1
			printf '%s\n' "${harnessWarn}⚠️  context threshold reached with no restart left${harnessOff} ${harnessDim}-- closing round, tools off; MDAT_HARNESS_MAX_RESTARTS raises the bound${harnessOff}" >&2
		else
			harnessMessages+=( "$( AgentsWireUserRecord "Your context is nearly full and this leg is about to be restarted, so no further tool call can run in it. Write the handover a fresh leg needs: it will be given the original task again word for word, and nothing else from this conversation. State what you have already done, what you found -- exact paths, names, values and commands, not a description of them -- what is still to do, and what must not be repeated. Write it as notes to yourself, in plain text, with no preamble." )" )
			harnessToolChoice="none"
			harnessSummariseRound=1
			printf '%s\n' "${harnessWarn}♻️  context threshold reached${harnessOff} ${harnessDim}-- $harnessRoundTotal tokens last round, at or over $harnessContextTokens; summarising for restart $(( harnessRestartCount + 1 ))${harnessMaxRestarts:+ of $harnessMaxRestarts}${harnessOff}" >&2
		fi
	fi

	## Braces are load-bearing: bash 3.2 reads the first byte of an abutting UTF-8
	## character as part of an unbraced name.
	AgentsHarnessTitleState
	printf '%s\n' "${harnessDim}── round $harnessRound ─────────────────────────────────${harnessOff}${harnessUsageTotal:+ ${harnessDim}· $harnessUsageTotal tokens so far${harnessOff}}" >&2

	## The MCP set is enumerated again before a round only when the catalogue may be stale --
	## mcp.servers.index changed, a server was unavailable, or a call failed to reach its
	## server (AgentsHarnessMcpStale); its report shows when the set or the note changed.
	if [ "$harnessRound" -gt 1 ] && AgentsHarnessMcpStale ; then
		harnessMcpToolsJsonWas="$harnessMcpToolsJson"
		AgentsHarnessMcpEnumerate 2> "$harnessScratch/mcp.enum.err"
		if [ "$harnessMcpToolsJson" != "$harnessMcpToolsJsonWas" ] || [ "$harnessMcpUnavailableNote" != "$harnessMcpNoteTold" ] ; then
			printf '%s\n' "${harnessWarn}🔌 MCP tool set changed${harnessOff} ${harnessDim}-- this round declares the set enumerated now${harnessOff}" >&2
			cat "$harnessScratch/mcp.enum.err" >&2
		fi
		## A changed unavailable note reaches the model between rounds, as a job's output does.
		if [ "$harnessMcpUnavailableNote" != "$harnessMcpNoteTold" ] ; then
			if [ -n "$harnessMcpUnavailableNote" ] ; then
				harnessMessages+=( "$( AgentsWireUserRecord "The MCP servers available to you have changed since you were last told. As of now:"$'\n'"$harnessMcpUnavailableNote" )" )
			else
				harnessMessages+=( "$( AgentsWireUserRecord "The MCP servers available to you have changed since you were last told: every MCP server named for this run is now available, and any earlier sentence saying one is unavailable no longer holds." )" )
			fi
			harnessMcpNoteTold="$harnessMcpUnavailableNote"
		fi
	fi

	## To a file, never argv: a long conversation outgrows the OS argument limit, and
	## stdin is already the header channel.
	## The kept context first gains whatever user turns this round adds.
	AgentsHarnessContextSync user ""
	AgentsHarnessCacheWatch
	AgentsWireRequestBody > "$harnessScratch/request.json"

	## Every attempt starts from a clean accumulator, and a retry here never touches
	## $harnessRound above. The count is per leg (HARNESS_STREAM_ATTEMPTS), and a failed
	## attempt waits before the next: HARNESS_RETRY_DELAY seconds, doubled each time. A
	## test or a provider that wants none sets it to 0.
	harnessStreamAttempt=0
	harnessStreamMaxAttempts="${HARNESS_STREAM_ATTEMPTS:-3}"
	case "$harnessStreamMaxAttempts" in ''|*[!0123456789]*|0) harnessStreamMaxAttempts=3 ;; esac
	[ "$harnessStreamMaxAttempts" -le 10 ] || harnessStreamMaxAttempts=10
	harnessRetryDelay="${HARNESS_RETRY_DELAY:-1}"
	case "$harnessRetryDelay" in ''|*[!0123456789]*) harnessRetryDelay=1 ;; esac
	harnessRetryWait=0
	harnessStatus=""
	harnessStreamOk=0
	while [ "$harnessStreamAttempt" -lt "$harnessStreamMaxAttempts" ] ; do
		harnessStreamAttempt=$(( harnessStreamAttempt + 1 ))
		rm -f "$harnessScratch"/stream.* 2>/dev/null
		: > "$harnessScratch/stream.content"

		## Token on curl's stdin, never argv, and any declared extra header rides that same
		## channel, so argv is the same length whatever a leaf declares. Built per attempt
		## because the auth carve-out below re-exchanges the bearer and retries.
		AgentsHarnessRefreshBearer
		harnessAuthHeader="Authorization: Bearer $harnessBearer"
		[ -z "$harnessExtraHeaders" ] || harnessAuthHeader="$harnessAuthHeader"$'\n'"$harnessExtraHeaders"

		## Nothing else may sit in this pipe or block buffering returns.
		## set +e brackets this one statement so ${PIPESTATUS[0]} is curl's, not the loop's.
		set +e
		curl -N -sS --connect-timeout 10 --speed-limit 1 --speed-time 45 -X POST "$harnessEndpoint" \
			-H @- \
			-H "Content-type: application/json" \
			-D "$harnessScratch/stream.headers" \
			--data-binary "@$harnessScratch/request.json" <<< "$harnessAuthHeader" 2>"$harnessScratch/stream.curlerr" \
			| AgentsWireStreamConsume
		harnessCurlRc="${PIPESTATUS[0]}"
		set -e

		if [ "$harnessCurlRc" = "0" ] && [ -f "$harnessScratch/stream.done" ] ; then
			harnessStreamOk=1
			break
		fi

		## The status line, when the transport gave one: a body alone cannot say whether a
		## refusal is temporary. A leg whose transport writes no headers reads an empty one.
		harnessStatus=""
		[ ! -s "$harnessScratch/stream.headers" ] || harnessStatus="$( LC_ALL=C awk 'NR == 1 { print $2 }' "$harnessScratch/stream.headers" 2>/dev/null )" || harnessStatus=""

		## A complete, non-streaming error body is a refusal, not a disconnect. Two things
		## can make it worth another attempt: an auth-class refusal on a leg that exchanges
		## its bearer, an HTTP status the provider uses for a temporary condition, or a
		## refusal body whose own type is one of those. Everything else ends the round.
		if [ -s "$harnessScratch/stream.rawother" ] && [ ! -f "$harnessScratch/stream.done" ] ; then
			harnessRetryable=0
			case "$harnessStatus" in
				429|500|502|503|504|529) harnessRetryable=1 ;;
			esac
			if [ "$harnessRetryable" = 0 ] ; then
				case "$( cat "$harnessScratch/stream.rawother" )" in
					*rate_limit*|*overloaded*|*server_error*|*api_error*|*timeout*|*unavailable*) harnessRetryable=1 ;;
				esac
			fi
			harnessAuthRefusal=0
			if [ -n "$harnessTokenExchange" ] ; then
				case "$( cat "$harnessScratch/stream.rawother" )" in
					*401*|*nauthorized*|*nvalid_token*|*xpired*) harnessAuthRefusal=1 ;;
				esac
			fi
			if [ "$harnessRetryable" = 0 ] && [ "$harnessAuthRefusal" = 0 ] ; then
				break
			fi
			if [ "$harnessStreamAttempt" -ge "$harnessStreamMaxAttempts" ] ; then
				break
			fi
			if [ "$harnessAuthRefusal" = 1 ] ; then
				harnessBearer=""
				echo "${harnessWarn}🔁 RETRY:${harnessOff} stream attempt $harnessStreamAttempt/$harnessStreamMaxAttempts was refused as an auth failure${harnessStatus:+ (HTTP $harnessStatus)} -- dropping the cached bearer, re-exchanging and retrying the whole round" >&2
			else
				echo "${harnessWarn}🔁 RETRY:${harnessOff} stream attempt $harnessStreamAttempt/$harnessStreamMaxAttempts was refused${harnessStatus:+ with HTTP $harnessStatus} as a temporary condition -- retrying the whole round after the backoff" >&2
			fi
		else
			echo "${harnessWarn}🔁 RETRY:${harnessOff} stream attempt $harnessStreamAttempt/$harnessStreamMaxAttempts disconnected mid-stream (curl rc=$harnessCurlRc$( [ ! -s "$harnessScratch/stream.curlerr" ] || printf ': %s' "$( cat "$harnessScratch/stream.curlerr" )" )) -- discarding partial output and retrying the whole round" >&2
		fi
		## Backoff before the next attempt: the base, doubled each time, capped at 30 seconds.
		if [ "$harnessRetryDelay" -gt 0 ] ; then
			harnessRetryWait=$(( harnessRetryWait > 0 ? harnessRetryWait * 2 : harnessRetryDelay ))
			[ "$harnessRetryWait" -le 30 ] || harnessRetryWait=30
			sleep "$harnessRetryWait" 2>/dev/null || :
		fi
		done

	## Give stderr a clean line break after any accumulated live text.
	[ ! -s "$harnessScratch/stream.content" ] || printf '\n' >&2

	## The round's own file goes with the other stream.* accumulators; the running one stays.
	if [ -s "$harnessScratch/stream.usage" ] ; then
		read -r harnessRoundPrompt harnessRoundCompletion harnessRoundTotal < "$harnessScratch/stream.usage" || :
		harnessUsagePrompt=$(( harnessUsagePrompt + harnessRoundPrompt ))
		harnessUsageCompletion=$(( harnessUsageCompletion + harnessRoundCompletion ))
		harnessUsageTotal=$(( harnessUsageTotal + harnessRoundTotal ))
		printf '%s %s %s\n' "$harnessUsagePrompt" "$harnessUsageCompletion" "$harnessUsageTotal" > "$harnessScratch/usage.running"
	## Enabled and never fed: the threshold can never fire, and a run that then walks
	## into the model's own limit reads exactly like one this managed. Said once.
	elif [ "$harnessRound" = 1 ] && [ "$harnessContextTokens" != 0 ] ; then
		printf '%s\n' "${harnessWarn}⚠️  no token usage in this stream${harnessOff} ${harnessDim}-- MDAT_HARNESS_CONTEXT_TOKENS is $harnessContextTokens, but nothing here measures the context, so no summarise-and-restart can fire${harnessOff}" >&2
	fi
	## The round's tokens and visible text to the session transcript, usage or none.
	AgentsTranscriptHarnessRound "$harnessRound" "$harnessScratch" || :

	if [ "$harnessStreamOk" != "1" ] && [ ! -s "$harnessScratch/stream.rawother" ] ; then
		## a provider that gave no complete answer ends the run: kept beside the record with its reason, as a refusal is (sketch 3.6)
		AgentsHarnessRefusalKeep "$harnessHost gave no complete answer -- gave up after $harnessStreamMaxAttempts stream attempts, none reached a clean [DONE]"
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: round $harnessRound: gave up after $harnessStreamMaxAttempts stream attempts, none reached a clean [DONE] (see DESIGN DECISION 1: a partial stream is always discarded, never spliced) -- last curl rc=$harnessCurlRc" >&2
		exit 1
	fi

	harnessResponseSynthesized=0
	if [ -s "$harnessScratch/stream.rawother" ] ; then
		harnessResponse="$( cat "$harnessScratch/stream.rawother" )"
	else
		## The adapter synthesizes the exact document shape the downstream code expects.
		AgentsWireSynthesizeResponse
		harnessResponseSynthesized=1
	fi

	## From here $harnessResponse is either a real non-streaming error body or this
	## round's synthesized document, and this code cannot tell the two apart.
	harnessErrorRc=0
	harnessErrorCode="$( AgentsWireErrorCode )" || harnessErrorRc=$?
	if [ "$harnessErrorRc" = "0" ] ; then
		harnessErrorDetail="$( AgentsHarnessArgValue "$harnessResponse" message )"
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: $harnessHost refused the request -- $harnessErrorCode: ${harnessErrorDetail:-<no message>}" >&2
		AgentsHarnessRefusalKeep "$harnessHost refused the request -- $harnessErrorCode: ${harnessErrorDetail:-<no message>}"
		exit 1
	elif [ "$harnessErrorRc" != "3" ] ; then
		AgentsHarnessRefusalKeep "$harnessHost gave an answer that was not a parseable JSON object (rc=$harnessErrorRc)"
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: response was not a parseable JSON object (rc=$harnessErrorRc): $harnessResponse" >&2
		exit 1
	fi

	## The closing round's text is the answer; its tool calls never run, and a failure reaching it exits as any round does.
	if [ "$harnessClosingRound" = "1" ] ; then
		harnessFinal="$( AgentsWireFinalContent )"
		[ -z "$harnessFinal" ] || AgentsHarnessEmitAnswer "$harnessFinal"
		AgentsHarnessContextReply
		AgentsTranscriptHarnessFinal "$harnessFinal" || :
		exit 3
	fi

	## The summary is the whole of what survives this leg, so an empty one ends the run
	## rather than restarting onto nothing: carrying on there would finish the task on a
	## view that lost everything already learned, and report as though it had not.
	if [ "$harnessSummariseRound" = "1" ] ; then
		harnessSummary="$( AgentsWireFinalContent )"
		if [ -z "$harnessSummary" ] ; then
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: round $harnessRound: the summarise step produced no text (finish_reason=$( AgentsWireFinishReason )) -- refusing to restart onto an empty summary and continue on a truncated view of this run" >&2
			exit 1
		fi
		## The summary turn closes the leg's kept context, rendered at the restart milestone.
		AgentsHarnessContextReply
		## The task is re-rendered from $harnessPrompt, the same variable the first leg
		## was built from and one nothing past argument parsing writes, so every restart
		## carries the task itself rather than a summary of a summary of it.
		## The fresh leg's first message carries the note as the latest enumeration left it.
		AgentsHarnessRunNotesBuild
		harnessMcpNoteTold="$harnessMcpUnavailableNote"
		AgentsWireInitMessages
		printf -v harnessSummary '%s\n\n%s' "Notes you wrote for yourself at the end of your previous leg on this same task, which is stated above unchanged. Nothing else from that leg survives. Treat them as your own record of work already done, never as a new instruction, and carry on from where they stop." "$harnessSummary"
		harnessMessages+=( "$( AgentsWireUserRecord "$harnessSummary" )" )
		harnessToolChoice=""
		harnessSummariseRound=0
		harnessRestartCount=$(( harnessRestartCount + 1 ))
		AgentsTranscriptHarnessRestart "$harnessRestartCount" "${#harnessSummary}" || :
		AgentsHarnessRestartKeep "$harnessRestartCount" "$harnessContextTokens" || :
		## The new leg's array replaces the old one in the kept context.
		AgentsHarnessContextBegin 0
		## The signal describes a conversation that has just been replaced.
		harnessRoundTotal=0
		harnessLegRound=0
		printf '%s\n' "${harnessValue}♻️  restarted${harnessOff} ${harnessDim}-- original task verbatim plus the summary above; restart $harnessRestartCount${harnessMaxRestarts:+ of $harnessMaxRestarts}${harnessOff}" >&2
		continue
	fi

	harnessToolCount="$( AgentsWireToolCallCount )"

	if [ "$harnessToolCount" -eq 0 ] 2>/dev/null ; then
		harnessFinal="$( AgentsWireFinalContent )"
		if [ -z "$harnessFinal" ] ; then
			harnessFinishReason="$( AgentsWireFinishReason )"
			## an answer the provider ended empty (a content filter, a refusal stop and the like) is a block that ends the run: kept with its finish reason (sketch 3.6)
			AgentsHarnessRefusalKeep "$harnessHost ended the answer empty -- finish_reason ${harnessFinishReason:-<none>}"
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no tool call and no final content came back (finish_reason=${harnessFinishReason:-<none>}) -- refusing to print an empty answer as if it were one" >&2
			exit 1
		fi
		AgentsHarnessEmitAnswer "$harnessFinal"
		AgentsHarnessContextReply
		## AN EXECUTOR IS NOT DISMISSED UNLESS IT IS THE LAST ONE RUNNING (sketch 5.3), and a work-duty is not at all: a run whose session has another run
		## still going does not end on its plain reply either (AgentsHarnessOthersRunning). It waits as a duty does, and the quiet round of its wait
		## asks the question again.
		## A WORK-DUTY IS A LOOP IN ONE SESSION AND ONLY A DISMISSAL ENDS IT: a plain-text reply is its model thinking it is done, not an end.
		## The idle-wait is made here as the model would have made it, the conversation is returned to its checkpoint where one is held, and the
		## model is asked again. A dismissed run, a run that is no work-duty and a run that answers plain ten times in a row without a tool call
		## in between (a wait that cannot be made) end as before.
		if [ -z "$harnessDismissedEnd" ] && [ "${harnessDutyPlainRuns:-0}" -lt 10 ] && { AgentsHarnessWorkDuty || AgentsHarnessOthersRunning ; } \
			&& [ ! -e "$MMDAPP/.local/agents/sessions/${MDAT_SPAWN_SESSION_ID:-/}/dismissed" ] ; then
			harnessDutyPlainRuns=$(( ${harnessDutyPlainRuns:-0} + 1 ))
			harnessIdleForce=1
			AgentsHarnessIdleWait -
			harnessIdleForce=""
			continue
		fi
		AgentsTranscriptHarnessFinal "$harnessFinal" || :
		harnessExitClean=1 ; exit 0
	fi
	harnessDutyPlainRuns=0

	## The assistant's own tool_calls message goes into history verbatim first -- this
	## API's required shape for a multi-turn tool exchange.
	## Every call's fields are read once, here, and both loops below take them from there.
	AgentsHarnessToolCallsRead "$harnessToolCount"
	harnessToolCallsJson=""
	harnessIndex=0
	while [ "$harnessIndex" -lt "$harnessToolCount" ] ; do
		harnessCallId="${harnessCallIds[$harnessIndex]}"
		harnessFuncName="${harnessCallNames[$harnessIndex]}"
		harnessFuncArgsRaw="${harnessCallArgs[$harnessIndex]}"
		harnessToolCallsJson="${harnessToolCallsJson}${harnessToolCallsJson:+,}$( AgentsWireToolCallEntry "$harnessCallId" "$harnessFuncName" "$harnessFuncArgsRaw" )"
		harnessIndex=$(( harnessIndex + 1 ))
	done
	harnessMessages+=( "$( AgentsWireAssistantToolCallsRecord "$harnessToolCallsJson" )" )
	AgentsHarnessContextSync assistant "$( AgentsHarnessContextAssistantMeta )"

	## Then one result per call, keyed by that exact tool_call_id.
	harnessIndex=0
	while [ "$harnessIndex" -lt "$harnessToolCount" ] ; do
		harnessCallId="${harnessCallIds[$harnessIndex]}"
		harnessFuncName="${harnessCallNames[$harnessIndex]}"
		harnessFuncArgsRaw="${harnessCallArgs[$harnessIndex]}"

		AgentsTranscriptToolStart "$harnessFuncName" || :
		AgentsHarnessAnnounceTool "$harnessFuncName" "$harnessFuncArgsRaw"

		## Every configured hook gets its say before the call runs, and a refusal becomes
		## the result the model reads, so the tool never executes.
		harnessResult="$( AgentsHarnessHooksRefusal "$harnessFuncName" "$harnessFuncArgsRaw" )"
		[ -n "$harnessResult" ] || harnessResult="$( AgentsHarnessArmGate "$harnessFuncName" )"
		if [ -n "$harnessResult" ] && [ -z "$harnessArmRedirectLogged" ] && [ "${harnessResult#ERROR: read your duty file first}" != "$harnessResult" ] ; then
			harnessArmRedirectLogged=1
			## A tracking post of this run, so it goes into the tracking thread of its coworking
			## session, a reply there as every other is (AgentsToolsEventTrackThreadPost), never a
			## post of its own at the top of event-track.
			(
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.EventTrackThread.include"
				AgentsToolsEventTrackThreadPost "$harnessAgent" "$( AgentsToolsEventTrackThreadOwnDir )" --kind refusal \
					--session-id "$MDAT_SPAWN_SESSION_ID" --field what="Unarmed call redirected" --field tool="$harnessFuncName" \
					--field reason="read $harnessAgent.armed.md with Skill first" < /dev/null
			) > /dev/null 2>&1 || :
		fi

		## A result already here is a hook's or the arm gate's: the call was refused, not run.
		harnessTranscriptOutcome="" ; [ -z "$harnessResult" ] || harnessTranscriptOutcome="refused"
		[ -n "$harnessResult" ] || AgentsHarnessRunTool "$harnessFuncName" "$harnessFuncArgsRaw"
		AgentsHarnessArmNote "$harnessFuncName" "$harnessFuncArgsRaw" "$harnessResult"
		## The result joins the array, and the kept context, before the milestone its
		## transcript hook may commit, so that commit carries this call. The model is given
		## the reply (AgentsHarnessReply), and the kept context and the transcript line record
		## it, so a line rendered from the context is the line the hook writes; every check
		## below still reads the result itself.
		AgentsHarnessReply "$harnessFuncName" "$harnessResult"
		harnessMessages+=( "$( AgentsWireToolResultRecord "$harnessCallId" "$harnessReply" "$harnessReplyDate" )" )
		AgentsHarnessContextSync tool "$( [ -z "$harnessContextFile" ] || AgentsHarnessContextToolMeta "$harnessFuncName" "$harnessCallId" "$harnessResult" "$harnessTranscriptOutcome" )"
		AgentsTranscriptToolDone "$harnessFuncName" "$harnessFuncArgsRaw" "$harnessReply" loop "$harnessTranscriptOutcome" || :

		## The announce line states an intent and reads the same whether the call ran or
		## was refused, so a refusal is marked explicitly for a transcript reader.
		case "$harnessResult" in
			ERROR:*)
				printf '%s\n' "   ${harnessBad}🚫 refused:${harnessOff} ${harnessDim}$( AgentsHarnessTruncateArg "$harnessResult" )${harnessOff}" >&2
			;;
		esac

		harnessIndex=$(( harnessIndex + 1 ))
	done
	## A session that was dismissed and has given its handback since ends here, whatever its
	## model would call next (AgentsHarnessDismissedAfter): the round is whole, and no request follows.
	if [ -n "$harnessDismissedEnd" ] ; then
		printf '%s\n' "🏁 ${harnessDim}dismissed, and the handback is given: the run ends here${harnessOff}" >&2
		harnessExitClean=1 ; exit 0
	fi
	## The round is whole, so this is a turn boundary: the snapshots and rewinds the run's executor asked in it are made (F10.5).
	AgentsHarnessCheckpointRound
done
