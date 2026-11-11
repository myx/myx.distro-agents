#!/usr/bin/env bash
## AgentsStaleTreeRefusalCheck -- the content tools refuse `$MMDAPP/.local/myx/**` when `$MDLT_ORIGIN` points elsewhere
## (AgentsHarnessStaleTree in AgentsHarnessAccess.include, the Bash command text in AgentsHarnessToolsBash.include; the
## human-owner's task of 8 November): that tree is a stale copy of the tooling, never read, written, searched or run then.
## Guards: Read, Write, Edit, Grep and Glob on a path under the stale tree are refused with the text naming the tree and
## MDLT_ORIGIN, and nothing is written; a Bash command naming the tree, absolute or from the workspace, is refused and runs
## nothing; the same tools on a path beside it run; where MDLT_ORIGIN is the workspace's own `.local`, the rule does not
## apply (the function alone, with the gate's words stubbed).
## Section 5 holds the decision of 2026-11-11 on a Bash command's own text, and it is the section that decides it: the two
## relative forms are refused by the shared test's words from the workspace root, a comment naming the tree is refused there
## too because the gate cannot tell it from a path, and another workspace's path and either text from another folder run
## unchanged.
## Red: a harness that reads the stale tree fails `Read is refused`; one that runs the command fails `Bash runs nothing`;
## one that rewrites a relative form to a bare prefix fails `a bare relative path is refused`; one that rewrites a comment
## or another workspace's path fails `a comment naming the tree at the workspace root is refused` and `another workspace's
## path runs unchanged`; one that refuses beyond the workspace root fails the two rows whose cwd is `inside/`.
## Offline: a temp workspace of this check alone, removed at its end; the served harness from this origin; nothing is requested.
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
rigTmp="$( rigTempDir AgentsStaleTreeRefusalCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/myx/rig.pkg" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/inside" "$rigTmp/other-ws/.local/myx/rig.pkg" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
printf 'stale line\n' > "$rigTmp/ws/.local/myx/rig.pkg/stale.txt"
printf 'another workspace line\n' > "$rigTmp/other-ws/.local/myx/rig.pkg/theirs.txt"
printf 'live line\n' > "$rigTmp/inside/live.txt"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigStale="$rigTmp/ws/.local/myx/rig.pkg/stale.txt"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The read roots take the stale tree in, so only the rule refuses it, never the root set.
rigCall(){ ## tool, argument object, call name
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$3.out" 2> "$rigTmp/$3.err" || :
}
rigRefused(){ ## call name -- yes where the stale-tree refusal is in the result
	LC_ALL=C grep -q 'a stale copy of the tooling this workspace does not run from' "$rigTmp/$1.out" && printf yes || printf no
}

echo "-- 1. the file tools refuse the stale tree --"
rigCall Read "{\"path\":\"$rigStale\"}" read
rigAssert "Read is refused"                            "$( rigRefused read ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/read.out" )" "yes:0"
rigAssert "the refusal names MDLT_ORIGIN"              "$( LC_ALL=C grep -c "MDLT_ORIGIN is $rigOrigin" "$rigTmp/read.out" )" 1
rigCall Write "{\"path\":\"$rigStale\",\"content\":\"written\"}" write
rigAssert "Write is refused, nothing written"          "$( rigRefused write ):$( cat "$rigStale" )" "yes:stale line"
rigCall Edit "{\"path\":\"$rigStale\",\"old_string\":\"stale\",\"new_string\":\"edited\"}" edit
rigAssert "Edit is refused, nothing written"           "$( rigRefused edit ):$( cat "$rigStale" )" "yes:stale line"
rigCall Grep "{\"pattern\":\"stale\",\"path\":\"$rigTmp/ws/.local/myx\"}" grep
rigAssert "Grep is refused"                            "$( rigRefused grep ):$( LC_ALL=C grep -c 'stale.txt' "$rigTmp/grep.out" )" "yes:0"
rigCall Glob "{\"pattern\":\"*.txt\",\"path\":\"$rigTmp/ws/.local/myx\"}" glob
rigAssert "Glob is refused"                            "$( rigRefused glob ):$( LC_ALL=C grep -c 'stale.txt' "$rigTmp/glob.out" )" "yes:0"

