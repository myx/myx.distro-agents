#!/usr/bin/env bash
## Behavioural check on what a console says when it is asked to resume a run it cannot resume
## (sh-lib/manager/AgentsConsoleShellScript.template.sh, the MDAT_SPAWN_RESUME arm), run rather than read,
## against the real console template in a rig workspace with no CLI started.
## Held:
##   1. THE FIRST FAILURE IS IN THE RECORD. A harness run whose keep of the reason ended it is
##      resumed with no kept context: the refusal names the reason the run ended, read from the
##      marker the harness keeps beside the sandbox.
##   2. THE SPAWN RECORD IS THE SECOND READER, and the run's own log the third: where neither the
##      harness's marker nor the record's end-reason says why, the first line of the run's log that
##      reports a fault is said, which is what a fresh spawn that died before it kept anything leaves. With no marker, the reason comes from the record's
##      own `end-reason`, so a run the harness never flagged still says why it stopped.
##   3. NOTHING RECORDED IS SAID AS THAT, never left as a bare refusal that hides it.
##   4. THE CONTROL: the refusal still refuses, and still exits non-zero, whatever it says.
## Red before the change: 1 to 3 said "no kept context" and nothing of why the run ended.
## Offline: the rig's workspace holds the template and its own settings, the CLI is never started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsConsoleShellScript.template.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "console template not found: $rigTemplate"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnResumeReasonCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A fresh workspace: settings naming the origin, and the `deepseek` leg, a harness CLI whose run is
## resumed from its kept context. The refusal is read before any request, so nothing reaches a service.
rigScenario(){ ## name, the .refused text (may be empty), the record's end-reason (may be empty)
	rigDir="$rigTmp/$1"
	rigRun="rig-run-$1"
	rigSand="$rigDir/ws/.local/agents/spawned/$rigRun"
	mkdir -p "$rigSand" "$rigDir/bin" "$rigDir/home" "$rigDir/ws/.local/.agents"
	printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigDir/ws/.local/MDLT.settings.env"
	printf 'SPAWN_TIER_NORMAL=deepseek\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'PRESET_CLI_SERVICE=deepseek\n' > "$rigDir/ws/.local/.agents/preset-deepseek.agent.env"
	[ -z "$2" ] || printf '%s\n' "$2" > "$rigSand/$rigRun.refused"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: magic-tester\nstatus: spawn-failed\ncli: deepseek\n' "$rigRun" "$rigRun"
		[ -z "$3" ] || printf 'end-reason: %s\n' "$3"
		printf -- '---\n\n# Spawn session: %s\n' "$rigRun"
	} > "$rigSand/$rigRun.spawn.md"
	## No context.jsonl: the run kept none, which is the case this check is about.
	rm -f "$rigSand/context.jsonl"
}
## One console start, guarded into the rig tree, with the resume asked for and the leg's own flag
## gone so no real service is reached. Its stderr is read; its status is the refusal's.
rigConsoleResume(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" RIG_TEMPLATE="$rigTemplate" RIG_RUN="$rigRun" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" || exit 99
			exec env MDAT_SPAWN_SESSION_ID="$RIG_RUN" MDAT_SPAWN_RESUME=true bash "$RIG_TEMPLATE" --cli deepseek --non-interactive rig-prompt
		' < /dev/null > "$rigDir/out" 2> "$rigDir/err"
	printf '%s' "$?" > "$rigDir/rc"
}

echo "-- 1. the reason the harness kept is what the refusal says --"
rigScenario kept 'api.deepseek.com gave no complete answer -- gave up after 3 stream attempts, none reached a clean [DONE]' ''
rigConsoleResume
rigAssert "the refusal that a run cannot be resumed names the reason the harness kept for its end" \
	"$( LC_ALL=C grep -c -F -- 'Why the run ended: api.deepseek.com gave no complete answer -- gave up after 3 stream attempts, none reached a clean [DONE]' "$rigDir/err" )" "1"

