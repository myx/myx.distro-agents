#!/usr/bin/env bash
## Behavioural check on S23.1: the CheckList is also the queue. A spawn that finds the limit of runs reached is not made: it is filed as an inquiry for the coordinator and added as an
## item to the CheckList of the coordinator's running work-duty (AgentsToolsSpawnLimitReached, AgentsToolsSpawnQueue, AgentsTools.SpawnSandbox.include). Held:
##   1. THE LIMIT: unset, 0 or no number is no limit; below it is not reached; at it, reached, and prints `<running> <limit>`. A run counts once however many of its processes show,
##      and a process of the tooling itself is no run. The process list is this rig's own.
##   2. THE QUEUE, a duty running: the request is filed as an inquiry (its routine, members, description and task in the text) and the duty's list holds one pending item naming it.
##   3. THE QUEUE, no duty running: the inquiry is filed, and the answer says there is no list (none).
## The end to end start (--spawn-session at the limit) is held by AgentsMagicSpawnSessionCheck.
## Offline: a stand-in DistroAgentsTools records the filing; the duty is a process of this check's own; every tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include" ] || rigRefuse "the include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnQueueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigEach in $rigPids ; do kill -9 "$rigEach" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSp="$rigTmp/ws/.local/agents/spawned/rig-duty"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigSp" "$rigTmp/home" "$rigTmp/bin" "$rigData/inboxes/magic-coordinator/incoming"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH"
## The rig's process list: `ps -A` answers from ps.list, anything else is the real ps.
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*) cat "%s/ps.list" ; exit 0 ;;\nesac\nexec "%s" "$@"\n' "$rigTmp" "$rigRealPs" > "$rigTmp/bin/ps"
chmod +x "$rigTmp/bin/ps"
: > "$rigTmp/ps.list"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigFn(){ ## the function and its arguments... -- run in the include: `<rc>:<what it printed>`; MDAT_SPAWN_LIMIT from rigLimit
	local fnOut fnRc
	fnOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" ${rigLimit:+MDAT_SPAWN_LIMIT="$rigLimit"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" > /dev/null 2>&1
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" > /dev/null 2>&1
			## The stand-in of the tool the queue files its inquiry with: it keeps what it was asked and the text it was given.
			DistroAgentsTools(){
				case "$1" in
					--upsert-inbox-inquiry) printf "%s|%s|%s\n" "$2" "$3" "$5" >> "$RIG_TMP/filed.log" ; cat "$7" > "$RIG_TMP/filed.text" ;;
				esac
				return 0
			}
			"$@"
		' rig "$@" 2> /dev/null )"
	fnRc=$?
	printf '%s:%s' "$fnRc" "$fnOut"
}
rigLimit=""

echo "-- 1. the limit --"
printf '1001 claude --session-id rig-run-one\n' > "$rigTmp/ps.list"
rigLimit=""
rigAssert "no limit set: not reached" "$( rigFn AgentsToolsSpawnLimitReached )" "1:"
rigLimit="0"
rigAssert "a limit of 0 is none" "$( rigFn AgentsToolsSpawnLimitReached )" "1:"
rigLimit="many"
rigAssert "a limit that is no number is none" "$( rigFn AgentsToolsSpawnLimitReached )" "1:"
rigLimit="2"
rigAssert "one run of two: not reached" "$( rigFn AgentsToolsSpawnLimitReached )" "1:"
printf '1001 claude --session-id rig-run-one\n1002 claude --session-id rig-run-two\n' > "$rigTmp/ps.list"
rigAssert "two runs of two: reached, and says so" "$( rigFn AgentsToolsSpawnLimitReached )" "0:2 2"
printf '1001 claude --session-id rig-run-one\n1002 claude --session-id rig-run-one --other\n1003 bash /x/DistroAgentsTools.fn.sh --session-id rig-tool-call\n' > "$rigTmp/ps.list"
rigAssert "a run counts once however many processes show, and the tooling's own is none" "$( rigFn AgentsToolsSpawnLimitReached )" "1:"

echo "-- 2. the queue, a duty running --"
rigDutyPid="$( sleep 600 > /dev/null 2>&1 < /dev/null & printf '%s' "$!" )"
rigPids="$rigPids $rigDutyPid"
rigStart="$( LC_ALL=C ps -o lstart= -p "$rigDutyPid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
[ -n "$rigStart" ] || rigRefuse "the stand-in duty has no start time"
printf -- '---\nspawn-id: rigduty\nsession-id: rig-duty-session\nowner: magic-coordinator\nstatus: spawn-started\nroutine: magic-coordinator.work-duty.routine.md\nhost: %s\nrun-process: %s %s\n---\n\n# Spawn session: rigduty\n' "$rigHost" "$rigDutyPid" "$rigStart" > "$rigSp/rigduty.spawn.md"
rigLimit=""
rigOut="$( rigFn AgentsToolsSpawnQueue "2 2" magic-team.coworking.routine.md "keeper-a keeper-b" "the description" "the task text" )"
rigItem="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^SPAWN_QUEUE_ITEM=//p' )"
rigAssert "the answer says it is queued, names the inquiry and the duty's session" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e '^0:SPAWN_QUEUED=true$' ):$( printf '%s\n' "$rigItem" | LC_ALL=C grep -c '^inquiry-[0-9TZ]*-queued-spawn-[0-9]*$' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^SPAWN_QUEUE_CHECKLIST=rig-duty-session:magic-coordinator$' )" "1:1:1"
rigAssert "the inquiry was filed to the coordinator, under the item's name" "$( LC_ALL=C awk -F'|' -v item="$rigItem" '{ print $1 "|" ( $2 == item ".md" ? "named" : "other" ) }' "$rigTmp/filed.log" )" "magic-coordinator|named"
rigAssert "its text carries the routine, the members, the description and the task" "$( LC_ALL=C grep -c -e 'routine: magic-team.coworking.routine.md' -e 'members: keeper-a keeper-b' -e 'description: the description' -e '^the task text$' "$rigTmp/filed.text" )" "4"
rigAssert "the duty's list holds one pending item naming the inquiry" "$( LC_ALL=C grep -c -F -e "- [ ] queued spawn of magic-team.coworking.routine.md: start it when a run ends ($rigItem)" "$rigSp/magic-coordinator.checklist.md" 2> /dev/null )" "1"

echo "-- 3. the queue, no duty running --"
kill -9 "$rigDutyPid" 2> /dev/null
rigLeft=50 ; while kill -0 "$rigDutyPid" 2> /dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
rm -rf "$rigWs/.local/agents/liveness" "$rigSp/magic-coordinator.checklist.md" "$rigTmp/filed.log"
rigOut="$( rigFn AgentsToolsSpawnQueue "2 2" magic-team.coworking.routine.md "keeper-a" "d" "t" )"
rigAssert "the answer says there is no list" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e '^0:SPAWN_QUEUED=true$' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^SPAWN_QUEUE_CHECKLIST=none$' )" "1:1"
rigAssert "the inquiry is filed all the same, and no list was made" "$( LC_ALL=C grep -c '^magic-coordinator|' "$rigTmp/filed.log" ):$( [ -e "$rigSp/magic-coordinator.checklist.md" ] && printf made || printf none )" "1:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN QUEUE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
