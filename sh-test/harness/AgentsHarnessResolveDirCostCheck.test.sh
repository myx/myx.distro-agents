#!/usr/bin/env bash
## Behavioural check of the harness's path resolution on a call path (AgentsHarnessResolveDir): a lookup costs the same whatever
## was asked before it in the process, never a scan of every earlier path. A harness start resolves every access root, hundreds
## where the roots index does not vouch, so a scan per lookup is a walk of the whole set on every root. Held:
##   1. two hundred distinct paths cost at most twelve lines a lookup inside the function, not a growing scan
##   2. a path that is no directory answers itself, and enters no directory
##   3. a directory answers its real path, and a second ask of it enters no directory
##   4. a path that became a directory after its miss is resolved afresh
## Red before the change: the cache is searched from its first entry, so the two hundred lookups run some sixty thousand lines.
## Offline: a rig folder of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessResolveDirCostCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
mkdir -p "$rigTmp/real-dir" "$rigTmp/later" || exit 1
rmdir "$rigTmp/later" || exit 1
rigPs4='+${FUNCNAME[0]}: '

echo "-- 1. a lookup costs the same, however many came before it --"
rigLines="$( bash -c '. "$1/sh-lib/harness/AgentsHarnessAccess.include" || exit 1 ; PS4="$3" ; set -x
	costAt=0 ; while [ "$costAt" -lt 200 ] ; do AgentsHarnessResolveDir "$2/absent-$costAt" costOut ; costAt=$(( costAt + 1 )) ; done
	set +x' _ "$rigPkg" "$rigTmp" "$rigPs4" 2>&1 > /dev/null | LC_ALL=C awk '/^\++AgentsHarnessResolveDir: / { n++ } END { print n + 0 }' )"
rigAssert "control: the trace reaches the function" "$( [ "$rigLines" -gt 0 ] && echo reached || echo none )" reached
rigAssert "two hundred lookups stay within twelve lines each ($rigLines lines)" "$( [ "$rigLines" -le 2400 ] && echo bounded || echo grows )" bounded

echo "-- 2 to 4. the answers --"
rigAnswers="$( bash -c '. "$1/sh-lib/harness/AgentsHarnessAccess.include" || exit 1 ; PS4="$3"
	AgentsHarnessResolveDir "$2/absent-x" ansMiss ; printf "MISS=%s\n" "$ansMiss"
	AgentsHarnessResolveDir "$2/real-dir" ansHit ; printf "HIT=%s\n" "$ansHit"
	set -x ; AgentsHarnessResolveDir "$2/real-dir" ansAgain ; set +x ; printf "AGAIN=%s\n" "$ansAgain"
	set -x ; AgentsHarnessResolveDir "$2/absent-y" ansMissTwo ; set +x
	AgentsHarnessResolveDir "$2/later" ansBefore ; mkdir "$2/later" ; printf "LATER-BEGIN\n" >&2
	set -x ; AgentsHarnessResolveDir "$2/later" ansAfter ; set +x ; printf "LATER=%s|%s\n" "$ansBefore" "$ansAfter"
' _ "$rigPkg" "$rigTmp" "$rigPs4" 2>&1 )"
rigAssert "a path that is no directory answers itself" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed -n 's/^MISS=//p' )" "$rigTmp/absent-x"
rigAssert "a directory answers its real path" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed -n 's/^HIT=//p' )" "$rigTmp/real-dir"
rigAssert "and asked again answers the same" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed -n 's/^AGAIN=//p' )" "$rigTmp/real-dir"
rigAssert "the second ask and a miss enter no directory" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed '/^LATER-BEGIN$/,$d' | LC_ALL=C grep -c -E '^\++AgentsHarnessResolveDir: cd ' || : )" "0"
rigAssert "a path that became a directory after its miss answers its real path" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed -n 's/^LATER=//p' )" "$rigTmp/later|$rigTmp/later"
rigAssert "and is entered afresh, not answered from its miss" "$( printf '%s\n' "$rigAnswers" | LC_ALL=C sed -n '/^LATER-BEGIN$/,$p' | LC_ALL=C grep -c -E '^\++AgentsHarnessResolveDir: cd ' || : )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS RESOLVE DIR COST CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_RESOLVE_DIR_COST: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
