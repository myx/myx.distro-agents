#!/usr/bin/env bash
## Behavioural check on F5.3 of the refactorings epic, the write gate of the ONE validator
## (AgentsToolsDocValidateGate, sh-lib/team-data/AgentsTools.DocValidate.include) and the writers that enforce the
## contracts: the board primitive (--intern-op-board-upsert-move-edit) and the inbox primitive
## (--intern-op-member-inbox-upsert), the transcript appender, and every writer that files an audit item.
## Held:
##   1. a board create fills type, from, date, owner and document-contract, and the item meets its contract; the acting
##      member is the one named or the spawned session's own; a create with neither is refused, nothing written
##   2. an approval is refused without `blocks`, and made with it
##   3. the gate compares the item before and after: a fault the item already had is no fault of the write; a refusing
##      fault the write introduces refuses it, the item as it was; a reporting fault is said and the write goes on
##   4. the three behaviours of a validation failure are one: a refusal and a warning are said the same way, and the name
##      rule and the misfiled type are rules of the gate, not a second mechanism
##   5. the inbox: owner is the member whose inbox it is, document-contract is filled, from is required, an update that
##      drops the required keys is refused
##   6. the transcript appender opens a new transcript with document-contract and type, once
##   7. every writer of an audit item names its contract, and what it writes meets it (the output-style logs included)
##   8. the spawn proxy names the acting member of the dispatch it creates
## Red before F5.3: none of the above holds.
## Offline: rig files only; every call goes through one `env -i` whose child refuses to run outside this rig's tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocWriteGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The effective account of these rigs is the USER they give: a stand-in `id` first on PATH says it (none where USER is empty), as the person at the console is the effective account
## (AgentsToolsConsoleAccount, sh-lib/member/AgentsTools.CallerCheck.include).
mkdir -p "$rigTmp/idbin" && printf '#!/bin/sh\n[ "$*" = "-un" ] || exec /usr/bin/id "$@"\n[ -n "${USER:-}" ] || exit 1\necho "$USER"\n' > "$rigTmp/idbin/id" && chmod +x "$rigTmp/idbin/id"
rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/rig-other" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/board/pending" "$rigData/board/review" "$rigData/board/backlog" "$rigData/audit"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
rigField(){ ## file, field -- the value of one frontmatter field, bounded to the first --- block
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigFieldCount(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { n++ ; } END { print n + 0 ; }' "$1"
}
## One team op, guarded, against the rig's own stores; rc into <result>.rc. RIG_AGENT, when set, becomes MDAT_SPAWN_AGENT, RIG_USER USER.
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/idbin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} ${RIG_USER:+USER="$RIG_USER"} RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
## The validator on one file as its kind, the rows and the exit code: `<rc>:<number of rows>`.
rigMeets(){ ## kind, file
	local meetsRows meetsRc=0
	meetsRows="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/idbin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		bash "$rigFn" --intern-doc-validate "$1" "$2" 2> /dev/null )" || meetsRc=$?
	printf '%s:%s' "$meetsRc" "$( printf '%s' "$meetsRows" | LC_ALL=C grep -c . || : )"
}

echo "-- 1. a board create: the headers are filled, the item meets its contract --"
rigT1=task-20261001T1000Z-first.md
printf 'the work\n' | rigOp "$rigTmp/c1" --create-running rig-member "$rigT1" --upsert-from-stdin
rigAssert "created, rc 0" "$( cat "$rigTmp/c1.rc" ):$( [ -f "$rigData/board/running/$rigT1" ] && echo yes || echo no )" "0:yes"
rigAssert "type, from, owner are the item's type and the acting member, document-contract the contract of the type" \
	"$( rigField "$rigData/board/running/$rigT1" type ):$( rigField "$rigData/board/running/$rigT1" from ):$( rigField "$rigData/board/running/$rigT1" owner ):$( rigField "$rigData/board/running/$rigT1" document-contract )" "task:rig-member:rig-member:board-item.task"
