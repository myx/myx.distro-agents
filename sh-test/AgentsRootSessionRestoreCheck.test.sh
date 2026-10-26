#!/usr/bin/env bash
## Behavioural check on restore (F1.3 of the root-harness epic): a NEW myx.distro MCP server
## process adopts an existing root-harness session with its id and the token mint printed, and
## serves calls as that session; a wrong token, an unknown id or a missing token is refused with
## the reason and changes nothing.
##
## Read OFF THE WIRE, from real `--intern-mcp-server --run` processes driven over stdio, the way
## AgentsRootSessionCheck and AgentsRootSessionServedCheck read theirs -- never by re-applying the
## dispatch here, which would only report that the two agree.
##
## Held, one case per statement:
##   S1. Server A mints; A ends (its process exits, its server scratch root goes). Server B, a new
##       process in the same workspace, adopts with the id and token; B serves CheckList (writing
##       into the SAME sessions/<id>/ folder A registered), Wait timeout=2 (WAIT-RESULT: TIMEOUT,
##       never the no-session refusal), Skill, and an execute script that sees
##       MDAT_SPAWN_SESSION_ID=<id>; a second mint in B returns the SAME id and token.
##   S2. A wrong token, an unknown id and a tokenless adopt are each refused with the reason;
##       after them the same server still carries NO session (info and CheckList say so, execute
##       sees no id, no root-session store exists), the session-folder and token counts are
##       unchanged, and a valid adopt afterwards still works.
##
## Also held, because F1.3 must not move them:
##   * the RootSession result shape -- mint carries SESSION/TOKEN/USE, adopt and info carry
##     SESSION/USE and never a token;
##   * pathlessness of this feature's own messages -- the RootSession results and the Wait
##     TIMEOUT carry no slash, no absolute path and no server scratch store. CheckList's
##     checklist result names the member and session and carries no path (the owner's fix-it-now;
##     S1/S2), so its exact shape is pinned rather than judged pathless;
##   * no Slack message, board item or team channel is written;
##   * a server with NO session behaves exactly as F1.2 pinned today: CheckList is listed and
##     refuses at execution with its hint, Wait refuses with today's --wait-session-id text,
##     Skill works, execute sees no id, and no session folder is made.
##
## THE RIG ORIGIN. The server loads the real sibling myx.distro-system context when it starts and
## the settings reader of myx.distro-.local when an operation reads a setting. They are linked
## READ-ONLY beside the copied package -- never a mute stand-in. The package under test is a COPY
## of whatever MDLT_ORIGIN names; the server, the tool floor, the handler and every file written
## are that copy's own.
##
## Offline, and self-contained in its scratch: a fake curl first on PATH is the whole of the
## offline guarantee, and every server run writes only under this check's own tree.
##
## Red recipe: point MDLT_ORIGIN at a COPY of the received tree in which the one line that hands
## the server's `root-session` store to the harness -- `[ -z "$mcpRootSessionId" ] || export
## MDAT_SPAWN_SESSION_ID="$mcpRootSessionId"` in
## sh-lib/mcp/AgentsTools.InternMcpRequest.include -- is removed. The adopt still succeeds (the
## store is written) but the next served calls do not carry it: CheckList answers "belongs to no
## session", Wait is refused for want of a session, and execute prints no id. Those are exactly
## the S1 assertions that fail; S2 and the no-session control stay green. Green is the received
## tree unmodified. No git, and the real tree is never written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRequest="$rigHere/mcp/AgentsTools.InternMcpRequest.include"
rigRootSession="$rigHere/mcp/AgentsTools.RootSession.include"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a
## pass, and an empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigHarness" "$rigRequest" "$rigRootSession" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootSessionRestoreCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigHome="$rigTmp/home"
rigBin="$rigTmp/bin"
rigSlack="$rigTmp/slack"
rigSkills="$rigTmp/skills"
mkdir -p "$rigOrigin/myx" \
	"$rigHome" "$rigBin" "$rigSlack" "$rigSkills/magic-coordinator" "$rigSkills/rig-skill" \
	|| rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigBin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
