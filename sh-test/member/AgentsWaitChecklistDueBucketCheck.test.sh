#!/usr/bin/env bash
## RED CHECK for the second gap in S13.9: the `checklist:<member>` Wait source puts an item in its
## due bucket by the presence of a ` (due: ` mark alone, with no comparison against now.
## The code's own comment at AgentsTools.MemberWaitLocal.include:144-147 says "An item past its due
## time is rendered with its own line first", and the epic's item says "An item past its due time is
## a Wait floor source". The test at :172 is `*' (due: '*)`, which every due mark matches.
## Measured consequence: a future due time is filed as due and rendered twice, once `due` and once
## `open`. Red today: 2 of 3. Green once the bucket compares the moment, as the Wait's own block does
## at AgentsHarnessBatch.include:307-309.
## Offline: this rig's own tree, the probe called directly.
set -u
: "${MMDAPP:?MMDAPP is not set}"
: "${MDLT_ORIGIN:?MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPkg/sh-lib/member/AgentsTools.MemberWaitLocal.include" ] || { echo "ERROR: no wait include" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitChecklistDueBucketCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/.local/agents/sessions/rig-bucket"
rigList="$rigTmp/.local/agents/sessions/rig-bucket/magic-developer.checklist.md"

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }
## The probe's own rendering: its buckets are `<bucket><tab><line>`.
rigProbe(){ ## output file
	MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitCore.include"
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWaitLocal.include"
		waitSessionId=rig-bucket
		AgentsWaitProbeChecklist magic-developer magic-developer x "$1"
	' _ "$1"
}

echo "-- the control: a past due item is filed as due, and said once --"
printf -- '- [ ] Overdue (due: 2020-01-01 00:00 +0000)\n- [ ] Plain\n' > "$rigList"
rigProbe "$rigTmp/past.out"
rigAssert "the past due item is in the due bucket" "$( LC_ALL=C grep -c '^due'$'\t' "$rigTmp/past.out" || : )" 1

echo "-- a future due item is not due, and is not said twice --"
printf -- '- [ ] Later (due: 2099-01-01 00:00 +0000)\n- [ ] Plain\n' > "$rigList"
rigProbe "$rigTmp/future.out"
rigAssert "nothing is in the due bucket" "$( LC_ALL=C grep -c '^due'$'\t' "$rigTmp/future.out" || : )" 0
rigAssert "and the item is said once" \
	"$( LC_ALL=C grep -c -F -- 'Later (due: 2099-01-01 00:00 +0000)' "$rigTmp/future.out" || : )" 1

if [ "$rigFail" -ne 0 ] ; then
	printf 'WAIT CHECKLIST DUE BUCKET: FAILED, %d of %d assertions red\n' "$rigFail" "$(( rigPass + rigFail ))" >&2
	exit 1
fi
printf 'WAIT CHECKLIST DUE BUCKET: OK (%d assertions)\n' "$rigPass"
