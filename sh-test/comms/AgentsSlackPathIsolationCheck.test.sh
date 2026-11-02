#!/usr/bin/env bash
## Behavioural check on the Slack path isolation of sh-lib/comms/AgentsTools.MemberCommsSlack*.include (epic 20261026-refactorings, S28.1):
## a call parses only its own path. The router file holds the member and client stubs, the presence, profile and socket arms and the
## dispatcher function, and each --intern-op-comms-slack-<op> operation lives in an include of its own that only its own arm sources.
## Held, run and not read (every file a call sources is logged by a line put at the head of each .include of a copy of the package):
##   1. THE OPERATIONS. Each of read, search, react, delete, edit, file-info, file-fetch, file-share and send, called by the stub of the
##      member (--slack-<op>, the rig acting as the member through MDAT_SPAWN_AGENT) over a Slack-shaped fake curl: the call reaches its
##      own Slack method, and of the MemberCommsSlack*.include files it sources the router and its own include, and no other.
##   2. THE STUBS. Each --slack-<op> and each --client-comms-slack-<op> with --print-required-scopes, which needs no network and no
##      acting member: it sources nothing of the family but the router and its own include, and prints the scopes the operation has
##      always printed. The stub of a member reaches the intern arm by calling the router's own function again, so the pair covers that hop.
##   3. THE CHEAP LOAD. Every Wait sources the router with --intern-op-comms-slack-read --print-required-scopes: the router answers it
##      itself, so a call of that pair, and a real Wait over a file source, parse no more than the router's own lines (the router limit).
##   4. THE CONTROL. The presence, profile and socket arms, split out long before this epic, are called the same ways (the intern arm,
##      the stub of the member and the client stub, each with --print-required-scopes): their calls source the router and their own
##      include, and no other.
##   5. THE FIRST SEARCH OF A PROCESS. The search arm is reached by the source-time call of the router, and a function it calls that the
##      router file defines further down is not there yet. A first search in a fresh process ends 0 and asks its Slack method. The control is
##      the same search in a process that loaded the router once before. Section 5b runs only with RIG_FINDINGS=1. It is a finding that stands beside the split: the arm calls
##      the comms-cache functions it files its answer with and never loads them, so "command not found" is on the error stream of every
##      search of a process that did not load that include by another way (the answer is then never cached). Drop 5b if the owner rules that stays.
##   6. THE INSTRUMENT. The classifier of a log is run on logs made by hand: the log it must pass, and one each for the faults it names
##      (another operation's include, no include of its own, no router). A classifier that cannot fail is no check.
## Red recipe: on the one file of before the split every operation's call sources the router alone, so section 1 fails on "its own include
## was not sourced" and section 3 fails on 3173 lines parsed where the router limit is 120; section 5 fails on the first search
## (status 127, the arm calls AgentsToolsCommsSlackSearchAnswer before the router file has defined it, and AgentsToolsCommsCacheSearchSignature
## is never loaded); sections 4 and 6 pass on it.
## Offline: a Slack-shaped fake curl is first on PATH, and every workspace is a folder of the rig's own under $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

