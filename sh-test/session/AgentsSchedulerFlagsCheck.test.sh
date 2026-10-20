#!/usr/bin/env bash
## Behavioural check on the schedule's flags and their setters (F7.5 of the refactorings epic, DistroAgentsDispatcher.fn.sh): scheduling is a
## convention with an interpreter, and Dispatcher owns the policy deciding when a run starts, so the flags and the setters are Dispatcher's.
## The flags are derived from the settings, the overrides and the clock, never stored (epic 1730); what persists is settings (1731, 1769).
## Held, run and not read, with a clock of the rig's own:
##   1. --current-flags prints worktime, weekend, emergency, overtime and learning, in that order, a line each, `<flag>: yes|no`; with
##      nothing set, worktime and weekend read `no (not set)` and the others `no`; it writes nothing.
##   2. The setters keep their value in the settings the epic names (Settled 2026-10-19): --set-country (two or three letters) in
##      MDAT_SCHEDULE_COUNTRY, --set-timezone (a zone name of the system) in MDAT_SCHEDULE_TIMEZONE, --set-worktime <start> <until>
##      <days-of-week> in MDAT_SCHEDULE_WORKTIME, --set-weekend <days-of-week> in MDAT_SCHEDULE_WEEKEND; a value of another form is refused
##      with a line, rc 1, and nothing is stored. The days are F5.4's: workdays, weekend, daily, or a list such as mon,thu; the weekend
##      itself is a list of days.
##   3. worktime falls out of the timezone, the hours, the days and the clock; weekend out of the timezone, its days and the clock.
##      `workdays` and `weekend` as worktime days need the weekend to be set.
##   4. The overrides are settings: emergency is set with a TTL, prolonged by a second call and cleared by --no; learning is on or off and
##      takes no TTL; overtime is for outside worktime, ends at the TTL or, with none, when normal worktime starts, and is refused
##      during worktime; worktime and weekend are derived and have no override; a flag that is none of the five is refused.
## Offline: a date first on PATH gives the rig's clock; every workspace is a folder of the rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSchedulerFlagsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills/rig-member"
printf 'rig\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
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
## Monday 2026-10-19 10:00 UTC, which is 13:00 in Etc/GMT-3 (UTC+3).
rigMon13=1792404000 ; rigMon18=1792422000 ; rigTueBefore=1792475940 ; rigTueStart=1792476000 ; rigSat13=1792836000
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
rigRc=0 rigOut=""
rigRun(){ ## script, words... -- one call from the rig workspace; rc in rigRc, stdout and stderr in rigOut
	local runScript="$1"
	shift
	rigRc=0
	rigOut="$( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$runScript" "$@" 2>&1 < /dev/null )" || rigRc=$?
	rigOut="$( printf '%s\n' "$rigOut" | LC_ALL=C grep -v -e 'SystemContext' -e 'Working in:' )"
}
rigSetting(){ ## key -- the stored value, `-` where none
	rigRun "$rigTool" --agents-config-option magic-team --select-default "$1" -
	printf '%s' "$rigOut"
}
rigFlag(){ ## flag -- its line of --current-flags
	rigRun "$rigDispatcher" --current-flags
	printf '%s' "$rigOut" | LC_ALL=C awk -v want="$1" 'index( $0, want ": " ) == 1 { print ; exit }'
}
rigStore(){ ## -- the settings file of the rig, as its sum
	[ -f "$rigWs/.local/.agents/magic-team.agent.env" ] && cksum < "$rigWs/.local/.agents/magic-team.agent.env" || printf 'none'
}

echo "-- 1. --current-flags, nothing set --"
rigRun "$rigDispatcher" --current-flags
rigAssert "five lines in the order of the epic, worktime and weekend reading no (not set), the others no" "$rigRc:$( printf '%s' "$rigOut" | tr '\n' '|' )" \
	"0:worktime: no (not set)|weekend: no (not set)|emergency: no|overtime: no|learning: no"
rigBefore="$( rigStore )" ; rigRun "$rigDispatcher" --current-flags
rigAssert "it writes nothing" "$( rigStore )" "$rigBefore"
rigRun "$rigDispatcher" --current-flags --everything
rigAssert "a word it does not take is refused, rc 1" "$rigRc" "1"

echo "-- 2. the setters --"
rigRun "$rigDispatcher" --set-country nz
rigAssert "--set-country: rc 0, the setting named, the value upper case" "$rigRc:$rigOut:$( rigSetting MDAT_SCHEDULE_COUNTRY )" "0:MDAT_SCHEDULE_COUNTRY: NZ:NZ"
rigRun "$rigDispatcher" --set-country NZL
rigAssert "--set-country takes three letters" "$rigRc:$( rigSetting MDAT_SCHEDULE_COUNTRY )" "0:NZL"
for rigBad in n n1 NZLD "" ; do
	rigRun "$rigDispatcher" --set-country "$rigBad"
	rigAssert "--set-country '$rigBad' is refused, rc 1, the value kept" "$rigRc:$( rigSetting MDAT_SCHEDULE_COUNTRY )" "1:NZL"
