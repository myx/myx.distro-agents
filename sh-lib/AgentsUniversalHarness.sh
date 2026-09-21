#!/usr/bin/env bash
set -e

## AgentsUniversalHarness.sh -- the universal tool-calling harness: all of the
## logic, none of the provider specifics. Never invoked directly: a provider stub
## sets the HARNESS_* variables and execs this file, so the core becomes that
## process. Endpoint-shaped code lives in the wire adapter named by HARNESS_WIRE.
## AgentsHarnessSelfCheck.awk and AgentsHarnessContainmentCheck.sh locate code here
## by exact spellings, so renaming anything is a coordinated change to both.
## DESIGN DECISION 1 -- a mid-stream disconnect discards partial state and retries
## the whole round; there is no resume primitive here. DESIGN DECISION 2 -- such a
## retry never consumes a round against the cap. DESIGN DECISION 3 -- a full context
## is met by summarise-and-restart, bounded, never by eviction. MAGIC.md carries the
## reasoning.

harnessHere="$( cd "$( dirname -- "$0" )" && pwd )"

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

harnessMissing=""
[ -n "$harnessProviderName" ]    || harnessMissing="$harnessMissing HARNESS_PROVIDER_NAME"
[ -n "$harnessEndpoint" ]        || harnessMissing="$harnessMissing HARNESS_ENDPOINT"
[ -n "$harnessHost" ]            || harnessMissing="$harnessMissing HARNESS_HOST"
[ -n "$harnessWire" ]            || harnessMissing="$harnessMissing HARNESS_WIRE"
[ -n "$harnessCredentialNames" ] || harnessMissing="$harnessMissing HARNESS_CREDENTIAL_NAMES"
[ -n "${HARNESS_MODEL_LIGHT:-}" ] || harnessMissing="$harnessMissing HARNESS_MODEL_LIGHT"
[ -n "${HARNESS_MODEL_MAIN:-}" ]  || harnessMissing="$harnessMissing HARNESS_MODEL_MAIN"
if [ -n "$harnessMissing" ] ; then
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

harnessTier="normal"
harnessAccessRoots=()
harnessWriteAccessRoots=()
harnessSessionId=""
harnessAgent=""
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
			## No server is granted by default, so a spawn names each one it wants;
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
harnessPrompt="$*"
if [ -z "$harnessPrompt" ] ; then
	harnessPrompt="$( cat )"
fi
if [ -z "$harnessPrompt" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no prompt given -- pass it as trailing argv, or on stdin" >&2
	exit 1
fi

## The stub decides which model and which key; the core owns only the mapping's shape.
harnessReasoningEffort=""
case "$harnessTier" in
	light)
		harnessModel="$HARNESS_MODEL_LIGHT"
		harnessToken="${HARNESS_TOKEN_LIGHT:-}"
	;;
	normal)
		harnessModel="$HARNESS_MODEL_MAIN"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
	;;
	heavy)
		harnessModel="$HARNESS_MODEL_MAIN"
		harnessReasoningEffort="high"
		harnessToken="${HARNESS_TOKEN_MAIN:-}"
	;;
esac

