#!/usr/bin/env bash
## AgentsBashKillGuardCheck -- the Bash tool refuses a kill by pattern (epic S10.20; AgentsHarnessBashKillByPattern,
## AgentsHarnessToolsBash.include). A run owns its own processes alone, and a `pkill`, a `killall`, a `kill` fed by
## `pgrep`, `ps` or `xargs`, or a `kill -1` ends whatever matches on the whole workstation.
## Held, through the served Bash tool:
##   1. `pkill -f rig`, `killall rig`, `kill $(pgrep rig)`, `ps | grep rig | awk | xargs kill`, `kill -9 -1` and a `pkill`
##      after `&&` are each refused with ERROR, nothing run: a marker file the command would also write is not written;
##   2. a `kill` of one pid number, the word pkill inside single quotes, and a comment naming pkill are not refused by this
##      guard: the command runs and writes its marker;
##   3. the detached shape (background: true) refuses the same way;
##   4. a `kill -TERM <pid>` of a process the run does not own (AgentsHarnessBashKillForeign) is refused with ERROR naming
##      the pid, nothing runs and the process lives; a signal 0 probe of it runs; a group signal to it and the detached
##      shape are refused the same way.
## Red: a guard that reads the word inside a quoted string fails `the word quoted as data runs`; one that misses the
## `&&` shape fails its row; a harness without the own-pid limit fails `a signal to a pid not the run's own is refused`
## and the process it signalled is gone.
## Offline: a temp folder of this check alone, removed at its end; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashKillGuardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigSleep=""
trap '[ -z "$rigSleep" ] || kill "$rigSleep" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/inside" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## argument object, call name
	( cd "$rigTmp/ws" && printf '%s' "$1" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp/inside" --access-write-root "$rigTmp/inside" ) \
		> "$rigTmp/$2.out" 2> "$rigTmp/$2.err" || :
}
## One served call of a command that would also write a marker file: the marker says whether anything ran.
rigTry(){ ## call name, command text (JSON-escaped already), detached (true|false)
	rm -f "$rigTmp/inside/mark.$1"
	rigCall "{\"command\":\"$2 ; touch $rigTmp/inside/mark.$1\",\"cwd\":\"$rigTmp/inside\",\"background\":$3}" "$1"
	printf '%s:%s' "$( LC_ALL=C grep -c 'kills by pattern' "$rigTmp/$1.out" )" "$( [ -f "$rigTmp/inside/mark.$1" ] && printf ran || printf none )"
}
## The same, for the own-pid limit: the count of its refusal line, and whether the marker was written.
rigTryOwn(){ ## call name, command text (JSON-escaped already), detached (true|false)
	rm -f "$rigTmp/inside/mark.$1"
	rigCall "{\"command\":\"$2 ; touch $rigTmp/inside/mark.$1\",\"cwd\":\"$rigTmp/inside\",\"background\":$3}" "$1"
	local ownSaid ownWaited=0 ownTasks="$rigTmp/ws/.local/agents/sessions/rig-session/processes"
	ownSaid="$( LC_ALL=C grep -c 'no process of this run' "$rigTmp/$1.out" )"
	## The detached shape answers as a task: the own set is read at the call, so its refusal lands in the task's own output
	## file a moment after the call returned. Read there, five seconds at most.
	if [ "$3" = true ] ; then
		while [ "$ownWaited" -lt 20 ] && [ "$( cat "$ownTasks"/process-*.out 2> /dev/null | LC_ALL=C grep -c 'no process of this run' )" = 0 ] ; do sleep 0.25 ; ownWaited=$(( ownWaited + 1 )) ; done
		ownSaid="$( cat "$ownTasks"/process-*.out 2> /dev/null | LC_ALL=C grep -c 'no process of this run' )"
	fi
	printf '%s:%s' "$ownSaid" "$( [ -f "$rigTmp/inside/mark.$1" ] && printf ran || printf none )"
}

echo "-- 1. a kill by pattern is refused, nothing runs --"
rigAssert "the by-name shape"               "$( rigTry pk 'pkill -f rig-nothing-named-so' false )" "1:none"
rigAssert "the all-by-name shape"           "$( rigTry ka 'killall rig-nothing-named-so' false )" "1:none"
rigAssert "a signal to what pgrep lists"    "$( rigTry pg 'kill -TERM $(pgrep -f rig-nothing-named-so)' false )" "1:none"
rigAssert "a signal through xargs"          "$( rigTry xa 'ps -A | grep rig-nothing | awk \\\"{print \$1}\\\" | xargs kill' false )" "1:none"
rigAssert "a signal to every process"       "$( rigTry al 'kill -9 -1' false )" "1:none"
rigAssert "the by-name shape after &&"      "$( rigTry an 'true && pkill -TERM -f rig-nothing-named-so' false )" "1:none"

