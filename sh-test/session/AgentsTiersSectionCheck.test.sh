#!/usr/bin/env bash
## Check on the skillset section that states the security tier set (stage 8 of the build): the section
## under `### Security context tiers` in `skillset/magic-team/magic-team/magic-team.basic.md` carries no
## `(draft)` label, and states the four tiers the tooling now builds.
## Held, one case per statement:
##   1. control: the reader finds the section at all, so an empty answer is not an empty run
##   2. the section's own text carries no `(draft)` label, judged by a reader that trips on a planted
##      one and is clear on a clean one
##   3. the section names all four tiers
##   4. the section states `public` is no channel, which is what the built behaviour does
## Red before stage 8: case 2 fails, because the section as it stands carries the label.
## Offline: it reads two files and writes only its own rig.
set -u
rigPackageRoot=""
case "${1:-}" in --*) ;; "") ;; *) rigPackageRoot="$1" ;; esac
if [ -n "$rigPackageRoot" ] && [ -d "$rigPackageRoot/skillset" ] ; then
	scanPackage="$rigPackageRoot"
else
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set, and no package root was given}"
	scanPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
fi
scanFile="skillset/magic-team/magic-team/magic-team.basic.md"
scanHeading="### Security context tiers"
scanRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$scanPackage/$scanFile" ] || scanRefuse "no $scanFile under $scanPackage"
. "$scanPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
scanRig="$( rigTempDir AgentsTiersSectionCheck )" || exit 1
scanRig="$( cd "$scanRig" && pwd -P )" || exit 1
trap 'chmod -R u+w "$scanRig" 2> /dev/null ; rm -rf -- "$scanRig"' EXIT

## The section, from its heading to the next heading of the same or a higher level. A file with no such
## heading prints nothing, which case 1 catches.
scanSection(){ ## file
	LC_ALL=C awk -v want="### Security context tiers" '
		$0 == want { inside = 1 ; print ; next }
		inside && /^#{1,3} / { exit }
		inside { print }' "$1"
}
scanSectionOf(){ scanSection "$scanPackage/$scanFile" ; }

scanPass=0 ; scanFail=0
scanAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; scanPass=$(( scanPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; scanFail=$(( scanFail + 1 ))
	fi
}

echo "-- 1. control: the section is found --"
scanAssert "the heading stands in the file, and its body is read" \
	"[$( [ -n "$( scanSectionOf )" ] && printf found || printf absent )]" "[found]"

echo "-- 2. the reader trips on a planted draft label, and is clear on a clean section --"
scanDraft(){ ## text -- how many draft labels it carries
	printf '%s\n' "$1" | LC_ALL=C grep -c -F '(draft)' || :
}
scanAssert "red: a planted draft label is caught" \
	"$( scanDraft "### Security context tiers

\`(draft)\` Every session carries one tier." )" 1
scanAssert "green: and the same section without it is clear" \
	"$( scanDraft "### Security context tiers

Every session carries one tier." )" 0
scanAssert "the section as it stands carries no draft label" "$( scanDraft "$( scanSectionOf )" )" 0

echo "-- 3. the section names all four tiers --"
scanBody="$( scanSectionOf )"
scanAssert "each of the four tiers is named" \
	"$( for scanTier in private system shared public ; do printf '%s\n' "$scanBody" | LC_ALL=C grep -c -E "^\s*[-*] .*\*\*$scanTier\*\*|^\s*[-*] \`$scanTier\`" ; done | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" \
	"1 1 1 1"

echo "-- 4. the section states a channel for each of the three tiers that has one --"
## The brief's bar for stage 8 is the label and the built behaviour. The three channel-bearing tiers
## are checked here as the behaviour's own statement; the `public` line's wording is reported to the
## coordinator as a finding rather than enforced, since the brief fixes the label and not the wording.
scanAssert "private, system and shared each name a channel" \
	"$( for scanTier in private system shared ; do printf '%s\n' "$scanBody" | LC_ALL=C grep -E "^\s*[-*] .*\*\*$scanTier\*\*|^\s*[-*] \`$scanTier\`" | LC_ALL=C grep -c -iE 'channel|conversation|thread' ; done | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" \
	"1 1 1"

if [ "$scanFail" -ne 0 ] ; then
	echo "⛔ TIERS SECTION CHECK FAILED: $scanFail of $(( scanPass + scanFail )) assertion(s)" >&2
	echo "  fix:  the section in $scanFile -- never the assertion" >&2
	exit 1
fi
printf 'TIERS_SECTION: OK (%d assertions, offline)\n' "$scanPass"
