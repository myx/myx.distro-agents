#!/usr/bin/env bash
## Behavioural check on the comms reader's queue report and its restart rate (task-20261120T1710Z-comms-reader-drops-queued-posts).
## Held:
##   1. A QUEUED BLOCK SLACK REFUSES IS REPORTED TO ITS SENDER. A post queued for the reader (MDAT_SEND_ASYNC, the SendMessage tool's
##      path) and then refused by Slack gets `refused` on its block's own stamp line, AND one block reaches the sending session's chat
##      file addressed to the member that sent it, naming that block and saying it was not posted. Today the mark is written and the
##      sender is never told.
##   2. TWO STARTS OF THE READER WITHIN ONE MINUTE START ONE PROCESS. A start meets a lock whose note names a process that is gone -- the
##      shape the live log holds thousands of (`took over the lock of pid N, which is gone or is another process now`) -- and starts a
##      reader. A second start inside that same minute, meeting a lock whose note is again none of the reader's, answers that a start
##      was made recently and starts nothing. Today each such start makes another process.
##   3. A PULL OF A DIRECT CONVERSATION THE USER IDENTITY CANNOT REACH RESOLVES, AND THE SOURCE STAYS ONE FOLDER. A `slack-conversation`
##      pull of a `D`-prefixed direct conversation whose cached recipe names `false` reads it, serves its messages, and the bot identity
##      answers the read the user's was refused for. The recipe keeps its `false`, and the folder stays the one the ingest pass lists: a
##      recipe turned `true` resolves the ingest to another folder, and the source is read once and never again. Today nothing is served.
## Each arm carries its control, shown to answer either way on the same run: no block addressed to the sender before the refusal, a
## first start that does make one process, and a pull shown to reach its conversation at all.
## Offline: a Slack-shaped fake curl first on PATH, every workspace a folder of this rig's own, no model CLI started, and every process
## this check starts is ended by it, through the rig's process helper and the fixture that ends comms threads.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin: $rigTool"
[ -f "$rigHere/session/AgentsTools.SessionComms.include" ] || rigRefuse "the comms reader is not at the origin: $rigHere/session/AgentsTools.SessionComms.include"
[ -f "$rigHere/comms/AgentsTools.CommsCache.include" ] || rigRefuse "the comms cache is not at the origin: $rigHere/comms/AgentsTools.CommsCache.include"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
## And every thread a scene of this rig starts, by its log or its lock, ended before the rig goes.
. "$rigFixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends threads is missing"
rigTmp="$( rigTempDir AgentsSessionCommsQueueReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/bin" "$rigTmp/bin-fast" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/bin-fast/sleep"
chmod +x "$rigTmp/bin-fast/sleep"
rigPath="$rigTmp/bin:$PATH"
[ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH, so this check would issue real requests"

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
rigDir="" rigSession="" rigSessDir="" rigThread="" rigRoot="" rigChat="" rigRc=0 rigStandPid=""
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigScene(){ ## scenario name -- a workspace with one live session: its folder, thread, record, launch marker and settings
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-qr-$1"
	rm -rf "$rigDir"
	rigSessDir="$rigDir/ws/.local/agents/sessions/$rigSession"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/comms" \
		"$rigDir/ws/.local/agents/spawned/trk" "$rigDir/data" "$rigSessDir/control"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/keeper-rig.agent.env"
	## The root of a session's own thread is the tooling's own post, not a person's message: a person's root would make every send into
	## the thread a reply to that person, and the send's contact gate would refuse it before anything was queued.
	rigRoot="$(( rigNow - 400 )).000001"
	rigThread="CRIGSES01:$rigRoot"
	printf '%s\n' "$rigThread" > "$rigSessDir/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: rig\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-11-05 09:00 +0200\n---\n\n# Spawn session: %s\n' "$rigSession" "$rigSession" "$rigSession" > "$rigDir/ws/.local/agents/spawned/trk/$rigSession.spawn.md"
	: > "$rigSessDir/launch"
	touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigSessDir/launch"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","bot_id":"BRIGTEAM01","text":"RIG-ROOT","thread_ts":"%s"}],"has_more":false}\n' "$rigRoot" "$rigRoot" > "$rigDir/replies.CRIGSES01.$rigRoot.json"
	: > "$rigDir/api.log"
	: > "$rigDir/posts"
	rigChat="$rigSessDir/session.chat"
	## The control thread of the scene's session lives: a stand-in process, named in the pid file the reader watches.
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	rigProcBegan "$rigStandPid" > "$rigSessDir/control/pid"
}
## The reader of the scene is live, as a symlink lock naming the stand-in states: the SendMessage tool queues the post.
rigCommsLock(){ ln -sf "$rigStandPid rig" "$rigDir/ws/.local/agents/comms/lock" ; }
## One send of keeper-rig into the session thread, queued for the reader as the SendMessage tool queues it.
rigSendQueued(){ ## body
	printf '%s' "$1" | ( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_THREAD -u CLAUDE_CODE_SESSION_ID -u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT \
		"PATH=$rigTmp/bin-fast:$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_SESSION_ID=$rigSession" "MDAT_SEND_ASYNC=true" bash "$rigTool" --slack-send-message --team-member keeper-rig "$rigThread" --from-stdin ) > "$rigDir/send.out" 2> "$rigDir/send.err"
	rigRc=$?
}
## One push of every channel's cache outbox, as the reader makes it.
rigPush(){ ## output basename
	( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash -c ". \"$rigHere/session/AgentsTools.SessionComms.include\" || exit 9 ; . \"$rigHere/comms/AgentsTools.CommsCache.include\" || exit 9 ; AgentsToolsCommsCachePushAll \"\$( date +%s )\"" ) > "$rigDir/$1.out" 2> "$rigDir/$1.err"
	rigRc=$?
}
rigBlocks(){ ## how many blocks the chat file holds
	[ -f "$rigChat" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$rigChat"
}
rigCalls(){ ## method -- how many calls of it the log holds
	LC_ALL=C awk -v want="$1" '$2 == want { count++ ; } END { print count + 0 ; }' "$rigDir/api.log"
}
## What a reader of the chat file sees for one block: the index line with the stamp laid over it, third field the conversation.
rigResolved(){ ## block number -- `<ts> <conversation>` as the index resolves it
	[ -f "$rigChat.index" ] || { printf 'no-index' ; return 0 ; }
	MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". \"$rigHere/session/AgentsTools.SessionChat.include\" || exit 9 ; AgentsToolsSessionChatResolve \"$rigChat.index\" \"$rigChat.stamps\"" 2> /dev/null \
		| LC_ALL=C awk -v want="$1" -F'\t' '$1 == want { print $2 " " $3 }'
}
## What the chat file says to one member about one block: `<blocks addressed to it> <of those that name the block and say it was not
## posted>`. A member is addressed when its name is one of the header's addressees, exactly.
rigReportedTo(){ ## member, block number
	[ -f "$rigChat" ] || { printf '0 0' ; return 0 ; }
	LC_ALL=C awk -v who="$1" -v no="$2" '
		function failed(text) {
			return ( text ~ /refused/ || text ~ /not posted/ || text ~ /could not be posted/ || text ~ /did not post/ || text ~ /failed/ ) ? 1 : 0
		}
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ {
			if ( held && failed(body) && ( body ~ ("(^|[^0-9])" no "([^0-9]|$)") ) ) { said++ }
			head = $0 ; sub(/^[^ ]* /, "", head) ; sub(/:$/, "", head)
			to = head ; sub(/^.* -> /, "", to)
			held = ( index("," to ",", "," who ",") > 0 ) ? 1 : 0
			body = ""
			if ( held ) { seen++ }
			next
		}
		held { body = body "\n" $0 }
		END {
			if ( held && failed(body) && ( body ~ ("(^|[^0-9])" no "([^0-9]|$)") ) ) { said++ }
			printf "%d %d", seen + 0, said + 0
		}' "$rigChat"
}

echo "-- 1. a queued block Slack refuses is reported to its sender --"
rigScene queue
rigCommsLock
printf 'error:is_archived\n' > "$rigDir/post-script"
rigSendQueued "RIG-QUEUED-ONE"
rigAssert "a send into the session's own thread, the reader live, is queued: recorded now, no Slack call" \
	"$rigRc:$( LC_ALL=C grep -c '"queued":true' "$rigDir/send.out" ):$( rigCalls chat.postMessage )" "0:1:0"
rigAssert "its block is in the chat file" "$( rigBlocks )" 1
rigAssert "control: no block is addressed to the sender yet, and none says a post failed" "$( rigReportedTo keeper-rig 1 )" "0 0"
rigPush queue
rigAssert "the push reaches Slack for it" "$( rigCalls chat.postMessage )" 1
rigAssert "control: the refusal path ran -- the block's stamp line, the mark its index line resolves to, is refused" \
	"$( LC_ALL=C awk -F'\t' '$1 == 1 { last = $3 } END { print ( last == "" ? "no-line" : last ) }' "$rigChat.stamps" 2> /dev/null ):$( rigResolved 1 | LC_ALL=C awk '{ print $2 }' )" "refused:refused"
rigAssert "and one block reaches the sender's chat file, addressed to the sender, naming the block, saying it was not posted" \
	"$( rigReportedTo keeper-rig 1 )" "1 1"

echo "-- 2. two starts of the reader within one minute start one process --"
rigScene starts
rigStart(){ ## output basename -- one start of the reader in the scene's workspace, the reader mode left to the operation
	( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_COMMS_READER \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash "$rigTool" --intern-session-comms --start ) > "$rigDir/$1.out" 2> "$rigDir/$1.err"
	rigRc=$?
}
rigStarts(){ ## how many readers this rig's own log says were started: one line per process actually started
	LC_ALL=C grep -c 'a start of the communications reader is made' "$rigDir/ws/.local/agents/comms/log" 2> /dev/null
}
rigLockPid(){ LC_ALL=C awk '{ print $1 ; }' < "$rigDir/ws/.local/agents/comms/lock" 2> /dev/null ; }
## A lock whose note names a process that is gone: what every live start line of the log reports meeting.
rigLostLock(){ printf '999999 Mon_Jan__1_00:00:00_2001\n' > "$rigDir/ws/.local/agents/comms/lock" ; }
rigLostLock
rigStart first
rigDaemon="$( LC_ALL=C sed -n 's/^started \([0-9][0-9]*\)$/\1/p' "$rigDir/first.out" | head -1 )"
[ -z "$rigDaemon" ] || { rigProcNote "$rigDaemon" ; rigStarted="$rigStarted $rigDaemon" ; }
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ "$( rigLockPid )" != "${rigDaemon:-none}" ] ; do sleep 0.5 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "control: the first start does make one process, which takes the lock and is named by it" \
	"$( rigStarts ):$( [ -n "$rigDaemon" ] && [ "$( rigLockPid )" = "$rigDaemon" ] && printf named || printf unnamed ):$( rigProcStill "${rigDaemon:-0}" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "1:named:1"