if [ -z "$harnessToken" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no credential -- $harnessCredentialNames must be set in this process's own environment. This leg reads those names itself, exactly as claude reads ANTHROPIC_API_KEY" >&2
	exit 1
fi

## What this run costs, said once: the tier picked the model, and the model is metered.
printf '%s\n' "🤖 ${harnessDim}$harnessProviderName${harnessOff} ${harnessTool}$harnessModel${harnessOff} ${harnessDim}· $harnessTier tier${harnessOff}" >&2

## Roots are canonicalised by the same rule the candidate is, in one helper used by
## every append site: resolving one side only broke --access-root <symlink>.
AgentsHarnessResolveDir(){
	local resolveIn="$1" resolveOut
	resolveOut="$( cd "$resolveIn" 2>/dev/null && pwd -P )" || resolveOut=""
	[ -n "$resolveOut" ] || resolveOut="$resolveIn"
	printf '%s' "$resolveOut"
}

harnessRoots=""
if [ "${#harnessAccessRoots[@]}" -gt 0 ] ; then
	for harnessRoot in "${harnessAccessRoots[@]}" ; do
		harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessRoot" )"$'\n'
	done
else
	harnessFragment="${MMDAPP:-}/.claude/copilot-add-dir.fragment"
	## Fallback only for a console generated before this leg was passed --access-root; every line shape it ever wrote ends in its own path.
	if [ -f "$harnessFragment" ] ; then
		while IFS= read -r harnessLine ; do
			harnessLine="${harnessLine##*$'\t'}"
			case "$harnessLine" in
				/*) harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessLine" )"$'\n' ;;
			esac
		done < "$harnessFragment"
	fi
fi
if [ -z "$harnessRoots" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-write-root for a root it may both read and write, or --access-read-root for one it may only read, or run this inside a workspace whose .claude/copilot-add-dir.fragment already exists (DistroAgentsTools --make-workspace-integrations)." >&2
	exit 1
fi

## Reads keep the generous set above. Writes narrow to their own where one is given;
## with none, they stay exactly as wide as reads, which is what every console
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

harnessScratch="$( mktemp -d -t "AgentsUniversalHarness-XXXXXXXX" )" || {
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

trap 'trap "" INT TERM ; AgentsHarnessRestoreTerminal ; AgentsHarnessReapChildren ; rm -rf -- "$harnessScratch"' EXIT

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

## Wall-clock bound on Bash. The 900 is the human-owner's chosen value, so a
## later reader tuning it is changing a policy decision, not an implementation guess.
harnessRunTimeout="${MDAT_HARNESS_RUN_TIMEOUT:-900}"
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
## prefix-matched against the resolved roots. A final component that is itself a
## symlink is not resolved, so a symlink inside an allowed root pointing out of it
## is followed by any tool that opens it.
AgentsHarnessPathAllowed(){
	local checkPath="$1" checkRoots="${2:-$harnessRoots}" checkRoot checkReal
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
		checkReal="$( cd "$( dirname -- "$checkPath" )" 2>/dev/null && pwd -P )" || checkReal=""
		if [ -n "$checkReal" ] ; then
			case "$checkReal" in
				*/) checkReal="$checkReal$( basename -- "$checkPath" )" ;;
				*)  checkReal="$checkReal/$( basename -- "$checkPath" )" ;;
			esac
		fi
	fi
	## An unresolvable path is compared as given rather than admitted by default.
	[ -n "$checkReal" ] || checkReal="$checkPath"
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

AgentsHarnessToolRead(){
	local toolPath="$1" toolOffset="$2" toolLimit="$3" toolBytes
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	## Existence is not readability, and the two are refused separately: without this
	## the size test below compares an empty value and emits shell noise, not an answer.
	if [ ! -r "$toolPath" ] ; then
		printf 'ERROR: not readable (permission denied): %s\n' "$toolPath" ; return 0
	fi
	## A line range is the only way past the byte cap below, so it states what it showed.
	if [ -n "$toolOffset" ] || [ -n "$toolLimit" ] ; then
		[ -n "$toolOffset" ] || toolOffset=1
		if ! AgentsHarnessWholeNumber "$toolOffset" || [ "$toolOffset" -lt 1 ] ; then
			printf 'ERROR: offset must be a whole line number counting from 1, got: %s\n' "$toolOffset" ; return 0
		fi
		if [ -n "$toolLimit" ] && { ! AgentsHarnessWholeNumber "$toolLimit" || [ "$toolLimit" -lt 1 ] ; } ; then
			printf 'ERROR: limit must be a whole number of lines, at least 1, got: %s\n' "$toolLimit" ; return 0
		fi
		## Digits by the checks above, so there is nothing here for -v to backslash-decode.
		LC_ALL=C awk -v fromLine="$toolOffset" -v lineLimit="${toolLimit:-0}" -v byteCap=200000 '
			NR >= fromLine && ( lineLimit == 0 || NR < fromLine + lineLimit ) {
				rangeBytes = rangeBytes + length($0) + 1
				if ( rangeBytes <= byteCap ) { print ; shownCount = shownCount + 1 ; shownBytes = rangeBytes ; }
			}
			END {
				if ( rangeBytes > byteCap ) printf "... TRUNCATED: showed %d of %d bytes in the requested range ...\n", shownBytes, rangeBytes
				printf "... read %d line(s) from line %d; the file has %d lines ...\n", shownCount, fromLine, NR
			}
		' "$toolPath"
		return 0
	fi
	## Capped and said so, never silently: an unbounded read risks the request itself.
	toolBytes="$( wc -c < "$toolPath" | tr -d ' ' )"
	if [ "$toolBytes" -gt 200000 ] ; then
		head -c 200000 "$toolPath"
		printf '\n... TRUNCATED at 200000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$toolPath"
	fi
}