echo "-- 1b. the run's own log, where neither the marker nor the record says --"
## Run 633f79fd: a fresh spawn whose first run died at a harness fault, with no context kept, no
## marker and no end-reason. The fault is the first reporting line of its own log, and it is what
## the refusal must say rather than only that no context was kept.
rigScenario logged '' ''
mkdir -p "$rigDir/ws/.local/agents/sessions/$rigRun"
printf '%s\n' '# console: rig access roots' \
	'/Users/rig/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh: line 539: export: DistroAgentsTools: not a function' \
	'# console: rig access roots' > "$rigDir/ws/.local/agents/sessions/$rigRun/session.log"
## The record's own header, rewritten with its output-file inside the frontmatter, where the console reads it.
LC_ALL=C awk -v logPath="$rigDir/ws/.local/agents/sessions/$rigRun/session.log" '
	$0 == "---" && ++fence == 2 { print "output-file: " logPath }
	{ print }
' "$rigSand/$rigRun.spawn.md" > "$rigSand/$rigRun.spawn.next" && mv -f "$rigSand/$rigRun.spawn.next" "$rigSand/$rigRun.spawn.md"
rigConsoleResume
rigAssert "with neither marker nor end-reason the refusal names the last line of the run's own log that reports a fault" \
	"$( LC_ALL=C grep -c -F -- 'Why the run ended: /Users/rig/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh: line 539: export: DistroAgentsTools: not a function' "$rigDir/err" )" "1"
## The log of a run that ended on a refusal holds that refusal too, and the run's own cause is the
## fault above it. This is the shape of the 30 logs that carried only the console's own refusal.
printf '%s\n' '# console: rig access roots' \
	'/Users/rig/harness/AgentsDeepseekHarness.sh: line 7: cannot report the round' \
	'⛔ ERROR: AgentsDeepseekHarness.sh: round 37: gave up after 3 stream attempts, none reached a clean [DONE]' \
	'⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_RESUME is true but no kept context, and this is this refusal itself' >> "$rigDir/ws/.local/agents/sessions/$rigRun/session.log"
rigConsoleResume
rigAssert "and the console's own refusal, written into that same log after it, is never read as the cause: the fault that ended the run is named" \
	"$( LC_ALL=C grep -c -F -- 'Why the run ended: ⛔ ERROR: AgentsDeepseekHarness.sh: round 37: gave up after 3 stream attempts, none reached a clean [DONE]' "$rigDir/err" ):$( LC_ALL=C grep -c -F -- 'Why the run ended: ⛔ ERROR: DistroAgentsConsole' "$rigDir/err" )" "1:0"

echo "-- 2. the spawn record's own end-reason is the second reader --"
rigScenario record '' 'its round was refused for its context length, and the summarise round was refused too'
rigConsoleResume
rigAssert "with no marker the reason comes from the record's end-reason" \
	"$( LC_ALL=C grep -c -F -- 'Why the run ended: its round was refused for its context length, and the summarise round was refused too' "$rigDir/err" )" "1"

echo "-- 3. nothing recorded is said as nothing recorded --"
rigScenario bare '' ''
rigConsoleResume
rigAssert "with neither marker nor end-reason the refusal says that nothing recorded a reason" \
	"$( LC_ALL=C grep -c -F -- 'Why the run ended: nothing recorded a reason for its end' "$rigDir/err" )" "1"

echo "-- 4. the control: it refuses, and it exits non-zero --"
rigAssert "the refusal still refuses rather than starting a session that would look resumed" \
	"$( LC_ALL=C grep -c -F -- "MDAT_SPAWN_RESUME is true but 'deepseek' has no --resume flag and no kept context" "$rigDir/err" ):$( cat "$rigDir/rc" )" "1:1"
## The control of the control: a run that kept its context is not refused at all.
rigScenario ctx 'api.deepseek.com gave no complete answer' ''
printf '%s\n' '{"type":"context","version":1,"session":"'"$rigRun"'","leg":1,"from":0}' > "$rigSand/context.jsonl"
rigConsoleResume
rigAssert "control: with a context kept the same start is not refused, so the three assertions above read the branch they name" \
	"$( LC_ALL=C grep -c -F -- 'MDAT_SPAWN_RESUME is true but' "$rigDir/err" )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN RESUME REASON CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  sh-lib/manager/AgentsConsoleShellScript.template.sh, the MDAT_SPAWN_RESUME arm -- never the assertion" >&2
	exit 1
fi
printf 'SPAWN_RESUME_REASON: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
