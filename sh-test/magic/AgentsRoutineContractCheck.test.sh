#!/usr/bin/env bash
## Check over the routine contract and its sections (F5.4 of the refactorings epic). F5.4 lands its contract and its
## template only; the 47-file edit is F6.7's sweep (AgentsRoutineSweepCheck). Read over the package's skillset, and
## run once: `--manager-routine-list` over a rig skillset.
## Held:
##   1. templates/routine.contract.format.md, its Frontmatter line: names type:, requires-session-kind:, the optional
##      tracking-item:, operations: and start-context: (F6.1: flat keys, a key left out meaning any), and the autorun
##      keys `runs-at:` (an explicit `none` where a routine never auto-runs) and `runs-after:` (open-names 22, 23: no
##      one-word key);
##      and names none of `session:`, `default-for-session-kind:` and `requires:` (there is no requires: line)
##   2. the contract says --manager-routine-list prints requires-session-kind:, not session:
##   3. the contract lists `# Opening steps` among a routine's sections, and the template's own skeleton carries the
##      three headings `# Opening steps`, `# Steps`, `# Closure steps`, in that order
##   4. the contract names the four verbs: validate, automate, help, reject
##   5. `default-for-session-kind:` is gone: no skillset file carries it as a frontmatter key
##   6. every routine file carries `# Routine's local procedures` (today magic-team.handback-review lacks it)
##   7. run: --manager-routine-list prints a routine's requires-session-kind: value in its session field
## Red before F5.4: the contract names session: and default-for-session-kind: and no Opening steps, two files carry
## default-for-session-kind:, handback-review lacks its heading, and the listing reads only session:.
## Not tested, for want of a name: the autorun trigger key, which takes an explicit `none` (open-names.md, F5.4).
## Offline: the package is read, and the rig skillset alone is listed.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigSkillset="$rigPackage/skillset"
rigContract="$rigSkillset/magic-team/magic-team/templates/routine.contract.format.md"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigContract" ] || rigRefuse "no routine contract at the origin this workspace resolves: $rigContract"
[ -f "$rigTool" ] || rigRefuse "no dispatcher at the origin: $rigTool"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsRoutineContractCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigFront(){ ## file -- its first frontmatter block
	LC_ALL=C awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"
}
rigFrontLine="$( LC_ALL=C grep -m 1 -E '^- Frontmatter:' "$rigContract" )"
rigHas(){ ## text, fixed string -- yes or no
	if printf '%s\n' "$1" | LC_ALL=C grep -q -F -- "$2" ; then printf 'yes' ; else printf 'no' ; fi
}

echo "-- control: the contract has its Frontmatter line, and the routine files are found --"
find "$rigSkillset" -name '*.routine.md' -type f | LC_ALL=C sort > "$rigTmp/routines"
rigAssert "the Frontmatter line is there, and 20 routine files or more" "$( [ -n "$rigFrontLine" ] && echo line || echo none ) $( [ "$( LC_ALL=C grep -c . "$rigTmp/routines" )" -ge 20 ] && echo files || echo few )" "line files"

echo "-- 1. the Frontmatter line --"
rigAssert "names type:, requires-session-kind:, tracking-item:, operations:, start-context:, runs-at: and runs-after:" \
	"$( rigHas "$rigFrontLine" '`type:`' ) $( rigHas "$rigFrontLine" '`requires-session-kind:`' ) $( rigHas "$rigFrontLine" '`tracking-item:`' ) $( rigHas "$rigFrontLine" '`operations:`' ) $( rigHas "$rigFrontLine" '`start-context:`' ) $( rigHas "$rigFrontLine" '`runs-at:`' ) $( rigHas "$rigFrontLine" '`runs-after:`' )" "yes yes yes yes yes yes yes"
rigAssert "names no one-word autorun key: neither autorun: nor after:" \
	"$( rigHas "$rigFrontLine" '`autorun:`' ) $( rigHas "$rigFrontLine" '`after:`' )" "no no"
rigAssert "names none of session:, default-for-session-kind: and requires:" \
	"$( rigHas "$rigFrontLine" '`session:`' ) $( rigHas "$rigFrontLine" '`default-for-session-kind:`' ) $( rigHas "$rigFrontLine" '`requires:`' )" "no no no"

echo "-- 2. the listing the contract describes --"
rigListLine="$( LC_ALL=C grep -m 1 -F -- '--manager-routine-list' "$rigContract" )"
rigAssert "the line naming --manager-routine-list names requires-session-kind:, not session:" \
	"$( rigHas "$rigListLine" '`requires-session-kind:`' ) $( rigHas "$rigListLine" '`session:`' )" "yes no"

echo "-- 3. the three section headings --"
rigAssert "the contract lists # Opening steps among the sections" "$( LC_ALL=C grep -c -x -F -- '- `# Opening steps`' "$rigContract" )" "1"
rigAssert "the skeleton carries the three headings, in order, each once" \
	"$( LC_ALL=C grep -E -x '# (Opening steps|Steps|Closure steps)' "$rigContract" | LC_ALL=C tr '\n' '|' )" "# Opening steps|# Steps|# Closure steps|"

echo "-- 4. the four verbs --"
rigAssert "validate, automate, help and reject are each named"  "$( for rigVerb in validate automate help reject ; do LC_ALL=C grep -q -F -- "\`$rigVerb\`" "$rigContract" && printf '%s ' "$rigVerb" ; done )" "validate automate help reject "

echo "-- 5. default-for-session-kind: is gone --"
rigAssert "no skillset file carries it as a frontmatter key"    "[$( find "$rigSkillset" -name '*.md' -type f | LC_ALL=C sort | while IFS= read -r rigFile ; do rigFront "$rigFile" | LC_ALL=C grep -q '^default-for-session-kind:' && printf ' %s' "${rigFile##*/}" ; done )]" "[]"

echo "-- 6. # Routine's local procedures in every routine file --"
rigAssert "the routine files lacking it"                         "[$( while IFS= read -r rigFile ; do LC_ALL=C grep -q -x -F "# Routine's local procedures" "$rigFile" || printf ' %s' "${rigFile##*/}" ; done < "$rigTmp/routines" )]" "[]"

echo "-- 7. --manager-routine-list prints requires-session-kind: --"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills/keeper-rig"
printf -- '---\nname: keeper-rig\ndescription: rig\n---\nrig\n' > "$rigTmp/skills/keeper-rig/SKILL.md"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: keeper-rig\ninvitees: \nrequires-session-kind: coworking\n---\n# keeper-rig.alpha.routine — the actual procedure\n\n# Opening steps\n\n# Steps\n\n# Closure steps\n\n# Routine'"'"'s local procedures\n' > "$rigTmp/skills/keeper-rig/keeper-rig.alpha.routine.md"
( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" --manager-routine-list ) > "$rigTmp/list" 2> "$rigTmp/list.err" < /dev/null
rigAssert "its row is listed, and its session field holds coworking" "$( LC_ALL=C awk -F'\t' '$1 == "routine" && $2 == "keeper-rig.alpha.routine.md" { print "listed", $6 }' "$rigTmp/list" )" "listed coworking"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE CONTRACT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_CONTRACT: OK (%d assertions, offline)\n' "$rigPassCount"
