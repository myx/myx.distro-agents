#!/usr/bin/env bash
## Behavioural check on the strict-JSON repair of a kept context before a resume (sh-lib/harness/AgentsHarnessContext.include,
## AgentsHarnessContextRepair): a line the provider's parser would refuse is replaced by a short note record, so the request
## body is always valid JSON. Held, run rather than read:
##   1. A BAD RECORD IS REPLACED: every line of the repaired file parses strictly, and the count is unchanged.
##   2. THE NOTE NAMES WHAT HAPPENED, once.
##   3. THE VALID LINES ARE UNTOUCHED, byte for byte.
##   4. THE CONTROL: a clean file comes back byte-identical, so the repair is not a rewrite of everything.
## Measured 2026-11-25: a 46,365-byte tool record passed the local validator and the provider refused the request
## ("messages[26]: expected value", request 2ebc679f), so the resumed run died in one second.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/harness/AgentsHarnessContext.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessContextRepairCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigRepair(){ ## file -- runs the repair, printing the NOTE line
	MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" || exit 9 ; AgentsHarnessContextRepair "$2"' rig-repair "$rigInclude" "$1" 2>&1
}
rigStrict(){ ## file -- how many lines fail strict JSON
	python3 - "$1" <<'PY'
import json,sys
bad=0
for line in open(sys.argv[1],encoding='utf-8'):
    try: json.loads(line)
    except Exception: bad+=1
print(bad)
PY
}
rigCtx(){ ## file, message numbers..., one corrupt record at the number given with a trailing "x"
	local ctxFile="$1" ctxNo=1
	shift
	{
		printf '{"type":"context","session":"rig"}\n'
		printf '{"type":"system","text":"rig"}\n'
		printf '{"type":"tools","tools":[]}\n'
		for ctxNo in "$@" ; do
			case "$ctxNo" in *x) printf '{"type":"message","n":%s,"kind":"tool","record":{BROKEN\n' "${ctxNo%x}" ;;
				*) printf '{"type":"message","n":%s,"kind":"assistant","record":{"role":"assistant","content":"rig"}}\n' "$ctxNo" ;;
			esac
		done
	} > "$ctxFile"
}
echo "-- 1. a bad record is replaced --"
rigCtx "$rigTmp/bad.ctx" 1 5x 6
rigNote="$( rigRepair "$rigTmp/bad.ctx" )"
rigAssert "every line parses strictly after the repair" "$( rigStrict "$rigTmp/bad.ctx" )" "0"
rigAssert "the message count is unchanged: the record is replaced, not dropped" "$( LC_ALL=C grep -c '"type":"message"' "$rigTmp/bad.ctx" )" "2"
echo "-- 2. the note names what happened --"
rigAssert "the NOTE is printed once" "$( printf '%s\n' "$rigNote" | LC_ALL=C grep -c 'failed strict JSON and were replaced at resume' )" "1"
echo "-- 3. the valid lines are untouched --"
rigAssert "the first message survives byte for byte" "$( LC_ALL=C grep -c '"n":1,"kind":"assistant","record":{"role":"assistant","content":"rig"}' "$rigTmp/bad.ctx" )" "1"
rigAssert "the last message survives byte for byte" "$( LC_ALL=C grep -c '"n":6,"kind":"assistant","record":{"role":"assistant","content":"rig"}' "$rigTmp/bad.ctx" )" "1"
echo "-- 4. the control: a clean file is untouched --"
rigCtx "$rigTmp/clean.ctx" 1 2
rigBefore="$( cksum < "$rigTmp/clean.ctx" )"
rigRepair "$rigTmp/clean.ctx" > /dev/null 2>&1
rigAssert "a clean file comes back byte-identical" "$( cksum < "$rigTmp/clean.ctx" )" "$rigBefore"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CONTEXT REPAIR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'HARNESS_CONTEXT_REPAIR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
