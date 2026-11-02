#!/usr/bin/env bash
## Behavioural check on the Wait path isolation of sh-lib/member/AgentsTools.MemberWait*.include (epic 20261026-refactorings, S28.1): a wait
## parses the probe of a source kind only when it has a source of that kind. AgentsTools.MemberWait.include keeps the wait arm and sources
## the core of helpers; each kind's probe lives in an include of its own, sourced only by a wait that has such a source.
## Held, run and not read (every file a call sources is logged by a line put at the head of each .include of a copy of the package, and
## every probe function the process holds afterwards is listed, so what was parsed is read from the process and not from the file names):
##   1. THE KINDS. One wait of 2 seconds for each kind, in a process of its own, over a Slack-shaped fake curl: it sources the arm, the core
##      and the pieces its kind takes (file, inbox, board, process and wake: Local; slack: Slack; ask: Ask and Slack; replies: Replies;
##      mentions and tagged: Mentions; dms: Dms; chat and scan: Chat) and no other MemberWait*.include, it holds the probe functions of
##      those pieces and no other, and it is not refused for a kind it does not carry (the kind's probe must be there before the check).
##   2. THE FLOOR. A --wait-default wait of a session adds to the sources it was given the replies of the session's own posts, the
##      member's DMs and mentions and its wake marker (the chat of the session too, where the session has a folder; the rig's has none):
##      a wait of a file source in such a session sources the Local, Replies, Dms and Mentions pieces, and no other.
##   3. THE CALLERS. AgentsToolsPendingReplyPollOwn (MemberPendingReply.include) needs the ask probe, and the floor of the session chat that
##      advances a stored wait's floor (SessionChat.include) needs the floor helper: each sources the core and what it uses (the floor
##      advance: the core and at most one piece), and never the arm file, which would also run a wait arm over the caller's own arguments.
##   4. THE INSTRUMENT. The classifier is run on logs and function lists made by hand: the pair it must pass, and one each for the faults it
##      names (a piece of another kind, a piece missing, a probe of another kind held, the arm file where it must not be).
## Red recipe: on the one file of before the split every wait sources the arm file alone and holds all fourteen probes, so section 1 fails on the
## core and the own piece not sourced and on the probes of the other kinds held; section 3 fails on the arm file sourced; section 4 passes on it.
## Section 5 is a finding that stands beside the split, and is not part of it: on the file of before the split AgentsToolsPendingReplyPollOwn
## sources the wait include, whose arm answers the caller's own first argument with "invalid option" and returns 1, and the caller reads
## that as a failed load and returns 0 before it has looked at one record. Once the include is functions only the load succeeds and the
## poll runs. Drop section 5 if the owner rules that the poll stays off.
## Offline: a Slack-shaped fake curl is first on PATH, and every workspace is a folder of the rig's own under $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

