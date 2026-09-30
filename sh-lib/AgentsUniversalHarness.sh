#!/usr/bin/env bash
set -e

## AgentsUniversalHarness.sh -- the universal tool-calling harness: all of the
## logic, none of the provider specifics. Never invoked directly: a provider stub
## sets the HARNESS_* variables and execs this file, so the core becomes that
## process. Endpoint-shaped code lives in the wire adapter named by HARNESS_WIRE.
## AgentsHarnessSelfCheck.test.awk and AgentsHarnessContainmentCheck.test.sh locate code here
## by exact spellings, so renaming anything is a coordinated change to both.
## DESIGN DECISION 1 -- a mid-stream disconnect discards partial state and retries
## the whole round; there is no resume primitive here. DESIGN DECISION 2 -- such a
## retry never consumes a round against the cap. DESIGN DECISION 3 -- a full context
## is met by summarise-and-restart, never by eviction. MAGIC.md carries the
## reasoning.

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
			## AgentsHarnessMcpClient.sh resolves the name against .local/agents/mcp.servers.json.
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
	## member where MDAT_SKILLSET_ROOT is unset; one it still cannot find is said, not dropped.
	harnessServedSkillset="${MDAT_SKILLSET_ROOT:-${HOME:+$HOME/.claude/skills}}"
	## Announced, then exported, so every later check and every child the call runs reads the same root.
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] ; then
		printf 'WARNING: MDAT_SKILLSET_ROOT is not set in this process, so the served identity is read from the fallback %s\n' "${harnessServedSkillset:-<HOME unset too>}" >&2
		[ -z "$harnessServedSkillset" ] || export MDAT_SKILLSET_ROOT="$harnessServedSkillset"
	fi
	if [ -n "$harnessAgent" ] && [ ! -r "$harnessServedSkillset/$harnessAgent/$harnessAgent.basic.md" ] ; then
		harnessAgentMissing="no team identity resolved: ${harnessServedSkillset:-<MDAT_SKILLSET_ROOT and HOME unset>}/$harnessAgent/$harnessAgent.basic.md is not readable -- set MDAT_SKILLSET_ROOT in the MCP server environment"
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
if [ "${#harnessAccessRoots[@]}" -eq 0 ] ; then
	harnessRootsInclude="$harnessHere/AgentsTools.ClientAccessRoots.include"
	if [ ! -f "$harnessRootsInclude" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the access-root mechanism is missing from this package: $harnessRootsInclude" >&2
		exit 1
	fi
	## The include reaches the config store through this name, as it does in the console.
	if ! type DistroAgentsTools >/dev/null 2>&1 ; then
		DistroAgentsTools(){ "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
	fi
	. "$harnessRootsInclude"
	## Captured on its own line so a failed producer refuses the run: read through the
	## herestring directly, its status is lost and a short set passes as the whole one.
	## stderr is captured with it, so the reason travels with the refusal; the loop
	## below keeps absolute paths only. Under --intern-tool stdout is all a caller sees.
	if ! harnessOwnRoots="$( AgentsToolsClientAccessRoots "${MMDAPP:-}" "$harnessAgent" 2>&1 )" ; then
		[ -z "$harnessToolOnly" ] || printf 'ERROR: the access-root set could not be computed, so nothing was done: %s\n' "$harnessOwnRoots"
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the access-root set could not be computed, refusing rather than running on a partial set: $harnessOwnRoots" >&2
		exit 1
	fi
	while IFS= read -r harnessOwnRoot ; do
		case "$harnessOwnRoot" in
			/*) harnessAccessRoots+=( "$harnessOwnRoot" ) ;;
		esac
	done <<< "$harnessOwnRoots"
	## Writes narrow the way the console narrows them: the write reference roots plus the
	## declared Edit grants, never the whole read set, so the skills root stays read-only.
	if [ "${#harnessWriteAccessRoots[@]}" -eq 0 ] ; then
		if ! harnessOwnRoots="$( { AgentsToolsClientAccessReferenceRoots write "${MMDAPP:-}" "$harnessAgent" && AgentsToolsClientAccessGrantRoots ; } 2>&1 )" ; then
			[ -z "$harnessToolOnly" ] || printf 'ERROR: the write-root set could not be computed, so nothing was done: %s\n' "$harnessOwnRoots"
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the write-root set could not be computed, refusing rather than writing wherever reads reach: $harnessOwnRoots" >&2
			exit 1
		fi
		while IFS= read -r harnessOwnRoot ; do
			case "$harnessOwnRoot" in
				/*) harnessWriteAccessRoots+=( "$harnessOwnRoot" ) ;;
			esac
		done <<< "$harnessOwnRoots"
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

harnessRoots=""
for harnessRoot in "${harnessAccessRoots[@]}" ; do
	harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessRoot" )"$'\n'
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
	for harnessWriteRoot in "${harnessWriteAccessRoots[@]}" ; do
		harnessWriteRoots="${harnessWriteRoots}$( AgentsHarnessResolveDir "$harnessWriteRoot" )"$'\n'
	done
	## A named member writes its own directory by definition, without being granted it.
	[ -z "$harnessAgentRealDir" ] || harnessWriteRoots="${harnessWriteRoots}$harnessAgentRealDir"$'\n'
fi
[ -n "$harnessWriteRoots" ] || harnessWriteRoots="$harnessRoots"

## The spawn's own sandbox is added here, after the write set is final.
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
	harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/input" )"$'\n'"$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/output" )"$'\n'
	harnessWriteRoots="${harnessWriteRoots}$( AgentsHarnessResolveDir "$MDAT_SPAWN_SANDBOX_ROOT/output" )"$'\n'
fi

## The CLI's per-session scratchpad joins both sets, glob-matched since its path encoding is not ours.
[ -n "${MDAT_SPAWN_SESSION_ID:-}" ] || [ -z "${CLAUDE_CODE_SESSION_ID:-}" ] || for harnessScratchpadDir in "/tmp/claude-$UID"/*/"$CLAUDE_CODE_SESSION_ID"/scratchpad ; do
	[ -d "$harnessScratchpadDir" ] || continue
	harnessScratchpadDir="$( AgentsHarnessResolveDir "$harnessScratchpadDir" )"
	harnessRoots="${harnessRoots}${harnessScratchpadDir}"$'\n'
	harnessWriteRoots="${harnessWriteRoots}${harnessScratchpadDir}"$'\n'
done

## Claude Code saves a tool result too large to return under its own session folder and
## tells the agent to read it there, so that folder joins the read set only, after writes.
[ -z "${CLAUDE_CODE_SESSION_ID:-}" ] || for harnessSessionResults in "$HOME/.claude/projects"/*/"$CLAUDE_CODE_SESSION_ID"/tool-results ; do
	[ ! -d "$harnessSessionResults" ] || harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessSessionResults" )"$'\n'
done

harnessScratch="$( mktemp -d "${TMPDIR:-/tmp}/AgentsUniversalHarness.XXXXXX" )" || {
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
## Ceiling on one Wait call, its own knob beside Bash's, as MCP enumeration has its
## own. 600 is ten minutes: twice the operation's own five-minute default, so a model
## asking for a longer single wait still gets one, while no single call can hold this
## run open indefinitely. A long vigil is many bounded waits, not one unbounded one --
## which is what lets the agent re-decide between them.
harnessWaitTimeout="${MDAT_HARNESS_WAIT_TIMEOUT:-600}"
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

## A granted call for this session, tool and resolved target; an Allow once is used up here.
AgentsHarnessGranted(){ ## tool, resolved target
	local grantTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" grantSession grantLine
	grantSession="$( AgentsHarnessSessionKey )"
	[ -n "$2" ] && [ -n "$grantSession" ] && [ -n "$harnessAgent" ] && [ -x "$grantTools" ] || return 1
	"$grantTools" --intern-op-permission-grant-read "$harnessAgent" --session-id "$grantSession" --tool "$1" --target "$2" \
		> "$harnessScratch/grant.out" 2> /dev/null || return 1
	grantLine="$( LC_ALL=C sed -n 's/^GRANT: //p' "$harnessScratch/grant.out" | head -1 )"
	case "$grantLine" in
		'session '*|'planned '*) return 0 ;;
		'once '*)
			"$grantTools" --intern-op-permission-grant-consume --session-id "$grantSession" --refusal-id "${grantLine#once }" \
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
	printf '%s\n' "$3"
	refusalSession="$( AgentsHarnessSessionKey )"
	if [ -z "$refusalSession" ] || [ -z "$harnessAgent" ] || [ ! -x "$refusalTools" ] ; then
		printf 'REFUSAL-ID: none -- this session has no session id or team identity, so the refusal was not recorded and cannot be escalated by id.\n'
		return 0
	fi
	"$refusalTools" --intern-op-permission-refusal-log "$harnessAgent" --session-id "$refusalSession" --tool "$1" --target "$2" \
		--reason "$3" > "$harnessScratch/refusal.out" 2> "$harnessScratch/refusal.err" || :
	refusalId="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$harnessScratch/refusal.out" | head -1 )"
	if [ -z "$refusalId" ] ; then
		printf 'REFUSAL-ID: none -- recording the refusal failed, so it cannot be escalated by id. What the operation reported follows:\n'
		cat "$harnessScratch/refusal.err" 2>/dev/null
		return 0
	fi
	printf 'REFUSAL-ID: %s\n' "$refusalId"
	printf 'This is a refusal, not a verdict. If this task needs the call, ask for it with AskUserQuestion kind=permission, refusal_id=%s, a reason and a task_ref, addressed to the coordinator in this session. Carry on with work that does not need it. A granted call is retried exactly as it was made.\n' "$refusalId"
	LC_ALL=C grep '⚠️' "$harnessScratch/refusal.err" 2>/dev/null || :
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
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
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

## Whole-file overwrite or create, never a partial patch; Edit is the partial path.
AgentsHarnessToolWrite(){
	local toolPath="${3:-$1}" toolContent="$2" toolTemp toolLock=""
	if [ -z "$toolPath" ] ; then
		AgentsHarnessRefusal Write "" "ERROR: no path was given -- pass file_path, or path. Keys received: $( printf '{"a":%s}' "$4" | LC_ALL=C awk -v path=a -v mode=keys -f "$harnessHere/AgentsHarnessJsonSlice.awk" 2>/dev/null | LC_ALL=C awk 'BEGIN { keyList = "" ; } { keyList = keyList ( NR > 1 ? ", " : "" ) $0 ; } END { print ( keyList == "" ? "none" : keyList ) ; }' ). Nothing was written." ; return 0
	fi
	if ! AgentsHarnessPathAllowed "$toolPath" "$harnessWriteRoots" && ! AgentsHarnessGranted Write "$harnessResolvedPath" ; then
		AgentsHarnessRefusal Write "${harnessResolvedPath:-$toolPath}" "ERROR: path not in the allowed write-root set -- it may still be readable: $toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if AgentsHarnessWriteExcluded "$toolPath" ; then
		AgentsHarnessRefusal Write "$toolPath" "ERROR: path is in a team store that an unattended session never writes with Write or Edit -- use the team tooling operation for it: $toolPath" ; return 0
	fi
	mkdir -p "$( dirname -- "$toolPath" )" 2>/dev/null || {
		printf 'ERROR: could not create the parent directory of: %s\n' "$toolPath" ; return 0
	}
	if ! AgentsHarnessLockTake "$toolPath" ; then
		printf 'ERROR: could not take the write lock for %s -- another call is writing it, or the lock area is unusable -- so nothing was written. Retry.\n' "$toolPath" ; return 0
	fi
	toolLock="$agentsLocalLockPath"
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
AgentsHarnessToolEdit(){
	local toolPath="${5:-$1}" toolOld="$2" toolNew="$3" toolAll="$4" toolCount toolTemp toolLock=""
	if [ -z "$toolPath" ] ; then
		AgentsHarnessRefusal Edit "" "ERROR: no path was given -- pass file_path, or path. Keys received: $( printf '{"a":%s}' "$6" | LC_ALL=C awk -v path=a -v mode=keys -f "$harnessHere/AgentsHarnessJsonSlice.awk" 2>/dev/null | LC_ALL=C awk 'BEGIN { keyList = "" ; } { keyList = keyList ( NR > 1 ? ", " : "" ) $0 ; } END { print ( keyList == "" ? "none" : keyList ) ; }' ). Nothing was written." ; return 0
	fi
	if ! AgentsHarnessPathAllowed "$toolPath" "$harnessWriteRoots" && ! AgentsHarnessGranted Edit "$harnessResolvedPath" ; then
		AgentsHarnessRefusal Edit "${harnessResolvedPath:-$toolPath}" "ERROR: path not in the allowed write-root set -- it may still be readable: $toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if AgentsHarnessWriteExcluded "$toolPath" ; then
		AgentsHarnessRefusal Edit "$toolPath" "ERROR: path is in a team store that an unattended session never writes with Write or Edit -- use the team tooling operation for it: $toolPath" ; return 0
	fi
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	if [ -z "$toolOld" ] ; then
		printf 'ERROR: old_string is empty -- an empty match has no unique position\n' ; return 0
	fi
	## Taken before the count: a count read outside the lock is stale by the time it is used.
	if ! AgentsHarnessLockTake "$toolPath" ; then
		printf 'ERROR: could not take the write lock for %s -- another call is writing it, or the lock area is unusable -- so nothing was written. Retry.\n' "$toolPath" ; return 0
	fi
	toolLock="$agentsLocalLockPath"
	## index() counts and substitutes in one call so the two cannot drift; ENVIRON, never -v.
	toolCount="$( EDIT_OLD="$toolOld" LC_ALL=C awk -v RS=$'\001' '
		BEGIN { editOld = ENVIRON["EDIT_OLD"] ; matchCount = 0 ; }
		{
			scanRest = $0
			while ( ( matchPos = index(scanRest, editOld) ) > 0 ) {
				matchCount = matchCount + 1
				scanRest = substr(scanRest, matchPos + length(editOld))
			}
		}
		END { print matchCount + 0 ; }
	' "$toolPath" 2>/dev/null || : )"
	[ -n "$toolCount" ] || toolCount=0
	if [ "$toolCount" = "0" ] ; then
		AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: old_string not found in %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	## Only an explicit opt-in lifts the uniqueness guard; anything else leaves it standing.
	case "$toolAll" in
		true|1) ;;
		*) toolAll="" ;;
	esac
	if [ -z "$toolAll" ] && [ "$toolCount" != "1" ] ; then
		AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: old_string occurs %s times in %s -- it must identify exactly one place. Nothing was written; extend old_string until it is unique, or pass replace_all to change every occurrence.\n' "$toolCount" "$toolPath" ; return 0
	fi
	## `printf "%s", $0` with the RS re-join, never `print`, which appends ORS and
	## gave a file that ended without a newline one it never had.
	if ! EDIT_OLD="$toolOld" EDIT_NEW="$toolNew" EDIT_ALL="$toolAll" LC_ALL=C awk -v RS=$'\001' '
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
	' "$toolPath" > "$harnessScratch/edit.out" 2>/dev/null ; then
		AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: could not rewrite: %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	## Replaced by rename, as Write does, so no reader ever sees a half-written file.
	toolTemp="$( dirname -- "$toolPath" )/.$( basename -- "$toolPath" ).mdat-edit.$$"
	if ! cp -p "$toolPath" "$toolTemp" 2>/dev/null || ! cat "$harnessScratch/edit.out" > "$toolTemp" || ! mv -f "$toolTemp" "$toolPath" ; then
		rm -f "$toolTemp" ; AgentsToolsLocalLockGive "$toolLock"
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	AgentsToolsLocalLockGive "$toolLock"
	if [ -n "$toolAll" ] ; then
		printf 'OK: replaced %s occurrence(s) in %s\n' "$toolCount" "$toolPath"
	else
		printf 'OK: replaced one occurrence in %s\n' "$toolPath"
	fi
}

## The root is tested before the pattern is evaluated, so a missing directory is named
## as missing rather than collapsing into "the pattern matched nothing".
AgentsHarnessToolGlob(){
	local toolPattern="$1" toolPath="${2:-$PWD}" toolLong="$3" toolBytes globStat globLine globSlice
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
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

## `ripgrep` would replace this `grep -rn` outright; the human-owner ruled "Not now".
AgentsHarnessToolGrep(){ ## pattern, path, context, before, after, ignore_case, output_mode, glob, -n, -o, -A, -B, -C, -i, head_limit, offset, multiline, type
	local toolPattern="$1" toolPath="${2:-$PWD}" toolContext="${13:-$3}" toolBefore="${12:-$4}" toolAfter="${11:-$5}" toolIgnoreCase="${14:-$6}" toolMode="${7:-files_with_matches}" toolGlob="$8" toolLineNumbers="$9" toolOnlyMatching="${10}" toolHeadLimit="${15:-250}" toolOffset="${16:-0}" toolBytes toolRegex grepFlags globPrefix globGroup globSuffix globAlts globAlt
	case "${17}" in
		true|1) printf 'ERROR: multiline is not supported by this Grep, only by the native Grep tool. Search with a pattern that matches within one line instead. Nothing was searched.\n' ; return 0 ;;
	esac
	if [ -n "${18}" ] ; then
		printf 'ERROR: type is not supported yet: its type table is not built. Use glob to select files by name instead, such as *.js. Nothing was searched.\n' ; return 0
	fi
	case "${toolGlob#\*\*/}" in
		*/*) ;;
		*) toolGlob="${toolGlob#\*\*/}" ;;
	esac
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
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
	{
		case "$toolGlob" in
			*/*)
				find "$toolPath" -type f 2>&3 | GLOB_ROOT="${toolPath%/}/" GLOB_PATTERN="$toolGlob" LC_ALL=C awk -f "$harnessHere/AgentsHarnessGlobFilterFunction.awk" | LC_ALL=C tr '\n' '\000' | xargs -0 -r grep "${grepFlags[@]}" -H -- "$toolRegex" 2>&1 || :
			;;
			*) grep "${grepFlags[@]}" -- "$toolRegex" "$toolPath" 2>&1 || : ;;
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
			( sleep "$toolTimeout" ; kill -TERM "$harnessRunPid" 2>/dev/null && : > "$harnessScratch/run.timedout" ) >/dev/null &
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
	[ -z "$searchDefaults" ] || searchDenied="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select WEB_DENY_PREFIXES 2> "$harnessScratch/webpolicy.err" )" || searchDefaults=""
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

AgentsHarnessToolWebFetch(){
	local toolUrl="$1" fetchUrl="$1" fetchStatus fetchTarget fetchRc=0 fetchHops=0 toolBytes fetchTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" fetchVerdict fetchAllowExtra="" fetchDenied="" fetchUnread="" fetchFromHost fetchToHost
	case "$toolUrl" in
		http://*|https://*) ;;
		*)
			printf 'ERROR: url must be an absolute http:// or https:// URL, got: %s\n' "$toolUrl" ; return 0
		;;
	esac
	[ -x "$fetchTools" ] || fetchUnread=1
	[ -n "$fetchUnread" ] || fetchAllowExtra="$( "$fetchTools" --agents-config-option magic-team --select WEB_ALLOW_PREFIXES 2> "$harnessScratch/webpolicy.err" )" || fetchUnread=1
	[ -n "$fetchUnread" ] || fetchDenied="$( "$fetchTools" --agents-config-option magic-team --select WEB_DENY_PREFIXES 2>> "$harnessScratch/webpolicy.err" )" || fetchUnread=1
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
	case "$fetchStatus" in
		2??) printf '... HTTP %s -- raw body follows, nothing stripped or rendered ...\n' "$fetchStatus" ;;
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

## The team's own sanctioned send operation, never a Slack call of this harness's own:
## the credential stays inside that operation and never reaches argv. The text goes in
## on stdin, where no shell quoting can reach it -- a single apostrophe in a composed
## send emptied one live message in this estate.
AgentsHarnessToolSendMessage(){ ## target, message, as bot, address to, broadcast (true: a thread reply also shown in the conversation)
	local toolTarget="$1" toolMessage="$2" toolAsBot="$3" toolAddressTo="$4" toolBroadcast="${5:-}" sendRc=0
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to send under, and one is never guessed here. Nothing was sent. Report this rather than working around it.%s\n' "${harnessAgentMissing:+ ($harnessAgentMissing)}" ; return 0
	fi
	## No target named: default to this session's own coworking thread, where one
	## exists. An ad-hoc/solo spawn holding none keeps today's explicit-target
	## requirement exactly -- the error just below fires precisely as it always has.
	if [ -z "$toolTarget" ] ; then
		type AgentsToolsSessionThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		toolTarget="$( AgentsToolsSessionThreadFind 2>/dev/null )" || toolTarget=""
	fi
	if [ -z "$toolTarget" ] || [ -z "$toolMessage" ] ; then
		printf 'ERROR: both to and message are required, and one of them was empty. Nothing was sent.\n' ; return 0
	fi
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other send path exists here. Nothing was sent.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	## Built as argv so the optional flag is one token rather than a quoted fragment.
	set -- "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-comms-slack-send-message "$harnessAgent" "$toolTarget"
	case "$toolAsBot" in
		true|1|yes) set -- "$@" --identity-bot ;;
	esac
	[ -z "$toolAddressTo" ] || set -- "$@" --address-to "$toolAddressTo"
	[ "$toolBroadcast" != "true" ] || set -- "$@" --reply-broadcast
	## Output to a file rather than a capture: the operation forks curl, and a capture
	## returns on pipe EOF rather than on the command it ran.
	printf '%s' "$toolMessage" | "$@" --from-stdin >"$harnessScratch/send.out" 2>&1 || sendRc=$?
	if [ "$sendRc" != "0" ] ; then
		printf 'ERROR: the send failed (rc=%s) and nothing was posted. What the operation reported follows:\n' "$sendRc"
	else
		printf 'Sent to %s as %s. What the operation reported follows:\n' "$toolTarget" "$harnessAgent"
	fi
	cat "$harnessScratch/send.out"
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
AgentsHarnessToolWait(){
	local toolSources="$1" toolTimeout="$2" toolPoll="$3" toolSince="$4" toolAddressee="$5" waitRc=0 waitSource
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to wait as, and one is never guessed here. Nothing was waited on.%s\n' "${harnessAgentMissing:+ ($harnessAgentMissing)}" ; return 0
	fi
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other wait path exists here. Nothing was waited on.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	## Per-call override of the harness-wide ceiling, validated the way Bash validates
	## its own, and cut down to that ceiling rather than refused: a bound that is too
	## long is a bound, and refusing it would turn a waitable question into an error.
	if [ -n "$toolTimeout" ] ; then
		if ! AgentsHarnessWholeNumber "$toolTimeout" ; then
			printf 'ERROR: timeout must be a whole number of seconds, got: %s\n' "$toolTimeout" ; return 0
		fi
	else
		toolTimeout="$harnessWaitTimeout"
	fi
	[ "$toolTimeout" -le "$harnessWaitTimeout" ] || toolTimeout="$harnessWaitTimeout"
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
	## No source named: default to this session's own coworking thread, any post
	## but the caller's own, where a session thread exists. An ad-hoc/solo spawn
	## holding none keeps today's default exactly -- magic-team and human-owner,
	## resolved below by --member-wait-for-input itself from an empty sources list.
	if [ -z "$toolSources" ] ; then
		type AgentsToolsSessionThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		local waitDefaultThread=""
		waitDefaultThread="$( AgentsToolsSessionThreadFind 2>/dev/null )" || waitDefaultThread=""
		[ -z "$waitDefaultThread" ] || toolSources="slack:$waitDefaultThread:conversation"
	fi
	## Built as argv, so a source naming a thread stays one token rather than a
	## quoted fragment, and an empty sources string adds no flag at all.
	set -- "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-wait-for-input "$harnessAgent"
	for waitSource in $toolSources ; do
		set -- "$@" --wait-source "$waitSource"
	done
	set -- "$@" --wait-timeout "$toolTimeout"
	[ -z "$toolPoll" ] || set -- "$@" --wait-poll-interval "$toolPoll"
	[ -z "$toolSince" ] || set -- "$@" --wait-since-utime "$toolSince"
	[ -z "$toolAddressee" ] || set -- "$@" --wait-addressee "$toolAddressee"
	"$@" >"$harnessScratch/wait.out" 2>"$harnessScratch/wait.err" || waitRc=$?
	if [ "$waitRc" != "0" ] ; then
		printf 'ERROR: the wait could not be performed (rc=%s), so NOTHING is known about those sources -- this is not a wait that found nothing, and their silence must not be read as quiet. What the operation reported follows:\n' "$waitRc"
		cat "$harnessScratch/wait.err"
		return 0
	fi
	cat "$harnessScratch/wait.out"
}

## Helpers behind Agent, TaskStop and TaskOutput. Deliberately NOT named
## AgentsHarnessTool*: that family is the static tool class AgentsHarnessSelfCheck.test.awk
## matches site by site, and a helper with no tool behind it is an orphan there.

## A value reaching a command line, gated by explicit character enumeration rather than
## a bracket range -- [a-z] is collation-dependent and has matched `A` on this estate.
AgentsHarnessBareName(){ ## candidate
	local nameRest="$1" nameChar
	[ -n "$nameRest" ] || return 1
	while [ -n "$nameRest" ] ; do
		nameChar="${nameRest%"${nameRest#?}"}"
		nameRest="${nameRest#?}"
		case "$nameChar" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
			0|1|2|3|4|5|6|7|8|9) ;;
			-|_|.) ;;
			*) return 1 ;;
		esac
	done
	return 0
}

## Where the spawn proxy records a session: one dispatch item per spawn, in whichever
## board state holds it. Both handles taken here already exist -- the session id, which
## ListAgents prints, and the item filename, which Agent's result names -- so nothing
## mints an identifier of its own. Prints the item path, or nothing.
AgentsHarnessDispatchItemPath(){ ## handle
	local handleText="$1" dispatchState dispatchFile
	local dispatchFiles=()
	case "$handleText" in
		''|*/*|*..*) return 0 ;;
	esac
	for dispatchState in running pending blocked parked processed archived retained backlog ; do
		[ -f "$MDAT_DATA_ROOT/board/$dispatchState/$handleText" ] || continue
		printf '%s' "$MDAT_DATA_ROOT/board/$dispatchState/$handleText"
		return 0
	done
	for dispatchState in running pending blocked parked processed archived retained backlog ; do
		for dispatchFile in "$MDAT_DATA_ROOT"/board/"$dispatchState"/dispatch-*.md ; do
			[ -f "$dispatchFile" ] || continue
			dispatchFiles+=( "$dispatchFile" )
		done
	done
	[ "${#dispatchFiles[@]}" -gt 0 ] || return 0
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

