#!/usr/bin/env bash
## AgentsSessionPrintbackDismissalCheck — behavioural check on dismissal and handback over the root-native
## printback channel of the root-harness epic (F2.3), run rather than read: one root session and one helper,
## over printback only, with no Slack call and no thread. Held, one case per statement:
##
##   S1. A HELPER'S REPORT REACHES THE ROOT OVER THE PRINTBACK CHANNEL. A root session is minted by a real
##       `--intern-mcp-server --run` process (RootSession), and a helper is dispatched into it by the spawn
##       proxy as the root's own session env has it. Both session addresses resolve to the session's printback
##       channel -- `session-current` for the root and the helper, `session-parent` for the helper -- and the
##       helper's served SubagentHandback (its default target is session-parent) is recorded as a printback
##       block of the session's one chat file, its conversation the channel-id and its origin `printback`
##       (the helper's join records before it as the origin `notice` block F3.3 adds). The root's
##       served Wait returns RECEIVED with that block, and a second Wait returns TIMEOUT: delivered once.
##
##   S2. THE ROOT'S DISMISSAL REACHES THE HELPER, AND ITS WAIT RETURNS DISMISSED. The root's served
##       SendMessage sends the one word DISMISSED to session-current, addressed to the helper, and it is
##       recorded on the same channel and file. The helper's served Wait returns `WAIT-RESULT: DISMISSED`,
##       naming the root as who dismissed it, from the chat block alone; its next Wait returns DISMISSED at
##       once, and the session keeps the mark. AND IT HOLDS WITH A CONVERSATION PRESENT: a second printback
##       session carries a conversation thread in its run (the record and MDAT_CONVERSATION_THREADS a spawn
##       writes), and its bare Wait's default source is still `chat:<session>` alone -- the kind decides
##       the channel before any Slack source is considered -- so the dismissal placed on the chat arrives
##       as DISMISSED, the wait's own filters name no Slack source, and no Slack call is made.
##
##   S3. THE DISPATCH STATES THE CHANNEL KIND IN USE. The dispatch the helper is handed names the channel
##       kind -- `channel kind: printback` -- and the channel-id it is named by, `printback:<session>`, in
##       place of a session thread; and the spawn opens no thread, so no `session.thread` exists in the
##       session's folder. The spawn's own result names the root's session as the one the helper is in.
##
## NO SLACK CALL AND NO THREAD, held throughout: the fake curl is never reached (there is no `calls` file at
## all), no `session.thread` is opened, no outbox or inbox is left, exactly one session chat file exists in
## the workspace, and the only messages recorded there are the two the feature puts there.
##
## THE RIG ORIGIN. Every call runs the package COPY in this rig (never the tree under test):
## `origin/myx/myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked READ-ONLY
## beside it -- never a mute stand-in. The workspace is the rig's own folder, and both sides are real
## `--intern-mcp-server --run` processes on ONE session: the root's carries the minted session (RootSession),
## the helper's carries the spawn record of the run dispatched into it. One server process per exchange, as
## the root of a real chat is a new process per turn: the server is line-driven, and a served Wait holds the
## wire for its own bound, so a call that must wait is its own process. What the check orders is what a real
## root and helper do anyway: each takes its floor before anything is addressed to it, the report comes in,
## the dismissal goes out.
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee, and it logs
## every call it is given), a fake console records the dispatch and starts no model, every workspace is a
## folder of the rig's own, and no model CLI is started.
##
## Red recipe: run this check against a COPY of the RECEIVED tree -- the tree before F2.3 -- with only this
## check added to its `sh-test`. Nothing else is changed. S3's dispatch assertions fail first, because the
## spawn proxy still hands the helper `session_thread_ts: none -- the opening post failed ...` and opens no
## thread knowledge of any kind; S1 fails where the feature starts: `session-parent` names nowhere ("the
## parent session ... has no recorded thread"), so the served SubagentHandback is refused and no block is
## recorded, and the root's Wait finds nothing; S2 fails behind it, because there is no DISMISSED block to
## deliver. The conversation fixture fails on its own first assertion there too: a printback session's bare
## Wait watches the Slack conversation it continues (`slack:<channel>:<ts>:conversation`) instead of
## `chat:<session>`, and the fake curl is reached. The red is the FEATURE ABSENT (the printback session
## address, the default wait source, the dispatch line), never a check that did not run: `rigRefuse` stops
## the check at its first unreachable subject. On the BUILT tree before this feature's ordering fix the
## conversation fixture alone is red, on the default sources -- the fix's own red: the printback branch sat
## behind "no conversation", so a printback session that continues one answered with the Slack source.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigFixtures="$rigPackage/sh-test/check-fixtures"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigHarness" "$rigField" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionPrintbackDismissalCheck )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigBin="$rigTmp/bin"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
rigWs="$rigTmp/ws"
rigScn="$rigTmp/slack"
rigRootMember="magic-coordinator"
rigHelperMember="rig-helper"
mkdir -p "$rigOrigin/myx" "$rigBin" "$rigHome" "$rigSkills/$rigRootMember" "$rigSkills/$rigHelperMember" \
	"$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScn" || rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