## THE NAMES: one block, the only place a piece's name is written. The family is matched by regex, so a piece that moves is still seen. A name that
## moved in review is given to a run in the variable beside it, RIG_WAIT_PIECE_<KIND> (RIG_WAIT_ARM for the arm file), with no edit of this file.
rigPackageRel="myx/myx.distro-agents"
rigFamilyRegex='^AgentsTools\.MemberWait.*\.include$'
rigArm="${RIG_WAIT_ARM:-AgentsTools.MemberWait.include}"
rigPieceCore="${RIG_WAIT_PIECE_CORE:-AgentsTools.MemberWaitCore.include}"
rigPieceSlack="${RIG_WAIT_PIECE_SLACK:-AgentsTools.MemberWaitSlack.include}"
rigPieceReplies="${RIG_WAIT_PIECE_REPLIES:-AgentsTools.MemberWaitReplies.include}"
rigPieceAsk="${RIG_WAIT_PIECE_ASK:-AgentsTools.MemberWaitAsk.include}"
rigPieceMentions="${RIG_WAIT_PIECE_MENTIONS:-AgentsTools.MemberWaitMentions.include}"
rigPieceDms="${RIG_WAIT_PIECE_DMS:-AgentsTools.MemberWaitDms.include}"
rigPieceChat="${RIG_WAIT_PIECE_CHAT:-AgentsTools.MemberWaitChat.include}"
rigPieceLocal="${RIG_WAIT_PIECE_LOCAL:-AgentsTools.MemberWaitLocal.include}"
## the probe functions each piece holds
rigProbesLocal="AgentsWaitProbeFile AgentsWaitProbeProcess AgentsWaitProbeInbox AgentsWaitProbeBoard AgentsWaitProbeWake"
rigProbesSlack="AgentsWaitProbeSlack AgentsWaitProbeSlackPerson"
rigProbesReplies="AgentsWaitProbeReplies"
rigProbesAsk="AgentsWaitProbeAsk"
rigProbesMentions="AgentsWaitProbeMentions AgentsWaitProbeTagged"
rigProbesDms="AgentsWaitProbeDms"
rigProbesChat="AgentsWaitProbeChat AgentsWaitProbeScan"
rigMember="magic-tester"
## Files the arm sources whatever the wait holds (the three phases the arm was split into, not pieces of a kind), RIG_WAIT_ALWAYS to change them, space-separated, empty for none.
rigAlways="${RIG_WAIT_ALWAYS-AgentsTools.MemberWaitSources.include AgentsTools.MemberWaitRun.include AgentsTools.MemberWaitResult.include}"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "no dispatcher at the origin this workspace resolves: $rigPackage"
[ -f "$rigPackage/sh-lib/member/$rigArm" ] || rigRefuse "no wait arm at the origin: $rigPackage/sh-lib/member/$rigArm"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so a wait would have no member to act as"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitPathIsolationCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] && echo "kept: $rigTmp" || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT

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

## THE CLASSIFIER. A log is the files one call sourced, a path a line; a probe list is the probe functions the process held, a name a line.
rigFamilyOf(){ ## log -- the family's files it names, once each, a basename a line, sorted
	LC_ALL=C awk -v rx="$rigFamilyRegex" '{ n = split( $0, part, "/" ) ; if ( part[ n ] ~ rx ) print part[ n ] ; }' "$1" | LC_ALL=C sort -u
}
rigSorted(){ ## words... -- one a line, sorted, once each
	printf '%s\n' "$@" | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk 'NF' | LC_ALL=C sort -u
}
rigDiff(){ ## got lines, want lines -- `ok`, or what is missing and what is more, in a line
	local diffMissing diffMore
	diffMissing="$( LC_ALL=C comm -13 <( printf '%s\n' "$1" ) <( printf '%s\n' "$2" ) | LC_ALL=C tr '\n' ' ' )"
	diffMore="$( LC_ALL=C comm -23 <( printf '%s\n' "$1" ) <( printf '%s\n' "$2" ) | LC_ALL=C tr '\n' ' ' )"
	if [ -z "$diffMissing$diffMore" ] ; then printf ok ; else printf 'missing [%s] more [%s]' "${diffMissing% }" "${diffMore% }" ; fi
}
rigPiecesOfKind(){ ## kind -- the pieces a wait with one source of it takes, besides the arm and the core
	case "$1" in
		file|inbox|board|process|wake) printf '%s' "$rigPieceLocal" ;;
		slack) printf '%s' "$rigPieceSlack" ;;
		ask) printf '%s %s' "$rigPieceAsk" "$rigPieceSlack" ;;
		replies) printf '%s' "$rigPieceReplies" ;;
		mentions|tagged) printf '%s' "$rigPieceMentions" ;;
		dms) printf '%s' "$rigPieceDms" ;;
		chat|scan) printf '%s' "$rigPieceChat" ;;
	esac
}
rigProbesOfPiece(){ ## piece -- the probe functions it holds
	case "$1" in
		"$rigPieceLocal") printf '%s' "$rigProbesLocal" ;;
		"$rigPieceSlack") printf '%s' "$rigProbesSlack" ;;
		"$rigPieceReplies") printf '%s' "$rigProbesReplies" ;;
		"$rigPieceAsk") printf '%s' "$rigProbesAsk" ;;
		"$rigPieceMentions") printf '%s' "$rigProbesMentions" ;;
		"$rigPieceDms") printf '%s' "$rigProbesDms" ;;
		"$rigPieceChat") printf '%s' "$rigProbesChat" ;;
	esac
}
rigWantFiles(){ ## withArm (yes|no), pieces... -- the files a call must source, a line each
	local wantArm="$1" wantPiece
	shift
	{ [ "$wantArm" != "yes" ] || { printf '%s\n' "$rigArm" ; [ -z "$rigAlways" ] || printf '%s\n' $rigAlways ; } ; printf '%s\n' "$rigPieceCore" ; for wantPiece in "$@" ; do printf '%s\n' "$wantPiece" ; done ; } | LC_ALL=C sort -u
}
rigWantProbes(){ ## pieces... -- the probe functions a call may hold, a line each
	local wantPiece
	for wantPiece in "$@" ; do rigProbesOfPiece "$wantPiece" ; printf ' ' ; done | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk 'NF' | LC_ALL=C sort -u
}

