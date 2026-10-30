#!/usr/bin/env bash
## Behavioural check on the Bash tool's cwd gate (S18.1): a cwd outside the allowed access-root set
## is refused through the one shared refusal path (AgentsHarnessRefusal), carrying a REFUSAL-ID and
## the way to ask for it, the same as every other tool's path refusal -- not a bare message of its
## own. Held, for both the detached and the foreground call shape:
##   1. a detached call (background: true) with a cwd outside the roots carries a REFUSAL-ID.
##   2. a foreground call with a cwd outside the roots carries a REFUSAL-ID.
## Offline: a shell of this box, no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashCwdRefusalHintCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/inside" "$rigTmp/outside" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## argument object, call name
	( cd "$rigTmp/ws" && printf '%s' "$1" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp/inside" --access-write-root "$rigTmp/inside" ) \
		> "$rigTmp/$2.out" 2> "$rigTmp/$2.err" || :
}
rigHasId(){ ## call name
	LC_ALL=C grep -c -E '^REFUSAL-ID: (refusal-|none --)' "$rigTmp/$1.out" "$rigTmp/$1.err" 2> /dev/null | LC_ALL=C awk -F: '{ s += $2 } END { print s + 0 }'
}

echo "-- 1. a detached call with a cwd outside the roots carries a REFUSAL-ID --"
rigCall "{\"command\":\"echo hi\",\"cwd\":\"$rigTmp/outside\",\"background\":true}" detached
rigAssert "refused, carrying a REFUSAL-ID" "$( rigHasId detached )" 1

echo "-- 2. a foreground call with a cwd outside the roots carries a REFUSAL-ID --"
rigCall "{\"command\":\"echo hi\",\"cwd\":\"$rigTmp/outside\"}" foreground
rigAssert "refused, carrying a REFUSAL-ID" "$( rigHasId foreground )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH CWD REFUSAL HINT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a Bash cwd outside the allowed roots is refused with a bare message, naming no owner and no way to ask" >&2
	echo "  fix:  repair sh-lib/harness/AgentsHarnessToolsBash.include -- never the assertion" >&2
	exit 1
fi
printf 'BASH_CWD_REFUSAL_HINT: OK (%d assertions, offline)\n' "$rigPassCount"
