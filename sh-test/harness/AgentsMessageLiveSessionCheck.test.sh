#!/usr/bin/env bash
## AgentsMessageLiveSessionCheck -- a member with no Slack DM of its own, in a workspace whose
## inbox fallback is refused, could not be reached by SendMessage at all (load incident
## 2026-10-29: magic-librarian 3ddf5706 to keeper-myx b190b9af, NO-SLACK-DM then an inbox
## refusal). A plain member-name target must first ask whether that member runs a live session
## of this workspace, and if it does, land in that session's own thread, never a DM or an
## inbox. A member with no live session is untouched by this: its DM, then its inbox, as
## before. Offline by construction: one fake spawn record, backed by a real but harmless
## background process, under this rig's own MMDAPP.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigMessages="$rigHere/harness/AgentsHarnessMessages.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigMessages" ] || rigRefuse "the harness messages file is not in the package: $rigMessages"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMessageLiveSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A background sleep, noted through the rig's own process helper, is the stand-in live process
## behind the fake record: signalled only while it is still itself, never by a recycled number.
sleep 20 & rigBgPid=$!
rigProcNote "$rigBgPid"
trap 'rigProcSignal KILL "$rigBgPid" ; wait "$rigBgPid" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
sleep 0.3
rigBgStart="$( LC_ALL=C ps -o lstart= -p "$rigBgPid" 2> /dev/null | LC_ALL=C awk '{ $1 = $1 ; gsub(/ /, "_") ; print }' )"
rigHost="$( hostname -s 2> /dev/null )"

mkdir -p "$rigTmp/.local/agents/spawned/spawnA" "$rigTmp/.local/temp"
cat > "$rigTmp/.local/agents/spawned/spawnA/spawnA.spawn.md" <<-EOF
	---
	session-id: sessA
	spawn-id: spawnA
	host: $rigHost
	workspace: rig-ws
	owner: keeper-myx
	status: spawn-started
	started-at: 2026-10-30 03:00 +0200
	run-process: $rigBgPid $rigBgStart
	session-thread: CFAKE:111.222
	---

	# fake live record
	EOF

rigLookup(){ ## team member
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		set -u
		. "'"$rigMessages"'" 2> /dev/null
		type AgentsHarnessMessageLiveSessionThread > /dev/null 2>&1 || { printf "%s" "no-such-function" ; exit 0 ; }
		AgentsHarnessMessageLiveSessionThread "'"$1"'"
	'
}

echo "-- a member whose session is alive here is reached in that session's own thread --"
rigAssert "the live session's thread is found, not a DM or an inbox" \
	"$( rigLookup keeper-myx )" "CFAKE:111.222 its live session"

echo "-- a member with no record at all is untouched: nothing is found for it --"
rigAssert "a member nobody spawned here returns nothing, so its DM and its inbox stand as before" \
	"$( rigLookup magic-nobody )" ""

rigProcSignal KILL "$rigBgPid" ; wait "$rigBgPid" 2> /dev/null || :
sleep 0.3
echo "-- once that session's own run has ended, it is no longer reached there --"
rigAssert "a record whose process is gone is not read as a live session" \
	"$( rigLookup keeper-myx )" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MESSAGE LIVE SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MESSAGE_LIVE_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
