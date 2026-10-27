#!/usr/bin/env bash
## AgentsHarnessNoticeSurfaceCheck -- behavioural check on background notices (F3.3 of the root-harness epic),
## run rather than read. Held, one case per statement, on a `none` session, with the other two kinds as guards:
##
##   S1. A NOTICE FROM THE SPAWN PROXY IS RECORDED IN THE CHAT FILE. A real spawn proxy run brings a helper
##       into a root session minted under `none` and leaves it running detached; the helper's console exits
##       at once with no handback. The proxy records the start notice (`rig-helper joined`) when the helper
##       arrives and, when its close finds no handback, the end notice (`... posted no handback`) -- both as
##       blocks of the session's ONE chat file whose index says origin `notice` and conversation the session's
##       printback channel. Nothing of either is printed by the proxy, posted to Slack, or kept anywhere else;
##       the session still opens no session thread.
##
##   S2. ON THE PRINTBACK CHANNEL, THE NEXT FOREGROUND CALL SURFACES ONE LINE PER NOTICE. A real
##       `--intern-mcp-server --run` process adopts the session and serves two calls in order. The first call
##       carries, as a content part of its own beside the tool's result, exactly one line for each recorded
##       notice -- the two notice lines and nothing else -- while the tool's own output stays exactly what the
##       tool printed. The date part is the reply layer's, as before.
##
##   S3. A SURFACED NOTICE IS NEVER SURFACED TWICE. The second served call carries no notice line at all, and
##       the chat index now names the root member as the one each notice was surfaced to: the mark is durable,
##       in the one chat file, not a buffer of the server process.
##
##   THE OTHER KINDS ARE UNCHANGED. A helper is brought into a `track` session and into a `full` session with
##       the same console: neither chat file gains a `notice` block, `track` still says nothing at the join,
##       `full` still posts the join into its session thread, and neither served call carries a notice part.
##
## THE BACKGROUND CASE IS THE DETACHED SPAWN: its start notice is recorded while the spawn call runs, its end
## notice after the root's call has returned. The `none` workspace configures SLACK_CHANNEL_EVENT_TRACK because
## that is the workspace's tracking channel, and the spawn's handback check runs only where a tracking thread
## exists; F3.1's claim that `none` opens no thread is about the SESSION thread, and this check asserts that no
## `session.thread` is made. The notice itself is recorded on the printback channel and never posted.
##
## THE RIG ORIGIN. Every run is the package COPY in this rig (never the tree under test): `origin/myx/
## myx.distro-agents`, with the REAL `myx.distro-system` and `myx.distro-.local` linked READ-ONLY beside it --
## never a mute stand-in. Every workspace is a folder of the rig's own, its one session minted by a real
## `--intern-mcp-server --run` process (RootSession), its helper brought in by a real spawn proxy run (a fake
## console records the dispatch and starts no model).
##
## Offline: a Slack-shaped fake curl is first on PATH (this rig's whole of the offline guarantee; it logs every
## call, keeps every posted payload, and answers a post with the channel it was given), every workspace is a
## folder of the rig's own, and no model CLI is started.
##
## RED RECIPE. Run this check against a COPY of the RECEIVED tree -- everything before F3.3 -- with only this
## check added to its `sh-test`. Nothing else is changed.
##
##   cp -Rp pristine/myx.distro-agents red/origin/myx/myx.distro-agents
##   ln -s <real myx.distro-system> red/origin/myx/myx.distro-system        # and myx.distro-.local
##   cp origin/.../sh-test/harness/AgentsHarnessNoticeSurfaceCheck.test.sh red/origin/.../sh-test/
##   MDLT_ORIGIN=$PWD/red/origin MMDAPP=$PWD/workspace MDAT_SKILLSET_ROOT=<skillset> \
##     bash red/origin/myx/myx.distro-agents/sh-test/harness/AgentsHarnessNoticeSurfaceCheck.test.sh
##
## Red is S1 first, on the received tree's own reason: a printback session has no session thread, and the spawn
## proxy tells a session of a helper's arrival only in a thread and of a run's end only where a thread or the
## tracking channel gives it a place to tell; with neither, nothing is said, so the chat file makes no block at
## all and S1's recordings are absent. S2 then has nothing to surface, and the S3 assertions that read the same
## record fail behind it. The guards that stand on the received tree -- the tool's own output unchanged, the
## empty second call, and both unchanged kinds -- pass there, as they must: the red is the NOTICE NOT RECORDED,
## never a check that did not run. Recorded run: 9 of 23 assertions fail, S1 first, then S2/S3 (the chat-file
## readings), the guards green.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigSlackStub="$rigFixtures/session-address-first.curl.stub.sh"
rigRootMember="magic-coordinator"
rigHelperMember="rig-helper"

