#!/usr/bin/env bash
## Behavioural check of the code requirements every spawn brief carries. The brief's mechanical block is what each dispatched run
## receives, so the rules that keep new code from needing repair are given there, not left for a run to find. Held, over the block
## as the filler emits it with its tags stripped:
##   1. a code-requirements line names code-craft.md and shell.md of magic-developer, read in full before code is written
##   2. its rules follow it as list items: removing over adding, inlining trivial functions, one operation per file, the bash 3.2
##      traps, the apply line with a red-then-green check, the per-call cost before and after, and when the work is done
## Red before the change: the block named no code rules at all. Offline; the template is read, never run.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"
[ -f "$rigTemplate" ] || { echo "⛔ ERROR: the brief template is not in the package: $rigTemplate -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsSpawnBriefCodeRequirementsCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The block as the filler emits it: from SPAWN-PREPARE-BRIEF to its closing line, its tags stripped.
LC_ALL=C awk '
	/^SPAWN-PREPARE-BRIEF: / { inBlock = 1 ; print ; next ; }
	!inBlock { next ; }
	$0 == "When done, hand back and Wait until dismissed." { print ; exit ; }
	{ sub( /^\[(own|native|lock|scan)\] /, "" ) ; print ; }
' "$rigTemplate" > "$rigTmp/block"
## The requirements: their line and the list items under it, up to the first line that is neither.
LC_ALL=C awk '/^code-requirements: / { inReq = 1 ; print ; next ; } inReq && /^- / { print ; next ; } inReq { exit ; }' "$rigTmp/block" > "$rigTmp/req"

echo "-- 1. the block names the code rules --"
rigAssert "the line naming both references, read in full" \
	"$( LC_ALL=C grep -c '^code-requirements: .*reference/code-craft\.md and reference/shell\.md of magic-developer.*in full' "$rigTmp/req" )" 1

echo "-- 2. its rules follow it --"
for rigRule in 'removes or simplifies code' 'Inline each trivial function at every call site' 'each operation in its own file' 'bash 3.2' 'red on base and green on the lane' 'in milliseconds, before and after' 'no call it touches got slower' ; do
	rigAssert "a rule: $rigRule" "$( LC_ALL=C grep -c -F -- "$rigRule" "$rigTmp/req" )" 1
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN BRIEF CODE REQUIREMENTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_BRIEF_CODE_REQUIREMENTS: OK (%d assertions, offline)\n' "$rigPassCount"
