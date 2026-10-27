#!/usr/bin/env bash
## AgentsRootHarnessVerbosityCheck — behavioural check on the setting that chooses a root-harness session's
## external channel (F3.1 of the root-harness epic), run rather than read. Held, one case per statement:
##
##   S1. THE SETTING IS DECLARED, SHOWN BY THE CONFIG DIGEST, AND SET PER WORKSPACE. `ROOT_HARNESS_VERBOSITY`
##       is a row of the digest's changeable settings under `control`/`channel`, a `choice` of `none`, `track`
##       and `full`, saved in the settings of the team of this workspace, `none` where nothing sets it. The
##       one writer of a declared setting saves it (`--manager-config-set`), the tooling's own reading gives
##       it back (`--agents-config-option magic-team --select`), a value it does not take is refused with
##       the three named and nothing written, and it is read AT MINT: a session minted under `track` keeps
##       `track` after the workspace is changed to `full`, and the next mint records `full`.
##
##   S2. `none`: THE SESSION'S EXTERNAL SIDE IS THE ROOT-NATIVE PRINTBACK CHANNEL; NO THREAD IS CREATED. The
##       minted session records the kind `none`; a helper spawned into it opens no session thread and no
##       tooling thread, the spawn makes NO Slack call at all, and the dispatch states `channel kind:
##       printback` and `printback:<session>`. The helper's join is a recorded `notice` block, its handback
##       is printed on that channel and recorded as a printback block, both in the session's one chat file.
##
##   S3. `track`: THE TOOLING THREAD RECEIVES THE DUPLICATES; NO SESSION THREAD IS CREATED. The minted
##       session records `track`; the spawn opens the session's tooling thread (the event-track thread, its
##       one record `event-track.thread`) and no session thread, and the dispatch states `channel kind:
##       track` and names that thread. The helper's handback -- the copy of a session message -- is posted
##       INTO that thread (the posted payload names the event-track channel and the tooling thread's ts) and
##       the session's one chat file records it; no session thread exists. AND THE CHANNEL IS READ BACK
##       (the coordinator's ruling): a bare Wait of the root, its floor set before the report, returns the
##       report `RECEIVED` from that one chat file with filters naming no Slack source; the root's
##       `DISMISSED` is copied into the tooling thread and delivered to the helper's own bare Wait, which
##       returns `WAIT-RESULT: DISMISSED`. A track session with a conversation present still defaults to
##       `chat:<session>` alone.
##
##   S4. `full`: A NORMAL SESSION THREAD IS CREATED IN THE TEAM CHANNEL, AS TODAY. The minted session
##       records `full`; the spawn opens the session thread in the team channel, records it
##       (`sessions/<session>/session.thread`) and hands it to the helper in the dispatch as
##       `session_thread_ts: <team channel>:<ts>`; the helper's handback is posted into that thread and the
##       one chat file records it; a bare Wait's default sources stay the session thread and the
##       conversations it continues, as printback's stay its chat file.
##
##   S5. THE SETTING NEVER GATES A MESSAGE THAT NAMES AN ADDRESS. In every one of the three workspaces, the
##       same addressed message -- the root's `SendMessage` to `human-owner`, addressed to the helper -- is
##       sent to that address and recorded, whatever the setting is; in `none` it is the only Slack call
##       the workspace makes, so the printback channel is proved not to swallow it.
##
## THE CHANNEL THE SESSION'S KIND NAMES IS THE ONE THE RUN IS DISPATCHED ON, held throughout: the kind
## record is written at mint beside the token, the tooling thread is recorded before the dispatch names it,
## and the dispatch's `## Your session thread` section states the kind in use in each workspace.
##
## THE RIG ORIGIN. Every call runs the package COPY in this rig (never the tree under test):
## `origin/myx/myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked
## READ-ONLY beside it -- never a mute stand-in. Each of the three workspaces is the rig's own folder, and
## its one session is minted by a real `--intern-mcp-server --run` process (RootSession) and dispatched into
## by the real spawn proxy, as the root's own session env makes it. The helper's handback is served by a
## real server process carrying that run, exactly as a helper's own server would. One server process per
## exchange, as a real chat is a new process per turn; a call that must wait is its own process.
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee, and it
## logs every call it is given, with the channel and the thread of a post), a fake console records the
## dispatch and starts no model, every workspace is a folder of the rig's own, and no model CLI is started.
##
## Red recipe: run this check against a COPY of the RECEIVED tree -- the tree before F3.1 -- with only this
## check and its curl fixture added to its `sh-test`. Nothing else is changed.
##
##   cp -Rp pristine/myx.distro-agents red/origin/myx/myx.distro-agents
##   ln -s <real myx.distro-system> red/origin/myx/myx.distro-system        # and myx.distro-.local
##   cp origin/.../sh-test/harness/AgentsRootHarnessVerbosityCheck.test.sh red/origin/.../sh-test/
##   cp origin/.../sh-test/check-fixtures/root-harness-verbosity.curl.stub.sh red/origin/.../sh-test/check-fixtures/
##   MDLT_ORIGIN=$PWD/red/origin MMDAPP=$PWD/workspace MDAT_SKILLSET_ROOT=<skillset> \
##     bash red/origin/myx/myx.distro-agents/sh-test/harness/AgentsRootHarnessVerbosityCheck.test.sh
##
## Red is S1 first, on the received tree's own reason: `--manager-config-digest --full control` prints no
## `ROOT_HARNESS_VERBOSITY` line and the writer refuses the key as none of the changeable settings, so the
## setting is not there to be read. Behind it the Settled line fails: no `root-session.kind` is written at
## mint. Then S3 and S4 fail on the F2.3 inference: a minted session with a token and no session thread is
## read as printback, so a `track` spawn hands the helper `channel kind: printback` and its handback is
## printed instead of posted into the tooling thread -- and the read-back the ruling asks for cannot name
## the tooling thread at all -- while a `full` spawn opens no team-channel session thread and its bare
## Wait defaults to the printback chat file instead of a session thread. S5 passes on the received tree
## once its kind-record assertion is left out, and so does the `none` channel itself: they are the guard
## that the feature did not regress what F2.2 and F2.3 already held, never a red driver. Recorded run:
## 27 of 60 assertions fail, in that order.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigRootMember="magic-coordinator"
rigHelperMember="rig-helper"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigFixtures/root-harness-verbosity.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootHarnessVerbosityCheck )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

