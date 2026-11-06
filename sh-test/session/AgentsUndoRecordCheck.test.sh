#!/usr/bin/env bash
## Behavioural check on the undo protocol's beats (S13.19 stages 2 to 4): `--undo-record` keeps
## the inverse of one act, writes the hold and posts the prompt of the act to the human-owner,
## `--undo-plan` is the dry run and refuses an operand that moved, `--undo-run` takes the steps
## once and resumes after a stop, `--undo-purge` closes the record, and `--undo-rework` keeps his
## words and the hold. Run and purge carry HIS answer alone, so a member's own word is refused,
## and so is a rework with no words. The three hold readers ask the marker what it names, and a
## marker naming no open record keeps the material and says which record it wanted.
## Offline: a Slack-shaped fake curl is first on PATH, and no tree but this check's own rig.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigSimLib="$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigSweepLib="$rigSimLib"
rigCurl="$rigPackage/sh-test/check-fixtures/change-approval.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigSweepLib" ] || rigRefuse "the sandbox include is missing from the package: $rigSweepLib"
[ -f "$rigCurl" ] || rigRefuse "the fake curl fixture is missing: $rigCurl"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsUndoRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home"
cp "$rigCurl" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
for rigReal in date uuidgen awk sed grep cmp mkdir mktemp rm wc cut tr sort cat cp mv od dirname basename hostname ; do
	[ ! -x "/usr/bin/$rigReal" ] || ln -sf "/usr/bin/$rigReal" "$rigTmp/bin/$rigReal" 2> /dev/null || :
	[ ! -x "/bin/$rigReal" ] || ln -sf "/bin/$rigReal" "$rigTmp/bin/$rigReal" 2> /dev/null || :
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
AgentsToolsUndoFieldRig(){ ## record id, key
	LC_ALL=C awk -v key="$2" '$0 == "---" { exit } index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; exit }' \
		"$rigWs/.local/agents/sessions/rigrun/undo/$1/record" 2> /dev/null
}

