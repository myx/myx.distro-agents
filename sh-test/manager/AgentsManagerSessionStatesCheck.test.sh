#!/usr/bin/env bash
## Behavioural check on S27.4 (console side) and S25.14 (title and chapter): the rows the console's session list prints
## show each run's state as the registry derives it, apart: thinking, tool, waiting, parked, finished. Held:
##   1. a run's state is the registry's word, and its activity is derived from that word alone: a run that thinks reads
##      working whatever its milestones last said, a run inside a Wait or an ask reads waiting, a run awaiting review
##      or ended has none (a milestone file is never the console's second opinion)
##   2. the tally of a session names every state its runs are in, thinking, tool and parked among them
##   3. a session whose runs have all ended or handed back, one of them parked, reads awaiting-review, never finished;
##      the active list keeps it, and a live run (the registry says live comes first) keeps its session running
##   4. the counters row counts the agents that work and the agents that wait by those same words
##   5. the title of a session is the one its records carry now, and its chapter is the one line its store keeps, `-`
##      where there is none; a retitle and a new chapter show at the next call
##   6. the read of one session gives its runs the same activity
## Red before S27.4: a thinking run read waiting from a stale milestone, a run in a Wait read working, the tally dropped
## thinking, in-tool and awaiting-review, a session of parked runs read finished, and no chapter was printed.
## Offline: the workspace, its spawn records and its stores are this rig's own temp tree; the only processes are sleepers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigInclude="$rigPkg/sh-lib/manager/AgentsTools.ManagerSession.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the manager session include is not at the origin: $rigInclude"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionStatesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap '[ -z "$rigPids" ] || rigProcSignal KILL $rigPids ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned" "$rigStores"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
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
rigRun(){ ## session id, spawn id, status, activity word or empty, title
	mkdir -p "$rigSpawned/$2" "$rigStores/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\nsession-comment: %s\n---\n' \
		"$1" "$2" "$2" "$rigHost" "$3" "$5" > "$rigSpawned/$2/$2.spawn.md"
	[ -z "${4:-}" ] || printf '1 %s %s\n' "$( date +%s )" "$4" > "$rigStores/$2/activity"
}
rigAlive(){ ## spawn id -- a process carrying the id, so the row reads running
	python3 -I -B -c 'import time; time.sleep(180)' -- --session-id "$1" > /dev/null 2>&1 &
	rigProcNote "$!" ; rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
}
rigPark(){ ## spawn id -- the mark a run leaves when it handed back
	: > "$rigStores/$1/parked"
}
rigCall(){ ## the function and its words -- the include read for its definitions alone, in an environment of the rig's own
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator MDSC_CMD=DistroAgentsTools \
		bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; shift ; "$@"' rig "$rigInclude" "$@" 2>&1
}
rigField(){ ## rows, kind, key, field number -- one field of the row of that kind that carries that key (a session's id, a run's spawn id)
	printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v kind="$2" -v key="$3" -v at="$4" '( kind == "session" && $1 == "session" && $2 == key ) || ( kind == "run" && $1 == "run" && $3 == key ) { print $at ; exit }'
}

echo "-- the rig: four sessions, six runs in the first --"
## sess-A, `Rig work`: a run that thinks, the milestone of its store still saying it went into a Wait (stale), a run inside a
## tool, a run inside a Wait, a run inside an ask, a run that handed back and left, a run that ended. It has a chapter.
rigRun sess-A think-A spawn-started thinking "Rig_work" ; rigAlive think-A
printf '2026-11-02T01:00:00Z message out\n2026-11-02T01:00:05Z wait going idle\n' > "$rigStores/think-A/milestones"
rigRun sess-A tool-A spawn-started "tool Read" "Rig_work" ; rigAlive tool-A
rigRun sess-A wait-A spawn-started "tool Wait" "Rig_work" ; rigAlive wait-A
rigRun sess-A ask-A spawn-started "tool AskQuestion" "Rig_work" ; rigAlive ask-A
rigRun sess-A park-A spawn-succeeded "" "Rig_work" ; rigPark park-A
rigRun sess-A done-A spawn-succeeded "" "Rig_work"
mkdir -p "$rigStores/sess-A" ; printf 'Writing the dispatch\n' > "$rigStores/sess-A/chapter"
## sess-B, `Parked only`: every run of it has ended or handed back, one of them parked.
rigRun sess-B park-B spawn-succeeded "" "Parked_only" ; rigPark park-B
rigRun sess-B done-B spawn-succeeded "" "Parked_only"
## sess-C, `Ended`: finished.
rigRun sess-C done-C spawn-succeeded "" "Ended"
## sess-D, `Handed back`: the one run of it handed back and left, waiting for the verdict.
rigRun sess-D park-D spawn-succeeded "" "Handed_back" ; rigPark park-D
sleep 2
rigOut="$( rigCall AgentsToolsManagerSessionRows --manager-session-list )"
rigCount="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "session" { n++ } END { print n + 0 }' )"
rigAssert "the list reads the four sessions of the rig" "$rigCount" "4"