echo "-- 2. Bash runs a command naming the tree on MDLT_ORIGIN's tree instead, and says so; the stale copy is never read --"
rigRewritten(){ ## call name -- yes where the result says the command was sent to the origin's tree
	LC_ALL=C grep -q "a stale copy of the tooling: it runs on $rigOrigin/myx" "$rigTmp/$1.out" && printf yes || printf no
}
rm -f "$rigTmp/inside/mark"
rigCall Bash "{\"command\":\"cat $rigStale ; touch $rigTmp/inside/mark\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" bash-abs
rigAssert "the absolute path runs on the origin's tree, the stale file unread" "$( rigRewritten bash-abs ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-abs.out" ):$( LC_ALL=C grep -c -F "$rigOrigin/myx/rig.pkg/stale.txt" "$rigTmp/bash-abs.out" )" "yes:0:1"
rigCall Bash "{\"command\":\"true\",\"cwd\":\"$rigTmp/ws/.local/myx/rig.pkg\",\"background\":false}" bash-cwd
rigAssert "a cwd in the tree is refused"               "$( rigRefused bash-cwd )" yes

echo "-- 3. the same tools beside the tree run --"
rigCall Read "{\"path\":\"$rigTmp/inside/live.txt\"}" read-live
rigAssert "Read beside it reads"                       "$( LC_ALL=C grep -c 'live line' "$rigTmp/read-live.out" )" 1
rigCall Bash "{\"command\":\"touch $rigTmp/inside/mark\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" bash-live
rigAssert "Bash beside it runs"                        "$( [ -e "$rigTmp/inside/mark" ] && printf ran || printf none )" ran

echo "-- 4. where the workspace runs from its own .local, the rule does not apply (the function alone) --"
rigAssert "the function stands down"                   "$( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigTmp/ws/.local" bash -c '
	harnessRoots="" harnessResolvedPath=""
	AgentsHarnessPathAllowed(){ harnessResolvedPath="$1" ; return 0 ; }
	. "$1" 2> /dev/null
	AgentsHarnessStaleTree Read "$2" && printf refused || printf allowed' _ "$rigHere/harness/AgentsHarnessAccess.include" "$rigStale" 2> /dev/null )" allowed
rigAssert "and stands down with no origin set"         "$( env -u MDLT_ORIGIN MMDAPP="$rigTmp/ws" bash -c '
	harnessRoots="" harnessResolvedPath=""
	AgentsHarnessPathAllowed(){ harnessResolvedPath="$1" ; return 0 ; }
	. "$1" 2> /dev/null
	AgentsHarnessStaleTree Read "$2" && printf refused || printf allowed' _ "$rigHere/harness/AgentsHarnessAccess.include" "$rigStale" 2> /dev/null )" allowed
rigAssert "and refuses with another origin"            "$( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" bash -c '
	harnessRoots="" harnessResolvedPath=""
	AgentsHarnessPathAllowed(){ harnessResolvedPath="$1" ; return 0 ; }
	. "$1" 2> /dev/null
	AgentsHarnessStaleTree Read "$2" > /dev/null && printf refused || printf allowed' _ "$rigHere/harness/AgentsHarnessAccess.include" "$rigStale" 2> /dev/null )" refused

