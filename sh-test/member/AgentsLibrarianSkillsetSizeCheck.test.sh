#!/usr/bin/env bash
## Behavioural check on `AgentLibrarianTools.fn.sh --skillset-size [<member>...]` (S7.2): the instrument that makes "the skillset shrinks"
## measurable, run rather than read, against a rig skillset built here. Held: one `file` row for each file of each registered member
## (kind, member, path below the member's folder, lines, bytes), one `member` row for each member (its lines and bytes summed), one `total`
## row; the lines of a file that is not text read `-` and count for no line, its bytes count; a file or a folder whose name starts with a dot
## is no part of the skillset; members named limit the rows to them, and the total is theirs alone; a name that is no registered member is
## refused, nothing printed; the rows are in order (member, then path, in the C order). Offline: the rig's skillset is its own tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/AgentLibrarianTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsLibrarianSkillsetSizeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local" "$rigSkills/rig-alpha/reference" "$rigSkills/rig-alpha/.hidden" "$rigSkills/rig-beta" "$rigSkills/trash"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
printf 'one\ntwo\nthree\n' > "$rigSkills/rig-alpha/rig-alpha.basic.md"
printf 'a\nb\n' > "$rigSkills/rig-alpha/reference/note.md"
printf '\000\001\002\003\004' > "$rigSkills/rig-alpha/mark.png"
printf 'secret\nlines\n' > "$rigSkills/rig-alpha/.hidden/h.md"
printf 'x\n' > "$rigSkills/rig-alpha/.dotfile"
printf 'only\n' > "$rigSkills/rig-beta/rig-beta.basic.md"
printf 'dropped\n' > "$rigSkills/trash/old.md"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRun(){ ## arguments... -> stdout in $rigTmp/out, stderr in $rigTmp/err, status in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigRows(){ LC_ALL=C grep -v '^SystemContext' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr '\n' '|' ; }

rigRun --skillset-size
rigAssert "every file, every member and the total, in order; binary lines read -, dot names and the trash folder are out" "$rigRc $( rigRows )" \
	"0 file rig-alpha mark.png - 5|file rig-alpha reference/note.md 2 4|file rig-alpha rig-alpha.basic.md 3 14|member rig-alpha - 5 23|file rig-beta rig-beta.basic.md 1 5|member rig-beta - 1 5|total - - 6 28|"
rigRun --skillset-size rig-beta
rigAssert "a member named limits the rows to it, and the total is its alone" "$rigRc $( rigRows )" "0 file rig-beta rig-beta.basic.md 1 5|member rig-beta - 1 5|total - - 1 5|"
rigRun --skillset-size rig-beta rig-alpha
rigAssert "two members named, in their own order of name" "$rigRc $( rigRows | LC_ALL=C cut -c1-40 )" "0 file rig-alpha mark.png - 5|file rig-alp"
rigRun --skillset-size rig-nobody
rigAssert "a name that is no registered member: refused in one line, rc 1, nothing printed" "$rigRc $( rigRows ) $( LC_ALL=C grep -c 'rig-nobody' "$rigTmp/err" )" "1  1"
rigRun --skillset-size '../x'
rigAssert "a name that is no bare name: refused" "$rigRc $( rigRows )" "1 "

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ LIBRARIAN SKILLSET SIZE CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "LIBRARIAN_SKILLSET_SIZE: OK ($rigPasses assertions, offline)"
