#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the TIME a Slack read takes against the SIZE of the body it reads.
## A reader that walks one whole-body string by index is quadratic on BWK awk, because every
## substr() costs the length of the string it is given: 0.39 s on a 100 kB thread, 140 s on
## 2 MB. One live --slack-read burned a core for 32 minutes on a long event-track thread and
## only stopped when a supervisor ended it.
##
## Every comms reader now walks the body through the package's one JSON engine
## (sh-lib/harness/AgentsHarnessJsonField.awk), which holds it as a chunk table and copies
## whole runs, so one body costs one pass.
##
##   1. FIVE READERS, ONE 2 MB BODY, ONE BOUND. Each reader must finish well inside the
##      bound, answer with the status its own contract states for this body, and print what
##      it exists to print. Its previous version took 21 s to over 120 s on this body.
##   2. THE SAME BYTES. Each reader against the version it replaced, kept in
##      check-fixtures/<reader>.legacy.awk: stdout, stderr and status, byte for byte. The
##      speed must come from the walk, never from reading less.
##
## A READER THAT NEVER RAN CANNOT PASS HERE. awk exits 2 at the load when a reader's engine is
## not there, with nothing on stdout, and a section that only asked "did it finish" would pass
## that. So section 1 holds every reader to its own status and its own output.
##
## RED RECIPE, in both directions: `--legacy` loads each reader alone, with no engine, and skips
## section 2. All five then fail, each saying `does not load without its engine: status 2, no
## output, awk calling undefined function jf...`, and the check ends red. A plain run is green.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigHere="$rigOrigin/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigEngine="$rigHere/harness/AgentsHarnessJsonField.awk"
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigBound=20
rigLegacyOnly=""
case "${1:-}" in
	'') rigEngineArgs=( -f "$rigEngine" ) ;;
	--legacy) rigEngineArgs=() ; rigLegacyOnly=1 ;;
	*) echo "⛔ ERROR: $0: the only argument is --legacy, got: $1" >&2 ; exit 1 ;;
