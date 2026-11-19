#!/usr/bin/env bash
## Check of the `condition` convention as written: the three forms are read out of board-model.md's section "`condition` and `recheck-date`",
## one sample of each is put through the start pass on an approved pending task with a recheck-date not yet due, and the start holds
## exactly the `unmet` one. The grooming routine's Block and Unblock verbs write those forms. Offline: a rig data root, nothing spawned.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
rigModel="${rigHere%/sh-lib}/skillset/magic-team/magic-team/reference/board-model.md"
rigGrooming="${rigHere%/sh-lib}/skillset/magic-team/magic-team/magic-team.grooming.routine.md"
[ -f "$rigHere/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's functions are not at the origin this workspace resolves: $rigHere"
[ -f "$rigModel" ] || rigRefuse "the board model is not at the origin this workspace resolves: $rigModel"
[ -f "$rigGrooming" ] || rigRefuse "the grooming routine is not at the origin this workspace resolves: $rigGrooming"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConditionConventionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$MDLT_ORIGIN"
rigOwnerBoardReady

## The forms, as the section's own list items write them: `<word>: …` in backticks, the section ending at the next heading.
rigForms="$( LC_ALL=C awk '
	$0 == "## `condition` and `recheck-date`" { inSection = 1 ; next ; }
	inSection && /^#/ { exit ; }
	inSection && /^  - `(unmet|met|none): / { formText = $0 ; sub( /^  - `/, "", formText ) ; sub( /`.*$/, "", formText ) ; print formText ; }
' "$rigModel" )"
rigAssert "the section names the three forms, unmet, met and none, once each" \
	"$( printf '%s\n' "$rigForms" | LC_ALL=C sed 's/:.*//' | LC_ALL=C sort | tr '\n' ' ' )" "met none unmet "
rigAssert "its Contents names the section" "$( LC_ALL=C grep -c -x -F -- '- `condition` and `recheck-date`' "$rigModel" || : )" 1

## One sample of each form on its own approved pending task, every placeholder filled, a recheck-date not yet due beside it.
rigRow=0
while IFS= read -r rigForm ; do
	[ -n "$rigForm" ] || continue
	rigRow=$(( rigRow + 1 ))
	{ printf '%s\n' '---' 'type: task' 'owner: rig' 'approved-by: human-owner (rig-session, 2026-01-01T00:00:00Z)'
	  printf 'condition: %s\n' "$( printf '%s' "$rigForm" | LC_ALL=C sed 's/<[^>]*>/rig/g' )"
	  printf '%s\n' 'recheck-date: 2099-01-01 00:00 +0000' '---' '' '# a form sample' ; } | rigOwnerBoardLegacyPut "task-20260101T000${rigRow}Z-${rigForm%%:*}.md"
done <<< "$rigForms"
## The start pass's own filter, its routine lookup stubbed to log the item and stop, so nothing is moved or started.
rigLog="$rigTmp/filter.log"
: > "$rigLog"
env MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=check RIG_LOG="$rigLog" RIG_HERE="$rigHere" bash -c '
	. "$RIG_HERE/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
	. "$RIG_HERE/board/AgentsTools.BoardItemHandler.include" > /dev/null 2>&1
	type AgentsToolsScheduleStartPending > /dev/null 2>&1 || exit 3
	AgentsToolsScheduleCurrentFlags(){ printf "worktime: yes\novertime: no\nemergency: no\n" ; }
	AgentsToolsSchedulePaceText(){ printf "pace: a duty start is allowed\n" ; }
	AgentsToolsBoardItemHandler(){ printf "%s\n" "${1##*/}" >> "$RIG_LOG" ; return 1 ; }
	AgentsToolsScheduleSpawn(){ return 1 ; }
	AgentsToolsScheduleStartPending > /dev/null 2>&1
' || rigRefuse "the start pass could not be run"
for rigWord in unmet met none ; do
	rigWant=started ; [ "$rigWord" != unmet ] || rigWant=held
	rigAssert "a sample of the $rigWord form, a date not yet due beside it, is $rigWant by the start pass" \
		"$( LC_ALL=C grep -q -e "-$rigWord\.md$" "$rigLog" && echo started || { ls "$rigData/board/pending" 2> /dev/null | LC_ALL=C grep -q -e "-$rigWord\.md$" && echo held || echo no-sample ; } )" "$rigWant"
done

## The grooming routine writes the same forms: Block the unmet one, Unblock the met and none ones.
rigFormOf(){ printf '%s\n' "$rigForms" | LC_ALL=C grep -m 1 -e "^$1: " || : ; }
rigAssert "the grooming Block verb writes the unmet form" \
	"$( LC_ALL=C grep -F -- '**Block**: `--grooming-to-blocked`' "$rigGrooming" | LC_ALL=C grep -c -F -- "\`condition: $( rigFormOf unmet )\`" || : )" 1
rigAssert "the grooming Unblock verb writes the met and none forms" \
	"$( LC_ALL=C grep -F -- '**Unblock**: `--grooming-to-pending`' "$rigGrooming" | LC_ALL=C grep -F -- "\`$( rigFormOf met )\`" | LC_ALL=C grep -c -F -- "\`$( rigFormOf none )\`" || : )" 1
if [ "$rigFails" -ne 0 ] ; then echo "⛔ CONDITION CONVENTION CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "CONDITION_CONVENTION: OK ($rigPasses assertions, offline)"
