#!/usr/bin/env bash
## Behavioural check on the security tier's default per routine (stage 2 of the security context tier
## set), run rather than read, against a rig workspace and a rig skillset built here.
## Held, one case per statement:
##   1. control: a routine's `security-tier:` is read as its own value (`AgentsToolsRoutineSecurityTier`)
##   2. a routine that names none inherits its kind routine's value, as `requires-session-kind:` is inherited
##   3. a routine of a kind, and its kind routine, both silent: nothing is printed and rc 1, so the caller
##      states which default it used rather than reading a silence as a tier
##   4. a value that is none of the four is refused, as the record refuses one
##   5. the workspace setting `SECURITY_TIER_DEFAULT` is a declared changeable setting of the control
##      subject, with the four as what it takes
##   6. and it is not one of the settings the console takes a free number for
## Red before stage 2: cases 1 to 5 fail, and case 6 holds as the guard it is.
## Offline: it writes only its own rig, and reads the package at the origin.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRoutineInclude="$rigPackage/sh-lib/routine/AgentsTools.RoutineRequirements.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this run resolves: $rigTool"
[ -f "$rigRoutineInclude" ] || rigRefuse "the routine requirements include is not at the origin: $rigRoutineInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineSecurityTierCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigHome="$rigTmp/home"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$rigWs/.local/.agents" "$rigSkills/magic-team" "$rigHome" "$rigTmp/bin" || rigRefuse "cannot make the rig"
## The rig's own curl, so no case can reach a socket.
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

## The routine of each kind, and one routine of each kind. `requires-session-kind:` decides the kind,
## and the kind routine is the file the tooling's own list names for it.
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n---\n# rig coworking\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig standalone\n' \
	> "$rigSkills/magic-team/magic-team.standalone.routine.md"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One call of the routine's tier reader: `rigOut` its standard output, `rigRc` its status. A function
## the package does not define reads as `missing`, which no case accepts as a value.
rigOut="" ; rigRc=0
rigTier(){ ## routine file path
	rigOut="$( ( export MDAT_SKILLSET_ROOT="$rigSkills" ; . "$rigRoutineInclude" 2> /dev/null ; AgentsToolsRoutineSecurityTier "$1" ) 2> /dev/null )" ; rigRc=$?
	case "$rigRc" in 127) rigOut="missing" ;; esac
}
rigRoutine(){ ## file name, `security-tier:` value or - for none
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n' > "$rigSkills/magic-team/$1"
	[ "$2" = - ] || printf 'security-tier: %s\n' "$2" >> "$rigSkills/magic-team/$1"
	printf -- '---\n# %s\n' "$1" >> "$rigSkills/magic-team/$1"
}

echo "-- 1. control: a routine's own key is its tier --"
rigRoutine rig-own.routine.md private
rigTier "$rigSkills/magic-team/rig-own.routine.md"
rigAssert "a routine naming private reads as private" "$rigOut" private

echo "-- 2. a routine that names none inherits its kind routine's --"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\nsecurity-tier: shared\n---\n# rig coworking\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
rigRoutine rig-kin.routine.md -
rigTier "$rigSkills/magic-team/rig-kin.routine.md"
rigAssert "a routine silent on the key takes its kind routine's shared" "$rigOut" shared

echo "-- 3. both silent: nothing printed, rc 1 --"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n---\n# rig coworking\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
rigTier "$rigSkills/magic-team/rig-kin.routine.md"
rigAssert "nothing is printed where neither names a tier" "$rigOut" ""
rigAssert "and the answer is rc 1, so no caller reads a silence as a tier" "$rigRc" 1

echo "-- 4. a value that is none of the four is refused --"
rigRoutine rig-bad.routine.md secret
rigTier "$rigSkills/magic-team/rig-bad.routine.md"
rigAssert "a fifth word is refused, rc 1, and prints nothing a caller could take as a tier" "$rigRc:$rigOut" "1:"

echo "-- 5. SECURITY_TIER_DEFAULT is a declared changeable setting, choice-kind --"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSECURITY_TIER_DEFAULT=private\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigDigest(){ ## subject... -- the tool's own digest line for the tier setting, empty when it has none
	env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$rigTmp/bin:$rigPath" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --manager-config-digest --full "$@" 2> /dev/null || :
}
## The tier setting has two rows in the digest: the scope key under `scopes`, and the changeable setting
## under `control`. The row this case is about is the control one, so it is selected by its group and
## its key, never by the first line that carries the key.
rigRow="$( rigDigest | LC_ALL=C awk -F'\t' '$2 == "control" && $4 == "SECURITY_TIER_DEFAULT"' | head -1 )"
rigScopeRow="$( rigDigest | LC_ALL=C awk -F'\t' '$2 == "scopes" && $4 == "SECURITY_TIER_DEFAULT"' | head -1 )"
rigAssert "control: the digest carries the same key as a scope key too, so the row below is selected and not merely found" \
	"[$( [ -n "$rigScopeRow" ] && printf present || printf absent )]" "[present]"
rigAssert "the digest lists the tier default, with the value the workspace saved" \
	"$( printf '%s\n' "$rigRow" | LC_ALL=C awk -F'\t' '{ print $6 }' )" private
rigAssert "as a changeable setting" \
	"$( printf '%s\n' "$rigRow" | LC_ALL=C awk -F'\t' '{ print $9 }' )" yes
rigAssert "whose kind is a choice" \
	"$( printf '%s\n' "$rigRow" | LC_ALL=C awk -F'\t' '{ print $10 }' )" choice
rigAssert "and what it takes is the four tiers" \
	"$( printf '%s\n' "$rigRow" | LC_ALL=C awk -F'\t' '{ print $13 }' | LC_ALL=C tr ',' '\n' | LC_ALL=C sed -n 's/=.*//p' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" \
	"private public shared system"

echo "-- 6. control: the console's free-number settings are still numbers --"
rigNumberRow="$( rigDigest | LC_ALL=C grep -F 'SESSION_CONTROL_KILL_SECONDS' | head -1 )"
rigAssert "a number setting is not offered the tiers" \
	"$( printf '%s\n' "$rigNumberRow" | LC_ALL=C awk -F'\t' '{ print $10 }' )" number

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ROUTINE SECURITY TIER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the routine key and the settings row -- never the assertion" >&2
	exit 1
fi
printf 'ROUTINE_SECURITY_TIER: OK (%d assertions, offline)\n' "$rigPass"
