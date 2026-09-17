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
## retry never consumes a round against the cap. MAGIC.md carries the reasoning.

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
harnessSessionId=""
harnessAgent=""
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
		--access-root)
			if [ -z "${2:-}" ] ; then
				echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: --access-root: value required" >&2
				exit 1
			fi
			harnessAccessRoots+=( "$2" )
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
	if [ -f "$harnessFragment" ] ; then
		## Four line shapes, matching AgentsConsoleShellScript.template.sh's own parser.
		while IFS= read -r harnessLine ; do
			[ -n "$harnessLine" ] || continue
			case "$harnessLine" in
				--add-dir)
					## Old two-line format's marker; its path is the `/*` arm below.
					continue
				;;
				own$'\t'/*|explicit$'\t'/*)
					harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "${harnessLine#*$'\t'}" )"$'\n'
				;;
				wildcard$'\t'/*)
					harnessWildcardPath="${harnessLine#*$'\t'}"
					[ ! -d "$harnessWildcardPath" ] || harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessWildcardPath" )"$'\n'
				;;
				/*)
					## Untagged, so existence-checked rather than trusted.
					[ ! -d "$harnessLine" ] || harnessRoots="${harnessRoots}$( AgentsHarnessResolveDir "$harnessLine" )"$'\n'
				;;
			esac
		done < "$harnessFragment"
	fi
fi
if [ -z "$harnessRoots" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-root, or run this inside a workspace whose .claude/copilot-add-dir.fragment already exists (DistroAgentsTools --make-workspace-integrations)." >&2
	exit 1
fi

harnessScratch="$( mktemp -d -t "AgentsUniversalHarness-XXXXXXXX" )" || {
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: could not create a scratch directory" >&2
	exit 1
}
trap 'rm -rf -- "$harnessScratch"' EXIT

## Wall-clock bound on run_command. The 900 is the human-owner's chosen value, so a
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
## macOS ships no `timeout` in base; coreutils installs it as `gtimeout` there.
harnessTimeoutCmd=""
if command -v timeout >/dev/null 2>&1 ; then
	harnessTimeoutCmd="timeout"
elif command -v gtimeout >/dev/null 2>&1 ; then
	harnessTimeoutCmd="gtimeout"
fi
## No startup refusal where neither exists: run_command enforces the bound itself.

## Published by AgentsHarnessPathAllowed for its caller.
harnessResolvedPath=""

## Absolute paths only, no `..` segment, resolved to their real location and then
## prefix-matched against the resolved roots. A final component that is itself a
## symlink is not resolved, so a symlink inside an allowed root pointing out of it
## is followed by any tool that opens it.
AgentsHarnessPathAllowed(){
	local checkPath="$1" checkRoot checkReal
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
	done <<< "$harnessRoots"
	return 1
}

AgentsHarnessToolReadFile(){
	local toolPath="$1" toolBytes
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
	## Capped and said so, never silently: an unbounded read risks the request itself.
	toolBytes="$( wc -c < "$toolPath" | tr -d ' ' )"
	if [ "$toolBytes" -gt 200000 ] ; then
		head -c 200000 "$toolPath"
		printf '\n... TRUNCATED at 200000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$toolPath"
	fi
}

## Whole-file overwrite or create, never a partial patch; edit_file is the partial path.
AgentsHarnessToolWriteFile(){
	local toolPath="$1" toolContent="$2" toolTemp
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
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
## long for read_file's cap. Uniqueness is required, not preferred: a silent
## first-of-several substitution is unrecoverable, and identical lines are the norm here.
AgentsHarnessToolEditFile(){
	local toolPath="$1" toolOld="$2" toolNew="$3" toolCount
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
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
		BEGIN { editOld = ENVIRON["EDIT_OLD"] ; matchCount = 0 }
		{
			scanRest = $0
			while ( ( matchPos = index(scanRest, editOld) ) > 0 ) {
				matchCount = matchCount + 1
				scanRest = substr(scanRest, matchPos + length(editOld))
			}
		}
		END { print matchCount + 0 }
	' "$toolPath" 2>/dev/null || : )"
	[ -n "$toolCount" ] || toolCount=0
	if [ "$toolCount" = "0" ] ; then
		printf 'ERROR: old_text not found in %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	if [ "$toolCount" != "1" ] ; then
		printf 'ERROR: old_text occurs %s times in %s -- it must identify exactly one place. Nothing was written; extend old_text until it is unique.\n' "$toolCount" "$toolPath" ; return 0
	fi
	## `printf "%s", $0` with the RS re-join, never `print`, which appends ORS and
	## gave a file that ended without a newline one it never had.
	if ! EDIT_OLD="$toolOld" EDIT_NEW="$toolNew" LC_ALL=C awk -v RS=$'\001' '
		BEGIN { editOld = ENVIRON["EDIT_OLD"] ; editNew = ENVIRON["EDIT_NEW"] ; editDone = 0 }
		{
			if (!editDone) {
				matchPos = index($0, editOld)
				if (matchPos > 0) {
					$0 = substr($0, 1, matchPos - 1) editNew substr($0, matchPos + length(editOld))
					editDone = 1
				}
			}
			if (NR > 1) printf "%s", RS
			printf "%s", $0
		}
	' "$toolPath" > "$harnessScratch/edit.out" 2>/dev/null ; then
		printf 'ERROR: could not rewrite: %s -- nothing was written\n' "$toolPath" ; return 0
	fi
	if ! cat "$harnessScratch/edit.out" > "$toolPath" ; then
		printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
	fi
	printf 'OK: replaced one occurrence in %s\n' "$toolPath"
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
	local toolFindMode=""
	[ -z "$toolLong" ] || toolFindMode="-ls"
	if [ -n "$toolPattern" ] ; then
		find "$toolPath/" -name "$toolPattern" $toolFindMode > "$harnessScratch/glob.out" 2>&1 || :
	else
		find "$toolPath/" -maxdepth 1 $toolFindMode > "$harnessScratch/glob.out" 2>&1 || :
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
	local toolPattern="$1" toolPath="$2" toolBytes
	if ! AgentsHarnessPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	toolPath="$harnessResolvedPath"
	if [ ! -e "$toolPath" ] ; then
		printf 'ERROR: no such path: %s\n' "$toolPath" ; return 0
	fi
	## `|| :` keeps grep's own rc 1 on no-match from tripping this script's set -e.
	grep -rn -- "$toolPattern" "$toolPath" > "$harnessScratch/grep.out" 2>&1 || :
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
AgentsHarnessToolRunCommand(){
	local toolCwd="$1" toolCommand="$2" toolStatus=0 toolBytes
	if ! AgentsHarnessPathAllowed "$toolCwd" ; then
		printf 'ERROR: cwd not in the allowed access-root set: %s\n' "$toolCwd" ; return 0
	fi
	toolCwd="$harnessResolvedPath"
	if [ ! -d "$toolCwd" ] ; then
		printf 'ERROR: no such directory: %s\n' "$toolCwd" ; return 0
	fi
	## The command always reaches bash as an argument, never spliced into a quoted string.
	rm -f "$harnessScratch/run.timedout"
	if [ "$harnessRunTimeout" = 0 ] ; then
		( cd "$toolCwd" && set -e && eval "$toolCommand" ) > "$harnessScratch/run.out" 2>&1 || toolStatus=$?
	elif [ -n "$harnessTimeoutCmd" ] ; then
		"$harnessTimeoutCmd" "$harnessRunTimeout" bash -c 'cd "$1" && set -e && eval "$2"' _ "$toolCwd" "$toolCommand" > "$harnessScratch/run.out" 2>&1 || toolStatus=$?
		[ "$toolStatus" != 124 ] || : > "$harnessScratch/run.timedout"
	else
		## Watchdog where no `timeout` exists; a group, not a subshell, so $toolStatus survives.
		{
			bash -c 'cd "$1" && set -e && eval "$2"' _ "$toolCwd" "$toolCommand" > "$harnessScratch/run.out" 2>&1 &
			harnessRunPid=$!
			## The >/dev/null is load-bearing: without it the orphaned `sleep` holds this
			## function's capture pipe open and every run_command blocks for the full bound.
			( sleep "$harnessRunTimeout" ; kill -TERM "$harnessRunPid" 2>/dev/null && : > "$harnessScratch/run.timedout" ) >/dev/null &
			harnessWatchPid=$!
			wait "$harnessRunPid" || toolStatus=$?
			kill -TERM "$harnessWatchPid" 2>/dev/null || :
			wait "$harnessWatchPid" 2>/dev/null || :
		} 2>/dev/null
	fi
	## Capped and said so, as read_file states its own cap.
	toolBytes="$( wc -c < "$harnessScratch/run.out" | tr -d ' ' )"
	if [ "$toolBytes" -gt 100000 ] ; then
		head -c 100000 "$harnessScratch/run.out"
		printf '\n... TRUNCATED at 100000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$harnessScratch/run.out"
	fi
	## Expiry is read from the flag the enforcing path wrote, never inferred from the status.
	[ ! -f "$harnessScratch/run.timedout" ] || printf '... TIMED OUT after %s seconds ...\n' "$harnessRunTimeout"
	printf '(exit status %s)\n' "$toolStatus"
}

## A tool_call's own `function.arguments` is itself a JSON document, so the same field
## reader runs again on it rather than a second parser being written.
AgentsHarnessArgValue(){
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}

## One line, every C0 byte and DEL folded to a space, cut on a UTF-8 character boundary.
AgentsHarnessTruncateArg(){
	printf '%s' "$1" | LC_ALL=C awk -v progressLineCap=120 -f "$harnessHere/AgentsProgressLineSafe.awk"
}

## Announced immediately before the call executes, so a run_command that might hang is
## visible. Every value here is model output and passes AgentsHarnessTruncateArg first,
## so the only escapes reaching the terminal are the $harness* literals placed around them.
AgentsHarnessAnnounceTool(){
	local announceFuncName="$1" announceArgsRaw="$2" announceIcon="❓" announceDetail=""
	case "$announceFuncName" in
		read_file)
			announceIcon="📖"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		write_file)
			announceIcon="📝"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		glob)
			announceIcon="📂"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" pattern )" )$harnessDim in $harnessOff$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		edit_file)
			announceIcon="✏️"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		grep)
			announceIcon="🔍"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" pattern )" )$harnessDim in $harnessOff$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" path )" )$harnessOff"
		;;
		run_command)
			announceIcon="💻"
			announceDetail="$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" command )" )$harnessDim in $harnessOff$harnessValue$( AgentsHarnessTruncateArg "$( AgentsHarnessArgValue "$announceArgsRaw" cwd )" )$harnessOff"
		;;
	esac
	printf '   %s %s%-11s%s %s\n' "$announceIcon" "$harnessTool" "$( AgentsHarnessTruncateArg "$announceFuncName" )" "$harnessOff" "$announceDetail" >&2
}

## Sourced, not exec'd: its functions run in this process and share everything above.
harnessWireFile="$harnessHere/Agents${harnessWire}Wire.sh"
if [ ! -f "$harnessWireFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: HARNESS_WIRE=$harnessWire names no adapter in this package: $harnessWireFile" >&2
	exit 1
fi
. "$harnessWireFile"

harnessSystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$harnessRoots
Use the given tools to accomplish the request, then reply with a final plain-text message once done. Do not ask the user a question -- there is no one to answer it; make the most reasonable choice and state what you did."

## --agent given: the member's own identity replaces the generic opener entirely.
## read_file below is a tool name in prose, which no structural check can see.
if [ -n "$harnessAgent" ] ; then
	harnessSystemText="$harnessAgentBasicText

If this task needs duty-level detail beyond the above, read_file your own $harnessAgentRealDir/$harnessAgent.armed.md yourself -- it is not included here.

You are running through a bespoke $harnessProviderName harness$harnessSystemTail"
else
	harnessSystemText="You are an autonomous coding agent running through a bespoke $harnessProviderName harness$harnessSystemTail"
fi

AgentsWireInitMessages

## A round cap, not an implicit "keep going until final text": an unbounded tool-call
## loop against a metered API is unbounded spend.
harnessRound=0
harnessMaxRounds=25

while : ; do
	harnessRound=$(( harnessRound + 1 ))
	if [ "$harnessRound" -gt "$harnessMaxRounds" ] ; then
		echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: stopped after $harnessMaxRounds request rounds with no final answer -- refusing to keep spending against a metered API on a conversation that has not converged" >&2
		exit 1
	fi

	## Braces are load-bearing: bash 3.2 reads the first byte of an abutting UTF-8
	## character as part of an unbraced name.
	printf '%s\n' "${harnessDim}── round $harnessRound ─────────────────────────────────${harnessOff}" >&2

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

	harnessToolCount="$( AgentsWireToolCallCount )"

	if [ "$harnessToolCount" -eq 0 ] 2>/dev/null ; then
		harnessFinal="$( AgentsWireFinalContent )"
		if [ -z "$harnessFinal" ] ; then
			harnessFinishReason="$( AgentsWireFinishReason )"
			echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: no tool call and no final content came back (finish_reason=${harnessFinishReason:-<none>}) -- refusing to print an empty answer as if it were one" >&2
			exit 1
		fi
		printf '%s\n' "$harnessFinal"
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

		case "$harnessFuncName" in
			read_file)   harnessResult="$( AgentsHarnessToolReadFile "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" )" ;;
			write_file)  harnessResult="$( AgentsHarnessToolWriteFile "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" content )" )" ;;
			glob)        harnessResult="$( AgentsHarnessToolGlob "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" long )" )" ;;
			edit_file)   harnessResult="$( AgentsHarnessToolEditFile "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" old_text )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" new_text )" )" ;;
			grep)        harnessResult="$( AgentsHarnessToolGrep "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" pattern )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" path )" )" ;;
			run_command) harnessResult="$( AgentsHarnessToolRunCommand "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" cwd )" "$( AgentsHarnessArgValue "$harnessFuncArgsRaw" command )" )" ;;
			*)           harnessResult="ERROR: unknown tool: $harnessFuncName" ;;
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