## Past the five seconds one start used to be marked for, and well inside the minute statement 2 is about.
sleep 8
rigScndFrom="$( date +%s )"
rigLostLock
rigStart second
rigScndTo="$( date +%s )"
rigAssert "the two starts are inside one minute of each other" \
	"$( [ $(( rigScndTo - rigScndFrom )) -lt 60 ] && printf within )" "within"
rigAssert "the second start, inside that minute, starts no second process" "$( rigStarts )" "1"
rigAssert "and its answer is no started process" \
	"$( LC_ALL=C head -1 "$rigDir/second.out" | LC_ALL=C grep -c '^started ' )" "0"
rigAssert "and it ended well" "$rigRc" 0

echo "-- 3. a pull of a direct conversation the user identity cannot reach resolves, and is not tried again --"
rigScene dm
## A fake curl answering by token and method, logging `<method> <identity> <channel>`: the identity a call went out under is what
## statement 3 is about, so it is read from the call and never from the reader's own words. The direct conversation answers the bot
## and refuses the user, as Slack does for a DM the user identity is not in.
mkdir -p "$rigDir/bin"
cat > "$rigDir/bin/curl" <<- 'FAKE'
	#!/usr/bin/env bash
	set -u
	dmHeader="$( cat )"
	dmMethod="" dmChannel="" dmPrev="" dmBody=""
	for dmArg in "$@" ; do
		case "$dmArg" in
			https://slack.com/api/*) dmMethod="${dmArg#https://slack.com/api/}" ; dmMethod="${dmMethod%%\?*}" ;;
			channel@*) dmChannel="$( cat "${dmArg#channel@}" 2> /dev/null )" ;;
			channel=*) dmChannel="${dmArg#channel=}" ;;
		esac
		[ "$dmPrev" != "--data-binary" ] || dmBody="${dmArg#@}"
		dmPrev="$dmArg"
	done
	[ -n "${RIG_DM_SCENARIO:-}" ] || { printf '{"ok":false,"error":"rig_no_scenario"}\n' ; exit 0 ; }
	dmToken="${dmHeader#Authorization: Bearer }"
	dmWho=user ; case "$dmToken" in rig-bot-*) dmWho=bot ;; esac
	printf '%s %s %s\n' "$dmMethod" "$dmWho" "${dmChannel:--}" >> "$RIG_DM_SCENARIO/dm-calls"
	case "$dmMethod" in
		auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGUSER01"}\n' ;;
		conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false}}\n' "${dmChannel:-DRIGDM0001}" ;;
		conversations.history|conversations.replies)
			case "$dmWho" in
				bot) printf '{"ok":true,"has_more":false,"messages":[{"type":"message","user":"URIGOWNER","text":"RIG-DM-ONE","ts":"1795400000.000100"}]}\n' ;;
				*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
			esac
		;;
		*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
	esac