## Refusing to report is this block's whole job: a run that exercised nothing must never print a pass, and an
## empty extraction is a fault here rather than a clean result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigSlackStub" "$rigFixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessNoticeSurfaceCheck )" || exit 1
trap 'for rigClean in 1 2 3 4 5 ; do sleep 0.5 ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null ; [ -e "$rigTmp" ] || break ; done' EXIT
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
cp "$rigSlackStub" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
[ "$( PATH="$rigBin:$PATH" command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on its PATH"

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
rigTextCount(){ ## text, then the grep options and the pattern -- matching lines, 0 when none
	local rigCountText="$1"
	shift
	rigCountText="$( printf '%s\n' "$rigCountText" | LC_ALL=C grep -c "$@" 2> /dev/null )" || :
	printf '%s' "${rigCountText:-0}"
}
rigLineCount(){ ## text -- its non-empty lines, 0 when none
	printf '%s\n' "$1" | LC_ALL=C awk 'NF { count++ } END { print count + 0 }'
}

## ---- wire readers, as the root-session checks read their servers ----
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2> /dev/null || :
}
rigText(){ ## answer line file -- the first text part of the result
	rigValue "$1" result.content.0.text
}
rigPartCount(){ ## answer line file -- how many text parts the result content has, 0 when none
	local rigParts="$( rigValue "$1" result.content.__count )"
	case "$rigParts" in ''|*[!0123456789]*) rigParts=0 ;; esac
	printf '%s' "$rigParts"
}
rigPartText(){ ## answer line file, index -- that content part's text
	rigValue "$1" "result.content.$2.text"
}
rigPartHas(){ ## answer line file, fixed text -- how many text parts hold it
	local rigHasAt=0 rigHasCount=0 rigHasParts="$( rigPartCount "$1" )"
	while [ "$rigHasAt" -lt "$rigHasParts" ] ; do
		LC_ALL=C grep -q -F -- "$2" < <( rigPartText "$1" "$rigHasAt" ) && rigHasCount=$(( rigHasCount + 1 ))
		rigHasAt=$(( rigHasAt + 1 ))
	done
	printf '%s' "$rigHasCount"
}
rigPartLineCount(){ ## answer line file, fixed text -- the non-empty lines of the one part that holds it
	local rigPartAt=0 rigPartParts="$( rigPartCount "$1" )" rigPartFound=""
	while [ "$rigPartAt" -lt "$rigPartParts" ] ; do
		rigPartFound="$( rigPartText "$1" "$rigPartAt" )"
		if printf '%s' "$rigPartFound" | LC_ALL=C grep -q -F -- "$2" ; then
			rigLineCount "$rigPartFound"
			return 0
		fi
		rigPartAt=$(( rigPartAt + 1 ))
	done
	printf 'no-part'
}
rigPartTextOf(){ ## answer line file, fixed text -- the text of the one part that holds it, `no-part` for none
	local rigPartAt=0 rigPartParts="$( rigPartCount "$1" )" rigPartFound=""
	while [ "$rigPartAt" -lt "$rigPartParts" ] ; do
		rigPartFound="$( rigPartText "$1" "$rigPartAt" )"
		if printf '%s' "$rigPartFound" | LC_ALL=C grep -q -F -- "$2" ; then
			printf '%s' "$rigPartFound"
			return 0
		fi
		rigPartAt=$(( rigPartAt + 1 ))
	done
	printf 'no-part'
}
rigReply(){ ## wire file, request id -- path of the line carrying that answer, empty when none
	local rigReplyFile="$1.id$2"
	: > "$rigReplyFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rigReplyFile" 2> /dev/null || :
	printf '%s' "$rigReplyFile"
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
rigSend(){ ## json line, id -- write it to the server, wait until that request is answered
	printf '%s\n' "$1"
	rigWaitAt=0
	while ! LC_ALL=C grep -q "\"id\":$2," "$rigServerWire" 2> /dev/null && [ "$rigWaitAt" -lt 6000 ] ; do
		sleep 0.1
		rigWaitAt=$(( rigWaitAt + 1 ))
	done
}
## One real server process: its stdin read to the end, its wire kept. The root process carries no run of its
## own: it has no MDAT_SESSION_THREAD, no MDAT_SESSION_ID and no spawn agent, and a served call adopts the
## minted session, as the root's own server does.
rigServer(){ ## wire file, workspace, scenario
	mkdir -p "$2/.local/temp" "$2/.local/.agents" || rigRefuse "cannot make the workspace $2"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		-u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u SUDO_USER -u SLACK_USER_TOKEN -u MDAT_SESSION_THREAD \
		MMDAPP="$2" MDLT_ORIGIN="$rigOrigin" HOME="$rigHome" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$3" PATH="$rigBin:$PATH" \
		bash "$rigRigTool" --intern-mcp-server --run > "$1" 2> "$1.err" || :
}
rigInit(){ printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' ; }
rigRootCall(){ ## id, operation -- one RootSession request
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}' "$1" "$2"
}
rigRootAdopt(){ ## id, session, token -- the RootSession adopt that makes a new server carry the minted session
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"adopt","session":"%s","token":"%s"}}}' "$1" "$2" "$3"
}
rigExecuteCall(){ ## id, marker -- one served execute call, its output the marker
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"execute","arguments":{"command":"echo %s"}}}' "$1" "$2"
}

