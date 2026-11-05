#!/usr/bin/env bash
## Behavioural check on the epic blueprint as a vault document type (S17.4, S6.43): `vault-item.epic-blueprint`, its contract, its one write
## `--upsert-vault-epic-blueprint`, and the three epic operations taking a vault item beside a path. A vault epic blueprint is
## `epic-blueprint-<date>-<matter>.md` in the team-data vault, so any member reads it with no ask, and every change commits. Held:
##   1. THE KIND IS BUILT: `vault-item.epic-blueprint` is named among the kinds, and the typed write stamps its contract and its
##      type word on a new item.
##   2. BOTH CHECKS PASS on the item: `--intern-doc-validate epic` (the shape, its frontmatter skipped) and
##      `--intern-doc-validate vault-item.epic-blueprint` (the store, the keys and the filename), with no row.
##   3. ANY MEMBER READS IT: `--get-vault-item` and `--epic-read` both serve a member that is no coordinator, and
##      `--epic-read --feature` returns one feature's section of the vault item.
##   4. THE WRITE IS THE ONE PATH: `--epic-update` on a vault item changes the item and leaves no second write path,
##      and a generic `--upsert-vault-item` of an epic name is refused.
##   5. EVERY CHANGE COMMITS: `--get-path-history` shows one more commit for each write.
##   6. REFUSED: a write as another member, a document that breaks the epic shape, a document that breaks the vault
##      keys, a name of another contract's type word, a missing vault item, and `--epic-list` of a folder that is no
##      `todo-sketchpad`.
## The red case of the unbuilt tree: the kind does not exist, so the item cannot be written at all, and a member's
## `--epic-read` is refused. Offline: a rig workspace, a rig store that is a git repository, and the real tooling.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigItems="$rigPackage/sh-scripts/DistroAgentsItems.fn.sh"
rigDispatch="$rigPackage/sh-scripts/AgentDispatcherTools.fn.sh"
rigValidate="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigKnowledge="$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigTool in "$rigItems" "$rigDispatch" "$rigValidate" "$rigKnowledge" ; do
	[ -f "$rigTool" ] || rigRefuse "a tool of the tooling is missing at the origin this workspace resolves: $rigTool"
done
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's fixture that makes its folder is missing from the package"
rigTmp="$( rigTempDir AgentsEpicVaultTypeCheck )" || rigRefuse "the rig's own folder could not be made"
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
rigWs="$rigTmp/ws" rigStore="$rigWs/store" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/temp" "$rigStore/vault" "$rigHome" "$rigSkills/magic-coordinator" "$rigSkills/magic-developer"
for rigMember in magic-coordinator magic-developer ; do printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md" ; done
git -C "$rigStore" init -q || rigRefuse "could not init the rig store"
git -C "$rigStore" config user.email rig@example.invalid
git -C "$rigStore" config user.name rig
git -C "$rigStore" commit -q --allow-empty -m seed || rigRefuse "could not seed the rig store"

rigOp(){ ## result prefix, the member (empty for no member), the tool, then its words... -- rc in $prefix.rc
	local rigResult="$1" rigAs="$2" rigToolPath="$3"
	shift 3
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" MDAT_WAIT_REMIND=off ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigToolPath" "$@" ) > "$rigResult.out" 2> "$rigResult.err" < /dev/null
	printf '%s' "$?" > "$rigResult.rc"
}
rigCommits(){ git -C "$rigStore" rev-list --count HEAD ; }
rigSaid(){ LC_ALL=C grep -c -F -- "$2" "$1.err" || : ; }

rigEpicName="epic-blueprint-20261102T0000Z-rig.md"
rigEpicPath="$rigStore/vault/$rigEpicName"
rigBody='---
document-contract: vault-item.epic-blueprint
type: epic-blueprint
from: magic-coordinator
date: 2026-11-02 00:00 +0200
---
# 20261102 rig: the epic

Source: `rig.sketch.md`. The rig sprint.
Builders: magic-developer for the code.

## Decisions

- One rule holds.

---

## S1 - The rig feature

Owner: magic-developer. State: open.

1. One outcome a check can pass. Owner: magic-developer.

## Done

'
rigCommitsAtWrite="$( rigCommits )"
printf '%s' "$rigBody" > "$rigTmp/body.md"

 echo "-- 1. the kind is built, and its typed write stamps it --"
