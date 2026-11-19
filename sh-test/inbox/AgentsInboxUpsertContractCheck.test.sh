#!/usr/bin/env bash
## Behavioural check on the contract of an inbox upsert (--upsert-inbox-note, --upsert-inbox-inquiry, --upsert-inbox-reflection):
## every write lands as a whole item of the operation's own type, or nothing is written.
## Held, against a temp store only:
##   1. CONTROL: a new inquiry from a body alone, and a whole inquiry, are written, the headers stamped; a note likewise.
##   2. Each operation writes its own type only: a note- name through the inquiry operation, an inquiry- name through
##      the note operation and a note- name through the reflection operation are refused, nothing written, the type named.
##   3. A new item whose body opens a frontmatter block it never closes is refused, nothing written, the block named.
##   4. An update of an item that has no frontmatter, by a body with none, is refused, the item as it was.
##   5. An update of an item that lacks required keys, by content that still lacks them, is refused, the keys named.
##   6. The item upsert (AgentsToolsItemUpsert --from-inbox) stamps and gates an inbox item too: a create fills the contract's
##      tooling-filled keys, a create whose block never closes or whose type is not the name's is refused, and a stored note
##      that lacked keys before stays writable.
## A malformed stored item is planted by writing the file into this rig's own temp store: no owner writes one.
## Every call goes through one `env -i` whose child refuses to run outside this rig's mktemp tree; no Slack, no mail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxUpsertContractCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigWs="$rigTmp/ws"
rigStoreSkills="$rigSkills"
mkdir -p "$rigWs/.local" "$rigTmp/home" "$rigSkills/magic-architect" "$rigSkills/magic-coordinator" "$rigData"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSaid(){ ## fixed text -- yes where the last call's output holds it
	LC_ALL=C grep -q -F -- "$1" "$rigTmp/out" && printf yes || printf no
}
rigIn(){ ## member, item filename -- yes where it is in that inbox, incoming/ or processed/
	[ -f "$rigData/inboxes/$1/incoming/$2" ] || [ -f "$rigData/inboxes/$1/processed/$2" ] && printf yes || printf no
}
rigField(){ ## file, field -- the value of one frontmatter field, bounded to the first --- block
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigTile(){ ## file -- the hash of the item's bytes, so an unchanged item is told from a rewritten one
	shasum -a 256 "$1" 2> /dev/null | LC_ALL=C cut -c 1-64
}
rigOp(){ ## args... -- stdout and stderr in out, rc in rigRc; the acting member is magic-coordinator
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_AGENT=magic-coordinator \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_WAIT_REMIND=off \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/out" 2>&1
	rigRc=$?
}
printf 'Body line one.\nBody line two.\n' > "$rigTmp/body.md"

echo "-- 1. control: a new item from a body alone, or whole, is written --"
rigOp --upsert-inbox-inquiry magic-architect inquiry-20261118T2100Z-rig-body.md --from-member magic-coordinator --from-file "$rigTmp/body.md"
rigI1="$rigData/inboxes/magic-architect/incoming/inquiry-20261118T2100Z-rig-body.md"
rigAssert "an inquiry from a body alone is written, its headers stamped" "$rigRc:$( rigField "$rigI1" type ):$( rigField "$rigI1" from ):$( rigField "$rigI1" document-contract )" "0:inquiry:magic-coordinator:inbox-item.inquiry"
printf -- '---\ntype: inquiry\nfrom: magic-coordinator\n---\n\n# Inquiry: rig whole\n\nWhole.\n' > "$rigTmp/whole.md"
rigOp --upsert-inbox-inquiry magic-architect inquiry-20261118T2101Z-rig-whole.md --from-file "$rigTmp/whole.md"
rigAssert "a whole inquiry is written" "$rigRc:$( rigIn magic-architect inquiry-20261118T2101Z-rig-whole.md )" "0:yes"
rigOp --upsert-inbox-note --team-member magic-coordinator note-20261118T2102Z-rig-own.md --from-file "$rigTmp/body.md"
rigAssert "a note from a body alone is written" "$rigRc:$( rigIn magic-coordinator note-20261118T2102Z-rig-own.md )" "0:yes"

echo "-- 2. each operation writes its own type only --"
rigOp --upsert-inbox-inquiry magic-architect note-20261118T2103Z-rig-cross.md --from-member magic-coordinator --include-processed --from-file "$rigTmp/body.md"
rigAssert "a note- name through the inquiry operation is refused, nothing written" "$rigRc:$( rigIn magic-architect note-20261118T2103Z-rig-cross.md )" "1:no"
rigAssert "and the refusal names the operation's type and the name's" "$( rigSaid '--upsert-inbox-inquiry writes inquiry-* items only, and note-20261118T2103Z-rig-cross.md names a note' )" yes
rigOp --upsert-inbox-note --team-member magic-coordinator inquiry-20261118T2104Z-rig-cross.md --from-file "$rigTmp/body.md"
rigAssert "an inquiry- name through the note operation is refused, nothing written" "$rigRc:$( rigIn magic-coordinator inquiry-20261118T2104Z-rig-cross.md ):$( rigSaid 'writes note-* items only' )" "1:no:yes"
rigOp --upsert-inbox-reflection --team-member magic-coordinator note-20261118T2105Z-rig-cross.md --from-file "$rigTmp/body.md"
rigAssert "a note- name through the reflection operation is refused, nothing written" "$rigRc:$( rigIn magic-coordinator note-20261118T2105Z-rig-cross.md ):$( rigSaid 'writes reflection-* items only' )" "1:no:yes"

echo "-- 3. a new item with no complete frontmatter --"
printf -- '---\nBody under a block that never closes.\n' > "$rigTmp/open.md"
rigOp --upsert-inbox-inquiry magic-architect inquiry-20261118T2106Z-rig-open.md --from-member magic-coordinator --from-file "$rigTmp/open.md"
rigAssert "a new inquiry whose block never closes is refused, nothing written, the block named" "$rigRc:$( rigIn magic-architect inquiry-20261118T2106Z-rig-open.md ):$( rigSaid 'the document has no complete frontmatter block' ):$( rigSaid 'nothing was written' )" "1:no:yes:yes"

echo "-- 4. an update of an item that has no frontmatter --"
rigBare="$rigData/inboxes/magic-coordinator/incoming/note-20261118T2107Z-rig-bare.md"
cp "$rigTmp/body.md" "$rigBare" || rigRefuse "could not plant the stored item $rigBare"
[ "$( LC_ALL=C sed -n 1p "$rigBare" )" = "Body line one." ] || rigRefuse "the stored item is not the bare body this case needs: $rigBare"
rigBefore="$( rigTile "$rigBare" )"
printf 'A new body, still bare.\n' > "$rigTmp/bare2.md"
rigOp --upsert-inbox-note --team-member magic-coordinator note-20261118T2107Z-rig-bare.md --from-file "$rigTmp/bare2.md"
rigAssert "the update is refused, the frontmatter named, the item as it was" "$rigRc:$( rigSaid 'the document has no complete frontmatter block' ):$( rigTile "$rigBare" )" "1:yes:$rigBefore"

echo "-- 5. an update of an item that lacks required keys --"
printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-11-18 21:08 +0000\n---\n\nKeys missing.\n' > "$rigTmp/short.md"
rigShort="$rigData/inboxes/magic-coordinator/incoming/note-20261118T2108Z-rig-short.md"
cp "$rigTmp/short.md" "$rigShort" || rigRefuse "could not plant the stored item $rigShort"
[ -z "$( rigField "$rigShort" owner )" ] || rigRefuse "the stored item has an owner, and this case needs it without one: $rigShort"
rigBefore="$( rigTile "$rigShort" )"
printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-11-18 21:08 +0000\n---\n\nKeys still missing.\n' > "$rigTmp/short2.md"
rigOp --upsert-inbox-note --team-member magic-coordinator note-20261118T2108Z-rig-short.md --from-file "$rigTmp/short2.md"
rigAssert "the update is refused, each missing key named, the item as it was" "$rigRc:$( rigSaid 'the key owner is required and absent' ):$( rigSaid 'the key document-contract is required and absent' ):$( rigTile "$rigShort" )" "1:yes:yes:$rigBefore"

echo "-- 6. the item upsert gates an inbox item --"
rigPut(){ ## item, body file -- the item upsert's own write into magic-coordinator's inbox; its output in out, rc in rigRc
	rigRc=0
	rigStoreItem "$rigTmp" "$rigData" "$rigWs" magic-coordinator "inbox magic-coordinator $1" "$2" > "$rigTmp/out" 2>&1 || rigRc=$?
}
printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-11-18 21:10 +0000\nowner: magic-coordinator\n---\n\nWhole.\n' > "$rigTmp/put-whole.md"
rigPut note-20261118T2110Z-rig-put-whole.md "$rigTmp/put-whole.md"
rigPutWhole="$rigData/inboxes/magic-coordinator/incoming/note-20261118T2110Z-rig-put-whole.md"
rigAssert "control: a whole note is written, and its contract is filled" "$rigRc:$( rigField "$rigPutWhole" document-contract )" "0:inbox-item.note"
rigPut note-20261118T2111Z-rig-put-bare.md "$rigTmp/body.md"
rigPutBare="$rigData/inboxes/magic-coordinator/incoming/note-20261118T2111Z-rig-put-bare.md"
rigAssert "a create from a body alone is stamped: type, from the caller, owner the inbox's member, the contract" \
	"$rigRc:$( rigField "$rigPutBare" type ):$( rigField "$rigPutBare" from ):$( rigField "$rigPutBare" owner ):$( rigField "$rigPutBare" document-contract )" "0:note:magic-coordinator:magic-coordinator:inbox-item.note"
printf -- '---\nBody under a block that never closes.\n' > "$rigTmp/put-open.md"
rigPut note-20261118T2112Z-rig-put-open.md "$rigTmp/put-open.md"
rigAssert "a create whose block never closes is refused, nothing written" "$rigRc:$( rigIn magic-coordinator note-20261118T2112Z-rig-put-open.md )" "1:no"
printf -- '---\ntype: inquiry\n---\n\nWrong type.\n' > "$rigTmp/put-type.md"
rigPut note-20261118T2114Z-rig-put-type.md "$rigTmp/put-type.md"
rigAssert "a create whose type is not the name's is refused, the type named, nothing written" "$rigRc:$( rigSaid 'is not the type word of the file name' ):$( rigIn magic-coordinator note-20261118T2114Z-rig-put-type.md )" "1:yes:no"
rigOld="$rigData/inboxes/magic-coordinator/incoming/note-20261118T2113Z-rig-put-old.md"
printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\n---\n\nOld.\n' > "$rigOld" || rigRefuse "could not plant the stored item $rigOld"
printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: rig-running\n---\n\nOld, updated.\n' > "$rigTmp/put-old.md"
rigPut note-20261118T2113Z-rig-put-old.md "$rigTmp/put-old.md"
rigAssert "control: a stored note that lacked keys before stays writable" "$rigRc:$( LC_ALL=C grep -c -F 'Old, updated.' "$rigOld" )" "0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX UPSERT CONTRACT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_UPSERT_CONTRACT: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
