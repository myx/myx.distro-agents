#!/usr/bin/env bash
## Behavioural check on S23.2: the parent of a session can add items to the CheckList of that session's executor. Through the real CheckList tool (--intern-tool CheckList),
## its own spawn records and the list the tool keeps. Held:
##   1. THE PARENT ADDS: a call from the parent session with append, member (the executor) and session puts the items on the executor's list, pending, after what it holds
##   2. NOT THE PARENT, NOT THE EXECUTOR, OR NO SESSION KNOWN: each is an error and changes nothing
##   3. OWN LIST: with no session, append adds to the caller's own list; to another member's list of its own session it is refused
##   4. THE OWNER'S WHOLE-LIST WRITE KEEPS WHAT IT WAS NOT SHOWN: items added since its last read or write stay, as pending, whatever list it gives, and the result says so
##   5. ...BUT NOT WHAT IT SAW: after a read of its own list the same write drops them, since the owner chose a list that was whole to it
##   6. TWO APPENDS AT ONCE lose none: the lock holds
##   7. append and todos together are refused
## Offline: every tree is this rig's own; no network is reached (the tool reads nothing of Slack).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCheckListAppendCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSp="$rigTmp/ws/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigSp/parent-folder" "$rigSp/child-folder" "$rigSp/other-folder" "$rigTmp/data"
for rigMember in magic-coordinator keeper-exec keeper-other ; do
	mkdir -p "$rigTmp/skills/$rigMember"
	printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
done
## The records: a parent session, its child (executor keeper-exec, whose record names the parent), and another session with another parent.
printf -- '---\nspawn-id: rig-parent\nsession-id: rig-parent\nowner: magic-coordinator\nparent-session-id: none\n---\n' > "$rigSp/parent-folder/rig-parent.spawn.md"
printf -- '---\nspawn-id: rig-child\nsession-id: rig-child\nowner: keeper-exec\nparent-session-id: rig-parent\n---\n' > "$rigSp/child-folder/rig-child.spawn.md"
printf -- '---\nspawn-id: rig-stranger\nsession-id: rig-stranger\nowner: keeper-other\nparent-session-id: rig-someone-else\n---\n' > "$rigSp/other-folder/rig-stranger.spawn.md"
rigChildList="$rigSp/child-folder/keeper-exec.checklist.md"
rigParentList="$rigSp/parent-folder/magic-coordinator.checklist.md"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigCall(){ ## caller spawn id, caller member, the JSON arguments -- the tool's whole answer
	( cd "$rigWs" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_SESSION_ID="$1" MDAT_SPAWN_AGENT="$2" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool CheckList 2> /dev/null )
}
rigLines(){ ## file -- its lines as one word, each joined by ` | `
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '{ printf "%s%s", ( n++ ? " | " : "" ), $0 }' "$1"
}
rigHead(){ ## text -- its first word
	printf '%s' "${1%%:*}"
}

echo "-- 1. the parent adds --"
printf -- '- [x] done already\n' > "$rigChildList"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["write the test","run it"],"member":"keeper-exec","session":"rig-child"}' )"
rigAssert "the parent's call is answered OK, naming the member and the session" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'keeper-exec in session rig-child' )" "OK:1"
rigAssert "the items stand after what the list held, pending" "$( rigLines "$rigChildList" )" "- [x] done already | - [ ] write the test | - [ ] run it"
rigAssert "and are noted for the owner" "$( rigLines "$rigChildList.added" )" "- [ ] write the test | - [ ] run it"

echo "-- 2. not the parent, not the executor, no session --"
rigOut="$( rigCall rig-stranger keeper-other '{"append":["sneaky"],"member":"keeper-exec","session":"rig-child"}' )"
rigAssert "a session that is not the parent is refused" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'only the parent of session rig-child' )" "ERROR:1"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["wrong member"],"member":"keeper-other","session":"rig-child"}' )"
rigAssert "a member that is not the executor is refused" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'is not the executor of session rig-child' )" "ERROR:1"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["nowhere"],"member":"keeper-exec","session":"rig-nosuch"}' )"
rigAssert "a session no record names is refused" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'no session rig-nosuch is known' )" "ERROR:1"
rigAssert "none of the three changed the list" "$( rigLines "$rigChildList" )" "- [x] done already | - [ ] write the test | - [ ] run it"

echo "-- 3. the caller's own list --"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["my own item"],"member":"magic-coordinator"}' )"
rigAssert "with no session, append adds to the caller's own list" "$( rigHead "$rigOut" ):$( rigLines "$rigParentList" )" "OK:- [ ] my own item"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["not mine"],"member":"keeper-exec"}' )"
rigAssert "another member's list, in the caller's own session, is refused" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'you append to your own list only' )" "ERROR:1"

echo "-- 4. the owner's whole-list write keeps what it was not shown --"
rigOut="$( rigCall rig-child keeper-exec '{"todos":[{"content":"write the test","status":"completed","activeForm":"Writing the test"}]}' )"
rigAssert "the write is OK and says another session's items were kept" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c '1 item(s) another session had added to it were kept, as pending' )" "OK:1"
rigAssert "the list has the owner's item, closed, and the one it was not shown, pending" "$( rigLines "$rigChildList" )" "- [x] write the test | - [ ] run it"
rigAssert "nothing is left to be kept" "$( [ -e "$rigChildList.added" ] && printf left || printf none )" "none"

echo "-- 5. but not what it saw --"
rigCall rig-parent magic-coordinator '{"append":["a third item"],"member":"keeper-exec","session":"rig-child"}' > /dev/null
rigOut="$( rigCall rig-child keeper-exec '' )"
rigAssert "the owner's read shows the list whole, the new item in it" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'a third item' )" "1"
rigOut="$( rigCall rig-child keeper-exec '{"todos":[{"content":"write the test","status":"completed","activeForm":"Writing the test"}]}' )"
rigAssert "the write after the read drops what the owner left out" "$( rigHead "$rigOut" ):$( rigLines "$rigChildList" )" "OK:- [x] write the test"

echo "-- 6. two appends at once --"
rm -f "$rigChildList" "$rigChildList.added"
rigCall rig-parent magic-coordinator '{"append":["a1","a2","a3","a4"],"member":"keeper-exec","session":"rig-child"}' > /dev/null &
rigCall rig-parent magic-coordinator '{"append":["b1","b2","b3","b4"],"member":"keeper-exec","session":"rig-child"}' > /dev/null &
wait
rigAssert "all eight items are there, once each" "$( LC_ALL=C grep -c '^- \[ \] [ab][1-4]$' "$rigChildList" ):$( LC_ALL=C sort -u "$rigChildList" | LC_ALL=C grep -c . ):$( [ -d "$rigChildList.lock" ] && printf locked || printf free )" "8:8:free"

echo "-- 7. append and todos together --"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["x"],"member":"keeper-exec","session":"rig-child","todos":[{"content":"y","status":"pending","activeForm":"Y"}]}' )"
rigAssert "refused" "$( rigHead "$rigOut" ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'append adds to a list and takes no todos' )" "ERROR:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CHECKLIST APPEND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CHECKLIST_APPEND: OK (%d assertions, offline)\n' "$rigPassCount"
