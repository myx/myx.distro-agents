#!/usr/bin/env bash
## Behavioural check on a session whose record reads settled while its process still works.
## A run that writes `spawn-ended-without-close` and leaves its process alive reads `finished` by the
## record's status alone, so every reader of the registry shows a working run as one that has ended.
## Held, each case its own session in this rig's workspace, through the tooling's own read
## (`--intern-session-control --one --session-id <id>`) and the state word that call writes:
##   1. SETTLED RECORD, THE PROCESS STILL RUNS: the state reads running. Red before the fix.
##   2. CONTROL, THE SAME SETTLED RECORD WITH ITS PROCESS GONE: it reads finished, never running, so a
##      settled record is still read as settled once its process really has gone.
##   3. CONTROL, AN OPEN RECORD AND ITS PROCESS ALIVE: the state reads running, as before the fix.
## Offline: the rig's own ps lists this rig's runs, its own curl answers nothing, and every process
## it starts it ends.
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
rigTmp="$( rigTempDir AgentsSettledRecordLiveRunCheck )" || exit 1
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

## THE RIG'S OWN PROCESS LIST, as the sibling session checks build it: the ps first on PATH answers a
## whole-host listing from this rig's list, and every other call goes to the real ps.
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

rigSettled="settled-$rigTag" ; rigSettledRun="settledrun-$rigTag" ; rigDeadRun="deadrun-$rigTag"
rigOpen="open-$rigTag"

echo "-- 1. a settled record whose process still runs --"
printf '%s bash /rig/harness.sh --session-id %s --agent rig-member the brief\n' "$rigPidA" "$rigSettled" > "$rigTmp/ps.list"
rigRecJoined "$rigSettled" "$rigSettledRun" spawn-ended-without-close "run-process: $rigPidA $rigStartA
" || rigRefuse "the record of the settled run could not be written"
rigRead "$rigSettled"
rigAssert "a settled record whose own process still runs reads running" "$rigState" "running"

echo "-- 2. control: the same settled status, its process gone --"
: > "$rigTmp/ps.list"
rigRecJoined "$rigDeadRun" "$rigDeadRun" spawn-ended-without-close "run-process: $rigPidA Thu_Jan__1_00:00:00_1970
" || rigRefuse "the record of the settled dead run could not be written"
rigRead "$rigDeadRun"
rigAssert "a settled record whose process is gone reads finished, never running" "$rigState" "finished"

echo "-- 3. control: an open record and its process alive --"
printf '%s bash /rig/harness.sh --session-id %s --agent rig-member the brief\n' "$rigPidA" "$rigOpen" > "$rigTmp/ps.list"
rigRecJoined "$rigOpen" "$rigOpen" spawn-started "run-process: $rigPidA $rigStartA
" || rigRefuse "the record of the open run could not be written"
rigRead "$rigOpen"
rigAssert "an open record whose run is alive still reads running" "$rigState" "running"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "no stand-in of this check is left" "$( kill -0 "$rigPidA" 2> /dev/null && echo alive || echo gone )" "gone"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SETTLED RECORD LIVE RUN CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SETTLED_RECORD_LIVE_RUN: OK (%d assertions, offline)\n' "$rigPasses"
