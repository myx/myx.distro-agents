#!/usr/bin/env bash
## S7.20 — the Schedule screen's write arms answer, and the operations behind them store what they say.
## Run, not read, against the REAL dispatcher: a scratch workspace of this rig's own, in a clean `env -i` as the console
## operator runs it, calling `DistroAgentsTools.fn.sh` itself. The screen half of S7.20 (Enter on a flag row opens its
## dialog) is the same item's second change and is held until these arms answer.
##
## Held (epic 20261102-refactorings, S7.20; audit S7.16 item 1; names settled by the coordinator, relayed 2026-11-03
## 00:16Z): `--manager-schedule-set-weekend sat,sun` stores a weekend that `--manager-schedule-read` then reports;
## `--manager-schedule-override-flag learning` sets a flag and `-- --no` clears it; `--manager-schedule-set-worktime
## 07:00 23:00 workdays` stores, while a bad value such as `25:00` is refused and stores nothing; and
## `--manager-schedule-override-flag worktime` is refused, saying worktime is derived. Today the three operations do not
## exist: each call is an invalid option with exit 1 (AgentsTools.ManagerSchedule.include:23 has only the read).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScheduleWriteLiveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## text, words -- yes where the text holds them
	case "${1:-}" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## ---- the rig: a scratch workspace, its own HOME and team data, and the real dispatcher, called as the console calls it ----
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigStore="$rigTmp/store"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/.local/temp" "$rigHome/skills/magic-tester" \
	"$rigStore/board" "$rigStore/audit" "$rigStore/contacts" "$rigStore/inboxes" "$rigStore/vault" \
	|| rigRefuse "the rig could not be made"
: > "$rigWs/.local/MDLT.settings.env"
printf -- '---\nname: magic-tester\n---\nrig identity\n' > "$rigHome/skills/magic-tester/magic-tester.basic.md"
rigRun(){ ## the operation and its words; prints what it printed and sets rigRc, rigOut, rigErr
	rigOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=en_US.UTF-8 \
		MDAT_WORKSPACE_MODE=team-rig MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigStore" \
		MDAT_SKILLSET_ROOT="$rigHome/skills" MDAT_BASH=/bin/bash MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" "$@" 2> "$rigTmp/last.err" )"
	rigRc=$?
	rigErr="$( cat "$rigTmp/last.err" )"
}
rigRead(){ ## a flag's answer in --manager-schedule-read, by its name
	rigRun --manager-schedule-read
	LC_ALL=C awk -v want="$1" -F'\t' '$1 == "flag" && $2 == want { print $3 ; exit }' <<< "$rigOut"
}

## ---- the four calls, each with the state it must leave ----
## The weekend flag answers whether today is one of the weekend's days, so the check names today: the read's own `now` row
## gives the weekday, and the weekend is set to it. That keeps the flag assertion true on any day of the week.
rigRun --manager-schedule-read
rigToday="$( LC_ALL=C awk -F'\t' '$1 == "now" { print $3 ; exit }' <<< "$rigOut" )"
case "$rigToday" in mon|tue|wed|thu|fri|sat|sun) rigTodayOk="yes" ;; *) rigTodayOk="no" ;; esac
rigAssert "the schedule read names today's weekday, so the weekend can be set to it" "$rigTodayOk" "yes"
rigRun --manager-schedule-set-weekend "$rigToday"
rigAssert "set-weekend of today's own weekday answers exit 0" "$rigRc" "0"
rigAssert "and the read then reports weekend yes" "$( rigRead weekend )" "yes"

rigRun --manager-schedule-override-flag learning
rigAssert "override-flag learning answers exit 0" "$rigRc" "0"
rigAssert "and the read then reports learning yes" "$( rigRead learning )" "yes"
rigRun --manager-schedule-override-flag --no learning
rigAssert "override-flag --no learning answers exit 0" "$rigRc" "0"
rigAssert "and the read then reports it cleared" "$( rigRead learning )" "no"

rigRun --manager-schedule-set-worktime 07:00 23:00 workdays
rigAssert "set-worktime answers exit 0" "$rigRc" "0"
## The read has no `worktime` row of its own: it gives the flag and one `cell` a day and an hour, `worktime` inside the
## window (AgentsManagerScheduleGrid / --manager-schedule-read). The window is read off those cells, which is the shape the
## screen draws.
rigRun --manager-schedule-read
rigCells="$( LC_ALL=C awk -F'\t' '$1 == "cell" && $2 == "mon" && $4 == "worktime" { printf "%s ", $3 }' <<< "$rigOut" )"
rigAssert "and the read then puts Monday's working cells at 07:00 through 22:00, not the default window" "$rigCells" "07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 "

rigRun --manager-schedule-set-worktime 25:00 23:00 workdays
rigAssert "a worktime of 25:00 is refused with exit 1" "$rigRc" "1"
rigRun --manager-schedule-read
rigCells="$( LC_ALL=C awk -F'\t' '$1 == "cell" && $2 == "mon" && $4 == "worktime" { printf "%s ", $3 }' <<< "$rigOut" )"
rigAssert "and the window the read gives is still the good one" "$rigCells" "07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 "

rigRun --manager-schedule-override-flag worktime
rigAssert "override-flag worktime is refused with exit 1" "$rigRc" "1"
rigAssert "and says worktime is derived" "$( rigHas "$rigErr" "derived" )" "yes"

## The known positive, in the same rig: the read the screen already uses answers, so a failing call above is about that
## operation and not about the rig.
rigRun --manager-schedule-read
rigAssert "the schedule read of the same rig answers" "$( rigHas "$rigOut" "flag" )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCHEDULE WRITE LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCHEDULE_WRITE_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