## A fresh rig: a workspace, its data root, and one sandbox of this rig's own, which is the
## acting run's sandbox -- the folder the record's hold is written in.
rigNew(){ ## name
	rigWs="$rigTmp/$1/ws" ; rigD="$rigTmp/$1/data" ; rigSp="$rigWs/.local/agents/spawned" ; rigRun="$rigSp/rigrun" ; rigDir="$rigTmp/$1"
	mkdir -p "$rigDir" ; : > "$rigDir/curl.log"
	mkdir -p "$rigD/inboxes/magic-coordinator/incoming" "$rigD/board/processed" "$rigWs/.local/agents/members/magic-coordinator" "$rigWs/.local/temp" "$rigRun/input" "$rigRun/output"
	mkdir -p "$rigWs/.local/agents/members/rig-member" "$rigWs/.local/agents/members/human-owner" "$rigWs/.local/.agents"
	printf '# human-owner\n' > "$rigWs/.local/agents/members/human-owner/SKILL.md"
	printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf -- '---\nname: rig-member\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/rig-member/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/rig-member/rig-member.basic.md"
	printf '# magic-coordinator\n' > "$rigWs/.local/agents/members/magic-coordinator/SKILL.md"
	printf 'rig\n' > "$rigRun/input/brief.md"
	printf -- '---\nsession-id: rigrun\nspawn-id: rigrun\nhost: %s\nstatus: spawn-succeeded\n---\n' "$rigHost" > "$rigRun/rigrun.spawn.md"
	touch -t 202001010000 "$rigRun/rigrun.spawn.md"
}
rigToolCall(){ ## arguments... -- the tool against this rig, rc in rigRc
	( cd "$rigWs" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" \
		MDAT_DATA_ROOT="$rigD" MDAT_SPAWN_SANDBOX_ROOT="$rigRun" MDAT_SPAWN_SESSION_ID=rigrun MDAT_SPAWN_AGENT=rig-member \
		bash "$rigTool" "$@" ) > "$rigTmp/call.out" 2>&1
	rigRc=$?
}
rigSweep(){ ## result file -- the sweep against this rig, as a rig
	env -i MDAT_WORKSPACE_MODE=team-rig PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_LIB="$rigSweepLib" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			MDSC_CMD=rig ; . "$RIG_LIB" ; AgentsToolsSpawnSandboxSweep rig-sweep
		' > "$1" 2>&1
}
rigPurge(){ ## result file, rc in rigRc
	mkdir -p "$rigWs/.local/.cleanup" && printf 'junk\n' > "$rigWs/.local/.cleanup/junk.txt"
	( cd "$rigWs" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" \
		bash "$rigTool" --owner-cleanup-purge ) > "$1" 2>&1
	rigRc=$?
}
## HIS ANSWER, written where the tool reads it: the record's own ask, closed with the verdict
## the human-owner gave, in the one store both the live and the closed records are found in.
rigAnswer(){ ## record id, verdict (accept|reject|rework), his words (may be empty), answered by (default: his account)
	local answerAsk="rigask-$1" answerRecord="$rigWs/.local/agents/sessions/rigrun/undo/$1/record" answerBy="${4:-URIGOWNER}"
	mkdir -p "$rigWs/.local/agents/pending"
	printf -- '---\nstatus: reply-received\nowner: rig-member\nkind: undo\nverdict: %s%s\nanswered-by: %s\n---\n\n# Question asked\n\nthe prompt\n' \
		"$2" "${3:+ -- $3}" "$answerBy" > "$rigWs/.local/agents/pending/$answerAsk.md"
	LC_ALL=C awk -v line="ask: $answerAsk" 'BEGIN { done = 0 } index( $0, "ask: " ) == 1 { if ( ! done ) { print line ; done = 1 } ; next } { print } END { if ( ! done ) print line }' \
		"$answerRecord" > "$answerRecord.new" && mv -f "$answerRecord.new" "$answerRecord"
}
rigRecord(){ ## the file as it stood, the file as the act left it, the live file -- record id in rigId
	printf '%s\n' "$1" > "$rigTmp/base.txt"
	printf '%s\n' "$2" > "$rigTmp/result.txt"
	printf '%s\n' "$2" > "$rigRun/output/live.txt"
	rigToolCall --undo-record file-write "$rigRun/output/live.txt" --base "$rigTmp/base.txt" --result "$rigTmp/result.txt" --session-id rigrun
	rigId="$( LC_ALL=C awk '/^RECORDED /{ print $2 ; exit }' "$rigTmp/call.out" )" || rigId=""
}

echo "-- 1. a record, and the hold it writes --"
rigNew record
rigRecord one two
rigAssert "a file act is recorded, and its state is open" \
	"$( LC_ALL=C awk '/^RECORDED /{ print ( $3 == "open" ? "open" : $3 ) ; exit }' "$rigTmp/call.out" )" "open"
rigAssert "the hold in the acting run's sandbox names that record" \
	"$( LC_ALL=C grep -c "^rigrun/$rigId\$" "$rigRun/undo.hold" 2>/dev/null || : )" 1
rigAssert "the record keeps the base the inverse puts back" \
	"$( [ -f "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/base" ] && cat "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/base" || printf 'absent' )" "one"

echo "-- 2. a kind outside the closed list --"
rigToolCall --undo-record not-a-kind anything --session-id rigrun
rigAssert "a kind that is no inverse is refused, and the kinds are named" \
	"$( LC_ALL=C grep -c 'is no inverse of this lane' "$rigTmp/call.out" ):$( LC_ALL=C grep -c 'file-write' "$rigTmp/call.out" )" "1:1"
rigAssert "and nothing is recorded" "$rigRc" 1

echo "-- 3. a kind the tree cannot run is recorded refused, and holds nothing --"
rigNew refuse
rigToolCall --undo-record item-trash dispatch-rig.md --session-id rigrun
rigAssert "the record says refused, and says why" \
	"$( LC_ALL=C awk '/^RECORDED /{ print $3 ; exit }' "$rigTmp/call.out" ):$( LC_ALL=C grep -c 'refused:' "$rigTmp/call.out" )" "refused:1"
rigAssert "a refused record writes no hold" "$( [ -f "$rigRun/undo.hold" ] && printf held || printf none )" "none"

echo "-- 4. the dry run --"
rigNew plan
rigRecord one two
rigToolCall --undo-plan "$rigId" --session-id rigrun
rigAssert "an unchanged file is ready, and its step is named" \
	"$( LC_ALL=C grep -c '^ready ' "$rigTmp/call.out" ):$( LC_ALL=C grep -c 'step AgentsUniversalHarness --intern-tool' "$rigTmp/call.out" )" "1:1"
printf 'three\n' > "$rigRun/output/live.txt"
rigToolCall --undo-plan "$rigId" --session-id rigrun
rigAssert "a file that moved is not ready, and the reason names it" \
	"$( LC_ALL=C grep -c '^not ready: the file has changed since the act' "$rigTmp/call.out" )" 1

echo "-- 5. the run --"
printf 'two\n' > "$rigRun/output/live.txt"
rigToolCall --undo-run "$rigId" --session-id rigrun
rigAssert "a run nobody answered is refused, and the file stays as the act left it" \
	"$rigRc:$( LC_ALL=C grep -c 'has no answer yet' "$rigTmp/call.out" ):$( cat "$rigRun/output/live.txt" )" "1:1:two"
printf 'two\n' > "$rigRun/output/live.txt"
rigAnswer "$rigId" reject
rigToolCall --undo-run "$rigId" --session-id rigrun
rigAssert "the base is put back" "$( cat "$rigRun/output/live.txt" )" "one"
rigAssert "the record closes as done, and the hold it made is released" \
	"$( LC_ALL=C awk '$0 == "---" { exit } index( $0, "state: " ) == 1 { print substr( $0, 8 ) ; exit }' "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/record" ):$( [ -f "$rigRun/undo.hold" ] && printf held || printf released )" "done:released"
rigToolCall --undo-run "$rigId" --session-id rigrun
rigAssert "a second run takes no step twice" \
	"$( LC_ALL=C grep -c '^made' "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/steps" ):$( LC_ALL=C grep -c 'nothing to do' "$rigTmp/call.out" )" "1:1"

echo "-- 6. the purge --"
rigNew purge
rigRecord one two
rigToolCall --undo-purge "$rigId" --session-id rigrun
rigAssert "a purge with no answer is refused, and the record and its hold stand" \
	"$rigRc:$( LC_ALL=C awk '$0 == "---" { exit } index( $0, "state: " ) == 1 { print substr( $0, 8 ) ; exit }' "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/record" ):$( [ -f "$rigRun/undo.hold" ] && printf held || printf released )" "1:open:held"
rigAnswer "$rigId" accept "" rig-member
rigToolCall --undo-purge "$rigId" --session-id rigrun
rigAssert "an answer that is not his is refused, and nothing is released" \
	"$rigRc:$( LC_ALL=C grep -c 'only the answer of the human-owner' "$rigTmp/call.out" )" "1:1"
rigAnswer "$rigId" reject
rigToolCall --undo-purge "$rigId" --session-id rigrun
rigAssert "his reject does not carry a purge" "$rigRc" 1
rigAnswer "$rigId" accept
rigToolCall --undo-purge "$rigId" --session-id rigrun
rigAssert "an accept closes the record, and the hold it made is released" \
	"$( LC_ALL=C awk '$0 == "---" { exit } index( $0, "state: " ) == 1 { print substr( $0, 8 ) ; exit }' "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/record" ):$( [ -f "$rigRun/undo.hold" ] && printf held || printf released )" "accepted:released"

echo "-- 7. the rework --"
rigNew rework
rigRecord one two
rigAnswer "$rigId" rework "" 
rigToolCall --undo-rework "$rigId" --session-id rigrun
rigAssert "a rework with no words is no verdict, and nothing moves" \
	"$rigRc:$( LC_ALL=C awk '$0 == "---" { exit } index( $0, "state: " ) == 1 { print substr( $0, 8 ) ; exit }' "$rigWs/.local/agents/sessions/rigrun/undo/$rigId/record" )" "1:open"
rigAnswer "$rigId" rework "do it as a copy first, and tell me"
rigToolCall --undo-rework "$rigId" --session-id rigrun
rigAssert "his words are kept as he wrote them, and the record moves to rework-asked" \
	"$( AgentsToolsUndoFieldRig "$rigId" state ):$( AgentsToolsUndoFieldRig "$rigId" rework-text )" "rework-asked:do it as a copy first, and tell me"
rigAssert "and the hold stands, because the promise does" \
	"$( [ -f "$rigRun/undo.hold" ] && printf held || printf released )" "held"

echo "-- 8. the readers ask what the marker names --"
rigNew readers
printf 'rigrun/undo-record-that-is-not-there\n' > "$rigRun/undo.hold"
rigSweep "$rigTmp/sweep.out"
rigAssert "a hold naming no open record keeps the sandbox, and says which record it wanted" \
	"$( [ -f "$rigRun/input/brief.md" ] && printf kept || printf gone ):$( LC_ALL=C grep -c 'undo-record-that-is-not-there' "$rigTmp/sweep.out" )" "kept:1"
rigPurge "$rigTmp/purge.out"
rigAssert "the purge refuses, and names the record it cannot find" \
	"$rigRc:$( LC_ALL=C grep -c 'undo-record-that-is-not-there' "$rigTmp/purge.out" )" "1:1"
rm -f "$rigRun/undo.hold"
rigSweep "$rigTmp/sweep2.out"
rigAssert "a sandbox with no marker is still emptied" \
	"$( [ -f "$rigRun/input/brief.md" ] && printf present || printf gone )" "gone"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ UNDO RECORD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'UNDO_RECORD: OK (%d assertions, offline)\n' "$rigPassCount"
