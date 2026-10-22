#!/usr/bin/env bash
## Behavioural check on the order of scans in a Wait and on the scan not begun (AgentsTools.MemberWait.include, "THE SCANS ARE READ LAST" and the
## round loop). A scan is the one source whose read takes minutes, so in a session's wait it follows every other source, and it is not begun once
## something has arrived in the round, nor once the bound has passed in it. Held:
##   1. a scan named first is read last: it follows the other sources in `# sources:`
##   2. a scan is not begun once something has arrived in the round: the inbox arrival is returned, the scan is named in WAIT-NEVER-READ and none of its report is in the return
##   3. control, nothing else arrived: the same scan is read and arrives
## Red before the change: 1 lists the scan first, and 2 returns the scan too.
## Offline: a Slack-shaped fake curl logs and answers any call; every tree is this rig's own; the collect window of the scan is one second.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A scan may start the control thread of a session of its rig that is not finished: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitScanLastCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
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
rigMember="magic-coordinator"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned/rig" "$rigW/.local/agents/members/$rigMember" "$rigD/inboxes/$rigMember/incoming" "$rigH"
## The rig's own workspace has a source folder: the context of the tool is detected from it.
ln -s "${rigHere%/myx/myx.distro-agents/sh-lib}" "$rigW/source" || rigRefuse "the rig's source link could not be made"
printf '# %s\n' "$rigMember" > "$rigW/.local/agents/members/$rigMember/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
done
rigQuiet="$rigTmp/quiet.txt"
: > "$rigQuiet"
rigBind(){ ## session id, routine file name or empty -- the spawn record of the session
	{
		printf -- '---\nspawn-id: %s\nsession-id: %s\n' "$1" "$1"
		[ -z "$2" ] || printf 'routine: %s\n' "$2"
		printf 'status: spawn-started\n---\n'
	} > "$rigW/.local/agents/spawned/rig/$1.spawn.md"
}
rigBind rig-plain-session ""
## One Wait, timeout 0, as a run of the session named; the rest are the sources and options.
rigWait(){ ## result name, session id, then the options of the wait
	local waitRc=0 waitName="$1" waitSession="$2"
	shift 2
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$waitSession" MDAT_SPAWN_SESSION_ID="$waitSession" MDAT_SPAWN_AGENT="$rigMember" MDAT_WAIT_REMIND=off \
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --wait-for-input "$rigMember" --wait-default --wait-session-id "$waitSession" --wait-timeout 0 "$@" ) > "$rigTmp/$waitName.out" 2> "$rigTmp/$waitName.err" < /dev/null 4> /dev/null || waitRc=$?
	printf '%s' "$waitRc" > "$rigTmp/$waitName.rc"
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line, or none
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}
rigSources(){ ## result name -- the `# sources:` line without the floor of the session (`replies:` and `chat:`)
	LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/$1.out" | head -1 | LC_ALL=C sed -e 's/replies:[^ ]* *//' -e 's/chat:[^ ]* *//' -e 's/ *$//'
}
rigArrivals(){ ## result name -- the sources that arrived, in order, space separated
	LC_ALL=C sed -n 's/^# arrived on: //p' "$rigTmp/$1.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigNeverRead(){ ## result name -- the WAIT-NEVER-READ line, or none
	local neverLine
	neverLine="$( LC_ALL=C sed -n 's/^WAIT-NEVER-READ: //p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${neverLine:-none}"
}

printf -- '---\ntype: note\nfrom: %s\n---\n\n# Note: scan last\n' "$rigMember" > "$rigD/inboxes/$rigMember/incoming/note-20261022T1800Z-scan-last.md"
echo "-- 1. a scan named first is read last --"
rigWait w1 rig-plain-session --wait-source scan:work-duty --wait-source "file:$rigQuiet"
rigAssert "the scan follows the file"                              "$( rigSources w1 )" "file:$rigQuiet scan:work-duty"
echo "-- 2. a scan is not begun once something has arrived --"
rigWait w2 rig-plain-session --wait-source scan:work-duty --wait-source "inbox:$rigMember" --wait-since-utime 1
rigAssert "the inbox arrival is returned, the scan is not"        "$( rigResult w2 ):$( rigArrivals w2 ):$( rigNeverRead w2 )" "RECEIVED:inbox:$rigMember:[scan:work-duty]"
echo "-- 3. control, nothing else arrived: the scan is read --"
rm -f "$rigD/inboxes/$rigMember/incoming/note-20261022T1800Z-scan-last.md"
rigWait w3 rig-plain-session --wait-source scan:work-duty --wait-source "inbox:$rigMember" --wait-since-utime 1
rigAssert "the scan arrives, nothing is named as never read"      "$( rigResult w3 ):$( rigArrivals w3 ):$( rigNeverRead w3 )" "RECEIVED:scan:work-duty:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SCAN LAST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SCAN_LAST: OK (%d assertions, offline)\n' "$rigPassCount"
