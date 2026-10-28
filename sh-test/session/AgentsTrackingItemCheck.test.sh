#!/usr/bin/env bash
## Behavioural check on the `tracking-item:` requirement (F6.1 of the refactorings epic): a flat, optional frontmatter
## key, `required | optional | forbidden`, a key left out meaning `any`. The tracking item is the board item the run's
## dispatch record links (its spawn record's `spawns:`), the one `--dispatch-doc:create` makes, which the review flow
## moves. Its four verbs:
##   validate: the value is one of the three words, and `forbidden` carries no item;
##   automate: at spawn, create the item and record its name on the dispatch;
##   reject: `forbidden` with an item attached, refused before any step runs.
## Run through the spawn proxy, the start every routine goes through, and the validator (F7.6's stub).
## Held:
##   0. control: a start with --dispatch-doc:create makes the item, and the spawn record's spawns: names it
##   1. the validator takes required, optional and forbidden, and refuses another word, naming tracking-item
##   2. required, started with no item (--dispatch-doc:none): the spawner makes the item, and the record names it
##   3. forbidden, started with an item (--dispatch-doc:create): refused, exit non-zero, before any step (no brief is
##      handed, no item is made), naming tracking-item
##   4. forbidden with no item, and optional with none, start without one
## The help verb, at routine start, asks the session's coordinator: not run here, as nothing starts a routine without
## its spawn in this rig.
## Red before F6.1: no tracking-item: is read (1, 2 and 3 fail; 0 and 4 hold today, and must stay).
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsTrackingItemCheck.XXXXXX" )" || exit 1
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
rigRoutine(){ ## folder, short name, the tracking-item: value or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\nruns-at: none\n'
		[ -z "$3" ] || printf 'tracking-item: %s\n' "$3"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$2"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$1/magic-team.$2.routine.md"
}
rigRoutine "$rigSkills/magic-team" rigtrackplain ""
rigRoutine "$rigSkills/magic-team" rigtrackrequired required
rigRoutine "$rigSkills/magic-team" rigtrackforbidden forbidden
rigRoutine "$rigSkills/magic-team" rigtrackoptional optional

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of keeper-rig's routine through the spawn proxy; rc in rigRc, the items made in rigItems, the item its
## spawn record's spawns: names in rigLinked, and whether a brief was handed in rigBriefed.
rigSpawn(){ ## routine short name, create|none
	rm -f "$rigTmp"/brief.*
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-tracking keeper-rig --routine "$1" --session-new "--dispatch-doc:$2" --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
	rigItems="$( find "$rigData/board" -type f -name '*.md' 2> /dev/null | LC_ALL=C grep -c . )"
	rigLinked="$( LC_ALL=C sed -n 's/^spawns: //p' "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | head -1 )"
	rigBriefed="$( [ -e "$rigTmp/brief.keeper-rig" ] && echo briefed || echo none )"
}
rigLinkedIsItem(){ ## -- `linked` where the record's spawns: names an item of the board
	if [ -n "$rigLinked" ] && find "$rigData/board" -type f -name "$rigLinked.md" 2> /dev/null | LC_ALL=C grep -q . ; then printf linked ; else printf "unlinked:${rigLinked:-none}" ; fi
}

echo "-- 0. control: --dispatch-doc:create makes the item, and the record links it --"
rigSpawn rigtrackplain create
rigAssert "one item made, linked by spawns:, and the run briefed" "$rigItems:$( rigLinkedIsItem ):$rigBriefed" "1:linked:briefed"

echo "-- 1. the validator takes the three words, and refuses another --"
for rigValue in required optional forbidden sometimes ; do rigRoutine "$rigTmp/routines" "rigvalue-$rigValue" "$rigValue" ; done
rigValidate(){ ## short name -- `0`, or `refused` and whether tracking-item is named
	local validateRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTesting" --skillset-validate-routine "$rigTmp/routines/magic-team.$1.routine.md" ) > "$rigTmp/validate" 2>&1 < /dev/null || validateRc=$?
	if [ "$validateRc" -eq 0 ] ; then printf 0 ; return ; fi
	if LC_ALL=C grep -q -F 'tracking-item' "$rigTmp/validate" ; then printf 'refused named' ; else printf 'refused unnamed' ; fi
}
rigAssert "required, optional and forbidden are taken"          "$( rigValidate rigvalue-required ):$( rigValidate rigvalue-optional ):$( rigValidate rigvalue-forbidden )" "0:0:0"
rigAssert "another word is refused, naming tracking-item"       "$( rigValidate rigvalue-sometimes )" "refused named"

echo "-- 2. required with no item: the spawner makes it, and the record names it --"
rigSpawn rigtrackrequired none
rigAssert "an item made, linked by spawns:, and the run briefed" "$rigRc:$rigItems:$( rigLinkedIsItem ):$rigBriefed" "0:1:linked:briefed"

echo "-- 3. forbidden with an item: refused before any step, naming tracking-item --"
rigSpawn rigtrackforbidden create
rigAssert "exit non-zero, no brief, no item, tracking-item named" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$rigBriefed:$rigItems:$( LC_ALL=C grep -c -F 'tracking-item' "$rigTmp/spawn.out" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "refused:none:0:named"

echo "-- 4. forbidden with no item, and optional with none, start without one --"
rigSpawn rigtrackforbidden none
rigAssert "forbidden, no item: started, and no item made"        "$rigRc:$rigBriefed:$rigItems" "0:briefed:0"
rigSpawn rigtrackoptional none
rigAssert "optional, no item: started, and no item made"         "$rigRc:$rigBriefed:$rigItems" "0:briefed:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TRACKING ITEM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TRACKING_ITEM: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