echo "-- 5. from the workspace root a relative path and a comment are refused; another workspace's path and any text from another folder run --"
## Every row here reads the command's own output, so a row is green only where the command that ran is the command written.
rigStaleLines(){ ## call name -- how many stale-tree lines the result carries, of either wording
	LC_ALL=C grep -c 'a stale copy of the tooling' "$rigTmp/$1.out" 2> /dev/null || :
}
rigCall Bash "{\"command\":\"cat .local/myx/rig.pkg/stale.txt\",\"cwd\":\"$rigTmp/ws\",\"background\":false}" bash-rel-bare
rigAssert "a bare relative path is refused, and the stale file unread" "$( rigRefused bash-rel-bare ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-rel-bare.out" )" "yes:0"
rigCall Bash "{\"command\":\"cat ./.local/myx/rig.pkg/stale.txt\",\"cwd\":\"$rigTmp/ws\",\"background\":false}" bash-rel-dot
rigAssert "a ./-prefixed relative path is refused the same way" "$( rigRefused bash-rel-dot ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-rel-dot.out" )" "yes:0"
rigCall Bash "{\"command\":\"printf 'the comment row ran\\\\n' # see .local/myx/ for the tooling copy\",\"cwd\":\"$rigTmp/ws\",\"background\":false}" bash-comment
## From the workspace root the gate cannot tell a comment from a path, so the row expects the refusal: refusing costs one
## re-run, where rewriting rewords what a colleague wrote and leaves no trace (magic-developer's ordering, 2026-11-11).
rigAssert "a comment naming the tree at the workspace root is refused" "$( rigRefused bash-comment ):$( LC_ALL=C grep -c 'the comment row ran' "$rigTmp/bash-comment.out" )" "yes:0"
rigCall Bash "{\"command\":\"cat $rigTmp/other-ws/.local/myx/rig.pkg/theirs.txt\",\"cwd\":\"$rigTmp/ws\",\"background\":false}" bash-other-ws
rigAssert "another workspace's path runs unchanged" "$( rigStaleLines bash-other-ws ):$( LC_ALL=C grep -c 'another workspace line' "$rigTmp/bash-other-ws.out" )" "0:1"

## The same two texts from a folder outside the workspace root, where `.local/myx/` names something else entirely.
## The read is guarded: from `inside/` the path names nothing, and an unguarded failure ends the command under `-e` before
## its own line runs, which would read as a refusal.
rigCall Bash "{\"command\":\"cat .local/myx/rig.pkg/stale.txt || : ;\\nprintf 'the relative row ran\\\\n'\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" bash-rel-elsewhere
rigAssert "a relative path from another folder runs unchanged" "$( rigStaleLines bash-rel-elsewhere ):$( LC_ALL=C grep -c 'the relative row ran' "$rigTmp/bash-rel-elsewhere.out" )" "0:1"
rigCall Bash "{\"command\":\"printf 'the comment elsewhere ran\\\\n' # see .local/myx/ for the tooling copy\",\"cwd\":\"$rigTmp/inside\",\"background\":false}" bash-comment-elsewhere
rigAssert "a comment from another folder runs unchanged" "$( rigStaleLines bash-comment-elsewhere ):$( LC_ALL=C grep -c 'the comment elsewhere ran' "$rigTmp/bash-comment-elsewhere.out" )" "0:1"

## THE ROOT HAS MORE THAN ONE SPELLING, and each of them resolves to it: a call with no cwd, `.`, and a doubled slash.
## The arm reads the cwd the call gives, so each spelling reaches the same decision or the refusal is missed. A `$MMDAPP/.`
## cwd is absent here on purpose: the gate refuses it at AgentsHarnessPathAllowed before the arm is reached at all.
rigCall Bash "{\"command\":\"cat .local/myx/rig.pkg/stale.txt\",\"cwd\":\".\",\"background\":false}" bash-rel-cwd-dot
rigAssert "a relative path with the cwd spelled . is refused" "$( rigRefused bash-rel-cwd-dot ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-rel-cwd-dot.out" )" "yes:0"
rigCall Bash "{\"command\":\"cat .local/myx/rig.pkg/stale.txt\",\"background\":false}" bash-rel-cwd-none
rigAssert "a relative path with no cwd at all is refused" "$( rigRefused bash-rel-cwd-none ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-rel-cwd-none.out" )" "yes:0"
rigCall Bash "{\"command\":\"cat .local/myx/rig.pkg/stale.txt\",\"cwd\":\"$rigTmp/ws//\",\"background\":false}" bash-rel-cwd-doubled
rigAssert "a relative path with the cwd spelled $MMDAPP// is refused" "$( rigRefused bash-rel-cwd-doubled ):$( LC_ALL=C grep -c 'stale line' "$rigTmp/bash-rel-cwd-doubled.out" )" "yes:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ STALE TREE REFUSAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a run reads or writes the stale copy under .local/myx and takes it for the tooling it runs from" >&2
	echo "  fix:  AgentsHarnessStaleTree in sh-lib/harness/AgentsHarnessAccess.include, the command text in AgentsHarnessToolBashRun" >&2
	exit 1
fi
echo "STALE_TREE_REFUSAL: OK ($rigPassCount assertions, offline)"
