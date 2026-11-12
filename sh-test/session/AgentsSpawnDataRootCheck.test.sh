#!/usr/bin/env bash
## AgentsSpawnDataRootCheck -- NO START OF A RIG REACHES ANOTHER RIG'S OR ANOTHER WORKSPACE'S TEAM DATA (S12.19, board task
## 20261106T1255Z). The start point of every spawn is `--intern-op-agent-spawn-proxy`, and it inherits whatever `MDAT_DATA_ROOT`
## the caller held: an invited member's session of another workspace hands it that workspace's own store. Held, run rather than
## read, one real start per row with the console, the Slack calls and every setting of this rig's own:
##   0. THE KNOWN POSITIVE, so a red below is not the rig: a start holding this workspace's own store succeeds, and its dispatch
##      item is in this store's board.
##   1. ANOTHER WORKSPACE'S DEFAULT STORE IS RE-RESOLVED: the start says so once, in a line naming both stores.
##   2. AND THE START'S WORK LANDS IN THIS WORKSPACE'S STORE: its dispatch item, its transcript and its session data-root record
##      are all under this workspace's own store, never in the other one, which is left exactly as it was found.
##   3. A RIG CONFIGURED WITH ITS OWN TEAM DATA DIRECTORY KEEPS IT: an inherited store of another workspace lands in that
##      directory instead, and this workspace's own default store, which nothing names, stays as it was found.
##   4. ANOTHER RIG'S CONFIGURED DIRECTORY IS NOT REACHED through a mark that does not name this workspace.
## A MEMBER OF ANY RIG works its own rig's items, so the rows are held for the start point itself and not for one member: the
## resolution takes no member as input, and one member's name stands in the rig's roster for that reason.
## Red recipe, measured on copies under this check's own scratch on 2026-11-12, one run each:
##   delete the S12.19 block of AgentsContext.UseAgentsTools.include (`:52-87` at 12:38): 1 of 22 fails, the section-4 row.
##     Sections 1 to 3 still pass, and they pass on the spawn proxy's own block, which is the second line of defence.
##   delete that block and the spawn proxy's own (`AgentsTools.InternOpAgentSpawnProxy.include:1106-1119`): 8 of 22 fail,
##     across sections 1 to 4, and the other workspace's store gains a dispatch item and two audit files.
##   delete the spawn proxy's block alone: no row fails. The context load re-resolves the inherited store first, so the
##     proxy's own sentence is never printed on the tree as it stands. The block is not dead: it is what holds sections 1 to 3
##     on the copy above whose context block is gone. Its sentence being unreachable is a finding of the round this check was
##     written in, reported to magic-coordinator, and not asserted here.
## Green on the tree as it stands: 22 of 22, run folder `mdat-tests/20261112T111343Z`, 245 s, and this file's assertion set is
## the one that run held. The check takes over 300 s on a loaded machine, so the runner's own timeout has to be raised for it: a
## run at the default 300 s ended at its limit with two of the start's processes still up, which is the run's limit and not a
## row of this check.
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The package under test is found from the origin this workspace resolves, and a mutated copy is pointed at by RIG_PACKAGE.
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOrigin="${rigPackage%/*/*}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -d "$rigOrigin/myx/myx.distro-.local" ] || rigRefuse "the tooling's own sibling is not beside the package under test: $rigOrigin/myx"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnDataRootCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
if [ "${MMDAPP#/}" = "${MMDAPP}" ] || [ "${MDAT_DATA_ROOT:-$rigTmp/absent}" = "${MDAT_DATA_ROOT#/}" ] ; then
	rigRefuse "MMDAPP or MDAT_DATA_ROOT is not an absolute path, so the rig guard cannot be written"
fi

rigWs="$rigTmp/ws" rigOther="$rigTmp/other-ws" rigSkills="$rigTmp/skills" rigCfg="$rigTmp/configured-team-data" rigOtherCfg="$rigTmp/other-configured-team-data"
rigOwnStore="$rigWs/.local/agents/team-data-root" rigOtherStore="$rigOther/.local/agents/team-data-root"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/rig-keeper" \
	"$rigOwnStore/board/running" "$rigOtherStore/board/running" || rigRefuse "the rig could not be made"