echo "-- 4. the instrument: the classifier on logs and lists made by hand --"
rigAlwaysRun="$rigAlways" ; rigAlways=""
printf '/x/%s\n/x/%s\n/x/%s\n/x/Other.include\n' "$rigArm" "$rigPieceCore" "$rigPieceLocal" > "$rigTmp/log.good"
printf '/x/%s\n/x/%s\n/x/%s\n/x/%s\n' "$rigArm" "$rigPieceCore" "$rigPieceLocal" "$rigPieceSlack" > "$rigTmp/log.more"
printf '/x/%s\n/x/%s\n' "$rigArm" "$rigPieceLocal" > "$rigTmp/log.nocore"
printf '/x/%s\n' "$rigArm" > "$rigTmp/log.armonly"
rigAssert "classifier: the arm, the core and the Local piece pass for a file wait" "$( rigDiff "$( rigFamilyOf "$rigTmp/log.good" )" "$( rigWantFiles yes "$rigPieceLocal" )" )" ok
rigAssert "classifier: a piece of another kind is named" "$( rigDiff "$( rigFamilyOf "$rigTmp/log.more" )" "$( rigWantFiles yes "$rigPieceLocal" )" )" "missing [] more [$rigPieceSlack]"
rigAssert "classifier: a missing core is named" "$( rigDiff "$( rigFamilyOf "$rigTmp/log.nocore" )" "$( rigWantFiles yes "$rigPieceLocal" )" )" "missing [$rigPieceCore] more []"
rigAssert "classifier: the arm file alone is named for what it lacks" "$( rigDiff "$( rigFamilyOf "$rigTmp/log.armonly" )" "$( rigWantFiles yes "$rigPieceLocal" )" )" "missing [$rigPieceCore $rigPieceLocal] more []"
rigAssert "classifier: the arm file where a caller may not source it is named" "$( rigDiff "$( rigFamilyOf "$rigTmp/log.good" )" "$( rigWantFiles no "$rigPieceLocal" )" )" "missing [] more [$rigArm]"
rigAssert "classifier: the probes of the Local piece pass for a file wait" "$( rigDiff "$( rigSorted "$rigProbesLocal" )" "$( rigWantProbes "$rigPieceLocal" )" )" ok
rigAssert "classifier: the Slack probe held by a file wait is named" "$( rigDiff "$( rigSorted "$rigProbesLocal $rigProbesSlack" )" "$( rigWantProbes "$rigPieceLocal" )" )" "missing [] more [AgentsWaitProbeSlack AgentsWaitProbeSlackPerson]"

