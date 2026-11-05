#!/usr/bin/env bash
## Behavioural check on S5.6: a session-control loop ends when its session has no live agent,
## and it ends the runs nobody else will end. Held, each case its own session in this rig's
## workspace, with SESSION_CONTROL_TICK_SECONDS=1 and SESSION_CONTROL_CLOSING_SECONDS=2:
##   1. A record `spawn-started` carrying `killed-by` and `killed-at`, its run's process gone:
##      the loop closes the record and ends. (Cause: AgentsTools.InternSessionControl.include:695
##      never treats a killed record as a death, so nothing settles it and the loop stays.)
##   2. A record `spawn-started`, its run's process gone, its supervising shell alive past the
##      closing time: the loop closes the record and ends. (Cause: :698 reads a live
##      supervising shell as "being closed", with no bound.)
##   3. A run alive whose dispatch item waits in review past REVIEW_WAIT_LIMIT, with nobody to
##      read its handback: the tooling ends the run after that limit and the closing time, and
##      then the loop. REVIEW_WAIT_LIMIT already bounds a handed-back run, inside its own Wait;
##      this rig sets it to 2 seconds.
##   4. A run alive whose dispatch item is already accepted (in board/processed): the tooling ends
##      the run, and then the loop.
##   5. Control: a run alive with no handback past any limit, its item open. The loop stays.
## The setting name in case 3 is REVIEW_WAIT_LIMIT, which bounds a handed-back run already.
## Red before S5.6: cases 1 to 4 all fail, and cases 0 and 5 pass.
## Offline: every tree is the rig's own; the fake curl answers every send with a refusal and
## opens no socket; every process this check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPkg/sh-test/check-fixtures/rig-blocking-stand-in.include.sh" || rigRefuse "the rig's blocking stand-in is missing from the package"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlEndsNoAgentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
## A loop this check keeps alive, and the subshell that waits on it, are ended here, from the note file: the
## rigLoop runs inside a command substitution, so nothing it notes reaches this shell's own trap. The notes are
## taken for this shell's own, and then ONE signal covers the loop pids and the stand-ins together: $rigPids holds
## the stand-ins alone, so the loop pids are read from the note file and named in that same call.
rigStopAll(){ rigLoops="$( PATH="$rigProcPath" LC_ALL=C awk 'NF == 2 && $1 ~ /^[0-9]+$/ { print $1 }' "$rigTmp/loops.note" 2> /dev/null )" ; rigProcNoteFrom "$rigTmp/loops.note" 2> /dev/null ; rigProcSignalWithChildren KILL $rigLoops $rigPids ; rm -rf -- "$rigTmp" ; }
trap rigStopAll EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigTmp/bin" "$rigTmp/home"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSESSION_CONTROL_TICK_SECONDS=1\nSESSION_CONTROL_CLOSING_SECONDS=2\nREVIEW_WAIT_LIMIT=2\nNO_PROXY=*\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
## The rig's skillset root, holding the members the death notices are posted as and to. A notice is
## refused before it leaves when its own member has no skill folder, and a death whose notice cannot
## be posted is not settled: the record then stays open and the loop stays with it.
mkdir -p "$rigTmp/skills/human-owner" "$rigTmp/skills/keeper-myx"
printf -- '---\nname: human-owner\n---\nrig human owner\n' > "$rigTmp/skills/human-owner/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/human-owner/human-owner.basic.md"
printf -- '---\nname: keeper-myx\n---\nrig keeper\n' > "$rigTmp/skills/keeper-myx/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/keeper-myx/keeper-myx.basic.md"
## Every send is answered here and no socket is opened: the notice of a death is told, and this rig
## never reaches Slack. A curl that refuses would leave the death unsettled, which is another case.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
cat > /dev/null
printf '{"ok":true,"ts":"1793659000.000001","channel":"CRIG00001"}'
exit 0
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A process that stands for a run: its own words carry the spawn id the tooling reads a run by. It blocks on a pipe
## this check holds, so it costs no wake-up a second and ends by itself when the check does, however the check ends.
rigStandIn(){ ## spawn id -- starts it; sets rigStandPid, and keeps it for the trap
	rigBlockingStandIn "$1" || rigRefuse "the stand-in for $1 could not be started"
	rigPids="$rigPids $rigStandPid"
}
rigStarted(){ ## pid -- the start word a record keeps for it
	LC_ALL=C ps -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit }'
}
rigAlive(){ kill -0 "$1" 2> /dev/null && printf alive || printf gone ; }
rigRecord(){ ## session id, spawn id, status, extra header lines
	mkdir -p "$rigWs/.local/agents/spawned/$2"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\nstarted-at: 2026-11-01 00:00 +0000\n' \
			"$1" "$2" "$2" "$rigHost" "$3"
		[ -z "${4:-}" ] || printf '%s\n' "$4"
		printf -- '---\n\n# rig spawn: %s\n' "$2"
	} > "$rigWs/.local/agents/spawned/$2/$2.spawn.md"
}
rigRecordStatus(){ ## spawn id -- the status word of its record
	LC_ALL=C sed -n 's/^status: //p' "$rigWs/.local/agents/spawned/$1/$1.spawn.md" 2> /dev/null | head -1 ;
}
rigOpenWord(){ ## record status -- `open` or `closed`
	case "$1" in spawn-started) printf 'open' ;; *) printf 'closed' ;; esac
}
## One control loop, run and bounded: rc unknown, so the loop's own end is the measurement.
rigLoop(){ ## session id, bound seconds -- the bound reached prints reached
	local loopSession="$1" loopBound="$2" loopPid loopWaited=0
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_SKILLSET_ROOT="$rigTmp/skills" \
			bash "$rigFn" --intern-session-control --run --session-id "$loopSession"
	) > "$rigTmp/loop-$loopSession.out" 2>&1 &
	loopPid=$!
	## The note goes in a file, not in this shell's own: this function is called inside a command
	## substitution, so nothing it sets reaches the caller's trap. The subshell that waits, and the
	## loop it waits on, are noted: ending either ends the sleep it holds at that moment.
	rigProcNoteFile "$rigTmp/loops.note" "$( exec sh -c 'echo "$PPID"' )" "$loopPid"
	disown "$loopPid" 2> /dev/null || :
	while [ "$loopWaited" -lt "$loopBound" ] && kill -0 "$loopPid" 2> /dev/null ; do
		sleep 1 ; loopWaited=$(( loopWaited + 1 ))
	done
	if kill -0 "$loopPid" 2> /dev/null ; then printf 'reached' ; else printf 'ended' ; fi
}