## A member of a rig, with a routine that locks nothing: this check is about the store, and a lock would hold the second start.
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-keeper/rig-keeper.basic.md" || rigRefuse "the member's identity could not be written"
printf '# rig armed\n' > "$rigSkills/rig-keeper/rig-keeper.armed.md"
printf '# rig-keeper\n' > "$rigSkills/rig-keeper/SKILL.md"
printf '# magic-team\n' > "$rigSkills/magic-team/SKILL.md"
printf -- '---\ntype: routine\nexecutors: rig-keeper\nmaintainers: rig-keeper\nrequires-session-kind: standalone\nruns-at: none\n---\n# rig-keeper.plain.routine -- the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\nNone.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\nNone.\n\n# Routine procedures\n\nNone.\n\n# Routine rules\n\nNone.\n\n# Tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n' > "$rigSkills/rig-keeper/rig-keeper.plain.routine.md"
## THE CONSOLE STAND-IN: it answers the marker the spawn proxy refuses to start without, and ends at once.
printf '#!/usr/bin/env bash\n## --cli-configured stand-in: MDAT_SPAWN_LAUNCH_MARKER\ncat > /dev/null\nprintf "rig-cli\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"\nprintf "handback\\n"\n' > "$rigWs/DistroAgentsConsole.sh" || rigRefuse "the console stand-in could not be written"
chmod +x "$rigWs/DistroAgentsConsole.sh"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\nMDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## THE OTHER WORKSPACE'S STORE holds one item of its own, so a write of this start's into it is visible as a new path and the
## state it was found in is a thing this check can compare against.
printf -- '---\ntype: task\nowner: keeper-other\n---\n\n# the other rig own item\n' > "$rigOtherStore/board/running/task-20261112T0000Z-other-rig-only.md" || rigRefuse "the other store's item could not be written"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigStoreTree(){ ## store path -- every path under it, sorted, so a write of any kind shows
	( cd "$1" 2> /dev/null && find . -type f | LC_ALL=C sort ) 2> /dev/null
}
rigOne(){ ## inherited data root, the name of its results, the workspace the console runs in, the mark beside the root (optional)
	local oneRoot="$1" oneName="$2" oneWs="${3:-$rigWs}" oneMark="${4:-}"
	( cd "$oneWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$oneWs" MDAT_DATA_ROOT="$oneRoot" ${oneMark:+MDAT_DATA_ROOT_OF="$oneMark"} MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-start rig-keeper --routine rig-keeper.plain --session-new --dispatch-doc:create --wait \
		<<< "RIG-TASK-TEXT" ) > "$rigTmp/$oneName.out" 2>&1
	printf '%s' "$?" > "$rigTmp/$oneName.rc"
}
rigSaid(){ ## results name, fixed text -- how many lines of them hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" 2> /dev/null || :
}
rigItemOf(){ ## store path -- the dispatch item this store gained
	( cd "$1" 2> /dev/null && find . -name 'dispatch-*.md' -type f | LC_ALL=C sed -n '1p' ) 2> /dev/null
}
rigSaidBoth(){ ## results name, the inherited store, this workspace's own store -- lines naming both
	LC_ALL=C grep -F "the inherited data root $2 is another workspace's" "$rigTmp/$1.out" 2> /dev/null \
		| LC_ALL=C grep -c -F "uses $3's own" || :
}
rigRootRecord(){ ## -- the data-root this workspace's newest session record names
	LC_ALL=C cat "$rigWs"/.local/agents/sessions/*/data-root 2> /dev/null | LC_ALL=C sed -n '1p'
}

echo "-- 0. the known positive: a start holding this workspace's own store writes into it --"
rigOwnBefore="$( rigStoreTree "$rigOwnStore" )"
rigOne "$rigOwnStore" own
rigAssert "the start succeeds"                          "$( cat "$rigTmp/own.rc" )" 0
rigAssert "and says nothing of another workspace"       "$( rigSaid own 'is another workspace' )" 0
rigAssert "and its dispatch item is in this store"      "$( [ -n "$( rigItemOf "$rigOwnStore" )" ] && echo item || echo none )" item
rigAssert "on a store it found with nothing of its own in it" "$( printf '%s\n' "$rigOwnBefore" | LC_ALL=C grep -c . || : )" 0
rigAssert "and the item is not in the other workspace's store" "$( [ -n "$( rigItemOf "$rigOtherStore" )" ] && echo item || echo none )" none

echo "-- 1 and 2. another workspace's own store: re-resolved, said once, and never written --"
rigOtherBefore="$( rigStoreTree "$rigOtherStore" )"
rigOwnBefore="$( rigStoreTree "$rigOwnStore" )"
rigOne "$rigOtherStore" inherited
rigAssert "the start succeeds"                          "$( cat "$rigTmp/inherited.rc" )" 0
rigAssert "and says the inherited store is another workspace's, once" "$( rigSaid inherited 'is another workspace' )" 1
rigAssert "names both stores in one line, in the words of whichever layer resolved it" "$( rigSaidBoth inherited "$rigOtherStore" "$rigWs" )" 1
rigAssert "its dispatch item is in this workspace's own store" "$( [ -n "$( rigItemOf "$rigOwnStore" )" ] && echo item || echo none )" item
rigAssert "and the session record names this workspace's own store" "$( rigRootRecord )" "$rigOwnStore"
rigAssert "the other workspace's store is left exactly as it was found" "$( rigStoreTree "$rigOtherStore" | LC_ALL=C diff -q <( printf '%s\n' "$rigOtherBefore" ) - > /dev/null && echo same || echo changed )" same
rigAssert "and holds no dispatch item"                  "$( find "$rigOtherStore" -name 'dispatch-*.md' -type f 2> /dev/null | LC_ALL=C grep -c . || : )" 0
rigAssert "and the other workspace's store holds no audit of this start" "$( printf '%s\n' "$( rigStoreTree "$rigOtherStore" )" | LC_ALL=C grep -c -F 'audit/' || : )" 0

echo "-- 3. a rig configured with its own team data directory keeps it --"
mkdir -p "$rigCfg/board/running" "$rigWs/.local/.agents" || rigRefuse "the configured directory could not be made"
printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigCfg" > "$rigWs/.local/.agents/magic-coordinator.agent.env"
rigCfgBefore="$( rigStoreTree "$rigCfg" )"
rigOwnBefore="$( rigStoreTree "$rigOwnStore" )"
rigOne "$rigOtherStore" configured
rigAssert "the start succeeds"                          "$( cat "$rigTmp/configured.rc" )" 0
rigAssert "the inherited store is named as another workspace's, and not as a configured directory" "$( rigSaid configured 'is another workspace' ):$( rigSaid configured 'is not the team data' )" "1:0"
rigAssert "its dispatch item is in the configured directory" "$( [ -n "$( rigItemOf "$rigCfg" )" ] && echo item || echo none )" item
rigAssert "the configured directory was empty of items before this start" "$( printf '%s\n' "$rigCfgBefore" | LC_ALL=C grep -c . || : )" 0
rigAssert "this workspace's own default store is untouched, because nothing names it" "$( rigStoreTree "$rigOwnStore" | LC_ALL=C diff -q <( printf '%s\n' "$rigOwnBefore" ) - > /dev/null && echo same || echo changed )" same
rigAssert "and the other workspace's store is untouched" "$( rigStoreTree "$rigOtherStore" | LC_ALL=C diff -q <( printf '%s\n' "$rigOtherBefore" ) - > /dev/null && echo same || echo changed )" same

echo "-- 4. another rig's configured directory, reached with a mark that does not name this workspace --"
## THE PAIR FED HERE: a start made from this rig (configured with the directory section 3 set), holding another rig's
## configured team data directory, and a mark (MDAT_DATA_ROOT_OF) that names neither this rig nor the store it came with. The
## context load's configured-directory arm runs on that mark and re-resolves for this rig, so the other rig's directory is
## never reached.
## MEASURED AND NOT A ROW: the same start with the mark naming this rig itself keeps the other rig's configured directory, and
## its dispatch item lands there. No caller of the tooling produces that pair: every layer that sets the mark sets it beside a
## root it resolved for that same workspace (AgentsContext.UseAgentsTools.include:41, :59, :83;
## AgentsTools.InternOpAgentSpawnProxy.include:1115; AgentsTools.InternSchedule.include:70). A row built on a pair nothing
## produces is a false alarm, so it is not written.
mkdir -p "$rigOtherCfg/board/running" "$rigOther/.local/.agents" || rigRefuse "the other rig's configured directory could not be made"
printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigOtherCfg" > "$rigOther/.local/.agents/magic-coordinator.agent.env"
rigOtherCfgBefore="$( rigStoreTree "$rigOtherCfg" )"
rigOne "$rigOtherCfg" mismarked "$rigWs" "$rigOwnStore"
rigAssert "the start succeeds"                          "$( cat "$rigTmp/mismarked.rc" )" 0
rigAssert "nothing of it reaches the other rig's configured directory" "$( printf '%s\n' "$( rigStoreTree "$rigOtherCfg" )" | LC_ALL=C diff -q <( printf '%s\n' "$rigOtherCfgBefore" ) - > /dev/null && echo same || echo changed )" same
rigAssert "and its dispatch item is in this rig's configured directory" "$( [ -n "$( rigItemOf "$rigCfg" )" ] && echo item || echo none )" item

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN DATA ROOT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a start made under another workspace's data root writes that workspace's team data" >&2
	echo "  fix:  the data-root resolution in sh-lib/harness/AgentsContext.UseAgentsTools.include, for the pair row 4 feeds" >&2
	exit 1
fi
printf 'SPAWN_DATA_ROOT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
