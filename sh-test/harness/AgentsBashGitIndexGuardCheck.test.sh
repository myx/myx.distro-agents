#!/usr/bin/env bash
## AgentsBashGitIndexGuardCheck -- the Bash tool refuses a command that runs git, and one that names an index or cache folder
## (the owner's standing rules; the guard in AgentsHarnessToolsBash.include before the stale-tree rewrite). The tools own both:
## a repository is pulled and published by the workspace palette tasks, and an index is brought current by the ingest task.
## Held, through the served Bash tool, each with a marker file the command would also write, so the marker says whether it ran:
##   1. a command that runs git is refused with ERROR, nothing runs: after `&&`, after `sudo`, after a variable assignment;
##   2. the word git as data runs: inside single quotes, in a comment, as a path (`.git`), inside another word;
##   3. a command that names .local/system-index, .local/output-cache or .local/source-cache is refused, nothing runs;
##   4. a command that names another .local folder runs.
## Red: the check on a harness without the guard fails every refused row, since the marker is written. A guard that reads the
## word anywhere in the text fails `the word git as data runs`.
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
rigTmp="$( rigTempDir AgentsBashGitIndexGuardCheck )" || exit 1
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
## One served call of a command that would also write a marker file: the count of the refusal line, and whether it ran.
rigTry(){ ## call name, refusal words, command text (JSON-escaped already)
	rm -f "$rigTmp/inside/mark.$1"
	rigCall "{\"command\":\"$3 ; touch $rigTmp/inside/mark.$1\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" "$1"
	printf '%s:%s' "$( LC_ALL=C grep -c "$2" "$rigTmp/$1.out" )" "$( [ -f "$rigTmp/inside/mark.$1" ] && printf ran || printf none )"
}

echo "-- 1. a command that runs git is refused, nothing runs --"
rigAssert "git status"                      "$( rigTry g1 'runs git' 'git status' )" "1:none"
rigAssert "git after &&"                    "$( rigTry g2 'runs git' 'true && git log' )" "1:none"
rigAssert "git after sudo"                  "$( rigTry g3 'runs git' 'sudo git pull' )" "1:none"
rigAssert "git after an assignment"         "$( rigTry g4 'runs git' 'GIT_DIR=x git diff' )" "1:none"
rigAssert "git by a path"                   "$( rigTry g5 'runs git' '/usr/bin/git merge x' )" "1:none"
rigAssert "git after a pipe"                "$( rigTry g6 'runs git' 'echo a | git apply' )" "1:none"

echo "-- 2. the word git as data runs --"
rigAssert "the word quoted as data runs"    "$( rigTry d1 'runs git' "echo 'git status'" )" "0:ran"
rigAssert "a comment naming git runs"       "$( rigTry d2 'runs git' 'true # git status\ntrue' )" "0:ran"
rigAssert "a .git path runs"                "$( rigTry d3 'runs git' 'ls .git 2>/dev/null || true' )" "0:ran"
rigAssert "git inside another word runs"    "$( rigTry d4 'runs git' 'echo digit legit github' )" "0:ran"

echo "-- 3. an index or cache folder is refused, nothing runs --"
rigAssert "the system index"                "$( rigTry i1 'index or cache folder' 'ls .local/system-index 2>/dev/null || true' )" "1:none"
rigAssert "the output cache"                "$( rigTry i2 'index or cache folder' 'cat x/.local/output-cache/y 2>/dev/null || true' )" "1:none"
rigAssert "the source cache"                "$( rigTry i3 'index or cache folder' 'echo .local/source-cache' )" "1:none"

echo "-- 4. another .local folder runs --"
rigAssert "the agents folder runs"          "$( rigTry o1 'index or cache folder' 'ls .local/agents 2>/dev/null || true' )" "0:ran"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH GIT INDEX GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a member's Bash can run git and read the index and cache folders the tools own" >&2
	echo "  fix:  the NO GIT guard in sh-lib/harness/AgentsHarnessToolsBash.include" >&2
	exit 1
fi
echo "BASH_GIT_INDEX_GUARD: OK ($rigPassCount assertions, offline)"
