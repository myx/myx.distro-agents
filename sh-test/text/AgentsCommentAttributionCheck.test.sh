#!/usr/bin/env bash
## Behavioural check on the shape of a justification: a line states the rule, never the ruling behind it. A comment, a printed
## label, a `MAGIC.md` or a skillset line that names an owner beside a bare date is red. A measurement's own date is not, and neither is an item id,
## whose date is followed by `T`. The scan is proved able to fail on a rig tree before its silence on the family means anything.
## Offline: it writes nothing but its own rig.
set -u

rigHere="$( cd "${BASH_SOURCE%/*}" && pwd -P )"
rigPkg="$( cd "$rigHere/../.." && pwd -P )"
rigFamily="$( cd "$rigPkg/.." && pwd -P )"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set, so this rig has no place to live}"
[ -d "$rigFamily/myx.distro-agents" ] || rigRefuse "the family is not beside this check: $rigFamily"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommentAttributionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The scan: <root> -> a `file:line` for each line naming an owner and a bare date. Two greps, because a code file is read on its
## comment lines alone while a document is read whole. A date an id carries is followed by `T`, and a fixture under
## check-fixtures keeps its shape on purpose, so neither is a hit.
rigScan(){ ## root
	LC_ALL=C grep -rInE '^[[:space:]]*#.*(human-)?owner[^)]{0,80}20[0-9]{2}-[0-9]{2}-[0-9]{2}([^0-9T]|$)' \
		--include='*.sh' --include='*.include' --include='*.awk' --include='*.py' "$1" 2>/dev/null \
		| LC_ALL=C grep -v '/check-fixtures/'
	LC_ALL=C grep -rInE '(human-)?owner[^)]{0,80}20[0-9]{2}-[0-9]{2}-[0-9]{2}([^0-9T]|$)' \
		--include='MAGIC.md' --include='*.basic.md' --include='*.armed.md' --include='*.routine.md' --include='*.format.md' "$1" 2>/dev/null \
		| LC_ALL=C grep -v '/check-fixtures/'
	LC_ALL=C grep -rInE '^[[:space:]]*echo .*(human-)?owner[^)]{0,80}20[0-9]{2}-[0-9]{2}-[0-9]{2}([^0-9T]|$)' \
		--include='*.sh' --include='*.include' "$1" 2>/dev/null \
		| LC_ALL=C grep -v '/check-fixtures/'
	: true
}

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## The rig: one file of each shape the scan must tell apart, so a silence is a measurement and never a broken pattern.
rigRig="$rigTmp/rig"
mkdir -p "$rigRig" || exit 1
printf '## A RULE by the owner, 2026-01-01: the rule, with its author and its date.\n' > "$rigRig/bad.include" || exit 1
printf '## A RULE: the rule.\n## Measured 2026-01-01: three calls, 3 ms each.\n' > "$rigRig/good.include" || exit 1
printf '# A note carrying a board item, board task 2026-01-01T0101Z, and no ruling.\n' > "$rigRig/MAGIC.md" || exit 1
printf '%s\n' 'echo "-- a case for the owner, 2026-01-01 --"' > "$rigRig/bad-label.sh" || exit 1
printf "%s\n" "rigItem x 'approved-by: human-owner (rig-session, 2026-01-01T01:00:00Z)'" > "$rigRig/rig-item.include" || exit 1
rigHits="$( rigScan "$rigRig" )"
rigCount(){ printf '%s\n' "$1" | LC_ALL=C grep -c -- "$2" ; }

rigAssert "a comment naming an owner and a bare date is one hit" \
	"$( rigCount "$rigHits" 'bad\.include' )" "1"
rigAssert "the same rule stated plainly, and a measurement's own date, are no hit" \
	"$( rigCount "$rigHits" 'good\.include' )" "0"
rigAssert "a date an item id carries is no hit" \
	"$( rigCount "$rigHits" 'MAGIC\.md' )" "0"
rigAssert "a printed label naming an owner and a date is one hit" \
	"$( rigCount "$rigHits" 'bad-label\.sh' )" "1"
rigAssert "a fixture's approved-by header, whose date an id carries, is no hit" \
	"$( rigCount "$rigHits" 'rig-item\.include' )" "0"

## The family this check came with: the tree a writer edits, never the copies installed elsewhere.
rigLive="$( rigScan "$rigFamily" )"
if [ -n "$rigLive" ] ; then
	printf '%s\n' "$rigLive" | LC_ALL=C sed 's/^/        /' >&2
fi
rigAssert "the family beside this check carries no dated owner attribution" \
	"$( printf '%s\n' "$rigLive" | LC_ALL=C grep -c . )" "0"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ COMMENT ATTRIBUTION CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "COMMENT_ATTRIBUTION: OK ($rigPasses assertions, offline)"
