#!/usr/bin/env bash
## Behavioural check on RootSession (F1.1 of the root-harness epic, corrected 2026-10-25): the
## myx.distro MCP server serves one tool of its own, beside execute, that carries the root-harness
## session of the server instance. It serves three operations -- mint, adopt and info -- and its
## results name the system, never the filesystem. Read OFF THE WIRE, from a real server's own
## tools/list and tools/call answers, the way AgentsMcpSecondaryToolCheck reads them -- never by
## re-applying the dispatch here, which would only report that the two agree.
##
## Held, one case per statement of the corrected text:
##   S1. mint returns a minted bare session id, the token that proves it, and a short instruction on
##       where to use it -- and no result carries a path-shaped value;
##   S2. the minted session is registered, so a NEW server adopts its id with the token mint printed;
##       no transcript pointer and no team data are written;
##   S3. a second mint in the same server returns the same id and token and creates nothing new;
##   S4. adopt takes the id and the token; an id without its token, an unknown id, a wrong token and
##       an unknown operation are refused and change nothing; info returns the carried id;
##   S5. no Slack message, no board item and no team channel is written.
##
## Offline, and self-contained in its scratch: a fake curl first on PATH is the whole of the
## offline guarantee, and every server run writes only under this check's own tree. The tree under
## test is whatever MDLT_ORIGIN names -- so a red run needs the planted tree named there, not
## merely executed.
##
## THE RIG ORIGIN. The server loads the sibling myx.distro-system context when it starts, and the
## settings reader of myx.distro-.local when an operation reads a setting. A lab origin may carry
## this package alone, so this check assembles an origin of its own under its scratch: a COPY of the
## tree UNDER TEST, and a stand-in for each sibling the start needs and the origin does not carry.
## The server, the tool list, the request handler and every file the tool writes are the package's
## own; only siblings outside this wave are stood in for, and only where there is none.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a
## pass, and an empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigHere/mcp/AgentsTools.InternMcpRequest.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootSessionCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

rigOrigin="$rigTmp/origin"
rigHome="$rigTmp/home"
rigBin="$rigTmp/bin"
rigSlack="$rigTmp/slack"
mkdir -p "$rigOrigin/myx/myx.distro-system/sh-lib" "$rigOrigin/myx/myx.distro-.local/sh-lib" \
	"$rigHome" "$rigBin" "$rigSlack"
## The ground rule is a COPY, never a link: a tool of the rig that writes into its own origin
## must never reach the package under test.
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
printf '%s\n' '#!/usr/bin/env bash' \
	'## Rig stand-in for the system context: this origin may carry myx.distro-agents alone.' \
	'DistroSystemContext(){ return 0 ; }' \
	'Distro(){ return 1 ; }' \
	'Require(){ return 1 ; }' \
	'Action(){ return 0 ; }' \
	> "$rigOrigin/myx/myx.distro-system/sh-lib/SystemContext.include"
