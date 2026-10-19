#!/usr/bin/env bash
## Behavioural check on where the tooling keeps its scratch: in the workspace's own .local/agents/scratch,
## never in the system's temp folder (the owner's rule), and nowhere at all where there is no workspace. Run rather than read, offline. The harness's own scratch is held by
## AgentsCredentialExposureCheck and the manager check's run folder by AgentsManagerCheckRunCheck; held here:
##   1. --intern-op-remote-bootstrap-emit takes the remote workspace, and refuses with none, or with a path
##      that could leave its quotes or climb out of itself
##   2. the script it emits keeps its temp root in that workspace's .local/agents/scratch, runs the task
##      there, and removes the root after
##   3. that script refuses, and makes nothing, where the path it was given is no workspace
##   4. the manager screen's reader keeps a call's files in the workspace's scratch, and with no workspace
##      starts no call and says why
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkspaceScratchCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigBare="$rigTmp/no-workspace"
mkdir -p "$rigWs/.local" "$rigBare" "$rigTmp/home"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigEmit(){ ## name, emit arguments... -- the emitted script in <name>.sh, stderr in <name>.err, rc in rigRc
	local emitName="$1" ; shift
	rigRc=0
	printf 'echo RIG-TASK-RAN ; pwd\n' | ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigTool" --intern-op-remote-bootstrap-emit --label rig-boot --task-from-stdin "$@" ) \
		> "$rigTmp/$emitName.sh" 2> "$rigTmp/$emitName.err" || rigRc=$?
}
rigBoot(){ ## name -- runs <name>.sh as a target shell would, from its stdin; out and err beside it, rc in rigRc
	rigRc=0
	( cd / && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" /bin/sh ) < "$rigTmp/$1.sh" > "$rigTmp/$1.out" 2> "$rigTmp/$1.boot.err" || rigRc=$?
}

echo "-- 1. the emit takes the remote workspace, and refuses without a good one --"
rigEmit none
rigAssert "with no --remote-workspace it is refused, rc 1, and emits nothing" "$rigRc $( LC_ALL=C wc -c < "$rigTmp/none.sh" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -e '--remote-workspace <absolute path> is required' "$rigTmp/none.err" )" "1 0 1"
rigEmit climb --remote-workspace "$rigWs/../ws"
rigAssert "a path with a .. segment is refused" "$rigRc $( LC_ALL=C grep -c -e '--remote-workspace: the absolute path' "$rigTmp/climb.err" )" "1 1"
rigEmit relative --remote-workspace "ws"
rigAssert "a relative path is refused" "$rigRc $( LC_ALL=C grep -c -e '--remote-workspace: the absolute path' "$rigTmp/relative.err" )" "1 1"
rigEmit quote --remote-workspace "$rigTmp/it's"
rigAssert "a path holding a quote is refused" "$rigRc $( LC_ALL=C grep -c -e '--remote-workspace: the absolute path' "$rigTmp/quote.err" )" "1 1"

echo "-- 2. the emitted script keeps its temp root in that workspace's scratch --"
rigEmit good --remote-workspace "$rigWs"
[ "$rigRc" = 0 ] && [ -s "$rigTmp/good.sh" ] || rigRefuse "the emit gave no script for a good workspace, so nothing below would be measured: $( head -3 "$rigTmp/good.err" | LC_ALL=C tr '\n' ' ' )"
rigBoot good
rigRoot="$( LC_ALL=C sed -n 's/^BOOTSTRAP_TEMP_ROOT=//p' "$rigTmp/good.boot.err" | head -1 )"
rigAssert "the script ran its task, rc 0" "$rigRc $( LC_ALL=C grep -c -x 'RIG-TASK-RAN' "$rigTmp/good.out" )" "0 1"
rigAssert "its temp root was in the workspace's .local/agents/scratch" "$( case "$rigRoot" in ("$rigWs/.local/agents/scratch/rig-boot."*) printf scratch ;; ('') printf none ;; (*) printf '%s' "$rigRoot" ;; esac )" scratch
rigAssert "and is gone after it" "$( [ -n "$rigRoot" ] && [ ! -e "$rigRoot" ] && printf gone || printf left )" gone

echo "-- 3. where its path is no workspace, the script refuses and makes nothing --"
rigEmit bare --remote-workspace "$rigBare"
rigBoot bare
rigAssert "the script refuses, rc 1, saying the path is no workspace, and runs no task" "$rigRc $( LC_ALL=C grep -c -F 'no myx.distro workspace to keep the temp root in' "$rigTmp/bare.boot.err" ) $( LC_ALL=C grep -c -x 'RIG-TASK-RAN' "$rigTmp/bare.out" )" "1 1 0"
rigAssert "and makes nothing there" "$( find "$rigBare" -mindepth 1 | LC_ALL=C grep -c . )" 0

echo "-- 4. the manager screen's reader keeps a call's files in the workspace's scratch --"
rigReader(){ ## workspace given to the reader ('' for none) -- status and error of one call of /bin/echo
	env -u MMDAPP python3 -I -B -c '
import sys, time, importlib.util
spec = importlib.util.spec_from_file_location("screen", sys.argv[1])
screen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen)
reader = screen.OperationReader(["/bin/echo"], sys.argv[2])
reader.start("read", "rig", ["RIG-ECHO"])
for wait in range(100):
    done = reader.collect()
    if done:
        print("%s|%s|%s" % (done[0]["status"], done[0]["text"].strip(), done[0]["error"]))
        break
    time.sleep(0.05)
' "$rigHere/AgentsManagerScreen.py" "$1" 2> "$rigTmp/reader.err"
}
rigAssert "with a workspace, a call runs and its output comes back" "$( rigReader "$rigWs" )" "0|RIG-ECHO|"
rigAssert "its files were kept in the workspace's .local/agents/scratch" "$( [ -d "$rigWs/.local/agents/scratch" ] && printf made || printf none )" made
rigAssert "with no workspace, no call is started, and the reader says why" "$( rigReader "" )" "127||could not be started: no workspace to keep its output in (.local/agents/scratch)"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WORKSPACE SCRATCH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WORKSPACE_SCRATCH: OK (%d assertions, offline)\n' "$rigPasses"
