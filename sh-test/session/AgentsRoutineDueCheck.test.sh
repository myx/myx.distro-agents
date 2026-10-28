#!/usr/bin/env bash
## Behavioural check on the autorun interpreter (F7.5 of the refactorings epic, DistroAgentsDispatcher.fn.sh --routine-due <routine>): a
## routine declares its own autorun, `runs-at: <days> <HH:MM>` and `runs-after: <routine>`, and Dispatcher decides from the settings, the
## clock and the run history, which it owns. The time is the earliest start; where a predecessor is named it is the trigger, and the
## chain needs no waiting state (epic 1740-1752). rc 0 due; rc 1 not due, and why; rc 2 refused, naming the predecessor that did not run;
## rc 3 a call that could not be understood. Held, run and not read, with a clock and a Slack of the rig's own:
##   1. A routine with no autorun, `runs-at: none` or none at all, is not due, whatever else it says.
##   2. runs-at: due from its time on a day of its days, in the team's zone; not before that time; not on another day; once a day:
##      a run of it that started that day, whatever became of it, makes it not due again until the next such day. A run of another day,
##      and one of another routine, do not. `workdays` and `weekend` read the weekend setting, or sat,sun where none is set (the owner, 2026-10-21).
##   3. runs-after is the trigger: the routine is due when its time has come and the predecessor completed (spawn-succeeded) that
##      day; refused, naming the predecessor, while it has not (a run that failed, one that is still open and one of another day are
##      not completed); not due, with the time, before its time even when the predecessor completed.
##   4. The chain that stops is never silent: when the last day on which the routine was to run has passed with the predecessor not
##      completed and the routine itself not run, the answer carries an ESCALATE line naming both, and one post goes to the
##      event-alert channel; recorded, so a second call posts nothing. No escalation where the predecessor completed, where the
##      routine ran, and for a routine that follows none.
##   5. The text of the post is a block of the tooling-note template (Schedule/chain-broken), not a text written in code.
## Offline: a date first on PATH gives the rig's clock, a Slack-shaped fake curl takes the posts; every workspace is a folder of the rig's.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineDueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigDir="$rigTmp/skills/rig-member" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigDir" "$rigSkills/magic-coordinator" "$rigScn/data"
printf 'rig\n' > "$rigDir/rig-member.basic.md" ; printf 'rig\n' > "$rigDir/rig-member.armed.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md" ; printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_ALERT=CRIGALERT1\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
printf 'magic-coordinator=URIGCOORD1=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
: > "$rigScn/calls"
ln -s "$( command -v date )" "$rigTmp/bin/date.real" || rigRefuse "no date on PATH to hand the other calls to"
cat > "$rigTmp/bin/date" <<'RIGDATE'
#!/bin/sh
## The rig's clock: the instant in now.epoch, formatted by the real date as it would at that instant (TZ is the caller's).
real="${0%/*}/date.real"
epoch="$( cat "${0%/*}/../now.epoch" )"
case "$*" in
	+%s) echo "$epoch" ; exit 0 ;;
esac
case "$1" in
	+*) if "$real" -r 0 +%s > /dev/null 2>&1 ; then exec "$real" -r "$epoch" "$@" ; else exec "$real" -d "@$epoch" "$@" ; fi ;;
esac
exec "$real" "$@"
RIGDATE
chmod +x "$rigTmp/bin/date"
## Monday 2026-10-19 in Etc/GMT-3 (UTC+3): 08:00, 13:00; Tuesday 00:30; Saturday 13:00.
rigMon08=1792386000 ; rigMon13=1792404000 ; rigTue0030=1792445400 ; rigSat13=1792836000
rigAt(){ printf '%s' "$1" > "$rigTmp/now.epoch" ; }
rigAt "$rigMon13"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRc=0 rigOut="" rigErr="" rigReadOnly=""
rigRun(){ ## script, words... -- one call from the rig workspace; rc in rigRc, stdout in rigOut, stderr in rigErr
	local runScript="$1"
	shift
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigScn/data" RIG_SCENARIO="$rigScn" bash "$runScript" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )" ; rigErr="$( cat "$rigTmp/err" )"
}
rigRoutine(){ ## name, runs-at value ("" for no key), runs-after value ("" for none)
	{
		printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf 'runs-at: %s\n' "$2"
		[ -z "${3:-}" ] || printf 'runs-after: %s\n' "$3"
		printf -- '---\n# rig-member.%s.routine\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n# Routine'"'"'s local procedures\n\nNone.\n' "$1"
	} > "$rigDir/rig-member.$1.routine.md"
}
rigRun_n=0
rigRecord(){ ## routine name, status, started-at, resolved-at ("" for none) -- one spawn record of the rig's history
	rigRun_n=$(( rigRun_n + 1 ))
	mkdir -p "$rigWs/.local/agents/spawned/rig-sess-$rigRun_n"
	{
		printf -- '---\nsession-id: rig-sess-%s\nspawn-id: rig-run-%s\nparent-spawn-id: none\nstart-context: spawned\nhost: rig\nworkspace: rigws\nowner: rig-member\nstatus: %s\nstarted-at: %s\n' "$rigRun_n" "$rigRun_n" "$2" "$3"
		[ -z "${4:-}" ] || printf 'resolved-at: %s\n' "$4"
		printf 'routine: rig-member.%s.routine.md\n---\n\n# Spawn session: rig-run-%s\n' "$1" "$rigRun_n"
	} > "$rigWs/.local/agents/spawned/rig-sess-$rigRun_n/rig-run-$rigRun_n.spawn.md"
}
rigClearRecords(){ rm -rf "$rigWs/.local/agents/spawned" ; rigRun_n=0 ; }
rigDue(){ ## name -- one --routine-due call (with --read-only where rigReadOnly is set), the answer in `<rc>|<stdout lines joined>`
	rigRun "$rigDispatcher" --routine-due ${rigReadOnly:+--read-only} "rig-member.$1.routine.md"
	printf '%s|%s' "$rigRc" "$( printf '%s\n' "$rigOut" | tr '\n' '|' )"
}
rigPosts(){ cat "$rigScn/posts" 2> /dev/null || printf 0 ; }

rigRoutine none-key "none"
rigRoutine no-key ""
rigRoutine only-after "" "rig-member.r"
rigRoutine r "workdays 09:00"
rigRoutine g "workdays 09:00" "rig-member.r"
rigRoutine h "workdays 09:00" "rig-member.r"
rigRoutine w "weekend 10:00"
rigRoutine d "daily 09:00"

echo "-- 1. no autorun --"
rigRun "$rigDispatcher" --set-timezone Etc/GMT-3 ; rigRun "$rigDispatcher" --set-weekend sat,sun
rigAssert "runs-at: none is not due, and says why" "$( rigDue none-key )" "1|NOT-DUE: rig-member.none-key.routine.md: it declares no autorun (runs-at: none)|"
rigAssert "no runs-at is not due" "$( rigDue no-key )" "1|NOT-DUE: rig-member.no-key.routine.md: it declares no autorun (no runs-at)|"
rigAssert "runs-after alone is no autorun: the time is the earliest start, and there is none" "$( rigDue only-after )" "1|NOT-DUE: rig-member.only-after.routine.md: it declares no autorun (no runs-at)|"

echo "-- 2. runs-at --"
rigAssert "Monday 13:00, workdays 09:00, no run: due" "$( rigDue r )" "0|DUE: rig-member.r.routine.md|"
rigAt "$rigMon08"
rigAssert "Monday 08:00: not before its time, which it names" "$( rigDue r )" "1|NOT-DUE: rig-member.r.routine.md: before its earliest start, 09:00|"
rigAt "$rigSat13"
rigAssert "Saturday: not a workday" "$( rigDue r )" "1|NOT-DUE: rig-member.r.routine.md: today is not one of its days (workdays)|"
rigAssert "the same Saturday is a day of weekend 10:00: due" "$( rigDue w )" "0|DUE: rig-member.w.routine.md|"
rigAt "$rigMon13"
rigAssert "daily runs on a Monday as well" "$( rigDue d )" "0|DUE: rig-member.d.routine.md|"
rigRecord r spawn-succeeded '2026-10-19 09:30 +0300' '2026-10-19 09:50 +0300'
rigAssert "a run that started today, ended well: not due again today" "$( rigDue r )" "1|NOT-DUE: rig-member.r.routine.md: it ran today (rig-run-1)|"
rigClearRecords
rigRecord r spawn-failed '2026-10-19 09:30 +0300' '2026-10-19 09:31 +0300'
rigAssert "a run that failed counts as a run: it is not started again and again" "$( rigDue r )" "1|NOT-DUE: rig-member.r.routine.md: it ran today (rig-run-1)|"
rigClearRecords
rigRecord r spawn-started '2026-10-19 09:30 +0300' ''
rigAssert "a run still open counts as well" "$( rigDue r )" "1|NOT-DUE: rig-member.r.routine.md: it ran today (rig-run-1)|"
rigClearRecords
rigRecord r spawn-succeeded '2026-10-18 09:30 +0300' '2026-10-18 09:50 +0300'
rigRecord g spawn-succeeded '2026-10-19 09:30 +0300' '2026-10-19 09:50 +0300'
rigAssert "a run of yesterday, and a run of another routine today, do not: due" "$( rigDue r )" "0|DUE: rig-member.r.routine.md|"
rigClearRecords
rigRun "$rigTool" --agents-config-option magic-team --delete MDAT_SCHEDULE_WEEKEND
rigAssert "workdays with the weekend not set read the default sat,sun: due on a Monday" "$( rigDue r )" "0|DUE: rig-member.r.routine.md|"
rigAssert "daily needs no weekend" "$( rigDue d )" "0|DUE: rig-member.d.routine.md|"
rigRun "$rigDispatcher" --set-weekend sat,sun

echo "-- 3. runs-after --"
rigAssert "the predecessor has not run today: refused, naming it" "$( rigDue g )" "2|REFUSED: rig-member.g.routine.md: rig-member.r.routine.md has not completed today|"
rigRecord r spawn-succeeded '2026-10-18 09:30 +0300' '2026-10-18 09:50 +0300'
rigAssert "it completed yesterday: that is not today" "$( rigDue g )" "2|REFUSED: rig-member.g.routine.md: rig-member.r.routine.md has not completed today|"
rigClearRecords
rigRecord r spawn-failed '2026-10-19 09:10 +0300' '2026-10-19 09:20 +0300'
rigAssert "it failed today: not completed" "$( rigDue g )" "2|REFUSED: rig-member.g.routine.md: rig-member.r.routine.md has not completed today|"
rigClearRecords
rigRecord r spawn-started '2026-10-19 09:10 +0300' ''
rigAssert "it is still open: not completed" "$( rigDue g )" "2|REFUSED: rig-member.g.routine.md: rig-member.r.routine.md has not completed today|"
rigClearRecords
rigRecord r spawn-succeeded '2026-10-19 09:10 +0300' '2026-10-19 09:40 +0300'
rigAssert "it completed today: due, with a line naming its completed run" "$( rigDue g )" "0|DUE: rig-member.g.routine.md|AFTER: rig-member.r.routine.md rig-run-1|"
rigAssert "a second routine that follows it is due too" "$( rigDue h )" "0|DUE: rig-member.h.routine.md|AFTER: rig-member.r.routine.md rig-run-1|"
rigAt "$rigMon08"
rigClearRecords
rigRecord r spawn-succeeded '2026-10-19 07:00 +0300' '2026-10-19 07:30 +0300'
rigAssert "before its time it is not due even though the predecessor completed: the time is a not-before" "$( rigDue g )" "1|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|"
rigAt "$rigMon13"
rigRecord g spawn-succeeded '2026-10-19 10:00 +0300' '2026-10-19 10:30 +0300'
rigAssert "and once it has run today it is not due again" "$( rigDue g )" "1|NOT-DUE: rig-member.g.routine.md: it ran today (rig-run-2)|"
rigClearRecords

echo "-- 4. the chain that stops --"
rigAt "$rigTue0030"
rigAssert "no escalation here for a routine that follows none (the day passed, nothing ran)" "$( rigDue r | cut -c1-1 )" "1"
rigAssert "...and the answer carries no ESCALATE line" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c '^ESCALATE:' )" "0"
rigAssert "Monday passed with r not completed and g not run: ESCALATE names both" "$( rigDue g )" \
	"1|ESCALATE: rig-member.g.routine.md: rig-member.r.routine.md did not run on 2026-10-19, so the chain is broken|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|"
rigAssert "one post went to the event-alert channel" "$( rigPosts )" "1"
rigAssert "its text is the tooling-note block, and names the chain" "$( LC_ALL=C grep -c -F -e 'rig-member.g.routine.md' -e 'rig-member.r.routine.md' "$rigScn/post.1" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "named"
rigAssert "and it went to the channel the setting names" "$( LC_ALL=C grep -c 'CRIGALERT1' "$rigScn/post.1" )" "1"
rigAssert "the template holds the block (not a text of the code)" "$( LC_ALL=C grep -c '^## chain-broken' "$rigPackage/sh-lib/templates/tooling-note.post.format.md" )" "1"
rigAssert "a second call says nothing of it again, and posts nothing" "$( rigDue h | cut -c1-1 ):$( rigPosts )" "1:2"
rigAssert "(h is another routine that follows r: its own chain, its own post)" "$( rigDue g ):$( rigPosts )" "1|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|:2"
rigClearRecords
rm -rf "$rigWs/.local/agents/schedule/escalated" ; : > "$rigScn/calls" ; printf "0" > "$rigScn/posts"
rigRecord r spawn-succeeded '2026-10-19 09:10 +0300' '2026-10-19 09:40 +0300'
rigAssert "Monday passed with r completed: no escalation, no post" "$( rigDue g ):$( rigPosts )" "1|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|:0"
rigClearRecords
rigRecord g spawn-succeeded '2026-10-19 11:00 +0300' '2026-10-19 11:20 +0300'
rigAssert "Monday passed with g run all the same: no escalation" "$( rigDue g ):$( rigPosts )" "1|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|:0"
rigClearRecords

echo "-- 4b. --read-only: the question is asked, and nothing is posted or marked --"
rigAt "$rigTue0030"
rm -rf "$rigWs/.local/agents/schedule" ; : > "$rigScn/calls" ; printf "0" > "$rigScn/posts"
rigReadOnly=1
rigAssert "asked with --read-only: the answer without the ESCALATE line, no post, and no mark kept" "$( rigDue g ):$( rigPosts ):$( [ -e "$rigWs/.local/agents/schedule" ] && echo marked || echo unmarked )" "1|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|:0:unmarked"
rigReadOnly=""
## the first look at the routine, as an earlier call of the Dispatcher kept it: Monday morning, before the day that broke the chain ended
mkdir -p "$rigWs/.local/agents/schedule/seen" ; printf '%s' "$rigMon08" > "$rigWs/.local/agents/schedule/seen/rig-member.g.routine.md"
rigAssert "asked as the Dispatcher asks it (without it), the same chain is escalated and posted once (the control)" "$( rigDue g ):$( rigPosts )" "1|ESCALATE: rig-member.g.routine.md: rig-member.r.routine.md did not run on 2026-10-19, so the chain is broken|NOT-DUE: rig-member.g.routine.md: before its earliest start, 09:00|:1"
rigClearRecords
rigAt "$rigMon13"
rigReadOnly=1
rigAssert "every other answer is the same with it: due, not due, refused (Monday 13:00, nothing has run)" "$( rigDue d ) $( rigDue none-key ) $( rigDue g | cut -c1-1 )" "0|DUE: rig-member.d.routine.md| 1|NOT-DUE: rig-member.none-key.routine.md: it declares no autorun (runs-at: none)| 2"
rigReadOnly=""
rigRun "$rigDispatcher" --routine-due --read-only
rigAssert "--read-only with no routine, and a second word, are refused as before: rc 3, nothing on stdout" "$rigRc:$( printf '%s' "$rigOut" | wc -c | tr -d ' ' )" "3:0"
rigRun "$rigDispatcher" --routine-due --read-only rig-member.r.routine.md rig-member.g.routine.md
rigAssert "two routines with it: rc 3" "$rigRc" "3"

echo "-- 4c. the list a console shows: the autorun, whether the file is valid, and whether a start now would be accepted --"
rigAt "$rigMon13"
rigClearRecords
rigListRow(){ ## name -- the autorun, valid and would-start fields (13 to 17) of that routine's row of --manager-routine-list
	rigRun "$rigTool" --manager-routine-list
	LC_ALL=C awk -F'\t' -v want="rig-member.$1.routine.md" '$1 == "routine" && $2 == want { print $13 "|" $14 "|" $15 "|" $16 "|" $17 }' "$rigTmp/out"
}
rigRoutine bad "soon"
rigAssert "a routine with an autorun that is due now: it runs by itself, at its days and time, follows none, is valid, and a start now would be accepted" "$( rigListRow r )" "yes|workdays_09:00|-|yes|yes"
rigAssert "one that follows a routine that has not completed today: its autorun is not due, and says why, so a start now would not be accepted, though the file is valid" "$( rigListRow g )" "yes|workdays_09:00|rig-member.r|yes|no:rig-member.r.routine.md_has_not_completed_today"
rigAssert "daily is due on a Monday as well" "$( rigListRow d )" "yes|daily_09:00|-|yes|yes"
rigAssert "a routine outside its window is valid and would not start: weekend on a Monday" "$( rigListRow w )" "yes|weekend_10:00|-|yes|no:today_is_not_one_of_its_days_(weekend)"
rigAssert "runs-at: none declares no autorun; no runs-at, and runs-after alone, are refused by the validator as a missing mandatory key" "$( rigListRow none-key ) / $( rigListRow no-key ) / $( rigListRow only-after )" "no|none|-|yes|yes / no|-|-|no:runs-at:_is_mandatory_--_write_runs-at:_none,_or_runs-at:_<days>_<HH:MM>|yes / no|-|rig-member.r|no:runs-at:_is_mandatory_--_write_runs-at:_none,_or_runs-at:_<days>_<HH:MM>|yes"
rigAssert "a runs-at that is none of <days> <HH:MM> is declared, the validator refuses it with the rule and the words, and the Dispatcher cannot decide it" "$( rigListRow bad | LC_ALL=C cut -d'|' -f1-3 )|$( rigListRow bad | LC_ALL=C cut -d'|' -f4 | LC_ALL=C cut -c1-46 )|$( rigListRow bad | LC_ALL=C cut -d'|' -f5 )" "yes|soon|-|no:runs-at:_soon_is_not_none_or_<days>_<HH:MM>|no:its_autorun_could_not_be_decided"
rm -rf "$rigWs/.local/agents/schedule" ; printf "0" > "$rigScn/posts"
rigRun "$rigTool" --manager-routine-list
rigAssert "listing the routines posts nothing and marks nothing: the question of the autorun is asked with --read-only" "$( rigPosts ):$( [ -e "$rigWs/.local/agents/schedule" ] && echo marked || echo unmarked )" "0:unmarked"
rm -f "$rigDir/rig-member.bad.routine.md"

echo "-- 5. a call that cannot be understood --"
rigRun "$rigDispatcher" --routine-due
rigAssert "no routine: rc 3, a line, nothing on stdout" "$rigRc:$( printf '%s' "$rigOut" | wc -c | tr -d ' ' ):$( printf '%s\n' "$rigErr" | LC_ALL=C grep -v 'SystemContext' | LC_ALL=C grep -c 'ERROR' )" "3:0:1"
rigRun "$rigDispatcher" --routine-due rig-member.no-such
rigAssert "a routine that matches no file: rc 3" "$rigRc:$( printf '%s' "$rigOut" | wc -c | tr -d ' ' )" "3:0"
rigRun "$rigDispatcher" --routine-due rig-member.r.routine.md rig-member.g.routine.md
rigAssert "two routines: rc 3" "$rigRc" "3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE DUE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_DUE: OK (%d assertions, offline)\n' "$rigPassCount"
