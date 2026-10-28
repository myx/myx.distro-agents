#!/usr/bin/env bash
## Behavioural check on the `operations:` requirement (F6.1 of the refactorings epic): a flat, optional frontmatter key
## naming the operation prefixes a routine's steps need, decided against what the acting member holds. Its four verbs:
##   validate: each prefix exists, and the declared executors can hold it;
##   automate: nothing (a permission is only ever passed by a holder);
##   help: a prefix an executor cannot hold: the finding names the operation, the member and the routine, and the
##         permission ask that is the route;
##   reject: a prefix no member session may hold, `--manager-*` (the console's own family), said plainly as a wall.
## THE ROW REPORTS AND NEVER ENFORCES: the validator prints a finding as a row of the rule `report-operations` and
## still passes the routine, a start prints it and still starts the routine, and nothing overrides it.
## Held:
##   1. a routine whose executors hold every prefix passes, with no finding
##   2. a --magic-* prefix with an executor that is not magic-coordinator, unannotated: a finding naming the operation,
##      the member, the routine and the permission ask; the routine still passes (exit 0)
##   3. the same prefix annotated in the routine's own tooling list as the coordinator's only: no finding
##   4. a --manager-* prefix: a finding that says no member session may hold it and that it runs from the console
##   5. a prefix no operation answers to, and a word that is no operation prefix: a finding each
##   6. a start of a routine with findings still starts, and says them
##   7. the key left out means any: no finding
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTesting="$rigPackage/sh-scripts/DistroAgentsTesting.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineOperationsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board" "$rigTmp/routines"
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
## A routine: folder, short name, executors, the operations: value or nothing, a tooling line or nothing.
rigRoutine(){
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\nruns-at: none\n' "$3"
		[ -z "$4" ] || printf 'operations: %s\n' "$4"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$2"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\n## DistroAgentsTools magic-tooling operations\n\n"
		[ -z "$5" ] || printf '%s\n' "$5"
		printf "\n# Maintainer Notes\n\nNone.\n"
	} > "$1/magic-team.$2.routine.md"
}
rigOp='--move-to-pending'
rigAnnotated='- `--move-to-pending <team-member> <item-filename> --from-state:<state>` — `magic-coordinator` only'
rigRoutine "$rigTmp/routines" holds magic-coordinator "$rigOp" ""
rigRoutine "$rigTmp/routines" mismatch keeper-rig "$rigOp" ""
rigRoutine "$rigTmp/routines" annotated keeper-rig "$rigOp" "$rigAnnotated"
rigRoutine "$rigTmp/routines" manager keeper-rig "--manager-session-list" ""
rigRoutine "$rigTmp/routines" nosuch magic-coordinator "--no-such-operation-at-all-" ""
rigRoutine "$rigTmp/routines" noword magic-coordinator "board-to-pending" ""
rigRoutine "$rigTmp/routines" leftout keeper-rig "" ""

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigValidate(){ ## short name -- the validator's exit, then its rows of the rule report-operations
	local validateRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTesting" --skillset-validate-routine "$rigTmp/routines/magic-team.$1.routine.md" ) > "$rigTmp/validate" 2> "$rigTmp/validate.err" < /dev/null || validateRc=$?
	rigRc="$validateRc"
	rigRows="$( LC_ALL=C grep -c -F ': report-operations: ' "$rigTmp/validate" || : )"
}
rigSays(){ ## fixed string -- yes where a report-operations row holds it
	if LC_ALL=C grep -F ': report-operations: ' "$rigTmp/validate" | LC_ALL=C grep -q -F -- "$1" ; then printf yes ; else printf no ; fi
}

echo "-- 1. executors that hold the prefix: no finding --"
rigValidate holds
rigAssert "passes, no row" "$rigRc:$rigRows" "0:0"

echo "-- 2. a --magic-* prefix an executor cannot hold, unannotated: reported, never enforced --"
rigValidate mismatch
rigAssert "the routine still passes, with one row" "$rigRc:$rigRows" "0:1"
rigAssert "the row names the operation, the member, the routine and the permission ask" "$( rigSays "$rigOp" ):$( rigSays keeper-rig ):$( rigSays magic-team.mismatch.routine.md ):$( rigSays RequestPermission )" "yes:yes:yes:yes"

echo "-- 3. annotated in the routine's own tooling list: no finding --"
rigValidate annotated
rigAssert "passes, no row" "$rigRc:$rigRows" "0:0"

echo "-- 4. a --manager-* prefix: no member session may hold it --"
rigValidate manager
rigAssert "one row, still exit 0" "$rigRc:$rigRows" "0:1"
rigAssert "it says no member session may hold it, and that it runs from the console" "$( rigSays 'no member session may hold' ):$( rigSays console )" "yes:yes"

echo "-- 5. a prefix no operation answers to, and a word that is none --"
rigValidate nosuch
rigAssert "one row, naming that no operation answers" "$rigRc:$rigRows:$( rigSays 'no operation of the tooling answers' )" "0:1:yes"
rigValidate noword
rigAssert "one row, naming that it is no operation prefix" "$rigRc:$rigRows:$( rigSays 'no operation prefix' )" "0:1:yes"

echo "-- 7. left out: any --"
rigValidate leftout
rigAssert "passes, no row" "$rigRc:$rigRows" "0:0"

echo "-- 6. a start of a routine with findings still starts, and says them --"
for rigName in mismatch manager ; do cp "$rigTmp/routines/magic-team.$rigName.routine.md" "$rigSkills/magic-team/" ; done
rigSpawn(){ ## routine short name
	rm -f "$rigTmp"/brief.*
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-operations keeper-rig --routine "$1" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
}
rigSpawn mismatch
rigAssert "the start runs: exit 0, the run briefed" "$rigRc:$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )" "0:briefed"
rigAssert "and says the finding, naming the operation and the member" "$( LC_ALL=C grep -c -F 'REPORT' "$rigTmp/spawn.out" ):$( LC_ALL=C grep -F 'REPORT' "$rigTmp/spawn.out" | LC_ALL=C grep -c -F -e "$rigOp" )" "1:1"
rigSpawn manager
rigAssert "a --manager-* finding stops nothing either: exit 0, the run briefed" "$rigRc:$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )" "0:briefed"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE OPERATIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_OPERATIONS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