## THE NAMES: one block, the only place a piece's name is written. The family is matched by regex, so a piece that moves is still seen. A name that
## moved in review is given to a run in the variable beside it, RIG_SLACK_PIECE_<OP> (RIG_SLACK_ROUTER for the router, RIG_SLACK_FAMILY_REGEX for
## the family), with no edit of this file.
rigPackageRel="myx/myx.distro-agents"
rigFamilyRegex="${RIG_SLACK_FAMILY_REGEX:-^AgentsTools\.(MemberCommsSlack|InternOpCommsSlack).*\.include$}"
rigRouter="${RIG_SLACK_ROUTER:-AgentsTools.MemberCommsSlack.include}"
rigRouterLimit="${RIG_ROUTER_LIMIT:-150}"
rigMember="magic-tester"
rigPieceRead="${RIG_SLACK_PIECE_READ:-AgentsTools.InternOpCommsSlackRead.include}"
rigPieceSearch="${RIG_SLACK_PIECE_SEARCH:-AgentsTools.InternOpCommsSlackSearch.include}"
rigPieceReact="${RIG_SLACK_PIECE_REACT:-AgentsTools.InternOpCommsSlackReact.include}"
rigPieceDelete="${RIG_SLACK_PIECE_DELETE:-AgentsTools.InternOpCommsSlackDelete.include}"
rigPieceEdit="${RIG_SLACK_PIECE_EDIT:-AgentsTools.InternOpCommsSlackEdit.include}"
rigPieceFileInfo="${RIG_SLACK_PIECE_FILEINFO:-AgentsTools.InternOpCommsSlackFileInfo.include}"
rigPieceFileFetch="${RIG_SLACK_PIECE_FILEFETCH:-AgentsTools.InternOpCommsSlackFileFetch.include}"
rigPieceFileShare="${RIG_SLACK_PIECE_FILESHARE:-AgentsTools.InternOpCommsSlackFileShare.include}"
rigPieceSend="${RIG_SLACK_PIECE_SEND:-AgentsTools.InternOpCommsSlackSend.include}"
## A piece an operation's own include sources by need: file-fetch calls the file-info helper. Taken as ruled on the build owner's word, with magic-architect
## and keeper-myx accepting the built shape, and open to the magic-coordinator's overrule (Q127). Set RIG_SLACK_ALSO_FILEFETCH to an empty value to refuse it.
## The router limit of 150 lines is held the same way (Q126, the brief said 120): set RIG_ROUTER_LIMIT=120 to hold the brief's.
rigAlsoFileFetch="${RIG_SLACK_ALSO_FILEFETCH-AgentsTools.InternOpCommsSlackFileInfo.include}"
rigPiecePresence="AgentsTools.MemberCommsSlackPresence.include"
rigPieceProfile="AgentsTools.MemberCommsSlackProfile.include"
rigPieceSocket="AgentsTools.MemberCommsSlackSocket.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "no dispatcher at the origin this workspace resolves: $rigPackage"
[ -f "$rigPackage/sh-lib/comms/$rigRouter" ] || rigRefuse "no router at the origin: $rigPackage/sh-lib/comms/$rigRouter"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so a stub would have no member to act as"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSlackPathIsolationCheck.XXXXXX" )" || exit 1
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

## THE CLASSIFIER. A log is the files one call sourced, a path a line.
rigFamilyOf(){ ## log -- the family's files it names, once each, a basename a line
	LC_ALL=C awk -v rx="$rigFamilyRegex" '{ n = split( $0, part, "/" ) ; if ( part[ n ] ~ rx ) print part[ n ] ; }' "$1" | LC_ALL=C sort -u
}
rigClassify(){ ## log, the operation's own include (empty: the router alone is allowed), own-required|own-optional|router-optional -- `ok`, or what is wrong, in a line
	local classFamily classExtra classOwn="${2%% *}" classAllowed="$2"
	classFamily="$( rigFamilyOf "$1" )"
	classExtra="$( printf '%s\n' "$classFamily" | LC_ALL=C awk -v router="$rigRouter" -v allowed=" $classAllowed " 'NF && $0 != router && index( allowed, " " $0 " " ) == 0 { printf "%s ", $0 ; }' )"
	[ "$3" = "router-optional" ] || case " $( printf '%s' "$classFamily" | LC_ALL=C tr '\n' ' ' ) " in *" $rigRouter "*) ;; *) printf 'the router was not sourced' ; return 0 ;; esac
	[ -z "$classExtra" ] || { printf 'sourced besides the router and its own: %s' "${classExtra% }" ; return 0 ; }
	if [ "$3" = "own-required" ] && [ -n "$classOwn" ] ; then
		case " $( printf '%s' "$classFamily" | LC_ALL=C tr '\n' ' ' ) " in *" $classOwn "*) ;; *) printf 'its own include was not sourced: %s' "$classOwn" ; return 0 ;; esac
	fi
	printf 'ok'
}
rigLinesOfFamily(){ ## log -- the lines of the family's files it names, as they stand in the package under check
	LC_ALL=C awk -v rx="$rigFamilyRegex" '{ n = split( $0, part, "/" ) ; if ( part[ n ] ~ rx ) print part[ n ] ; }' "$1" | LC_ALL=C sort -u \
		| while IFS= read -r famName ; do wc -l < "$rigPackage/sh-lib/comms/$famName" ; done | LC_ALL=C awk '{ sum += $1 ; } END { print sum + 0 ; }'
}