echo "-- 1. a run's activity comes from the registry's state word, never from a milestone --"
rigAssert "a thinking run reads thinking, and working: its stale milestone saying it went into a Wait is not asked"  "$( rigField "$rigOut" run think-A 7 ) $( rigField "$rigOut" run think-A 12 )" "thinking working"
rigAssert "a run inside a tool reads tool and working" "$( rigField "$rigOut" run tool-A 7 ) $( rigField "$rigOut" run tool-A 12 )" "tool working"
rigAssert "a run inside a Wait reads waiting, with no milestone to say so" "$( rigField "$rigOut" run wait-A 7 ) $( rigField "$rigOut" run wait-A 12 )" "waiting waiting"
rigAssert "a run that handed back and left reads parked, with no activity" "$( rigField "$rigOut" run park-A 7 ) $( rigField "$rigOut" run park-A 12 )" "parked -"
rigAssert "a run that ended reads finished, with no activity" "$( rigField "$rigOut" run done-A 7 ) $( rigField "$rigOut" run done-A 12 )" "finished -"

echo "-- 2. the tally of a session names every state its runs are in --"
rigAssert "sess-A: thinking, tool, waiting (two), parked and finished, in that order" "$( rigField "$rigOut" session sess-A 8 )" "thinking=1,tool=1,waiting=2,parked=1,finished=1"

echo "-- 3. the state of a session whose runs hand back --"
rigAssert "sess-A, with runs at work, reads running" "$( rigField "$rigOut" session sess-A 4 )" "running"
rigAssert "sess-B, its runs ended or parked, reads awaiting-review and not finished" "$( rigField "$rigOut" session sess-B 4 )" "awaiting-review"
rigAssert "sess-D, its only run handed back, reads awaiting-review" "$( rigField "$rigOut" session sess-D 4 )" "awaiting-review"
rigAssert "sess-C, every run ended, reads finished" "$( rigField "$rigOut" session sess-C 4 )" "finished"
rigActive="$( rigCall AgentsToolsManagerSessionRows --manager-session-active active | LC_ALL=C awk -F'\t' '$1 == "session" { printf "%s ", $2 }' )"
rigAssert "the active list keeps the sessions awaiting review and leaves the finished one out" "$( printf '%s\n' $rigActive | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "sess-A sess-B sess-D "

echo "-- 4. the counters row counts the agents that work and that wait --"
rigAssert "two agents work (thinking, in-tool) and two wait (a Wait, an ask); a run awaiting review is neither" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "counters" { print $4 " " $5 }' )" "2 2"

echo "-- 5. the title and the chapter --"
rigAssert "the title a session's records carry is its name" "$( rigField "$rigOut" session sess-A 3 ) | $( rigField "$rigOut" session sess-B 3 )" "Rig_work | Parked_only"
rigAssert "the chapter a store keeps is the last field of its session, a session with none reads -" "$( rigField "$rigOut" session sess-A 15 ) | $( rigField "$rigOut" session sess-B 15 )" "Writing_the_dispatch | -"
for rigOne in think-A tool-A wait-A ask-A park-A done-A ; do
	LC_ALL=C sed 's/^session-comment: .*/session-comment: Fixing_the_release_build/' "$rigSpawned/$rigOne/$rigOne.spawn.md" > "$rigSpawned/$rigOne/$rigOne.spawn.md.new" && mv -f "$rigSpawned/$rigOne/$rigOne.spawn.md.new" "$rigSpawned/$rigOne/$rigOne.spawn.md"
done
printf 'Reviewing the handback\n' > "$rigStores/sess-A/chapter"
rigOut2="$( rigCall AgentsToolsManagerSessionRows --manager-session-list )"
rigAssert "a retitle and a new chapter show at the next call" "$( rigField "$rigOut2" session sess-A 3 ) | $( rigField "$rigOut2" session sess-A 15 )" "Fixing_the_release_build | Reviewing_the_handback"

echo "-- 6. the read of one session gives its runs the same activity --"
rigScoped="$( rigCall bash -c '. "$0" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerSessionScope --manager-session-read sess-A > /dev/null 2>&1 ; printf "%s\n" "$scopeListed"' "$rigInclude" )"
rigAssert "in the read of sess-A the thinking run reads working, the run in a Wait waiting, the parked one none" \
	"$( rigField "$rigScoped" run think-A 12 ) $( rigField "$rigScoped" run wait-A 12 ) $( rigField "$rigScoped" run park-A 12 )" "working waiting -"

echo "-- the count --"
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'MANAGER SESSION STATES: OK (%d assertions, offline)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ MANAGER SESSION STATES CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