rigRigPackage="$rigOrigin/myx/myx.distro-agents"
rigRigTool="$rigRigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRigHarness="$rigRigPackage/sh-lib/harness/AgentsUniversalHarness.sh"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
printf -- '---\nname: %s\n---\nrig root member\n' "$rigRootMember" > "$rigSkills/$rigRootMember/$rigRootMember.basic.md"
printf -- '---\nname: %s\n---\nrig helper member\n' "$rigHelperMember" > "$rigSkills/$rigHelperMember/$rigHelperMember.basic.md"
## The Slack settings are here on purpose: any Slack path taken would find them and reach the fake curl, whose
## log this check asserts empty. The channel is one the fake answers for, so a stray call cannot fail silently.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The console the spawn proxy launches: it records the dispatch it is handed and starts no model. It names
## --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy greps for before it launches anything.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: records the dispatch and marks the launch.' \
	'cat > "$RIG_SCENARIO/dispatch"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigCount(){ ## file, pattern -- matching lines, 0 when the file is absent
	local rigCountText=""
	rigCountText="$( LC_ALL=C grep -c "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${rigCountText:-0}"
}
rigTextCount(){ ## text, then the grep options and the pattern -- matching lines, 0 when none
	local rigTextCountText="$1"
	shift
	rigTextCountText="$( printf '%s\n' "$rigTextCountText" | LC_ALL=C grep -c "$@" 2> /dev/null )" || :
	printf '%s' "${rigTextCountText:-0}"
}
rigExists(){ ## path -- `yes` when it is there, `no` otherwise
	[ -e "$1" ] && printf yes || printf no
}

## ---- wire readers, as the root-session checks read their servers ----
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2> /dev/null || :
}
rigText(){ ## answer line file -- the first text part of the result
	rigValue "$1" result.content.0.text
}
rigIsError(){ ## answer line file -- yes when the call was refused
	case "$( rigValue "$1" result.isError )" in
		true) printf yes ;;
		*)    [ -n "$( rigValue "$1" error.message )" ] && printf yes || printf no ;;
	esac
}
rigFieldOf(){ ## text, key -- the value of the `<key>: ` line, first one
	printf '%s\n' "$1" | LC_ALL=C sed -n "s/^$2: //p" | head -n 1
}
rigFirstLine(){ ## text -- its first line
	printf '%s\n' "$1" | LC_ALL=C sed -n '1p'
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
}
## One real server process: its stdin read to the end, its wire kept. <helper> non-empty gives it the helper's
## identity and session env, as a spawn hands its run; empty, the root's, which adopts the minted session.
rigServer(){ ## wire file, workspace, scenario, helper session/spawn words (empty: the root's server), conversation threads (optional)
	mkdir -p "$2/.local/temp" "$2/.local/.agents" || rigRefuse "cannot make the workspace $2"
	if [ -n "$4" ] ; then
		env -u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN -u MDAT_SPAWN_AGENT \
			-u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
			${6:+-u MDAT_CONVERSATION_THREADS} \
			MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
			MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" RIG_CHAT="$3/chat" PATH="$rigBin:$PATH" \
			MDAT_SPAWN_AGENT="$rigHelperMember" MDAT_SESSION_ID="$4" MDAT_SPAWN_SESSION_ID="$5" \
			${6:+MDAT_CONVERSATION_THREADS="$6"} \
			bash "$rigRigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
		return 0
	fi
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" RIG_CHAT="$3/chat" PATH="$rigBin:$PATH" \
		bash "$rigRigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigSend(){ ## json line, id -- write it to the server, wait until that request is answered
	printf '%s\n' "$1"
	rigWaitAt=0
	while ! LC_ALL=C grep -q "\"id\":$2," "$rigServerWire" 2> /dev/null && [ "$rigWaitAt" -lt 4000 ] ; do
		sleep 0.1
		rigWaitAt=$(( rigWaitAt + 1 ))
	done
}
rigStarted(){ ## wire file, label -- refuse when the server never answered initialize
	local rigStartedAnswer=""
	rigStartedAnswer="$( rigReply "$1" 1 )"
	[ -s "$rigStartedAnswer" ] || {
		echo "-- $2: the server answered no initialize, so its stderr follows --" >&2
		sed 's/^/    /' "$1.err" >&2
		rigRefuse "$2: the server never started"
	}
}
rigInit(){ printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' ; }
rigRootCall(){ ## id, operation -- one RootSession request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}' "$1" "$2"
}
rigRootAdopt(){ ## id, session, token -- the RootSession adopt that makes a new server carry the minted session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"adopt","session":"%s","token":"%s"}}}' "$1" "$2" "$3"
}
rigWaitCall(){ ## id, timeout -- one served Wait, default mode, on this run's session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Wait","arguments":{"timeout":%s}}}' "$1" "$2"
}
rigSendMessageCall(){ ## id, message, address to -- one served SendMessage, to session-current
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"SendMessage","arguments":{"to":"session-current","message":"%s","address_to":"%s"}}}' "$1" "$2" "$3"
}
rigHandbackCall(){ ## id, outcome -- one served SubagentHandback, its default target (session-parent)
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"SubagentHandback","arguments":{"outcome":"%s"}}}' "$1" "$2"
}

