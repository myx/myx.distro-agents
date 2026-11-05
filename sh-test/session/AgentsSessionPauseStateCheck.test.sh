#!/usr/bin/env bash
## Behavioural check on S19.1: a session, or one run of it, has a real paused state. The console's own operations
## `--manager-session-pause` and `--manager-session-resume` write and remove it, the registry derives the word `paused`
## for a live run that is held, `ListAgents` shows and filters it, and the console's counter of paused sessions counts
## the sessions that hold one. Held:
##   1. a pause writes `sessions/<id>/paused`, holding `<when> <by>`, and resume removes it; a resume of a session that
##      is not paused is no fault
##   2. an id this workspace keeps no folder for is refused, and so is one that is no id: nothing is written
##   3. the registry derives `paused` for a live run, whether the flag stands on its own folder or on its session's,
##      and the run reads its activity word again once the pause ends
##   4. `ListAgents` shows the word, and `--state paused` keeps exactly the paused runs
##   5. the console's counter of paused sessions counts the sessions that hold one, and reads 0 again after a resume
##   6. a run's own id pauses that run alone, and its session's other run is untouched
## Red before S19: no operation writes the flag at all, and the registry has no word for it.
## Offline: a rig workspace, its spawn records and its stores are this rig's own temp tree; a run's process is a stand-in.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigPkg/sh-lib/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool file is not at the origin: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin: $rigHarness"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionPauseStateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSkills="$rigTmp/skills"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigAgents/pending" "$rigWs/.local/.agents" "$rigData/board/running" \
	"$rigSkills/magic-team" "$rigTmp/bin" || rigRefuse "the rig could not be made: $rigTmp"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-team/magic-team.basic.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT

## THE RIG'S OWN PROCESS LIST: only this rig's stand-ins are runs, never a process of the host that names one of its ids.
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
## A run of a session: its record and its two folders. The founder's own id is the session's, as a spawn that starts one.
rigRun(){ ## run id, session id, status (spawn-started where not given)
	mkdir -p "$rigAgents/spawned/$1" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-pause-rig\nowner: magic-developer\nstatus: %s\nstarted-at: 2026-11-04 02:00 +0200\n---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$1" "$rigHost" "${3:-spawn-started}" "$1" > "$rigAgents/spawned/$1/$1.spawn.md"
}
## A stand-in for a run's process, in this rig's own list as the run of that id by its own `--session-id` word.
rigStand(){ ## run id
	local standPid
	sleep 600 > /dev/null 2>&1 < /dev/null &
	standPid=$!
	rigProcNote "$standPid" ; rigStarted="$rigStarted $standPid"
	disown "$standPid" 2> /dev/null || :
	printf '%s claude --session-id %s --agent rig the brief\n' "$standPid" "$1" >> "$rigTmp/ps.list"
}
## A call as a console of this rig: no session of its own, the rig's own store and Slack-free path.
rigCall(){
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_READER=off MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash "$rigTool" "$@" ) < /dev/null 2>&1
}
## The served ListAgents, through the harness's one tool door. The access root is the rig's own tree, so the
## served call reads nothing of this host, and a marker in the rig's own folder carries its state word.
rigList(){
	( cd "$rigTmp" && printf '%s' "${1:-{\}}" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=magic-developer RIG_TMP="$rigTmp" RIG_WORKSPACE="$rigWs" \
		bash -c '[ -z "${MMDAPP:-}" ] || case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac ; exec bash "$1" --intern-tool ListAgents --access-read-root "$RIG_WORKSPACE" --access-read-root "$RIG_TMP"' rig "$rigHarness" ) 2>&1
}
rigStateOf(){ ## run id -- its row's derived state, through the registry's one render
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsRegistryRenderSpawnedSessions agents' rig "$rigPkg/sh-lib/team-data/AgentsTools.Registries.include" ) 2>&1 \
		| LC_ALL=C awk -v want="$1" 'NF == 13 && $8 == want { print $13 }' | head -1
}
rigCounters(){ ## -- the sessions the console counts as paused: the counters row of --manager-session-list
	rigCall --manager-session-list | LC_ALL=C awk -F'\t' '$1 == "counters" { print $3 }'
}

rigRun pause-sess pause-sess
rigRun pause-mate pause-sess
rigStand pause-sess ; rigStand pause-mate
rigRun pause-lone pause-lone
rigStand pause-lone
sleep 1

echo "-- 3. before any pause: the runs read their own activity word --"
rigAssert "a live run with no flag and no activity mark thinks" "$( rigStateOf pause-sess )" "thinking"
rigAssert "the console's counter of paused sessions starts at zero" "$( rigCounters )" "0"

