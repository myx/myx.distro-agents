#!/usr/bin/env bash
## Behavioural check on the rule that a sandbox is no door into source (epic S23.11): no link in a sandbox, a session folder or a
## test tree reaches a source tree. Run rather than read, offline: no deploy, no ssh, no host. Held:
##   1. the scan finds each way a link reaches a source root: an absolute link to a file, to a folder and to a file that is not there,
##      a relative link with a `..`, one deep in a subfolder, one to a second root, and a chain of two links
##   2. it finds nothing in a link that stays in the sandbox or leaves to a place that is no source, and says rc 0
##   3. a folder that is not there holds none and is no fault
##   4. a sandbox tree is a sandbox, a session folder or a test tree. The roots are this workspace's source and installed packages, the
##      origin's packages, and the source of each workspace beside it, and never one that lies in a sandbox tree
##   5. a link from a sandbox into source is refused, by the function the installer makes its links with, by the guard `ln` a run
##      puts first on its PATH, by the MCP execute operation that carries it and by the test runner that carries it into every
##      test, for a symbolic and for a hard link, absolute or relative. A link that stays in the sandbox is made.
##   6. live: no link in this workspace's sandboxes, session folders and test trees reaches a source tree
## The links this check makes stay inside its own throwaway rig. They are the proof that the scan is not blind, and none points into a
## real source tree. Red before: the scan did not exist, and a sandbox of an earlier run held links into the origin.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/sh-lib/session/AgentsTools.SandboxLinks.include" ] || rigRefuse "the scan is not at the origin this workspace resolves: $rigHere/sh-lib/session/AgentsTools.SandboxLinks.include"
. "$rigHere/sh-lib/session/AgentsTools.SandboxLinks.include" || exit 1
. "$rigHere/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSandboxLinkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigNames(){ ## -- the leaf names of the links on stdin, in one line
	LC_ALL=C awk -F'\t' '{ n = split( $1, p, "/" ) ; print p[n] }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}

echo "-- the rule held: a link is refused only where its slot lies in a sandbox, a session folder or a test tree AND its target resolves inside a source tree. Any other link is made, a handle link into the session's own .run folder among them --"
echo "-- the rig: a source root, a second root, a sandbox and a place that is no source --"
mkdir -p "$rigTmp/source/pkg" "$rigTmp/installed/pkg" "$rigTmp/sandbox/sub/deep" "$rigTmp/sandbox/.run.abc" "$rigTmp/elsewhere" "$rigTmp/clean"
: > "$rigTmp/source/pkg/file" ; : > "$rigTmp/installed/pkg/file" ; : > "$rigTmp/sandbox/real.txt" ; : > "$rigTmp/sandbox/.run.abc/out" ; : > "$rigTmp/elsewhere/file"
rigRoots="$rigTmp/source"$'\n'"$rigTmp/installed"

echo "-- 1. each way a link reaches a source root is found --"
ln -s "$rigTmp/source/pkg/file" "$rigTmp/sandbox/abs-file"
ln -s "$rigTmp/source/pkg" "$rigTmp/sandbox/abs-folder"
ln -s "$rigTmp/source/pkg/gone" "$rigTmp/sandbox/abs-gone"
ln -s ../source/pkg/file "$rigTmp/sandbox/rel-dotdot"
ln -s ../../../source/pkg "$rigTmp/sandbox/sub/deep/rel-deep"
ln -s "$rigTmp/installed/pkg/file" "$rigTmp/sandbox/second-root"
ln -s "$rigTmp/source/pkg/file" "$rigTmp/sandbox/hop-one"
ln -s "$rigTmp/sandbox/hop-one" "$rigTmp/sandbox/hop-two"
rigFound="$( AgentsToolsSandboxLinkScan "$rigRoots" "$rigTmp/sandbox" )" ; rigRc=$?
rigAssert "the scan finds the eight links that reach a root, by name" "$( printf '%s\n' "$rigFound" | rigNames )" "abs-file abs-folder abs-gone hop-one hop-two rel-deep rel-dotdot second-root"
rigAssert "and says rc 1" "$rigRc" 1
rigAssert "a finding holds the link, the target as written and the resolved target" "$( printf '%s\n' "$rigFound" | LC_ALL=C awk -F'\t' -v want="$rigTmp/source/pkg/file" '$1 ~ /\/abs-file$/ { print NF " " ( $2 == want ) " " ( $3 == want ) }' )" "3 1 1"
rigAssert "a link reaching the root through another link names the real file it ends at" "$( printf '%s\n' "$rigFound" | LC_ALL=C awk -F'\t' -v want="$rigTmp/source/pkg/file" '$1 ~ /\/hop-two$/ { print ( $3 == want ) ? "ends-at-file" : $3 }' )" "ends-at-file"