rigAlways="$rigAlwaysRun"
echo "-- the rig: a copy of the package under check, a log line at the head of each include, a fake curl --"
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx" "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents/pending" "$rigTmp/data" || exit 1
for rigPkg in "$MDLT_ORIGIN"/myx/myx.distro-* "$MDLT_ORIGIN"/myx/myx.common ; do
	[ -d "$rigPkg" ] || continue
	cp -RL "$rigPkg" "$rigOrigin/myx/${rigPkg##*/}" || rigRefuse "the copy of ${rigPkg##*/} failed"
done
[ "$( find "$rigOrigin" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" = "0" ] || rigRefuse "the copy holds a link, so a rig could reach the real tree"
find "$rigOrigin" -name .git -prune -exec rm -rf {} +
rigLogLine='[ -z "${RIG_SOURCED_LOG:-}" ] || printf '"'"'%s\n'"'"' "${BASH_SOURCE[0]}" >> "$RIG_SOURCED_LOG"'
find "$rigOrigin/$rigPackageRel/sh-lib" -name '*.include' -type f | while IFS= read -r rigFile ; do
	LC_ALL=C awk -v logLine="$rigLogLine" 'NR == 1 && $0 !~ /^#!/ { print logLine ; } { print ; } NR == 1 && $0 ~ /^#!/ { print logLine ; }' "$rigFile" > "$rigFile.rigtmp" \
		&& cat "$rigFile.rigtmp" > "$rigFile" && rm -f "$rigFile.rigtmp" || exit 1
done || rigRefuse "the log line could not be put at the head of the includes"
rigTools="$rigOrigin/$rigPackageRel/sh-scripts/DistroAgentsTools.fn.sh"
[ "$( LC_ALL=C sed -n 2p "$rigOrigin/$rigPackageRel/sh-lib/member/$rigArm" | LC_ALL=C cut -c1-40 )" = '[ -z "${RIG_SOURCED_LOG:-}" ] || printf ' ] || rigRefuse "the wait arm of the copy carries no log line"

cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## Slack-shaped fake curl: logs each method and answers every one with an empty, successful page. Opens no socket.
cat > /dev/null
rigMethod="no-method"
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.history|conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
RIG_CURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
printf 'quiet\n' > "$rigTmp/quiet.txt"
printf 'status: reply-received\nanswered-session: rig-other-session\nanswered-by: rig-other-session\nverdict: closed-by-operation\nkind: question\n# Thread\n' > "$rigTmp/ws/.local/agents/pending/rig-ask-001.md"
RIG_CURL_LOG="$rigTmp/curl.log"
RIG_SOURCED_LOG="$rigTmp/sourced.log"
export RIG_CURL_LOG RIG_SOURCED_LOG

rigAllProbes="$rigProbesLocal $rigProbesSlack $rigProbesReplies $rigProbesAsk $rigProbesMentions $rigProbesDms $rigProbesChat"
rigProcess(){ ## the shell script to run in one process of the copy, then the probe functions that process holds are listed in $rigTmp/held.out
	: > "$RIG_CURL_LOG" ; : > "$RIG_SOURCED_LOG" ; : > "$rigTmp/wait.out"
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" MDAT_WAIT_REMIND=off \
		bash -c "$1"'
			declare -F | LC_ALL=C awk '"'"'$3 ~ /^AgentsWaitProbe(Slack|SlackPerson|File|Process|Inbox|Board|Wake|Ask|Replies|Chat|Scan|Dms|Mentions|Tagged)$/ { print $3 ; }'"'"' | LC_ALL=C sort > "$RIG_HELD_LIST"' \
		rig "$rigTools" ) > "$rigTmp/process.out" 2> "$rigTmp/process.err" < /dev/null
}
RIG_HELD_LIST="$rigTmp/held.out"
export RIG_HELD_LIST

