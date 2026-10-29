#!/usr/bin/env bash
## Behavioural check on the short and the full form of a source the caller adds (F3.3's Settled paragraph): short or full is chosen when
## the source is added, written after it, `slack:<conversation>#short` or `#full`. SHORT returns each message cut to a short form, with
## the line that reads it in full with the operation the agent has, and keeps only that short form: a large message is copied nowhere.
## FULL keeps each message whole in a file of its own in the session's folder and returns a preview with a reference; a long return
## follows F2.4 as every result does. Either way the source's index cache file keeps a line for each message once. Held, run and not read:
##   1. A source with neither form is returned whole, as it always was, and nothing is kept.
##   2. #short: the short message whole, the long one cut with the read line naming the source and the message; no message file; the
##      index cache file holds the short forms; the sources line names the source without the form.
##   3. #full: every message whole in the return, and no file for it; only a single message over F2.4's threshold (8 KB) is kept as a file of
##      its own, previewed and referenced in the return and in the index line; the file holds it whole, the return does not.
##   4. The form goes with the source: it is stored with a stateful wait, and --wait-continue serves the next message in it; --wait-add
##      stores one, --wait-drop takes it away.
##   5. What is refused: a form on a source that is not a Slack source, and a form that is neither short, full nor ttl=<seconds>. A call with no session
##      folder to keep messages in returns them whole, and says so.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHere/member/AgentsWaitSourceMode.awk" ] || rigRefuse "the form awk is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitSourceModeCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigWaitPath="$rigTmp/bin:$PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigNow="$( date +%s )"
rigDir="" rigSession="" rigOut="" rigKey=""
rigScene(){ ## scenario name
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/sessions/$rigSession" "$rigDir/data/inboxes/$rigMember/incoming" "$rigDir/data/board/pending"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
	rigKey="$rigSession"
	rigHistory
}
rigLong="$( LC_ALL=C awk 'BEGIN { printf "RIG-X-LONG-START " ; for ( n = 1 ; n <= 1500 ; n++ ) printf "word%04d ", n ; printf "RIG-X-LONG-END" }' )"
rigHistory(){ ## the conversation: a short message and a long one, then optionally a third
	printf '{"ok":true,"messages":[{"ts":"%s.000001","user":"URIGOTHER","text":"RIG-X-SMALL a short one"},{"ts":"%s.000001","user":"URIGOTHER","text":"%s"}%s],"has_more":false}\n' \
		"$(( rigNow - 90 ))" "$(( rigNow - 80 ))" "$rigLong" "${1:-}" > "$rigDir/history.CRIGXXX01.json"
}
rigWait(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigDir/$waitName.out"
	env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_WAIT_POLL_SECONDS -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		"PATH=$rigWaitPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" "MDAT_SKILLSET_ROOT=$rigTmp/skills" ${rigKey:+MDAT_SESSION_ID=$rigKey} \
		MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		"$rigTool" --wait-for-input "$rigMember" "$@" > "$rigOut" 2> "$rigDir/$waitName.err" &
	waitPid=$!
	( waitLeft=60 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2>/dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigDir/$waitName.err" ; kill -TERM "$waitPid" 2>/dev/null ; sleep 2 ; kill -KILL "$waitPid" 2>/dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
rigSessionDir(){ printf '%s' "$rigDir/ws/.local/agents/sessions/$rigSession" ; }
rigHolds(){ ## text
	[ -f "$rigOut" ] || { printf 'no-such-output' ; return 0 ; }
	case "$( cat "$rigOut" )" in *"$1"*) printf yes ;; *) printf no ;; esac
}
rigFirst(){ LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigOut" ; }
rigSource(){ ## form -- the source as written
	printf 'slack:CRIGXXX01%s' "${1:+#$1}"
}
rigIndexFile(){ printf '%s/sources/slack_CRIGXXX01.md' "$( rigSessionDir )" ; }
rigKept(){ printf '%s/messages/slack_CRIGXXX01' "$( rigSessionDir )" ; }
rigFiles(){ ## folder -- how many files it holds, 0 for none
	[ -d "$1" ] && ls -1 "$1" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' || printf 0
}

echo "-- 1. neither form: whole, as it was --"
rigScene plain
rigWait plain-1 --wait-source "$( rigSource )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "RECEIVED, the long message whole to its last word"      "$( rigFirst ):$( rigHolds RIG-X-LONG-END )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "nothing is kept: no message folder, no index"           "$( rigFiles "$( rigKept )" ):$( [ -f "$( rigIndexFile )" ] && printf index || printf none )" "0:none"

echo "-- 2. short --"
rigScene short
rigWait short-1 --wait-source "$( rigSource short )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "RECEIVED"                                               "$( rigFirst )" "WAIT-RESULT: RECEIVED"
rigAssert "the short message whole"                                "$( rigHolds 'RIG-X-SMALL a short one' )" yes
rigAssert "the long one cut: its first words, not its last"        "$( rigHolds RIG-X-LONG-START ):$( rigHolds RIG-X-LONG-END )" "yes:no"
rigAssert "the cut message shows its own reference, source and ts"       "$( LC_ALL=C grep -c -E "RIG-X-LONG-START .*\\([0-9]+ bytes; CRIGXXX01:$(( rigNow - 80 )).000001\\)$" "$rigOut" )" 1
rigAssert "the line that reads one in full stands once in the return, naming the operation" "$( LC_ALL=C grep -c -F -- "--slack-read" "$rigOut" ):$( LC_ALL=C grep -c -F -- "# short forms: read one in full with --slack-read $rigMember <source>:<ts> --thread" "$rigOut" )" "1:1"
rigAssert "the sources line names the source, without the form"    "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigOut" )" "slack:CRIGXXX01"
rigAssert "no message is kept"                                     "$( rigFiles "$( rigKept )" )" 0
rigAssert "the index cache file keeps the short forms, a line each" "$( LC_ALL=C grep -c -E '^[0-9]+\.[0-9]+ \| URIGOTHER \| (RIG-X-SMALL a short one|RIG-X-LONG-START )' "$( rigIndexFile )" ):$( LC_ALL=C grep -c 'RIG-X-LONG-END' "$( rigIndexFile )" || : )" "2:0"

