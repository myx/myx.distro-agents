#!/usr/bin/env bash
## The reload a supervisor marks (--supervise-reload-due) reaches the run: its Wait answers RELOAD first while the mark stands, and a whole
## read of its own Skill records skill.loaded and clears the mark, so the next Wait waits as before. Offline: a temp workspace and skillset,
## each call one served tool of the harness under one `env -i`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin: $rigHarness"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReloadDueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data" ; rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigSkills/rig-member" "$rigSkills/magic-team" "$rigData" "$rigHome" "$rigTmp/bin"
printf -- '---\nname: rig-member\ndescription: rig\n---\nrig skill\n' > "$rigSkills/rig-member/SKILL.md"
for rigMember in rig-member magic-team ; do
	printf -- '---\nmaintainers: rig\n---\nrig %s basic\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig %s armed\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nname: magic-team\ndescription: rig\n---\nrig team\n' > "$rigSkills/magic-team/SKILL.md"
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigCall(){ ## result name, tool, argument object -- one served call of rig-member's run rig-run-reload
	( cd "$rigWs" && printf '%s' "$3" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=rig-run-reload \
		bash "$rigHarness" --intern-tool "$2" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
}
## The run's two files, by the session store's layout (.local/agents/sessions/<run>/), so a tree without them still reaches the rows below.
rigMark="$rigWs/.local/agents/sessions/rig-run-reload/reload.due" ; rigLoaded="$rigWs/.local/agents/sessions/rig-run-reload/skill.loaded"

echo "-- 1. a run whose reload is marked: its Wait answers RELOAD first, naming the file --"
mkdir -p "${rigMark%/*}" && printf '%s\t%s\n' 'skillset/magic-team/magic-team.basic.md' '2026-11-18T10:00:00Z' > "$rigMark"
rigCall wait1 Wait '{"timeout":1}'
rigAssert "the answer is RELOAD, with the changed file" "$( LC_ALL=C grep -c -x 'WAIT-RESULT: RELOAD' "$rigTmp/wait1.out" ):$( LC_ALL=C grep -c -F 'magic-team.basic.md' "$rigTmp/wait1.out" )" "1:1"
rigCall wait2 Wait '{"timeout":1}'
rigAssert "and again at the next round, while the mark stands" "$( LC_ALL=C grep -c -x 'WAIT-RESULT: RELOAD' "$rigTmp/wait2.out" )" 1

echo "-- 2. a whole read of its own Skill records the reload and clears the mark --"
rigCall skill Skill '{"skill":"rig-member"}'
rigAssert "the read is its skill" "$( LC_ALL=C grep -c -F 'rig rig-member basic' "$rigTmp/skill.out" )" 1
rigAssert "skill.loaded written, the mark gone" "$( [ -s "$rigLoaded" ] && echo loaded || echo none ):$( [ -f "$rigMark" ] && echo marked || echo cleared )" "loaded:cleared"
rigCall wait3 Wait '{"timeout":1}'
rigAssert "the next Wait waits as before: no RELOAD" "$( LC_ALL=C grep -c -x 'WAIT-RESULT: RELOAD' "$rigTmp/wait3.out" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ RELOAD DUE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'RELOAD_DUE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