## Whole-file overwrite or create, never a partial patch; Edit is the partial path.
AgentsHarnessToolWrite(){
	local toolPath="$1" toolContent="$2" toolTemp
	if ! AgentsHarnessPathAllowed "$toolPath" "$harnessWriteRoots" ; then
		printf 'ERROR: path not in the allowed write-root set -- it may still be readable: %s\n' "$toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	mkdir -p "$( dirname -- "$toolPath" )" 2>/dev/null || {
		printf 'ERROR: could not create the parent directory of: %s\n' "$toolPath" ; return 0
	}
	## In place, never temp+rename: `mv -f` carries the temp's umask mode onto the
	## target and silently widens a file that was deliberately not group-readable.
	if [ -e "$toolPath" ] ; then
		if ! printf '%s' "$toolContent" > "$toolPath" ; then
			printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
		fi
		printf 'OK: wrote %s\n' "$toolPath"
		return 0
	fi
	toolTemp="$toolPath.tmp.$$"
	if ! printf '%s' "$toolContent" > "$toolTemp" ; then
		printf 'ERROR: could not write: %s\n' "$toolPath" ; rm -f "$toolTemp" ; return 0
	fi
	if ! mv -f "$toolTemp" "$toolPath" ; then
		printf 'ERROR: could not install: %s\n' "$toolPath" ; rm -f "$toolTemp" ; return 0
	fi
	printf 'OK: wrote %s\n' "$toolPath"
}

## Partial edit by exact literal replacement. It reads the whole file inside this
## process and returns only a one-line result, so it is the way to change a file too
## long for Read's cap. Uniqueness is required, not preferred: a silent
## first-of-several substitution is unrecoverable, and identical lines are the norm here.
AgentsHarnessToolEdit(){
	local toolPath="$1" toolOld="$2" toolNew="$3" toolAll="$4" toolCount
	if ! AgentsHarnessPathAllowed "$toolPath" "$harnessWriteRoots" ; then
		printf 'ERROR: path not in the allowed write-root set -- it may still be readable: %s\n' "$toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	if [ -z "$toolOld" ] ; then
		printf 'ERROR: old_text is empty -- an empty match has no unique position\n' ; return 0
	fi
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
		printf 'ERROR: old_text not found in %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	## Only an explicit opt-in lifts the uniqueness guard; anything else leaves it standing.
	case "$toolAll" in
		true|1) ;;
		*) toolAll="" ;;
	esac
	if [ -z "$toolAll" ] && [ "$toolCount" != "1" ] ; then
		printf 'ERROR: old_text occurs %s times in %s -- it must identify exactly one place. Nothing was written; extend old_text until it is unique, or pass replace_all to change every occurrence.\n' "$toolCount" "$toolPath" ; return 0
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
		printf 'ERROR: could not rewrite: %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	if ! cat "$harnessScratch/edit.out" > "$toolPath" ; then
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	if [ -n "$toolAll" ] ; then
		printf 'OK: replaced %s occurrence(s) in %s\n' "$toolCount" "$toolPath"
	else
		printf 'OK: replaced one occurrence in %s\n' "$toolPath"
	fi
}