printf '%s\n' '#!/usr/bin/env bash' \
	'## Rig stand-in for the settings reader: this rig has no settings, so every read finds none.' \
	'return 0' \
	> "$rigOrigin/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigBin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"

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
rigBare(){ ## value -- yes when it is a bare name this package takes as a session
	case "$1" in
		''|.|..|*/*|*[[:space:]]*) printf no ;;
		*) printf yes ;;
	esac
}
rigPathless(){ ## text -- yes when it carries no path-shaped value (a slash)
	case "$1" in
		*/*) printf no ;;
		*) printf yes ;;
	esac
}
rigYesNo(){ ## value -- yes when non-empty
	[ -n "$1" ] && printf yes || printf no
}
rigAnswered(){ ## answer line file -- yes when the server answered that request
	[ -s "$1" ] && printf yes || printf no
}
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2> /dev/null || :
}
rigSlice(){ ## wire line file, json path, mode -- raw
	LC_ALL=C awk -v path="$2" -v mode="$3" -f "$rigField" < "$1" 2> /dev/null || :
}
rigPropsHolds(){ ## properties keys, key -- yes when the key is one of them
	printf '%s\n' "$1" | LC_ALL=C grep -qx -- "$2" && printf yes || printf no
}
rigFieldOf(){ ## text, key -- the value of the `<key>: ` line, first one
	printf '%s\n' "$1" | LC_ALL=C sed -n "s/^$2: //p" | head -n 1
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
rigCall(){ ## id, operation, extra arguments JSON (empty for none) -- one tools/call request
	if [ -z "${3:-}" ] ; then
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}\n' "$1" "$2"
	else
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s",%s}}}\n' "$1" "$2" "$3"
	fi
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
rigServer(){ ## wire file, workspace -- one real server run, its stdin read to the end
	mkdir -p "$2/.local" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_DATA_ROOT \
		-u MDAT_MCP_SERVED_MARKER \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		RIG_SCENARIO="$rigSlack" PATH="$rigBin:$PATH" \
		bash "$rigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
}
rigToolIndex(){ ## tools/list line file, tool name -- its index in result.tools, rc 1 when absent
	local rigAt=0 rigName=""
	while : ; do
		rigName="$( rigSlice "$1" "result.tools.$rigAt.name" raw )"
		[ -n "$rigName" ] || return 1
		[ "$rigName" != "\"$2\"" ] || { printf '%s' "$rigAt" ; return 0 ; }
		rigAt=$(( rigAt + 1 ))
	done
}
rigSessionDir(){ ## workspace, id -- the session's own record folder
	printf '%s' "$1/.local/agents/sessions/$2"
}
rigSessionDirs(){ ## workspace -- every session folder in it, one a line
	find "$1/.local/agents/sessions" -mindepth 1 -maxdepth 1 -type d 2> /dev/null | LC_ALL=C sort || :
}

## ---- S1: mint returns an id, the token and where to use it, and no path ----
echo "-- S1: mint returns an id, its token and a short instruction, and no path --"
rustWs="$rigTmp/s1/ws"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
	rigCall 3 mint
} | rigServer "$rigTmp/s1.wire" "$rustWs"

rustList="$( rigReply "$rigTmp/s1.wire" 2 )"
rustAt="$( rigToolIndex "$rustList" RootSession )" || rustAt=""
rigAssert "the server answered tools/list" "$( rigAnswered "$rustList" )" yes
rigAssert "the server lists a RootSession tool" "$( rigYesNo "$rustAt" )" yes
if [ -n "$rustAt" ] ; then
	rustProps="$( rigSlice "$rustList" "result.tools.$rustAt.inputSchema.properties" keys )"
	rigAssert "it declares the 'operation' argument" "$( rigPropsHolds "$rustProps" operation )" yes
	rigAssert "it declares the 'session' argument" "$( rigPropsHolds "$rustProps" session )" yes
	rigAssert "it declares the 'token' argument" "$( rigPropsHolds "$rustProps" token )" yes
	rigAssert "it declares the call's intent 'description'" "$( rigPropsHolds "$rustProps" description )" yes
	rigAssert "it requires the operation" "$( rigValue "$rustList" "result.tools.$rustAt.inputSchema.required.0" )" operation
fi
rustAnswer="$( rigReply "$rigTmp/s1.wire" 3 )"
rigAssert "the server answered the mint" "$( rigAnswered "$rustAnswer" )" yes
rustText="$( rigText "$rustAnswer" )"
rustId="$( rigFieldOf "$rustText" SESSION )"
rustToken="$( rigFieldOf "$rustText" TOKEN )"
rustUse="$( rigFieldOf "$rustText" USE )"
rigAssert "the mint is not an error" "$( rigIsError "$rustAnswer" )" no
rigAssert "it returns a session id" "$( rigYesNo "$rustId" )" yes
rigAssert "the id is a bare name" "$( rigBare "$rustId" )" yes
rigAssert "it returns the token mint printed" "$( rigYesNo "$rustToken" )" yes
rigAssert "the token is a bare value" "$( rigBare "$rustToken" )" yes
rigAssert "it returns a short instruction on where to use it" \
	"$( printf '%s\n' "$rustUse" | LC_ALL=C grep -q 'RootSession' && printf yes || printf no )" yes
rigAssert "the instruction is one line" "$( printf '%s\n' "$rustUse" | LC_ALL=C grep -c . )" 1
rigAssert "no result carries a path-shaped value" "$( rigPathless "$rustText" )" yes

