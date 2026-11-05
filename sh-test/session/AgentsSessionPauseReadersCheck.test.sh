#!/usr/bin/env bash
## Behavioural check on S19.3: the control and monitor threads read the paused state S19.1 writes. A paused run is never
## judged stuck, dead or idle, and nothing restarts or ends it while it holds; the session says so in its chat and in the
## duty's scan. And the two marks that wait on this state are wired to it: S6.37's `double_vertical_bar` on the session's
## root message, and S13.18's `paused=` signal with its `waiting` verdict. Held:
##   1. the pause operation writes the one flag every reader below asks, and no other
##   2. S13.18: `--supervise-scan` reads `paused=yes` and `waiting` for a run a pause holds, however old its last tool call,
##      and the control, with no flag, reads `paused=no` and `active`
##   3. the registry derives `paused` for it, and the control thread's own judging keeps the session `running`, so no thread
##      calls it finished and none restarts it
##   4. S6.37: the pause mark goes on the session's root message for exactly that flag, and comes off when it goes
##   5. the release step of the control thread ends no run a pause holds
##   6. the work-duty scan says the session is paused, and reads no run of it as stuck
##   7. a resume clears all of it: the scan is active again and the mark is taken off
## Red before S19: the flag had no writer, so every reader below was answered by a file made by hand here, and the two marks
## were never reached from a real pause.
## Offline: a rig workspace, its stores, a Slack answered by a curl first on PATH, and a rig process list. No socket.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigScanFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigScanFn" "$rigPkg/sh-lib/session/AgentsTools.SessionPause.include" ; do
	[ -f "$rigFile" ] || rigRefuse "a file this check measures is not at the origin: $rigFile"
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionPauseReadersCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
rigSlack="$rigTmp/slack"
rigSp="$rigWs/.local/agents/spawned"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigHome" "$rigSkills/magic-team" "$rigSp" "$rigStores" \
	"$rigData/board/running" "$rigSlack" || rigRefuse "the rig could not be made: $rigTmp"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-team/magic-team.basic.md"
mkdir -p "$rigSkills/magic-developer"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-developer/magic-developer.basic.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

## THE RIG'S SLACK, for the pause mark: no socket, each reaction kept as `<method> <ts> <name>`.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigDir="${0%/*}/../slack"
rigMethod="" rigTs="" rigName="" rigChannel=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		timestamp@*) rigTs="$( cat "${rigArg#timestamp@}" 2> /dev/null )" ;;
		name@*) rigName="$( cat "${rigArg#name@}" 2> /dev/null )" ;;
	esac
done
cat > /dev/null 2>&1 || :
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	reactions.add|reactions.remove) printf '%s %s:%s %s\n' "$rigMethod" "$rigChannel" "$rigTs" "$rigName" >> "$rigDir/react" ; printf '{"ok":true}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the rig's curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSESSION_CONTROL_TICK_SECONDS=1\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
## THE RIG'S OWN PROCESS LIST: a run of this rig is one of its stand-ins, never a process of this host.
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
exec /bin/ps "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## One call as a console of this rig.
rigCall(){
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_READER=off MDAT_TEAM_DATA_COMMIT_THREAD=off RIG_SCENARIO="$rigSlack" \
		bash "$@" ) < /dev/null 2>&1
}
## A session of this rig, with one run whose record names both its own and the session's id.
rigSession(){ ## session id, run id, the session's root message (may be empty)
	mkdir -p "$rigStores/$1" "$rigSp/$2" || rigRefuse "the session could not be made: $1"
	[ -z "${3:-}" ] || printf '%s\n' "$3" > "$rigStores/$1/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nstart-context: spawned\ntracking-name: %s\nhost: %s\nowner: magic-developer\nstatus: spawn-started\nspawns: dispatch-%s.md\n---\n' \
		"$1" "$2" "$2" "$rigHost" "$2" > "$rigSp/$2/$2.spawn.md"
}
## A stand-in for a run's process, in the rig's own list as the run of that id.
rigStand(){ ## run id
	local standPid
	sleep 600 > /dev/null 2>&1 < /dev/null &
	standPid=$!
	rigProcNote "$standPid" ; rigStarted="$rigStarted $standPid"
	disown "$standPid" 2> /dev/null || :
	printf '%s claude --session-id %s --agent rig the brief\n' "$standPid" "$1" >> "$rigTmp/ps.list"
}
## The rig's own activity mark for a run, and a tool line old enough that a stuck verdict would be due without the pause.
rigMarkOld(){ ## run id -- its own store keeps the mark, as a harness run writes it
	mkdir -p "$rigStores/$1"
	printf '1 %s tool Bash\n' "$(( $( date -u +%s ) - 1800 ))" > "$rigStores/$1/activity"
}
rigScan(){ ## -- the supervisor's scan of this rig
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigScanFn" --supervise-scan --workspace "$rigWs" ) 2>&1
}
rigRunWord(){ ## run id, field -- that field of its `run` line
	rigScan | LC_ALL=C awk -v want="$1" -v field="$2" '$1 == "run" && $3 == want { print $field }' | head -1
}
rigDerived(){ ## run id -- the registry's own word for it
	rigWantRun="$1"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsRegistryRenderSpawnedSessions agents' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" ) 2>&1 \
		| LC_ALL=C awk -v want="$rigWantRun" 'NF == 13 && $8 == want { print $13 }' | head -1
}
rigJudged(){ ## session id -- what the control thread's own judging says of it
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; . "$2" ; AgentsToolsRegistryRenderSpawnedSessions agents | LC_ALL=C awk "NF == 13 && \$2 != \"-\"" | AgentsToolsSessionControlJudged' \
			rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" "$rigPkg/sh-lib/session/AgentsTools.SessionControlStart.include" ) 2>&1 \
		| LC_ALL=C awk -v want="$1" '$1 == want { print $2 }' | head -1
}
rigReacted(){ LC_ALL=C tr '\n' ' ' < "$rigSlack/react" 2> /dev/null || : ; }
rigSection(){ : > "$rigSlack/react" ; }

