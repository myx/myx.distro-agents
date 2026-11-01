#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## AgentsInContextHelperCheck.test.sh -- a function an include calls in context has its include loaded on the way to that
## call. The overlay loads a helper where it is called; a call whose branch never sourced the helper stops the operation
## with "command not found", or silently takes its fallback. That is what this check fails on.
##
## Reachable here means one of two: a file-scope guard for the helper's include, before the file's first function, or a
## guarded source above the call, inside the function that makes it. A guard in a different function does not count.
## One gap stays outside this check's reach: a source placed in one branch of a function and a call made in another.
##
##  1. every call of a moved helper has the helper's include on the way to it
##  2. the control: a file-scope guard satisfies a call in any function
##  3. the control: a function's own include is not reported
##  4. a moved helper's own include carries what its body calls
##
## Offline: the files of this package are read, and nothing is run.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -d "$rigHere/sh-lib" ] || { echo "⛔ ERROR: no sh-lib at $rigHere" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsInContextHelperCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The helpers this package calls in context, and the include that defines each.
rigHelpers="$rigTmp/helpers.tsv"
cat > "$rigHelpers" <<'RIGHELPERS'
AgentsToolsConfigOption	sh-lib/config/AgentsTools.ConfigOption.include
AgentsToolsCommsSlackRun	sh-lib/comms/AgentsTools.CommsSlack.include
AgentsToolsMemberCommsSlackRun	sh-lib/comms/AgentsTools.MemberCommsSlack.include
AgentsToolsMyRoot	sh-lib/common/AgentsTools.MyRoot.include
AgentsToolsFrontSyntax	sh-lib/harness/AgentsContext.FrontTable.Help.include
AgentsToolsFrontHelp	sh-lib/harness/AgentsContext.FrontTable.Help.include
AgentsToolsFrontSummary	sh-lib/harness/AgentsContext.FrontTable.Help.include
AgentsToolsFrontRetired	sh-lib/harness/AgentsContext.FrontTable.Retired.include
RIGHELPERS