rigAssert "the item meets its contract: exit 0, no row" "$( rigMeets board-item.task "$rigData/board/running/$rigT1" )" "0:0"
printf 'the work\n' | rigOp "$rigTmp/c2" --create-running rig-member task-20261001T1001Z-owned.md --upsert-from-stdin --header:upsert:owner:rig-other
rigAssert "an owner given is never overwritten" "$( rigField "$rigData/board/running/task-20261001T1001Z-owned.md" owner ):$( rigFieldCount "$rigData/board/running/task-20261001T1001Z-owned.md" owner )" "rig-other:1"
printf -- '---\n---\nwork\n' | RIG_AGENT=rig-other rigOp "$rigTmp/c3" --intern-op-board-upsert-move-edit pending task-20261001T1002Z-spawned.md --create --upsert-from-stdin --context rig
rigAssert "with no acting member named, the spawned session's own member is the acting one" "$( cat "$rigTmp/c3.rc" ):$( rigField "$rigData/board/pending/task-20261001T1002Z-spawned.md" from ):$( rigField "$rigData/board/pending/task-20261001T1002Z-spawned.md" owner )" "0:rig-other:rig-other"
printf -- '---\n---\nwork\n' | RIG_USER=rigacct rigOp "$rigTmp/c6" --intern-op-board-upsert-move-edit pending task-20261001T1006Z-console.md --create --upsert-from-stdin --context rig
rigAssert "a person at a console, no session spawned: the acting member is user-<account>, from the USER of the call" \
	"$( cat "$rigTmp/c6.rc" ):$( rigField "$rigData/board/pending/task-20261001T1006Z-console.md" from ):$( rigField "$rigData/board/pending/task-20261001T1006Z-console.md" owner ):$( rigMeets board-item.task "$rigData/board/pending/task-20261001T1006Z-console.md" )" "0:user-rigacct:user-rigacct:0:0"
printf -- '---\n---\nwork\n' | RIG_AGENT=rig-other RIG_USER=rigacct rigOp "$rigTmp/c7" --intern-op-board-upsert-move-edit pending task-20261001T1007Z-both.md --create --upsert-from-stdin --context rig
rigAssert "a spawned session's member comes before the account, and the member named before both" \
	"$( rigField "$rigData/board/pending/task-20261001T1007Z-both.md" owner ):$( printf -- '---\n---\nwork\n' | RIG_AGENT=rig-other RIG_USER=rigacct rigOp "$rigTmp/c8" --intern-op-board-upsert-move-edit pending task-20261001T1008Z-named.md --create --acting-member:rig-member --upsert-from-stdin --context rig ; rigField "$rigData/board/pending/task-20261001T1008Z-named.md" owner )" "rig-other:rig-member"
printf -- '---\n---\nwork\n' | rigOp "$rigTmp/c4" --intern-op-board-upsert-move-edit pending task-20261001T1003Z-nobody.md --create --upsert-from-stdin --context rig
rigAssert "with no one at all (no acting member, no spawned session, no USER), the create is refused and nothing is written, owner and from named" \
	"$( cat "$rigTmp/c4.rc" ):$( [ -f "$rigData/board/pending/task-20261001T1003Z-nobody.md" ] && echo written || echo absent ):$( rigHolds "$rigTmp/c4" 'the key owner is required and absent' ):$( rigHolds "$rigTmp/c4" 'the key from is required and absent' ):$( rigHolds "$rigTmp/c4" 'nothing was written' )" "1:absent:yes:yes:yes"
printf -- '---\n---\nwork\n' | rigOp "$rigTmp/c5" --intern-op-board-upsert-move-edit pending epic-20261001T1004Z-notatype.md --create --upsert-from-stdin --context rig
rigAssert "a name whose type has no contract is no concern of the gate: written, no contract named" "$( cat "$rigTmp/c5.rc" ):$( rigFieldCount "$rigData/board/pending/epic-20261001T1004Z-notatype.md" document-contract )" "0:0"

