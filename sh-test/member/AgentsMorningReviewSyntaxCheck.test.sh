#!/usr/bin/env bash
## Behavioural check on the syntax lines the daily board review holds before its first round (S18.5 of the
## refactorings epic): the six operations its steps use stand in its own `## Tooling operations` block, copied
## character for character from the help page that owns each one, and the routine's text reaches the run's prompt
## prefix, which is what carries them there. Held:
##   1. the routine declares `cache-prefix: routine`, so its text is part of the prefix
##   2. each of the six lines stands in that block once, copied from its help page, never written in a short form
##   3. the routine's text as the tool mixes it into the prefix carries all six, on the same terms
##   4. the reader can fail both ways: one help page seeded with a narrowed form gives exactly that operation's row,
##      and the unaltered page gives none
## Red before S18.5, measured: the frontmatter carries no `cache-prefix:`, and the block carries the bare operation
## names, so 1 fails and 2 and 3 fail on six rows each. Part 4 stays green either way, which is what shows its own
## two directions work.
## Offline: the package at the origin, and a rig tree of this check's own. No network, no session, no other workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigHelp="$rigPkg/sh-lib/help"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-scripts/DistroAgentsSession.fn.sh" ] || rigRefuse "the Session file is not at the origin this workspace resolves: $rigPkg/sh-scripts"
[ -d "$rigHelp" ] || rigRefuse "the family's help is not at the origin: $rigHelp"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMorningReviewSyntaxCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/agents" "$rigHome" "$rigData" \
	"$rigSkills/magic-librarian" "$rigSkills/magic-team" || exit 1
rigCopyTree "$rigPkg/skillset/magic-team/magic-librarian" "$rigSkills/magic-librarian" || rigRefuse "the skillset could not be copied into the rig"
rigCopyTree "$rigPkg/skillset/magic-team/magic-team" "$rigSkills/magic-team" || rigRefuse "the team routines could not be copied into the rig"
rigRoutine="$rigSkills/magic-librarian/magic-librarian.morning-review.routine.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}
## The six operations the routine's steps use, and the help page that owns each one's syntax line.
rigOps(){ ## -- one `operation page` a line
	cat <<'OPS'
update-routine-state Help.DistroAgentsSession.help.md
upsert-inbox-inquiry Help.DistroAgentsItems.help.md
skillset-upsert Help.AgentLibrarianTools.help.md
queue-list Help.AgentLibrarianTools.help.md
queue-take Help.AgentLibrarianTools.help.md
queue-done Help.AgentLibrarianTools.help.md
OPS
}
## What one operation's line must be, as the routine carries it: its help page's syntax line as a bullet. Nothing
## where that page holds no line for the operation.
rigWanted(){ ## help directory, operation, page name -- the bullet
	LC_ALL=C awk -v op="--$2" '
		index($0, "📘 syntax: ") == 1 { line = $0 ; sub(/^📘 syntax: /, "", line) ; n = split(line, w, " ") ; if (w[2] == op) { printf "- `%s`\n", line ; exit ; } ; }
	' "$1/$3" 2> /dev/null
}
## The routine's own tooling block as its text reaches the prefix: the last `Tooling operations` heading, whose
## level the mix raises by one, and the lines under it to the next heading.
rigBlock(){ ## mixed text, where to write the block
	LC_ALL=C awk '
		/^#+ Tooling operations$/ { inside = 1 ; block = "" ; next ; }
		inside && /^#/ { seen = block ; inside = 0 ; next ; }
		inside { block = block $0 "\n" ; }
		END { printf "%s", ( inside || seen != "" ) ? ( inside ? block : seen ) : "" ; }
	' "$1" > "$2" || :
}
## One row for each of the six lines a text does not carry exactly once: absent, repeated, or written in a form its
## help page does not give. Nothing when all six stand as copied.
rigRows(){ ## text file, help directory -- one row a fault
	local rowOp rowPage rowWant rowCount
	while read -r rowOp rowPage ; do
		[ -n "$rowOp" ] || continue
		rowWant="$( rigWanted "$2" "$rowOp" "$rowPage" )"
		if [ -z "$rowWant" ] ; then
			printf '%s: its help page carries no syntax line for it\n' "$rowOp"
			continue
		fi
		rowCount="$( LC_ALL=C grep -c -x -F -- "$rowWant" "$1" || : )"
		case "$rowCount" in
			1) ;;
			0) printf '%s: the line its help page gives is not there: %s\n' "$rowOp" "$rowWant" ;;
			*) printf '%s: the line its help page gives stands %s times\n' "$rowOp" "$rowCount" ;;
		esac
	done <<< "$( rigOps )"
}
rigRowCount(){ ## text file, help directory -- how many lines it faults on
	rigRows "$1" "$2" | LC_ALL=C grep -c . || :
}

