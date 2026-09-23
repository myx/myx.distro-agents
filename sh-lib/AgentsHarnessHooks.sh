#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only

## AgentsHarnessHooks.sh -- PreToolUse hooks for the universal harness. Sourced by
## AgentsUniversalHarness.sh and never executed: everything here runs in the core's
## process. Equivalence with claude rather than a second mechanism -- the descriptor
## is the same `hooks.PreToolUse` array of the workspace's own .claude/settings.json
## that claude itself reads, the hook gets the same payload on stdin, and it answers
## with the same hookSpecificOutput.permissionDecision document.
## THE RULE SET IS NOT THE SAME SET, AND THAT IS THE SECOND DELIBERATE DIVERGENCE:
## the array carries two classes of hook, and the class filter below drops the
## deny-reroute ones. What that changes is which rules apply here, never how a
## rule that applies is judged -- every entry the filter keeps goes through the
## whole of the fail-closed path below, unweakened.
## IT FAILS CLOSED, WHICH IS A DELIBERATE DIVERGENCE: claude treats a non-zero hook
## as non-blocking and runs the tool anyway. Here anything short of an explicit allow
## -- an unreadable configuration, a hook that will not run, a non-zero exit, an
## answer in a shape this cannot read -- refuses the call and states why.

## The descriptor is flattened once, at source time, into `matcher<TAB>command` lines
## -- the same tab-separated spelling AgentsTools.Install.include already writes for
## the settings merge. Every later decision is then builtins alone over this value:
## no parser sits in the per-call decision path, where a missing binary's empty
## output and exit 0 would read as permission.
harnessHooksList=""
## Set instead of the list where the configuration cannot be trusted; every call is
## then refused naming this, because a guard that cannot read its rules permits nothing.
harnessHooksFault=""
## Entries the class filter below left out, so a narrower set is never silent.
harnessHooksSkipped=0

