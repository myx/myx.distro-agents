#!/usr/bin/env bash
## Behavioural check on the seed of the executor's CheckList (S22 item 4 of the refactorings epic): a spawn opens its executor's list with its
## formal tasks, its routine's duties and its caller's items, as pending items, before the member's first turn. Held, against the real
## spawn proxy with a console stand-in that only records the dispatch it is started with:
##   1. the steps of the brief's `## Formal task` section become pending items, in order, under the executor's own name
##   2. a brief with no such section leaves no list at all, and the session starts as it did
##   3. the section is the steps and nothing else: its prose, the headings and the text of other sections are no item, and a heading ends it
##   4. a step the section states twice stands once
##   5. only the executor's list is written, and nothing is written closed
##   6. the writer, called again on a list it holds: nothing is added twice, and a line already there is never closed, reworded or moved
##   7. a routine's duties, its steps in reading order, follow the brief's steps, and `--checklist-item` arguments follow the duties; a text stated by
##      two sources stands once; a routine and no brief still seeds, and a routine's step names alone are the items
##   8. a work-duty's routine seeds nothing: it is a loop that no list can finish
##   9. a tracking document the spawn is made from gives its `## Formal task` steps as the brief does
##  10. a dispatch naming an epic file and one feature gives that feature's open work, its numbered items, in order; the
##      feature's nested lines that are no item are none, and other features' items are none; a dispatch naming an epic and
##      no feature, or a feature that stands not once, seeds only what its other sources give
## Red on the first seed, which read the brief alone: 7 fails (1 to 6, 8 and 9 hold, and 8 is what must stay).
## Red on the epic source, before it was built: 10 fails (1 to 9 hold, and 9 is what must stay).
## Offline: a fake console that records what it receives, a fake curl that answers Slack; every run an `env -i` child.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsHarnessSpawnSeedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/home/.agents/magic-team" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/inboxes/keeper-myx"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name -- a routine with one step in its Opening steps, two in its Steps and one in its Closure steps
	{
		printf -- '---\ntype: routine\nexecutors: keeper-myx\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-open**: open.\n\n# Steps\n\n1. **rig-work**: work.\n2. **rig-check**: check.\n\n# Closure steps\n\n1. **rig-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigsteps
rigRoutine work-duty
printf -- '---\ntype: task\nfrom: keeper-myx\nowner: keeper-myx\n---\n\n# A tracked task\n\n## Formal task\n\n- RIG-TRACKED-ONE\n- RIG-TRACKED-TWO\n\n## Decisions\n\n- RIG-NOT-A-STEP\n' > "$rigData/board/running/task-rig-seed.md"
## An epic for the feature-open-work source, at a path under a `todo-sketchpad` folder, named by the brief as a builder's is.
rigEpicRoot="$rigWs/source/myx/todo-sketchpad/backlog"
mkdir -p "$rigEpicRoot"
printf '%s\n' \
	'# 20260101 rig epic' \
	'' \
	'## Decisions' \
	'' \
	'- RIG-DECISION-IS-NO-ITEM' \
	'' \
	'## S22 - The CheckList' \
	'' \
	'4. RIG-FEATURE-ITEM-ONE' \
	'- RIG-NESTED-IS-NO-ITEM' \
	'Open: item 4, owner rig.' \
	'' \
	'## S24 - Process flow' \
	'' \
	'19. RIG-FEATURE-OTHER' \
	'- RIG-OTHER-NESTED' \
	'' \
	'## Done' \
	'' \
	'- S22.3: RIG-DONE-IS-NO-ITEM' \
	> "$rigEpicRoot/20260101-rig.epic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## the brief, then the further arguments of the proxy
	local rigBrief="$1"
	shift
	: > "$rigTmp/brief"
	rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --wait --context rig-spawn-seed "$@"
		' rig-spawn "$@" <<< "$rigBrief" 2>&1
}
rigSpawnTracked(){ ## the name of a board item in the rig's running state
	: > "$rigTmp/brief"
	rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy keeper-myx --from-board "$1" --dispatch-doc:none --wait --context rig-spawn-seed
		' rig-spawn "$1" < /dev/null 2>&1
}
rigLists(){ ## the checklist files the spawn made, the member of each, space-joined
	find "$rigWs/.local/agents" -name '*.checklist.md' 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | tr '\n' ' '
}
rigList(){ ## the executor's list as written
	local rigFile
	rigFile="$( find "$rigWs/.local/agents" -name 'keeper-myx.checklist.md' 2> /dev/null | head -1 )"
	[ -f "$rigFile" ] && cat "$rigFile" || printf 'no-list'
}

