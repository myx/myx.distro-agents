#!/usr/bin/env bash
## Behavioural check on the `mark` row the contracts repeat: one row per kind of item, copied into every contract of that kind.
## Ten copies of one sentence are how the copies drift apart, so the check compares them rather than trusting them: within a kind
## of item every `mark` row is byte-identical, and two kinds may differ. A rig pair of differing rows proves the comparison able
## to fail before its silence on the family means anything. Offline: it writes nothing but its own rig.
set -u

rigHere="$( cd "${BASH_SOURCE%/*}" && pwd -P )"
rigPkg="$( cd "$rigHere/../.." && pwd -P )"
rigFamily="$( cd "$rigPkg/.." && pwd -P )"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set, so this rig has no place to live}"
[ -d "$rigFamily/myx.distro-agents" ] || rigRefuse "the family is not beside this check: $rigFamily"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContractRowParityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The rows of a tree: `<kind of item>\t<mark row>`, one line per contract holding the row. The kind is the file's own first
## segment, so a board item and an inbox item are compared apart while every board contract is compared together.
rigRows(){ ## contracts-dir
	LC_ALL=C awk -F'\t' '/^\| `mark` \|/ {
		name = FILENAME ; sub( /.*\//, "", name ) ; sub( /\.contract\.format\.md$/, "", name )
		kind = name ; sub( /-item$/, "-item", kind ) ; sub( /\.[^.]*$/, "", kind )
		printf "%s\t%s\n", kind, $0
	}' "$1"/*.contract.format.md 2>/dev/null
}
## The rows that break the rule: a kind holding more than one distinct row.
rigOffenders(){ ## rows
	printf '%s\n' "$1" | LC_ALL=C awk -F'\t' 'NF {
		key = $1 SUBSEP $0 ; if ( seen[key]++ ) next ; kinds[$1]++ ; rows[$1] = rows[$1] "\n  " substr( $0, length( $1 ) + 2 )
	} END { for ( k in kinds ) if ( kinds[k] > 1 ) printf "%s: %d rows%s\n", k, kinds[k], rows[k] ; }'
}

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## The rig: one kind whose two copies agree, one kind whose two copies differ, and one kind alone, which has nothing to disagree with.
rigRig="$rigTmp/rig"
mkdir -p "$rigRig" || exit 1
printf '| `mark` | optional | member | `enum important, urgent` | one row |\n' > "$rigRig/board-item.task.contract.format.md" || exit 1
printf '| `mark` | optional | member | `enum important, urgent` | one row |\n' > "$rigRig/board-item.idea.contract.format.md" || exit 1
printf '| `mark` | optional | member | `enum important, urgent` | one row |\n' > "$rigRig/inbox-item.note.contract.format.md" || exit 1
printf '| `mark` | optional | member | `enum important, urgent` | another row |\n' > "$rigRig/inbox-item.inquiry.contract.format.md" || exit 1
printf '| `mark` | optional | member | `enum important, urgent` | alone |\n' > "$rigRig/epic.contract.format.md" || exit 1
rigHits="$( rigOffenders "$( rigRows "$rigRig" )" )"
rigAssert "a kind whose copies agree is no offender, and a kind alone is none" \
	"$( printf '%s\n' "$rigHits" | LC_ALL=C grep -c 'board-item\|epic' )" "0"
rigAssert "a kind whose copies differ is one offender, naming the kind" \
	"$( printf '%s\n' "$rigHits" | LC_ALL=C grep -c 'inbox-item' )" "1"

## The family this check came with: every contract it carries, compared.
rigLive="$( rigOffenders "$( rigRows "$rigPkg/skillset/magic-team/magic-team/contracts" )" )"
if [ -n "$rigLive" ] ; then
	printf '%s\n' "$rigLive" | LC_ALL=C sed 's/^/        /' >&2
fi
rigAssert "every kind of item carries one mark row across its contracts" \
	"$( printf '%s\n' "$rigLive" | LC_ALL=C grep -c . )" "0"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ CONTRACT ROW PARITY CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "CONTRACT_ROW_PARITY: OK ($rigPasses assertions, offline)"
