#!/usr/bin/env bash
## Behavioural check on the test runner's rig sweep (board task 20261107T1905Z; `--sweep-rigs-list` and `--sweep-rigs`
## in AgentsRunTests.sh). A check ended by KILL runs no trap, so its rig stays under .local/agents/scratch/sh-test until a
## sweep removes it. Held, run rather than read, over a rig folder of this check's own throwaway workspace:
##   1. THE LIST FORM REMOVES NOTHING: it names the rigs that would go, and every folder is still there after it.
##   2. THE REMOVING FORM REMOVES an old rig and an old rig whose file is immutable and whose folder is read-only
##      (flags and modes cleared first), and says so a rig a line.
##   3. IT KEEPS a rig younger than the hours, a rig a live process names, and a rig holding a link that reaches a
##      source tree (the no-symlinks rule: a delete never runs over one), each kept one named with its reason, and the
##      source the link reaches is intact after the sweep.
##   4. A FILE THAT IS NO RIG FOLDER is named and left; a word where the hours should be is refused, rc 1.
## Red recipe: a runner that removes on the list form fails row 1; one that skips the flag clearing fails the frozen
## row; one that reads no process list fails the busy row; one that scans no links fails the link row.
## The link into source is made with /bin/ln: the guard ln a run puts first on PATH refuses it, as it should.
## Offline: a rig of this check alone, removed at its end; one `sleep` of its own, ended at its end.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigRunner="$rigOrigin/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] || rigRefuse "the package's sh-lib is not at the origin: $rigOrigin"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsSweepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigBusyPid=""
trap '[ -z "$rigBusyPid" ] || kill "$rigBusyPid" 2> /dev/null ; chflags -R nouchg "$rigTmp" 2> /dev/null ; chmod -R u+rwX "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## THE RIG FOLDER OF A THROWAWAY WORKSPACE, with one rig of each kind, the old ones dated 1 November.
rigWs="$rigTmp/ws"
rigRigs="$rigWs/.local/agents/scratch/sh-test"
mkdir -p "$rigRigs/OldCheck.aaaaaaaa/deep" "$rigRigs/YoungCheck.bbbbbbbb" "$rigRigs/LinkCheck.cccccccc" "$rigRigs/FrozenCheck.dddddddd" "$rigRigs/BusyCheck.eeeeeeee" || exit 1
echo old > "$rigRigs/OldCheck.aaaaaaaa/deep/f"
echo frozen > "$rigRigs/FrozenCheck.dddddddd/f"
chflags uchg "$rigRigs/FrozenCheck.dddddddd/f" 2> /dev/null || :
chmod 500 "$rigRigs/FrozenCheck.dddddddd"
/bin/ln -s "$rigOrigin/myx/myx.distro-agents/sh-lib" "$rigRigs/LinkCheck.cccccccc/into-source" || rigRefuse "the link into source could not be made for the rig"
echo stray > "$rigRigs/stray.out"
for rigOne in OldCheck.aaaaaaaa LinkCheck.cccccccc FrozenCheck.dddddddd BusyCheck.eeeeeeee ; do
	touch -t 202611010000 "$rigRigs/$rigOne" || exit 1
done
## A process that names the busy rig in its arguments for the life of this check: two commands, so bash does not exec the sleep alone.
bash -c "sleep 300 ; : $rigRigs/BusyCheck.eeeeeeee" < /dev/null > /dev/null 2>&1 &
rigBusyPid=$!
rigWaited=0
while [ "$rigWaited" -lt 20 ] && ! ps -A -ww -o args= 2> /dev/null | LC_ALL=C grep -q -F "$rigRigs/BusyCheck.eeeeeeee" ; do sleep 0.25 ; rigWaited=$(( rigWaited + 1 )) ; done
## The grep that reads the list names the rig in its own arguments too, so the control asks for one process at least.
rigAssert "control: a live process names the busy rig" "$( [ "$( ps -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -F "$rigRigs/BusyCheck.eeeeeeee" )" -ge 1 ] && printf named || printf none )" named

