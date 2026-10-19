#!/usr/bin/env bash
## Behavioural check on a routine's start context (F6.1 of the refactorings epic): a routine declares
## `start-context: inline | spawned | any`. `inline` runs only inside another run, `spawned` only as a run of its own,
## `any` either way, and a joined start counts as `spawned`. Each declared mode keeps its closure line in the Closure
## steps, in the form the routines already use: `Run inline: ...` and `Run as its own session: ...`.
## - validate: the value is one of the three words, and the Closure steps carry a closure line for each mode it allows.
## - reject: at start, a start whose recorded `start-context:` the routine does not allow is refused before any step
##   runs, naming the start to use.
## The key is `start-context:`, a flat, optional frontmatter key, and a key left out means `any` (rigContextLine below
## is the one place the line is written). There is no `requires:` line.
## Held:
##   1. the validator (F7.6's --tester-skillset-validate-routine) takes inline, spawned and any, each with its closure
##      lines; it refuses joined and both, naming start-context
##   2. it refuses a declared mode whose closure line is missing: inline with no `Run inline:`, spawned with no
##      `Run as its own session:`, any with only one of the two, and a closure line that stands outside the Closure steps
##   3. at start, through the spawn proxy: an inline routine started as a run of its own, and a spawned routine started
##      inline, are refused, exit non-zero, before any step runs (the console is never started, no record is written),
##      and the refusal names the start to use
##   4. allowed starts run: a spawned routine started as its own run and joined; an inline routine started inline;
##      an any routine started either way, and so a routine that leaves the key out
## Red before F6.1: no validator and no start gate (1, 2 and 3 fail; 4 holds today, and must stay).
## Offline: a fake curl first on PATH, a stand-in console that records each brief and runs no model.
set -u
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
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsStartContextCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/rig-member-a" "$rigSkills/magic-coordinator" "$rigData/board" "$rigTmp/routines"
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
for rigMember in rig-member-a magic-coordinator ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## THE KEY FORM, written in this one place while it is open.
rigContextLine(){ ## mode, or `left-out` -- the frontmatter line that declares it, with its newline; none where left out
	[ "$1" = left-out ] || printf 'start-context: %s\n' "$1"
}
## A routine of the team: its short name, its mode, the closure text of its Closure steps, and where the closure
## text stands: `closure`, or `steps` to put it in the Steps instead.
rigRoutine(){ ## folder, short name, mode, closure text, closure|steps
	local routineSteps="1. **work**: work." routineClosure="1. **close**: close."
	if [ "$5" = steps ] ; then routineSteps="$routineSteps"$'\n\n'"$4" ; else routineClosure="$routineClosure"$'\n\n'"$4" ; fi
	{
		printf -- '---\ntype: routine\nexecutors: rig-member-a\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n'
		rigContextLine "$3"
		printf -- '---\n'
		printf '# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n%s\n\n# Closure steps\n\n%s\n\n' "$2" "$routineSteps" "$routineClosure"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$1/magic-team.$2.routine.md"
}
rigInline='Run inline: hand back to the run that brought you in.'
rigOwn='Run as its own session: run the close-session group.'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigValidate(){ ## short name -- `0`, or `refused` and whether the answer names start-context or a closure line
	local validateRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --tester-skillset-validate-routine "$rigTmp/routines/magic-team.$1.routine.md" ) > "$rigTmp/validate" 2>&1 < /dev/null || validateRc=$?
	if [ "$validateRc" -eq 0 ] ; then printf 0 ; return ; fi
	if LC_ALL=C grep -q -E 'start-context|Run inline|Run as its own session' "$rigTmp/validate" ; then printf 'refused named' ; else printf 'refused unnamed' ; fi
}