rigOp "$rigTmp/w1" magic-coordinator "$rigItems" --upsert-vault-epic-blueprint "$rigEpicName" --from-file "$rigTmp/body.md"
rigAssert "the epic blueprint vault write succeeds"             "$( cat "$rigTmp/w1.rc" ):$( [ -f "$rigEpicPath" ] && printf made || printf none )" "0:made"
rigAssert "it names its contract and its type word"             "$( LC_ALL=C grep -c -x -F 'document-contract: vault-item.epic-blueprint' "$rigEpicPath" ):$( LC_ALL=C grep -c -x -F 'type: epic-blueprint' "$rigEpicPath" )" "1:1"
rigOp "$rigTmp/w1b" magic-coordinator "$rigValidate" --intern-doc-validate no-such-kind "$rigEpicPath"
rigAssert "the kind is built: it is named among the kinds"      "$( cat "$rigTmp/w1b.rc" ):$( LC_ALL=C grep -c -w 'vault-item.epic-blueprint' "$rigTmp/w1b.err" )" "1:1"

echo "-- 2. both checks pass on the item --"
rigOp "$rigTmp/c1" "" "$rigValidate" --intern-doc-validate epic "$rigEpicPath"
rigAssert "the epic shape passes, its frontmatter skipped"       "$( cat "$rigTmp/c1.rc" ):$( LC_ALL=C grep -c . "$rigTmp/c1.out" )" "0:0"
rigOp "$rigTmp/c2" "" "$rigValidate" --intern-doc-validate vault-item.epic-blueprint "$rigEpicPath"
rigAssert "the vault contract passes"                            "$( cat "$rigTmp/c2.rc" ):$( LC_ALL=C grep -c . "$rigTmp/c2.out" )" "0:0"
printf '%s' "$rigBody" | LC_ALL=C sed 's/^# 20261102 rig: the epic$/no title here/' > "$rigTmp/broken-shape.md"
rigOp "$rigTmp/c3" "" "$rigValidate" --intern-doc-validate epic "$rigTmp/broken-shape.md"
rigAssert "control: the epic shape still refuses a document with no title" "$( cat "$rigTmp/c3.rc" ):$( LC_ALL=C grep -c 'epic-title' "$rigTmp/c3.out" )" "1:1"
printf '%s' "$rigBody" | LC_ALL=C sed '/^type: epic-blueprint$/d' > "$rigTmp/broken-keys.md"
rigOp "$rigTmp/c4" "" "$rigValidate" --intern-doc-validate vault-item.epic-blueprint "$rigTmp/broken-keys.md"
rigAssert "control: the vault contract still refuses a missing key"        "$( cat "$rigTmp/c4.rc" ):$( LC_ALL=C grep -c 'the key type is required' "$rigTmp/c4.out" )" "1:1"

echo "-- 3. any member reads it, with no ask --"
rigOp "$rigTmp/r1" magic-developer "$rigItems" --get-vault-item "$rigEpicName"
rigAssert "a member reads the item through the vault read"      "$( cat "$rigTmp/r1.rc" ):$( LC_ALL=C grep -c -x -F '## S1 - The rig feature' "$rigTmp/r1.out" )" "0:1"
rigOp "$rigTmp/r2" magic-developer "$rigDispatch" --epic-read "$rigEpicName"
rigAssert "a member reads it through --epic-read, whole"        "$( cat "$rigTmp/r2.rc" ):$( LC_ALL=C grep -c -x -F '## Decisions' "$rigTmp/r2.out" )" "0:1"
rigOp "$rigTmp/r3" magic-developer "$rigDispatch" --epic-read "$rigEpicName" --feature S1
rigAssert "one feature of the vault item comes back alone"      "$( cat "$rigTmp/r3.rc" ):$( LC_ALL=C grep -c -x -F '## S1 - The rig feature' "$rigTmp/r3.out" ):$( LC_ALL=C grep -c -x -F '## Decisions' "$rigTmp/r3.out" )" "0:1:0"
rigOp "$rigTmp/r4" magic-coordinator "$rigDispatch" --epic-list
rigAssert "the vault's epics are listed with no folder"         "$( cat "$rigTmp/r4.rc" ):$( LC_ALL=C grep -c -F "$rigEpicName" "$rigTmp/r4.out" )" "0:1"

