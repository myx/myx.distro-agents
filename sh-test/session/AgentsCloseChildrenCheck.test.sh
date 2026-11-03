#!/usr/bin/env bash
## Behavioural check on S27.5, under S6.25: an executor's close dismisses every run it spawned and that still
## waits, matched on `parent-spawn-id`. The dismissal is the tooling's own state: the run's mark is kept, the
## session chat file records it, and one line to @here says what was ended. Nothing is posted to the run.
## Red before S27.5: the child is left waiting on a run that is gone.
## Offline: a Slack-shaped fake curl logs each post and opens no socket; each run is a stand-in
## process carrying its own spawn id; the workspace and board are this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigSandbox="$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigFixture="$rigPkg/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSandbox" ] || rigRefuse "the spawn sandbox include is not at the origin: $rigSandbox"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCloseChildrenCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions" "$rigSpawned" "$rigTmp/bin" "$rigTmp/data/board"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '{"ok":true,"messages":[{"ts":"1700000002.000100","user":"URIGBOT01","text":"opened"}],"has_more":false}\n' > "$rigTmp/replies.json"
for rigMember in magic-coordinator magic-tester keeper-myx ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
done
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigRecord(){ ## spawn, session, owner, parent spawn, start context, session thread
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$1"
	printf '%s\n' "$6" > "$rigWs/.local/agents/sessions/$1/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nstart-context: %s\nparent-session-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nsession-thread: %s\n---\n' \
		"$2" "$1" "$4" "$5" "$2" "$1" "$rigHost" "$3" "$6" > "$rigSpawned/$1/$1.spawn.md"
}
rigMark(){ ## spawn id -- what its tooling dismissal mark holds, or `none`
	if [ -f "$rigWs/.local/agents/sessions/$1/dismissed" ] ; then
		LC_ALL=C head -1 "$rigWs/.local/agents/sessions/$1/dismissed"
	else
		printf 'none'
	fi
}
rigCountIn(){ ## file, text -- how many lines of the file hold the text, 0 where the file is not there
	if [ ! -f "$1" ] ; then printf '0' ; return 0 ; fi
	LC_ALL=C awk -v want="$2" 'index( $0, want ) { found++ } END { print found + 0 }' "$1"
}
rigLive(){ ## spawn id -- a stand-in process carrying the id, in the host process list
	python3 -I -B -c 'import time; time.sleep(600)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
}
rigStatus(){ ## record path
	LC_ALL=C sed -n 's/^status: //p' "$1" 2> /dev/null | head -1
}
rigClose(){ ## record path -- the close the proxy runs when a run ends, in this scene
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$1" ; AgentsToolsSpawnProxyCloseSandbox "$2" succeeded 0 "the rig ended it"' rig "$rigSandbox" "$1" 2>&1
}

echo "-- 1. a parent's close dismisses the children still waiting on it (S27.5) --"
: > "$rigTmp/curl.log" ; : > "$rigTmp/bodies"
rigRecord rig-parent-$$ rig-parent-$$ magic-coordinator none spawned CPARENT01:1700000000.000100
rigRecord rig-child-$$ rig-parent-$$ magic-tester rig-parent-$$ joined CCHILD01:1700000000.000200
rigRecord rig-stranger-$$ rig-other-$$ keeper-myx none spawned CSTRANGER01:1700000000.000300
rigLive rig-child-$$
rigLive rig-stranger-$$
sleep 2
rigOut="$( rigClose "$rigSpawned/rig-parent-$$/rig-parent-$$.spawn.md" )"
rigAssert "the parent's record closes"                 "$( rigStatus "$rigSpawned/rig-parent-$$/rig-parent-$$.spawn.md" )" "spawn-succeeded"
rigAssert "its child is dismissed by the tooling"      "$( rigMark rig-child-$$ ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'CHILDREN-CLOSE: rig-child-.* dismissed' )" "tooling (the close of rig-parent-$$):1"
rigAssert "the session chat file records it"           "$( rigCountIn "$rigWs/.local/agents/sessions/rig-parent-$$/session.chat" 'DISMISSED' )" 1
rigAssert "one line to @here says what was ended"      "$( rigCountIn "$rigTmp/curl.log" 'chat.postMessage' )" 1
rigAssert "a run it never spawned is untouched"        "$( rigMark rig-stranger-$$ ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'rig-stranger-' )" "none:0"
rigAssert "the child's own record is left to its run"  "$( rigStatus "$rigSpawned/rig-child-$$/rig-child-$$.spawn.md" )" "spawn-started"

echo "-- 2. a control: a parent with no child waiting posts nothing --"
rigRecord rig-lone-$$ rig-lone-$$ magic-coordinator none spawned CLONE01:1700000000.000400
: > "$rigTmp/curl.log" ; : > "$rigTmp/bodies"
rigOut2="$( rigClose "$rigSpawned/rig-lone-$$/rig-lone-$$.spawn.md" )"
rigAssert "the lone parent closes"                     "$( rigStatus "$rigSpawned/rig-lone-$$/rig-lone-$$.spawn.md" )" "spawn-succeeded"
rigAssert "and nothing was sent"                       "$( rigCountIn "$rigTmp/curl.log" 'chat.postMessage' )" 0
rigAssert "it says so in its own line"                 "$( printf '%s' "$rigOut2" | LC_ALL=C grep -c 'CHILDREN-CLOSE: no run was spawned by this one' )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLOSE CHILDREN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLOSE_CHILDREN: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