## ---- S2: the minted session is registered, so a new server adopts it ----
echo "-- S2: a new server adopts the minted id with the token, and nothing else is written --"
rustWs="$rigTmp/s2/ws"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 mint
} | rigServer "$rigTmp/s2a.wire" "$rustWs"
rustMintAnswer="$( rigReply "$rigTmp/s2a.wire" 3 )"
rigAssert "the server answered the mint" "$( rigAnswered "$rustMintAnswer" )" yes
rustMintText="$( rigText "$rustMintAnswer" )"
rustId="$( rigFieldOf "$rustMintText" SESSION )"
rustToken="$( rigFieldOf "$rustMintText" TOKEN )"
rigAssert "the mint is not an error" "$( rigIsError "$rustMintAnswer" )" no
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 adopt "\"session\":\"$rustId\",\"token\":\"$rustToken\""
} | rigServer "$rigTmp/s2b.wire" "$rustWs"
rustAdoptAnswer="$( rigReply "$rigTmp/s2b.wire" 3 )"
rigAssert "a new server answered the adopt" "$( rigAnswered "$rustAdoptAnswer" )" yes
rustAdoptText="$( rigText "$rustAdoptAnswer" )"
rigAssert "the adopt is not an error" "$( rigIsError "$rustAdoptAnswer" )" no
rigAssert "the new server adopted the id minted before it" "$( rigFieldOf "$rustAdoptText" SESSION )" "$rustId"
rigAssert "the session's own record folder exists" "$( [ -d "$( rigSessionDir "$rustWs" "$rustId" )" ] && printf yes || printf no )" yes
rigAssert "the token mint printed is kept for a later process" \
	"$( [ -s "$( rigSessionDir "$rustWs" "$rustId" )/root-session.token" ] && IFS= read -r rustKept < "$( rigSessionDir "$rustWs" "$rustId" )/root-session.token" ; printf '%s' "${rustKept:-}" )" "$rustToken"
rigAssert "no transcript pointer is written" "$( [ ! -e "$( rigSessionDir "$rustWs" "$rustId" )/transcript" ] && printf yes || printf no )" yes
rigAssert "no team data is written" "$( [ ! -e "$rustWs/.local/agents/team-data-root" ] && printf yes || printf no )" yes
rigAssert "the adopt result carries no path" "$( rigPathless "$rustAdoptText" )" yes

## ---- S3: a second mint in the same process returns the same id and token ----
echo "-- S3: a second mint in the same server returns the same id and token and creates nothing --"
rustWs="$rigTmp/s3/ws"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 mint
	rigCall 4 mint
} | rigServer "$rigTmp/s3.wire" "$rustWs"
rustFirstAnswer="$( rigReply "$rigTmp/s3.wire" 3 )"
rustSecondAnswer="$( rigReply "$rigTmp/s3.wire" 4 )"
rigAssert "the server answered both mints" "$( rigAnswered "$rustFirstAnswer" ):$( rigAnswered "$rustSecondAnswer" )" "yes:yes"
rustFirst="$( rigText "$rustFirstAnswer" )"
rustSecond="$( rigText "$rustSecondAnswer" )"
rigAssert "both mints returned the facts" "$( [ -n "$rustFirst" ] && [ -n "$rustSecond" ] && printf yes || printf no )" yes
rigAssert "the second mint returns the same id and token" "$rustSecond" "$rustFirst"
rigAssert "the second mint created no second session folder" "$( rigSessionDirs "$rustWs" | LC_ALL=C grep -c . )" 1
rigAssert "the second mint created no second token record" "$( find "$rustWs/.local/agents/sessions" -name root-session.token -type f 2> /dev/null | LC_ALL=C grep -c . )" 1
rigAssert "the second mint result carries no path" "$( rigPathless "$rustSecond" )" yes