## The output path the spawn proxy writes into a dispatch item when it CLOSES one.
## Empty while the session is still running, which is exactly when a caller wants it --
## hence the receipt derivation below rather than this alone.
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

## The live processes carrying a spawn id in their own command line. The console
## passes --session-id to the CLI as this spawn's own id, so the spawn-id the dispatch
## item records is also an OS handle -- which is what lets a stop reach a helper that
## is cooperating in no way. The id travels in the environment, never in argv, so this never matches itself.
## -ww defeats the width truncation that would otherwise cut the id off a long CLI line.
AgentsHarnessSessionPids(){ ## session id
	export MDAT_HARNESS_WANT_SESSION="$1"
	ps -A -ww -o pid=,args= 2>/dev/null | LC_ALL=C awk '
		index($0, ENVIRON["MDAT_HARNESS_WANT_SESSION"]) > 0 { print $1 ; }
	'
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
AgentsHarnessToolAgent(){ ## agent name, prompt, cli service, session name or comment
	local toolAgentName="$1" toolPrompt="$2" toolCliService="$3" toolSessionNameOrComment="$4" spawnRc=0
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
	if [ ! -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present at the origin this workspace resolves, %s, and no other spawn path exists here. Nothing was spawned.\n' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	set -- "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-agent-spawn-proxy "$toolAgentName" \
		--from-stdin --dispatch-doc:create --context Agent
	[ -z "$toolCliService" ] || set -- "$@" --spawn-cli-service "$toolCliService"
	## Absent: this spawn joins the caller's own coworking session where one is
	## inherited, or runs ad-hoc/solo where none is. Present: this spawn starts a
	## session of its own, titled by this text -- passed as a genuine argv token,
	## never folded into any format string the proxy builds from it.
	[ -z "$toolSessionNameOrComment" ] || set -- "$@" --session-name-or-comment "$toolSessionNameOrComment"
	printf '%s' "$toolPrompt" | "$@" >"$harnessScratch/spawn.out" 2>&1 || spawnRc=$?
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
		## Confined to the team data store: this parameter would otherwise be a read of
		## any path at all, around the access roots that bound Read, Glob and Grep.
		case "$toolOutputFile" in
			"$MDAT_DATA_ROOT"/*) ;;
			*)
				printf 'ERROR: output_file is accepted only inside the team data store at %s, and this one is outside it: %s. Give the dispatch item name or the session id as handle instead.\n' "$MDAT_DATA_ROOT" "$toolOutputFile" ; return 0
			;;
		esac
		case "$toolOutputFile" in
			*..*)
				printf 'ERROR: output_file may not step upward out of the team data store: %s\n' "$toolOutputFile" ; return 0
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
			printf 'ERROR: dispatch item %s was found, but no output log for receipt %s exists under %s/audit. Status recorded on the item: %s. The log is absent rather than unread -- a spawn whose dispatch document was suppressed writes its log to a scratch path this tool does not reach.\n' "$itemName" "$receiptId" "$MDAT_DATA_ROOT" "${itemStatus:-<none>}" ; return 0
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
AgentsHarnessToolTaskStop(){ ## handle, force, task_id, shell_id
	local toolHandle="${3:-${4:-$1}}" toolForce="$2"
	local itemPath itemName itemStatus sessionId stopPids stopPid survivors forceWanted=no
	if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
		printf 'ERROR: MDAT_DATA_ROOT is not set in this process, so the dispatch records naming a helper session cannot be located. Nothing was signalled, and no session is implied to be absent.\n' ; return 0
	fi
	if [ -z "$toolHandle" ] ; then
		printf 'ERROR: task_id is required: the session id, which ListAgents prints, or the dispatch item filename, which the Agent result names as DISPATCH_ITEM. Nothing was signalled.\n' ; return 0
	fi
	case "$toolForce" in
		true|1|yes) forceWanted=yes ;;
	esac
	itemPath="$( AgentsHarnessDispatchItemPath "$toolHandle" )"
	if [ -z "$itemPath" ] ; then
		printf 'ERROR: no dispatch item matches handle %s in any board state under %s. A helper spawned WITHOUT a tracking document has no record here at all, so it cannot be reached by handle -- that is a property of how it was spawned, and nothing was signalled.\n' "$toolHandle" "$MDAT_DATA_ROOT" ; return 0
	fi
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
	stopPids="$( AgentsHarnessSessionPids "$sessionId" )"
	if [ -z "$stopPids" ] ; then
		printf 'STOP-RESULT: NO-PROCESS\nDispatch item %s, session %s, status %s.\nNo running process carries that session id, so nothing was signalled. Where the status above is a closed one this session had already finished; otherwise the record says running and no process matches it, which is UNKNOWN rather than stopped -- the session may have died without its record being closed, or its CLI may not carry the session id on its command line.\n' "$itemName" "$sessionId" "${itemStatus:-<none>}" ; return 0
	fi
	for stopPid in $stopPids ; do
		kill -TERM "$stopPid" 2>/dev/null || :
	done
	sleep 2
	survivors="$( AgentsHarnessSessionPids "$sessionId" )"
	if [ -z "$survivors" ] ; then
		printf 'STOP-RESULT: STOPPED\nDispatch item %s, session %s.\nTERM was sent to pid(s) %s and the process list no longer carries that session id.\nThe dispatch item is closed by the spawn operation itself rather than here, so its status may still read as started for a moment.\n' "$itemName" "$sessionId" "$( printf '%s' "$stopPids" | tr '\n' ' ' )" ; return 0
	fi
	if [ "$forceWanted" != "yes" ] ; then
		printf 'STOP-RESULT: STILL-RUNNING\nDispatch item %s, session %s.\nTERM was sent to pid(s) %s and pid(s) %s are still running two seconds later. Nothing further was sent: KILL happens only when force is asked for. Call again with force set true to send it.\n' "$itemName" "$sessionId" "$( printf '%s' "$stopPids" | tr '\n' ' ' )" "$( printf '%s' "$survivors" | tr '\n' ' ' )" ; return 0
	fi
	for stopPid in $survivors ; do
		kill -KILL "$stopPid" 2>/dev/null || :
	done
	sleep 2
	survivors="$( AgentsHarnessSessionPids "$sessionId" )"
	if [ -z "$survivors" ] ; then
		printf 'STOP-RESULT: KILLED\nDispatch item %s, session %s.\nTERM did not end it, KILL was sent because force was asked for, and the process list no longer carries that session id.\nA KILLed CLI reaps none of its own children, so anything it had started may still be running.\n' "$itemName" "$sessionId" ; return 0
	fi
	printf 'STOP-RESULT: NOT-STOPPED\nDispatch item %s, session %s.\nTERM and then KILL were both sent, and pid(s) %s are STILL present. This session was NOT stopped -- report it rather than working around it.\n' "$itemName" "$sessionId" "$( printf '%s' "$survivors" | tr '\n' ' ' )"
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

## ONE optional labelled field, appended only where it carries a value. A label printed
## over an empty value is worse than its absence: it asserts the writer considered that
## field and had nothing, which is exactly what an omission must never be read as.
AgentsHarnessFormalField(){ ## label, value
	[ -n "$2" ] || return 0
	printf '%s\n%s\n\n' "$1" "$2"
}

## The four report tools below are SendMessage with a fixed shape and NOT a second
## delivery path -- one mechanism, four stubs over it, which is the shape the
## specification asks for. This is the one place that shape is applied: the target
## check, the identity rule and the send itself are written once rather than four
## times, and each stub owns only its own field validation and body. Deliberately NOT
## named AgentsHarnessTool*: that family is the static tool class
## AgentsHarnessSelfCheck.test.awk matches site by site, and a helper with no tool behind it
## is reported there as an orphan.
AgentsHarnessFormalSend(){ ## tool name, target, as_bot, body text
	local formalName="$1" formalTo="$2" formalAsBot="$3" formalBody="$4"
	if [ -z "$formalTo" ] ; then
		printf 'ERROR: %s: to is required and was empty, so there is nowhere to post it. Nothing was sent.\n' "$formalName" ; return 0
	fi
	AgentsHarnessToolSendMessage "$formalTo" "$formalBody" "$formalAsBot"
}

## Posting a handback does not end this run and releases nobody waiting on it -- the
## description says so, because a model reading otherwise stops working mid-task.
AgentsHarnessToolSubagentHandback(){
	local toolTo="$1" toolTask="$2" toolOutcome="$3" toolFindings="$4" toolUnfinished="$5" toolAsBot="$6" toolBody
	if [ -z "$toolOutcome" ] ; then
		printf 'ERROR: SubagentHandback: outcome is required and was empty. A handback carrying no outcome reports nothing, so nothing was sent.\n' ; return 0
	fi
	## Answers to this session's questions nobody waited on are collected by the tooling
	## before it hands back, so none is left unread (AgentsTools.PendingReplyCollect.include).
	local toolCollected="" toolCollectSession
	toolCollectSession="$( AgentsHarnessSessionKey )"
	if [ -n "$toolCollectSession" ] ; then
		toolCollected="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-pending-reply-collect \
			--session-id "$toolCollectSession" --context SubagentHandback 2>/dev/null | LC_ALL=C grep -v '^COLLECT: ' )" || toolCollected=""
	fi
	toolBody="$( {
		printf 'Handback\n\n'
		AgentsHarnessFormalField 'Task as given:' "$toolTask"
		AgentsHarnessFormalField 'Outcome:' "$toolOutcome"
		AgentsHarnessFormalField 'Findings:' "$toolFindings"
		AgentsHarnessFormalField 'Unfinished, and what was not checked:' "$toolUnfinished"
		AgentsHarnessFormalField 'Answers collected, and questions still open:' "$toolCollected"
	} )"
	AgentsHarnessFormalSend SubagentHandback "$toolTo" "$toolAsBot" "$toolBody"
}

AgentsHarnessToolReportFindings(){
	local toolTo="$1" toolSubject="$2" toolFindings="$3" toolEvidence="$4" toolConfidence="$5" toolAsBot="$6" toolBody
	if [ -z "$toolSubject" ] || [ -z "$toolFindings" ] ; then
		printf 'ERROR: ReportFindings: both subject and findings are required, and one of them was empty. Nothing was sent.\n' ; return 0
	fi
	## Caller text never lands in a format string: a % in a subject would otherwise be
	## read as a conversion specifier and corrupt the line it sits on.
	toolBody="$( {
		printf 'Findings: %s\n\n' "$toolSubject"
		AgentsHarnessFormalField 'What was established:' "$toolFindings"
		AgentsHarnessFormalField 'Evidence:' "$toolEvidence"
		AgentsHarnessFormalField 'Confidence, and what was not checked:' "$toolConfidence"
	} )"
	AgentsHarnessFormalSend ReportFindings "$toolTo" "$toolAsBot" "$toolBody"
}

AgentsHarnessToolPushNotification(){
	local toolTo="$1" toolSeverity="$2" toolHeadline="$3" toolDetail="$4" toolAction="$5" toolAsBot="$6" toolBody toolMark
	if [ -z "$toolHeadline" ] ; then
		printf 'ERROR: PushNotification: headline is required and was empty. Nothing was sent.\n' ; return 0
	fi
	## Enumerated, never defaulted: an unrecognised severity quietly rendered as info is
	## a real alert delivered as a note, which is the one failure this field prevents.
	case "$toolSeverity" in
		info)  toolMark="INFO" ;;
		warn)  toolMark="WARN" ;;
		alert) toolMark="ALERT" ;;
		*)
			printf 'ERROR: PushNotification: severity must be info, warn or alert, got: %s. Nothing was sent, because guessing it would deliver an alert as a note.\n' "${toolSeverity:-<none>}" ; return 0
		;;
	esac
	toolBody="$( {
		printf '%s -- %s\n\n' "$toolMark" "$toolHeadline"
		AgentsHarnessFormalField 'Detail:' "$toolDetail"
		AgentsHarnessFormalField 'Action required:' "$toolAction"
	} )"
	AgentsHarnessFormalSend PushNotification "$toolTo" "$toolAsBot" "$toolBody"
}

## Announces a document; it publishes nothing and creates nothing. The URL is gated the
## way WebFetch gates its own, because announcing a link nobody can open is worse than
## not announcing it: a reader cannot tell a wrong URL from a document they lack access to.
AgentsHarnessToolArtifact(){
	local toolTo="$1" toolUrl="$2" toolTitle="$3" toolKind="$4" toolSummary="$5" toolAsBot="$6" toolBody
	case "$toolUrl" in
		http://*|https://*) ;;
		*)
			printf 'ERROR: Artifact: url must be the absolute http:// or https:// URL of a document that already exists, got: %s. Nothing was sent, and nothing was published -- this tool only announces a document other tooling created.\n' "${toolUrl:-<none>}" ; return 0
		;;
	esac
	toolBody="$( {
		printf '%s\n\n' "${toolTitle:-Document}"
		AgentsHarnessFormalField 'Kind:' "$toolKind"
		AgentsHarnessFormalField 'Link:' "$toolUrl"
		AgentsHarnessFormalField 'Summary:' "$toolSummary"
	} )"
	AgentsHarnessFormalSend Artifact "$toolTo" "$toolAsBot" "$toolBody"
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
## AskUserQuestion, its stub in the myx.distro MCP, and a claude-native AskUserQuestion
## the hook reroutes into it -- because they all arrive at this function.
##
## Neither helper can fail this tool. A question that was genuinely asked must be
## reported as asked even where recording it did not work, so a failure here degrades
## to no record and a warning, never to a wrong outcome line.
AgentsHarnessPendingReplyOpen(){ ## conversation id, question body, then the typed-question metadata: kind, address_to, channel, question ts, thread ts, addressees, asking accounts, refusal id, options, then the thread tag and the question key
	local openTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" openId="" openSession
	[ -x "$openTools" ] || return 0
	[ -n "$harnessAgent" ] || return 0
	openSession="$( AgentsHarnessSessionKey )"
	openId="$( printf '%s' "$2" | "$openTools" --intern-op-pending-reply-open "$harnessAgent" \
		--to "$1" \
		${openSession:+--session-id "$openSession"} \
		${3:+--kind "$3"} ${4:+--address-to "$4"} ${5:+--channel "$5"} ${6:+--question-ts "$6"} ${7:+--thread-ts "$7"} \
		${8:+--addressees "$8"} ${9:+--asking-accounts "$9"} ${10:+--refusal-id "${10}"} ${11:+--options "${11}"} \
		${12:+--question-tag "${12}"} ${13:+--question-key "${13}"} \
		--context AskUserQuestion 2>"$harnessScratch/pending-open.err" )" || openId=""
	if [ -z "$openId" ] ; then
		printf 'WARNING: AskUserQuestion: the question was posted but NOT recorded as a pending reply, so nothing will resume or re-ask it later. What the operation reported follows:\n' >&2
		cat "$harnessScratch/pending-open.err" >&2 2>/dev/null || :
		return 0
	fi
	printf '%s\n' "$openId"
}

AgentsHarnessPendingReplyClose(){ ## pending reply id, status, optional verdict, optional ts of the reply taken as the answer
	local closeTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	[ -n "$1" ] || return 0
	[ -x "$closeTools" ] || return 0
	## Only while still open: a record another closer (a collect, a settle) closed first is left as it is.
	local closeRc=0
	"$closeTools" --intern-op-pending-reply-close "$1" --if-open --status "$2" ${3:+--verdict "$3"} ${4:+--answer-ts "$4"} --context AskUserQuestion >/dev/null 2>&1 || closeRc=$?
	case "$closeRc" in
		0|3) ;;
		*) printf 'WARNING: AskUserQuestion: pending reply %s could not be closed as %s, so it still reads as waiting.\n' "$1" "$2" >&2 ;;
	esac
	return 0
}

## A typed question's verdict, read and applied by the team's escalation operation.
## Prints its result lines; nothing at all when there is no record to read.
AgentsHarnessEscalationRead(){ ## pending reply id
	[ -n "$1" ] && [ -n "$harnessAgent" ] || return 0
	"$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-escalation-read "$harnessAgent" "$1" \
		> "$harnessScratch/escalation-read.out" 2> /dev/null || :
	LC_ALL=C grep -E '^(ESCALATION|VERDICT|VERDICT-TEXT|VERDICT-REASON|ANSWERED-BY|GRANT): ' "$harnessScratch/escalation-read.out" 2>/dev/null || :
}

AgentsHarnessToolAskUserQuestion(){
	local toolTo="$1" toolQuestion="$2" toolOptions="$3" toolContext="$4" toolWait="$5" toolTimeout="$6" toolSource="$7" toolAsBot="$8" toolAddressTo="$9"
	local toolKind="${10:-question}" toolUnderstood="${11}" toolFrom="${12}" toolWillDo="${13}" toolRefusalId="${14}" toolReason="${15}" toolTaskRef="${16}" toolPendingId="${17}"
	local askBody askSent askWaitOut askFirst askOutcome askPendingId=""
	local askChannel="" askTs="" askThreadTs="" askAddressees=""
	local askRounds=0
	local askAsk="" askOpen="" askOpenTs="" askSelfIds=" " askSendOut askRecordOnly=""
	local askSession="" askRecord="" askRecordLine askRefusedTool="" askRefusedTarget="" askRefusedOwner=""
	local askTag="" askKey="" askWhere="" askReuseChannel="" askReuseThread="" askDupId="" askDupOwner="" askDupSession="" askLock=""
	## A re-wait: the question is already posted and recorded, so everything it is judged
	## against comes from its open record, and nothing is posted again.
	if [ -n "$toolPendingId" ] ; then
		local rewaitRecord="" rewaitStatus="" rewaitSession="" rewaitLine
		AgentsHarnessBareName "$toolPendingId" && rewaitRecord="$MMDAPP/.local/agents/pending/$toolPendingId.md"
		if [ -z "$rewaitRecord" ] || [ ! -f "$rewaitRecord" ] ; then
			printf 'ERROR: AskUserQuestion: pending_id %s names no pending reply in this workspace, so there is nothing to wait on. Nothing was posted.\n' "$toolPendingId" ; return 0
		fi
		toolKind="question" ; toolTo="" ; toolAddressTo="" ; toolOptions=""
		while IFS= read -r rewaitLine ; do
			case "$rewaitLine" in
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
			printf 'ERROR: AskUserQuestion: pending reply %s belongs to session %s, not this one, so this session may not wait on it. Nothing was posted.\n' "$toolPendingId" "$rewaitSession" ; return 0
		fi
		if [ "$rewaitStatus" != "reply-pending" ] ; then
			printf 'ERROR: AskUserQuestion: pending reply %s is closed (status %s), so there is nothing to wait on. Nothing was posted.\n' "$toolPendingId" "${rewaitStatus:-none}" ; return 0
		fi
		[ ! -f "${rewaitRecord%.md}.options" ] || toolOptions="$( cat "${rewaitRecord%.md}.options" )"
		askPendingId="$toolPendingId"
		toolWait="true"
		askSent="(re-wait on pending reply $toolPendingId: nothing was posted)"
	else
	## No target named: default to this session's own coworking thread, where one
	## exists -- same rule and same reason as SendMessage's own default. An ad-hoc/
	## solo spawn holding none keeps today's explicit-target requirement exactly.
	if [ -z "$toolTo" ] ; then
		type AgentsToolsSessionThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		toolTo="$( AgentsToolsSessionThreadFind 2>/dev/null )" || toolTo=""
	fi
	if [ -z "$toolTo" ] ; then
		printf 'ERROR: AskUserQuestion: to is required and was empty, so there is nobody to ask. Nothing was sent.\n' ; return 0
	fi
	## The thread numbers its questions itself, so a number the asker put in front of the
	## text ("Q1: ...", "q2) ...", "Q3 - ...") would show beside it as a second one.
	local askLabel='^[Qq][0-9]+[[:space:]]*[-:.)][[:space:]]*'
	if [[ "$toolQuestion" =~ $askLabel ]] ; then
		toolQuestion="${toolQuestion:${#BASH_REMATCH[0]}}"
	fi
	if [ -z "$toolQuestion" ] ; then
		printf 'ERROR: AskUserQuestion: question is required and was empty. Nothing was sent.\n' ; return 0
	fi
	## A typed kind is refused before anything is sent when a field it needs is missing.
	case "$toolKind" in
		question) ;;
		readback)
			[ -n "$toolUnderstood" ] && [ -n "$toolFrom" ] && [ -n "$toolWillDo" ] || {
				printf 'ERROR: AskUserQuestion: kind readback needs understood, source and will_do, and one was empty. Nothing was sent.\n' ; return 0
			}
		;;
		decision)
			[ -n "$toolOptions" ] || {
				printf 'ERROR: AskUserQuestion: kind decision needs options, one per line, each starting with the word that answers it. Nothing was sent.\n' ; return 0
			}
			## Two options answered by the same word would make the verdict a guess.
			if [ -n "$( printf '%s\n' "$toolOptions" | LC_ALL=C awk '{ sub( /^- /, "" ) ; optionWord = tolower( $1 ) ; if ( optionWord != "" && seenWord[optionWord]++ ) { print optionWord ; exit ; } ; }' )" ] ; then
				printf 'ERROR: AskUserQuestion: kind decision needs each option to start with a different word, and two start with the same one. Nothing was sent.\n' ; return 0
			fi
		;;
		permission)
			[ -n "$toolRefusalId" ] && [ -n "$toolReason" ] && [ -n "$toolTaskRef" ] || {
				printf 'ERROR: AskUserQuestion: kind permission needs refusal_id, reason and task_ref, and one was empty. Nothing was sent.\n' ; return 0
			}
			askSession="$( AgentsHarnessSessionKey )"
			AgentsHarnessBareName "$toolRefusalId" && [ -n "$askSession" ] && askRecord="$MMDAPP/.local/agents/sessions/$askSession/$toolRefusalId.md"
			if [ -z "$askRecord" ] || [ ! -f "$askRecord" ] ; then
				printf 'ERROR: AskUserQuestion: no refusal %s is recorded for this session, so there is nothing to ask permission for. Nothing was sent.\n' "$toolRefusalId" ; return 0
			fi
			## The refused call is shown from the record, never from the asker's words.
			while IFS= read -r askRecordLine ; do
				case "$askRecordLine" in
					'owner: '*) askRefusedOwner="${askRecordLine#owner: }" ;;
					'tool: '*) askRefusedTool="${askRecordLine#tool: }" ;;
					'target: '*) askRefusedTarget="${askRecordLine#target: }" ;;
					'# '*) break ;;
				esac
			done < "$askRecord"
		;;
		*)
			printf 'ERROR: AskUserQuestion: kind must be question, readback, decision or permission, got: %s. Nothing was sent.\n' "$toolKind" ; return 0
		;;
	esac
	if [ -z "$toolAddressTo" ] ; then
		case "$toolTo" in
			*:*) ;;
			*) toolAddressTo="$toolTo" ;;
		esac
	fi
	## Where the question goes (AgentsTools.AskThread.include): an identical open question
	## to the same addressee is not asked again, and one open thread to a person carries
	## every later question to them, each tagged Q<n> so an answer names which it answers.
	askTag="Q1"
	askKey="$( printf '%s' "$toolQuestion" | LC_ALL=C tr -s ' \t\n' '   ' | LC_ALL=C sed 's/^ //;s/ $//' | cksum )"
	askKey="${askKey// /-}"
	type AgentsToolsAskThreadFind > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.AskThread.include" 2> /dev/null || :
	type AgentsToolsLocalLockTake > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.LocalLock.include" 2> /dev/null || :
	if [ -n "$toolAddressTo" ] && type AgentsToolsAskThreadFind > /dev/null 2>&1 ; then
		## Finding, posting and recording are one step per addressee, so two askers at once
		## never count the same thread and post under the same tag. Given back on every way
		## out below, up to the record being written.
		if type AgentsToolsLocalLockTake > /dev/null 2>&1 && AgentsToolsLocalLockTake "ask-thread-$( printf '%s' "$toolAddressTo" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' )" 60 "the question thread to $toolAddressTo" ; then
			askLock="$agentsLocalLockPath"
		else
			printf 'WARNING: AskUserQuestion: the question-thread lock for %s could not be taken, so this question opens a thread of its own rather than risk sharing a tag.\n' "$toolAddressTo" >&2
		fi
		askWhere="$( AgentsToolsAskThreadFind "$toolTo" "$toolAddressTo" "$askKey" )"
		[ -n "$askLock" ] || case "$askWhere" in REUSE$'\t'*) askWhere="NEW"$'\t'"Q1" ;; esac
	fi
	case "$askWhere" in
		DUPLICATE$'\t'*)
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			IFS=$'\t' read -r _ askDupId askDupOwner askDupSession <<< "$askWhere"
			## Asking again is not how an answer is found: its thread is read first, and an
			## answer already there closes the record and is returned, with nothing posted.
			local askDupCollected=""
			askDupCollected="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-pending-reply-collect \
				--id "$askDupId" --context AskUserQuestion 2>/dev/null | LC_ALL=C grep '^ANSWERED ' )" || askDupCollected=""
			if [ -n "$askDupCollected" ] ; then
				printf 'ASK-RESULT: RECEIVED\nThe same question to %s was already asked as pending reply %s, and its thread already holds the answer, so nothing was posted and the record is now closed. What the tooling collected, as `ANSWERED <id> <tag> | <question> | <answer>`:\n%s\n' "$toolAddressTo" "$askDupId" "$askDupCollected"
				return 0
			fi
			printf 'ASK-RESULT: ALREADY-OPEN\nThe same question to %s is already open as pending reply %s, asked by %s%s, so it was not posted again.\n' "$toolAddressTo" "$askDupId" "${askDupOwner:-an unknown member}" "${askDupSession:+ in session $askDupSession}"
			[ -z "$askDupSession" ] || [ "$askDupSession" != "$( AgentsHarnessSessionKey )" ] || printf 'AskUserQuestion pending_id=%s\n' "$askDupId"
			return 0
		;;
		REUSE$'\t'*)
			IFS=$'\t' read -r _ askReuseChannel askReuseThread askTag <<< "$askWhere"
		;;
	esac
	## The number is the person's, not the thread's: one counter per addressee, taken while
	## the ask-thread lock is held, so the same person never sees two questions called Q1.
	if [ -n "$toolAddressTo" ] && type AgentsToolsAskThreadNextTag > /dev/null 2>&1 ; then
		askTag="$( AgentsToolsAskThreadNextTag "$toolAddressTo" )"
	fi
	askBody="$(
		case "$toolKind" in
			(readback) printf '# 🔁 Readback %s\n\n%s\n\n' "$askTag" "$toolQuestion" ;;
			(decision) printf '# 🧭 Decision %s\n\n%s\n\n' "$askTag" "$toolQuestion" ;;
			(permission) printf '# 🔐 Permission %s\n\n%s\n\n' "$askTag" "$toolQuestion" ;;
			(*) printf '# ❓ Question %s\n\n%s\n\n' "$askTag" "$toolQuestion" ;;
		esac
		AgentsHarnessFormalField '**📥 What I understood**' "$toolUnderstood"
		AgentsHarnessFormalField '**📎 Where it came from**' "$toolFrom"
		AgentsHarnessFormalField '**▶️ What I will do if confirmed**' "$toolWillDo"
		if [ "$toolKind" = "permission" ] ; then
			printf '**🚫 Refused call**\n- tool: %s\n- target: %s\n- refused for: %s\n- refusal: %s\n\n' "$askRefusedTool" "$askRefusedTarget" "$askRefusedOwner" "$toolRefusalId"
		fi
		AgentsHarnessFormalField '**❔ Why this task needs it**' "$toolReason"
		AgentsHarnessFormalField '**🗂 Task**' "$toolTaskRef"
		if [ -n "$toolOptions" ] ; then
			printf '**📋 Options**\n'
			printf '%s\n' "$toolOptions" | while IFS= read -r bodyOption ; do
				[ -n "$bodyOption" ] || continue
				## Parenthesised patterns keep bash 3.2 from closing this substitution early.
				case "$bodyOption" in
					(-\ *)
						printf '%s\n' "$bodyOption"
					;;
					(*)
						printf -- '- %s\n' "$bodyOption"
					;;
				esac
			done
			printf '\n'
		fi
		AgentsHarnessFormalField '**⚙ Context**' "$toolContext"
		printf '**✅ How to answer**\n'
		case "$toolKind" in
			(readback)
				printf -- '- reply `yes` to confirm, `no` to stop, or `correct` followed by the correction\n'
				printf -- '- or react with :white_check_mark: for yes, :x: for no\n'
			;;
			(decision)
				printf -- '- reply with the first word of the option you choose\n'
			;;
			(permission)
				printf -- '- reply `deny`, `allow-once` for this one call, or `allow-session` for this session\n'
				printf -- '- or react with :x: to deny\n'
			;;
			(*)
				printf -- '- react on this message with any emoji, which is the fastest answer\n'
				printf -- '- or reply in this thread\n'
			;;
		esac
		## A plain reply answers the latest question above it; an earlier one is named by number.
		## Only a question joining a thread has earlier ones there; its first question has none,
		## whatever its number, since numbers are counted per person.
		[ -z "$askReuseThread" ] || printf -- '- to answer an earlier question in this thread instead, start your reply with its number, for example `Q1 yes`\n'
	)"
	if [ -z "$toolAddressTo" ] ; then
		case "$toolTo" in
			*:*)
			;;
			*)
				toolAddressTo="$toolTo"
			;;
		esac
	fi
	if [ -z "$toolAddressTo" ] ; then
		printf 'ERROR: AskUserQuestion: `to` names one message (%s) rather than a party, so address_to is required and was empty. An answer is recognised by who wrote it, so a question addressed to nobody could be answered by anybody. Nothing was sent.\n' "$toolTo" ; return 0
	fi
	askAsk="$toolTo"
	[ -z "$askReuseThread" ] || askAsk="$askReuseChannel:$askReuseThread"
	[ -n "$askReuseThread" ] || case "$toolTo" in
		*:*)
		;;
		*)
			askOpen="$( AgentsHarnessToolSendMessage "$toolTo" "❓ $toolQuestion"$'\n\n'"The full question and how to answer it are in this thread." "$toolAsBot" "$toolAddressTo" )"
			case "$askOpen" in
				ERROR:*)
					[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
					printf 'ERROR: AskUserQuestion: the thread this question needed could not be opened, so the question was never posted and nobody was asked. THE QUESTION DOES NOT EXIST. The opener repeats the question, so a refusal naming an output-style predicate means the question sits below the plain-language floor this team holds, which is written out in %s/magic-team/magic-team.shared.md -- rewrite the question to that standard and ask it again. What the send reported follows:\n%s\n' "${MDAT_SKILLSET_ROOT:-}" "$askOpen"
					return 0
				;;
			esac
			askOpenTs="$( printf '%s\n' "$askOpen" | LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' | head -1 )"
			if [ -z "$askOpenTs" ] ; then
				[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
				printf 'ERROR: AskUserQuestion: the opener was posted to %s and the send could not name its ts, so there is no thread to put the question in and the question was NOT posted. Nobody was asked. What the send reported follows:\n%s\n' "$toolTo" "$askOpen"
				return 0
			fi
			askAsk="$toolTo:$askOpenTs"
		;;
	esac
	## A question joining a thread already running is also shown in the conversation, or it
	## sits buried under earlier replies where the person never sees it.
	askSent="$( AgentsHarnessToolSendMessage "$askAsk" "$askBody" "$toolAsBot" "$toolAddressTo" "${askReuseThread:+true}" )"
	case "$askSent" in
		ERROR:*)
			[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
			printf 'ERROR: AskUserQuestion: the question could NOT be posted, so nobody was asked and no answer is pending anywhere. THE QUESTION DOES NOT EXIST: this is not a question that went unanswered, and it will not be answered later. A refusal naming an output-style predicate means the text sits below the plain-language floor this team holds, which is written out in %s/magic-team/magic-team.shared.md -- rewrite the question to that standard and ask it again. What the send reported follows:\n%s\n' "${MDAT_SKILLSET_ROOT:-}" "$askSent"
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
	## The account this question was posted under never answers it, whatever address_to said.
	askSelfIds=" $( for askSendOut in "$askOpen" "$askSent" ; do printf '%s\n' "$askSendOut" | LC_ALL=C grep '^{' | LC_ALL=C awk -v path=message.user -v optional=1 -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsSlackJsonField.awk" 2>/dev/null ; done | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"
	askPendingId="$( AgentsHarnessPendingReplyOpen "$toolTo" "$askBody" "$toolKind" "$toolAddressTo" "$askChannel" "$askTs" "$askThreadTs" "$askAddressees" "$askSelfIds" "$toolRefusalId" "$toolOptions" "$askTag" "$askKey" )"
	[ -z "$askLock" ] || AgentsToolsLocalLockGive "$askLock"
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
			return 0
		;;
	esac
	if [ -z "$toolSource" ] ; then
		if [ -z "$askChannel" ] || [ -z "$askThreadTs" ] || [ -z "$askTs" ] ; then
			printf 'ASK-RESULT: POSTED\nThe question is posted to %s%s and NO WAIT WAS PERFORMED. The send could not name the thread it landed in, so there is no one thread to watch. Widening to the whole conversation is refused here: anything found there would not be known to answer this. Nothing is known about whether it was answered. What the send reported follows:\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId}" "$askSent"
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
			return 0
		fi
		[ -n "$askRecordOnly" ] || toolSource="slack:$askChannel:$askThreadTs"
	fi
	if AgentsHarnessWholeNumber "$toolTimeout" && [ "$toolTimeout" -lt 1 ] ; then
		toolTimeout="$harnessWaitTimeout"
	fi
	## An escalation answered through the team operation is seen between rounds, so its rounds stay short.
	if [ "$toolKind" != "question" ] && { ! AgentsHarnessWholeNumber "$toolTimeout" || [ "$toolTimeout" -gt 60 ] ; } ; then
		toolTimeout=60
	fi
	local askNeverRead="" askAnsweredElsewhere=""
	while : ; do
		askRounds=$(( askRounds + 1 ))
		askWaitOut="$( AgentsHarnessToolWait "$toolSource" "$toolTimeout" "" "$askTs" "$askAddressees" )"
		case "${askWaitOut%%$'\n'*}" in
			*TIMEOUT*)
				## A round that never read the thread is not a quiet thread, so it ends the wait.
				askNeverRead="${askWaitOut#*$'\n'WAIT-NEVER-READ: }"
				if [ "$askNeverRead" != "$askWaitOut" ] ; then
					askNeverRead="${askNeverRead%%$'\n'*}"
					case "$askNeverRead" in
						*"[$toolSource]"*) break ;;
					esac
				fi
				askNeverRead=""
				if [ "$toolKind" != "question" ] ; then
					case "$( AgentsHarnessEscalationRead "$askPendingId" )" in
						*"ESCALATION: $askPendingId answered"*) askAnsweredElsewhere=1 ; break ;;
					esac
				fi
			;;
			*RECEIVED*)
				## Any filtered arrival ends the wait: a reply that classifies nothing goes back to
				## the agent as UNCLASSIFIED with the record open, and the agent may re-wait on it.
				break
			;;
			*)
				break
			;;
		esac
	done
	if [ -n "$askNeverRead" ] ; then
		printf 'ERROR: AskUserQuestion: the question WAS posted to %s%s, and then its thread could not be read at all, so NOTHING is known about whether it was answered. Its silence must not be read as quiet. What the wait reported follows:\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId, still open}" "$askWaitOut"
		return 0
	fi
	case "$askWaitOut" in
		ERROR:*)
			printf 'ERROR: AskUserQuestion: the question WAS posted to %s%s, and then the wait for an answer could not be performed -- so the question stands and NOTHING is known about whether it was answered. Its silence must not be read as quiet. What the wait reported follows:\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId, still open}" "$askWaitOut"
			return 0
		;;
	esac
	## The outcome is read off the wait operation's own first line, which carries
	## RECEIVED, TIMEOUT or ERROR. An answer in any other shape is stated as unclassified
	## rather than folded into one of the three, since each of them directs a different
	## next step and guessing between them is the failure this line exists to prevent.
	askFirst="${askWaitOut%%$'\n'*}"
	case "$askFirst" in
		*RECEIVED*) askOutcome="RECEIVED" ;;
		*TIMEOUT*)  askOutcome="TIMEOUT" ;;
		*ERROR*)    askOutcome="ERROR" ;;
		*)          askOutcome="UNCLASSIFIED" ;;
	esac
	[ -z "$askAnsweredElsewhere" ] || askOutcome="RECEIVED"
	## Two of the four close the record and two deliberately leave it open. A received
	## answer is done with; a timeout is a question still standing, so it closes as
	## timed-out and stays in the store for the re-ask. An ERROR or an UNCLASSIFIED
	## wait means nothing whatever is known about whether anybody answered, and
	## recording either as unanswered would assert exactly what was not learned.
	## A typed kind's verdict is read and applied by the escalation operation, the one place that does it.
	local askVerdict="" askReadLines="" askReason=""
	if [ "$toolKind" != "question" ] && [ "$askOutcome" = "RECEIVED" ] ; then
		askReadLines="$( AgentsHarnessEscalationRead "$askPendingId" )"
		askVerdict="$( printf '%s\n' "$askReadLines" | LC_ALL=C sed -n 's/^VERDICT: //p' | head -1 )"
		askReason="$( printf '%s\n' "$askReadLines" | LC_ALL=C sed -n 's/^VERDICT-REASON: //p' | head -1 )"
		[ -n "$askVerdict" ] || askVerdict="UNCLASSIFIED"
	fi
	## In a thread several questions share, a reply with no number that came after the latest
	## question above it was already answered answers none of them: it goes back
	## unclassified, with the record open, as a typed kind's would.
	if [ "$toolKind" = "question" ] && [ "$askOutcome" = "RECEIVED" ] \
		&& printf '%s\n' "$askWaitOut" | LC_ALL=C grep -q '^UNMATCHED-REPLY ' \
		&& ! printf '%s\n' "$askWaitOut" | LC_ALL=C grep -q -E '^([0-9]+\.[0-9]+ \| |reaction on the question: )' ; then
		askVerdict="UNCLASSIFIED"
		askReason="a reply with no question number came after the latest question above it was already answered, so it answers none -- a reply to this question starts with the plain text ${askTag:-its number}"
	fi
	case "$askOutcome:$toolKind:$askVerdict" in
		RECEIVED:question:)
			## The reply taken as the answer, so the close can mark it :eyes:.
			AgentsHarnessPendingReplyClose "$askPendingId" reply-received "" \
				"$( printf '%s\n' "$askWaitOut" | LC_ALL=C sed -n -E 's/^([0-9]+\.[0-9]+) \| .*/\1/p' | head -1 )"
		;;
		TIMEOUT:*)  AgentsHarnessPendingReplyClose "$askPendingId" reply-timeout ;;
	esac
	printf 'ASK-RESULT: %s\n' "$askOutcome"
	[ -z "$askVerdict" ] || printf 'VERDICT: %s\n' "$askVerdict"
	[ -z "$askReadLines" ] || printf '%s\n' "$askReadLines" | LC_ALL=C grep -E '^(VERDICT-TEXT|ANSWERED-BY|GRANT): ' || :
	[ -z "$askWaitNote" ] || printf '%s\n' "$askWaitNote"
	if [ "$askVerdict" = "UNCLASSIFIED" ] ; then
		printf 'VERDICT-REASON: %s\n' "${askReason:-the reply names none of the answers this kind takes}"
		printf 'No verdict is taken, and record %s stays open. You may post more in the same thread, then wait again with the call on the last line; it posts nothing.\n' "${askPendingId:-<none>}"
	fi
	printf 'The question was posted to %s%s, and its own thread was watched over %s wait round(s). What the wait returned follows verbatim.\n%s\n' "$toolTo" "${askPendingId:+ and recorded as pending reply $askPendingId}" "$askRounds" "$askWaitOut"
	[ "$askVerdict" != "UNCLASSIFIED" ] || [ -z "$askPendingId" ] || printf 'AskUserQuestion pending_id=%s\n' "$askPendingId"
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
			printf 'ERROR: ListMcpResourcesTool: this run enumerated no MCP server at all, so there is nothing to list. A server is reachable only because this harness was started naming it or, with none named, because this workspace registers it in .local/agents/mcp.servers.json, and nothing here can add one.\n' ; return 0
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
			printf 'ERROR: ReadMcpResourceTool: this run enumerated no MCP server at all, so there is nothing to read from. A server is reachable only because this harness was started naming it or, with none named, because this workspace registers it in .local/agents/mcp.servers.json, and nothing here can add one.\n' ; return 0
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
			printf 'ERROR: ReadMcpResourceDirTool: this run enumerated no MCP server at all, so there is nothing to read from. A server is reachable only because this harness was started naming it or, with none named, because this workspace registers it in .local/agents/mcp.servers.json, and nothing here can add one.\n' ; return 0
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

## Holds no catalogue: the floor is rendered by the mirror on every call, so both wires
## search one literal, and the MCP entries are this round's $harnessMcpToolsJson,
## each already carrying its separating comma.
AgentsHarnessToolToolSearch(){ ## query, max_results
	local toolQuery="$1" toolMax="$2" searchFloor="" searchRc=0
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
	searchFloor="$( bash "$harnessHere/AgentsHarnessMcpMirror.sh" )" || searchRc=$?
	case "$searchRc:$searchFloor" in
		'0:['*']') ;;
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

## Reaches the skillset directly and DELIBERATELY NOT through AgentsHarnessPathAllowed.
## A member folder under the skillset root is a SYMLINK into whatever source tree owns
## it, so resolving a candidate with `cd ... && pwd -P` and prefix-matching it against
## the resolved root refuses every real member file -- the containment check would be
## correct and the tool would be useless. Containment is held lexically instead, decided
## before any resolution: a relative name carrying no `..` segment, no leading slash and
## nothing outside the gated character set cannot name anything the join does not place
## under the root, whatever that root later resolves to.
AgentsHarnessToolSkill(){ ## name, file, list, offset, limit, skill, args
	local toolName="$1" toolFile="$2" toolList="$3" toolOffset="$4" toolLimit="$5" toolSkill="$6" toolArgs="$7"
	local skillDir skillPath skillRest skillSeg skillBytes skillPrefix skillLeaf skillSought pluginRoot skillPluginData
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
			skillDir="$( AgentsHarnessSkillLocate "$skillLeaf" "${MDAT_SKILLSET_ROOT:-$HOME/.claude/skills}/$skillLeaf/SKILL.md" "$HOME/.claude/skills/$skillLeaf/SKILL.md" "${MDAT_SKILLSET_ROOT:-$HOME/.claude/skills}"/*/SKILL.md "$HOME"/.claude/skills/*/SKILL.md )"
			skillPath="$skillDir/SKILL.md"
			skillSought="a skill folder or a SKILL.md frontmatter name $skillLeaf under ${MDAT_SKILLSET_ROOT:-$HOME/.claude/skills} and $HOME/.claude/skills"
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
	## $HOME/.claude/skills is where every member is linked, whichever skillset this
	## process resolved: a workspace-scoped one carries only some of them.
	skillDir="${MDAT_SKILLSET_ROOT:-$HOME/.claude/skills}/$toolName"
	[ -d "$skillDir" ] || skillDir="$HOME/.claude/skills/$toolName"
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

## A tool_call's own `function.arguments` is itself a JSON document, so the same field
## reader runs again on it rather than a second parser being written.
AgentsHarnessArgValue(){
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## The same value byte for byte, into harnessArgExact: a command substitution drops every
## trailing newline, so content ending in one would be written without it.
harnessArgExact=""
harnessArgOld=""
AgentsHarnessArgExact(){ ## raw arguments, key, alias key read only when the key is absent
	## Absent, not empty: an empty new_string is a real value, and the key still wins over its alias.
	[ -z "$3" ] || printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" >/dev/null 2>&1 || set -- "$1" "$3"
	harnessArgExact="$( AgentsHarnessArgValue "$1" "$2" ; printf 'x' )"
	harnessArgExact="${harnessArgExact%x}"
	harnessArgExact="${harnessArgExact%$'\n'}"
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
	case "$announceFuncName" in
		Read)
			announceIcon="📖"
			announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" file_path )"
			[ -n "$announcePath" ] || announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" path )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Write)
			announceIcon="📝"
			announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" file_path )"
			[ -n "$announcePath" ] || announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" path )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Glob)
			announceIcon="📁"
			## Path on its own line: a pattern and a long path on one line push each
			## other off the terminal, and the path is the half that identifies the
			## call. Two spaces past the tool line, not aligned to the detail column --
			## a wide gutter on a continuation reads as a second column that is not there.
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" pattern )" )$harnessOff"
			## Only when there is one: the announce prints before the call validates its
			## arguments, so a missing path would otherwise render a second line holding
			## an indent, the word `in`, and nothing.
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Edit)
			announceIcon="✏️"
			announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" file_path )"
			[ -n "$announcePath" ] || announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" path )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		Grep)
			announceIcon="🔍"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" pattern )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Bash)
			announceIcon="💻"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" cwd )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" command )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim in$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		WebSearch)
			announceIcon="🔎"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" query )" )$harnessOff"
		;;
		WebFetch)
			announceIcon="🌐"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" url )" )$harnessOff"
		;;
		SendMessage)
			announceIcon="✉️"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" to )" )$harnessOff"
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
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" to )" )$harnessOff"
		;;
		ReportFindings)
			announceIcon="📊"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" subject )" )$harnessOff"
		;;
		PushNotification)
			announceIcon="📣"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" headline )" )$harnessOff"
		;;
		Artifact)
			announceIcon="🔗"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" url )" )$harnessOff"
		;;
		## The question, then the conversation on its own line: a question and a target
		## on one line push each other off the terminal, and this call may hold the run
		## for minutes, so what it is waiting on has to be visible.
		AskUserQuestion)
			announceIcon="❔"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" to )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" question )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim to$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		## server is optional here, so a bare call states what it will actually do rather
		## than announcing an empty detail that reads as a stall.
		ListMcpResourcesTool)
			announceIcon="🗂️"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" server )" )"
			announceDetail="$harnessDim every MCP server this run enumerated$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$harnessValue$announcePath$harnessOff"
		;;
		ReadMcpResourceTool)
			announceIcon="📄"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" server )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" uri )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim on$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		ReadMcpResourceDirTool)
			announceIcon="🗃️"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" server )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" uri_prefix )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim on$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		Skill)
			announceIcon="📚"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" file )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" name )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim file$harnessOff $harnessValue$announcePath$harnessOff"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" skill )" )"
			[ -z "$announcePath" ] || announceDetail="$harnessValue$announcePath$harnessOff"
		;;
		## The member being spawned, then the brief on its own line: this call starts a
		## session that outlives the turn, so who it starts has to be visible at a glance.
		Agent)
			announceIcon="🚀"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" prompt )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" agent )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim brief$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		TaskStop)
			announceIcon="🛑"
			announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" task_id )"
			[ -n "$announcePath" ] || announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" shell_id )"
			[ -n "$announcePath" ] || announcePath="$( AgentsHarnessArgValue "$announceArgsRaw" handle )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announcePath" )$harnessOff"
		;;
		TaskOutput)
			announceIcon="📜"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" handle )" )$harnessOff"
		;;
		ToolSearch)
			announceIcon="🧰"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" query )" )$harnessOff"
		;;
		## A start and a read are the same tool, and which one this call is decides which
		## field identifies it, so both are shown rather than one that may be empty.
		Monitor)
			announceIcon="📡"
			announcePath="$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" handle )" )"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" command )" )$harnessOff"
			[ -z "$announcePath" ] || announceDetail="$announceDetail"$'\n'"     $harnessDim handle$harnessOff $harnessValue$announcePath$harnessOff"
		;;
		## Last, after every static arm: an mcp__ prefix must never displace a built-in.
		## The whole argument object is shown, since only the server knows its own shape.
		mcp__*)
			announceIcon="🔌"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$announceArgsRaw" )$harnessOff"
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
		Write|Edit|Bash|SendMessage|AskUserQuestion|Agent|mcp__*__execute|mcp__*__Write|mcp__*__Edit|mcp__*__SendMessage|mcp__*__AskUserQuestion|mcp__*__Agent) ;;
		*) return 0 ;;
	esac
	printf 'ERROR: read your duty file first: Skill name=%s file=%s.armed.md -- then retry this call. Nothing was done.\n' "$harnessAgent" "$harnessAgent"
}
AgentsHarnessArmNote(){ ## tool name, arguments JSON, result -- records the arming read
	[ -z "$harnessArmedAt" ] && [ "$1" = "Skill" ] && [ -n "$harnessAgent" ] || return 0
	[ "$( AgentsHarnessArgValue "$2" name )" = "$harnessAgent" ] && [ "$( AgentsHarnessArgValue "$2" file )" = "$harnessAgent.armed.md" ] || return 0
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
	## Text a tool writes is taken byte for byte, ahead of the arms that keep their own spelling.
	case "$harnessFuncName" in
		Write) AgentsHarnessArgExact "$harnessFuncArgsRaw" content ;;
		Edit) AgentsHarnessArgExact "$harnessFuncArgsRaw" old_string old_text ; harnessArgOld="$harnessArgExact" ; AgentsHarnessArgExact "$harnessFuncArgsRaw" new_string new_text ;;
	esac
	case "$harnessFuncName" in
		Read)      harnessResult="$( AgentsHarnessToolRead "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pages )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" file_path )" )" ;;
		Write)     harnessResult="$( AgentsHarnessToolWrite "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$harnessArgExact" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" file_path )" "$harnessFuncArgsRaw" )" ;;
		Glob)      harnessResult="$( AgentsHarnessToolGlob "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" long )" )" ;;
		Edit)      harnessResult="$( AgentsHarnessToolEdit "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$harnessArgOld" "$harnessArgExact" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" replace_all )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" file_path )" "$harnessFuncArgsRaw" )" ;;
		Grep)      harnessResult="$( AgentsHarnessToolGrep "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" context )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" before )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" after )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" ignore_case )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" output_mode )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" glob )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -n )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -o )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -A )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -B )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -C )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" -i )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" head_limit )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" multiline )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" type )" )" ;;
		Bash)      harnessResult="$( AgentsHarnessToolBash "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" cwd )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" command )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" timeout )" )" ;;
		WebSearch) harnessResult="$( AgentsHarnessToolWebSearch "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" query )" "$harnessFuncArgsRaw" )" ;;
		WebFetch)  harnessResult="$( AgentsHarnessToolWebFetch "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" url )" )" ;;
		SendMessage) harnessResult="$( AgentsHarnessToolSendMessage "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" message )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
		ListAgents) harnessResult="$( AgentsHarnessToolListAgents "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" view )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" session_id )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" state )" )" ;;
		Wait)      harnessResult="$( AgentsHarnessToolWait "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" sources )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" timeout )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" poll_interval )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" since_utime )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" addressee )" )" ;;
		SubagentHandback) harnessResult="$( AgentsHarnessToolSubagentHandback "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" task )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" outcome )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" findings )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" unfinished )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
		ReportFindings) harnessResult="$( AgentsHarnessToolReportFindings "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" subject )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" findings )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" evidence )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" confidence )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
		PushNotification) harnessResult="$( AgentsHarnessToolPushNotification "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" severity )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" headline )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" detail )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" action_required )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
		Artifact)  harnessResult="$( AgentsHarnessToolArtifact "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" url )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" title )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" kind )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" summary )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
		AskUserQuestion) harnessResult="$( AgentsHarnessToolAskUserQuestion "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" question )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" options )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" context )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" wait )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" timeout )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" wait_source )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" address_to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" kind )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" understood )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" source )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" will_do )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" refusal_id )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" reason )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" task_ref )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pending_id )" )" ;;
		ListMcpResourcesTool) harnessResult="$( AgentsHarnessToolListMcpResourcesTool "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" server )" )" ;;
		ReadMcpResourceTool) harnessResult="$( AgentsHarnessToolReadMcpResourceTool "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" server )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" uri )" )" ;;
		ReadMcpResourceDirTool) harnessResult="$( AgentsHarnessToolReadMcpResourceDirTool "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" server )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" uri_prefix )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" )" ;;
		Skill)     harnessResult="$( AgentsHarnessToolSkill "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" name )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" file )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" list )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" skill )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" args )" )" ;;
		Agent)     harnessResult="$( AgentsHarnessToolAgent "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" agent )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" prompt )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" cli_service )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" session_name_or_comment )" )" ;;
		TaskStop)  harnessResult="$( AgentsHarnessToolTaskStop "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" handle )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" force )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" task_id )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" shell_id )" )" ;;
		TaskOutput) harnessResult="$( AgentsHarnessToolTaskOutput "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" handle )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" output_file )" )" ;;
		ToolSearch) harnessResult="$( AgentsHarnessToolToolSearch "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" query )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" max_results )" )" ;;
		Monitor)   harnessResult="$( AgentsHarnessToolMonitor "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" command )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" cwd )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" handle )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" )" ;;
		## Last, after every static arm: an mcp__ prefix must never displace a built-in.
		mcp__*)    harnessResult="$( AgentsHarnessMcpCall "$harnessFuncName" "$harnessFuncArgsRaw" )" ;;
		*)         harnessResult="ERROR: unknown tool: $harnessFuncName" ;;
	esac
}

