#!/usr/bin/env bash
## Behavioural check on the review classifier of a board item's `## Decisions`
## (sh-lib/board/AgentsTools.InternOpDecisions.include, the `--review` arm): the action each unconfirmed
## line is proposed, and whether a `[backfilled ...]` mark counts as evidence for `confirm`.
## Board sub-item: task-20261124T2055Z-decisions-classifier-counts-backfilled-mark.
## The ruling the rows follow is `narrow` (magic-coordinator, 2026-11-25 17:03 +0200): a `[backfilled ...]`
## mark settles a line only when it names a message id, or an ask id whose record was found. Every other
## mark keeps the action it has today, and a mark naming only its recorder settles nothing, because its
## own words say no confirmation was found.
## Held, one row per shape the classifier must tell apart:
##   0. control: the list is drawn, holds every unconfirmed shape, and leaves out an already-confirmed line
##   1. a mark naming a message id, bare digits: `confirm` (red before the fix)
##   2. a mark naming a message id as a Slack coordinate: `confirm` (red before the fix)
##   3. a mark naming an ask id whose record was found: `confirm` (red before the fix)
##   4. control: a mark naming an ask id whose record was not found: `prune`
##   5. a mark naming the person a decision was settled with: `prune`, under the ruling that a mark
##      settles nothing on a person
##   6. a mark whose words name a settling person and carry `(settled)` inside its own brackets: `prune`.
##      It reads `confirm` today by accident, because the tail is taken from the first ` (` in the line
##      and that bracket sits inside the mark. Under the ruling the accident closes, so this row is red
##      before the fix and green after (measured at keeper-myx's fixture, 16:59 +0200).
##   7. control: a mark naming only the member that recorded the line: `prune`
##   8. control: a bare mark, naming nothing: `prune`
##   9. control: a mark naming `unknown`: `prune`
##  10. control: a line with no mark at all: `prune`, as today
##  11. control: a line with no mark whose tail carries its answer: `confirm`, as today
## Rows 1 to 3 and row 6 are the change: they read `prune` today and must read `confirm`, `confirm`,
## `confirm` and `prune` after it. Rows 4 to 5 and 7 to 11 are the controls, and the fix must move none
## of them. A build that flips a control has widened the ruling, and one that leaves row 1 at `prune`
## has not built it.
## Offline: a rig workspace and data root under .local/temp, and a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "${MMDAPP%/}/.local/temp" && mktemp -d "${MMDAPP%/}/.local/temp/AgentsDecisionsReviewBackfilledEvidenceCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigPending="$rigWs/.local/agents/pending"
rigBoard="$rigTmp/data/board"
mkdir -p "$rigPending" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/scenario" "$rigWs/.local/.agents"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigBoard/$rigState" ; done
## The members the call reads: the one that owns the item, the party it is asked of, and the ones the
## name registry lists. A member with no skill directory is refused by name, which would mask the rows.
for rigOne in "$rigMember" magic-coordinator human-owner ; do
	mkdir -p "$rigTmp/skills/$rigOne"
	printf 'rig\n' > "$rigTmp/skills/$rigOne/$rigOne.basic.md"
	printf 'rig\n' > "$rigTmp/skills/$rigOne/$rigOne.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
printf '%s\t:microscope:\tVera\tTester\tbugsniff\n' "$rigMember" > "$rigWs/.local/agents/team-members-names.registry"
printf '%s\t%s\tsource\trig\t%s\n' "$rigWs" "$rigMember" "$rigTmp/skills/$rigMember" > "$rigWs/.local/agents/members.registry"
## Nothing here should reach Slack: the Slack-shaped fake curl is first on PATH in case something tries.
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
RIG_SCENARIO="$rigTmp/scenario"
RIG_CURL_LOG="$rigTmp/scenario/curl.log"
: > "$RIG_CURL_LOG"
export PATH RIG_SCENARIO RIG_CURL_LOG
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

## THE ITEM. One unconfirmed line per shape, and one already-confirmed line that must not be listed.
## The mark's own grammar is the one the 2026-11-18 backfill wrote: `[backfilled <date> with the
## human-owner allowance: <evidence>]`. Each line's own words say which shape it is.
rigAllowance="[backfilled 2026-11-18 with the human-owner allowance:"
rigRev="task-20261009T0900Z-rig-backfilled-evidence"
{
	printf -- '---\ntype: task\nowner: %s\n---\n\n# Rig backfilled evidence\n\n## Decisions\n<!-- decisions-of: %s -->\n\n' "$rigMember" "$rigRev"
	printf -- '- 2026-11-01T10:00Z magic-tester resolved: The rig ships on Friday. %s message 1794280013.615612]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:01Z magic-tester clarification: The rig keeps the red wire. %s message slack:D0BT9LQGGF4:1794280020.000100]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:02Z magic-tester resolved: The rig counts the votes. %s ask 5f1c2d3e-0000-4000-8000-000000000001, answered by URIGOWNER]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:03Z magic-tester clarification: The rig drops the old port. %s ask 5f1c2d3e-0000-4000-8000-000000000002, its record not found]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:04Z magic-tester clarification: The rig paints it green. %s settled with URIGOWNER, no ask id]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:11Z magic-tester clarification: The rig holds the gate open. %s answered by URIGOWNER (settled)]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:05Z magic-tester clarification: The rig moves the booth. %s recorded by magic-tester, no confirmation found]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:06Z magic-tester clarification: The rig names no one. [backfilled]\n'
	printf -- '- 2026-11-01T10:07Z magic-tester clarification: The rig knows nobody. %s confirmed by unknown]\n' "$rigAllowance"
	printf -- '- 2026-11-01T10:08Z magic-tester clarification: The rig reads no mark at all.\n'
	printf -- '- 2026-11-01T10:09Z magic-tester resolved: The rig answers in its tail. (answered by URIGOWNER (settled))\n'
	printf -- '- 2026-11-01T10:10Z magic-tester resolved: The rig already stands. (readback rig-c, confirmed by URIGOWNER at 2026-11-01T10:10Z)\n'
} > "$rigBoard/running/$rigRev.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## THE CALL. The review is asked as the member that owns the item. Its list lands in the pending
## record's `understood` slot, which is where the party's own words are read back from.
## The rig's own scenario, curl log and PATH ride into the call by name: `env -i` clears the exported
## ones, and the fake curl with them, so a call that posted would fail as unposted and mask every row.
rigRc=0
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
	MDAT_HARNESS_WAIT_TIMEOUT=1 RIG_SCENARIO="$RIG_SCENARIO" RIG_CURL_LOG="$RIG_CURL_LOG" \
	bash "$rigTool" --record-decision --team-member "$rigMember" "$rigRev" --review --with human-owner ) \
	> "$rigTmp/rev.out" 2> "$rigTmp/rev.err" || rigRc=$?