## THE RIG ORIGIN: a COPY of the tree under test, and read-only links to the real siblings.
rigOrigin="$rigTmp/origin"
rigBin="$rigTmp/bin"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigOrigin/myx" "$rigBin" "$rigHome" "$rigSkills" || rigRefuse "cannot make the rig's own tree"
cp -Rp "$rigPackage" "$rigOrigin/myx/myx.distro-agents" || rigRefuse "cannot copy the tree under test into the rig origin"
for rigSibling in myx.distro-system myx.distro-.local ; do
	[ -d "$rigSource/myx/$rigSibling" ] || rigRefuse "this check runs the real $rigSibling read-only beside the package, and none is at $rigSource/myx/$rigSibling"
	ln -s "$rigSource/myx/$rigSibling" "$rigOrigin/myx/$rigSibling" || rigRefuse "cannot link the real $rigSibling beside the rig's package"
done
rigRigPackage="$rigOrigin/myx/myx.distro-agents"
rigRigTool="$rigRigPackage/sh-scripts/DistroAgentsTools.fn.sh"
for rigMember in "$rigRootMember" "$rigHelperMember" ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
done
cp "$rigFixtures/root-harness-verbosity.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
## One real server process: its stdin read to the end, its wire kept. <helper session> non-empty gives it the
## helper's identity and session env, as a spawn hands its run; empty, the root's, which adopts the session.
rigServer(){ ## wire file, workspace, scenario, helper's coworking session (empty: the root's), helper's spawn id
	mkdir -p "$2/.local/temp" "$2/.local/.agents" || rigRefuse "cannot make the workspace $2"
	if [ -n "$4" ] ; then
		env -u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN -u MDAT_SPAWN_AGENT \
			-u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
			MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
			MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" RIG_CHAT="$3/chat" PATH="$rigBin:$PATH" \
			MDAT_SPAWN_AGENT="$rigHelperMember" MDAT_SESSION_ID="$4" MDAT_SPAWN_SESSION_ID="$5" \
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
rigSendMessageCall(){ ## id, message, address to -- one served SendMessage, to the named address
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"SendMessage","arguments":{"to":"%s","message":"%s","address_to":"%s"}}}' "$1" "$2" "$3" "$4"
}
rigHandbackCall(){ ## id, outcome -- one served SubagentHandback, its default target (session-parent)
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"SubagentHandback","arguments":{"outcome":"%s"}}}' "$1" "$2"
}