echo "-- 6. the instrument: the classifier on logs made by hand --"
printf '/x/sh-lib/comms/%s\n/x/sh-lib/comms/%s\n/x/sh-lib/comms/Other.include\n' "$rigRouter" "$rigPieceReact" > "$rigTmp/log.good"
printf '/x/sh-lib/comms/%s\n/x/sh-lib/comms/%s\n/x/sh-lib/comms/%s\n' "$rigRouter" "$rigPieceReact" "$rigPieceSend" > "$rigTmp/log.extra"
printf '/x/sh-lib/comms/%s\n' "$rigRouter" > "$rigTmp/log.routeronly"
printf '/x/sh-lib/comms/%s\n' "$rigPieceReact" > "$rigTmp/log.norouter"
rigAssert "classifier: the router and the operation's own include pass" "$( rigClassify "$rigTmp/log.good" "$rigPieceReact" own-required )" ok
rigAssert "classifier: another operation's include is named" "$( rigClassify "$rigTmp/log.extra" "$rigPieceReact" own-required )" "sourced besides the router and its own: $rigPieceSend"
rigAssert "classifier: no include of its own is named" "$( rigClassify "$rigTmp/log.routeronly" "$rigPieceReact" own-required )" "its own include was not sourced: $rigPieceReact"
rigAssert "classifier: the router alone passes where an own include is not required" "$( rigClassify "$rigTmp/log.routeronly" "$rigPieceReact" own-optional )" ok
rigAssert "classifier: no router is named" "$( rigClassify "$rigTmp/log.norouter" "$rigPieceReact" own-required )" "the router was not sourced"
rigAssert "classifier: a log of nothing is no router" "$( : > "$rigTmp/log.empty" ; rigClassify "$rigTmp/log.empty" "" own-optional )" "the router was not sourced"
rigAssert "classifier: a log of nothing passes where the router is optional" "$( rigClassify "$rigTmp/log.empty" "" router-optional )" ok
rigAssert "classifier: another operation's include is named where the router is optional" "$( rigClassify "$rigTmp/log.extra" "" router-optional )" "sourced besides the router and its own: $rigPieceReact $rigPieceSend"

echo "-- the rig: a copy of the package under check, a log line at the head of each include, a fake curl --"
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx" "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents" "$rigTmp/data" || exit 1
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
rigRouterCopy="$rigOrigin/$rigPackageRel/sh-lib/comms/$rigRouter"
[ "$( LC_ALL=C sed -n 2p "$rigRouterCopy" | LC_ALL=C cut -c1-40 )" = '[ -z "${RIG_SOURCED_LOG:-}" ] || printf ' ] || rigRefuse "the router of the copy carries no log line"

cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## Slack-shaped fake curl: logs each method and answers it from a table. Opens no socket.
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
	conversations.history) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	search.messages) printf '{"ok":true,"messages":{"total":1,"paging":{"count":100,"total":1,"page":1,"pages":1},"matches":[{"ts":"1700000900.000100","user":"URIGOTHER","text":"plain","permalink":"https://rig.slack.com/archives/CRIG00001/p1700000900000100"}]}}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_channel":true,"is_member":true,"name":"rig"}}\n' ;;
	files.getUploadURLExternal) printf '{"ok":true,"upload_url":"https://files.slack.com/upload/rig","file_id":"F0RIG00001"}\n' ;;
	files.info) printf '{"ok":true,"file":{"id":"F0RIG00001","name":"rig.txt","size":3,"url_private":"https://files.slack.com/rig","url_private_download":"https://files.slack.com/rig-dl"}}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
RIG_CURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
printf 'rig share body\n' > "$rigTmp/share.txt"
RIG_CURL_LOG="$rigTmp/curl.log"
RIG_SOURCED_LOG="$rigTmp/sourced.log"
export RIG_CURL_LOG RIG_SOURCED_LOG

rigCall(){ ## arguments of the dispatcher -- one call in a process of its own, its sourced files in $RIG_SOURCED_LOG, its Slack methods in $RIG_CURL_LOG, its status in rigRc
	: > "$RIG_CURL_LOG" ; : > "$RIG_SOURCED_LOG"
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" bash "$rigTools" "$@" ) \
		> "$rigTmp/call.out" 2> "$rigTmp/call.err" < /dev/null ; rigRc=$?
}
rigReached(){ ## the Slack method the call must have asked of the fake -- `reached` or `not-reached`
	LC_ALL=C grep -q -x -F "$1" "$RIG_CURL_LOG" && printf reached || printf not-reached
}

