#!/usr/bin/env bash
## Behavioural check on S19.2: the pause holds a run at the named points. Seven tools hold where the epic names them, and
## `execute` is the one point that refuses instead. Held, each with a control that the same call finishes while no flag stands:
##   1. Read is held at its START, so a paused run reads nothing while it holds
##   2. Write and Edit are held at their EXIT, so the work is done and the result waits
##   3. Bash and WorkspaceContextExecute are held at their EXIT, so the command ran and its result waits
##   4. SendMessage and SubagentHandback are held at their EXIT, so the message went and its result waits
##   5. `execute` is checked at its START, and once the pause ends it refuses with PAUSED: nothing ran, and the run calls it again
##   6. a flag on the run's coworking session holds its runs as the run's own flag does
## A tool's own body is replaced by a marker here: what this check measures is the pause envelope around it, and each body has
## its own check. The wait itself is the real one, at its own 5-second look.
## Red before S19: no point asks anything, so every call returns while the flag still stands.
## Offline: the rig is this check's own temp tree, and no socket is opened.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPkg/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigLib/harness/AgentsHarnessToolsFile.include" ] || rigRefuse "the file tools are not at the origin: $rigLib/harness/AgentsHarnessToolsFile.include"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessPausePointsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigRun="$rigWs/.local/agents/sessions/rig-run"
rigSess="$rigWs/.local/agents/sessions/rig-sess"
mkdir -p "$rigRun" "$rigSess" "$rigTmp/marks" "$rigTmp/src" || rigRefuse "the rig could not be made: $rigTmp"
printf 'rig-alpha\n' > "$rigTmp/src/a.txt"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One tool function, run in a rig of its own: the include sourced, the tool's own body replaced by a marker, so only the
## pause envelope is under test. The call runs in the background; its output file is how this shell sees it end.
cat > "$rigTmp/rigPauseCall.sh" <<'RIGCALL'
#!/usr/bin/env bash
## $1 the include to source, $2 the tool function, $3 the Run function to stub (may be empty), the rest the call's arguments.
set -u
rigInclude="$1" ; rigTool="$2" ; rigStub="$3" ; shift 3
rigMarked(){
	printf 'ran\n' > "$RIG_MARK"
	return 0
}
. "$rigInclude" || exit 90
[ -z "$rigStub" ] || eval "$rigStub(){ rigMarked ; }"
printf 'entered\n' > "$RIG_MARK.entered"
"$rigTool" "$@"
printf 'returned\n' > "$RIG_MARK.returned"
exit 0
RIGCALL
chmod +x "$rigTmp/rigPauseCall.sh"