echo "-- 2. an approval needs blocks --"
printf 'gate\n' | rigOp "$rigTmp/a1" --create-running rig-member approval-20261001T1010Z-gate.md --upsert-from-stdin
rigAssert "an approval without blocks is refused, nothing written, the key named" "$( cat "$rigTmp/a1.rc" ):$( [ -f "$rigData/board/running/approval-20261001T1010Z-gate.md" ] && echo written || echo absent ):$( rigHolds "$rigTmp/a1" 'the key blocks is required and absent' )" "1:absent:yes"
printf 'gate\n' | rigOp "$rigTmp/a2" --create-running rig-member approval-20261001T1011Z-gate.md --upsert-from-stdin --header:upsert:blocks:"${rigT1%.md}"
rigAssert "with blocks it is made, and meets the contract of an approval" "$( cat "$rigTmp/a2.rc" ):$( rigField "$rigData/board/running/approval-20261001T1011Z-gate.md" document-contract ):$( rigMeets board-item.approval "$rigData/board/running/approval-20261001T1011Z-gate.md" )" "0:board-item.approval:0:0"

echo "-- 3. before and after: only what the write introduces --"
rigS=task-20261001T1020Z-stored.md
printf -- '---\ntype: task\nfrom: rig-member\ndate: 2026-07-01\nstatus: open\n---\n# Task: a stored task\n' > "$rigData/board/running/$rigS"
rigBase="$( rigMeets board-item.task "$rigData/board/running/$rigS" )"
rigAssert "control: the stored item has faults of its own (no owner, no document-contract, a date with no time)" "$rigBase" "1:3"
rigOp "$rigTmp/e1" --intern-op-board-upsert-move-edit running "$rigS" --from-state:running --header:upsert:status:blocked
rigAssert "an edit that introduces nothing is written whatever the item already lacks" "$( cat "$rigTmp/e1.rc" ):$( rigField "$rigData/board/running/$rigS" status ):$( rigHolds "$rigTmp/e1" 'board-upsert-move-edit: ⛔ ERROR' )" "0:blocked:no"
rigAssert "the item still lacks what it lacked: a change fills nothing" "$( rigFieldCount "$rigData/board/running/$rigS" document-contract )" "0"
rigOp "$rigTmp/e2" --intern-op-board-upsert-move-edit running "$rigS" --from-state:running --header:upsert:date:2026-07-02
rigAssert "a bad value changed for another bad value is the fault it was: written" "$( cat "$rigTmp/e2.rc" ):$( rigField "$rigData/board/running/$rigS" date )" "0:2026-07-02"
rigOp "$rigTmp/e3" --intern-op-board-upsert-move-edit review "$rigS" --from-state:running
rigAssert "a move with no new fault goes" "$( cat "$rigTmp/e3.rc" ):$( [ -f "$rigData/board/review/$rigS" ] && echo moved )" "0:moved"
rigOp "$rigTmp/e4" --intern-op-board-upsert-move-edit review "$rigS" --from-state:review --header:upsert:archive:yes
rigAssert "a refusing fault the write introduces refuses it: ERROR, the item as it was" "$( cat "$rigTmp/e4.rc" ):$( rigField "$rigData/board/review/$rigS" archive | LC_ALL=C wc -c | LC_ALL=C tr -d ' ' ):$( rigHolds "$rigTmp/e4" 'board-upsert-move-edit: ⛔ ERROR: ' ):$( rigHolds "$rigTmp/e4" 'the key archive is not the word true: yes' )" "1:0:yes:yes"
rigOp "$rigTmp/e5" --intern-op-board-upsert-move-edit review "$rigS" --from-state:review --header:upsert:own-note:looked
rigAssert "a reporting fault is said as a WARNING and the write goes on" "$( cat "$rigTmp/e5.rc" ):$( rigField "$rigData/board/review/$rigS" own-note ):$( rigHolds "$rigTmp/e5" 'board-upsert-move-edit: ⚠️ WARNING: ' ):$( rigHolds "$rigTmp/e5" 'the key own-note is not named by the contract' )" "0:looked:yes:yes"
rigOp "$rigTmp/e6" --intern-op-board-upsert-move-edit review "$rigS" --from-state:review --header:upsert:own-note:looked
rigAssert "the fault it already has is not said again" "$( cat "$rigTmp/e6.rc" ):$( rigHolds "$rigTmp/e6" 'WARNING' )" "0:no"
rigOp "$rigTmp/e7" --intern-op-board-upsert-move-edit review "$rigS" --from-state:review --header:upsert:owner:rig-member --header:upsert:document-contract:board-item.task --header:upsert:date:"2026-07-01 10:00 +0000"
rigAssert "an edit that fixes the faults is written" "$( cat "$rigTmp/e7.rc" ):$( rigMeets board-item.task "$rigData/board/review/$rigS" )" "0:0:1"
rigOp "$rigTmp/e8" --intern-op-board-upsert-move-edit review "$rigS" --from-state:review --header:remove:owner
rigAssert "an edit that takes a required key out of a sound item is refused, the item as it was" "$( cat "$rigTmp/e8.rc" ):$( rigField "$rigData/board/review/$rigS" owner ):$( rigHolds "$rigTmp/e8" 'the key owner is required and absent' )" "1:rig-member:yes"
printf -- '---\ntype: task\nfrom: rig-member\ndate: 2026-07-01\nstatus: open\n---\n# Task: a stored task\n' > "$rigData/board/running/task-20261001T1021Z-moved.md"
printf -- '---\nstatus: open\ntype: task\nfrom: rig-member\ndate: 2026-07-01\n---\n# Task: a retitled stored task\n\nA new paragraph above nothing.\n' | rigOp "$rigTmp/e9" --intern-op-board-upsert-move-edit running task-20261001T1021Z-moved.md --from-state:running --upsert-from-stdin
rigAssert "lines that moved are no new fault: a rewrite that keeps the item's faults where they stand, in other lines, is written" "$( cat "$rigTmp/e9.rc" ):$( rigHolds "$rigData/board/running/task-20261001T1021Z-moved.md" 'A new paragraph' )" "0:yes"