echo "-- 1. the kinds: one wait of each --"
rigKind(){ ## kind, source
	local kindName="$1" kindPieces kindPiece
	kindPieces="$( rigPiecesOfKind "$kindName" )"
	rigProcess '. "$1" ; set +e ; DistroAgentsTools --wait-for-input --team-member '"$rigMember"' --wait-source "'"$2"'" --wait-timeout 2 --wait-poll-interval 1 > "$RIG_WAIT_OUT" ; echo "wait-rc=$?" > "$RIG_WAIT_RC" ;'
	[ -z "${RIG_DEBUG:-}" ] || { echo "== $kindName: $( LC_ALL=C head -1 "$rigTmp/wait.out" ) / $( LC_ALL=C tr '\n' ' ' < "$RIG_WAIT_RC" )" ; LC_ALL=C head -3 "$rigTmp/process.err" | LC_ALL=C cut -c1-250 ; }
	rigAssert "$kindName: the wait ran, and was not refused for a kind it does not carry" \
		"$( LC_ALL=C grep -c '^WAIT-RESULT: ' "$rigTmp/wait.out" | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'no input source of kind' "$rigTmp/wait.out" "$rigTmp/process.err" | LC_ALL=C awk -F: '{ sum += $2 ; } END { print sum + 0 ; }' )" "1:0"
	rigAssert "$kindName: it sourced the arm, the core and its own pieces, and no other MemberWait*.include" \
		"$( rigDiff "$( rigFamilyOf "$RIG_SOURCED_LOG" )" "$( rigWantFiles yes $kindPieces )" )" ok
	rigAssert "$kindName: it holds the probe functions of those pieces, and no other" \
		"$( rigDiff "$( LC_ALL=C cat "$RIG_HELD_LIST" )" "$( rigWantProbes $kindPieces )" )" ok
}
RIG_WAIT_OUT="$rigTmp/wait.out"
RIG_WAIT_RC="$rigTmp/wait.rc"
export RIG_WAIT_OUT RIG_WAIT_RC
rigKind file "file:$rigTmp/quiet.txt"
rigKind inbox "inbox:$rigMember"
rigKind board "board:pending"
rigKind process "process:rig-process-1"
rigKind wake "wake:$rigMember"
rigKind slack "slack:CRIG00001"
rigKind ask "ask:rig-ask-001"
rigKind replies "replies:rig-session-1"
rigKind mentions "mentions:$rigMember"
rigKind tagged "tagged:$rigMember"
rigKind dms "dms:$rigMember"
rigKind chat "chat:rig-session-1"
rigKind scan "scan:permission-escalation"

echo "-- 2. the floor of a session --"
rigProcess '. "$1" ; set +e ; DistroAgentsTools --wait-for-input --team-member '"$rigMember"' --wait-default --wait-session-id rig-floor-1 --wait-source "file:'"$rigTmp"'/quiet.txt" --wait-timeout 2 --wait-poll-interval 1 > "$RIG_WAIT_OUT" ;'
[ -z "${RIG_DEBUG:-}" ] || LC_ALL=C grep -m3 -e '^# waited' -e '^WAIT-RESULT' "$RIG_WAIT_OUT"
rigAssert "a --wait-default wait of a file source in a session: the arm, the core, Local, Replies, Dms and Mentions, and no other" \
	"$( rigDiff "$( rigFamilyOf "$RIG_SOURCED_LOG" )" "$( rigWantFiles yes "$rigPieceLocal" "$rigPieceReplies" "$rigPieceDms" "$rigPieceMentions" )" )" ok
rigAssert "and it holds the probe functions of those four pieces, and no other" \
	"$( rigDiff "$( LC_ALL=C cat "$RIG_HELD_LIST" )" "$( rigWantProbes "$rigPieceLocal" "$rigPieceReplies" "$rigPieceDms" "$rigPieceMentions" )" )" ok

