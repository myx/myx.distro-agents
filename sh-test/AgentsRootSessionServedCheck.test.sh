#!/usr/bin/env bash
## Behavioural check on the session a served MCP call runs as (F1.2 of the root-harness epic),
## and on the static floor that carries CheckList: when the myx.distro MCP server carries a
## root-harness session (RootSession mint/adopt keeps it in the server's scratch root), a
## served call is made as that session, with no console and no spawn record behind it; a server
## carrying no session executes every call exactly as it did before.
##
## Read OFF THE WIRE, from a real `--intern-mcp-server --run` driven over stdio, the way
## AgentsRootSessionCheck and AgentsHarnessServedIdentityCheck read their servers -- never by
## re-applying the dispatch here, which would only report that the two agree.
##
## Held, one case per statement of F1.2 and per the owner's ruling that widened it:
##   S1. After RootSession mint, the next served calls carry the session: CheckList writes its
##       checklist into `.local/agents/sessions/<minted id>/`, the place of a root session, as
##       the root session's magic-coordinator (MDAT_SPAWN_AGENT unset).
##   S2. Wait, CheckList and Skill work in that server with no console, no spawn record and no
##       session thread: Wait returns TIMEOUT (not the "needs --wait-session-id" refusal),
##       CheckList writes, Skill reads a skillset file. No spawn record, no `session.thread`
##       and no `MDAT_SESSION_ID`/`MDAT_SPAWN_AGENT` from the host exist. The session export is
##       the server's, not one tool's: an `execute` script sees `MDAT_SPAWN_SESSION_ID`.
##   S3. A server with no session executes every call as today: CheckList refuses on the call
##       ("this call belongs to no session yet ... no place to be kept"), its refusal a hint
##       that names `RootSession operation=mint` and `operation=adopt`, not a denial that the
##       tool is unoffered; Wait returns today's `--wait-default needs --wait-session-id`
##       refusal, Skill works, an `execute` script sees no session id, `ToolSearch` finds
##       CheckList (search is a way of offering it), and no session folder is made. The
##       catalogue is NOT part of S3: by the ruling, the tool block is static.
##   D7. Reached through another MCP server (`MDAT_MCP_SERVED_MARKER=1`), the served list is
##       exactly `execute`: `RootSession` and `CheckList` are absent because the WHOLE floor is,
##       not because a place is unknown.
##
## THE STATIC FLOOR. The tool block is described once and never changes, for the input cache
## the host keeps on it. CheckList is a basic tool and is listed like any other; it is never
## withheld and never gated, and it refuses only at execution, where the harness knows no
## place to write. So: the catalogue is byte-identical before and after a mint, RootSession
## and CheckList are both in it at both times, no `notifications/tools/list_changed` is sent
## for the mint, and the same list is served with no session at all.
##
## THE HARNESS SIDE. The model path needs a provider, an endpoint and a credential, so it is
## not exercised offline here. Its declaration source is: the wire adapter the model path
## sources (`AgentsOpenAiChatWire.sh`, which defines `harnessToolsJson`) and the mirror that
## renders the same declarations for the MCP floor (`AgentsHarnessMcpMirror.sh`). Both are
## asserted to carry CheckList with no session, while the harness's own place probe says there
## is no place -- the declaration unconditional, the refusal at execution. A source assertion
## pins the removed model-path filter so a later re-add is noticed.
##
## ON "NO PATH-SHAPED VALUE" (RULING R1 / D8). The rule is asserted on F1.2's own messages
## only: the RootSession minted facts, the no-session CheckList hint, and the Wait TIMEOUT (and
## its no-session refusal) -- pathless, no absolute path, no server scratch store.
## TWO THINGS ARE DELIBERATELY NOT JUDGED, and named here so the exclusion is visible:
##   * CheckList's result names the member and session and carries no path (the owner's fix-it-now;
##     existing workspace-relative result (pinned verbatim by AgentsHarnessTodoWriteCheck);
##     F1.2 changes no tool's result text. Its exact shape is pinned below so a change shows.
##   * `SystemContext: init: <path>`, the real sibling's pre-existing diagnostic on stderr. It
##     is not this feature's result; the rig links the REAL siblings rather than a mute stand-in
##     precisely so nothing real is hidden here.
## Skill's content and `execute`'s script output are fixture text, not this feature's messages,
## so the pathless rule is not asserted on them either.
##
## Offline, and self-contained in its scratch: a fake curl first on PATH is the whole of the
## offline guarantee, and the server writes only under this check's own tree. The tree under
## test is whatever MDLT_ORIGIN names -- so a red run needs the planted tree named there, not
## merely executed, and a rig's package is always a COPY of it.
##
## Red recipe, run against the tree received for F1.2: list, mint, list, CheckList, Wait, Skill
## -> CheckList is absent from both lists (nothing is offered it without a place), the call is
## `Unknown tool`, Wait is refused for want of a session, and no checklist is written. The
## no-session case is red there too: it lists CheckList absent and answers `Unknown tool`, where
## this check holds the static floor and the execution refusal.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRequest="$rigHere/mcp/AgentsTools.InternMcpRequest.include"
rigMirror="$rigHere/harness/AgentsHarnessMcpMirror.sh"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must never print
## a pass, and an empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigHarness" "$rigRequest" "$rigMirror" "$rigWire" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootSessionServedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN. The server loads the sibling myx.distro-system context when it starts, and
## the settings reader of myx.distro-.local when an operation reads a setting. They are the REAL
## siblings, linked READ-ONLY beside the copied package -- never a mute stand-in, which would hide
## the pre-existing `SystemContext: init: <path>` line the real context prints. Nothing real is
## hidden here; the pathless assertions below are scoped to F1.2's own messages for that reason.
## The package under test is a COPY; only siblings are linked, and only beside it.
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
## The member the served identity resolves to, and one skillset file for Skill to read. The
## member's basic file is read on every served call, so its absence would drop the identity and
## take the four sending tools down; the rig holds it, and nothing else.
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
rigSlice(){ ## wire line file, json path, mode -- raw
	LC_ALL=C awk -v path="$2" -v mode="$3" -f "$rigField" < "$1" 2> /dev/null || :
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
rigHolds(){ ## text, fragment -- yes when the text holds it
	case "$1" in
		*"$2"*) printf yes ;;
		*) printf no ;;
	esac
}
rigNoAbsolute(){ ## text -- yes when it names no absolute path
	case "$1" in
		/*|*' /'*) printf no ;;
		*) printf yes ;;
	esac
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
rigTools(){ ## tools/list answer file -- each tool name, one a line
	local rigAt=0 rigToolName=""
	while : ; do
		rigToolName="$( rigValue "$1" "result.tools.$rigAt.name" )"
		[ -n "$rigToolName" ] || return 0
		printf '%s\n' "$rigToolName"
		rigAt=$(( rigAt + 1 ))
	done
}
rigLine(){ ## text, line -- yes when one whole line of the text is exactly it
	printf '%s\n' "$1" | LC_ALL=C grep -qx -- "$2" && printf yes || printf no
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
rigServerMarked(){ ## wire file, workspace -- the same server reached through another MCP server
	mkdir -p "$2/.local" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigSlack" PATH="$rigBin:$PATH" \
		MDAT_MCP_SERVED_MARKER=1 \
		bash "$rigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigQuiet(){ ## the rest of the line, in a process with no session of any kind
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER \
		MMDAPP="$1" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills" \
		PATH="$rigBin:$PATH" "${@:2}"
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
rigSessionDir(){ ## workspace, id -- the session's own record folder
	printf '%s' "$1/.local/agents/sessions/$2"
}
rigSpawnRecords(){ ## workspace -- how many spawn records it holds
	find "$1/.local/agents/spawned" -name '*.spawn.md' -type f 2> /dev/null | LC_ALL=C grep -c . || :
}
rigCount(){ ## file, pattern -- matching lines, 0 when the file is absent
	local rigCountText=""
	rigCountText="$( LC_ALL=C grep -c "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${rigCountText:-0}"
}

rigListJson='{"todos":[{"content":"rig item","status":"pending","activeForm":"doing rig item"}]}'
rigMd='- [ ] rig item'

## ---- S1, S2: mint, then the served calls carry the session; the floor never moves ----
echo "-- S1/S2: a host lists, mints, and the next calls run as the minted session --"
rigWs="$rigTmp/with-session/ws"
rigWireFile="$rigTmp/with-session.wire"
rigSequence "$rigWireFile" "$rigWs" \
	'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
	'{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
	'{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"mint"}}}' \
	'{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}' \
	"{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"CheckList\",\"arguments\":$rigListJson}}" \
	'{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"Wait","arguments":{"timeout":2}}}' \
	'{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Skill","arguments":{"name":"rig-skill","file":"SKILL.md"}}}' \
	'{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"execute","arguments":{"command":"printf \"%s\\n\" \"${MDAT_SPAWN_SESSION_ID:-none}\""}}}' > /dev/null
rigInit="$( rigReply "$rigWireFile" 1 )"
[ "$( rigAnswered "$rigInit" )" = yes ] || {
	echo "-- the server answered no initialize, so its stderr follows --" >&2
	sed 's/^/    /' "$rigWireFile.err" >&2
	rigRefuse "the server never started"
}
rigListBefore="$( rigReply "$rigWireFile" 2 )"
rigMint="$( rigReply "$rigWireFile" 3 )"
rigListAfter="$( rigReply "$rigWireFile" 4 )"
rigListAnswer="$( rigReply "$rigWireFile" 5 )"
rigWaitAnswer="$( rigReply "$rigWireFile" 6 )"
rigSkillAnswer="$( rigReply "$rigWireFile" 7 )"
rigExecAnswer="$( rigReply "$rigWireFile" 8 )"

## The static floor, first: listed before and after a mint, the same tool block both times.
rigAssert "the host's first catalogue answered" "$( rigAnswered "$rigListBefore" )" yes
rigAssert "the first catalogue carries RootSession" "$( rigLists "$rigListBefore" RootSession )" yes
rigAssert "the first catalogue carries CheckList, with no place known yet" "$( rigLists "$rigListBefore" CheckList )" yes
rigAssert "the mint answered" "$( rigAnswered "$rigMint" )" yes
rigAssert "the mint is not an error" "$( rigIsError "$rigMint" )" no
rigMintText="$( rigText "$rigMint" )"
rigSession="$( rigFieldOf "$rigMintText" SESSION )"
rigToken="$( rigFieldOf "$rigMintText" TOKEN )"
rigAssert "the mint returned a bare session id" "$( rigBare "$rigSession" )" yes
rigAssert "the mint returned a token" "$( [ -n "$rigToken" ] && printf yes || printf no )" yes
rigAssert "the mint result carries no path-shaped value" "$( rigPathless "$rigMintText" )" yes
rigAssert "the mint result carries no absolute path" "$( rigNoAbsolute "$rigMintText" )" yes
rigAssert "no result names the server's scratch store" "$( rigHolds "$rigMintText" 'agent-mcp.' )" no
rigAssert "the catalogue after the mint carries RootSession" "$( rigLists "$rigListAfter" RootSession )" yes
rigAssert "the catalogue after the mint carries CheckList" "$( rigLists "$rigListAfter" CheckList )" yes
rigAssert "the tool block is byte-identical before and after the mint" \
	"$( rigSlice "$rigListAfter" result raw )" "$( rigSlice "$rigListBefore" result raw )"
rigAssert "the mint announced no catalogue change: the block is static" \
	"$( LC_ALL=C grep -c 'notifications/tools/list_changed' "$rigWireFile" )" 0

## S1: the call runs as the session the server carries. The place of a root session's
## checklist is its own session folder, sessions/<id>, and the served identity is the root
## session's magic-coordinator (MDAT_SPAWN_AGENT is unset in the server's environment).
rigChecklistAnswer="$( rigText "$rigListAnswer" )"
rigAssert "the served CheckList answered" "$( rigAnswered "$rigListAnswer" )" yes
rigAssert "the served CheckList is not an error" "$( rigIsError "$rigListAnswer" )" no
rigAssert "it names the minted session" "$( rigHolds "$rigChecklistAnswer" "in session $rigSession " )" yes
rigAssert "it wrote as the root session's magic-coordinator" "$( rigHolds "$rigChecklistAnswer" 'checklist of magic-coordinator' )" yes
## RULING R1 / D8 and the owner's fix-it-now: CheckList's result is pathless like F1.2's own messages --
## it names the member and the session, and no `.local/agents/sessions/...` path. The real SystemContext's
## pre-existing `SystemContext: init: <path>` diagnostic is stderr and not this feature's result.
rigAssert "the checklist result is pathless: the member and the session, no path" \
	"$( rigHolds "$rigChecklistAnswer" 'checklist of magic-coordinator' ):$( rigHolds "$rigChecklistAnswer" '.local/agents/sessions' )" yes:no
rigAssert "the session's folder holds the checklist" \
	"$( [ -f "$( rigSessionDir "$rigWs" "$rigSession" )/magic-coordinator.checklist.md" ] && printf yes || printf no )" yes
rigAssert "the checklist is the one the call wrote" \
	"$( cat "$( rigSessionDir "$rigWs" "$rigSession" )/magic-coordinator.checklist.md" 2> /dev/null )" "$rigMd"

## S2: Wait returns its own TIMEOUT, never the no-session refusal, and Skill reads its file.
rigWaitText="$( rigText "$rigWaitAnswer" )"
rigAssert "the served Wait answered" "$( rigAnswered "$rigWaitAnswer" )" yes
rigAssert "the served Wait is not an error" "$( rigIsError "$rigWaitAnswer" )" no
rigAssert "Wait returns TIMEOUT" "$( rigTimeout "$rigWaitText" )" yes
rigAssert "Wait is not refused for want of a session" "$( rigHolds "$rigWaitText" 'needs --wait-session-id' )" no
rigAssert "the Wait result carries no path-shaped value" "$( rigPathless "$rigWaitText" )" yes
rigAssert "the Wait result carries no absolute path" "$( rigNoAbsolute "$rigWaitText" )" yes
rigAssert "the Wait result names no server scratch store" "$( rigHolds "$rigWaitText" 'agent-mcp.' )" no
rigSkillText="$( rigText "$rigSkillAnswer" )"
rigAssert "the served Skill answered" "$( rigAnswered "$rigSkillAnswer" )" yes
rigAssert "the served Skill is not an error" "$( rigIsError "$rigSkillAnswer" )" no
rigAssert "Skill read the skillset file" "$( rigHolds "$rigSkillText" 'RIG-SKILL-MARKER' )" yes

## D6: the export is the server's, not one tool's, so an execute script sees it too. A whole
## line exactly the id, because the real SystemContext prints its pre-existing init line around
## the script's own output (D8/R1: that diagnostic is not this feature's result).
rigAssert "an execute call runs with the session in its environment" \
	"$( rigLine "$( rigText "$rigExecAnswer" )" "$rigSession" )" yes

## S2 again, from the other side: none of it needed a console, a spawn record or a thread.
rigAssert "no console run: the workspace holds no spawn record" "$( rigSpawnRecords "$rigWs" )" 0
rigAssert "no session thread was opened" "$( [ ! -e "$( rigSessionDir "$rigWs" "$rigSession" )/session.thread" ] && printf yes || printf no )" yes
rigAssert "no Slack message was posted by the calls" "$( rigCount "$rigSlack/calls" 'chat.postMessage' )" 0
rigAssert "no board item was written" "$( find "$rigWs" -path '*/board/*' -type f 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "the calls wrote into the session folder only, as their own session record" \
	"$( [ -f "$( rigSessionDir "$rigWs" "$rigSession" )/root-session.token" ] && printf yes || printf no )" yes

## ---- S3: with no session, the floor is the same and execution is today's ----
echo "-- S3: a server carrying no session lists the same tools and refuses at execution --"
rigWsEmpty="$rigTmp/no-session/ws"
rigWireEmpty="$rigTmp/no-session.wire"
rigSequence "$rigWireEmpty" "$rigWsEmpty" \
	'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
	'{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
	"{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"CheckList\",\"arguments\":$rigListJson}}" \
	'{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"Wait","arguments":{"timeout":2}}}' \
	'{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"Skill","arguments":{"name":"rig-skill","file":"SKILL.md"}}}' \
	'{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"execute","arguments":{"command":"printf \"%s\\n\" \"${MDAT_SPAWN_SESSION_ID:-none}\""}}}' \
	'{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"ToolSearch","arguments":{"query":"checklist"}}}' > /dev/null
rigInitEmpty="$( rigReply "$rigWireEmpty" 1 )"
[ "$( rigAnswered "$rigInitEmpty" )" = yes ] || {
	echo "-- the no-session server answered no initialize, so its stderr follows --" >&2
	sed 's/^/    /' "$rigWireEmpty.err" >&2
	rigRefuse "the no-session server never started"
}
rigListEmpty="$( rigReply "$rigWireEmpty" 2 )"
rigCheckEmpty="$( rigReply "$rigWireEmpty" 3 )"
rigWaitEmpty="$( rigReply "$rigWireEmpty" 4 )"
rigSkillEmpty="$( rigReply "$rigWireEmpty" 5 )"
rigExecEmpty="$( rigReply "$rigWireEmpty" 6 )"
rigSearchEmpty="$( rigReply "$rigWireEmpty" 7 )"

rigAssert "the no-session catalogue answered" "$( rigAnswered "$rigListEmpty" )" yes
rigAssert "the no-session catalogue carries RootSession" "$( rigLists "$rigListEmpty" RootSession )" yes
rigAssert "the no-session catalogue carries CheckList: it is never withheld from the floor" "$( rigLists "$rigListEmpty" CheckList )" yes
rigAssert "the no-session catalogue is the same tool block as the session server's" \
	"$( rigSlice "$rigListEmpty" result raw )" "$( rigSlice "$rigListBefore" result raw )"
rigCheckEmptyText="$( rigText "$rigCheckEmpty" )"
rigAssert "the served CheckList is not an unknown tool" "$( rigValue "$rigCheckEmpty" error.message )" ""
rigAssert "the served CheckList is a tool result, not an absent tool" "$( rigValue "$rigCheckEmpty" result.isError )" true
rigAssert "the served CheckList refuses at execution for want of a place" \
	"$( rigHolds "$rigCheckEmptyText" 'this call belongs to no session yet' )" yes
rigAssert "the refusal says the checklist has no place to be kept" \
	"$( rigHolds "$rigCheckEmptyText" 'no place to be kept' )" yes
rigAssert "the refusal names the way out: RootSession operation=mint" \
	"$( rigHolds "$rigCheckEmptyText" 'RootSession operation=mint' )" yes
rigAssert "the refusal also names operation=adopt for an existing session" \
	"$( rigHolds "$rigCheckEmptyText" 'operation=adopt' )" yes
rigAssert "the refusal is a hint, not a denial that the tool is unoffered" \
	"$( rigHolds "$rigCheckEmptyText" 'not offered' )" no
rigAssert "it wrote nothing" "$( rigHolds "$rigCheckEmptyText" 'Nothing was written' )" yes
rigAssert "the CheckList refusal carries no path-shaped value" "$( rigPathless "$rigCheckEmptyText" )" yes
rigAssert "the CheckList refusal carries no absolute path" "$( rigNoAbsolute "$rigCheckEmptyText" )" yes
rigAssert "the CheckList refusal names no server scratch store" "$( rigHolds "$rigCheckEmptyText" 'agent-mcp.' )" no
rigWaitEmptyText="$( rigText "$rigWaitEmpty" )"
rigAssert "the served Wait was refused" "$( rigIsError "$rigWaitEmpty" )" yes
## Not judged pathless (R1/D8): this is TODAY's refusal, and with the real siblings it carries
## the pre-existing `SystemContext: init: <path>` diagnostic inside the operation's own error
## text. It is not F1.2's message; only the exact refusal is asserted. The with-session Wait
## TIMEOUT, which is the feature's message, is asserted pathless above.
rigAssert "Wait refuses exactly as today: the state needs a session" \
	"$( rigHolds "$rigWaitEmptyText" '--wait-default needs --wait-session-id, because the state it keeps or ends is the state of one session. Nothing was waited on.' )" yes
rigSkillEmptyText="$( rigText "$rigSkillEmpty" )"
rigAssert "the served Skill still works" "$( rigIsError "$rigSkillEmpty" )" no
rigAssert "Skill read the skillset file with no session" "$( rigHolds "$rigSkillEmptyText" 'RIG-SKILL-MARKER' )" yes
## D6: with no session the export sets nothing, so an execute script sees no session id.
rigAssert "with no session an execute call sees no session id" "$( rigLine "$( rigText "$rigExecEmpty" )" none )" yes
## D5: search is a way of offering it; the call refuses with the hint, never with silence.
rigAssert "ToolSearch finds CheckList with no session" \
	"$( rigHolds "$( rigText "$rigSearchEmpty" )" '"name":"CheckList"' )" yes
rigAssert "no session folder was made" \
	"$( find "$rigWsEmpty/.local/agents/sessions" -mindepth 1 -maxdepth 1 -type d 2> /dev/null | LC_ALL=C grep -c . )" 0
rigAssert "no console run: no spawn record was made" "$( rigSpawnRecords "$rigWsEmpty" )" 0

## ---- D7: reached through another MCP server, the served list is exactly `execute` ----
## The marker means an outer server reached this one: it then declines every harness tool and
## its own RootSession, so enumeration cannot descend through it twice. CheckList is absent
## there because the WHOLE floor is, not because a place is unknown.
echo "-- D7: through another server, the floor is execute alone --"
rigWsMarked="$rigTmp/marked/ws"
rigWireMarked="$rigTmp/marked.wire"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
} | rigServerMarked "$rigWireMarked" "$rigWsMarked"
rigListMarked="$( rigReply "$rigWireMarked" 2 )"
rigAssert "the marked server answered tools/list" "$( rigAnswered "$rigListMarked" )" yes
rigAssert "reached through another server, exactly one tool is served" \
	"$( rigTools "$rigListMarked" | LC_ALL=C grep -c . )" 1
rigAssert "that one tool is execute" "$( rigTools "$rigListMarked" | head -n 1 )" execute
rigAssert "RootSession is absent there: the whole floor is" "$( rigLists "$rigListMarked" RootSession )" no
rigAssert "CheckList is absent there: the whole floor is" "$( rigLists "$rigListMarked" CheckList )" no

## ---- R2's harness side: the declarations are unconditional, the place is not ----
echo "-- the harness side: CheckList is declared with no place, and refuses at execution --"
rigMirrorOut="$( rigQuiet "$rigWsEmpty" bash "$rigMirror" "" "Bash WorkspaceContextExecute" 2> /dev/null )" || rigMirrorOut=""
rigAssert "the MCP floor's own mirror renders CheckList" \
	"$( rigHolds "$rigMirrorOut" '{"name":"CheckList",' )" yes
rigWireOut="$( rigQuiet "$rigWsEmpty" bash -c '. "$1" ; printf "%s" "$harnessToolsJson"' _ "$rigWire" 2> /dev/null )" || rigWireOut=""
rigAssert "the wire the model path sources declares CheckList" \
	"$( rigHolds "$rigWireOut" '{"type":"function","function":{"name":"CheckList",' )" yes
rigAssert "the harness's model-path filter no longer drops it" \
	"$( LC_ALL=C grep -c 'grep -v -F .{\"type\":\"function\",\"function\":{\"name\":\"CheckList\",' "$rigHarness" )" 0
rigPlaceOut="$( rigQuiet "$rigWsEmpty" bash "$rigHarness" --intern-checklist-place < /dev/null 2> /dev/null )" || rigPlaceOut=""
rigAssert "with no session the harness knows no place for it" \
	"$( rigHolds "$rigPlaceOut" 'this call belongs to no session yet' )" yes
rigAssert "and its place refusal is the hint, not a denial" \
	"$( rigHolds "$rigPlaceOut" 'RootSession operation=mint' )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT SESSION SERVED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  make --intern-mcp-request carry the session RootSession holds in the server's" >&2
	echo "        scratch root (root-session) to the harness as MDAT_SPAWN_SESSION_ID, and keep" >&2
	echo "        the tool block static: CheckList listed unconditionally, refusing at execution" >&2
	echo "        in sh-lib/mcp/AgentsTools.InternMcpRequest.include and" >&2
	echo "        sh-lib/harness/AgentsUniversalHarness.sh -- never the assertion" >&2
	exit 1
fi
printf 'ROOT_SESSION_SERVED: OK (%d assertions, offline: session carried by CheckList/Wait/Skill, static floor before/after mint/no session, execution refusals, no console/spawn/thread)\n' "$rigPassCount"
