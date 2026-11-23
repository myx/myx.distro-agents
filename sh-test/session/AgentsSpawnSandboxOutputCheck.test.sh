#!/usr/bin/env bash
## Behavioural check on what a sandbox's output/ keeps when its last run closes: a marked copy of a
## source tree goes, and the patch and the note of the work stay, because the review of that work is
## still open. The claim is the design's: a source-tree copy is a path under output/ listed in
## output/copies.manifest, and AgentsToolsSpawnSandboxReleaseOutput removes it at the sandbox's last
## close, which AgentsToolsSpawnProxyCloseSandbox makes.
## Red before the build: nothing releases a copy, so the close leaves the copied tree's own paths in
## output/ beside the note and the patch, where the assertion asks for those two alone.
## Offline: a Slack-shaped fake curl logs each post and opens no socket; the workspace, the board, the
## session store and the sandbox are this check's own rig tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/spawn/AgentsTools.SpawnSandbox.include"
rigCurl="$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the spawn sandbox include is not at the origin: $rigInclude"
[ -f "$rigCurl" ] || rigRefuse "the fake curl fixture is missing from the package: $rigCurl"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnSandboxOutputCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigData="$rigWs/.local/agents/team-data-root"
rigSkills="$rigTmp/skills"
rigBin="$rigTmp/bin"
rigSeed="$rigTmp/seed"
mkdir -p "$rigBin" "$rigHome" "$rigSkills/rig-member" "$rigData" \
	"$rigWs/.local/.agents" "$rigWs/.local/agents/members/rig-member" "$rigWs/.local/agents/sessions" || exit 1
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf -- '---\nname: rig-member\n---\nrig member\n' > "$rigWs/.local/agents/members/rig-member/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cp "$rigCurl" "$rigBin/curl" && chmod +x "$rigBin/curl" || rigRefuse "could not install the fake curl"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigTmp/replies.json"
: > "$rigTmp/curl.log"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

## THE BOARD ITEM: the work of this sandbox is in review, which is the state that keeps a patch and a
## note. The store is written by its owner, the item writer of the rig's own team data.
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigBoardStates "$rigData" review || rigRefuse "the rig's board was not made ready"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: %s\n---\n\n# rig work, in review\n' "rig-out-$$" | rigStoreItem "$rigData" board review dispatch-rig-review.md \
	|| rigRefuse "the board item of the review was not written"

## THE SANDBOX: one run, started, whose output/ holds a marked copy of a fake source tree in the
## member's own folder, and beside it the staged patch and the note of the work. The manifest marks
## the copy, and it is the record of it rather than a path of the work, so the assertion leaves it out.
rigSpawn="rig-out-$$"
rigSandbox="$rigWs/.local/agents/spawned/$rigSpawn"
rigOutput="$rigSandbox/output"
rigCopy="$rigOutput/rig-member/rigpkg"
mkdir -p "$rigSandbox/input/$rigSpawn" "$rigCopy/.git" "$rigWs/.local/agents/sessions/$rigSpawn" || exit 1
printf '# rigpkg\n' > "$rigCopy/MAGIC.md"
: > "$rigCopy/file.sh"
: > "$rigCopy/.git/HEAD"
printf 'rig patch\n' > "$rigOutput/keep.patch"
printf '# rig note\n' > "$rigOutput/keep.md"
printf 'rig-member/rigpkg\t%s\t0\t2026-11-23T10:00:00Z\n' "$rigCopy" > "$rigOutput/copies.manifest"
printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: rig-member\nhost: %s\nstatus: spawn-started\nsession-thread: CRIG00001:1700000000.000001\n---\n' \
	"$rigSpawn" "$rigSpawn" "$rigHost" > "$rigSandbox/$rigSpawn.spawn.md"
printf '%s\n' 'CRIG00001:1700000000.000001' > "$rigWs/.local/agents/sessions/$rigSpawn/session.thread"

## THE CLOSE: the sandbox's own last close, made by the proxy's close as a run's end makes it.
rigClose(){
	( cd "$rigWs" || exit 1
	  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-member RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		MDAT_COLLECT_THREAD=off MDAT_COMMS_READER=off MDAT_WAIT_REMIND=off MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash -c '. "$1" ; AgentsToolsSpawnProxyCloseSandbox "$2" succeeded 0 "the rig ended it"' rig \
			"$rigInclude" "$rigSandbox/$rigSpawn.spawn.md" ) > "$rigTmp/close.out" 2> "$rigTmp/close.err"
	printf '%s' "$?" > "$rigTmp/close.rc"
}
rigSurvivors(){ ## -- the paths standing in output/, named relative to it, sorted, on one line; the manifest is the record of them
	( cd "$rigSandbox/output" 2> /dev/null \
		&& find . -mindepth 1 -maxdepth 1 ! -name copies.manifest | LC_ALL=C sed 's|^\./||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )
}

rigClose
rigAssert "the close ran" "$( cat "$rigTmp/close.rc" )" 0
rigAssert "the surviving paths of output/ are the note and the patch" "$( rigSurvivors )" "keep.md keep.patch"
[ ! -s "$rigTmp/close.err" ] || printf '  # the close said: %s\n' "$( LC_ALL=C sed -n 1p "$rigTmp/close.err" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN SANDBOX OUTPUT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SANDBOX_OUTPUT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