esac

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigEngine" ] || rigRefuse "the JSON engine is not at the origin this workspace resolves: $rigEngine"
[ -x "$rigTools" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTools"
for rigName in AgentsSlackMessagesFormat AgentsSlackMessageSelect AgentsSlackHistoryThreadTargets AgentsSlackConversationCounterparty AgentsSlackSearchMatches ; do
	[ -f "$rigHere/comms/$rigName.awk" ] || rigRefuse "a comms reader is missing: $rigHere/comms/$rigName.awk"
	[ -f "$rigTest/check-fixtures/$rigName.legacy.awk" ] || rigRefuse "the kept original of $rigName is missing from check-fixtures"
done
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackJsonReadTimeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/body"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## THE BODY: Slack's own conversations.replies shape, one JSON document on one line, its
## messages carrying the fields these five readers read -- text, a nested block, a
## reaction, a file, metadata, reply counts -- and each message padded towards 2 MB.
LC_ALL=C awk '
	BEGIN {
		body = "" ; n = 0
		while (length(body) < 2000000) {
			text = sprintf("reply %d: a message of ordinary length, padded out so the body reaches the size this check needs. ", n)
			ts = sprintf("17937%05d.%06d", 10000 + n, n * 7 % 1000000)
			body = body (n == 0 ? "" : ",") "{\"type\":\"message\",\"user\":\"U0BODY\",\"text\":\"" text "\",\"ts\":\"" ts "\",\"thread_ts\":\"1793710000.000100\",\"reply_count\":2,\"latest_reply\":\"1793710002.000014\",\"reply_users\":[\"U0BODY\",\"U0OTHER\"],\"reactions\":[{\"name\":\"thumbsup\",\"users\":[\"U0OTHER\"],\"count\":1}],\"blocks\":[{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_section\",\"elements\":[{\"type\":\"text\",\"text\":\"" text "\"}]}]}],\"files\":[{\"id\":\"F0BODY\",\"name\":\"a report.pdf\",\"size\":1234,\"mimetype\":\"application/pdf\"}],\"metadata\":{\"event_type\":\"t\",\"event_payload\":{\"sender\":\"U0SENDER\",\"tracking\":\"event\",\"session\":\"s-1\"}}}"
			n++
		}
		printf "{\"ok\":true,\"messages\":[%s],\"has_more\":false}\n", body
	}' > "$rigTmp/body/replies.json" || rigRefuse "the 2 MB body could not be built"
rigSize="$( LC_ALL=C wc -c < "$rigTmp/body/replies.json" | LC_ALL=C tr -d ' ' )"
[ "$rigSize" -ge 2000000 ] || rigRefuse "the body came out at $rigSize bytes, not the 2 MB this check needs"
rigLastTs="$( LC_ALL=C awk -v mode=records -v array=messages -v want=ts -v dialect=slack -f "$rigEngine" < "$rigTmp/body/replies.json" | LC_ALL=C tail -1 )"
[ -n "$rigLastTs" ] || rigRefuse "the body's own ts list came back empty, so nothing below would be measuring a read"
rigBody="$rigTmp/body/replies.json"

## One reader under a wall-clock bound, into the given output stem. Prints
## `<seconds> <status>`, or BOUND-HIT where it was ended at the bound.
rigTimed(){ ## output stem, -f/-v arguments...
	local timedStem="$1" timedPid timedStart timedLeft timedRc=0
	shift
	timedStart="$( date +%s )"
	LC_ALL=C awk "$@" < "$rigBody" > "$timedStem.out" 2> "$timedStem.err" &
	timedPid=$!
	timedLeft=$rigBound
	while kill -0 "$timedPid" 2> /dev/null && [ "$timedLeft" -gt 0 ] ; do
		sleep 1 ; timedLeft=$(( timedLeft - 1 ))
	done
	if kill -0 "$timedPid" 2> /dev/null ; then
		kill -9 "$timedPid" 2> /dev/null ; wait "$timedPid" 2> /dev/null
		printf 'BOUND-HIT' ; return 0
	fi
	wait "$timedPid" || timedRc=$?
	printf '%s %s' "$(( $( date +%s ) - timedStart ))" "$timedRc"
}

## THE STATUS AND THE OUTPUT ARE BOTH ASSERTED. A reader whose engine is not loaded exits 2
## from awk with nothing on stdout; a section asking only "did it finish" passes it. So each
## reader is held to the status its contract states for this body, and to the line it exists
## to print -- or to its empty stdout, where that is its answer.
rigReaderTable(){
	printf '%s\n' \
		'AgentsSlackMessagesFormat|-v msgBound=1|0|\| U0BODY \|' \
		"AgentsSlackMessageSelect|-v wantTs=$rigLastTs|0|\\\"ts\\\":\\\"$rigLastTs\\\"" \
		'AgentsSlackHistoryThreadTargets|-v latest=1|0|^:1793710000\.000000 ' \
		'AgentsSlackConversationCounterparty|-v channelBound=1|0|none' \
		'AgentsSlackSearchMatches|-v cutoff=1|3|none'
}
rigReaderTable > "$rigTmp/readers"
while IFS='|' read -r rigName rigArgs rigWantRc rigWantOut ; do
	[ -n "$rigName" ] || continue
	rigGot="$( rigTimed "$rigTmp/time" ${rigEngineArgs[@]+"${rigEngineArgs[@]}"} -f "$rigHere/comms/$rigName.awk" $rigArgs )"
	if [ "$rigGot" = "BOUND-HIT" ] ; then
		rigAssert "$rigName finishes inside ${rigBound}s" "still running at ${rigBound}s" "finished inside the bound"
		continue
	fi
	rigRc="${rigGot#* }"
	## A READER THAT NEVER RAN MUST FAIL, in either mode, and must not collect a pass from
	## anything else here: awk exits 2 at the load when the engine is not there.
	if [ "$rigRc" = "2" ] ; then
		rigAssert "$rigName loaded and ran" "did not load: $( LC_ALL=C head -1 "$rigTmp/time.err" 2> /dev/null )" "loaded"
		continue
	fi
	rigAssert "$rigName loaded and ran" "loaded" "loaded"
	rigAssert "$rigName finished inside ${rigBound}s" "$( [ "$rigGot" = BOUND-HIT ] && printf no || printf yes )" "yes"
	rigAssert "$rigName answers with the status its contract states" "${rigRc}" "${rigWantRc}"
	if [ "$rigWantOut" = "none" ] ; then
		rigAssert "$rigName prints nothing, which is its answer for this body" \
			"$( LC_ALL=C wc -c < "$rigTmp/time.out" 2> /dev/null | LC_ALL=C tr -d ' ' )" "0"
	else
		rigAssert "$rigName prints the line it exists to print" \
			"$( [ "$( LC_ALL=C grep -c -E -- "$rigWantOut" "$rigTmp/time.out" 2> /dev/null || : )" -gt 0 ] && printf printed || printf nothing )" "printed"
	fi
done < "$rigTmp/readers"

echo "-- 2. the same bytes the reader it replaced printed --"
if [ -n "$rigLegacyOnly" ] ; then
	echo "  SKIP  --legacy: the readers under test ARE the originals, so there is nothing to compare"
else
## A SMALL body for this section, on purpose: the kept originals are quadratic, so running
## one of them over the 2 MB body of section 1 would hold this check for minutes. What is
## compared here is the rendering, not the speed, and the small body carries every field
## the five readers read.
printf '%s\n' '{"ok":true,"messages":[{"type":"message","user":"U0AAA","text":"first line\nsecond line with a token <!date^1793710000^{date_short}|3 Nov 2026> and a mention <@U0BBB>","ts":"1793710000.000100","thread_ts":"1793710000.000100","reply_count":2,"latest_reply":"1793710002.000014","reply_users":["U0AAA","U0BBB"],"reactions":[{"name":"thumbsup","users":["U0BBB"],"count":1}],"blocks":[{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"block text one"}]}]}],"files":[{"id":"F0AAA","name":"a report.pdf","size":1234,"mimetype":"application/pdf"}],"metadata":{"event_type":"t","event_payload":{"sender":"U0CCC","author_run":"run-1","addressee_run":"run-2","tracking":"event","session":"s-1"}}},{"type":"message","user":"U0BBB","bot_id":"B0BBB","text":"3.14159 | not a head\nbut 1793710001.000200 | shaped like one","ts":"1793710001.000200","thread_ts":"1793710000.000100"}]}' > "$rigTmp/body/small.json"
printf '%s\n' '{"ok":true,"channel":{"id":"D0AAA","is_im":true,"user":"U0PARTY","latest":{"user":"U0LAST","bot_profile":{"user_id":"U0BOT"}}}}' > "$rigTmp/body/small-info.json"
printf '%s\n' '{"ok":true,"query":"q","messages":{"total":1,"paging":{"page":1,"pages":1,"count":1},"matches":[{"ts":"1793710000.000100","text":"a match","permalink":"https://t.slack.com/archives/C0AAA/p1793710000000100?thread_ts=1793700000.000001&cid=C0AAA","user":"U0AAA"}]}}' > "$rigTmp/body/small-search.json"
for rigLine in \
	"AgentsSlackMessagesFormat:$rigTmp/body/small.json:" \
	"AgentsSlackMessageSelect:$rigTmp/body/small.json:-v wantTs=1793710001.000200" \
	"AgentsSlackHistoryThreadTargets:$rigTmp/body/small.json:-v latest=1" \
	"AgentsSlackConversationCounterparty:$rigTmp/body/small-info.json:" \
	"AgentsSlackSearchMatches:$rigTmp/body/small-search.json:-v cutoff=0" ; do
	rigName="${rigLine%%:*}" rigRest="${rigLine#*:}"
	rigBody="${rigRest%%:*}" rigArgs="${rigRest#*:}"
	rigOldRc=0 ; rigNewRc=0
	LC_ALL=C awk $rigArgs -f "$rigTest/check-fixtures/$rigName.legacy.awk" < "$rigBody" > "$rigTmp/old.out" 2> "$rigTmp/old.err" || rigOldRc=$?
	LC_ALL=C awk $rigArgs -f "$rigEngine" -f "$rigHere/comms/$rigName.awk" < "$rigBody" > "$rigTmp/new.out" 2> "$rigTmp/new.err" || rigNewRc=$?
	rigAssert "$rigName: stdout as before" \
		"$( LC_ALL=C cksum < "$rigTmp/new.out" | LC_ALL=C awk '{ print $1 "-" $2 }' )" \
		"$( LC_ALL=C cksum < "$rigTmp/old.out" | LC_ALL=C awk '{ print $1 "-" $2 }' )"
	rigAssert "$rigName: stderr and status as before" \
		"$( LC_ALL=C cksum < "$rigTmp/new.err" | LC_ALL=C awk '{ print $1 "-" $2 }' )/$rigNewRc" \
		"$( LC_ALL=C cksum < "$rigTmp/old.err" | LC_ALL=C awk '{ print $1 "-" $2 }' )/$rigOldRc"
done
fi


echo "-- 3. one message is asked for as one message --"
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigTmp/skills/keeper-rig" "$rigTmp/scn"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGMEM01=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
## A Slack-shaped fake curl: it records each call's method and its --form fields, and answers
## conversations.replies with the one message its `oldest` names.
## Each form field reaches curl as `--data-urlencode <name>@<file>`, its value inside that
## file, so the file is read here exactly as Slack would receive it.
rigMethod="" rigForms=""
for rigArg in "$@" ; do
	case "$rigArg" in
		--data-urlencode)
			rigReadNext=1 ; continue
		;;
	esac
	if [ -n "${rigReadNext:-}" ] ; then
		rigReadNext=""
		rigForms="$rigForms $( printf '%s=%s' "${rigArg%%@*}" "$( LC_ALL=C cat "${rigArg#*@}" 2> /dev/null )" )"
		continue
	fi
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s%s\n' "$rigMethod" "$rigForms" >> "$RIG_SCN/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false}}\n' ;;
	conversations.replies)
		rigWant=""
		for rigField in $rigForms ; do case "$rigField" in oldest=*) rigWant="${rigField#oldest=}" ;; esac ; done
		printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGOTHER","text":"RIG-ONE-MESSAGE","thread_ts":"%s"}],"has_more":false}\n' "$rigWant" "$rigWant"
	;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
	"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
	"MDAT_DATA_ROOT=$rigTmp/scn/data" "RIG_SCN=$rigTmp/scn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_SESSION_ID=rig-session" \
	"MDAT_SLACK_THREAD_CACHE_SECONDS=0" "MDAT_COMMS_READER=off" \
	bash "$rigTools" --slack-read --team-member keeper-rig CRIG00001:1793715757.435389 ) > "$rigTmp/read.out" 2> "$rigTmp/read.err" || :
