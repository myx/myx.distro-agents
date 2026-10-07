#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only

## AgentsHarnessHooks.sh -- PreToolUse hooks for the universal harness. Sourced by
## AgentsUniversalHarness.sh and never executed: everything here runs in the core's
## process. Equivalence with claude rather than a second mechanism -- the hooks are
## the ones our installer writes into .claude/settings.json for claude, taken from the
## policy that file is generated from (never from the file), the hook gets the same
## payload on stdin, and it answers with the same hookSpecificOutput.permissionDecision
## document.
## THE RULE SET IS NOT THE SAME SET, AND THAT IS THE SECOND DELIBERATE DIVERGENCE:
## the policy carries two classes of hook, and the class filter below drops the
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

## The rule set is OUR OWN: AgentsTools.ClientToolPolicy.include names every hook this
## estate installs and its class, and that is all this harness applies. A deny-reroute
## hook routes a *-native client at this estate's own MCP tooling, which is already
## what is running here, so it is left out; a memory-deny hook applies everywhere and
## stays. .claude/settings.json is never read: it is generated from these same records
## for the *-native clients, and anything else written there is theirs, not ours.
## Absent, the policy refuses this start: a class that cannot be resolved is not a
## class, and guessing it either way is the fault this split exists to remove.
harnessHooksPolicyFile="$harnessHere/AgentsTools.ClientToolPolicy.include"
if [ ! -f "$harnessHooksPolicyFile" ] ; then
	echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: the client tool policy is missing from this package, so no hook class can be resolved: $harnessHooksPolicyFile" >&2
	exit 1
fi
. "$harnessHooksPolicyFile"

## From the installer's .local/agents/harness.hooks.index while it vouches for this
## policy (one cksum, no parse), else computed from the policy itself -- the same
## records either way (AgentsHarnessHooksLoad.include).
. "$harnessHere/AgentsHarnessHooksLoad.include"
if AgentsHarnessHooksRecords "${MMDAPP:-}" ; then
	AgentsHarnessHooksFromRecords "$agentsHooksRecords"
else
	harnessHooksFault="the client tool policy could not state the hooks this estate installs"
fi

if [ -n "$harnessHooksFault" ] ; then
	printf '%s\n' "${harnessWarn}🪝 hooks${harnessOff} ${harnessBad}unreadable${harnessOff} ${harnessDim}-- every tool call will be refused: $harnessHooksFault${harnessOff}" >&2
elif [ -n "$harnessHooksList" ] ; then
	if [ "$agentsHooksFrom" = "harness.hooks.index" ] ; then
		printf '%s\n' "🪝 ${harnessDim}PreToolUse hooks from${harnessOff} ${harnessValue}$MMDAPP/.local/agents/harness.hooks.index${harnessOff}" >&2
	else
		printf '%s\n' "🪝 ${harnessDim}PreToolUse hooks computed from${harnessOff} ${harnessValue}the client tool policy${harnessOff}" >&2
	fi
fi
## Said on its own line and on either path above: a set narrowed by the class
## filter otherwise reads exactly like a workspace that configured fewer hooks.
[ "$harnessHooksSkipped" = "0" ] || printf '%s\n' "🪝 ${harnessDim}skipped${harnessOff} ${harnessValue}$harnessHooksSkipped${harnessOff} ${harnessDim}deny-reroute hook(s): those route a *-native client to the myx.distro MCP, and this harness already is that destination${harnessOff}" >&2

## The payload's `session_id` and `cwd` are the same for every call of a run, and the
## refusal runs in a command substitution, where nothing it caches survives the call.
## So they are escaped once here, with the raw text beside them; a call whose raw
## text has since changed escapes its own, exactly as every call used to.
harnessHooksSessionRaw=""
harnessHooksSessionEsc=""
harnessHooksCwdRaw=""
harnessHooksCwdEsc=""
harnessHooksEscaped=""
if [ -z "$harnessHooksFault" ] && [ -n "$harnessHooksList" ] ; then
	harnessHooksSessionRaw="$harnessSessionId"
	harnessHooksSessionEsc="$( printf '%s' "$harnessHooksSessionRaw" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	harnessHooksCwdRaw="$PWD"
	harnessHooksCwdEsc="$( printf '%s' "$harnessHooksCwdRaw" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	harnessHooksEscaped=1
fi