echo "-- 1. the steps of the Formal task section, in order, under the executor's name --"
rigOut="$( rigSpawn $'RIG-TASK-TEXT\n\n## Formal task\n\n- RIG-STEP-ONE\n- RIG-STEP-TWO\n- RIG-STEP-THREE\n' )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "three pending items, in order, nothing else"            "$( rigList )" $'- [ ] RIG-STEP-ONE\n- [ ] RIG-STEP-TWO\n- [ ] RIG-STEP-THREE'
rigAssert "the brief itself is as it was: the section stays in it" "$( LC_ALL=C grep -c -x -F -- '- RIG-STEP-TWO' "$rigTmp/brief" )" 1

echo "-- 2. no Formal task section: no list --"
rigOut="$( rigSpawn $'RIG-TASK-TEXT\n\n## Notes\n\n- RIG-NOT-A-STEP\n' )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "no list was made"                                       "$( rigLists )" ""

echo "-- 3. the section is the steps, and nothing else --"
rigSpawn $'RIG-TASK-TEXT\n\n## Formal task\n\nSome prose that is no step.\n\n- [ ] RIG-STEP-A\n- RIG-STEP-B   \n### A sub heading ends it\n- RIG-AFTER-HEADING\n\n## Later\n\n- RIG-LATER\n' > /dev/null
rigAssert "prose, a checkbox mark, trailing blanks, and what follows a heading"  "$( rigList )" $'- [ ] RIG-STEP-A\n- [ ] RIG-STEP-B'

echo "-- 4. one step stated twice stands once --"
rigSpawn $'RIG-TASK-TEXT\n\n## Formal task\n\n- RIG-STEP-ONE\n- RIG-SHARED\n- RIG-STEP-TWO\n- RIG-SHARED\n' > /dev/null
rigAssert "the steps in order, the repeated one once"                   "$( rigList )" $'- [ ] RIG-STEP-ONE\n- [ ] RIG-SHARED\n- [ ] RIG-STEP-TWO'

echo "-- 5. only the executor's list; nothing closed --"
rigSpawn $'RIG-TASK-TEXT\n\n## Formal task\n\n- RIG-STEP-ONE\n' > /dev/null
rigAssert "one list, the executor's"                                    "$( rigLists )" "keeper-myx.checklist.md "
rigAssert "no item is written closed or in progress"                    "$( rigList | LC_ALL=C grep -c -v '^- \[ \] ' )" 0

echo "-- 6. the writer on a list it holds --"
rigWriter="$rigTmp/writer.sh"
cat > "$rigWriter" << 'RIG_WRITER'
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CheckListSeed.include"
printf '%s\n' "$RIG_ITEMS" | AgentsToolsCheckListSeed rig-session rig-member
RIG_WRITER
rigSeed(){ ## items, a line each
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_ITEMS="$1" bash "$rigWriter" 2> /dev/null )
}
rigFolder="$rigWs/.local/agents/sessions/rig-session"
mkdir -p "$rigFolder"
printf -- '- [x] RIG-DONE-ITEM\n- [ ] RIG-OPEN-ITEM (in progress: Doing the open item)\n- [ ] RIG-PENDING-ITEM' > "$rigFolder/rig-member.checklist.md"
rigAdded="$( rigSeed $'RIG-DONE-ITEM\nRIG-OPEN-ITEM\nRIG-PENDING-ITEM\nRIG-NEW-ITEM\nRIG-NEW-ITEM' )"
rigAssert "it adds the one new item, once"                              "$rigAdded" 1
rigAssert "the lines it holds stay as they were, a closed one closed, and a list with no last newline gets one before the new line" "$( cat "$rigFolder/rig-member.checklist.md" )" $'- [x] RIG-DONE-ITEM\n- [ ] RIG-OPEN-ITEM (in progress: Doing the open item)\n- [ ] RIG-PENDING-ITEM\n- [ ] RIG-NEW-ITEM'
rigAdded="$( rigSeed $'RIG-DONE-ITEM\nRIG-NEW-ITEM' )"
rigAssert "the same items again add nothing"                            "$rigAdded:$( wc -l < "$rigFolder/rig-member.checklist.md" | tr -d ' ' )" 0:4
rigAssert "and leave no temporary file beside the list"                 "$( ls "$rigFolder" | LC_ALL=C grep -c 'checklist.md\.' )" 0

