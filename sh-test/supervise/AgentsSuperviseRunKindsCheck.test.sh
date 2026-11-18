#!/usr/bin/env bash
## Behavioural check of the scan's two kinds read from the run-record table alone: `start-failing`
## (sh-lib/supervise/AgentsTools.SuperviseStartFailing.include) and `stale-rules` (AgentsTools.SuperviseStaleRules.include).
## Each kind is printed where its case holds and left out where it does not. Offline: the table and the skillset are fixtures
## in the rig, and nothing outside it is read or written.
set -u
[ -n "${MMDAPP:-}" ] || { echo "⛔ ERROR: MMDAPP is not set" >&2 ; exit 1 ; }
rigHere="$( cd "$( dirname "$0" )/../.." && pwd )"
[ -n "${MDLT_ORIGIN:-}" ] || MDLT_ORIGIN="$( cd "$rigHere/../.." && pwd )"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSuperviseRunKindsCheck.XXXXXX" )" || exit 1
trap 'rm -rf "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then rigPass=$(( rigPass + 1 )) ; printf '  PASS  %s\n' "$1"
	else rigFail=$(( rigFail + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fi
}
. "$rigHere/sh-lib/supervise/AgentsTools.SuperviseStartFailing.include"
. "$rigHere/sh-lib/supervise/AgentsTools.SuperviseStaleRules.include"
rigWs="$rigTmp/ws" ; mkdir -p "$rigWs/.local/agents/spawned"
rigNow="$( date +%s )"
rigRow(){ ## written, session id, owner, status -- one table row, TAB-separated
	printf 'sbx\tname\t%s\tspawn-%s\t%s\t%s\t%s\n' "$1" "${2:0:8}" "$2" "$3" "$4"
}
rigTouch(){ ## epoch, file
	touch -t "$( date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S )" "$2"
}

echo "-- start-failing --"
rigTable="$( rigRow $(( rigNow - 600 )) 11111111-aaaa magic-devops spawn-failed
rigRow $(( rigNow - 300 )) 11111111-aaaa magic-devops spawn-failed
rigRow $(( rigNow - 300 )) 22222222-aaaa magic-tester spawn-failed
rigRow $(( rigNow - 500 )) 33333333-aaaa magic-architect spawn-failed
rigRow $(( rigNow - 400 )) 33333333-aaaa magic-architect spawn-failed
rigRow $(( rigNow - 100 )) 33333333-aaaa magic-architect spawn-started
rigRow $(( rigNow - 7300 )) 44444444-aaaa magic-frontender spawn-failed
rigRow $(( rigNow - 7200 )) 44444444-aaaa magic-frontender spawn-failed )"
rigOut="$( AgentsToolsSuperviseStartFailing "$rigWs" "$rigNow" "$rigTable" 2> /dev/null )"
rigAssert "two failed starts in the hour and none open: named, with its count and age" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^start-failing ws 11111111 magic-devops failed=2 last=5m why=' )" 1
rigAssert "one failed start is not" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 22222222 )" 0
rigAssert "a session with a run open now is not" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 33333333 )" 0
rigAssert "failures older than the hour are not" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 44444444 )" 0

echo "-- stale-rules --"
rigSkills="$rigTmp/skillset" ; mkdir -p "$rigSkills/magic-team"
printf 'rule\n' > "$rigSkills/magic-team/a.md" ; printf 'rule\n' > "$rigSkills/magic-team/b.md"
rigTouch $(( rigNow - 18000 )) "$rigSkills/magic-team/a.md"
rigTouch $(( rigNow - 1800 )) "$rigSkills/magic-team/b.md"
rigTable="$( rigRow $(( rigNow - 7200 )) 55555555-aaaa magic-coordinator spawn-started
rigRow $(( rigNow - 3700 )) 55555555-aaaa magic-coordinator spawn-started
rigRow $(( rigNow - 60 )) 66666666-aaaa magic-tester spawn-started
rigRow $(( rigNow - 9000 )) 77777777-aaaa magic-devops spawn-succeeded )"
rigOut="$( AgentsToolsSuperviseStaleRules "$rigWs" "$rigNow" "$rigTable" "$rigSkills" 2> /dev/null )"
rigAssert "an open run started before the newest change: named once, by its oldest run" \
	"$rigOut" 'stale-rules ws 55555555 magic-coordinator started=2h changed=30m'
rigAssert "a run started after it is not, nor a run no longer open" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e 66666666 -e 77777777 )" 0
rigTouch $(( rigNow - 18000 )) "$rigSkills/magic-team/b.md"
rigAssert "with nothing changed since the oldest open run started, nothing is named" \
	"$( AgentsToolsSuperviseStaleRules "$rigWs" "$rigNow" "$rigTable" "$rigSkills" 2> /dev/null )" ""
rigAssert "with no run open, nothing is named and nothing is read" \
	"$( AgentsToolsSuperviseStaleRules "$rigWs" "$rigNow" "$( rigRow $(( rigNow - 60 )) 77777777-aaaa magic-devops spawn-succeeded )" "$rigTmp/absent" 2> /dev/null ):$?" ":0"
echo
[ "$rigFail" -eq 0 ] || { echo "⛔ SUPERVISE RUN KINDS CHECK FAILED: $rigFail of $(( rigPass + rigFail ))" >&2 ; exit 1 ; }
echo "SUPERVISE_RUN_KINDS: OK ($rigPass assertions, offline, rig tree only)"