## Prints the refusal a hook decided on, and nothing at all where the call may run.
## The caller uses emptiness as the verdict, so every path that cannot reach a
## decision prints a refusal rather than returning quietly.
AgentsHarnessHooksRefusal(){
	local hookToolName="$1" hookArgsRaw="$2" hookInputJson hookInputRc hookPayload hookMatcher hookCommand hookLine hookMatches hookRc hookDecision hookReason hookWatchPid hookRunPid hookReadOffset hookReadLimit hookReadPath hookSessionEsc hookCwdEsc hookRead hookSep
	if [ -n "$harnessHooksFault" ] ; then
		printf 'ERROR: refused before running: this harness cannot read the PreToolUse hook configuration -- %s. A hook configuration that cannot be read refuses every call rather than permitting one. Report this rather than working around it.\n' "$harnessHooksFault"
		return 0
	fi
	[ -n "$harnessHooksList" ] || return 0

	## The payload speaks claude's own vocabulary, because the hooks it must satisfy are
	## written against `tool_input.file_path` and the rest of claude's argument spelling.
	## Each field below is exactly "$( AgentsHarnessArgValue "$hookArgsRaw" <key> )". Every
	## caller has already parsed these same arguments (AgentsHarnessAnnounceTool), and then
	## the table's harnessArgV_<key> holds that value -- trailing newlines dropped, unset
	## where empty -- so reading it costs no subshell. Where the table is some other
	## document's, the fields are read here exactly as they always were, into locals of
	## the same names.
	if [ "$harnessArgParsed" != 1 ] || [ "$hookArgsRaw" != "$harnessArgRaw" ] ; then
		local harnessArgV_offset harnessArgV_limit harnessArgV_file_path harnessArgV_path harnessArgV_pattern harnessArgV_command harnessArgV_cwd harnessArgV_handle harnessArgV_query harnessArgV_url harnessArgV_to harnessArgV_message harnessArgV_sources
		case "$hookToolName" in
			Read|Write|Edit)
				if [ "$hookToolName" = Read ] ; then
					harnessArgV_offset="$( AgentsHarnessArgValue "$hookArgsRaw" offset )"
					harnessArgV_limit="$( AgentsHarnessArgValue "$hookArgsRaw" limit )"
				fi
				harnessArgV_file_path="$( AgentsHarnessArgValue "$hookArgsRaw" file_path )"
				[ -n "$harnessArgV_file_path" ] || harnessArgV_path="$( AgentsHarnessArgValue "$hookArgsRaw" path )"
			;;
			Glob|Grep)
				harnessArgV_path="$( AgentsHarnessArgValue "$hookArgsRaw" path )"
				[ "$hookToolName" != Glob ] || harnessArgV_pattern="$( AgentsHarnessArgValue "$hookArgsRaw" pattern )"
			;;
			Bash) harnessArgV_command="$( AgentsHarnessArgValue "$hookArgsRaw" command )" ;;
			Monitor)
				harnessArgV_command="$( AgentsHarnessArgValue "$hookArgsRaw" command )"
				harnessArgV_cwd="$( AgentsHarnessArgValue "$hookArgsRaw" cwd )"
				harnessArgV_handle="$( AgentsHarnessArgValue "$hookArgsRaw" handle )"
			;;
			WebSearch) harnessArgV_query="$( AgentsHarnessArgValue "$hookArgsRaw" query )" ;;
			WebFetch) harnessArgV_url="$( AgentsHarnessArgValue "$hookArgsRaw" url )" ;;
			SendMessage)
				harnessArgV_to="$( AgentsHarnessArgValue "$hookArgsRaw" to )"
				harnessArgV_message="$( AgentsHarnessArgValue "$hookArgsRaw" message )"
			;;
			Wait) harnessArgV_sources="$( AgentsHarnessArgValue "$hookArgsRaw" sources )" ;;
		esac
	fi
	case "$hookToolName" in
		## claude's own Read tool_input carries the range beside the path, so a hook here
		## reads the same three fields. Each half is emitted only where the call carried a
		## whole number: an absent range stays absent rather than arriving as 0, and a
		## value that is not a number is left out rather than written as a broken literal.
		Read)
			hookReadOffset="${harnessArgV_offset-}"
			hookReadLimit="${harnessArgV_limit-}"
			hookReadPath="${harnessArgV_file_path-}"
			[ -n "$hookReadPath" ] || hookReadPath="${harnessArgV_path-}"
			AgentsHarnessWholeNumber "$hookReadOffset" || hookReadOffset=""
			AgentsHarnessWholeNumber "$hookReadLimit" || hookReadLimit=""
			hookInputJson='{"file_path":"'"$( printf '%s' "$hookReadPath" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"'"${hookReadOffset:+,\"offset\":$hookReadOffset}${hookReadLimit:+,\"limit\":$hookReadLimit}"'}'
		;;
		Write|Edit)
			hookReadPath="${harnessArgV_file_path-}"
			[ -n "$hookReadPath" ] || hookReadPath="${harnessArgV_path-}"
			hookInputJson='{"file_path":"'"$( printf '%s' "$hookReadPath" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}'
		;;
		## Glob's pattern rides along in claude's own order: an absolute one names where it reads by itself.
		Glob)      hookInputJson='{"pattern":"'"$( printf '%s' "${harnessArgV_pattern-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","path":"'"$( printf '%s' "${harnessArgV_path-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Grep)      hookInputJson='{"path":"'"$( printf '%s' "${harnessArgV_path-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		Bash)      hookInputJson='{"command":"'"$( printf '%s' "${harnessArgV_command-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## Monitor runs a shell command, so it is shaped in Bash's own spelling: a hook
		## written to guard `tool_input.command` must decide on this call exactly as it
		## decides on that one, and a command that escaped the guard by arriving under a
		## different field name would be a hole in it. The handle rides along, so a hook
		## can tell a start from a read of one already running.
		Monitor)   hookInputJson='{"command":"'"$( printf '%s' "${harnessArgV_command-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","cwd":"'"$( printf '%s' "${harnessArgV_cwd-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","handle":"'"$( printf '%s' "${harnessArgV_handle-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		WebSearch) hookInputJson='{"query":"'"$( printf '%s' "${harnessArgV_query-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		WebFetch)  hookInputJson='{"url":"'"$( printf '%s' "${harnessArgV_url-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		SendMessage) hookInputJson='{"to":"'"$( printf '%s' "${harnessArgV_to-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'","message":"'"$( printf '%s' "${harnessArgV_message-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## ListAgents takes no arguments, so what a hook decides on is the store it reads.
		ListAgents) hookInputJson='{"data_root":"'"$( printf '%s' "${MDAT_DATA_ROOT:-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## What a hook decides on for Wait is WHERE this agent is about to listen, so the
		## sources go in. The bound is not a permission question and is left out. An empty
		## sources value is the tooling's own default set, not an absence of targets, so a
		## hook reading this field sees the empty string and can refuse on exactly that.
		Wait) hookInputJson='{"sources":"'"$( printf '%s' "${harnessArgV_sources-}" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"'"}' ;;
		## A tool whose arguments are not shaped here still faces every matcher-less hook,
		## and an MCP tool's arguments already ARE the object a hook reads fields out of --
		## so they are passed through verbatim rather than emptied. An empty object here
		## would let a hook written to deny read nothing, match nothing and exit 0, which
		## is an allow: fail-open inside a mechanism whose whole point is failing closed.
		*)
			hookInputRc=0
			printf '%s' "$hookArgsRaw" | LC_ALL=C awk -v path=__probe__ -v mode=raw -f "$harnessHere/AgentsHarnessJsonField.awk" >/dev/null 2>&1 || hookInputRc=$?
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
	if [ -n "$harnessHooksEscaped" ] && [ "$harnessSessionId" = "$harnessHooksSessionRaw" ] ; then
		hookSessionEsc="$harnessHooksSessionEsc"
	else
		hookSessionEsc="$( printf '%s' "$harnessSessionId" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	fi
	if [ -n "$harnessHooksEscaped" ] && [ "$PWD" = "$harnessHooksCwdRaw" ] ; then
		hookCwdEsc="$harnessHooksCwdEsc"
	else
		hookCwdEsc="$( printf '%s' "$PWD" | LC_ALL=C awk -f "$harnessHere/AgentsMcpJsonEscape.awk" )"
	fi
	hookPayload='{"session_id":"'"$hookSessionEsc"'","cwd":"'"$hookCwdEsc"'","hook_event_name":"PreToolUse","tool_name":"'"$hookToolName"'","tool_input":'"$hookInputJson"'}'

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

		## Both fields in one read: the decision's own rc, then the decision and the reason,
		## each exactly what its own `$( AgentsHarnessJsonField.awk ... )` used to hold.
		hookRc=0
		hookRead="$( LC_ALL=C awk -f "$harnessHere/AgentsHarnessJsonField.awk" -f "$harnessHere/AgentsHarnessHookDecision.awk" < "$harnessScratch/hook.out" 2>/dev/null )" || hookRc=$?
		## Output that is not the decision document is unread input, and unread input is
		## refusal -- this is the one branch where a missing parser must not mean yes.
		if [ "$hookRc" != "0" ] && [ "$hookRc" != "3" ] ; then
			printf 'ERROR: blocked before running -- the PreToolUse hook `%s` answered in a shape this harness could not read (rc=%s), and an unread answer is a refusal here, never a permission.\n' "$hookCommand" "$hookRc"
			return 0
		fi
		[ "$hookRc" = "0" ] || continue

		hookSep="${hookRead%%$'\n'*}"
		hookRead="${hookRead#*$'\n'}"
		hookDecision="${hookRead%%"$hookSep"*}"
		hookReason="${hookRead#*"$hookSep"}"
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
