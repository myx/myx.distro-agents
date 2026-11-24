#!/usr/bin/env bash
## Behavioural check on the control thread of a session whose id is the own id of its first run. That is the shape of every session a start
## founds: a record that carries `session-id: X` and `spawn-id: X`. The thread reads the runs of its session from the session's kept list of
## records (AgentsToolsSessionControlRows, sh-lib/session/AgentsTools.InternSessionControl.include). A read that yields no run leaves the id
## to be taken for the own id of a run, and the thread refuses.
## Run rather than read, against a rig workspace built here. The store's owner writes the records. A ps first on PATH lists the rig's own runs.
## Stand-in processes have their own pids. A curl beside it only logs, and nothing may call it.
## Held:
##   1. ONE TICK BY HAND, --intern-session-control --one --session-id <founder>: status 0, no error, no refusal, and the state reads running.
##   2. CONTROL, THE OWN ID OF A RUN THAT JOINED THE SESSION: refused in one line naming its session, status 1, nothing written.
##      The refusal stays where it belongs, so the green of 1 is not the refusal removed.
##   3. THE THREAD, started by the console (--manager-session-control-start --session-id <founder>). Its pid file names the process the
##      console started. The state it wrote reads running. Its log holds its start and no refusal.
## Red where the rows are read through a field the paths of the kept list do not have: 1 and 3 fail, and 2 holds.
## Offline: only the rig's own tree is read or written, and this check ends every thread and stand-in it starts.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlOwnIdCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The ids of this run's sessions carry the name mktemp gave it. A copy of this check beside it then never counts this one's threads.
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/audit"
rigBoardStates "$rigData" running
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigStarted=""
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's list. A line is `<pid> <command line>`, listed only while it lives. Every other call goes to the real ps.
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
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigRec(){ ## run, session, status, closing lines (may be empty) -- the run's record, written by the store's owner into the folder of its session
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$3" "${4:-}" "$2" | rigOwnerStore AgentsSpawnRecordWrite "$1" "$2"
}
rigClosed='resolved-at: 2026-10-13 09:30 +0300
'
rigRc=0
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigSaid(){ ## fixed text -- how many lines of the last stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
rigState(){ ## session -- the word of its state file
	LC_ALL=C sed -n 's/^state: //p' "$rigStores/$1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p'
}
rigLogHas(){ ## session, fixed text -- how many lines of its log hold it
	LC_ALL=C grep -c -F -- "$2" "$rigStores/$1/control/log" 2> /dev/null || :
}

rigFounder="founder-$rigTag" ; rigJoined="joined-$rigTag"
rigRec "$rigFounder" "$rigFounder" spawn-started '' || rigRefuse "the record of the founder run could not be written"
## The founder's run, alive: a stand-in under its own pid that stands in the rig's process list by its --session-id word.
sleep 600 > /dev/null 2>&1 < /dev/null &
rigStandPid=$!
rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
disown "$rigStandPid" 2> /dev/null || :
printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$rigFounder" >> "$rigTmp/ps.list"

echo "-- 1. one tick by hand for a session whose id is the own id of its run --"
rigRun "$rigOp" --one --session-id "$rigFounder"
rigAssert "one tick: status 0, no error, and no refusal naming the own id of a run" "$rigRc:$( rigTroubles ):$( rigSaid 'is the own id of a run of session' )" "0:0:0"
rigAssert "it leaves its log and its state and no pid file and no lock, and the state reads running" \
	"$( ls -A "$rigStores/$rigFounder/control" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ):$( rigState "$rigFounder" )" "log state:running"

echo "-- 2. control: the own id of a run that joined the session is refused --"
rigRec "$rigJoined" "$rigFounder" spawn-succeeded "$rigClosed" || rigRefuse "the record of the joined run could not be written"
rigRun "$rigOp" --one --session-id "$rigJoined"
rigAssert "refused in one line that names its session, status 1, and no folder is made for it" \
	"$rigRc:$( rigTroubles ):$( rigSaid "'$rigJoined' is the own id of a run of session $rigFounder" ):$( [ -e "$rigStores/$rigJoined" ] && echo folder || echo none )" "1:1:1:none"

echo "-- 3. the thread the console starts holds the session --"
rm -f "$rigStores/$rigFounder/control/state"
rigRun --manager-session-control-start --session-id "$rigFounder"
rigStartedPid="$( LC_ALL=C awk -F'\t' '$1 == "control" { print $4 ; }' "$rigTmp/out" )"
rigAssert "the console answers started, with the process, status 0" \
	"$rigRc:$( LC_ALL=C sed -n '$=' "$rigTmp/out" ):$( LC_ALL=C tr '\t' '|' < "$rigTmp/out" | LC_ALL=C sed 's/|[0-9][0-9]*|/|PID|/' )" "0:1:control|$rigFounder|started|PID|-"
rigWaitLeft=50
while [ "$( rigState "$rigFounder" )" != running ] && [ "$rigWaitLeft" -gt 0 ] ; do sleep 0.2 ; rigWaitLeft=$(( rigWaitLeft - 1 )) ; done
rigAssert "the pid file of the session holds the process the console started with when it began, and the state it wrote reads running" \
	"$( cat "$rigStores/$rigFounder/control/pid" 2> /dev/null ):$( rigState "$rigFounder" )" "$( rigProcBegan "$rigStartedPid" ):running"
rigAssert "its log holds its start and no refusal" \
	"$( rigLogHas "$rigFounder" "the control thread of session $rigFounder runs as pid $rigStartedPid, a tick every 1s" ):$( rigLogHas "$rigFounder" 'is the own id of a run of session' )" "1:0"

echo "-- 4. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "no process of this host shows as a thread of a session of this check" \
	"$( "$rigTmp/bin/ps.real" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "--intern-session-control --run --session-id [a-z0-9]+-$rigTag\$" || : )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL OWN ID CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_OWN_ID: OK (%d assertions, offline)\n' "$rigPasses"