echo "-- 3. the callers that source a piece of the wait --"
rigProcess '. "$1" ; set +e ; . "$MDLT_ORIGIN/'"$rigPackageRel"'/sh-lib/questions/AgentsTools.MemberPendingReply.include" ; AgentsToolsPendingReplyPollOwn '"$rigMember"' ;'
RIG_POLLOWN_LOG="$rigTmp/sourced.pollown.log"
cp "$RIG_SOURCED_LOG" "$RIG_POLLOWN_LOG"
rigAssert "AgentsToolsPendingReplyPollOwn: the core, the Ask piece and the Slack piece it needs, and no other; never the arm file" \
	"$( rigDiff "$( rigFamilyOf "$RIG_SOURCED_LOG" )" "$( rigWantFiles no "$rigPieceAsk" "$rigPieceSlack" )" )" ok
rigAssert "and it holds the ask probe and the Slack probes, and no other" \
	"$( rigDiff "$( LC_ALL=C cat "$RIG_HELD_LIST" )" "$( rigWantProbes "$rigPieceAsk" "$rigPieceSlack" )" )" ok

rigHas(){ ## haystack, needle -- yes or no
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}
rigAtMostOnePiece(){ ## log -- `ok`, or what is wrong: the arm sourced, no core, or more than one piece besides the core
	local onePieces oneFamily
	oneFamily="$( rigFamilyOf "$1" )"
	case " $( printf '%s' "$oneFamily" | LC_ALL=C tr '\n' ' ' ) " in *" $rigArm "*) printf 'the arm file was sourced' ; return 0 ;; esac
	case " $( printf '%s' "$oneFamily" | LC_ALL=C tr '\n' ' ' ) " in *" $rigPieceCore "*) ;; *) printf 'the core was not sourced' ; return 0 ;; esac
	onePieces="$( printf '%s\n' "$oneFamily" | LC_ALL=C awk -v core="$rigPieceCore" 'NF && $0 != core { printf "%s ", $0 ; }' )"
	case "${onePieces% }" in *" "*) printf 'more than one piece besides the core: %s' "${onePieces% }" ; return 0 ;; esac
	printf ok
}
rigAssert "classifier: the core alone passes for a floor advance" "$( printf '/x/%s\n' "$rigPieceCore" > "$rigTmp/log.coreonly" ; rigAtMostOnePiece "$rigTmp/log.coreonly" )" ok
rigAssert "classifier: the core and one piece pass" "$( printf '/x/%s\n/x/%s\n' "$rigPieceCore" "$rigPieceChat" > "$rigTmp/log.coreone" ; rigAtMostOnePiece "$rigTmp/log.coreone" )" ok
rigAssert "classifier: two pieces are named" "$( printf '/x/%s\n/x/%s\n/x/%s\n' "$rigPieceCore" "$rigPieceChat" "$rigPieceLocal" > "$rigTmp/log.coretwo" ; rigAtMostOnePiece "$rigTmp/log.coretwo" )" "more than one piece besides the core: $rigPieceChat $rigPieceLocal"
rigAssert "classifier: the arm file is named" "$( rigAtMostOnePiece "$rigTmp/log.good" )" "the arm file was sourced"
rigAssert "classifier: a missing core is named" "$( printf '/x/%s\n' "$rigPieceChat" > "$rigTmp/log.nocoreone" ; rigAtMostOnePiece "$rigTmp/log.nocoreone" )" "the core was not sourced"