echo "-- 1. the operations, called by the stub of the member --"
rigOne(){ ## operation, its include, the Slack method it must reach, the stub's arguments after the member
	local oneOp="$1" onePiece="$2" oneMethod="$3"
	shift 3
	rigCall "--slack-$oneOp" "$rigMember" "$@"
	[ -z "${RIG_DEBUG:-}" ] || { echo "== $oneOp rc=$rigRc methods: $( LC_ALL=C tr '\n' ' ' < "$RIG_CURL_LOG" )" ; LC_ALL=C head -4 "$rigTmp/call.err" | LC_ALL=C cut -c1-300 ; }
	rigAssert "$oneOp: the call reached $oneMethod" "$( rigReached "$oneMethod" )" reached
	rigAssert "$oneOp: it sourced the router and its own include, and no other of the family" "$( rigClassify "$RIG_SOURCED_LOG" "$onePiece$( [ "$oneOp" != file-fetch ] || printf ' %s' "$rigAlsoFileFetch" )" own-required )" ok
}
rigOne read "$rigPieceRead" conversations.history CRIG00001
rigOne search-messages "$rigPieceSearch" search.messages CRIG00001 --comms-since-utime 1700000000
rigOne react "$rigPieceReact" reactions.add CRIG00001:1700000000.000100 eyes
rigOne delete-message "$rigPieceDelete" chat.delete CRIG00001:1700000000.000100
rigOne edit-message "$rigPieceEdit" chat.update CRIG00001:1700000000.000100 RIG-BODY
rigOne file-info "$rigPieceFileInfo" files.info F0RIG00001
rigOne file-fetch "$rigPieceFileFetch" files.info F0RIG00001 "$rigTmp/fetched.txt"
rigOne file-share "$rigPieceFileShare" files.getUploadURLExternal CRIG00001 --from-file "$rigTmp/share.txt"
rigOne send-message "$rigPieceSend" chat.postMessage CRIG00001 RIG-BODY

echo "-- 2. the stubs, with --print-required-scopes --"
rigScopes(){ ## -- the scopes the last call printed, on one line
	LC_ALL=C tr '\n' ' ' < "$rigTmp/call.out" | LC_ALL=C sed 's/ $//'
}
rigStubs(){ ## operation, its include, the scopes it prints
	rigCall "--client-comms-slack-$1" --print-required-scopes
	rigAssert "client stub $1: the router and at most its own include, no other of the family; the scopes it has always printed; ended 0" \
		"$( rigClassify "$RIG_SOURCED_LOG" "$2" own-optional ):$rigRc:$( rigScopes )" "ok:0:$3"
	rigCall "--slack-$1" --print-required-scopes
	rigAssert "member stub $1: the same" "$( rigClassify "$RIG_SOURCED_LOG" "$2" own-optional ):$rigRc:$( rigScopes )" "ok:0:$3"
}
rigStubs read "$rigPieceRead" 'channels:read channels:history groups:read groups:history im:read im:history mpim:read mpim:history im:write'
rigStubs search-messages "$rigPieceSearch" 'search:read'
rigStubs react "$rigPieceReact" 'reactions:write reactions:read im:write'
rigStubs delete-message "$rigPieceDelete" 'chat:write im:write'
rigStubs edit-message "$rigPieceEdit" 'chat:write im:write'
rigStubs file-info "$rigPieceFileInfo" 'files:read'
rigStubs file-fetch "$rigPieceFileFetch$( [ -z "$rigAlsoFileFetch" ] || printf ' %s' "$rigAlsoFileFetch" )" 'files:read'
rigStubs file-share "$rigPieceFileShare" 'files:write chat:write im:write channels:read im:read'
rigStubs send-message "$rigPieceSend" "chat:write users:read channels:read channels:join|channels:write im:write mpim:write"

echo "-- 3. the cheap load every Wait makes --"
rigCall --intern-op-comms-slack-read --print-required-scopes
rigAssert "the pair is answered, and by the router alone" "$rigRc:$( rigScopes ):$( rigClassify "$RIG_SOURCED_LOG" "" own-optional )" \
	"0:channels:read channels:history groups:read groups:history im:read im:history mpim:read mpim:history im:write:ok"
rigAssert "and it parsed no more than the router's lines (limit $rigRouterLimit)" \
	"$( [ "$( rigLinesOfFamily "$RIG_SOURCED_LOG" )" -le "$rigRouterLimit" ] && printf within || printf 'over: %s lines parsed' "$( rigLinesOfFamily "$RIG_SOURCED_LOG" )" )" within
