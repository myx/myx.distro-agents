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
mkdir -p "$rigTmp/ws" "$rigTmp/ws/.local/agents/members/keeper-rig" "$rigTmp/ws/.local/agents/members/magic-team"
printf '# keeper-rig\n' > "$rigTmp/ws/.local/agents/members/keeper-rig/SKILL.md"
printf '# keeper-rig\n' > "$rigTmp/ws/.local/agents/members/keeper-rig/keeper-rig.armed.md"
printf '# magic-team\n' > "$rigTmp/ws/.local/agents/members/magic-team/SKILL.md"
printf '# magic-team\n' > "$rigTmp/ws/.local/agents/members/magic-team/magic-team.armed.md"

rigOut="$( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --member-help keeper-rig 2>/dev/null )" || rigRefuse "--member-help keeper-rig failed"

## One row per printed syntax line: PASS or FAIL, then the line. An entry is a run of
## syntax lines and the text under them, and its printed text must equal the manual's.
rigRows="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsMemberHelpEntryTextCompare.awk" "$rigManual" - )"

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