rigReach(){ ## file, helper, helper's include -- rc 1 where the include is not on the way to the call
	LC_ALL=C awk -v FN="$2" -v OWNER="$3" -v FILE="$1" '
		BEGIN {
			## pass one: a guard at column 0 is in place before any call, wherever it sits in the file
			while ( ( getline l < FILE ) > 0 ) {
				if ( index( l, OWNER ) > 0 && l ~ /^(type|\.) / ) fileScope = 1
			}
			close( FILE )
		}
		/^[A-Za-z_][A-Za-z0-9_]*\(\)/ { fnLine = NR ; fnGuard = 0 }
		{ if ( index( $0, OWNER ) > 0 && $0 !~ /^[ \t]*#/ ) { if ( l ~ /^(type|\.) / ) { } ; if ( $0 ~ /^[ \t]+\. / || $0 ~ /^[ \t]+type / ) fnGuard = 1 } }
		/^[ \t]*#/ { next }
		{
			line = $0
			while ( match( line, "[A-Za-z_][A-Za-z0-9_]*" ) > 0 ) {
				name = substr( line, RSTART, RLENGTH ) ; line = substr( line, RSTART + RLENGTH )
				if ( name != FN ) continue
				if ( fileScope || fnGuard || fnLine == 0 ) next
				print NR ; exit 1
			}
		}' "$1"
}

: > "$rigTmp/missing.tsv"
while IFS=$'\t' read -r rigFn rigOwner ; do
	[ -n "$rigFn" ] || continue
	LC_ALL=C grep -rl --include='*.include' -E "(^|[^A-Za-z0-9_])${rigFn}([^A-Za-z0-9_]|$)" "$rigHere/sh-lib" | while IFS= read -r rigFile ; do
		rigRel="${rigFile#"$rigHere"/}"
		[ "$rigRel" = "$rigOwner" ] || rigReach "$rigFile" "$rigFn" "$rigOwner" > /dev/null || \
			printf '%s\t%s\t%s\n' "$rigRel" "$rigFn" "$rigOwner" >> "$rigTmp/missing.tsv"
	done
done < "$rigHelpers"
LC_ALL=C sort -u -o "$rigTmp/missing.tsv" "$rigTmp/missing.tsv"

echo "-- 1. every call of a moved helper has its include on the way to it --"
rigMissing="$( LC_ALL=C wc -l < "$rigTmp/missing.tsv" | tr -d ' ' )"
rigAssert "no call path reaches a moved helper unsourced" "$rigMissing" "0"
[ "$rigMissing" = "0" ] || LC_ALL=C head -20 "$rigTmp/missing.tsv" | LC_ALL=C sed 's/^/        /' >&2

echo "-- 2. the control: a file-scope guard --"
LC_ALL=C printf 'helper = "sh-lib/config/AgentsTools.ConfigOption.include"\n' > "$rigTmp/ctl1.sh"
LC_ALL=C printf 'type AgentsToolsConfigOption > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.ConfigOption.include"\nF(){ AgentsToolsConfigOption x ; }\n' > "$rigTmp/ctl2.sh"
rigAssert "a guard at the top of the file satisfies a call in a function" "$( rigReach "$rigTmp/ctl2.sh" AgentsToolsConfigOption sh-lib/config/AgentsTools.ConfigOption.include > /dev/null ; printf '%s' "$?" )" "0"

echo "-- 3. the control: a function's own include --"
rigAssert "the include that defines a helper is not reported" "$( LC_ALL=C awk -F'\t' '$1 == $3' "$rigTmp/missing.tsv" | LC_ALL=C wc -l | tr -d ' ' )" "0"

echo "-- 4. a moved helper's own include carries what its body calls --"
find "$rigHere/sh-lib" -name '*.include' -print | LC_ALL=C sort | while IFS= read -r rigFile ; do
	LC_ALL=C sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)()[[:space:]]*{.*/\1/p' "$rigFile" | while IFS= read -r rigFn ; do
		printf '%s\t%s\n' "$rigFn" "${rigFile#"$rigHere"/}"
	done
done > "$rigTmp/defines.tsv"
: > "$rigTmp/helperGaps.tsv"
LC_ALL=C cut -f2 "$rigHelpers" | LC_ALL=C sort -u | while IFS= read -r rigOwnerRel ; do
	rigOwnerFile="$rigHere/$rigOwnerRel"
	[ -f "$rigOwnerFile" ] || continue
	LC_ALL=C awk -F'\t' -v FILE="$rigOwnerFile" -v REL="$rigOwnerRel" -v MAP="$rigTmp/defines.tsv" -v OUT="$rigTmp/helperGaps.tsv" '
		BEGIN { while ( ( getline l < MAP ) > 0 ) { split( l, p, "\t" ) ; if ( p[1] != "" ) { if ( p[1] in owner ) owner[p[1]] = "AMBIGUOUS" ; else owner[p[1]] = p[2] } } ; fnLine = 0 ; fileScope = 0 }
		/^[A-Za-z_][A-Za-z0-9_]*\(\)/ { fnLine = NR }
		{ whole = whole "\n" $0 }
		END {
			while ( ( getline l < FILE ) > 0 ) {
				if ( l ~ /^[ \t]*#/ ) continue
				while ( match( l, /[A-Za-z_][A-Za-z0-9_]*/ ) ) {
					name = substr( l, RSTART, RLENGTH ) ; l = substr( l, RSTART + RLENGTH )
					if ( !( name in owner ) ) continue
					if ( owner[name] == "AMBIGUOUS" || owner[name] == REL ) continue
					if ( index( whole, owner[name] ) == 0 ) print REL "\t" name "\t" owner[name] >> OUT
				}
			}
		}' "$rigOwnerFile"
done
LC_ALL=C sort -u -o "$rigTmp/helperGaps.tsv" "$rigTmp/helperGaps.tsv"
rigGaps="$( LC_ALL=C wc -l < "$rigTmp/helperGaps.tsv" | tr -d ' ' )"
rigAssert "a moved helper's include sources what its body calls" "$rigGaps" "0"
[ "$rigGaps" = "0" ] || LC_ALL=C head -20 "$rigTmp/helperGaps.tsv" | LC_ALL=C sed 's/^/        /' >&2

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ IN-CONTEXT HELPER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  fix:  source the helper's include at the top of the function that calls it, or at the top of the file" >&2
	exit 1
fi
printf 'IN_CONTEXT_HELPER: OK (%d assertions, offline, %d helpers)\n' "$rigPasses" "$( LC_ALL=C wc -l < "$rigHelpers" | tr -d ' ' )"
