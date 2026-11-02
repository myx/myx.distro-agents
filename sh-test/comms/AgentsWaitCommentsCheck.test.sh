#!/usr/bin/env bash
## Check on the comments of the hot wait files (epic 20261026-refactorings, S28.7): AgentsTools.MemberWait.include, AgentsTools.MemberWaitRun.include and
## AgentsTools.MemberWaitSources.include of sh-lib/member keep one-line comments only, because the shell lexes every comment of them on every Wait. The
## longer text lives in the package's MAGIC.md. Held, run and not read:
##   1. THE COMMENTS. No file holds a block of two or more comment lines in a row (a line whose first non-blank character is #). The shebang line and the
##      editor marker line `# ^^^ for syntax checking in the editor only` at the head are not comments. A blank line ends a block.
##   2. THE FILES STILL RUN. Each file parses under bash, and a Wait over a file source still waits: it ran its rounds and ended TIMEOUT where the file
##      stays quiet, and ended RECEIVED, with the new line in its answer and before its bound, where the file changes. Removing a comment must not take code with it.
##   3. THE INSTRUMENT. The reader of blocks is run on files made by hand: a two-line block, a three-line block, a tab-indented block, one-line comments
##      between code, the head markers alone, a block after the head markers, and an empty file. A reader that cannot fail is no check.
## Red recipe: on the files before S28.7 (29, 38 and 25 blocks of two lines or more), section 1 fails for each file; sections 2 and 3 pass on them.
## Offline: the Wait runs in a workspace folder of the rig's own under $MMDAPP/.local/agents/scratch/sh-test; nothing is written to the package.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigMember="magic-tester"
rigFiles="AgentsTools.MemberWait.include AgentsTools.MemberWaitRun.include AgentsTools.MemberWaitSources.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || rigRefuse "no dispatcher at the origin this workspace resolves: $rigPackage"
for rigName in $rigFiles ; do
	[ -s "$rigPackage/sh-lib/member/$rigName" ] || rigRefuse "no such file, or an empty one, at the origin: $rigPackage/sh-lib/member/$rigName"
done

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitCommentsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] && echo "kept: $rigTmp" || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## THE READER. A block is two or more comment lines in a row; it is counted where its second line is met.
rigBlocks(){ ## file -- "<blocks> block(s), the first at line <n>" ; "0 block(s)" where there is none
	LC_ALL=C awk '
		FNR == 1 && $0 ~ /^#!/ { run = 0 ; next ; }
		FNR <= 2 && $0 == "# ^^^ for syntax checking in the editor only" { run = 0 ; next ; }
		$0 ~ /^[[:space:]]*#/ { run++ ; if ( run == 2 ) { blocks++ ; if ( first == 0 ) first = FNR - 1 ; } next ; }
		{ run = 0 ; }
		END { if ( blocks == 0 ) print "0 block(s)" ; else printf "%d block(s), the first at line %d\n", blocks, first ; }
	' "$1"
}

echo "-- 3. the instrument: the reader on files made by hand --"
printf '#!/usr/bin/env bash\n# ^^^ for syntax checking in the editor only\n\n## one\n## two\nx=1\n' > "$rigTmp/h.two"
printf '#!/usr/bin/env bash\nx=1\n## one\n## two\n## three\ny=2\n' > "$rigTmp/h.three"
printf '#!/usr/bin/env bash\nf(){\n\t## one\n\t## two\n\ttrue\n}\n' > "$rigTmp/h.tabs"
printf '#!/usr/bin/env bash\n# ^^^ for syntax checking in the editor only\n## one\nx=1\n## two\ny=2\n\t## three\n' > "$rigTmp/h.single"
printf '#!/usr/bin/env bash\n# ^^^ for syntax checking in the editor only\nx=1\n' > "$rigTmp/h.markers"
printf '#!/usr/bin/env bash\n# ^^^ for syntax checking in the editor only\n## one\n## two\nx=1\n' > "$rigTmp/h.aftermarkers"
printf '## one\n\n## two\n' > "$rigTmp/h.blankbetween"
: > "$rigTmp/h.empty"
rigAssert "reader: a two-line block is one block, at its first line" "$( rigBlocks "$rigTmp/h.two" )" "1 block(s), the first at line 4"
rigAssert "reader: a three-line block is one block" "$( rigBlocks "$rigTmp/h.three" )" "1 block(s), the first at line 3"
rigAssert "reader: a tab-indented block is a block" "$( rigBlocks "$rigTmp/h.tabs" )" "1 block(s), the first at line 3"
rigAssert "reader: one-line comments between code are none" "$( rigBlocks "$rigTmp/h.single" )" "0 block(s)"
rigAssert "reader: the head markers alone are none" "$( rigBlocks "$rigTmp/h.markers" )" "0 block(s)"
rigAssert "reader: a block straight after the head markers is one" "$( rigBlocks "$rigTmp/h.aftermarkers" )" "1 block(s), the first at line 3"
rigAssert "reader: a blank line ends a block" "$( rigBlocks "$rigTmp/h.blankbetween" )" "0 block(s)"
rigAssert "reader: an empty file is none" "$( rigBlocks "$rigTmp/h.empty" )" "0 block(s)"

echo "-- 1. the comments of the hot wait files --"
for rigName in $rigFiles ; do
	rigAssert "$rigName: one-line comments only" "$( rigBlocks "$rigPackage/sh-lib/member/$rigName" )" "0 block(s)"
done

echo "-- 2. the files still run --"
for rigName in $rigFiles ; do
	rigAssert "$rigName: parses under bash" "$( bash -n "$rigPackage/sh-lib/member/$rigName" > /dev/null 2>&1 && printf parses || printf 'does-not-parse' )" parses
done
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents" "$rigTmp/data" || exit 1
printf 'quiet\n' > "$rigTmp/quiet.txt"
rigWait(){ ## bound in seconds -- one Wait over the file source, its answer in $rigTmp/wait.out, its status in rigRc
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-source "file:$rigTmp/quiet.txt" --wait-timeout "$1" --wait-poll-interval 1 ) \
		> "$rigTmp/wait.out" 2> "$rigTmp/wait.err" < /dev/null ; rigRc=$?
}
rigWait 2
rigAssert "a Wait over a quiet file: ended 0 as TIMEOUT, and ran its rounds" \
	"$rigRc:$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/wait.out" ):$( LC_ALL=C grep -c 'poll round' "$rigTmp/wait.out" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "ran" : "did-not-run" ; }' )" "0:TIMEOUT:ran"
( sleep 2 ; printf 'changed\n' >> "$rigTmp/quiet.txt" ) &
rigWait 12
wait
rigAssert "a Wait over a file that changes: ended 0 as RECEIVED, with the new line in its answer" \
	"$rigRc:$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/wait.out" ):$( LC_ALL=C grep -c -x 'changed' "$rigTmp/wait.out" | LC_ALL=C tr -d ' ' )" "0:RECEIVED:1"
rigAssert "and it returned before its bound" \
	"$( LC_ALL=C sed -n 's/^# waited: \([0-9]*\)s of \([0-9]*\)s bound.*/\1 \2/p' "$rigTmp/wait.out" | LC_ALL=C awk '{ print ( $1 < $2 ) ? "before-bound" : "at-bound" ; }' )" before-bound

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT COMMENTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_COMMENTS: OK (%d assertions, offline, rig workspace only)\n' "$rigPassCount"