rigSweep(){ ## the form, then the hours -- the runner's output in rigOut, its rc in rigRc
	rigOut="$( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" bash "$rigRunner" "$1" "$2" 2>&1 )" ; rigRc=$?
	rigOut="${rigOut//$rigRigs\//}"
}
rigSaid(){ ## a text -- the count of the runner's lines holding it
	printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "$1"
}

echo "-- 1. the list form names what would go and removes nothing --"
rigSweep --sweep-rigs-list 24
rigAssert "rc 0, and the old, frozen and busy-named rigs are listed as would-remove where they qualify" "$rigRc:$( rigSaid 'would remove OldCheck.aaaaaaaa' ):$( rigSaid 'would remove FrozenCheck.dddddddd' ):$( rigSaid 'would remove BusyCheck.eeeeeeee' )" "0:1:1:0"
rigAssert "the busy rig and the link rig are kept, each with its reason" "$( rigSaid 'kept, a process names it: BusyCheck.eeeeeeee' ):$( rigSaid 'kept, a link in it reaches a source tree: LinkCheck.cccccccc' )" "1:1"
rigAssert "the young rig is neither listed nor kept-with-reason, and the file is named as no rig folder" "$( rigSaid 'YoungCheck.bbbbbbbb' ):$( rigSaid 'kept, no rig folder: stray.out' )" "0:1"
rigAssert "the summary counts two to remove, two kept, one young" "$( rigSaid '2 rig(s) would be removed, 2 kept (a process or a link), 1 younger than 24 hour(s)' )" 1
rigAssert "every folder is still there after the list" "$( ls -1 "$rigRigs" | LC_ALL=C grep -c . )" 6

echo "-- 2. the removing form removes the old and the frozen rig --"
rigSweep --sweep-rigs 24
rigAssert "rc 0, both are said removed" "$rigRc:$( rigSaid 'removed OldCheck.aaaaaaaa' ):$( rigSaid 'removed FrozenCheck.dddddddd' )" "0:1:1"
rigAssert "and both are gone" "$( [ -e "$rigRigs/OldCheck.aaaaaaaa" ] && printf old-there || printf old-gone ):$( [ -e "$rigRigs/FrozenCheck.dddddddd" ] && printf frozen-there || printf frozen-gone )" "old-gone:frozen-gone"
rigAssert "the summary counts two removed, none failed, two kept, one young" "$( rigSaid '2 rig(s) removed, 0 could not be, 2 kept (a process or a link), 1 younger than 24 hour(s)' )" 1

echo "-- 3. the young, the busy and the link rig stay, and the source is intact --"
rigAssert "the young rig stays" "$( [ -d "$rigRigs/YoungCheck.bbbbbbbb" ] && printf there || printf gone )" there
rigAssert "the busy rig stays, named with its reason" "$( [ -d "$rigRigs/BusyCheck.eeeeeeee" ] && printf there || printf gone ):$( rigSaid 'kept, a process names it: BusyCheck.eeeeeeee' )" "there:1"
rigAssert "the link rig stays with its link, named with its reason" "$( [ -L "$rigRigs/LinkCheck.cccccccc/into-source" ] && printf there || printf gone ):$( rigSaid 'kept, a link in it reaches a source tree: LinkCheck.cccccccc' )" "there:1"
rigAssert "the source tree the link reaches is intact" "$( [ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] && [ -f "$rigOrigin/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" ] && printf intact || printf harmed )" intact

echo "-- 4. a file that is no rig folder is left, and a word for the hours is refused --"
rigAssert "the stray file is still there" "$( [ -f "$rigRigs/stray.out" ] && printf there || printf gone )" there
rigSweep --sweep-rigs x
rigAssert "a word where the hours should be is refused, rc 1, nothing removed" "$rigRc:$( rigSaid 'takes a number of hours: x' ):$( ls -1 "$rigRigs" | LC_ALL=C grep -c . )" "1:1:4"

kill "$rigBusyPid" 2> /dev/null ; wait "$rigBusyPid" 2> /dev/null ; rigBusyPid=""
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ RUN TESTS SWEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: the rig sweep removes what it should keep, or keeps what it should remove, or the list form removes" >&2
	echo "  fix:  the --sweep-rigs block of sh-test/AgentsRunTests.sh -- never the assertion" >&2
	exit 1
fi
printf 'RUN_TESTS_SWEEP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
