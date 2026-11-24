#!/usr/bin/env bash
## AgentsWaitRepliesCursorCheck -- the replies probe of a Wait looks at every own post of the run, across Wait calls, the post whose check
## has been due longest first (AgentsWaitProbeReplies, sh-lib/wait/AgentsTools.MemberWaitReplies.include). A post is due at its last look
## plus its own TTL, and the record carries both. A Wait call starts its round count at 1, so an order keyed on that count restarts at the
## newest posts on every call, and a reply to an older post of a long-lived run is never read in the short Waits a run makes.
##   1. a post never looked at is due since the beginning: a fresh record is looked at newest first, three a round
##   2. over five calls, each starting its round count at 1 and each committing its looks as a Wait does, every one of ten posts is looked at
##   3. of three posts the one whose check has been due longest is looked at first, then the next due, and the post not yet due last,
##      though it is not the newest
##   4. a record of one post is looked at by every call
##   5. nothing is lost by the order: after the calls the record still holds every post once, with its own text, and only the checked
##      time of the posts that were looked at has moved
## Red before the fix: the five calls look at the same three newest posts, and the second case reads the newest first. Offline: the look
## is a stand-in that notes the post it was given and moves its check time, so no service is asked, and the rig workspace is the check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPackage/sh-lib/wait/AgentsTools.MemberWaitReplies.include" ] || { echo "⛔ ERROR: the replies probe is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsWaitRepliesCursorCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
export MMDAPP="$rigTmp/ws"
export MDAT_WORKSPACE_MODE=team-rig
rigBase=1700001000
for rigSession in rigfresh-0001 rigdue-0001 rigsolo-0001 ; do mkdir -p "$MMDAPP/.local/agents/sessions/$rigSession" || exit 1 ; done
## TEN FRESH OWN POSTS, the newest first as the store keeps them: `<channel>:<thread> <ts> <addressees> <thread floor> <conversation floor> <siblings> <reactions> <checked>`.
for rigAt in 10 9 8 7 6 5 4 3 2 1 ; do
	printf 'CRIG:17000009%02d.000100 17000009%02d.000100 U0RIGONE - - 0 - -\n' "$rigAt" "$rigAt"
done > "$MMDAPP/.local/agents/sessions/rigfresh-0001/last-own-post"
## THREE POSTS OF DIFFERENT DUE MOMENTS. A: a new thread, TTL 6 s, looked at 20 s ago, due 14 s ago. B: a quiet one, TTL 100 s, looked at 150 s
## ago, due 50 s ago, the longest. C: quiet, looked at 10 s ago, not due for 90 s.
{
	printf 'CRIG:%s.000100 %s.000100 U0RIGONE - - 0 - %s\n' "$(( rigBase - 30 ))" "$(( rigBase - 30 ))" "$(( rigBase - 20 ))"
	printf 'CRIG:%s.000100 %s.000100 U0RIGONE - - 0 - %s\n' "$(( rigBase - 5000 ))" "$(( rigBase - 5000 ))" "$(( rigBase - 150 ))"
	printf 'CRIG:%s.000100 %s.000100 U0RIGONE - - 0 - %s\n' "$(( rigBase - 6000 ))" "$(( rigBase - 6000 ))" "$(( rigBase - 10 ))"
} > "$MMDAPP/.local/agents/sessions/rigdue-0001/last-own-post"
printf 'CRIG:1700000099.000100 1700000099.000100 U0RIGONE - - 0 - -\n' > "$MMDAPP/.local/agents/sessions/rigsolo-0001/last-own-post"