## The root is tested before the pattern is evaluated, so a missing directory is named
## as missing rather than collapsing into "the pattern matched nothing".
AgentsHarnessToolGlob(){
	local toolPattern="$1" toolPath="$2" toolLong="$3" toolBytes
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
	local toolFindMode=""
	[ -z "$toolLong" ] || toolFindMode="-ls"
	if [ -n "$toolPattern" ] ; then
		find -L "$toolPath/" -name "$toolPattern" $toolFindMode > "$harnessScratch/glob.out" 2>&1 || :
	else
		find -L "$toolPath/" -maxdepth 1 $toolFindMode > "$harnessScratch/glob.out" 2>&1 || :
	fi
	## Capped and said so: a truncated list reads as the complete set of matches.
	toolBytes="$( wc -c < "$harnessScratch/glob.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt 100000 ] ; then
		head -c 100000 "$harnessScratch/glob.out"
		printf '\n... TRUNCATED at 100000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$harnessScratch/glob.out"
	fi
}

## `ripgrep` would replace this `grep -rn` outright; the human-owner ruled "Not now".
AgentsHarnessToolGrep(){
	local toolPattern="$1" toolPath="$2" toolContext="$3" toolBefore="$4" toolAfter="$5" toolIgnoreCase="$6" toolMode="$7" toolBytes grepFlags
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if [ ! -e "$toolPath" ] ; then
		printf 'ERROR: no such path: %s\n' "$toolPath" ; return 0
	fi
	## The mode picks the output shape; -C/-B/-A and -i are carried by BSD and GNU grep alike.
	case "$toolMode" in
		''|content)         grepFlags=( -rn ) ;;
		files_with_matches) grepFlags=( -rl ) ;;
		count)              grepFlags=( -rc ) ;;
		*)
			printf 'ERROR: output_mode must be content, files_with_matches or count, got: %s\n' "$toolMode" ; return 0
		;;
	esac
	## A per-side value wins over context, which otherwise sets both sides.
	[ -n "$toolBefore" ] || toolBefore="$toolContext"
	[ -n "$toolAfter" ] || toolAfter="$toolContext"
	if [ -n "$toolBefore" ] && ! AgentsHarnessWholeNumber "$toolBefore" ; then
		printf 'ERROR: before/context must be a whole number of lines, got: %s\n' "$toolBefore" ; return 0
	fi
	if [ -n "$toolAfter" ] && ! AgentsHarnessWholeNumber "$toolAfter" ; then
		printf 'ERROR: after/context must be a whole number of lines, got: %s\n' "$toolAfter" ; return 0
	fi
	[ -z "$toolBefore" ] || grepFlags+=( -B "$toolBefore" )
	[ -z "$toolAfter" ] || grepFlags+=( -A "$toolAfter" )
	case "$toolIgnoreCase" in
		true|1) grepFlags+=( -i ) ;;
	esac
	## `|| :` keeps grep's own rc 1 on no-match from tripping this script's set -e.
	grep "${grepFlags[@]}" -- "$toolPattern" "$toolPath" > "$harnessScratch/grep.out" 2>&1 || :
	## Capped and said so: a truncated search reads as "there are no further matches".
	toolBytes="$( wc -c < "$harnessScratch/grep.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt 100000 ] ; then
		head -c 100000 "$harnessScratch/grep.out"
		printf '\n... TRUNCATED at 100000 of %s bytes ...\n' "$toolBytes"
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

## Refuses by construction: nothing here configures a search provider, and guessing one would be worse than refusing.
AgentsHarnessToolWebSearch(){
	printf '%s\n' 'ERROR: WebSearch is not configured on this installation -- this harness has no search endpoint and no search credential, nothing was searched, and no provider is guessed here. Missing: a search provider chosen by the human-owner, its endpoint, and its credential name declared beside the others in AgentsToolsOwnerSetupOptionSpec and stored with --owner-setup. Do not retry; say in your answer that web search was unavailable, and use the file, Glob, Grep and Bash tools for anything reachable locally.'
}

