#!/usr/bin/env bash
## Behavioural check on one frontmatter headers program and one board state list (task-20261115T1024Z):
##   1. the program stands once, in sh-lib/core/AgentsFrontmatterHeaderValues.awk, and both owners name it there
##   2. both readers answer the same values for the same keys: the first frontmatter block only, the first line of
##      its key, an empty answer for a key the block lacks, and a body line that only looks like a header
##   3. the board item lookup is derived from the one list of the states: every state of the list is reached, a state
##      appended to the list is reached with no further code, and a name two states hold answers the list's first
##   4. one awk a call in each reader, the shared program, and no program text left in either include
## Red before the fix: the program stands twice, and the lookup carries a literal list of its own, so an appended
## state is never found. Offline: a temp workspace and data root under the rig's own folder, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigShared="$rigLib/core/AgentsFrontmatterHeaderValues.awk"
rigSession="$rigLib/session/AgentsTools.SessionStore.include"
rigItem="$rigLib/board/AgentsTools.ItemDecisions.include"
rigStatesFile="$rigLib/board/AgentsTools.BoardStates.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigOne in "$rigSession" "$rigItem" "$rigStatesFile" ; do
	[ -f "$rigOne" ] || rigRefuse "not in this package: $rigOne"
done
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsFrontmatterHeadersCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigData" "$rigTmp/home"

## The readers run in their own environment, as every store write of this rig does: the rig's workspace and store, and
## nothing of this check's own.
rigRead(){ ## shell text -- what it printed
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash -c "$1"
}

echo "-- 1. the headers program stands once, and both owners name it there --"
rigAssert "the one program is in the package's core, where both owners may read it" \
	"$( [ -f "$rigShared" ] && printf there || printf absent )" there
rigAssert "the run-record reader names it, in one call" \
	"$( LC_ALL=C grep -c 'awk -v keys="\$headKeys" -f "\$MDLT_ORIGIN/myx/myx\.distro-agents/sh-lib/core/AgentsFrontmatterHeaderValues\.awk"' "$rigSession" || : )" 1
rigAssert "the board item reader names it, in one call" \
	"$( LC_ALL=C grep -c 'awk -v keys="\$headKeys" -f "\$MDLT_ORIGIN/myx/myx\.distro-agents/sh-lib/core/AgentsFrontmatterHeaderValues\.awk"' "$rigItem" || : )" 1
rigAssert "the run-record reader carries no copy of the program" \
	"$( LC_ALL=C grep -c 'index( \$0, k\[i\]' "$rigSession" || : )" 0
rigAssert "the board item reader carries no copy either" \
	"$( LC_ALL=C grep -c 'index( \$0, k\[i\]' "$rigItem" || : )" 0
rigAssert "the one program's body stands once in the package" \
	"$( cat "$rigSession" "$rigItem" "$rigShared" 2> /dev/null | LC_ALL=C grep -c 'index( \$0, k\[i\]' || : )" 1

echo "-- 2. both readers answer the same values for the same keys --"
printf -- '---\nspawn-id: rig-run-1\nmember: rig-fixture\nstatus: spawn-started\nsession-comment: a run of this rig\n---\nmark: this body line is no header\n' | rigOwnerSpawnPut rig-run-1 \
	|| rigRefuse "the owner did not write the run record"
printf -- '---\ntype: task\nmark: urgent\nowner: rig-fixture\n---\nstatus: this body line is no header\n' | rigStoreItem "$rigData" board review note-20261117T0000Z-rig.md \
	|| rigRefuse "the owner did not write the board item"
rigRunOut="$( rigRead '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.include" || exit 1
	AgentsSessionRunHeadersInto rig-run-1 readMember=member readAbsent=nosuchkey readMark=mark || exit 1
	printf "%s|%s|%s" "$readMember" "$readAbsent" "$readMark"
' )" || rigRefuse "the run-record reader did not answer"
rigItemOut="$( rigRead '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ItemDecisions.include" || exit 1
	AgentsToolsBoardItemHeadersInto note-20261117T0000Z-rig.md readState readMark=mark readType=type readAbsent=nosuchkey || exit 1
	printf "%s|%s|%s|%s" "$readState" "$readMark" "$readType" "$readAbsent"