rigLog="$rigTmp/looks.log"
. "$rigPackage/sh-lib/wait/AgentsTools.MemberWaitReplies.include" || { echo "⛔ ERROR: the replies probe did not load -- refusing to report a result" >&2 ; exit 1 ; }
## THE LOOK is a stand-in that notes the thread of the post it was given and moves its check time to the round's moment, as the real look
## does; the probe's own walk is what is measured.
AgentsWaitRepliesLook(){ ## member, now, the post's line, the rendering file, a number
	local lookWhere lookTs lookAddr lookThreadFloor lookChanFloor lookSibs lookReact lookChecked
	read -r lookWhere lookTs lookAddr lookThreadFloor lookChanFloor lookSibs lookReact lookChecked <<< "$3"
	printf '%s\n' "${lookWhere##*:}" >> "$rigLog"
	printf '%s %s %s %s %s %s %s %s\n' "$lookWhere" "$lookTs" "$lookAddr" "$lookThreadFloor" "$lookChanFloor" "$lookSibs" "$lookReact" "$2" >> "$4.advance"
	return 0
}
## ONE WAIT CALL: its round count starts at 1, as every call's does, and the Wait commits what its looks found when it returns.
rigCall(){ ## session, the round's moment
	local waitRound=1 roundNow="$2"
	AgentsWaitProbeReplies rigmember "$1" "" "$rigTmp/out.$1" && AgentsOwnPostsReplace "$1" "$rigTmp/out.$1.advance"
}

echo "-- 1. a fresh record is looked at newest first, three a round --"
: > "$rigLog"
rigCall rigfresh-0001 "$rigBase"
rigAssert "the first post looked at is the newest" "$( head -1 "$rigLog" )" "1700000910.000100"
rigAssert "the round looks at three posts" "$( LC_ALL=C grep -c . "$rigLog" )" 3

echo "-- 2. over five calls every post is looked at --"
: > "$rigLog" ; printf 'x\n' > /dev/null
for rigAt in 10 9 8 7 6 5 4 3 2 1 ; do
	printf 'CRIG:17000009%02d.000100 17000009%02d.000100 U0RIGONE - - 0 - -\n' "$rigAt" "$rigAt"
done > "$MMDAPP/.local/agents/sessions/rigfresh-0001/last-own-post"
for rigRun in 1 2 3 4 5 ; do rigCall rigfresh-0001 "$(( rigBase + rigRun * 10 ))" ; done
rigAssert "each of the ten posts was looked at" "$( LC_ALL=C sort -u "$rigLog" | LC_ALL=C grep -c . )" 10
echo "-- 5. nothing is lost --"
rigRecord="$MMDAPP/.local/agents/sessions/rigfresh-0001/last-own-post"
rigAssert "the record still holds ten lines" "$( LC_ALL=C grep -c . "$rigRecord" )" 10
rigAssert "each post stands once, in the order it had" "$( LC_ALL=C awk '{ print $1 ; }' "$rigRecord" | LC_ALL=C tr '\n' ' ' )" \
	"$( for rigAt in 10 9 8 7 6 5 4 3 2 1 ; do printf 'CRIG:17000009%02d.000100 ' "$rigAt" ; done )"
rigAssert "every post kept its own timestamp, addressee and floors: only the last field moved" \
	"$( LC_ALL=C awk '{ print $2 " " $3 " " $4 " " $5 " " $6 " " $7 ; }' "$rigRecord" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 10

echo "-- 3. the check due longest goes first --"
: > "$rigLog"
rigCall rigdue-0001 "$rigBase"
rigAssert "the post due longest is looked at first, then the next due, then the one not yet due" \
	"$( LC_ALL=C tr '\n' ' ' < "$rigLog" )" "$(( rigBase - 5000 )).000100 $(( rigBase - 30 )).000100 $(( rigBase - 6000 )).000100 "

echo "-- 4. a record of one post --"
: > "$rigLog"
rigCall rigsolo-0001 "$rigBase" ; rigCall rigsolo-0001 "$(( rigBase + 10 ))"
rigAssert "control: its one post is looked at in each call" "$( LC_ALL=C grep -c -x -F 1700000099.000100 "$rigLog" )" 2

printf 'WAIT_REPLIES_CURSOR: %s (%d assertions, offline, rig tree only)\n' "$( [ "$rigFail" = 0 ] && echo OK || echo FAIL )" "$(( rigPass + rigFail ))"
[ "$rigFail" = 0 ] || exit 1
