#!/usr/bin/env bash
## Behavioural check on a routine's own input scan (F6.3 of the refactorings epic, open-names 34, 35 and 36): a routine
## declares its scans in frontmatter, one repeatable line for each, `input-scan-def: <scan> [--option value ...]`, or
## `input-scan-def: none` for no scan; a value that exists only at session time is a macro in the template fill's own form,
## `{{<option-name>}}` over F2.2's five names. The spawner runs the scan itself, with no
## instruction to an agent; its result is saved to `input/input-scan.md` of the session sandbox, beside `dispatch.md`,
## `pointers.md` and `conversation.md`, and it is presented through the brief and the pointers, in the code's fill order.
## Run through the spawn proxy, with a stand-in console that records its brief and runs no model.
## Held:
##   1. a start of a routine that declares a scan saves the scan's result to input/input-scan.md of its sandbox: the
##      report of the scan named, its macros filled (no `{{` stands in it)
##   2. the brief names input/input-scan.md (pointers.md, where a start writes one, is not written by this start)
##   3. control: a routine that declares no scan has no input/input-scan.md
##   4. several lines run in order, each result under `## input scan: <scan>`; the brief names the scans
##   5. a line that names no scan of the tooling stops the start before anything is made; `none` runs no scan
##   6. a scan that fails does not stop the start: the file says it failed, and what it said
##   7. the spawner keeps the scan's pointer in the run's session (F10.5 gate B): `scan:<scan>:<member>` holds the sum of the report the run was
##      given, so the first wait on the scan as a source (`--idle-wait`'s) wakes only on what is new beyond it, and a scan the spawner did not
##      run, or one that failed, has none
## Red before F6.3: no input-scan-def: is read (1 and 2 fail).
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsInputScanDefCheck.XXXXXX" )" || exit 1
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
	'## input/ is emptied when the run closes: what the scan left there is read while the run is live.' \
	'cp "$MDAT_SPAWN_SANDBOX_ROOT/input/input-scan.md" "$RIG_SCENARIO/input-scan.seen" 2> /dev/null || :' \
	'## The run is in its session: its pointers, then the first wait on a scan the spawner ran, and one on a scan it did not.' \
	'cp "$MMDAPP/.local/agents/sessions/$MDAT_SESSION_ID/session.chat.pointers" "$RIG_SCENARIO/pointers.seen" 2> /dev/null || :' \
	'bash "$RIG_FN" --wait-for-input "$MDAT_SPAWN_AGENT" --wait-source scan:permission-escalation --wait-timeout 0 > "$RIG_SCENARIO/wait.seen" 2> /dev/null < /dev/null || :' \
	'bash "$RIG_FN" --wait-for-input "$MDAT_SPAWN_AGENT" --wait-source scan:member-work-session --wait-timeout 0 > "$RIG_SCENARIO/wait.control" 2> /dev/null < /dev/null || :' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name, the input-scan-def: line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigscanned 'input-scan-def: permission-escalation'
rigRoutine rigplain ''
rigRoutine rigtwo 'input-scan-def: permission-escalation
input-scan-def: member-work-session'
rigRoutine rigbad 'input-scan-def: nosuch-scan'
rigRoutine rignone 'input-scan-def: none'
rigRoutine rigfail 'input-scan-def: permission-escalation --bogus {{team-member}}'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSumOf(){ ## file -- the sum of its bytes, as a wait keeps the sum of a report: <cksum>-<size>
	LC_ALL=C cksum < "$1" 2> /dev/null | LC_ALL=C awk '{ print $1 "-" $2 ; }'
}
rigPointerOf(){ ## scan -- the pointer the run's session holds for the scan of keeper-rig, or none
	cat "$rigTmp/pointers.seen" 2> /dev/null | LC_ALL=C awk -F '\t' -v want="scan:$1:keeper-rig" '$1 == want { print $2 ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }'
}
rigFirst(){ ## file -- its first line
	LC_ALL=C sed -n 1p "$1" 2> /dev/null
}
## One start of keeper-rig's routine through the spawn proxy, waiting for its run; the sandbox it made in rigSandbox.
rigSpawn(){ ## routine short name
	rm -f "$rigTmp"/brief.* "$rigTmp/input-scan.seen" "$rigTmp/pointers.seen" "$rigTmp/wait.seen" "$rigTmp/wait.control"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sandboxes"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-scan-def keeper-rig --routine "$1" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1
	rigSandbox="$( find "$rigWs/.local/agents/spawned" -type d -name input 2> /dev/null | head -1 )"
	rigSandbox="${rigSandbox%/input}"
}