echo "-- 4. one behaviour for a failure: refused or said, in one form --"
printf -- '---\n---\nlegacy\n' | rigOp "$rigTmp/u1" --intern-op-board-upsert-move-edit pending task-2026-09-29-legacy.md --create --acting-member:rig-member --upsert-from-stdin --context rig
rigAssert "the naming Rule is a rule of the gate: a WARNING line of the same form, the item created" \
	"$( cat "$rigTmp/u1.rc" ):$( rigHolds "$rigTmp/u1" 'board-upsert-move-edit: ⚠️ WARNING: --create: task-2026-09-29-legacy.md does not follow the naming Rule' ):$( [ -f "$rigData/board/pending/task-2026-09-29-legacy.md" ] && echo created )" "0:yes:created"
printf 'misfiled\n' | RIG_AGENT=rig-member rigOp "$rigTmp/u2" --upsert-inbox-note rig-member warning-20261001T1030Z-misfiled.md
rigAssert "a type in the wrong store is a rule of the gate: a WARNING line of the same form, the item written" \
	"$( cat "$rigTmp/u2.rc" ):$( rigHolds "$rigTmp/u2" 'member-inbox-upsert: ⚠️ WARNING: new item: warning-20261001T1030Z-misfiled.md is not an inbox type' )" "0:yes"
rigAssert "there is no second mechanism: the naming check function is gone, and the two primitives ask the one gate" \
	"$( LC_ALL=C grep -r -l 'AgentsToolsItemNameShapeCheck' "$rigPackage/sh-lib" "$rigPackage/sh-scripts" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'AgentsToolsDocValidateGate ' "$rigPackage/sh-lib/board/AgentsTools.InternOpBoardUpsertMoveEdit.include" ):$( LC_ALL=C grep -c 'AgentsToolsDocValidateGate ' "$rigPackage/sh-lib/inbox/AgentsTools.InternOpMemberInboxUpsert.include" )" "0:2:2"

echo "-- 5. the inbox --"
printf 'a note\n' | RIG_AGENT=rig-member rigOp "$rigTmp/i1" --upsert-inbox-note rig-member note-20261001T1040Z-own.md
rigI1="$rigData/inboxes/rig-member/incoming/note-20261001T1040Z-own.md"
rigAssert "a note: document-contract, owner the inbox's member, from the writer; it meets its contract" \
	"$( cat "$rigTmp/i1.rc" ):$( rigField "$rigI1" document-contract ):$( rigField "$rigI1" owner ):$( rigField "$rigI1" from ):$( rigMeets inbox-item.note "$rigI1" )" "0:inbox-item.note:rig-member:rig-member:0:0"