printf 'rig-coordinator\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf -- '---\nname: rig-skill\n---\nRIG-SKILL-MARKER\n' > "$rigSkills/rig-skill/SKILL.md"

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
rigAnswered(){ ## answer line file -- yes when the server answered that request
	[ -s "$1" ] && printf yes || printf no
}
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
rigShape(){ ## text -- the upper-case field names of its lines, one space each
	printf '%s\n' "$1" | LC_ALL=C sed -n 's/^\([A-Z][A-Z]*\):.*/\1/p' | tr '\n' ' '
}
rigBare(){ ## value -- yes when it is a bare name this package takes as a session
	case "$1" in
		''|.|..|*/*|*[[:space:]]*) printf no ;;
		*) printf yes ;;
	esac
}
rigPathless(){ ## text -- yes when it carries no slash
	case "$1" in
		*/*) printf no ;;
		*) printf yes ;;
	esac
}
rigNoAbsolute(){ ## text -- yes when it names no absolute path
	case "$1" in
		/*|*' /'*) printf no ;;
		*) printf yes ;;
	esac
}
rigHolds(){ ## text, fragment -- yes when the text holds it
	case "$1" in
		*"$2"*) printf yes ;;
		*) printf no ;;
	esac
}
rigLine(){ ## text, line -- yes when one whole line of the text is exactly it
	printf '%s\n' "$1" | LC_ALL=C grep -qx -- "$2" && printf yes || printf no
}
rigTimeout(){ ## wait result -- yes when its first line is the TIMEOUT outcome
	case "$( printf '%s\n' "$1" | head -n 1 )" in
		'WAIT-RESULT: TIMEOUT'*) printf yes ;;
		*) printf no ;;
	esac
}
rigLists(){ ## tools/list answer file, tool name -- yes when the catalogue carries it
	local rigAt=0 rigToolName=""
	while : ; do
		rigToolName="$( rigValue "$1" "result.tools.$rigAt.name" )"
		[ -n "$rigToolName" ] || { printf no ; return 0 ; }
		[ "$rigToolName" != "$2" ] || { printf yes ; return 0 ; }
		rigAt=$(( rigAt + 1 ))
	done
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
}
rigServer(){ ## wire file, workspace -- one real server run, its stdin read to the end
	mkdir -p "$2/.local" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigSlack" PATH="$rigBin:$PATH" \
		bash "$rigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigSequence(){ ## wire file, workspace, then request lines -- each sent once the one before is answered
	local seqWire="$1" seqWs="$2" seqLine="" seqId="" seqWait=0
	shift 2
	: > "$seqWire"
	for seqLine in "$@" ; do
		printf '%s\n' "$seqLine"
		seqId="${seqLine#*\"id\":}"
		seqId="${seqId%%,*}"
		seqWait=0
		while ! LC_ALL=C grep -q "\"id\":$seqId," "$seqWire" 2> /dev/null && [ "$seqWait" -lt 1200 ] ; do
			sleep 0.1
			seqWait=$(( seqWait + 1 ))
		done
	done | rigServer "$seqWire" "$seqWs"
}
rigStarted(){ ## wire file, label -- refuse when the server never answered initialize
	local started=""
	started="$( rigReply "$1" 1 )"
	[ "$( rigAnswered "$started" )" = yes ] || {
		echo "-- $2: the server answered no initialize, so its stderr follows --" >&2
		sed 's/^/    /' "$1.err" >&2
		rigRefuse "$2: the server never started"
	}
}
rigSessionDir(){ ## workspace, id -- the session's own record folder
	printf '%s' "$1/.local/agents/sessions/$2"
}
rigSessionDirs(){ ## workspace -- every session folder in it, one a line
	find "$1/.local/agents/sessions" -mindepth 1 -maxdepth 1 -type d 2> /dev/null | LC_ALL=C sort || :
}
rigTokenFiles(){ ## workspace -- its root-session token records, one a line
	find "$1/.local/agents/sessions" -name root-session.token -type f 2> /dev/null | LC_ALL=C sort || :
}
rigSpawnRecords(){ ## workspace -- how many spawn records it holds
	find "$1/.local/agents/spawned" -name '*.spawn.md' -type f 2> /dev/null | LC_ALL=C grep -c . || :
}
rigCount(){ ## file, pattern -- matching lines, 0 when the file is absent
	local rigCountText=""
	rigCountText="$( LC_ALL=C grep -c "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${rigCountText:-0}"
}
rigScratchRoots(){ ## workspace -- server scratch roots still there, one a line
	find "$1/.local/temp" -mindepth 1 -maxdepth 1 -type d -name 'agent-mcp.*' 2> /dev/null | LC_ALL=C sort || :
}
rigCall(){ ## id, operation, extra arguments JSON (empty for none) -- one RootSession request
	if [ -z "${3:-}" ] ; then
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}\n' "$1" "$2"
	else
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s",%s}}}\n' "$1" "$2" "$3"
	fi
}
rigCallTool(){ ## id, tool name, arguments JSON -- one tools/call request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
rigAssertRootSessionPathless(){ ## label, text -- the pathlessness F1.3 holds for RootSession
	rigAssert "$1 carries no path-shaped value" "$( rigPathless "$2" )" yes
	rigAssert "$1 carries no absolute path" "$( rigNoAbsolute "$2" )" yes
	rigAssert "$1 names no server scratch store" "$( rigHolds "$2" 'agent-mcp.' )" no
}
rigAssertNoSlack(){ ## label
	rigAssert "$1: no Slack post was made" "$( rigCount "$rigSlack/calls" 'chat.postMessage' )" 0
	rigAssert "$1: no Slack body was sent" "$( [ ! -s "$rigSlack/bodies" ] && printf yes || printf no )" yes
}

rigInit='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
rigListJson='{"todos":[{"content":"rig item","status":"pending","activeForm":"doing rig item"}]}'
rigMd='- [ ] rig item'

## ---- S1: A mints and ends; B adopts and serves as the same session ----
echo "-- S1: server A mints and ends; a new server B adopts and serves as that session --"
rigWs="$rigTmp/s1/ws"
rigSequence "$rigTmp/s1-a.wire" "$rigWs" \
	"$rigInit" \
	"$( rigCall 2 mint )"
rigStarted "$rigTmp/s1-a.wire" "S1 server A"

rigMintAnswer="$( rigReply "$rigTmp/s1-a.wire" 2 )"
rigAssert "A answered the mint" "$( rigAnswered "$rigMintAnswer" )" yes
rigAssert "A's mint is not an error" "$( rigIsError "$rigMintAnswer" )" no
rigMintText="$( rigText "$rigMintAnswer" )"
rigId="$( rigFieldOf "$rigMintText" SESSION )"
rigToken="$( rigFieldOf "$rigMintText" TOKEN )"
rigAssert "A's mint returned a session id" "$( [ -n "$rigId" ] && printf yes || printf no )" yes
rigAssert "the id is a bare session name" "$( rigBare "$rigId" )" yes
rigAssert "A's mint returned the token that proves it" "$( [ -n "$rigToken" ] && printf yes || printf no )" yes
rigAssert "the token is a bare value" "$( rigBare "$rigToken" )" yes
rigAssert "the mint result shape is SESSION, TOKEN, USE" "$( rigShape "$rigMintText" )" "SESSION TOKEN USE "
rigAssertRootSessionPathless "A's mint result" "$rigMintText"
rigAssert "A's mint no longer has a running scratch root" "$( rigScratchRoots "$rigWs" | LC_ALL=C grep -c . )" 0
rigAssert "A's session record folder remains" "$( [ -d "$( rigSessionDir "$rigWs" "$rigId" )" ] && printf yes || printf no )" yes
rigAssert "the token mint printed remains beside it" \
	"$( IFS= read -r rigKeptToken < "$( rigSessionDir "$rigWs" "$rigId" )/root-session.token" ; printf '%s' "${rigKeptToken:-}" )" "$rigToken"

## B is a new process in the same workspace: it adopts, then every served call must carry the
## adopted session. Calls are sent one at a time, once the one before is answered, as a host does.
rigSequence "$rigTmp/s1-b.wire" "$rigWs" \
	"$rigInit" \
	"$( rigCall 2 adopt "\"session\":\"$rigId\",\"token\":\"$rigToken\"" )" \
	"$( rigCall 3 info )" \
	"$( rigCallTool 4 CheckList "$rigListJson" )" \
	"$( rigCallTool 5 Wait '{"timeout":2}' )" \
	"$( rigCallTool 6 Skill '{"name":"rig-skill","file":"SKILL.md"}' )" \
	"$( rigCall 7 mint )" \
	"$( rigCallTool 8 execute '{"command":"printf \"%s\\n\" \"${MDAT_SPAWN_SESSION_ID:-none}\""}' )"
rigStarted "$rigTmp/s1-b.wire" "S1 server B"

rigAdoptAnswer="$( rigReply "$rigTmp/s1-b.wire" 2 )"
rigAssert "the new server answered the adopt" "$( rigAnswered "$rigAdoptAnswer" )" yes
rigAssert "the adopt is not an error" "$( rigIsError "$rigAdoptAnswer" )" no
rigAdoptText="$( rigText "$rigAdoptAnswer" )"
rigAssert "the new server adopted the id minted before it" "$( rigFieldOf "$rigAdoptText" SESSION )" "$rigId"
rigAssert "the adopt result shape is SESSION, USE" "$( rigShape "$rigAdoptText" )" "SESSION USE "
rigAssert "the adopt result never prints the token" "$( rigFieldOf "$rigAdoptText" TOKEN )" ""
rigAssertRootSessionPathless "the adopt result" "$rigAdoptText"

rigInfoAnswer="$( rigReply "$rigTmp/s1-b.wire" 3 )"
rigInfoText="$( rigText "$rigInfoAnswer" )"
rigAssert "info after the restore is not an error" "$( rigIsError "$rigInfoAnswer" )" no
rigAssert "info returns the adopted id" "$( rigFieldOf "$rigInfoText" SESSION )" "$rigId"
rigAssert "the info result shape is SESSION, USE" "$( rigShape "$rigInfoText" )" "SESSION USE "
rigAssertRootSessionPathless "the info result" "$rigInfoText"

## CheckList: the same folder A registered, as the root session's magic-coordinator.
rigChecklistAnswer="$( rigReply "$rigTmp/s1-b.wire" 4 )"
rigChecklistText="$( rigText "$rigChecklistAnswer" )"
rigAssert "the served CheckList answered" "$( rigAnswered "$rigChecklistAnswer" )" yes
rigAssert "the served CheckList is not an error" "$( rigIsError "$rigChecklistAnswer" )" no
rigAssert "it names the adopted session" "$( rigHolds "$rigChecklistText" "in session $rigId " )" yes
rigAssert "it wrote as the root session's magic-coordinator" "$( rigHolds "$rigChecklistText" 'checklist of magic-coordinator' )" yes
## The owner's fix-it-now: CheckList's result is pathless -- the member and the session, no path.
rigAssert "the checklist result is pathless: the member and the session, no path" \
	"$( rigHolds "$rigChecklistText" 'checklist of magic-coordinator' ):$( rigHolds "$rigChecklistText" '.local/agents/sessions' )" yes:no
rigAssert "the restored session's folder holds the checklist" \
	"$( [ -f "$( rigSessionDir "$rigWs" "$rigId" )/magic-coordinator.checklist.md" ] && printf yes || printf no )" yes
rigAssert "the checklist is the one the restored call wrote" \
	"$( cat "$( rigSessionDir "$rigWs" "$rigId" )/magic-coordinator.checklist.md" 2> /dev/null )" "$rigMd"

## Wait: the session's own TIMEOUT, never the no-session refusal.
rigWaitAnswer="$( rigReply "$rigTmp/s1-b.wire" 5 )"
rigWaitText="$( rigText "$rigWaitAnswer" )"
rigAssert "the served Wait answered" "$( rigAnswered "$rigWaitAnswer" )" yes
rigAssert "the served Wait is not an error" "$( rigIsError "$rigWaitAnswer" )" no
rigAssert "Wait returns TIMEOUT" "$( rigTimeout "$rigWaitText" )" yes
rigAssert "Wait is not refused for want of a session" "$( rigHolds "$rigWaitText" 'needs --wait-session-id' )" no
rigAssert "the Wait TIMEOUT carries no path-shaped value" "$( rigPathless "$rigWaitText" )" yes
rigAssert "the Wait TIMEOUT carries no absolute path" "$( rigNoAbsolute "$rigWaitText" )" yes
rigAssert "the Wait TIMEOUT names no server scratch store" "$( rigHolds "$rigWaitText" 'agent-mcp.' )" no

## Skill: the restored call reads its file.
rigSkillAnswer="$( rigReply "$rigTmp/s1-b.wire" 6 )"
rigSkillText="$( rigText "$rigSkillAnswer" )"
rigAssert "the served Skill answered" "$( rigAnswered "$rigSkillAnswer" )" yes
rigAssert "the served Skill is not an error" "$( rigIsError "$rigSkillAnswer" )" no
rigAssert "Skill read the skillset file" "$( rigHolds "$rigSkillText" 'RIG-SKILL-MARKER' )" yes

## A second mint in B: the same session, the same token, nothing new.
rigMint2Answer="$( rigReply "$rigTmp/s1-b.wire" 7 )"
rigMint2Text="$( rigText "$rigMint2Answer" )"
rigAssert "the second mint answered" "$( rigAnswered "$rigMint2Answer" )" yes
rigAssert "the second mint is not an error" "$( rigIsError "$rigMint2Answer" )" no
rigAssert "the second mint returns the same id and token" "$rigMint2Text" "$rigMintText"
rigAssert "the second mint result shape stays SESSION, TOKEN, USE" "$( rigShape "$rigMint2Text" )" "SESSION TOKEN USE "
rigAssertRootSessionPathless "the second mint result" "$rigMint2Text"

## execute: the export is the server's, not one tool's.
rigExecAnswer="$( rigReply "$rigTmp/s1-b.wire" 8 )"
rigAssert "the restored server's execute answered" "$( rigAnswered "$rigExecAnswer" )" yes
rigAssert "the restored server's execute sees the adopted session id" \
	"$( rigLine "$( rigText "$rigExecAnswer" )" "$rigId" )" yes

## Nothing else was written, and nothing was sent.
rigAssert "no console run: the restored workspace holds no spawn record" "$( rigSpawnRecords "$rigWs" )" 0
rigAssert "no session thread was opened" "$( [ ! -e "$( rigSessionDir "$rigWs" "$rigId" )/session.thread" ] && printf yes || printf no )" yes
rigAssert "no transcript pointer was written" "$( [ ! -e "$( rigSessionDir "$rigWs" "$rigId" )/transcript" ] && printf yes || printf no )" yes
rigAssert "no team data is written" "$( [ ! -e "$rigWs/.local/agents/team-data-root" ] && printf yes || printf no )" yes
rigAssert "no board item was written" "$( find "$rigWs" -path '*/board/*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssertNoSlack "restore"

## ---- S2: the three refusals, and nothing changed ----
echo "-- S2: wrong token, unknown id and tokenless adopt are refused and change nothing --"
rigUnknown="99999999-8888-7777-6666-555555555555"
rigWrong="00000000-0000-4000-8000-000000000000"
rigFoldersBefore="$( rigSessionDirs "$rigWs" | LC_ALL=C grep -c . )"
rigTokensBefore="$( rigTokenFiles "$rigWs" | LC_ALL=C grep -c . )"
rigSequence "$rigTmp/s2.wire" "$rigWs" \
	"$rigInit" \
	"$( rigCall 2 adopt "\"session\":\"$rigId\",\"token\":\"$rigWrong\"" )" \
	"$( rigCall 3 adopt "\"session\":\"$rigUnknown\",\"token\":\"$rigUnknown\"" )" \
	"$( rigCall 4 adopt "\"session\":\"$rigId\"" )" \
	"$( rigCall 5 info )" \
	"$( rigCallTool 6 CheckList "$rigListJson" )" \
	"$( rigCallTool 7 execute '{"command":"printf \"%s\\n\" \"${MDAT_SPAWN_SESSION_ID:-none}\""}' )" \
	"$( rigCall 8 adopt "\"session\":\"$rigId\",\"token\":\"$rigToken\"" )" \
	"$( rigCall 9 info )"
rigStarted "$rigTmp/s2.wire" "S2 server"

rigWrongAnswer="$( rigReply "$rigTmp/s2.wire" 2 )"
rigWrongText="$( rigText "$rigWrongAnswer" )"
rigAssert "a wrong token is refused" "$( rigIsError "$rigWrongAnswer" )" yes
rigAssert "the wrong-token refusal names the token as the reason" "$( rigHolds "$rigWrongText" 'token' )" yes
rigAssert "it says the token does not match the one mint printed" "$( rigHolds "$rigWrongText" 'does not match' )" yes
rigAssert "it does not repeat the caller's token" "$( rigHolds "$rigWrongText" "$rigWrong" )" no
rigAssert "it does not repeat the session id" "$( rigHolds "$rigWrongText" "$rigId" )" no
rigAssertRootSessionPathless "the wrong-token refusal" "$rigWrongText"

rigUnknownAnswer="$( rigReply "$rigTmp/s2.wire" 3 )"
rigUnknownText="$( rigText "$rigUnknownAnswer" )"
rigAssert "an unknown id is refused" "$( rigIsError "$rigUnknownAnswer" )" yes
rigAssert "the unknown-id refusal says the id names no adoptable session" \
	"$( rigHolds "$rigUnknownText" 'names no session this server can adopt' )" yes
rigAssert "it does not repeat the unknown id" "$( rigHolds "$rigUnknownText" "$rigUnknown" )" no
rigAssertRootSessionPathless "the unknown-id refusal" "$rigUnknownText"

rigNoTokenAnswer="$( rigReply "$rigTmp/s2.wire" 4 )"
rigNoTokenText="$( rigText "$rigNoTokenAnswer" )"
rigAssert "an id without its token is refused" "$( rigIsError "$rigNoTokenAnswer" )" yes
rigAssert "the tokenless refusal names the token as the reason" "$( rigHolds "$rigNoTokenText" 'token' )" yes
rigAssert "it says an id without its token is refused" "$( rigHolds "$rigNoTokenText" 'an id without its token is refused' )" yes
rigAssertRootSessionPathless "the tokenless refusal" "$rigNoTokenText"

## After the three refusals: no store, no session served, nothing made.
rigInfoAfterAnswer="$( rigReply "$rigTmp/s2.wire" 5 )"
rigInfoAfterText="$( rigText "$rigInfoAfterAnswer" )"
rigAssert "after the refusals info still says this server carries no session" "$( rigIsError "$rigInfoAfterAnswer" )" yes
rigAssert "and its reason is that no session is carried" "$( rigHolds "$rigInfoAfterText" 'carries no session yet' )" yes
rigCheckAfterAnswer="$( rigReply "$rigTmp/s2.wire" 6 )"
rigCheckAfterText="$( rigText "$rigCheckAfterAnswer" )"
rigAssert "after the refusals CheckList still belongs to no session" "$( rigIsError "$rigCheckAfterAnswer" )" yes
rigAssert "its refusal says there is no place to be kept" "$( rigHolds "$rigCheckAfterText" 'no place to be kept' )" yes
rigExecAfterAnswer="$( rigReply "$rigTmp/s2.wire" 7 )"
rigAssert "after the refusals execute sees no session id, so no store exists" \
	"$( rigLine "$( rigText "$rigExecAfterAnswer" )" none )" yes
rigAssert "no unknown-id session folder was made" "$( [ ! -e "$( rigSessionDir "$rigWs" "$rigUnknown" )" ] && printf yes || printf no )" yes
rigAssert "the session-folder count is unchanged" "$( rigSessionDirs "$rigWs" | LC_ALL=C grep -c . )" "$rigFoldersBefore"
rigAssert "the token-record count is unchanged" "$( rigTokenFiles "$rigWs" | LC_ALL=C grep -c . )" "$rigTokensBefore"
rigAssert "the session's own token still reads as mint printed" \
	"$( IFS= read -r rigKeptToken < "$( rigSessionDir "$rigWs" "$rigId" )/root-session.token" ; printf '%s' "${rigKeptToken:-}" )" "$rigToken"

## The same server still adopts after the refusals: nothing was broken.
rigAdoptAfterAnswer="$( rigReply "$rigTmp/s2.wire" 8 )"
rigAdoptAfterText="$( rigText "$rigAdoptAfterAnswer" )"
rigAssert "a valid adopt after the refusals is not an error" "$( rigIsError "$rigAdoptAfterAnswer" )" no
rigAssert "it adopts the same id" "$( rigFieldOf "$rigAdoptAfterText" SESSION )" "$rigId"
rigAssertRootSessionPathless "the post-refusal adopt result" "$rigAdoptAfterText"
rigInfoFinalAnswer="$( rigReply "$rigTmp/s2.wire" 9 )"
rigInfoFinalText="$( rigText "$rigInfoFinalAnswer" )"
rigAssert "info after the refusals and the adopt returns the id" "$( rigFieldOf "$rigInfoFinalText" SESSION )" "$rigId"
rigAssertRootSessionPathless "the final info result" "$rigInfoFinalText"

rigAssert "no console run: the refusal workspace holds no spawn record" "$( rigSpawnRecords "$rigWs" )" 0
rigAssert "no session thread was opened by the refusals" "$( [ ! -e "$( rigSessionDir "$rigWs" "$rigId" )/session.thread" ] && printf yes || printf no )" yes
rigAssert "no board item was written by the refusals" "$( find "$rigWs" -path '*/board/*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssertNoSlack "refusals"

## ---- S3: behaviour with no session is unchanged ----
echo "-- control: a server carrying no session behaves exactly as F1.2 pinned today --"
rigWsEmpty="$rigTmp/no-session/ws"
rigSequence "$rigTmp/s3.wire" "$rigWsEmpty" \
	"$rigInit" \
	'{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
	"$( rigCallTool 3 CheckList "$rigListJson" )" \
	"$( rigCallTool 4 Wait '{"timeout":2}' )" \
	"$( rigCallTool 5 Skill '{"name":"rig-skill","file":"SKILL.md"}' )" \
	"$( rigCallTool 6 execute '{"command":"printf \"%s\\n\" \"${MDAT_SPAWN_SESSION_ID:-none}\""}' )"
rigStarted "$rigTmp/s3.wire" "no-session server"

rigListEmpty="$( rigReply "$rigTmp/s3.wire" 2 )"
rigAssert "the no-session catalogue answered" "$( rigAnswered "$rigListEmpty" )" yes
rigAssert "the no-session catalogue carries RootSession" "$( rigLists "$rigListEmpty" RootSession )" yes
rigAssert "the no-session catalogue carries CheckList, never withheld" "$( rigLists "$rigListEmpty" CheckList )" yes
rigCheckEmptyAnswer="$( rigReply "$rigTmp/s3.wire" 3 )"
rigCheckEmptyText="$( rigText "$rigCheckEmptyAnswer" )"
rigAssert "the no-session CheckList is a tool result, not an absent tool" "$( rigValue "$rigCheckEmptyAnswer" result.isError )" true
rigAssert "it refuses at execution for want of a place" "$( rigHolds "$rigCheckEmptyText" 'this call belongs to no session yet' )" yes
rigAssert "its refusal says there is no place to be kept" "$( rigHolds "$rigCheckEmptyText" 'no place to be kept' )" yes
rigAssert "it names RootSession operation=mint" "$( rigHolds "$rigCheckEmptyText" 'RootSession operation=mint' )" yes
rigAssert "it also names operation=adopt" "$( rigHolds "$rigCheckEmptyText" 'operation=adopt' )" yes
rigAssert "it is a hint, never a denial that the tool is unoffered" "$( rigHolds "$rigCheckEmptyText" 'not offered' )" no
rigAssert "the no-session CheckList refusal carries no path-shaped value" "$( rigPathless "$rigCheckEmptyText" )" yes
rigAssert "the no-session CheckList refusal carries no absolute path" "$( rigNoAbsolute "$rigCheckEmptyText" )" yes
rigAssert "the no-session CheckList refusal names no server scratch store" "$( rigHolds "$rigCheckEmptyText" 'agent-mcp.' )" no
rigWaitEmptyAnswer="$( rigReply "$rigTmp/s3.wire" 4 )"
rigWaitEmptyText="$( rigText "$rigWaitEmptyAnswer" )"
rigAssert "the no-session Wait is refused" "$( rigIsError "$rigWaitEmptyAnswer" )" yes
## Today's refusal may carry the real SystemContext's pre-existing init line, so only the exact
## refusal is asserted here, as F1.2's check does.
rigAssert "Wait refuses exactly as today: the state needs a session" \
	"$( rigHolds "$rigWaitEmptyText" '--wait-default needs --wait-session-id, because the state it keeps or ends is the state of one session. Nothing was waited on.' )" yes
rigSkillEmptyAnswer="$( rigReply "$rigTmp/s3.wire" 5 )"
rigAssert "the no-session Skill still works" "$( rigIsError "$rigSkillEmptyAnswer" )" no
rigAssert "Skill read the skillset file with no session" "$( rigHolds "$( rigText "$rigSkillEmptyAnswer" )" 'RIG-SKILL-MARKER' )" yes
rigExecEmptyAnswer="$( rigReply "$rigTmp/s3.wire" 6 )"
rigAssert "with no session an execute call sees no session id" "$( rigLine "$( rigText "$rigExecEmptyAnswer" )" none )" yes
rigAssert "no session folder was made by the no-session server" "$( rigSessionDirs "$rigWsEmpty" | LC_ALL=C grep -c . )" 0
rigAssert "no console run: no spawn record was made with no session" "$( rigSpawnRecords "$rigWsEmpty" )" 0
rigAssert "no board item was written with no session" "$( find "$rigWsEmpty" -path '*/board/*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "no team data is written with no session" "$( [ ! -e "$rigWsEmpty/.local/agents/team-data-root" ] && printf yes || printf no )" yes
rigAssertNoSlack "no-session control"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT SESSION RESTORE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  make a new server's adopt write the session where its served calls read it" >&2
	echo "        (RootSession adopt in sh-lib/mcp/AgentsTools.RootSession.include, the" >&2
	echo "        root-session store read in sh-lib/mcp/AgentsTools.InternMcpRequest.include)," >&2
	echo "        never the assertion" >&2
	exit 1
fi
printf 'ROOT_SESSION_RESTORE: OK (%d assertions, offline: two real servers, adopt then CheckList/Wait/Skill/execute, refusals change nothing, no-session control)\n' "$rigPassCount"