## ---- a direct call, outside any server: the setting's own operations ----
rigDirect(){ ## workspace, then the tool's arguments
	local rigDirectWs="$1"
	shift
	( cd "$rigDirectWs" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigDirectWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigRigTool" "$@" )
}
rigSettingDigestLine(){ ## digest output file -- the ROOT_HARNESS_VERBOSITY line, the fields a check reads
	LC_ALL=C awk -F'\t' '$1 == "line" && $4 == "ROOT_HARNESS_VERBOSITY" { print $2, $3, $5, $6, $9, $10, $11, $12, $13, $15 ; }' "$1"
}
rigSettingDigestFile(){ ## digest output file -- the file the setting's line names, `-` when absent
	LC_ALL=C awk -F'\t' '$1 == "line" && $4 == "ROOT_HARNESS_VERBOSITY" { print $14 ; }' "$1"
}

## ---- the session's own records and the chat file, as the check reads them ----
rigSessionDir(){ printf '%s' "$1/.local/agents/sessions/$2" ; }
rigChatFile(){ printf '%s/session.chat' "$( rigSessionDir "$1" "$2" )" ; }
rigKindOf(){ ## workspace, session -- the recorded kind, `none` when no record
	local rigKindValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/root-session.kind" ] || IFS= read -r rigKindValue < "$( rigSessionDir "$1" "$2" )/root-session.kind" || :
	printf '%s' "${rigKindValue:-none}"
}
rigThreadOf(){ ## workspace, session, record name -- the recorded thread, `none` when absent
	local rigThreadValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/$3" ] || IFS= read -r rigThreadValue < "$( rigSessionDir "$1" "$2" )/$3" || :
	printf '%s' "${rigThreadValue:-none}"
}
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
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { print $1, $2, $3, $4, $6 ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigIndexField(){ ## chat file, N, field 2..6 -- that field of the block's index line
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$2" -v field="$3" '$1 == want { print $field ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigChats(){ ## workspace -- every session chat file in it, one a line
	find "$1/.local/agents/sessions" -name 'session.chat' -type f 2> /dev/null | LC_ALL=C sort || :
}
rigSlackReached(){ ## scenario -- `file` when the fake curl was reached at all, `none` when it never was
	[ -f "$1/calls" ] && printf file || printf none
}
rigCalls(){ ## scenario -- how many calls the fake curl was given, 0 when none
	[ -f "$1/calls" ] && LC_ALL=C grep -c . "$1/calls" 2> /dev/null || printf 0
}
rigCallLine(){ ## scenario, method, channel -- the calls of that method to that channel, one a line
	[ -f "$1/calls" ] || return 0
	LC_ALL=C awk -v wantMethod="$2" -v wantChannel="$3" '$1 == wantMethod && $2 == wantChannel { print ; }' "$1/calls"
}
rigPostBody(){ ## scenario, fixed text -- the path of the first posted payload that holds the text, empty for none
	local rigPostFile=""
	for rigPostFile in "$1"/post.* ; do
		[ -f "$rigPostFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigPostFile" || continue
		printf '%s' "$rigPostFile" ; return 0
	done
	printf ''
}
rigPostCount(){ ## scenario, fixed text -- how many posted payloads hold the text
	local rigPostFile="" rigPostSeen=0
	for rigPostFile in "$1"/post.* ; do
		[ -f "$rigPostFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigPostFile" && rigPostSeen=$(( rigPostSeen + 1 ))
	done
	printf '%s' "$rigPostSeen"
}
rigPostField(){ ## scenario, fixed text, json key -- the first value of that key in the payload holding the text
	local rigPostFile=""
	rigPostFile="$( rigPostBody "$1" "$2" )"
	[ -n "$rigPostFile" ] || { printf 'no-post' ; return 0 ; }
	LC_ALL=C sed -n 's/.*"'"$3"'":"\([^"]*\)".*/\1/p' "$rigPostFile" | head -1
}

## ---- 1. S1: the setting, declared and shown by the digest, set per workspace ----
echo "-- S1: the setting is declared, shown by the digest, and set per workspace --"
rigSetWs="$rigTmp/ws-setting"
mkdir -p "$rigSetWs/.local/.agents" "$rigSetWs/.local/temp" "$rigSetWs/.local/agents" || rigRefuse "cannot make the setting rig's workspace"
rigSetFile="$rigSetWs/.local/.agents/magic-team.agent.env"
: > "$rigSetFile"
rigDirect "$rigSetWs" --manager-config-digest --full control > "$rigTmp/setting-digest" 2> "$rigTmp/setting-digest.err"
rigDigestRc=$?
rigAssert "the digest ends 0 and its control subject counts the new line" "$rigDigestRc:$( LC_ALL=C awk -F'\t' '$1 == "subject" && $2 == "control" { print $3 ; }' "$rigTmp/setting-digest" )" "0:3"
rigAssert "the setting is a declared changeable line, a choice of the workspace, unchanged by default" \
	"$( rigSettingDigestLine "$rigTmp/setting-digest" )" "control channel set none yes choice workspace default none=Printback,track=Tooling_Thread,full=Team_Thread settings"
rigAssert "and it is saved in the settings of the team of this workspace" \
	"$( rigSettingDigestFile "$rigTmp/setting-digest" )" "$rigSetFile"
rigDirect "$rigSetWs" --manager-config-set ROOT_HARNESS_VERBOSITY track > "$rigTmp/setting-save" 2> "$rigTmp/setting-save.err"
rigAssert "the one writer of a declared setting saves it: rc 0 and one row naming the key, the value, the scope and the file" \
	"$?:$( LC_ALL=C tr '\t' ' ' < "$rigTmp/setting-save" )" "0:saved ROOT_HARNESS_VERBOSITY track workspace $rigSetFile"
rigAssert "the settings of the team hold the value, one line, and nothing else was added" \
	"$( LC_ALL=C grep -c -x -F 'ROOT_HARNESS_VERBOSITY=track' "$rigSetFile" ):$( LC_ALL=C grep -c . "$rigSetFile" )" "1:1"
rigDirect "$rigSetWs" --agents-config-option magic-team --select ROOT_HARNESS_VERBOSITY > "$rigTmp/setting-select" 2> /dev/null
rigAssert "the tooling's own reading of the setting gives it back" "$( LC_ALL=C sed -n '1p' "$rigTmp/setting-select" )" "track"
rigDirect "$rigSetWs" --manager-config-set ROOT_HARNESS_VERBOSITY trace > "$rigTmp/setting-bad" 2> "$rigTmp/setting-bad.err"
rigBadRc=$?
rigAssert "a value the setting does not take is refused, rc 1, naming the three, and nothing is written" \
	"$rigBadRc:$( LC_ALL=C grep -c -F 'Its values: none, track, full' "$rigTmp/setting-bad.err" ):$( LC_ALL=C grep -c -x -F 'ROOT_HARNESS_VERBOSITY=track' "$rigSetFile" )" "1:1:1"

## THE KIND IS SET AT MINT (the Settled line): the setting is read once, when the session is made.
rigMint(){ ## workspace, scenario -- mints one session and keeps its id, token and text in rigMint*
	local rigMintWs="$1" rigMintScn="$2"
	rigServerWire="$rigTmp/wire-mint-${rigMintWs##*/}"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootCall 2 mint )" 2
	} | rigServer "$rigServerWire" "$rigMintWs" "$rigMintScn" ""
	rigStarted "$rigServerWire" "the mint server of ${rigMintWs##*/}"
	rigMintText="$( rigText "$( rigReply "$rigServerWire" 2 )" )"
	rigMintSession="$( rigFieldOf "$rigMintText" SESSION )"
	rigMintToken="$( rigFieldOf "$rigMintText" TOKEN )"
	[ -n "$rigMintSession" ] && [ -n "$rigMintToken" ] || rigRefuse "the RootSession mint printed no session id and token, so nothing below would be measured: $rigMintText"
}
rigMintScn="$rigTmp/scn-mint"
mkdir -p "$rigMintScn"
rigMint "$rigSetWs" "$rigMintScn"
rigAssert "a session minted under track records its kind at mint, beside the token" \
	"$( rigKindOf "$rigSetWs" "$rigMintSession" ):$( rigExists "$( rigSessionDir "$rigSetWs" "$rigMintSession" )/root-session.kind" ):$( rigExists "$( rigSessionDir "$rigSetWs" "$rigMintSession" )/root-session.token" )" "track:yes:yes"
rigSetTracked="$rigMintSession"
rigDirect "$rigSetWs" --manager-config-set ROOT_HARNESS_VERBOSITY full > /dev/null 2>&1
rigMint "$rigSetWs" "$rigMintScn"
rigAssert "the next mint reads the setting again and records full" "$( rigKindOf "$rigSetWs" "$rigMintSession" )" "full"
rigAssert "the session minted before the change keeps the kind it was given" "$( rigKindOf "$rigSetWs" "$rigSetTracked" )" "track"
rigMintSetScn="$rigMintScn"

## ---- the three workspaces, one a value, each with its own one session ----
rigValueWorkspace(){ ## value -- makes the workspace and its settings, keeps the paths in rigValueWs/rigValueScn
	local rigValue="$1"
	rigValueWs="$rigTmp/ws-$rigValue"
	rigValueScn="$rigTmp/scn-$rigValue"
	mkdir -p "$rigValueWs/.local/.agents" "$rigValueWs/.local/temp" "$rigValueScn" || rigRefuse "cannot make the $rigValue workspace"
	{
		printf 'ROOT_HARNESS_VERBOSITY=%s\n' "$rigValue"
		printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n'
		## The tooling thread exists only where an event-track conversation is configured: `none` has none,
		## so its spawn has no thread of any kind to open and no Slack call to make.
		[ "$rigValue" = "none" ] || printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n'
	} > "$rigValueWs/.local/.agents/magic-team.agent.env"
	## The console the spawn proxy launches: it records the dispatch it is handed and starts no model. It names
	## --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy greps for before it launches anything.
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured stand-in: records the dispatch and marks the launch.' \
		'cat > "$RIG_SCENARIO/dispatch"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigValueWs/DistroAgentsConsole.sh"
	chmod +x "$rigValueWs/DistroAgentsConsole.sh"
}
rigDispatch=""
rigSpawnHelper(){ ## value, session -- spawns the helper into that session; keeps the dispatch and the spawn id
	local rigSpawnValue="$1" rigSpawnSession="$2" rigSpawnOut="$rigTmp/spawn-$1.out"
	( cd "$rigValueWs" && env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigHome" MMDAPP="$rigValueWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigValueScn" RIG_CHAT="$rigValueScn/chat" \
		MDAT_SPAWN_SESSION_ID="$rigSpawnSession" MDAT_SPAWN_AGENT="$rigRootMember" \
		bash "$rigRigTool" --intern-op-agent-spawn-proxy "$rigHelperMember" --from-stdin --dispatch-doc:none \
			--context Agent --calling-member "$rigRootMember" --wait ) > "$rigSpawnOut" 2> "$rigSpawnOut.err" <<< "RIG-TASK dispatch this helper into the $rigSpawnValue session"
	rigSpawnRc=$?
	[ -f "$rigValueScn/dispatch" ] || rigRefuse "the fake console never received a dispatch in the $rigSpawnValue workspace, so nothing below would be measured: $( LC_ALL=C grep 'ERROR' "$rigSpawnOut" "$rigSpawnOut.err" | head -2 | LC_ALL=C tr '\n' ' ' )"
	rigDispatch="$( cat "$rigValueScn/dispatch" )"
	rigSpawnSessionOut="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigSpawnOut" | head -1 )"
	rigSpawnId=""
	for rigSpawnRecord in "$rigValueWs"/.local/agents/spawned/*/*.spawn.md ; do
		[ -f "$rigSpawnRecord" ] || continue
		LC_ALL=C grep -qx -F "session-id: $rigSpawnSession" "$rigSpawnRecord" || continue
		rigSpawnId="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigSpawnRecord" | head -1 )"
		break
	done
	[ -n "$rigSpawnId" ] || rigRefuse "the spawn made no record in the $rigSpawnValue session, so the helper could not be served: $( head -3 "$rigSpawnOut.err" | LC_ALL=C tr '\n' ' ' )"
}
rigHandback(){ ## helper session, spawn id -- one served SubagentHandback, its outcome kept in rigHandbackText
	rigServerWire="$rigTmp/wire-handback-$rigSpawnId"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigHandbackCall 2 "RIG-REPORT-$rigValueLabel" )" 2
	} | rigServer "$rigServerWire" "$rigValueWs" "$rigValueScn" "$1" "$2"
	rigStarted "$rigServerWire" "the helper's handback server"
	rigHandbackAnswer="$( rigReply "$rigServerWire" 2 )"
	rigHandbackText="$( rigText "$rigHandbackAnswer" )"
}
rigAddressed(){ ## workspace, scenario, session, token, label -- the root's served SendMessage to human-owner
	local rigAddressedWs="$1" rigAddressedScn="$2" rigAddressedSession="$3" rigAddressedToken="$4" rigAddressedLabel="$5"
	rigServerWire="$rigTmp/wire-addressed-$rigAddressedLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootAdopt 2 "$rigAddressedSession" "$rigAddressedToken" )" 2
		rigSend "$( rigSendMessageCall 3 human-owner "RIG-ADDRESSED-$rigAddressedLabel" "$rigHelperMember" )" 3
	} | rigServer "$rigServerWire" "$rigAddressedWs" "$rigAddressedScn" ""
	rigStarted "$rigServerWire" "the root's addressed-send server"
	rigAddressedAnswer="$( rigReply "$rigServerWire" 3 )"
	rigAddressedText="$( rigText "$rigAddressedAnswer" )"
}
rigWaitCall(){ ## id, timeout -- one served Wait, default mode, on this run's session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Wait","arguments":{"timeout":%s}}}' "$1" "$2"
}
rigRootWait(){ ## workspace, scenario, session, token, timeout, label -- the root's bare Wait, its text kept in rigWaitText
	local rigWaitWs="$1" rigWaitScn="$2" rigWaitSession="$3" rigWaitToken="$4" rigWaitTimeout="$5" rigWaitLabel="$6"
	rigServerWire="$rigTmp/wire-root-wait-$rigWaitLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootAdopt 2 "$rigWaitSession" "$rigWaitToken" )" 2
		rigSend "$( rigWaitCall 3 "$rigWaitTimeout" )" 3
	} | rigServer "$rigServerWire" "$rigWaitWs" "$rigWaitScn" ""
	rigStarted "$rigServerWire" "the root's $rigWaitLabel wait server"
	rigWaitAnswer="$( rigReply "$rigServerWire" 3 )"
	rigWaitText="$( rigText "$rigWaitAnswer" )"
}
rigHelperWait(){ ## workspace, scenario, session, spawn id, timeout, label -- the helper's bare Wait
	local rigWaitWs="$1" rigWaitScn="$2" rigWaitSession="$3" rigWaitSpawn="$4" rigWaitTimeout="$5" rigWaitLabel="$6"
	rigServerWire="$rigTmp/wire-helper-wait-$rigWaitLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigWaitCall 2 "$rigWaitTimeout" )" 2
	} | rigServer "$rigServerWire" "$rigWaitWs" "$rigWaitScn" "$rigWaitSession" "$rigWaitSpawn"
	rigStarted "$rigServerWire" "the helper's $rigWaitLabel wait server"
	rigWaitAnswer="$( rigReply "$rigServerWire" 2 )"
	rigWaitText="$( rigText "$rigWaitAnswer" )"
}
rigDismiss(){ ## workspace, scenario, session, token, label -- the root's served SendMessage DISMISSED to session-current
	local rigDismissWs="$1" rigDismissScn="$2" rigDismissSession="$3" rigDismissToken="$4" rigDismissLabel="$5"
	rigServerWire="$rigTmp/wire-dismiss-$rigDismissLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootAdopt 2 "$rigDismissSession" "$rigDismissToken" )" 2
		rigSend "$( rigSendMessageCall 3 session-current DISMISSED "$rigHelperMember" )" 3
	} | rigServer "$rigServerWire" "$rigDismissWs" "$rigDismissScn" ""
	rigStarted "$rigServerWire" "the root's dismissal server"
	rigDismissAnswer="$( rigReply "$rigServerWire" 3 )"
	rigDismissText="$( rigText "$rigDismissAnswer" )"
}
rigDefaultSources(){ ## workspace, session, spawn id, conversation threads (optional), session thread (optional)
	local rigDefaultsOut=""
	(
		cd "$1" && set +u
		unset MDAT_SESSION_THREAD MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID CLAUDE_CODE_SESSION_ID MDAT_SPAWN_AGENT MDAT_CONVERSATION_THREADS
		export MMDAPP="$1" MDLT_ORIGIN="$rigOrigin" MDAT_SESSION_ID="$2" MDAT_SPAWN_SESSION_ID="$3" MDAT_SPAWN_AGENT="$rigHelperMember"
		[ -z "${4:-}" ] || export MDAT_CONVERSATION_THREADS="$4"
		[ -z "${5:-}" ] || export MDAT_SESSION_THREAD="$5"
		. "$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" 2> /dev/null || :
		rigDefaultsOut="$( AgentsToolsWaitDefaultSources 2> /dev/null )" || rigDefaultsOut=""
		printf '%s' "${rigDefaultsOut:-<nothing>}"
	)
}

## ---- 2. S2: none -- the printback channel, no thread, no Slack call ----
echo "-- S2: none -- the session's external side is the printback channel; no thread is created --"
rigValueWorkspace none
rigMint "$rigValueWs" "$rigValueScn"
rigNoneSession="$rigMintSession"
rigNoneToken="$rigMintToken"
rigNoneChat="$( rigChatFile "$rigValueWs" "$rigNoneSession" )"
rigAssert "the minted session records the kind none, in a record of its own" "$( rigKindOf "$rigValueWs" "$rigNoneSession" ):$( rigExists "$( rigSessionDir "$rigValueWs" "$rigNoneSession" )/root-session.kind" )" "none:yes"
rigSpawnHelper none "$rigNoneSession"
rigNoneSpawnId="$rigSpawnId"
rigAssert "the spawn succeeds and puts the helper in the session" "$rigSpawnRc:$rigSpawnSessionOut" "0:$rigNoneSession"
rigAssert "the dispatch names the channel kind in use: printback" "$( rigTextCount "$rigDispatch" -F -- 'channel kind: printback' )" 1
rigAssert "and the channel-id it is named by" "$( rigTextCount "$rigDispatch" -F -- "printback:$rigNoneSession" )" 1
rigAssert "the dispatch hands over no session thread" "$( rigTextCount "$rigDispatch" -- '^session_thread_ts: none -- this session.s external side is the root-native printback' )" 1
rigAssert "no session thread and no tooling thread were created" "$( rigThreadOf "$rigValueWs" "$rigNoneSession" session.thread )/$( rigThreadOf "$rigValueWs" "$rigNoneSession" event-track.thread )" "none/none"
rigAssert "and the spawn made no Slack call at all: the fake curl is never reached" "$( rigSlackReached "$rigValueScn" )" "none"
rigValueLabel="none"
rigHandback "$rigNoneSession" "$rigSpawnId"
rigAssert "the helper's handback is served without error, on the printback channel" "$( rigIsError "$rigHandbackAnswer" ):$( rigTextCount "$rigHandbackText" -x -F -- "Sent to printback:$rigNoneSession (the printback channel of parent session $rigNoneSession) as $rigHelperMember. What the operation reported follows:" )" "no:1"
## F3.3 makes the helper's join a recorded notice of a printback session: it is block 1, origin `notice`,
## and the report is block 2. Nothing else of this check moves.
rigAssert "the join notice is recorded first and the report as the second block" \
	"$( rigHeaders "$rigNoneChat" ):$( rigIndexField "$rigNoneChat" 1 4 ):$( rigIndexField "$rigNoneChat" 2 2 ):$( rigIndexField "$rigNoneChat" 2 3 ):$( rigIndexField "$rigNoneChat" 2 4 )" \
	"2:notice:-:printback:$rigNoneSession:printback"
rigAssert "the body is the report, and the fake curl is still never reached" "$( rigTextCount "$( rigBody "$rigNoneChat" 2 )" -F -- "RIG-REPORT-none" ):$( rigSlackReached "$rigValueScn" )" "1:none"
rigAddressed "$rigValueWs" "$rigValueScn" "$rigNoneSession" "$rigNoneToken" none
rigNoneAddressedPost="$( rigPostBody "$rigValueScn" 'RIG-ADDRESSED-none' )"
rigAssert "S5: an addressed message is sent in none -- to human-owner's own conversation, and recorded" \
	"$( rigIsError "$rigAddressedAnswer" ):$( rigCalls "$rigValueScn" ):$( rigCount "$rigNoneAddressedPost" '"channel":"URIGOWNER"' ):$( rigTextCount "$( rigBody "$rigNoneChat" 3 )" -F -- 'RIG-ADDRESSED-none' )" \
	"no:1:1:1"
rigAssert "the printback channel is not the addressed message's: the address decides" "$( rigTextCount "$rigAddressedText" -F -- 'RIG-ADDRESSED-none' )" 1
rigAssert "S2/full unchanged: a printback session with a conversation present still defaults to its chat file alone" \
	"$( rigDefaultSources "$rigValueWs" "$rigNoneSession" "$rigNoneSpawnId" 'CRIG00001:1760000000.000900' )" "chat:$rigNoneSession"

## ---- 3. S3: track -- the tooling thread receives the duplicates, no session thread ----
echo "-- S3: track -- the tooling thread receives the duplicates; no session thread is created --"
rigValueWorkspace track
rigMint "$rigValueWs" "$rigValueScn"
rigTrackSession="$rigMintSession"
rigTrackToken="$rigMintToken"
rigTrackChat="$( rigChatFile "$rigValueWs" "$rigTrackSession" )"
rigAssert "the minted session records the kind track, in a record of its own" "$( rigKindOf "$rigValueWs" "$rigTrackSession" ):$( rigExists "$( rigSessionDir "$rigValueWs" "$rigTrackSession" )/root-session.kind" )" "track:yes"
rigSpawnHelper track "$rigTrackSession"
rigAssert "the spawn succeeds and puts the helper in the session" "$rigSpawnRc:$rigSpawnSessionOut" "0:$rigTrackSession"
rigTrackThread="$( rigThreadOf "$rigValueWs" "$rigTrackSession" event-track.thread )"
rigAssert "the spawn opens the session's tooling thread and records it" "$( rigThreadOf "$rigValueWs" "$rigTrackSession" event-track.thread | LC_ALL=C sed 's/:.*//' )" "CRIGTRACK"
rigAssert "no session thread was created" "$( rigThreadOf "$rigValueWs" "$rigTrackSession" session.thread )" "none"
rigAssert "the dispatch states the channel kind in use: track" "$( rigTextCount "$rigDispatch" -F -- 'channel kind: track' )" 1
rigAssert "and names the tooling thread the session's copies go to" "$( rigTextCount "$rigDispatch" -F -- "$rigTrackThread" )" 1
rigAssert "the dispatch hands over no session thread" "$( rigTextCount "$rigDispatch" -- '^session_thread_ts: none' )" 1
## The two floors are set before anything is addressed to either side, as a run's first Wait leaves them.
rigRootWait "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigTrackToken" 0 track-floor-root
rigAssert "the root's first Wait of the track session is a TIMEOUT, not an error" "$( rigFirstLine "$rigWaitText" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"
rigHelperWait "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigSpawnId" 0 track-floor-helper
rigAssert "the helper's first Wait of it is a TIMEOUT, not an error" "$( rigFirstLine "$rigWaitText" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"
rigValueLabel="track"
rigHandback "$rigTrackSession" "$rigSpawnId"
rigAssert "the helper's handback is served without error, on the parent session's tooling thread" \
	"$( rigIsError "$rigHandbackAnswer" ):$( rigTextCount "$rigHandbackText" -x -F -- "Sent to $rigTrackThread (the thread of parent session $rigTrackSession) as $rigHelperMember. What the operation reported follows:" )" "no:1"
rigAssert "THE TOOLING THREAD RECEIVES THE DUPLICATE: one post into it, one post only" \
	"$( rigPostCount "$rigValueScn" 'RIG-REPORT-track' ):$( rigPostField "$rigValueScn" 'RIG-REPORT-track' channel ):$( rigPostField "$rigValueScn" 'RIG-REPORT-track' thread_ts )" \
	"1:CRIGTRACK:${rigTrackThread#*:}"
rigAssert "the session's one chat file records it, from the run's own send" \
	"$( rigHeaders "$rigTrackChat" ):$( rigIndexField "$rigTrackChat" 1 4 )" "1:own"
rigAssert "no session thread was opened by the handback either" "$( rigThreadOf "$rigValueWs" "$rigTrackSession" session.thread )" "none"
## THE TRACK CHANNEL IS READ BACK (the coordinator's ruling): its record is the one chat file, and a bare Wait
## of the root reads it there -- the tooling thread received the copy, the chat file is the floor.
rigRootWait "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigTrackToken" 20 track-report
rigTrackFilters="$( printf '%s\n' "$rigWaitText" | LC_ALL=C sed -n 's/^# filters: //p' | head -1 )"
rigAssert "the root's bare Wait reads the helper's report back from the session's one chat file" \
	"$( rigFirstLine "$rigWaitText" ):$( rigTextCount "$rigWaitText" -F -- 'RIG-REPORT-track' ):$( rigTextCount "$rigWaitText" -F -- "# arrived on: slack:$rigTrackThread" )" \
	"WAIT-RESULT: RECEIVED:1:1"
rigAssert "and the wait's own filters name the chat file and no Slack source" \
	"$( rigTextCount "$rigTrackFilters" -F -- "chat:$rigTrackSession" ):$( rigTextCount "$rigTrackFilters" -F -- 'slack:' )" "1:0"
rigAddressed "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigTrackToken" track
rigTrackAddressedPost="$( rigPostBody "$rigValueScn" 'RIG-ADDRESSED-track' )"
rigAssert "S5: an addressed message is sent in track -- to human-owner's own conversation, whatever the setting says" \
	"$( rigIsError "$rigAddressedAnswer" ):$( rigCount "$rigTrackAddressedPost" '"channel":"URIGOWNER"' ):$( rigTextCount "$( rigBody "$rigTrackChat" 2 )" -F -- 'RIG-ADDRESSED-track' )" \
	"no:1:1"
rigAssert "and it went to the address, never into the tooling thread" "$( rigPostField "$rigValueScn" 'RIG-ADDRESSED-track' channel )" "URIGOWNER"
## The dismissal travels the same channel, and the helper's own bare Wait reads it back.
rigDismiss "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigTrackToken" track
rigAssert "the root's DISMISSED is served without error, copied into the tooling thread, and recorded" \
	"$( rigIsError "$rigDismissAnswer" ):$( rigPostField "$rigValueScn" 'DISMISSED' channel ):$( rigPostField "$rigValueScn" 'DISMISSED' thread_ts ):$( rigTextCount "$( rigBody "$rigTrackChat" 3 )" -x -F -- 'DISMISSED' )" \
	"no:CRIGTRACK:${rigTrackThread#*:}:1"
rigHelperWait "$rigValueWs" "$rigValueScn" "$rigTrackSession" "$rigSpawnId" 20 track-dismiss
rigAssert "the root's DISMISSED reaches the helper's bare Wait, which returns DISMISSED" \
	"$( rigFirstLine "$rigWaitText" ):$( rigTextCount "$rigWaitText" -F -- 'WAIT-DISMISSED-BY' ):$( rigTextCount "$rigWaitText" -F -- " | $rigRootMember" )" \
	"WAIT-RESULT: DISMISSED:1:1"
rigAssert "a track session with a conversation present still defaults to its chat file alone" \
	"$( rigDefaultSources "$rigValueWs" "$rigTrackSession" "$rigSpawnId" 'CRIG00001:1760000000.000900' )" "chat:$rigTrackSession"

## ---- 4. S4: full -- a normal session thread in the team channel ----
echo "-- S4: full -- a normal session thread is created in the team channel, as today --"
rigValueWorkspace full
rigMint "$rigValueWs" "$rigValueScn"
rigFullSession="$rigMintSession"
rigFullToken="$rigMintToken"
rigFullChat="$( rigChatFile "$rigValueWs" "$rigFullSession" )"
rigAssert "the minted session records the kind full, in a record of its own" "$( rigKindOf "$rigValueWs" "$rigFullSession" ):$( rigExists "$( rigSessionDir "$rigValueWs" "$rigFullSession" )/root-session.kind" )" "full:yes"
rigSpawnHelper full "$rigFullSession"
rigAssert "the spawn succeeds and puts the helper in the session" "$rigSpawnRc:$rigSpawnSessionOut" "0:$rigFullSession"
rigFullThread="$( rigThreadOf "$rigValueWs" "$rigFullSession" session.thread )"
rigAssert "a session thread is created in the team channel, and recorded as the session's" "$( printf '%s' "${rigFullThread%%:*}" )" "CRIG00001"
rigAssert "the dispatch hands that thread to the helper" "$( rigTextCount "$rigDispatch" -x -F -- "session_thread_ts: $rigFullThread" )" 1
rigAssert "the session thread's root is a top-level post in the team channel, seeded by the tooling" \
	"$( rigCallLine "$rigValueScn" chat.postMessage CRIG00001 | LC_ALL=C awk '$3 == "-" { print "root" ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' )" "root"
rigValueLabel="full"
rigHandback "$rigFullSession" "$rigSpawnId"
rigAssert "the helper's handback is served without error, on the session thread" \
	"$( rigIsError "$rigHandbackAnswer" ):$( rigTextCount "$rigHandbackText" -x -F -- "Sent to $rigFullThread (the thread of parent session $rigFullSession) as $rigHelperMember. What the operation reported follows:" )" "no:1"
rigAssert "the session thread receives it, and the session's one chat file records it" \
	"$( rigPostField "$rigValueScn" 'RIG-REPORT-full' channel ):$( rigPostField "$rigValueScn" 'RIG-REPORT-full' thread_ts ):$( rigHeaders "$rigFullChat" ):$( rigIndexField "$rigFullChat" 1 4 )" \
	"CRIG00001:${rigFullThread#*:}:1:own"
rigAddressed "$rigValueWs" "$rigValueScn" "$rigFullSession" "$rigFullToken" full
rigFullAddressedPost="$( rigPostBody "$rigValueScn" 'RIG-ADDRESSED-full' )"
rigAssert "S5: an addressed message is sent in full too -- to human-owner's own conversation" \
	"$( rigIsError "$rigAddressedAnswer" ):$( rigCount "$rigFullAddressedPost" '"channel":"URIGOWNER"' ):$( rigTextCount "$( rigBody "$rigFullChat" 2 )" -F -- 'RIG-ADDRESSED-full' )" \
	"no:1:1"
rigAssert "S4/full unchanged: a bare Wait's default sources stay the session thread and the conversations it continues" \
	"$( rigDefaultSources "$rigValueWs" "$rigFullSession" "$rigSpawnId" 'CRIG00001:1760000000.000900' "$rigFullThread" )" \
	"slack:$rigFullThread:conversation slack:CRIG00001:1760000000.000900:conversation"

## ---- 5. the floor: one record a session, no second channel, no background ----
echo "-- the floor: the session's one chat file, no outbox or inbox, nothing of the setting in a result --"
for rigOne in none track ; do
	rigOneWs="$rigTmp/ws-$rigOne"
	rigOneChat="$rigTmp/ws-$rigOne/.local/agents/sessions"
	case "$rigOne" in
		none) rigOneExpected="$rigNoneChat" ;;
		track) rigOneExpected="$rigTrackChat" ;;
	esac
	rigAssert "the $rigOne workspace holds exactly one session chat file: the session's own" \
		"$( rigChats "$rigOneWs" | LC_ALL=C tr '\n' ' ' )" "$rigOneExpected "
	rigAssert "the $rigOne session left no outbox and no inbox" \
		"$( rigExists "$( find "$rigOneChat" -name 'chat.outbox' -type f 2> /dev/null | head -1 )" ):$( rigExists "$( find "$rigOneChat" -name 'chat.inbox' -type f 2> /dev/null | head -1 )" )" "no:no"
done
## `full` is today's path: the tooling's joined line is a send of the spawn's own process, and it records
## under the run's id as it always has (a chat file of the run's folder, beside the one of the session).
rigAssert "in full the session's own chat file is the one record of its messages" \
	"$( rigHeaders "$rigFullChat" ):$( rigTextCount "$( rigBody "$rigFullChat" 1 )" -F -- 'RIG-REPORT-full' ):$( rigTextCount "$( rigBody "$rigFullChat" 2 )" -F -- 'RIG-ADDRESSED-full' )" \
	"2:1:1"
rigFloorChat="$( rigChatFile "$rigTmp/ws-track" "$rigTrackSession" )"
rigAssert "the printback workspace's only Slack send log line is the addressed message's" \
	"$( cat "$rigTmp"/ws-none/.local/agents/comms-slack-send.*.log 2> /dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -c -F -- 'URIGOWNER' "$rigTmp"/ws-none/.local/agents/comms-slack-send.*.log 2> /dev/null )" "1:1"
rigAssert "no result of any call carried the settings file's path" "$( LC_ALL=C cat "$rigTmp"/wire-* "$rigTmp"/spawn-*.out 2> /dev/null | LC_ALL=C grep -c -F -- 'magic-team.agent.env' )" 0
rigAssert "the report of a track handback is in the tooling thread and in the session's one chat file, nowhere else" \
	"$( rigPostCount "$rigTmp/scn-track" 'RIG-REPORT-track' ):$( rigCount "$rigFloorChat" 'RIG-REPORT-track' )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT HARNESS VERBOSITY (F3.1) CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROOT_HARNESS_VERBOSITY: OK (%d assertions, offline)\n' "$rigPassCount"
