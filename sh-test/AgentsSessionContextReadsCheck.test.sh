#!/usr/bin/env bash
## What the session-context scan reads, and what it skips (MAGIC.md, "What the scan
## reads, and what it skips"), checked against a fake Slack and a fake imaplib:
##   - a roster widened to channels reads the member channels and no other channel;
##   - --do-slack-tags searches mentions in a member-scope (client-*) scan;
##   - a thread of our own whose stated latest reply is before the cut-off is not
##     read, one with no stated latest reply still is, and sources-scanned stays whole;
##   - past the 128-conversation display cap, threads that could never be shown are
##     not read and the section says `capped`;
##   - email is one IMAP session (one login), searched UNSEEN SINCE the day before
##     the cut-off, fetched with BODY.PEEK[] per rendered UID.
## Every scan runs in a temp tree under one `env -i` guard; nothing real is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/session-context-reads.curl.test.sh" ] || rigRefuse "the fake Slack fixture is missing from the package"
[ -f "$rigPackage/sh-test/check-fixtures/session-context-reads.imaplib.test.py" ] || rigRefuse "the fake imaplib fixture is missing from the package"
rigTmp="$( mktemp -d -t AgentsSessionContextReadsCheck )" || exit 1
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
rigCount(){ ## file, extended regex
	LC_ALL=C grep -c -E -- "$2" "$1" 2>/dev/null || :
}

## 2026-10-07 12:00 UTC; the cut-off is an hour before it.
rigNow=1791374400
rigCut=$(( rigNow - 3600 ))

## One scan of client-fix1 in a fresh tree. name, dms, then scan options.
rigScan(){
	local scanName="$1" scanDms="$2" scanDir="$rigTmp/$1"
	shift 2
	mkdir -p "$scanDir/bin" "$scanDir/py" "$scanDir/ws/.local/.agents" "$scanDir/ws/.local/temp" \
		"$scanDir/ws/.local/agents/members/client-fix1" "$scanDir/data/inboxes/client-fix1" "$scanDir/data/board/running"
	cp "$rigPackage/sh-test/check-fixtures/session-context-reads.curl.test.sh" "$scanDir/bin/curl" && chmod +x "$scanDir/bin/curl"
	cp "$rigPackage/sh-test/check-fixtures/session-context-reads.imaplib.test.py" "$scanDir/py/imaplib.py"
	printf '# fixture\n' > "$scanDir/ws/.local/agents/members/client-fix1/SKILL.md"
	printf 'SLACK_BOT_TOKEN=xoxb-fixture\nSLACK_CHANNEL_MAGIC_TEAM=CFIXTEAM001\nSLACK_CHANNEL_HUMAN_OWNER=UFIXOWNER01\n' > "$scanDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=xoxp-fixture-client1\nSLACK_CONVERSATIONS=CFIXAAAA001\nEMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=rig@rig.invalid\nEMAIL_APP_PASSWORD=rig-app-password\n' \
		> "$scanDir/ws/.local/.agents/client-fix1.agent.env"
	: > "$scanDir/calls.log"
	local scanRc=0
	env -i HOME="$scanDir/home" PATH="$scanDir/bin:/usr/bin:/bin" MMDAPP="$scanDir/ws" MDAT_DATA_ROOT="$scanDir/data" TMPDIR="$scanDir/ws/.local/temp" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" PYTHONPATH="$scanDir/py" PYTHONDONTWRITEBYTECODE=1 \
		FIX_DIR="$scanDir" FIX_LATENCY=0 FIX_DMS="$scanDms" FIX_TS="$rigNow" FIX_CHANNELS="${RIG_CHANNELS:-0}" FIX_NONMEMBER="${RIG_NONMEMBER:-0}" \
		FIX_K6_AGE="${RIG_K6_AGE:-60}" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-session-context-scan client-fix1 "$@"
		' rig --all-types --member-scope-only --comms-since-utime "$rigCut" "$@" > "$scanDir/out" 2> "$scanDir/err" || scanRc=$?
	[ "$scanRc" != 99 ] || rigRefuse "the $scanName scan was not contained in the rig tree"
	printf '%s' "$scanRc" > "$scanDir/rc"
	[ -s "$scanDir/out" ] || rigRefuse "the $scanName scan printed no document: $( tail -3 "$scanDir/err" )"
}
rigLeft(){ ## scan name
	ls -1 "$rigTmp/$1/ws/.local/temp" | LC_ALL=C grep -c '^mdat-' || :
}