echo "-- 1. the three words, each with its closure lines --"
rigRoutine "$rigTmp/routines" ok-inline inline "$rigInline" closure
rigRoutine "$rigTmp/routines" ok-spawned spawned "$rigOwn" closure
rigRoutine "$rigTmp/routines" ok-any any "$rigInline $rigOwn" closure
rigRoutine "$rigTmp/routines" bad-joined joined "$rigInline $rigOwn" closure
rigRoutine "$rigTmp/routines" bad-both both "$rigInline $rigOwn" closure
rigAssert "inline, spawned and any are taken"                    "$( rigValidate ok-inline ):$( rigValidate ok-spawned ):$( rigValidate ok-any )" "0:0:0"
rigAssert "joined and both are refused, naming start-context"     "$( rigValidate bad-joined ):$( rigValidate bad-both )" "refused named:refused named"

echo "-- 2. a declared mode keeps its closure line in the Closure steps --"
rigRoutine "$rigTmp/routines" miss-inline inline "$rigOwn" closure
rigRoutine "$rigTmp/routines" miss-spawned spawned "$rigInline" closure
rigRoutine "$rigTmp/routines" miss-any any "$rigInline" closure
rigRoutine "$rigTmp/routines" misplaced inline "$rigInline" steps
rigAssert "inline with no Run inline: line is refused"            "$( rigValidate miss-inline )" "refused named"
rigAssert "spawned with no Run as its own session: line is refused" "$( rigValidate miss-spawned )" "refused named"
rigAssert "any with one of the two is refused"                    "$( rigValidate miss-any )" "refused named"
rigAssert "a closure line in the Steps is no closure line"        "$( rigValidate misplaced )" "refused named"

echo "-- 3. at start: a mode the routine does not allow is refused before any step runs --"
rigRoutine "$rigSkills/magic-team" run-inline inline "$rigInline" closure
rigRoutine "$rigSkills/magic-team" run-spawned spawned "$rigOwn" closure
rigRoutine "$rigSkills/magic-team" run-any any "$rigInline $rigOwn" closure
rigRoutine "$rigSkills/magic-team" run-left left-out "$rigInline $rigOwn" closure
## One start of rig-member-a through the spawn proxy, the routine and how it is started; rc in rigRc.
rigSpawn(){ ## routine short name, spawned|inline|joined
	local spawnContext=()
	[ "$2" = spawned ] || spawnContext=( --start-context "$2" )
	rm -f "$rigTmp"/brief.*
	chmod -R u+w -- "$rigWs/.local/agents/spawned" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-context rig-member-a --routine "$1" --session-new --dispatch-doc:none ${spawnContext[@]+"${spawnContext[@]}"} --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn" 2>&1 || rigRc=$?
}
rigRan(){ ## -- `ran` where the console was started or a record written, else `none`
	if ls "$rigTmp"/brief.* > /dev/null 2>&1 || ls "$rigWs"/.local/agents/spawned/*/*.md > /dev/null 2>&1 ; then printf ran ; else printf none ; fi
}
rigNames(){ ## extended pattern -- `named` where the refusal says it
	if LC_ALL=C grep -q -E -- "$1" "$rigTmp/spawn" ; then printf named ; else printf unnamed ; fi
}
rigSpawn run-inline spawned
rigAssert "an inline routine started as its own run: refused, nothing ran, the inline start named" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$( rigRan ):$( rigNames 'inline' )" "refused:none:named"
rigSpawn run-spawned inline
rigAssert "a spawned routine started inline: refused, nothing ran, its own run named" "$( [ "$rigRc" -ne 0 ] && echo refused || echo started ):$( rigRan ):$( rigNames 'spawned|own session|its own run' )" "refused:none:named"

echo "-- 4. allowed starts run --"
rigSpawn run-spawned spawned
rigAssert "a spawned routine as its own run"                      "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-spawned joined
rigAssert "a spawned routine joined: a joined start counts as spawned" "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-inline inline
rigAssert "an inline routine started inline"                      "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-any spawned
rigAssert "an any routine as its own run"                         "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-any inline
rigAssert "an any routine started inline"                         "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-left spawned
rigAssert "a routine that leaves the key out, as its own run"      "$rigRc:$( rigRan )" "0:ran"
rigSpawn run-left inline
rigAssert "and started inline: a key left out means any"          "$rigRc:$( rigRan )" "0:ran"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ START CONTEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'START_CONTEXT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