## ---- the chat file and the session's own records, as the check reads them ----
rigSessionDir(){ printf '%s' "${2:-$rigWs}/.local/agents/sessions/$1" ; }
rigChatFile(){ printf '%s/session.chat' "$( rigSessionDir "$1" "${2:-}" )" ; }
rigHeaders(){ ## chat file -- how many header lines it holds, `no-file` when there is none
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; } END { print count + 0 ; }' "$1"
}
rigHeader(){ ## chat file, N -- the Nth header line without its time
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; if ( count == want ) { sub(/^[^ ]* /, "") ; print ; exit ; } }' "$1"
}
rigBody(){ ## chat file, N -- the body of the Nth block, blank lines trimmed at its end
	[ -f "$1" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z .* -> .*:$/ { count++ ; inBlock = ( count == want ) ; if ( inBlock ) { next ; } }
		inBlock { lines[++n] = $0 }
		END { while ( n > 0 && lines[n] == "" ) { n-- ; } for ( i = 1 ; i <= n ; i++ ) { print lines[i] ; } }' "$1"
}
rigIndex(){ ## chat file, N -- its index line, fields 1..6 tab-separated, space-joined
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { print $1, $2, $3, $4, $5, $6 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigIndexKind(){ ## chat file, N -- its index line without the header line number: block, ts, conversation, origin, seen
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { print $1, $2, $3, $4, $6 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index" 2> /dev/null
}
rigIndexCount(){ ## chat file -- how many index lines it has
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 ; }' "$1.index"
}
rigChats(){ ## workspace -- every session chat file in it, one a line
	find "$1/.local/agents/sessions" -name 'session.chat' -type f 2> /dev/null | LC_ALL=C sort || :
}
rigThreadFile(){ ## session id -- `thread` when the session has a session.thread, `none` otherwise
	[ ! -f "$( rigSessionDir "$1" )/session.thread" ] && printf none || printf thread
}
rigSlackReached(){ ## `file` when the fake curl was reached at all, `none` when it never was
	[ -f "$1/calls" ] && printf file || printf none
}
rigSpawned(){ ## session id -- the spawn records naming that session, `id|owner` a line, sorted
	local rigSpawnRecord
	for rigSpawnRecord in "$rigWs"/.local/agents/spawned/*/*.spawn.md ; do
		[ -f "$rigSpawnRecord" ] || continue
		LC_ALL=C grep -qx -F "session-id: $1" "$rigSpawnRecord" || continue
		printf '%s|%s\n' "${rigSpawnRecord##*/}" "$( LC_ALL=C sed -n 's/^owner: //p' "$rigSpawnRecord" | head -1 )"
	done | LC_ALL=C sort
}
rigSpawnIdOf(){ ## the spawn id of the one helper record in the session, empty for none
	local rigOneRecord=""
	for rigOneRecord in "$rigWs"/.local/agents/spawned/*/*.spawn.md ; do
		[ -f "$rigOneRecord" ] || continue
		LC_ALL=C grep -qx -F "session-id: $1" "$rigOneRecord" || continue
		LC_ALL=C sed -n 's/^spawn-id: //p' "$rigOneRecord" | head -1
		return 0
	done
}
## The resolver, sourced the way an operation's include sources it: "rc=<n> " and what it printed, its lines
## joined by |. <helper session> non-empty sets the helper's env; empty, the root's.
rigResolve(){ ## helper session (empty: the root's), spawn id, target
	local rigResolveRc=0 rigResolveOut=""
	(
		set +u
		unset MDAT_SESSION_THREAD MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID CLAUDE_CODE_SESSION_ID MDAT_SPAWN_AGENT
		export MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin"
		[ -z "$1" ] || export MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="$2" MDAT_SPAWN_AGENT="$rigHelperMember"
		[ -n "$1" ] || export MDAT_SPAWN_SESSION_ID="$rigRootSession"
		. "$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsSlack.include" definitions-only
		rigResolveOut="$( DistroAgentsToolsResolveTarget "$3" )" || rigResolveRc=$?
		printf 'rc=%s %s' "$rigResolveRc" "$( printf '%s' "$rigResolveOut" | LC_ALL=C tr '\n' '|' )"
	)
}

## A direct call, outside any server, as F2.2's check makes one: the tool with the caller's env.
rigDirectIn(){ ## workspace, scenario, session id (empty: none), then the tool's arguments
	local rigDirectWs="$1" rigDirectSc="$2" rigDirectId="$3"
	shift 3
	( cd "$rigDirectWs" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigDirectWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_READER=off RIG_SCENARIO="$rigDirectSc" ${rigDirectId:+MDAT_SESSION_ID=$rigDirectId} \
		bash "$rigRigTool" "$@" )
}
## A bare Wait's default sources, asked of the one function the harness and the operation both ask
## (AgentsToolsWaitDefaultSources), under a run's env: printed as it answered, `<nothing>` where it answers none.
rigDefaultSources(){ ## workspace, session, spawn id, conversation threads (optional)
	local rigDefaultsOut=""
	(
		cd "$1" && set +u
		unset MDAT_SESSION_THREAD MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID CLAUDE_CODE_SESSION_ID MDAT_SPAWN_AGENT MDAT_CONVERSATION_THREADS
		export MMDAPP="$1" MDLT_ORIGIN="$rigOrigin" MDAT_SESSION_ID="$2" MDAT_SPAWN_SESSION_ID="$3" MDAT_SPAWN_AGENT="$rigHelperMember"
		[ -z "${4:-}" ] || export MDAT_CONVERSATION_THREADS="$4"
		. "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		rigDefaultsOut="$( AgentsToolsWaitDefaultSources 2> /dev/null )" || rigDefaultsOut=""
		printf '%s' "${rigDefaultsOut:-<nothing>}"
	)
}

## ---- 1. the root session: a real server mints it ----
echo "-- the root session: minted by RootSession through a real server process --"
rigRootWire="$rigTmp/wire-root-mint"
: > "$rigRootWire"
rigServerWire="$rigRootWire"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootCall 2 mint )" 2
} | rigServer "$rigRootWire" "$rigWs" "$rigScn" ""
rigStarted "$rigRootWire" "the mint server"
rigMintText="$( rigText "$( rigReply "$rigRootWire" 2 )" )"
rigRootSession="$( rigFieldOf "$rigMintText" SESSION )"
rigRootToken="$( rigFieldOf "$rigMintText" TOKEN )"
[ -n "$rigRootSession" ] && [ -n "$rigRootToken" ] || rigRefuse "the RootSession mint printed no session id and token, so nothing below would be measured: $rigMintText"
rigChat="$( rigChatFile "$rigRootSession" )"
rigAssert "the minted root session is the root-harness one, with the one chat record folder" "$( rigExists "$( rigSessionDir "$rigRootSession" )" ):$( rigExists "$( rigSessionDir "$rigRootSession" )/root-session.token" )" "yes:yes"

## ---- 2. the dispatch: one helper into the root's session ----
echo "-- S3: the dispatch into the root session, as the root's own session env makes it --"
( cd "$rigWs" && env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigHome" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" RIG_CHAT="$rigScn/chat" \
	MDAT_SPAWN_SESSION_ID="$rigRootSession" MDAT_SPAWN_AGENT="$rigRootMember" \
	bash "$rigRigTool" --intern-op-agent-spawn-proxy "$rigHelperMember" --from-stdin --dispatch-doc:none \
		--context Agent --calling-member "$rigRootMember" --wait ) > "$rigTmp/spawn.out" 2> "$rigTmp/spawn.err" <<< "RIG-TASK dispatch this helper into the root session"
rigSpawnRc=$?
[ -f "$rigScn/dispatch" ] || rigRefuse "the fake console never received a dispatch, so nothing of S3 would be measured: $( LC_ALL=C grep 'ERROR' "$rigTmp/spawn.out" "$rigTmp/spawn.err" | head -2 | LC_ALL=C tr '\n' ' ' )"
rigDispatch="$( cat "$rigScn/dispatch" )"
rigSpawnSession="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigTmp/spawn.out" | head -1 )"
rigSpawnId="$( rigSpawnIdOf "$rigRootSession" )"
[ -n "$rigSpawnId" ] || rigRefuse "the spawn made no record in the root session, so the helper could not be served: $( head -3 "$rigTmp/spawn.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the spawn succeeds and puts the helper in the root's session" "$rigSpawnRc:$rigSpawnSession" "0:$rigRootSession"
rigAssert "the helper is a run of the root session, and of it only" "$( rigSpawned "$rigRootSession" )" "$rigSpawnId.spawn.md|$rigHelperMember"
rigAssert "the dispatch names the channel kind in use" "$( rigTextCount "$rigDispatch" -- 'channel kind: printback' )" 1
rigAssert "and the channel-id the kind is named by" "$( rigTextCount "$rigDispatch" -F -- "printback:$rigRootSession" )" 1
rigAssert "the dispatch hands over no session thread" "$( rigTextCount "$rigDispatch" -- '^session_thread_ts: none' )" 1
rigAssert "the spawn opened no session thread" "$( rigThreadFile "$rigRootSession" )" none
rigAssert "and made no Slack call: the fake curl is never reached at all" "$( rigSlackReached "$rigScn" )" none

## ---- 3. S1: the report over printback ----
echo "-- S1: the helper's report reaches the root over the printback channel --"
rigAssert "the helper's session-parent resolves to the session's printback channel" \
	"$( rigResolve "$rigRootSession" "$rigSpawnId" session-parent )" "rc=0 CHANNEL=printback:$rigRootSession|THREAD_TS=|PARENT_SESSION_ID=$rigRootSession"
rigAssert "the helper's session-current resolves to it too" \
	"$( rigResolve "$rigRootSession" "$rigSpawnId" session-current )" "rc=0 CHANNEL=printback:$rigRootSession|THREAD_TS="
rigAssert "and so does the root's own session-current" \
	"$( rigResolve "" "" session-current )" "rc=0 CHANNEL=printback:$rigRootSession|THREAD_TS="
rigAssert "a message ts after either name is refused, naming the kind" \
	"$( rigResolve "$rigRootSession" "$rigSpawnId" "session-parent:1700000001.000001" | LC_ALL=C cut -c1-5 )" "rc=3 "

## The root's own floor is set before the report exists: what was there at first contact is not new to it.
rigRootWait1="$rigTmp/wire-root-wait1"
: > "$rigRootWait1"
rigServerWire="$rigRootWait1"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootAdopt 2 "$rigRootSession" "$rigRootToken" )" 2
	rigSend "$( rigWaitCall 3 0 )" 3
} | rigServer "$rigRootWait1" "$rigWs" "$rigScn" ""
rigStarted "$rigRootWait1" "the root's first wait server"
rigWait1Text="$( rigText "$( rigReply "$rigRootWait1" 3 )" )"
rigAssert "the root's Wait on the empty record is a TIMEOUT, not an error" "$( rigFirstLine "$rigWait1Text" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"

## The helper's floor is set the same way, before anything is addressed to it.
rigHelperWait1="$rigTmp/wire-helper-wait1"
: > "$rigHelperWait1"
rigServerWire="$rigHelperWait1"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigWaitCall 2 0 )" 2
} | rigServer "$rigHelperWait1" "$rigWs" "$rigScn" "$rigRootSession" "$rigSpawnId"
rigStarted "$rigHelperWait1" "the helper's first wait server"
rigHelperWait1Text="$( rigText "$( rigReply "$rigHelperWait1" 2 )" )"
rigAssert "the helper's Wait on the empty record is a TIMEOUT, not an error" "$( rigFirstLine "$rigHelperWait1Text" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"

## The report: the helper's own handback, its default target the parent session's channel.
rigHandbackWire="$rigTmp/wire-helper-handback"
: > "$rigHandbackWire"
rigServerWire="$rigHandbackWire"
rigReportBody="RIG-HELPER-REPORT"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigHandbackCall 2 "$rigReportBody" )" 2
} | rigServer "$rigHandbackWire" "$rigWs" "$rigScn" "$rigRootSession" "$rigSpawnId"
rigStarted "$rigHandbackWire" "the helper's handback server"
rigHandbackAnswer="$( rigReply "$rigHandbackWire" 2 )"
rigHandbackText="$( rigText "$rigHandbackAnswer" )"
rigAssert "the served SubagentHandback is not an error" "$( rigIsError "$rigHandbackAnswer" )" no
rigAssert "it names the printback channel it sent on, and it is the parent session's" \
	"$( rigTextCount "$rigHandbackText" -x -F -- "Sent to printback:$rigRootSession (the printback channel of parent session $rigRootSession) as $rigHelperMember. What the operation reported follows:" )" 1
rigAssert "it names who the report is from and to" "$( rigTextCount "$rigHandbackText" -x -F -- "$rigHelperMember -> $rigRootMember:" )" 1
rigAssert "the session keeps one chat file, the mint's" "$( rigChats "$rigWs" )" "$rigChat"
## F3.3 makes the helper's join a recorded notice of a printback session: it is block 1, origin `notice`,
## and the report is block 2. Nothing else of this check moves.
rigAssert "it holds the join notice and the report: two blocks" "$( rigHeaders "$rigChat" )" 2
rigAssert "the first is the join notice, recorded on the printback channel" \
	"$( rigIndexKind "$rigChat" 1 | LC_ALL=C awk '{ print $4 }' )" "notice"
rigAssert "the report's header names the helper and the root" "$( rigHeader "$rigChat" 2 )" "$rigHelperMember -> $rigRootMember:"
rigAssert "the body is the handback, the report in it" "$( rigTextCount "$( rigBody "$rigChat" 2 )" -F -- "$rigReportBody" )" 1
rigAssert "the report's index names the conversation as the printback channel-id, origin printback" \
	"$( rigIndexKind "$rigChat" 2 )" "2 - printback:$rigRootSession printback -"

## The root's Wait now reads it.
rigRootWait2="$rigTmp/wire-root-wait2"
: > "$rigRootWait2"
rigServerWire="$rigRootWait2"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootAdopt 2 "$rigRootSession" "$rigRootToken" )" 2
	rigSend "$( rigWaitCall 3 10 )" 3
} | rigServer "$rigRootWait2" "$rigWs" "$rigScn" ""
rigStarted "$rigRootWait2" "the root's second wait server"
rigRootWait2Text="$( rigText "$( rigReply "$rigRootWait2" 3 )" )"
rigAssert "the root's Wait returns the report RECEIVED" "$( rigFirstLine "$rigRootWait2Text" ):$( rigTextCount "$rigRootWait2Text" -F -- "$rigReportBody" )" "WAIT-RESULT: RECEIVED:1"
rigAssert "and says it arrived on the printback kind" "$( rigTextCount "$rigRootWait2Text" -x -F -- '# arrived on: printback' )" 1
rigAssert "and carries the block, addressed as the report was" "$( rigTextCount "$rigRootWait2Text" -F -- " $rigHelperMember -> $rigRootMember:" )" 1

## Delivered once: a later Wait of the root has nothing.
rigRootWait3="$rigTmp/wire-root-wait3"
: > "$rigRootWait3"
rigServerWire="$rigRootWait3"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootAdopt 2 "$rigRootSession" "$rigRootToken" )" 2
	rigSend "$( rigWaitCall 3 0 )" 3
} | rigServer "$rigRootWait3" "$rigWs" "$rigScn" ""
rigStarted "$rigRootWait3" "the root's third wait server"
rigRootWait3Text="$( rigText "$( rigReply "$rigRootWait3" 3 )" )"
rigAssert "the next Wait of the root returns TIMEOUT: the record is delivered once" \
	"$( rigFirstLine "$rigRootWait3Text" | LC_ALL=C cut -c1-20 ):$( rigTextCount "$rigRootWait3Text" -F -- "$rigReportBody" )" "WAIT-RESULT: TIMEOUT:0"

## ---- 4. S2: the dismissal over printback, and the helper's DISMISSED ----
echo "-- S2: the root's dismissal reaches the helper, and its wait returns DISMISSED --"
rigDismissWire="$rigTmp/wire-root-dismiss"
: > "$rigDismissWire"
rigServerWire="$rigDismissWire"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootAdopt 2 "$rigRootSession" "$rigRootToken" )" 2
	rigSend "$( rigSendMessageCall 3 DISMISSED "$rigHelperMember" )" 3
} | rigServer "$rigDismissWire" "$rigWs" "$rigScn" ""
rigStarted "$rigDismissWire" "the root's dismissal server"
rigDismissAnswer="$( rigReply "$rigDismissWire" 3 )"
rigDismissText="$( rigText "$rigDismissAnswer" )"
rigAssert "the root's served SendMessage is not an error" "$( rigIsError "$rigDismissAnswer" )" no
rigAssert "it sends on the session's printback channel, addressed to the helper" \
	"$( rigTextCount "$rigDismissText" -x -F -- "Sent to printback:$rigRootSession (the printback channel of this session) as $rigRootMember. What the operation reported follows:" ):$( rigTextCount "$rigDismissText" -x -F -- "$rigRootMember -> $rigHelperMember:" )" "1:1"
rigAssert "the chat file now holds three blocks: the notice, the report and the dismissal" "$( rigHeaders "$rigChat" )" 3
rigAssert "the dismissal's header names the root and the helper" "$( rigHeader "$rigChat" 3 )" "$rigRootMember -> $rigHelperMember:"
rigAssert "its body is the one word of a dismissal" "$( rigBody "$rigChat" 3 )" "DISMISSED"
rigAssert "its index line names the printback channel-id and the kind's origin" \
	"$( rigIndexKind "$rigChat" 3 )" "3 - printback:$rigRootSession printback -"

rigHelperWait2="$rigTmp/wire-helper-wait2"
: > "$rigHelperWait2"
rigServerWire="$rigHelperWait2"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigWaitCall 2 20 )" 2
} | rigServer "$rigHelperWait2" "$rigWs" "$rigScn" "$rigRootSession" "$rigSpawnId"
rigStarted "$rigHelperWait2" "the helper's dismissed wait server"
rigHelperWait2Text="$( rigText "$( rigReply "$rigHelperWait2" 2 )" )"
rigAssert "the helper's Wait returns DISMISSED" "$( rigFirstLine "$rigHelperWait2Text" )" "WAIT-RESULT: DISMISSED"
rigAssert "and names the root as who dismissed it" "$( rigTextCount "$rigHelperWait2Text" -F -- "WAIT-DISMISSED-BY: " ):$( rigTextCount "$rigHelperWait2Text" -F -- " | $rigRootMember" )" "1:1"
rigAssert "what arrived follows the outcome, as on RECEIVED" "$( rigTextCount "$rigHelperWait2Text" -x -F -- "DISMISSED" )" 1
rigAssert "the session keeps the dismissal on the helper's own store" \
	"$( rigCount "$rigWs/.local/agents/sessions/$rigSpawnId/dismissed" "| $rigRootMember$" )" 1

## Dismissed once: every later Wait is that dismissal, at once, and reads nothing.
rigHelperWait3="$rigTmp/wire-helper-wait3"
: > "$rigHelperWait3"
rigServerWire="$rigHelperWait3"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigWaitCall 2 60 )" 2
} | rigServer "$rigHelperWait3" "$rigWs" "$rigScn" "$rigRootSession" "$rigSpawnId"
rigStarted "$rigHelperWait3" "the helper's after-dismissal wait server"
rigHelperWait3Text="$( rigText "$( rigReply "$rigHelperWait3" 2 )" )"
rigAssert "the helper's next Wait returns DISMISSED at once, on its stored mark" \
	"$( rigFirstLine "$rigHelperWait3Text" ):$( rigTextCount "$rigHelperWait3Text" -F -- 'dismissed before this call' )" "WAIT-RESULT: DISMISSED:1"
rigAssert "and reads nothing: the chat file still holds three blocks" "$( rigHeaders "$rigChat" )" 3

## ---- 5. a printback session that continues a conversation: the kind decides before any Slack source ----
echo "-- a printback session carrying a conversation thread: its only default source is its chat file --"
rigConvWs="$rigTmp/conv-ws"
rigConvScn="$rigTmp/conv-slack"
rigConvThread="CRIG00001:1760000000.000101"
mkdir -p "$rigConvWs/.local/.agents" "$rigConvWs/.local/temp" "$rigConvScn" || rigRefuse "cannot make the conversation fixture's workspace"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigConvWs/.local/.agents/magic-team.agent.env"
rigConvWire="$rigTmp/wire-conv-mint"
: > "$rigConvWire"
rigServerWire="$rigConvWire"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigRootCall 2 mint )" 2
} | rigServer "$rigConvWire" "$rigConvWs" "$rigConvScn" ""
rigStarted "$rigConvWire" "the conversation fixture's mint server"
rigConvText="$( rigText "$( rigReply "$rigConvWire" 2 )" )"
rigConvSession="$( rigFieldOf "$rigConvText" SESSION )"
[ -n "$rigConvSession" ] || rigRefuse "the conversation fixture's mint printed no session, so nothing below would be measured: $rigConvText"
rigConvChat="$( rigChatFile "$rigConvSession" "$rigConvWs" )"
## The run a spawn into that session leaves: a helper of it, continuing one conversation. Staged as a spawn
## writes it (the record, and MDAT_CONVERSATION_THREADS in its environment), because the history read a real
## --conversation makes is itself a Slack call, and the no-Slack-call case is the one under test.
rigConvSpawn="rig-conv-helper-$$"
mkdir -p "$rigConvWs/.local/agents/spawned/conv-folder"
printf -- '---\nspawn-id: %s\nsession-id: %s\nparent-spawn-id: %s\nparent-session-id: %s\nparent-member: %s\nowner: %s\nstatus: spawn-started\nconversation-threads: %s\n---\n' \
	"$rigConvSpawn" "$rigConvSession" "$rigConvSession" "$rigConvSession" "$rigRootMember" "$rigHelperMember" "$rigConvThread" \
	> "$rigConvWs/.local/agents/spawned/conv-folder/$rigConvSpawn.spawn.md" || rigRefuse "cannot stage the conversation fixture's run"
rigConvSources="$( rigDefaultSources "$rigConvWs" "$rigConvSession" "$rigConvSpawn" "$rigConvThread" )"
printf '  ....  default sources with a conversation present: %s\n' "$rigConvSources"
rigAssert "a printback session that continues a conversation defaults to its chat file alone" "$rigConvSources" "chat:$rigConvSession"

## The floor is set before the dismissal, as a run's first Wait leaves it.
rigConvWait1="$rigTmp/wire-conv-wait1"
: > "$rigConvWait1"
rigServerWire="$rigConvWait1"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigWaitCall 2 0 )" 2
} | rigServer "$rigConvWait1" "$rigConvWs" "$rigConvScn" "$rigConvSession" "$rigConvSpawn" "$rigConvThread"
rigStarted "$rigConvWait1" "the conversation fixture's first wait server"
rigAssert "the helper's first Wait of that session is a TIMEOUT, not an error" "$( rigFirstLine "$( rigText "$( rigReply "$rigConvWait1" 2 )" )" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"

## The dismissal, put on the chat by the root's own send.
rigDirectIn "$rigConvWs" "$rigConvScn" "$rigConvSession" --slack-send-message "$rigRootMember" "printback:$rigConvSession" --address-to "$rigHelperMember" DISMISSED \
	> "$rigTmp/conv-dismiss.out" 2> "$rigTmp/conv-dismiss.err"
rigConvDismissRc=$?
rigAssert "the dismissal is recorded on the printback channel" "$rigConvDismissRc:$( rigHeaders "$rigConvChat" )" "0:1"
rigAssert "its header names the root and the helper" "$( rigHeader "$rigConvChat" 1 )" "$rigRootMember -> $rigHelperMember:"

rigConvWait2="$rigTmp/wire-conv-wait2"
: > "$rigConvWait2"
rigServerWire="$rigConvWait2"
{
	rigSend "$( rigInit )" 1
	rigSend "$( rigWaitCall 2 20 )" 2
} | rigServer "$rigConvWait2" "$rigConvWs" "$rigConvScn" "$rigConvSession" "$rigConvSpawn" "$rigConvThread"
rigStarted "$rigConvWait2" "the conversation fixture's dismissed wait server"
rigConvWait2Text="$( rigText "$( rigReply "$rigConvWait2" 2 )" )"
rigConvFilters="$( printf '%s\n' "$rigConvWait2Text" | LC_ALL=C sed -n 's/^# filters: //p' | head -1 )"
rigAssert "with a conversation present, the helper's Wait still returns DISMISSED from the chat" "$( rigFirstLine "$rigConvWait2Text" )" "WAIT-RESULT: DISMISSED"
rigAssert "the wait's own filters name the chat file and no Slack source" "$( rigTextCount "$rigConvFilters" -F -- "chat:$rigConvSession" ):$( rigTextCount "$rigConvFilters" -F -- 'slack:' )" "1:0"
rigAssert "the fixture's workspace holds one session chat file too" "$( rigChats "$rigConvWs" | LC_ALL=C grep -c . )" 1
rigAssert "and it reached no Slack either: the fake curl is never reached" "$( rigSlackReached "$rigConvScn" )" none

## ---- 6. no Slack call, no thread, no second record ----
echo "-- no Slack call and no thread, throughout --"
rigAssert "no Slack call was made: the fake curl is never reached at all, in either scenario" "$( rigSlackReached "$rigScn" ):$( rigSlackReached "$rigConvScn" )" "none:none"
rigAssert "no session thread was opened for the session" "$( rigThreadFile "$rigRootSession" )" none
rigAssert "the printback kind left no outbox" "$( rigExists "$( rigSessionDir "$rigRootSession" )/chat.outbox" )" no
rigAssert "and no inbox" "$( rigExists "$( rigSessionDir "$rigRootSession" )/chat.inbox" )" no
rigAssert "no Slack send log was written" "$( find "$rigWs" -name 'comms-slack-send*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "the workspace holds exactly one session chat file" "$( rigChats "$rigWs" | LC_ALL=C grep -c . )" 1
rigAssert "the report body is recorded in that one file, and the fake console's dispatch is not it" \
	"$( rigCount "$rigChat" "$rigReportBody" ):$( rigCount "$rigScn/dispatch" "$rigReportBody" )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION PRINTBACK DISMISSAL (F2.3) CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_PRINTBACK_DISMISSAL: OK (%d assertions, offline)\n' "$rigPassCount"