echo "-- 2. a link that stays in the sandbox, or leaves to a place that is no source, is no finding --"
ln -s "$rigTmp/clean/real.txt" "$rigTmp/clean/abs-inside"
ln -s .run.abc/out "$rigTmp/clean/handle.out"
ln -s "$rigTmp/elsewhere/file" "$rigTmp/clean/abs-elsewhere"
ln -s ../elsewhere/file "$rigTmp/clean/rel-elsewhere"
ln -s "$rigTmp/clean/not-there" "$rigTmp/clean/dangling-inside"
rigClean="$( AgentsToolsSandboxLinkScan "$rigRoots" "$rigTmp/clean" )" ; rigRc=$?
rigAssert "the five links of the clean folder give no finding" "[$rigClean]" "[]"
rigAssert "and say rc 0" "$rigRc" 0

echo "-- 3. a folder that is not there holds none --"
rigAbsent="$( AgentsToolsSandboxLinkScan "$rigRoots" "$rigTmp/absent" )" ; rigRc=$?
rigAssert "no finding and rc 0" "[$rigAbsent] $rigRc" "[] 0"

echo "-- 4. what is a sandbox tree, and what is a source root --"
rigAssert "this rig, a session folder and a sandbox are sandbox trees" "$( AgentsToolsSandboxTree "$rigTmp" && printf yes || printf no ) $( AgentsToolsSandboxTree "$MMDAPP/.local/agents/sessions" && printf yes || printf no ) $( AgentsToolsSandboxTree "$MMDAPP/.local/agents/spawned/x/output" && printf yes || printf no ) $( AgentsToolsSandboxTree "$MMDAPP/.local/temp" && printf yes || printf no )" "yes yes yes yes"
rigAssert "the workspace's source and its vendor folder are not" "$( AgentsToolsSandboxTree "$MMDAPP/source" && printf yes || printf no ) $( AgentsToolsSandboxTree "$MMDAPP/.claude" && printf yes || printf no )" "no no"
mkdir -p "$rigTmp/ws/source" "$rigTmp/ws/.local/myx" "$rigTmp/origin/myx" "$rigTmp/console/myx" "$rigTmp/beside/source"
rigAssert "a rig's own source, packages and origin are no source root, since the rig lies in a sandbox tree" "[$( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigTmp/origin" MDLT_CONSOLE_ORIGIN="$rigTmp/console" AgentsToolsSourceRoots )]" "[]"
rigRealPackages="$( cd -P "$MDLT_ORIGIN/myx" && pwd -P )"
rigAssert "the tooling origin's packages are a root unless the origin itself lies in a sandbox tree" "$( AgentsToolsSourceRoots | LC_ALL=C grep -c -x -F "$rigRealPackages" || : )" "$( AgentsToolsSandboxTree "$rigRealPackages" && printf 0 || printf 1 )"
rigAssert "the workspace's own source is a root" "$( AgentsToolsSourceRoots | LC_ALL=C grep -c -x -F "$( cd -P "$MMDAPP/source" 2> /dev/null && pwd -P )" || : )" "$( [ -d "$MMDAPP/source" ] && printf 1 || printf 0 )"
rigAssert "a workspace that holds the origin in .local gives its packages and never .local itself" "$( MMDAPP="$MMDAPP" MDLT_ORIGIN="$MMDAPP/.local" AgentsToolsSourceRoots | LC_ALL=C grep -c -x -F "$( cd -P "$MMDAPP/.local" && pwd -P )" || : )" 0

echo "-- 5. a link from a sandbox into source is refused by the guard ln and comes out as a copy from the installer's function; one that stays in the sandbox is made --"
rigReal="" rigRealFile=""
while IFS= read -r rigCandidate ; do
	[ -n "$rigCandidate" ] || continue
	rigRealFile="$( find "$rigCandidate" -maxdepth 3 -type f -size -100k 2> /dev/null | head -1 )"
	[ -z "$rigRealFile" ] || { rigReal="$rigCandidate" ; break ; }
