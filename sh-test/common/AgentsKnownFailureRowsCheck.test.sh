#!/usr/bin/env bash
## Behavioural check on the suite's own red list as a record: sh-test/known-failures.txt is what a reader trusts about a red
## check, so each row must be true of the check it names. Read over the suite tree this origin resolves, and run once. Held:
##   1. CONTROL: the list is read at all, and its rows are three filled fields, so no assertion below rests on a list this
##      check failed to parse.
##   2. A row that carries a fraction `<n> of <m>` carries the count of assertions its own check file makes. A row whose
##      denominator lags its file tells the next reader the check has not changed when it has.
##   3. CONTROL: a row carrying no fraction is no fault here, so the rule never forces a number onto a reason that reads well
##      without one, and the fix the plan allows — drop the fraction — takes the row out of this rule.
##   4. A refusal row names what the check needed. The one mechanical form of that is that the check file itself speaks the
##      words the row quotes: a row naming a message no check speaks cannot be traced to the thing it waited for.
##   5. CONTROL, and the half that makes 2 and 4 mean anything: the same two readings on a rig list and rig checks find a
##      stale fraction and an orphan refusal, so a reader that never fires is caught here.
## Red recipe: measured on the live tree at 2026-11-23 18:08 +0200, 49 rows carry a fraction and 13 of them disagree with
## their own check file, and 6 of the 20 refusal rows quote a message their check does not speak. Both counts are printed
## on failure, so a partly repaired list still says how far it moved.
## Offline: the suite tree this origin resolves, and this check's own rig under a temp HOME.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigSuite="$rigOrigin/myx/myx.distro-agents/sh-test"
rigList="$rigSuite/known-failures.txt"
rigRefusalMarker='refuses to report a result'
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigList" ] || rigRefuse "the red list is not at the origin this workspace resolves: $rigList"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsKnownFailureRowsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## How many assertions one check file makes: the calls to every function it defines whose body counts a pass and a fail. The
## static count is the only count a reader can check without running 24,000 assertions, and it is the count a row's
## denominator must agree with.
rigAssertionsOf(){ ## check file -- the number of assertion calls it makes, or empty where it defines no such helper
	local helper helpers count=0
	helpers="$( LC_ALL=C awk '
		function flush(   p, f) {
			if (name == "") return ;
			p = (body ~ /[Pp]ass[A-Za-z_]*[[:space:]]*=[[:space:]]*\$\(\(/) ;
			f = (body ~ /[Ff]ail[A-Za-z_]*[[:space:]]*=[[:space:]]*\$\(\(/) ;
			if (p && f) print name ;
			name = "" ; body = "" ;
		}
		{
			if (name == "") {
				if ($0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) {
					name = $0 ; sub(/^[[:space:]]*/, "", name) ; sub(/[[:space:]]*\(\).*/, "", name) ;
					body = $0 ;
					if ($0 ~ /\}/) { flush() ; } ;
				}
				next ;
			}
			body = body "\n" $0 ;
			if ($0 ~ /^\}/) flush() ;
		}
		END { flush() ; }
	' "$1" )"
	[ -n "$helpers" ] || return 0
	while IFS= read -r helper ; do
		[ -n "$helper" ] || continue
		count=$(( count + $( LC_ALL=C grep -cE "^[[:space:]]*$helper[[:space:]]" "$1" ) ))
	done <<< "$helpers"
	printf '%s' "$count"
}
rigFileOf(){ ## a check name, a suite folder -- its file, empty where the folder holds none of that name
	local found
	found="$( find "$2" -name "$1.test.sh" -print -quit 2> /dev/null )"
	[ -n "$found" ] || return 0
	printf '%s' "$found"
}
## The words a check file speaks when it refuses: the argument of every refusal-shaped call it makes.
rigSpeaksOf(){ ## check file -- one refusal message a line
	LC_ALL=C grep -oE '(rigRefuse|refuse)[[:space:]]+"[^"]+"' "$1" 2> /dev/null | LC_ALL=C sed -E 's/^[a-zA-Z]+[[:space:]]+"//; s/"$//'
}
## The rows of one list as `name<TAB>owner<TAB>reason`, comments and blank lines dropped.
rigRowsOf(){ ## list file -- one row a line
	LC_ALL=C awk -F'\t' '/^[[:space:]]*#/ { next ; } NF < 2 { next ; } { print $1 "\t" $2 "\t" $3 ; }' "$1"
}

echo "-- 1. control: the list is read, and its rows are three filled fields --"
rigRowCount="$( rigRowsOf "$rigList" | LC_ALL=C grep -c . || : )"
rigAssert "the list holds rows, and this reading found them" \
	"$( [ "${rigRowCount:-0}" -gt 0 ] && printf many || printf none )" many
rigAssert "every row is three filled fields, the shape the run itself refuses otherwise" \
	"$( rigRowsOf "$rigList" | LC_ALL=C awk -F'\t' '$1 == "" || $2 == "" || $3 == "" { n++ ; } END { print n + 0 ; }' )" 0

echo "-- 2. every row carrying a fraction carries the count of its own check file --"
rigStale=0 rigFractionRows=0 rigStaleList=""
while IFS=$'\t' read -r rigName rigOwner rigReason ; do
	case "$rigReason" in
		*" of "*[0-9]*) ;;
		*) continue ;;
	esac
	rigDenominator="$( printf '%s' "$rigReason" | LC_ALL=C grep -oE '[0-9]+ of [0-9]+' | LC_ALL=C sed -n 1p | LC_ALL=C awk '{ print $3 ; }' )"
	[ -n "$rigDenominator" ] || continue
	rigFractionRows=$(( rigFractionRows + 1 ))
	rigFile="$( rigFileOf "$rigName" "$rigSuite" )"
	if [ -z "$rigFile" ] ; then
		rigStale=$(( rigStale + 1 )) ; rigStaleList="$rigStaleList $rigName(no-file)"
		continue
	fi
	rigMade="$( rigAssertionsOf "$rigFile" )"
	if [ "$rigMade" != "$rigDenominator" ] ; then
		rigStale=$(( rigStale + 1 )) ; rigStaleList="$rigStaleList $rigName(row=$rigDenominator file=$rigMade)"
	fi
