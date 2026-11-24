#!/usr/bin/env bash
## AgentsAskOpenOnItemCheck -- an ask to a person about an item, while one to the same person about the same item is still open, is not posted
## again (AgentsToolsAskThreadFind, sh-lib/questions/AgentsTools.AskThread.include). The duplicate test matched on the question's own key, the
## hash of its text, so the same matter asked again in other words, or as a readback after a question, posted a second ask to the same person
## and left two open for the one thing.
##   1. an open question about an item, then a readback about it in other words to the same person: a duplicate, naming the open one
##   2. the same key is a duplicate as before: the control that the old test still holds
##   3. controls, each new: another item; another person; the open ask already answered; a permission ask; an ask with no item
## Red before the fix: the first case is new. Offline: the pending store is the check's own, and nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPackage/sh-lib/questions/AgentsTools.AskThread.include" ] || { echo "⛔ ERROR: the ask-thread include is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsAskOpenOnItemCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
export MMDAPP="$rigTmp/ws"
mkdir -p "$MMDAPP/.local/agents/pending" || exit 1
. "$rigPackage/sh-lib/questions/AgentsTools.AskThread.include" || { echo "⛔ ERROR: the ask-thread include did not load -- refusing to report a result" >&2 ; exit 1 ; }
## ONE PENDING RECORD, the store's own form: its header, then a title line, which ends the header.
rigRecord(){ ## id, status, kind, address-to, key, item
	printf -- '---\nstatus: %s\nkind: %s\naddress-to: %s\nquestion-key: %s\nowner: magic-coordinator\nsession-id: rigsession-0001\nitem: %s\n---\n\n# the ask\n' "$2" "$3" "$4" "$5" "$6" > "$MMDAPP/.local/agents/pending/$1.md"
}
rigAsk(){ ## to, address-to, key, item, kind -- the first word of the answer
	AgentsToolsAskThreadFind "$1" "$2" "$3" "magic-coordinator" "$4" "$5" | LC_ALL=C awk -F'\t' '{ print $1 " " $2 ; }'
}
rigRecord rigopen-0001 reply-pending question human-owner key-first task-20261123T2320Z-rig-item
rigRecord rigdone-0001 reply-received question human-owner key-done task-20261123T2330Z-rig-answered

echo "-- 1. the same item asked again in other words --"
rigAssert "a readback about the item the open question is about is a duplicate, and names it" \
	"$( rigAsk "" human-owner key-other task-20261123T2320Z-rig-item readback )" "DUPLICATE rigopen-0001"
echo "-- 2. the same key --"
rigAssert "control: the same key to the same person is a duplicate, with no item given" "$( rigAsk "" human-owner key-first "" question )" "DUPLICATE rigopen-0001"
echo "-- 3. controls, each new --"
rigAssert "another item is new" "$( rigAsk "" human-owner key-other task-20261123T2399Z-rig-elsewhere readback | LC_ALL=C awk '{ print $1 ; }' )" NEW
rigAssert "another person is new" "$( rigAsk "" magic-devops key-other task-20261123T2320Z-rig-item readback | LC_ALL=C awk '{ print $1 ; }' )" NEW
rigAssert "an item whose ask was answered is new" "$( rigAsk "" human-owner key-other task-20261123T2330Z-rig-answered readback | LC_ALL=C awk '{ print $1 ; }' )" NEW
rigAssert "a permission ask about the item is new" "$( rigAsk "" human-owner key-other task-20261123T2320Z-rig-item permission | LC_ALL=C awk '{ print $1 ; }' )" NEW
rigAssert "an ask with no item is new" "$( rigAsk "" human-owner key-other "" readback | LC_ALL=C awk '{ print $1 ; }' )" NEW

printf 'ASK_OPEN_ON_ITEM: %s (%d assertions, offline, rig tree only)\n' "$( [ "$rigFail" = 0 ] && echo OK || echo FAIL )" "$(( rigPass + rigFail ))"
[ "$rigFail" = 0 ] || exit 1