rigSession pause-sess pausrun "CHAIR019:1700000000.000900"
rigStand pausrun
rigMarkOld pausrun
rigSession free-sess freerun "CHAIR019:1700000000.001000"
rigStand freerun
rigMarkOld freerun
sleep 1

echo "-- 2. with no pause: the scan reads the control, and the run is stuck by its own old tool call --"
rigAssert "the control run reads paused=no" "$( rigRunWord freerun 8 )" "paused=no"
rigAssert "and its old tool call is what the scan says of it" "$( rigRunWord freerun 5 )" "stuck"

echo "-- 1. the pause operation writes the flag every reader above asks --"
rigPauseRow="$( rigCall "$rigTool" --manager-session-pause --session-id pause-sess )"
rigAssert "the pause names the flag it wrote" "$( printf '%s\n' "$rigPauseRow" | LC_ALL=C awk -F'\t' '$1 == "pause" { print $1 }' )" "pause"
rigAssert "and that is the file the readers ask of" "$( printf '%s\n' "$rigPauseRow" | LC_ALL=C awk -F'\t' '$1 == "pause" { print $3 }' | LC_ALL=C sed "s|$rigWs|WS|" )" "WS/.local/agents/sessions/pause-sess/paused"

echo "-- 2b. S13.18's paused signal and verdict --"
rigAssert "the scan reads the run a pause holds as paused" "$( rigRunWord pausrun 8 )" "paused=yes"
rigAssert "and it waits, whatever its last tool call says" "$( rigRunWord pausrun 5 )" "waiting"
rigAssert "the control beside it is unchanged" "$( rigRunWord freerun 8 )" "paused=no"

echo "-- 3. the registry, and the control thread's own judging --"
rigAssert "the registry derives the word paused for the held run" "$( rigDerived pausrun )" "paused"
rigAssert "the thread judges its session running, so nothing calls it finished" "$( rigJudged pause-sess )" "running"
rigAssert "and the control beside it derives its own activity word, never paused" "$( rigDerived freerun )" "tool"

