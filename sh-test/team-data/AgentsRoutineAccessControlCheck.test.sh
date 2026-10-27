#!/usr/bin/env bash
## Behavioural check on the routine key `access-control:` (epic S18.5; owner 2026-10-27: one grant grammar everywhere). A routine grants and refuses its
## participants tools and paths by one frontmatter line of rows `<member|executors|participants>:<verb>:<value>`, the verbs the project.inf rows have:
## allow-read, allow-write, allow-tool and their twins deny-read, deny-write, deny-tool. The keys it replaces, `allows:` and `denies:`, are gone, with no alias:
## the routine validator refuses a routine that still has one and names the key to write. Held, each as the verdict of the real validator on a rig routine:
##   1. a routine with rows of each of the six verbs passes;
##   2. a routine with `allows:` is refused, the answer naming `access-control:` and the line;
##   3. a routine with `denies:` is refused the same way;
##   4. a row with a verb that is none of the six, a row with no value and a row that names no member are refused, each on the line of the key;
##   5. a routine with no access-control passes as it did.
## Offline: rig files only; the validator is read-only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTesting="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"
rigKinds="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTesting" ] || rigRefuse "the testing file is not at the origin this workspace resolves: $rigTesting"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineAccessControlCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-a"
cp "$rigKinds/magic-team.standalone.routine.md" "$rigKinds/magic-team.coworking.routine.md" "$rigTmp/skills/magic-team/" || rigRefuse "the kind routines could not be copied into the rig"
printf 'rig\n' > "$rigTmp/skills/rig-a/rig-a.basic.md" ; printf 'rig\n' > "$rigTmp/skills/rig-a/rig-a.armed.md"
rigPass=0 rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRoutine(){ ## name, the lines of the key (may be empty)
	{
		printf -- '---\ntype: routine\nexecutors: rig-a\nmaintainers: human-owner\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigTmp/skills/magic-team/magic-team.$1.routine.md"
}
rigValidate(){ ## name -- rc in rigRc, both streams in $rigTmp/said
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTesting" --skillset-validate-routine "$rigTmp/skills/magic-team/magic-team.$1.routine.md" ) > "$rigTmp/said" 2>&1 < /dev/null || rigRc=$?
}
rigSaid(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/said" || : ; }

echo "-- 1. the six verbs pass --"
rigRoutine six 'access-control: participants:allow-read:docs/**, participants:allow-write:out/**, executors:allow-tool:WebFetch, participants:deny-read:docs/secret/**, participants:deny-write:out/no/**, rig-a:deny-tool:WebSearch'
rigValidate six
rigAssert "a routine with a row of each verb" "$rigRc" 0

echo "-- 2. and 3. the keys they replace are refused, naming the key to write --"
rigRoutine old 'allows: participants:WebSearch' ; rigValidate old
rigAssert "allows: is refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo passed ):$( rigSaid 'is no key of a routine any more' )" "refused:1"
rigRoutine olddeny 'denies: WebSearch' ; rigValidate olddeny
rigAssert "denies: is refused" "$( [ "$rigRc" -ne 0 ] && echo refused || echo passed ):$( rigSaid 'is no key of a routine any more' )" "refused:1"

echo "-- 4. a row of a wrong shape is refused --"
rigRoutine badverb 'access-control: participants:allow-everything:x' ; rigValidate badverb
rigAssert "a verb that is none of the six" "$( [ "$rigRc" -ne 0 ] && echo refused || echo passed ):$( rigSaid 'allow-everything' )" "refused:1"
rigRoutine novalue 'access-control: participants:allow-tool:' ; rigValidate novalue
rigAssert "a row with no value" "$( [ "$rigRc" -ne 0 ] && echo refused || echo passed )" "refused"
rigRoutine nowho 'access-control: allow-tool:WebSearch' ; rigValidate nowho
rigAssert "a row that names no member" "$( [ "$rigRc" -ne 0 ] && echo refused || echo passed )" "refused"

echo "-- 5. no access-control --"
rigRoutine none '' ; rigValidate none
rigAssert "a routine with none passes" "$rigRc" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ROUTINE ACCESS CONTROL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_ACCESS_CONTROL: OK (%d assertions, offline, rig files only)\n' "$rigPass"