FAKE
chmod +x "$rigDir/bin/curl"
[ "$( PATH="$rigDir/bin:$PATH" command -v curl )" = "$rigDir/bin/curl" ] || rigRefuse "arm 3's fake curl is not first on its PATH, so it would issue real requests"
rigDm="D0RIGDM0001"
rigDmEntry="slack-URIGUSER01-$rigDm"
rigDmDir="$rigDir/ws/.local/cache/comms/slack/$rigDmEntry"
mkdir -p "$rigDmDir" "$rigDir/ws/.local/cache/comms/.interest"
: > "$rigDir/dm-calls"
## The channel's cached recipe: how it is pulled, its target, its member, and `false` -- the user identity. Its ingest has run since the
## cache last moved, so the sweep does not answer for the pull: what this arm reads is the pull's own call.
printf '%s %s %s\n## target=%s channel=%s\nslack-conversation %s keeper-rig false 1795300000.000001\n' \
	"$(( rigNow - 3600 ))" 1795300000.000001 1795300000.000001 "$rigDm" "$rigDm" "$rigDm" > "$rigDmDir/.state.txt"
: > "$rigDmDir/.ingest.txt"
## Read lately by a reader that wants it now: the mark, and the want that makes the pull due whatever its own schedule says.
printf '%s 15\n' "$(( rigNow - 60 ))" > "$rigDir/ws/.local/cache/comms/.interest/$rigDmEntry"
: > "$rigDmDir/.want"
rigPull(){ ## output basename -- one pull of the watched channels
	( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_COMMS_CACHE_ONLY -u MDAT_COMMS_CACHE_PULLER -u MDAT_COMMS_CACHE_WAIT_SECONDS -u MDAT_SLACK_THREAD_CACHE_SECONDS \
		"PATH=$rigDir/bin:$PATH" "RIG_DM_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash -c ". \"$rigHere/comms/AgentsTools.CommsCache.include\" || exit 9 ; AgentsToolsCommsCachePullWatched \"\$( date +%s )\" 0" ) > "$rigDir/$1.out" 2> "$rigDir/$1.err"
	rigRc=$?
}
rigDmCalls(){ ## method, identity -- how many calls of that method went out under that identity
	LC_ALL=C awk -v want="$1" -v who="$2" '$1 == want && $2 == who { n++ } END { print n + 0 }' "$rigDir/dm-calls" 2> /dev/null
}
rigDmSeen(){ ## every call the arm's fake curl took, as `<method>=<identity>`, for a reader who has to know what happened
	LC_ALL=C awk '{ printf "%s=%s ", $1, $2 ; }' "$rigDir/dm-calls" 2> /dev/null
}
rigRecipe(){ LC_ALL=C tail -n 1 "$rigDmDir/.state.txt" 2> /dev/null ; }
rigServed(){ LC_ALL=C grep -c -F -e RIG-DM-ONE "$rigDmDir"/*/messages.txt 2> /dev/null | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' ; }
## The channel aged past the reader's TTL: the state a later pass meets. A fresh one would be served from the cache and no
## identity would be asked at all, so the identity a later pull chooses could not be measured.
rigAge(){ printf '%s %s %s\n' "$(( rigNow - 3600 ))" 1795300000.000001 1795300000.000001 > "$rigDir/state.head" ; { cat "$rigDir/state.head" ; LC_ALL=C tail -n +2 "$rigDmDir/.state.txt" ; } > "$rigDir/state.next" && mv -f "$rigDir/state.next" "$rigDmDir/.state.txt" ; }
rigPull dm-1
rigAssert "control: the pull reaches the conversation at all -- it ends well, and calls it as $( rigDmSeen )" \
	"$( [ "$rigRc" = 0 ] && printf ok || printf "rc=$rigRc" ):$( LC_ALL=C awk '$1 == "conversations.history" { n++ } END { print ( n > 0 ) ? "reached" : "unreached" }' "$rigDir/dm-calls" 2> /dev/null )" "ok:reached"
rigAssert "the direct conversation's message is served from the cache after the pull" "$( rigServed )" "1"
rigAssert "the user's read was refused and the bot's answered it: $( rigDmSeen )" \
	"$( rigDmCalls conversations.history user ):$( rigDmCalls conversations.history bot )" "1:1"
rigAssert "the recipe keeps its one folder, `false`: $( rigRecipe )" \
	"$( printf '%s\n' "$( rigRecipe )" | LC_ALL=C awk '{ print $4 }' )" "false"
## AND THE SOURCE STAYS THE PASS'S: the list its next pass builds over this same store holds the folder.
( cd "$rigDir/ws" && env "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" bash -c ". \"$rigHere/comms/AgentsTools.CommsIngestPass.include\" || exit 9 ; AgentsCommsIngestPassSources \"$rigDir/ingest.list\" \"$rigDir/ws/.local/cache/comms/slack\"" ) > /dev/null 2>&1
rigAssert "and the ingest pass still lists that direct conversation" "$( LC_ALL=C grep -c -F "$rigDmEntry" "$rigDir/ingest.list" 2> /dev/null )" 1
rigAssert "and no second folder of that conversation was made" \
	"$( ls "$rigDir/ws/.local/cache/comms/slack" | LC_ALL=C grep -c -- "$rigDm$" )" 1
: > "$rigDir/dm-calls"
rigAge
: > "$rigDmDir/.want"
rigPull dm-2
rigAssert "control: the second pull reaches the conversation too, and calls it as $( rigDmSeen )" \
	"$( LC_ALL=C awk '$1 == "conversations.history" { n++ } END { print ( n > 0 ) ? "reached" : "unreached" }' "$rigDir/dm-calls" 2> /dev/null )" "reached"
rigAssert "and still answers it under the bot: $( rigDmSeen )" "$( rigDmCalls conversations.history bot )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS QUEUE REPORT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_QUEUE_REPORT: OK (%d assertions, offline)\n' "$rigPassCount"
