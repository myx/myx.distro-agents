#!/usr/bin/env bash
## AgentsBashGitWriteGuardCheck -- a git write over a source tree is refused, and a run that issues one is stopped
## (the human-owner's ruling of 26 November: running git over the source is intentional damage).
## Held through the served Bash tool, each refused call also writing a marker file, so the marker says whether it ran:
##   1. each listed write is refused with ERROR, its tree and its subcommand named, and nothing runs:
##      reset, checkout, restore, clean, stash, revert, commit;
##   2. the same write is refused through a wrapper: a shell function in the call's own text, a wrapper script that
##      calls git, and `git -C <source path>`;
##   3. the read-only forms still run: status, log, diff, show, rev-parse, ls-remote (the control);
##   4. a write outside a source tree runs: the team-data store and a temp folder are not source trees;
##   5. the stop is recorded in the run's audit log and its session thread.
## Red: on a harness without the guard every refused row runs and writes its marker, so the row fails. A green here
## says the guard reads the call and its wrapper, and never a word quoted as data.
## Offline: a rig of this check alone, removed at its end; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashGitWriteGuardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents/sessions/rig-session" "$rigTmp/skills/$rigMember" \
	"$rigTmp/home" "$rigTmp/ws/source/rig.pkg" "$rigTmp/ws/source/rig.pkg/nested" "$rigTmp/ws/.local/temp/plain" \
	"$rigTmp/ws/.local/agents/team-data-root" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