printf 'Please look.\n' | RIG_AGENT=rig-other rigOp "$rigTmp/i2" --upsert-inbox-inquiry rig-member inquiry-20261001T1041Z-ask.md
rigI2="$rigData/inboxes/rig-member/incoming/inquiry-20261001T1041Z-ask.md"
rigAssert "an inquiry to another member's inbox: the owner is the member whose inbox holds it, from the one asking" "$( cat "$rigTmp/i2.rc" ):$( rigField "$rigI2" owner ):$( rigField "$rigI2" from ):$( rigField "$rigI2" document-contract )" "0:rig-member:rig-other:inbox-item.inquiry"
printf 'a person wrote this\n' | RIG_USER=rigacct rigOp "$rigTmp/i5" --upsert-inbox-note rig-member note-20261001T1043Z-console.md
rigAssert "a person at a console, no session spawned: the writer is user-<account>, and the note meets its contract" \
	"$( cat "$rigTmp/i5.rc" ):$( rigField "$rigData/inboxes/rig-member/incoming/note-20261001T1043Z-console.md" from ):$( rigField "$rigData/inboxes/rig-member/incoming/note-20261001T1043Z-console.md" owner ):$( rigMeets inbox-item.note "$rigData/inboxes/rig-member/incoming/note-20261001T1043Z-console.md" )" "0:user-rigacct:rig-member:0:0"
printf 'a member wrote this\n' | RIG_AGENT=rig-member RIG_USER=rigacct rigOp "$rigTmp/i6" --upsert-inbox-note rig-member note-20261001T1044Z-both.md
printf 'a named member wrote this\n' | RIG_AGENT=rig-member RIG_USER=rigacct rigOp "$rigTmp/i7" --upsert-inbox-note rig-member note-20261001T1045Z-named.md --from-member magic-coordinator
rigAssert "the spawned session's member comes before the account, and --from-member before both" \
	"$( rigField "$rigData/inboxes/rig-member/incoming/note-20261001T1044Z-both.md" from ):$( rigField "$rigData/inboxes/rig-member/incoming/note-20261001T1045Z-named.md" from )" "rig-member:magic-coordinator"
printf 'no one wrote this\n' | rigOp "$rigTmp/i3" --upsert-inbox-note rig-member note-20261001T1042Z-nobody.md
rigAssert "with no one at all (no writer named, no spawned session, no USER), the create is refused (from is required), nothing written" "$( cat "$rigTmp/i3.rc" ):$( [ -f "$rigData/inboxes/rig-member/incoming/note-20261001T1042Z-nobody.md" ] && echo written || echo absent ):$( rigHolds "$rigTmp/i3" 'the key from is required and absent' )" "1:absent:yes"
printf -- '---\ntype: note\n---\ndropped\n' | RIG_AGENT=rig-member rigOp "$rigTmp/i4" --upsert-inbox-note rig-member note-20261001T1040Z-own.md
rigAssert "an update that drops the item's required keys is refused, the item as it was" "$( cat "$rigTmp/i4.rc" ):$( rigHolds "$rigI1" 'a note' ):$( rigHolds "$rigTmp/i4" 'nothing was written' )" "1:yes:yes"

echo "-- 6. the transcript appender --"
RIG_AGENT=rig-member rigOp "$rigTmp/t1" --append-transcript rig-member --speaker rig-member --timestamp 2026-10-01T10:00:00Z --message "first" --transcript-name transcript-20261001T1050Z-rig.md --create
rigT="$rigData/audit/2026-10/transcript-20261001T1050Z-rig.md"
rigAssert "a new transcript opens with its contract and type" "$( cat "$rigTmp/t1.rc" ):$( rigField "$rigT" document-contract ):$( rigField "$rigT" type ):$( LC_ALL=C sed -n 1p "$rigT" )" "0:audit-item.transcript:transcript:---"
RIG_AGENT=rig-member rigOp "$rigTmp/t2" --append-transcript rig-member --speaker rig-member --timestamp 2026-10-01T10:01:00Z --message "second" --transcript-name transcript-20261001T1050Z-rig.md
rigAssert "a later entry adds no frontmatter, and the transcript meets its contract" "$( cat "$rigTmp/t2.rc" ):$( LC_ALL=C grep -c '^document-contract: ' "$rigT" ):$( rigHolds "$rigT" 'first' ):$( rigHolds "$rigT" 'second' ):$( rigMeets audit-item.transcript "$rigT" )" "0:1:yes:yes:0:0"

