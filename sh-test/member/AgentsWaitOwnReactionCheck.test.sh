#!/usr/bin/env bash
## A reaction on a run's own post is no input to handle when the tooling itself put it there (S6.38, the
## human-owner's rule: our own reactions, like a coordinator's message to a non-coordinator, are not input
## to handle; the message itself stays readable, so nothing is dropped from reading). The eyes reaction is
## the tooling's own hand-over mark, given by a Wait or a collect the moment a message is delivered.
##
## Why it matters: a delivered message gets eyes, the eyes is a new reaction on the post, a wait on that
## post sees a changed reaction set and returns it as an arrival, that arrival is handled as input, and
## another message is delivered and marked. Measured on 2026-11-03: 100 marks at 20:05Z, load 102.
##
## Held here:
##   1. AN EYES THAT ONLY THE TOOLING PUT THERE is no arrival: the reaction side of the post holds `-`.
##   2. A PERSON'S REACTION IS STILL AN ARRIVAL: another emoji is returned, as before.
##   3. CONTROL: a reply is still returned, so the read itself is proved to work.
## Offline: one mktemp tree, awk only, nothing of the team's read and no socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigAwk="$rigPkg/sh-lib/member/AgentsWaitOwnPostReplies.awk"
rigDismiss="$rigPkg/sh-lib/questions/AgentsDismissalMatch.awk"
[ -f "$rigAwk" ] || { echo "⛔ ERROR: the replies awk is not at the origin: $rigAwk" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitOwnReactionCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPass=0
rigFail=0
rigHits(){ ## file, pattern -- how many lines match, 0 where the file is not there
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C grep -c -e "$2" "$1" 2> /dev/null
}
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## One rendering of a thread in which the run's own post is the root, and the reactions on it are those named.
rigRender(){ ## reactions annotation (may be empty), then a reply line...
	local rigAnn="$1"
	shift
	printf '%s | URIGSELF |%s ROOT POST\n' "1760000000.000001" "${rigAnn:+ $rigAnn}"
	local rigLine
	for rigLine in "$@" ; do printf '%s\n' "$rigLine" ; done
}
## THE ACCOUNTS THE TOOLING REACTS AS, as live resolves them: the rig holds the same two files the workspace keeps, the send's own
## user-id cache and the mention-id cache, and the include's own function is asked for the list. So the check proves the resolution too.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/cache/comms/slack" "$rigWs/.local/.agents" || exit 1
printf '1793567564 U0BT7PCNG7Q\n' > "$rigWs/.local/cache/comms/slack/.user-id-magic-developer.txt"
printf '113992406 3626\nmagic-coordinator=U0BTTMPPZLG=magic.vane=Magic Vane=dispatchr=meloscope.slack.com\nmagic-tester=-\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigOurs="$( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigPkg/sh-lib/member/AgentsTools.MemberWaitReplies.include' > /dev/null 2>&1 || exit 9 ; AgentsToolsWaitOursReactIds" 2> /dev/null )" || rigOurs=""
rigAssert "the tooling's own accounts are read from the files the workspace keeps" "$( printf '%s\n' "$rigOurs" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "U0BT7PCNG7Q U0BTTMPPZLG "

## One read of that rendering: the side file's reactions, and what the read returned.
rigRead(){ ## rendering file
	LC_ALL=C awk -v threadTs="1760000000.000001" -v addressees="all" -v siblingsMax=1000000 -v postTs="1760000000.000001" \
		-v floorTs="1760000000.000001" -v callerName="magic-developer" -v deliver=1 -v side="$rigTmp/side" \
		-v oursReactIds="$rigOurs" -v callerId="U0BT7RIG01" \
		-f "$rigDismiss" -f "$rigAwk" < "$1" > "$rigTmp/out" 2> "$rigTmp/err" || :
	LC_ALL=C awk '$1 == "reactions" { sub(/^reactions /, "") ; print ; }' "$rigTmp/side" 2> /dev/null
}

echo "-- 1. a reaction by our own account on a root message --"
## The human-owner's test: the AUTHOR is what decides. Any reaction U0BT7PCNG7Q holds on a root message of the
## session is readable, and is no event and no input to a scan or a wait. Its name says nothing: eyes is not the
## test, and a name of ours is not the exception.
rigRender '[reactions: eyes x1 (U0BT7PCNG7Q)]' > "$rigTmp/eyes.txt"
rigAssert "our bot's eyes on the run's post is no arrival"           "$( rigRead "$rigTmp/eyes.txt" )" "-"
rigAssert "and nothing is returned for it"                          "$( rigHits "$rigTmp/out" 'reactions on your post' )" 0
rigRender '[reactions: white_check_mark x1 (U0BT7PCNG7Q)]' > "$rigTmp/check.txt"
rigAssert "nor is any other reaction of our bot"                     "$( rigRead "$rigTmp/check.txt" )" "-"
## Two of ours, a space apart: a rendering that separates them that way is read the same way.
rigRender '[reactions: eyes x2 (U0BT7PCNG7Q U0BTTMPPZLG)]' > "$rigTmp/eyes3.txt"
rigAssert "nor is a set of them, whoever of our accounts gave them" "$( rigRead "$rigTmp/eyes3.txt" )" "-"
## The same set with the run's own account named, as the include gives it: the run's id is ours too.
rigRender '[reactions: eyes x3 (U0BT7PCNG7Q U0BTTMPPZLG U0BT7RIG01)]' > "$rigTmp/eyes-run.txt"
rigAssert "nor is a set that names the run's own account"            "$( rigRead "$rigTmp/eyes-run.txt" )" "-"

echo "-- 2. a person's reaction is still an arrival --"
rigRender '[reactions: thumbsup x1 (URIGHUM1)]' > "$rigTmp/thumb.txt"
rigAssert "a person's reaction is a reaction set the read returns"    "$( rigRead "$rigTmp/thumb.txt" )" "[reactions: thumbsup x1 (URIGHUM1)]"
rigRender '[reactions: eyes x1 (U0BT7PCNG7Q)] [reactions: thumbsup x1 (URIGHUM1)]' > "$rigTmp/mixed.txt"
rigAssert "and our bot's beside it does not hide it"                  "$( rigRead "$rigTmp/mixed.txt" )" "[reactions: thumbsup x1 (URIGHUM1)]"
## THE AUTHOR DECIDES, NOT THE EMOJI (S6.38). A person's eyes on the run's own post is an arrival, as any other reaction of a
## person's is; the bot's eyes is not. Before this the emoji name decided, and a person's eyes came back as silence.
rigRender '[reactions: eyes x1 (URIGHUM1)]' > "$rigTmp/person-eyes.txt"
rigAssert "a person's eyes is an arrival like any other of theirs"    "$( rigRead "$rigTmp/person-eyes.txt" )" "[reactions: eyes x1 (URIGHUM1)]"
## Two of ours hold it, comma-joined as the formatter writes them: the set is ours, and no news.
rigRender '[reactions: white_check_mark x2 (U0BT7PCNG7Q,U0BTTMPPZLG)]' > "$rigTmp/ours-two.txt"
rigAssert "a set held only by two of our accounts, comma-joined, is no arrival" "$( rigRead "$rigTmp/ours-two.txt" )" "-"
## And our bot's eye beside a person's, comma-joined: the person's still comes back, and only the person's.
rigRender '[reactions: eyes x1 (URIGHUM1)] [reactions: eyes x2 (U0BT7PCNG7Q,U0BTTMPPZLG)]' > "$rigTmp/mixed-eyes.txt"
rigAssert "our set beside a person's eyes leaves the person's alone"  "$( rigRead "$rigTmp/mixed-eyes.txt" )" "[reactions: eyes x1 (URIGHUM1)]"

echo "-- 3. control: a reply still comes back --"
rigRender '' '1760000000.000002 | URIGHUM1 | A REPLY' > "$rigTmp/reply.txt"
rigRead "$rigTmp/reply.txt" > /dev/null
rigAssert "a reply after the floor is returned"                      "$( rigHits "$rigTmp/out" 'A REPLY' )" 1
rigAssert "and the read said nothing on its error stream"            "$( [ -s "$rigTmp/err" ] && printf said || printf quiet )" quiet

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ WAIT OWN REACTION CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_OWN_REACTION: OK (%d assertions, offline)\n' "$rigPass"
exit 0