echo "-- 4. one write path: --epic-update, and no generic write around it --"
rigOp "$rigTmp/u1" magic-developer "$rigDispatch" --epic-update "$rigEpicName" --set-status S1 running
rigAssert "another member's edit of the epic is refused"         "$( cat "$rigTmp/u1.rc" ):$( rigSaid "$rigTmp/u1" 'runs only as magic-coordinator' )" "1:1"
rigOp "$rigTmp/u2" magic-coordinator "$rigDispatch" --epic-update "$rigEpicName" --set-status S1 running
rigAssert "the coordinator edits the vault item, and it is stored" "$( cat "$rigTmp/u2.rc" ):$( LC_ALL=C grep -c -x -F 'Status: running' "$rigEpicPath" )" "0:1"
rigOp "$rigTmp/u3" magic-coordinator "$rigDispatch" --epic-update "$rigEpicName" --add-settled S1 one rule holds
rigAssert "a settlement is stored under its feature"             "$( cat "$rigTmp/u3.rc" ):$( LC_ALL=C grep -c -x -F 'one rule holds' "$rigEpicPath" )" "0:1"
printf -- 'x\n' | rigOp "$rigTmp/u4" magic-coordinator "$rigItems" --upsert-vault-item "$rigEpicName" --upsert-from-stdin
rigAssert "the generic vault write refuses an epic blueprint name" "$( cat "$rigTmp/u4.rc" ):$( rigSaid "$rigTmp/u4" '--upsert-vault-epic-blueprint' )" "1:1"

echo "-- 5. every change commits --"
rigCommitsAfter="$( rigCommits )"
rigOp "$rigTmp/u5" magic-coordinator "$rigDispatch" --epic-update "$rigEpicName" --set-status S1.1 done "one outcome holds now"
rigAssert "closing an item is one more commit, and the store is clean" "$( cat "$rigTmp/u5.rc" ):$(( $( rigCommits ) - rigCommitsAfter )):$( [ -z "$( git -C "$rigStore" status --porcelain )" ] && printf clean || printf dirty )" "0:1:clean"
rigOp "$rigTmp/h1" magic-developer "$rigKnowledge" --get-path-history "$rigEpicPath"
rigAssert "the history shows one commit for each write"          "$( cat "$rigTmp/h1.rc" ):$( [ "$( LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}	' "$rigTmp/h1.out" )" -eq "$(( $( rigCommits ) - rigCommitsAtWrite ))" ] && printf each || printf other )" "0:each"

echo "-- 6. refused, each with its reason --"
rigOp "$rigTmp/x1" magic-coordinator "$rigItems" --upsert-vault-epic-blueprint adr-20261102T0000Z-other.md --from-file "$rigTmp/body.md"
rigAssert "an epic blueprint body under another contract's name is refused" "$( cat "$rigTmp/x1.rc" ):$( [ -f "$rigStore/vault/adr-20261102T0000Z-other.md" ] && printf made || printf none )" "1:none"
rigOp "$rigTmp/x2" magic-coordinator "$rigItems" --upsert-vault-epic-blueprint epic-blueprint-20261102T0001Z-broken.md --from-file "$rigTmp/broken-shape.md"
rigAssert "the write is the store's check, and the shape has its own: a bad shape is stored, then refused by the epic check" "$( cat "$rigTmp/x2.rc" ):$( [ -f "$rigStore/vault/epic-blueprint-20261102T0001Z-broken.md" ] && printf made || printf none ):$( rigOp "$rigTmp/x2b" "" "$rigValidate" --intern-doc-validate epic "$rigStore/vault/epic-blueprint-20261102T0001Z-broken.md" ; cat "$rigTmp/x2b.rc" )" "0:made:1"
rigOp "$rigTmp/x3" magic-developer "$rigDispatch" --epic-read epic-blueprint-20260901T0000Z-none.md
rigAssert "a vault epic blueprint item that is not there is refused" "$( cat "$rigTmp/x3.rc" ):$( rigSaid "$rigTmp/x3" 'no such vault epic item' )" "1:1"
rigOp "$rigTmp/x4" magic-developer "$rigDispatch" --epic-list "$rigTmp"
rigAssert "a folder outside a todo-sketchpad is refused"         "$( cat "$rigTmp/x4.rc" ):$( rigSaid "$rigTmp/x4" 'is not under a todo-sketchpad folder' )" "1:1"
for rigRefused in w1 c1 c2 r1 r2 r3 u2 u3 u5 h1 x1 x2 x3 x4 ; do
	[ "$( LC_ALL=C grep -c 'invalid option' "$rigTmp/$rigRefused.err" || : )" = 0 ] || rigAssert "$rigRefused reached its operation, never an unknown one" "$( LC_ALL=C grep -c 'invalid option' "$rigTmp/$rigRefused.err" )" 0
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EPIC VAULT TYPE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EPIC_VAULT_TYPE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