done <<< "$( rigRowsOf "$rigList" )"
printf '  rows carrying a fraction: %s, of them disagreeing with their own file: %s%s\n' \
	"$rigFractionRows" "$rigStale" "$( [ -z "$rigStaleList" ] || printf ':%s' "$rigStaleList" )"
rigAssert "every fraction agrees with the assertion count of the check it names" "$rigStale" 0

echo "-- 3. control: a row carrying no fraction is no fault here --"
rigAssert "the list holds rows carrying no fraction, and this rule passes them over" \
	"$( [ "$rigRowCount" -gt "$rigFractionRows" ] && printf many || printf none )" many

echo "-- 4. every refusal row names a thing its own check file speaks of --"
rigOrphan=0 rigRefusalRows=0 rigOrphanList=""
while IFS=$'\t' read -r rigName rigOwner rigReason ; do
	case "$rigReason" in
		"$rigRefusalMarker"*) ;;
		*) continue ;;
	esac
	rigRefusalRows=$(( rigRefusalRows + 1 ))
	rigClaim="$( printf '%s' "${rigReason#"$rigRefusalMarker"}" | LC_ALL=C sed -E 's/^[: ]+//' | LC_ALL=C cut -d, -f1 | LC_ALL=C cut -d: -f1 )"
	rigFile="$( rigFileOf "$rigName" "$rigSuite" )"
	if [ -z "$rigFile" ] ; then
		rigOrphan=$(( rigOrphan + 1 )) ; rigOrphanList="$rigOrphanList $rigName(no-file)"
		continue
	fi
	rigTraceable=""
	while IFS= read -r rigSaid ; do
		[ -n "$rigSaid" ] || continue
		case "$rigSaid" in
			"$rigClaim"*) rigTraceable=1 ; break ;;
		esac
	done <<< "$( rigSpeaksOf "$rigFile" )"
	[ -n "$rigTraceable" ] || { rigOrphan=$(( rigOrphan + 1 )) ; rigOrphanList="$rigOrphanList $rigName"; }