echo "-- 7. a routine's duties, then the arguments' items --"
rigOut="$( rigSpawn $'RIG-TASK-TEXT\n\n## Formal task\n\n- RIG-STEP-ONE\n- rig-work\n' --routine rigsteps --session-new --checklist-item RIG-ARG-ONE --checklist-item rig-check )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the brief's steps, the routine's in reading order, then the arguments'; a text two sources state stands once"  "$( rigList )" $'- [ ] RIG-STEP-ONE\n- [ ] rig-work\n- [ ] rig-open\n- [ ] rig-check\n- [ ] rig-close\n- [ ] RIG-ARG-ONE'
rigSpawn 'RIG-TASK-TEXT' --routine rigsteps --session-new > /dev/null
rigAssert "a routine and no Formal task: the routine's duties alone, never an empty list"  "$( rigList )" $'- [ ] rig-open\n- [ ] rig-work\n- [ ] rig-check\n- [ ] rig-close'
rigSpawn 'RIG-TASK-TEXT' --checklist-item RIG-ONLY-ARG > /dev/null
rigAssert "an argument alone seeds a list too"                      "$( rigList )" '- [ ] RIG-ONLY-ARG'

echo "-- 8. a work-duty's routine seeds nothing --"
rigOut="$( rigSpawn 'RIG-TASK-TEXT' --routine work-duty --session-new )"
rigAssert "the work-duty started"                                  "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "and no list was made from its routine"                  "$( rigLists )" ""

echo "-- 9. a tracking document the spawn is made from --"
rigOut="$( rigSpawnTracked task-rig-seed.md )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "its formal tasks are the items, and its other sections no item"  "$( rigList )" $'- [ ] RIG-TRACKED-ONE\n- [ ] RIG-TRACKED-TWO'

echo "-- 10. the open work of the epic feature the brief names --"
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s\n\nRead the section of feature S22 with its Settled lines.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "that feature's numbered items, in order, and no nested line, other feature or decision"  "$( rigList )" '- [ ] RIG-FEATURE-ITEM-ONE'
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s\n\nRead the section of feature S24.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "another feature named gives its own item alone"          "$( rigList )" '- [ ] RIG-FEATURE-OTHER'
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s\n\nRead S22 and S24 in full.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "an epic and no feature seeds nothing, and the session starts as it did"  "$( rigLists )" ""
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s\n\nRead the section of feature S99.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "a feature that stands not once seeds nothing"            "$( rigLists )" ""
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s\n\nRead the section of feature S22, and of feature S24.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "two features named seed nothing"                         "$( rigLists )" ""
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\nEpic: %s/nope.epic.md\n\nRead the section of feature S22.\n' "$rigTmp" )" )"
rigAssert "the launch succeeded"                                   "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "an epic file that is no file seeds nothing"              "$( rigLists )" ""
rigOut="$( rigSpawn "$( printf 'RIG-TASK-TEXT\n\n## Formal task\n\n- RIG-STEP-ONE\n\nEpic: %s\n\nRead the section of feature S22.\n' "$rigEpicRoot/20260101-rig.epic.md" )" )"
rigAssert "the brief's own steps come first, the feature's items after them"  "$( rigList )" $'- [ ] RIG-STEP-ONE\n- [ ] RIG-FEATURE-ITEM-ONE'

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS SPAWN SEED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_SPAWN_SEED: OK (%d assertions, offline)\n' "$rigPassCount"
