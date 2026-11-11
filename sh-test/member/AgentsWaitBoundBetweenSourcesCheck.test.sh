#!/usr/bin/env bash
## Behavioural check on a bound inside a round (AgentsTools.MemberWait.include, "A ROUND READS EVERY SOURCE IT HOLDS").
## A bound decides when a wait RETURNS, never which sources its round reads (owner ruling 2026-10-31): a round reads every
## source it holds, an arrival found early included, and a probe that cannot finish inside the bound is handed to the task
## wrapper and named in WAIT-NEVER-READ. Held, with the inbox probe made slow by a `date` that sleeps when it is asked for a
## file's time (the one thing that probe calls it for), and a floor of 1 so that what is there counts as an arrival:
##   1. a bound of 2 s and a first probe of 3 s that finds the note: RECEIVED with both arrivals, the source after the slow
##      one read too, and nothing named in WAIT-NEVER-READ
##   2. control, the probe quick: both sources arrive, nothing is named in WAIT-NEVER-READ
##   3. a zero bound reads every source once, slow probe or not: both arrive
##   4. a quiet round past the bound (nothing found by the slow probe) still reads the source after it: nothing is named

## Offline: a Slack-shaped fake curl logs and answers any call; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitBoundBetweenSourcesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
cp "$rigTest/check-fixtures/wait-bound-slow-date.date.stub.sh" "$rigTmp/bin/date" || rigRefuse "the slow date fixture is missing from the package"
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/date"
RIG_DATE_REAL="$( command -v date )" || rigRefuse "no date on PATH to hand the other calls to"
export RIG_DATE_REAL
PATH="$rigTmp/bin:$PATH"
export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigW="$rigTmp/ws" rigD="$rigTmp/data" rigH="$rigTmp/home"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator/incoming" "$rigD/board/pending" "$rigH"
## The rig's own workspace has a source folder: the context of the tool is detected from it.
rigCopyTree "${rigHere%/myx/myx.distro-agents/sh-lib}" "$rigW/source" || rigRefuse "the rig's source copy could not be made"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigW/.local/.agents/magic-team.agent.env"
## One item in the inbox, so the inbox probe asks for a file's time.
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\n# Note: bound between sources\n' > "$rigD/inboxes/magic-coordinator/incoming/note-20261022T1700Z-bound-between-sources.md"
printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item pending\n' > "$rigD/board/pending/task-rig-pending.md"
## One Wait on the inbox, then a board state, from a floor of 1 (what is there counts); the slow date is on where the flag is.
rigWait(){ ## result name, bound seconds, slow (yes or no), floor (a number, or none)
	local waitRc=0
	rm -f "$rigTmp/slow"
	[ "$3" != yes ] || : > "$rigTmp/slow"
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" MDAT_WAIT_REMIND=off \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --wait-for-input --team-member magic-coordinator --wait-source inbox:magic-coordinator --wait-source board:pending --wait-timeout "$2" --wait-poll-interval 1 ${4:+--wait-since-utime "$4"} ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null 4> /dev/null || waitRc=$?
	printf '%s' "$waitRc" > "$rigTmp/$1.rc"
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line, or none
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}
rigNeverRead(){ ## result name -- the WAIT-NEVER-READ line, or none
	local neverLine
	neverLine="$( LC_ALL=C sed -n 's/^WAIT-NEVER-READ: //p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${neverLine:-none}"
}

rigArrivals(){ ## result name -- the sources that arrived, in order, space separated
	LC_ALL=C sed -n 's/^# arrived on: //p' "$rigTmp/$1.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
echo "-- 1. a bound that passes in the first probe, which found something: the source after it is read too --"
rigWait w1 2 yes 1
rigAssert "RECEIVED, ending 0, with both arrivals"                "$( rigResult w1 ):$( cat "$rigTmp/w1.rc" ):$( rigArrivals w1 )" "RECEIVED:0:board:pending inbox:magic-coordinator"
rigAssert "nothing is named as never read"                        "$( rigNeverRead w1 )" "none"
echo "-- 2. control, the probe quick: both sources arrive --"
rigWait w2 2 no 1
rigAssert "RECEIVED with both, nothing named as never read"       "$( rigResult w2 ):$( rigArrivals w2 ):$( rigNeverRead w2 )" "RECEIVED:board:pending inbox:magic-coordinator:none"
echo "-- 3. a zero bound reads every source once, slow probe or not --"
rigWait w3 0 yes 1
rigAssert "RECEIVED with both, nothing named as never read"       "$( rigResult w3 ):$( rigArrivals w3 ):$( rigNeverRead w3 )" "RECEIVED:board:pending inbox:magic-coordinator:none"
echo "-- 4. a quiet round past the bound still reads the sources at its tail --"
rigWait w4 2 yes
rigAssert "TIMEOUT, nothing named as never read"                  "$( rigResult w4 ):$( rigNeverRead w4 )" "TIMEOUT:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT BOUND BETWEEN SOURCES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_BOUND_BETWEEN_SOURCES: OK (%d assertions, offline)\n' "$rigPassCount"