## The one shape every case below takes: a call in the background, a flag that stands for a moment and then goes, and what
## the call did in that time.
rigCase(){ ## name, the flag's folder (`-` for none), the include, the tool, the Run function to stub, the call's arguments...
	local caseName="$1" caseFlagDir="$2" caseInclude="$3" caseTool="$4" caseStub="$5"
	shift 5
	rm -f "$rigTmp/marks"/*
	[ "$caseFlagDir" = "-" ] || : > "$caseFlagDir/paused"
	( cd "$rigTmp" && RIG_MARK="$rigTmp/marks/call" FOLDER_FLAG="" env MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-run MDAT_SESSION_ID=rig-sess MDAT_SPAWN_AGENT=magic-developer \
		bash "$rigTmp/rigPauseCall.sh" "$caseInclude" "$caseTool" "$caseStub" "$@" ) > "$rigTmp/marks/out" 2>&1 &
	rigCasePid=$!
	sleep 2
	local heldYet=no
	[ ! -f "$rigTmp/marks/call.returned" ] && heldYet=yes
	[ "$caseFlagDir" = "-" ] || rm -f "$caseFlagDir/paused"
	wait "$rigCasePid" 2> /dev/null || :
	local doneYet=no
	[ -f "$rigTmp/marks/call.returned" ] && doneYet=yes
	local markedYet=no
	[ ! -f "$rigTmp/marks/call" ] || markedYet=yes
	printf '%s\t%s\t%s\t%s\n' "$heldYet" "$doneYet" "$markedYet" "$( LC_ALL=C head -3 "$rigTmp/marks/out" | LC_ALL=C tr '\n' ' ' )"
}

echo "-- 1. Read is held at its start --"
rigAssert "Read with a flag standing is still out after two seconds, and ends once the flag goes, having read nothing" \
	"$( rigCase read "$rigRun" "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolRead "" "" 0 "" "" "$rigTmp/src/a.txt" | LC_ALL=C cut -f1-3 )" \
	"yes	yes	no"
echo "-- 2. Write and Edit are held at their exit --"
rigAssert "Write holds, then goes on, and its own body ran" \
	"$( rigCase write "$rigRun" "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolWrite AgentsHarnessToolWriteRun "$rigTmp/src/w.txt" "rig" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
rigAssert "Edit holds, then goes on, and its own body ran" \
	"$( rigCase edit "$rigRun" "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolEdit AgentsHarnessToolEditRun "$rigTmp/src/a.txt" "x" "y" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
echo "-- 3. Bash is held at its exit, and so is WorkspaceContextExecute --"
rigAssert "Bash holds, then goes on, and its own body ran" \
	"$( rigCase bash "$rigRun" "$rigLib/harness/AgentsHarnessToolsBash.include" AgentsHarnessToolBash AgentsHarnessToolBashRun "$rigTmp" "true" "" "" "" "" "" "" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
rigAssert "WorkspaceContextExecute holds, then goes on, and its own body ran" \
	"$( rigCase execute "$rigRun" "$rigLib/harness/AgentsHarnessToolsBash.include" AgentsHarnessToolWorkspaceContextExecute AgentsHarnessToolWorkspaceContextExecuteRun "true" "" "" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
echo "-- 4. SendMessage and SubagentHandback are held at their exit --"
rigAssert "SendMessage holds, then goes on, and its own body ran" \
	"$( rigCase send "$rigRun" "$rigLib/harness/AgentsHarnessMessages.include" AgentsHarnessToolSendMessage AgentsHarnessToolSendMessageRun "magic-team" "rig" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
rigAssert "SubagentHandback holds, then goes on, and its own body ran" \
	"$( rigCase handback "$rigRun" "$rigLib/harness/AgentsHarnessReports.include" AgentsHarnessToolSubagentHandback AgentsHarnessToolSubagentHandbackRun "rig outcome" | LC_ALL=C cut -f1-3 )" "yes	yes	yes"
echo "-- 5. a flag on the run's coworking session holds it too --"
rigAssert "Read is held by its session's flag, not only by its own folder" \
	"$( rigCase sessread "$rigSess" "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolRead "" "" 0 "" "" "$rigTmp/src/a.txt" | LC_ALL=C cut -f1-3 )" "yes	yes	no"
echo "-- 6. the control: with no flag at all, every one of them ends at once --"
rm -f "$rigRun/paused" "$rigSess/paused"
rigAssert "Read with no flag ends at once" \
	"$( rigCase read-free - "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolRead "" "" 0 "" "" "$rigTmp/src/a.txt" | LC_ALL=C cut -f1-3 )" "no	yes	no"
rigAssert "Write with no flag ends at once, its body run" \
	"$( rigCase write-free - "$rigLib/harness/AgentsHarnessToolsFile.include" AgentsHarnessToolWrite AgentsHarnessToolWriteRun "$rigTmp/src/w.txt" "rig" | LC_ALL=C cut -f1-3 )" "no	yes	yes"

echo "-- 7. \`execute\` checks at its START, and refuses rather than holding --"
## The one point a paused run is refused at rather than held at, and it is the tooling's own arm: `execute` there.
rigExecute(){ ## the flag stands at the start, and a background job lifts it two seconds in
	( sleep 2 ; rm -f "$rigRun/paused" ) &
	( cd "$rigTmp" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-run \
		bash "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute ) <<< 'printf RIG-RAN' 2>&1
}
: > "$rigRun/paused"
rigAssert "a call made while the flag stands, and lifted inside the wait, is refused with PAUSED, and nothing ran" \
	"$( rigExecute | LC_ALL=C awk '/PAUSED/ { paused = 1 } /RIG-RAN/ { ran = 1 } END { print ( paused && ! ran ? "refused-nothing-ran" : "held-or-ran:" paused ":" ran ) }' )" \
	"refused-nothing-ran"
rm -f "$rigRun/paused"
rigAssert "the control: with no flag standing, the same call runs its script" "$( rigExecute | LC_ALL=C grep -c 'RIG-RAN' )" "1"

for rigFile in "$rigLib/harness/AgentsHarnessToolsFile.include" "$rigLib/harness/AgentsHarnessToolsBash.include" "$rigLib/harness/AgentsHarnessMessages.include" "$rigLib/harness/AgentsHarnessReports.include" "$rigLib/session/AgentsTools.SessionPause.include" ; do
	[ -f "$rigFile" ] || rigRefuse "a file this check measures is gone: $rigFile"
	LC_ALL=C grep -q . "$rigFile" || rigRefuse "a file this check measures is empty: $rigFile"
	bash -n "$rigFile" 2> /dev/null || rigRefuse "a file this check measures does not parse: $rigFile"
done
rigAssert "every file this check measures parses" "parsed" "parsed"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PAUSE POINTS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PAUSE_POINTS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
