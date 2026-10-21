#!/usr/bin/env bash
## Behavioural check on a scan as a Wait source (F3.3 of the refactorings epic, open-names 1 to 4): a scan's report is
## a source of Wait, beside `slack:`, `file:`, `inbox:`, `board:` and `ask:`, spelt `scan:<scan>`, a scan of AgentsToolsInputScanNames. It wakes when the report differs from its stored baseline, as every source does. Inside the F3.2 cache
## age the cached report is read; past it the scan runs again, so the source's TTL is the cache age, five minutes. `timeout: 0` reads every source once and returns.
## Run through Wait's shell operation, --member-wait-for-input, as a run of a team session.
## Held, for the member-work-session scan (the advance scan this was first held for is retired, F7.12), a scan of the tooling that no member calls (F6.4: the
## spawner runs it from a routine's `input-scan-def:`), and so a source for the tooling's own use, never in the default set:
##   1. `scan:member-work-session` is a source this build waits on, not refused
##   2. with timeout 0 the call reads once and returns at once, with a WAIT-RESULT line
##   3. the `# sources:` line names the source
##   4. read again with nothing changed: TIMEOUT
##   5. an inbox note added: the report differs, the Wait wakes, RECEIVED, with the new note (the cache of a scan's report is AgentsInputScanCacheCheck's)
## Red before F3.3: no scan source (every case fails).
## Offline: a ps first on PATH lists the rig's own runs only (none); a Slack-shaped fake curl logs any call; every tree is
## this rig's own.
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
rigTmp="$( rigTempDir AgentsInputScanWaitSourceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*)\n\t\tcase "$*" in\n\t\t\t*pid=*) cat "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\t\t*) sed '"'"'s/^[^ ]* //'"'"' "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\tesac\n\t\texit 0\n\t;;\nesac\nexec "${0%%/*}/ps.real" "$@"\n' > "$rigTmp/bin/ps"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
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
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator/incoming" "$rigH"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item in %s\n' "$rigState" > "$rigD/board/$rigState/task-rig-$rigState.md"
done
rigSession="rig-scan-wait-session" rigRun="rig-scan-wait-run"
rigSource="scan:member-work-session"
## One Wait on the scan source, timeout 0, as a run of the team session; out, err, rc and how long it took.
rigWait(){ ## result name
	local waitStart waitRc=0
	waitStart="$( date +%s )"
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator \
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigTool" --member-wait-for-input magic-coordinator --wait-source "$rigSource" --wait-timeout 0 ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null 4> /dev/null || waitRc=$?
	printf '%s' "$waitRc" > "$rigTmp/$1.rc"
	printf '%s' "$(( $( date +%s ) - waitStart ))" > "$rigTmp/$1.took"
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line, or none
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}
rigAnswered(){ ## result name -- `result` where its outcome is RECEIVED or TIMEOUT, else the outcome
	case "$( rigResult "$1" )" in
		RECEIVED|TIMEOUT) printf result ;;
		*) rigResult "$1" ;;
	esac
}
rigStamp(){ ## minutes ago -- a touch -t stamp, BSD or GNU date
	local stampEpoch=$(( $( date +%s ) - $1 * 60 ))
	date -r "$stampEpoch" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M.%S
}

echo "-- 1. the scan is a source this build waits on --"
rigWait w1
rigAssert "not refused as a source, and the call ends 0"         "$( LC_ALL=C grep -c -F 'names nothing this build can wait on' "$rigTmp/w1.err" ):$( cat "$rigTmp/w1.rc" )" "0:0"
echo "-- 2. timeout 0: read once, back at once --"
rigAssert "a RECEIVED or TIMEOUT line, within thirty seconds"   "$( rigAnswered w1 ):$( [ "$( cat "$rigTmp/w1.took" )" -le 30 ] && echo quick || echo slow )" "result:quick"
echo "-- 3. the # sources: line names the source --"
rigAssert "the sources line holds the source"                    "$( LC_ALL=C grep -m 1 '^# sources: ' "$rigTmp/w1.out" | LC_ALL=C grep -c -F -- "$rigSource" )" "1"
echo "-- 4. nothing changed: TIMEOUT --"
rigWait w2
rigAssert "the second read finds the report as it was"           "$( rigResult w2 )" "TIMEOUT"
echo "-- 5. a note added to the inbox: the report differs, and the Wait wakes --"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\n# Note: scan wait added\n' > "$rigD/inboxes/magic-coordinator/incoming/note-20261021T0900Z-scan-wait-added.md"
rigWait w3
rigAssert "RECEIVED, with the note added" "$( rigResult w3 ):$( LC_ALL=C grep -c -F 'note-20261021T0900Z-scan-wait-added' "$rigTmp/w3.out" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/shown/' )" "RECEIVED:shown"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN WAIT SOURCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_WAIT_SOURCE: OK (%d assertions, offline)\n' "$rigPassCount"
