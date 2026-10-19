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

## Composed from what this run already tracks, read at call time rather than passed
## around: identity, model, round, the token figure, and whatever is happening right
## now. The detail argument is optional -- a round boundary has none. The figure is the
## last round's own total against the threshold that total is compared with, never the
## running sum: every round re-sends the whole conversation, so the sum counts the same
## context once per round and is not the number any decision here reads. It appears only
## once a round has actually been measured, rather than asserting a zero nothing weighed.
AgentsHarnessTitleState(){ ## optional trailing detail
	[ -n "$harnessTitleActive" ] || return 0
	local stateText="${harnessAgent:-harness} · ${harnessModel:-?} · round ${harnessRound}${harnessRoundTotal:+ · $harnessRoundTotal/$harnessContextTokens}${1:+ · $1}"
	printf '\033]2;%s\007' "$stateText" >&2
	## The reserved row is outside the scroll region, so this write cannot scroll, and the
	## cursor save/restore therefore returns to a partially written reasoning line exactly
	## as it was. ESC 7/ESC 8 rather than CSI s/CSI u: measured on Terminal.app, the CSI
	## pair leaves the cursor where it was moved to and only the DEC pair restores it. Cut
	## one column short -- a line reaching the last cell wraps, and a wrap there scrolls.
	[ -n "$harnessStatusRows" ] || return 0
	printf '\0337\033[%d;1H\033[K%s%s%s\0338' "$harnessStatusRows" "$harnessDim" "${stateText:0:$(( COLUMNS - 1 ))}" "$harnessOff" >&2
}

## Every terminal change this run made, undone in the one cleanup that runs on every
## exit. The region is reset first and the cursor then parked on the row the status line
## held: resetting DECSTBM homes the cursor, so without the reposition the next shell
## prompt lands at the top of the screen, over output that has not scrolled into the
## buffer yet and cannot be recovered once overwritten.
AgentsHarnessRestoreTerminal(){
	[ -n "$harnessTitleActive" ] || return 0
	[ -z "$harnessStatusRows" ] || printf '\033[r\033[%d;1H\033[K' "$harnessStatusRows" >&2
	printf '\033]2;%s\007' "$harnessHostName" >&2
}

## One place the answer leaves by, so the two emit sites cannot render differently.
## The rendering is captured rather than piped straight through: a filter that fails
## halfway would otherwise print a partial answer and then the whole of it again.
AgentsHarnessEmitAnswer(){ ## answer text
	local emitRendered
	if [ -n "$harnessMarkdownFilter" ] \
		&& emitRendered="$( printf '%s\n' "$1" | "$harnessMarkdownFilter" 2>/dev/null )" \
		&& [ -n "$emitRendered" ] ; then
		printf '%s\n' "$emitRendered"
		return 0
	fi
	printf '%s\n' "$1"
}

## Checked rather than trusted: a missing one otherwise fails silently and far away.
harnessSelfName="${HARNESS_SELF_NAME:-AgentsUniversalHarness.sh}"
harnessProviderName="${HARNESS_PROVIDER_NAME:-}"
harnessEndpoint="${HARNESS_ENDPOINT:-}"
harnessHost="${HARNESS_HOST:-}"
harnessWire="${HARNESS_WIRE:-}"
harnessCredentialNames="${HARNESS_CREDENTIAL_NAMES:-}"

## One tool, no model round: the MCP mirror serves the tool floor this file declares,
## and a served call runs the tool HERE rather than through a second implementation.
## No provider is involved, so the provider contract, the prompt, the credential and
## the model are all skipped. First argument only -- a prompt is trailing argv.
harnessToolOnly=""
harnessToolOnlyName=""
harnessServedWaitBound=""
## --intern-checklist-place: whether CheckList is offered to the session this process runs for,
## as a served CheckList call resolves it -- the served identity, then AgentsHarnessCheckListPlace
## -- and nothing run, logged or written: one line, `CHECKLIST-PLACE: <folder>` or `ERROR: <why>`.
## The MCP server asks it to decide whether its floor serves CheckList.
harnessPlaceOnly=""
if [ "${1:-}" = --intern-checklist-place ] ; then
	harnessPlaceOnly=1
	set -- --intern-tool CheckList
fi
## Read and Skill return whole lines up to this many bytes; a served result stays under the MCP client's own limit.
## Both values are stated once, in AgentsHarnessReadCap.include, which also fills them into the descriptions.
. "$harnessHere/AgentsHarnessReadCap.include"
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
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: this is the universal core and is never run directly -- a provider stub sets these and execs it. Not set:$harnessMissing" >&2
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
harnessReasoningEffort=""
case "$harnessTier" in
	light)
		harnessModel="$HARNESS_MODEL_LIGHT"
		harnessToken="${HARNESS_TOKEN_LIGHT:-}"
		harnessOutputTokens="${HARNESS_OUTPUT_TOKENS_LIGHT:-}"
		harnessContextTokens="${MDAT_HARNESS_CONTEXT_TOKENS:-$(( ${HARNESS_CONTEXT_TOKENS_LIGHT:-400000} - ${HARNESS_OUTPUT_TOKENS_LIGHT:-0} ))}"
	;;
	normal)
		harnessModel="$HARNESS_MODEL_MAIN"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
		harnessOutputTokens="${HARNESS_OUTPUT_TOKENS_MAIN:-}"
		harnessContextTokens="${MDAT_HARNESS_CONTEXT_TOKENS:-$(( ${HARNESS_CONTEXT_TOKENS_MAIN:-400000} - ${HARNESS_OUTPUT_TOKENS_MAIN:-0} ))}"
	;;
	heavy)
		harnessModel="$HARNESS_MODEL_MAIN"
		harnessReasoningEffort="high"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
		harnessOutputTokens="${HARNESS_OUTPUT_TOKENS_MAIN:-}"
		harnessContextTokens="${MDAT_HARNESS_CONTEXT_TOKENS:-$(( ${HARNESS_CONTEXT_TOKENS_MAIN:-400000} - ${HARNESS_OUTPUT_TOKENS_MAIN:-0} ))}"
	;;
esac

## A tool call reaches no endpoint and is not metered, so --intern-tool needs neither.
if [ -z "$harnessToolOnly" ] ; then
	if [ -z "$harnessToken" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no credential -- $harnessCredentialNames must be set in this process's own environment. This leg reads those names itself, exactly as claude reads ANTHROPIC_API_KEY" >&2
		exit 1
	fi
	## What this run costs, said once: the tier picked the model, and the model is metered.
	printf '%s\n' "🤖 ${harnessDim}$harnessProviderName${harnessOff} ${harnessTool}$harnessModel${harnessOff} ${harnessDim}· $harnessTier tier${harnessOff}" >&2
fi

## Roots are canonicalised by the same rule the candidate is, in one helper used by
## every append site: resolving one side only broke --access-root <symlink>.
AgentsHarnessResolveDir(){
	local resolveIn="$1" resolveOut
	resolveOut="$( cd "$resolveIn" 2>/dev/null && pwd -P )" || resolveOut=""
	[ -n "$resolveOut" ] || resolveOut="$resolveIn"
	printf '%s' "$resolveOut"
}

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
. "$harnessHere/AgentsTools.Grants.include"
harnessGateIndexed=""
## What a named member's file gate admits beside its permission index: what is known only
## at run time -- its children's input and output -- and its own member directory.
harnessRuntimeRoots=""
harnessRuntimeWriteRoots=""
harnessSandboxInReal=""
harnessSandboxOutReal=""
if [ "${#harnessAccessRoots[@]}" -eq 0 ] ; then
	harnessRootsInclude="$harnessHere/AgentsTools.ClientAccessRoots.include"
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
	. "$harnessHere/AgentsHarnessRootsIndex.include"
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
	[ -z "$harnessToolOnly" ] || printf 'ERROR: no access roots resolved, so nothing was done -- sh-lib/AgentsTools.ClientAccessRoots.include yielded an empty set; check MDAT_SKILLSET_ROOT, HOME and MMDAPP in the MCP server environment\n'
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-write-root for a root it may both read and write, or --access-read-root for one it may only read. With no flag at all the set comes from sh-lib/AgentsTools.ClientAccessRoots.include, so an empty set means that mechanism yielded nothing -- check MDAT_SKILLSET_ROOT and MMDAPP." >&2
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

## The spawn's own sandbox is added here, after the write set is final.
## The spawn op hands over the sandbox already resolved, as MDAT_SPAWN_SANDBOX_ROOT_REAL.
## It is taken only where it is provably the same directory and its input/ and output/
## are real directories under it, not links -- then `cd && pwd -P` would yield exactly
## those names; otherwise each is resolved here, as always.
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
	if [ -n "${MDAT_SPAWN_SANDBOX_ROOT_REAL:-}" ] && [ "${MDAT_SPAWN_SANDBOX_ROOT_REAL#/}" != "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ "$MDAT_SPAWN_SANDBOX_ROOT" -ef "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] ; then
		harnessSandboxInReal="$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" harnessSandboxOutReal="$MDAT_SPAWN_SANDBOX_ROOT_REAL/output"
	else
		harnessSandboxInReal="$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/input" )" harnessSandboxOutReal="$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/output" )"
	fi
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
			for harnessChildRecord in "$MMDAPP"/.local/agents/spawned/*/*.md ; do
				case $'\n'"$harnessChildNames" in
					*$'\n'"${harnessChildRecord#"$MMDAPP/.local/agents/spawned/"}"$'\n'*) harnessChildFiles+=( "$harnessChildRecord" ) ;;
				esac
			done
			[ "${#harnessChildFiles[@]}" -eq 0 ] || harnessChildRecords="$( LC_ALL=C grep -l -x -F "parent-spawn-id: $harnessParentKey" "${harnessChildFiles[@]}" 2>/dev/null )" || harnessChildRecords=""
		fi
	else
		harnessChildRecords="$( LC_ALL=C grep -l -x -F "parent-spawn-id: $harnessParentKey" "$MMDAPP"/.local/agents/spawned/*/*.md 2>/dev/null )" || harnessChildRecords=""
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

## Claude Code saves a tool result too large to return under its own session folder, outside
## every workspace root -- member folders live inside the workspace only, so no grant reaches
## there. AgentsHarnessDeniedHint below names the real fix on that one refusal: reread the
## original tool with a narrower offset/limit.

harnessScratchBase="${TMPDIR:-/tmp}"
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] && mkdir -p "$MDAT_SPAWN_SANDBOX_ROOT/tmp" 2>/dev/null ; then
	harnessScratchBase="$MDAT_SPAWN_SANDBOX_ROOT/tmp"
fi
harnessScratch="$( mktemp -d "$harnessScratchBase/AgentsUniversalHarness.XXXXXX" )" || {
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: could not create a scratch directory" >&2
	exit 1
}
## One cleanup, in one place, and deliberately no INT/TERM handler beside it. Bash runs
## neither a trap nor an untrapped signal's own termination until the foreground command
## it was waiting on has been reaped, so the stream pipeline is already gone by the time
## this runs -- measured: a handler that removes this directory and then holds the run
## open two seconds longer draws not one write out of the consumer, where removing it
## from under a live consumer draws a page of them. A `wait` here would have nothing to
## return on, a pipeline being no asynchronous job, so it narrows no window; and an
## `exit 130` from a handler would report a normal exit where dying by the signal is
## what tells a caller this run was interrupted. INT and TERM are ignored before the
## removal, and SIG_IGN survives the fork into `rm`, so a second Ctrl+C landing
## mid-removal cannot leave this directory half-gone.
## Bash hands an asynchronous child SIG_IGN for INT, so a terminal Ctrl+C never reaches
## anything started with `&` here and it outlives the run -- measured: a `sleep 30`
## still running after the harness had exited 130. Nothing a signal handler can reach,
## because by then this shell is gone and those processes are not its children any
## more. So each one records its pid as it starts and is signalled from the one
## cleanup, before the directory holding the record is removed.
AgentsHarnessReapChildren(){
	local reapFile reapPid
	for reapFile in "$harnessScratch"/*.pid ; do
		[ -f "$reapFile" ] || continue
		read -r reapPid < "$reapFile" || continue
		case "$reapPid" in ''|*[!0-9]*) continue ;; esac
		kill -TERM "$reapPid" 2>/dev/null || :
	done
}

## The status the run exits with is kept through the cleanup, so a failure never leaves as
## 0. Under set -e, bash 3.2 hands this trap $?=0 on a syntax error, so a 0 counts only
## when the run reached one of its own two successful exits, which set harnessExitClean.
harnessExitClean=""
trap 'harnessExitStatus=$? ; [ "$harnessExitStatus" != 0 ] || [ -n "$harnessExitClean" ] || harnessExitStatus=2 ; trap "" INT TERM ; AgentsHarnessRestoreTerminal ; AgentsHarnessReapChildren ; rm -rf -- "$harnessScratch" ; exit "$harnessExitStatus"' EXIT

## Monitor handles number from here rather than from a pid, so a handle stays readable
## in a transcript and cannot be reused by the system for something else.
harnessMonitorCount=0

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

## Absolute paths only, no `..` segment, resolved to their real location and then
## prefix-matched against the resolved roots. A final symlink component that exists
## is followed to its target and judged there; a dangling or cyclic one is judged as given.
AgentsHarnessPathAllowed(){
	local checkPath="$1" checkRoots="${2:-$harnessRoots}" checkRoot checkReal checkLinkDir
	harnessResolvedPath=""
	case "$checkPath" in
		/*) ;;
		*) return 1 ;;
	esac
	case "/$checkPath/" in
		*/../*|*/./*) return 1 ;;
	esac
	## `cd ... && pwd -P` is the portable resolver: neither macOS nor FreeBSD base
	## carries `readlink -f` or `realpath`.
	if [ -d "$checkPath" ] ; then
		checkReal="$( cd "$checkPath" 2>/dev/null && pwd -P )" || checkReal=""
	else
		checkLinkDir="${checkPath%/*}"
		[ -n "$checkLinkDir" ] || checkLinkDir="/"
		checkReal="$( cd "$checkLinkDir" 2>/dev/null && pwd -P )" || checkReal=""
		if [ -n "$checkReal" ] ; then
			case "$checkReal" in
				*/) checkReal="$checkReal${checkPath##*/}" ;;
				*)  checkReal="$checkReal/${checkPath##*/}" ;;
			esac
		fi
	fi
	## An unresolvable path is compared as given rather than admitted by default.
	[ -n "$checkReal" ] || checkReal="$checkPath"
	local checkHops=0 checkLink
	while [ -L "$checkReal" ] && [ -e "$checkReal" ] ; do
		checkHops=$(( checkHops + 1 ))
		[ "$checkHops" -le 40 ] || return 1
		checkLink="$( readlink "$checkReal" 2>/dev/null )" || return 1
		[ -n "$checkLink" ] || return 1
		case "$checkLink" in
			/*) ;;
			*) checkLink="${checkReal%/*}/$checkLink" ;;
		esac
		checkLinkDir="${checkLink%/*}"
		[ -n "$checkLinkDir" ] || checkLinkDir="/"
		checkReal="$( cd "$checkLinkDir" 2>/dev/null && pwd -P )" || return 1
		case "$checkReal" in
			*/) checkReal="$checkReal${checkLink##*/}" ;;
			*)  checkReal="$checkReal/${checkLink##*/}" ;;
		esac
	done
	## Published so every tool operates on this rather than the spelling the model typed.
	harnessResolvedPath="$checkReal"
	while IFS= read -r checkRoot ; do
		[ -n "$checkRoot" ] || continue
		case "$checkReal" in
			"$checkRoot"|"$checkRoot"/*) return 0 ;;
		esac
	done <<< "$checkRoots"
	return 1
}

## Appended to the generic access-root refusal for one path shape: Claude Code's own
## oversized-tool-result dump under ~/.claude/projects, which carries no grant (see the
## removed tool-results loop above). Empty for every other denied path, so the generic
## message there stays exactly as it was.
##   $1 = the path that was denied
AgentsHarnessDeniedHint(){
	case "$1" in
		"$HOME"/.claude/projects/*/*/tool-results/*)
			printf -- ' -- this looks like a saved oversized tool result; reread the original tool with a narrower offset/limit instead'
		;;
	esac
}

## Unattended unless a person is known to be there: this harness's own model loop always
## is; a served call is attended only from an interactive Claude Code client (its
## CLAUDE_CODE_ENTRYPOINT is cli or claude-vscode) with no unattended marker and no spawn
## id. An unset or unknown entrypoint is unattended, so a new surface fails closed.
AgentsHarnessUnattended(){
	[ -n "$harnessToolOnly" ] || return 0
	[ "${MDAT_SESSION_UNATTENDED:-}" != "true" ] || return 0
	[ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || return 0
	case "${CLAUDE_CODE_ENTRYPOINT:-}" in
		cli|claude-vscode) return 1 ;;
	esac
	return 0
}

## The team stores an unattended session never writes with Write or Edit, whatever its roots grant.
AgentsHarnessWriteExcluded(){ ## resolved path
	local excludeRoot excludeReal
	AgentsHarnessUnattended || return 1
	for excludeRoot in "${MDAT_DATA_ROOT:-}" "${MMDAPP:+$MMDAPP/.local/agents/sessions}" ; do
		[ -n "$excludeRoot" ] || continue
		excludeReal="$( cd "$excludeRoot" 2>/dev/null && pwd -P )" || excludeReal="$excludeRoot"
		case "$1" in
			"$excludeReal"|"$excludeReal"/*|"$excludeRoot"|"$excludeRoot"/*) return 0 ;;
		esac
	done
	return 1
}

## The session this call belongs to: the harness's own, a spawn's, or the Claude Code client's.
AgentsHarnessSessionKey(){
	printf '%s' "${harnessSessionId:-${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}}"
}

## Records the session's own last post from a send's reported fields, for the Wait floor
## fallback (AgentsTools.MemberWait.include reads sessions/<id>/last-own-post).
AgentsHarnessOwnPostRecord(){ ## send output file
	local ownSession ownChannel ownTs ownThread
	ownSession="$( AgentsHarnessSessionKey )"
	[ -n "$ownSession" ] && [ -n "${MMDAPP:-}" ] && AgentsHarnessBareName "$ownSession" || return 0
	ownChannel="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_CHANNEL=//p' "$1" | head -1 )"
	ownTs="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' "$1" | head -1 )"
	ownThread="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_THREAD_TS=//p' "$1" | head -1 )"
	AgentsHarnessBareName "$ownChannel" && AgentsHarnessBareName "$ownTs" || return 0
	[ -z "$ownThread" ] || AgentsHarnessBareName "$ownThread" || return 0
	mkdir -p "$MMDAPP/.local/agents/sessions/$ownSession" 2>/dev/null \
		&& printf '%s:%s %s\n' "$ownChannel" "${ownThread:-$ownTs}" "$ownTs" > "$MMDAPP/.local/agents/sessions/$ownSession/last-own-post" 2>/dev/null || :
	return 0
}

## A granted call for this session, tool and resolved target; an Allow once is used up here.
## Not granted, the asks still open that would allow the call (`OPEN-ASK:` lines of the read)
## are kept for the refusal of this very call, as `<id> <kind> <who it waits on>` lines, with
## the call they are for: AgentsHarnessRefusal says them, and only for that same call.
harnessGrantOpen=""
harnessGrantOpenFor=""
## And what granted it, as the read says it (`standing floor`, `task <item>`, ...), for the gate.
harnessGrantLayer=""
AgentsHarnessGranted(){ ## tool, resolved target
	local grantTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" grantSession grantLine
	harnessGrantOpen="" ; harnessGrantOpenFor="" ; harnessGrantLayer=""
	grantSession="$( AgentsHarnessSessionKey )"
	[ -n "$2" ] && [ -n "$grantSession" ] && [ -n "$harnessAgent" ] && [ -x "$grantTools" ] || return 1
	if ! "$BASH" "$grantTools" --intern-op-permission-grant-read "$harnessAgent" --session-id "$grantSession" --tool "$1" --target "$2" \
		> "$harnessScratch/grant.out" 2> /dev/null ; then
		harnessGrantOpen="$( LC_ALL=C awk '$1 == "OPEN-ASK:" && $2 != "" { print $2, $3, $4 ; }' "$harnessScratch/grant.out" 2> /dev/null )" || harnessGrantOpen=""
		[ -z "$harnessGrantOpen" ] || harnessGrantOpenFor="$1"$'\t'"$2"
		return 1
	fi
	grantLine="$( LC_ALL=C sed -n 's/^GRANT: //p' "$harnessScratch/grant.out" | head -1 )"
	harnessGrantLayer="$grantLine"
	case "$grantLine" in
		'session '*|'task '*|'planned '*|'standing '*) return 0 ;;
		'once '*)
			"$BASH" "$grantTools" --intern-op-permission-grant-consume --session-id "$grantSession" --refusal-id "${grantLine#once }" \
				> /dev/null 2>&1 || return 1
			return 0
		;;
	esac
	return 1
}

## A gated refusal: the original ERROR line first and unchanged, then the recorded
## refusal id and how to ask for the call. Recording never changes the outcome.
AgentsHarnessRefusal(){ ## tool, target, error line
	local refusalTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" refusalId="" refusalSession
	## The open asks the grant read of this very call named, taken once: a refusal whose call
	## no grant read ran for, or ran for another call, says none.
	local refusalOpen="" refusalAsk refusalKind refusalWho
	[ "$harnessGrantOpenFor" != "$1"$'\t'"$2" ] || refusalOpen="$harnessGrantOpen"
	harnessGrantOpen="" ; harnessGrantOpenFor=""
	printf '%s\n' "$3"
	refusalSession="$( AgentsHarnessSessionKey )"
	if [ -z "$refusalSession" ] || [ -z "$harnessAgent" ] || [ ! -x "$refusalTools" ] ; then
		printf 'REFUSAL-ID: none -- this session has no session id or team identity, so the refusal was not recorded and cannot be escalated by id.\n'
		return 0
	fi
	"$BASH" "$refusalTools" --intern-op-permission-refusal-log "$harnessAgent" --session-id "$refusalSession" --tool "$1" --target "$2" \
		--reason "$3" > "$harnessScratch/refusal.out" 2> "$harnessScratch/refusal.err" || :
	refusalId="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$harnessScratch/refusal.out" | head -1 )"
	if [ -z "$refusalId" ] ; then
		printf 'REFUSAL-ID: none -- recording the refusal failed, so it cannot be escalated by id. What the operation reported follows:\n'
		cat "$harnessScratch/refusal.err" 2>/dev/null
		return 0
	fi
	printf 'REFUSAL-ID: %s\n' "$refusalId"
	## An ask that would allow this call is already open: said ahead of the way to ask, so the
	## member waits for its answer and asks nothing again.
	if [ -n "$refusalOpen" ] ; then
		while read -r refusalAsk refusalKind refusalWho ; do
			[ -n "$refusalAsk" ] || continue
			printf 'An ask that would allow this call is already open: %s (a %s, waiting on %s). Do not ask again: wait for its answer with Wait sources=ask:%s, then retry the call.\n' \
				"$refusalAsk" "${refusalKind:-question}" "${refusalWho:-its addressee}" "$refusalAsk"
		done <<< "$refusalOpen"
	fi
	## What it is, and how to ask for it: the lines the refusal record's own operation gave
	## after the id (AgentsToolsPermissionRefusalHint, AgentsTools.InternOpPermission.include),
	## as they are, so this gate and a native client's hook say the same words.
	LC_ALL=C sed -n 's/^HINT: //p' "$harnessScratch/refusal.out" 2> /dev/null || :
	LC_ALL=C grep '⚠️' "$harnessScratch/refusal.err" 2>/dev/null || :
}

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
AgentsHarnessFileGate(){ ## tool, path, read|write
	local gateRoots gateRootsOk=1 gateRc=0 gateSession gateOwn
	if [ -z "$harnessGateIndexed" ] ; then
		gateRoots="$harnessRoots" ; [ "$3" = read ] || gateRoots="$harnessWriteRoots"
		AgentsHarnessPathAllowed "$2" "$gateRoots" && return 0
	else
		gateRoots="$harnessRuntimeRoots" ; [ "$3" = read ] || gateRoots="$harnessRuntimeWriteRoots"
		## Never empty: the check reads an empty set as the whole read set.
		AgentsHarnessPathAllowed "$2" "${gateRoots:-$'\n'}" && gateRootsOk=0
		if [ -n "$harnessResolvedPath" ] && [ -n "${MMDAPP:-}" ] ; then
			gateSession="${harnessSessionId:-${MDAT_SPAWN_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}}"
			gateOwn="$MMDAPP/.local/agents/sessions/$gateSession"
			if AgentsToolsGrantsSessionEnsure "$MMDAPP" "$harnessGrantMember" "$gateSession" "$harnessSandboxInReal" "$harnessSandboxOutReal" "$harnessGateOrigin" ; then
				AgentsToolsGrantsSessionCheck "$1" "$harnessResolvedPath" "$gateOwn" || gateRc=$?
				case "$gateRc" in
					0)
						## An Allow once is used up here, by the one lock its store keeps.
						[ -n "$agentsGrantsCheckOnce" ] || return 0
						"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-consume \
							--session-id "$gateSession" --refusal-id "$agentsGrantsCheckOnce" > /dev/null 2>&1 && return 0
					;;
					3)
						if [ -n "$harnessSandboxOutReal" ] ; then
							printf 'ERROR: %s is a read-only place, so nothing is written there: %s -- write to your session sandbox output/ instead, or a folder under it: %s/\n' "$agentsGrantsCheckPlace" "$2" "$harnessSandboxOutReal"
						else
							printf 'ERROR: %s is a read-only place, so nothing is written there: %s -- find another suitable location\n' "$agentsGrantsCheckPlace" "$2"
						fi
						return 1
					;;
				esac
			fi
		fi
		[ "$gateRootsOk" != 0 ] || [ "$gateRc" = 4 ] || return 0
	fi
	if AgentsHarnessGranted "$1" "$harnessResolvedPath" ; then
		[ "$gateRc" = 4 ] || return 0
		case "$harnessGrantLayer" in 'standing floor'*|'standing standing'*) ;; *) return 0 ;; esac
	fi
	[ "$gateRc" != 4 ] || return 4
	return 2
}

## The gate of every tool that reads by path, Read (a PDF and a notebook included), Glob and
## Grep, in the write gate's own shape (AgentsHarnessFileGate), and then granted this member by
## the one decision function the write gate and the native hook ask (AgentsHarnessGranted:
## floor, its own standing rows, routine, session, task, planned, an unexpired once).
## Anything else is a recorded refusal, printed here, and rc 1. Publishes
## $harnessResolvedPath, as the check does.
AgentsHarnessReadGate(){ ## tool, path
	local readGateRc=0
	AgentsHarnessFileGate "$1" "$2" read || readGateRc=$?
	case "$readGateRc" in
		0) return 0 ;;
		1) return 1 ;;
	esac
	AgentsHarnessRefusal "$1" "${harnessResolvedPath:-$2}" "ERROR: path not in the allowed access-root set: $2$( AgentsHarnessDeniedHint "$2" )"
	return 1
}

## Digits only, by explicit enumeration: a bracket range is collation-dependent.
AgentsHarnessWholeNumber(){
	local scanRest="$1" scanChar
	[ -n "$scanRest" ] || return 1
	while [ -n "$scanRest" ] ; do
		scanChar="${scanRest%"${scanRest#?}"}"
		scanRest="${scanRest#?}"
		case "$scanChar" in
			0|1|2|3|4|5|6|7|8|9) ;;
			*) return 1 ;;
		esac
	done
}

## A line range is the only way past the byte cap, so it states what it showed. Read and
## Skill both take one; Read passes numbered, for cat -n lines, and Skill does not.
AgentsHarnessReadRange(){ ## path, offset, limit, optional numbered
	local rangeOffset="${2:-1}" rangeLimit="$3"
	if ! AgentsHarnessWholeNumber "$rangeOffset" || [ "$rangeOffset" -lt 1 ] ; then
		printf 'ERROR: offset must be a whole line number counting from 1, got: %s\n' "$rangeOffset" ; return 0
	fi
	if [ -n "$rangeLimit" ] && { ! AgentsHarnessWholeNumber "$rangeLimit" || [ "$rangeLimit" -lt 1 ] ; } ; then
		printf 'ERROR: limit must be a whole number of lines, at least 1, got: %s\n' "$rangeLimit" ; return 0
	fi
	## Digits by the checks above and the mode a literal, so there is nothing here for -v to backslash-decode.
	LC_ALL=C awk -v fromLine="$rangeOffset" -v lineLimit="${rangeLimit:-0}" -v byteCap="$harnessReadCap" -v numberLines="$4" -v restHint="$5" -f "$harnessHere/AgentsHarnessReadRange.awk" "$1"
}

AgentsHarnessToolRead(){
	local toolPath="${5:-$1}" toolOffset="$2" toolLimit="$3" toolPages="$4" toolBytes toolMime pdfFirst pdfLast pdfText imagePath imageEdge
	if [ -z "$toolPath" ] ; then
		printf 'ERROR: file_path is required and was empty. Nothing was read.\n' ; return 0
	fi
	AgentsHarnessReadGate Read "$toolPath" || return 0
	toolPath="$harnessResolvedPath"
	if [ -d "$toolPath" ] ; then
		printf 'ERROR: is a directory, not a file: %s\n' "$toolPath" ; return 0
	fi
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	## Existence is not readability, and the two are refused separately: without this
	## the size test below compares an empty value and emits shell noise, not an answer.
	if [ ! -r "$toolPath" ] ; then
		printf 'ERROR: not readable (permission denied): %s\n' "$toolPath" ; return 0
	fi
	## pages is a PDF argument alone, so anywhere else it is refused rather than ignored.
	if [ -n "$toolPages" ] ; then
		case "$toolPath" in
			*.[pP][dD][fF]) ;;
			*) printf 'ERROR: pages applies to PDF files only: %s\n' "$toolPath" ; return 0 ;;
		esac
	fi
	if [ ! -s "$toolPath" ] ; then
		printf 'The file exists but is empty: %s\n' "$toolPath" ; return 0
	fi
	case "$toolPath" in
		*.[pP][dD][fF])
			## N or N-M, at most 20 pages. Without pages the first 11 are read, only to prove there are no more than 10.
			pdfFirst="${toolPages%%-*}" ; pdfLast="${toolPages#*-}"
			[ -n "$toolPages" ] || { pdfFirst=1 ; pdfLast=11 ; }
			if ! AgentsHarnessWholeNumber "$pdfFirst" || ! AgentsHarnessWholeNumber "$pdfLast" || [ "$pdfFirst" -lt 1 ] || [ "$pdfLast" -lt "$pdfFirst" ] || [ $(( 10#$pdfLast - 10#$pdfFirst )) -ge 20 ] ; then
				printf 'ERROR: pages must be one page number or a range such as 1-5, counting from 1, at most 20 pages per request, got: %s\n' "$toolPages" ; return 0
			fi
			## Pages each ended by a form feed, from PDFKit on macOS or pdftotext elsewhere.
			if command -v osascript >/dev/null 2>&1 ; then
				pdfText="$( osascript -l JavaScript -e 'ObjC.import("PDFKit"); function run(argv) { var pdfDoc = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0])); if (pdfDoc.isNil()) return "ERROR: not a readable PDF: " + argv[0]; var pageTotal = pdfDoc.pageCount, pageTexts = []; if (Number(argv[1]) > pageTotal) return "ERROR: pages start past the end of this PDF, which has " + pageTotal + " pages: " + argv[0]; for (var pageNo = Number(argv[1]); pageNo <= Math.min(Number(argv[2]), pageTotal); pageNo++) pageTexts.push(ObjC.unwrap(pdfDoc.pageAtIndex(pageNo - 1).string) || ""); return pageTexts.join("\f") + "\f"; }' "$toolPath" "$pdfFirst" "$pdfLast" 2>/dev/null )" || pdfText="ERROR: PDFKit could not read this PDF: $toolPath"
			elif command -v pdftotext >/dev/null 2>&1 ; then
				pdfText="$( pdftotext -f "$pdfFirst" -l "$pdfLast" "$toolPath" - 2>/dev/null )" || pdfText="ERROR: pdftotext could not read pages $pdfFirst-$pdfLast of this PDF -- past its last page, or not a readable PDF: $toolPath"
			else
				pdfText="ERROR: no PDF reader on this host -- neither osascript nor pdftotext is available: $toolPath"
			fi
			case "$pdfText" in
				ERROR:*) printf '%s\n' "$pdfText" ; return 0 ;;
			esac
			## One record per page; validated above, so nothing here for -v to decode.
			printf '%s' "$pdfText" | LC_ALL=C awk -v RS='\f' -v firstPage="$pdfFirst" -v pagesAsked="$toolPages" -v byteCap="$harnessReadCap" -f "$harnessHere/AgentsHarnessPdfPageRead.awk"
			return 0
		;;
		*.[iI][pP][yY][nN][bB])
			## jq, not python3: nested JSON, and jq ships in the macOS base where python3 is a stub.
			pdfText="$( jq -r 'def flat: if type == "array" then join("") else . end ; .cells | to_entries[] | "--- cell \(.key + 1): \(.value.cell_type // "unknown") ---", (.value.source // "" | flat), (.value.outputs // [] | .[] | "--- output: \(.output_type // "unknown") ---", (if .text then (.text | flat) elif .data["text/plain"] then (.data["text/plain"] | flat) else (.traceback // [] | join("\n")) end), (.data // {} | keys[] | select(startswith("image/")) | "[image output: \(.), not shown]"))' "$toolPath" 2>/dev/null )" || { printf 'ERROR: could not render this notebook -- not notebook JSON, or no jq on this host: %s\n' "$toolPath" ; return 0 ; }
			printf '%s\n' "$pdfText" | LC_ALL=C awk -v byteCap="$harnessReadCap" '{ shownBytes = shownBytes + length($0) + 1 ; if ( shownBytes > byteCap ) { print "... TRUNCATED: the rest of this notebook is over the " byteCap "-byte cap of this reader ..." ; exit ; } print ; }'
			return 0
		;;
	esac
	## An image goes back as its own content part through the side file the served path passes; stdout carries text only.
	case "$toolPath" in
		*.[pP][nN][gG]|*.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[gG][iI][fF]|*.[wW][eE][bB][pP]) toolMime="$( file --mime-type -b "$toolPath" 2>/dev/null )" || toolMime="" ;;
	esac
	case "$toolMime" in
		image/png|image/jpeg|image/gif|image/webp)
			if [ -z "${harnessImageFile:-}" ] ; then
				printf 'Image file (%s): it cannot be shown on this path, only through the served Read tool: %s\n' "$toolMime" "$toolPath" ; return 0
			fi
			imagePath="$toolPath"
			toolBytes="$( wc -c < "$toolPath" | tr -d ' ' )"
			## Shrunk only when over budget; sips -Z enlarges as readily as it shrinks, so the edge only halves from the real one.
			if [ $(( ( toolBytes + 2 ) / 3 * 4 )) -gt "$harnessReadCap" ] && command -v sips >/dev/null 2>&1 ; then
				imageEdge="$( sips -g pixelWidth -g pixelHeight "$toolPath" 2>/dev/null | LC_ALL=C awk '( $1 == "pixelWidth:" || $1 == "pixelHeight:" ) && $2 + 0 > edgeMax { edgeMax = $2 + 0 ; } END { print edgeMax + 0 ; }' )"
				while [ $(( ( toolBytes + 2 ) / 3 * 4 )) -gt "$harnessReadCap" ] && [ "$imageEdge" -gt 1 ] ; do
					imageEdge=$(( imageEdge / 2 ))
					sips -Z "$imageEdge" "$toolPath" --out "$harnessScratch/read.image" >/dev/null 2>&1 || break
					imagePath="$harnessScratch/read.image"
					toolBytes="$( wc -c < "$imagePath" | tr -d ' ' )"
				done
			fi
			if [ $(( ( toolBytes + 2 ) / 3 * 4 )) -gt "$harnessReadCap" ] ; then
				printf 'ERROR: image is %s bytes, over the %s-byte budget this reader can return once encoded: %s\n' "$toolBytes" "$harnessReadCap" "$toolPath" ; return 0
			fi
			if ! { printf '%s\t' "$toolMime" ; base64 < "$imagePath" | LC_ALL=C tr -d '\n' ; } > "$harnessImageFile" ; then
				printf 'ERROR: could not stage the image for return: %s\n' "$toolPath" ; return 0
			fi
			printf 'Image %s, %s bytes, returned as an image part: %s\n' "$toolMime" "$toolBytes" "$toolPath"
			return 0
		;;
	esac
	if [ -n "$toolOffset" ] || [ -n "$toolLimit" ] ; then
		AgentsHarnessReadRange "$toolPath" "$toolOffset" "${toolLimit:-2000}" numbered
		return 0
	fi
	## Capped and said so, never silently: an unbounded read risks the request itself.
	## Measured as numbered, since that is what goes back: a file under the cap can be over it once numbered.
	toolBytes="$( LC_ALL=C awk -v byteCap="$harnessReadCap" '{ numberedBytes = numberedBytes + length(sprintf("%6d", NR)) + length($0) + 2 ; if ( NR > 2000 ) numberedBytes = byteCap + 1 ; if ( numberedBytes > byteCap ) exit ; } END { print numberedBytes + 0 ; }' "$toolPath" )"
	if [ "$toolBytes" -gt "$harnessReadCap" ] ; then
		AgentsHarnessReadRange "$toolPath" 1 2000 numbered
	else
		LC_ALL=C awk '{ printf "%6d\t%s\n", NR, $0 ; }' "$toolPath"
	fi
}

## One writer per target at a time, through the package's one local lock primitive
## (sh-lib/AgentsTools.LocalLock.include), keyed by the cksum of the resolved path.
AgentsHarnessLockTake(){ ## resolved target
	local lockKey
	lockKey="$( printf '%s' "$1" | LC_ALL=C cksum | LC_ALL=C tr ' ' '-' )" || return 1
	AgentsToolsLocalLockTake "$lockKey" 30 "$1"
}

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

## One value of the kept change this call applies, from its own `change` file, or empty.
AgentsHarnessChangeKept(){ ## key
	local keptLine
	[ -f "$harnessChangeApply/change" ] || return 0
	while IFS= read -r keptLine ; do
		case "$keptLine" in "$1: "*) printf '%s' "${keptLine#"$1: "}" ; return 0 ;; esac
	done < "$harnessChangeApply/change"
}

## What the edit of one position matched when the change this call applies was shown.
AgentsHarnessChangeMatched(){ ## position, from 0
	local matchedList matchedAt=0 matchedOne
	matchedList="$( AgentsHarnessChangeKept matched )"
	for matchedOne in $matchedList ; do
		[ "$matchedAt" != "$1" ] || { printf '%s' "$matchedOne" ; return 0 ; }
		matchedAt=$(( matchedAt + 1 ))
	done
}

## What a write tool does with its gate's answer in those two ways. rc 0: go on -- to apply, or
## for rc 4 to hold. rc 1: the call ends here, and what it comes to is already printed.
## A call that applies a kept change is that change and no other: of this session, this tool
## and this file, its approval noted on its prompt's record by the operation that read it.
AgentsHarnessChangeMode(){ ## tool, the gate's answer
	local modeAsk
	if [ -n "$harnessChangeApply" ] ; then
		modeAsk="$( AgentsHarnessChangeKept ask )"
		if [ "$harnessChangeApply" != "$MMDAPP/.local/agents/sessions/$( AgentsHarnessSessionKey )/changes/${harnessChangeApply##*/}" ] \
			|| [ "$( AgentsHarnessChangeKept tool )" != "$1" ] || ! AgentsHarnessBareName "$modeAsk" \
			|| ! LC_ALL=C grep -q -x -F 'verdict: approve' "$MMDAPP/.local/agents/pending/$modeAsk.answered/verdict" 2>/dev/null ; then
			printf 'ERROR: %s: this call names a kept change to apply, and it is not that change of this session with its approval noted, so nothing was written\n' "$1"
			return 1
		fi
		case "$2" in
			0|4)
				[ "$( AgentsHarnessChangeKept file )" = "$harnessResolvedPath" ] && return 0
				printf 'ERROR: %s: this call names a kept change to apply, and that change is of another file, so nothing was written\n' "$1"
			;;
			1) printf 'STALE: the place of %s is read-only now, so nothing was written\n' "$( AgentsHarnessChangeKept file )" ;;
			*) printf 'STALE: your access no longer covers %s, so nothing was written\n' "$( AgentsHarnessChangeKept file )" ;;
		esac
		return 1
	fi
	[ -n "$harnessChangeHoldOnly" ] || return 0
	case "$2" in
		4) : > "$harnessChangeHoldOnly" 2>/dev/null || : ; return 0 ;;
		0) printf 'NOT-HELD: allowed\n' ;;
		1) ;;
		*) printf 'NOT-HELD: refused\n' ;;
	esac
	return 1
}

## Whether the file a kept Write was shown against is the file as it stands: the same bytes,
## or still no file where there was none.
AgentsHarnessChangeBaseSame(){ ## resolved target
	if [ -f "$harnessChangeApply/base" ] ; then
		cmp -s "$harnessChangeApply/base" "$1"
	else
		[ ! -e "$1" ]
	fi
}

## One call held: its change kept, shown to the human-owner and recorded as an ask of this
## session, by the team operation that owns all three (--intern-op-change-hold). Prints what
## the call comes to: HELD, with its wait item, which is how the member hears the verdict; OK
## where the call leaves the file as it is, so there is nothing to hold; or the ERROR that
## says nothing is held, and why. The member is never kept waiting here.
AgentsHarnessChangeHold(){ ## tool, resolved target, the file as it stands (empty: there is none), the file as the call leaves it, raw arguments, what each edit matched (Edit)
	local holdTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" holdSession holdOut="" holdRc=0 holdId holdShown holdCut=""
	holdSession="$( AgentsHarnessSessionKey )"
	if [ -z "$holdSession" ] || [ -z "$harnessAgent" ] || [ ! -x "$holdTools" ] ; then
		printf 'ERROR: %s: a change to %s needs the approval of the human-owner, and this session has no session id or team identity to hold it under, so nothing is held and nothing was written\n' "$1" "$2"
		return 0
	fi
	if ! printf '%s' "$5" > "$harnessScratch/change.call" ; then
		printf 'ERROR: %s: the change to %s could not be kept to hold it, so nothing is held and nothing was written\n' "$1" "$2"
		return 0
	fi
	holdOut="$( "$BASH" "$holdTools" --intern-op-change-hold "$harnessAgent" --session-id "$holdSession" --tool "$1" --file "$2" ${3:+--base "$3"} --result "$4" \
		--call "$harnessScratch/change.call" ${6:+--matched "$6"} 2> "$harnessScratch/change.err" )" || holdRc=$?
	if [ "$holdRc" = "0" ] && [ "$holdOut" = "NOCHANGE" ] ; then
		printf 'OK: nothing is held or written: this call leaves %s exactly as it is\n' "$2"
		return 0
	fi
	holdId="$( printf '%s\n' "$holdOut" | LC_ALL=C sed -n 's/^HELD \([0-9a-f-]*\)$/\1/p' | head -1 )"
	if [ "$holdRc" != "0" ] || [ -z "$holdId" ] ; then
		printf 'ERROR: %s: a change to %s needs the approval of the human-owner, and it could not be shown to him, so it is NOT held and nothing was written. Make the call again once what stopped it is cleared. What the operation reported follows:\n' "$1" "$2"
		cat "$harnessScratch/change.err" 2>/dev/null
		return 0
	fi
	holdShown="$( printf '%s\n' "$holdOut" | LC_ALL=C sed -n 's/^SHOWN \([0-9]* [0-9]*\)$/\1/p' | head -1 )"
	[ -z "$holdShown" ] || [ "${holdShown%% *}" = "${holdShown##* }" ] || holdCut=", the first ${holdShown%% *} of its ${holdShown##* } lines"
	printf 'HELD: this change to %s is held for the approval of the human-owner, and nothing is written yet. It is shown to him as a diff%s, and is applied exactly as shown when he approves.\n' "$2" "$holdCut"
	printf 'The file stays as it is until then: a Read of it shows the file as it is now, without this change.\n'
	printf 'His verdict comes to you on Wait, as pending reply %s: approve, reject, or his own words, whole. Carry on with work that does not need this change. To take it back: AskQuestion pending_id=%s withdraw=<why>.\n' "$holdId" "$holdId"
	AgentsHarnessAskWaitNext "$holdId"
}

## Whole-file overwrite or create, never a partial patch; Edit is the partial path.
AgentsHarnessToolWrite(){
	local toolPath="${3:-$1}" toolContent="$2" toolTemp toolLock="" toolGateRc=0 toolHeld=""
	if [ -z "$toolPath" ] ; then
		AgentsHarnessRefusal Write "" "ERROR: no path was given -- pass file_path, or path. Keys received: $( printf '{"a":%s}' "$4" | LC_ALL=C awk -v path=a -v mode=keys -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null | LC_ALL=C awk 'BEGIN { keyList = "" ; } { keyList = keyList ( NR > 1 ? ", " : "" ) $0 ; } END { print ( keyList == "" ? "none" : keyList ) ; }' ). Nothing was written." ; return 0
	fi
	AgentsHarnessFileGate Write "$toolPath" write || toolGateRc=$?
	AgentsHarnessChangeMode Write "$toolGateRc" || return 0
	case "$toolGateRc" in
		1) return 0 ;;
		2) AgentsHarnessRefusal Write "${harnessResolvedPath:-$toolPath}" "ERROR: path not in the allowed write-root set -- it may still be readable: $toolPath" ; return 0 ;;
		4) [ -n "$harnessChangeApply" ] || toolHeld=1 ;;
	esac
	toolPath="$harnessResolvedPath"
	if AgentsHarnessWriteExcluded "$toolPath" ; then
		AgentsHarnessRefusal Write "$toolPath" "ERROR: path is in a team store that an unattended session never writes with Write or Edit -- use the team tooling operation for it: $toolPath" ; return 0
	fi
	## Held for approval: nothing is written. The change is kept and shown instead.
	if [ -n "$toolHeld" ] ; then
		if ! printf '%s' "$toolContent" > "$harnessScratch/change.result" || { [ -e "$toolPath" ] && ! cp "$toolPath" "$harnessScratch/change.base" 2>/dev/null ; } ; then
			printf 'ERROR: could not keep the change to hold it, so nothing is held and nothing was written: %s\n' "$toolPath" ; return 0
		fi
		AgentsHarnessChangeHold Write "$toolPath" "$( [ ! -e "$toolPath" ] || printf '%s' "$harnessScratch/change.base" )" "$harnessScratch/change.result" "$4" ""
		return 0
	fi
	mkdir -p "$( dirname -- "$toolPath" )" 2>/dev/null || {
		printf 'ERROR: could not create the parent directory of: %s\n' "$toolPath" ; return 0
	}
	if ! AgentsHarnessLockTake "$toolPath" ; then
		printf 'ERROR: could not take the write lock for %s -- another call is writing it, or the lock area is unusable -- so nothing was written. Retry.\n' "$toolPath" ; return 0
	fi
	toolLock="$agentsLocalLockPath"
	## A kept Write is applied only over the file it was shown against: it replaces the whole of it.
	if [ -n "$harnessChangeApply" ] && ! AgentsHarnessChangeBaseSame "$toolPath" ; then
		AgentsToolsLocalLockGive "$toolLock"
		printf 'STALE: %s has changed since this change was shown, and a Write replaces the whole file, so nothing was written\n' "$toolPath" ; return 0
	fi
	## Replaced by rename, never rewritten in place, so a reader sees the old file or the
	## new one and never half of it. `cp -p` first gives the temp the target's own mode.
	toolTemp="$( dirname -- "$toolPath" )/.$( basename -- "$toolPath" ).mdat-write.$$"
	if [ -e "$toolPath" ] && ! cp -p "$toolPath" "$toolTemp" 2>/dev/null ; then
		rm -f "$toolTemp" ; AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	if ! printf '%s' "$toolContent" > "$toolTemp" || ! mv -f "$toolTemp" "$toolPath" ; then
		rm -f "$toolTemp" ; AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	AgentsToolsLocalLockGive "$toolLock"
	printf 'OK: wrote %s\n' "$toolPath"
}

## Partial edit by exact literal replacement. It reads the whole file inside this
## process and returns only a one-line result, so it is the way to change a file too
## long for Read's cap. Uniqueness is required, not preferred: a silent
## first-of-several substitution is unrecoverable, and identical lines are the norm here.
## One call carries one edit, or a list of them in edits, and both are one list here:
## applied in order, each to the text the one before it left, and written once, all or
## nothing. An edit of a list that cannot be applied is named by its position from 1.
AgentsHarnessToolEdit(){
	local toolPath="${5:-$1}" toolOld="$2" toolNew="$3" toolAll="$4" toolCount toolTemp toolLock="" toolGateRc=0
	local editsListed="" editsCount=1 editsIndex=0 editsOld=() editsNew=() editsAll=() editsSource editsOut editsSpare editsWhere="" editsNote=""
	local toolHeld="" editsSeen=""
	if [ -z "$toolPath" ] ; then
		AgentsHarnessRefusal Edit "" "ERROR: no path was given -- pass file_path, or path. Keys received: $( printf '{"a":%s}' "$6" | LC_ALL=C awk -v path=a -v mode=keys -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null | LC_ALL=C awk 'BEGIN { keyList = "" ; } { keyList = keyList ( NR > 1 ? ", " : "" ) $0 ; } END { print ( keyList == "" ? "none" : keyList ) ; }' ). Nothing was written." ; return 0
	fi
	AgentsHarnessFileGate Edit "$toolPath" write || toolGateRc=$?
	AgentsHarnessChangeMode Edit "$toolGateRc" || return 0
	case "$toolGateRc" in
		1) return 0 ;;
		2) AgentsHarnessRefusal Edit "${harnessResolvedPath:-$toolPath}" "ERROR: path not in the allowed write-root set -- it may still be readable: $toolPath" ; return 0 ;;
		4) [ -n "$harnessChangeApply" ] || toolHeld=1 ;;
	esac
	toolPath="$harnessResolvedPath"
	if AgentsHarnessWriteExcluded "$toolPath" ; then
		AgentsHarnessRefusal Edit "$toolPath" "ERROR: path is in a team store that an unattended session never writes with Write or Edit -- use the team tooling operation for it: $toolPath" ; return 0
	fi
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	## Both forms are read into one list of edits: edits as the call gave it, or the single
	## form as a list of one that carries its own replace_all. A value in edits that is no
	## list is refused, never read as no edits.
	AgentsHarnessArgParse "$6"
	if AgentsHarnessArgFind edits.__count ; then
		editsListed=1
		editsCount="$harnessArgFound"
		## One form per call: a list beside a top-level edit leaves unsaid which one is meant.
		if [ -n "$toolOld$toolNew" ] || [ "$toolAll" = "true" ] || [ "$toolAll" = "1" ] ; then
			printf 'ERROR: edits was given together with a top-level old_string, new_string or replace_all -- use one form: every change inside edits, each with its own replace_all, or one change at the top level. Nothing was written.\n' ; return 0
		fi
		case "$editsCount" in ''|*[!0123456789]*) editsCount=0 ;; esac
		if [ "$editsCount" = "0" ] ; then
			printf 'ERROR: edits is an empty list -- give at least one edit, each with old_string and new_string. Nothing was written.\n' ; return 0
		fi
	elif { AgentsHarnessArgFind edits && [ -n "$harnessArgFound" ] ; } || AgentsHarnessArgFind edits.old_string || AgentsHarnessArgFind edits.old_text ; then
		printf 'ERROR: edits must be an array of edits, each with old_string and new_string, got a single value -- nothing was written\n' ; return 0
	else
		editsOld=( "$toolOld" ) ; editsNew=( "$toolNew" ) ; editsAll=( "$toolAll" )
	fi
	## Read and checked whole before the lock is taken, so a call that cannot run never
	## waits on another writer. An edit of a list is read as the top level is: old_string
	## and new_string byte for byte, the *_text name only where its own is absent.
	while [ "$editsIndex" -lt "$editsCount" ] ; do
		if [ -n "$editsListed" ] ; then
			AgentsHarnessArgExact "$6" "edits.$editsIndex.old_string" "edits.$editsIndex.old_text" ; editsOld[$editsIndex]="$harnessArgExact"
			AgentsHarnessArgExact "$6" "edits.$editsIndex.new_string" "edits.$editsIndex.new_text" ; editsNew[$editsIndex]="$harnessArgExact"
			editsAll[$editsIndex]="$( AgentsHarnessArgValue "$6" "edits.$editsIndex.replace_all" )"
			editsWhere="edit $(( editsIndex + 1 )) of $editsCount failed, none was applied: "
		fi
		## Only an explicit opt-in lifts the uniqueness guard; anything else leaves it standing.
		case "${editsAll[$editsIndex]}" in
			true|1) ;;
			*) editsAll[$editsIndex]="" ;;
		esac
		if [ -z "${editsOld[$editsIndex]}" ] ; then
			printf 'ERROR: %sold_string is empty -- an empty match has no unique position\n' "$editsWhere" ; return 0
		fi
		editsIndex=$(( editsIndex + 1 ))
	done
	## Taken before the count: a count read outside the lock is stale by the time it is used.
	if ! AgentsHarnessLockTake "$toolPath" ; then
		printf 'ERROR: could not take the write lock for %s -- another call is writing it, or the lock area is unusable -- so nothing was written. Retry.\n' "$toolPath" ; return 0
	fi
	toolLock="$agentsLocalLockPath"
	## Two scratch texts take turns: each edit reads the one the edit before it wrote, the
	## first one the file itself, so nothing reaches the file before the last has applied.
	editsSource="$toolPath" ; editsOut="$harnessScratch/edit.out" ; editsSpare="$harnessScratch/edit.in"
	editsIndex=0
	while [ "$editsIndex" -lt "$editsCount" ] ; do
		[ -z "$editsListed" ] || editsWhere="edit $(( editsIndex + 1 )) of $editsCount failed, none was applied: "
		## index() counts and substitutes in one call so the two cannot drift; ENVIRON, never -v.
		toolCount="$( EDIT_OLD="${editsOld[$editsIndex]}" LC_ALL=C awk -v RS=$'\001' '
			BEGIN { editOld = ENVIRON["EDIT_OLD"] ; matchCount = 0 ; }
			{
				scanRest = $0
				while ( ( matchPos = index(scanRest, editOld) ) > 0 ) {
					matchCount = matchCount + 1
					scanRest = substr(scanRest, matchPos + length(editOld))
				}
			}
			END { print matchCount + 0 ; }
		' "$editsSource" 2>/dev/null || : )"
		[ -n "$toolCount" ] || toolCount=0
		## A kept change is applied only where each edit matches what it matched when it was shown.
		if [ -n "$harnessChangeApply" ] && [ "$toolCount" != "$( AgentsHarnessChangeMatched "$editsIndex" )" ] ; then
			AgentsToolsLocalLockGive "$toolLock"
			printf 'STALE: %s has changed since this change was shown: %sits old_string matched %s place(s) then and matches %s now, so nothing was written\n' \
				"$toolPath" "${editsListed:+edit $(( editsIndex + 1 )) of $editsCount, }" "$( AgentsHarnessChangeMatched "$editsIndex" )" "$toolCount" ; return 0
		fi
		editsSeen="$editsSeen${editsSeen:+ }$toolCount"
		if [ "$toolCount" = "0" ] ; then
			AgentsToolsLocalLockGive "$toolLock"
			printf 'ERROR: %sold_string not found in %s -- nothing was written\n' "$editsWhere" "$toolPath" ; return 0
		fi
		if [ -z "${editsAll[$editsIndex]}" ] && [ "$toolCount" != "1" ] ; then
			AgentsToolsLocalLockGive "$toolLock"
			printf 'ERROR: %sold_string occurs %s times in %s -- it must identify exactly one place. Nothing was written; extend old_string until it is unique, or pass replace_all to change every occurrence.\n' "$editsWhere" "$toolCount" "$toolPath" ; return 0
		fi
		## `printf "%s", $0` with the RS re-join, never `print`, which appends ORS and
		## gave a file that ended without a newline one it never had.
		if ! EDIT_OLD="${editsOld[$editsIndex]}" EDIT_NEW="${editsNew[$editsIndex]}" EDIT_ALL="${editsAll[$editsIndex]}" LC_ALL=C awk -v RS=$'\001' '
			BEGIN { editOld = ENVIRON["EDIT_OLD"] ; editNew = ENVIRON["EDIT_NEW"] ; editAll = ENVIRON["EDIT_ALL"] ; editDone = 0 ; }
			{
				outText = ""
				scanRest = $0
				while ( ( editAll != "" || !editDone ) && ( matchPos = index(scanRest, editOld) ) > 0 ) {
					outText = outText substr(scanRest, 1, matchPos - 1) editNew
					scanRest = substr(scanRest, matchPos + length(editOld))
					editDone = 1
				}
				if (NR > 1) printf "%s", RS
				printf "%s%s", outText, scanRest
			}
		' "$editsSource" > "$editsOut" 2>/dev/null ; then
			AgentsToolsLocalLockGive "$toolLock"
			printf 'ERROR: %scould not rewrite: %s -- nothing was written\n' "$editsWhere" "$toolPath" ; return 0
		fi
		[ -z "$editsListed" ] || [ -z "${editsAll[$editsIndex]}" ] || editsNote="$editsNote${editsNote:+, }edit $(( editsIndex + 1 )) replaced $toolCount occurrence(s)"
		editsSource="$editsOut" ; editsOut="$editsSpare" ; editsSpare="$editsSource"
		editsIndex=$(( editsIndex + 1 ))
	done
	## Held for approval: nothing reaches the file. The change is kept and shown instead, with
	## the file as it stands under the lock, which is what the change was worked out from.
	if [ -n "$toolHeld" ] ; then
		if ! cp "$toolPath" "$harnessScratch/change.base" 2>/dev/null || ! cp "$editsSource" "$harnessScratch/change.result" 2>/dev/null ; then
			AgentsToolsLocalLockGive "$toolLock"
			printf 'ERROR: could not keep the change to hold it, so nothing is held and nothing was written: %s\n' "$toolPath" ; return 0
		fi
		AgentsToolsLocalLockGive "$toolLock"
		AgentsHarnessChangeHold Edit "$toolPath" "$harnessScratch/change.base" "$harnessScratch/change.result" "$6" "$editsSeen"
		return 0
	fi
	## Replaced by rename, as Write does, so no reader ever sees a half-written file.
	toolTemp="$( dirname -- "$toolPath" )/.$( basename -- "$toolPath" ).mdat-edit.$$"
	if ! cp -p "$toolPath" "$toolTemp" 2>/dev/null || ! cat "$editsSource" > "$toolTemp" || ! mv -f "$toolTemp" "$toolPath" ; then
		rm -f "$toolTemp" ; AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	AgentsToolsLocalLockGive "$toolLock"
	if [ -n "$editsListed" ] ; then
		printf 'OK: applied %s edit(s) in %s%s\n' "$editsCount" "$toolPath" "${editsNote:+ -- $editsNote}"
	elif [ -n "${editsAll[0]}" ] ; then
		printf 'OK: replaced %s occurrence(s) in %s\n' "$toolCount" "$toolPath"
	else
		printf 'OK: replaced one occurrence in %s\n' "$toolPath"
	fi
}

## The root is tested before the pattern is evaluated, so a missing directory is named
## as missing rather than collapsing into "the pattern matched nothing".
AgentsHarnessToolGlob(){
	local toolPattern="$1" toolPath="${2:-$PWD}" toolLong="$3" toolBytes globStat globLine globSlice
	AgentsHarnessReadGate Glob "$toolPath" || return 0
	toolPath="$harnessResolvedPath"
	if [ ! -d "$toolPath" ] ; then
		printf 'ERROR: no such directory: %s\n' "$toolPath" ; return 0
	fi
	## `find`, not a shell glob: a glob cannot recurse and an unmatched one expands to itself.
	## -L because a skillset member entry is a symlinked directory, and without it the walk
	## lists such an entry without ever entering it, reporting a clean empty result.
	## Oldest first by modification time, the package's own `ls -tr` order; stat(1) speaks BSD or GNU.
	if stat -f '%m' / >/dev/null 2>&1 ; then
		globStat=( -L -f $'%m\t%N' )
	elif stat -c '%Y' / >/dev/null 2>&1 ; then
		globStat=( -L -c $'%Y\t%n' )
	else
		printf 'ERROR: stat(1) understands neither the BSD nor the GNU format flag, so matches cannot be ordered by modification time\n' ; return 0
	fi
	## A pattern holding a slash is matched against the root-relative path as an anchored ERE, built here; ENVIRON, never -v.
	case "$toolPattern" in
		'')  find -L "$toolPath/" -maxdepth 1 -exec stat "${globStat[@]}" {} + || : ;;
		*/*) find -L "$toolPath/" -type f | GLOB_ROOT="$toolPath/" GLOB_PATTERN="$toolPattern" LC_ALL=C awk -f "$harnessHere/AgentsHarnessGlobFilterInline.awk" | LC_ALL=C tr '\n' '\000' | xargs -0 -r stat "${globStat[@]}" ;;
		*)   find -L "$toolPath/" -type f -name "$toolPattern" -exec stat "${globStat[@]}" {} + || : ;;
	esac 2> "$harnessScratch/glob.err" | LC_ALL=C sort -n | LC_ALL=C awk '{ sub(/^[0-9]+\t/, "") ; print ; }' > "$harnessScratch/glob.out"
	## find -ls over the sorted paths, in slices well under any argv limit; every path is absolute, so none reads as an expression.
	if [ -n "$toolLong" ] ; then
		globSlice=()
		while IFS= read -r globLine ; do
			globSlice+=( "$globLine" )
			[ "${#globSlice[@]}" -lt 1000 ] || { find -L "${globSlice[@]}" -maxdepth 0 -ls || : ; globSlice=() ; }
		done < "$harnessScratch/glob.out" > "$harnessScratch/glob.ls" 2>&1
		[ "${#globSlice[@]}" -eq 0 ] || find -L "${globSlice[@]}" -maxdepth 0 -ls >> "$harnessScratch/glob.ls" 2>&1 || :
		mv -f "$harnessScratch/glob.ls" "$harnessScratch/glob.out"
	fi
	cat "$harnessScratch/glob.err" >> "$harnessScratch/glob.out"
	if [ -n "$toolPattern" ] && [ ! -s "$harnessScratch/glob.out" ] ; then
		printf 'No files found\n' ; return 0
	fi
	## Capped and said so: a truncated list reads as the complete set of matches.
	toolBytes="$( wc -c < "$harnessScratch/glob.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt "$harnessReadCap" ] ; then
		AgentsHarnessReadRange "$harnessScratch/glob.out" 1 "" "" "narrow the pattern or path to see the rest"
	else
		cat "$harnessScratch/glob.out"
	fi
}

## Grep's `type`: the file-name globs of one ripgrep type, space-separated, from ripgrep's
## own default table, trimmed to common types. Returns 1 for a name not in it. With no
## argument it prints the known names, for the refusal to list.
AgentsHarnessGrepTypeGlobs(){ ## type name
	case "${1-}" in
		'')       printf 'awk c cpp cs css docker go html java js json kotlin lua make markdown md perl php py ruby rust sh sql svg swift toml ts txt xml yaml' ;;
		awk)      printf '*.awk' ;;
		c)        printf '*.c *.h *.H' ;;
		cpp)      printf '*.C *.cc *.cpp *.cxx *.c++ *.h *.H *.hh *.hpp *.hxx *.h++ *.inl' ;;
		cs)       printf '*.cs' ;;
		css)      printf '*.css *.scss' ;;
		docker)   printf '*Dockerfile*' ;;
		go)       printf '*.go' ;;
		html)     printf '*.htm *.html *.ejs' ;;
		java)     printf '*.java *.jsp *.jspx *.properties' ;;
		js)       printf '*.js *.jsx *.vue *.cjs *.mjs' ;;
		json)     printf '*.json *.sarif composer.lock' ;;
		kotlin)   printf '*.kt *.kts' ;;
		lua)      printf '*.lua' ;;
		make)     printf '*.mak *.mk GNUmakefile Gnumakefile makefile Makefile' ;;
		markdown|md) printf '*.markdown *.md *.mdown *.mdwn *.mkd *.mkdn *.mdx' ;;
		perl)     printf '*.perl *.pl *.PL *.plh *.plx *.pm *.t' ;;
		php)      printf '*.php *.php3 *.php4 *.php5 *.php7 *.php8 *.pht *.phtml' ;;
		py)       printf '*.py *.pyi' ;;
		ruby)     printf '*.rb *.gemspec Gemfile Rakefile config.ru .irbrc' ;;
		rust)     printf '*.rs' ;;
		sh)       printf '*.sh *.bash *.zsh *.ksh *.csh *.tcsh .bashrc .bash_profile .bash_login .bash_logout .profile .zshrc .zprofile .zshenv .zlogin .zlogout .kshrc .cshrc .login .logout' ;;
		sql)      printf '*.sql *.psql' ;;
		svg)      printf '*.svg' ;;
		swift)    printf '*.swift' ;;
		toml)     printf '*.toml Cargo.lock' ;;
		ts)       printf '*.ts *.tsx *.cts *.mts' ;;
		txt)      printf '*.txt' ;;
		xml)      printf '*.xml *.xml.dist *.dtd *.xsl *.xslt *.xsd *.xjb *.rng *.sch *.xhtml' ;;
		yaml)     printf '*.yaml *.yml' ;;
		*)        return 1 ;;
	esac
}

## `ripgrep` would replace this `grep -rn` outright; the human-owner ruled "Not now".
AgentsHarnessToolGrep(){ ## pattern, path, context, before, after, ignore_case, output_mode, glob, -n, -o, -A, -B, -C, -i, head_limit, offset, multiline, type
	local toolPattern="$1" toolPath="${2:-$PWD}" toolContext="${13:-$3}" toolBefore="${12:-$4}" toolAfter="${11:-$5}" toolIgnoreCase="${14:-$6}" toolMode="${7:-files_with_matches}" toolGlob="$8" toolLineNumbers="$9" toolOnlyMatching="${10}" toolHeadLimit="${15:-250}" toolOffset="${16:-0}" toolBytes toolRegex grepFlags globPrefix globGroup globSuffix globAlts globAlt typeGlobs typeGlob typeFind=()
	case "${17}" in
		true|1) printf 'ERROR: multiline is not supported by this Grep, only by the native Grep tool. Search with a pattern that matches within one line instead. Nothing was searched.\n' ; return 0 ;;
	esac
	## A type is a find predicate over the file name, ANDed with glob as ripgrep ANDs -t and -g.
	if [ -n "${18}" ] ; then
		typeGlobs="$( AgentsHarnessGrepTypeGlobs "${18}" )" || {
			printf 'ERROR: unrecognized file type: %s. Known types: %s. Use glob for any other set of files, such as *.ext. Nothing was searched.\n' "${18}" "$( AgentsHarnessGrepTypeGlobs )" ; return 0
		}
		read -r -a typeGlobs <<< "$typeGlobs"
		for typeGlob in "${typeGlobs[@]}" ; do
			[ "${#typeFind[@]}" -eq 0 ] || typeFind+=( -o )
			typeFind+=( -name "$typeGlob" )
		done
		typeFind=( '(' "${typeFind[@]}" ')' )
	fi
	case "${toolGlob#\*\*/}" in
		*/*) ;;
		*) toolGlob="${toolGlob#\*\*/}" ;;
	esac
	AgentsHarnessReadGate Grep "$toolPath" || return 0
	toolPath="$harnessResolvedPath"
	if [ ! -e "$toolPath" ] ; then
		printf 'ERROR: no such path: %s\n' "$toolPath" ; return 0
	fi
	## ripgrep class escapes become POSIX classes; an escaped backslash and every other escape pass through untouched.
	toolRegex="$( GREP_PATTERN="$toolPattern" LC_ALL=C awk -f "$harnessHere/AgentsHarnessGrepPatternToPosix.awk" )" || { printf '%s\n' "$toolRegex" ; return 0 ; }
	## The mode picks the output shape; -E, -C/-B/-A, -i, -o, -H and --include are carried by BSD and GNU grep alike.
	case "$toolMode" in
		content)            grepFlags=( -rE ) ;;
		files_with_matches) grepFlags=( -rlE ) ;;
		count)              grepFlags=( -rcE ) ;;
		*)
			printf 'ERROR: output_mode must be content, files_with_matches or count, got: %s\n' "$toolMode" ; return 0
		;;
	esac
	## A per-side value wins over -C, which otherwise sets both sides.
	[ -n "$toolBefore" ] || toolBefore="$toolContext"
	[ -n "$toolAfter" ] || toolAfter="$toolContext"
	if [ -n "$toolBefore" ] && ! AgentsHarnessWholeNumber "$toolBefore" ; then
		printf 'ERROR: -B/before/-C/context must be a whole number of lines, got: %s\n' "$toolBefore" ; return 0
	fi
	if [ -n "$toolAfter" ] && ! AgentsHarnessWholeNumber "$toolAfter" ; then
		printf 'ERROR: -A/after/-C/context must be a whole number of lines, got: %s\n' "$toolAfter" ; return 0
	fi
	if ! AgentsHarnessWholeNumber "$toolHeadLimit" ; then
		printf 'ERROR: head_limit must be a whole number of lines or entries, got: %s\n' "$toolHeadLimit" ; return 0
	fi
	if ! AgentsHarnessWholeNumber "$toolOffset" ; then
		printf 'ERROR: offset must be a whole number of lines or entries, got: %s\n' "$toolOffset" ; return 0
	fi
	if [ "$toolMode" = content ] ; then
		## BSD grep mixes context lines into -o output and GNU grep drops them, so -o takes none.
		case "$toolOnlyMatching" in
			true|1) toolBefore="" ; toolAfter="" ;;
		esac
		[ -z "$toolBefore" ] || grepFlags+=( -B "$toolBefore" )
		[ -z "$toolAfter" ] || grepFlags+=( -A "$toolAfter" )
		case "$toolLineNumbers" in
			false|0) ;;
			*) grepFlags+=( -n ) ;;
		esac
		case "$toolOnlyMatching" in
			true|1) grepFlags+=( -o ) ;;
		esac
	fi
	case "$toolIgnoreCase" in
		true|1) grepFlags+=( -i ) ;;
	esac
	## --include matches a file name only, and takes no braces, so one {a,b} group becomes one --include per branch.
	case "$toolGlob" in
		'') ;;
		*/*) ;;
		*\{*\}*)
			globPrefix="${toolGlob%%\{*}" ; globGroup="${toolGlob#*\{}" ; globSuffix="${globGroup#*\}}" ; globGroup="${globGroup%%\}*}"
			case "$globGroup$globSuffix" in
				*[{}]*) printf 'ERROR: glob takes at most one {a,b} group, got: %s\n' "$toolGlob" ; return 0 ;;
			esac
			if [ -z "$globGroup" ] ; then
				printf 'ERROR: glob has an empty {} group, so it would match every file, got: %s\n' "$toolGlob" ; return 0
			fi
			IFS=, read -r -a globAlts <<< "$globGroup"
			for globAlt in "${globAlts[@]}" ; do
				grepFlags+=( --include="$globPrefix$globAlt$globSuffix" )
			done
		;;
		*) grepFlags+=( --include="$toolGlob" ) ;;
	esac
	## `|| :` keeps grep's own rc 1 on no-match from tripping this script's set -e. Paged, and said so when cut.
	## A glob holding a slash selects files by path first, as Glob matches a path, and grep reads only those.
	## A type does the same by file name; a file named as path is searched whatever its type, as ripgrep does.
	[ -d "$toolPath" ] || typeFind=()
	{
		case "$toolGlob" in
			*/*)
				find "$toolPath" -type f ${typeFind[@]+"${typeFind[@]}"} 2>&3 | GLOB_ROOT="${toolPath%/}/" GLOB_PATTERN="$toolGlob" LC_ALL=C awk -f "$harnessHere/AgentsHarnessGlobFilterFunction.awk" | LC_ALL=C tr '\n' '\000' | xargs -0 -r grep "${grepFlags[@]}" -H -- "$toolRegex" 2>&1 || :
			;;
			*)
				if [ "${#typeFind[@]}" -gt 0 ] ; then
					find "$toolPath" -type f "${typeFind[@]}" 2>&3 | LC_ALL=C tr '\n' '\000' | xargs -0 -r grep "${grepFlags[@]}" -H -- "$toolRegex" 2>&1 || :
				else
					grep "${grepFlags[@]}" -- "$toolRegex" "$toolPath" 2>&1 || :
				fi
			;;
		esac
	} 3>&1 | LC_ALL=C awk -v skipCount="$toolOffset" -v keepCount="$toolHeadLimit" '
		NR > skipCount && ( keepCount == 0 || NR <= skipCount + keepCount ) { print ; }
		END { if ( keepCount > 0 && NR > skipCount + keepCount ) { printf "... head_limit reached: showed %d of %d lines or entries; continue with offset %d ...\n", keepCount, NR, skipCount + keepCount ; } ; }
	' > "$harnessScratch/grep.out"
	## Capped and said so: a truncated search reads as "there are no further matches".
	toolBytes="$( wc -c < "$harnessScratch/grep.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt "$harnessReadCap" ] ; then
		AgentsHarnessReadRange "$harnessScratch/grep.out" 1 "" "" "narrow the pattern or path to see the rest"
	elif [ ! -s "$harnessScratch/grep.out" ] ; then
		printf 'No matches found\n'
	else
		cat "$harnessScratch/grep.out"
	fi
}

## No sandboxing beyond the cwd bound, matching copilot's own --allow-all-tools trust
## model. Output goes to a scratch file rather than $( ): a model-supplied command may
## background a child that holds a capture pipe open forever.
AgentsHarnessToolBash(){
	local toolCwd="$1" toolCommand="$2" toolTimeout="$3" toolStatus=0 toolBytes
	if ! AgentsHarnessPathAllowed "$toolCwd" ; then
		printf 'ERROR: cwd not in the allowed access-root set: %s\n' "$toolCwd" ; return 0
	fi
	toolCwd="$harnessResolvedPath"
	if [ ! -d "$toolCwd" ] ; then
		printf 'ERROR: no such directory: %s\n' "$toolCwd" ; return 0
	fi
	## Per-call override of the harness-wide bound, validated the way that bound is.
	if [ -n "$toolTimeout" ] ; then
		if ! AgentsHarnessWholeNumber "$toolTimeout" ; then
			printf 'ERROR: timeout must be a whole number of seconds, got: %s\n' "$toolTimeout" ; return 0
		fi
	else
		toolTimeout="$harnessRunTimeout"
	fi
	## The command always reaches bash as an argument, never spliced into a quoted string.
	rm -f "$harnessScratch/run.timedout"
	if [ "$toolTimeout" = 0 ] ; then
		( cd "$toolCwd" && set -e && eval "$toolCommand" ) > "$harnessScratch/run.out" 2>&1 || toolStatus=$?
	elif [ -n "$harnessTimeoutCmd" ] ; then
		"$harnessTimeoutCmd" "$toolTimeout" bash -c 'cd "$1" && set -e && eval "$2"' _ "$toolCwd" "$toolCommand" > "$harnessScratch/run.out" 2>&1 || toolStatus=$?
		[ "$toolStatus" != 124 ] || : > "$harnessScratch/run.timedout"
	else
		## Watchdog where no `timeout` exists; a group, not a subshell, so $toolStatus survives.
		{
			bash -c 'cd "$1" && set -e && eval "$2"' _ "$toolCwd" "$toolCommand" > "$harnessScratch/run.out" 2>&1 &
			harnessRunPid=$!
			printf '%s\n' "$harnessRunPid" > "$harnessScratch/run.pid"
			## The >/dev/null is load-bearing: without it the orphaned `sleep` holds this
			## function's capture pipe open and every Bash call blocks for the full bound.
			## The watchdog ends the command it was started for and no other process: at the
			## bound the pid alone may name whoever was given that number since. So it keeps
			## when the command began, read as the watchdog starts, and signals only while that
			## pid is still the process that began then (AgentsToolsRegistryProcessesBegan, the
			## one reading a process is kept by, loaded in the watchdog's own shell). Where no
			## start can be read, nothing is signalled by the number alone.
			(
				type AgentsToolsRegistryProcessesBegan > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null
				harnessRunBegan="$( printf '%s\n' "$harnessRunPid" | AgentsToolsRegistryProcessesBegan 2> /dev/null )"
				sleep "$toolTimeout"
				[ -n "$harnessRunBegan" ] && [ "$( printf '%s\n' "$harnessRunPid" | AgentsToolsRegistryProcessesBegan 2> /dev/null )" = "$harnessRunBegan" ] && kill -TERM "$harnessRunPid" 2>/dev/null && : > "$harnessScratch/run.timedout"
			) >/dev/null &
			harnessWatchPid=$!
			printf '%s\n' "$harnessWatchPid" > "$harnessScratch/watch.pid"
			wait "$harnessRunPid" || toolStatus=$?
			kill -TERM "$harnessWatchPid" 2>/dev/null || :
			wait "$harnessWatchPid" 2>/dev/null || :
			## Reaped normally: the records exist so the cleanup can reach a child the
			## run never got to wait on, not to re-signal one already gone.
			rm -f "$harnessScratch/run.pid" "$harnessScratch/watch.pid"
		} 2>/dev/null
	fi
	## Capped and said so, as Read states its own cap.
	toolBytes="$( wc -c < "$harnessScratch/run.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt 100000 ] ; then
		head -c 100000 "$harnessScratch/run.out"
		printf '\n... TRUNCATED at 100000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$harnessScratch/run.out"
	fi
	## Expiry is read from the flag the enforcing path wrote, never inferred from the status.
	[ ! -f "$harnessScratch/run.timedout" ] || printf '... TIMED OUT after %s seconds ...\n' "$toolTimeout"
	printf '(exit status %s)\n' "$toolStatus"
}

## One scalar out of a search response, by path. Its own reader rather than a reuse
## of AgentsHarnessArgValue below: that one names a tool call and this one names a
## search result, and one spelling shared between them would make a later change to
## either silently change the other.
AgentsHarnessSearchField(){ ## response JSON, path
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## One array of {Text, FirstURL} records, rendered under its own denominator. Both
## arrays this endpoint returns carry that shape, and RelatedTopics additionally
## carries GROUP entries holding nested topics instead of a link -- those are counted
## as skipped and said so, never dropped in silence, because a list that quietly
## shows four of nine reads as a list of four.
AgentsHarnessSearchTopics(){ ## response JSON, array path, heading, cap, allowed domains, blocked domains, denied URL prefixes, default allowed URL prefixes
	local topicsBody="$1" topicsPath="$2" topicsHeading="$3" topicsCap="$4"
	local topicsCount topicsIndex=0 topicsShown=0 topicsSkipped=0 topicsDropped=0 topicsText topicsUrl
	topicsCount="$( AgentsHarnessSearchField "$topicsBody" "$topicsPath.__count" )"
	## Explicit digit enumeration, never a bracket range: [0-9] is collation-dependent.
	case "$topicsCount" in ''|*[!0123456789]*) topicsCount=0 ;; esac
	[ "$topicsCount" -gt 0 ] || return 0
	printf '%s (%s found):\n' "$topicsHeading" "$topicsCount"
	while [ "$topicsIndex" -lt "$topicsCap" ] && [ "$topicsIndex" -lt "$topicsCount" ] ; do
		topicsText="$( AgentsHarnessSearchField "$topicsBody" "$topicsPath.$topicsIndex.Text" )"
		topicsUrl="$( AgentsHarnessSearchField "$topicsBody" "$topicsPath.$topicsIndex.FirstURL" )"
		topicsIndex=$(( topicsIndex + 1 ))
		if [ -z "$topicsUrl" ] ; then
			topicsSkipped=$(( topicsSkipped + 1 ))
			continue
		fi
		if ! SEARCH_URL="$topicsUrl" SEARCH_ALLOWED="$5" SEARCH_BLOCKED="$6" SEARCH_ALWAYS="$( WEB_URL="$topicsUrl" WEB_ALLOW="$8" WEB_DENY="$7" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlPolicy.awk" )" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlDomainFilter.awk" ; then
			topicsDropped=$(( topicsDropped + 1 ))
			continue
		fi
		topicsShown=$(( topicsShown + 1 ))
		printf '  %s. %s\n     %s\n' "$topicsShown" "${topicsText:-<no text on this entry>}" "$topicsUrl"
	done
	[ "$topicsSkipped" = 0 ] || printf '  (%s of the first %s carried a nested topic group rather than a link, and are not shown)\n' "$topicsSkipped" "$topicsIndex"
	[ "$topicsDropped" = 0 ] || printf '  (%s of the first %s were dropped by allowed_domains or blocked_domains)\n' "$topicsDropped" "$topicsIndex"
	[ "$topicsIndex" -ge "$topicsCount" ] || printf '  (first %s of %s examined, capped at %s)\n' "$topicsIndex" "$topicsCount" "$topicsCap"
	return 0
}

## DuckDuckGo Instant Answer, the provider the human-owner chose. KEYLESS BY
## MEASUREMENT rather than by assumption: this endpoint answered HTTP 200 with a
## real abstract for FreeBSD and for bhyve, and with eight related topics for awk,
## carrying no credential of any kind -- so no search credential is declared in
## AgentsToolsOwnerSetupOptionSpec and none is stored with --owner-setup. A slot
## added there for symmetry with the other tools would stand empty forever and read
## as a value nobody got round to filling, which is worse than no slot at all.
## The two HTML front ends were measured in the same session and are NOT fallbacks
## this may quietly try: html.duckduckgo.com and lite.duckduckgo.com each answer 202
## with an anti-bot challenge and zero results, with and without a browser
## User-Agent. curl builds the query string itself through --data-urlencode, so a
## query carrying a space, an & or an = is never encoded by hand here.
##
## A query that finds nothing is NOT dressed as an error: this endpoint indexes
## named things, so an ordinary question returning nothing is its ordinary
## behaviour, and only a request that could not be made at all says ERROR.
AgentsHarnessToolWebSearch(){ ## query, raw arguments
	local toolQuery="$1" searchBody searchStatus searchRc=0 searchEmitted=0 searchCount
	local searchAbstract searchAbstractSource searchAbstractUrl
	local searchAnswer searchAnswerType searchDefinition searchDefinitionUrl
	local searchAllowed="" searchBlocked="" searchDenied="" searchDefaults domainKey domainList domainCount domainIndex
	if [ -z "$toolQuery" ] ; then
		printf 'ERROR: query is required and was empty, so nothing was searched.\n' ; return 0
	fi
	if [ "${#toolQuery}" -lt 2 ] ; then
		printf 'ERROR: query must be at least 2 characters, got: %s -- nothing was searched.\n' "$toolQuery" ; return 0
	fi
	## Each list is an array of domains, one per line here.
	for domainKey in allowed_domains blocked_domains ; do
		domainList="" ; domainIndex=0
		domainCount="$( AgentsHarnessArgValue "$2" "$domainKey.__count" )"
		if [ -z "$domainCount" ] && [ -n "$( AgentsHarnessArgValue "$2" "$domainKey" )" ] ; then
			printf 'ERROR: %s must be an array of domains, got a single value -- nothing was searched.\n' "$domainKey" ; return 0
		fi
		case "$domainCount" in ''|*[!0123456789]*) domainCount=0 ;; esac
		while [ "$domainIndex" -lt "$domainCount" ] ; do
			domainList="$domainList$( AgentsHarnessArgValue "$2" "$domainKey.$domainIndex" )"$'\n'
			domainIndex=$(( domainIndex + 1 ))
		done
		case "$domainKey" in
			allowed_domains) searchAllowed="$domainList" ;;
			*) searchBlocked="$domainList" ;;
		esac
	done
	searchDefaults="$harnessWebAllowDefaults"
	[ -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] || searchDefaults=""
	[ -z "$searchDefaults" ] || searchDenied="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select WEB_DENY_PREFIXES 2> "$harnessScratch/webpolicy.err" )" || searchDefaults=""
	[ -z "$searchDefaults" ] || ! LC_ALL=C grep -qF '.local/.agents/magic-team.agent.env' "$harnessScratch/webpolicy.err" || searchDefaults=""
	[ -n "$searchDefaults" ] || printf 'Note: the web access policy could not be read, so no result is kept outside allowed_domains by default.\n'
	## Body to its own file, so the capture holds the one-line status and nothing else.
	searchStatus="$( curl -sS -L --connect-timeout 10 --max-time 60 -G \
		--data-urlencode "q=$toolQuery" \
		-d format=json -d no_redirect=1 -d no_html=1 -d t=myx.distro-agents \
		-o "$harnessScratch/search.body" -w '%{http_code}' \
		-- 'https://api.duckduckgo.com/' 2>"$harnessScratch/search.err" )" || searchRc=$?
	if [ "$searchRc" != "0" ] ; then
		printf 'ERROR: the search request did not complete (curl rc=%s), so NOTHING was searched and nothing may be concluded about this query either way: %s\n' "$searchRc" "$( cat "$harnessScratch/search.err" 2>/dev/null )" ; return 0
	fi
	case "$searchStatus" in
		2??) ;;
		*)
			printf 'ERROR: the search endpoint answered HTTP %s rather than a result set, so NOTHING was searched. This is the endpoint refusing or failing, never a query that found nothing.\n' "$searchStatus" ; return 0
		;;
	esac
	searchBody="$( cat "$harnessScratch/search.body" 2>/dev/null )"
	if [ -z "$searchBody" ] ; then
		printf 'ERROR: the search endpoint answered HTTP %s with an empty body, so nothing could be read and NOTHING was searched.\n' "$searchStatus" ; return 0
	fi
	printf '... DuckDuckGo Instant Answer for: %s ...\n' "$toolQuery"
	## AbstractText is the same prose without markup; Abstract is the fallback only
	## because no_html=1 is a request the endpoint honours rather than a guarantee.
	searchAbstract="$( AgentsHarnessSearchField "$searchBody" AbstractText )"
	[ -n "$searchAbstract" ] || searchAbstract="$( AgentsHarnessSearchField "$searchBody" Abstract )"
	searchAbstractSource="$( AgentsHarnessSearchField "$searchBody" AbstractSource )"
	searchAbstractUrl="$( AgentsHarnessSearchField "$searchBody" AbstractURL )"
	if [ -n "$searchAbstract" ] ; then
		searchEmitted=$(( searchEmitted + 1 ))
		if [ -n "$searchAbstractUrl" ] && ! SEARCH_URL="$searchAbstractUrl" SEARCH_ALLOWED="$searchAllowed" SEARCH_BLOCKED="$searchBlocked" SEARCH_ALWAYS="$( WEB_URL="$searchAbstractUrl" WEB_ALLOW="$searchDefaults" WEB_DENY="$searchDenied" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlPolicy.awk" )" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlDomainFilter.awk" ; then
			printf 'Abstract: dropped by allowed_domains or blocked_domains\n'
		else
			printf 'Abstract%s: %s\n' "${searchAbstractSource:+ ($searchAbstractSource)}" "$searchAbstract"
			[ -z "$searchAbstractUrl" ] || printf '  %s\n' "$searchAbstractUrl"
		fi
	fi
	searchAnswer="$( AgentsHarnessSearchField "$searchBody" Answer )"
	searchAnswerType="$( AgentsHarnessSearchField "$searchBody" AnswerType )"
	if [ -n "$searchAnswer" ] ; then
		searchEmitted=$(( searchEmitted + 1 ))
		printf 'Answer%s: %s\n' "${searchAnswerType:+ ($searchAnswerType)}" "$searchAnswer"
	fi
	searchDefinition="$( AgentsHarnessSearchField "$searchBody" Definition )"
	searchDefinitionUrl="$( AgentsHarnessSearchField "$searchBody" DefinitionURL )"
	if [ -n "$searchDefinition" ] ; then
		searchEmitted=$(( searchEmitted + 1 ))
		if [ -n "$searchDefinitionUrl" ] && ! SEARCH_URL="$searchDefinitionUrl" SEARCH_ALLOWED="$searchAllowed" SEARCH_BLOCKED="$searchBlocked" SEARCH_ALWAYS="$( WEB_URL="$searchDefinitionUrl" WEB_ALLOW="$searchDefaults" WEB_DENY="$searchDenied" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlPolicy.awk" )" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlDomainFilter.awk" ; then
			printf 'Definition: dropped by allowed_domains or blocked_domains\n'
		else
			printf 'Definition: %s\n' "$searchDefinition"
			[ -z "$searchDefinitionUrl" ] || printf '  %s\n' "$searchDefinitionUrl"
		fi
	fi
	## Counted here as well as inside the renderer, because what decides the
	## found-nothing sentence below is whether the response carried anything at all.
	searchCount="$( AgentsHarnessSearchField "$searchBody" Results.__count )"
	case "$searchCount" in ''|*[!0123456789]*) searchCount=0 ;; esac
	[ "$searchCount" = 0 ] || searchEmitted=$(( searchEmitted + 1 ))
	AgentsHarnessSearchTopics "$searchBody" Results "Results" 10 "$searchAllowed" "$searchBlocked" "$searchDenied" "$searchDefaults"
	searchCount="$( AgentsHarnessSearchField "$searchBody" RelatedTopics.__count )"
	case "$searchCount" in ''|*[!0123456789]*) searchCount=0 ;; esac
	[ "$searchCount" = 0 ] || searchEmitted=$(( searchEmitted + 1 ))
	AgentsHarnessSearchTopics "$searchBody" RelatedTopics "Related topics" 10 "$searchAllowed" "$searchBlocked" "$searchDenied" "$searchDefaults"
	if [ "$searchEmitted" = 0 ] ; then
		printf 'No instant-answer content for this query. The endpoint was reached and answered HTTP %s; it simply holds no abstract, answer, definition, result or related topic for these words. THIS IS A COMPLETE, SUCCESSFUL SEARCH AND NOT A FAILURE: the DuckDuckGo Instant Answer API indexes named things rather than arbitrary phrases, so an ordinary multi-word question returns exactly this. Do not retry the same query. A shorter query naming one thing may well answer; otherwise say in your final answer that the search returned nothing, never that web search was unavailable.\n' "$searchStatus"
	fi
}

AgentsHarnessToolWebFetch(){ ## url, prompt
	local toolUrl="$1" toolPrompt="${2-}" fetchUrl="$1" fetchStatus fetchTarget fetchRc=0 fetchHops=0 toolBytes fetchTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" fetchVerdict fetchAllowExtra="" fetchDenied="" fetchUnread="" fetchFromHost fetchToHost
	case "$toolUrl" in
		http://*|https://*) ;;
		*)
			printf 'ERROR: url must be an absolute http:// or https:// URL, got: %s\n' "$toolUrl" ; return 0
		;;
	esac
	[ -x "$fetchTools" ] || fetchUnread=1
	[ -n "$fetchUnread" ] || fetchAllowExtra="$( "$BASH" "$fetchTools" --agents-config-option magic-team --select WEB_ALLOW_PREFIXES 2> "$harnessScratch/webpolicy.err" )" || fetchUnread=1
	[ -n "$fetchUnread" ] || fetchDenied="$( "$BASH" "$fetchTools" --agents-config-option magic-team --select WEB_DENY_PREFIXES 2>> "$harnessScratch/webpolicy.err" )" || fetchUnread=1
	[ -n "$fetchUnread" ] || ! LC_ALL=C grep -qF '.local/.agents/magic-team.agent.env' "$harnessScratch/webpolicy.err" || fetchUnread=1
	if [ -n "$fetchUnread" ] ; then
		printf 'ERROR: the web access policy could not be read, so it cannot be checked and nothing was fetched: %s\n' "$toolUrl" ; return 0
	fi
	while : ; do
		fetchVerdict="$( WEB_URL="$fetchUrl" WEB_ALLOW="$harnessWebAllowDefaults $fetchAllowExtra" WEB_DENY="$fetchDenied" LC_ALL=C awk -f "$harnessHere/AgentsHarnessUrlPolicy.awk" )"
		case "$fetchVerdict" in
			allowed) ;;
			*)
				if ! AgentsHarnessGranted WebFetch "$fetchUrl" ; then
					case "$fetchVerdict" in
						denied) AgentsHarnessRefusal WebFetch "$fetchUrl" "ERROR: forbidden: $fetchUrl matches a denied URL prefix. Ask permission for it with the refusal id below, or accept that this URL will not be fetched." ;;
						*) AgentsHarnessRefusal WebFetch "$fetchUrl" "ERROR: forbidden: $fetchUrl matches no allowed URL prefix. Ask permission for it with the refusal id below, or accept that this URL will not be fetched." ;;
					esac
					return 0
				fi
			;;
		esac
		## Body to its own file, so the capture holds curl's own one-line status and nothing else.
		fetchRc=0
		fetchStatus="$( curl -sS --proto '=http,https' --connect-timeout 10 --max-time 120 -o "$harnessScratch/fetch.body" -w '%{http_code} %{redirect_url}' -- "$fetchUrl" 2>"$harnessScratch/fetch.err" )" || fetchRc=$?
		if [ "$fetchRc" != "0" ] ; then
			printf 'ERROR: the request did not complete (curl rc=%s): %s\n' "$fetchRc" "$( cat "$harnessScratch/fetch.err" 2>/dev/null )" ; return 0
		fi
		fetchTarget=""
		case "$fetchStatus" in
			*' '*) fetchTarget="${fetchStatus#* }" ; fetchStatus="${fetchStatus%% *}" ;;
		esac
		case "$fetchStatus" in
			3??) [ -n "$fetchTarget" ] || break ;;
			*) break ;;
		esac
		fetchFromHost="${fetchUrl#*://}" ; fetchFromHost="${fetchFromHost%%[/?#]*}" ; fetchFromHost="${fetchFromHost##*@}" ; fetchFromHost="${fetchFromHost%:*}"
		fetchToHost="${fetchTarget#*://}" ; fetchToHost="${fetchToHost%%[/?#]*}" ; fetchToHost="${fetchToHost##*@}" ; fetchToHost="${fetchToHost%:*}"
		if [ "$( printf '%s' "${fetchFromHost%.}" | LC_ALL=C tr '[:upper:]' '[:lower:]' )" != "$( printf '%s' "${fetchToHost%.}" | LC_ALL=C tr '[:upper:]' '[:lower:]' )" ] ; then
			printf 'ERROR: redirect not followed: HTTP %s from %s to a different host: %s\nFetch that URL with WebFetch to follow it.\n' "$fetchStatus" "$fetchUrl" "$fetchTarget" ; return 0
		fi
		fetchHops=$(( fetchHops + 1 ))
		if [ "$fetchHops" -gt 10 ] ; then
			printf 'ERROR: more than 10 same-host redirects, stopped before: %s -- nothing more was fetched.\n' "$fetchTarget" ; return 0
		fi
		fetchUrl="$fetchTarget"
	done
	[ "$fetchHops" = 0 ] || printf '... followed %s same-host redirect(s) to: %s ...\n' "$fetchHops" "$fetchUrl"
	## A non-2xx still carries a body worth reading, so the status leads and the body follows.
	## A served call has no model to apply a prompt with, so the prompt goes back to the
	## caller, framed ahead of the body: never dropped, and never claimed as applied.
	case "$fetchStatus:$toolPrompt" in
		2??:) printf '... HTTP %s -- raw body follows, nothing stripped or rendered ...\n' "$fetchStatus" ;;
		2??:*) printf '... HTTP %s -- the PROMPT WAS NOT APPLIED: this WebFetch runs no model. Apply it yourself to the unprocessed body below, nothing stripped or rendered. Your prompt: %s ...\n' "$fetchStatus" "$toolPrompt" ;;
		*)   printf 'ERROR: HTTP %s -- the raw body it returned follows\n' "$fetchStatus" ;;
	esac
	## Capped and said so: a cut page reads as a complete one.
	toolBytes="$( wc -c < "$harnessScratch/fetch.body" | tr -d ' ' )"
	if [ "$toolBytes" -gt 100000 ] ; then
		head -c 100000 "$harnessScratch/fetch.body"
		printf '\n... TRUNCATED at 100000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$harnessScratch/fetch.body"
	fi
}

## The one addressee rule of every send tool. The two names below are the only place a session's address is spelled
## here. What each names, and why one names nowhere, is the one address resolver's to say (DistroAgentsToolsResolveTarget).
harnessParentName="session-parent"
harnessCurrentName="session-current"

## The thread a session address names, asked of the one address resolver: prints "<thread> <what it is>", or an
## ERROR line saying why it names nowhere and what to pass instead, and returns 1.
AgentsHarnessSessionThread(){ ## the session address as given, what did not happen (default: Nothing was sent.)
	local sessionResolved="" sessionRc=0 sessionLine sessionChannel="" sessionTs="" sessionWhat="the thread of this session"
	type DistroAgentsToolsResolveTarget > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.CommsSlack.include" 2> /dev/null || :
	sessionResolved="$( DistroAgentsToolsResolveTarget "$1" 2> /dev/null )" || sessionRc=$?
	if [ "$sessionRc" = "3" ] ; then
		printf 'ERROR: %s %s\n' "$sessionResolved" "${2:-Nothing was sent.}" ; return 1
	fi
	while IFS= read -r sessionLine ; do
		case "$sessionLine" in
			CHANNEL=*) sessionChannel="${sessionLine#CHANNEL=}" ;;
			THREAD_TS=*) sessionTs="${sessionLine#THREAD_TS=}" ;;
			PARENT_SESSION_ID=*) sessionWhat="the thread of parent session ${sessionLine#PARENT_SESSION_ID=}" ;;
		esac
	done <<< "$sessionResolved"
	if [ "$sessionRc" != "0" ] || [ -z "$sessionChannel" ] || [ -z "$sessionTs" ] ; then
		printf 'ERROR: the address resolver gave no thread for %s (rc=%s), so it names nowhere here. Pass the thread as <channel>:<ts> instead. %s\n' "$1" "$sessionRc" "${2:-Nothing was sent.}" ; return 1
	fi
	## With :<ts> the address is one message in the conversation of that thread.
	case "$1" in *:*) sessionWhat="a message in the conversation of $sessionWhat" ;; esac
	printf '%s:%s %s\n' "$sessionChannel" "$sessionTs" "$sessionWhat"
}

## The sender's own words of a message a tool builds around them, one paragraph for each
## value given: what the plain-language floor measures in place of the whole message, whose
## other lines -- headings, labels, a refused call, text carried from a record -- are the
## tool's and nobody can rewrite. A caller sets harnessSendProse to this for its one send.
AgentsHarnessSendProse(){ ## values...
	local proseOne
	for proseOne in "$@" ; do
		[ -z "$proseOne" ] || printf '%s\n\n' "$proseOne"
	done
}

## The team's own sanctioned send operation, never a Slack call of this harness's own:
## the credential stays inside that operation and never reaches argv. The text goes in
## on stdin, where no shell quoting can reach it -- a single apostrophe in a composed
## send emptied one live message in this estate.
AgentsHarnessToolSendMessage(){ ## target, message, as bot, address to, broadcast (true: a thread reply also shown in the conversation), no inbox (true: a team member with no Slack DM is refused, since an inbox cannot be waited on), next (reply|handback: a NEXT: line naming the Wait that follows a sent message)
	local toolTarget="$1" toolMessage="$2" toolAsBot="$3" toolAddressTo="$4" toolBroadcast="${5:-}" toolNoInbox="${6:-}" toolNext="${7:-}" sendRc=0 toolShown="" toolSession toolInbox
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to send under, and one is never guessed here. Nothing was sent. Report this rather than working around it.%s\n' "${harnessAgentMissing:+ ($harnessAgentMissing)}" ; return 0
	fi
	## The served SendMessage posts in its session only with its seat there (F6.9, AgentsHarnessSendSeatRefused).
	[ "$toolNext" != "reply" ] || ! AgentsHarnessSendSeatRefused "$toolTarget" || return 0
	## No target named: default to this session's own coworking thread, where one
	## exists. An ad-hoc/solo spawn holding none keeps today's explicit-target
	## requirement exactly -- the error just below fires precisely as it always has.
	if [ -z "$toolTarget" ] ; then
		type AgentsToolsSessionCurrentThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		toolTarget="$( AgentsToolsSessionCurrentThreadFind 2>/dev/null )" || toolTarget=""
	fi
	case "$toolTarget" in
		"$harnessCurrentName"|"$harnessCurrentName":*|"$harnessParentName"|"$harnessParentName":*)
			toolSession="$( AgentsHarnessSessionThread "$toolTarget" )" || { printf '%s\n' "$toolSession" ; return 0 ; }
			toolTarget="${toolSession%% *}"
			toolShown="$toolTarget (${toolSession#* })"
		;;
	esac
	if [ -z "$toolTarget" ] || [ -z "$toolMessage" ] ; then
		printf 'ERROR: both to and message are required, and one of them was empty. Nothing was sent.\n' ; return 0
	fi
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other send path exists here. Nothing was sent.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	## Built as argv so the optional flag is one token rather than a quoted fragment.
	set -- "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-comms-slack-send-message "$harnessAgent" "$toolTarget"
	case "$toolAsBot" in
		true|1|yes) set -- "$@" --identity-bot ;;
	esac
	[ -z "$toolAddressTo" ] || set -- "$@" --address-to "$toolAddressTo"
	[ "$toolBroadcast" != "true" ] || set -- "$@" --reply-broadcast
	## Output to a file rather than a capture: the operation forks curl, and a capture
	## returns on pipe EOF rather than on the command it ran.
	## send.delivered is written only by a delivery that succeeded, Slack or inbox: what a
	## caller (SubagentHandback) reads to act once on a delivered message, never on a failed one.
	rm -f "$harnessScratch/send.delivered"
	## Only the sender's own words are measured against the plain-language floor: named by
	## the caller in harnessSendProse for this one send, else the whole message is theirs.
	if [ "${harnessSendProse+set}" = "set" ] ; then
		printf '%s' "$harnessSendProse" > "$harnessScratch/send.prose"
		printf '%s' "$toolMessage" | MDAT_SEND_PROSE_FILE="$harnessScratch/send.prose" "$@" --from-stdin >"$harnessScratch/send.out" 2>&1 || sendRc=$?
	else
		printf '%s' "$toolMessage" | "$@" --from-stdin >"$harnessScratch/send.out" 2>&1 || sendRc=$?
	fi
	## A team member with no Slack DM of its own is reached by its inbox, a hand-off it reads later.
	## A question cannot use it, because nothing can wait on a file.
	if [ "$sendRc" != "0" ] && LC_ALL=C grep -q -E 'ERROR: .*--member-comms-slack-send-message: NO-SLACK-DM: ' "$harnessScratch/send.out" ; then
		toolTarget="${toolTarget%%:*}"
		if [ "$toolNoInbox" = "true" ] ; then
			printf 'ERROR: %s has no Slack DM channel, and an inbox cannot carry a question that waits for an answer. Nothing was sent.\n' "$toolTarget" ; return 0
		fi
		toolInbox="inquiry-$( date -u +%Y%m%dT%H%MZ )-message-$( printf '%s' "$toolMessage" | cksum | cut -d' ' -f1 ).md"
		if { printf -- '---\ntype: inquiry\nfrom: %s\ndate: %s\nowner: %s\n---\n\n%s\n' "$harnessAgent" "$( date +'%Y-%m-%d %H:%M %z' )" "$toolTarget" "$toolMessage" ; } \
			| "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-upsert-member-inquiry "$toolTarget" "$toolInbox" > "$harnessScratch/inbox.out" 2>&1 ; then
			printf 'inbox %s %s\n' "$toolTarget" "$toolInbox" > "$harnessScratch/send.delivered"
			printf 'Sent to the inbox of %s as %s, because that team member has no Slack DM channel of its own. It is read only when that member next processes its inbox.\n' "$toolTarget" "$toolInbox"
		else
			printf 'ERROR: %s has no Slack DM channel, and its inbox refused the hand-off, so nothing was sent. What the operation reported follows:\n' "$toolTarget"
			cat "$harnessScratch/inbox.out"
		fi
		return 0
	fi
	## Carrying the retired marker of a question, `NEEDS REPLY`: not sent, and returned as the
	## correction the send made of it (AgentsToolsOutputStyleRetiredMarker), with what to do in
	## its place: the question goes into a tool that asks, alone, and the message goes again
	## without it. A send that takes no inbox is a question's own, asked with such a tool
	## already, so there the marker alone comes out.
	if [ "$sendRc" != "0" ] && LC_ALL=C grep -q '^- needs-reply-marker: ' "$harnessScratch/send.out" ; then
		printf 'CORRECTION: the message was NOT sent and must be corrected and sent again. It carries the marker NEEDS REPLY, which is retired: a question to a person is asked with a tool that asks, alone in its own message, and a plain message carries none. This is a correction for you to make, never a refusal or a denial: there is no limit on attempts, and every attempt is checked the same way. Only the marker is looked for, in your own words: a quoted line and code are left out, and no wording is read as a question.\n'
		LC_ALL=C grep '^- needs-reply-marker: ' "$harnessScratch/send.out" || :
		if [ "$toolNoInbox" = "true" ] ; then
			printf 'NEXT: take the marker out and ask again: a question asked with this tool already waits for its answer\n'
		else
			printf 'NEXT: ask the question with AskQuestion, ConfirmReadback, EscalateDecision or RequestPermission, alone in its own message, and send this message again without the marker and without the question\n'
		fi
		return 0
	fi
	## Over the plain-language floor: not sent, and returned as the correction it is, never as
	## an error, a refusal or a denial. Its first word is the one fixed word of this outcome;
	## then each fault, then what to do. Every attempt is measured the same way.
	if [ "$sendRc" != "0" ] && LC_ALL=C grep -q '^CORRECTION: ' "$harnessScratch/send.out" ; then
		printf 'CORRECTION: the message was NOT sent and must be corrected and sent again. It is over the plain-language limits. This is a correction for you to make, never a refusal or a denial: there is no limit on attempts, and every attempt is measured the same way. Only your own words are measured.\n'
		LC_ALL=C grep '^- ' "$harnessScratch/send.out" || :
		printf 'NEXT: rewrite these and send again\n'
		return 0
	fi
	if [ "$sendRc" != "0" ] ; then
		printf 'ERROR: the send failed (rc=%s) and nothing was posted. What the operation reported follows:\n' "$sendRc"
	else
		printf 'Sent to %s as %s. What the operation reported follows:\n' "${toolShown:-$toolTarget}" "$harnessAgent"
	fi
	cat "$harnessScratch/send.out"
	## The session's own last post, "<channel>:<thread-ts> <ts>": the floor a later Wait takes for
	## that thread when it has none stored, so a reply landing between this post and that Wait
	## is not skipped. Best effort: a post not recorded only loses that fallback.
	[ "$sendRc" != "0" ] || AgentsHarnessOwnPostRecord "$harnessScratch/send.out"
	[ "$sendRc" != "0" ] || ! LC_ALL=C grep -q '^SENT_MESSAGE_TS=' "$harnessScratch/send.out" || printf 'slack\n' > "$harnessScratch/send.delivered"
	## One extra last line naming the Wait that follows, only for a caller that asked (the
	## SendMessage and SubagentHandback tools) -- never for a tool that asks, which waits itself,
	## or the announcement stubs, which expect no reply. Built from the send's own reported fields.
	[ "$sendRc" = "0" ] && [ -n "$toolNext" ] || return 0
	if [ "$toolNext" = "handback" ] ; then
		[ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && [ "${MDAT_SPAWN_CALLER_WAITS:-}" != "true" ] || return 0
		## A session that was dismissed is done with this handback: told to wait here, it did.
		if AgentsHarnessDismissedBy > /dev/null ; then
			printf 'NEXT: you are dismissed and your handback is given -- end your run now, and call nothing more\n'
			return 0
		fi
		## A run that reports to no one ends on its report.
		if AgentsHarnessReportsNone ; then
			## Unless it founded its session and others of it still run (F6.9): it ends once they have.
			if AgentsHarnessDismissWaits > /dev/null ; then
				printf 'NEXT: your report is given, and others of the session you founded still run -- call Wait with no sources and obey what arrives, until it returns DISMISSED once they have ended\n'
				return 0
			fi
			printf 'NEXT: your report is given and you report to no one -- end your run now, and call nothing more\n'
			return 0
		fi
		printf 'NEXT: you are not done -- call Wait with no sources (your session thread) and obey what arrives, until it returns DISMISSED\n'
		return 0
	fi
	local nextChannel nextTs nextThread nextAddressees
	nextChannel="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_CHANNEL=//p' "$harnessScratch/send.out" | head -1 )"
	nextTs="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' "$harnessScratch/send.out" | head -1 )"
	nextThread="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_THREAD_TS=//p' "$harnessScratch/send.out" | head -1 )"
	nextAddressees="$( LC_ALL=C sed -n 's/^SENT_MESSAGE_ADDRESSEES=//p' "$harnessScratch/send.out" | head -1 )"
	[ -n "$nextChannel" ] && [ -n "$nextTs" ] && [ -n "$nextThread" ] || return 0
	case "$nextAddressees" in
		'') printf 'NEXT: to wait for a reply in its thread, call Wait sources=slack:%s:%s:conversation since_utime=%s\n' "$nextChannel" "$nextThread" "$nextTs" ;;
		*' '*) printf 'NEXT: to wait for a reply in its thread, call Wait sources=slack:%s:%s since_utime=%s addressee="%s"\n' "$nextChannel" "$nextThread" "$nextTs" "$nextAddressees" ;;
		*) printf 'NEXT: to wait for a reply in its thread, call Wait sources=slack:%s:%s since_utime=%s addressee=%s\n' "$nextChannel" "$nextThread" "$nextTs" "$nextAddressees" ;;
	esac
}

## The spawned-sessions registry is what enumerates agents: every spawn has a sandbox, created
## even when empty, so a session with no tracking document and no board item is still listed.
## Rebuilt from the sandbox roots on each call, with liveness measured for this host's rows.
##
## view/session_id/state are optional filters onto that same registry -- see
## AgentsToolsRegistryRenderSpawnedSessions's own header for what each composes with.
AgentsHarnessToolListAgents(){
	local toolView="${1:-agents}" toolSessionId="$2" toolState="$3"
	local listRegistries="$harnessHere/AgentsTools.Registries.include"
	if [ -z "${MMDAPP:-}" ] ; then
		printf 'ERROR: MMDAPP is not set in this process, so the spawn sandbox roots cannot be located. Nothing was listed, and no session is implied to be absent.\n' ; return 0
	fi
	if [ ! -f "$listRegistries" ] ; then
		printf 'ERROR: the registry reader is missing at %s, so nothing was listed, and no session is implied to be absent.\n' "$listRegistries" ; return 0
	fi
	case "$toolView" in
		agents|sessions) ;;
		*) printf 'ERROR: view must be agents or sessions, got: %s\n' "$toolView" ; return 0 ;;
	esac
	case "$toolState" in
		''|running|waiting|finished) ;;
		*) printf 'ERROR: state must be running, waiting or finished, got: %s. running also includes waiting rows.\n' "$toolState" ; return 0 ;;
	esac
	( . "$listRegistries" ; AgentsToolsRegistryRenderSpawnedSessions "$toolView" "$toolSessionId" "$toolState" ) 2>&1
}

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

## The mark's file. rc 1, nothing printed, for a session that keeps none.
AgentsHarnessDismissedFile(){
	[ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && [ -n "${MMDAPP:-}" ] && AgentsHarnessBareName "$MDAT_SPAWN_SESSION_ID" || return 1
	case "$MDAT_SPAWN_SESSION_ID" in .|..) return 1 ;; esac
	printf '%s' "$MMDAPP/.local/agents/sessions/$MDAT_SPAWN_SESSION_ID/dismissed"
}
## Keeps the dismissal, once: who dismissed this session, as its Wait said it.
AgentsHarnessDismissedKeep(){ ## who dismissed it (the WAIT-DISMISSED-BY value)
	local keepFile
	keepFile="$( AgentsHarnessDismissedFile )" || return 0
	[ ! -f "$keepFile" ] || return 0
	{ mkdir -p "${keepFile%/*}" && printf '%s\n' "${1:-unknown}" > "$keepFile.$$.tmp" && mv -f "$keepFile.$$.tmp" "$keepFile" ; } 2> /dev/null || :
	return 0
}
## Who dismissed this session, printed. rc 1 for a session that was not dismissed.
AgentsHarnessDismissedBy(){
	local byFile byLine=""
	byFile="$( AgentsHarnessDismissedFile )" || return 1
	[ -f "$byFile" ] || return 1
	IFS= read -r byLine < "$byFile" || :
	printf '%s' "${byLine:-unknown}"
}
## The last line of a result for a dismissed session: what is left for it to do.
AgentsHarnessDismissedNext(){
	local nextFile
	if nextFile="$( AgentsHarnessDismissedFile )" && [ -f "$nextFile.handback" ] ; then
		printf 'NEXT: you are dismissed and your handback is given -- end your run now, and call nothing more\n'
	else
		printf 'NEXT: you are dismissed -- give your handback if you have not, then end your run\n'
	fi
}
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
AgentsHarnessDismissedAfter(){ ## tool name
	local afterFile afterDelay afterSession afterGrace="${MDAT_DISMISSED_END_GRACE:-60}"
	case "$1" in SubagentHandback|Wait) ;; *) return 0 ;; esac
	afterFile="$( AgentsHarnessDismissedFile )" && [ -f "$afterFile.handback" ] || return 0
	if [ -z "$harnessToolOnly" ] ; then
		harnessDismissedEnd=1
		return 0
	fi
	AgentsHarnessWholeNumber "$afterGrace" || afterGrace=60
	afterDelay=2 ; [ "$1" != "SubagentHandback" ] || afterDelay="$afterGrace"
	afterSession="$MDAT_SPAWN_SESSION_ID"
	type AgentsToolsRegistryRunWords > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null || return 0
	(
		trap '' HUP INT
		afterFd=3 ; while [ "$afterFd" -lt 64 ] ; do eval "exec $afterFd>&-" ; afterFd=$(( afterFd + 1 )) ; done
		sleep "$afterDelay"
		afterWord="$( AgentsHarnessSessionWordPids "$afterSession" )"
		afterPids=""
		for afterPid in $afterWord ; do
			[ "$( ps -p "$afterPid" -ww -o args= 2> /dev/null | AgentsToolsRegistryRunWords )" != "$afterSession" ] || afterPids="$afterPids $afterPid"
		done
		[ -n "$afterPids" ] || [ -n "$afterWord" ] || afterPids="$( AgentsHarnessSessionPids "$afterSession" )"
		[ -n "$afterPids" ] || exit 0
		printf '# %s: the tooling ends this run: it was dismissed, its handback is given, and it did not end by itself\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" >> "$MMDAPP/.local/agents/sessions/$afterSession/session.log" 2> /dev/null
		for afterPid in $afterPids ; do
			kill -TERM "$afterPid" 2> /dev/null
		done
		exit 0
	) > /dev/null 2>&1 < /dev/null &
	return 0
}

## ---- THE SEAT AND WHEN A RUN IS DISMISSED (F6.9; AgentsTools.SpawnSandbox.include) ----
## A member is active once in a session: of its runs there, the one that holds its seat reads the
## session and posts in it. The served Wait and SendMessage of a spawned run take its seat at its
## first read of the session or post to it; a run without it is given nothing of the session but
## a DISMISSED addressed to it, and its post there is refused, naming the run that holds it. A
## run whose seat passed to the run that restarts it is dismissed by the tooling. A dismissal of
## a session's executor waits while another participant of that session runs, and is given at
## its first Wait once they have ended.

## This run's seat in its session: rc 0, nothing printed, where it holds it or has none to hold
## (no spawn record of its own, a record that names no session, or a seat that cannot be read
## now); rc 1, the holder's spawn id printed, where another live run of its member holds it.
AgentsHarnessSeatTake(){
	local seatRecord="" seatSession="" seatHolder="" seatRc=0
	seatRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" )" && [ -n "$seatRecord" ] || return 0
	type AgentsToolsSessionSeatTake > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || return 0
	seatSession="$( AgentsToolsSpawnSandboxRecordHeader "$seatRecord" session-id )"
	[ -n "$seatSession" ] || return 0
	seatHolder="$( AgentsToolsSessionSeatTake "$seatSession" "$harnessAgent" "$seatRecord" )" || seatRc=$?
	[ "$seatRc" = "1" ] && [ -n "$seatHolder" ] || return 0
	printf '%s' "$seatHolder"
	return 1
}

## Whether the run that holds this run's seat is its restart: its record names this run as the
## one it restarts (`restarted-from:`). rc 0 it is.
AgentsHarnessSeatPassed(){ ## the holder's spawn id
	local passedRecord=""
	passedRecord="$( AgentsToolsSessionRunRecord "$1" )" || return 1
	[ "$( AgentsToolsSpawnSandboxRecordHeader "$passedRecord" restarted-from )" = "${MDAT_SPAWN_SESSION_ID:-}" ]
}

## Whether a served wait reads this run's session: with its default sources (its session thread
## and the threads it continues), with slack:session-current, or continuing its stored wait.
AgentsHarnessWaitReadsSession(){ ## sources, mode
	case "$2" in
		continue) return 0 ;;
		close) return 1 ;;
	esac
	[ -n "$1" ] || return 0
	case " $1 " in
		*" slack:$harnessCurrentName "*) return 0 ;;
	esac
	return 1
}

## Whether a dismissal of this run waits (AgentsToolsSessionDismissHeld): rc 0 it does, the
## participants of its session that still run printed on one line.
AgentsHarnessDismissWaits(){
	local waitsRecord="" waitsOthers=""
	waitsRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" )" && [ -n "$waitsRecord" ] || return 1
	type AgentsToolsSessionDismissHeld > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || return 1
	waitsOthers="$( AgentsToolsSessionDismissHeld "$waitsRecord" )" || return 1
	printf '%s' "$waitsOthers" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}

## A dismissal held while others of this run's session ran (AgentsToolsSessionDismissHold), given
## once it may be: kept as this run's dismissal, and printed as the Wait result it is, rc 0. rc 1
## where none is held, or where it still waits.
AgentsHarnessDismissHeldGive(){
	local giveFile giveBy="" giveHandback=""
	[ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && [ -n "${MMDAPP:-}" ] && AgentsHarnessBareName "$MDAT_SPAWN_SESSION_ID" || return 1
	giveFile="$MMDAPP/.local/agents/sessions/$MDAT_SPAWN_SESSION_ID/dismiss-held"
	[ -f "$giveFile" ] || return 1
	! AgentsHarnessDismissWaits > /dev/null || return 1
	{ IFS= read -r giveBy ; IFS= read -r giveHandback ; } < "$giveFile" || :
	AgentsHarnessDismissedKeep "${giveBy:-unknown}"
	[ "$giveHandback" != "handback-given" ] || : > "$( AgentsHarnessDismissedFile ).handback" 2> /dev/null || :
	rm -f "$giveFile"
	printf 'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: %s\n# held while other runs of this session ran, and given now that they have ended\n' "${giveBy:-unknown}"
	return 0
}

## The rest of a served wait of a run without its seat: it waits on through its stored wait until
## its bound, given nothing of its session, and a TIMEOUT says so as usual. A DISMISSED addressed
## to it still arrives, alone; one that waits (AgentsHarnessDismissWaits) is kept, and the wait goes on.
AgentsHarnessWaitSeatless(){ ## bound in seconds (empty: none), when the wait began (epoch seconds), the stored wait's session key
	local lessLeft="" lessRc lessBy=""
	while : ; do
		lessLeft=""
		if [ -n "$1" ] ; then
			lessLeft=$(( $2 + $1 - $( date +%s ) ))
			[ "$lessLeft" -gt 0 ] || break
		fi
		lessRc=0
		"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-wait-for-input "$harnessAgent" --wait-continue \
			${3:+--wait-session-id "$3"} ${lessLeft:+--wait-timeout "$lessLeft"} > "$harnessScratch/wait.out" 2> "$harnessScratch/wait.err" || lessRc=$?
		if [ "$lessRc" != "0" ] ; then
			printf 'ERROR: the wait could not be performed (rc=%s), so NOTHING is known about those sources. What the operation reported follows:\n' "$lessRc"
			cat "$harnessScratch/wait.err"
			return 0
		fi
		case "$( head -1 "$harnessScratch/wait.out" )" in
			"WAIT-RESULT: RECEIVED") ;;
			"WAIT-RESULT: TIMEOUT") break ;;
			*) cat "$harnessScratch/wait.out" ; return 0 ;;
		esac
		lessBy="$( dismissalMember="$harnessAgent" LC_ALL=C awk -f "$harnessHere/AgentsDismissalMatch.awk" -f "$harnessHere/AgentsHarnessWaitDismissed.awk" "$harnessScratch/wait.out" )" || continue
		if AgentsHarnessDismissWaits > /dev/null ; then
			AgentsToolsSessionDismissHold "$MDAT_SPAWN_SESSION_ID" "$lessBy"
			continue
		fi
		printf 'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: %s\n# given alone: this run does not hold its seat in its session\n' "$lessBy"
		AgentsHarnessDismissedKeep "$lessBy"
		printf 'NEXT: you are dismissed -- give your handback if you have not, then end your run\n'
		return 0
	done
	printf 'WAIT-RESULT: TIMEOUT (%ss) NEXT: Wait mode=continue\n' "$(( $( date +%s ) - $2 ))"
}

## The served SendMessage (AgentsHarnessToolSendMessage, `reply`): a post to this run's own session
## is its run's only where the run holds its member's seat there, taken by this post where nobody
## holds it (AgentsHarnessSeatTake). Otherwise the refusal is printed, naming the run that holds it,
## rc 0, and nothing is to be sent; rc 1 where the post may go. Every other send is as it was.
AgentsHarnessSendSeatRefused(){ ## target as given
	local seatedThread="" seatedHolder=""
	case "$1" in
		''|"$harnessCurrentName"|"$harnessCurrentName":*)
			seatedHolder="$( AgentsHarnessSeatTake )" || :
		;;
		*)
			seatedThread="$( AgentsHarnessSessionThread "$harnessCurrentName" 2> /dev/null )" || seatedThread=""
			[ -z "$seatedThread" ] || [ "$1" != "${seatedThread%% *}" ] || seatedHolder="$( AgentsHarnessSeatTake )" || :
		;;
	esac
	[ -n "$seatedHolder" ] || return 1
	printf 'ERROR: not sent: run %s holds the seat of %s in this session, and only the run that holds it posts there. Nothing was sent. This run goes on, and posts there once that run has ended.\n' "$seatedHolder" "$harnessAgent"
	return 0
}

## The wait happens HERE, in this process, inside one tool call: the model spends
## nothing while nothing is happening and its context does not grow, which is the
## whole reason this is a tool and not a loop of reads. Through the team's own
## long-poll operation and no other path -- no Slack call of this harness's own and
## no credential in argv; which input sources exist is that operation's business,
## never this file's. Output to a file rather than a capture: the operation drives
## reads that fork curl, and a capture returns on pipe EOF rather than on the
## process it ran.
##
## A wait that comes back with nothing is NOT an error and is never dressed as one:
## the operation's own WAIT-RESULT line is passed through untouched, so the model
## reads TIMEOUT and ERROR as the different things they are.
## A call naming a mode (arguments 7 to 11: mode, seen, note, done, wait) is a stateful wait kept per
## session; an internal caller passing six arguments or fewer gets today's stateless wait.
AgentsHarnessToolWait(){
	local toolSources="$1" toolTimeout="$2" toolPoll="$3" toolSince="$4" toolAddressee="$5" toolIncludeOwn="$6" waitRc=0 waitSource waitStateful="false" waitSession waitName waitThread
	local toolMode="${7:-}" toolSeen="${8:-}" toolNote="${9:-}" toolDone="${10:-}" toolWaitIds="${11:-}"
	## unwait names one source to drop from the stored wait on demand -- the same
	## kind:target (or slack:session-current/slack:session-parent alias) `sources`
	## takes, resolved the identical way, below, before this becomes a drop call
	## instead of a wait. Takes no timeout/poll/since/addressee/include-own: a
	## drop runs once and returns, like --wait-close already does.
	local toolUnwait="${13:-}" waitUnwaitMode="false"
	if [ -n "$toolUnwait" ] ; then
		waitUnwaitMode="true"
		toolSources="$toolUnwait"
	fi
	if [ $# -ge 7 ] ; then
		waitStateful="true"
		[ -n "$toolMode" ] || toolMode="default"
		case "$toolMode" in
			default|continue|close) ;;
			*) printf 'ERROR: mode must be default, continue or close, got: %s\n' "$toolMode" ; return 0 ;;
		esac
	fi
	## An asking call waits on this session's stored wait too (a twelfth argument, `ask`): the
	## same stateful round, given back as the operation printed it. What it means for the ask
	## and for whatever else arrived is that call's to say (AgentsHarnessAsk).
	local waitTool="$waitStateful"
	[ "${12:-}" != "ask" ] || waitTool="false"
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to wait as, and one is never guessed here. Nothing was waited on.%s\n' "${harnessAgentMissing:+ ($harnessAgentMissing)}" ; return 0
	fi
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other wait path exists here. Nothing was waited on.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	## A session that was dismissed does not wait again: every later Wait is that dismissal,
	## returned at once with the line that says what is left to do, so no wait keeps it alive.
	local waitDismissedEarlier=""
	if waitDismissedEarlier="$( AgentsHarnessDismissedBy )" ; then
		printf 'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: %s\n# this session was dismissed before this call, so nothing was waited on\n' "$waitDismissedEarlier"
		[ "$waitTool" != "true" ] || AgentsHarnessDismissedNext
		return 0
	fi
	## THE SEAT (F6.9), on the tool's own wait of a spawned run: a dismissal held while others of
	## its session ran is given once they have ended; a wait that reads its session takes its seat
	## there, or finds the run that holds it (waitSeatless); a run whose seat passed to the run that
	## restarts it is dismissed by the tooling.
	local waitRecord="" waitSeatless="" waitStarted="" waitHeldOthers=""
	waitStarted="$( date +%s )"
	[ "$waitTool" != "true" ] || waitRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" 2> /dev/null )" || waitRecord=""
	if [ -n "$waitRecord" ] ; then
		type AgentsToolsSessionSeatTake > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		if AgentsHarnessDismissHeldGive ; then
			AgentsHarnessDismissedNext
			return 0
		fi
		! AgentsHarnessWaitReadsSession "$toolSources" "$toolMode" || waitSeatless="$( AgentsHarnessSeatTake )" || :
		if [ -n "$waitSeatless" ] && AgentsHarnessSeatPassed "$waitSeatless" ; then
			printf 'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: tooling (the seat of this run in its session passed to %s, the run that restarts it)\n' "$waitSeatless"
			AgentsHarnessDismissedKeep "tooling (the seat of this run in its session passed to $waitSeatless, the run that restarts it)"
			AgentsHarnessDismissedNext
			return 0
		fi
	fi
	## The RETURN bound. A caller's own timeout is honoured, validated the way Bash validates
	## its own. With none, this harness waits until something arrives (empty is no bound),
	## and a served call returns by harnessServedWaitBound, safely under the client cutoff.
	## Either is cut down to a ceiling rather than refused: a bound that is too long is a
	## bound, and refusing it would turn a waitable question into an error.
	if [ -n "$toolTimeout" ] ; then
		if ! AgentsHarnessWholeNumber "$toolTimeout" ; then
			printf 'ERROR: timeout must be a whole number of seconds, got: %s\n' "$toolTimeout" ; return 0
		fi
	else
		toolTimeout="$harnessServedWaitBound"
	fi
	[ -z "$harnessServedWaitBound" ] || [ "$toolTimeout" -le "$harnessServedWaitBound" ] || toolTimeout="$harnessServedWaitBound"
	if [ -n "$harnessWaitTimeout" ] ; then
		[ -n "$toolTimeout" ] && [ "$toolTimeout" -le "$harnessWaitTimeout" ] || toolTimeout="$harnessWaitTimeout"
	fi
	## A session whose handback waits in review waits for its verdict at most REVIEW_WAIT_LIMIT
	## seconds (AgentsTools.ReviewFlow.include): bounded to what is left, and at the limit the
	## tooling ends it, recorded. The item stays in review. Only the tool's own stateful wait.
	## Nothing is loaded for a session with no spawn record, which has no item to review.
	if [ "$waitTool" = "true" ] && [ "${MDAT_SPAWN_CALLER_WAITS:-}" != "true" ] && [ -n "$( AgentsHarnessSessionKey )" ] \
		&& [ -n "$( ls "${MMDAPP:-/nonexistent}"/.local/agents/spawned/*/"$( AgentsHarnessSessionKey ).md" 2> /dev/null )" ] ; then
		local waitReviewLeft=""
		type AgentsReviewWaitLeft > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ReviewFlow.include" 2> /dev/null || :
		waitReviewLeft="$( AgentsReviewWaitLeft "$( AgentsHarnessSessionKey )" 2> /dev/null )" || waitReviewLeft=""
		case "$waitReviewLeft" in
			'') ;;
			expired)
				## The limit dismisses no run while another participant of its session runs (F6.9): the wait goes on.
				if [ -n "$waitRecord" ] && AgentsToolsSessionOthersRunning "$waitRecord" > /dev/null ; then
					waitReviewLeft=""
				else
					waitDismissedEarlier="$( AgentsReviewWaitExpire "${harnessAgent:-unknown}" "$( AgentsHarnessSessionKey )" 2> /dev/null )" || :
					[ -z "$waitDismissedEarlier" ] || printf '%s\n' "$waitDismissedEarlier"
					waitDismissedEarlier="$( printf '%s\n' "$waitDismissedEarlier" | LC_ALL=C sed -n 's/^WAIT-DISMISSED-BY: //p' | head -1 )"
					[ -z "$waitDismissedEarlier" ] || AgentsHarnessDismissedKeep "$waitDismissedEarlier"
					printf 'NEXT: you are dismissed -- end your run\n'
					return 0
				fi
			;;
			*) [ -n "$toolTimeout" ] && [ "$toolTimeout" -le "$waitReviewLeft" ] || toolTimeout="$waitReviewLeft" ;;
		esac
	fi
	if [ -n "$toolPoll" ] && ! AgentsHarnessWholeNumber "$toolPoll" ; then
		printf 'ERROR: poll_interval must be a whole number of seconds, got: %s\n' "$toolPoll" ; return 0
	fi
	if [ -n "$toolSince" ] ; then
		if ! AgentsHarnessWholeNumber "${toolSince%%.*}" ; then
			printf 'ERROR: since_utime must be epoch seconds, or a Slack message ts written <epoch>.<micros>, got: %s\n' "$toolSince" ; return 0
		fi
		if [ "$toolSince" != "${toolSince#*.}" ] && ! AgentsHarnessWholeNumber "${toolSince#*.}" ; then
			printf 'ERROR: since_utime must be epoch seconds, or a Slack message ts written <epoch>.<micros>, got: %s\n' "$toolSince" ; return 0
		fi
	fi
	## No source named: default to this session's own coworking thread and every
	## conversation thread it continues (AgentsToolsWaitDefaultSources), any post but
	## the caller's own. An ad-hoc/solo spawn holding none keeps today's default exactly
	## -- magic-team and human-owner, resolved below by --member-wait-for-input itself
	## from an empty sources list.
	if [ -z "$toolSources" ] && [ "$toolMode" != "continue" ] && [ "$toolMode" != "close" ] ; then
		type AgentsToolsWaitDefaultSources > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		local waitDefaultThread=""
		waitDefaultThread="$( AgentsToolsWaitDefaultSources 2>/dev/null )" || waitDefaultThread=""
		[ -z "$waitDefaultThread" ] || toolSources="$waitDefaultThread"
		## A thread source needs a floor. A stateful call leaves it to the operation, which resumes
		## from the floor stored for that thread, so nothing that arrived between two calls is
		## skipped; only the stateless internal call means "from now on".
		[ -z "$waitDefaultThread" ] || [ -n "$toolSince" ] || [ "$waitStateful" = "true" ] || toolSince="$( date +%s )"
	fi
	## slack:session-current and slack:session-parent each name that session's thread as a :conversation source, the values SendMessage to takes.
	for waitName in "$harnessCurrentName" "$harnessParentName" ; do
		case " $toolSources " in
			*" slack:$waitName "*)
				waitThread="$( AgentsHarnessSessionThread "$waitName" "Nothing was waited on." )" || { printf '%s\n' "$waitThread" ; return 0 ; }
				toolSources=" $toolSources "
				## The replacement stays bare: bash 3.2 keeps a quote written inside it as part of the source.
				toolSources="${toolSources/" slack:$waitName "/ slack:${waitThread%% *}:conversation }"
				[ -n "$toolSince" ] || [ "$waitStateful" = "true" ] || toolSince="$( date +%s )"
			;;
		esac
	done
	## unwait's own target was resolved by the same alias loop above (slack:session-
	## current/-parent included), so it reaches --unwait exactly as a plain source
	## would. One call, its own result printed as it comes back, never the rest of
	## this function's wait/mode handling below.
	if [ "$waitUnwaitMode" = "true" ] ; then
		waitSession="$( AgentsHarnessSessionKey )"
		set -- "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-wait-for-input "$harnessAgent" --unwait "$toolSources"
		[ -z "$waitSession" ] || set -- "$@" --wait-session-id "$waitSession"
		"$@" >"$harnessScratch/wait.out" 2>"$harnessScratch/wait.err" || waitRc=$?
		if [ "$waitRc" != "0" ] ; then
			printf 'ERROR: the unwait could not be performed (rc=%s). What the operation reported follows:\n' "$waitRc"
			cat "$harnessScratch/wait.err"
			return 0
		fi
		[ ! -s "$harnessScratch/wait.err" ] || cat "$harnessScratch/wait.err" >&2
		cat "$harnessScratch/wait.out"
		return 0
	fi
	## Built as argv, so a source naming a thread stays one token rather than a
	## quoted fragment, and an empty sources string adds no flag at all.
	set -- "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-wait-for-input "$harnessAgent"
	for waitSource in $toolSources ; do
		set -- "$@" --wait-source "$waitSource"
	done
	if [ "$waitStateful" = "true" ] ; then
		waitSession="$( AgentsHarnessSessionKey )"
		set -- "$@" "--wait-$toolMode"
		[ -z "$waitSession" ] || set -- "$@" --wait-session-id "$waitSession"
		[ -z "$toolSeen" ] || set -- "$@" --wait-react-seen "$toolSeen"
		[ -z "$toolNote" ] || set -- "$@" --wait-react-note "$toolNote"
		[ -z "$toolDone" ] || set -- "$@" --wait-react-done "$toolDone"
		[ -z "$toolWaitIds" ] || set -- "$@" --wait-react-wait "$toolWaitIds"
	fi
	[ -z "$toolTimeout" ] || set -- "$@" --wait-timeout "$toolTimeout"
	[ -z "$toolPoll" ] || set -- "$@" --wait-poll-interval "$toolPoll"
	[ -z "$toolSince" ] || set -- "$@" --wait-since-utime "$toolSince"
	[ -z "$toolAddressee" ] || set -- "$@" --wait-addressee "$toolAddressee"
	case "$toolIncludeOwn" in
		true|1|yes) set -- "$@" --wait-include-own ;;
	esac
	"$@" >"$harnessScratch/wait.out" 2>"$harnessScratch/wait.err" || waitRc=$?
	if [ "$waitRc" != "0" ] ; then
		printf 'ERROR: the wait could not be performed (rc=%s), so NOTHING is known about those sources -- this is not a wait that found nothing, and their silence must not be read as quiet. What the operation reported follows:\n' "$waitRc"
		cat "$harnessScratch/wait.err"
		return 0
	fi
	## What a wait that worked said on its stderr goes to this run's own log, never left in scratch.
	[ ! -s "$harnessScratch/wait.err" ] || cat "$harnessScratch/wait.err" >&2
	## A dismissal is a Wait outcome of its own: a message whose body is DISMISSED,
	## addressed to this member (AgentsHarnessWaitDismissed.awk). The spawner sends it when
	## it is satisfied; the waiting session ends with its handback on it. Everything the
	## wait returned still follows, so nothing it saw is hidden behind the outcome.
	local waitDismissedBy=""
	if [ "$( head -1 "$harnessScratch/wait.out" )" = "WAIT-RESULT: RECEIVED" ] \
		&& waitDismissedBy="$( dismissalMember="$harnessAgent" LC_ALL=C awk -f "$harnessHere/AgentsDismissalMatch.awk" -f "$harnessHere/AgentsHarnessWaitDismissed.awk" "$harnessScratch/wait.out" )" ; then
		## An executor is not dismissed while another participant of its session runs (F6.9): its
		## dismissal is kept, given at its first wait once they have ended, and this wait is what it got.
		if [ -n "$waitRecord" ] && waitHeldOthers="$( AgentsHarnessDismissWaits )" ; then
			AgentsToolsSessionDismissHold "$MDAT_SPAWN_SESSION_ID" "$waitDismissedBy"
		else
			printf 'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: %s\n' "$waitDismissedBy"
			## A run without its seat is given nothing of its session but its dismissal.
			[ -n "$waitSeatless" ] || tail -n +2 "$harnessScratch/wait.out"
			AgentsHarnessDismissedKeep "$waitDismissedBy"
			[ "$waitTool" != "true" ] || printf 'NEXT: you are dismissed -- give your handback if you have not, then end your run\n'
			return 0
		fi
	fi
	## A run without its seat is given nothing of its session: its wait goes on until its bound.
	if [ -n "$waitSeatless" ] && [ "$( head -1 "$harnessScratch/wait.out" )" = "WAIT-RESULT: RECEIVED" ] ; then
		AgentsHarnessWaitSeatless "$toolTimeout" "$waitStarted" "$waitSession"
		return 0
	fi
	## A TIMEOUT on the tool's own stateful wait is ONE line: every quiet result stays in the
	## model's context, and that it is normal is said once, in the tool description. Only a
	## source never read adds its WAIT-NEVER-READ line, since its silence means nothing.
	if [ "$waitTool" = "true" ] && [ "$( head -1 "$harnessScratch/wait.out" )" = "WAIT-RESULT: TIMEOUT" ] ; then
		printf 'WAIT-RESULT: TIMEOUT (%ss) NEXT: Wait mode=continue\n' "$( LC_ALL=C sed -n 's/^# waited: \([0-9]*\)s of .*/\1/p' "$harnessScratch/wait.out" | head -1 )"
		LC_ALL=C grep '^WAIT-NEVER-READ: ' "$harnessScratch/wait.out" || :
		return 0
	fi
	cat "$harnessScratch/wait.out"
	[ -z "$waitHeldOthers" ] || printf '# DISMISSED held: this run founded its session, where %s still run: the dismissal is given at its first Wait once they have ended\n' "$waitHeldOthers"
	## One extra last line naming the next call, on the tool's own stateful wait only: an internal
	## stateless caller (a tool that asks) embeds this output and has no stored wait to continue.
	[ "$waitTool" = "true" ] || return 0
	## An asked question's wait item that arrived is taken into its record here, as the asking call would.
	[ "$( head -1 "$harnessScratch/wait.out" )" != "WAIT-RESULT: RECEIVED" ] || AgentsHarnessWaitAskResolve "$harnessScratch/wait.out"
	case "$( head -1 "$harnessScratch/wait.out" )" in
		"WAIT-RESULT: RECEIVED") printf 'NEXT: if this is not what you are waiting for, call Wait mode=continue -- it resumes after what is shown here\n' ;;
	esac
}

## One line appended to the current session's transcript, by --member-append-session-transcript
## with no --transcript-name: the session decides the file. No session, nothing appended.
AgentsHarnessToolSessionTranscriptAppend(){ ## note
	local appendOut="" appendRc=0
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s. Nothing was appended.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	appendOut="$( MDAT_SPAWN_SESSION_ID="$( AgentsHarnessSessionKey )" "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" \
		--member-append-session-transcript "${harnessAgent:-unknown}" --message "$1" 2>&1 )" || appendRc=$?
	if [ "$appendRc" != "0" ] ; then
		appendOut="$( printf '%s\n' "$appendOut" | LC_ALL=C grep -F 'ERROR:' | tail -1 )"
		[ -n "$appendOut" ] || appendOut="ERROR: the append failed (rc=$appendRc). Nothing was appended."
		printf 'ERROR: %s\n' "${appendOut#*ERROR: }" ; return 0
	fi
	printf '%s\n' "$appendOut" | LC_ALL=C grep '^OK: ' | tail -1
}

## CheckList: the checklist of session tasks of a member in a session, kept as the native
## TodoWrite keeps its list -- a call with todos replaces the caller's whole list -- and read by a
## call with none: the caller's own list, or with member that participant's, or with `*` every
## participant's. One member, one list in a session, however many runs it has there:
## <member>.checklist.md, Markdown, one line an item, `- [x]` done, `- [ ]` not yet, the item in
## progress followed by its activeForm. Kept in the session's place (AgentsHarnessCheckListPlace).
## A participant writes its own list alone. Checked whole first, so a list with one bad item is
## refused and the list kept before stays as it was; written to a temp file mktemp names beside
## it and put in place by one rename, so no reader sees half a list.
AgentsHarnessToolCheckList(){ ## raw arguments
	local todoCount todoIndex=0 todoField todoWhere todoPending=0 todoActive=0 todoDone=0 todoFile todoText="" todoLine todoContent todoPathNo=0 todoTmp=""
	AgentsHarnessArgParse "$1"
	## No pre-requisites, no tool: a session whose member or place the harness does not know has none.
	if ! AgentsHarnessCheckListPlace ; then
		printf 'ERROR: %s Nothing was written.\n' "$checkListWhy" ; return 0
	fi
	if ! AgentsHarnessArgFind todos.__count ; then
		## A value that is there and is no list is told apart from no value at all, which reads.
		while [ "$todoPathNo" -lt "${#harnessArgPaths[@]}" ] ; do
			case "${harnessArgPaths[$todoPathNo]}" in
				todos|todos.*) printf 'ERROR: todos must be an array of items, each an object with content, status and activeForm. Nothing was written.\n' ; return 0 ;;
			esac
			todoPathNo=$(( todoPathNo + 1 ))
		done
		## Arguments that parsed to nothing are a read only where they are an empty object.
		if [ "${#harnessArgPaths[@]}" -eq 0 ] ; then
			case "$1" in
				*[!{}$' \t\r\n']*) printf 'ERROR: the arguments are no JSON object: give todos to write your own list, or no todos to read a list. Nothing was written.\n' ; return 0 ;;
			esac
		fi
		AgentsHarnessCheckListRead "${harnessArgV_member:-}"
		return 0
	fi
	if [ -n "${harnessArgV_member:-}" ] ; then
		printf 'ERROR: member reads a list and takes no todos, and you write only your own list: give todos, or member, not both. Nothing was written.\n' ; return 0
	fi
	todoCount="$harnessArgFound"
	case "$todoCount" in ''|*[!0123456789]*) printf 'ERROR: todos could not be read as a list. Nothing was written.\n' ; return 0 ;; esac
	while [ "$todoIndex" -lt "$todoCount" ] ; do
		todoWhere="todos item $(( todoIndex + 1 )) of $todoCount"
		for todoField in content status activeForm ; do
			if ! AgentsHarnessArgFind "todos.$todoIndex.$todoField" || [ -z "$harnessArgFound" ] ; then
				printf 'ERROR: %s: %s is required and must not be empty -- each item is an object with content, status and activeForm. Nothing was written.\n' "$todoWhere" "$todoField" ; return 0
			fi
		done
		AgentsHarnessArgFind "todos.$todoIndex.content" || :
		todoContent="$harnessArgFound"
		AgentsHarnessArgFind "todos.$todoIndex.status" || :
		case "$harnessArgFound" in
			pending) todoPending=$(( todoPending + 1 )) ; todoLine="- [ ] $todoContent" ;;
			in_progress)
				todoActive=$(( todoActive + 1 ))
				AgentsHarnessArgFind "todos.$todoIndex.activeForm" || :
				todoLine="- [ ] $todoContent (in progress: $harnessArgFound)"
			;;
			completed) todoDone=$(( todoDone + 1 )) ; todoLine="- [x] $todoContent" ;;
			*) printf 'ERROR: %s: status must be pending, in_progress or completed, got: %s. Nothing was written.\n' "$todoWhere" "$( AgentsHarnessTruncateArg "$harnessArgFound" )" ; return 0 ;;
		esac
		## One line an item: a line break or a tab inside a text is a space.
		todoText="$todoText${todoLine//[$'\n\r\t']/ }"$'\n'
		todoIndex=$(( todoIndex + 1 ))
	done
	todoFile="$checkListFolder/$checkListMember.checklist.md"
	if ! { mkdir -p "$checkListFolder" 2>/dev/null && todoTmp="$( mktemp "$todoFile.XXXXXX" 2>/dev/null )" \
		&& printf '%s' "$todoText" > "$todoTmp" 2>/dev/null && mv -f "$todoTmp" "$todoFile" 2>/dev/null ; } ; then
		[ -z "$todoTmp" ] || rm -f "$todoTmp" 2>/dev/null || :
		printf 'ERROR: the list could not be written to %s. Nothing was written.\n' "$todoFile" ; return 0
	fi
	printf 'OK: the checklist of %s in session %s now holds %s item(s): %s pending, %s in progress, %s completed. Kept in %s\n' \
		"$checkListMember" "$checkListSession" "$todoCount" "$todoPending" "$todoActive" "$todoDone" "${todoFile#"$MMDAPP"/}"
}

## Whether the harness knows the caller's checklist, and where: the member is the caller as the
## harness knows it; the session is the coworking session it works in (the one the spawn proxy
## named, else the one its own spawn record names, else its own); the place is the sandbox root
## of the spawn that founded the session, where a spawn founded it, else the session folder,
## sessions/<id>, where a root session founded it. Both are fixed from the session's start, so
## every run of every participant finds the one place. Sets checkListMember, checkListSession and
## checkListFolder; returns 1 with the refusal in checkListWhy where the member or the place is
## not known -- the tool is then not offered either.
checkListMember="" checkListSession="" checkListFolder="" checkListWhy=""
AgentsHarnessCheckListPlace(){
	local placeRecord=""
	checkListMember="" checkListSession="" checkListFolder="" checkListWhy=""
	if [ -z "$harnessAgent" ] ; then
		checkListWhy='this session has no team identity, so it has no checklist: CheckList is not offered to it.' ; return 1
	fi
	if [ -z "${MMDAPP:-}" ] ; then
		checkListWhy='MMDAPP is not set in this process, so no checklist has a place: CheckList is not offered here.' ; return 1
	fi
	checkListSession="${MDAT_SESSION_ID:-}"
	if [ -z "$checkListSession" ] && [ -n "${MDAT_SPAWN_SESSION_ID:-}" ] ; then
		placeRecord="$( AgentsHarnessSpawnRecordPath "$MDAT_SPAWN_SESSION_ID" )"
		[ -z "$placeRecord" ] || checkListSession="$( AgentsHarnessDispatchField "$placeRecord" session-id )"
	fi
	[ -n "$checkListSession" ] || checkListSession="$( AgentsHarnessSessionKey )"
	if [ -z "$checkListSession" ] ; then
		checkListWhy='this call belongs to no session, so there is no place for a checklist: CheckList is not offered to it.' ; return 1
	fi
	if ! AgentsHarnessBareName "$checkListSession" || [ "$checkListSession" = "." ] || [ "$checkListSession" = ".." ] ; then
		checkListWhy="the session id of this call is no bare name, so it names no place for a checklist: CheckList is not offered to it. The id: $( AgentsHarnessTruncateArg "$checkListSession" )."
		checkListSession="" ; return 1
	fi
	placeRecord="$( AgentsHarnessSpawnRecordPath "$checkListSession" )"
	if [ -n "$placeRecord" ] ; then
		checkListFolder="${placeRecord%/*}"
	else
		checkListFolder="$MMDAPP/.local/agents/sessions/$checkListSession"
	fi
	checkListMember="$harnessAgent"
	return 0
}

## The participants of the session with a known member name, sorted, one a line: the caller; the
## spawn records whose session-id is the session (the rows of the spawned-sessions registry,
## AgentsToolsRegistrySpawnedSessionsRows, read fresh); and the members whose list is kept in its
## place. Never a row with no member name.
AgentsHarnessCheckListMembers(){
	local membersFile membersName
	{
		printf '%s\n' "$checkListMember"
		( . "$harnessHere/AgentsTools.Registries.include" && AgentsToolsRegistrySpawnedSessionsRows 2> /dev/null ) \
			| LC_ALL=C awk -v session="$checkListSession" '$2 == session && $5 != "-" { print $5 ; }'
		for membersFile in "$checkListFolder"/*.checklist.md ; do
			[ -f "$membersFile" ] || continue
			membersFile="${membersFile##*/}"
			printf '%s\n' "${membersFile%.checklist.md}"
		done
	} | while IFS= read -r membersName ; do
		! AgentsHarnessBareName "$membersName" || printf '%s\n' "$membersName"
	done | LC_ALL=C sort -u
}

## A read: the caller's own list, one participant's by its member name, or with `*` every
## participant's, each under its member name, an empty one shown as empty. Writes nothing.
AgentsHarnessCheckListRead(){ ## member name, `*`, or empty for the caller's own
	local readWant="${1:-$checkListMember}" readMembers readName readCount=0 readOut=""
	readMembers="$( AgentsHarnessCheckListMembers )"
	if [ "$readWant" = "*" ] ; then
		while IFS= read -r readName ; do
			[ -n "$readName" ] || continue
			AgentsHarnessFileText "$checkListFolder/$readName.checklist.md"
			readOut="$readOut"$'\n\n'"## $readName (${checkListFolder#"$MMDAPP"/}/$readName.checklist.md)"$'\n'"${harnessFileText:-(empty)}"
			readCount=$(( readCount + 1 ))
		done <<< "$readMembers"
		printf 'CHECKLISTS of session %s: %s participant(s), each under its member name.%s\n' "$checkListSession" "$readCount" "$readOut"
		return 0
	fi
	case $'\n'"$readMembers"$'\n' in
		*$'\n'"$readWant"$'\n'*) ;;
		*)
			printf 'ERROR: %s is not a participant of session %s, so it has no checklist here. Its participants are: %s. Give one of them as member, or * for all. Nothing was written.\n' \
				"$( AgentsHarnessTruncateArg "$readWant" )" "$checkListSession" "$( printf '%s\n' "$readMembers" | LC_ALL=C awk 'NF { printf "%s%s", ( n++ ? ", " : "" ), $0 ; }' )"
			return 0
		;;
	esac
	AgentsHarnessFileText "$checkListFolder/$readWant.checklist.md"
	printf 'CHECKLIST of %s in session %s (%s):\n%s\n' "$readWant" "$checkListSession" "${checkListFolder#"$MMDAPP"/}/$readWant.checklist.md" "${harnessFileText:-(empty)}"
}

## Helpers behind Agent, TaskStop and TaskOutput. Deliberately NOT named
## AgentsHarnessTool*: that family is the static tool class AgentsHarnessSelfCheck.test.awk
## matches site by site, and a helper with no tool behind it is an orphan there.

## A value reaching a command line: one bare name, asked of the family's one bare-name gate
## (AgentsToolsAssertBareName, AgentsTools.BareName.include, which has no other effect), quietly.
AgentsHarnessBareName(){ ## candidate
	type AgentsToolsAssertBareName > /dev/null 2>&1 || . "$harnessHere/AgentsTools.BareName.include" 2> /dev/null || return 1
	AgentsToolsAssertBareName "$1" "a name" AgentsHarnessBareName 2> /dev/null
}

## Where the spawn proxy records a session: one dispatch item per spawn, in whichever
## board state holds it. Both handles taken here already exist -- the session id, which
## ListAgents prints, and the item filename, which Agent's result names -- so nothing
## mints an identifier of its own. Prints the item path, or nothing.
## With `every`, nothing is chosen for the caller: a filename prints as `file <path>`, and an
## id prints every item that names it, a line each, in board order. `own <path>`: the id is
## the item's spawn-id, its own run. `sole <path>`: the id is its session-id and it carries
## no spawn-id, written before the two were split, so that id is its own run too.
## `shared <path>`: the id is its session-id and its spawn-id is another, a participant of
## that session.
AgentsHarnessDispatchItemPath(){ ## handle, optional `every`
	local handleText="$1" dispatchState dispatchFile
	local dispatchFiles=()
	case "$handleText" in
		''|*/*|*..*) return 0 ;;
	esac
	for dispatchState in running pending review blocked parked processed archived retained backlog ; do
		[ -f "$MDAT_DATA_ROOT/board/$dispatchState/$handleText" ] || continue
		[ "${2:-}" != "every" ] || printf 'file '
		printf '%s' "$MDAT_DATA_ROOT/board/$dispatchState/$handleText"
		return 0
	done
	for dispatchState in running pending review blocked parked processed archived retained backlog ; do
		for dispatchFile in "$MDAT_DATA_ROOT"/board/"$dispatchState"/dispatch-*.md ; do
			[ -f "$dispatchFile" ] || continue
			dispatchFiles+=( "$dispatchFile" )
		done
	done
	[ "${#dispatchFiles[@]}" -gt 0 ] || return 0
	if [ "${2:-}" = "every" ] ; then
		## The first session-id and the first spawn-id of each frontmatter, compared as text.
		MDAT_HARNESS_WANT_ID="$handleText" LC_ALL=C awk '
			function itemSaid() {
				if ( itemFile == "" ) { return ; }
				if ( itemSpawn == wantId ) { print "own " itemFile ; }
				else if ( itemSession == wantId ) { print ( itemSpawn == "" ? "sole " : "shared " ) itemFile ; }
				itemFile = "" ;
			}
			BEGIN { wantId = ENVIRON["MDAT_HARNESS_WANT_ID"] "" ; }
			FNR == 1 { itemSaid() ; itemFile = FILENAME ; itemSpawn = "" ; itemSession = "" ; inFront = ($0 == "---") ; next ; }
			!inFront { next ; }
			$0 == "---" { inFront = 0 ; next ; }
			/^session-id:/ && itemSession == "" { itemSession = $0 ; sub(/^session-id:[ \t]*/, "", itemSession) ; itemSession = itemSession "" ; }
			/^spawn-id:/ && itemSpawn == "" { itemSpawn = $0 ; sub(/^spawn-id:[ \t]*/, "", itemSpawn) ; itemSpawn = itemSpawn "" ; }
			END { itemSaid() ; }
		' "${dispatchFiles[@]}"
		return 0
	fi
	## One pass over every candidate rather than one awk per file, and the id is matched
	## inside the frontmatter only, so a body quoting it is not a hit. The wanted value
	## travels in the environment: -v performs backslash decoding, ENVIRON does not.
	MDAT_HARNESS_WANT_ID="$handleText" LC_ALL=C awk '
		FNR == 1 { inFront = ($0 == "---") ; next ; }
		!inFront { next ; }
		$0 == "---" { inFront = 0 ; next ; }
		/^session-id:/ {
			idValue = $0
			sub(/^session-id:[ \t]*/, "", idValue)
			if (idValue == ENVIRON["MDAT_HARNESS_WANT_ID"]) { print FILENAME ; exit ; }
		}
	' "${dispatchFiles[@]}"
	return 0
}

## One frontmatter field of a dispatch item, or empty.
AgentsHarnessDispatchField(){ ## item path, field name
	MDAT_HARNESS_WANT_FIELD="$2" LC_ALL=C awk '
		NR == 1 { if ($0 != "---") exit ; next ; }
		$0 == "---" { exit ; }
		{
			fieldName = ENVIRON["MDAT_HARNESS_WANT_FIELD"]
			if (index($0, fieldName ":") == 1) {
				fieldValue = substr($0, length(fieldName) + 2)
				sub(/^[ \t]+/, "", fieldValue)
				print fieldValue
				exit
			}
		}
	' "$1" 2>/dev/null || :
}

## The items of a list of paths as one phrase, each by its filename, its owner and its
## spawn-id: for a refusal that asks its caller to name one of them.
AgentsHarnessDispatchItemsSaid(){ ## -- stdin: item paths, a line each
	local saidPath saidOwner saidSpawn saidText=""
	while IFS= read -r saidPath ; do
		[ -n "$saidPath" ] || continue
		saidOwner="$( AgentsHarnessDispatchField "$saidPath" owner )"
		saidSpawn="$( AgentsHarnessDispatchField "$saidPath" spawn-id )"
		saidText="$saidText${saidText:+, }${saidPath##*/} (${saidOwner:-<no owner>}, spawn-id ${saidSpawn:-<none>})"
	done
	printf '%s' "$saidText"
}

## The record of one spawn in this workspace's sandbox roots, by the spawn's own id: the file
## of that name that names the id as its spawn-id. Every spawn has one, with or without a
## dispatch item, and it is what ListAgents lists. Prints its path, or nothing.
AgentsHarnessSpawnRecordPath(){ ## spawn id
	local recordPath
	case "$1" in
		''|*/*|*..*) return 0 ;;
	esac
	[ -n "${MMDAPP:-}" ] || return 0
	for recordPath in "$MMDAPP/.local/agents/spawned"/*/"$1.md" ; do
		[ -f "$recordPath" ] || continue
		[ "$( AgentsHarnessDispatchField "$recordPath" spawn-id )" = "$1" ] || continue
		printf '%s' "$recordPath"
		return 0
	done
	return 0
}

## The output path the spawn proxy writes into a dispatch item when it CLOSES one.
## Empty while the session is still running, which is exactly when a caller wants it --
## hence the session log by spawn id, and the receipt derivation for an older log, beside it.
AgentsHarnessDispatchOutputFile(){ ## item path
	LC_ALL=C awk '
		index($0, "output-file:") == 1 {
			pathValue = substr($0, 13)
			sub(/^[ \t]+/, "", pathValue)
			if (pathValue != "") { print pathValue ; exit ; }
		}
	' "$1" 2>/dev/null || :
}

## The spawn proxy names its dispatch item and its output log from one receipt, so the
## log is reachable from the item name while the session still runs. This derivation is
## coupled to that naming; where it stops matching, the search below reports what it
## looked for rather than reporting the log absent.
AgentsHarnessDispatchReceipt(){ ## item filename
	local nameText="${1%.md}"
	case "$nameText" in
		dispatch-*-spawn-proxy-*) ;;
		*) return 0 ;;
	esac
	nameText="${nameText#dispatch-}"
	printf 'spawn-proxy-%s-%s' "${nameText%%-spawn-proxy-*}" "${nameText##*-spawn-proxy-}"
}

## The live processes that run as a spawn. The console passes --session-id to the CLI as
## this spawn's own id, so the spawn-id the dispatch item records is also an OS handle --
## which is what lets a stop reach a helper that is cooperating in no way.
## -ww defeats the width truncation that would otherwise cut the id off a long CLI line.
## For every caller alike, a stop that signals what this names and a read that only asks
## whether the run lives: only the processes that run as it, by the one rule a run is
## recognised by (AgentsToolsRegistryRunPids, AgentsTools.Registries.include), its own
## --session-id or --resume word matched whole. A line that merely holds the id, another
## participant's or the tooling's, is none of them: a process that waits on a session is
## never that session's run. `own-word` is still taken, and asks for nothing more.
AgentsHarnessSessionWordPids(){ ## session id, optional `own-word` (the reading every caller gets)
	type AgentsToolsRegistryRunPids > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null || return 0
	ps -A -ww -o pid=,args= 2>/dev/null | AgentsToolsRegistryRunPids "$1"
	return 0
}
## The live processes of one spawn. With `own-word`, as a stop asks, which signals what this
## names: the run's own processes and every process they started, to any depth, by the one
## walk the manager's kill uses too (AgentsToolsRegistryRunProcesses,
## AgentsTools.Registries.include): never a process that runs as another spawn, nor the shell
## that supervises one. Without it, as TaskOutput asks, which only reads whether the run
## lives: those that run as it by their own word, as above; where none does, the same walk,
## which then starts from the process the spawn's record names as the one its launch started.
## No asking process is named to the walk: a member may stop the run it stands under, as it
## always could.
AgentsHarnessSessionPids(){ ## session id, optional `own-word` (as above)
	local pidsFound
	if [ "${2:-}" != "own-word" ] ; then
		pidsFound="$( AgentsHarnessSessionWordPids "$1" )"
		if [ -n "$pidsFound" ] ; then
			printf '%s\n' "$pidsFound"
			return 0
		fi
	fi
	type AgentsToolsRegistryRunLeftKept > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null || return 0
	if [ "${2:-}" = "own-word" ] ; then
		## And what an earlier stop of this run signalled and left, kept in the run's store: it
		## stands under no process of the run any more, and is still the run's to end.
		{ AgentsToolsRegistryRunProcesses "$1" "" - ; AgentsToolsRegistryRunLeftKept "$1" ; } | LC_ALL=C awk '$1 != "" && ! pidSaid[$1]++ { print $1 ; }'
		return 0
	fi
	AgentsToolsRegistryRunProcesses "$1" "" -
	return 0
}

## What a stop is about to signal, each process with when it began, as it is kept until the
## stop reads what is left (AgentsToolsRegistryProcessesBegan). Loaded here, where it runs: the
## lookups of a stop run inside command substitutions, so what they load is gone with them.
AgentsHarnessStopKept(){ ## -- stdin: process ids, a line each
	type AgentsToolsRegistryProcessesBegan > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null || return 0
	AgentsToolsRegistryProcessesBegan
}

## Keeps in the run's own store what a stop signalled and found still there, for the next stop
## or kill of that run (AgentsToolsRegistryRunLeftKeep); with nothing given, nothing is kept
## any more. In a shell of its own: what it loads is not the harness's to hold.
AgentsHarnessStopKeep(){ ## session id, the process ids still there (may be empty)
	(
		type AgentsToolsRegistryRunLeftKeep > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null || exit 0
		AgentsToolsRegistryRunLeftKeep "$1" "$2"
	) > /dev/null 2>&1 || :
	return 0
}

## What is left of a run that a stop signalled: the processes it signalled that are still the
## processes they were, and whatever the run's walk gives now, read in the one place the
## manager's kill reads it too (AgentsToolsRegistryRunLeft, AgentsTools.Registries.include).
## No asking process is named, as for the walk above.
AgentsHarnessStopLeft(){ ## session id, the processes signalled as `<pid> <start>` lines (may be empty)
	if type AgentsToolsRegistryRunLeft > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" 2> /dev/null ; then
		AgentsToolsRegistryRunLeft "$1" "$2" -
		return 0
	fi
	AgentsHarnessSessionPids "$1" own-word
}

## Spawns a helper session through the team spawn operation this package owns, and
## returns at once rather than waiting: a spawn that blocks for the helper lifetime is
## not a spawn, and TaskOutput and TaskStop are how the caller follows up.
##
## --dispatch-doc:create is the whole point and is not optional here. It is what writes
## the board item carrying the session id, and that item is what TaskOutput resolves and
## what TaskStop acts on; ListAgents lists the spawn's sandbox, which the spawn creates too. A spawn made without it leaves a
## helper nothing can list, read or end, which is the failure this tool exists to close.
##
## The brief goes in on stdin, never argv, so no shell parses it. Output to a file
## rather than a capture: the operation backgrounds a child, and a capture returns on
## pipe EOF rather than on the command it ran.
AgentsHarnessToolAgent(){ ## agent name, prompt, cli service, session name or comment, session id to join, conversation threads, description (why this spawn is made), new session (true: a session of its own), settings workspace (the one named to pay for this spawn)
	local toolAgentName="$1" toolPrompt="$2" toolCliService="$3" toolSessionNameOrComment="$4" toolSessionId="$5" toolConversation="${6:-}" toolDescription="${7:-}" toolNewSession="${8:-}" toolSettingsWorkspace="${9:-}" toolConversationThread spawnRc=0
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to spawn under, and one is never guessed here. Nothing was spawned. Report this rather than working around it.%s\n' "${harnessAgentMissing:+ ($harnessAgentMissing)}" ; return 0
	fi
	if [ -z "$toolAgentName" ] || [ -z "$toolPrompt" ] ; then
		printf 'ERROR: both agent and prompt are required, and one of them was empty. Nothing was spawned.\n' ; return 0
	fi
	if ! AgentsHarnessBareName "$toolAgentName" ; then
		printf 'ERROR: agent must be a bare member name such as keeper-myx, got: %s. Nothing was spawned.\n' "$toolAgentName" ; return 0
	fi
	if [ -n "$toolCliService" ] && ! AgentsHarnessBareName "$toolCliService" ; then
		printf 'ERROR: cli_service must be a bare service name, got: %s. Nothing was spawned.\n' "$toolCliService" ; return 0
	fi
	if [ -n "$toolSettingsWorkspace" ] && ! AgentsHarnessBareName "$toolSettingsWorkspace" ; then
		printf 'ERROR: settings_workspace must be the bare name of a workspace, the last segment of its path, got: %s. Nothing was spawned.\n' "$toolSettingsWorkspace" ; return 0
	fi
	if [ -n "$toolSessionId" ] && ! AgentsHarnessBareName "$toolSessionId" ; then
		printf 'ERROR: session_id must be a bare id, the SESSION_ID= an earlier spawn printed, got: %s. Nothing was spawned.\n' "$toolSessionId" ; return 0
	fi
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other spawn path exists here. Nothing was spawned.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	set -- "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-agent-spawn-proxy "$toolAgentName" \
		--from-stdin --dispatch-doc:create --context Agent
	## The member this call is made as, which a session never spawned names nowhere in its
	## environment: kept on the spawn's record, so the handback of the helper has an addressee.
	set -- "$@" --calling-member "$harnessAgent"
	[ -z "$toolCliService" ] || set -- "$@" --spawn-cli-service "$toolCliService"
	## The workspace named to pay for this one spawn: looked up by the spawn itself, which refuses a name this machine does not know.
	[ -z "$toolSettingsWorkspace" ] || set -- "$@" --spawn-settings-workspace "$toolSettingsWorkspace"
	## The session that spawns is the coworking session, and the proxy decides which: the
	## one this caller is in, else this caller's own, whose thread the first helper opens
	## and every later one joins. This text titles that thread for the spawn that opens
	## it -- passed as a genuine argv token, never folded into any format string the proxy
	## builds from it.
	[ -z "$toolSessionNameOrComment" ] || set -- "$@" --session-name-or-comment "$toolSessionNameOrComment"
	## Asked for plainly: a separate session for this helper, with a thread of its own.
	case "$toolNewSession" in
		true|1|yes) set -- "$@" --session-new ;;
	esac
	## The caller's own words for what this spawn is for: kept on the spawn's records, and shown
	## on the first line of its start post. A genuine argv token, as the comment above is.
	[ -z "$toolDescription" ] || set -- "$@" --description "$toolDescription"
	## Joins an existing coworking session instead of starting one: the proxy
	## itself resolves the thread and refuses rather than starting a new
	## session silently when the id names none.
	[ -z "$toolSessionId" ] || set -- "$@" --session-id "$toolSessionId"
	## The conversation threads this spawn continues; the proxy validates each one.
	for toolConversationThread in $toolConversation ; do
		set -- "$@" --conversation "$toolConversationThread"
	done
	## The mechanical brief block -- tool-routing, read-and-obey, executors, invitees and
	## the open warnings -- is the tooling's to write, never the caller's to copy: the
	## standing default routine's block goes ahead of the prompt, unless the prompt already
	## opens with one. A member the block cannot be built for (no .armed.md, no template)
	## is still spawned, and the result says the block is missing.
	local toolBriefNote=""
	case "$toolPrompt" in
		"SPAWN-PREPARE-BRIEF: "*) ;;
		*)
			local toolBrief=""
			if toolBrief="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-spawn-prepare-brief "$toolAgentName" --routine-default ${toolCliService:+--cli-service "$toolCliService"} ${toolSettingsWorkspace:+--settings-workspace "$toolSettingsWorkspace"} --context Agent 2>"$harnessScratch/spawn-brief.err" )" && [ -n "$toolBrief" ] ; then
				toolPrompt="$toolBrief"$'\n\n'"$toolPrompt"
			else
				toolBriefNote="NOTE: the spawn brief block (tool-routing, read-and-obey) could not be built for $toolAgentName, so the prompt went in without it: $( head -1 "$harnessScratch/spawn-brief.err" 2>/dev/null )"
			fi
		;;
	esac
	printf '%s' "$toolPrompt" | "$@" >"$harnessScratch/spawn.out" 2>&1 || spawnRc=$?
	[ -z "$toolBriefNote" ] || printf '%s\n' "$toolBriefNote" >> "$harnessScratch/spawn.out"
	if [ "$spawnRc" != "0" ] ; then
		printf 'ERROR: the spawn failed (rc=%s) and NO helper session is running. What the operation reported follows:\n' "$spawnRc"
		cat "$harnessScratch/spawn.out"
		return 0
	fi
	printf 'Spawned as %s. The DISPATCH_ITEM value below is the handle TaskOutput and TaskStop take, and ListAgents lists this session while it runs. What the operation reported follows:\n' "$toolAgentName"
	cat "$harnessScratch/spawn.out"
}

## A bounded window over a file some other process is still writing, carrying its own
## denominator: the range shown AND the total so far, never a bare window. It extends
## the byte-cap shape AgentsHarnessToolBash already states rather than replacing it.
##
## It takes a path and nothing whatever about what wrote it, so a reader of any kind of
## detached child output can use it. That is deliberate: the windowed read is the part
## two such readers genuinely share, and it is factored out here so a second one need
## not restate it.
AgentsHarnessWindowedRead(){ ## path, byte offset, byte limit
	local readPath="$1" readOffset="$2" readLimit="$3" readTotal readStart readEnd
	readTotal="$( wc -c < "$readPath" | tr -d ' ' )"
	[ -n "$readLimit" ] || readLimit=100000
	if [ -z "$readOffset" ] ; then
		## No offset means the end of the log, which is what following a live child wants.
		readStart=$(( readTotal - readLimit ))
		[ "$readStart" -ge 0 ] || readStart=0
	else
		readStart="$readOffset"
	fi
	if [ "$readStart" -ge "$readTotal" ] ; then
		printf 'bytes %s-%s of %s so far: NOTHING NEW in this window -- the log has not grown past byte %s yet. That is a log with nothing further in it, never a log that has ended.\n' "$readStart" "$readStart" "$readTotal" "$readStart"
		return 0
	fi
	readEnd=$(( readStart + readLimit ))
	[ "$readEnd" -le "$readTotal" ] || readEnd="$readTotal"
	printf 'bytes %s-%s of %s so far' "$readStart" "$readEnd" "$readTotal"
	if [ "$readEnd" -lt "$readTotal" ] ; then
		printf ', %s further byte(s) ahead of this window -- call again with offset %s\n\n' "$(( readTotal - readEnd ))" "$readEnd"
	elif [ "$readStart" -gt 0 ] ; then
		printf ', the end of the log so far; the earlier %s byte(s) are not shown\n\n' "$readStart"
	else
		printf ', the whole log so far\n\n'
	fi
	tail -c +$(( readStart + 1 )) "$readPath" | head -c "$readLimit"
}

## Reads a helper session output with no cooperation from it and no effect on it: the
## spawn proxy redirects the child streams to a file on disk, so this is an ordinary
## windowed read of that file at any moment, running or finished.
##
## THREE OUTCOMES, worded so they cannot be confused, because reading them alike is the
## failure this tool exists to prevent. RUNNING: the session is still alive, and what it
## has written SO FAR follows -- a window that ends is never the session ending. EMPTY:
## the session is alive and has written nothing yet, which is not a session that
## produced nothing. FINISHED: its record is closed. Anything that could not be read is
## a stated ERROR instead, and is never dressed as a helper that was quiet.
AgentsHarnessToolTaskOutput(){ ## handle, byte offset, byte limit, output file
	local toolHandle="$1" toolOffset="$2" toolLimit="$3" toolOutputFile="$4"
	local itemPath itemName itemStatus sessionId receiptId logPath="" logHow="" logCandidate
	local liveNow="unknown" logTotal
	if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
		printf 'ERROR: MDAT_DATA_ROOT is not set in this process, so the dispatch records naming a helper session cannot be located. Nothing was read, and no output is implied to be absent.\n' ; return 0
	fi
	if [ -n "$toolOffset" ] && ! AgentsHarnessWholeNumber "$toolOffset" ; then
		printf 'ERROR: offset must be a whole number of bytes, got: %s\n' "$toolOffset" ; return 0
	fi
	if [ -n "$toolLimit" ] && { ! AgentsHarnessWholeNumber "$toolLimit" || [ "$toolLimit" -lt 1 ] ; } ; then
		printf 'ERROR: limit must be a whole number of bytes above zero, got: %s\n' "$toolLimit" ; return 0
	fi
	[ -n "$toolLimit" ] || toolLimit="$harnessReadCap"
	[ "$toolLimit" -le "$harnessReadCap" ] || toolLimit="$harnessReadCap"
	if [ -n "$toolOutputFile" ] ; then
		## Confined to the team data store and to the session logs the spawn proxy writes
		## (sessions/<spawn-id>/session.log): this parameter would otherwise be a read of
		## any path at all, around the access roots that bound Read, Glob and Grep.
		case "$toolOutputFile" in
			"$MDAT_DATA_ROOT"/*) ;;
			"${MMDAPP:-/nonexistent}"/.local/agents/sessions/*/session.log) ;;
			*)
				printf 'ERROR: output_file is accepted only inside the team data store at %s, or as a session log at %s/.local/agents/sessions/<session id>/session.log, and this one is neither: %s. Give the dispatch item name or the session id as handle instead.\n' "$MDAT_DATA_ROOT" "${MMDAPP:-<no MMDAPP>}" "$toolOutputFile" ; return 0
			;;
		esac
		case "$toolOutputFile" in
			*..*)
				printf 'ERROR: output_file may not step upward out of the team data store or the session logs: %s\n' "$toolOutputFile" ; return 0
			;;
		esac
		logPath="$toolOutputFile" ; logHow="the output_file given"
	else
		if [ -z "$toolHandle" ] ; then
			printf 'ERROR: handle is required: the session id, which ListAgents prints, or the dispatch item filename, which the Agent result names as DISPATCH_ITEM. Nothing was read.\n' ; return 0
		fi
		itemPath="$( AgentsHarnessDispatchItemPath "$toolHandle" )"
		if [ -z "$itemPath" ] ; then
			printf 'ERROR: no dispatch item matches handle %s in any board state under %s. A helper spawned WITHOUT a tracking document has no record here at all, so it cannot be reached by handle -- that is a property of how it was spawned, not a missing output.\n' "$toolHandle" "$MDAT_DATA_ROOT" ; return 0
		fi
		itemName="${itemPath##*/}"
		itemStatus="$( AgentsHarnessDispatchField "$itemPath" status )"
		## spawn-id is this process's own OS handle; session-id is the shared
		## coworking id since session-id and spawn-id were split apart, so an item
		## written before that carries no spawn-id and session-id is still its own.
		sessionId="$( AgentsHarnessDispatchField "$itemPath" spawn-id )"
		[ -n "$sessionId" ] || sessionId="$( AgentsHarnessDispatchField "$itemPath" session-id )"
		if [ -n "$sessionId" ] ; then
			if [ -n "$( AgentsHarnessSessionPids "$sessionId" )" ] ; then liveNow=yes ; else liveNow=no ; fi
		fi
		logPath="$( AgentsHarnessDispatchOutputFile "$itemPath" )"
		[ -z "$logPath" ] || logHow="the output-file the dispatch item records, which it writes only once the session closes"
		## While it runs: its session log, named by the spawn id the item records.
		if [ -z "$logPath" ] && [ -n "$sessionId" ] && [ -n "${MMDAPP:-}" ] && AgentsHarnessBareName "$sessionId" \
			&& [ -f "$MMDAPP/.local/agents/sessions/$sessionId/session.log" ] ; then
			logPath="$MMDAPP/.local/agents/sessions/$sessionId/session.log" ; logHow="the session log of spawn $sessionId"
		fi
		if [ -z "$logPath" ] ; then
			receiptId="$( AgentsHarnessDispatchReceipt "$itemName" )"
			if [ -z "$receiptId" ] ; then
				printf 'ERROR: dispatch item %s records no output-file and its name does not carry a spawn receipt, so its output log could not be located. Status recorded on the item: %s\n' "$itemName" "${itemStatus:-<none>}" ; return 0
			fi
			for logCandidate in "$MDAT_DATA_ROOT"/audit/*/"$receiptId".output.log ; do
				[ -f "$logCandidate" ] || continue
				## States only how the path was found. Whether the session is still open is
				## reported on its own line from a live reading, and a clause here that
				## could disagree with it would be worse than no clause at all.
				logPath="$logCandidate" ; logHow="derived from the spawn receipt $receiptId"
				break
			done
		fi
		if [ -z "$logPath" ] ; then
			printf 'ERROR: dispatch item %s was found, but no session log for spawn %s exists under %s/.local/agents/sessions, and no output log for receipt %s under %s/audit. Status recorded on the item: %s. The log is absent rather than unread.\n' "$itemName" "${sessionId:-<none>}" "${MMDAPP:-<no MMDAPP>}" "$receiptId" "$MDAT_DATA_ROOT" "${itemStatus:-<none>}" ; return 0
		fi
	fi
	if [ ! -f "$logPath" ] ; then
		printf 'ERROR: the output log named for this session does not exist: %s\n' "$logPath" ; return 0
	fi
	if [ ! -r "$logPath" ] ; then
		printf 'ERROR: the output log named for this session is not readable: %s\n' "$logPath" ; return 0
	fi
	logTotal="$( wc -c < "$logPath" | tr -d ' ' )"
	## The outcome first, on its own line, before anything that could be mistaken for it.
	if [ "$liveNow" = "yes" ] && [ "$logTotal" -eq 0 ] ; then
		printf 'OUTPUT-RESULT: EMPTY\n'
	elif [ "$liveNow" = "yes" ] ; then
		printf 'OUTPUT-RESULT: RUNNING\n'
	elif [ "$liveNow" = "no" ] ; then
		printf 'OUTPUT-RESULT: FINISHED\n'
	else
		printf 'OUTPUT-RESULT: UNKNOWN\n'
	fi
	printf 'Output log: %s\n' "$logPath"
	printf 'Located by: %s\n' "$logHow"
	[ -z "$itemName" ] || printf 'Dispatch item: %s, status %s\n' "$itemName" "${itemStatus:-<none>}"
	case "$liveNow" in
		yes) printf 'A process still carries this session id, so this log is STILL BEING WRITTEN: what follows is what exists so far, and its end is not the end of the work.\n' ;;
		no)  printf 'No process carries this session id any more, so this log is complete.\n' ;;
		*)   printf 'Whether a process still carries this session id could not be established, so it is NOT known whether this log is complete.\n' ;;
	esac
	if [ "$logTotal" -eq 0 ] ; then
		printf 'The log is zero bytes: this session has written NOTHING YET. That is an empty log, never a session that produced nothing.\n'
		return 0
	fi
	printf '\n'
	AgentsHarnessWindowedRead "$logPath" "$toolOffset" "$toolLimit"
}

## Ends a running helper session. The session id the dispatch item records is on the
## command line of the CLI the console started, so this reaches the process itself and
## needs nothing from the helper.
##
## TERM alone by default, and KILL only where the caller asks for it: a stop that
## escalates silently is a destructive default. Nothing is reported as stopped until
## the process list has been read AGAIN and the process is gone -- a signal delivered
## is not a process ended, and the two must never read alike.
##
## WHAT IS SIGNALLED IS KEPT, each process with when it began, and what is left is read by
## those processes themselves, beside the run's walk (AgentsHarnessStopLeft): a process the
## run started that ignores TERM outlives the run's own process, and no walk from the run
## leads to it any more. So it is said to be still running, and with force it gets the KILL.
## The same pid begun at another time is another process, and is never signalled for the first.
## What is still there when this call ends is kept in the run's own store (AgentsHarnessStopKeep),
## and the next stop of the run, or a kill of it, starts from that too: a call again with
## force, which the STILL-RUNNING result tells its caller to make, finds what this one left.
##
## ONLY THE RUN ASKED FOR IS SIGNALLED, WITH WHAT IT STARTED. Its process is found by the one
## rule a run is recognised by: its own --session-id or --resume word, or the process its spawn
## record names; never by the id standing somewhere on a command line, which every other
## participant of its session and the tooling hold too. With it go the processes it started, to
## any depth, and never one that runs as another spawn, nor the shell that supervises one
## (AgentsHarnessSessionPids). A filename is its item.
## An id is the run that has it as its own: the item that names it as spawn-id (or, written
## before session-id and spawn-id were split, as session-id alone); else, with no item of
## its own, the spawn record of that name, which is what says the id is a run of this
## workspace, and the stop is then recorded on no item, as the result says. An id that items
## name only as the session they joined is refused with those items listed, since nothing
## says which participant is meant; one that no item and no spawn record names is not
## reached, whatever process carries it.
AgentsHarnessToolTaskStop(){ ## handle, force, task_id, shell_id
	local toolHandle="${3:-${4:-$1}}" toolForce="$2"
	local itemPath itemName itemStatus sessionId stopPids stopPid stopKept="" survivors forceWanted=no
	local stopRecord stopItems stopNamed stopOf stopCloses="The dispatch item is closed by the spawn operation itself rather than here, so its status may still read as started for a moment."
	if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
		printf 'ERROR: MDAT_DATA_ROOT is not set in this process, so the dispatch records naming a helper session cannot be located. Nothing was signalled, and no session is implied to be absent.\n' ; return 0
	fi
	if [ -z "$toolHandle" ] ; then
		printf 'ERROR: task_id is required: the spawn-id of the run, which ListAgents prints, or the dispatch item filename, which the Agent result names as DISPATCH_ITEM. Nothing was signalled.\n' ; return 0
	fi
	case "$toolForce" in
		true|1|yes) forceWanted=yes ;;
	esac
	stopItems="$( AgentsHarnessDispatchItemPath "$toolHandle" every )"
	itemPath="$( printf '%s\n' "$stopItems" | LC_ALL=C sed -n 's/^file //p' )"
	if [ -z "$itemPath" ] ; then
		## The item of the run that has this id as its own, never the first that holds it.
		stopNamed="$( printf '%s\n' "$stopItems" | LC_ALL=C sed -n 's/^own //p' )"
		[ -n "$stopNamed" ] || stopNamed="$( printf '%s\n' "$stopItems" | LC_ALL=C sed -n 's/^sole //p' )"
		case "$stopNamed" in
			*'
'*)
				printf 'ERROR: %s dispatch item(s) name %s as their own run: %s. Pass the filename of the one to stop as task_id. Nothing was signalled.\n' "$( printf '%s\n' "$stopNamed" | LC_ALL=C grep -c . )" "$toolHandle" "$( printf '%s\n' "$stopNamed" | AgentsHarnessDispatchItemsSaid )" ; return 0
			;;
		esac
		itemPath="$stopNamed"
	fi
	if [ -z "$itemPath" ] ; then
		## No dispatch item of its own: the handle is a spawn's own id where a spawn record of
		## this workspace names it.
		stopRecord="$( AgentsHarnessSpawnRecordPath "$toolHandle" )"
		if [ -z "$stopRecord" ] ; then
			## Items that name it only as the session they joined: no run of its own.
			stopNamed="$( printf '%s\n' "$stopItems" | LC_ALL=C sed -n 's/^shared //p' )"
			if [ -n "$stopNamed" ] ; then
				printf 'ERROR: %s is the session id of %s dispatch item(s), and no item and no spawn record has it as its own run: %s. Pass the filename of the one to stop, or its spawn-id, as task_id. Nothing was signalled.\n' "$toolHandle" "$( printf '%s\n' "$stopNamed" | LC_ALL=C grep -c . )" "$( printf '%s\n' "$stopNamed" | AgentsHarnessDispatchItemsSaid )" ; return 0
			fi
			printf 'ERROR: no dispatch item matches handle %s in any board state under %s, and no spawn record under %s names it as its spawn-id. A run is reached by its dispatch item, or by the spawn-id ListAgents prints for it, and this handle is neither, so nothing was signalled.\n' "$toolHandle" "$MDAT_DATA_ROOT" "${MMDAPP:-<no MMDAPP>}/.local/agents/spawned" ; return 0
		fi
		itemStatus="$( AgentsHarnessDispatchField "$stopRecord" status )"
		sessionId="$toolHandle"
		stopOf="No dispatch item names session $sessionId as its own run, so there is no item to record a stop on. Its spawn record is $stopRecord"
		stopCloses="The spawn record is closed by the spawn operation itself rather than here, so its status may still read as started for a moment."
	else
		itemName="${itemPath##*/}"
		itemStatus="$( AgentsHarnessDispatchField "$itemPath" status )"
		## spawn-id is this process's own OS handle; session-id is the shared
		## coworking id since session-id and spawn-id were split apart, so an item
		## written before that carries no spawn-id and session-id is still its own.
		sessionId="$( AgentsHarnessDispatchField "$itemPath" spawn-id )"
		[ -n "$sessionId" ] || sessionId="$( AgentsHarnessDispatchField "$itemPath" session-id )"
		if [ -z "$sessionId" ] ; then
			printf 'ERROR: dispatch item %s carries no session-id, so there is no handle on any process and NOTHING was signalled. Status recorded on the item: %s\n' "$itemName" "${itemStatus:-<none>}" ; return 0
		fi
		stopOf="Dispatch item $itemName, session $sessionId"
	fi
	stopPids="$( AgentsHarnessSessionPids "$sessionId" own-word )"
	## What an ended run is said to be, by how it was found: a process that carried the session
	## id, or, for a CLI that is given no session word, the process the run was started as.
	local stopGone="the process list no longer carries that session id"
	[ -z "$stopPids" ] || [ -n "$( AgentsHarnessSessionWordPids "$sessionId" own-word )" ] || stopGone="the process this run was started as, which its spawn record names, is no longer running"
	if [ -z "$stopPids" ] ; then
		printf 'STOP-RESULT: NO-PROCESS\n%s, status %s.\nNo running process carries that session id, so nothing was signalled. Where the status above is a closed one this session had already finished; otherwise the record says running and no process matches it, which is UNKNOWN rather than stopped -- the session may have died without its record being closed, or its CLI may not carry the session id on its command line.\n' "$stopOf" "${itemStatus:-<none>}" ; return 0
	fi
	## The ordered ending recorded before the signal, in the item's Decisions and the session
	## transcript (AgentsTools.ReviewFlow.include); the stop itself stays this tool's. With no
	## item there is nowhere to record it, which the result says.
	[ -z "$itemPath" ] || "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-review-end "${harnessAgent:-unknown}" "$itemName" \
		--reason taskstop --no-dismiss > /dev/null 2>&1 || :
	stopKept="$( printf '%s\n' "$stopPids" | AgentsHarnessStopKept )" || stopKept=""
	for stopPid in $stopPids ; do
		kill -TERM "$stopPid" 2>/dev/null || :
	done
	sleep 2
	survivors="$( AgentsHarnessStopLeft "$sessionId" "$stopKept" )"
	AgentsHarnessStopKeep "$sessionId" "$survivors"
	if [ -z "$survivors" ] ; then
		printf 'STOP-RESULT: STOPPED\n%s.\nTERM was sent to pid(s) %s and %s.\n%s\n' "$stopOf" "$( printf '%s' "$stopPids" | tr '\n' ' ' )" "$stopGone" "$stopCloses" ; return 0
	fi
	if [ "$forceWanted" != "yes" ] ; then
		printf 'STOP-RESULT: STILL-RUNNING\n%s.\nTERM was sent to pid(s) %s and pid(s) %s are still running two seconds later. Nothing further was sent: KILL happens only when force is asked for. Call again with force set true to send it.\n' "$stopOf" "$( printf '%s' "$stopPids" | tr '\n' ' ' )" "$( printf '%s' "$survivors" | tr '\n' ' ' )" ; return 0
	fi
	for stopPid in $survivors ; do
		kill -KILL "$stopPid" 2>/dev/null || :
	done
	sleep 2
	survivors="$( AgentsHarnessStopLeft "$sessionId" "$stopKept" )"
	AgentsHarnessStopKeep "$sessionId" "$survivors"
	if [ -z "$survivors" ] ; then
		printf 'STOP-RESULT: KILLED\n%s.\nTERM did not end it, KILL was sent because force was asked for, and %s.\nA KILLed CLI reaps none of its own children, so anything it had started may still be running.\n' "$stopOf" "$stopGone" ; return 0
	fi
	printf 'STOP-RESULT: NOT-STOPPED\n%s.\nTERM and then KILL were both sent, and pid(s) %s are STILL present. This session was NOT stopped -- report it rather than working around it.\n' "$stopOf" "$( printf '%s' "$survivors" | tr '\n' ' ' )"
}

## The same windowed read as TaskOutput, pointed at the other kind of child: a shell
## job this process started, rather than a helper session carrying a dispatch document.
## The reading half is AgentsHarnessWindowedRead, shared rather than restated.
##
## LIFETIME is what the two kinds do NOT share, and it is decided the opposite way. A
## helper session has its own tracking document, its own identity and its own report
## path, so it legitimately outlives the run that spawned it. A shell job has none of
## those: its whole value is this agent reading it, and a deploy still running on real
## hosts with nobody reading it is the case this tool exists to prevent. So its pid is
## recorded where AgentsHarnessReapChildren already looks, while its log and cursor keep
## their own directory one level down, which that non-recursive glob does not reach.
##
## WHAT THAT REAPING ACTUALLY REACHES, measured rather than assumed: TERM goes to the
## wrapper recorded in the pid file, and a command that forked its own children leaves
## those orphaned -- a `sleep 25` outlived the run it was started in. That is the
## PID-versus-process-group limit `magic-developer`'s own shell reference already states
## for this hand-rolled shape. The tool says so rather than promising a lifetime it does
## not enforce; a process-group signal is a separate change to a shared mechanism.
##
## FOUR OUTCOMES, the same words TaskOutput uses, because they are the same states.
## There is no UNKNOWN one here: the job is this process's own child, so whether it is
## alive is always readable rather than inferred.
AgentsHarnessToolMonitor(){ ## command, cwd, handle, byte offset, byte limit
	local toolCommand="$1" toolCwd="$2" toolHandle="$3" toolOffset="$4" toolLimit="$5"
	local monitorLog monitorPid monitorAlive monitorStatus monitorTotal
	if [ -n "$toolCommand" ] ; then
		if ! AgentsHarnessPathAllowed "$toolCwd" ; then
			printf 'ERROR: cwd not in the allowed access-root set: %s. Nothing was started.\n' "$toolCwd" ; return 0
		fi
		toolCwd="$harnessResolvedPath"
		if [ ! -d "$toolCwd" ] ; then
			printf 'ERROR: no such directory: %s. Nothing was started.\n' "$toolCwd" ; return 0
		fi
		if ! mkdir -p "$harnessScratch/monitor" ; then
			printf 'ERROR: could not create the monitor state directory under %s, so no job could be registered. Nothing was started.\n' "$harnessScratch" ; return 0
		fi
		harnessMonitorCount=$(( harnessMonitorCount + 1 ))
		toolHandle="job-$harnessMonitorCount"
		printf '%s' "$toolCommand" > "$harnessScratch/monitor/$toolHandle.cmd"
		: > "$harnessScratch/monitor/$toolHandle.log"
		: > "$harnessScratch/monitor/$toolHandle.cursor"
		## Redirected to a file and detached from this function's own capture pipe, never
		## captured: a command substitution returns when that pipe has no writers left, so
		## a child still holding it would hold this call open for the job's whole life.
		## The status is written by the job itself, because nothing else can read it -- a
		## `wait` here would block for exactly as long as the job runs.
		## The eval gets a subshell of its own so that an `exit` inside the command ends
		## THAT shell rather than this one: measured, a command ending in `exit 7` otherwise
		## takes the status write with it, and the job then reads as having recorded no
		## status at all -- a failure dressed as an unknown. The inner form is Bash's own,
		## so the same command run either way behaves the same.
		( monitorStatus=0 ; ( cd "$toolCwd" && set -e && eval "$toolCommand" ) || monitorStatus=$? ; printf '%s\n' "$monitorStatus" > "$harnessScratch/monitor/$toolHandle.status" ) \
			< /dev/null > "$harnessScratch/monitor/$toolHandle.log" 2>&1 &
		## Beside run.pid and watch.pid, so the one cleanup at EXIT reaches this too.
		printf '%s\n' "$!" > "$harnessScratch/monitor-$toolHandle.pid"
		printf 'MONITOR-RESULT: EMPTY\nMonitor handle: %s\nCommand: %s\nIn: %s\nThe job is RUNNING and has written nothing yet. Whatever it writes reaches you AUTOMATICALLY at the start of your following turns, in order from its first byte, with nothing skipped -- carry on with other work and react when it arrives. Read it sooner by calling Monitor with handle %s. When this run ends the job is signalled, but a command that forked its own children may leave those running, so do not leave it unattended.\n' \
			"$toolHandle" "$toolCommand" "$toolCwd" "$toolHandle"
		return 0
	fi
	if [ -z "$toolHandle" ] ; then
		printf 'ERROR: give command and cwd to start a job, or handle to read one already started. Neither was given, so nothing was started and nothing was read.\n' ; return 0
	fi
	case "$toolHandle" in
		job-[0-9]*) ;;
		*)
			printf 'ERROR: handle must be one a Monitor start returned, such as job-1, and this is not one: %s. Nothing was read.\n' "$toolHandle" ; return 0
		;;
	esac
	monitorLog="$harnessScratch/monitor/$toolHandle.log"
	if [ ! -f "$monitorLog" ] ; then
		printf 'ERROR: no background job named %s was started in this run, so there is no log to read. This is a handle naming nothing, never a job that produced nothing.\n' "$toolHandle" ; return 0
	fi
	if [ -n "$toolOffset" ] && ! AgentsHarnessWholeNumber "$toolOffset" ; then
		printf 'ERROR: offset must be a whole number of bytes, got: %s\n' "$toolOffset" ; return 0
	fi
	if [ -n "$toolLimit" ] && { ! AgentsHarnessWholeNumber "$toolLimit" || [ "$toolLimit" -lt 1 ] ; } ; then
		printf 'ERROR: limit must be a whole number of bytes above zero, got: %s\n' "$toolLimit" ; return 0
	fi
	[ -n "$toolLimit" ] || toolLimit="$harnessReadCap"
	[ "$toolLimit" -le "$harnessReadCap" ] || toolLimit="$harnessReadCap"
	monitorTotal="$( wc -c < "$monitorLog" | tr -d ' ' )"
	monitorPid=""
	read -r monitorPid < "$harnessScratch/monitor-$toolHandle.pid" 2>/dev/null || monitorPid=""
	if [ -n "$monitorPid" ] && kill -0 "$monitorPid" 2>/dev/null ; then
		monitorAlive=yes
	else
		## Dropped once the job is gone, so the one cleanup cannot signal a pid the system
		## has since handed to something else.
		monitorAlive=no
		rm -f "$harnessScratch/monitor-$toolHandle.pid"
	fi
	if [ "$monitorAlive" = yes ] && [ "$monitorTotal" -eq 0 ] ; then
		printf 'MONITOR-RESULT: EMPTY\n'
	elif [ "$monitorAlive" = yes ] ; then
		printf 'MONITOR-RESULT: RUNNING\n'
	else
		printf 'MONITOR-RESULT: FINISHED\n'
	fi
	printf 'Monitor handle: %s\nCommand: %s\n' "$toolHandle" "$( cat "$harnessScratch/monitor/$toolHandle.cmd" )"
	if [ "$monitorAlive" = yes ] ; then
		printf 'This job is STILL RUNNING, so this log is STILL BEING WRITTEN: what follows is what exists so far, and its end is not the end of the work.\n'
	elif [ -f "$harnessScratch/monitor/$toolHandle.status" ] ; then
		printf 'This job has ENDED with exit status %s, so this log is complete.\n' "$( cat "$harnessScratch/monitor/$toolHandle.status" )"
	else
		printf 'This job is no longer running and recorded NO exit status, so it was killed or died before it could write one. The log is complete; whether the work finished is NOT known from it.\n'
	fi
	if [ "$monitorTotal" -eq 0 ] ; then
		printf 'The log is zero bytes: this job has written NOTHING YET. That is an empty log, never a job that produced nothing.\n'
		return 0
	fi
	printf '\nOutput from several targets arrives INTERLEAVED in this one stream. A line belongs to whichever target that line itself names, never to the target named by an earlier line.\n\n'
	AgentsHarnessWindowedRead "$monitorLog" "$toolOffset" "$toolLimit"
}

## What makes Monitor a monitor rather than a poll. Called once per round, immediately
## before the request body is frozen, it returns whatever every registered job has
## written since the last round, or nothing at all. So the model never has to remember
## to ask, and a deploy failing at minute one reaches it on the next round instead of
## at minute nine.
##
## The cursor starts at byte zero and only ever moves forward, so a window is never a
## tail: the beginning of a failing deploy cannot be skipped, which is the specific way
## a silent tail turns three failed hosts into a clean ending.
##
## It stops at a line boundary. A line split across two rounds is exactly how one host's
## error gets attributed to another host, because the half naming the host and the half
## carrying the error arrive in different turns.
AgentsHarnessMonitorSpool(){
	local spoolLog spoolHandle spoolCursor spoolTotal spoolAvail spoolSpan spoolCut spoolPid
	for spoolLog in "$harnessScratch"/monitor/*.log ; do
		[ -f "$spoolLog" ] || continue
		spoolHandle="${spoolLog##*/}" ; spoolHandle="${spoolHandle%.log}"
		spoolCursor=""
		read -r spoolCursor < "${spoolLog%.log}.cursor" 2>/dev/null || spoolCursor=""
		case "$spoolCursor" in ''|*[!0-9]*) spoolCursor=0 ;; esac
		spoolTotal="$( wc -c < "$spoolLog" | tr -d ' ' )"
		spoolAvail=$(( spoolTotal - spoolCursor ))
		[ "$spoolAvail" -gt 0 ] || continue
		## One round's share, so a job writing faster than the model reads cannot take
		## the whole window. What is left over is not lost: the cursor holds it for the
		## next round, and Monitor with a handle reads it now.
		[ "$spoolAvail" -le 20000 ] || spoolAvail=20000
		## Bytes up to and including the last newline in that span. awk cannot see whether
		## its input ended with a newline, so the sum of each record plus its terminator is
		## compared against the span: one byte over means the final record was unterminated,
		## and that partial line is held back rather than delivered cut.
		spoolSpan="$( tail -c +$(( spoolCursor + 1 )) "$spoolLog" | head -c "$spoolAvail" | LC_ALL=C awk -v span="$spoolAvail" 'BEGIN{ sumBytes = 0 ; lastLen = 0 ; } { sumBytes += length($0) + 1 ; lastLen = length($0) ; } END{ if ( sumBytes == span + 1 ) { print sumBytes - 1 - lastLen ; } else { print sumBytes ; } }' )"
		spoolCut=""
		if [ "$spoolSpan" -eq 0 ] ; then
			## No complete line yet, so nothing is said this round -- except where one line
			## is longer than a whole window, which would otherwise stall forever. There the
			## window is taken at the cap and says that it cut a line.
			[ "$spoolAvail" -ge 20000 ] || continue
			spoolSpan="$spoolAvail"
			spoolCut=yes
		fi
		spoolPid=""
		read -r spoolPid < "$harnessScratch/monitor-$spoolHandle.pid" 2>/dev/null || spoolPid=""
		printf 'Background job %s, which you started with Monitor, has written more output while you were working. You did not ask for this. Nothing has been skipped: it arrives in order from the first byte, one piece per turn, so you can react before the job ends.\n' "$spoolHandle"
		printf 'Command: %s\n' "$( cat "${spoolLog%.log}.cmd" )"
		if [ -n "$spoolPid" ] && kill -0 "$spoolPid" 2>/dev/null ; then
			printf 'State: RUNNING -- this job is still going, so the end of this window is NOT the end of the work, and more follows on your next turn.\n'
		elif [ -f "${spoolLog%.log}.status" ] ; then
			printf 'State: FINISHED, exit status %s.\n' "$( cat "${spoolLog%.log}.status" )"
		else
			printf 'State: FINISHED with NO exit status recorded, so it was killed or died before writing one. Whether its work completed is NOT known from this log.\n'
		fi
		printf 'Output from several targets arrives INTERLEAVED in this one stream. A line belongs to whichever target that line itself names, never to the target named by an earlier line.\n'
		[ -z "$spoolCut" ] || printf 'NOTE: one line is longer than this whole window, so this window CUTS IT IN HALF and the remainder follows next turn. Do not read the cut end as the end of that line.\n'
		printf '\n'
		AgentsHarnessWindowedRead "$spoolLog" "$spoolCursor" "$spoolSpan"
		printf '\n'
		printf '%s\n' "$(( spoolCursor + spoolSpan ))" > "${spoolLog%.log}.cursor"
	done
}

## The body of one report tool: the block of its own name in the report template
## (sh-lib/templates/report.post.format.md), filled by the filler the ask posts use. The
## fields travel in the caller's environment, as ASKP_F_<slot>, and are placed by position,
## never read as a pattern or a format. A field with no value leaves its label out, as the
## template's `[[ … ]]` says: a label printed over an empty value is worse than its absence,
## since it asserts the writer considered that field and had nothing, which is exactly what
## an omission must never be read as. Prints the body; non-zero, with the reason in
## report-post.err, when the template could not fill it.
AgentsHarnessFormalBody(){ ## block `<Section>/<heading>`
	AgentsHarnessAskPost || return 3
	ASKP_BLOCK="$1" AgentsToolsAskPostFill block report.post.format.md "" 2> "$harnessScratch/report-post.err"
}

## The task a report belongs to, as it stands under the report's `Task` label: the task of
## this session in words, from the board item its spawn was dispatched for
## (AgentsTools.TaskText.include, the one piece of code that says a task in words), with the
## names of that item after the words, and under them the task as the call itself gave it,
## which a handback alone does (`# Lines`, task, in the report template). Where the session
## has no such item it is the call's own words alone, and nothing where the call gave none:
## the label is then left out. Run in the caller's command substitution, so what it loads
## stays there. It never fails a report.
AgentsHarnessReportTask(){ ## the task as the call gave it (may be empty)
	local reportSession reportItem="" reportPath="" reportTask="" reportTitle="" reportName reportNames=""
	reportSession="$( AgentsHarnessSessionKey )"
	if [ -n "$reportSession" ] && [ -n "${MDAT_DATA_ROOT:-}" ] ; then
		type AgentsToolsDecisionsItemFromRef > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ItemDecisions.include" 2> /dev/null || :
		type AgentsToolsTaskText > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.TaskText.include" 2> /dev/null || :
		if type AgentsToolsDecisionsItemFromRef > /dev/null 2>&1 && type AgentsToolsTaskText > /dev/null 2>&1 ; then
			reportItem="$( AgentsToolsDecisionsItemFromRef "" "$reportSession" 2> /dev/null )" || reportItem=""
			[ -z "$reportItem" ] || reportPath="$( AgentsToolsDecisionsItemPath "$reportItem" 2> /dev/null )" || reportPath=""
			[ -z "$reportPath" ] || reportTask="$( AgentsToolsTaskText "$reportPath" )"
			reportTitle="$( AgentsToolsTaskTextValue "$reportTask" title )"
			for reportName in "$( AgentsToolsTaskTextValue "$reportTask" item )" "$( AgentsToolsTaskTextValue "$reportTask" dispatch )" ; do
				[ -z "$reportName" ] || reportNames="$reportNames${reportNames:+ · }\`$reportName\`"
			done
		fi
	fi
	if [ -n "$reportTitle" ] ; then
		ASKP_F_task_title="$reportTitle" ASKP_F_task_names="$reportNames" ASKP_F_task_given="${1:-}" AgentsHarnessFormalBody "Lines/task" && return 0
	fi
	printf '%s' "${1:-}"
}

## What a report tool returns when its body could not be filled: nothing was sent.
AgentsHarnessFormalUnfilled(){ ## tool name
	printf 'ERROR: %s: the post could not be filled from its template, so nothing was sent. What the fill reported follows:\n%s\n' "$1" "$( cat "$harnessScratch/report-post.err" 2>/dev/null )"
}

## The exact inverse of AgentsTools.InternOpPermission.include's
## AgentsToolsPermissionEscapeRecord, applied when a refused call's target is read
## back out of the record. The record serialises %, newline, CR and edge whitespace
## as %XX so it stays one safe line. Reading the target back materialises the
## natural value again, and this is that step. % is decoded last, after every other code, so a %25 that
## reconstructs a literal "%" can never land in front of two hex digits left
## from another code and be misread as one. Any other %XX, or a bare %, is not
## one of this escaper's own codes and passes through exactly as given.
AgentsHarnessRefusedTargetDecode(){ ## value
	local decValue="$1"
	decValue="${decValue//%0A/$'\n'}"
	decValue="${decValue//%0D/$'\r'}"
	decValue="${decValue//%20/ }"
	decValue="${decValue//%09/$'\t'}"
	decValue="${decValue//%25/%}"
	printf '%s' "$decValue"
}

## The four report tools below are SendMessage with a fixed shape and NOT a second
## delivery path -- one mechanism, four stubs over it, which is the shape the
## specification asks for. This is the one place that shape is applied: the target
## check, the identity rule and the send itself are written once rather than four
## times, and each stub owns only its own field validation: its body is the block of its
## own name in the report template (AgentsHarnessFormalBody). Deliberately NOT
## named AgentsHarnessTool*: that family is the static tool class
## AgentsHarnessSelfCheck.test.awk matches site by site, and a helper with no tool behind it
## is reported there as an orphan.
AgentsHarnessFormalSend(){ ## tool name, target, as_bot, body text, optional next (see AgentsHarnessToolSendMessage), optional address to (who the post is for, as SendMessage takes it)
	local formalName="$1" formalTo="$2" formalAsBot="$3" formalBody="$4"
	if [ -z "$formalTo" ] ; then
		printf 'ERROR: %s: to is required and was empty, so there is nowhere to post it. Nothing was sent.\n' "$formalName" ; return 0
	fi
	AgentsHarnessToolSendMessage "$formalTo" "$formalBody" "$formalAsBot" "${6:-}" "" "" "${5:-}"
}

## Where this run reports to (AgentsToolsRunRoute), from its own spawn record: printed, rc 0.
## Nothing, rc 1, for a session with no spawn record of its own.
AgentsHarnessReportsTo(){
	local reportsRecord=""
	reportsRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" )" && [ -n "$reportsRecord" ] || return 1
	type AgentsToolsRunRoute > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || return 1
	AgentsToolsRunRoute "$reportsRecord" 2> /dev/null
}

## Whether this run reports to no one, as its own spawn record says it (`none` is only ever written
## there): rc 0 it does. Asks the record alone, no reading of who is alive, so it is cheap to ask.
AgentsHarnessReportsNone(){
	local noneRecord=""
	noneRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" )" && [ -n "$noneRecord" ] || return 1
	type AgentsToolsSpawnSandboxRecordHeader > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || return 1
	[ "$( AgentsToolsSpawnSandboxRecordHeader "$noneRecord" "$agentsRunRouteField" )" = none ]
}

## Who a handback is for where its call names nobody: the caller, the member that made the
## spawn call this session was started by, as the spawn records name it (AgentsToolsSessionParentMember). Prints
## nothing where no record names it, where it is this member itself, or where the member
## send would not take the name as an addressee: a default never fails a handback.
AgentsHarnessCallerMember(){
	local callerMember=""
	type AgentsToolsSessionParentMember > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
	type AgentsToolsTeamMemberDirectory > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.TeamRegistry.include" 2> /dev/null || :
	type AgentsToolsSessionParentMember > /dev/null 2>&1 && type AgentsToolsTeamMemberDirectory > /dev/null 2>&1 || return 0
	callerMember="$( AgentsToolsSessionParentMember 2> /dev/null )" || return 0
	## The bare name the member send itself holds an addressee to.
	case "$callerMember" in .|..|-*) return 0 ;; esac
	AgentsHarnessBareName "$callerMember" && [ "$callerMember" != "$harnessAgent" ] || return 0
	AgentsToolsTeamMemberDirectory "$callerMember" > /dev/null 2>&1 || return 0
	printf '%s' "$callerMember"
}

## Posting a handback does not end this run and releases nobody waiting on it -- the
## description says so, because a model reading otherwise stops working mid-task.
AgentsHarnessToolSubagentHandback(){
	local toolTo="${1:-$harnessParentName}" toolTask="$2" toolOutcome="$3" toolFindings="$4" toolUnfinished="$5" toolAsBot="$6" toolAddressTo="${7:-}" toolBody
	if [ -z "$toolOutcome" ] ; then
		printf 'ERROR: SubagentHandback: outcome is required and was empty. A handback carrying no outcome reports nothing, so nothing was sent.\n' ; return 0
	fi
	## A handback to the parent goes where this run reports to (AgentsToolsRunRoute): a session's
	## thread, which session-parent resolves; a member's own conversation, addressed to it; for
	## a person, the human-owner's conversation, addressed to him; for a run that reports to no
	## one, its own session thread, as its report. A session with no spawn record of its own has
	## no address, and session-parent stays as the one address resolver says it.
	local toolRoute=""
	## Loaded here, in this shell: the reading below runs in a subshell of its own.
	type AgentsToolsRunRouteKind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
	toolRoute="$( AgentsHarnessReportsTo )" || toolRoute=""
	if [ "$toolTo" = "$harnessParentName" ] && [ -n "$toolRoute" ] ; then
		case "$( AgentsToolsRunRouteKind "$toolRoute" 2> /dev/null )" in
			none) toolTo="$harnessCurrentName" ;;
			member) toolTo="$toolRoute" ; [ -n "$toolAddressTo" ] || toolAddressTo="$toolRoute" ;;
			person) toolTo="human-owner" ; [ -n "$toolAddressTo" ] || toolAddressTo="human-owner" ;;
		esac
	fi
	## A handback into a session thread that names nobody is for the caller. One into a
	## conversation the call names keeps the addressee that conversation gives it.
	if [ -z "$toolAddressTo" ] ; then
		case "$toolTo" in
			"$harnessParentName"|"$harnessCurrentName") toolAddressTo="$( AgentsHarnessCallerMember )" ;;
		esac
	fi
	## Answers to this session's questions nobody waited on are collected by the tooling
	## before it hands back, so none is left unread (AgentsTools.PendingReplyCollect.include).
	local toolCollected="" toolCollectSession
	toolCollectSession="$( AgentsHarnessSessionKey )"
	if [ -n "$toolCollectSession" ] ; then
		toolCollected="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-pending-reply-collect \
			--session-id "$toolCollectSession" --context SubagentHandback 2>/dev/null | LC_ALL=C grep -v '^COLLECT: ' )" || toolCollected=""
	fi
	toolBody="$( ASKP_F_task="$( AgentsHarnessReportTask "$toolTask" )" ASKP_F_outcome="$toolOutcome" ASKP_F_findings="$toolFindings" ASKP_F_unfinished="$toolUnfinished" ASKP_F_collected="$toolCollected" ASKP_F_address_to="$toolAddressTo" \
		AgentsHarnessFormalBody "Skeleton/SubagentHandback" )" || { AgentsHarnessFormalUnfilled SubagentHandback ; return 0 ; }
	rm -f "$harnessScratch/send.out" "$harnessScratch/send.delivered"
	## Its own words are the outcome, the findings and what is unfinished: the task as given is
	## carried, and the answers collected are the tooling's.
	harnessSendProse="$( AgentsHarnessSendProse "$toolOutcome" "$toolFindings" "$toolUnfinished" )" \
	AgentsHarnessFormalSend SubagentHandback "$toolTo" "$toolAsBot" "$toolBody" handback "$toolAddressTo"
	## A run that reports to no one ends on its report, whatever it reports: marked as a dismissed
	## run whose handback is given, so the harness ends it once this call is over
	## (AgentsHarnessDismissedAfter). Its report moves nothing to review.
	if [ "$toolRoute" = none ] && [ -f "$harnessScratch/send.delivered" ] ; then
		## One that founded its session ends once the others of it have ended (F6.9): kept until then.
		if AgentsHarnessDismissWaits > /dev/null ; then
			AgentsToolsSessionDismissHold "$MDAT_SPAWN_SESSION_ID" "tooling (this run reports to no one, and its report is given)" handback-given
			rm -f "$harnessScratch/send.delivered"
			return 0
		fi
		AgentsHarnessDismissedKeep "tooling (this run reports to no one, and its report is given)"
		: > "$( AgentsHarnessDismissedFile ).handback" 2> /dev/null || :
		rm -f "$harnessScratch/send.delivered"
		return 0
	fi
	## A delivered handback of a session that was dismissed is the one its run ends on: marked
	## here, read by AgentsHarnessDismissedAfter once this call is over.
	if [ -f "$harnessScratch/send.delivered" ] && AgentsHarnessDismissedBy > /dev/null ; then
		: > "$( AgentsHarnessDismissedFile ).handback" 2> /dev/null || :
	fi
	## A delivered handback, posted to Slack or left in the caller's inbox, moves the session's
	## own item running -> review once, recorded in its Decisions and transcript
	## (AgentsTools.ReviewFlow.include). A failed one moves nothing. Silent, and never fails the call.
	[ -n "$toolCollectSession" ] && [ -f "$harnessScratch/send.delivered" ] || return 0
	rm -f "$harnessScratch/send.delivered"
	"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-review-handback "$harnessAgent" --session-id "$toolCollectSession" \
		--message "$( printf '%s' "$toolOutcome" | LC_ALL=C tr '\n' ' ' | cut -c1-200 )" > /dev/null 2>&1 || :
}

AgentsHarnessToolReportFindings(){
	local toolTo="$1" toolSubject="$2" toolFindings="$3" toolEvidence="$4" toolConfidence="$5" toolAsBot="$6" toolAddressTo="${7:-}" toolBody
	if [ -z "$toolSubject" ] || [ -z "$toolFindings" ] ; then
		printf 'ERROR: ReportFindings: both subject and findings are required, and one of them was empty. Nothing was sent.\n' ; return 0
	fi
	toolBody="$( ASKP_F_task="$( AgentsHarnessReportTask )" ASKP_F_subject="$toolSubject" ASKP_F_findings="$toolFindings" ASKP_F_evidence="$toolEvidence" ASKP_F_confidence="$toolConfidence" ASKP_F_address_to="$toolAddressTo" \
		AgentsHarnessFormalBody "Skeleton/ReportFindings" )" || { AgentsHarnessFormalUnfilled ReportFindings ; return 0 ; }
	harnessSendProse="$( AgentsHarnessSendProse "$toolSubject" "$toolFindings" "$toolEvidence" "$toolConfidence" )" \
	AgentsHarnessFormalSend ReportFindings "$toolTo" "$toolAsBot" "$toolBody" "" "$toolAddressTo"
}

AgentsHarnessToolPushNotification(){
	local toolTo="$1" toolSeverity="$2" toolHeadline="$3" toolDetail="$4" toolAction="$5" toolAsBot="$6" toolAddressTo="${7:-}" toolBody toolMark
	if [ -z "$toolHeadline" ] ; then
		printf 'ERROR: PushNotification: headline is required and was empty. Nothing was sent.\n' ; return 0
	fi
	## Enumerated, never defaulted: an unrecognised severity quietly rendered as info is
	## a real alert delivered as a note, which is the one failure this field prevents.
	case "$toolSeverity" in
		info|warn|alert) ;;
		*)
			printf 'ERROR: PushNotification: severity must be info, warn or alert, got: %s. Nothing was sent, because guessing it would deliver an alert as a note.\n' "${toolSeverity:-<none>}" ; return 0
		;;
	esac
	## Its title is the template's own, by its severity (`# Severity`).
	toolMark="$( AgentsHarnessFormalBody "Severity/$toolSeverity" )" || toolMark=""
	toolBody="$( ASKP_F_task="$( AgentsHarnessReportTask )" ASKP_F_severity="$toolMark" ASKP_F_headline="$toolHeadline" ASKP_F_detail="$toolDetail" ASKP_F_action_required="$toolAction" ASKP_F_address_to="$toolAddressTo" \
		AgentsHarnessFormalBody "Skeleton/PushNotification" )" || toolBody=""
	[ -n "$toolMark" ] && [ -n "$toolBody" ] || { AgentsHarnessFormalUnfilled PushNotification ; return 0 ; }
	harnessSendProse="$( AgentsHarnessSendProse "$toolHeadline" "$toolDetail" "$toolAction" )" \
	AgentsHarnessFormalSend PushNotification "$toolTo" "$toolAsBot" "$toolBody" "" "$toolAddressTo"
}

## Announces a document. With url it announces one that already exists, and publishes
## nothing; announcing a link nobody can open is worse than not announcing it, so the URL is
## checked first. With file the tooling publishes it first (AgentsHarnessArtifactPublish).
AgentsHarnessToolArtifact(){
	local toolTo="$1" toolUrl="$2" toolTitle="$3" toolKind="$4" toolSummary="$5" toolAsBot="$6" toolFile="${7:-}" toolArgsRaw="${8:-}" toolAddressTo="${9:-}" toolBody
	if [ -n "$toolFile" ] ; then
		AgentsHarnessArtifactPublish || return 0
	fi
	case "$toolUrl" in
		http://*|https://*) ;;
		*)
			printf 'ERROR: Artifact: url must be the absolute http:// or https:// URL of a document that already exists, got: %s. Nothing was sent, and nothing was published -- give file instead to publish a document first.\n' "${toolUrl:-<none>}" ; return 0
		;;
	esac
	## A document announced with no title takes the template's own word for one (`# Words`, untitled).
	[ -n "$toolTitle" ] || toolTitle="$( AgentsHarnessFormalBody "Words/untitled" )" || toolTitle=""
	toolBody="$( ASKP_F_task="$( AgentsHarnessReportTask )" ASKP_F_title="$toolTitle" ASKP_F_kind="$toolKind" ASKP_F_url="$toolUrl" ASKP_F_summary="$toolSummary" ASKP_F_address_to="$toolAddressTo" \
		AgentsHarnessFormalBody "Skeleton/Artifact" )" || toolBody=""
	[ -n "$toolTitle" ] && [ -n "$toolBody" ] || { AgentsHarnessFormalUnfilled Artifact ; return 0 ; }
	AgentsHarnessFormalSend Artifact "$toolTo" "$toolAsBot" "$toolBody" "" "$toolAddressTo"
}

## The publish half of Artifact, outside the AgentsHarnessTool* family (no tool of its own).
## It reads and sets the caller toolUrl, toolTitle and toolKind, and returns 1 having said
## why when nothing is to be posted. A publish is outward-facing, so it is the one gated
## Artifact call: the session Artifact permission on the target `publish`, then a read of
## every file, since publishing sends it out. The tooling does the rest as this member
## (--intern-artifact-publish, AgentsTools.InternArtifact.include).
AgentsHarnessArtifactPublish(){
	local pubTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" pubSession pubArgs=() pubPath pubCount pubIndex=0 pubRc=0
	if [ -n "$toolUrl" ] ; then
		printf 'ERROR: Artifact: give url to announce a document that exists, or file to publish one, not both. Nothing was sent, and nothing was published.\n' ; return 1
	fi
	if [ -z "$toolTo" ] || [ -z "$toolTitle" ] ; then
		printf 'ERROR: Artifact: to and title are both required to publish, and one was empty. Nothing was published.\n' ; return 1
	fi
	if [ -z "$harnessAgent" ] || [ ! -x "$pubTools" ] ; then
		printf 'ERROR: Artifact: this run has no team identity or no tooling, so it cannot publish. Nothing was published.\n' ; return 1
	fi
	if ! AgentsHarnessGranted Artifact publish ; then
		AgentsHarnessRefusal Artifact publish "ERROR: Artifact: publishing needs the Artifact permission, which this member does not hold in this session. Nothing was published."
		return 1
	fi
	AgentsHarnessReadGate Read "$toolFile" || return 1
	pubArgs+=( --document "$harnessResolvedPath" )
	pubCount="$( AgentsHarnessArgValue "$toolArgsRaw" files.__count )"
	if [ -z "$pubCount" ] && [ -n "$( AgentsHarnessArgValue "$toolArgsRaw" files )" ] ; then
		printf 'ERROR: Artifact: files must be an array of absolute paths, got a single value. Nothing was published.\n' ; return 1
	fi
	case "$pubCount" in ''|*[!0123456789]*) pubCount=0 ;; esac
	while [ "$pubIndex" -lt "$pubCount" ] ; do
		pubPath="$( AgentsHarnessArgValue "$toolArgsRaw" "files.$pubIndex" )"
		AgentsHarnessReadGate Read "$pubPath" || return 1
		pubArgs+=( --file "$harnessResolvedPath" )
		pubIndex=$(( pubIndex + 1 ))
	done
	[ -z "$toolKind" ] || pubArgs+=( --kind "$toolKind" )
	pubSession="$( AgentsHarnessSessionKey )"
	[ -z "$pubSession" ] || pubArgs+=( --session-id "$pubSession" )
	"$BASH" "$pubTools" --intern-artifact-publish "$harnessAgent" --title "$toolTitle" "${pubArgs[@]}" \
		> "$harnessScratch/artifact.out" 2> "$harnessScratch/artifact.err" < /dev/null || pubRc=$?
	toolUrl="$( LC_ALL=C sed -n 's/^ARTIFACT_URL=//p' "$harnessScratch/artifact.out" | head -1 )"
	if [ "$pubRc" != 0 ] ; then
		printf 'ERROR: Artifact: the publish did not complete (rc=%s), so nothing was posted.%s What the tooling said:\n' "$pubRc" "${toolUrl:+ The document exists at $toolUrl: once it is complete, announce it with url, never publish it again.}"
		LC_ALL=C grep -v '^# ' "$harnessScratch/artifact.err" 2>/dev/null | head -20
		return 1
	fi
	toolTitle="$( LC_ALL=C sed -n 's/^ARTIFACT_TITLE=//p' "$harnessScratch/artifact.out" | head -1 )"
	toolKind="$( LC_ALL=C sed -n 's/^ARTIFACT_KIND=//p' "$harnessScratch/artifact.out" | head -1 )"
	printf 'PUBLISHED: %s at %s -- if the post below failed, announce it with url, never publish it again.\n' "$toolTitle" "$toolUrl"
	return 0
}

## Composed from the two tools it is built on and nothing else: the question goes out
## through AgentsHarnessToolSendMessage and the wait is AgentsHarnessToolWait over the
## same target. THE OUTCOME LINE IS THIS TOOL'S WHOLE CONTRACT. POSTED, RECEIVED,
## TIMEOUT and an ERROR must never read alike, because what to do next differs for all
## four -- and above all a question that was never posted must never look like one
## nobody answered. Both call sites capture rather than stream, which is safe because
## each of those functions already redirects its own child to a file: nothing the send
## or the wait forks holds this capture pipe open.
## The pending-reply store is the tooling's, reached the way this harness reaches all
## tooling: through an intern op, never by writing that store's files from here. One
## place records a posted question for every path that can ask one -- this harness's own
## tools that ask (AskQuestion, ConfirmReadback, EscalateDecision, RequestPermission, and
## their second name AskUserQuestion), their stubs in the myx.distro MCP, and a claude-native
## AskUserQuestion the hook reroutes to them -- because they all arrive at this function.
##
## Neither helper can fail this tool. A question that was genuinely asked must be
## reported as asked even where recording it did not work, so a failure here degrades
## to no record and a warning, never to a wrong outcome line.
AgentsHarnessPendingReplyOpen(){ ## conversation id, question body, then the typed-question metadata: kind, address_to, channel, question ts, thread ts, addressees, asking accounts, refusal id, options, then the thread tag and the question key, then as bot (true: posted under the bot identity), then the task_ref the item is found by, then the reason, then the answer form (select), then the fields the post was filled with, then the live version where the first post is not it (the reply a proposal is)
	local openTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" openId="" openSession openIdentity="member"
	[ -x "$openTools" ] || return 0
	[ -n "$harnessAgent" ] || return 0
	openSession="$( AgentsHarnessSessionKey )"
	## Kept on the record, so the tooling's reminders post under the identity the question did.
	case "${14:-}" in
		true|1|yes) openIdentity="bot" ;;
	esac
	openId="$( printf '%s' "$2" | "$BASH" "$openTools" --intern-op-pending-reply-open "$harnessAgent" \
		--to "$1" \
		${openSession:+--session-id "$openSession"} \
		${3:+--kind "$3"} ${4:+--address-to "$4"} ${5:+--channel "$5"} ${6:+--question-ts "$6"} ${7:+--thread-ts "$7"} \
		${8:+--addressees "$8"} ${9:+--asking-accounts "$9"} ${10:+--refusal-id "${10}"} ${11:+--options "${11}"} \
		${12:+--question-tag "${12}"} ${13:+--question-key "${13}"} ${15:+--task-ref "${15}"} ${16:+--reason "${16}"} --ask-identity "$openIdentity" \
		${17:+--select "${17}"} ${18:+--fields "${18}"} ${19:+--revision-ts "${19}"} \
		--context "$harnessAskName" 2>"$harnessScratch/pending-open.err" )" || openId=""
	if [ -z "$openId" ] ; then
		printf 'WARNING: %s: the question was posted but NOT recorded as a pending reply, so nothing will resume or re-ask it later. What the operation reported follows:\n' "$harnessAskName" >&2
		cat "$harnessScratch/pending-open.err" >&2 2>/dev/null || :
		return 0
	fi
	printf '%s\n' "$openId"
}

AgentsHarnessPendingReplyClose(){ ## pending reply id, status, optional verdict, optional ts of the reply taken as the answer, optional answerer
	local closeTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	[ -n "$1" ] || return 0
	[ -x "$closeTools" ] || return 0
	## Only while still open: a record another closer (a collect, a settle) closed first is left as it is.
	local closeRc=0
	"$BASH" "$closeTools" --intern-op-pending-reply-close "$1" --if-open --status "$2" ${3:+--verdict "$3"} ${4:+--answer-ts "$4"} ${5:+--answered-by "$5"} --context "$harnessAskName" >/dev/null 2>&1 || closeRc=$?
	case "$closeRc" in
		0|3) ;;
		*) printf 'WARNING: %s: pending reply %s could not be closed as %s, so it still reads as waiting.\n' "$harnessAskName" "$1" "$2" >&2 ;;
	esac
	return 0
}

## Before a question is posted: the answer it already has, from this session's closed asks or
## its item's `## Decisions`, read by the pending-reply store's own op. Prints the whole
## ASK-RESULT block and rc 0 when one is found, so the caller posts nothing; rc 1 otherwise.
AgentsHarnessAskEarlier(){ ## kind, question, question key, address_to, refusal id, task ref
	local earlyTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" earlyFound earlyId earlyAnswer
	[ -x "$earlyTools" ] && [ -n "$harnessAgent" ] || return 1
	earlyFound="$( printf '%s' "$2" | "$BASH" "$earlyTools" --intern-op-pending-reply-earlier "$harnessAgent" --session-id "$( AgentsHarnessSessionKey )" \
		--kind "$1" ${3:+--question-key "$3"} ${4:+--address-to "$4"} ${5:+--refusal-id "$5"} ${6:+--task-ref "$6"} 2>/dev/null \
		| LC_ALL=C grep -m1 -E '^EARLIER-(RECORD|DECISION) ' )" || earlyFound=""
	[ -n "$earlyFound" ] || return 1
	printf 'ASK-RESULT: RECEIVED\n'
	case "$earlyFound" in
		'EARLIER-RECORD '*)
			earlyId="${earlyFound#EARLIER-RECORD }" ; earlyId="${earlyId%% | *}"
			## A plain question carries a verdict only where it had an answer form (select).
			AgentsHarnessEscalationRead "$earlyId" | LC_ALL=C grep -E '^(VERDICT|VERDICT-TEXT|ANSWERED-BY|GRANT): ' || :
			printf 'NOT ASKED AGAIN: this session already asked the same question as pending reply %s, and it is answered, so nothing was posted. The earlier answer, as `EARLIER-RECORD <id> | <answer> | <answered-by> | <answered-at>`:\n%s\n' "$earlyId" "$earlyFound"
		;;
		*)
			if [ "$1" != "question" ] ; then
				earlyAnswer="${earlyFound##* -> }" ; earlyAnswer="${earlyAnswer% (*}"
				printf 'VERDICT: %s\n' "${earlyAnswer%% *}"
				case "$earlyAnswer" in *' -- '*) printf 'VERDICT-TEXT: %s\n' "${earlyAnswer#* -- }" ;; esac
			fi
			printf 'NOT ASKED AGAIN: the Decisions of the task item already answer this question, so nothing was posted. Decisions are binding. The line, as `EARLIER-DECISION <item> | <line>`:\n%s\n' "$earlyFound"
		;;
	esac
	return 0
}

## What the read of an answer kept beside it that the wait's own rendering does not hold: a
## message he posted between the two reads. The read keeps it on the record and watches the
## thread from it on, so no later Wait brings it: it is given with the answer, as the read
## worded it. $1: what the wait returned.
AgentsHarnessAskLaterSaid(){
	local saidLine saidTs
	LC_ALL=C grep '^CLARIFICATION: ' "$harnessScratch/escalation-read.out" 2> /dev/null | while IFS= read -r saidLine ; do
		saidTs="${saidLine#CLARIFICATION: }" ; saidTs="${saidTs%% *}"
		printf '%s\n' "$1" | LC_ALL=C grep -q -F -- "$saidTs | " || printf '%s\n' "$saidLine"
	done
	return 0
}

## A typed question's verdict, read and applied by the team's escalation operation.
## Prints its result lines; nothing at all when there is no record to read.
AgentsHarnessEscalationRead(){ ## pending reply id
	[ -n "$1" ] && [ -n "$harnessAgent" ] || return 0
	"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-escalation-read "$harnessAgent" "$1" \
		> "$harnessScratch/escalation-read.out" 2> /dev/null || :
	LC_ALL=C grep -E '^(ESCALATION|VERDICT|VERDICT-TEXT|VERDICT-REASON|ANSWERED-BY|GRANT|CHANGE|WAITING-ON|UNREADABLE-REASON): ' "$harnessScratch/escalation-read.out" 2>/dev/null || :
}

## The answers a wait returned on a question, without the wait's own lines: the section
## between its source markers where it has them, else every line that is no wait line.
## Inside the section a line is the wait's own by where it stands, never by what it starts
## with, since a person writes lines that start with `# ` too. There is one: the last, where
## the probe says the record is closed (AgentsWaitProbeAsk), naming the record by its id.
AgentsHarnessAskAnswerBody(){ ## wait output, pending reply id
	case "$1" in
		*"# --- what that source holds now follows ---"*)
			printf '%s\n' "$1" | MDAT_ASK_CLOSED_LINE="# pending reply ${2:-} is closed: " LC_ALL=C awk '
				function lastLine() { if ( heldAny && index( heldLine, ENVIRON["MDAT_ASK_CLOSED_LINE"] ) != 1 ) { print heldLine ; } heldAny = 0 ; }
				$0 == "# --- what that source holds now follows ---" { inBody = 1 ; heldAny = 0 ; next ; }
				$0 == "# --- end ---" { lastLine() ; inBody = 0 ; next ; }
				inBody { if ( heldAny ) { print heldLine ; } heldLine = $0 ; heldAny = 1 ; }
				END { if ( inBody ) { lastLine() ; } }'
		;;
		*) printf '%s\n' "$1" | LC_ALL=C grep -v -E '^(# |WAIT-|NEXT: |ASK-RESULT: )' || : ;;
	esac
}

## The answers a wait returned, as their writers' own words: the send header a member's reply
## starts with is taken off (AgentsPendingReplyOwnWords.awk) on the way to the readers that
## keep what a reply says, so it is never kept as an answer or as a clarification.
AgentsHarnessAskOwnWords(){ ## stdin: the answers
	LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsDismissalMatch.awk" -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsPendingReplyOwnWords.awk" 2>/dev/null
}

## Keeps clarification lines ("<ts>\t<author>\t<text>") on a question's record and its item's
## Decisions. At the close (a floor given, "close" as the fourth argument) it also sets its
## follow floor to the newest message read, or to the question when none was: its thread stays
## watched from there, so only what comes later arrives. After the close the floor stays put,
## and the Wait's own baseline tells new from seen. Prints how many lines were new.
AgentsHarnessAskKeepClarifications(){ ## pending id, clarification lines, newest message ts read (may be empty), close|empty
	[ -n "$1" ] || { printf '0\n' ; return 0 ; }
	local keepFloor="" keepOut=""
	if [ "${4:-}" = "close" ] ; then
		keepFloor="${3:-}"
		[ -n "$keepFloor" ] || keepFloor="$( AgentsHarnessAskRecordField "$1" question-ts )"
	fi
	[ -n "$2" ] || [ -n "$keepFloor" ] || { printf '0\n' ; return 0 ; }
	keepOut="$( printf '%s\n' "$2" | "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-pending-reply-clarify "$1" --from-stdin \
		${keepFloor:+--follow-floor "$keepFloor"} 2>/dev/null )" \
		|| printf 'WARNING: %s: the clarifications on pending reply %s were not kept on its record.\n' "$harnessAskName" "$1" >&2
	keepOut="$( printf '%s\n' "$keepOut" | LC_ALL=C sed -n 's/^CLARIFIED [^ ]* \([0-9][0-9]*\)$/\1/p' | head -1 )"
	printf '%s\n' "${keepOut:-0}"
	return 0
}

## The asker acting on its own question already asked, by pending id: withdraw it with a
## reason (--member-pending-reply-settle --withdraw), or close its decision by a readback
## naming the option it takes the reply to mean (--member-escalation-readback). Prints the
## result block.
AgentsHarnessAskAct(){ ## pending id, readback option, withdraw reason, understood text
	local actId="$1" actReadback="$2" actWithdraw="$3" actUnderstood="$4" actOut actRc=0
	local actTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	if [ -z "$actId" ] ; then
		printf 'ERROR: %s: readback and withdraw act on a question already asked, so they need its pending_id. Nothing was posted.\n' "$harnessAskName" ; return 0
	fi
	if [ -n "$actReadback" ] && [ -n "$actWithdraw" ] ; then
		printf 'ERROR: %s: readback and withdraw are two different acts, and both were given. Nothing was done to pending reply %s.\n' "$harnessAskName" "$actId" ; return 0
	fi
	if ! AgentsHarnessBareName "$actId" || [ ! -f "$MMDAPP/.local/agents/pending/$actId.md" ] ; then
		printf 'ERROR: %s: pending_id %s names no pending reply in this workspace. Nothing was done.\n' "$harnessAskName" "$actId" ; return 0
	fi
	if [ -n "$actWithdraw" ] ; then
		actOut="$( "$BASH" "$actTools" --member-pending-reply-settle "$harnessAgent" "$actId" --reason "$actWithdraw" --withdraw 2>&1 )" || actRc=$?
		if [ "$actRc" = "0" ] && printf '%s\n' "$actOut" | LC_ALL=C grep -q -x -F "WITHDRAWN $actId" ; then
			AgentsHarnessAskWaitItem drop "$actId" || :
			printf 'ASK-RESULT: WITHDRAWN\nPending reply %s is withdrawn: closed with your reason and no verdict, so it answers, grants and decides nothing, and it is reminded no more. A note in its thread tells the person it is no longer needed, and it has left your Wait set.\n' "$actId"
			## What could not be done to its post (its mark, its answer emoji, the edit) fails no
			## withdraw, and is logged as every warning of this tool is, never dropped.
			printf '%s\n' "$actOut" | LC_ALL=C grep -F -- '⚠️ WARNING: ' >&2 || :
			return 0
		fi
		printf 'ERROR: %s: pending reply %s was NOT withdrawn, and stays as it was. What the operation reported follows:\n%s\n' "$harnessAskName" "$actId" "$actOut"
		return 0
	fi
	actOut="$( "$BASH" "$actTools" --member-escalation-readback "$harnessAgent" "$actId" "$actReadback" "$actUnderstood" 2>&1 )" || actRc=$?
	if [ "$actRc" = "0" ] && printf '%s\n' "$actOut" | LC_ALL=C grep -q -x -F "ESCALATION: $actId answered" ; then
		## The item stays in the Wait set: a later reply there is an objection, kept on the decision.
		AgentsHarnessAskWaitItem add "$actId" || :
		printf 'ASK-RESULT: RECEIVED\n'
		printf '%s\n' "$actOut" | LC_ALL=C grep -E '^(VERDICT|VERDICT-TEXT|ANSWERED-BY|CLOSED-BY): ' || :
		printf 'Your readback is posted in the thread of pending reply %s, and closes it with that verdict. The replies there are kept on the decision as clarifications. The question stays in your Wait set: a later reply from the person there, such as an objection, arrives on Wait and is kept the same way.\n' "$actId"
		printf 'WAIT-ID: ask:%s\n' "$actId"
		return 0
	fi
	printf 'ERROR: %s: the readback did NOT close pending reply %s, which stays open. What the operation reported follows:\n%s\n' "$harnessAskName" "$actId" "$actOut"
	return 0
}

## The name the ask tool was called by, which every message of it carries: one of the names
## in AgentsTools.AskPost.include, which all run the one ask function below.
harnessAskName="AskUserQuestion"

## The table of the tools that ask and the post each makes, loaded where first needed.
AgentsHarnessAskPost(){
	type AgentsToolsAskToolRow > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.AskPost.include" 2> /dev/null
}

## Whether a name is a party a permission is routed for: the human-owner, or a team member
## by its name. A conversation, an account id and a routine are none.
AgentsHarnessAskParty(){ ## name
	case "$1" in
		human-owner) return 0 ;;
		''|event-track|event-alert|magic-team|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
	esac
	[ -d "${MDAT_SKILLSET_ROOT:-${MMDAPP:-}/.local/agents/members}/$1" ]
}

## The answer form of the caller's question: its kind's own, else its select, else free text.
AgentsHarnessAskForm(){
	AgentsToolsAskKindRow "$toolKind" || :
	printf '%s' "${agentsAskRowForm:-${toolSelect:-text}}"
}

## A question is refused before anything is sent when its kind or its answer form lacks a
## field it needs. Prints the ERROR line and returns 1. For a permission the refused call is
## read from its record into the caller's askRefused*, never taken from the asker's words,
## and with it askRefusedCall, what a request for it is known by.
## What a proposal lacks is a correction its caller makes, so its line starts with CORRECTION,
## and so does the line for options given with no answer form.
AgentsHarnessAskCheck(){ ## -- reads the caller's tool* fields
	case "$toolSelect" in
		''|yes-no|one|many) ;;
		*) printf 'ERROR: %s: select must be yes-no, one or many, got: %s. Nothing was sent.\n' "$harnessAskName" "$toolSelect" ; return 1 ;;
	esac
	case "$toolKind" in
		question)
			case "$toolSelect" in
				'')
					## Free text takes no options: a list under it would look like answers and take no click.
					[ -z "$toolOptions" ] || {
						printf 'CORRECTION: %s: options are given with no select, so the post would list answers nobody can click. Pass select one to take one of them, or select many to take any number of them. Nothing was sent.\n' "$harnessAskName" ; return 1
					}
				;;
				yes-no)
					[ -z "$toolOptions" ] || {
						printf 'ERROR: %s: select yes-no takes no options, since its answers are yes and no. Use select one to offer your own answers. Nothing was sent.\n' "$harnessAskName" ; return 1
					}
				;;
				one|many)
					[ -n "$toolOptions" ] || {
						printf 'ERROR: %s: select %s needs options, one per line, each starting with the word that answers it. Nothing was sent.\n' "$harnessAskName" "$toolSelect" ; return 1
					}
					## The verdict names an option by its first word, so two alike would make it a guess.
					if [ -n "$( printf '%s\n' "$toolOptions" | LC_ALL=C awk '{ sub( /^- /, "" ) ; optionWord = tolower( $1 ) ; if ( optionWord != "" && seenWord[optionWord]++ ) { print optionWord ; exit ; } ; }' )" ] ; then
						printf 'ERROR: %s: select %s needs each option to start with a different word, and two start with the same one. Nothing was sent.\n' "$harnessAskName" "$toolSelect" ; return 1
					fi
				;;
			esac
		;;
		readback)
			[ -n "$toolUnderstood" ] && [ -n "$toolFrom" ] && [ -n "$toolWillDo" ] || {
				printf 'ERROR: %s: kind readback needs understood, source and will_do, and one was empty. Nothing was sent.\n' "$harnessAskName" ; return 1
			}
		;;
		decision)
			[ -n "$toolOptions" ] || {
				printf 'ERROR: %s: kind decision needs options, one per line, each starting with the word that answers it. Nothing was sent.\n' "$harnessAskName" ; return 1
			}
			## Two options answered by the same word would make the verdict a guess.
			if [ -n "$( printf '%s\n' "$toolOptions" | LC_ALL=C awk '{ sub( /^- /, "" ) ; optionWord = tolower( $1 ) ; if ( optionWord != "" && seenWord[optionWord]++ ) { print optionWord ; exit ; } ; }' )" ] ; then
				printf 'ERROR: %s: kind decision needs each option to start with a different word, and two start with the same one. Nothing was sent.\n' "$harnessAskName" ; return 1
			fi
			## A plain "ok" takes the recommended option, so at most one may be marked.
			if [ "$( printf '%s\n' "$toolOptions" | LC_ALL=C grep -c -i -F '(recommended)' )" -gt 1 ] ; then
				printf 'ERROR: %s: kind decision takes at most one option marked (recommended), and more than one is. Nothing was sent.\n' "$harnessAskName" ; return 1
			fi
		;;
		permission)
			[ -n "$toolRefusalId" ] && [ -n "$toolReason" ] && [ -n "$toolTaskRef" ] || {
				printf 'ERROR: %s: kind permission needs refusal_id, reason and task_ref, and one was empty. Nothing was sent.\n' "$harnessAskName" ; return 1
			}
			askSession="$( AgentsHarnessSessionKey )"
			askRecord=""
			AgentsHarnessBareName "$toolRefusalId" && [ -n "$askSession" ] && askRecord="$MMDAPP/.local/agents/sessions/$askSession/$toolRefusalId.md"
			if [ -z "$askRecord" ] || [ ! -f "$askRecord" ] ; then
				printf 'ERROR: %s: no refusal %s is recorded for this session, so there is nothing to ask permission for. Nothing was sent.\n' "$harnessAskName" "$toolRefusalId" ; return 1
			fi
			## The refused call is shown from the record, never from the asker's words.
			while IFS= read -r askRecordLine ; do
				case "$askRecordLine" in
					'owner: '*) askRefusedOwner="${askRecordLine#owner: }" ;;
					'tool: '*) askRefusedTool="${askRecordLine#tool: }" ;;
					'target: '*) askRefusedTarget="$( AgentsHarnessRefusedTargetDecode "${askRecordLine#target: }" )" ;;
					'# '*) break ;;
				esac
			done < "$askRecord"
			## What makes two requests the same one: the refused call itself -- its tool, its exact
			## target, whose call it was and in which session -- never the words the asker puts
			## beside it. The check for a request already open is keyed on it (AgentsHarnessAsk).
			askRefusedCall="permission $askSession $askRefusedOwner $askRefusedTool $askRefusedTarget"
			## A person is shown the target by its location root, `<place>:<relative path>`, where
			## it lies in a registered place, and then never its absolute path beside it; as given
			## where it lies in none. The record keeps the exact target, which the grant is written from.
			[ -z "$askRefusedTarget" ] || askRefusedTarget="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-place "$harnessAgent" "$askRefusedTarget" 2>/dev/null \
				|| printf '%s\n' "$askRefusedTarget" )"
			## The folder of the refused file, which a request for one call offers as one more
			## answer: as the post shows it, and nothing where it cannot be right
			## (--intern-op-permission-folder). A request with entries is a set, and offers none.
			## The project that file lies in is one more answer beside the folder, where the same
			## operation names one: a project of a source tree that is wider than the folder.
			askRefusedFolder="" ; askRefusedProject=""
			[ -n "${toolEntries:-}" ] || askRefusedFolder="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-folder "$harnessAgent" \
				--session-id "$askSession" --refusal-id "$toolRefusalId" 2> /dev/null )" || askRefusedFolder=""
			askRefusedProject="$( LC_ALL=C sed -n 's/^PROJECT-SHOWN: //p' <<< "$askRefusedFolder" | head -1 )"
			askRefusedFolder="$( LC_ALL=C sed -n 's/^SHOWN: //p' <<< "$askRefusedFolder" | head -1 )"
		;;
		proposal)
			## Put by its own tool only: the skeleton of the second name has no place for its document.
			AgentsToolsAskKindRow proposal && [ "${askPostName:-$harnessAskName}" = "$agentsAskRowName" ] || {
				printf 'ERROR: %s: a proposal is put with %s, its own tool. Nothing was sent.\n' "$harnessAskName" "${agentsAskRowName:-its own tool}" ; return 1
			}
			## Only the coordinator proposes: the proposal routine names no other executor.
			[ "$harnessAgent" = "magic-coordinator" ] || {
				printf 'CORRECTION: %s: only magic-coordinator puts a proposal to the human-owner, and this call is made as %s. Hand the proposal to magic-coordinator, which puts it. Nothing was sent.\n' "$harnessAskName" "${harnessAgent:-no team member}" ; return 1
			}
			## A proposal is never posted without its document: what is approved is that document.
			case "$toolDocument" in
				''|*[[:space:]]*) false ;;
				http://?*|https://?*) : ;;
				*) false ;;
			esac || {
				printf 'CORRECTION: %s: a proposal is put with the link to its document, and document must be the absolute http:// or https:// URL of a page that already exists, got: %s. Publish the document first, with Artifact file=<path> kind=PRO, and pass the link its result names. Nothing was sent.\n' "$harnessAskName" "${toolDocument:-<none>}" ; return 1
			}
			[ -n "$toolProposal" ] || {
				printf 'CORRECTION: %s: proposal is required and was empty: the proposed form and its tight reasoning. Nothing was sent.\n' "$harnessAskName" ; return 1
			}
		;;
		*)
			printf 'ERROR: %s: kind must be question, readback, decision or permission, got: %s. Nothing was sent.\n' "$harnessAskName" "$toolKind" ; return 1
		;;
	esac
	return 0
}

## The post of the caller's question, filled from its tool's own template
## (sh-lib/templates/, AgentsTools.AskPost.include). Prints the body; non-zero, with the
## reason in ask-post.err, when the template could not fill it.
AgentsHarnessAskBody(){ ## optional revised (1: the question asked again, changed)
	AgentsHarnessAskPost && AgentsToolsAskKindRow "$toolKind" || return 3
	## A second name of the tools shows every field in its own skeleton, around its kind's template.
	ASKP_SKELETON="$( AgentsToolsAskPostSkeleton "${askPostName:-$harnessAskName}" )" \
	ASKP_OPTIONS="$toolOptions" ASKP_REVISED="${1:-}" ASKP_F_tag="$askTag" ASKP_F_question="$toolQuestion" ASKP_F_context="$toolContext" \
		ASKP_F_understood="$toolUnderstood" ASKP_F_source="$toolFrom" ASKP_F_will_do="$toolWillDo" \
		ASKP_F_refused_tool="$askRefusedTool" ASKP_F_refused_target="$askRefusedTarget" ASKP_F_refused_for="$askRefusedOwner" ASKP_F_refusal_id="$toolRefusalId" \
		ASKP_F_folder="${askRefusedFolder:-}" ASKP_F_project="${askRefusedProject:-}" \
		ASKP_F_reason="$toolReason" ASKP_F_task="$toolTaskRef" ASKP_F_proposal="$toolProposal" ASKP_F_document="$toolDocument" \
		AgentsToolsAskPostFill post "$agentsAskRowTemplate" "$( AgentsHarnessAskForm )" 2> "$harnessScratch/ask-post.err"
}

## The root a proposal opens its thread with: the `## root` block of its template, the
## question alone. It is posted once, and no later call changes it. Prints it; non-zero,
## with the reason in ask-post.err, when the template has no such block.
AgentsHarnessAskRootBody(){
	AgentsHarnessAskPost && AgentsToolsAskKindRow "$toolKind" || return 3
	ASKP_BLOCK="Skeleton/root" ASKP_F_question="$toolQuestion" AgentsToolsAskPostFill block "$agentsAskRowTemplate" "" 2> "$harnessScratch/ask-post.err"
}

## The asker's own words in the post: the fields the call gave, its options as the list they
## are. The title, the headings, the refused call of a permission and the lines that say how
## to answer are the template's, and are not measured against the plain-language floor.
AgentsHarnessAskProse(){
	AgentsHarnessSendProse "$toolQuestion" "$toolContext" "$toolUnderstood" "$toolFrom" "$toolWillDo" "$toolReason" "$toolTaskRef" "$toolProposal" \
		"$( [ -z "$toolOptions" ] || printf '%s\n' "$toolOptions" | LC_ALL=C awk 'NF { sub( /^- /, "" ) ; print "- " $0 ; }' )"
}

## What the post was filled with, as kept beside its record: a later fill starts from it.
AgentsHarnessAskFields(){
	AgentsHarnessAskPost || return 0
	AgentsToolsAskPostFieldsPack asked-as "${askPostName:-$harnessAskName}" tag "$askTag" question "$toolQuestion" context "$toolContext" understood "$toolUnderstood" source "$toolFrom" will-do "$toolWillDo" \
		refused-tool "$askRefusedTool" refused-target "$askRefusedTarget" refused-for "$askRefusedOwner" refusal-id "$toolRefusalId" folder "${askRefusedFolder:-}" project "${askRefusedProject:-}" \
		reason "$toolReason" task "$toolTaskRef" proposal "$toolProposal" document "$toolDocument"
}

## The answer emoji of the caller's question, as Slack names: what its template places for
## its answer form, the folder's too where a permission offers the folder of the refused file,
## and the project's where it offers the project beside it.
AgentsHarnessAskSeedNames(){
	AgentsHarnessAskPost && AgentsToolsAskKindRow "$toolKind" || return 0
	ASKP_OPTIONS="$toolOptions" ASKP_F_folder="${askRefusedFolder:-}" ASKP_F_project="${askRefusedProject:-}" AgentsToolsAskPostFill reactions "$agentsAskRowTemplate" "$( AgentsHarnessAskForm )" 2> /dev/null || :
}

## Places emoji under one post, or takes them off, as the identity that posted it. A failed
## one is logged and never fails the ask. They are never an answer: only an addressee's is.
AgentsHarnessAskReact(){ ## <channel>:<ts>, as bot (true|...), add|remove, emoji names...
	local reactAt="$1" reactAs="member" reactDo="$3"
	case "$2" in true|1|yes|bot) reactAs="bot" ;; esac
	shift 3
	[ -n "$reactAt" ] && [ $# -gt 0 ] && AgentsHarnessAskPost || return 0
	MDSC_CMD="$harnessAskName" AgentsToolsAskPostReact "$harnessAgent" "$reactAt" "$reactAs" "$reactDo" "$@"
}

## The same question asked again, changed (revise): the same record, id and number, however
## much of it changes. A field given replaces the one the question was asked with, and the
## rest stay. A question with its own thread keeps its first post as the place to answer:
## that post is marked once, its answer emoji follow the changed answers, and the changed
## question is one reply under it, the one before it removed. A question asked inside
## another thread is asked again as a new reply there: the version before it stays, marked,
## without its answer emoji and its How to answer part, and nothing is deleted. A proposal
## is the reply under its root from the start, so every change of it removes the reply
## before and posts the changed one: its root is never marked, and takes no question. Reads and
## sets the caller's tool* and ask* fields. Prints an ERROR line and returns 1 when the
## question stands as it was.
AgentsHarnessAskRevise(){ ## record file, options given (empty: unchanged), select given (empty: unchanged, text: free text)
	local revRecord="$1" revOptions="$2" revSelect="$3" revSlot revValue revAsBot="false" revPrev revTs="" revOld revNew revName revOut revSuperseded=""
	local revTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	if ! AgentsHarnessAskPost || [ ! -f "${revRecord%.md}.fields" ] ; then
		printf 'ERROR: %s: pending reply %s was asked before the fields of a question were kept, so it cannot be asked again changed. Withdraw it and ask the changed question anew. Nothing was posted.\n' "$harnessAskName" "$toolPendingId" ; return 1
	fi
	if [ "$toolKind" = "proposal" ] && [ -n "$toolQuestion" ] ; then
		printf 'CORRECTION: %s: the question of a proposal is the root of its thread, which is posted once and never changes, so a changed proposal takes no question. Pass what you change: proposal, document or context. Nothing was posted, and pending reply %s stands as it was.\n' "$harnessAskName" "$toolPendingId" ; return 1
	fi
	if [ -z "$toolQuestion$toolContext$toolUnderstood$toolFrom$toolWillDo$toolReason$toolTaskRef$toolProposal$toolDocument$revOptions$revSelect" ] ; then
		printf 'ERROR: %s: revise asks the same question again, changed, so it needs at least one changed field. Nothing was posted, and pending reply %s stands as it was.\n' "$harnessAskName" "$toolPendingId" ; return 1
	fi
	while IFS=$'\t' read -r revSlot revValue ; do
		## Never `printf -v` an empty result: bash 3.2 then leaves the buffer of the one before.
		[ -z "$revValue" ] || printf -v revValue '%b' "$revValue"
		case "$revSlot" in
			## The post keeps the skeleton of the name the question was first asked by.
			asked-as) askPostName="$revValue" ;;
			question) [ -n "$toolQuestion" ] || toolQuestion="$revValue" ;;
			context) [ -n "$toolContext" ] || toolContext="$revValue" ;;
			understood) [ -n "$toolUnderstood" ] || toolUnderstood="$revValue" ;;
			source) [ -n "$toolFrom" ] || toolFrom="$revValue" ;;
			will-do) [ -n "$toolWillDo" ] || toolWillDo="$revValue" ;;
			reason) [ -n "$toolReason" ] || toolReason="$revValue" ;;
			task) [ -n "$toolTaskRef" ] || toolTaskRef="$revValue" ;;
			proposal) [ -n "$toolProposal" ] || toolProposal="$revValue" ;;
			document) [ -n "$toolDocument" ] || toolDocument="$revValue" ;;
		esac
	done < "${revRecord%.md}.fields"
	case "$revSelect" in
		'') ;;
		text) toolSelect="" ;;
		*) toolSelect="$revSelect" ;;
	esac
	[ -z "$revOptions" ] || toolOptions="$revOptions"
	## Yes or no takes no options, so those of the form before it go.
	[ "$toolKind:$toolSelect" != "question:yes-no" ] || [ -n "$revOptions" ] || toolOptions=""
	## Free text takes none either, so a question taken back to it leaves them too.
	[ "$toolKind:$revSelect" != "question:text" ] || [ -n "$revOptions" ] || toolOptions=""
	AgentsHarnessAskCheck || return 1
	[ "$toolKind" = "question" ] || toolSelect=""
	## The emoji the question had, before its record changes.
	revOld=" $( AgentsToolsAskPostRecordFill reactions "$revRecord" 2> /dev/null | LC_ALL=C tr '\n' ' ' )"
	revPrev="$( AgentsHarnessAskRecordField "$toolPendingId" revision-ts )"
	[ "$( AgentsHarnessAskRecordField "$toolPendingId" ask-identity )" != "bot" ] || revAsBot="true"
	askBody="$( AgentsHarnessAskBody 1 )" || askBody=""
	if [ -z "$askBody" ] ; then
		printf 'ERROR: %s: the changed post could not be filled from its template, so nothing was posted and pending reply %s stands as it was. What the fill reported follows:\n%s\n' "$harnessAskName" "$toolPendingId" "$( cat "$harnessScratch/ask-post.err" 2>/dev/null )" ; return 1
	fi
	revOut="$( harnessSendProse="$( AgentsHarnessAskProse )" AgentsHarnessToolSendMessage "$askChannel:$askThreadTs" "$askBody" "$revAsBot" "$toolAddressTo" "" true )"
	revTs="$( printf '%s\n' "$revOut" | LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' | head -1 )"
	case "$revOut" in ERROR:*) revTs="" ;; esac
	## Over the plain-language floor: a correction to make, passed on as it is. The question
	## stands as it was asked until the corrected one is posted.
	case "$revOut" in CORRECTION:*) printf '%s\n' "$revOut" ; return 1 ;; esac
	if [ -z "$revTs" ] ; then
		printf 'ERROR: %s: the changed question could NOT be posted, so pending reply %s stands as it was asked. What the send reported follows:\n%s\n' "$harnessAskName" "$toolPendingId" "$revOut" ; return 1
	fi
	revNew=" $( AgentsHarnessAskSeedNames | LC_ALL=C tr '\n' ' ' )"
	if [ "$askThreadTs" = "$askTs" ] ; then
		if [ -n "$revPrev" ] ; then
			## One live update under the root: the one before it goes, under the identity that posted it.
			"$BASH" "$revTools" --member-comms-slack-delete-message "$harnessAgent" "$askChannel:$revPrev" $( [ "$revAsBot" != "true" ] || printf -- '--identity-bot' ) > /dev/null 2>&1 \
				|| printf 'WARNING: %s: the update before this one, %s:%s, could not be removed, so the thread holds two.\n' "$harnessAskName" "$askChannel" "$revPrev" >&2
		elif AgentsToolsAskKindRow "$toolKind" ; then
			AgentsHarnessAskReact "$askChannel:$askTs" "$revAsBot" add $( ASKP_BLOCK="Marks/superseded" AgentsToolsAskPostFill block "$agentsAskRowTemplate" "" 2> /dev/null )
		fi
		## The emoji under the root follow the live version: those that no longer answer go,
		## and the missing ones are placed.
		for revName in $revOld ; do
			case "$revNew" in *" $revName "*) ;; *) AgentsHarnessAskReact "$askChannel:$askTs" "$revAsBot" remove "$revName" ;; esac
		done
		for revName in $revNew ; do
			case "$revOld" in *" $revName "*) ;; *) AgentsHarnessAskReact "$askChannel:$askTs" "$revAsBot" add "$revName" ;; esac
		done
	else
		revSuperseded="${revPrev:-$askTs}"
		MDSC_CMD="$harnessAskName" AgentsToolsAskPostClose "$revRecord" "$revSuperseded" superseded edit
	fi
	AgentsHarnessAskReact "$askChannel:$revTs" "$revAsBot" add $revNew
	revOut="$( printf '%s' "$askBody" | "$BASH" "$revTools" --intern-op-pending-reply-revise "$toolPendingId" --from-stdin --revision-ts "$revTs" --select "$toolSelect" --options "$toolOptions" \
		--fields "$( AgentsHarnessAskFields )" --revised-by "$harnessAgent" ${revSuperseded:+--superseded "$revSuperseded"} --context "$harnessAskName" 2>&1 )" || {
		printf 'ERROR: %s: the changed question WAS posted as %s:%s, and then pending reply %s could not be updated, so an answer is still read against the question as it was. What the operation reported follows:\n%s\n' "$harnessAskName" "$askChannel" "$revTs" "$toolPendingId" "$revOut" ; return 1
	}
	## Its wait item starts afresh: what the thread held before the change is no arrival.
	AgentsHarnessAskWaitItem drop "$toolPendingId" || :
	askSent="(pending reply $toolPendingId asked again, changed: its live version is $askChannel:$revTs, in the thread of the question. ${revOut##*$'\n'})"
	return 0
}

## A proposal is changed only while its root carries no verdict. With one there -- read now
## from its thread, or recorded before -- nothing is posted: prints the correction, with the
## verdict, and returns 1.
AgentsHarnessAskProposalVerdict(){ ## pending reply id
	local verdictLines
	verdictLines="$( AgentsHarnessEscalationRead "$1" )"
	case "$verdictLines" in
		*"ESCALATION: $1 answered"*) ;;
		*) return 0 ;;
	esac
	printf 'CORRECTION: %s: the root of this proposal already carries its verdict, so no changed proposal was posted. A verdict is on the whole proposal and closes it: pending reply %s is closed with the verdict below, and a changed proposal is a new one, put with a new call.\n' "$harnessAskName" "$1"
	printf '%s\n' "$verdictLines" | LC_ALL=C grep -E '^(VERDICT|VERDICT-TEXT|ANSWERED-BY): ' || :
	return 1
}

## The proposal itself, posted as the one reply under the root just sent. Sets the caller's
## askLiveTs, and adds what the send reported to its askSent. A reply that could not be
## posted leaves no proposal, so its root goes too, under the identity that posted it:
## prints the ERROR, or the CORRECTION of the send, and returns 1.
AgentsHarnessAskProposalReply(){ ## -- reads the caller's ask* and tool* fields
	local replyOut="" replyBot="" replyRoot="the root could not be named, so it may stand with no proposal under it"
	case "$toolAsBot" in true|1|yes) replyBot="--identity-bot" ;; esac
	if [ -n "$askChannel" ] && [ -n "$askTs" ] ; then
		replyOut="$( harnessSendProse="$( AgentsHarnessAskProse )" AgentsHarnessToolSendMessage "$askChannel:$askTs" "$askBody" "$toolAsBot" "$toolAddressTo" "" true )"
		askLiveTs="$( printf '%s\n' "$replyOut" | LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' | head -1 )"
		case "$replyOut" in ERROR:*|CORRECTION:*) askLiveTs="" ;; esac
		if [ -n "$askLiveTs" ] ; then
			askSent="$askSent"$'\n'"$replyOut"
			return 0
		fi
		## No root stands without its proposal.
		if "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-comms-slack-delete-message "$harnessAgent" "$askChannel:$askTs" $replyBot > /dev/null 2>&1 ; then
			replyRoot="its root was removed"
		else
			replyRoot="its root $askChannel:$askTs could not be removed, and stands with no proposal under it"
		fi
	fi
	case "$replyOut" in
		CORRECTION:*) printf '%s\n' "$replyOut" ;;
		*) printf 'ERROR: %s: the proposal could NOT be posted under its root, so %s, and nothing is pending anywhere. THE PROPOSAL DOES NOT EXIST: this is not a proposal that went unanswered. Put it again. What the send reported follows:\n%s\n' "$harnessAskName" "$replyRoot" "${replyOut:-the send of the root named no message to reply under}" ;;
	esac
	return 1
}

## One call of a tool that asks. The name it was called by picks its row
## (AgentsTools.AskPost.include), which presets the kind, and the one ask function below
## runs it. A tool that presets its kind takes its own parameters and the common ones only.
## A second name, with no preset, takes kind as a parameter, and every parameter.
AgentsHarnessAskCall(){ ## the tool name as called
	local callKind="${harnessArgV_kind}" callKey callArg
	if ! AgentsHarnessAskPost || ! AgentsToolsAskToolRow "$1" ; then
		printf 'ERROR: %s names no tool that asks, so nothing was sent.\n' "$1" ; return 0
	fi
	harnessAskName="$agentsAskRowName"
	if [ -n "$agentsAskRowKind" ] ; then
		for callKey in ${!harnessArgV_@} ; do
			callArg="${callKey#harnessArgV_}"
			case " $agentsAskCommonArgs $agentsAskRowArgs " in
				*" $callArg "*) ;;
				*)
					printf 'ERROR: %s: %s is not a parameter of %s. Its own are: %s. The common ones are: %s. Nothing was sent.\n' "$harnessAskName" "$callArg" "$harnessAskName" "$agentsAskRowArgs" "$agentsAskCommonArgs" ; return 0
				;;
			esac
		done
		callKind="$agentsAskRowKind"
	fi
	## The entries of a permission: a list, taken an entry a line, or one text that is that already.
	local callEntries="${harnessArgV_entries}" callEntryNo=0 callEntryCount=""
	if AgentsHarnessArgFind "entries.__count" ; then
		callEntries="" ; callEntryCount="$harnessArgFound"
		case "$callEntryCount" in ''|*[!0123456789]*) callEntryCount=0 ;; esac
		while [ "$callEntryNo" -lt "$callEntryCount" ] ; do
			! AgentsHarnessArgFind "entries.$callEntryNo" || callEntries="$callEntries$harnessArgFound"$'\n'
			callEntryNo=$(( callEntryNo + 1 ))
		done
	fi
	AgentsHarnessAsk "${harnessArgV_to}" "${harnessArgV_question}" "${harnessArgV_options}" "${harnessArgV_context}" "${harnessArgV_wait}" "${harnessArgV_timeout}" "${harnessArgV_wait_source}" "${harnessArgV_as_bot}" "${harnessArgV_address_to}" "$callKind" "${harnessArgV_understood}" "${harnessArgV_source}" "${harnessArgV_will_do}" "${harnessArgV_refusal_id}" "${harnessArgV_reason}" "${harnessArgV_task_ref}" "${harnessArgV_pending_id}" "${harnessArgV_readback}" "${harnessArgV_withdraw}" "${harnessArgV_select}" "${harnessArgV_revise}" "${harnessArgV_proposal}" "${harnessArgV_document}" "$callEntries"
}
## The four tools that ask, each its own name over the one ask function.
AgentsHarnessToolAskQuestion(){ AgentsHarnessAskCall AskQuestion ; }
AgentsHarnessToolConfirmReadback(){ AgentsHarnessAskCall ConfirmReadback ; }
AgentsHarnessToolEscalateDecision(){ AgentsHarnessAskCall EscalateDecision ; }
AgentsHarnessToolRequestPermission(){ AgentsHarnessAskCall RequestPermission ; }
## And the fifth: a proposal put to the human-owner, the coordinator's alone.
AgentsHarnessToolProposeApprove(){ AgentsHarnessAskCall ProposeApprove ; }

## How a tool that asks is announced: the question, then the conversation on its own line.
## A question and a target on one line push each other off the terminal, and this call may
## hold the run for minutes, so what it is waiting on has to be visible. Sets the caller's
## announce* fields.
AgentsHarnessAskAnnounce(){
	announceIcon="❔"
	announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_to}" )"
	announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_question}" )$harnessOff"
	[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim to$harnessOff $harnessValue$announcePath$harnessOff"
}

AgentsHarnessAsk(){
	local toolTo="$1" toolQuestion="$2" toolOptions="$3" toolContext="$4" toolWait="$5" toolTimeout="$6" toolSource="$7" toolAsBot="$8" toolAddressTo="$9"
	local toolKind="${10:-question}" toolUnderstood="${11}" toolFrom="${12}" toolWillDo="${13}" toolRefusalId="${14}" toolReason="${15}" toolTaskRef="${16}" toolPendingId="${17}"
	local toolReadback="${18:-}" toolWithdraw="${19:-}" toolSelect="${20:-}" toolRevise="${21:-}" toolProposal="${22:-}" toolDocument="${23:-}" toolEntries="${24:-}"
	local askBody askSent askWaitOut askFirst askOutcome askPendingId="" askSelectNote="" askPostName="" askRouteNote=""
	## Free text is the form of a question with no select, so `text` names it too.
	[ "$toolSelect" != "text" ] || toolSelect=""
	AgentsHarnessAskPost || :
	## On a question already asked: the asker withdraws it, or closes its decision by its own
	## readback of the reply. Each through the team operation that owns it; nothing is waited on.
	if [ -n "$toolReadback$toolWithdraw" ] ; then
		AgentsHarnessAskAct "$toolPendingId" "$toolReadback" "$toolWithdraw" "$toolUnderstood"
		return 0
	fi
	## Asked again, changed, is an act on a question already asked too.
	case "$toolRevise" in
		''|false|0|no) ;;
		*)
			[ -n "$toolPendingId" ] || {
				printf 'ERROR: %s: revise asks a question already asked again, changed, so it needs its pending_id. Nothing was posted.\n' "$harnessAskName" ; return 0
			}
		;;
	esac
	local askChannel="" askTs="" askThreadTs="" askAddressees=""
	local askRounds=0
	local askSelfIds=" " askRecordOnly="" askSessionWait="" askOthers=""
	local askSession="" askRecord="" askRecordLine askRefusedTool="" askRefusedTarget="" askRefusedOwner="" askRefusedCall="" askRefusedFolder="" askRefusedProject=""
	local askTag="" askKey="" askWhere="" askDupId="" askDupOwner="" askDupSession="" askLock="" askRoutine=""
	## A re-wait: the question is already posted and recorded, so everything it is judged
	## against comes from its open record, and nothing is posted again.
	if [ -n "$toolPendingId" ] ; then
		local rewaitRecord="" rewaitStatus="" rewaitSession="" rewaitLine
		AgentsHarnessBareName "$toolPendingId" && rewaitRecord="$MMDAPP/.local/agents/pending/$toolPendingId.md"
		if [ -z "$rewaitRecord" ] || [ ! -f "$rewaitRecord" ] ; then
			printf 'ERROR: %s: pending_id %s names no pending reply in this workspace, so there is nothing to wait on. Nothing was posted.\n' "$harnessAskName" "$toolPendingId" ; return 0
		fi
		## What a revise gives stays aside: everything else comes from the record.
		local reviseOptions="$toolOptions" rewaitSelect=""
		toolKind="question" ; toolTo="" ; toolAddressTo="" ; toolOptions=""
		while IFS= read -r rewaitLine ; do
			case "$rewaitLine" in
				'select: '*) rewaitSelect="${rewaitLine#select: }" ;;
				'status: '*) rewaitStatus="${rewaitLine#status: }" ;;
				'session-id: '*) rewaitSession="${rewaitLine#session-id: }" ;;
				'kind: '*) toolKind="${rewaitLine#kind: }" ;;
				'communication-channel-id: slack:'*) toolTo="${rewaitLine#communication-channel-id: slack:}" ;;
				'address-to: '*) toolAddressTo="${rewaitLine#address-to: }" ;;
				'channel: '*) askChannel="${rewaitLine#channel: }" ;;
				'question-ts: '*) askTs="${rewaitLine#question-ts: }" ;;
				'thread-ts: '*) askThreadTs="${rewaitLine#thread-ts: }" ;;
				'addressees: '*) askAddressees="${rewaitLine#addressees: }" ;;
				'asking-accounts: '*) askSelfIds=" ${rewaitLine#asking-accounts: } " ;;
				'refusal-id: '*) toolRefusalId="${rewaitLine#refusal-id: }" ;;
				'question-tag: '*) askTag="${rewaitLine#question-tag: }" ;;
				'# '*) break ;;
			esac
		done < "$rewaitRecord"
		## The verdict feeds grants keyed to the asking session, so no other session collects it.
		if [ -n "$rewaitSession" ] && [ "$rewaitSession" != "$( AgentsHarnessSessionKey )" ] ; then
			printf 'ERROR: %s: pending reply %s belongs to session %s, not this one, so this session may not wait on it. Nothing was posted.\n' "$harnessAskName" "$toolPendingId" "$rewaitSession" ; return 0
		fi
		## A proposal whose root carries its verdict takes no change: the verdict is given back.
		case "$toolKind:$toolRevise" in
			proposal:|proposal:false|proposal:0|proposal:no) ;;
			proposal:*) AgentsHarnessAskProposalVerdict "$toolPendingId" || return 0 ;;
		esac
		if [ "$rewaitStatus" != "reply-pending" ] ; then
			printf 'ERROR: %s: pending reply %s is closed (status %s), so there is nothing to wait on. Nothing was posted.\n' "$harnessAskName" "$toolPendingId" "${rewaitStatus:-none}" ; return 0
		fi
		[ ! -f "${rewaitRecord%.md}.options" ] || toolOptions="$( cat "${rewaitRecord%.md}.options" )"
		askPendingId="$toolPendingId"
		toolWait="true"
		askSent="(re-wait on pending reply $toolPendingId: nothing was posted)"
		toolSelect="$rewaitSelect"
		## The same question asked again, changed: posted in its thread, then waited on as above.
		case "$toolRevise" in
			''|false|0|no) ;;
			*) AgentsHarnessAskRevise "$rewaitRecord" "$reviseOptions" "${20:-}" || return 0 ;;
		esac
	else
	## A proposal opens a thread of its own: to the human-owner, unless a conversation is named.
	[ "$toolKind" != "proposal" ] || [ -n "$toolTo" ] || toolTo="human-owner"
	## A permission asked with entries is a Permission set of the asking member, for its task
	## (below): the human-owner's to answer, in the bot's conversation with him, as every set
	## is, whoever the call names. Entries go with a permission and nothing else.
	local askSetNote=""
	if [ -n "$toolEntries" ] ; then
		if [ "$toolKind" != "permission" ] ; then
			printf 'ERROR: %s: entries go with a permission request only, and this is a %s. Nothing was sent.\n' "$harnessAskName" "$toolKind" ; return 0
		fi
		case "$toolTo:$toolAddressTo" in
			:|human-owner:|:human-owner|human-owner:human-owner) ;;
			*) askSetNote="NOTE: addressed to human-owner, not ${toolAddressTo:-$toolTo}: a Permission set is his to answer." ;;
		esac
		toolTo="human-owner" ; toolAddressTo="human-owner"
	fi
	## No target and no party named: asked where this run reports to (AgentsToolsRunRoute), the
	## one address its questions and escalations go to: a session in its thread, addressed to its
	## member; a member as a member is asked (below); a person, the human-owner. A session with no
	## spawn record of its own keeps the default below.
	if [ -z "$toolTo" ] && [ -z "$toolAddressTo" ] ; then
		local askRouteRecord="" askRouteTo=""
		if askRouteRecord="$( AgentsHarnessSpawnRecordPath "${MDAT_SPAWN_SESSION_ID:-}" )" && [ -n "$askRouteRecord" ] ; then
			type AgentsToolsRunRoute > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
			askRouteTo="$( AgentsToolsRunRoute "$askRouteRecord" 2> /dev/null )" || askRouteTo=""
			## A run that reports to no one asks where it would report to if it named nobody.
			[ "$askRouteTo" != none ] || askRouteTo="$( AgentsToolsRunRoute "$askRouteRecord" default 2> /dev/null )" || askRouteTo=""
			case "$( AgentsToolsRunRouteKind "$askRouteTo" 2> /dev/null )" in
				session) toolTo="$harnessParentName" ; toolAddressTo="$( AgentsToolsRunRouteMember "$askRouteTo" 2> /dev/null )" || toolAddressTo="" ;;
				member) toolTo="$askRouteTo" ; toolAddressTo="$askRouteTo" ;;
				person) toolTo="human-owner" ; toolAddressTo="human-owner" ;;
			esac
		fi
	fi
	## No target named: default to this session's own coworking thread, where one
	## exists -- same rule and same reason as SendMessage's own default. An ad-hoc/
	## solo spawn holding none keeps today's explicit-target requirement exactly.
	if [ -z "$toolTo" ] ; then
		type AgentsToolsSessionCurrentThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		toolTo="$( AgentsToolsSessionCurrentThreadFind 2>/dev/null )" || toolTo=""
	fi
	if [ -z "$toolTo" ] ; then
		printf 'ERROR: %s: to is required and was empty, so there is nobody to ask. Nothing was sent.\n' "$harnessAskName" ; return 0
	fi
	## A session's thread is one message-thread target like any other, so address_to is still required for it.
	case "$toolTo" in
		"$harnessCurrentName"|"$harnessCurrentName":*|"$harnessParentName"|"$harnessParentName":*)
			toolTo="$( AgentsHarnessSessionThread "$toolTo" )" || { printf 'ERROR: %s: %s\n' "$harnessAskName" "${toolTo#ERROR: }" ; return 0 ; }
			toolTo="${toolTo%% *}"
		;;
	esac
	## A routine (`<name>.routine`) is asked by no post at all: the ask is recorded for that
	## routine's executors, who answer it through the team operation (AgentsTools.MemberEscalation.include).
	case "$toolTo" in
		*:*) ;;
		*.routine)
			type AgentsToolsRoutineFile > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.TeamRegistry.include" 2> /dev/null || :
			if ! type AgentsToolsRoutineFile > /dev/null 2>&1 || ! AgentsToolsRoutineFile "$toolTo" > /dev/null ; then
				printf 'ERROR: %s: to names %s, and no one routine of this team carries that name, so there is nobody to ask. Nothing was recorded.\n' "$harnessAskName" "$toolTo" ; return 0
			fi
			if [ -n "$toolAddressTo" ] && [ "$toolAddressTo" != "$toolTo" ] ; then
				printf 'ERROR: %s: a question to a routine is addressed to that routine, and address_to names %s instead. Nothing was recorded.\n' "$harnessAskName" "$toolAddressTo" ; return 0
			fi
			askRoutine="$toolTo"
		;;
	esac
	## The retired marker of a plain message, `NEEDS REPLY`, in front of the text is taken off,
	## as the number below is: this tool is the question, and waits for its answer itself.
	local askMarker='^NEEDS[[:space:]]+REPLY[[:space:]]*[-:.)]?[[:space:]]*'
	if [[ "$toolQuestion" =~ $askMarker ]] ; then
		toolQuestion="${toolQuestion:${#BASH_REMATCH[0]}}"
	fi
	## The tool numbers its questions itself, so a number the asker put in front of the
	## text ("Q1: ...", "q2) ...", "Q3 - ...") would show beside it as a second one.
	local askLabel='^[Qq][0-9]+[[:space:]]*[-:.)][[:space:]]*'
	if [[ "$toolQuestion" =~ $askLabel ]] ; then
		toolQuestion="${toolQuestion:${#BASH_REMATCH[0]}}"
	fi
	## A permission is asked by its refused call: the tooling says what is asked, and the asker
	## gives the reason. A question of its own is optional there, and is shown with the reason.
	if [ -z "$toolQuestion" ] && [ "$toolKind" != "permission" ] ; then
		printf 'ERROR: %s: question is required and was empty. Nothing was sent.\n' "$harnessAskName" ; return 0
	fi
	## A typed kind is refused before anything is sent when a field it needs is missing.
	AgentsHarnessAskCheck || return 0
	case "$toolKind" in
		question) ;;
		## A typed kind keeps its own answer form.
		*)
			[ -z "$toolSelect" ] || askSelectNote="select=$toolSelect was ignored: a $toolKind question keeps its own answer form."
			toolSelect=""
		;;
	esac
	## A proposal: its root is a message of its own, and the human-owner alone gives its verdict.
	if [ "$toolKind" = "proposal" ] ; then
		case "$toolTo" in
			*:*|*.routine)
				printf 'CORRECTION: %s: a proposal opens a thread of its own, whose root is its question, so to names the human-owner or a conversation, never a thread or a routine, and it named %s. Leave to out, or name a conversation. Nothing was sent.\n' "$harnessAskName" "$toolTo" ; return 0
			;;
		esac
		case "$toolAddressTo" in
			''|human-owner) toolAddressTo="human-owner" ;;
			*)
				printf 'CORRECTION: %s: a proposal is put to the human-owner, whose own reaction on its root is the verdict, and address_to named %s. Leave address_to out. Nothing was sent.\n' "$harnessAskName" "$toolAddressTo" ; return 0
			;;
		esac
	fi
	## A routine's executors answer through the team operation, which takes a typed verdict only.
	if [ -n "$askRoutine" ] && [ "$toolKind" = "question" ] ; then
		printf 'ERROR: %s: a question to a routine must be of kind readback, decision or permission, since its executors answer it with a verdict of that kind. Nothing was recorded.\n' "$harnessAskName" ; return 0
	fi
	## Whether `to` names a thread is read past a client: marker, the other organisation's side
	## of a client-* member (AgentsTools.CommsSlack.include): here and below.
	if [ -z "$toolAddressTo" ] ; then
		case "${toolTo#client:}" in
			## A thread has no party of its own, and neither has event-track or event-alert: a place.
			*:*|event-track|event-alert) ;;
			*) toolAddressTo="$toolTo" ;;
		esac
	fi
	## A TEAM MEMBER'S NAME IS AN ADDRESSEE, NEVER A PLACE. Asked by its name, a member is asked
	## in this session's own thread, a reply there addressed to that member, where the session
	## reads it: the place a permission routed to a holder is asked in too (below). That member's
	## own conversation is nobody else's to read, and only a member with an account has one. It
	## stays the place only where this session has no thread. The human-owner is asked in the
	## owner's own conversation, and a proposal opens a thread of its own, both as before.
	if [ "$toolKind" != "proposal" ] && [ "$toolTo" != "human-owner" ] && AgentsHarnessAskParty "$toolTo" ; then
		local askMemberThread=""
		type AgentsToolsSessionCurrentThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		askMemberThread="$( AgentsToolsSessionCurrentThreadFind 2>/dev/null )" || askMemberThread=""
		[ -z "$askMemberThread" ] || toolTo="$askMemberThread"
	fi
	## WHO A PERMISSION GOES TO is settled as it is asked (--intern-op-permission-route): the
	## party named, where it holds the refused call and can be reached; else a holder running
	## in this session; else the human-owner. Sent to another party, the question is addressed
	## to that party, and the result says so in one NOTE line. Only a party named by its name
	## is routed: a conversation, an account id and a routine are asked as given. An operation
	## that fails, or names nobody, leaves the ask exactly as it was made.
	local askRouteOut="" askRoute=""
	if [ "$toolKind" = "permission" ] && [ -z "$toolEntries" ] && [ -n "$toolRefusalId" ] && [ -z "$askRoutine" ] && [ -n "$harnessAgent" ] && AgentsHarnessAskParty "$toolAddressTo" ; then
		askRouteOut="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-route "$harnessAgent" \
			--session-id "$askSession" --refusal-id "$toolRefusalId" --address-to "$toolAddressTo" 2> /dev/null )" || askRouteOut=""
		askRoute="$( printf '%s\n' "$askRouteOut" | LC_ALL=C sed -n 's/^ROUTE: //p' | head -1 )"
		if [ -n "$askRoute" ] && [ "$askRoute" != "$toolAddressTo" ] && AgentsHarnessAskParty "$askRoute" ; then
			askRouteNote="NOTE: addressed to $askRoute, not $toolAddressTo: $( printf '%s\n' "$askRouteOut" | LC_ALL=C sed -n 's/^ROUTE-REASON: //p' | head -1 )"
			case "$askRoute" in
				## The human-owner is asked by the team bot, in the bot's conversation with the owner (below).
				human-owner) toolTo="human-owner" ;;
				## A member running in this session is asked where the asker pointed, the thread or
				## conversation the session talks in. The named party's own conversation is not that
				## place: then the session's thread, else the routed member's own conversation.
				*)
					if [ "$toolTo" = "$toolAddressTo" ] ; then
						type AgentsToolsSessionThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
						toolTo="$( AgentsToolsSessionThreadFind 2>/dev/null )" || toolTo=""
						[ -n "$toolTo" ] || toolTo="$askRoute"
					fi
				;;
			esac
			toolAddressTo="$askRoute"
		fi
	fi
	## An ask of the human-owner, in the owner's own conversation (`to` is `human-owner`), is the
	## team bot's to post, whoever asks and whatever as_bot the call gave: a question, a
	## readback, a decision and a permission alike, in the bot's conversation with the owner, as
	## a Permission set is (--magic-permission-set-request). So the owner is asked in one place,
	## never in the conversation of whichever account asks, where the bot can place no answer
	## emoji and read no answer. Its record then says `ask-identity: bot`, so its emoji and
	## every later read, edit and reminder are the bot's too. An ask of a team member stays the
	## asking member's own, and so does one addressed to the owner in another conversation.
	## Never a proposal: that is the coordinator's own, under its own rules.
	local askOwnerBot=""
	if [ "$toolTo" = "human-owner" ] && [ "$toolAddressTo" = "human-owner" ] ; then
		case "$toolKind" in
			question|readback|decision|permission)
				askOwnerBot=1
				toolAsBot="true"
			;;
		esac
	fi
	## Whether the question is posted (AgentsTools.AskThread.include): an identical open
	## question to the same addressee is not asked again. Every other question is a message
	## of its own: a top-level message where `to` names a conversation or a person, so its
	## thread is that question's own conversation, and never joined to another question's
	## thread. Only a `to` naming a thread (<channel>:<ts>, the parent's) posts inside it.
	## A question is the same one by its words. A permission is the same one by its refused
	## call (askRefusedCall, AgentsHarnessAskCheck), however it is worded, or with no words at all.
	askTag=""
	askKey="$( printf '%s' "${askRefusedCall:-$toolQuestion}" | LC_ALL=C tr -s ' \t\n' '   ' | LC_ALL=C sed 's/^ //;s/ $//' | cksum )"
	askKey="${askKey// /-}"
	type AgentsToolsAskThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.AskThread.include" 2> /dev/null || :
	type AgentsToolsLocalLockTake > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.LocalLock.include" 2> /dev/null || :
	## A question this session already had answered, or its item's Decisions answer, is not asked again.
	## Never a proposal: a verdict was given to one document, and answers for no other. Nor a
	## permission asked with entries: the answer one call had answers for no set.
	if [ "$toolKind" != "proposal" ] && [ -z "$toolEntries" ] ; then
		AgentsHarnessAskEarlier "$toolKind" "$toolQuestion" "$askKey" "$toolAddressTo" "$toolRefusalId" "$toolTaskRef" && return 0
	fi
	if [ -n "$toolAddressTo" ] && type AgentsToolsAskThreadFind > /dev/null 2>&1 ; then
		## Finding, posting and recording are one step per addressee, so two askers at once
		## never both post the same question or take the same number. Given back on every
		## way out below, up to the record being written.
		if type AgentsToolsLocalLockTake > /dev/null 2>&1 && AgentsToolsLocalLockTake "ask-thread-$( printf '%s' "$toolAddressTo" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' )" 60 "the questions to $toolAddressTo" ; then
			askLock="$agentsLocalLockPath"
		else
			printf 'WARNING: %s: the question lock for %s could not be taken, so this question is posted without it, and its number may repeat one asked at the same moment.\n' "$harnessAskName" "$toolAddressTo" >&2
		fi
		askWhere="$( AgentsToolsAskThreadFind "$toolTo" "$toolAddressTo" "$askKey" "$harnessAgent" )"
		## A proposal always opens its own thread: the thread of one closed before is never joined.
		case "$toolKind:$askWhere" in proposal:SAME$'\t'*) askWhere="" ;; esac
	fi
	## The same question, asked of the human-owner before under a member's own account,
	## stands in a conversation the bot is not in: asked again it is a new message of the
	## bot's, never a reply there. One the bot asked keeps its own thread, as below.
	if [ -n "$askOwnerBot" ] ; then
		case "$askWhere" in
			SAME$'\t'*$'\t'bot) ;;
			SAME$'\t'*) askWhere="" ;;
		esac
	fi
	## A FURTHER REFUSED CALL, while a permission question of this session to the human-owner is
	## still open and unanswered, makes no new prompt: it is added to the open one, which then
	## asks for every call in one post, and one answer covers them all
	## (--intern-op-escalation-permission-add, AgentsTools.MemberEscalation.include). Added,
	## nothing is posted or recorded here, and this call waits on that prompt as on its own.
	## A call the open prompt asks for already is the same question, already open. Anything
	## else -- no open prompt, one answered, an operation that fails -- leaves this ask exactly
	## as it was made: a prompt of its own.
	local askJoined="" askJoinedOut=""
	if [ -n "$askOwnerBot" ] && [ "$toolKind" = "permission" ] && [ -z "$toolEntries" ] && [ -n "$toolRefusalId" ] && [ -n "$harnessAgent" ] ; then
		askJoinedOut="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-escalation-permission-add "$harnessAgent" \
			--session-id "$askSession" --refusal-id "$toolRefusalId" --reason "$toolReason" --context "$harnessAskName" 2> /dev/null )" || askJoinedOut=""
		case "$askJoinedOut" in
			'ADDED: '*)
				askJoined="${askJoinedOut%%$'\n'*}" ; askJoined="${askJoined#ADDED: }"
				askWhere=""
				askRouteNote="${askRouteNote:+$askRouteNote$'\n'}NOTE: no new prompt was posted. This call is added to the open permission prompt of this session to the human-owner, pending reply $askJoined, which now asks for $( printf '%s\n' "$askJoinedOut" | LC_ALL=C sed -n 's/^ENTRIES: //p' | head -1 ) calls in one post. One answer covers them all: allow-set grants every call of it for this session, deny grants none."
			;;
			'THERE: '*)
				askJoinedOut="${askJoinedOut%%$'\n'*}"
				askWhere="DUPLICATE"$'\t'"${askJoinedOut#THERE: }"$'\t'"$harnessAgent"$'\t'"$askSession"
			;;
		esac
	fi
	## THE WHOLE NEED OF A TASK IN ONE ASK. With entries the request is a Permission set of the
	## asking member, for its task, asked by the team operation that asks every set
	## (--intern-op-permission-set-ask, AgentsTools.InternOpPermission.include): one post, one
	## answer, one grant. Nothing is posted or recorded here, and this call waits on that set
	## as on a prompt of its own. Among the entries a line `purpose: <text>` says what the
	## entries since the one before it are for; the reason says what the whole access is for.
	## A set that is not asked comes back as what stopped it: an entry to correct, an ask that
	## is open already, or the tooling's own failure, each said as itself.
	if [ -n "$toolEntries" ] ; then
		local askSetArgs=() askSetLine askSetRc=0 askSetSaid=""
		while IFS= read -r askSetLine ; do
			askSetLine="${askSetLine#"${askSetLine%%[![:space:]]*}"}" ; askSetLine="${askSetLine%"${askSetLine##*[![:space:]]}"}"
			case "$askSetLine" in
				'') ;;
				purpose:*) askSetLine="${askSetLine#purpose:}" ; askSetArgs+=( --purpose "${askSetLine#"${askSetLine%%[![:space:]]*}"}" ) ;;
				*) askSetArgs+=( --entry "$askSetLine" ) ;;
			esac
		done <<< "$toolEntries"
		askWhere=""
		askJoinedOut="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-set-ask "$harnessAgent" \
			--session-id "$askSession" --refusal-id "$toolRefusalId" --task-ref "$toolTaskRef" --reason "$toolReason" "${askSetArgs[@]}" 2> "$harnessScratch/set-ask.err" )" || askSetRc=$?
		case "$askSetRc:$askJoinedOut" in
			0:'THERE: '*)
				askJoinedOut="${askJoinedOut%%$'\n'*}"
				askWhere="DUPLICATE"$'\t'"${askJoinedOut#THERE: }"$'\t'"$harnessAgent"$'\t'"$askSession"
			;;
			0:*'PERMISSION-SET: asked '*)
				askJoined="$( printf '%s\n' "$askJoinedOut" | LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' | head -1 )"
				askSetSaid="$( printf '%s\n' "$askJoinedOut" | LC_ALL=C sed -n 's/^SCOPE: //p' | head -1 )"
				case "$askSetSaid" in
					'task '?*) askSetSaid="for the task ${askSetSaid#task }" ;;
					*) askSetSaid="for this session" ;;
				esac
				askRouteNote="${askSetNote:+$askSetNote$'\n'}NOTE: asked as one Permission set, pending reply $askJoined: $( printf '%s\n' "$askJoinedOut" | LC_ALL=C sed -n 's/^ENTRIES: //p' | head -1 ) entries for $harnessAgent, $askSetSaid. One answer of the human-owner covers them all: allow-set grants every entry, deny grants none, and edit returns the set to you with the change to make."
			;;
			0:*'PERMISSION-SET: held'*)
				[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
				printf 'CORRECTION: %s: nothing was asked: you hold every entry already, so there is nothing to ask for. Make the refused call again.\n' "$harnessAskName"
				return 0
			;;
			*)
				[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
				## Its own lines only: what the request said as it stopped, the operation's name taken off.
				askSetSaid="$( LC_ALL=C grep -e '^CORRECTION: ' -e 'permission-set-ask: ⛔ ERROR: ' "$harnessScratch/set-ask.err" 2> /dev/null \
					| LC_ALL=C sed -e 's/^CORRECTION: [^:]*: //' -e 's/^.*permission-set-ask: ⛔ ERROR: //' | head -3 )"
				case "$askSetRc:$askJoinedOut" in
					6:*) printf 'CORRECTION: %s: %s\n' "$harnessAskName" "${askSetSaid:-nothing was asked.}" ;;
					## Before its participants are said nothing is posted: an entry stopped it.
					*'PARTICIPANTS: '*) printf 'ERROR: %s: the Permission set could not be asked, so no answer is pending. What the request reported follows:\n%s\n' "$harnessAskName" "${askSetSaid:-$( cat "$harnessScratch/set-ask.err" 2> /dev/null )}" ;;
					*) printf 'CORRECTION: %s: nothing was asked: %s. Correct the entries and ask again.\n' "$harnessAskName" "${askSetSaid:-the request was refused before anything was posted}" ;;
				esac
				return 0
			;;
		esac
	fi
	## A STREAM OF CALLS ASKED ALONE IS STOPPED HERE. A call asked alone that would be one more
	## prompt to the human-owner is not posted once he has answered as many of this session
	## for this task as the one number allows (--intern-op-permission-single-asks; the number
	## is agentsPermissionSingleAsks, AgentsTools.PermissionHolds.include): it goes back to its
	## asker, to be asked with everything else the task still needs. A set never comes here;
	## nor does a call added to an open prompt, one that is open already, or one asked of a
	## member or the coordinator.
	if [ -n "$askOwnerBot" ] && [ "$toolKind" = "permission" ] && [ -z "$toolEntries" ] && [ -z "$askJoined" ] && [ -n "$harnessAgent" ] ; then
		local askSingles=""
		case "$askWhere" in
			DUPLICATE$'\t'*) ;;
			*)
				askSingles="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-single-asks "$harnessAgent" \
					--session-id "$askSession" --task-ref "$toolTaskRef" 2> /dev/null )" || askSingles=""
			;;
		esac
		case "$askSingles" in
			'SINGLE-ASKS: stop '*)
				[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
				askSingles="${askSingles#SINGLE-ASKS: stop }"
				printf 'CORRECTION: %s: nothing was posted. A session asks the human-owner for one call alone at most %s time(s) for a task, and he has already answered that many of this session for this task: pending reply %s. Ask once for what the rest of the task needs: call %s again with this refusal_id and entries, one entry for each place, written Tool,Tool:<folder>/**, with every tool you will use there, in every workspace the task touches, and say what the access is for. The entries must cover the refused call.\n' \
					"$harnessAskName" "$( printf '%s\n' "${askSingles%%$'\n'*}" | LC_ALL=C awk '{ print $2 ; }' )" \
					"$( printf '%s\n' "$askSingles" | LC_ALL=C sed -n 's/^ANSWERED: //p' | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//' -e 's/ /, /g' )" "$harnessAskName"
				return 0
			;;
		esac
	fi
	case "$askWhere" in
		DUPLICATE$'\t'*)
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			IFS=$'\t' read -r _ askDupId askDupOwner askDupSession <<< "$askWhere"
			## Asking again is not how an answer is found: its thread is read first, and an
			## answer already there closes the record and is returned, with nothing posted.
			local askDupCollected=""
			askDupCollected="$( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-pending-reply-collect \
				--id "$askDupId" --context "$harnessAskName" 2>/dev/null | LC_ALL=C grep '^ANSWERED ' )" || askDupCollected=""
			if [ -n "$askDupCollected" ] ; then
				AgentsHarnessAskWaitItem drop "$askDupId" || :
				printf 'ASK-RESULT: RECEIVED\nThe same question to %s was already asked as pending reply %s, and its thread already holds the answer, so nothing was posted and the record is now closed. What the tooling collected, as `ANSWERED <id> <tag> | <question> | <answer>`:\n%s\n' "$toolAddressTo" "$askDupId" "$askDupCollected"
				return 0
			fi
			printf 'ASK-RESULT: ALREADY-OPEN\nThe same question to %s is already open as pending reply %s, asked by %s%s, so it was not posted again.\n' "$toolAddressTo" "$askDupId" "${askDupOwner:-an unknown member}" "${askDupSession:+ in session $askDupSession}"
			if [ -n "$askDupSession" ] && [ "$askDupSession" = "$( AgentsHarnessSessionKey )" ] ; then
				AgentsHarnessAskWaitNext "$askDupId"
				printf '%s pending_id=%s\n' "$harnessAskName" "$askDupId"
			fi
			return 0
		;;
		SAME$'\t'*)
			## The same question, asked before and closed: asked again it is still that
			## question, so it goes into its own thread under its own number, never into a
			## new top-level message -- and under the identity it was asked with, the one
			## that can post in that conversation.
			## Split by hand: a tab is IFS whitespace, so read would drop the empty number field.
			local askSameRest="${askWhere#SAME$'\t'}" askSameChannel=""
			askSameChannel="${askSameRest%%$'\t'*}" ; askSameRest="${askSameRest#*$'\t'}"
			toolTo="$askSameChannel:${askSameRest%%$'\t'*}" ; askSameRest="${askSameRest#*$'\t'}"
			askTag="${askSameRest%%$'\t'*}"
			case "${askSameRest##*$'\t'}" in
				bot) toolAsBot="true" ;;
				*) toolAsBot="false" ;;
			esac
		;;
	esac
	## Only a question posted into a thread `to` names is numbered, since only there can
	## several questions share one thread; a top-level question carries no number. The
	## number is the person's, not the thread's: one counter per addressee, taken while
	## the ask-thread lock is held, so the same person never sees two questions called Q1.
	## A question asked into the thread another question opened for itself is a follow-up
	## on that same question, and keeps its number, or its having none.
	case "$askWhere" in
		SAME$'\t'*) ;;
		*)
			case "${toolTo#client:}" in
				*:*)
					if ! type AgentsToolsAskThreadRootTag > /dev/null 2>&1 || ! askTag="$( AgentsToolsAskThreadRootTag "${toolTo%:*}" "${toolTo##*:}" )" ; then
						askTag="Q1"
						if [ -n "$toolAddressTo" ] && type AgentsToolsAskThreadNextTag > /dev/null 2>&1 ; then
							askTag="$( AgentsToolsAskThreadNextTag "$toolAddressTo" )"
						fi
					fi
				;;
			esac
		;;
	esac
	## The post is its tool's own template, filled (sh-lib/templates/): its title and icon, its
	## fields, and how to answer its answer form. A required field left empty refuses here.
	askBody="$( AgentsHarnessAskBody )" || askBody=""
	if [ -z "$askBody" ] ; then
		[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
		printf 'ERROR: %s: the post could not be filled from its template, so nothing was sent. What the fill reported follows:\n%s\n' "$harnessAskName" "$( cat "$harnessScratch/ask-post.err" 2>/dev/null )"
		return 0
	fi
	## A proposal opens its thread with its root, the question alone, and is itself the reply
	## under it. Both are filled before anything is sent, so no root is posted with no proposal.
	local askRootBody="" askLiveTs=""
	if [ "$toolKind" = "proposal" ] ; then
		askRootBody="$( AgentsHarnessAskRootBody )" || askRootBody=""
		if [ -z "$askRootBody" ] ; then
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			printf 'ERROR: %s: the root of the proposal could not be filled from its template, so nothing was sent. What the fill reported follows:\n%s\n' "$harnessAskName" "$( cat "$harnessScratch/ask-post.err" 2>/dev/null )"
			return 0
		fi
	fi
	if [ -z "$toolAddressTo" ] ; then
		case "${toolTo#client:}" in
			*:*|event-track|event-alert)
			;;
			*)
				toolAddressTo="$toolTo"
			;;
		esac
	fi
	if [ -z "$toolAddressTo" ] ; then
		printf 'ERROR: %s: `to` names a message, a thread or a place (%s) rather than a party, so address_to is required and was empty. An answer is recognised by who wrote it, so a question addressed to nobody could be answered by anybody. Nothing was sent.\n' "$harnessAskName" "$toolTo" ; return 0
	fi
	## One post, the question itself: to a person or a conversation it is a new top-level
	## message, whose own thread carries its answer and whatever discussion follows it; to
	## a thread (<channel>:<ts>, the parent's) it is a reply there. No opener goes ahead of it.
	if [ -n "$askRoutine" ] ; then
		askSent="(addressed to $askRoutine: nothing was posted; its executors answer it through the team operation)"
	elif [ -n "$askJoined" ] ; then
		## Added to the open prompt: nothing is posted, and where that prompt stands is read
		## from what the operation printed, as from a send.
		askSent="$askJoinedOut"
	else
		askSent="$( harnessSendProse="$( AgentsHarnessAskProse )" AgentsHarnessToolSendMessage "$toolTo" "${askRootBody:-$askBody}" "$toolAsBot" "$toolAddressTo" "" true )"
	fi
	case "$askSent" in
		## Over the plain-language floor: a correction to make, passed on as it is. Nobody was
		## asked and nothing is pending, until the corrected question is sent.
		CORRECTION:*)
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			printf '%s\n' "$askSent"
			return 0
		;;
		ERROR:*)
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			printf 'ERROR: %s: the question could NOT be posted, so nobody was asked and no answer is pending anywhere. THE QUESTION DOES NOT EXIST: this is not a question that went unanswered, and it will not be answered later. The plain-language floor (%s/magic-team/magic-team.shared.md) is not what stopped it: a question over the floor comes back as CORRECTION, never as this error -- clear what the send reported and ask it again. What the send reported follows:\n%s\n' "$harnessAskName" "${MDAT_SKILLSET_ROOT:-}" "$askSent"
			return 0
		;;
	esac
	## The question is posted, so from here it is a pending reply and is recorded as
	## one. Recorded only now, never before the send: a question that was never posted
	## is not a question nobody answered, and this tool's whole contract rests on those
	## two never reading alike. The record is what lets a reply resume the work, or an
	## unanswered question be re-asked, after this session is gone -- so it is written
	## whether or not anybody waits here.
	askChannel="$( printf '%s\n' "$askSent" | LC_ALL=C sed -n 's/^SENT_MESSAGE_CHANNEL=//p' | head -1 )"
	askTs="$( printf '%s\n' "$askSent" | LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' | head -1 )"
	askThreadTs="$( printf '%s\n' "$askSent" | LC_ALL=C sed -n 's/^SENT_MESSAGE_THREAD_TS=//p' | head -1 )"
	askAddressees="$( printf '%s\n' "$askSent" | LC_ALL=C sed -n 's/^SENT_MESSAGE_ADDRESSEES=//p' | head -1 )"
	## A member with no account of its own is asked by its name and answers under the team's
	## account: its name stands among the accounts that answer, and every reader of the answer
	## tells its reply by the sender the tooling recorded on it (AgentsSlackThreadAnswers.awk).
	askAddressees="$askAddressees $( printf '%s\n' "$askSent" | LC_ALL=C sed -n 's/^SENT_MESSAGE_ADDRESSEE_MEMBERS=//p' | head -1 )"
	askAddressees="${askAddressees# }" ; askAddressees="${askAddressees% }"
	## The account this question was posted under never answers it, whatever address_to said.
	askSelfIds=" $( printf '%s\n' "$askSent" | LC_ALL=C grep '^{' | LC_ALL=C awk -v path=message.user -v optional=1 -v dialect=slack -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsHarnessJsonField.awk" 2>/dev/null | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"
	[ -z "$askRoutine" ] || askSelfIds=""
	## A proposal: its root is posted, and the proposal goes under it, the reply answers are read after.
	if [ -n "$askRootBody" ] && ! AgentsHarnessAskProposalReply ; then
		[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
		return 0
	fi
	[ -n "$askJoined" ] && askPendingId="$askJoined" || askPendingId="$( AgentsHarnessPendingReplyOpen "$toolTo" "${askRootBody:+$askRootBody$'\n\n'}$askBody" "$toolKind" "$toolAddressTo" "$askChannel" "$askTs" "$askThreadTs" "$askAddressees" "$askSelfIds" "$toolRefusalId" "$toolOptions" "$askTag" "$askKey" "$toolAsBot" "$toolTaskRef" "$toolReason" "$toolSelect" "$( AgentsHarnessAskFields )" "$askLiveTs" )"
	[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
	## The answer emoji go under the question itself, as the identity that posted it. A call
	## added to an open prompt places none: that prompt has its own.
	[ -n "$askRoutine" ] || [ -n "$askJoined" ] || [ -z "$askChannel" ] || [ -z "$askTs" ] || AgentsHarnessAskReact "$askChannel:$askTs" "$toolAsBot" add $( AgentsHarnessAskSeedNames )
	## An ask to a routine exists only as its record.
	if [ -n "$askRoutine" ] && [ -z "$askPendingId" ] ; then
		printf 'ERROR: %s: the question to %s could not be recorded, and nothing was posted, so THE QUESTION DOES NOT EXIST and nobody was asked. Ask it again.\n' "$harnessAskName" "$askRoutine" ; return 0
	fi
	fi ## end of the posting path
	## An escalation is answered before the work goes on, so a typed kind always waits.
	local askWaitNote=""
	case "$toolKind:$toolWait" in
		question:*) ;;
		*:false|*:0|*:no)
			askWaitNote="wait=false was ignored: a $toolKind question is an escalation, and it always waits for its answer."
			toolWait="true"
		;;
	esac
	case "$toolWait" in
		false|0|no)
			printf 'ASK-RESULT: POSTED\nThe question is posted to %s and no wait was asked for, so no answer was collected here. It stands and stays answerable, and can be picked up later%s. What the send reported follows:\n%s\n' "$toolTo" "${askPendingId:+ -- recorded as pending reply $askPendingId}" "$askSent"
			AgentsHarnessAskWaitNext "$askPendingId"
			return 0
		;;
	esac
	if [ -z "$toolSource" ] ; then
		## An ask to a routine, a re-wait on one included (even re-addressed since), has no thread:
		## its record is what is watched.
		case "$toolTo" in *:*) ;; *.routine) askRoutine="$toolTo" ;; esac
		if [ -z "$askRoutine" ] && { [ -z "$askChannel" ] || [ -z "$askThreadTs" ] || [ -z "$askTs" ] ; } ; then
			printf 'ASK-RESULT: POSTED\nThe question is posted to %s%s and NO WAIT WAS PERFORMED. The send could not name the thread it landed in, so there is no one thread to watch. Widening to the whole conversation is refused here: anything found there would not be known to answer this. Nothing is known about whether it was answered. What the send reported follows:\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId}" "$askSent"
			[ -z "$askRouteNote" ] || printf '%s\n' "$askRouteNote"
			return 0
		fi
		## An escalation to a member with no Slack account is answered through the team
		## operation, which closes its record, so the record itself is what is watched.
		if [ -z "$askAddressees" ] && [ "$toolKind" != "question" ] && [ -n "$askPendingId" ] && AgentsHarnessBareName "$toolAddressTo" ; then
			askRecordOnly=1
			askTs=""
			toolSource="file:$MMDAPP/.local/agents/pending/$askPendingId.md"
		fi
		if [ -z "$askAddressees" ] && [ -z "$askRecordOnly" ] ; then
			printf 'ASK-RESULT: POSTED\nThe question is posted to %s%s and NO WAIT WAS PERFORMED. Nobody resolved as its addressee, so no arrival could be told apart from an unrelated message, or from our own next post. Nothing is known about whether it was answered. Ask again naming address_to. What the send reported follows:\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId}" "$askSent"
			[ -z "$askRouteNote" ] || printf '%s\n' "$askRouteNote"
			return 0
		fi
		[ -n "$askRecordOnly" ] || toolSource="slack:$askChannel:$askThreadTs"
		## The wait IS the session's Wait: the question's wait item joins this session's wait set
		## and is what is waited on, read by the same probe a later Wait reads it with. Only a
		## question with no record falls back to its thread named directly.
		if [ -n "$askPendingId" ] ; then
			## Added, this call waits on the stored wait whole -- the session's other open asks and
			## every other source it holds -- and returns on whatever of it arrives, as a Wait does.
			AgentsHarnessAskWaitItem add "$askPendingId" && askSessionWait=1 || :
			toolSource="ask:$askPendingId"
			askTs=""
			askAddressees=""
		fi
	fi
	if AgentsHarnessWholeNumber "$toolTimeout" && [ "$toolTimeout" -lt 1 ] ; then
		toolTimeout="$harnessWaitTimeout"
	fi
	## An escalation answered through the team operation is seen between rounds, so its rounds stay short.
	if [ "$toolKind" != "question" ] && { ! AgentsHarnessWholeNumber "$toolTimeout" || [ "$toolTimeout" -gt 60 ] ; } ; then
		toolTimeout=60
	fi
	local askNeverRead="" askAnsweredElsewhere=""
	## THE ROUND. A call that waits on the session's stored wait comes back, with nothing
	## arrived, a little sooner than the prompt cache of the CLI service the session runs on
	## expires (AgentsTools.CliService.include), as its Wait does: the turn that goes on
	## waiting then reads the session's history from that cache.
	local askStarted="" askRound=""
	askStarted="$( date +%s )"
	if [ -n "$askSessionWait" ] ; then
		type AgentsToolsCliServiceWaitRound > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.CliService.include" 2> /dev/null || :
		! type AgentsToolsCliServiceWaitRound > /dev/null 2>&1 || askRound="$( AgentsToolsCliServiceWaitRound "$( AgentsToolsCliServiceOfSession "$( AgentsHarnessSessionKey )" )" )"
		AgentsHarnessWholeNumber "$askRound" || askRound=""
		## A served call comes back by its own bound too, where that is the shorter.
		[ -z "$askRound" ] || [ -z "$harnessServedWaitBound" ] || [ "$askRound" -le "$harnessServedWaitBound" ] || askRound="$harnessServedWaitBound"
	fi
	while : ; do
		askRounds=$(( askRounds + 1 ))
		if [ -n "$askSessionWait" ] ; then
			askWaitOut="$( AgentsHarnessToolWait "" "$toolTimeout" "" "" "" "" continue "" "" "" "" ask )"
			## A stored wait that cannot be run costs the ask nothing: its own answer is waited for alone.
			case "$askWaitOut" in
				ERROR:*)
					askSessionWait=""
					askWaitNote="${askWaitNote:+$askWaitNote$'\n'}NOTE: the stored wait of this session could not be run, so this call waited for its own answer alone and for nothing else the session waits on. What the wait reported: $( printf '%s\n' "$askWaitOut" | LC_ALL=C sed -n '2p' )"
				;;
			esac
		fi
		[ -n "$askSessionWait" ] || askWaitOut="$( AgentsHarnessToolWait "$toolSource" "$toolTimeout" "" "$askTs" "$askAddressees" )"
		case "${askWaitOut%%$'\n'*}" in
			*TIMEOUT*)
				## An escalation answered where this wait does not read -- through the team operation,
				## or in the thread of its forward -- is found by its own read, which stands whether or
				## not this round could read the question's thread.
				if [ "$toolKind" != "question" ] ; then
					case "$( AgentsHarnessEscalationRead "$askPendingId" )" in
						*"ESCALATION: $askPendingId answered"*) askAnsweredElsewhere=1 ; break ;;
					esac
				fi
				## A round that never read the thread is not a quiet thread, so it ends the wait.
				askNeverRead="${askWaitOut#*$'\n'WAIT-NEVER-READ: }"
				if [ "$askNeverRead" != "$askWaitOut" ] ; then
					askNeverRead="${askNeverRead%%$'\n'*}"
					case "$askNeverRead" in
						*"[$toolSource]"*) break ;;
					esac
				fi
				askNeverRead=""
				## The round is over and nothing arrived: one line, the call that goes on waiting.
				## The ask stays open and in the Wait set.
				if [ -n "$askRound" ] && [ $(( $( date +%s ) - askStarted )) -ge "$askRound" ] ; then
					printf 'ASK-RESULT: TIMEOUT (%ss) NEXT: %s pending_id=%s\n' "$(( $( date +%s ) - askStarted ))" "$harnessAskName" "$askPendingId"
					return 0
				fi
			;;
			*RECEIVED*)
				## Any filtered arrival ends the wait: a reply that classifies nothing goes back to
				## the agent as RETURNED with the record open, and the agent may re-wait on it.
				break
			;;
			*)
				break
			;;
		esac
	done
	## The stored wait returns on whatever of it arrives. What is not this call's own answer is
	## taken as a Wait takes it and given to the asker, saying what it is. With the own answer
	## not among it, the call returns on that: the ask stays open and in the Wait set, and the
	## last lines are the exact calls that go on waiting for it.
	if [ -n "$askSessionWait" ] && [ -z "$askAnsweredElsewhere" ] ; then
		case "${askWaitOut%%$'\n'*}" in
			'WAIT-RESULT: RECEIVED'*)
				askOthers="$( AgentsHarnessAskSessionArrivals "$askPendingId" "$askWaitOut" )"
				if [ ! -s "$harnessScratch/ask-own.out" ] ; then
					printf 'ASK-RESULT: ARRIVED-OTHER\nThis call returned because something else this session waits on arrived, and not the answer to what it asked. Pending reply %s (%s) is NOT answered yet: it stays open and in your Wait set, and nothing about it is lost. What arrived follows, each part saying what it is. Read it, then go on waiting for this answer with the call on the last line, which posts nothing.\n' "$askPendingId" "$toolKind"
					[ -z "$askRouteNote" ] || printf '%s\n' "$askRouteNote"
					[ -z "$askWaitNote" ] || printf '%s\n' "$askWaitNote"
					printf '%s\n' "$askOthers"
					AgentsHarnessAskWaitNext "$askPendingId"
					printf '%s pending_id=%s\n' "$harnessAskName" "$askPendingId"
					return 0
				fi
				[ -z "$askOthers" ] || askWaitOut="$( cat "$harnessScratch/ask-own.out" )"
			;;
		esac
	fi
	if [ -n "$askNeverRead" ] ; then
		printf 'ERROR: %s: the question WAS posted to %s%s, and then its thread could not be read at all, so NOTHING is known about whether it was answered. Its silence must not be read as quiet. What the wait reported follows:\n%s\n' "$harnessAskName" "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId, still open}" "$askWaitOut"
		[ -z "$askRouteNote" ] || printf '%s\n' "$askRouteNote"
		[ "$toolSource" != "ask:$askPendingId" ] || AgentsHarnessAskWaitNext "$askPendingId"
		return 0
	fi
	case "$askWaitOut" in
		ERROR:*)
			printf 'ERROR: %s: the question WAS posted to %s%s, and then the wait for an answer could not be performed -- so the question stands and NOTHING is known about whether it was answered. Its silence must not be read as quiet. What the wait reported follows:\n%s\n' "$harnessAskName" "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId, still open}" "$askWaitOut"
			[ -z "$askRouteNote" ] || printf '%s\n' "$askRouteNote"
			[ "$toolSource" != "ask:$askPendingId" ] || AgentsHarnessAskWaitNext "$askPendingId"
			return 0
		;;
	esac
	AgentsHarnessAskResolve "$askPendingId" "$toolKind" "$askTag" "$askWaitOut" "$askAnsweredElsewhere" "$askWaitNote${askSelectNote:+${askWaitNote:+$'\n'}$askSelectNote}" ask \
		"$( printf '%sThe question was posted to %s%s, and its own thread%s was watched over %s wait round(s). What the wait returned follows verbatim.\n%s' "${askRouteNote:+$askRouteNote$'\n'}" "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId}" "${askThreadTs:+ (slack:$askChannel:$askThreadTs)}" "$askRounds" "$askWaitOut" )"
	[ -z "$askOthers" ] || printf 'ALSO-ARRIVED: in the same wait, beside the answer above, something else this session waits on arrived. It follows, each part saying what it is.\n%s\n' "$askOthers"
}

## What a round of the session's stored wait brought to an asking call, told apart. The part
## of the call's own ask is left in $harnessScratch/ask-own.out, as a wait that returned it
## alone would have printed it; empty when that ask did not arrive. Everything else that
## arrived is printed: each source as the wait showed it, then each arrived ask taken into its
## record as a Wait takes it (AgentsHarnessWaitAskResolve). Nothing is printed when the own
## ask is all that arrived.
AgentsHarnessAskSessionArrivals(){ ## own pending reply id, wait output
	printf '%s\n' "$2" | LC_ALL=C awk -v ownHead="# arrived on: ask:$1" -v ownFile="$harnessScratch/ask-own.out" -v otherFile="$harnessScratch/ask-others.out" '
		BEGIN { printf "" > ownFile ; printf "" > otherFile ; }
		$0 == ownHead { inOwn = 1 ; print "WAIT-RESULT: RECEIVED" > ownFile ; }
		inOwn { print > ownFile ; if ( $0 == "# --- end ---" ) { inOwn = 0 ; } next ; }
		{ print > otherFile ; }
	'
	LC_ALL=C grep -q '^# arrived on: ' "$harnessScratch/ask-others.out" 2> /dev/null || return 0
	LC_ALL=C awk '/^# arrived on: / { shown = 1 ; } shown { print ; }' "$harnessScratch/ask-others.out"
	harnessAskName="" AgentsHarnessWaitAskResolve "$harnessScratch/ask-others.out"
}

## What a pending reply's record says, one field: the frontmatter ahead of its body.
AgentsHarnessAskRecordField(){ ## pending reply id, field name
	local fieldLine
	AgentsHarnessBareName "$1" && [ -f "$MMDAPP/.local/agents/pending/$1.md" ] || return 0
	while IFS= read -r fieldLine ; do
		case "$fieldLine" in
			"$2: "*) printf '%s' "${fieldLine#"$2: "}" ; return 0 ;;
			'# '*) return 0 ;;
		esac
	done < "$MMDAPP/.local/agents/pending/$1.md"
}

## An asked question's wait item, ask:<pending-id> (AgentsTools.MemberWait.include), joins this
## session's stored wait when the question is posted and leaves it once answered, so the
## session's next Wait mode=continue covers an answer nobody waited for in the asking call.
## Through the team's own wait operation, never by writing its state from here. rc 1 when it
## could not be added; a drop of an item the stored wait does not hold starts nothing.
AgentsHarnessAskWaitItem(){ ## add|drop, pending reply id
	local itemTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" itemSession itemLine
	[ -n "$2" ] && [ -n "$harnessAgent" ] && [ -x "$itemTools" ] || return 1
	itemSession="$( AgentsHarnessSessionKey )"
	AgentsHarnessBareName "$itemSession" || return 1
	if [ "$1" = "drop" ] ; then
		itemLine="$( LC_ALL=C sed -n 's/^sources: //p' "$MMDAPP/.local/agents/sessions/$itemSession/wait/state" 2>/dev/null | head -1 )"
		case " $itemLine" in
			*" ask:$2 "*) ;;
			*) return 0 ;;
		esac
	fi
	"$BASH" "$itemTools" --intern-op-wait-for-input "$harnessAgent" "--wait-$1" --wait-session-id "$itemSession" --wait-source "ask:$2" > /dev/null 2>&1
}

## The lines that end an ask left open: its wait item, and the Wait that collects its answer.
AgentsHarnessAskWaitNext(){ ## pending reply id
	[ -n "$1" ] || return 0
	printf 'WAIT-ID: ask:%s\n' "$1"
	if AgentsHarnessAskWaitItem add "$1" ; then
		printf 'NEXT: added to your Wait set -- call Wait mode=continue, or start a new wait with Wait sources=ask:%s\n' "$1"
	else
		printf 'NEXT: to wait for the answer, call Wait sources=ask:%s -- it posts nothing\n' "$1"
	fi
}

## How an answer that a wait saw on an asked question is taken into its pending record --
## the one place, for an asking call's own wait and for a Wait whose ask:<pending-id> item
## arrived. Prints the ASK-RESULT block; the caller's own text (shown) goes after it.
## The item leaves the session's wait once its record is no longer pending.
AgentsHarnessAskResolve(){ ## pending reply id, kind, question tag, wait output, answered elsewhere (non-empty) or empty, wait note, caller ask|wait, shown
	local askPendingId="$1" toolKind="${2:-question}" askTag="$3" askWaitOut="$4" askAnsweredElsewhere="$5" askWaitNote="$6" askCaller="$7" askShown="$8"
	local askFirst askOutcome
	## A permission question that took a further call is a Permission set by now
	## (--intern-op-escalation-permission-add): what is said of it follows its record.
	[ "$toolKind" != "permission" ] || [ "$( AgentsHarnessAskRecordField "$askPendingId" kind )" != "permission-set" ] || toolKind="permission-set"
	## The outcome is read off the wait's own first line, each as itself: RECEIVED, TIMEOUT,
	## DISMISSED (a dismissal of this member came where the answer was waited for) or CLOSED.
	## Each directs a different next step, so none is folded into another. A wait that could
	## not run, and a first line this tool does not know, are an ERROR that says which, the
	## unknown line quoted: guessing an outcome for it is the failure this prevents.
	askFirst="${askWaitOut%%$'\n'*}"
	case "$askFirst" in
		'WAIT-RESULT: RECEIVED'*)  askOutcome="RECEIVED" ;;
		'WAIT-RESULT: TIMEOUT'*)   askOutcome="TIMEOUT" ;;
		'WAIT-RESULT: DISMISSED'*) askOutcome="DISMISSED" ;;
		'WAIT-RESULT: CLOSED'*)    askOutcome="CLOSED" ;;
		*)                         askOutcome="ERROR" ;;
	esac
	[ -z "$askAnsweredElsewhere" ] || askOutcome="RECEIVED"
	## Only a received answer closes the record; every other outcome deliberately leaves it
	## open. A timeout is a question still standing, and a pending record never expires by
	## age, so it stays pending for the next wait. An ERROR means nothing whatever is known
	## about whether anybody answered, and recording it as unanswered would assert exactly
	## what was not learned.
	if [ "$askOutcome" = "ERROR" ] ; then
		case "$askFirst" in
			'WAIT-RESULT: ERROR'*|'ERROR'*)
				printf 'ERROR: %s: the wait on pending reply %s could not be performed, so NOTHING is known about whether it was answered, and its record is left as it was. Its silence must not be read as quiet.\n' "${harnessAskName:-Wait}" "${askPendingId:-<none>}"
			;;
			*)
				printf 'ERROR: %s: the wait on pending reply %s returned a first line this tool does not know, so NOTHING is known about whether it was answered, and its record is left as it was. That line: "%s"\n' "${harnessAskName:-Wait}" "${askPendingId:-<none>}" "$askFirst"
			;;
		esac
		[ -z "$askShown" ] || printf '%s\n' "$askShown"
		[ -z "$askPendingId" ] || AgentsHarnessAskWaitNext "$askPendingId"
		return 0
	fi
	## A typed kind's verdict is read and applied by the escalation operation, the one place that does it.
	## A plain question with an answer form (select) takes its verdict the same way.
	local askVerdict="" askReadLines="" askReason="" askForm=""
	[ "$toolKind" != "question" ] || askForm="$( AgentsHarnessAskRecordField "$askPendingId" select )"
	if { [ "$toolKind" != "question" ] || [ -n "$askForm" ] ; } && [ "$askOutcome" = "RECEIVED" ] ; then
		askReadLines="$( AgentsHarnessEscalationRead "$askPendingId" )"
		## The one place that reads a verdict could not read the thread: nothing is known about how
		## it was answered. An ERROR that says so, never RETURNED, and the record is left open.
		case "$askReadLines" in
			*"ESCALATION: $askPendingId unreadable"*)
				printf 'ERROR: %s: something arrived on pending reply %s, and then its thread could not be read for the verdict, so NOTHING is known about how it was answered, and its record is left as it was, open. %s\n' \
					"${harnessAskName:-Wait}" "$askPendingId" "$( printf '%s\n' "$askReadLines" | LC_ALL=C sed -n 's/^UNREADABLE-REASON: //p' | head -1 )"
				[ -z "$askShown" ] || printf '%s\n' "$askShown"
				AgentsHarnessAskWaitNext "$askPendingId"
				return 0
			;;
		esac
		askVerdict="$( printf '%s\n' "$askReadLines" | LC_ALL=C sed -n 's/^VERDICT: //p' | head -1 )"
		askReason="$( printf '%s\n' "$askReadLines" | LC_ALL=C sed -n 's/^VERDICT-REASON: //p' | head -1 )"
		## RETURNED: the reply names none of the answers, so the question comes back to its asker.
		## A read that still says UNCLASSIFIED, the word before it, means the same.
		[ -n "$askVerdict" ] && [ "$askVerdict" != "UNCLASSIFIED" ] || askVerdict="RETURNED"
	fi
	## In a thread several questions share, a reply with no number that came after the latest
	## question above it was already answered answers none of them: it goes back to the
	## asker as RETURNED, with the record open, as a typed kind's would.
	if [ "$toolKind" = "question" ] && [ "$askOutcome" = "RECEIVED" ] \
		&& printf '%s\n' "$askWaitOut" | LC_ALL=C grep -q '^UNMATCHED-REPLY ' \
		&& ! printf '%s\n' "$askWaitOut" | LC_ALL=C grep -q -E '^([0-9]+\.[0-9]+ \| |reaction on the question: )' ; then
		askVerdict="RETURNED"
		askReason="a reply with no question number came after the latest question above it was already answered, so it answers none -- a reply to this question starts with the plain text ${askTag:-its number}"
	fi
	case "$askOutcome:$toolKind:$askVerdict" in
		RECEIVED:question:)
			## The reply taken as the answer, so the close can mark it :eyes:, and its text and
			## author, so the record and the item's Decisions keep what the answer said. Its
			## first line is the answer; the rest of it, and every later reply, are kept as
			## clarifications on it (AgentsPendingReplyClarifications.awk).
			local askAnswerHead="" askAnswerText="" askAnswerBody="" askAnswerTs="" askClarify=""
			askAnswerBody="$( AgentsHarnessAskAnswerBody "$askWaitOut" "$askPendingId" )"
			askAnswerHead="$( printf '%s\n' "$askAnswerBody" | LC_ALL=C grep -m1 -E '^([0-9]+\.[0-9]+ \| |reaction on the question: )' )" || askAnswerHead=""
			case "$askAnswerHead" in
				'reaction on the question: '*) askAnswerText="$askAnswerHead" ;;
				?*) askAnswerText="$( printf '%s\n' "$askAnswerBody" | AgentsHarnessAskOwnWords | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsPendingReplyAnswerText.awk" 2>/dev/null )" || askAnswerText="" ;;
			esac
			askAnswerTs="$( printf '%s\n' "$askAnswerBody" | LC_ALL=C sed -n -E 's/^([0-9]+\.[0-9]+) \| .*/\1/p' | head -1 )"
			AgentsHarnessPendingReplyClose "$askPendingId" reply-received "$askAnswerText" "$askAnswerTs" \
				"$( printf '%s\n' "$askAnswerHead" | LC_ALL=C sed -n -E 's/^[0-9]+\.[0-9]+ \| ([^|]*[^| ]) *\|.*/\1/p' )"
			case "$askAnswerHead" in
				'reaction on the question: '*) askAnswerTs="$( AgentsHarnessAskRecordField "$askPendingId" question-ts )" ;;
			esac
			[ -z "$askAnswerTs" ] || askClarify="$( printf '%s\n' "$askAnswerBody" | AgentsHarnessAskOwnWords | LC_ALL=C awk -v answerTs="$askAnswerTs" \
				-f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsPendingReplyClarifications.awk" 2>/dev/null )" || askClarify=""
			## The thread stays watched from the newest message read here, so a later one is new.
			AgentsHarnessAskKeepClarifications "$askPendingId" "$askClarify" "$( printf '%s\n' "$askAnswerBody" | LC_ALL=C awk '/^[0-9]+\.[0-9]+ \| / { ts = $1 ; } END { print ts ; }' )" close > /dev/null
		;;
	esac
	## A plain question answered through an operation, the console's among them, stands in no
	## thread: its record carries the words and who gave them (answered-session says it came
	## that way), and they are given to its asker as a verdict and its giver are.
	if [ "$askOutcome:$toolKind:$askVerdict" = "RECEIVED:question:" ] && [ -z "$askForm" ] && [ -n "$askPendingId" ] \
		&& [ "$( AgentsHarnessAskRecordField "$askPendingId" status )" = "reply-received" ] && [ -n "$( AgentsHarnessAskRecordField "$askPendingId" answered-session )" ] ; then
		askVerdict="$( AgentsHarnessAskRecordField "$askPendingId" verdict )"
		askReadLines="ANSWERED-BY: $( AgentsHarnessAskRecordField "$askPendingId" answered-by )"
	fi
	printf 'ASK-RESULT: %s\n' "$askOutcome"
	[ -z "$askVerdict" ] || printf 'VERDICT: %s\n' "$askVerdict"
	[ -z "$askReadLines" ] || printf '%s\n' "$askReadLines" | LC_ALL=C grep -E '^(VERDICT-TEXT|ANSWERED-BY|CLOSED-BY|GRANT|CHANGE): ' || :
	[ -z "$askReadLines" ] || AgentsHarnessAskLaterSaid "$askWaitOut"
	[ -z "$askWaitNote" ] || printf '%s\n' "$askWaitNote"
	## An outcome that collected no answer says what it means for the question: it stays open.
	case "$askOutcome" in
		TIMEOUT)
			printf 'No answer arrived within this wait. Pending reply %s stays open: a pending reply never expires by age.\n' "${askPendingId:-<none>}"
		;;
		DISMISSED)
			printf 'You were dismissed where this answer was waited for, so none was collected here. Pending reply %s stays open, and is answered or withdrawn as any other: %s pending_id=%s withdraw=<why> discards it where it is no longer needed.\n' \
				"${askPendingId:-<none>}" "${harnessAskName:-AskQuestion}" "${askPendingId:-<none>}"
		;;
		CLOSED)
			printf 'The wait was closed before an answer came, so none was collected here. Pending reply %s stays open.\n' "${askPendingId:-<none>}"
		;;
	esac
	if [ "$askVerdict" = "RETURNED" ] ; then
		printf 'VERDICT-REASON: %s\n' "${askReason:-the reply names none of the answers this kind takes}"
		## What it may mean, and the ways on, each with its exact call: the template's own words.
		AgentsHarnessAskReturnedHint "$askPendingId" "$toolKind" "$askForm" "$( [ "$askCaller" != "ask" ] || printf '%s' "$harnessAskName" )"
		if [ "$askCaller" = "wait" ] ; then
			printf 'Record %s stays open and in your Wait set: Wait mode=continue returns the next reply or click, and posts nothing.\n' "${askPendingId:-<none>}"
		else
			printf 'Record %s stays open. To wait for the next reply or click, call Wait as the NEXT: line says, or the call on the last line. Neither posts anything.\n' "${askPendingId:-<none>}"
		fi
	fi
	[ -z "$askShown" ] || printf '%s\n' "$askShown"
	## Still pending, the item stays for the next Wait. Answered, it stays too while its thread
	## is watched (a follow floor): a later message there is a clarification or correction kept
	## with the answer, until the session ends. Closed any other way, it leaves the Wait set.
	if [ -n "$askPendingId" ] && [ "$( AgentsHarnessAskRecordField "$askPendingId" status )" != "reply-pending" ] ; then
		if [ "$( AgentsHarnessAskRecordField "$askPendingId" status )" = "reply-received" ] && [ -n "$( AgentsHarnessAskRecordField "$askPendingId" follow-floor )" ] ; then
			AgentsHarnessAskWaitItem add "$askPendingId" || :
			printf 'Pending reply %s stays in your Wait set, and its thread stays watched: a later message there arrives on Wait as ASK-RESULT: CLARIFIED, kept with the answer.\n' "$askPendingId"
		else
			AgentsHarnessAskWaitItem drop "$askPendingId" || :
		fi
	fi
	## An outcome with no answer names its own next step: a dismissal ends the run, a timeout
	## or a closed wait leaves the answer to the next Wait.
	case "$askOutcome" in
		DISMISSED)
			printf 'NEXT: you are dismissed -- give your handback if you have not, then end your run\n'
			return 0
		;;
		TIMEOUT|CLOSED)
			[ -z "$askPendingId" ] || AgentsHarnessAskWaitNext "$askPendingId"
			return 0
		;;
	esac
	[ "$askCaller" = "ask" ] && [ "$askVerdict" = "RETURNED" ] && [ -n "$askPendingId" ] || return 0
	AgentsHarnessAskWaitNext "$askPendingId"
	printf '%s pending_id=%s\n' "$harnessAskName" "$askPendingId"
}

## What the asker of a returned question is told: the hint of its tool's own template
## (`# Returned`), saying what the reply may mean, with the exact call of each way on.
AgentsHarnessAskReturnedHint(){ ## pending reply id, kind, answer form (empty for none), the tool name as called (empty: the tool of that kind)
	local hintId="${1:-<none>}" hintTool="${4:-}" hintThread="" hintReadback="" hintText=""
	AgentsHarnessAskPost && AgentsToolsAskKindRow "$2" || return 0
	[ -n "$hintTool" ] || hintTool="$agentsAskRowName"
	## A kind no tool asks is acted on by its id through the first of the tools that ask.
	[ -n "$hintTool" ] || hintTool="AskQuestion"
	hintThread="$( AgentsHarnessAskRecordField "$1" channel )"
	[ -z "$hintThread" ] || hintThread="$hintThread:$( AgentsHarnessAskRecordField "$1" thread-ts )"
	## A readback may close a decision or a question with an answer form, never a permission.
	case "$2:$3" in
		decision:*|question:?*) hintReadback="$hintTool pending_id=$hintId readback=<the answer you take the reply to mean> understood=<why>" ;;
	esac
	hintText="$( ASKP_BLOCK="Returned/hint" ASKP_F_explain_call="SendMessage to=${hintThread:-<the thread of the question>} message=<your explanation>, then Wait mode=continue" \
		ASKP_F_revise_call="$hintTool pending_id=$hintId revise=true with the fields you change" \
		ASKP_F_withdraw_call="$hintTool pending_id=$hintId withdraw=<why>" ASKP_F_readback_call="$hintReadback" \
		AgentsToolsAskPostFill block "$agentsAskRowTemplate" "" 2> /dev/null )" || hintText=""
	[ -z "$hintText" ] || printf '%s\n' "$hintText"
}

## A Wait whose ask:<pending-id> items arrived: each is taken into its record by
## AgentsHarnessAskResolve, from its own section of what the wait returned, after that output.
AgentsHarnessWaitAskResolve(){ ## wait output file
	local resolveItem resolveId resolveSection resolveStatus
	for resolveItem in $( LC_ALL=C sed -n 's/^# arrived on: \(ask:[0-9A-Za-z._-]*\)$/\1/p' "$1" ) ; do
		resolveId="${resolveItem#ask:}"
		resolveSection="$( LC_ALL=C awk -v item="$resolveItem" '
			$0 == "# arrived on: " item { inItem = 1 ; next ; }
			inItem && $0 == "# --- what that source holds now follows ---" { next ; }
			inItem && $0 == "# --- end ---" { exit ; }
			inItem { print ; }
		' "$1" )"
		resolveStatus="$( AgentsHarnessAskRecordField "$resolveId" status )"
		printf '# --- pending reply %s, as the asking call would take it ---\n' "$resolveId"
		## Which ask it is, in its own first words: a result may carry the answers to several.
		printf 'ASKED: %s, %s: %s\n' "$( AgentsHarnessAskRecordField "$resolveId" kind )" "$( AgentsHarnessAskRecordField "$resolveId" asked-at )" \
			"$( LC_ALL=C awk '$0 == "---" { dashes++ ; next ; } dashes >= 2 && $0 !~ /^#/ && $0 !~ /^[ \t]*$/ { print substr( $0, 1, 200 ) ; exit ; }' "$MMDAPP/.local/agents/pending/$resolveId.md" 2> /dev/null )"
		## Withdrawn by its asker: nothing more to take, and it leaves the Wait set.
		if [ "$resolveStatus" = "withdrawn" ] ; then
			printf 'NOTE: pending reply %s is withdrawn, so nothing that arrives there is taken as an answer, and it leaves your Wait set.\n' "$resolveId"
			## Dismissed from the console, its record says so and by which account: said as that, with the reason given there.
			case "$( AgentsHarnessAskRecordField "$resolveId" withdrawn-by )" in
				console:*)
					printf 'It was dismissed from the console by %s. Reason: %s. That is no answer: nothing was answered, granted or decided.\n' \
						"$( AgentsHarnessAskRecordField "$resolveId" withdrawn-by | LC_ALL=C sed 's/^console://' )" "$( AgentsHarnessAskRecordField "$resolveId" withdraw-reason )"
				;;
			esac
			AgentsHarnessAskWaitItem drop "$resolveId" || :
			continue
		fi
		## Answered, and its thread still watched from its follow floor: what arrives is what the
		## person wrote there since, kept with the answer as clarifications or corrections, and
		## shown, since it may correct the answer -- or object to the asker's readback.
		## With nothing new kept, it is read as before: the answer the record carries.
		local resolveClarify="" resolveReadback=""
		if [ "$resolveStatus" = "reply-received" ] && [ -n "$( AgentsHarnessAskRecordField "$resolveId" follow-floor )" ] ; then
			## Read without the probe's own last line, where it says the record is closed: that is
			## no word of the person's (AgentsHarnessAskAnswerBody).
			resolveClarify="$( AgentsHarnessAskAnswerBody "# --- what that source holds now follows ---"$'\n'"$resolveSection"$'\n'"# --- end ---" "$resolveId" | AgentsHarnessAskOwnWords | LC_ALL=C awk -v answerTs="$( AgentsHarnessAskRecordField "$resolveId" follow-floor )" \
				-f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsPendingReplyClarifications.awk" 2>/dev/null )" || resolveClarify=""
			[ -z "$resolveClarify" ] || [ "$( AgentsHarnessAskKeepClarifications "$resolveId" "$resolveClarify" )" != "0" ] || resolveClarify=""
		fi
		if [ -n "$resolveClarify" ] ; then
			[ "$( AgentsHarnessAskRecordField "$resolveId" closed-by )" != "readback" ] || resolveReadback=1
			printf 'ASK-RESULT: CLARIFIED\nVERDICT: %s\n' "$( AgentsHarnessAskRecordField "$resolveId" verdict )"
			[ -z "$resolveReadback" ] || printf 'CLOSED-BY: readback\n'
			printf 'Pending reply %s is answered%s. The person wrote in its thread after that, and it is kept with the answer as clarifications, on its record and its item Decisions. Read it: it may correct the answer%s, which may then need changing. It stays in your Wait set for anything more.\n' \
				"$resolveId" "${resolveReadback:+ by your readback}" "${resolveReadback:+, or object to your readback}"
			printf '%s\n' "$resolveSection"
			continue
		fi
		[ "$resolveStatus" = "reply-pending" ] || printf 'NOTE: pending reply %s was already closed (%s) before this Wait saw it, so its record is left as it was.\n' "$resolveId" "${resolveStatus:-no record}"
		## Its section goes on between the wait's own markers, as the wait printed it: what the person
		## wrote is told from the wait's own lines by where it stands (AgentsHarnessAskAnswerBody).
		AgentsHarnessAskResolve "$resolveId" "$( AgentsHarnessAskRecordField "$resolveId" kind )" "$( AgentsHarnessAskRecordField "$resolveId" question-tag )" \
			"WAIT-RESULT: RECEIVED"$'\n'"# --- what that source holds now follows ---"$'\n'"$resolveSection"$'\n'"# --- end ---" "" "" wait ""
	done
}

## The three MCP resource tools reach the same servers this run already enumerated,
## through the same client the mcp__ tools use. A server is resolvable out of the config
## by name alone, so the grant is enforced HERE: a name this run was not started with is
## refused rather than started, which is what keeps --mcp-server the whole of the grant.
## Outside the AgentsHarnessTool* family for the reason AgentsHarnessMcpCall is.
AgentsHarnessMcpResourceServers(){ ## optional single server name; prints the servers to use
	local wantName="$1" haveName
	[ "${#harnessMcpServers[@]}" -gt 0 ] || return 1
	if [ -z "$wantName" ] ; then
		printf '%s\n' "${harnessMcpServers[@]}"
		return 0
	fi
	for haveName in "${harnessMcpServers[@]}" ; do
		[ "$haveName" != "$wantName" ] || { printf '%s\n' "$wantName" ; return 0 ; }
	done
	return 2
}

## One resources/list exchange with one server, leaving its answer in mcp.result the way
## AgentsHarnessMcpCall leaves its own. Non-zero with $harnessMcpFault set where the
## server could not be run or never answered. The ids continue that file's own sequence,
## so a reply is matched by id rather than by position in a stream that also carries
## banners and notifications.
AgentsHarnessMcpResourceList(){ ## server name
	local listServer="$1"
	{
		AgentsHarnessMcpHandshake
		printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"resources/list","params":{}}'
	} > "$harnessScratch/mcp.req"
	AgentsHarnessMcpRun "$listServer" "$harnessRunTimeout" 4 || return 1
	AgentsHarnessMcpReply 4 || { harnessMcpFault="it returned no answer to resources/list (exit status $harnessMcpStatus)${harnessMcpDiag:+ -- it said: $harnessMcpDiag}" ; return 1 ; }
	printf '%s\n' "$harnessMcpReply" > "$harnessScratch/mcp.result"
}

## One resources/read exchange. The uri is escaped and its line breaks folded first: a
## JSON-RPC request is one physical line, and a raw newline inside a string literal is
## not legal JSON anyway, so folding one can never change a value.
AgentsHarnessMcpResourceRead(){ ## server name, uri
	local readServer="$1" readUri="$2" readUriEsc
	readUri="${readUri//$'\n'/ }"
	readUri="${readUri//$'\r'/ }"
	readUriEsc="$( printf '%s' "$readUri" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	{
		AgentsHarnessMcpHandshake
		printf '%s\n' '{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"'"$readUriEsc"'"}}'
	} > "$harnessScratch/mcp.req"
	AgentsHarnessMcpRun "$readServer" "$harnessRunTimeout" 5 || return 1
	AgentsHarnessMcpReply 5 || { harnessMcpFault="it returned no answer to resources/read (exit status $harnessMcpStatus)${harnessMcpDiag:+ -- it said: $harnessMcpDiag}" ; return 1 ; }
	printf '%s\n' "$harnessMcpReply" > "$harnessScratch/mcp.result"
}

## Renders whatever resources/read answer is sitting in mcp.result. Shared by the single
## read and the prefix read so one server answer can never render two different ways.
## LC_ALL=C for the whole body, so the length test and the cut count the same bytes the
## cap is expressed in -- under the ambient UTF-8 locale they count characters instead.
AgentsHarnessMcpResourceRender(){ ## uri
	local LC_ALL=C
	local renderUri="$1" renderRc=0 renderCount renderIndex renderText renderMime renderBytes renderErr
	renderErr="$( AgentsHarnessMcpField error.message < "$harnessScratch/mcp.result" )" || renderErr=""
	if [ -n "$renderErr" ] ; then
		printf 'ERROR: the server refused to read %s: %s\n' "$renderUri" "$renderErr"
		return 0
	fi
	renderCount="$( AgentsHarnessMcpField result.contents.__count < "$harnessScratch/mcp.result" )" || renderRc=$?
	if [ "$renderRc" != "0" ] ; then
		printf 'ERROR: the server answered the read of %s in a shape this harness cannot read -- no result.contents array (rc=%s). Nothing is implied about what that resource holds.\n' "$renderUri" "$renderRc"
		return 0
	fi
	renderIndex=0
	while [ "$renderIndex" -lt "$renderCount" ] 2>/dev/null ; do
		renderRc=0
		renderMime="$( AgentsHarnessMcpField "result.contents.$renderIndex.mimeType" < "$harnessScratch/mcp.result" )" || renderMime=""
		renderText="$( AgentsHarnessMcpField "result.contents.$renderIndex.text" < "$harnessScratch/mcp.result" )" || renderRc=$?
		renderIndex=$(( renderIndex + 1 ))
		if [ "$renderRc" != "0" ] ; then
			printf '[part %s of %s carries no text%s -- a binary or otherwise non-text part, which this harness does not render]\n' "$renderIndex" "$renderCount" "${renderMime:+, media type $renderMime}"
			continue
		fi
		## Capped and said so, as Read states its own cap: a cut resource otherwise reads
		## as the whole of one.
		renderBytes="${#renderText}"
		if [ "$renderBytes" -gt 100000 ] ; then
			printf '%s\n' "${renderText:0:100000}"
			printf '... TRUNCATED at 100000 of %s bytes ...\n' "$renderBytes"
		else
			printf '%s\n' "$renderText"
		fi
	done
	[ "$renderCount" != 0 ] || printf '(the server returned no content for %s)\n' "$renderUri"
}

AgentsHarnessToolListMcpResourcesTool(){ ## server (optional)
	local toolServer="$1" listServers="" listServerRc=0 listName listRc listCount listIndex
	local listUri listResName listMime listDesc listErr
	listServers="$( AgentsHarnessMcpResourceServers "$toolServer" )" || listServerRc=$?
	case "$listServerRc" in
		0) ;;
		1)
			printf 'ERROR: ListMcpResourcesTool: this run enumerated no MCP server at all, so there is nothing to list. A server is reachable only because this harness was started naming it or, with none named, because the installer registers it for this workspace (.local/agents/mcp.servers.index), and nothing here can add one.\n' ; return 0
		;;
		*)
			printf 'ERROR: ListMcpResourcesTool: this run did not enumerate an MCP server named %s, and one it was never given is never started here. The servers this run holds are:%s\n' "$toolServer" "$( printf ' %s' "${harnessMcpServers[@]}" )" ; return 0
		;;
	esac
	while IFS= read -r listName ; do
		[ -n "$listName" ] || continue
		printf '... MCP server %s ...\n' "$listName"
		if ! AgentsHarnessMcpResourceList "$listName" ; then
			printf 'ERROR: %s could not be asked for its resources: %s\n' "$listName" "$harnessMcpFault"
			continue
		fi
		listRc=0
		listCount="$( AgentsHarnessMcpField result.resources.__count < "$harnessScratch/mcp.result" )" || listRc=$?
		if [ "$listRc" != "0" ] ; then
			listErr="$( AgentsHarnessMcpField error.message < "$harnessScratch/mcp.result" )" || listErr=""
			if [ -n "$listErr" ] ; then
				printf 'ERROR: %s refused resources/list: %s\n' "$listName" "$listErr"
			else
				printf 'ERROR: %s answered resources/list in a shape this harness cannot read -- no result.resources array (rc=%s). Nothing is implied about whether it publishes resources.\n' "$listName" "$listRc"
			fi
			continue
		fi
		## Every listing carries its denominator: without one, a reader cannot tell a
		## server publishing nothing from a walk that read nothing.
		printf '%s resource(s) published:\n' "$listCount"
		listIndex=0
		while [ "$listIndex" -lt "$listCount" ] 2>/dev/null ; do
			listUri="$( AgentsHarnessMcpField "result.resources.$listIndex.uri" < "$harnessScratch/mcp.result" )" || listUri=""
			listResName="$( AgentsHarnessMcpField "result.resources.$listIndex.name" < "$harnessScratch/mcp.result" )" || listResName=""
			listMime="$( AgentsHarnessMcpField "result.resources.$listIndex.mimeType" < "$harnessScratch/mcp.result" )" || listMime=""
			listDesc="$( AgentsHarnessMcpField "result.resources.$listIndex.description" < "$harnessScratch/mcp.result" )" || listDesc=""
			listIndex=$(( listIndex + 1 ))
			printf '  %s. %s\n' "$listIndex" "${listUri:-<this entry carries no uri, so it cannot be read>}"
			[ -z "$listResName" ] || printf '     name: %s\n' "$listResName"
			[ -z "$listMime" ] || printf '     type: %s\n' "$listMime"
			[ -z "$listDesc" ] || printf '     %s\n' "$listDesc"
		done
		[ "$listCount" != 0 ] || printf '  (this server publishes no resources. It was reached and it answered, so that is a complete answer and not a failure.)\n'
	done <<< "$listServers"
}

AgentsHarnessToolReadMcpResourceTool(){ ## server, uri
	local toolServer="$1" toolUri="$2" readServers="" readServerRc=0
	if [ -z "$toolServer" ] || [ -z "$toolUri" ] ; then
		printf 'ERROR: ReadMcpResourceTool: both server and uri are required, and one of them was empty. Nothing was read.\n' ; return 0
	fi
	readServers="$( AgentsHarnessMcpResourceServers "$toolServer" )" || readServerRc=$?
	case "$readServerRc" in
		0) ;;
		1)
			printf 'ERROR: ReadMcpResourceTool: this run enumerated no MCP server at all, so there is nothing to read from. A server is reachable only because this harness was started naming it or, with none named, because the installer registers it for this workspace (.local/agents/mcp.servers.index), and nothing here can add one.\n' ; return 0
		;;
		*)
			printf 'ERROR: ReadMcpResourceTool: this run did not enumerate an MCP server named %s, and one it was never given is never started here. The servers this run holds are:%s\n' "$toolServer" "$( printf ' %s' "${harnessMcpServers[@]}" )" ; return 0
		;;
	esac
	if ! AgentsHarnessMcpResourceRead "$toolServer" "$toolUri" ; then
		printf 'ERROR: ReadMcpResourceTool: the MCP server `%s` could not be run: %s\n' "$toolServer" "$harnessMcpFault" ; return 0
	fi
	printf '... %s on %s ...\n' "$toolUri" "$toolServer"
	AgentsHarnessMcpResourceRender "$toolUri"
}

AgentsHarnessToolReadMcpResourceDirTool(){ ## server, uri_prefix, limit
	local toolServer="$1" toolPrefix="$2" toolLimit="$3" dirServers="" dirServerRc=0 dirRc=0
	local dirCount dirIndex dirUri dirMatched=0 dirRead=0 dirMatches="" dirErr
	if [ -z "$toolServer" ] ; then
		printf 'ERROR: ReadMcpResourceDirTool: server is required and was empty. Nothing was read.\n' ; return 0
	fi
	if [ -z "$toolPrefix" ] ; then
		printf 'ERROR: ReadMcpResourceDirTool: uri_prefix is required and was empty. An empty prefix matches every resource a server publishes, which is a listing rather than a read -- use ListMcpResourcesTool for that.\n' ; return 0
	fi
	if [ -n "$toolLimit" ] ; then
		if ! AgentsHarnessWholeNumber "$toolLimit" || [ "$toolLimit" -lt 1 ] ; then
			printf 'ERROR: ReadMcpResourceDirTool: limit must be a whole number of resources, at least 1, got: %s\n' "$toolLimit" ; return 0
		fi
	else
		toolLimit=20
	fi
	dirServers="$( AgentsHarnessMcpResourceServers "$toolServer" )" || dirServerRc=$?
	case "$dirServerRc" in
		0) ;;
		1)
			printf 'ERROR: ReadMcpResourceDirTool: this run enumerated no MCP server at all, so there is nothing to read from. A server is reachable only because this harness was started naming it or, with none named, because the installer registers it for this workspace (.local/agents/mcp.servers.index), and nothing here can add one.\n' ; return 0
		;;
		*)
			printf 'ERROR: ReadMcpResourceDirTool: this run did not enumerate an MCP server named %s, and one it was never given is never started here. The servers this run holds are:%s\n' "$toolServer" "$( printf ' %s' "${harnessMcpServers[@]}" )" ; return 0
		;;
	esac
	if ! AgentsHarnessMcpResourceList "$toolServer" ; then
		printf 'ERROR: ReadMcpResourceDirTool: the MCP server `%s` could not be asked for its resources: %s\n' "$toolServer" "$harnessMcpFault" ; return 0
	fi
	dirCount="$( AgentsHarnessMcpField result.resources.__count < "$harnessScratch/mcp.result" )" || dirRc=$?
	if [ "$dirRc" != "0" ] ; then
		dirErr="$( AgentsHarnessMcpField error.message < "$harnessScratch/mcp.result" )" || dirErr=""
		if [ -n "$dirErr" ] ; then
			printf 'ERROR: ReadMcpResourceDirTool: `%s` refused resources/list: %s\n' "$toolServer" "$dirErr"
		else
			printf 'ERROR: ReadMcpResourceDirTool: `%s` answered resources/list in a shape this harness cannot read -- no result.resources array (rc=%s). Nothing is implied about what it publishes.\n' "$toolServer" "$dirRc"
		fi
		return 0
	fi
	## The whole listing is consumed into a list of matching uris BEFORE any read runs.
	## Each read overwrites mcp.result, so walking the listing and reading inside the
	## same loop would read the first match and then keep walking a document that is no
	## longer there -- silently, and reporting a count it never had.
	dirIndex=0
	while [ "$dirIndex" -lt "$dirCount" ] 2>/dev/null ; do
		dirUri="$( AgentsHarnessMcpField "result.resources.$dirIndex.uri" < "$harnessScratch/mcp.result" )" || dirUri=""
		dirIndex=$(( dirIndex + 1 ))
		[ -n "$dirUri" ] || continue
		case "$dirUri" in
			"$toolPrefix"*) ;;
			*) continue ;;
		esac
		dirMatched=$(( dirMatched + 1 ))
		[ "$dirMatched" -le "$toolLimit" ] || continue
		dirMatches="$dirMatches$dirUri"$'\n'
	done
	printf '... %s of the %s resource(s) on %s start with %s ...\n' "$dirMatched" "$dirCount" "$toolServer" "$toolPrefix"
	if [ "$dirMatched" = 0 ] ; then
		printf 'No resource uri on this server starts with that text. The server was reached and it published %s resource(s), so this is a COMPLETE, SUCCESSFUL call and not a failure -- run ListMcpResourcesTool to see the uris it does publish.\n' "$dirCount"
		return 0
	fi
	while IFS= read -r dirUri ; do
		[ -n "$dirUri" ] || continue
		printf -- '--- %s ---\n' "$dirUri"
		if ! AgentsHarnessMcpResourceRead "$toolServer" "$dirUri" ; then
			printf 'ERROR: %s could not be read: %s\n' "$dirUri" "$harnessMcpFault"
			continue
		fi
		dirRead=$(( dirRead + 1 ))
		AgentsHarnessMcpResourceRender "$dirUri"
	done <<< "$dirMatches"
	printf '... read %s of the %s matching resource(s); the bound on this call was %s ...\n' "$dirRead" "$dirMatched" "$toolLimit"
}

## The floor is rendered by the mirror once per process and kept in this scratch file --
## the call runs in a command substitution, so a variable would not outlive it -- and both
## wires search that one literal. Only a rendering that succeeded is kept: a failed one
## is tried again, and says why, on the next call. The MCP entries are this round's
## $harnessMcpToolsJson, each already carrying its separating comma.
harnessToolSearchFloorFile="$harnessScratch/toolsearch.floor"
AgentsHarnessToolToolSearch(){ ## query, max_results
	local toolQuery="$1" toolMax="$2" searchFloor="" searchRc=0 searchUnoffered=""
	## A tool this session is not offered is not found either.
	AgentsHarnessCheckListPlace || searchUnoffered="CheckList"
	if [ -z "$toolQuery" ] ; then
		printf 'ERROR: ToolSearch: query is required and was empty. Nothing was searched.\n' ; return 0
	fi
	if [ -n "$toolMax" ] ; then
		if ! AgentsHarnessWholeNumber "$toolMax" || [ "$toolMax" -lt 1 ] ; then
			printf 'ERROR: ToolSearch: max_results must be a whole number of tools, at least 1, got: %s\n' "$toolMax" ; return 0
		fi
	else
		toolMax=5
	fi
	if [ -s "$harnessToolSearchFloorFile" ] ; then
		AgentsHarnessFileText "$harnessToolSearchFloorFile"
		searchFloor="$harnessFileText"
	else
		searchFloor="$( bash "$harnessHere/AgentsHarnessMcpMirror.sh" "" "$searchUnoffered" )" || searchRc=$?
	fi
	case "$searchRc:$searchFloor" in
		'0:['*']')
			## Written whole and then renamed, so a reader never meets half a floor.
			[ -s "$harnessToolSearchFloorFile" ] || { printf '%s' "$searchFloor" > "$harnessToolSearchFloorFile.$$" && mv -f "$harnessToolSearchFloorFile.$$" "$harnessToolSearchFloorFile" ; } 2>/dev/null || rm -f "$harnessToolSearchFloorFile.$$" 2>/dev/null || :
		;;
		*)
			printf 'ERROR: ToolSearch: the harness tool declarations did not render (rc=%s), so nothing was searched. The renderer names the declaration at fault on stderr.\n' "$searchRc" ; return 0
		;;
	esac
	printf '%s' "${searchFloor%]}${harnessMcpToolsJson:-}]" | MDAT_TOOLSEARCH_QUERY="$toolQuery" MDAT_TOOLSEARCH_MAX="$toolMax" LC_ALL=C awk -f "$harnessHere/AgentsHarnessToolSearch.awk" || searchRc=$?
	[ "$searchRc" = 0 ] || printf 'ERROR: ToolSearch: the tool catalogue could not be read (rc=%s), so nothing is implied about which tools exist. The reader names the declaration at fault on stderr.\n' "$searchRc"
}

## Explicit character enumeration rather than a bracket range, which is collation-
## dependent: `[a-z]` has matched `A` on this estate.
AgentsHarnessSkillSegmentOk(){ ## one path segment
	local segRest="$1" segChar
	case "$segRest" in ''|.|..) return 1 ;; esac
	while [ -n "$segRest" ] ; do
		segChar="${segRest%"${segRest#?}"}"
		segRest="${segRest#?}"
		case "$segChar" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
			0|1|2|3|4|5|6|7|8|9) ;;
			-|_|.) ;;
			*) return 1 ;;
		esac
	done
}

## The first candidate whose folder is named for the skill, or whose frontmatter name is
## the skill, wins. A candidate glob that matched nothing is a path getline cannot open.
AgentsHarnessSkillLocate(){ ## skill name, then candidate SKILL.md paths in search order -- prints the folder
	printf '%s\n' "${@:2}" | LC_ALL=C awk -v wantName="$1" -f "$harnessHere/AgentsHarnessSkillLocate.awk"
}

## Only the named sections of a Markdown file, |-separated heading texts, each down to the
## next heading of the same or a higher level; an unknown one is ERROR listing the headings.
AgentsHarnessSkillSection(){ ## file, sections
	skillSections="$2" LC_ALL=C awk -f "$harnessHere/AgentsHarnessSkillSection.awk" "$1"
}

## Reaches the skillset directly and DELIBERATELY NOT through AgentsHarnessPathAllowed.
## A member folder under the skillset root is a SYMLINK into whatever source tree owns
## it, so resolving a candidate with `cd ... && pwd -P` and prefix-matching it against
## the resolved root refuses every real member file -- the containment check would be
## correct and the tool would be useless. Containment is held lexically instead, decided
## before any resolution: a relative name carrying no `..` segment, no leading slash and
## nothing outside the gated character set cannot name anything the join does not place
## under the root, whatever that root later resolves to.
AgentsHarnessToolSkill(){ ## name, file, list, offset, limit, skill, args, section
	local toolName="$1" toolFile="$2" toolList="$3" toolOffset="$4" toolLimit="$5" toolSkill="$6" toolArgs="$7" toolSection="${8:-}"
	local skillDir skillPath skillRest skillSeg skillBytes skillPrefix skillLeaf skillSought pluginRoot skillPluginData skillOwnRoot skillCandidate skillOther
	local skillVendor=()
	## A member of another workspace is found through the shared registry, never through this workspace's own index.
	type AgentsToolsTeamMemberDirectory > /dev/null 2>&1 || . "$harnessHere/AgentsTools.TeamRegistry.include"
	## skill is the native call shape: the name resolved and the skill rendered as the
	## client does both. A path of its own, apart from name, file and list.
	if [ -n "$toolSkill" ] ; then
		skillLeaf="${toolSkill##*:}"
		skillPrefix=""
		case "$toolSkill" in :*) printf 'ERROR: Skill: skill has an empty prefix before the colon: %s\n' "$toolSkill" ; return 0 ;; *:*) skillPrefix="${toolSkill%:*}" ;; esac
		if ! AgentsHarnessSkillSegmentOk "$skillLeaf" ; then
			printf 'ERROR: Skill: skill does not end in a bare skill name -- letters, digits, underscore, dot and hyphen only, and never . or .. : %s\n' "$toolSkill" ; return 0
		fi
		skillRest="$skillPrefix"
		while [ -n "$skillRest" ] ; do
			skillSeg="${skillRest%%/*}"
			case "$skillRest" in
				*/*) skillRest="${skillRest#*/}" ;;
				*)   skillRest="" ;;
			esac
			if ! AgentsHarnessSkillSegmentOk "$skillSeg" ; then
				printf 'ERROR: Skill: skill names a prefix segment that is not a bare name -- letters, digits, underscore, dot and hyphen only, and never . or .. : %s\n' "$toolSkill" ; return 0
			fi
		done
		if [ -z "$skillPrefix" ] ; then
			## Team members from the member index, then a member of another workspace by its
			## name; then a skill the user or a vendor put in $HOME/.claude/skills as a real
			## folder. A link there is one our installer generated, and is never read back.
			skillOwnRoot="${MDAT_SKILLSET_ROOT:-${MMDAPP:-}/.local/agents/members}"
			skillOther="$( AgentsToolsTeamMemberDirectory "$skillLeaf" 2> /dev/null )" || skillOther=""
			skillVendor=()
			for skillCandidate in "$HOME/.claude/skills/$skillLeaf" "$HOME"/.claude/skills/*/ ; do
				skillCandidate="${skillCandidate%/}"
				[ ! -L "$skillCandidate" ] && [ -f "$skillCandidate/SKILL.md" ] || continue
				skillVendor+=( "$skillCandidate/SKILL.md" )
			done
			skillDir="$( AgentsHarnessSkillLocate "$skillLeaf" "$skillOwnRoot/$skillLeaf/SKILL.md" "$skillOwnRoot"/*/SKILL.md ${skillOther:+"$skillOther/SKILL.md"} ${skillVendor[@]+"${skillVendor[@]}"} )"
			skillPath="$skillDir/SKILL.md"
			skillSought="a skill folder or a SKILL.md frontmatter name $skillLeaf under $skillOwnRoot and the real folders of $HOME/.claude/skills"
		elif [ "$skillPrefix" = anthropic-skills ] ; then
			skillDir="$( AgentsHarnessSkillLocate "$skillLeaf" "$HOME"/.claude/skills/synced/*/"$skillLeaf"/SKILL.md "$HOME"/.claude/skills/synced/*/*/SKILL.md )"
			skillPath="$skillDir/SKILL.md"
			skillSought="a synced skill folder or a SKILL.md frontmatter name $skillLeaf under $HOME/.claude/skills/synced"
		else
			## A prefix that can name a plugin is tried as one first, then as a directory.
			## The plugin folder name is not the plugin name: plugin.json holds that.
			case "$skillPrefix" in
				*/*) ;;
				*)
					pluginRoot="$( printf '%s\n' "$HOME"/.claude/plugins/synced/*/*/.claude-plugin/plugin.json | LC_ALL=C awk -v wantName="$skillPrefix" -f "$harnessHere/AgentsHarnessPluginNameLocate.awk" )"
					if [ -n "$pluginRoot" ] ; then
						skillDir="$( AgentsHarnessSkillLocate "$skillLeaf" "$pluginRoot/skills/$skillLeaf/SKILL.md" "$pluginRoot"/skills/*/SKILL.md )"
						skillPath="$skillDir/SKILL.md"
						if [ -z "$skillDir" ] && [ -f "$pluginRoot/commands/$skillLeaf.md" ] ; then
							skillDir="$pluginRoot/commands"
							skillPath="$skillDir/$skillLeaf.md"
						fi
					fi
					skillSought="a plugin named $skillPrefix under $HOME/.claude/plugins/synced holding skill $skillLeaf or commands/$skillLeaf.md, then "
				;;
			esac
			if [ -z "$skillDir" ] ; then
				pluginRoot=""
				[ ! -f "$PWD/$skillPrefix/.claude/skills/$skillLeaf/SKILL.md" ] || skillDir="$PWD/$skillPrefix/.claude/skills/$skillLeaf"
				skillPath="$skillDir/SKILL.md"
				skillSought="$skillSought$PWD/$skillPrefix/.claude/skills/$skillLeaf/SKILL.md"
			fi
		fi
		if [ -z "$skillDir" ] ; then
			printf 'ERROR: Skill: no such skill: %s -- looked for %s\n' "$toolSkill" "$skillSought" ; return 0
		fi
		if [ ! -r "$skillPath" ] ; then
			printf 'ERROR: Skill: not readable (permission denied): %s\n' "$skillPath" ; return 0
		fi
		skillPluginData="$( [ -z "$pluginRoot" ] || LC_ALL=C awk -v pluginName="$skillPrefix" '{ if ( match($0, /"marketplace_name":"[^"]*"/) ) { pluginId = pluginName "@" substr($0, RSTART + 20, RLENGTH - 21) ; gsub(/[^A-Za-z0-9_-]/, "-", pluginId) ; printf "%s/.claude/plugins/data/%s", ENVIRON["HOME"], pluginId ; exit ; } }' "$pluginRoot.meta.json" 2>/dev/null )"
		## Values through ENVIRON, which -v would backslash-decode. Arguments go in first and
		## are never expanded again; the CLAUDE variables are replaced after them, as the
		## docs define. SESSION_ID, EFFORT, PROJECT_DIR and ! commands have no value here and
		## stay as written.
		skillArgs="$toolArgs" skillLabel="$toolSkill" skillBaseDir="$skillDir" skillPluginRoot="$pluginRoot" skillPluginData="$skillPluginData" \
		LC_ALL=C awk -f "$harnessHere/AgentsHarnessSkillArgumentsFill.awk" "$skillPath" > "$harnessScratch/skill.out"
		if [ -n "$toolSection" ] ; then
			AgentsHarnessSkillSection "$harnessScratch/skill.out" "$toolSection" > "$harnessScratch/skill.section" || :
			mv -f "$harnessScratch/skill.section" "$harnessScratch/skill.out"
			case "$( head -c 6 "$harnessScratch/skill.out" )" in ERROR:) cat "$harnessScratch/skill.out" ; return 0 ;; esac
		fi
		skillBytes="$( wc -c < "$harnessScratch/skill.out" | tr -d ' ' )"
		if [ -n "$toolOffset" ] || [ -n "$toolLimit" ] || [ "$skillBytes" -gt "$harnessReadCap" ] ; then
			AgentsHarnessReadRange "$harnessScratch/skill.out" "$toolOffset" "$toolLimit"
		else
			cat "$harnessScratch/skill.out"
		fi
		return 0
	fi
	if [ -z "$toolName" ] ; then
		printf 'ERROR: Skill: skill or name is required -- skill loads a skill as the native tool does, name reads a file from a skill folder\n' ; return 0
	fi
	## `<member>/<file>` in name is the same call as name plus file.
	case "$toolName" in
		*/*)
			[ -n "$toolFile" ] || toolFile="${toolName#*/}"
			toolName="${toolName%%/*}"
		;;
	esac
	if ! AgentsHarnessSkillSegmentOk "$toolName" ; then
		printf 'ERROR: Skill: name is not a bare skill folder name -- letters, digits, underscore, dot and hyphen only, and never . or .. : %s\n' "${toolName:-<none>}" ; return 0
	fi
	## The member index holds this workspace's own members; a member of another workspace
	## is found through the shared registry. A real folder in $HOME/.claude/skills is a
	## skill the user or a vendor put there; a link there is our own generated output,
	## never read back.
	skillDir="${MDAT_SKILLSET_ROOT:-${MMDAPP:-}/.local/agents/members}/$toolName"
	[ -d "$skillDir" ] || ! skillOther="$( AgentsToolsTeamMemberDirectory "$toolName" 2> /dev/null )" || skillDir="$skillOther"
	[ -d "$skillDir" ] || [ -L "$HOME/.claude/skills/$toolName" ] || skillDir="$HOME/.claude/skills/$toolName"
	if [ ! -d "$skillDir" ] ; then
		printf 'ERROR: Skill: no such skill folder: %s\n' "$toolName" ; return 0
	fi
	case "$toolList" in
		true|1|yes)
			## -L because a member folder under the skillset root is a symlink into the
			## tree that owns it, and without it the walk lists that entry without ever
			## entering it -- printing a clean empty result for a folder full of files.
			## Names relative to the folder, so each line is a valid `file` argument.
			( cd "$skillDir" && find -L . -type f | sed -e 's|^\./||' ) > "$harnessScratch/skill.out" 2>&1 || :
			skillBytes="$( wc -c < "$harnessScratch/skill.out" | tr -d ' ' )"
			if [ -n "$toolOffset" ] || [ -n "$toolLimit" ] || [ "$skillBytes" -gt "$harnessReadCap" ] ; then
				AgentsHarnessReadRange "$harnessScratch/skill.out" "$toolOffset" "$toolLimit"
			else
				cat "$harnessScratch/skill.out"
			fi
			return 0
		;;
	esac
	[ -n "$toolFile" ] || toolFile="SKILL.md"
	case "$toolFile" in
		/*)
			printf 'ERROR: Skill: file is a name inside the skill folder, never an absolute path: %s\n' "$toolFile" ; return 0
		;;
	esac
	skillRest="$toolFile"
	while [ -n "$skillRest" ] ; do
		skillSeg="${skillRest%%/*}"
		case "$skillRest" in
			*/*) skillRest="${skillRest#*/}" ;;
			*)   skillRest="" ;;
		esac
		if ! AgentsHarnessSkillSegmentOk "$skillSeg" ; then
			printf 'ERROR: Skill: file names a segment that is not a bare filename -- letters, digits, underscore, dot and hyphen only, and never . or .. : %s\n' "$toolFile" ; return 0
		fi
	done
	skillPath="$skillDir/$toolFile"
	if [ ! -f "$skillPath" ] ; then
		printf 'ERROR: Skill: no such file in the %s skill folder: %s -- call this again with list set true to see what that folder holds\n' "$toolName" "$toolFile" ; return 0
	fi
	## Existence is not readability, and the two are refused separately: without this the
	## size test below compares an empty value and emits shell noise, not an answer.
	if [ ! -r "$skillPath" ] ; then
		printf 'ERROR: Skill: not readable (permission denied): %s\n' "$toolName/$toolFile" ; return 0
	fi
	## section narrows the file to the named headings first; offset, limit and the cap then
	## apply to that text, as they do to a whole file.
	if [ -n "$toolSection" ] ; then
		AgentsHarnessSkillSection "$skillPath" "$toolSection" > "$harnessScratch/skill.out" || :
		case "$( head -c 6 "$harnessScratch/skill.out" )" in ERROR:) cat "$harnessScratch/skill.out" ; return 0 ;; esac
		skillPath="$harnessScratch/skill.out"
	fi
	if [ -n "$toolOffset" ] || [ -n "$toolLimit" ] ; then
		AgentsHarnessReadRange "$skillPath" "$toolOffset" "$toolLimit"
		return 0
	fi
	## Capped and said so, exactly as Read states its own cap.
	skillBytes="$( wc -c < "$skillPath" | tr -d ' ' )"
	if [ "$skillBytes" -gt "$harnessReadCap" ] ; then
		AgentsHarnessReadRange "$skillPath" 1 ""
	else
		cat "$skillPath"
	fi
}

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
AgentsHarnessArgParse(){ ## raw arguments
	[ "$harnessArgParsed" != 1 ] || [ "$1" != "$harnessArgRaw" ] || return 0
	local parseTable parseLine parseKind parsePath parseEnc parseValue
	unset ${!harnessArgV_@} ${!harnessArgD_@}
	harnessArgPaths=()
	harnessArgEncs=()
	harnessArgRaw="$1"
	harnessArgParsed=1
	## The here-string adds the one newline `printf '%s\n'` handed the field reader.
	parseTable="$( LC_ALL=C awk -f "$harnessHere/AgentsHarnessJsonField.awk" -f "$harnessHere/AgentsHarnessArgTable.awk" <<< "$1" 2>/dev/null )" || parseTable=""
	[ -n "$parseTable" ] || return 0
	while IFS= read -r parseLine ; do
		case "$parseLine" in '!ok') continue ;; esac
		parseKind="${parseLine%%$'\t'*}"
		parseLine="${parseLine#*$'\t'}"
		## Never `printf -v` an empty result: bash 3.2 then leaves the buffer of the one before.
		parsePath="${parseLine%%$'\t'*}"
		[ -z "$parsePath" ] || printf -v parsePath '%b' "$parsePath"
		parseEnc="${parseLine#*$'\t'}"
		harnessArgPaths+=( "$parsePath" )
		harnessArgEncs+=( "$parseEnc" )
		case "$parseKind" in
			v|d)
				parseValue=""
				[ -z "$parseEnc" ] || printf -v parseValue '%b' "$parseEnc"
				while : ; do
					case "$parseValue" in *$'\n') parseValue="${parseValue%$'\n'}" ;; *) break ;; esac
				done
				[ -n "$parseValue" ] || continue
				if [ "$parseKind" = v ] ; then
					printf -v "harnessArgV_$parsePath" '%s' "$parseValue"
				else
					printf -v "harnessArgD_${parsePath#-}" '%s' "$parseValue"
				fi
			;;
		esac
	done <<< "$parseTable"
}

## The value at one exact path of the parsed table, untrimmed, into harnessArgFound;
## non-zero when the path is absent -- or the arguments were not one JSON object.
AgentsHarnessArgFind(){ ## key path
	local findIndex=0 findCount="${#harnessArgPaths[@]}"
	harnessArgFound=""
	[ -n "$1" ] || return 1
	while [ "$findIndex" -lt "$findCount" ] ; do
		if [ "${harnessArgPaths[$findIndex]}" = "$1" ] ; then
			[ -z "${harnessArgEncs[$findIndex]}" ] || printf -v harnessArgFound '%b' "${harnessArgEncs[$findIndex]}"
			return 0
		fi
		findIndex=$(( findIndex + 1 ))
	done
	return 1
}

## Byte for byte what the field reader prints for this path. Answered from the parsed
## table when it is this same raw string -- a subshell inherits it -- and by the reader
## itself for any other document.
AgentsHarnessArgValue(){
	## A path carrying a backslash or a newline is left to the reader: awk's own -v
	## escape processing decides what such a path even names.
	if [ "$harnessArgParsed" = 1 ] && [ "$1" = "$harnessArgRaw" ] && [ "${2//[\\$'\n']/}" = "$2" ] ; then
		! AgentsHarnessArgFind "$2" || printf '%s\n' "$harnessArgFound"
		return 0
	fi
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## The same value byte for byte, into harnessArgExact: a command substitution drops every
## trailing newline, so content ending in one would be written without it.
harnessArgExact=""
harnessArgOld=""
AgentsHarnessArgExact(){ ## raw arguments, key, alias key read only when the key is absent
	AgentsHarnessArgParse "$1"
	## Absent, not empty: an empty new_string is a real value, and the key still wins over its alias.
	if [ -n "$3" ] && ! AgentsHarnessArgFind "$2" ; then
		set -- "$1" "$3"
	fi
	harnessArgExact=""
	if AgentsHarnessArgFind "$2" ; then
		harnessArgExact="$harnessArgFound"
	fi
}

## One line, every C0 byte and DEL folded to a space, cut on a UTF-8 character boundary.
## A path is identified by its END, so cutting from the right removes the only part
## that tells two calls apart: three files under one long directory all announce as
## the same truncated prefix. A value holding a separator therefore keeps its tail
## and is marked with a leading `...`; anything else keeps the right-hand cut, where
## the start is what identifies it. The sanitiser runs over the whole value either
## way -- with no cut first, so the control-byte guard sees every byte before any of
## it is dropped.
AgentsHarnessTruncateArg(){
	## LC_ALL=C for the whole body, so ${#var} and ${var: -N} count the same bytes the
	## renderer's cap is expressed in. Under the ambient UTF-8 locale they count
	## characters instead, and a 383-byte path then passes the byte test and emits
	## 334 bytes on one line.
	local LC_ALL=C
	## A big cap, never 0: in standalone mode that renderer emits nothing at all for
	## a cap of 0 -- the fold-without-cut meaning belongs to its function form only.
	local truncSafe truncTail truncHead="" truncBase truncWsParent="${MMDAPP%/*}" truncCap=110
	truncSafe="$( printf '%s' "$1" | LC_ALL=C awk -v progressLineCap=1000000 -f "$harnessHere/AgentsProgressLineSafe.awk" )"
	if [ "${#truncSafe}" -le "$truncCap" ] ; then
		printf '%s' "$truncSafe"
		return 0
	fi
	## Starts with a separator, not merely contains one: a JSON argument object
	## carrying a file: source holds slashes too, and eliding its head throws away
	## the field names that say what the call was.
	case "$truncSafe" in
		/*)
			## Under a workspace the head through that workspace's own name is kept as well, so which tree a path is in stays visible; kept only while the whole basename still fits.
			truncBase="${truncSafe##*/}"
			case "$truncSafe" in
				"$truncWsParent"/*/*) [ -z "$truncWsParent" ] || { truncHead="${truncSafe#"$truncWsParent"/}" ; truncHead="$truncWsParent/${truncHead%%/*}/" ; } ;;
			esac
			[ $(( ${#truncHead} + 3 + ${#truncBase} )) -le "$truncCap" ] || truncHead=""
			truncTail="${truncSafe: -$(( truncCap - 3 - ${#truncHead} ))}"
			## A byte cut lands mid-character as readily as the renderer's own would,
			## and the head of a UTF-8 sequence is what was dropped -- so any leading
			## continuation byte is removed rather than emitted as a broken character.
			## The range is safe here only because this body pins LC_ALL=C above.
			while : ; do
				case "$truncTail" in
					[$'\x80'-$'\xbf']*) truncTail="${truncTail#?}" ;;
					*) break ;;
				esac
			done
			printf '%s...%s' "$truncHead" "$truncTail"
		;;
		*) printf '%s' "$1" | LC_ALL=C awk -v progressLineCap="$truncCap" -f "$harnessHere/AgentsProgressLineSafe.awk" ;;
	esac
}

## Announced immediately before the call executes, so a Bash call that might hang is
## visible. Every value here is model output and passes AgentsHarnessTruncateArg first,
## so the only escapes reaching the terminal are the $harness* literals placed around them.
AgentsHarnessAnnounceTool(){
	local announceFuncName="$1" announceArgsRaw="$2" announceIcon="❓" announceDetail="" announcePath=""
	## Parsed once here; the dispatch that follows reads the same table.
	AgentsHarnessArgParse "$announceArgsRaw"
	case "$announceFuncName" in
		Read)
			announceIcon="📖"
			announcePath="${harnessArgV_file_path}"
			[ -n "$announcePath" ] || announcePath="${harnessArgV_path}"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Write)
			announceIcon="📝"
			announcePath="${harnessArgV_file_path}"
			[ -n "$announcePath" ] || announcePath="${harnessArgV_path}"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Glob)
			announceIcon="📁"
			## Path on its own line: a pattern and a long path on one line push each
			## other off the terminal, and the path is the half that identifies the
			## call. Two spaces past the tool line, not aligned to the detail column --
			## a wide gutter on a continuation reads as a second column that is not there.
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_path}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_pattern}" )$harnessOff"
			## Only when there is one: the announce prints before the call validates its
			## arguments, so a missing path would otherwise render a second line holding
			## an indent, the word `in`, and nothing.
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Edit)
			announceIcon="✏️"
			announcePath="${harnessArgV_file_path}"
			[ -n "$announcePath" ] || announcePath="${harnessArgV_path}"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Grep)
			announceIcon="🔍"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_path}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_pattern}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Bash)
			announceIcon="💻"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_cwd}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_command}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		WebSearch)
			announceIcon="🔎"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_query}" )$harnessOff"
		;;
		WebFetch)
			announceIcon="🌐"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_url}" )$harnessOff"
		;;
		SendMessage)
			announceIcon="✉️"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_to}" )$harnessOff"
		;;
		ListAgents)
			announceIcon="👥"
			announceDetail="$harnessDim running agent sessions$harnessOff"
		;;
		## Every argument is optional here, so the whole object is shown rather than one
		## named field: a call that may hold this run for minutes has to be visible in
		## full, and a bare Wait{} announcing an empty detail would look like a stall.
		Wait)
			announceIcon="⏳"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announceArgsRaw" )$harnessOff"
		;;
		## The four report tools are SendMessage with a fixed shape, so each announces the
		## one field that identifies the call rather than the whole body it composed.
		SubagentHandback)
			announceIcon="📦"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_to}" )${harnessOff}"
			[ -n "${harnessArgV_to}" ] || announceDetail="${harnessValue}${harnessParentName}${harnessOff}"
		;;
		ReportFindings)
			announceIcon="📊"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_subject}" )$harnessOff"
		;;
		PushNotification)
			announceIcon="📣"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_headline}" )$harnessOff"
		;;
		Artifact)
			announceIcon="🔗"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_url:-${harnessArgV_file}}" )$harnessOff"
		;;
		## The tools that ask, each announced the same way (AgentsHarnessAskAnnounce).
		AskQuestion)
			AgentsHarnessAskAnnounce
		;;
		ConfirmReadback)
			AgentsHarnessAskAnnounce
		;;
		EscalateDecision)
			AgentsHarnessAskAnnounce
		;;
		RequestPermission)
			AgentsHarnessAskAnnounce
		;;
		ProposeApprove)
			AgentsHarnessAskAnnounce
		;;
		## Their second name, declared nowhere and still taken.
		AskUserQuestion|mcp__*__AskUserQuestion)
			AgentsHarnessAskAnnounce
		;;
		## server is optional here, so a bare call states what it will actually do rather
		## than announcing an empty detail that reads as a stall.
		ListMcpResourcesTool)
			announceIcon="🗂️"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_server}" )"
			announceDetail="$harnessDim every MCP server this run enumerated$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$harnessValue$announcePath$harnessOff"
		;;
		ReadMcpResourceTool)
			announceIcon="📄"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_server}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_uri}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim on$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		ReadMcpResourceDirTool)
			announceIcon="🗃️"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_server}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_uri_prefix}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim on$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Skill)
			announceIcon="📚"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_file}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_name}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim file$harnessOff $harnessValue$announcePath$harnessOff"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_skill}" )"
			[ -z "$announcePath" ] || announceDetail="$harnessValue$announcePath$harnessOff"
		;;
		## The member being spawned, then the brief on its own line: this call starts a
		## session that outlives the turn, so who it starts has to be visible at a glance.
		Agent)
			announceIcon="🚀"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_prompt}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_agent}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim brief$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		TaskStop)
			announceIcon="🛑"
			announcePath="${harnessArgV_task_id}"
			[ -n "$announcePath" ] || announcePath="${harnessArgV_shell_id}"
			[ -n "$announcePath" ] || announcePath="${harnessArgV_handle}"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		TaskOutput)
			announceIcon="📜"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_handle}" )$harnessOff"
		;;
		ToolSearch)
			announceIcon="🧰"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_query}" )$harnessOff"
		;;
		## A start and a read are the same tool, and which one this call is decides which
		## field identifies it, so both are shown rather than one that may be empty.
		Monitor)
			announceIcon="📡"
			announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_handle}" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_command}" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim handle$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		SessionTranscriptAppend)
			announceIcon="🗒️"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "${harnessArgV_note}" )$harnessOff"
		;;
		## The list is an array, so its length is shown rather than one field of it.
		CheckList)
			announceIcon="📋"
			if AgentsHarnessArgFind todos.__count ; then
				announceDetail="$harnessValue$harnessArgFound$harnessOff$harnessDim item(s)$harnessOff"
			else
				announceDetail="$harnessDim the checklist of ${harnessArgV_member:-this member}$harnessOff"
			fi
		;;
		## Last, after every static arm: an mcp__ prefix must never displace a built-in.
		## A call carrying a command is announced like Bash/Grep/Glob above: the command
		## on the announce line, an optional comment on its own labelled line below, no
		## raw JSON. Only the server knows the shape of anything else, so that still
		## falls back to showing the whole argument object.
		mcp__*)
			announceIcon="🔌"
			announcePath="${harnessArgV_command}"
			if [ -n "$announcePath" ]; then
				announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
				announcePath="$( AgentsHarnessTruncateArg "${harnessArgV_comment}" )"
				[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim comment$harnessOff $harnessValue$announcePath$harnessOff"
			else
				announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announceArgsRaw" )$harnessOff"
			fi
		;;
	esac
	## Named in the title as it starts, so a long call says what it is waiting on
	## without the reader hunting back through scrollback for the announce line.
	AgentsHarnessTitleState "$announceFuncName"
	printf '   %s %s%-*s%s %s\n' "$announceIcon" "$harnessTool" "$harnessLabelWidth" "$( AgentsHarnessTruncateArg "$announceFuncName" )" "$harnessOff" "$announceDetail" >&2
}

## One dispatch, two callers: the model loop below and the --intern-tool arm
## above it. The arms keep their own spelling because AgentsHarnessSelfCheck.test.awk
## locates them by it, and harnessResult stays global so the loop reads the
## result exactly where it always did.
## Arm before acting: a spawned session's model loop is redirected from any acting call until it
## has read its own duty file through Skill. Loading stays deferred. MAGIC.md, "Arm before acting".
harnessArmedAt="" harnessArmRedirectLogged="" harnessArmRanges=""
AgentsHarnessArmGate(){ ## tool name -- prints the redirect when the call must wait for arming
	[ -z "$harnessToolOnly" ] && [ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && [ -n "$harnessAgent" ] && [ -z "$harnessArmedAt" ] || return 0
	case "$1" in
		Write|Edit|Bash|SendMessage|AskUserQuestion|AskQuestion|ConfirmReadback|EscalateDecision|RequestPermission|ProposeApprove|Agent|mcp__*__execute|mcp__*__Write|mcp__*__Edit|mcp__*__SendMessage|mcp__*__AskUserQuestion|mcp__*__AskQuestion|mcp__*__ConfirmReadback|mcp__*__EscalateDecision|mcp__*__RequestPermission|mcp__*__ProposeApprove|mcp__*__Agent) ;;
		*) return 0 ;;
	esac
	printf 'ERROR: read your duty file first: Skill name=%s file=%s.armed.md -- then retry this call. Nothing was done.\n' "$harnessAgent" "$harnessAgent"
}
AgentsHarnessArmNote(){ ## tool name, arguments JSON, result -- records the arming read
	[ -z "$harnessArmedAt" ] && [ "$1" = "Skill" ] && [ -n "$harnessAgent" ] || return 0
	AgentsHarnessArgParse "$2"
	[ "${harnessArgV_name}" = "$harnessAgent" ] && [ "${harnessArgV_file}" = "$harnessAgent.armed.md" ] || return 0
	case "$3" in ERROR:*|'') return 0 ;; esac
	## "In full" means every line: each read's range is recorded, and arming waits until the
	## union covers line 1 to the last. A read with no footer is the whole file.
	local armRange
	armRange="$( printf '%s\n' "$3" | LC_ALL=C awk '
		/^\.\.\. read [0-9]+ line\(s\) from line [0-9]+; the file has [0-9]+ lines \.\.\.$/ { shown = $3 ; from = $7 ; sub( /;$/, "", from ) ; total = $11 ; footer = 1 ; }
		END { if ( ! footer ) { print "whole" ; } else if ( shown > 0 ) { print from " " ( from + shown - 1 ) " " total ; } ; }
	' )"
	case "$armRange" in
		'') return 0 ;;
		whole) harnessArmRanges="whole" ;;
		*) harnessArmRanges="$harnessArmRanges${harnessArmRanges:+$'\n'}$armRange" ;;
	esac
	[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || printf '%s\n' "$harnessArmRanges" > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.armed-ranges" 2>/dev/null || :
	[ "$harnessArmRanges" = "whole" ] || [ -n "$( printf '%s\n' "$harnessArmRanges" | LC_ALL=C sort -n -k1,1 | LC_ALL=C awk '
		{ if ( $3 > total ) { total = $3 ; } ; if ( $1 <= reach + 1 ) { if ( $2 > reach ) { reach = $2 ; } ; } else { gap = 1 ; } ; }
		END { if ( ! gap && total > 0 && reach >= total ) { print "covered" ; } ; }
	' )" ] || return 0
	harnessArmedAt="$( date +"%Y-%m-%d %H:%M %z" )"
	[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || printf '%s\n' "$harnessArmedAt" > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.armed" 2>/dev/null || :
}

AgentsHarnessRunTool(){ ## tool name, arguments JSON -- sets harnessResult
	local harnessFuncName="$1" harnessFuncArgsRaw="$2"
	## One parse per call -- a no-op when the announce already parsed this same string --
	## and every arm below reads its fields from harnessArgV_*/harnessArgD_*.
	AgentsHarnessArgParse "$harnessFuncArgsRaw"
	## Text a tool writes is taken byte for byte, ahead of the arms that keep their own spelling.
	case "$harnessFuncName" in
		Write) AgentsHarnessArgExact "$harnessFuncArgsRaw" content ;;
		Edit) AgentsHarnessArgExact "$harnessFuncArgsRaw" old_string old_text ; harnessArgOld="$harnessArgExact" ; AgentsHarnessArgExact "$harnessFuncArgsRaw" new_string new_text ;;
	esac
	case "$harnessFuncName" in
		Read)      harnessResult="$( AgentsHarnessToolRead "${harnessArgV_path}" "${harnessArgV_offset}" "${harnessArgV_limit}" "${harnessArgV_pages}" "${harnessArgV_file_path}" )" ;;
		Write)     harnessResult="$( AgentsHarnessToolWrite "${harnessArgV_path}" "$harnessArgExact" "${harnessArgV_file_path}" "$harnessFuncArgsRaw" )" ;;
		Glob)      harnessResult="$( AgentsHarnessToolGlob "${harnessArgV_pattern}" "${harnessArgV_path}" "${harnessArgV_long}" )" ;;
		Edit)      harnessResult="$( AgentsHarnessToolEdit "${harnessArgV_path}" "$harnessArgOld" "$harnessArgExact" "${harnessArgV_replace_all}" "${harnessArgV_file_path}" "$harnessFuncArgsRaw" )" ;;
		Grep)      harnessResult="$( AgentsHarnessToolGrep "${harnessArgV_pattern}" "${harnessArgV_path}" "${harnessArgV_context}" "${harnessArgV_before}" "${harnessArgV_after}" "${harnessArgV_ignore_case}" "${harnessArgV_output_mode}" "${harnessArgV_glob}" "${harnessArgD_n}" "${harnessArgD_o}" "${harnessArgD_A}" "${harnessArgD_B}" "${harnessArgD_C}" "${harnessArgD_i}" "${harnessArgV_head_limit}" "${harnessArgV_offset}" "${harnessArgV_multiline}" "${harnessArgV_type}" )" ;;
		Bash)      harnessResult="$( AgentsHarnessToolBash "${harnessArgV_cwd}" "${harnessArgV_command}" "${harnessArgV_timeout}" )" ;;
		WebSearch) harnessResult="$( AgentsHarnessToolWebSearch "${harnessArgV_query}" "$harnessFuncArgsRaw" )" ;;
		WebFetch)  harnessResult="$( AgentsHarnessToolWebFetch "${harnessArgV_url}" "${harnessArgV_prompt}" )" ;;
		SendMessage) harnessResult="$( AgentsHarnessToolSendMessage "${harnessArgV_to}" "${harnessArgV_message}" "${harnessArgV_as_bot}" "${harnessArgV_address_to}" "" "" reply )" ;;
		ListAgents) harnessResult="$( AgentsHarnessToolListAgents "${harnessArgV_view}" "${harnessArgV_session_id}" "${harnessArgV_state}" )" ;;
		Wait)      harnessResult="$( AgentsHarnessToolWait "${harnessArgV_sources}" "${harnessArgV_timeout}" "${harnessArgV_poll_interval}" "${harnessArgV_since_utime}" "${harnessArgV_addressee}" "${harnessArgV_include_own}" "${harnessArgV_mode}" "${harnessArgV_seen}" "${harnessArgV_note}" "${harnessArgV_done}" "${harnessArgV_wait}" "" "${harnessArgV_unwait}" )" ;;
		SubagentHandback) harnessResult="$( AgentsHarnessToolSubagentHandback "${harnessArgV_to}" "${harnessArgV_task}" "${harnessArgV_outcome}" "${harnessArgV_findings}" "${harnessArgV_unfinished}" "${harnessArgV_as_bot}" "${harnessArgV_address_to}" )" ;;
		ReportFindings) harnessResult="$( AgentsHarnessToolReportFindings "${harnessArgV_to}" "${harnessArgV_subject}" "${harnessArgV_findings}" "${harnessArgV_evidence}" "${harnessArgV_confidence}" "${harnessArgV_as_bot}" "${harnessArgV_address_to}" )" ;;
		PushNotification) harnessResult="$( AgentsHarnessToolPushNotification "${harnessArgV_to}" "${harnessArgV_severity}" "${harnessArgV_headline}" "${harnessArgV_detail}" "${harnessArgV_action_required}" "${harnessArgV_as_bot}" "${harnessArgV_address_to}" )" ;;
		Artifact)  harnessResult="$( AgentsHarnessToolArtifact "${harnessArgV_to}" "${harnessArgV_url}" "${harnessArgV_title}" "${harnessArgV_kind}" "${harnessArgV_summary}" "${harnessArgV_as_bot}" "${harnessArgV_file}" "$harnessFuncArgsRaw" "${harnessArgV_address_to}" )" ;;
		AskQuestion) harnessResult="$( AgentsHarnessToolAskQuestion )" ;;
		ConfirmReadback) harnessResult="$( AgentsHarnessToolConfirmReadback )" ;;
		EscalateDecision) harnessResult="$( AgentsHarnessToolEscalateDecision )" ;;
		RequestPermission) harnessResult="$( AgentsHarnessToolRequestPermission )" ;;
		ProposeApprove) harnessResult="$( AgentsHarnessToolProposeApprove )" ;;
		## The second name of the tools that ask: accepted wherever a call is taken, declared nowhere.
		AskUserQuestion) harnessResult="$( AgentsHarnessAskCall AskUserQuestion )" ;;
		ListMcpResourcesTool) harnessResult="$( AgentsHarnessToolListMcpResourcesTool "${harnessArgV_server}" )" ;;
		ReadMcpResourceTool) harnessResult="$( AgentsHarnessToolReadMcpResourceTool "${harnessArgV_server}" "${harnessArgV_uri}" )" ;;
		ReadMcpResourceDirTool) harnessResult="$( AgentsHarnessToolReadMcpResourceDirTool "${harnessArgV_server}" "${harnessArgV_uri_prefix}" "${harnessArgV_limit}" )" ;;
		Skill)     harnessResult="$( AgentsHarnessToolSkill "${harnessArgV_name}" "${harnessArgV_file}" "${harnessArgV_list}" "${harnessArgV_offset}" "${harnessArgV_limit}" "${harnessArgV_skill}" "${harnessArgV_args}" "${harnessArgV_section}" )" ;;
		Agent)     harnessResult="$( AgentsHarnessToolAgent "${harnessArgV_agent}" "${harnessArgV_prompt}" "${harnessArgV_cli_service}" "${harnessArgV_session_name_or_comment}" "${harnessArgV_session_id}" "${harnessArgV_conversation}" "${harnessArgV_description}" "${harnessArgV_new_session:-}" "${harnessArgV_settings_workspace:-}" )" ;;
		TaskStop)  harnessResult="$( AgentsHarnessToolTaskStop "${harnessArgV_handle}" "${harnessArgV_force}" "${harnessArgV_task_id}" "${harnessArgV_shell_id}" )" ;;
		TaskOutput) harnessResult="$( AgentsHarnessToolTaskOutput "${harnessArgV_handle}" "${harnessArgV_offset}" "${harnessArgV_limit}" "${harnessArgV_output_file}" )" ;;
		ToolSearch) harnessResult="$( AgentsHarnessToolToolSearch "${harnessArgV_query}" "${harnessArgV_max_results}" )" ;;
		SessionTranscriptAppend) harnessResult="$( AgentsHarnessToolSessionTranscriptAppend "${harnessArgV_note}" )" ;;
		CheckList) harnessResult="$( AgentsHarnessToolCheckList "$harnessFuncArgsRaw" )" ;;
		Monitor)   harnessResult="$( AgentsHarnessToolMonitor "${harnessArgV_command}" "${harnessArgV_cwd}" "${harnessArgV_handle}" "${harnessArgV_offset}" "${harnessArgV_limit}" )" ;;
		## Last, after every static arm: an mcp__ prefix must never displace a built-in.
		mcp__*)    harnessResult="$( AgentsHarnessMcpCall "$harnessFuncName" "$harnessFuncArgsRaw" )" ;;
		*)         harnessResult="ERROR: unknown tool: $harnessFuncName" ;;
	esac
	## A session that was dismissed and has given its handback is ended by the harness itself.
	AgentsHarnessDismissedAfter "$harnessFuncName"
}

## The reply its caller is given for a result, by the one reply layer (AgentsTranscriptReplyFinish,
## AgentsTools.SessionTranscript.include): a long result kept in the session's results/ folder and
## named, and the host's time on a line of its own. harnessResult stays the result itself, for every
## check made on it. Nothing is added to a result that goes to the tooling rather than to a caller:
## a change applied or held for another call (MDAT_CHANGE_APPLY, MDAT_CHANGE_HOLD_ONLY), and the
## NOT-HELD of a native client's own tool.
harnessReply=""
AgentsHarnessReply(){ ## tool name, result -- sets harnessReply
	harnessReply="$2"
	[ -z "${MDAT_CHANGE_APPLY:-}" ] && [ -z "${MDAT_CHANGE_HOLD_ONLY:-}" ] || return 0
	case "$2" in NOT-HELD:*) return 0 ;; esac
	type AgentsTranscriptReplyFinish > /dev/null 2>&1 || return 0
	harnessReply="$( AgentsTranscriptReplyFinish "$1" "$2" "$( [ "$1" != Read ] || printf '%s' "${harnessArgV_file_path:-${harnessArgV_path}}" )" )" || harnessReply="$2"
}

## One file's whole content, as `$( cat file )` gives it -- every trailing newline
## dropped, empty when it is absent -- into harnessFileText, with builtins only.
harnessFileText=""
AgentsHarnessFileText(){ ## file
	harnessFileText=""
	[ -f "$1" ] || return 0
	IFS= read -r -d '' harnessFileText < "$1" || :
	while : ; do
		case "$harnessFileText" in *$'\n') harnessFileText="${harnessFileText%$'\n'}" ;; *) break ;; esac
	done
}

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

## Sourced, not exec'd: its functions run in this process and share everything above.
## Checked on every path, so a misnamed wire is refused exactly as it always was.
harnessWireFile="$harnessHere/Agents${harnessWire}Wire.sh"
if [ ! -f "$harnessWireFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE=$harnessWire names no adapter in this package: $harnessWireFile" >&2
	exit 1
fi
if [ -n "$harnessNeedsMcp" ] ; then
	. "$harnessWireFile"
	## The declarations a hosted model is given state the cap this process applies.
	[ -z "${harnessToolsJson:-}" ] || harnessToolsJson="$( printf '%s\n' "$harnessToolsJson" | AgentsReadCapFill "$harnessReadCap" )"
	## No pre-requisites, no tool: CheckList is offered only where the harness knows the member and
	## the place of its list (AgentsHarnessCheckListPlace), on every path the wire is read on.
	AgentsHarnessCheckListPlace || [ -z "${harnessToolsJson:-}" ] \
		|| harnessToolsJson="$( printf '%s\n' "$harnessToolsJson" | LC_ALL=C grep -v -F '{"type":"function","function":{"name":"CheckList",' )"
fi

## The bearer the auth header is built from. With no exchange declared it is the stored
## credential, seeded once here, and no exchange code runs anywhere in this process.
harnessBearer="$harnessToken"
if [ -n "$harnessTokenExchange" ] ; then
	harnessExchangeFile="$harnessHere/Agents${harnessTokenExchange}Exchange.sh"
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
harnessHooksFile="$harnessHere/AgentsHarnessHooks.sh"
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
AgentsHarnessMcpServerSet(){
	[ "$harnessMcpServersNamed" -eq 0 ] || return 0
	harnessMcpServers=()
	case "$harnessToolOnlyName" in
		ListMcpResourcesTool|ReadMcpResourceTool|ReadMcpResourceDirTool|ToolSearch|'')
			if [ -n "${MMDAPP:-}" ] ; then
				## From the installer's index, else the same registration composed from our primary sources.
				AgentsHarnessMcpKeys
				while IFS= read -r harnessToolPeer ; do
					[ -n "$harnessToolPeer" ] || continue
					[ "myx.distro" != "$harnessToolPeer" ] || continue
					harnessMcpServers+=( "$harnessToolPeer" )
				done <<< "$harnessMcpResKeys"
			fi
		;;
	esac
}

## Sourced on the same terms, and after the hooks so a server this enumerates is
## already subject to them. It enumerates only what harnessMcpServers holds by now,
## so a run holding none reads no file and starts no process.
harnessMcpFile="$harnessHere/AgentsHarnessMcpClient.sh"
if [ ! -f "$harnessMcpFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the MCP client support is missing from this package: $harnessMcpFile" >&2
	exit 1
fi
[ -z "$harnessNeedsMcp" ] || . "$harnessMcpFile"
## The local lock primitive Write and Edit take; absent, every write is refused as unlockable.
[ ! -f "$harnessHere/AgentsTools.LocalLock.include" ] || . "$harnessHere/AgentsTools.LocalLock.include"
## The session transcript and token hooks; every one returns 0, and is called with || : besides.
[ ! -f "$harnessHere/AgentsTools.SessionTranscript.include" ] || . "$harnessHere/AgentsTools.SessionTranscript.include"

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
. "$harnessHere/AgentsHarnessModelRound.include"
## The kept model context and its resume, on the model path only.
. "$harnessHere/AgentsHarnessContext.include"

## A spawned session run by this loop is one whose arming can be observed: said beside its record.
[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || : > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.harness" 2>/dev/null || :

## Said only when the two sets differ, so an ungranted run reads exactly as it did.
harnessWriteNote=""
[ "$harnessWriteRoots" = "$harnessRoots" ] || harnessWriteNote="Writing is narrower than reading. Write and Edit may only write under these roots:
$harnessWriteRoots
Everything else above you may read, list, search and run commands in, but not write to. Do not try to work around that -- report it instead.
"

## A spawned session never ends on its own, its work done or not: its spawner dismisses it.
## Not one whose caller blocks on it (MDAT_SPAWN_CALLER_WAITS): that caller cannot send DISMISSED.
harnessSpawnedWaitNote=""
## Nor one that reports to no one, which ends on its report (AgentsHarnessReportsNone).
[ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || [ "${MDAT_SPAWN_CALLER_WAITS:-}" = "true" ] || AgentsHarnessReportsNone || harnessSpawnedWaitNote=" You are a spawned session: you never end on your own, not even when your work is done. When it is done, report that to whoever started you with SubagentHandback, saying you are done and waiting for further instructions, then keep waiting with Wait on your session thread and keep obeying what arrives there. End your run only when a Wait returns DISMISSED."
harnessSystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$harnessRoots
$harnessWriteNote
Use the given tools to accomplish the request, then reply with a final plain-text message once done. A plain-text reply with no tool call ends your run, so never give one while the work is still open: waiting for an answer, a reply, another session or any other event is not done. Wait for it with the Wait tool (mcp__myx_distro__Wait over MCP), and after a TIMEOUT wait again, look elsewhere or escalate -- never end the run just to wait. Then carry on obeying your instructions.$harnessSpawnedWaitNote Nobody is reading this terminal, so a question written into your own answer reaches no one: where you genuinely need a decision only a person can make, AskQuestion is the one way to ask for one. Otherwise make the most reasonable choice and state what you did."

## --agent given: the member's own identity replaces the generic opener entirely.
## Skill below is a tool name in prose, which no structural check can see.
if [ -n "$harnessAgent" ] ; then
	printf -v harnessSystemText '%s\n\n%s\n\n%s' \
		"$harnessAgentBasicText" \
		"Before your first acting call, read your own $harnessAgent.armed.md with the Skill tool, name $harnessAgent and file $harnessAgent.armed.md -- it is not included here. In a spawned session, Write, Edit, Bash, execute, SendMessage, AskQuestion, ConfirmReadback, EscalateDecision, RequestPermission, ProposeApprove and Agent are redirected until you have. Every skillset file is read with Skill, which works even where Read is denied." \
		"You are running through a bespoke $harnessProviderName harness$harnessSystemTail"
else
	harnessSystemText="You are an autonomous coding agent running through a bespoke $harnessProviderName harness$harnessSystemTail"
fi

## A named-but-unavailable MCP server owes the model a sentence: its tools are absent
## from the declarations, and nothing else in the run says why.
harnessSystemBase="$harnessSystemText"
[ -z "$harnessMcpUnavailableNote" ] || printf -v harnessSystemText '%s\n\n%s' "$harnessSystemBase" "$harnessMcpUnavailableNote"
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

## No round ceiling by default: a round is one model turn, which tracks neither
## cost nor progress, and a task is not finished by being cut off at one.
## MDAT_HARNESS_MAX_ROUNDS sets one where a caller wants it; unset means none.
harnessRound=0
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
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_CONTEXT_TOKENS must be a whole number of tokens, got: $harnessContextTokens" >&2
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

	## Output from a background job reaches the model HERE, between rounds, which is the
	## only place on this wire it can: the body below is one complete document written in
	## full before the first response byte arrives, and chat-completions has no verb for
	## appending to a turn already in flight. An empty spool appends nothing, so a run
	## that started no job sends a byte-identical request.
	harnessMonitorPending="$( AgentsHarnessMonitorSpool )"
	[ -z "$harnessMonitorPending" ] || harnessMessages+=( "$( AgentsWireUserRecord "$harnessMonitorPending" )" )

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
	AgentsWireRequestBody > "$harnessScratch/request.json"

	## Every attempt starts from a clean accumulator, and a retry here never touches
	## $harnessRound above.
	harnessStreamAttempt=0
	harnessStreamMaxAttempts=3
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
			--data-binary "@$harnessScratch/request.json" <<< "$harnessAuthHeader" 2>"$harnessScratch/stream.curlerr" \
			| AgentsWireStreamConsume
		harnessCurlRc="${PIPESTATUS[0]}"
		set -e

		if [ "$harnessCurlRc" = "0" ] && [ -f "$harnessScratch/stream.done" ] ; then
			harnessStreamOk=1
			break
		fi

		## A complete, non-streaming error body is not a disconnect: no retry. The one
		## exception is an auth-class refusal on a leg that exchanges its bearer, which is
		## what a bearer dying mid-round looks like from here. No exchange, no carve-out.
		if [ -s "$harnessScratch/stream.rawother" ] && [ ! -f "$harnessScratch/stream.done" ] ; then
			if [ -z "$harnessTokenExchange" ] || [ "$harnessStreamAttempt" -ge "$harnessStreamMaxAttempts" ] ; then
				break
			fi
			## Read off the refusal body: this curl hands back no HTTP status to read.
			## Each spelling drops its own leading letter, so one pattern matches both cases.
			case "$( cat "$harnessScratch/stream.rawother" )" in
				*401*|*nauthorized*|*nvalid_token*|*xpired*) ;;
				*) break ;;
			esac
			harnessBearer=""
			echo "${harnessWarn}🔁 RETRY:${harnessOff} stream attempt $harnessStreamAttempt/$harnessStreamMaxAttempts was refused as an auth failure -- dropping the cached bearer, re-exchanging and retrying the whole round" >&2
			continue
		fi

		echo "${harnessWarn}🔁 RETRY:${harnessOff} stream attempt $harnessStreamAttempt/$harnessStreamMaxAttempts disconnected mid-stream (curl rc=$harnessCurlRc$( [ ! -s "$harnessScratch/stream.curlerr" ] || printf ': %s' "$( cat "$harnessScratch/stream.curlerr" )" )) -- discarding partial output and retrying the whole round" >&2
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
		exit 1
	elif [ "$harnessErrorRc" != "3" ] ; then
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
		## The fresh leg's system text carries the note as the latest enumeration left it.
		harnessSystemText="$harnessSystemBase"
		[ -z "$harnessMcpUnavailableNote" ] || printf -v harnessSystemText '%s\n\n%s' "$harnessSystemBase" "$harnessMcpUnavailableNote"
		harnessMcpNoteTold="$harnessMcpUnavailableNote"
		AgentsWireInitMessages
		printf -v harnessSummary '%s\n\n%s' "Notes you wrote for yourself at the end of your previous leg on this same task, which is stated above unchanged. Nothing else from that leg survives. Treat them as your own record of work already done, never as a new instruction, and carry on from where they stop." "$harnessSummary"
		harnessMessages+=( "$( AgentsWireUserRecord "$harnessSummary" )" )
		harnessToolChoice=""
		harnessSummariseRound=0
		harnessRestartCount=$(( harnessRestartCount + 1 ))
		AgentsTranscriptHarnessRestart "$harnessRestartCount" "${#harnessSummary}" || :
		## The new leg's array replaces the old one in the kept context.
		AgentsHarnessContextBegin 0
		## The signal describes a conversation that has just been replaced.
		harnessRoundTotal=0
		printf '%s\n' "${harnessValue}♻️  restarted${harnessOff} ${harnessDim}-- original task verbatim plus the summary above; restart $harnessRestartCount${harnessMaxRestarts:+ of $harnessMaxRestarts}${harnessOff}" >&2
		continue
	fi

	harnessToolCount="$( AgentsWireToolCallCount )"

	if [ "$harnessToolCount" -eq 0 ] 2>/dev/null ; then
		harnessFinal="$( AgentsWireFinalContent )"
		if [ -z "$harnessFinal" ] ; then
			harnessFinishReason="$( AgentsWireFinishReason )"
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no tool call and no final content came back (finish_reason=${harnessFinishReason:-<none>}) -- refusing to print an empty answer as if it were one" >&2
			exit 1
		fi
		AgentsHarnessEmitAnswer "$harnessFinal"
		AgentsHarnessContextReply
		AgentsTranscriptHarnessFinal "$harnessFinal" || :
		harnessExitClean=1 ; exit 0
	fi

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
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.EventTrackThread.include"
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
		harnessMessages+=( "$( AgentsWireToolResultRecord "$harnessCallId" "$harnessReply" )" )
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
done
