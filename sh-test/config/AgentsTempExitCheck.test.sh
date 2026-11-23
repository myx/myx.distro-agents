#!/usr/bin/env bash
## Behavioural check on the temp files a tool makes: every one of them goes, whatever ends the shell.
## Held, both ends of one observation: a shell that claims two files under the rig's own .local/temp and
## is then ended by SIGTERM leaves that folder empty, and the same shell ended by its own return leaves it
## empty too. The claim is the one the design names: sh-lib/common/AgentsTools.TempFiles.include, with
## AgentsToolsTempClaim, AgentsToolsTempRelease and AgentsToolsTempArm.
## Red before the build: no claim exists, so the two files made between the mktemp and the rm survive both
## ends, and the assertion reads 2:2 where it wants 0:0.
## Offline: a stub shell of this check's own, and a rig workspace of this check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/common/AgentsTools.TempFiles.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/sh-lib/common" ] || rigRefuse "the package's sh-lib/common is not at the origin this workspace resolves: $rigPackage/sh-lib/common"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTempExitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigProcSignal TERM "$rigStubPid" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws"
rigTemp="$rigWs/.local/temp"
rigHoldDir="$rigTmp/hold"
mkdir -p "$rigTemp" "$rigHoldDir" "$rigWs/.local/agents" || exit 1

## THE STUB: one temp family, as the build leaves it. It makes its two files inside the rig's .local/temp,
## claims them, and then waits to be ended from outside. Its hold stands outside that folder, so the count
## the assertion reads has the tooling's own entries only. The hold is a pipe the stub holds both ends of,
## a shell builtin, so the stub has no child of its own and nothing of it can outlive the check. Its second
## end is its own return, the same observation by the other exit path.
cat > "$rigTmp/claim-stub.sh" <<'RIG-STUB'
set -u
rigDir="$1" rigInclude="$2" rigEnd="$3" rigHoldDir="$4"
: > "$rigDir/mdat-rig-one.tmp" || exit 1
: > "$rigDir/mdat-rig-two.tmp" || exit 1
if [ -f "$rigInclude" ] ; then
	. "$rigInclude" || exit 1
fi
if type AgentsToolsTempClaim > /dev/null 2>&1 ; then
	AgentsToolsTempClaim "$rigDir/mdat-rig-one.tmp" "$rigDir/mdat-rig-two.tmp" || exit 1
else
	echo "RIG-NO-CLAIM: $rigInclude holds no AgentsToolsTempClaim" >&2
fi
echo "RIG-CLAIMED"
[ "$rigEnd" != return ] || exit 0
rigHold="$rigHoldDir/hold.fifo"
mkfifo "$rigHold" || exit 1
exec 9<>"$rigHold"
read -r -t 120 -u 9 rigLine
RIG-STUB

rigLeft(){ ## -- how many entries stand directly under the rig's .local/temp
	find "$rigTemp" -mindepth 1 -maxdepth 1 2> /dev/null | LC_ALL=C grep -c . || :
}
rigFresh(){ ## -- the rig's .local/temp, empty, and a fresh hold folder, for the end that follows
	rm -rf "$rigTemp" "$rigHoldDir" || exit 1
	mkdir -p "$rigTemp" "$rigHoldDir" || exit 1
}

echo "-- 1. ended by SIGTERM --"
rigFresh
bash "$rigTmp/claim-stub.sh" "$rigTemp" "$rigInclude" wait "$rigHoldDir" > "$rigTmp/term.out" 2> "$rigTmp/term.err" &
rigStubPid=$!
rigProcNote "$rigStubPid"
rigReady=""
for rigTurn in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 ; do
	LC_ALL=C grep -q 'RIG-CLAIMED' "$rigTmp/term.out" 2> /dev/null && { rigReady=yes ; break ; }
	sleep 0.2
done
[ -n "$rigReady" ] || rigRefuse "the claim stub never reached its claim, so nothing was measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/term.err" )"
[ "$( rigLeft )" = 2 ] || rigRefuse "the stub left $( rigLeft ) entries rather than the two it made, so the signal has nothing to remove"
rigProcSignal TERM "$rigStubPid" 2> /dev/null || :
wait "$rigStubPid" 2> /dev/null || :
rigAfterTerm="$( rigLeft )"

echo "-- 2. ended by its own return --"
rigFresh
bash "$rigTmp/claim-stub.sh" "$rigTemp" "$rigInclude" return "$rigHoldDir" > "$rigTmp/return.out" 2> "$rigTmp/return.err" || :
rigAfterReturn="$( rigLeft )"
rigAssert "the rig's .local/temp is empty after SIGTERM and after a return" "$rigAfterTerm:$rigAfterReturn" "0:0"
[ ! -s "$rigTmp/term.err" ] || printf '  # the claim is not there yet, as the stub found it: %s\n' "$( LC_ALL=C sed -n 1p "$rigTmp/term.err" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEMP EXIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEMP_EXIT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