echo "-- 1. the routine asks for its text in the prefix --"
rigAssert "the routine declares cache-prefix: routine" \
	"$( LC_ALL=C awk 'NR == 1 { next ; } $0 == "---" { exit ; } /^cache-prefix: / { sub(/^cache-prefix: /, "") ; print ; exit ; }' "$rigRoutine" )" "routine"

echo "-- 2. the six lines are copied from their help pages --"
rigBlock "$rigRoutine" "$rigTmp/own-block"
rigAssert "the routine's own tooling block was found, and holds lines" \
	"$( [ -s "$rigTmp/own-block" ] && printf found || printf missing )" "found"
rigRows "$rigTmp/own-block" "$rigHelp"
rigAssert "every one of the six operations carries its help page's own line, once" "$( rigRowCount "$rigTmp/own-block" "$rigHelp" )" "0"

echo "-- 3. the text the prefix carries holds all six --"
( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
	MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" \
	bash "$rigPkg/sh-scripts/DistroAgentsSession.fn.sh" --get-routine-text magic-librarian.morning-review ) > "$rigTmp/mixed.md" 2> "$rigTmp/mixed.err"
rigMixedRc=$?
rigAssert "the routine's text can be read: rc 0" "$rigMixedRc" "0"
if [ "$rigMixedRc" != 0 ] ; then sed -n '1,5p' "$rigTmp/mixed.err" >&2 ; fi
rigBlock "$rigTmp/mixed.md" "$rigTmp/mixed-block"
rigAssert "the mixed text carries the routine's block, with its lines" \
	"$( [ -s "$rigTmp/mixed-block" ] && printf found || printf missing )" "found"
rigRows "$rigTmp/mixed-block" "$rigHelp"
rigAssert "and it carries the six lines as copied, so the prefix holds them" "$( rigRowCount "$rigTmp/mixed-block" "$rigHelp" )" "0"

echo "-- 4. the reader can fail both ways --"
mkdir -p "$rigTmp/help" || exit 1
cp "$rigHelp"/Help.DistroAgentsSession.help.md "$rigHelp"/Help.DistroAgentsItems.help.md "$rigHelp"/Help.AgentLibrarianTools.help.md "$rigTmp/help/" \
	|| rigRefuse "the three help pages could not be copied into the rig"
## A block built the way the routine must carry it: the six lines rigWanted gives, in this check's own order.
while read -r rowOp rowPage ; do
	[ -n "$rowOp" ] || continue
	rigWanted "$rigHelp" "$rowOp" "$rowPage"
done <<< "$( rigOps )" > "$rigTmp/wanted-block"
rigAssert "a block built from the help pages is six lines" "$( LC_ALL=C grep -c . "$rigTmp/wanted-block" || : )" "6"
rigAssert "the reader passes it: no row" "$( rigRowCount "$rigTmp/wanted-block" "$rigHelp" )" "0"
LC_ALL=C awk '
	index($0, "📘 syntax: ") == 1 && index($0, ".fn.sh --update-routine-state ") {
		line = $0 ; at = index(line, " [--edit-patch-from-stdin|--from-file <path>]") ; if (at > 0) line = substr(line, 1, at - 1) ; print line ; next
	}
	{ print ; }
' "$rigHelp/Help.DistroAgentsSession.help.md" > "$rigTmp/seed-page" || exit 1
cp "$rigTmp/seed-page" "$rigTmp/help/Help.DistroAgentsSession.help.md" || exit 1
rigAssert "the seed took: that page's line for the operation is the narrowed one" \
	"$( LC_ALL=C grep -c -x -F '📘 syntax: DistroAgentsSession.fn.sh --update-routine-state [--team-member <team-member>] [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]...' "$rigTmp/help/Help.DistroAgentsSession.help.md" || : )" "1"
rigAssert "and the pages it does not touch are as the origin has them" \
	"$( cmp -s "$rigHelp/Help.AgentLibrarianTools.help.md" "$rigTmp/help/Help.AgentLibrarianTools.help.md" && printf same || printf different )" "same"
rigAssert "the wanted block against the seeded page: exactly that one operation's row" "$( rigRowCount "$rigTmp/wanted-block" "$rigTmp/help" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ MORNING REVIEW SYNTAX CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'AGENTS_MORNING_REVIEW_SYNTAX: OK (%d assertions, offline)\n' "$rigPassCount"