echo "-- 1. a pause writes the flag of its id, and a resume removes it --"
rigPaused="$( rigCall --manager-session-pause --session-id pause-sess )"
rigAssert "the pause prints one row naming the id and the file it wrote" "$( printf '%s\n' "$rigPaused" | LC_ALL=C awk -F'\t' '$1 == "pause" { print $1, $2 }' )" "pause pause-sess"
rigAssert "and the flag stands in the session's folder" "$( [ -f "$rigAgents/sessions/pause-sess/paused" ] && echo stands || echo absent )" "stands"
rigAssert "its one line is the moment and who asked, a UTC stamp and a word" \
	"$( LC_ALL=C awk 'NF == 2 { stamp = ( $1 ~ /^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/ ) ; print ( stamp && $2 != "" ? "stamped" : "bad" ) ; }' "$rigAgents/sessions/pause-sess/paused" )" "stamped"

echo "-- 3. the registry derives the word, for a run held by its session's flag --"
rigAssert "a live run held by its session's pause reads paused" "$( rigStateOf pause-sess )" "paused"
rigAssert "and so does every other run of that session" "$( rigStateOf pause-mate )" "paused"
rigAssert "a run of another session is untouched" "$( rigStateOf pause-lone )" "thinking"

echo "-- 5. the console's counter counts the sessions that hold one --"
rigAssert "one paused session is counted" "$( rigCounters )" "1"

echo "-- 1. resume removes it, and a second resume is no fault --"
rigAssert "the resume prints one row" "$( rigCall --manager-session-resume --session-id pause-sess | LC_ALL=C awk -F'\t' '$1 == "resume" { print $1 }' )" "resume"
rigAssert "the flag is gone" "$( [ -f "$rigAgents/sessions/pause-sess/paused" ] && echo stands || echo absent )" "absent"
rigAssert "a resume of a session that is not paused ends well" "$( rigCall --manager-session-resume --session-id pause-sess > /dev/null 2>&1 && echo ok || echo refused )" "ok"
rigAssert "the run reads its own word again" "$( rigStateOf pause-sess )" "thinking"
rigAssert "and the counter is back to zero" "$( rigCounters )" "0"

echo "-- 6. a run's own id pauses that run alone --"
rigCall --manager-session-pause --session-id pause-mate > /dev/null 2>&1 || :
rigAssert "the run held by its own folder reads paused" "$( rigStateOf pause-mate )" "paused"
rigAssert "and the founder of its session, whose own folder holds no flag, does not" "$( rigStateOf pause-sess )" "thinking"
rigCall --manager-session-resume --session-id pause-mate > /dev/null 2>&1 || :

echo "-- 2. an id this workspace does not keep is refused, and nothing is written --"
rigAssert "an unknown id is refused, one error line, exit 1" \
	"$( rigCall --manager-session-pause --session-id no-such-session > /dev/null 2>&1 && echo ok || echo refused ):$( rigCall --manager-session-pause --session-id no-such-session 2>&1 | LC_ALL=C grep -c 'ERROR' )" "refused:1"
rigAssert "an id that is no id is refused too" "$( rigCall --manager-session-pause --session-id ../escape > /dev/null 2>&1 && echo ok || echo refused )" "refused"
rigAssert "a resume of an id this workspace does not keep is refused as its pause is" "$( rigCall --manager-session-resume --session-id no-such-session > /dev/null 2>&1 && echo ok || echo refused )" "refused"
rigAssert "and no flag was made anywhere for either" "$( ls "$rigAgents/sessions"/*/paused "$rigWs/.local/agents/escape/paused" 2> /dev/null | wc -l | tr -d ' ' )" "0"

echo "-- 4. ListAgents shows the word, and its own filter keeps the paused runs --"
rigCall --manager-session-pause --session-id pause-lone > /dev/null 2>&1 || :
rigAssert "a row of a paused run carries the word paused" "$( rigList '{"view":"agents"}' | LC_ALL=C awk -v want=pause-lone '$1 == want && $NF == "paused" { n++ } END { print n + 0 }' )" "1"
rigAssert "--state paused keeps the paused run and drops the others" "$( rigList '{"view":"agents","state":"paused"}' | LC_ALL=C awk 'NF == 13 { print $1 }' | LC_ALL=C sort | tr '\n' ' ' )" "pause-lone "
rigAssert "and the refusal of a word it does not know names the pause among its states" "$( rigList '{"view":"agents","state":"nonsense"}' | LC_ALL=C grep -c '^ERROR: state must be.*paused' )" "1"
rigCall --manager-session-resume --session-id pause-lone > /dev/null 2>&1 || :

rigAssert "the tool file still parses" "$( bash -n "$rigTool" > /dev/null 2>&1 && echo parsed || echo broken )" "parsed"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PAUSE STATE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PAUSE_STATE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
