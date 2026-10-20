#!/usr/bin/env bash
## Behavioural check on per-routine review control (F6.5 of the refactorings epic, open-names 38): a routine declares
## its review with the one key F6.8 already gives team-data documents, `review-by:`. `review-by: none` disables review:
## the dispatch item of its run closes straight to processed, with `review: none` in its Decisions. A routine that sets
## no `review-by:` keeps today's review: its item goes to review. Today AgentsToolsSpawnProxyCloseDispatch decides it,
## with no routine consulted.
## Run through the spawn proxy with a dispatch item made for the run, and a stand-in console that hands back at once.
## Held:
##   1. a routine with review-by: none: its item is in board/processed, not in board/review, and its Decisions say
##      `review: none`
##   2. control: a routine with no review-by: its item is in board/review
## Red before F6.5: no routine is consulted (1 fails; 2 holds today, and must stay).
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineReviewByCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name, the review-by: line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rignoreview 'review-by: none'
rigRoutine rigreviewed ''

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of keeper-rig's routine through the spawn proxy, a dispatch item made for it; where its item ended, as
## `<state>:<file>`, in rigItemAt.
rigSpawn(){ ## routine short name
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-review-by keeper-rig --routine "$1" --session-new --dispatch-doc:create --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.$1.out" 2>&1
	rigItem="$( find "$rigData/board" -type f -name 'dispatch-*.md' 2> /dev/null | head -1 )"
	rigItemAt="none"
	[ -z "$rigItem" ] || { rigItemAt="${rigItem%/*}" ; rigItemAt="${rigItemAt##*/}" ; }
}

echo "-- control: a start with a dispatch item makes the item --"
rigSpawn rigreviewed
rigAssert "the start made its dispatch item, and handed back"    "$( [ "$rigItemAt" != none ] && echo item || echo none )" "item"
echo "-- 2. control: a routine with no review-by: its item goes to review --"
rigAssert "the item is in board/review"                          "$rigItemAt" "review"
echo "-- 1. review-by: none: the item closes straight to processed, review: none in its Decisions --"
rigSpawn rignoreview
rigAssert "the item is in board/processed"                       "$rigItemAt" "processed"
rigAssert "its Decisions say review: none"                       "$( LC_ALL=C grep -c -F 'review: none' "$rigItem" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' )" "said"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE REVIEW BY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_REVIEW_BY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
