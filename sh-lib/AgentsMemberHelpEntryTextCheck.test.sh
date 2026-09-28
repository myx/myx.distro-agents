#!/usr/bin/env bash
## Behavioural check on --member-help, run rather than read, against a scenario skillset
## built here. Holds: every help entry --member-help prints carries the same text the
## manual gives it, an entry with several syntax lines included. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigManual="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.help.md"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigManual" ] || rigRefuse "the manual is not at the origin this workspace resolves: $rigManual"

rigTmp="$( mktemp -d -t "AgentsMemberHelpEntryTextCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws" "$rigTmp/home/.claude/skills/keeper-rig" "$rigTmp/home/.claude/skills/magic-team"
printf '# keeper-rig\n' > "$rigTmp/home/.claude/skills/keeper-rig/SKILL.md"
printf '# keeper-rig\n' > "$rigTmp/home/.claude/skills/keeper-rig/keeper-rig.armed.md"
printf '# magic-team\n' > "$rigTmp/home/.claude/skills/magic-team/SKILL.md"
printf '# magic-team\n' > "$rigTmp/home/.claude/skills/magic-team/magic-team.armed.md"

rigOut="$( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --member-help keeper-rig 2>/dev/null )" || rigRefuse "--member-help keeper-rig failed"

## One row per printed syntax line: PASS or FAIL, then the line. An entry is a run of
## syntax lines and the text under them, and its printed text must equal the manual's.
rigRows="$( printf '%s\n' "$rigOut" | LC_ALL=C awk '
	FNR == NR {
		if ( $0 ~ /^## / ) { inOptions = ( $0 ~ /^##  Options:/ ) ; headerTotal = 0 ; next ; }
		if ( ! inOptions ) { next ; }
		if ( $0 ~ /^\t\t--/ ) {
			if ( ! inHeaders ) { headerTotal = 0 ; }
			inHeaders = 1 ;
			if ( !( $0 in manualText ) ) { headerList[++headerTotal] = $0 ; manualText[$0] = "" ; }
			next ;
		}
		inHeaders = 0 ;
		for ( headerIndex = 1 ; headerIndex <= headerTotal ; headerIndex++ ) { manualText[headerList[headerIndex]] = manualText[headerList[headerIndex]] $0 "\n" ; }
		next ;
	}
	## Trailing blank lines are not compared: the capture above strips them from the last entry.
	function flushEntry(    headerIndex, wantText ) {
		sub( /\n+$/, "", shownText ) ;
		for ( headerIndex = 1 ; headerIndex <= shownTotal ; headerIndex++ ) {
			if ( !( shownList[headerIndex] in manualText ) ) { print "FAIL\t" substr( shownList[headerIndex], 3 ) ; continue ; }
			wantText = manualText[shownList[headerIndex]] ;
			sub( /\n+$/, "", wantText ) ;
			print ( wantText == shownText ? "PASS" : "FAIL" ) "\t" substr( shownList[headerIndex], 3 ) ;
		}
		shownTotal = 0 ; shownText = "" ;
	}
	$0 ~ /^\t\t--/ {
		if ( ! shownHeaders ) { flushEntry() ; }
		shownHeaders = 1 ;
		shownList[++shownTotal] = $0 ;
		next ;
	}
	shownTotal > 0 { shownHeaders = 0 ; shownText = shownText $0 "\n" ; }
	END { flushEntry() ; }
' "$rigManual" - )"

## The two entries this check was written for have to be among those measured, each
## with both of its syntax lines.
for rigName in --member-comms-google-file-find --member-wait-for-input ; do
	rigHits="$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' -v want="$rigName" '{ split( $2, word, " " ) ; if ( word[1] == want ) { hits++ ; } } END { print hits + 0 ; }' )"
	[ "$rigHits" -gt 0 ] || rigRefuse "$rigName is not printed at all, so its entry would not be measured"
	[ "$rigHits" -ge 2 ] || rigRows="$rigRows"$'\n'"FAIL	$rigName: printed with $rigHits of its 2 syntax lines"
done

rigFails="$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' '$1 == "FAIL" { printf "  FAIL  %s\n", $2 ; }' )"
rigPasses="$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' '$1 == "PASS" { total++ ; } END { print total + 0 ; }' )"
if [ -n "$rigFails" ] ; then
	printf '%s\n' "$rigFails"
	echo "⛔ MEMBER HELP ENTRY TEXT CHECK FAILED: printed text differs from the manual's under the syntax lines above" >&2 ; exit 1
fi
printf 'MEMBER_HELP_ENTRY_TEXT: OK (%d syntax lines, offline)\n' "$rigPasses"