printf 'quiet\n' > "$rigTmp/quiet.txt"
rigCall --wait-for-input --team-member "$rigMember" --wait-source "file:$rigTmp/quiet.txt" --wait-timeout 2 --wait-poll-interval 1
rigAssert "control of the wait: it ran its rounds" "$( LC_ALL=C grep -c 'poll round' "$rigTmp/call.out" | LC_ALL=C tr -d ' ' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "ran" : "did-not-run" ; }' )" ran
rigAssert "a Wait over a file source sourced nothing of the family but the router, which it may leave unloaded" "$( rigClassify "$RIG_SOURCED_LOG" "" router-optional )" ok
rigAssert "and its cheap load parsed no more than the router's lines (limit $rigRouterLimit)" \
	"$( [ "$( rigLinesOfFamily "$RIG_SOURCED_LOG" )" -le "$rigRouterLimit" ] && printf within || printf 'over: %s lines parsed' "$( rigLinesOfFamily "$RIG_SOURCED_LOG" )" )" within

echo "-- 4. the control: the arms split out already --"
rigControl(){ ## operation, its include, the scopes it prints
	rigCall "--intern-op-comms-slack-$1" --print-required-scopes
	rigAssert "control, intern arm $1: the router and its own include, no other of the family; the scopes; ended 0" \
		"$( rigClassify "$RIG_SOURCED_LOG" "$2" own-required ):$rigRc:$( rigScopes )" "ok:0:$3"
	rigStubs "$1" "$2" "$3"
}
rigControl presence-status "$rigPiecePresence" 'rtm:stream users:read'
rigControl socket-status "$rigPieceSocket" 'app_mentions:read'
rigControl profile-get "$rigPieceProfile" 'users.profile:read users.profile:write users:read users:write dnd:read dnd:write'

echo "-- 5. the first search of a process --"
rigCall --slack-search-messages "$rigMember" CRIG00001 --comms-since-utime 1700000000
rigAssert "a first search in a fresh process: ended 0, and asked search.messages once" \
	"$rigRc:$( LC_ALL=C grep -c -x 'search.messages' "$RIG_CURL_LOG" | LC_ALL=C tr -d ' ' )" "0:1"
## The control: the same search in a process that has already loaded the router once, as a Wait does with its cheap load. The router file is
## then whole in the process, whatever its order, so a search that fails only for its order runs here.
: > "$RIG_CURL_LOG"
( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
	MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" \
	bash -c '. "$1" ; set +e ; . "$2" --intern-op-comms-slack-read --print-required-scopes > /dev/null ; DistroAgentsTools --slack-search-messages "$3" CRIG00001 --comms-since-utime 1700000100 > /dev/null ; echo "rc=$?"' \
	rig "$rigTools" "$rigRouterCopy" "$rigMember" ) > "$rigTmp/loaded.out" 2> "$rigTmp/loaded.err" < /dev/null
rigAssert "control, the same search in a process that loaded the router before: ended 0, and asked search.messages once" \
	"$( LC_ALL=C sed -n 's/^rc=//p' "$rigTmp/loaded.out" ):$( LC_ALL=C grep -c -x 'search.messages' "$RIG_CURL_LOG" | LC_ALL=C tr -d ' ' )" "0:1"

echo "-- 5b. a finding beside the split: the search arm loads the comms cache it files its answer in --"
if [ -z "${RIG_FINDINGS:-}" ] ; then
	echo "   skipped: a finding beside the split, kept out of it by the build owner (RIG_FINDINGS=1 runs it); filed to magic-coordinator as inquiry-20261102T1700Z-search-arm-never-loads-comms-cache"
else
	rigAssert "a first search in a fresh process left no \"command not found\" on its error stream: $( LC_ALL=C sed -n 's/.*: \([A-Za-z]*\): command not found.*/\1/p' "$rigTmp/call.err" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" \
		"$( LC_ALL=C grep -c 'command not found' "$rigTmp/call.err" | LC_ALL=C tr -d ' ' )" 0
	rigAssert "control: nor did the same search in a process that loaded the router before: $( LC_ALL=C sed -n 's/.*: \([A-Za-z]*\): command not found.*/\1/p' "$rigTmp/loaded.err" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" \
		"$( LC_ALL=C grep -c 'command not found' "$rigTmp/loaded.err" | LC_ALL=C tr -d ' ' )" 0
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK PATH ISOLATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_PATH_ISOLATION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
