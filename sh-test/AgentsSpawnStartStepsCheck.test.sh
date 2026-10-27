#!/usr/bin/env bash
## Behavioural check on the clock of a start, run rather than read: through the real spawn proxy on a stand-in console, a
## start of a routine that carries an input scan writes its start milestone with the seconds each step of the start took.
## Held:
##   1. THE START MILESTONE CARRIES THE STEPS. The first line of the session's milestones reads `start steps: <step>=<n>s ...
##      total=<n>s`, in the order the start ran them, the steps `prepare`, `scan-wait`, `routine-lock`, `incoming-sync`,
##      `records`, `session-thread`, `start-post`, `sandbox`, `input-scan` and `brief-launch` among them, and the transcript is
##      the same as before.
##   2. THE SCAN SAYS ITS OWN SECTIONS. The `input-scan` step carries the sections of the scan in brackets, `input-scan[inbox=<n>s
##      ... slack-collect=<n>s]=<n>s`, so a slow scan names its slow section in the same line.
##   3. NOTHING OF THE CLOCK LEAKS. The console the start launched has no MDAT_SCAN_TRACE_FILE in its environment.
## Offline: the same rig as AgentsSpawnCloseWithdrawCheck; the collect window of the scan is three seconds; no Slack call is made.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigNote="tooling-note.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnStartStepsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents" ; rigPend="$rigAgents/pending" ; rigFn="$rigTool"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/source/rigrepo/rigpkg" "$rigHome" "$rigSkills/rig-member" "$rigData/board/running"
printf 'SLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigWs/.local/.agents/preset-rig-cli.agent.env"
printf '# rigpkg\n' > "$rigWs/source/rigrepo/rigpkg/MAGIC.md"
printf '# workspace\n' > "$rigWs/MAGIC.md"
printf '# rig routine\n' > "$rigSkills/rig-member/magic-team.rig.routine.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the rig's file, which holds
## no line at all, so no run of this rig is ever "running", and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\ncat "${0%%/*}/../uptime.line" 2> /dev/null\n' > "$rigTmp/bin/uptime"
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 1.25 1.00 1.00\n' > "$rigTmp/uptime.line"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/uptime"

## The routine of this rig carries an input scan, the work-duty one, as the real work-duty routine does; its collect window is one second.
rm -f "$rigSkills/rig-member/magic-team.rig.routine.md"
mkdir -p "$rigSkills/magic-team"
printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig\nrequires-session-kind: standalone\ninput-scan-def: work-duty --session-id {{session-id}}\n---\n# rig routine with a scan\n' > "$rigSkills/magic-team/magic-team.rig.routine.md"
printf 'SLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_TIER_NORMAL=rig-cli\nWAIT_COLLECT_SECONDS=3\n' > "$rigWs/.local/.agents/magic-team.agent.env"
mkdir -p "$rigData/inboxes/rig-member/incoming" "$rigWs/.local/agents/members/rig-member"

## THE STAND-IN CONSOLE: it notes whether the clock's file reached its environment, and ends.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCLI'
#!/bin/sh
## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)
cat > /dev/null
[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "rig-cli" > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_TMP/run-id"
printf 'trace-file=[%s]\n' "${MDAT_SCAN_TRACE_FILE:-}" > "$RIG_TMP/console-env"
mkdir -p "$MDAT_SPAWN_SANDBOX_ROOT/output" && echo deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"
RIGCLI
chmod +x "$rigWs/DistroAgentsConsole.sh"

echo "-- 1. the start milestone carries the seconds of each step of the start --"
printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
	| env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --routine magic-team.rig.routine.md --dispatch-doc:create --wait
		' > "$rigTmp/spawn.out" 2> "$rigTmp/spawn.err"
rigRunId="$( cat "$rigTmp/run-id" 2> /dev/null )"
rigMiles="$rigWs/.local/agents/sessions/$rigRunId/milestones"
[ -n "$rigRunId" ] || { cat "$rigTmp/spawn.err" | head -20 ; rigRefuse "the stand-in console never ran" ; }
rigLine="$( LC_ALL=C sed -n 1p "$rigMiles" 2> /dev/null )"
rigStepsRe='^start steps: prepare=[0-9]+s scan-wait=[0-9]+s routine-lock=[0-9]+s incoming-sync=[0-9]+s records=[0-9]+s session-thread=[0-9]+s start-post=[0-9]+s sandbox=[0-9]+s input-scan\[[^]]*\]=[0-9]+s brief-launch=[0-9]+s total=[0-9]+s$'
rigAssert "the first milestone is the start, with the seconds of every step in the order the start ran them, and a total" "$( printf '%s' "$rigLine" | LC_ALL=C sed 's/^[0-9T:Z-]* //' | LC_ALL=C grep -c -E "$rigStepsRe" || : )" "1"
echo "-- 2. the scan says its own sections, and the seed of the Wait baseline does not wait the collect window out a second time --"
rigAssert "the input-scan step carries the sections of the scan: the collect that waited, then the seed run that skipped it" "$( printf '%s' "$rigLine" | LC_ALL=C grep -c -E 'input-scan\[inbox=[0-9]+s slack-collect=[0-9]+s inbox=[0-9]+s slack-skipped=[01]s\]=[0-9]+s' || : )" "1"
echo "-- 3. nothing of the clock leaks --"
rigAssert "the console has no MDAT_SCAN_TRACE_FILE in its environment" "$( cat "$rigTmp/console-env" 2> /dev/null )" "trace-file=[]"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ AGENT SPAWN START STEPS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "AGENT SPAWN START STEPS: OK ($rigPasses assertions, offline)"
