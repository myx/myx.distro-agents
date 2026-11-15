#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the paths a spawn brief names: every sandbox path a brief names must hold a readable file.
## A brief is the only place a run is told which file is its input, so a brief naming a path nothing writes sends
## the run looking where nothing is. (sh-lib/templates/spawn-brief.document.format.md, AgentsToolsSpawnSandboxFillInput)
## The population is every path a brief places in the run's sandbox: one written with a slash under `input/`, or a bare
## `*.md` name on a line saying where it sits ("your own input folder", "your sandbox"). A skillset file is read
## through the reader and a board item is no file at a path, so neither is in the population -- said here, since a
## count without its population is a shape and not a result.
## One probe serves every brief below, so the controls and the measurement share one instrument.
##   1. THE POSITIVE CONTROL: a brief naming a file the writer fills reports it found, and nothing missing.
##   2. NEGATIVE CONTROL, A PATH NOTHING WRITES: a brief naming one reports it missing.
##   3. NEGATIVE CONTROL, THE OLD WORDING: the scan line as it stood before the fix, `input/input-scan.md of your
##      sandbox`, reports missing against the very run whose folder holds the scan.
##   4. THE MEASUREMENT: a real spawn end to end -- the brief it produced names no missing path.
## Offline: no network, no model; a stand-in console records the brief and the live input folder, and the rig is
## this check's own tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnBriefPathsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## THE PROBE. The population is each path a brief places in the run's sandbox: a name the brief puts in `your own
## input folder` or `of your sandbox`, and a path written under `input/`. A name the brief only reads through the
## skillset reader is no sandbox path and is not in the population.
rigProbe(){ ## brief, the run's own input folder, the sandbox root -- `ok|missing<TAB>token<TAB>resolved`, one per path
	LC_ALL=C awk -v own="$2" -v box="$3" '
	function emit(where, token, path) {
		if (token in seen) { return }
		seen[token] = 1
		printf "%s\t%s\t%s\n", where, token, path
	}
	{
		last = ""
		n = split($0, word, /[^A-Za-z0-9_.\/-]+/)
		for (i = 1; i <= n; i++) {
			named = word[i]
			## The full stop that ends a sentence is no part of the name it ends.
			sub(/^[.,]+/, "", named) ; sub(/[.,]+$/, "", named)
			if (named ~ /^input\/[A-Za-z0-9_.\/-]+\.md$/) { emit("box", named, box "/" named) }
			if (named ~ /^[A-Za-z0-9_.-]+\.md$/) { last = named ; continue }
			## The name stands right before the words that place it, and nowhere else on the line.
			if (named == "your" && last != "") {
				if (word[i + 1] == "own" && word[i + 2] == "input" && word[i + 3] == "folder") { emit("own", last, own "/" last) ; last = "" ; continue }
				if (word[i + 1] == "sandbox") { emit("box", last, box "/" last) ; last = "" ; continue }
			}
		}
	}' "$1" | LC_ALL=C sort -u | while IFS=$'\t' read -r rigWhere rigToken rigPath ; do
		if [ -f "$rigPath" ] && [ -r "$rigPath" ] ; then
			printf 'ok\t%s\t%s\n' "$rigToken" "$rigPath"
		else
			printf 'missing\t%s\t%s\n' "$rigToken" "$rigPath"
		fi
	done
}
rigProbeList(){ ## brief, own input folder, sandbox root -- the probe's own lines, shown
	rigProbe "$1" "$2" "$3" | while IFS=$'\t' read -r rigState rigToken rigPath ; do
		printf '  %-7s %s -> %s\n' "$rigState" "$rigToken" "$rigPath"
	done
}
rigProbeMissing(){ ## brief, own input folder, sandbox root -- how many paths were found missing
	rigProbe "$1" "$2" "$3" | LC_ALL=C grep -c '^missing' || :
}
rigProbeChecked(){ ## brief, own input folder, sandbox root -- how many paths the brief names at all
	rigProbe "$1" "$2" "$3" | LC_ALL=C grep -c . || :
}

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: records the brief, and the run'"'"'s own input folder as the run finds it.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'## input/ is emptied when the run closes: what the run could see is copied while the run is live.' \
	'cp -RLp "$MDAT_SPAWN_SANDBOX_ROOT/input/$MDAT_SPAWN_SESSION_ID" "$RIG_SCENARIO/input.live" 2> /dev/null || :' \
	'printf "%s\n" "$MDAT_SPAWN_SANDBOX_ROOT" > "$RIG_SCENARIO/sandbox.root"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
