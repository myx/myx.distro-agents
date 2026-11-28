#!/usr/bin/env bash
## Behavioural check of the ingest pass's cost on the comms reader (code-craft: no process per pass where the caller's clock or a kept
## moment answers). AgentsCommsIngestPass in a rig store of fifty channel sources, the ingest itself a stub that records its call and
## writes the folder's .ingest.txt, as the real one does; date and stat counted:
##   1. a first pass given the caller's epoch ingests the fifty due sources and starts no date
##   2. a second pass five seconds on, every source pulled again, ingests none (their TTL has not passed) and asks stat of none
##   3. a third pass twenty seconds on ingests all fifty again, and asks stat of none
##   4. control: the TTL table still answers 15 for a Slack source and 60 for mentions
## Red before the change: each pass started date, and each due source was asked of stat on every pass.
## Offline: a rig store of this check's own; no source is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIngestPassForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigStore="$rigTmp/ws/.local/cache/comms/slack"
rigForks="$rigTmp/forks"
rigI=0
while [ "$rigI" -lt 50 ] ; do
	rigFolder="$rigStore/slack-bot-C0RIG$( printf '%05d' "$rigI" )"
	mkdir -p "$rigFolder" || exit 1
	printf '1 0 0\n\nslack-conversation C0RIG%05d magic-rig false\n' "$rigI" > "$rigFolder/.state.txt"
	rigI=$(( rigI + 1 ))
done
cat > "$rigTmp/ingest-stub" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ] ; do [ "$1" = "--folder" ] && { : > "$2/.ingest.txt" ; printf 'ingest\n' >> "$rigForks" ; } ; shift ; done
exit 0
EOF
chmod +x "$rigTmp/ingest-stub"
rigNow="$( date +%s )"
rigOut="$( MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigForks="$rigForks" rigStore="$rigStore" rigNow="$rigNow" rigStub="$rigTmp/ingest-stub" bash -c '
	. "$rigPkg/sh-lib/comms/AgentsTools.CommsIngestPass.include" || exit 1
	BASH="$rigStub"
	date(){ printf "date\n" >> "$rigForks" ; command date "$@" ; }
	stat(){ printf "stat\n" >> "$rigForks" ; command stat "$@" ; }
	count(){ printf "%s=%s " "$1" "$( grep -cx "$1" "$rigForks" )" ; }
	: > "$rigForks" ; AgentsCommsIngestPass 0 "$rigNow" > /dev/null 2>&1 ; count date ; count ingest ; echo
	sleep 1 ; for s in "$rigStore"/*/.state.txt ; do : >> "$s" ; touch "$s" ; done
	: > "$rigForks" ; AgentsCommsIngestPass 0 "$(( rigNow + 5 ))" > /dev/null 2>&1 ; count date ; count ingest ; count stat ; echo
	: > "$rigForks" ; AgentsCommsIngestPass 0 "$(( rigNow + 20 ))" > /dev/null 2>&1 ; count date ; count ingest ; count stat ; echo
	. "$rigPkg/sh-lib/member/AgentsTools.SourceTtl.include" ; printf "ttl=%s/%s\n" "$( AgentsToolsSourceTtlOf slack:C0X )" "$( AgentsToolsSourceTtlOf mentions:x )"
' 2> /dev/null )"
rigLine(){ printf '%s\n' "$rigOut" | sed -n "${1}p" ; }

echo "-- 1. a first pass: fifty ingests, no date --"
rigAssert "the first pass" "$( rigLine 1 )" "date=0 ingest=50 "
echo "-- 2. five seconds on: none due, no stat --"
rigAssert "the second pass" "$( rigLine 2 )" "date=0 ingest=0 stat=0 "
echo "-- 3. twenty seconds on: all due, no stat --"
rigAssert "the third pass" "$( rigLine 3 )" "date=0 ingest=50 stat=0 "
echo "-- 4. control: the TTL table --"
rigAssert "a Slack source and mentions" "$( rigLine 4 )" "ttl=15/60"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS INGEST PASS FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_INGEST_PASS_FORK: OK (%d assertions, offline, rig store only)\n' "$rigPass"