rigFormAsk="$( LC_ALL=C grep '^conversations.replies ' "$rigTmp/scn/calls" 2> /dev/null | LC_ALL=C tail -1 )"
rigAssert "the one-message read asks with oldest, inclusive and limit=1" \
	"$( printf '%s' "$rigFormAsk" | LC_ALL=C grep -c -e 'oldest=1793715757.435389' -e 'inclusive=true' -e 'limit=1' )" "1"
rigAssert "the read returns the one message, as raw JSON" \
	"$( LC_ALL=C grep -c '"ts":"1793715757.435389"' "$rigTmp/read.out" 2> /dev/null )" "1"

echo "-- 4. a read past its bound ends itself, and one whose caller has gone ends itself --"
## BOTH DIRECTIONS, each a process of its own with its own stderr, and every process this
## section starts is ended before it returns: the machine has no room for a leftover.
cat > "$rigTmp/helperProbe.sh" <<'PROBE'
#!/usr/bin/env bash
## $1 origin root, $2 `bound` or `orphan`, $3 output file, $4 error file, $5 bound seconds
## The helper's own failure line goes to THIS shell's stderr, which the caller of this probe
## keeps, so the probe's own stderr file is that line's file.
MDSC_CMD=probe MMDAPP="$RIG_WS"
. "$1/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsSlack.include" || { echo "rc=missing" > "$3.rc" ; exit 1 ; }
MDAT_SLACK_READ_BOUND_SECONDS="$5" AgentsToolsSlackReadBounded "$3" "$4" "$RIG_SLEEP"
echo "rc=$?" > "$3.rc"
PROBE
chmod +x "$rigTmp/helperProbe.sh"
rigSleep="$( mktemp "$MMDAPP/.local/temp/agents-read-probe.XXXXXX" 2> /dev/null )" || rigSleep=""
printf '#!/bin/sh\n# A stand-in for a read of this check alone: it writes one line to stderr, then waits.\necho probe-stderr >&2\nexec sleep 600\n' > "$rigSleep"
chmod +x "$rigSleep"
## The bound: five seconds, so the read is ended at it.
RIG_WS="$rigTmp" RIG_SLEEP="$rigSleep" bash "$rigTmp/helperProbe.sh" "$rigOrigin" bound "$rigTmp/bound.out" "$rigTmp/bound.err" 5 > /dev/null 2> "$rigTmp/bound.said" || :
rigAssert "a read past its bound is ended and says so" \
	"$( LC_ALL=C cat "$rigTmp/bound.out.rc" 2> /dev/null )/$( LC_ALL=C grep -c 'ended at its bound' "$rigTmp/bound.said" 2> /dev/null )" "rc=1/1"