mkdir -p "$rigSkills/keeper-rig"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md"
printf '# rig armed\n' > "$rigSkills/keeper-rig/keeper-rig.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
{
	printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
	printf 'input-scan-def: permission-escalation\n'
	printf -- '---\n# magic-team.rigscanned.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n'
	printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
} > "$rigSkills/magic-team/magic-team.rigscanned.routine.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of keeper-rig's routine through the spawn proxy, waiting for its run.
rigSpawn(){ ## -- the brief at $rigTmp/brief.keeper-rig, the run's live input folder at $rigTmp/input.live
	rm -rf "$rigTmp/brief.keeper-rig" "$rigTmp/input.live" "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sandboxes" "$rigWs/.local/agents/member-pointers"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-brief-paths keeper-rig --routine rigscanned --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1
	[ -f "$rigTmp/brief.keeper-rig" ] || rigRefuse "the stand-in console recorded no brief: $( tail -3 "$rigTmp/spawn.out" )"
	[ -d "$rigTmp/input.live" ] || rigRefuse "the stand-in console copied no live input folder: $( tail -3 "$rigTmp/spawn.out" )"
}

echo "-- 1. the positive control: a brief naming a file the writer fills --"
mkdir -p "$rigTmp/plant/own" "$rigTmp/plant/box"
printf 'planted\n' > "$rigTmp/plant/own/planted-note.md"
printf '[scan] the note: planted-note.md in your own input folder holds the rig note.\n' > "$rigTmp/plant/brief.positive"
rigProbeList "$rigTmp/plant/brief.positive" "$rigTmp/plant/own" "$rigTmp/plant/box"
rigAssert "it reports nothing missing" "$( rigProbeMissing "$rigTmp/plant/brief.positive" "$rigTmp/plant/own" "$rigTmp/plant/box" )" "0"
rigAssert "and it measured one path, so a clean answer is a measurement" "$( rigProbeChecked "$rigTmp/plant/brief.positive" "$rigTmp/plant/own" "$rigTmp/plant/box" )" "1"

echo "-- 2. negative control: a brief naming a path nothing writes --"
printf '[scan] the note: planted-note.md in your own input folder holds the rig note, beside input/never-written.md.\n' > "$rigTmp/plant/brief.negative"
rigProbeList "$rigTmp/plant/brief.negative" "$rigTmp/plant/own" "$rigTmp/plant/box"
rigAssert "the path nothing writes is missing" "$( rigProbeMissing "$rigTmp/plant/brief.negative" "$rigTmp/plant/own" "$rigTmp/plant/box" )" "1"
rigAssert "and it is that one path, named, while the planted file is reported found" "$( rigProbe "$rigTmp/plant/brief.negative" "$rigTmp/plant/own" "$rigTmp/plant/box" | LC_ALL=C awk -F '\t' '{ printf "%s:%s ", $1, $2 ; }' )" "missing:input/never-written.md ok:planted-note.md "

echo "-- 3. the measurement: a real spawn, and every path its brief names --"
rigSpawn
rigBoxRoot="$( LC_ALL=C sed -n 1p "$rigTmp/sandbox.root" 2> /dev/null )"
[ -n "$rigBoxRoot" ] && [ -d "$rigBoxRoot" ] || rigRefuse "the stand-in console recorded no sandbox root: $( tail -3 "$rigTmp/spawn.out" )"
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigProbeList "$rigTmp/brief.keeper-rig" "$rigTmp/input.live" "$rigBoxRoot"
rigAssert "the brief names at least one sandbox path" "$( [ "$( rigProbeChecked "$rigTmp/brief.keeper-rig" "$rigTmp/input.live" "$rigBoxRoot" )" -ge 1 ] && echo some || echo none )" "some"
rigAssert "and every one of them holds a readable file" "$( rigProbeMissing "$rigTmp/brief.keeper-rig" "$rigTmp/input.live" "$rigBoxRoot" )" "0"

echo "-- 4. negative control on the real brief: the scan line as it stood before the fix --"
cp "$rigTmp/brief.keeper-rig" "$rigTmp/brief.old"
LC_ALL=C sed -i.bak -e 's#^\(input-scan: \)input-scan\.md in your own input folder#\1input/input-scan.md of your sandbox#' "$rigTmp/brief.old"
rm -f "$rigTmp/brief.old.bak"
rigAssert "the control brief carries the older wording" "$( LC_ALL=C grep -c -F 'input/input-scan.md of your sandbox' "$rigTmp/brief.old" )" "1"
rigAssert "and none of the corrected wording" "$( LC_ALL=C grep -c -F 'input-scan.md in your own input folder' "$rigTmp/brief.old" )" "0"
rigAssert "the same run's folder does hold its scan, so only the named path is wrong" "$( [ -f "$rigTmp/input.live/input-scan.md" ] && [ -r "$rigTmp/input.live/input-scan.md" ] && echo held || echo none )" "held"
rigProbeList "$rigTmp/brief.old" "$rigTmp/input.live" "$rigBoxRoot"
rigAssert "RED: the path the older wording names is missing" "$( rigProbeMissing "$rigTmp/brief.old" "$rigTmp/input.live" "$rigBoxRoot" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN BRIEF PATHS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_BRIEF_PATHS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