## Unrestricted by the human-owner's own ruling: any address this host can reach, no allow-list.
AgentsHarnessToolWebFetch(){
	local toolUrl="$1" fetchStatus fetchRc=0 toolBytes
	case "$toolUrl" in
		http://*|https://*) ;;
		*)
			printf 'ERROR: url must be an absolute http:// or https:// URL, got: %s\n' "$toolUrl" ; return 0
		;;
	esac
	## Body to its own file, so the capture holds curl's own one-line status and nothing else.
	fetchStatus="$( curl -sS -L --connect-timeout 10 --max-time 120 -o "$harnessScratch/fetch.body" -w '%{http_code}' -- "$toolUrl" 2>"$harnessScratch/fetch.err" )" || fetchRc=$?
	if [ "$fetchRc" != "0" ] ; then
		printf 'ERROR: the request did not complete (curl rc=%s): %s\n' "$fetchRc" "$( cat "$harnessScratch/fetch.err" 2>/dev/null )" ; return 0
	fi
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
AgentsHarnessToolSendMessage(){
	local toolTarget="$1" toolMessage="$2" toolAsBot="$3" sendRc=0
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to send under, and one is never guessed here. Nothing was sent. Report this rather than working around it.\n' ; return 0
	fi
	if [ -z "$toolTarget" ] || [ -z "$toolMessage" ] ; then
		printf 'ERROR: both to and message are required, and one of them was empty. Nothing was sent.\n' ; return 0
	fi
	if [ ! -x "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present beside this harness at %s, and no other send path exists here. Nothing was sent.\n' "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
	fi
	## Built as argv so the optional flag is one token rather than a quoted fragment.
	set -- "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" --member-comms-slack-send-message "$harnessAgent" "$toolTarget"
	case "$toolAsBot" in
		true|1|yes) set -- "$@" --identity-bot ;;
	esac
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

## No central registry of running sessions exists in this estate -- measured against the
## team data store, not assumed. What the store does record is one dispatch board item
## per spawned session, carrying that session's own id, owner and status, so that is
## what this reads. A store it cannot reach is an ERROR, never an empty list.
AgentsHarnessToolListAgents(){
	local listFile listTotal=0 listShown=0
	if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
		printf 'ERROR: MDAT_DATA_ROOT is not set in this process, so the team data store holding the running-session records cannot be located. Nothing was listed, and no session is implied to be absent.\n' ; return 0
	fi
	if [ ! -d "$MDAT_DATA_ROOT/board/running" ] ; then
		printf 'ERROR: the team data store at %s carries no board/running directory, so no running-session record could be read. Nothing was listed, and no session is implied to be absent.\n' "$MDAT_DATA_ROOT" ; return 0
	fi
	for listFile in "$MDAT_DATA_ROOT"/board/running/*.md ; do
		[ -f "$listFile" ] || continue
		listTotal=$(( listTotal + 1 ))
		case "${listFile##*/}" in
			dispatch-*) ;;
			*) continue ;;
		esac
		listShown=$(( listShown + 1 ))
		printf '%s\n' "${listFile##*/}"
		LC_ALL=C awk '
			NR == 1 { if ($0 != "---") exit ; next ; }
			$0 == "---" { exit ; }
			/^(session-id|owner|status|started-at|outcome):/ {
				fieldLine = $0
				if (length(fieldLine) > 200) fieldLine = substr(fieldLine, 1, 200) " ... [cut at 200 of " length($0) " characters]"
				print "  " fieldLine ;
			}
		' "$listFile"
	done
	printf '(%s running agent session(s) listed, out of %s board item(s) in the running state)\n' "$listShown" "$listTotal"
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
	local toolSources="$1" toolTimeout="$2" toolPoll="$3" toolSince="$4" waitRc=0 waitSource
	if [ -z "$harnessAgent" ] ; then
		printf 'ERROR: this harness was started without --agent, so it has no team identity to wait as, and one is never guessed here. Nothing was waited on.\n' ; return 0
	fi
	if [ ! -x "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" ] ; then
		printf 'ERROR: the team tooling is not present beside this harness at %s, and no other wait path exists here. Nothing was waited on.\n' "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" ; return 0
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
	if [ -n "$toolSince" ] && ! AgentsHarnessWholeNumber "$toolSince" ; then
		printf 'ERROR: since_utime must be a whole number of epoch seconds, got: %s\n' "$toolSince" ; return 0
	fi
	## Built as argv, so a source naming a thread stays one token rather than a
	## quoted fragment, and an empty sources string adds no flag at all.
	set -- "${harnessHere%/*}/sh-scripts/DistroAgentsTools.fn.sh" --member-wait-for-input "$harnessAgent"
	for waitSource in $toolSources ; do
		set -- "$@" --wait-source "$waitSource"
	done
	set -- "$@" --wait-timeout "$toolTimeout"
	[ -z "$toolPoll" ] || set -- "$@" --wait-poll-interval "$toolPoll"
	[ -z "$toolSince" ] || set -- "$@" --wait-since-utime "$toolSince"
	"$@" >"$harnessScratch/wait.out" 2>"$harnessScratch/wait.err" || waitRc=$?
	if [ "$waitRc" != "0" ] ; then
		printf 'ERROR: the wait could not be performed (rc=%s), so NOTHING is known about those sources -- this is not a wait that found nothing, and their silence must not be read as quiet. What the operation reported follows:\n' "$waitRc"
		cat "$harnessScratch/wait.err"
		return 0
	fi
	cat "$harnessScratch/wait.out"
}