echo "-- 2. not a pattern: one pid, a quoted word, a comment --"
rigAssert "one pid number runs"             "$( rigTry pid 'kill -0 99999999 2>/dev/null || true' false )" "0:ran"
rigAssert "the word quoted as data runs"    "$( rigTry quo "echo 'pkill is a word here'" false )" "0:ran"
rigAssert "a comment naming the word runs"  "$( rigTry com 'true # pkill nothing\ntrue' false )" "0:ran"

echo "-- 3. the detached shape refuses the same way --"
rigAssert "the detached shape is refused"   "$( rigTry det 'pkill -f rig-nothing-named-so' true )" "1:none"

echo "-- 4. a pid not the run's own --"
sleep 300 < /dev/null > /dev/null 2>&1 &
rigSleep=$!
rigAssert "a signal to a pid not the run's own is refused" "$( rigTryOwn fo "kill -TERM $rigSleep" false )" "1:none"
rigAssert "and the process lives"                          "$( kill -0 "$rigSleep" 2> /dev/null && printf lives || printf gone )" lives
rigAssert "a signal 0 probe of it runs"                    "$( rigTryOwn pr "kill -0 $rigSleep" false )" "0:ran"
rigAssert "a group signal to it is refused"                "$( rigTryOwn fg "kill -TERM -- -$rigSleep" false )" "1:none"
rigAssert "the detached shape refuses it the same way"     "$( rigTryOwn fd "kill -TERM $rigSleep" true )" "1:none"
## The sleep stays named: the EXIT trap signals it again, so none is left behind where this kill did not take.
kill "$rigSleep" 2> /dev/null ; wait "$rigSleep" 2> /dev/null

echo "-- 5. a scan of a whole tree is refused, nothing runs (the hot-path rule; AgentsHarnessBashScanWide) --"
## The same marker shape: the count of the refusal line, and whether the command ran. The paths are text the guard reads;
## none of them need exist, and a run of one that does not exist still touches the marker.
rigTryScan(){ ## call name, command text (JSON-escaped already)
	rm -f "$rigTmp/inside/mark.$1"
	rigCall "{\"command\":\"$2 ; touch $rigTmp/inside/mark.$1\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" "$1"
	printf '%s:%s' "$( LC_ALL=C grep -c 'scans a whole tree' "$rigTmp/$1.out" )" "$( [ -f "$rigTmp/inside/mark.$1" ] && printf ran || printf none )"
}
rigAssert "a recursive grep over a workspace root"        "$( rigTryScan s1 'grep -rl needle /Users/rig/Workspaces/ws-rig' )" "1:none"
rigAssert "a recursive grep over a store root"            "$( rigTryScan s2 'grep -rn needle /Users/rig/Workspaces/ws-rig/.local/agents/spawned' )" "1:none"
rigAssert "a find over the source tree"                   "$( rigTryScan s3 'find /Users/rig/Workspaces/ws-rig/source -name x.md' )" "1:none"
rigAssert "a find over a volume workspace"                "$( rigTryScan s4 'find /Volumes/ws-2017/myx-work -type d -name inboxes' )" "1:none"
rigAssert "a recursive grep over the workspace variable"  "$( rigTryScan s5 'grep -rn needle \$MMDAPP/.local/agents' )" "1:none"
rigAssert "a recursive grep after &&"                     "$( rigTryScan s6 'true && grep -rln needle /Users/rig/Workspaces/ws-rig/.local' )" "1:none"
rigAssert "a grep over one project folder runs"           "$( rigTryScan s7 'grep -rn needle /Users/rig/Workspaces/ws-rig/source/myx/one.project 2>/dev/null || true' )" "0:ran"
rigAssert "a find in one session folder runs"             "$( rigTryScan s8 'find /Users/rig/Workspaces/ws-rig/.local/agents/sessions/one -name x 2>/dev/null || true' )" "0:ran"
rigAssert "a flat grep of a root runs"                    "$( rigTryScan s9 'grep -n needle /Users/rig/Workspaces/ws-rig 2>/dev/null || true' )" "0:ran"
rigAssert "the words quoted as data run"                  "$( rigTryScan s10 "echo 'find /Users/rig/Workspaces/ws-rig'" )" "0:ran"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH KILL GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a member's Bash can end processes it does not own, by a pattern, on the whole machine" >&2
	echo "  fix:  AgentsHarnessBashKillByPattern and AgentsHarnessBashKillForeign in sh-lib/harness/AgentsHarnessToolsBash.include" >&2
	exit 1
fi
echo "BASH_KILL_GUARD: OK ($rigPassCount assertions, offline)"