## Sourced, not exec'd: its functions run in this process and share everything above.
harnessWireFile="$harnessHere/Agents${harnessWire}Wire.sh"
if [ ! -f "$harnessWireFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE=$harnessWire names no adapter in this package: $harnessWireFile" >&2
	exit 1
fi
. "$harnessWireFile"
## The declarations a hosted model is given state the cap this process applies.
[ -z "${harnessToolsJson:-}" ] || harnessToolsJson="$( printf '%s\n' "$harnessToolsJson" | AgentsReadCapFill "$harnessReadCap" )"

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

## Exchanges only where one is declared, and only where the bearer is absent or its margin
## is spent -- which is why the header below reads one variable in both cases.
AgentsHarnessRefreshBearer(){
	[ -n "$harnessTokenExchange" ] || return 0
	local exchangeNow="$( date +%s )"
	[ -z "$harnessBearer" ] || [ "$exchangeNow" -ge "$harnessBearerGoodUntil" ] || return 0
	local exchangeOut="$( printf '%s' "$harnessToken" | AgentsExchangeBearer )"
	harnessBearer="${exchangeOut%% *}"
	if [ -z "$harnessBearer" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: Agents${harnessTokenExchange}Exchange.sh returned no bearer for the credential named in $harnessCredentialNames -- this leg cannot authenticate" >&2
		exit 1
	fi
	## Two fields or none: a single field is the bearer, and its expiry is then unknown.
	local exchangeExpiry=0
	case "$exchangeOut" in *' '*) exchangeExpiry="${exchangeOut#* }" ;; esac
	AgentsHarnessWholeNumber "$exchangeExpiry" || exchangeExpiry=0
	## Both numbers below are chosen policy values and not derived ones -- nothing here
	## bounds a single stream, that curl carrying no --max-time -- so tuning either is a
	## policy decision rather than a correction.
	[ "$exchangeExpiry" != 0 ] || exchangeExpiry=$(( exchangeNow + 1800 ))
	harnessBearerGoodUntil=$(( exchangeExpiry - 300 ))
	## A lifetime shorter than the margin cannot be margined, and absorbing that silently
	## re-exchanges on every attempt for the rest of the run.
	if [ "$harnessBearerGoodUntil" -le "$exchangeNow" ] ; then
		echo "${harnessWarn}⚠️  bearer lifetime is under the 300s margin${harnessOff} ${harnessDim}-- Agents${harnessTokenExchange}Exchange.sh returned an expiry $(( exchangeExpiry - exchangeNow ))s away; using it unmargined, which is a mis-parsed TTL or a very short-lived token${harnessOff}" >&2
		harnessBearerGoodUntil="$exchangeExpiry"
	fi
	printf '%s\n' "${harnessDim}🔑 bearer exchanged via Agents${harnessTokenExchange}Exchange.sh -- $(( harnessBearerGoodUntil - exchangeNow ))s until the next exchange${harnessOff}" >&2
}

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
## the workspace's own cooked mcp.servers.json, minus this package's own server: our
## registered key and our serverInfo.name are both the literal myx.distro, and
## enumerating ourselves is how a walk descends into a copy of itself. Self-exclusion
## terminates only if every participant excludes itself, so the marker below travels
## to every child as well -- a copy of us reached through a foreign server sees it and
## declines. Named after the caller has parsed argv, and before the client is sourced,
## because that file enumerates as it loads. A model run that named no --mcp-server
## takes the same set, the empty name being that run: this harness is the myx.distro
## destination for it too. No mcp.servers.json means no set, and nothing is printed.
## A set named on argv is the run's own and stays. With none named, the set is read
## from mcp.servers.json again on every enumeration -- the client enumerates on load
## and again before every round -- so a server registered or removed there reaches the
## next round rather than the next run.
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
			if [ -f "${MMDAPP:-}/.local/agents/mcp.servers.json" ] ; then
				while IFS= read -r harnessToolPeer ; do
					[ -n "$harnessToolPeer" ] || continue
					[ "myx.distro" != "$harnessToolPeer" ] || continue
					harnessMcpServers+=( "$harnessToolPeer" )
				done <<< "$( LC_ALL=C awk -v path=mcpServers -v mode=keys -f "$harnessHere/AgentsHarnessJsonSlice.awk" < "$MMDAPP/.local/agents/mcp.servers.json" 2>/dev/null )"
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
. "$harnessMcpFile"
## The local lock primitive Write and Edit take; absent, every write is refused as unlockable.
[ ! -f "$harnessHere/AgentsTools.LocalLock.include" ] || . "$harnessHere/AgentsTools.LocalLock.include"

## --intern-tool ends here: the tools, the hooks and the MCP client are all in scope by
## now, and everything below this point is the model path. The argument object arrives
## on stdin as the same raw JSON a tool_call carries, so a served call and a model call
## read their arguments through one reader. stdout carries the result and nothing else.
if [ -n "$harnessToolOnly" ] ; then
	harnessToolOnlyArgs="$( cat )"
	[ -n "$harnessToolOnlyArgs" ] || harnessToolOnlyArgs="{}"
	AgentsHarnessAnnounceTool "$harnessToolOnlyName" "$harnessToolOnlyArgs"
	## Every hook gets its say here exactly as it does in the loop: a surface that skips
	## them is a way around them.
	harnessResult="$( AgentsHarnessHooksRefusal "$harnessToolOnlyName" "$harnessToolOnlyArgs" )"
	[ -n "$harnessResult" ] || AgentsHarnessRunTool "$harnessToolOnlyName" "$harnessToolOnlyArgs"
	## Served path tools also hand the server a request line and a one-line result summary, as a separate content part; stdout stays the plain result.
	case "$harnessHeadFile:$harnessToolOnlyName" in
		:*) ;;
		*:Read|*:Write|*:Edit|*:Glob|*:Grep)
			case "$harnessResult" in
				ERROR:*|OK:*) harnessHeadSummary="$( AgentsHarnessTruncateArg "${harnessResult%%$'\n'*}" )" ;;
				*) harnessHeadSummary="$( printf '%s' "$harnessResult" | LC_ALL=C awk '{ b += length($0) + 1 ; } END { printf "%d lines, %d bytes", NR, ( NR ? b - 1 : 0 ) ; }' )" ;;
			esac
			( harnessTool='' harnessValue='' harnessDim='' harnessOff='' harnessTitleActive='' ; AgentsHarnessAnnounceTool "$harnessToolOnlyName" "$harnessToolOnlyArgs" 2>&1 >/dev/null ; printf '      result %s\n' "$harnessHeadSummary" ) > "$harnessHeadFile" || :
		;;
	esac
	printf '%s\n' "$harnessResult"
	## A refused or unknown tool leaves a caller's status check dead otherwise.
	case "$harnessResult" in
		ERROR:*)
			printf '%s\n' "   ${harnessBad}🚫 refused:${harnessOff} ${harnessDim}$( AgentsHarnessTruncateArg "$harnessResult" )${harnessOff}" >&2
			exit 1
		;;
	esac
	harnessExitClean=1 ; exit 0
