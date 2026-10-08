#!/usr/bin/env bash
## A served call with MDAT_SKILLSET_ROOT unset reads its identity from the fallback, the
## workspace's own member index view ($MMDAPP/.local/agents/members), says so, and works;
## with no member there it refuses naming the path it tried -- a member linked in the
## vendor folder $HOME/.claude/skills is never read; with the root set it says nothing
## about a fallback. Wait is the probe: it needs an
## identity and, on a file source with a one-second bound, reaches nothing off this box.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHarness="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
rigTmp="$( mktemp -d -t AgentsHarnessIdentityFallbackCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/ws/.local/agents/members/$rigMember" "$rigTmp/home/.claude/skills/$rigMember" "$rigTmp/bare/.local"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/ws/.local/agents/members/$rigMember/$rigMember.basic.md"
cp "$rigTmp/ws/.local/agents/members/$rigMember/$rigMember.basic.md" "$rigTmp/home/.claude/skills/$rigMember/"
: > "$rigTmp/src"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigWait(){ ## result file, workspace, then env assignments or -u NAME for this call
	local waitOut="$1" waitWs="$2" ; shift 2
	printf '{"sources":"file:%s","timeout":"1"}' "$rigTmp/src" | env -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SKILLSET_ROOT "$@" \
		MMDAPP="$waitWs" MDAT_SPAWN_AGENT="$rigMember" HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig \
		bash "$rigHarness" --intern-tool Wait > "$waitOut" 2> "$waitOut.err" || :
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}

echo "-- root unset, the member in the workspace's member index --"
rigWait "$rigTmp/a" "$rigTmp/ws" HOME="$rigTmp/home"
rigAssert "the fallback is stated"                     "$( rigHolds "$rigTmp/a.err" "the served identity is read from the fallback $rigTmp/ws/.local/agents/members" )" yes
rigAssert "and the identity it names works: the wait runs" "$( head -1 "$rigTmp/a" )" "WAIT-RESULT: TIMEOUT"

echo "-- root unset, no member index, the member only in the vendor folder under HOME --"
rigWait "$rigTmp/b" "$rigTmp/bare" HOME="$rigTmp/home"
rigAssert "the refusal names the path it tried"        "$( rigHolds "$rigTmp/b" "no team identity resolved: $rigTmp/bare/.local/agents/members/$rigMember/$rigMember.basic.md is not readable" )" yes

echo "-- control: root set --"
rigWait "$rigTmp/c" "$rigTmp/bare" MDAT_SKILLSET_ROOT="$rigTmp/ws/.local/agents/members" HOME="$rigTmp/bare"
rigAssert "no fallback is stated"                      "$( rigHolds "$rigTmp/c.err" 'read from the fallback' )" no
rigAssert "and the wait runs"                          "$( head -1 "$rigTmp/c" )" "WAIT-RESULT: TIMEOUT"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IDENTITY FALLBACK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_IDENTITY_FALLBACK: OK (%d assertions, offline)\n' "$rigPassCount"