echo "-- 0. control, and the instrument's known positive: a session whose records are closed ends its loop --"
## Without this the three `ended` assertions below would be equally consistent with a bound the loop
## can never reach; here the same measurement comes out `ended` on a session that has nothing to watch.
rigRecord rig-closed rig-closed-run spawn-succeeded
rigAssert "0. the loop ends on a session with every record closed" "$( rigLoop rig-closed 30 )" ended

echo "-- 1. a killed record with no live process is closed, and the loop ends (S5.6) --"
rigRecord rig-killed rig-killed-run spawn-started "killed-by: magic-coordinator
killed-at: 2026-11-01 00:10 +0000"
rigAssert "1. the loop ends once the record is closed" "$( rigLoop rig-killed 30 )" ended
rigAssert "1. the record is closed" "$( rigOpenWord "$( rigRecordStatus rig-killed-run )" )" closed

echo "-- 2. a record whose supervising shell outlives it is closed after the closing time --"
rigStandIn rig-sup-$$ ; rigSupervisor="$rigStandPid"
rigRecord rig-sup rig-sup-run spawn-started "supervisor-process: $rigSupervisor $( rigStarted "$rigSupervisor" )"
rigAssert "2. the loop ends once the record is closed" "$( rigLoop rig-sup 30 )" ended
rigAssert "2. the record is closed" "$( rigOpenWord "$( rigRecordStatus rig-sup-run )" )" closed

echo "-- 3. a handed-back run whose item waits in review past the limit is ended, and then the loop --"
rigStandIn rig-handback-run ; rigRun3="$rigStandPid"
rigRecord rig-handback rig-handback-run spawn-started "run-process: $rigRun3 $( rigStarted "$rigRun3" )
spawns: dispatch-rig-handback"
mkdir -p "$rigWs/.local/agents/sessions/rig-handback"
printf '1700000000 handback\n' > "$rigWs/.local/agents/sessions/rig-handback/milestones"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-review\nspawn-id: rig-handback-run\nreview-by: magic-coordinator\nreview-since-epoch: 1000\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
	> "$rigData/board/review/dispatch-rig-handback.md"
rigAssert "3. the loop ends" "$( rigLoop rig-handback 30 )" ended
rigAssert "3. the run it waited on is ended" "$( rigAlive "$rigRun3" )" gone
rigAssert "3. and its record is closed" "$( rigOpenWord "$( rigRecordStatus rig-handback-run )" )" closed

echo "-- 4. an accepted item ends its runs, and then the loop --"
rigStandIn rig-accepted-run ; rigRun4="$rigStandPid"
rigRecord rig-accepted rig-accepted-run spawn-started "run-process: $rigRun4 $( rigStarted "$rigRun4" )
spawns: dispatch-rig-accepted"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-processed\nspawn-id: rig-accepted-run\n---\n\n# rig dispatch\n\n## Decisions\n\n- 2026-11-02T00:00:00Z verdict: accepted: rig work\n' \
	> "$rigData/board/processed/dispatch-rig-accepted.md"
rigAssert "4. the loop ends" "$( rigLoop rig-accepted 30 )" ended
rigAssert "4. the accepted item's run is ended" "$( rigAlive "$rigRun4" )" gone
rigAssert "4. and its record is closed" "$( rigOpenWord "$( rigRecordStatus rig-accepted-run )" )" closed

echo "-- 5. control: a live run with no handback, its item open, leaves the loop and the run alone --"
rigStandIn rig-live-run ; rigRun5="$rigStandPid"
rigRecord rig-live rig-live-run spawn-started "run-process: $rigRun5 $( rigStarted "$rigRun5" )
spawns: dispatch-rig-live"
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: rig-live-run\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
	> "$rigData/board/running/dispatch-rig-live.md"
rigAssert "5. the loop stays" "$( rigLoop rig-live 12 )" reached
rigAssert "5. and the run is left alive" "$( rigAlive "$rigRun5" )" alive
rigAssert "5. with its record still open" "$( rigOpenWord "$( rigRecordStatus rig-live-run )" )" open

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ SESSION_CONTROL_ENDS_NO_AGENT CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'SESSION_CONTROL_ENDS_NO_AGENT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