echo "-- 3. full --"
rigScene full
rigMid="$( LC_ALL=C awk 'BEGIN { printf "RIG-X-MID-START " ; for ( n = 1 ; n <= 500 ; n++ ) printf "mid%04d ", n ; printf "RIG-X-MID-END" }' )"
rigHistory ",{\"ts\":\"$(( rigNow - 70 )).000001\",\"user\":\"URIGOTHER\",\"text\":\"$rigMid\"}"
rigWait full-1 --wait-source "$( rigSource full )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "RECEIVED, the short message whole"                      "$( rigFirst ):$( rigHolds 'RIG-X-SMALL a short one' )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "a message of about 4 KB, over the 2 KB preview and under the threshold, whole to its last word" "$( rigHolds RIG-X-MID-END )" yes
rigAssert "the long message, over the threshold, is a preview: its start, not its end" "$( rigHolds RIG-X-LONG-START ):$( rigHolds RIG-X-LONG-END )" "yes:no"
rigAssert "only that one is a file of its own"                     "$( rigFiles "$( rigKept )" )" 1
rigAssert "the file is the long message, whole"                    "$( LC_ALL=C grep -c 'RIG-X-LONG-END' "$( rigKept )/$(( rigNow - 80 )).000001.md" )" 1
rigAssert "the return names that file, its size and its lines, once" "$( LC_ALL=C grep -c -E "^  \[kept: $( rigKept )/[0-9.]+\.md, [0-9]+ bytes, [0-9]+ lines" "$rigOut" )" 1
rigAssert "the return is the F2.4 preview and the rest whole: well under the long result"  "$( LC_ALL=C wc -c < "$rigOut" | LC_ALL=C tr -d ' ' | LC_ALL=C awk '{ print ( $1 < 12000 ) ? "short" : "long:" $1 }' )" short
rigAssert "the index cache file holds each message once, the kept one with its file" "$( LC_ALL=C wc -l < "$( rigIndexFile )" | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c -F -- " -> $( rigKept )/" "$( rigIndexFile )" )" "3:1"
rigWait full-2 --wait-source "$( rigSource full )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "served again, the index stays at one line a message, one file"  "$( LC_ALL=C wc -l < "$( rigIndexFile )" | LC_ALL=C tr -d ' ' ):$( rigFiles "$( rigKept )" )" "3:1"

echo "-- 4. the form goes with the source --"
rigScene stored
rigWait stored-1 --wait-default --wait-session-id "$rigSession" --wait-source "$( rigSource short )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "stored with the stateful wait"                          "$( LC_ALL=C grep -c -x -F 'mode slack:CRIGXXX01 short' "$( rigSessionDir )/wait/state" )" 1
rigHistory ",{\"ts\":\"$(( rigNow - 10 )).000001\",\"user\":\"URIGOTHER\",\"text\":\"RIG-X-NEWEST $rigLong\"}"
rigWait stored-2 --wait-continue --wait-session-id "$rigSession" --wait-timeout 4
rigAssert "continue serves the next message in the same form: cut" "$( rigHolds RIG-X-NEWEST ):$( rigHolds RIG-X-LONG-END ):$( LC_ALL=C grep -c -F -- '--slack-read' "$rigOut" )" "yes:no:1"
rigWait stored-3 --wait-add --wait-session-id "$rigSession" --wait-source "file:$rigDir/none#full"
rigAssert "a form on a file source is refused, and the stored wait is as it was" "$( rigFirst ):$( LC_ALL=C grep -c -x -F 'mode slack:CRIGXXX01 short' "$( rigSessionDir )/wait/state" )" "WAIT-RESULT: ERROR:1"
rigWait stored-4 --wait-add --wait-session-id "$rigSession" --wait-source "slack:CRIGYYY01#full"
rigAssert "--wait-add stores the form of the source it adds"       "$( rigFirst ):$( LC_ALL=C grep -c -x -F 'mode slack:CRIGYYY01 full' "$( rigSessionDir )/wait/state" )" "WAIT-RESULT: ADDED:1"
rigWait stored-5 --wait-drop --wait-session-id "$rigSession" --wait-source "slack:CRIGYYY01"
rigAssert "--wait-drop takes it away with the source"              "$( rigFirst ):$( LC_ALL=C grep -c 'CRIGYYY01' "$( rigSessionDir )/wait/state" || : ):$( LC_ALL=C grep -c -x -F 'mode slack:CRIGXXX01 short' "$( rigSessionDir )/wait/state" )" "WAIT-RESULT: DROPPED:0:1"

echo "-- 5. what is refused, and no folder --"
rigScene refuse
rigWait refuse-1 --wait-source "file:$rigDir/none#short" --wait-timeout 0
rigAssert "a form on a source that is no Slack source"             "$( rigFirst ):$( LC_ALL=C grep -c 'only a Slack source takes a short or a full form' "$rigDir/refuse-1.err" )" "WAIT-RESULT: ERROR:1"
rigWait refuse-2 --wait-source "slack:CRIGXXX01#huge" --wait-timeout 0
rigAssert "a form that is neither short, full nor ttl=<seconds>" "$( rigFirst ):$( LC_ALL=C grep -c 'is short, full or ttl=<seconds>, and nothing else' "$rigDir/refuse-2.err" )" "WAIT-RESULT: ERROR:1"
rigScene nofolder
rigKey=""
rigWait nofolder-1 --wait-source "$( rigSource full )" --wait-since-utime "$(( rigNow - 120 ))" --wait-timeout 4
rigAssert "full with no session folder: the messages whole, and said so" "$( rigFirst ):$( rigHolds RIG-X-LONG-END ):$( LC_ALL=C grep -c 'has no session folder to keep the messages in' "$rigDir/nofolder-1.err" )" "WAIT-RESULT: RECEIVED:yes:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SOURCE MODE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SOURCE_MODE: OK (%d assertions, offline)\n' "$rigPassCount"