## Two classes share that one array, because a *-native client reads it natively
## and our harness reads it here. A deny-reroute hook routes a native client at
## this estate's own MCP tooling, which is already what is running here, so it is
## left out; a memory-deny hook applies everywhere and stays. The class comes from
## AgentsTools.ClientToolPolicy.include, the one place the policy is stated, and
## never from a hook's own name. Absent, this refuses to start on the same rule
## the access-root mechanism follows: a class that cannot be resolved is not a
## class, and guessing it either way is the fault this split exists to remove.
harnessHooksPolicyFile="$harnessHere/AgentsTools.ClientToolPolicy.include"
if [ ! -f "$harnessHooksPolicyFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the client tool policy is missing from this package, so no hook class can be resolved: $harnessHooksPolicyFile" >&2
	exit 1
fi
. "$harnessHooksPolicyFile"
## An empty list is the legitimate "nothing is deny-reroute" and leaves every
## entry in force; only a non-zero return is a fault, and it refuses every call.
harnessHooksRerouteKeys=()
harnessHooksRerouteList="$( AgentsToolsClientToolPolicyRerouteHookKeys )" || harnessHooksFault="the client tool policy could not state which hooks are *-native only"
while IFS= read -r harnessHooksRerouteKey ; do
	[ -n "$harnessHooksRerouteKey" ] || continue
	harnessHooksRerouteKeys+=( "$harnessHooksRerouteKey" )
done <<< "$harnessHooksRerouteList"

if [ -z "$harnessHooksFault" ] && [ -n "${MMDAPP:-}" ] && [ -e "$MMDAPP/.claude/settings.json" ] ; then
	if [ ! -f "$MMDAPP/.claude/settings.json" ] || [ ! -r "$MMDAPP/.claude/settings.json" ] ; then
		harnessHooksFault="$MMDAPP/.claude/settings.json exists but is not a readable file"
	else
		harnessHooksDoc="$( cat "$MMDAPP/.claude/settings.json" )"
		harnessHooksRc=0
		harnessHooksEntryCount="$( printf '%s\n' "$harnessHooksDoc" | LC_ALL=C awk -v path=hooks.PreToolUse.__count -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || harnessHooksRc=$?
		## rc 3 is the settled "this workspace configures no PreToolUse hook" answer and
		## leaves everything below inert; anything else is a document we cannot vouch for.
		if [ "$harnessHooksRc" != "0" ] && [ "$harnessHooksRc" != "3" ] ; then
			harnessHooksFault="$MMDAPP/.claude/settings.json did not parse as one JSON object (rc=$harnessHooksRc)"
		elif [ "$harnessHooksRc" = "0" ] ; then
			harnessHooksEntry=0
			while [ "$harnessHooksEntry" -lt "$harnessHooksEntryCount" ] 2>/dev/null ; do
				## An absent matcher is claude's own "every tool", so rc 3 leaves it empty.
				harnessHooksMatcher="$( printf '%s\n' "$harnessHooksDoc" | LC_ALL=C awk -v path="hooks.PreToolUse.$harnessHooksEntry.matcher" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || harnessHooksMatcher=""
				harnessHooksRc=0
				harnessHooksInnerCount="$( printf '%s\n' "$harnessHooksDoc" | LC_ALL=C awk -v path="hooks.PreToolUse.$harnessHooksEntry.hooks.__count" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || harnessHooksRc=$?
				if [ "$harnessHooksRc" != "0" ] ; then
					harnessHooksFault="hooks.PreToolUse[$harnessHooksEntry] carries no readable hooks array"
					break
				fi
				harnessHooksInner=0
				while [ "$harnessHooksInner" -lt "$harnessHooksInnerCount" ] 2>/dev/null ; do
					harnessHooksType="$( printf '%s\n' "$harnessHooksDoc" | LC_ALL=C awk -v path="hooks.PreToolUse.$harnessHooksEntry.hooks.$harnessHooksInner.type" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || harnessHooksType=""
					harnessHooksCommand="$( printf '%s\n' "$harnessHooksDoc" | LC_ALL=C awk -v path="hooks.PreToolUse.$harnessHooksEntry.hooks.$harnessHooksInner.command" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || harnessHooksCommand=""
					## A type this cannot run, and a separator inside a field, are both
					## "not understood" -- which is refusal to proceed, never a silent skip.
					if [ "$harnessHooksType" != "command" ] || [ -z "$harnessHooksCommand" ] ; then
						harnessHooksFault="hooks.PreToolUse[$harnessHooksEntry].hooks[$harnessHooksInner] is not a runnable command hook"
						break
					fi
					## The class filter, and it sits here rather than in the decision
					## path so a skipped entry never reaches one. Matched as a plain
					## substring of the command, the same way the installed hooks are
					## already recognised, and by builtins alone.
					harnessHooksReroute=""
					for harnessHooksRerouteKey in "${harnessHooksRerouteKeys[@]}" ; do
						case "$harnessHooksCommand" in
							*"$harnessHooksRerouteKey"*) harnessHooksReroute=1 ; break ;;
						esac
					done
					if [ -n "$harnessHooksReroute" ] ; then
						harnessHooksSkipped=$(( harnessHooksSkipped + 1 ))
						harnessHooksInner=$(( harnessHooksInner + 1 ))
						continue
					fi
					case "$harnessHooksMatcher$harnessHooksCommand" in
						*$'\t'*|*$'\n'*)
							harnessHooksFault="hooks.PreToolUse[$harnessHooksEntry] carries a tab or newline this cannot represent"
							break
						;;
					esac
					harnessHooksList="${harnessHooksList}${harnessHooksMatcher}"$'\t'"${harnessHooksCommand}"$'\n'
					harnessHooksInner=$(( harnessHooksInner + 1 ))
				done
				[ -z "$harnessHooksFault" ] || break
				harnessHooksEntry=$(( harnessHooksEntry + 1 ))
			done
		fi
	fi
fi

if [ -n "$harnessHooksFault" ] ; then
	printf '%s\n' "${harnessWarn}🪝 hooks${harnessOff} ${harnessBad}unreadable${harnessOff} ${harnessDim}-- every tool call will be refused: $harnessHooksFault${harnessOff}" >&2
elif [ -n "$harnessHooksList" ] ; then
	printf '%s\n' "🪝 ${harnessDim}PreToolUse hooks from${harnessOff} ${harnessValue}$MMDAPP/.claude/settings.json${harnessOff}" >&2
fi
## Said on its own line and on either path above: a set narrowed by the class
## filter otherwise reads exactly like a workspace that configured fewer hooks.
[ "$harnessHooksSkipped" = "0" ] || printf '%s\n' "🪝 ${harnessDim}skipped${harnessOff} ${harnessValue}$harnessHooksSkipped${harnessOff} ${harnessDim}deny-reroute hook(s): those route a *-native client to the myx.distro MCP, and this harness already is that destination${harnessOff}" >&2