## ---- the session's own records, as the check reads them ----
rigSessionDir(){ printf '%s' "$1/.local/agents/sessions/$2" ; }
rigChatFile(){ printf '%s/session.chat' "$( rigSessionDir "$1" "$2" )" ; }
rigIndexFile(){ printf '%s/session.chat.index' "$( rigSessionDir "$1" "$2" )" ; }
rigExists(){ [ -e "$1" ] && printf yes || printf no ; }
rigKindOf(){ ## workspace, session -- the recorded kind
	local rigKindValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/root-session.kind" ] || IFS= read -r rigKindValue < "$( rigSessionDir "$1" "$2" )/root-session.kind" || :
	printf '%s' "$rigKindValue"
}
rigThreadOf(){ ## workspace, session, record name -- the recorded thread, `none` when absent
	local rigThreadValue=""
	[ ! -f "$( rigSessionDir "$1" "$2" )/$3" ] || IFS= read -r rigThreadValue < "$( rigSessionDir "$1" "$2" )/$3" || :
	printf '%s' "${rigThreadValue:-none}"
}
rigIndexField(){ ## chat file, block, field 1..6 -- that field of the block's index line
	[ -f "$1.index" ] || { printf 'no-index' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v want="$2" -v field="$3" '$1 == want { print $field ; found = 1 ; exit ; } END { if ( ! found ) { print "no-such-block" ; } }' "$1.index"
}
rigNoticeCount(){ ## workspace, session -- index blocks recorded as notices on the printback channel
	local rigNoticeIndex=""
	rigNoticeIndex="$( rigIndexFile "$1" "$2" )"
	[ -f "$rigNoticeIndex" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -F'\t' -v where="printback:$2" '$3 == where && $4 == "notice" { count++ } END { print count + 0 }' "$rigNoticeIndex"
}
rigPrintbackCount(){ ## chat file -- index lines whose conversation is a printback channel
	[ -f "$1.index" ] || { printf 0 ; return 0 ; }
	LC_ALL=C awk -F'\t' '$3 ~ /^printback:/ { count++ } END { print count + 0 }' "$1.index"
}
rigNoticeBody(){ ## workspace, session, notice number (1-based among the notice blocks) -- its body, one line
	local rigBodyIndex="" rigBodyChat=""
	rigBodyIndex="$( rigIndexFile "$1" "$2" )"
	rigBodyChat="$( rigChatFile "$1" "$2" )"
	[ -f "$rigBodyIndex" ] && [ -f "$rigBodyChat" ] || { printf 'no-file' ; return 0 ; }
	LC_ALL=C awk -F'\t' -v where="printback:$2" -v want="$3" '
		FILENAME == ARGV[1] { if ( $3 == where && $4 == "notice" ) { seen++ ; if ( seen == want ) { head = $5 ; found = 1 } } next }
		found && FNR >= head { if ( FNR == head ) { body = "" ; next } if ( $0 ~ /^[ \t]*$/ ) { if ( body != "" ) { exit } next } body = ( body == "" ) ? $0 : body " " $0 }
		END { print ( body == "" ) ? "no-body" : body }
	' "$rigBodyIndex" "$rigBodyChat"
}
rigWaitNotices(){ ## workspace, session, count, tries -- yes when the chat index has that many notice blocks
	local rigWaitTries="${4:-80}" rigWaitAt=0
	while [ "$rigWaitAt" -lt "$rigWaitTries" ] ; do
		[ "$( rigNoticeCount "$1" "$2" )" -ge "$3" ] && { printf yes ; return 0 ; }
		sleep 0.5
		rigWaitAt=$(( rigWaitAt + 1 ))
	done
	printf no
}

## ---- the fake Slack, as the offline copy of every Slack call ----
rigPostCount(){ ## scenario, fixed text -- how many posted payloads hold the text
	local rigPostFile="" rigPostSeen=0
	for rigPostFile in "$1"/post.* ; do
		[ -f "$rigPostFile" ] || continue
		LC_ALL=C grep -q -F -- "$2" "$rigPostFile" && rigPostSeen=$(( rigPostSeen + 1 ))
	done
	printf '%s' "$rigPostSeen"
}

## ---- the rig's own workspaces, mint and spawn ----
rigWorkspace(){ ## kind -- makes the workspace, its settings and its fake console; keeps rigWs and rigScn
	local rigMakeKind="$1"
	rigWs="$rigTmp/ws-$rigMakeKind"
	rigScn="$rigTmp/scn-$rigMakeKind"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScn" || rigRefuse "cannot make the $rigMakeKind workspace"
	{
		printf 'ROOT_HARNESS_VERBOSITY=%s\n' "$rigMakeKind"
		printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n'
		## Every workspace keeps the team's tracking channel: the spawn's handback check, which records the
		## end notice, runs only where a tracking thread exists. `none` still opens no SESSION thread.
		printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n'
	} > "$rigWs/.local/.agents/magic-team.agent.env"
	## The console the spawn proxy launches: it records the dispatch and starts no model. It names
	## --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy greps for before it launches anything.
	printf '%s\n' '#!/usr/bin/env bash' '## --cli-configured stand-in: records the dispatch and marks the launch.' \
		'cat > "$RIG_SCENARIO/dispatch"' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
	chmod +x "$rigWs/DistroAgentsConsole.sh"
}
rigMint(){ ## workspace, scenario -- mints one session; keeps rigSession, rigToken and rigChat
	local rigMintText=""
	rigServerWire="$rigTmp/wire-mint-${1##*/}"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootCall 2 mint )" 2
	} | rigServer "$rigServerWire" "$1" "$2"
	rigStarted "$rigServerWire" "the mint server of ${1##*/}"
	rigMintText="$( rigText "$( rigReply "$rigServerWire" 2 )" )"
	rigSession="$( printf '%s\n' "$rigMintText" | LC_ALL=C sed -n 's/^SESSION: //p' | head -n 1 )"
	rigToken="$( printf '%s\n' "$rigMintText" | LC_ALL=C sed -n 's/^TOKEN: //p' | head -n 1 )"
	[ -n "$rigSession" ] && [ -n "$rigToken" ] || rigRefuse "the RootSession mint printed no session id and token: $rigMintText"
	rigChat="$( rigChatFile "$1" "$rigSession" )"
}
rigSpawn(){ ## workspace, scenario, session, `wait` or `detach` -- a real spawn proxy run, fake console, no model
	local rigSpawnWs="$1" rigSpawnScn="$2" rigSpawnSession="$3" rigSpawnMode="$4" rigSpawnOut="$rigTmp/spawn-${1##*/}.out" rigSpawnWait=""
	[ "$rigSpawnMode" != "wait" ] || rigSpawnWait="--wait"
	( cd "$rigSpawnWs" && env -i PATH="$rigBin:/usr/bin:/bin" HOME="$rigHome" MMDAPP="$rigSpawnWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigSpawnScn" RIG_CHAT="$rigSpawnScn/chat" \
		MDAT_SPAWN_SESSION_ID="$rigSpawnSession" MDAT_SPAWN_AGENT="$rigRootMember" \
		bash "$rigRigTool" --intern-op-agent-spawn-proxy "$rigHelperMember" --from-stdin --dispatch-doc:none \
			--context Agent --calling-member "$rigRootMember" $rigSpawnWait ) > "$rigSpawnOut" 2> "$rigSpawnOut.err" <<< "RIG-TASK bring $rigHelperMember into the $rigSpawnSession session"
	rigSpawnRc=$?
	## A detached spawn returns before its background run has started the console: the dispatch is the
	## evidence that the console really ran, so it is waited for, bounded.
	rigSpawnAt=0
	while [ ! -f "$rigSpawnScn/dispatch" ] && [ "$rigSpawnAt" -lt 200 ] ; do
		sleep 0.1
		rigSpawnAt=$(( rigSpawnAt + 1 ))
	done
	[ -f "$rigSpawnScn/dispatch" ] || rigRefuse "the fake console never received a dispatch in ${rigSpawnWs##*/}, so the spawn was not exercised: $( LC_ALL=C grep 'ERROR' "$rigSpawnOut" "$rigSpawnOut.err" 2> /dev/null | head -2 | LC_ALL=C tr '\n' ' ' )"
	rigSpawnSessionOut="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigSpawnOut" | head -1 )"
}
rigServed(){ ## workspace, scenario, session, token, label, then the calls as id:marker pairs -- one server, in order
	local rigServedWs="$1" rigServedScn="$2" rigServedSession="$3" rigServedToken="$4" rigServedLabel="$5"
	shift 5
	rigServerWire="$rigTmp/wire-served-$rigServedLabel"
	: > "$rigServerWire"
	{
		rigSend "$( rigInit )" 1
		rigSend "$( rigRootAdopt 2 "$rigServedSession" "$rigServedToken" )" 2
		while [ $# -ge 2 ] ; do
			rigSend "$( rigExecuteCall "$1" "$2" )" "$1"
			shift 2
		done
	} | rigServer "$rigServerWire" "$rigServedWs" "$rigServedScn"
	rigStarted "$rigServerWire" "the root's $rigServedLabel server"
}

## ============================== S1-S3: none ==============================
echo "-- S1: a spawn proxy notice is recorded in the chat file of a none session --"
rigWorkspace none
rigMint "$rigWs" "$rigScn"
rigNoneSession="$rigSession"
rigNoneToken="$rigToken"
rigNoneChat="$rigChat"
rigAssert "the minted session records the kind none" "$( rigKindOf "$rigWs" "$rigNoneSession" )" "none"
rigSpawn "$rigWs" "$rigScn" "$rigNoneSession" detach
rigAssert "the spawn starts the helper detached" "$rigSpawnRc:$rigSpawnSessionOut" "0:$rigNoneSession"
## The start notice is recorded by the spawn call itself; the end notice comes from the detached close, so the
## check waits for it, bounded, and reports what it found rather than hanging.
rigAssert "the start and end notices are both recorded, within the bound" \
	"$( rigWaitNotices "$rigWs" "$rigNoneSession" 2 80 )" "yes"
rigAssert "the chat file records exactly two notice blocks, on the session's printback channel" \
	"$( rigNoticeCount "$rigWs" "$rigNoneSession" ):$( rigIndexField "$rigNoneChat" 1 3 ):$( rigIndexField "$rigNoneChat" 1 4 ):$( rigIndexField "$rigNoneChat" 2 4 )" \
	"2:printback:$rigNoneSession:notice:notice"
rigAssert "the first notice is the helper's start, one line" \
	"$( rigNoticeBody "$rigWs" "$rigNoneSession" 1 )" "$rigHelperMember joined"
rigAssert "the second is its end with no handback, one line" \
	"$( printf '%s' "$( rigNoticeBody "$rigWs" "$rigNoneSession" 2 )" | LC_ALL=C grep -c -F -- 'posted no handback' )" "1"
rigAssert "no session thread was created (none's external side is the printback channel)" \
	"$( rigThreadOf "$rigWs" "$rigNoneSession" session.thread )" "none"
rigAssert "no Slack post carries either notice line: the record is the chat file's" \
	"$( rigPostCount "$rigScn" "$rigHelperMember joined" ):$( rigPostCount "$rigScn" 'posted no handback' )" "0:0"
rigAssert "the notices are marked delivered to nobody yet" \
	"$( rigIndexField "$rigNoneChat" 1 6 ):$( rigIndexField "$rigNoneChat" 2 6 )" "-:-"

echo "-- S2/S3: the next foreground call surfaces one line per notice, once --"
rigServed "$rigWs" "$rigScn" "$rigNoneSession" "$rigNoneToken" none 3 CALL-ONE 4 CALL-TWO
rigFirstAnswer="$( rigReply "$rigServerWire" 3 )"
rigSecondAnswer="$( rigReply "$rigServerWire" 4 )"
rigAssert "S2: the first call's own result is exactly what the tool printed" "$( rigText "$rigFirstAnswer" )" "CALL-ONE"
rigAssert "S2: the notices are a content part of their own, one line each" \
	"$( rigPartHas "$rigFirstAnswer" "$rigHelperMember joined" ):$( rigPartLineCount "$rigFirstAnswer" "$rigHelperMember joined" )" "1:2"
rigAssert "S2: that part holds the end notice's line too" \
	"$( printf '%s' "$( rigPartTextOf "$rigFirstAnswer" "$rigHelperMember joined" )" | LC_ALL=C grep -c -F -- 'posted no handback' )" "1"
rigAssert "S2: the notices are not inside the tool's own output" \
	"$( printf '%s' "$( rigText "$rigFirstAnswer" )" | LC_ALL=C grep -c -F -- 'joined' )" "0"
rigAssert "S3: the first call carries each notice line exactly once" \
	"$( printf '%s\n' "$( rigPartTextOf "$rigFirstAnswer" "$rigHelperMember joined" )" | LC_ALL=C grep -c -x -F -- "$rigHelperMember joined" )" "1"
rigAssert "S3: the second call carries no notice line at all" \
	"$( rigPartHas "$rigSecondAnswer" "$rigHelperMember joined" ):$( rigPartHas "$rigSecondAnswer" 'posted no handback' )" "0:0"
rigAssert "S3: the chat index marks each notice as surfaced to the root member" \
	"$( rigIndexField "$rigNoneChat" 1 6 ):$( rigIndexField "$rigNoneChat" 2 6 )" "$rigRootMember:$rigRootMember"

## ============================== track and full: unchanged ==============================
echo "-- track: the tooling thread, and no notice block --"
rigWorkspace track
rigMint "$rigWs" "$rigScn"
rigTrackSession="$rigSession"
rigTrackToken="$rigToken"
rigTrackChat="$rigChat"
rigSpawn "$rigWs" "$rigScn" "$rigTrackSession" wait
rigAssert "track: the spawn succeeds and opens the session's tooling thread" \
	"$rigSpawnRc:$( rigThreadOf "$rigWs" "$rigTrackSession" event-track.thread | LC_ALL=C sed 's/:.*//' )" "0:CRIGTRACK"
rigAssert "track: no notice block and no printback conversation are recorded" \
	"$( rigNoticeCount "$rigWs" "$rigTrackSession" ):$( rigPrintbackCount "$rigTrackChat" )" "0:0"
rigServed "$rigWs" "$rigScn" "$rigTrackSession" "$rigTrackToken" track 3 CALL-TRACK
rigTrackAnswer="$( rigReply "$rigServerWire" 3 )"
rigAssert "track: the served call carries no notice part" "$( rigPartHas "$rigTrackAnswer" "$rigHelperMember joined" )" "0"

echo "-- full: the session thread, and no notice block --"
rigWorkspace full
rigMint "$rigWs" "$rigScn"
rigFullSession="$rigSession"
rigFullToken="$rigToken"
rigFullChat="$rigChat"
rigSpawn "$rigWs" "$rigScn" "$rigFullSession" wait
rigAssert "full: the spawn succeeds and opens the session's team-channel thread" \
	"$rigSpawnRc:$( rigThreadOf "$rigWs" "$rigFullSession" session.thread | LC_ALL=C sed 's/:.*//' )" "0:CRIG00001"
rigAssert "full: the join is still posted into the session thread" "$( rigPostCount "$rigScn" "$rigHelperMember joined" )" "1"
rigAssert "full: no notice block and no printback conversation are recorded" \
	"$( rigNoticeCount "$rigWs" "$rigFullSession" ):$( rigPrintbackCount "$rigFullChat" )" "0:0"
rigServed "$rigWs" "$rigScn" "$rigFullSession" "$rigFullToken" full 3 CALL-FULL
rigFullAnswer="$( rigReply "$rigServerWire" 3 )"
rigAssert "full: the served call carries no notice part" "$( rigPartHas "$rigFullAnswer" "$rigHelperMember joined" )" "0"

echo
rigTotal=$(( rigPassCount + rigFailCount ))
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'HARNESS NOTICE SURFACE: OK (%d assertions, offline)\n' "$rigTotal"
	exit 0
fi
printf '⛔ HARNESS NOTICE SURFACE (F3.3) CHECK FAILED: %d of %d assertion(s)\n%d PASS, %d FAIL\n' \
	"$rigFailCount" "$rigTotal" "$rigPassCount" "$rigFailCount"
exit 1