rigId="$( LC_ALL=C grep -o -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$rigTmp/rev.out" | head -1 )"
[ -n "$rigId" ] || rigRefuse "the review asked nothing, so this check has no list to read: rc $rigRc, $( head -2 "$rigTmp/rev.err" | tr '\n' ' ' )"
rigFields=""
for rigOne in "$rigPending/$rigId.fields" "$rigPending/closed/$rigId.fields" ; do
	[ -f "$rigOne" ] || continue
	rigFields="$rigOne"
done
[ -n "$rigFields" ] || rigRefuse "the review's own record kept no fields, so its list cannot be read: $rigPending/$rigId.fields"
rigPlan="$( LC_ALL=C awk -F'\t' '$1 == "understood" { print substr( $0, length( $1 ) + 2 ) ; exit ; }' "$rigFields" )"
## The list is kept in the record as one line, its rows parted by a literal `\n`: each row is written
## back as its own line here, so an assertion reads the row rather than the escape.
rigPlanLines="$( printf '%s' "$rigPlan" | LC_ALL=C awk '{ gsub( /\\n/, "\n" ) ; print }' )"
## The action listed for the line whose text holds the phrase, or `absent`: each row reads
## `1. confirm: <who>, <kind>, <day>` and the row after it carries the decision's own text.
rigActionOf(){ ## a phrase of the line's own text -> the action listed for it
	printf '%s\n' "$rigPlanLines" | LC_ALL=C awk -v want="$1" '
		/^[0-9]+\. / { action = $2 ; sub( /:$/, "", action ) ; next ; }
		/^> / { if ( index( $0, want ) > 0 ) { print action ; found = 1 ; exit ; } }
		END { if ( ! found ) { printf "absent\n" ; } }
	'
}

echo "-- 0. control: the list is drawn, and holds every unconfirmed line and no confirmed one --"
rigAssert "the review asked, and its list is on the record"     "$( [ -n "$rigId" ] && printf asked || printf none ):$( [ -n "$rigPlan" ] && printf list || printf empty )" "asked:list"
## Ten unconfirmed lines, one per shape; the eleventh line is already confirmed and stays out.
rigAssert "eleven lines are listed: the confirmed one is left out" "$( printf '%s\n' "$rigPlanLines" | LC_ALL=C grep -c '^[0-9]\+\. ' )" 11
rigAssert "control: the already-confirmed line is not listed"    "$( printf '%s\n' "$rigPlanLines" | LC_ALL=C grep -c 'The rig already stands' )" 0

echo "-- 1. a mark naming a message id, bare digits --"
rigAssert "it is proposed as confirm"                           "$( rigActionOf 'The rig ships on Friday' )" confirm

echo "-- 2. a mark naming a message id as a Slack coordinate --"
rigAssert "it is proposed as confirm"                           "$( rigActionOf 'The rig keeps the red wire' )" confirm

echo "-- 3. a mark naming an ask id whose record was found --"
rigAssert "it is proposed as confirm"                           "$( rigActionOf 'The rig counts the votes' )" confirm

echo "-- 4. control: a mark naming an ask id whose record was not found --"
rigAssert "it is proposed as prune"                             "$( rigActionOf 'The rig drops the old port' )" prune

echo "-- 5. control: a mark naming the person a decision was settled with --"
rigAssert "it is proposed as prune, under the narrow ruling"     "$( rigActionOf 'The rig paints it green' )" prune

echo "-- 6. a mark whose own words name a settling person and carry (settled) --"
rigAssert "it is proposed as prune: the accident closes"         "$( rigActionOf 'The rig holds the gate open' )" prune

echo "-- 7. control: a mark naming only the member that recorded the line --"
rigAssert "it is proposed as prune, not confirm"                 "$( rigActionOf 'The rig moves the booth' )" prune

echo "-- 8. control: a bare mark, naming nothing --"
rigAssert "it is proposed as prune"                             "$( rigActionOf 'The rig names no one' )" prune

echo "-- 9. control: a mark naming unknown --"
rigAssert "it is proposed as prune"                             "$( rigActionOf 'The rig knows nobody' )" prune

echo "-- 10. control: a line with no mark at all --"
rigAssert "it is proposed as prune, as today"                   "$( rigActionOf 'The rig reads no mark at all' )" prune

echo "-- 11. control: a line with no mark whose tail carries its answer --"
rigAssert "it is proposed as confirm, as today"                 "$( rigActionOf 'The rig answers in its tail' )" confirm

echo
printf 'DECISIONS_REVIEW_BACKFILLED_EVIDENCE: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { echo "⛔ DECISIONS REVIEW BACKFILLED EVIDENCE CHECK FAILED" >&2 ; exit 1 ; }
