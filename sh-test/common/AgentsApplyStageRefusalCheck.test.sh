#!/usr/bin/env bash
## Behavioural check on the apply tool's staging refusal (DistroAgentsTesting.fn.sh, DistroAgentsTestingApplyDo): the tool is
## run as the world runs it, an executed script with set -e on. A live place the run may not stage beside must end the run at
## its own refusal, naming the file. Measured on the unguarded line 2026-11-25 17:2x +0200: the failed mktemp ended the script
## silently at rc 1, so the refusal its own guard prints was never reached. With the guard: rc 4 and the naming.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
tool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"
[ -f "$tool" ] || { echo "⛔ ERROR: no $tool" >&2 ; exit 1 ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsApplyStageRefusalCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigRepo="$rigTmp/repo"
rigLive="$rigRepo/source/myx/p/d"
rigScratch="$rigTmp/scratch"
mkdir -p "$rigWs/.local/temp" "$rigLive" "$rigScratch/base/myx/p/d" "$rigScratch/source/myx/p/d" || exit 1
printf 'one\ntwo\n' > "$rigLive/a.sh"
cp -p "$rigLive/a.sh" "$rigScratch/base/myx/p/d/a.sh"
printf 'one\nMINE\n' > "$rigScratch/source/myx/p/d/a.sh"
printf 'myx/p/d/a.sh\n' > "$rigScratch/changed-files.txt"
cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
printf 'myx/p\n' > "$rigScratch/packages.txt"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
chmod 555 "$rigLive"
MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$tool" --apply-tool apply --repository "$rigRepo" --scratch "$rigScratch" > "$rigTmp/out" 2>&1
rigRc=$?
chmod 755 "$rigLive"
rigAssert "the run ends at the abort, 4" "$rigRc" 4
rigAssert "and names the file it could not stage beside" "$( LC_ALL=C grep -c 'CANNOT STAGE beside myx/p/d/a.sh' "$rigTmp/out" 2> /dev/null || : )" 1
rigAssert "nothing was put in place" "$( LC_ALL=C grep -c MINE "$rigLive/a.sh" 2> /dev/null || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY STAGE REFUSAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'APPLY_STAGE_REFUSAL: OK (%d assertions, offline, throwaway rig)\n' "$rigPassCount"
