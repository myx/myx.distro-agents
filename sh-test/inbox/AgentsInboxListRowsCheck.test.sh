#!/usr/bin/env bash
## Behavioural check on the inbox listing, one row for every item (task-20261111T1948Z-inbox-listing-blind-for-one-member):
## `--list-inbox-items` reads a member's `incoming/` and, with `--include-processed`, its `processed/`. The listing's own
## per-folder awk call must not end the whole listing where one folder's `*.md` glob matches nothing: an inbox whose
## `incoming/` holds no `.md` is the ordinary state of a drained inbox, and it blinded the call until 2026-11-12.
## Held, against a scratch team data store:
##   1. `incoming/` holding no `.md` and `processed/` holding three: three rows with --include-processed, none without
##   2. a suffix-less entry in `incoming/`, beside one `.md` there: the `.md` row is listed without the option, and the
##      suffix-less entry is no row (the listing reads `*.md`, and a name that is no item is no row)
##   3. the control that the arm separates two answers on one inbox: an item taken out gives one row fewer, and back in
##      gives it again, the call's own status 0 in both directions
## Red: with the `|| :` taken off the per-folder awk call, section 1 reads no row at all.
## Offline: one mktemp tree, every call through one `env -i` whose child refuses to run outside it; no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxListRowsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home"
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigInbox="$rigData/inboxes/rig-member"
mkdir -p "$rigHome" "$rigWs/.local" "$rigInbox/incoming" "$rigInbox/processed" || rigRefuse "could not create the scratch team data store"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigList(){ ## out file, arguments... -- one listing call; rc into <out>.rc
	local listOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash "$rigFn" "$@" ) > "$listOut" 2>&1 < /dev/null || { printf '%s' "$?" > "$listOut.rc" ; return 0 ; }
	printf '0' > "$listOut.rc"
}
## A row is a line whose first tab field is the folder's own state word: the header line and any prose are none.
rigRows(){ ## out file -- its rows only
	LC_ALL=C awk -F'\t' '$1 == "incoming" || $1 == "processed" { print }' "$1" 2> /dev/null
}
rigRowCount(){ ## out file, state word
	rigRows "$1" | LC_ALL=C grep -c "^$2" || :
}
rigItem(){ ## folder, item filename
	printf -- '---\ntype: note\n---\n\n# Rig item %s\n' "$2" > "$rigInbox/$1/$2"
}

echo "-- 1. an inbox with no .md in incoming/ still lists its processed items --"
for rigN in one two three ; do rigItem processed "note-20261101T0900Z-$rigN.md" ; done
rigList "$rigTmp/l1" --list-inbox-items --of rig-member
rigAssert "the plain listing succeeds"                          "$( cat "$rigTmp/l1.rc" )" 0
rigAssert "and holds no row, the option not being given"         "$( rigRows "$rigTmp/l1" | LC_ALL=C grep -c . || : )" 0
rigList "$rigTmp/l2" --list-inbox-items --of rig-member --include-processed
rigAssert "with --include-processed it succeeds"                 "$( cat "$rigTmp/l2.rc" )" 0
rigAssert "and holds one row per processed item, three"          "$( rigRowCount "$rigTmp/l2" processed )" 3
rigAssert "each row naming its own item"                         "$( rigRows "$rigTmp/l2" | LC_ALL=C awk -F'\t' '{ print $2 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "note-20261101T0900Z-one.md note-20261101T0900Z-three.md note-20261101T0900Z-two.md "

echo "-- 2. a suffix-less entry beside a real one: the real one is still a row --"
printf 'a name that is no item\n' > "$rigInbox/incoming/reflection-20261030T0000Z-suffixless"
rigItem incoming note-20261101T0904Z-in.md
rigList "$rigTmp/l3" --list-inbox-items --of rig-member
rigAssert "the plain listing succeeds"                           "$( cat "$rigTmp/l3.rc" )" 0
rigAssert "and names the item of incoming/"                      "$( rigRowCount "$rigTmp/l3" incoming )" 1
rigAssert "the suffix-less name is no row, the listing reading *.md" "$( rigRows "$rigTmp/l3" | LC_ALL=C grep -c 'suffixless' || : )" 0

echo "-- 3. the control: one item fewer is one row fewer, and back --"
mv "$rigInbox/processed/note-20261101T0900Z-two.md" "$rigTmp/two.parked"
rigList "$rigTmp/l4" --list-inbox-items --of rig-member --include-processed
rigAssert "one row fewer with the item out"                      "$( cat "$rigTmp/l4.rc" ) $( rigRowCount "$rigTmp/l4" processed )" "0 2"
mv "$rigTmp/two.parked" "$rigInbox/processed/note-20261101T0900Z-two.md"
rigList "$rigTmp/l5" --list-inbox-items --of rig-member --include-processed
rigAssert "and its row back with the item in place"              "$( cat "$rigTmp/l5.rc" ) $( rigRowCount "$rigTmp/l5" processed )" "0 3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX LIST ROWS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a per-folder glob that matches nothing ends the listing, and a drained incoming/ blinds a populated inbox" >&2
	echo "  fix:  the per-folder awk call in --list-inbox-items, sh-lib/member/AgentsTools.Member.include" >&2
	exit 1
fi
printf 'INBOX_LIST_ROWS: OK (%d assertions, offline)\n' "$rigPassCount"