echo "-- 4. S6.37's pause mark is placed for that same flag --"
rigInRig(){
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" SLACK_BOT_TOKEN=rig-bot-token-TEAM RIG_SCENARIO="$rigSlack" \
		bash -c '. "$1" ; shift ; "$@"' rig "$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include" "$@" ) 2>&1
}
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks pause-sess > /dev/null
rigAssert "the pause mark goes on the session's root message" "$( rigReacted )" "reactions.add CHAIR019:1700000000.000900 double_vertical_bar "
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks pause-sess > /dev/null
rigAssert "and is asked for once, not at every tick" "$( rigReacted )" ""

echo "-- 5. the release step ends no run a pause holds --"
## The guard the release step asks, in both directions, in this rig: the flag is the answer, not the item's state.
rigPauseHeld(){ ## run id, session id -- the question the release step asks, as the tooling asks it
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsSessionPauseHeld "$2" "$3" && printf held || printf free' rig "$rigPkg/sh-lib/session/AgentsTools.SessionPause.include" "$1" "$2" ) 2>&1
}
rigAssert "the release step's own guard says held while the flag stands" "$( rigPauseHeld pausrun pause-sess )" "held"
## A run whose dispatch item is processed, with the flag standing: the release step reaches it and turns away.
mkdir -p "$rigStores/pause-sess/control" "$rigData/board/processed"
printf -- '---\ntype: dispatch\nowner: magic-developer\nstatus: dispatch-processed\nspawn-id: pausrun\nsession-id: pause-sess\n---\n' > "$rigData/board/processed/dispatch-pausrun.md"
rigRelease(){ ## -- one pass of the release step over the paused run, as the control thread makes it
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1" ; . "$2" ; controlDir="$3" ; controlClosing=0 ; controlRows="$( printf "pausrun %s - %s magic-developer spawn-started - pausrun - - %s - running - -\n" pause-sess "$rigHost" "$rigWs" )" ; AgentsToolsSessionControlRelease' \
			rig "$rigPkg/sh-lib/session/AgentsTools.SessionControlStart.include" "$rigPkg/sh-lib/session/AgentsTools.SessionControlRelease.include" "$rigStores/pause-sess/control" ) > /dev/null 2>&1
}
rigRelease
rigAssert "a paused run whose item is processed is left alone: no release mark" "$( ls "$rigStores/pause-sess/control"/release.* 2> /dev/null | wc -l | tr -d ' ' )" "0"
rm -f "$rigStores/pause-sess/paused"
rigAssert "and with the flag gone the same guard says free, so the pause is what turned it away" "$( rigPauseHeld pausrun pause-sess )" "free"
rm -f "$rigStores/pause-sess/control"/release.*
rigCall "$rigTool" --manager-session-pause --session-id pause-sess > /dev/null 2>&1

echo "-- 6. the duty's scan says the session is paused --"
rigDutyScan(){ ## -- the work-duty scan as the paused session runs it
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SESSION_ID=pause-sess MDAT_SCAN_SEED_QUIET=1 MDAT_COMMS_READER=off \
		bash "$rigTool" --intern-op-work-duty-input-scan magic-developer --session-id pause-sess ) 2>&1
}
rigAssert "the scan says the session is paused" "$( rigDutyScan | LC_ALL=C grep -c 'session pause-sess is paused' )" "1"

echo "-- 7. a resume clears it everywhere --"
rigResumeRow="$( rigCall "$rigTool" --manager-session-resume --session-id pause-sess )"
rigAssert "the resume says a flag stood, and removed it" "$( printf '%s\n' "$rigResumeRow" | LC_ALL=C awk -F'\t' '$1 == "resume" { print $1, $4 }' )" "resume resumed"
rigAssert "the scan reads the run as it reads the control now: not paused, and its own old tool call again" "$( rigRunWord pausrun 8 ):$( rigRunWord pausrun 5 )" "paused=no:$( rigRunWord freerun 5 )"
rigAssert "the registry derives its own activity word again" "$( rigDerived pausrun )" "tool"
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks pause-sess > /dev/null
rigAssert "the pause mark comes off the root message" "$( rigReacted )" "reactions.remove CHAIR019:1700000000.000900 double_vertical_bar "
rigAssert "and the duty's scan says nothing of a pause" "$( rigDutyScan | LC_ALL=C grep -c 'is paused' )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PAUSE READERS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PAUSE_READERS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