fi

## A spawned session run by this loop is one whose arming can be observed: said beside its record.
[ -z "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] || [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || : > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.harness" 2>/dev/null || :

## Said only when the two sets differ, so an ungranted run reads exactly as it did.
harnessWriteNote=""
[ "$harnessWriteRoots" = "$harnessRoots" ] || harnessWriteNote="Writing is narrower than reading. Write and Edit may only write under these roots:
$harnessWriteRoots
Everything else above you may read, list, search and run commands in, but not write to. Do not try to work around that -- report it instead.
"

harnessSystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$harnessRoots
$harnessWriteNote
Use the given tools to accomplish the request, then reply with a final plain-text message once done. Nobody is reading this terminal, so a question written into your own answer reaches no one: where you genuinely need a decision only a person can make, AskUserQuestion is the one way to ask for one. Otherwise make the most reasonable choice and state what you did."

## --agent given: the member's own identity replaces the generic opener entirely.
## Skill below is a tool name in prose, which no structural check can see.
if [ -n "$harnessAgent" ] ; then
	printf -v harnessSystemText '%s\n\n%s\n\n%s' \
		"$harnessAgentBasicText" \
		"Before your first acting call, read your own $harnessAgent.armed.md with the Skill tool, name $harnessAgent and file $harnessAgent.armed.md -- it is not included here. In a spawned session, Write, Edit, Bash, execute, SendMessage, AskUserQuestion and Agent are redirected until you have. Every skillset file is read with Skill, which works even where Read is denied." \
		"You are running through a bespoke $harnessProviderName harness$harnessSystemTail"
else
	harnessSystemText="You are an autonomous coding agent running through a bespoke $harnessProviderName harness$harnessSystemTail"
fi

## A named-but-unavailable MCP server owes the model a sentence: its tools are absent
## from the declarations, and nothing else in the run says why.
harnessSystemBase="$harnessSystemText"
[ -z "$harnessMcpUnavailableNote" ] || printf -v harnessSystemText '%s\n\n%s' "$harnessSystemBase" "$harnessMcpUnavailableNote"
harnessMcpNoteTold="$harnessMcpUnavailableNote"

AgentsWireInitMessages

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

	## The MCP set is enumerated again every round; its report shows when the set or the note changed.
	if [ "$harnessRound" -gt 1 ] ; then
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

	if [ "$harnessStreamOk" != "1" ] && [ ! -s "$harnessScratch/stream.rawother" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: round $harnessRound: gave up after $harnessStreamMaxAttempts stream attempts, none reached a clean [DONE] (see DESIGN DECISION 1: a partial stream is always discarded, never spliced) -- last curl rc=$harnessCurlRc" >&2
		exit 1
	fi

	if [ -s "$harnessScratch/stream.rawother" ] ; then
		harnessResponse="$( cat "$harnessScratch/stream.rawother" )"
	else
		## The adapter synthesizes the exact document shape the downstream code expects.
		AgentsWireSynthesizeResponse
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
		harnessExitClean=1 ; exit 0
	fi

	## The assistant's own tool_calls message goes into history verbatim first -- this
	## API's required shape for a multi-turn tool exchange.
	harnessToolCallsJson=""
	harnessIndex=0
	while [ "$harnessIndex" -lt "$harnessToolCount" ] ; do
		harnessCallId="$( AgentsWireToolCallId "$harnessIndex" )"
		harnessFuncName="$( AgentsWireToolCallName "$harnessIndex" )"
		harnessFuncArgsRaw="$( AgentsWireToolCallArgs "$harnessIndex" )"
		harnessToolCallsJson="${harnessToolCallsJson}${harnessToolCallsJson:+,}$( AgentsWireToolCallEntry "$harnessCallId" "$harnessFuncName" "$harnessFuncArgsRaw" )"
		harnessIndex=$(( harnessIndex + 1 ))
	done
	harnessMessages+=( "$( AgentsWireAssistantToolCallsRecord "$harnessToolCallsJson" )" )

	## Then one result per call, keyed by that exact tool_call_id.
	harnessIndex=0
	while [ "$harnessIndex" -lt "$harnessToolCount" ] ; do
		harnessCallId="$( AgentsWireToolCallId "$harnessIndex" )"
		harnessFuncName="$( AgentsWireToolCallName "$harnessIndex" )"
		harnessFuncArgsRaw="$( AgentsWireToolCallArgs "$harnessIndex" )"

		AgentsHarnessAnnounceTool "$harnessFuncName" "$harnessFuncArgsRaw"

		## Every configured hook gets its say before the call runs, and a refusal becomes
		## the result the model reads, so the tool never executes.
		harnessResult="$( AgentsHarnessHooksRefusal "$harnessFuncName" "$harnessFuncArgsRaw" )"
		[ -n "$harnessResult" ] || harnessResult="$( AgentsHarnessArmGate "$harnessFuncName" )"
		if [ -n "$harnessResult" ] && [ -z "$harnessArmRedirectLogged" ] && [ "${harnessResult#ERROR: read your duty file first}" != "$harnessResult" ] ; then
			harnessArmRedirectLogged=1
			printf '%s\n' "Unarmed call redirected" '```' "member: $harnessAgent" "session-id: $MDAT_SPAWN_SESSION_ID" "tool: $harnessFuncName" "redirect: read $harnessAgent.armed.md with Skill first" '```' \
				| "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-comms-slack-send-message "$harnessAgent" event-track --identity-bot --from-stdin > /dev/null 2>&1 || :
		fi

		[ -n "$harnessResult" ] || AgentsHarnessRunTool "$harnessFuncName" "$harnessFuncArgsRaw"
		AgentsHarnessArmNote "$harnessFuncName" "$harnessFuncArgsRaw" "$harnessResult"

		## The announce line states an intent and reads the same whether the call ran or
		## was refused, so a refusal is marked explicitly for a transcript reader.
		case "$harnessResult" in
			ERROR:*)
				printf '%s\n' "   ${harnessBad}🚫 refused:${harnessOff} ${harnessDim}$( AgentsHarnessTruncateArg "$harnessResult" )${harnessOff}" >&2
			;;
		esac

		harnessMessages+=( "$( AgentsWireToolResultRecord "$harnessCallId" "$harnessResult" )" )
		harnessIndex=$(( harnessIndex + 1 ))
	done
done