' )" || rigRefuse "the board item reader did not answer"
rigAssert "the run record's own key, its absent key, and its body line" "$rigRunOut" "rig-fixture||"
rigAssert "the item's state, its two keys, its absent key, and its body line" "$rigItemOut" "review|urgent|task|"

echo "-- 3. the lookup takes the one list: every state, an appended one, and the list's own order --"
rigBoardStates "$rigData" || rigRefuse "the board's own maker did not stand the state folders up"
rigAllStates="$( rigRead '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 1 ; printf "%s " $agentsBoardStates' )" || rigRefuse "the one list did not read"
rigStateCount="$( printf '%s' "$rigAllStates" | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' )"
rigAssert "control: the one list names the states this rig walks" "$( [ "$rigStateCount" -ge 9 ] && printf at-least-nine || printf "only $rigStateCount" )" at-least-nine
rigFound=""
rigWant=""
for rigState in $rigAllStates ; do
	rigWant="$rigWant$rigState "
	printf -- '---\ntype: note\n---\nrig body\n' | rigStoreItem "$rigData" board "$rigState" "note-20261117T0000Z-$rigState.md" \
		|| rigRefuse "the owner did not write the item of $rigState"
	rigFound="$rigFound$( rigRead '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ItemDecisions.include" || exit 1
		AgentsToolsBoardItemInto readPath "'"note-20261117T0000Z-$rigState.md"'" || exit 1
		printf "%s" "${readPath%/*}"
	' | LC_ALL=C sed 's|^.*/board/||' ) "
done
rigAssert "the lookup reaches every state of the one list" "$rigFound" "$rigWant"

## The order the answer comes in is the active states first, then the rest, of the one list: a name that a live state
## and the backlog both hold answers the live one. This case holds before the fix as after, so it pins the order the
## fix must keep. What the fix alone can meet is the case below: a state the list gains is searched with no code change.
for rigState in backlog running ; do
	printf -- '---\ntype: note\n---\nrig body\n' | rigStoreItem "$rigData" board "$rigState" note-20261117T0000Z-two-states.md \
		|| rigRefuse "the owner did not write the item of $rigState"
done
rigAssert "a name a live state and the backlog both hold answers the live one" \
	"$( rigRead '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ItemDecisions.include" || exit 1
		AgentsToolsBoardItemInto readPath note-20261117T0000Z-two-states.md || exit 1
		printf "%s" "${readPath%/*}"
	' | LC_ALL=C sed 's|^.*/board/||' )" "running"

## An appended state is the case a literal list cannot meet: the vocabulary grows, and no further code changes. The
## list is extended, the board's own maker stands the appended state's folder up, the item writer puts one item there,
## and the lookup finds it. Every write is the owner's own: this check builds no store path and moves no file.
rigAssert "a state appended to the one list is made and found with no further code" \
	"$( rigRead '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 1
		agentsBoardStates="$agentsBoardStates rig-new-state"
		AgentsToolsBoardReady || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
		printf -- "---\ntype: note\n---\nrig body\n" | AgentsToolsItemUpsert rig-fixture --from-board rig-new-state note-20261117T0000Z-appended.md --upsert-from-stdin --context rig || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ItemDecisions.include" || exit 1
		AgentsToolsBoardItemInto readPath note-20261117T0000Z-appended.md || exit 1
		printf "%s" "${readPath%/*}"
	' | LC_ALL=C sed 's|^.*/board/||' )" "rig-new-state"

## The one awk a call: the count inside each reader's own body, never the whole include.
rigBody(){ ## file, function name -- that function's body
	LC_ALL=C awk -v fn="$2" 'index( $0, fn "()" ) == 1 { inBody = 1 ; next ; } inBody && $0 == "}" { exit ; } inBody { print ; }' "$1"
}
rigAssert "the run-record reader makes one awk call in its own body" \
	"$( rigBody "$rigSession" AgentsSessionRunHeadersInto | LC_ALL=C grep -c 'LC_ALL=C awk' || : )" 1
rigAssert "the board item reader makes one awk call in its own body" \
	"$( rigBody "$rigItem" AgentsToolsBoardItemHeadersInto | LC_ALL=C grep -c 'LC_ALL=C awk' || : )" 1

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ]