echo "-- 1. the spawner runs the declared scan and saves its result --"
rigSpawn rigscanned
rigAssert "control: the start made a sandbox with its input folder" "$( [ -n "$rigSandbox" ] && [ -d "$rigSandbox/input" ] && echo sandbox || echo none )" "sandbox"
rigAssert "input/input-scan.md holds the scan's report, its macros filled (read by the live run)" "$( [ -f "$rigTmp/input-scan.seen" ] && echo saved || echo none ):$( LC_ALL=C grep -c -F 'permission asks addressed to' "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/report/' ):$( LC_ALL=C grep -c -F '{{' "$rigTmp/input-scan.seen" 2> /dev/null )" "saved:report:0"
rigAssert "7. the run's session holds the scan's pointer at the report the run was given"  "$( rigPointerOf permission-escalation )" "$( rigSumOf "$rigTmp/input-scan.seen" )"
rigAssert "7. so the first wait on that scan has nothing new: TIMEOUT"                      "$( rigFirst "$rigTmp/wait.seen" )" "WAIT-RESULT: TIMEOUT"
rigAssert "7. control: a scan the spawner did not run wakes the first time: RECEIVED"       "$( rigFirst "$rigTmp/wait.control" )" "WAIT-RESULT: RECEIVED"

echo "-- 2. it is presented through the brief --"
rigAssert "the brief names input/input-scan.md"                  "$( LC_ALL=C grep -c -F 'input-scan.md' "$rigTmp/brief.keeper-rig" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "named"

echo "-- 3. control: a routine with no scan has no input-scan.md --"
rigSpawn rigplain
rigAssert "a sandbox, and no input/input-scan.md in it (read by the live run)" "$( [ -n "$rigSandbox" ] && echo sandbox || echo none ):$( [ -e "$rigTmp/input-scan.seen" ] && echo saved || echo none )" "sandbox:none"
rigAssert "7. a start that ran no scan keeps no scan pointer"                                "$( cat "$rigTmp/pointers.seen" 2> /dev/null | LC_ALL=C awk '/^scan:/ { hit++ ; } END { print hit + 0 ; }' )" "0"

echo "-- 4. several lines run in order, each result under its scan --"
rigSpawn rigtwo
rigAssert "two headings, in order, and both scans' own text (read by the live run)" "$( LC_ALL=C grep '^## input scan: ' "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C tr '\n' '|' )" "## input scan: permission-escalation|## input scan: member-work-session|"
rigAssert "the brief names the scans, joined" "$( LC_ALL=C grep -c -F '(permission-escalation, member-work-session)' "$rigTmp/brief.keeper-rig" 2> /dev/null )" "1"
rigAssert "7. each scan of two has its pointer, and the first wait on one has nothing new"  "$( rigPointerOf permission-escalation | LC_ALL=C grep -c -E '^[0-9]+-[0-9]+$' ):$( rigPointerOf member-work-session | LC_ALL=C grep -c -E '^[0-9]+-[0-9]+$' ):$( rigFirst "$rigTmp/wait.seen" )" "1:1:WAIT-RESULT: TIMEOUT"

echo "-- 5. a line naming no scan stops the start; none runs none --"
rigSpawn rigbad
rigAssert "the start fails naming the line, and no brief reached a console" "$( LC_ALL=C grep -c -F "input-scan-def: 'nosuch-scan' does not start with a scan of the tooling" "$rigTmp/spawn.out" ):$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . )" "1:0"
rigSpawn rignone
rigAssert "none: a sandbox, and no input/input-scan.md in it" "$( [ -n "$rigSandbox" ] && echo sandbox || echo none ):$( [ -e "$rigTmp/input-scan.seen" ] && echo saved || echo none )" "sandbox:none"

echo "-- 6. a scan that fails does not stop the start --"
rigSpawn rigfail
rigAssert "the start ran; the file says the scan failed and names the line" "$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -c -F '## input scan failed' "$rigTmp/input-scan.seen" 2> /dev/null ):$( LC_ALL=C grep -c -F 'permission-escalation-input-scan keeper-rig --bogus keeper-rig' "$rigTmp/input-scan.seen" 2> /dev/null )" "1:1:1"
rigAssert "7. a scan that failed has no pointer"                                           "$( rigPointerOf permission-escalation )" "none"

echo "-- 7. the pointer of a definition with options is of the view by name, and of the report a scan kept (the function alone) --"
## AgentsToolsInputScanDefSeed over a stand-in for the scan: the options' run printed OPTIONS-VIEW, the scan by its name prints NAMES-ONLY-VIEW.
cat > "$rigTmp/seed-unit.sh" << 'RIG_SEED_UNIT'
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InputScanDef.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
DistroAgentsTools(){ [ "${RIG_NAMES_RC:-0}" = 0 ] || return 1 ; printf 'NAMES-ONLY-VIEW\n' ; }
printf '%s\n' "$RIG_RUN_TEXT" > "$RIG_RUN_FILE"
AgentsToolsInputScanDefSeed "$RIG_LINE" "${RIG_LINE%% *}" keeper-rig "${RIG_SESSION-seed-unit-session}" "$RIG_RUN_FILE"
RIG_SEED_UNIT
rigSeedUnit(){ ## definition line, the text the spawner's run printed, [names-only run's exit code] -- the pointer the session keeps afterwards
	rm -rf "$rigTmp/seed-ws" ; mkdir -p "$rigTmp/seed-ws"
	( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigTmp/seed-ws" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_LINE="$1" RIG_RUN_TEXT="$2" RIG_RUN_FILE="$rigTmp/seed-run.out" RIG_NAMES_RC="${3:-0}" ${RIG_SESSION+RIG_SESSION="$RIG_SESSION"} \
		bash "$rigTmp/seed-unit.sh" ) > /dev/null 2>&1
	cat "$rigTmp/seed-ws/.local/agents/sessions/seed-unit-session/session.chat.pointers" 2> /dev/null | LC_ALL=C awk -F '\t' '$1 == "scan:permission-escalation:keeper-rig" { print $2 ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }'
}
printf 'NAMES-ONLY-VIEW\n' > "$rigTmp/seed-names.txt" ; printf 'OPTIONS-VIEW\n' > "$rigTmp/seed-options.txt"
rigAssert "a bare line: the pointer is the sum of the report the spawner printed"                  "$( rigSeedUnit 'permission-escalation' 'OPTIONS-VIEW' )" "$( rigSumOf "$rigTmp/seed-options.txt" )"
rigAssert "a line with options: the sum of the scan read by its name, not of the options' run"       "$( rigSeedUnit 'permission-escalation --opt v' 'OPTIONS-VIEW' )" "$( rigSumOf "$rigTmp/seed-names.txt" )"
rigAssert "and where the scan cannot be read by its name, no pointer is kept"                        "$( rigSeedUnit 'permission-escalation --opt v' 'OPTIONS-VIEW' 1 )" "none"
printf 'THE-KEPT-REPORT-OF-A-SESSION\n' > "$rigTmp/seed-kept.txt"
rigAssert "a scan that printed the reference to its kept report: the sum of that report"             "$( rigSeedUnit 'permission-escalation' "a preview line
... KEPT: the whole result, 29 bytes in 1 lines, is in $rigTmp/seed-kept.txt -- all of it is shown above ..." )" "$( rigSumOf "$rigTmp/seed-kept.txt" )"
RIG_SESSION=""
rigAssert "a start with no session keeps no pointer"                                                  "$( rigSeedUnit 'permission-escalation' 'OPTIONS-VIEW' )" "none"
unset RIG_SESSION

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN DEF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_DEF: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
