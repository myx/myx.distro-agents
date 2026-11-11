#!/usr/bin/env bash
## AgentsMagicSectionUpsertCheck -- the one write to a MAGIC.md, by section (DistroAgentsKnowledge.fn.sh
## --magic-section-upsert, AgentsTools.InternOpMagicSection.include; epic S10.23).
## Guards: an existing section's body is replaced and every other line of the file stays; a section the file has
## not is added at its end; the file's mode is kept; a path that names no MAGIC.md, a link, a missing file, a body
## with a `## ` line, an empty body and a missing --section are each refused with nothing written.
## Red: a write that touches another section fails `the other sections stand`; a body with a heading accepted fails `a body that opens a section is refused`.
## Offline: a temp folder of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsMagicSectionUpsertCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigOp(){ ## arguments -- stdout, with stderr in rig.err and rc in rig.rc
	( cd "$rigTmp" && bash "$rigFn" "$@" ) > "$rigTmp/rig.out" 2> "$rigTmp/rig.err" ; printf '%s' "$?" > "$rigTmp/rig.rc" ; cat "$rigTmp/rig.out"
}
rigMagic="$rigTmp/proj/MAGIC.md"
mkdir -p "$rigTmp/proj"
printf '# rig project\n\nThe title paragraph.\n\n## Purpose\n\nOld purpose line one.\nOld purpose line two.\n\n## Layout\n\n- a folder\n' > "$rigMagic"
chmod 640 "$rigMagic"

echo "-- 1. an existing section's body is replaced, the rest stands --"
rigAssert "the update is said"                   "$( rigOp --magic-section-upsert "$rigMagic" --section Purpose --text 'New purpose.' )" "MAGIC-SECTION: updated Purpose in $rigMagic"
rigAssert "the new body stands under its heading" "$( LC_ALL=C awk '/^## Purpose$/ { p = 1 ; next } /^## / { p = 0 } p && NF' "$rigMagic" | LC_ALL=C tr '\n' '|' )" "New purpose.|"
rigAssert "the other sections stand"             "$( LC_ALL=C grep -c -x -e '# rig project' -e 'The title paragraph.' -e '## Layout' -e '- a folder' "$rigMagic" ):$( LC_ALL=C grep -c 'Old purpose' "$rigMagic" )" "4:0"
rigAssert "the mode is kept"                     "$( LC_ALL=C stat -f '%Lp' "$rigMagic" 2> /dev/null || LC_ALL=C stat -c '%a' "$rigMagic" )" "640"

echo "-- 2. a section the file has not is added at the end, from stdin --"
rigAssert "the add is said"                      "$( printf 'Run the checks.\nThen hand back.\n' | rigOp --magic-section-upsert "$rigMagic" --section 'How to work' --from-stdin )" "MAGIC-SECTION: added How to work in $rigMagic"
rigAssert "it stands last, whole"                "$( tail -n 4 "$rigMagic" | LC_ALL=C tr '\n' '|' )" "## How to work||Run the checks.|Then hand back.|"
rigAssert "the earlier sections stand"           "$( LC_ALL=C grep -c -x -e '## Purpose' -e 'New purpose.' -e '## Layout' -e '- a folder' "$rigMagic" )" "4"

