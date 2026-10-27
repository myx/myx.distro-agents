#!/usr/bin/env bash
## Behavioural check: a kill from the console and a member's TaskStop of a run leave the control thread of its
## session alive (--intern-session-control). The thread is what reports the end of that run, and the id of a
## session is its founder's own run id: the command line of the thread carries that very id, as
## `--session-id <id>`, the word a run is told by. Run rather than read, in a rig workspace built here: two
## sessions, each with a founder, a participant and a real control thread, whose own command line stands in the
## rig's process list beside the stand-ins of the runs.
## Held, for the founder's run and for a participant's:
##   1. TaskStop of a run, through its dispatch item and by its own id, ends the process of that run and no other:
##      the thread lives, holds its session, and its log knows no end.
##   2. The kill of one run from the console, and then of the whole session, ends the runs, and the thread lives.
## Red where a reader finds the processes of a run by the id as a part of any command line: the thread is then
## ended in order by the TERM meant for the run. Offline: a curl first on PATH only logs and nothing may call it;
## every thread and stand-in of this check is ended by it, through the rig's helpers.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's helper for control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlStopKillCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigStarted=""
trap 'rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH to hand the other calls to"
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
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo rig ; exit 0 ; }\nexec "${0%%/*}/id.real" "$@"\n' > "$rigTmp/bin/id"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/id" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in keeper-rig keeper-myx magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## The person at the console, `user-<account>`: the runs below report to it, so its kills hold the
## authority to end them (F6.10, AgentsTools.Authority.include).
rigConsoleUser="user-$( printf '%s' "$( id -un 2>/dev/null )" | LC_ALL=C tr -s ' \t\r\n' '_' )"
rigRec(){ ## run id, which is its sandbox too; session id; member
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\nspawns: dispatch-%s\nreports-to: %s\n---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$3" "$1" "${rigReportsTo:-$rigConsoleUser}" "$2" > "$rigSp/$1/$1.spawn.md"
	printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: %s\nsession-id: %s\n---\n\n# rig dispatch\n' "$3" "$1" "$2" > "$rigData/board/running/dispatch-$1.md"
}
## A stand-in process that only waits, in the rig's process list as the run of that id, by its own --session-id word.
rigStandPid=""
rigStand(){ ## run id
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigCall(){ ## NAME=value words, then a command -- in the rig workspace, as a bare console, or as the session those words name
	local callWords=()
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) callWords[${#callWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		${callWords[@]+"${callWords[@]}"} "$@" ) < /dev/null
}
## The real thread of a session, listed in the rig's process list under its own command line. Sets rigThreadPid.
rigThreadPid=""
rigThread(){ ## session id
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --intern-session-control --run --session-id "$1" ) > "$rigTmp/thread.$1.out" 2> "$rigTmp/thread.$1.err" < /dev/null &
	rigThreadPid=$!
	rigProcNote "$rigThreadPid" ; rigStarted="$rigStarted $rigThreadPid"
	disown "$rigThreadPid" 2> /dev/null || :
	rigWaitFor 20 rigHolds "$1" "$rigThreadPid" || rigRefuse "the thread of $1 did not start, so nothing below would be measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/thread.$1.err" | cut -c1-600 )"
	printf '%s %s\n' "$rigThreadPid" "$( LC_ALL=C "$rigTmp/bin/ps.real" -ww -o args= -p "$rigThreadPid" )" >> "$rigTmp/ps.list"
}
rigHolds(){ ## session id, pid -- the pid file of the session names that pid
	local holdsLine=""
	{ IFS= read -r holdsLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holdsLine" ] && [ "${holdsLine%% *}" = "$2" ]
}
rigThreadIs(){ ## session id, pid -- alive, holding its session, and its log knows no end
	sleep 2
	printf '%s:%s:%s' "$( rigEnded "$2" && echo ended || echo alive )" "$( rigHolds "$1" "$2" && echo holds || echo lost )" "$( LC_ALL=C grep -c -F -- ', ends: ' "$rigStores/$1/control/log" 2> /dev/null )"
}

echo "-- 1. a member's TaskStop of a run leaves the control thread of its session alive --"
## Stopped by a member's TaskStop: these runs report to that member, magic-coordinator (F6.10).
rigReportsTo=magic-coordinator
rigRec fa-run fa-run keeper-rig ; rigStand fa-run ; rigFa="$rigStandPid"
rigRec pa-run fa-run keeper-myx ; rigStand pa-run ; rigPa="$rigStandPid"
rigReportsTo=""
rigThread fa-run ; rigThreadA="$rigThreadPid"
rigAssert "control: the command line of the thread stands in the rig's process list and carries the id of the founder's run as its --session-id word" \
	"$( LC_ALL=C grep -c -E "^$rigThreadA .*--intern-session-control --run --session-id fa-run\$" "$rigTmp/ps.list" )" "1"
printf '%s\n' '{"task_id":"pa-run"}' > "$rigTmp/stop.args"
rigCall MDAT_SPAWN_AGENT=magic-coordinator bash -c 'exec bash "$0" --intern-tool TaskStop < "$1"' "$rigHarness" "$rigTmp/stop.args" > "$rigTmp/stop-pa.out" 2>&1
rigWaitFor 20 rigEnded "$rigPa"
rigAssert "TaskStop of a participant, by its own run id: its process is ended, the founder's is not, and the thread lives, holds its session, and its log knows no end" \
	"$( rigEnded "$rigPa" && echo stopped || echo runs ):$( rigEnded "$rigFa" && echo stopped || echo runs ):$( rigThreadIs fa-run "$rigThreadA" )" "stopped:runs:alive:holds:0"
printf '%s\n' '{"task_id":"dispatch-fa-run.md"}' > "$rigTmp/stop.args"
rigCall MDAT_SPAWN_AGENT=magic-coordinator bash -c 'exec bash "$0" --intern-tool TaskStop < "$1"' "$rigHarness" "$rigTmp/stop.args" > "$rigTmp/stop-fa.out" 2>&1
rigWaitFor 20 rigEnded "$rigFa"
rigAssert "TaskStop of the founder, through its dispatch item: its process is ended, and the thread, whose command line carries that id, lives, holds its session, and its log knows no end" \
	"$( rigEnded "$rigFa" && echo stopped || echo runs ):$( rigThreadIs fa-run "$rigThreadA" )" "stopped:alive:holds:0"
rigAssert "control: both stops were made and said so" "$( LC_ALL=C grep -c -e 'STOPPED' -e 'TERM was sent' "$rigTmp/stop-pa.out" "$rigTmp/stop-fa.out" | LC_ALL=C awk -F: '$NF >= 1 { saidCount++ } END { print saidCount + 0 }' )" "2"

echo "-- 2. a kill from the console leaves the control thread of the session alive --"
rigRec fb-run fb-run keeper-rig ; rigStand fb-run ; rigFb="$rigStandPid"
rigRec pb-run fb-run keeper-myx ; rigStand pb-run ; rigPb="$rigStandPid"
rigThread fb-run ; rigThreadB="$rigThreadPid"
rigCall bash "$rigTool" --manager-session-kill --session-id pb-run --run > "$rigTmp/kill-pb.out" 2> "$rigTmp/kill-pb.err"
rigWaitFor 20 rigEnded "$rigPb"
rigAssert "the kill of one participant from the console: its process is ended, the founder's is not, and the thread lives, holds its session, and its log knows no end" \
	"$( rigEnded "$rigPb" && echo killed || echo runs ):$( rigEnded "$rigFb" && echo killed || echo runs ):$( rigThreadIs fb-run "$rigThreadB" )" "killed:runs:alive:holds:0"
rigCall bash "$rigTool" --manager-session-kill --session-id fb-run > "$rigTmp/kill-fb.out" 2> "$rigTmp/kill-fb.err"
rigWaitFor 20 rigEnded "$rigFb"
rigWaitFor 20 rigEnded "$rigThreadB"
rigAssert "the kill of the whole session, by the id of its founder: the founder's process is ended, and the thread is ended by no signal meant for a run: the kill finished the session, so the thread ended by itself, in order, and its log says why" \
	"$( rigEnded "$rigFb" && echo killed || echo runs ):$( rigEnded "$rigThreadB" && echo ended || echo alive ):$( LC_ALL=C grep -c -F -- ', ends: its session is finished' "$rigStores/fb-run/control/log" 2> /dev/null ):$( LC_ALL=C grep -c -F -- 'it was ended by' "$rigStores/fb-run/control/log" 2> /dev/null )" "killed:ended:1:0"
rigAssert "control: the killed runs are marked on their records, so the thread takes neither for a death" \
	"$( LC_ALL=C grep -l -e '^killed-by: rig$' "$rigSp/fb-run/fb-run.spawn.md" "$rigSp/pb-run/pb-run.spawn.md" 2> /dev/null | LC_ALL=C grep -c . ):$( [ -e "$rigStores/fb-run/control/dead" ] && echo dead-kept || echo none )" "2:none"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

echo ""
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL STOP KILL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a stop or a kill of a run reaches the control thread of its session, which is what reports the end of that run" >&2
	echo "  fix:  the one rule a run is told by (AgentsToolsRegistryRunWords, myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include): the thread is no run -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_CONTROL_STOP_KILL: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