echo "-- a channel-wide roster: 3 member channels, 5 it can only see; mentions searched --"
RIG_CHANNELS=3 RIG_NONMEMBER=5 rigScan members 4 --do-slack --do-slack-tags
rigAssert "the scan read every source"                       "$( cat "$rigTmp/members/rc" )" 0
rigAssert "no channel it is not in was read"                 "$( rigCount "$rigTmp/members/calls.log" ' CFIXNON' )" 0
rigAssert "control: each member channel's history was read" "$( rigCount "$rigTmp/members/calls.log" '^user conversations.history CFIXMEM' )" 3
rigAssert "the mention search ran under the member's token"  "$( rigCount "$rigTmp/members/calls.log" '^user search.messages ' )" 1
rigAssert "and is stated in the instrument line"             "$( rigCount "$rigTmp/members/out" '^instrument: .*mentions of <@UFIXSELF> searched' )" 1
rigAssert "the mention hit's thread was read"                "$( rigCount "$rigTmp/members/calls.log" '^user conversations.replies CFIXMENT001 ' )" 1
rigAssert "no mdat-* file is left"                           "$( rigLeft members )" 0

echo "-- threads: stale ones of our own, one with no stated latest reply, fresh ones --"
rigScan threads 20 --do-slack
rigAssert "the scan read every source"                       "$( cat "$rigTmp/threads/rc" )" 0
rigAssert "control: the stale threads' histories were read"  "$( rigCount "$rigTmp/threads/calls.log" '^user conversations.history DFIX00000(0|1)3 ' )" 2
rigAssert "a stale thread we started is not read"            "$( rigCount "$rigTmp/threads/calls.log" '^user conversations.replies DFIX00000(0|1)3 ' )" 0
rigAssert "one tagging us with no stated latest reply is"    "$( rigCount "$rigTmp/threads/calls.log" '^user conversations.replies DFIX00000(0|1)4 ' )" 2
rigAssert "a fresh thread is read"                           "$( rigCount "$rigTmp/threads/calls.log" '^user conversations.replies DFIX00000(0|1)2 ' )" 2
rigAssert "and its new reply is in the document"             "$( rigCount "$rigTmp/threads/out" '^text: reply B DFIX0000002$' )" 1
rigAssert "sources-scanned still counts every source whole"  "$( rigCount "$rigTmp/threads/out" '^sources-scanned: 29 of 29$' )" 1
rigAssert "nothing is capped below the display cap"          "$( rigCount "$rigTmp/threads/out" 'NOTE:\*\* capped' )" 0
rigAssert "no mdat-* file is left"                           "$( rigLeft threads )" 0

echo "-- past the display cap: 160 conversations, 16 threads older than all of them --"
RIG_K6_AGE=3000 rigScan cap 160 --do-slack
rigAssert "the scan read every source it chose to"           "$( cat "$rigTmp/cap/rc" )" 0
rigAssert "the threads the cap excludes are not read"        "$( rigCount "$rigTmp/cap/calls.log" '^user conversations.replies DFIX[0-9]*6 ' )" 0
rigAssert "the section says so, with their number"           "$( rigCount "$rigTmp/cap/out" '^\*\*NOTE:\*\* capped -- 16 thread\(s\) not read' )" 1
rigAssert "the cap still shows 128 conversations"            "$( rigCount "$rigTmp/cap/out" '^conversations: 128 shown of ' )" 1
rigAssert "control: the threads above the cap are read"      "$( rigCount "$rigTmp/cap/calls.log" '^user conversations.replies DFIX[0-9]*2 ' )" 16
rigAssert "no mdat-* file is left"                           "$( rigLeft cap )" 0

echo "-- email: one IMAP session, searched since the day before the cut-off --"
rigScan email 2 --do-email
rigAssert "the scan read its one source"                     "$( cat "$rigTmp/email/rc" )" 0
rigAssert "one connection"                                   "$( rigCount "$rigTmp/email/imap.log" '^CONNECT ' )" 1
rigAssert "one login"                                        "$( rigCount "$rigTmp/email/imap.log" '^LOGIN ' )" 1
rigAssert "the mailbox opened read-only"                     "$( rigCount "$rigTmp/email/imap.log" '^EXAMINE INBOX$' )" 1
rigAssert "unread, since the day before the cut-off"         "$( rigCount "$rigTmp/email/imap.log" '^UID SEARCH UNSEEN SINCE 06-Oct-2026$' )" 1
rigAssert "each found UID fetched without setting Seen"      "$( rigCount "$rigTmp/email/imap.log" '^UID FETCH [0-9]+ \(BODY\.PEEK\[\]\)$' )" 3
rigAssert "the section states the date bound"                "$( rigCount "$rigTmp/email/out" '^cut-off-applied: by date -- IMAP SINCE 06-Oct-2026' )" 1
rigAssert "a fetched message is rendered"                    "$( rigCount "$rigTmp/email/out" '^subject: second rig mail$' )" 1
rigAssert "an older unseen message is outside the search"    "$( rigCount "$rigTmp/email/out" '^## email-message 99$' )" 0
rigAssert "a UID with no message is said, not dropped"       "$( rigCount "$rigTmp/email/out" '^fetch: not read -- the IMAP session returned 4 for this UID' )" 1
rigAssert "no mdat-* file is left"                           "$( rigLeft email )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CONTEXT READS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTEXT_READS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