echo "-- 7. every writer of an audit item names its contract, and what it writes meets it --"
rigArtFile="$rigData/audit/artifact-20261001T1060Z-rig.md"
( export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" ; artCmd=rig artRecord="$rigArtFile" artNumber=D-1 artCode=D artTitle=Rig artMember=rig-member artSession=rig-session artFullTitle="D-1 Rig" artKind=D
	eval "$( LC_ALL=C sed -n '/^AgentsToolsArtifactRecordWrite(){/,/^}/p' "$rigPackage/sh-lib/common/AgentsTools.InternArtifact.include" )"
	AgentsToolsArtifactRecordWrite published https://rig.example/doc ) > /dev/null 2>&1
rigAssert "the artifact record: its contract named, and it meets it" "$( rigField "$rigArtFile" document-contract ):$( rigMeets audit-item.artifact "$rigArtFile" )" "audit-item.artifact:0:0"
rigSnapOut="$rigTmp/snap.out"
( export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=rig RIG_SNAP="$rigSnapOut"
	AgentsToolsAtlassianJiraIssueRead(){ printf 'the issue as read\n' ; }
	AgentsToolsItemUpsert(){ ## member, --from-audit, name, --from-file, file, ...
		cp -- "$5" "$RIG_SNAP" ; printf '%s' "$3" > "$RIG_SNAP.name"
	}
	eval "$( LC_ALL=C sed -n '/^AgentsToolsClientCommsSnapshotBeforeWrite(){/,/^}/p' "$rigPackage/sh-lib/client/AgentsTools.ClientComms.include" )"
	AgentsToolsClientCommsSnapshotBeforeWrite rig-member jira-issue-transition jira issue ABC-1 AgentsToolsAtlassianJiraIssueRead ABC-1 ) > /dev/null 2>&1
rigSnapFile="$rigTmp/$( cat "$rigSnapOut.name" 2> /dev/null )"
cp -- "$rigSnapOut" "$rigSnapFile" 2> /dev/null
rigAssert "the snapshot: its contract named, and it meets it (its file name carries what it says)" "$( rigField "$rigSnapFile" document-contract ):$( rigMeets audit-item.snapshot "$rigSnapFile" )" "audit-item.snapshot:0:0"

rigStyleLog(){ ## declaration|refusal -- the file the output-style writer made
	( export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=rig ; . "$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.OutputStyle.include"
		case "$1" in
			declaration) printf 'A declared text.\n' | AgentsToolsOutputStyleRefusal rig-member report rig-destination "" none ;;
			refusal) printf 'One clause; another clause.\n' | AgentsToolsOutputStyleRefusal rig-member "" rig-destination "" semicolon ;;
		esac ) > /dev/null 2>&1
	ls "$rigData"/audit/"$1"-*-output-style.md 2> /dev/null | LC_ALL=C head -1
}
rigDeclLog="$( rigStyleLog declaration )"
rigAssert "the output-style declaration log: its contract named, and it meets it" "$( rigField "$rigDeclLog" document-contract ):$( rigMeets audit-item.declaration "$rigDeclLog" )" "audit-item.declaration:0:0"
rigRefLog="$( rigStyleLog refusal )"
rigAssert "the output-style refusal log: its contract named, and it meets it" "$( rigField "$rigRefLog" document-contract ):$( rigMeets audit-item.refusal "$rigRefLog" )" "audit-item.refusal:0:0"

echo "-- 8. the dispatch the spawn proxy creates names its acting member --"
rigAssert "the create of the dispatch item carries --acting-member:<the caller>" "$( LC_ALL=C grep -c -e '--acting-member:"$callerName"' "$rigPackage/sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DOC WRITE GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_WRITE_GATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