done <<< "$( rigRowsOf "$rigList" )"
printf '  refusal rows: %s, of them quoting no message their own check speaks: %s%s\n' \
	"$rigRefusalRows" "$rigOrphan" "$( [ -z "$rigOrphanList" ] || printf ':%s' "$rigOrphanList" )"
rigAssert "every refusal row names what its own check waited for" "$rigOrphan" 0

echo "-- 5. control: the same two readings find a stale fraction and an orphan refusal in a rig list --"
rigRigSuite="$rigTmp/suite"
mkdir -p "$rigRigSuite/common"
cat > "$rigRigSuite/common/RigCountedCheck.test.sh" <<'RIGCHECK'
#!/usr/bin/env bash
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then rigPasses=$(( rigPasses + 1 )) ; else rigFails=$(( rigFails + 1 )) ; fi
}
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
rigAssert "one" a a
rigAssert "two" a a
rigAssert "three" a a
if [ -n "${rigNever:-}" ] ; then rigRefuse "the rig produced no refusal to ask permission for" ; fi
RIGCHECK
printf 'RigCountedCheck\tmagic-tester\t1 of 2: a fraction off the count its file makes\nRigCountedCheck\tmagic-tester\t%s: the rig produced no refusal to ask permission for\nRigCountedCheck\tmagic-tester\t%s: a thing this check never says\n' \
	"$rigRefusalMarker" "$rigRefusalMarker" > "$rigTmp/known-failures.txt"
rigStaleRig=0
while IFS=$'\t' read -r rigName rigOwner rigReason ; do
	rigDenominator="$( printf '%s' "$rigReason" | LC_ALL=C grep -oE '[0-9]+ of [0-9]+' | LC_ALL=C sed -n 1p | LC_ALL=C awk '{ print $3 ; }' )"
	[ -n "$rigDenominator" ] || continue
	[ "$( rigAssertionsOf "$rigRigSuite/common/$rigName.test.sh" )" = "$rigDenominator" ] || rigStaleRig=$(( rigStaleRig + 1 ))
done <<< "$( rigRowsOf "$rigTmp/known-failures.txt" )"
rigAssert "control: a fraction off its file's count is found on the rig" "$rigStaleRig" 1
rigOrphanRig=0
while IFS=$'\t' read -r rigName rigOwner rigReason ; do
	case "$rigReason" in "$rigRefusalMarker"*) ;; *) continue ;; esac
	rigClaim="$( printf '%s' "${rigReason#"$rigRefusalMarker"}" | LC_ALL=C sed -E 's/^[: ]+//' | LC_ALL=C cut -d, -f1 | LC_ALL=C cut -d: -f1 )"
	rigTraceable=""
	while IFS= read -r rigSaid ; do
		[ -n "$rigSaid" ] || continue
		case "$rigSaid" in "$rigClaim"*) rigTraceable=1 ; break ;; esac
	done <<< "$( rigSpeaksOf "$rigRigSuite/common/$rigName.test.sh" )"
	[ -n "$rigTraceable" ] || rigOrphanRig=$(( rigOrphanRig + 1 ))
done <<< "$( rigRowsOf "$rigTmp/known-failures.txt" )"
rigAssert "control: an orphan refusal is found on the rig, and the one it speaks is not" "$rigOrphanRig" 1

if [ "$rigFails" -ne 0 ] ; then
	printf 'KNOWN FAILURE ROWS: FAIL (%s passed, %s failed)\n' "$rigPasses" "$rigFails" ; exit 1
fi
printf 'KNOWN_FAILURE_ROWS: OK (%s assertions, offline, suite tree and rig list)\n' "$rigPasses"