done <<< "$( AgentsToolsSourceRoots )"
rigAssert "control: a real source root and a real file in it are there to aim at" "$( [ -d "$rigReal" ] && [ -f "$rigRealFile" ] && printf some || printf none )" some
mkdir -p "$rigTmp/guard"
rigDepth="$( printf '%s' "$rigTmp/guard" | LC_ALL=C awk -F/ '{ print NF - 1 }' )"
rigUp="$( i=0 ; while [ "$i" -lt "$rigDepth" ] ; do printf '../' ; i=$(( i + 1 )) ; done )"
## The roots below are a rig's own, so that a copy of a whole folder is small: the function reads them through AgentsToolsSourceRoots.
mkdir -p "$rigTmp/fake/pkg" ; printf 'one\n' > "$rigTmp/fake/pkg/file"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake "$rigTmp/fake/pkg" "$rigTmp/guard/abs-dir" ) 2> "$rigTmp/guard.err" ; rigRc=$?
rigAssert "AgentsToolsLinkMake, where the target folder is in a source root, puts a real copy in the slot and no link, and says so" "$rigRc $( [ -L "$rigTmp/guard/abs-dir" ] && printf link || printf real ) $( cat "$rigTmp/guard/abs-dir/file" 2> /dev/null ) $( LC_ALL=C grep -c 'is a copy of' "$rigTmp/guard.err" )" "0 real one 1"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake ../fake/pkg/file "$rigTmp/guard/rel-file" ) 2> /dev/null ; rigRc=$?
rigAssert "...and for a relative target that climbs to a file of it" "$rigRc $( [ -L "$rigTmp/guard/rel-file" ] && printf link || printf real ) $( cat "$rigTmp/guard/rel-file" 2> /dev/null )" "0 real one"
ln -s "$rigTmp/fake/pkg/file" "$rigTmp/guard/hop-src"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake "$rigTmp/guard/hop-src" "$rigTmp/guard/hop-copy" ) 2> /dev/null ; rigRc=$?
rigAssert "...and for a target that reaches the root through a link: the copy is of the file it ends at" "$rigRc $( [ -L "$rigTmp/guard/hop-copy" ] && printf link || printf real ) $( cat "$rigTmp/guard/hop-copy" 2> /dev/null )" "0 real one"
ln -s "$rigTmp/elsewhere/file" "$rigTmp/guard/was-link"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake "$rigTmp/fake/pkg/file" "$rigTmp/guard/was-link" ) 2> /dev/null ; rigRc=$?
rigAssert "...and a link already in the slot is replaced by the copy" "$rigRc $( [ -L "$rigTmp/guard/was-link" ] && printf link || printf real ) $( cat "$rigTmp/guard/was-link" 2> /dev/null )" "0 real one"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake "$rigTmp/fake/pkg/file" "$rigTmp/guard/abs-dir" ) 2> /dev/null ; rigRc=$?
rigAssert "a folder in the slot is never replaced" "$rigRc $( cat "$rigTmp/guard/abs-dir/file" 2> /dev/null )" "1 one"
( AgentsToolsSourceRoots(){ printf '%s\n' "$rigTmp/fake" ; } ; AgentsToolsLinkMake "$rigTmp/fake/pkg/gone" "$rigTmp/guard/no-copy" ) 2> /dev/null ; rigRc=$?
rigAssert "a target in the root that is not there gives rc 1 and nothing in the slot" "$rigRc $( [ -e "$rigTmp/guard/no-copy" ] || [ -L "$rigTmp/guard/no-copy" ] && printf made || printf none )" "1 none"
AgentsToolsLinkMake "$rigRealFile" "$rigTmp/guard/real-file" 2> /dev/null ; rigRc=$?
rigAssert "against the real roots, a file of real source comes out as a copy, no link" "$rigRc $( [ -L "$rigTmp/guard/real-file" ] && printf link || printf real ) $( cmp -s "$rigRealFile" "$rigTmp/guard/real-file" && printf same || printf differs )" "0 real same"
AgentsToolsLinkMake "$rigTmp/elsewhere/file" "$rigTmp/guard/ok" ; rigRc=$?
rigAssert "a target inside the rig is linked" "$rigRc $( readlink "$rigTmp/guard/ok" )" "0 $rigTmp/elsewhere/file"
AgentsToolsLinkMake "$rigTmp/elsewhere/file2" "$rigTmp/guard/ok" ; rigRc=$?
rigAssert "and an existing link of the slot is replaced" "$rigRc $( readlink "$rigTmp/guard/ok" )" "0 $rigTmp/elsewhere/file2"
AgentsToolsLinkMake .run.abc/out "$rigTmp/guard/handle.out" ; rigRc=$?
rigAssert "a handle link of a session into its own hidden .run folder is no refusal: it is made" "$rigRc $( readlink "$rigTmp/guard/handle.out" )" "0 .run.abc/out"
( AgentsToolsLnGuard -s "$rigReal" "$rigTmp/guard/g1" ) 2> /dev/null ; rigRc=$?
rigAssert "the guard refuses ln -s to source" "$rigRc $( [ -L "$rigTmp/guard/g1" ] && printf made || printf none )" "1 none"
( AgentsToolsLnGuard -sfn "$rigReal" "$rigTmp/guard" ) 2> /dev/null ; rigRc=$?
rigAssert "...and ln -sfn into a folder, where the slot is named by the target's leaf" "$rigRc $( [ -L "$rigTmp/guard/${rigReal##*/}" ] && printf made || printf none )" "1 none"
( AgentsToolsLnGuard "$rigRealFile" "$rigTmp/guard/h1" ) 2> /dev/null ; rigRc=$?
rigAssert "...and a hard link to a file of source, which would let a write of the run reach it" "$rigRc $( [ -e "$rigTmp/guard/h1" ] && printf made || printf none )" "1 none"
( AgentsToolsLnGuard -s "$rigTmp/elsewhere/file" "$rigTmp/guard/g2" ) ; rigRc=$?
rigAssert "the guard runs ln where the target stays in the rig" "$rigRc $( readlink "$rigTmp/guard/g2" )" "0 $rigTmp/elsewhere/file"
AgentsToolsLnGuardMake "$rigTmp/guardbin" || rigRefuse "the guard ln could not be written"
rigAssert "the guard folder's ln is executable" "$( [ -x "$rigTmp/guardbin/ln" ] && printf yes || printf no )" yes
( PATH="$rigTmp/guardbin:$PATH" ; ln -s "$rigReal" "$rigTmp/guard/p1" ) 2> /dev/null ; rigRc=$?
rigAssert "put first on PATH, a plain ln of a rig script is refused for source" "$rigRc $( [ -L "$rigTmp/guard/p1" ] && printf made || printf none )" "1 none"
( PATH="$rigTmp/guardbin:$PATH" ; ln -s "$rigTmp/elsewhere/file" "$rigTmp/guard/p2" ) ; rigRc=$?
rigAssert "...and made for a target in the rig" "$rigRc $( readlink "$rigTmp/guard/p2" )" "0 $rigTmp/elsewhere/file"

echo "-- the execute tool of the MCP server, which a member's shell commands run through, carries the guard --"
mkdir -p "$rigTmp/home" "$rigTmp/ws/.local"
rigExec(){ ## script -- runs it through the execute operation in the rig's workspace; rc in rigRc, stderr in $rigTmp/exec.err
	rigRc=0
	printf '%s\n' "$1" | env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_CONSOLE_ORIGIN="${MDLT_CONSOLE_ORIGIN:-}" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute > "$rigTmp/exec.out" 2> "$rigTmp/exec.err" || rigRc=$?
}
## The console origin this run resolves is the root its own guard reads, so the rig aims at that one. A packages
## folder is not one, and no root sorts into this choice.
rigConsole="$MDLT_ORIGIN"
if [ ! -d "$rigConsole/myx" ] ; then
	rigConsole="$( AgentsToolsSourceRoots | LC_ALL=C grep '/myx$' | head -1 )" ; rigConsole="${rigConsole%/myx}"
fi
rigAssert "control: a source root named by its console origin is there for the rig to aim at" "$( [ -d "$rigConsole/myx" ] && printf some || printf none )" some
rigExec "ln -s '$rigConsole/myx' '$rigTmp/guard/x1'"
rigAssert "a command that links a sandbox into source is refused, rc 1, with the refusal said, and nothing is made" "$rigRc $( LC_ALL=C grep -c 'refusing a link from a sandbox into source' "$rigTmp/exec.err" ) $( [ -L "$rigTmp/guard/x1" ] && printf made || printf none )" "1 1 none"
rigExec "ln -s '$rigTmp/elsewhere/file' '$rigTmp/guard/x2'"
rigAssert "and one that links inside the sandbox is made" "$rigRc $( readlink "$rigTmp/guard/x2" )" "0 $rigTmp/elsewhere/file"

echo "-- the runner puts the guard ln first on the PATH of every test it runs --"
rigRunPkg="$rigTmp/rws/.local/temp/rig-origin/source/myx/myx.distro-agents"
mkdir -p "$rigRunPkg/sh-test/check-fixtures" "$rigRunPkg/sh-lib/session" "$rigTmp/rhome" "$rigTmp/rmembers" "$rigTmp/rdata"
cp "$rigHere/sh-test/AgentsRunTests.sh" "$rigRunPkg/sh-test/AgentsRunTests.sh"
cp "$rigHere/sh-test/check-fixtures"/runner-*.py "$rigRunPkg/sh-test/check-fixtures/"
cp "$rigHere/sh-lib/session/AgentsTools.SandboxLinks.include" "$rigRunPkg/sh-lib/session/"
cat > "$rigRunPkg/sh-test/RigLn.test.sh" <<'RIGLN'
#!/usr/bin/env bash
{ printf 'LN=%s\n' "$( command -v ln )" ; ln -s "$RIG_AIM" "$RIG_SHARED/rig-slot" 2> /dev/null ; printf 'RC=%s\n' "$?" ; ln -s "$RIG_SHARED/elsewhere" "$RIG_SHARED/rig-ok" ; printf 'OKRC=%s\n' "$?" ; } > "$RIG_SHARED/ln.found"
echo "RIG_TINY: OK"
RIGLN
( cd "$rigTmp/rws" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/rhome" PATH="$PATH" MMDAPP="$rigTmp/rws" MDLT_ORIGIN="$rigTmp/rws/.local/temp/rig-origin/source" MDLT_CONSOLE_ORIGIN="$rigConsole" \
	MYXROOT="${MYXROOT:-}" MDAT_SKILLSET_ROOT="$rigTmp/rmembers" MDAT_DATA_ROOT="$rigTmp/rdata" RIG_SHARED="$rigTmp" RIG_AIM="$rigConsole/myx" \
	bash "$rigRunPkg/sh-test/AgentsRunTests.sh" -w 1 -t 120 RigLn ) > "$rigTmp/runner.out" 2>&1 ; rigRc=$?
rigAssert "the control: the runner ran the tiny test, and it passed" "$rigRc $( LC_ALL=C grep -c '^PASS  RigLn ' "$rigTmp/runner.out" || : )" "0 1"
rigLnFound="$( LC_ALL=C sed -n 's/^LN=//p' "$rigTmp/ln.found" )"
case "$rigLnFound" in
	("$rigTmp/rws/.local/temp/mdat-tests/"*"/guard-bin/ln") rigLnWhich=guard ;;
	(*) rigLnWhich="$rigLnFound" ;;
esac
rigAssert "the ln the test finds is the guard of that run, in the run's own folder" "$rigLnWhich" guard
rigAssert "it refused a link into source, and made nothing" "$( LC_ALL=C sed -n 's/^RC=//p' "$rigTmp/ln.found" ) $( [ -L "$rigTmp/rig-slot" ] && printf made || printf none )" "1 none"
rigAssert "and made the link that stays in the rig" "$( LC_ALL=C sed -n 's/^OKRC=//p' "$rigTmp/ln.found" ) $( [ -L "$rigTmp/rig-ok" ] && printf made || printf none )" "0 made"

echo "-- 6. live: this workspace's sandboxes, session folders and test trees --"
rigLiveRoots="$( AgentsToolsSourceRoots )"
rigAssert "control: the live roots are not empty, so the scan below has something to find" "$( [ -n "$rigLiveRoots" ] && printf some || printf none )" some
rigLive="$( AgentsToolsSandboxLinkScan "$rigLiveRoots" "$MMDAPP/.local/agents/spawned" "$MMDAPP/.local/agents/sessions" "$MMDAPP/.local/agents/scratch" "$MMDAPP/.local/temp" "$MMDAPP/output" )" || :
rigAssert "no link of a sandbox, a session folder or a test tree reaches a source tree" "$( printf '%s' "$rigLive" | LC_ALL=C awk -F'\t' 'NF { n++ ; if ( n <= 5 ) s = s $1 " -> " $3 " ; " } END { print n + 0 " link(s) " s }' )" "0 link(s) "

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SANDBOX LINK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SANDBOX_LINK: OK (%d assertions, offline)\n' "$rigPasses"