## The two repositories the rows are judged on: one source tree, and one store that is no source tree.
for rigRepo in "$rigTmp/ws/source/rig.pkg" "$rigTmp/ws/.local/temp/plain" ; do
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 /usr/bin/git -C "$rigRepo" init -q 2>/dev/null || rigRefuse "could not make the rig repository $rigRepo"
	printf 'seed\n' > "$rigRepo/seed.txt"
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 /usr/bin/git -C "$rigRepo" add -A 2>/dev/null || :
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 /usr/bin/git -C "$rigRepo" -c user.name=rig -c user.email=rig@rig.invalid commit -q -m seed 2>/dev/null || :
done
## The run's two records, so a stop can be read from the place a reader looks: its audit log, and its session thread.
printf '%s\n' "$rigTmp/audit.log" > "$rigTmp/ws/.local/agents/sessions/rig-session/transcript"
: > "$rigTmp/audit.log"
printf '# %s rig-a: the session thread\n\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigTmp/ws/.local/agents/sessions/rig-session/session.chat"
printf '1\t-\t-\town\t1\t-\n' > "$rigTmp/ws/.local/agents/sessions/rig-session/session.chat.index"
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
## One served call, in a fresh harness process, with the run's own session and member, so the records it writes land in
## this rig: the call's whole text is the command. The rig's source tree is declared, because a rig lives in a sandbox tree
## and the guard's own computation leaves a sandbox out by design: only the tree is declared, never the guard's decision.
rigCall(){ ## call name, command text (JSON-escaped already), cwd (optional)
	( cd "$rigTmp/ws" && printf '{"command":"%s","cwd":"%s","background":false}' "$2" "${3:-$rigTmp/ws}" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" \
		MDLT_ORIGIN="$rigOrigin" MDAT_GIT_SOURCE_ROOTS="$rigTmp/ws/source" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		python3 -I -B "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 60 -- \
		bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp/ws" --access-write-root "$rigTmp/ws" ) \
		> "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
}
## A refused call: the count of the refusal line, and whether the marker the command would also write exists.
rigTry(){ ## call name, marker-adding command text (JSON-escaped), refusal words
	rm -f "$rigTmp/ws/mark.$1"
	rigCall "$1" "$2 ; touch $rigTmp/ws/mark.$1"
	printf '%s:%s' "$( LC_ALL=C grep -c "$3" "$rigTmp/$1.out" 2>/dev/null || : )" "$( [ -f "$rigTmp/ws/mark.$1" ] && printf ran || printf none )"
}
## A call that runs: the count of the refusal line, and whether the marker was written.
rigRuns(){ ## call name, command text (JSON-escaped), refusal words
	rm -f "$rigTmp/ws/mark.$1"
	rigCall "$1" "$2 ; touch $rigTmp/ws/mark.$1"
	printf '%s:%s' "$( LC_ALL=C grep -c "$3" "$rigTmp/$1.out" 2>/dev/null || : )" "$( [ -f "$rigTmp/ws/mark.$1" ] && printf ran || printf none )"
}
rigSource="$rigTmp/ws/source/rig.pkg"
rigPlain="$rigTmp/ws/.local/temp/plain"

echo "-- 1. each listed git write over a source tree is refused, nothing runs --"
## The guard's own computation, on the real workspace: the tree it protects is named by the workspace, never by a constant.
rigAssert "the workspace's source tree is a source tree" \
	"$( env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$MMDAPP" MDLT_ORIGIN="$rigOrigin" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.GitWrite.include" ; AgentsToolsGitSourceRoots' 2>/dev/null | LC_ALL=C grep -c -x "$( cd "$MMDAPP/source" 2> /dev/null && pwd -P )" )" "1"
rigAssert "reset --hard"        "$( rigTry w1 "git -C $rigSource reset --hard HEAD" 'git write (reset)' )" "1:none"
rigAssert "checkout --"        "$( rigTry w2 "git -C $rigSource checkout -- ." 'git write (checkout)' )" "1:none"
rigAssert "restore"            "$( rigTry w3 "git -C $rigSource restore ." 'git write (restore)' )" "1:none"
rigAssert "clean -fd"          "$( rigTry w4 "git -C $rigSource clean -fd" 'git write (clean)' )" "1:none"
rigAssert "stash"              "$( rigTry w5 "git -C $rigSource stash" 'git write (stash)' )" "1:none"
rigAssert "revert"             "$( rigTry w6 "git -C $rigSource revert --no-edit HEAD" 'git write (revert)' )" "1:none"
rigAssert "commit"             "$( rigTry w7 "git -C $rigSource commit -m rig" 'git write (commit)' )" "1:none"
rigAssert "the tree is named"  "$( LC_ALL=C grep -c "Tree: $rigSource" "$rigTmp/w1.out" 2>/dev/null || : )" "1"
rigAssert "the rule is named"  "$( LC_ALL=C grep -c 'no run writes a source tree with git' "$rigTmp/w1.out" 2>/dev/null || : )" "1"

echo "-- 2. the same write is refused through a wrapper --"
rigAssert "a shell function in the call" "$( rigTry r1 'g(){ git -C '"$rigSource"' reset --hard HEAD ; } ; g' 'git write (reset)' )" "1:none"
printf '#!/bin/sh\ngit -C %s reset --hard HEAD\n' "$rigSource" > "$rigTmp/ws/wrap-reset.sh"
chmod +x "$rigTmp/ws/wrap-reset.sh"
rigAssert "a wrapper script that calls git" "$( rigTry r2 "$rigTmp/ws/wrap-reset.sh" 'git write (reset)' )" "1:none"
rigAssert "git -C naming the tree"          "$( rigTry r3 "git -C $rigSource checkout -- ." 'git write (checkout)' )" "1:none"
rigAssert "git run from inside the tree"    "$( rm -f "$rigTmp/ws/mark.r4" ; rigCall r4 'git reset --hard HEAD ; touch '"$rigTmp"'/ws/mark.r4' "$rigSource" ; printf '%s:%s' "$( LC_ALL=C grep -c 'git write (reset)' "$rigTmp/r4.out" 2>/dev/null || : )" "$( [ -f "$rigTmp/ws/mark.r4" ] && printf ran || printf none )" )" "1:none"

echo "-- 3. the read-only forms still run (the control) --"
rigAssert "git status"     "$( rigRuns c1 "git -C $rigSource status --porcelain" 'git write (' )" "0:ran"
rigAssert "git log"        "$( rigRuns c2 "git -C $rigSource log --oneline -1" 'git write (' )" "0:ran"
rigAssert "git diff"       "$( rigRuns c3 "git -C $rigSource diff --stat" 'git write (' )" "0:ran"
rigAssert "git show"       "$( rigRuns c4 "git -C $rigSource show --stat --oneline HEAD" 'git write (' )" "0:ran"
rigAssert "git rev-parse"  "$( rigRuns c5 "git -C $rigSource rev-parse --short HEAD" 'git write (' )" "0:ran"
rigAssert "git ls-remote"  "$( rigRuns c6 "git -C $rigSource ls-remote . 2>&1 || true" 'git write (' )" "0:ran"

echo "-- 4. a write outside a source tree runs --"
rigAssert "a write in a temp folder"  "$( rigRuns o1 "git -C $rigPlain checkout -- ." 'git write (' )" "0:ran"
rigAssert "a write in the store"      "$( rigRuns o2 "git -C $rigTmp/ws/.local/agents/team-data-root checkout -- . 2>&1 || true" 'git write (' )" "0:ran"

echo "-- 5. the stop is recorded in the audit log and the session thread --"
LC_ALL=C grep -q 'stopped a git reset over a source tree' "$rigTmp/audit.log" 2>/dev/null && rigAudit=found || rigAudit=none
rigAssert "the audit log carries the stop"                "$rigAudit" "found"
LC_ALL=C grep -q "STOPPED: a git reset over a source tree ($rigSource)" "$rigTmp/ws/.local/agents/sessions/rig-session/session.chat" 2>/dev/null && rigChat=found || rigChat=none
rigAssert "the session thread carries the stop"           "$rigChat" "found"

echo "-- 6. the other two shell channels the harness owns, each refused by the same guard --"
## The guard first on PATH is what every channel meets: the guard folder is made from the include under test, and the two
## channels are run as they really run, one a tooling `execute` and one myx.common's own `lib/execShStdin`.
rigGuardBin="$rigTmp/ws/.local/agents/guard-bin"
env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
	bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.GitWrite.include" && AgentsToolsGitGuardMake "$MMDAPP/.local/agents/guard-bin"' 2>/dev/null || :
rigAssert "the guard git is written into the guard folder" "$( [ -x "$rigGuardBin/git" ] && printf written || printf none )" "written"
[ -x "$rigGuardBin/git" ] || rigRefuse "the guard git was not written, so the other two channels could not be judged"
rigMyxCommon="$( command -v myx.common 2>/dev/null )" || rigMyxCommon=""
[ -n "$rigMyxCommon" ] || rigMyxCommon="$( ls "$rigOrigin"/myx/myx.common/*/host/tarball/bin/myx.common 2>/dev/null | head -1 )"
## The channel call: the command run with the guard folder first on PATH, and a marker it would also write.
rigChannel(){ ## call name, refusal words, command text
	rm -f "$rigTmp/ws/mark.$1"
	( cd "$rigTmp/ws" && printf '%s' "$3 ; touch $rigTmp/ws/mark.$1" | env -i HOME="$rigTmp/home" PATH="$rigGuardBin:$rigPath" MMDAPP="$rigTmp/ws" \
		MDLT_ORIGIN="$rigOrigin" MDAT_GIT_SOURCE_ROOTS="$rigTmp/ws/source" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
	printf '%s:%s' "$( LC_ALL=C grep -c "$2" "$rigTmp/$1.out" 2>/dev/null || : )" "$( [ -f "$rigTmp/ws/mark.$1" ] && printf ran || printf none )"
}
rigAssert "execute: reset --hard is refused"   "$( rigChannel x1 'git write (reset)' "git -C $rigSource reset --hard HEAD" )" "1:none"
rigAssert "execute: git status still runs"     "$( rigChannel x2 'git write (' "git -C $rigSource status --porcelain" )" "0:ran"
if [ -n "$rigMyxCommon" ] ; then
	rigStdinChannel(){ ## call name, refusal words, command text
		rm -f "$rigTmp/ws/mark.$1"
		( cd "$rigTmp/ws" && printf '%s' "$3 ; touch $rigTmp/ws/mark.$1" | env -i HOME="$rigTmp/home" PATH="$rigGuardBin:$rigPath" \
			MDAT_GIT_SOURCE_ROOTS="$rigTmp/ws/source" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
			"$rigMyxCommon" lib/execShStdin ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
		printf '%s:%s' "$( LC_ALL=C grep -c "$2" "$rigTmp/$1.out" 2>/dev/null || : )" "$( [ -f "$rigTmp/ws/mark.$1" ] && printf ran || printf none )"
	}
	rigAssert "lib_execShStdin: reset --hard is refused" "$( rigStdinChannel s1 'git write (reset)' "git -C $rigSource reset --hard HEAD" )" "1:none"
	rigAssert "lib_execShStdin: git log still runs"     "$( rigStdinChannel s2 'git write (' "git -C $rigSource log --oneline -1" )" "0:ran"
else
	printf '  SKIP  lib_execShStdin: myx.common is not installed in this rig, so that channel is not judged here\n'
	rigFailCount=$(( rigFailCount + 1 ))
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH GIT WRITE GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a run can destroy a source tree with git, and nothing records the run that did" >&2
	echo "  fix:  the guard in sh-lib/common/AgentsTools.GitWrite.include, called by the Bash tool" >&2
	exit 1
fi
echo "BASH_GIT_WRITE_GUARD: OK ($rigPassCount assertions, offline)"