## ---- S4: adopt takes id and token; every refusal changes nothing; info reads the carried one ----
echo "-- S4: adopt takes the token; tokenless, unknown and wrong-token adopts are refused --"
rustWs="$rigTmp/s4/ws"
rustUnknown="99999999-8888-7777-6666-555555555555"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 mint
} | rigServer "$rigTmp/s4a.wire" "$rustWs"
rustMintAnswer="$( rigReply "$rigTmp/s4a.wire" 3 )"
rigAssert "the server answered the mint" "$( rigAnswered "$rustMintAnswer" )" yes
rustMintText="$( rigText "$rustMintAnswer" )"
rustId="$( rigFieldOf "$rustMintText" SESSION )"
rustToken="$( rigFieldOf "$rustMintText" TOKEN )"
## A second server adopts, then refuses, in order: each call needs what the one before it
## printed, and the server answers requests in parallel.
rigSequence "$rigTmp/s4b.wire" "$rustWs" \
	'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
	"$( rigCall 3 adopt "\"session\":\"$rustId\",\"token\":\"$rustToken\"" )" \
	"$( rigCall 4 adopt "\"session\":\"$rustId\"" )" \
	"$( rigCall 5 adopt "\"session\":\"$rustUnknown\",\"token\":\"$rustUnknown\"" )" \
	"$( rigCall 6 adopt "\"session\":\"$rustId\",\"token\":\"$rustUnknown\"" )" \
	"$( rigCall 7 info )" \
	"$( rigCall 8 no-such-operation )" > /dev/null
rustAdoptAnswer="$( rigReply "$rigTmp/s4b.wire" 3 )"
rigAssert "adopt with the minted id and token is not an error" "$( rigIsError "$rustAdoptAnswer" )" no
rigAssert "it adopts the id minted before it" "$( rigFieldOf "$( rigText "$rustAdoptAnswer" )" SESSION )" "$rustId"
rigAssert "the adopt result carries no path" "$( rigPathless "$( rigText "$rustAdoptAnswer" )" )" yes
rustNoTokenAnswer="$( rigReply "$rigTmp/s4b.wire" 4 )"
rustNoTokenText="$( rigText "$rustNoTokenAnswer" )"
rigAssert "an id without its token is refused" "$( rigIsError "$rustNoTokenAnswer" )" yes
rigAssert "the tokenless refusal says the token is missing" \
	"$( printf '%s\n' "$rustNoTokenText" | LC_ALL=C grep -qi 'token' && printf yes || printf no )" yes
rigAssert "the tokenless refusal carries no path" "$( rigPathless "$rustNoTokenText" )" yes
rustUnknownAnswer="$( rigReply "$rigTmp/s4b.wire" 5 )"
rigAssert "an unknown id is refused" "$( rigIsError "$rustUnknownAnswer" )" yes
rigAssert "the unknown-id refusal carries no path" "$( rigPathless "$( rigText "$rustUnknownAnswer" )" )" yes
rustWrongTokenAnswer="$( rigReply "$rigTmp/s4b.wire" 6 )"
rigAssert "a wrong token is refused" "$( rigIsError "$rustWrongTokenAnswer" )" yes
rigAssert "the wrong-token refusal carries no path" "$( rigPathless "$( rigText "$rustWrongTokenAnswer" )" )" yes
rigAssert "the refusals changed nothing: the server still carries the adopted id" \
	"$( rigFieldOf "$( rigText "$( rigReply "$rigTmp/s4b.wire" 7 )" )" SESSION )" "$rustId"
rigAssert "info prints no token" "$( rigFieldOf "$( rigText "$( rigReply "$rigTmp/s4b.wire" 7 )" )" TOKEN )" ""
rigAssert "info carries no path" "$( rigPathless "$( rigText "$( rigReply "$rigTmp/s4b.wire" 7 )" )" )" yes
rustOpAnswer="$( rigReply "$rigTmp/s4b.wire" 8 )"
rigAssert "an unknown operation is refused" "$( rigIsError "$rustOpAnswer" )" yes
rigAssert "the unknown-operation refusal is fixed text, not the caller's value" \
	"$( printf '%s\n' "$( rigText "$rustOpAnswer" )" | LC_ALL=C grep -q 'not one of mint, adopt, info' && printf yes || printf no )" yes
rigAssert "the refused id created no session folder" "$( [ ! -e "$( rigSessionDir "$rustWs" "$rustUnknown" )" ] && printf yes || printf no )" yes

