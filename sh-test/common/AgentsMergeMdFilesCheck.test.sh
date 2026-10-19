#!/usr/bin/env bash
## Behavioural check on the markdown nesting engine (F2.1 of the refactorings epic):
## `--intern-merge-md-files [--do-index] [--section-prefix <N>] [--section-limit <N>]
##   [--mixin [--section-{exclude|include} "<glob>" ...] <file-name> "<result-section-name>"]...`
## Every file enters by --mixin, which names the section it becomes; there is no plain file argument. The default
## section prefix is 1 (`#`), the default limit 3 levels; a section deeper than the limit is replaced by a reference to
## its file; --do-index puts a Contents section first, at the prefix level, a nested list of the captions to the capped
## depth; a merged file's heading levels are reworked to fit, never kept blindly.
## Held:
##   1. two mixins: each a section of its own name at the prefix level, its file's sections one level under it
##   2. --section-prefix 2: the mixin sections at `##`, theirs at `###`
##   3. a file whose headings skip levels is reworked: its sections come one level under its mixin, whatever they were
##   4. the limit: by default a section at level 4 of the result is replaced by one line naming its file and its
##      heading; with --section-limit 2, so is one at level 3
##   4b. a `#` line inside a code fence is no heading: neither reworked nor counted
##   5. --do-index: a section titled Contents first, at the prefix level, listing the captions nested, to the capped depth
##   6. --section-exclude drops the sections whose caption matches; --section-include keeps only those
##   7. a plain file argument is refused, naming --mixin, and nothing is printed
##   8. a consumer: a default skill load (`skill`, no file) serves one merged bundle instead of the SKILL.md: the member's
##      basic and armed files, then the team's, each its own section, in that order, and no SKILL.md content
##   8b. a skill whose SKILL.md declares `status: reference-only` is served as is, its SKILL.md only
## Red before F2.1: no such operation (every case fails).
## Offline: files of this rig's own temp tree; the Skill read is a served call in a rig workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigHarness" ] || rigRefuse "the tool or the harness is not at the origin this workspace resolves: $MDLT_ORIGIN"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsMergeMdFilesCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/md" "$rigTmp/ws/.local/.agents" "$rigTmp/home"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The files: one with three levels and a fourth, one whose headings skip to ###, one with sections to filter.
printf '# Alpha one\n\nalpha one body\n\n## Alpha two\n\nalpha two body\n\n### Alpha three\n\nalpha three body\n\n#### Alpha four\n\nalpha four body\n' > "$rigTmp/md/alpha.md"
printf '### Beta top\n\nbeta top body\n\n#### Beta under\n\nbeta under body\n' > "$rigTmp/md/beta.md"
printf '# Keep me\n\nkept body\n\n# Drop me\n\ndropped body\n' > "$rigTmp/md/gamma.md"
rigMerge(){ ## result name, arguments... -- one merge, from the md folder; out and rc
	local rigName="$1" ; shift
	( cd "$rigTmp/md" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" --intern-merge-md-files "$@" ) > "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err"
	printf '%s' "$?" > "$rigTmp/$rigName.rc"
}
rigHeads(){ ## result name -- its heading lines, joined by |
	LC_ALL=C grep -E '^#+ ' "$rigTmp/$1.out" 2> /dev/null | LC_ALL=C tr '\n' '|' | LC_ALL=C sed 's/|$//'
}
rigHas(){ ## result name, fixed text -- yes or no
	LC_ALL=C grep -q -F -- "$2" "$rigTmp/$1.out" 2> /dev/null && printf yes || printf no
}

echo "-- 1. two mixins, each a section of its own name, its file's sections under it --"
rigMerge m1 --mixin "$rigTmp/md/alpha.md" "Section A" --mixin "$rigTmp/md/beta.md" "Section B"
rigAssert "exit 0"                                            "$( cat "$rigTmp/m1.rc" )" 0
rigAssert "the headings, to the default limit of three"       "$( rigHeads m1 )" "# Section A|## Alpha one|### Alpha two|# Section B|## Beta top|### Beta under"
rigAssert "the bodies kept"                                   "$( rigHas m1 'alpha two body' ) $( rigHas m1 'beta under body' )" "yes yes"

echo "-- 2. --section-prefix 2 --"
rigMerge m2 --section-prefix 2 --section-limit 4 --mixin "$rigTmp/md/beta.md" "Section B"
rigAssert "the mixin at ##, its sections under it"            "$( rigHeads m2 )" "## Section B|### Beta top|#### Beta under"

echo "-- 3. a file whose headings skip levels is reworked to fit --"
rigAssert "beta's ### top comes one level under its mixin, not kept as ###" "$( rigHeads m1 | LC_ALL=C tr '|' '\n' | LC_ALL=C grep -c -x '## Beta top' )" 1

echo "-- 4. the limit: a deeper section becomes a reference to its file --"
rigAssert "by default the fourth result level is not inlined"   "$( rigHas m1 'alpha three body' )" no
rigAssert "one line in its place names its file and its heading" "$( LC_ALL=C grep -F 'alpha.md' "$rigTmp/m1.out" | LC_ALL=C grep -c -F 'Alpha three' )" 1
rigMerge m4 --section-limit 2 --mixin "$rigTmp/md/alpha.md" "Section A"
rigAssert "with --section-limit 2: two levels, the third named by one line" "$( rigHeads m4 ):$( rigHas m4 'alpha two body' ):$( LC_ALL=C grep -F 'alpha.md' "$rigTmp/m4.out" | LC_ALL=C grep -c -F 'Alpha two' )" "# Section A|## Alpha one:no:1"

echo "-- 4b. a # line inside a code fence is no heading --"
printf '# Fenced\n\n```sh\n# a shell comment, no heading\n## nor this\n```\n\nafter the fence\n' > "$rigTmp/md/fenced.md"
rigMerge m9 --mixin "$rigTmp/md/fenced.md" "Section F"
rigAssert "the fenced lines are kept as they were, and only the real headings are reworked" \
	"$( rigHas m9 '# a shell comment, no heading' ):$( LC_ALL=C grep -c -x -F '## nor this' "$rigTmp/m9.out" ):$( rigHeads m9 | LC_ALL=C sed 's/|# a shell comment, no heading//; s/|## nor this//' )" "yes:1:# Section F|## Fenced"

echo "-- 5. --do-index: a Contents section first, the captions nested, to the capped depth --"
rigMerge m5 --do-index --mixin "$rigTmp/md/alpha.md" "Section A" --mixin "$rigTmp/md/beta.md" "Section B"
rigAssert "the first heading is Contents, at the prefix level" "$( rigHeads m5 | LC_ALL=C cut -d'|' -f1 )" "# Contents"
rigAssert "it lists the captions in order, nested by depth, none past the limit" \
	"$( LC_ALL=C awk '
		/^#+ / { n++ ; if ( n == 2 ) exit ; next }
		n == 1 && /^[ \t]*[-*+] / {
			indent = match( $0, /[^ \t]/ ) - 1 ; text = $0 ; sub( /^[ \t]*[-*+] +/, "", text ) ; gsub( /[][]/, "", text ) ; sub( /\(.*$/, "", text )
			count++ ; ind[ count ] = indent ; cap[ count ] = text ; widths[ indent ] = 1
		}
		END {
			for ( w in widths ) { rank = 0 ; for ( v in widths ) if ( v + 0 < w + 0 ) rank++ ; depth[ w ] = rank }
			for ( i = 1 ; i <= count ; i++ ) printf "%d:%s|", depth[ ind[ i ] ], cap[ i ]
		}' "$rigTmp/m5.out" )" \
	"0:Section A|1:Alpha one|2:Alpha two|0:Section B|1:Beta top|2:Beta under|"

echo "-- 6. --section-exclude and --section-include --"
rigMerge m6 --mixin --section-exclude "Drop*" "$rigTmp/md/gamma.md" "Section G"
rigAssert "exclude: the matching section is left out"         "$( rigHas m6 'kept body' ) $( rigHas m6 'dropped body' )" "yes no"
rigMerge m7 --mixin --section-include "Drop*" "$rigTmp/md/gamma.md" "Section G"
rigAssert "include: only the matching section is kept"        "$( rigHas m7 'kept body' ) $( rigHas m7 'dropped body' )" "no yes"

echo "-- 7. a plain file argument is refused --"
rigMerge m8 "$rigTmp/md/alpha.md"
rigAssert "refused, naming --mixin, nothing printed"          "$( [ "$( cat "$rigTmp/m8.rc" )" -ne 0 ] && printf refused || printf accepted ):$( LC_ALL=C grep -c -F -- '--mixin' "$rigTmp/m8.err" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "names" : "silent" }' ):$( [ -s "$rigTmp/m8.out" ] && printf printed || printf empty )" "refused:names:empty"

echo "-- 8. a consumer: a default skill load serves the member's and the team's files as one bundle, no SKILL.md --"
mkdir -p "$rigTmp/skills/rig-member" "$rigTmp/skills/magic-team"
printf '# Basic\n\nRIG-TEAM-BASIC-LINE\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
printf '# Armed\n\nRIG-TEAM-ARMED-LINE\n' > "$rigTmp/skills/magic-team/magic-team.armed.md"
printf -- '---\nname: rig-member\ndescription: rig member\n---\n# rig-member\n\nRIG-SKILL-LINE\n' > "$rigTmp/skills/rig-member/SKILL.md"
printf '# Basic\n\nRIG-BASIC-LINE\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
printf '# Armed\n\nRIG-ARMED-LINE\n' > "$rigTmp/skills/rig-member/rig-member.armed.md"
printf '{"skill":"rig-member"}' | ( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=rig-merge-run bash "$rigHarness" --intern-tool Skill ) > "$rigTmp/skill.out" 2> "$rigTmp/skill.err"
rigAssert "one read holds the member's basic and armed file"  "$( rigHas skill RIG-BASIC-LINE ) $( rigHas skill RIG-ARMED-LINE )" "yes yes"
rigAssert "and the team's basic and armed file"               "$( rigHas skill RIG-TEAM-BASIC-LINE ) $( rigHas skill RIG-TEAM-ARMED-LINE )" "yes yes"
rigAssert "each its own section, in that order"              "$( LC_ALL=C grep -E '^# (rig-member|magic-team)\.(basic|armed)\.md$' "$rigTmp/skill.out" | LC_ALL=C tr '\n' ' ' )" "# rig-member.basic.md # rig-member.armed.md # magic-team.basic.md # magic-team.armed.md "
rigAssert "each file's own sections at one level under it"     "$( LC_ALL=C grep -E '^#+ (Basic|Armed)$' "$rigTmp/skill.out" | LC_ALL=C sed -E 's/^(#+) .*/\1/' | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 1
rigAssert "no SKILL.md content in the read"                   "$( rigHas skill RIG-SKILL-LINE ) $( rigHas skill 'Base directory for this skill' )" "no no"

echo "-- 8b. a skill whose SKILL.md declares status: reference-only is served unmerged --"
mkdir -p "$rigTmp/skills/rig-record"
printf -- '---\nname: rig-record\nstatus: reference-only\ndescription: rig record\n---\n# rig-record\n\nRIG-RECORD-LINE\n' > "$rigTmp/skills/rig-record/SKILL.md"
printf '# Basic\n\nRIG-RECORD-BASIC\n' > "$rigTmp/skills/rig-record/rig-record.basic.md"
printf '# Armed\n\nRIG-RECORD-ARMED\n' > "$rigTmp/skills/rig-record/rig-record.armed.md"
printf '{"skill":"rig-record"}' | ( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=rig-merge-run bash "$rigHarness" --intern-tool Skill ) > "$rigTmp/record.out" 2> "$rigTmp/record.err"
rigAssert "its SKILL.md served, neither basic nor armed merged, nor the team's" "$( rigHas record RIG-RECORD-LINE ) $( rigHas record RIG-RECORD-BASIC ) $( rigHas record RIG-RECORD-ARMED ) $( rigHas record RIG-TEAM-BASIC-LINE )" "yes no no no"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MERGE MD FILES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MERGE_MD_FILES: OK (%d assertions, offline)\n' "$rigPassCount"