pkill -f "$rigSleep" 2> /dev/null || :
## The caller gone: the probe is started by a shell that leaves at once.
RIG_WS="$rigTmp" RIG_SLEEP="$rigSleep" bash -c 'bash "$1" "$2" orphan "$3" "$4" 600 > /dev/null 2> "$5" & exit 0' _ "$rigTmp/helperProbe.sh" "$rigOrigin" "$rigTmp/orphan.out" "$rigTmp/orphan.err" "$rigTmp/orphan.said" || :
sleep 6
rigAssert "a read whose caller has gone is ended, not left running" \
	"$( LC_ALL=C cat "$rigTmp/orphan.out.rc" 2> /dev/null )/$( LC_ALL=C grep -c 'asked for it has gone' "$rigTmp/orphan.said" 2> /dev/null )" "rc=1/1"
pkill -f "$rigSleep" 2> /dev/null || :
rigAssert "no read of this section is left running" \
	"$( ps -ax -o command 2> /dev/null | LC_ALL=C grep -F "$rigSleep" | LC_ALL=C grep -v -c 'grep' || : )" "0"
rm -f "$rigSleep" 2> /dev/null || :

echo "-- 5. the read's own error text is written once, never into the file it is collected by --"
## THE DEFECT THIS GUARDS, measured: a caller whose stderr IS the file the read is collected
## into. `cat` of that file onto itself doubles it on every pass -- 11 bytes became 174 MB in
## under a minute. A shell's own stderr is a file here, and its size is read between passes so
## this check can never grow without bound.
printf '#!/bin/sh\necho one-line-to-stderr >&2\n' > "$rigTmp/say.sh"
chmod +x "$rigTmp/say.sh"
cat > "$rigTmp/sameProbe.sh" <<'PROBE'
#!/usr/bin/env bash
## Its stderr IS the very file the read is collected into: the shape that grew without end.
MDSC_CMD=probe
. "$1/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsSlack.include" || exit 1
AgentsToolsSlackReadBounded "$2" "$2" "$3"
PROBE
chmod +x "$rigTmp/sameProbe.sh"
bash "$rigTmp/sameProbe.sh" "$rigOrigin" "$rigTmp/same.out" "$rigTmp/say.sh" > /dev/null 2>> "$rigTmp/same.out" || :
rigAssert "the read's error text is one line, and its file did not grow" \
	"$( LC_ALL=C wc -l < "$rigTmp/same.out" 2> /dev/null | LC_ALL=C tr -d ' ' ):$( LC_ALL=C wc -c < "$rigTmp/same.out" 2> /dev/null | LC_ALL=C tr -d ' ' )" "1:19"

printf '\n%s of %s checks passed\n' "$rigPassCount" "$(( rigPassCount + rigFailCount ))"
[ "$rigFailCount" = 0 ] || exit 1
exit 0