## ---- S4b: a caller's value is never repeated, so no refusal carries a path ----
echo "-- S4b: path-shaped caller values are refused without being repeated --"
rustWs="$rigTmp/s4b/ws"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 mint
} | rigServer "$rigTmp/s4b-a.wire" "$rustWs"
rustPathMint="$( rigReply "$rigTmp/s4b-a.wire" 3 )"
rustPathId="$( rigFieldOf "$( rigText "$rustPathMint" )" SESSION )"
rigAssert "control: the mint for the path cases returned a session" "$( rigIsError "$rustPathMint" ):$( rigYesNo "$rustPathId" )" "no:yes"
rigSequence "$rigTmp/s4b-b.wire" "$rustWs" \
	'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
	"$( rigCall 3 '../../mint' )" \
	"$( rigCall 4 adopt "\"session\":\"../../etc/passwd\",\"token\":\"rig-token\"" )" \
	"$( rigCall 5 adopt "\"session\":\"a/b\",\"token\":\"rig-token\"" )" \
	"$( rigCall 6 adopt "\"session\":\"$rustPathId\",\"token\":\"../../token\"" )" > /dev/null
for rustPathAt in 3 4 5 6 ; do
	rustPathAnswer="$( rigReply "$rigTmp/s4b-b.wire" "$rustPathAt" )"
	rustPathText="$( rigText "$rustPathAnswer" )"
	rigAssert "request $rustPathAt with a path-shaped caller value is refused" "$( rigIsError "$rustPathAnswer" )" yes
	rigAssert "and its decoded result carries no slash" "$( rigPathless "$rustPathText" )" yes
done
rustPathOpText="$( rigText "$( rigReply "$rigTmp/s4b-b.wire" 3 )" )"
rigAssert "the unknown-operation refusal is its fixed text" \
	"$( printf '%s\n' "$rustPathOpText" | LC_ALL=C grep -q 'not one of mint, adopt, info' && printf yes || printf no )" yes
rustPathIdText="$( rigText "$( rigReply "$rigTmp/s4b-b.wire" 4 )" )"
rigAssert "the unknown-id refusal does not repeat 'etc'" \
	"$( printf '%s\n' "$rustPathIdText" | LC_ALL=C grep -q 'etc' && printf no || printf yes )" yes
rigAssert "and does not repeat 'passwd'" \
	"$( printf '%s\n' "$rustPathIdText" | LC_ALL=C grep -q 'passwd' && printf no || printf yes )" yes
rustPathTokenText="$( rigText "$( rigReply "$rigTmp/s4b-b.wire" 6 )" )"
rigAssert "the wrong-token refusal does not repeat the token's path" \
	"$( printf '%s\n' "$rustPathTokenText" | LC_ALL=C grep -q '\.\.' && printf no || printf yes )" yes
rigAssert "no path-shaped caller value created a session folder" "$( rigSessionDirs "$rustWs" | LC_ALL=C grep -c . )" 1

## ---- S5: no Slack message, no board item and no team channel ----
echo "-- S5: no Slack message, no board item and no team channel is written --"
rustWs="$rigTmp/s5/ws"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 3 mint
} | rigServer "$rigTmp/s5.wire" "$rustWs"
rustAnswer="$( rigReply "$rigTmp/s5.wire" 3 )"
rigAssert "the server answered the mint" "$( rigAnswered "$rustAnswer" )" yes
rustText="$( rigText "$rustAnswer" )"
rustId="$( rigFieldOf "$rustText" SESSION )"
rigAssert "control: the mint returned a session" "$( rigIsError "$rustAnswer" ):$( rigYesNo "$rustId" )" "no:yes"
rigAssert "no Slack call was made" "$( [ ! -s "$rigSlack/calls" ] && printf yes || printf no )" yes
rigAssert "no Slack body was sent" "$( [ ! -s "$rigSlack/bodies" ] && printf yes || printf no )" yes
rigAssert "no board item was written" "$( find "$rustWs" -path '*/board/*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "no team channel (session thread) was opened" "$( [ ! -e "$( rigSessionDir "$rustWs" "$rustId" )/session.thread" ] && printf yes || printf no )" yes
rigAssert "no team data is written" "$( [ ! -e "$rustWs/.local/agents/team-data-root" ] && printf yes || printf no )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  repair the RootSession tool in sh-lib/mcp/" >&2
	echo "        (AgentsTools.RootSession.include and the arm in AgentsTools.InternMcpRequest.include)," >&2
	echo "        never the assertion" >&2
	exit 1
fi
printf 'ROOT_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