## Prints the refusal a hook decided on, and nothing at all where the call may run.
## The caller uses emptiness as the verdict, so every path that cannot reach a
## decision prints a refusal rather than returning quietly.
AgentsHarnessHooksRefusal(){
	local hookToolName="$1" hookArgsRaw="$2" hookInputJson hookInputRc hookPayload hookMatcher hookCommand hookLine hookMatches hookRc hookDecision hookReason hookWatchPid hookRunPid hookReadOffset hookReadLimit
	if [ -n "$harnessHooksFault" ] ; then
		printf 'ERROR: refused before running: this harness cannot read the PreToolUse hook configuration -- %s. A hook configuration that cannot be read refuses every call rather than permitting one. Report this rather than working around it.\n' "$harnessHooksFault"
		return 0
	fi
	[ -n "$harnessHooksList" ] || return 0

	## The payload speaks claude's own vocabulary, because the hooks it must satisfy are
	## written against `tool_input.file_path` and the rest of claude's argument spelling.
	case "$hookToolName" in
		## claude's own Read tool_input carries the range beside the path, so a hook here
		## reads the same three fields. Each half is emitted only where the call carried a
		## whole number: an absent range stays absent rather than arriving as 0, and a
		## value that is not a number is left out rather than written as a broken literal.
		Read)
			hookReadOffset="$( AgentsHarnessArgValue "$hookArgsRaw" offset )"
			hookReadLimit="$( AgentsHarnessArgValue "$hookArgsRaw" limit )"
			AgentsHarnessWholeNumber "$hookReadOffset" || hookReadOffset=""
			AgentsHarnessWholeNumber "$hookReadLimit" || hookReadLimit=""
			hookInputJson='{"file_path":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" path )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"'"${hookReadOffset:+,\"offset\":$hookReadOffset}${hookReadLimit:+,\"limit\":$hookReadLimit}"'}'
		;;
		Write)     hookInputJson='{"file_path":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" path )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Edit)      hookInputJson='{"file_path":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" path )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Glob)      hookInputJson='{"path":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" path )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Grep)      hookInputJson='{"path":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" path )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Bash)      hookInputJson='{"command":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" command )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## Monitor runs a shell command, so it is shaped in Bash's own spelling: a hook
		## written to guard `tool_input.command` must decide on this call exactly as it
		## decides on that one, and a command that escaped the guard by arriving under a
		## different field name would be a hole in it. The handle rides along, so a hook
		## can tell a start from a read of one already running.
		Monitor)   hookInputJson='{"command":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" command )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","cwd":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" cwd )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","handle":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" handle )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		WebSearch) hookInputJson='{"query":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" query )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		WebFetch)  hookInputJson='{"url":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" url )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		SendMessage) hookInputJson='{"to":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" to )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","message":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" message )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## ListAgents takes no arguments, so what a hook decides on is the store it reads.
		ListAgents) hookInputJson='{"data_root":"'"$( printf '%s' "${MDAT_DATA_ROOT:-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## What a hook decides on for Wait is WHERE this agent is about to listen, so the
		## sources go in. The bound is not a permission question and is left out. An empty
		## sources value is the tooling's own default set, not an absence of targets, so a
		## hook reading this field sees the empty string and can refuse on exactly that.
		Wait) hookInputJson='{"sources":"'"$( printf '%s' "$( AgentsHarnessArgValue "$hookArgsRaw" sources )" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## A tool whose arguments are not shaped here still faces every matcher-less hook,
		## and an MCP tool's arguments already ARE the object a hook reads fields out of --
		## so they are passed through verbatim rather than emptied. An empty object here
		## would let a hook written to deny read nothing, match nothing and exit 0, which
		## is an allow: fail-open inside a mechanism whose whole point is failing closed.
		*)
			hookInputRc=0
			printf '%s' "$hookArgsRaw" | LC_ALL=C awk -v path=__probe__ -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" >/dev/null 2>&1 || hookInputRc=$?
			## rc 0 found it, rc 3 parsed and it is absent -- both prove one JSON object.
			hookInputJson='{}'
			case "$hookInputRc" in
				0|3) hookInputJson="$hookArgsRaw" ;;
			esac
		;;
	esac

	## The arguments go UNDER `tool_input`, which is where a hook reads them: the estate's
	## own jq hook asks for `.tool_input.file_path`, and handed a bare object it reads
	## nothing, matches nothing and exits 0 -- an allow, from a hook written to deny.
	hookPayload='{"session_id":"'"$( printf '%s' "$harnessSessionId" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","cwd":"'"$( printf '%s' "$PWD" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","hook_event_name":"PreToolUse","tool_name":"'"$hookToolName"'","tool_input":'"$hookInputJson"'}'

	while IFS= read -r hookLine ; do
		[ -n "$hookLine" ] || continue
		hookMatcher="${hookLine%%$'\t'*}"
		hookCommand="${hookLine#*$'\t'}"

		## Exact names and `A|B` alternation are what the estate's matchers actually use.
		## A matcher carrying anything richer is not skipped -- the hook is run and left
		## to decide, since guessing a regex wrong the other way permits silently.
		hookMatches=0
		case "$hookMatcher" in
			''|'*') hookMatches=1 ;;
			*'('*|*')'*|*'['*|*']'*|*'.'*|*'*'*|*'+'*|*'?'*|*'^'*|*'$'*|*'\'*) hookMatches=1 ;;
			*)
				case "|$hookMatcher|" in
					*"|$hookToolName|"*) hookMatches=1 ;;
				esac
			;;
		esac
		[ "$hookMatches" = "1" ] || continue

		## Output to files, never a capture: a hook that leaves a child behind would hold
		## a capture pipe open and hang this harness for that child's whole lifetime.
		: > "$harnessScratch/hook.out"
		: > "$harnessScratch/hook.err"
		hookRc=0
		if [ -n "$harnessTimeoutCmd" ] ; then
			printf '%s' "$hookPayload" | CLAUDE_PROJECT_DIR="$MMDAPP" "$harnessTimeoutCmd" 60 bash -c "$hookCommand" > "$harnessScratch/hook.out" 2>"$harnessScratch/hook.err" || hookRc=$?
		else
			## Watchdog where no `timeout` exists, the shape Bash already uses here.
			{
				printf '%s' "$hookPayload" | CLAUDE_PROJECT_DIR="$MMDAPP" bash -c "$hookCommand" > "$harnessScratch/hook.out" 2>"$harnessScratch/hook.err" &
				hookRunPid=$!
				( sleep 60 ; kill -TERM "$hookRunPid" 2>/dev/null ) >/dev/null &
				hookWatchPid=$!
				wait "$hookRunPid" || hookRc=$?
				kill -TERM "$hookWatchPid" 2>/dev/null || :
				wait "$hookWatchPid" 2>/dev/null || :
			} 2>/dev/null
		fi

		## claude runs the tool anyway on a non-zero hook. This does not: a hook that
		## crashed, was killed or was never executable has not approved anything.
		if [ "$hookRc" != "0" ] ; then
			printf 'ERROR: blocked before running -- the PreToolUse hook `%s` did not complete (exit status %s)%s. A hook that fails refuses the call here rather than letting it through.\n' "$hookCommand" "$hookRc" "$( [ ! -s "$harnessScratch/hook.err" ] || printf ': %s' "$( LC_ALL=C awk -v progressLineCap=400 -f "$harnessHere/AgentsProgressLineSafe.awk" < "$harnessScratch/hook.err" )" )"
			return 0
		fi

		## Silence with a clean exit is the allow every hook in this estate uses.
		[ -s "$harnessScratch/hook.out" ] || continue

		hookRc=0
		hookDecision="$( LC_ALL=C awk -v path=hookSpecificOutput.permissionDecision -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" < "$harnessScratch/hook.out" 2>/dev/null )" || hookRc=$?
		## Output that is not the decision document is unread input, and unread input is
		## refusal -- this is the one branch where a missing parser must not mean yes.
		if [ "$hookRc" != "0" ] && [ "$hookRc" != "3" ] ; then
			printf 'ERROR: blocked before running -- the PreToolUse hook `%s` answered in a shape this harness could not read (rc=%s), and an unread answer is a refusal here, never a permission.\n' "$hookCommand" "$hookRc"
			return 0
		fi
		[ "$hookRc" = "0" ] || continue

		hookReason="$( LC_ALL=C awk -v path=hookSpecificOutput.permissionDecisionReason -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk" < "$harnessScratch/hook.out" 2>/dev/null )" || hookReason=""
		case "$hookDecision" in
			allow) continue ;;
			deny)
				printf 'ERROR: blocked by a PreToolUse hook: %s\n' "${hookReason:-no reason given}"
				return 0
			;;
			## `ask` wants a human, and this leg has none -- the system prompt says so.
			ask)
				printf 'ERROR: blocked by a PreToolUse hook, which asked for a human decision: %s. Nobody is watching this run, so there is no one to approve it. Do not retry; report it.\n' "${hookReason:-no reason given}"
				return 0
			;;
			*)
				printf 'ERROR: blocked before running -- the PreToolUse hook `%s` returned the permission decision `%s`, which this harness does not know. An unrecognised decision refuses the call rather than permitting it.\n' "$hookCommand" "$hookDecision"
				return 0
			;;
		esac
	done <<< "$harnessHooksList"
}