## The floor advance: a session whose chat file is given a message, and a stored wait whose floor the delivery of that message moves.
rigFloorSession="rig-sess-floor"
rigFloorWs="$rigTmp/floorws"
rigNow="$( date +%s )"
rigThread="CRIGSES01:$(( rigNow - 400 )).000001"
mkdir -p "$rigFloorWs/.local/agents/sessions/$rigFloorSession/wait" "$rigFloorWs/.local/.agents" || exit 1
cp "$rigTmp/ws/.local/.agents/magic-team.agent.env" "$rigTmp/ws/.local/.agents/$rigMember.agent.env" "$rigFloorWs/.local/.agents/" || exit 1
printf '%s\n' "$rigThread" > "$rigFloorWs/.local/agents/sessions/$rigFloorSession/session.thread"
: > "$rigTmp/launch.marker"
touch -t "$( date -r $(( rigNow - 300 )) +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$(( rigNow - 300 ))" +%Y%m%d%H%M.%S )" "$rigTmp/launch.marker"
printf 'sources: slack:%s:conversation\naddressee: \ninclude-own: false\nfloor slack:%s:conversation %s\n' "$rigThread" "$rigThread" "$(( rigNow - 300 ))" \
	> "$rigFloorWs/.local/agents/sessions/$rigFloorSession/wait/state"
rigFloorRun(){ ## the script to run in a process of the copy, in the floor's workspace
	( env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_CONVERSATION_THREADS -u MDAT_SPAWN_AGENT \
		MMDAPP="$rigFloorWs" MDLT_ORIGIN="$rigOrigin" MDAT_SPAWN_LAUNCH_MARKER="$rigTmp/launch.marker" bash -c "$1" ) 2> /dev/null
}
rigFloorImport(){ ## thread messages as a JSON array body -- rendered by the formatter of the copy and imported into the session's chat file
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$1" > "$rigTmp/thread.json"
	LC_ALL=C awk -f "$rigOrigin/$rigPackageRel/sh-lib/comms/AgentsSlackMessagesFormat.awk" < "$rigTmp/thread.json" > "$rigTmp/thread.rendered" 2> /dev/null
	rigFloorRun ". '$rigOrigin/$rigPackageRel/sh-lib/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatImport '$rigFloorSession' '$rigThread' '$rigTmp/thread.rendered' slack -"
}
rigFloorDeliver(){
	rigFloorRun ". '$rigOrigin/$rigPackageRel/sh-lib/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatFloor '$rigFloorSession' '$rigMember' '' deliver"
}
rigRoot="{\"ts\":\"$(( rigNow - 400 )).000001\",\"user\":\"URIGHUM1\",\"text\":\"RIG-ROOT-BEFORE-LAUNCH\"}"
rigNew="{\"ts\":\"$(( rigNow - 100 )).000001\",\"user\":\"URIGHUM1\",\"text\":\"RIG-NEW-ONE\",\"thread_ts\":\"$(( rigNow - 400 )).000001\"}"
rigFloorImport "$rigRoot" ; rigFloorDeliver > /dev/null
rigFloorImport "$rigRoot,$rigNew"
: > "$RIG_SOURCED_LOG"
RIG_SOURCED_LOG="$RIG_SOURCED_LOG" rigFloorOut="$( RIG_SOURCED_LOG="$RIG_SOURCED_LOG" rigFloorDeliver )"
rigAssert "the floor of the session chat delivered the new message, and moved the stored wait's floor to its ts (the advance ran)" \
	"$( rigHas "$rigFloorOut" RIG-NEW-ONE ):$( LC_ALL=C awk '$1 == "floor" { print $3 ; exit ; }' "$rigFloorWs/.local/agents/sessions/$rigFloorSession/wait/state" )" \
	"yes:$(( rigNow - 100 )).000001"
rigAssert "the floor advance: the core and at most one piece, and never the arm file" "$( rigAtMostOnePiece "$RIG_SOURCED_LOG" )" ok

echo "-- 5. a finding beside the split: the poll of a member's own asks goes on to its records --"
rigAssert "AgentsToolsPendingReplyPollOwn sourced the ask include it reads the records with, after the wait include" \
	"$( LC_ALL=C grep -c 'AgentsHarnessAsk\.include$' "$RIG_POLLOWN_LOG" | LC_ALL=C tr -d ' ' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT PATH ISOLATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_PATH_ISOLATION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