echo "-- 3. refusals write nothing --"
rigBefore="$( cat "$rigMagic" )"
rigOp --magic-section-upsert "$rigTmp/proj/README.md" --section Purpose --text x > /dev/null
rigAssert "a path that names no MAGIC.md"        "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'names no MAGIC.md' "$rigTmp/rig.err" )" "1:1"
rigOp --magic-section-upsert "$rigTmp/none/MAGIC.md" --section Purpose --text x > /dev/null
rigAssert "a missing file"                       "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'no such file' "$rigTmp/rig.err" )" "1:1"
ln -s "$rigMagic" "$rigTmp/link.MAGIC.md" 2> /dev/null ; mkdir -p "$rigTmp/linked" ; ln -s "$rigMagic" "$rigTmp/linked/MAGIC.md"
rigOp --magic-section-upsert "$rigTmp/linked/MAGIC.md" --section Purpose --text x > /dev/null
rigAssert "a link"                               "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'is a link' "$rigTmp/rig.err" )" "1:1"
rigOp --magic-section-upsert "$rigMagic" --section Purpose --text $'Text\n## Another\nmore' > /dev/null
rigAssert "a body that opens a section is refused" "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'opens a section' "$rigTmp/rig.err" )" "1:1"
rigOp --magic-section-upsert "$rigMagic" --section Purpose --text '   ' > /dev/null
rigAssert "an empty body"                        "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'body is empty' "$rigTmp/rig.err" )" "1:1"
rigOp --magic-section-upsert "$rigMagic" --text x > /dev/null
rigAssert "no --section"                         "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'syntax is' "$rigTmp/rig.err" )" "1:1"
rigAssert "and the file is as it was"            "$( [ "$( cat "$rigMagic" )" = "$rigBefore" ] && printf same || printf changed )" same
rigAssert "no temp is left beside it"            "$( ls "$rigTmp/proj" | LC_ALL=C tr '\n' ' ' )" "MAGIC.md "

echo "-- 4. in a git checkout, a file behind its upstream is not edited (S12.28) --"
## An upstream with one more commit on MAGIC.md than the clone has fetched... the clone fetches it, so HEAD is behind @{u}.
rigUp="$rigTmp/upstream" ; rigClone="$rigTmp/clone"
git init -q "$rigUp" && ( cd "$rigUp" && git config user.email rig@rig && git config user.name rig && printf '# up\n\n## Purpose\n\nOne.\n' > MAGIC.md && git add MAGIC.md && git commit -q -m one ) 2> /dev/null
git clone -q "$rigUp" "$rigClone" 2> /dev/null && ( cd "$rigClone" && git config user.email rig@rig && git config user.name rig ) 2> /dev/null
( cd "$rigUp" && printf '# up\n\n## Purpose\n\nTwo.\n' > MAGIC.md && git commit -q -am two ) 2> /dev/null
( cd "$rigClone" && git fetch -q ) 2> /dev/null
rigBefore4="$( cat "$rigClone/MAGIC.md" )"
rigOp --magic-section-upsert "$rigClone/MAGIC.md" --section Purpose --text 'Three.' > /dev/null
rigAssert "a file behind its upstream is refused, with pull named" "$( cat "$rigTmp/rig.rc" ):$( LC_ALL=C grep -c 'behind its upstream by 1 commit' "$rigTmp/rig.err" ):$( LC_ALL=C grep -c 'pull the checkout first' "$rigTmp/rig.err" )" "1:1:1"
rigAssert "and nothing was written"                       "$( [ "$( cat "$rigClone/MAGIC.md" )" = "$rigBefore4" ] && printf same || printf changed )" same
( cd "$rigClone" && git pull -q --ff-only ) 2> /dev/null
rigAssert "once current, the edit lands"                   "$( rigOp --magic-section-upsert "$rigClone/MAGIC.md" --section Purpose --text 'Three.' )" "MAGIC-SECTION: updated Purpose in $rigClone/MAGIC.md"
( cd "$rigUp" && printf '# up\n\n## Purpose\n\nFour.\n' > MAGIC.md && git commit -q -am four ) 2> /dev/null
( cd "$rigClone" && git fetch -q ) 2> /dev/null
rigAssert "a file with a local change is edited, behind or not: it is the member's own work" "$( rigOp --magic-section-upsert "$rigClone/MAGIC.md" --section Purpose --text 'Five.' )" "MAGIC-SECTION: updated Purpose in $rigClone/MAGIC.md"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MAGIC SECTION UPSERT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a write to a MAGIC.md may touch more than its one section, or refuse nothing" >&2
	echo "  fix:  AgentsToolsMagicSectionUpsert in sh-lib/team-data/AgentsTools.InternOpMagicSection.include" >&2
	exit 1
fi
echo "MAGIC_SECTION_UPSERT: OK ($rigPass assertions, offline)"