done
rigRun "$rigDispatcher" --set-timezone Etc/GMT-3
rigAssert "--set-timezone: a zone name of the system" "$rigRc:$rigOut:$( rigSetting MDAT_SCHEDULE_TIMEZONE )" "0:MDAT_SCHEDULE_TIMEZONE: Etc/GMT-3:Etc/GMT-3"
for rigBad in Not/AZone ../etc/passwd /etc/passwd "" ; do
	rigRun "$rigDispatcher" --set-timezone "$rigBad"
	rigAssert "--set-timezone '$rigBad' is refused, rc 1, the zone kept" "$rigRc:$( rigSetting MDAT_SCHEDULE_TIMEZONE )" "1:Etc/GMT-3"
done
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 workdays
rigAssert "--set-worktime <start> <until> <days>: kept as written" "$rigRc:$rigOut:$( rigSetting MDAT_SCHEDULE_WORKTIME )" "0:MDAT_SCHEDULE_WORKTIME: 09:00 17:00 workdays:09:00 17:00 workdays"
for rigBad in "9:00 17:00 workdays" "09:00 25:00 workdays" "17:00 09:00 workdays" "09:00 09:00 workdays" "09:00 17:00 funday" "09:00 17:00 mon,funday" "09:00 17:00" "09:00" ; do
	rigRun "$rigDispatcher" --set-worktime $rigBad
	rigAssert "--set-worktime $rigBad is refused, rc 1, the worktime kept" "$rigRc:$( rigSetting MDAT_SCHEDULE_WORKTIME )" "1:09:00 17:00 workdays"
done
rigRun "$rigDispatcher" --set-worktime 08:30 12:00 mon,thu
rigAssert "a list of days, and daily, are days too" "$rigRc:$( rigSetting MDAT_SCHEDULE_WORKTIME )" "0:08:30 12:00 mon,thu"
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 daily
rigAssert "daily" "$rigRc:$( rigSetting MDAT_SCHEDULE_WORKTIME )" "0:09:00 17:00 daily"
rigRun "$rigDispatcher" --set-weekend sat,sun
rigAssert "--set-weekend <days-of-week>: kept as written" "$rigRc:$rigOut:$( rigSetting MDAT_SCHEDULE_WEEKEND )" "0:MDAT_SCHEDULE_WEEKEND: sat,sun:sat,sun"
for rigBad in weekend workdays daily funday "sat,funday" "" ; do
	rigRun "$rigDispatcher" --set-weekend "$rigBad"
	rigAssert "--set-weekend '$rigBad' is refused (the weekend is a list of days), rc 1, the weekend kept" "$rigRc:$( rigSetting MDAT_SCHEDULE_WEEKEND )" "1:sat,sun"
done
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 workdays

echo "-- 3. worktime and weekend from the clock --"
rigAt "$rigMon13"
rigAssert "Monday 13:00 in the zone: worktime, no weekend" "$( rigFlag worktime )|$( rigFlag weekend )" "worktime: yes|weekend: no"
rigAt "$rigMon18"
rigAssert "Monday 18:00: after the hours" "$( rigFlag worktime )" "worktime: no"
rigAt "$rigTueBefore"
rigAssert "Tuesday 08:59: before them" "$( rigFlag worktime )" "worktime: no"
rigAt "$rigTueStart"
rigAssert "Tuesday 09:00: they begin" "$( rigFlag worktime )" "worktime: yes"
rigAt "$rigSat13"
rigAssert "Saturday 13:00: weekend, and no worktime on workdays" "$( rigFlag worktime )|$( rigFlag weekend )" "worktime: no|weekend: yes"
rigAt "$rigMon13"
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 tue,thu
rigAssert "worktime days as a list: Monday is not one" "$( rigFlag worktime )" "worktime: no"
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 weekend
rigAssert "weekend as worktime days: not on a Monday" "$( rigFlag worktime )" "worktime: no"
rigAt "$rigSat13"
rigAssert "weekend as worktime days: on a Saturday" "$( rigFlag worktime )" "worktime: yes"
rigRun "$rigDispatcher" --set-worktime 09:00 17:00 workdays
rigRun "$rigTool" --agents-config-option magic-team --delete MDAT_SCHEDULE_WEEKEND
rigAt "$rigMon13"
rigAssert "workdays with the weekend not set cannot be decided: no (weekend not set)" "$( rigFlag worktime )|$( rigFlag weekend )" "worktime: no (weekend not set)|weekend: no (not set)"
rigRun "$rigDispatcher" --set-weekend sat,sun