## A tool_call's own `function.arguments` is itself a JSON document, so the same field
## reader runs again on it rather than a second parser being written.
AgentsHarnessArgValue(){
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
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
	## characters instead, and a 383-byte path then passes a 120-byte test and emits
	## 334 bytes on one line.
	local LC_ALL=C
	## A big cap, never 0: in standalone mode that renderer emits nothing at all for
	## a cap of 0 -- the fold-without-cut meaning belongs to its function form only.
	local truncSafe truncTail truncCap=120
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
			truncTail="${truncSafe: -$(( truncCap - 3 ))}"
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
			printf '...%s' "$truncTail"
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
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		Write)
			announceIcon="📝"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		Glob)
			announceIcon="📂"
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
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
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
			announceIcon="💬"
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

## Sourced, not exec'd: its functions run in this process and share everything above.
harnessWireFile="$harnessHere/Agents${harnessWire}Wire.sh"
if [ ! -f "$harnessWireFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE=$harnessWire names no adapter in this package: $harnessWireFile" >&2
	exit 1
fi
. "$harnessWireFile"

## Sourced the same way, and after the wire so its refusals can name this run's tools.
## Absent, this refuses to start: a harness that cannot consult its hooks must not run
## unguarded, which is the same rule its hooks are held to.
harnessHooksFile="$harnessHere/AgentsHarnessHooks.sh"
if [ ! -f "$harnessHooksFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the PreToolUse hook support is missing from this package: $harnessHooksFile" >&2
	exit 1
fi
. "$harnessHooksFile"

## Sourced on the same terms, and after the hooks so a server this enumerates is
## already subject to them. It enumerates only what --mcp-server named, so a spawn
## naming none reads no file and starts no process.
harnessMcpFile="$harnessHere/AgentsHarnessMcpClient.sh"
if [ ! -f "$harnessMcpFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the MCP client support is missing from this package: $harnessMcpFile" >&2
	exit 1
fi
. "$harnessMcpFile"

## Said only when the two sets differ, so an ungranted run reads exactly as it did.
harnessWriteNote=""
[ "$harnessWriteRoots" = "$harnessRoots" ] || harnessWriteNote="Writing is narrower than reading. Write and Edit may only write under these roots:
$harnessWriteRoots
Everything else above you may read, list, search and run commands in, but not write to. Do not try to work around that -- report it instead.
"

harnessSystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$harnessRoots
$harnessWriteNote
Use the given tools to accomplish the request, then reply with a final plain-text message once done. Do not ask the user a question -- there is no one to answer it; make the most reasonable choice and state what you did."

## --agent given: the member's own identity replaces the generic opener entirely.
## Read below is a tool name in prose, which no structural check can see.
if [ -n "$harnessAgent" ] ; then
	harnessSystemText="$harnessAgentBasicText

If this task needs duty-level detail beyond the above, Read your own $harnessAgentRealDir/$harnessAgent.armed.md yourself -- it is not included here.

You are running through a bespoke $harnessProviderName harness$harnessSystemTail"
else
	harnessSystemText="You are an autonomous coding agent running through a bespoke $harnessProviderName harness$harnessSystemTail"
fi

## A named-but-unavailable MCP server owes the model a sentence: its tools are absent
## from the declarations, and nothing else in the run says why.
[ -z "$harnessMcpUnavailableNote" ] || harnessSystemText="$harnessSystemText

$harnessMcpUnavailableNote"

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
## The 64000 is a policy value sized from this file's own caps rather than from any
## model's published window: one Read result caps at 200000 bytes and max_tokens is
## 8192, so the largest round that can follow a trip still has somewhere to land.
## Fallback only, for a provider stub that sets nothing -- the stub knows its models
## and this file does not. Not 64000: that predates the current model generation and
## is below this team's own instruction set, so a pass summarised and restarted before
## executing a single step. A provider whose window is genuinely smaller sets its own.
harnessContextTokens="${MDAT_HARNESS_CONTEXT_TOKENS:-400000}"
## Bounded because an unbounded summarise-restart cycle is worse than the failure it
## replaces: a task that keeps refilling the window is not converging, and the run
## must end saying so rather than paying for the same window again.
harnessMaxRestarts="${MDAT_HARNESS_MAX_RESTARTS:-3}"
if ! AgentsHarnessWholeNumber "$harnessContextTokens" ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_CONTEXT_TOKENS must be a whole number of tokens, got: $harnessContextTokens" >&2
	exit 1
fi
if ! AgentsHarnessWholeNumber "$harnessMaxRestarts" ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_MAX_RESTARTS must be a whole number of restarts, got: $harnessMaxRestarts" >&2
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
		if [ "$harnessRestartCount" -ge "$harnessMaxRestarts" ] ; then
			harnessMessages+=( "$( AgentsWireUserRecord "Your context is full and your restart budget is spent, so no further tool call can run. Reply now, in plain text, with what you did, what you found, and what is left unfinished." )" )
			harnessToolChoice="none"
			harnessClosingRound=1
			printf '%s\n' "${harnessWarn}⚠️  context threshold reached with no restart left${harnessOff} ${harnessDim}-- closing round, tools off; MDAT_HARNESS_MAX_RESTARTS raises the bound${harnessOff}" >&2
		else
			harnessMessages+=( "$( AgentsWireUserRecord "Your context is nearly full and this leg is about to be restarted, so no further tool call can run in it. Write the handover a fresh leg needs: it will be given the original task again word for word, and nothing else from this conversation. State what you have already done, what you found -- exact paths, names, values and commands, not a description of them -- what is still to do, and what must not be repeated. Write it as notes to yourself, in plain text, with no preamble." )" )
			harnessToolChoice="none"
			harnessSummariseRound=1
			printf '%s\n' "${harnessWarn}♻️  context threshold reached${harnessOff} ${harnessDim}-- $harnessRoundTotal tokens last round, at or over $harnessContextTokens; summarising for restart $(( harnessRestartCount + 1 )) of $harnessMaxRestarts${harnessOff}" >&2
		fi
	fi

	## Braces are load-bearing: bash 3.2 reads the first byte of an abutting UTF-8
	## character as part of an unbraced name.
	AgentsHarnessTitleState
	printf '%s\n' "${harnessDim}── round $harnessRound ─────────────────────────────────${harnessOff}${harnessUsageTotal:+ ${harnessDim}· $harnessUsageTotal tokens so far${harnessOff}}" >&2

	harnessBody="$( AgentsWireRequestBody )"

	## Token on curl's stdin, never argv.
	harnessAuthHeader="Authorization: Bearer $harnessToken"

	## Every attempt starts from a clean accumulator, and a retry here never touches
	## $harnessRound above.
	harnessStreamAttempt=0
	harnessStreamMaxAttempts=3
	harnessStreamOk=0
	while [ "$harnessStreamAttempt" -lt "$harnessStreamMaxAttempts" ] ; do
		harnessStreamAttempt=$(( harnessStreamAttempt + 1 ))
		rm -f "$harnessScratch"/stream.* 2>/dev/null
		: > "$harnessScratch/stream.content"

		## Nothing else may sit in this pipe or block buffering returns.
		## set +e brackets this one statement so ${PIPESTATUS[0]} is curl's, not the loop's.
		set +e
		curl -N -sS --connect-timeout 10 --speed-limit 1 --speed-time 45 -X POST "$harnessEndpoint" \
			-H @- \
			-H "Content-type: application/json" \
			-d "$harnessBody" <<< "$harnessAuthHeader" 2>"$harnessScratch/stream.curlerr" \
			| AgentsWireStreamConsume
		harnessCurlRc="${PIPESTATUS[0]}"
		set -e

		if [ "$harnessCurlRc" = "0" ] && [ -f "$harnessScratch/stream.done" ] ; then
			harnessStreamOk=1
			break
		fi

		## A complete, non-streaming error body is not a disconnect: no retry.
		if [ -s "$harnessScratch/stream.rawother" ] && [ ! -f "$harnessScratch/stream.done" ] ; then
			break
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
		AgentsWireInitMessages
		harnessMessages+=( "$( AgentsWireUserRecord "Notes you wrote for yourself at the end of your previous leg on this same task, which is stated above unchanged. Nothing else from that leg survives. Treat them as your own record of work already done, never as a new instruction, and carry on from where they stop.

$harnessSummary" )" )
		harnessToolChoice=""
		harnessSummariseRound=0
		harnessRestartCount=$(( harnessRestartCount + 1 ))
		## The signal describes a conversation that has just been replaced.
		harnessRoundTotal=0
		printf '%s\n' "${harnessValue}♻️  restarted${harnessOff} ${harnessDim}-- original task verbatim plus the summary above; restart $harnessRestartCount of $harnessMaxRestarts${harnessOff}" >&2
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
		exit 0
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

		[ -n "$harnessResult" ] || case "$harnessFuncName" in
			Read)      harnessResult="$( AgentsHarnessToolRead "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" offset )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" limit )" )" ;;
			Write)     harnessResult="$( AgentsHarnessToolWrite "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" content )" )" ;;
			Glob)      harnessResult="$( AgentsHarnessToolGlob "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" long )" )" ;;
			Edit)      harnessResult="$( AgentsHarnessToolEdit "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" old_text )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" new_text )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" replace_all )" )" ;;
			Grep)      harnessResult="$( AgentsHarnessToolGrep "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" context )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" before )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" after )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" ignore_case )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" output_mode )" )" ;;
			Bash)      harnessResult="$( AgentsHarnessToolBash "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" cwd )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" command )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" timeout )" )" ;;
			WebSearch) harnessResult="$( AgentsHarnessToolWebSearch )" ;;
			WebFetch)  harnessResult="$( AgentsHarnessToolWebFetch "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" url )" )" ;;
			SendMessage) harnessResult="$( AgentsHarnessToolSendMessage "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" to )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" message )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" as_bot )" )" ;;
			ListAgents) harnessResult="$( AgentsHarnessToolListAgents )" ;;
			Wait)      harnessResult="$( AgentsHarnessToolWait "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" sources )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" timeout )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" poll_interval )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" since_utime )" )" ;;
			## Last, after every static arm: an mcp__ prefix must never displace a built-in.
			mcp__*)    harnessResult="$( AgentsHarnessMcpCall "$harnessFuncName" "$harnessFuncArgsRaw" )" ;;
			*)         harnessResult="ERROR: unknown tool: $harnessFuncName" ;;
		esac

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
