#!/usr/bin/env bash
## Behavioural check on a session whose run carries two ids: its record is named by the session and its
## `spawn-id` header holds the run, and the CLI that runs it was given the session id. A reader that matches
## the live process list on the spawn id alone finds nothing, so a working run reads gone.
## Held, each case its own session in this rig's workspace, through the tooling's own read
## (`--intern-session-control --one --session-id <id>`) and the state word that call writes:
##   1. TWO IDS THAT DIFFER, the run alive: the state reads running. Red before the fix.
##   2. CONTROL, the record names a process that began at another time (a pid come round again), and no
##      process runs as the session: it does not read running, so the fix cannot make every session look alive.
##   3. CONTROL, TWO IDS THAT AGREE, the run alive: the state reads running, so the ordinary shape still reads.
## Offline: the rig's own ps lists this rig's runs, its own curl answers nothing, and every process it starts it ends.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || rigRefuse "the rig's store owner is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsJoinedRunReadsRunningCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigStores" "$rigHome" "$rigSkills" "$rigData/audit"
rigBoardStates "$rigData" running
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST, as the sibling session checks build it: the ps first on PATH answers a whole-host
## listing from this rig's list, and every other call goes to the real ps.
rigRealTool ps "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## The record of a run whose two ids differ, written the way the store writes one: the FILE is named by the
## session and lives in the session's own folder, while its `spawn-id` header holds the run.
rigRecJoined(){ ## session, spawn, status, extra record lines
	mkdir -p "$rigStores/$1" || return 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-11-26 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$1" "$2" "$rigHost" "$3" "${4:-}" "$1" | rigOwnerStore AgentsSpawnRecordWrite "$1" "$1"
}
rigRead(){ ## session -- the state word the tooling wrote for it, in rigState; the call's status in rigRc
	rm -f "$rigStores/$1/control/state" 2> /dev/null
	## The tooling holds its process list for 10 s, so each arm reads the list this arm wrote.
	rm -f "$rigWs/.local/temp/ps-args.txt" 2> /dev/null
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOp" --one --session-id "$1" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	rigState="$( LC_ALL=C sed -n 's/^state: //p' "$rigStores/$1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p' )"
}

## Stand-ins: real processes of this rig, each kept with when it began.
sleep 900 > /dev/null 2>&1 < /dev/null & rigPidA=$!
rigProcNote "$rigPidA" ; rigStarted="$rigStarted $rigPidA"
disown "$rigPidA" 2> /dev/null || :
rigStartA="$( LC_ALL=C ps -o lstart= -p "$rigPidA" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
[ -n "$rigStartA" ] || rigRefuse "the stand-in did not start, so nothing below would be measured"

rigJoined="joined-$rigTag" ; rigJoinedRun="run-$rigTag" ; rigReused="reused-$rigTag" ; rigReusedRun="reusedrun-$rigTag"
rigAgreeing="agreeing-$rigTag"

echo "-- 1. two ids that differ, the run alive, the process carrying the session id --"
printf '%s bash /rig/harness.sh --session-id %s --agent rig-member the brief\n' "$rigPidA" "$rigJoined" > "$rigTmp/ps.list"
rigRecJoined "$rigJoined" "$rigJoinedRun" spawn-started "run-process: $rigPidA $rigStartA
" || rigRefuse "the record of the joined run could not be written"
rigRead "$rigJoined"
rigAssert "a session whose ids differ and whose run is alive reads running" "$rigState" "running"

echo "-- 2. control: the record names a process that began at another time, and no process runs as the session --"
: > "$rigTmp/ps.list"
rigRecJoined "$rigReused" "$rigReusedRun" spawn-started "run-process: $rigPidA Thu_Jan__1_00:00:00_1970
" || rigRefuse "the record of the reused pid could not be written"
rigRead "$rigReused"
rigAssert "a pid come round again is not read as that run, and the session does not read running" "$rigState" ""

echo "-- 3. control: two ids that agree, the run alive --"
printf '%s bash /rig/harness.sh --session-id %s --agent rig-member the brief\n' "$rigPidA" "$rigAgreeing" > "$rigTmp/ps.list"
rigRecJoined "$rigAgreeing" "$rigAgreeing" spawn-started "run-process: $rigPidA $rigStartA
" || rigRefuse "the record of the agreeing run could not be written"
rigRead "$rigAgreeing"
rigAssert "a session whose ids agree and whose run is alive still reads running" "$rigState" "running"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "no stand-in of this check is left" "$( kill -0 "$rigPidA" 2> /dev/null && echo alive || echo gone )" "gone"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ JOINED RUN READS RUNNING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'JOINED_RUN_READS_RUNNING: OK (%d assertions, offline)\n' "$rigPasses"