echo "-- 4. the overrides --"
rigRun "$rigDispatcher" --override-flag emergency
rigAssert "emergency without a TTL is refused, rc 1" "$rigRc:$( rigFlag emergency )" "1:emergency: no"
rigRun "$rigDispatcher" --override-flag emergency 3600
rigAssert "emergency <ttl>: yes, with the seconds left, kept as a setting" "$rigRc:$rigOut:$( rigFlag emergency ):$( rigSetting MDAT_SCHEDULE_EMERGENCY )" "0:emergency: yes (3600 seconds left):emergency: yes (3600 seconds left):until $(( rigMon13 + 3600 ))"
rigAt $(( rigMon13 + 1800 ))
rigAssert "the seconds left follow the clock" "$( rigFlag emergency )" "emergency: yes (1800 seconds left)"
rigRun "$rigDispatcher" --override-flag emergency 7200
rigAssert "a second call prolongs it: the end is the TTL from then" "$rigRc:$( rigFlag emergency )" "0:emergency: yes (7200 seconds left)"
rigAt $(( rigMon13 + 1800 + 7201 ))
rigAssert "it ends at its end" "$( rigFlag emergency )" "emergency: no"
rigAt "$rigMon13"
rigRun "$rigDispatcher" --override-flag emergency 3600
rigRun "$rigDispatcher" --override-flag --no emergency
rigAssert "--no clears it: no, and the setting gone" "$rigRc:$rigOut:$( rigFlag emergency ):$( rigSetting MDAT_SCHEDULE_EMERGENCY )" "0:emergency: no:emergency: no:-"
rigRun "$rigDispatcher" --override-flag --no emergency 60
rigAssert "--no with a TTL is refused" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag emergency 0
rigAssert "a TTL is whole seconds, 1 or more: 0 is refused" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag emergency soon
rigAssert "a TTL that is no number is refused" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag learning
rigAssert "learning is on: yes, kept as a setting" "$rigRc:$( rigFlag learning ):$( rigSetting MDAT_SCHEDULE_LEARNING )" "0:learning: yes:on"
rigRun "$rigDispatcher" --override-flag learning 60
rigAssert "learning is on or off and takes no TTL" "$rigRc:$( rigFlag learning )" "1:learning: yes"
rigRun "$rigDispatcher" --override-flag --no learning
rigAssert "--no learning: off" "$rigRc:$( rigFlag learning ):$( rigSetting MDAT_SCHEDULE_LEARNING )" "0:learning: no:-"
rigAt "$rigMon13"
rigRun "$rigDispatcher" --override-flag overtime
rigAssert "overtime during worktime is refused: it is for outside worktime" "$rigRc:$( rigFlag overtime )" "1:overtime: no"
rigAt "$rigMon18"
rigRun "$rigDispatcher" --override-flag overtime
rigAssert "overtime with no TTL, outside worktime: yes, until normal worktime starts (Tuesday 09:00)" "$rigRc:$( rigFlag overtime ):$( rigSetting MDAT_SCHEDULE_OVERTIME )" "0:overtime: yes (54000 seconds left):until $rigTueStart"
rigAt "$rigTueBefore"
rigAssert "it holds until then" "$( rigFlag overtime )" "overtime: yes (60 seconds left)"
rigAt "$rigTueStart"
rigAssert "and is dropped when normal worktime starts" "$( rigFlag overtime )|$( rigFlag worktime )" "overtime: no|worktime: yes"
rigAt "$rigMon18"
rigRun "$rigDispatcher" --override-flag overtime 3600
rigAssert "overtime with a TTL: until then" "$rigRc:$( rigFlag overtime )" "0:overtime: yes (3600 seconds left)"
rigRun "$rigDispatcher" --override-flag overtime 99999
rigAssert "a TTL past the start of worktime is cut at it" "$rigRc:$( rigFlag overtime )" "0:overtime: yes (54000 seconds left)"
rigRun "$rigDispatcher" --override-flag --no overtime
rigAssert "--no overtime: off" "$rigRc:$( rigFlag overtime )" "0:overtime: no"
rigRun "$rigDispatcher" --override-flag worktime
rigAssert "worktime is derived and has no override" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag --no weekend
rigAssert "nor has weekend" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag holiday
rigAssert "a flag that is none of the five is refused" "$rigRc" "1"
rigRun "$rigDispatcher" --override-flag
rigAssert "no flag is refused" "$rigRc" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULER FLAGS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULER_FLAGS: OK (%d assertions, offline)\n' "$rigPassCount"
