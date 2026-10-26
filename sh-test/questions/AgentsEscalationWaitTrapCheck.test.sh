#!/usr/bin/env bash
## Check on the traps of --escalate-wait (T9a): an interrupted or killed wait discards its request.
## The waiter (AgentsToolsAuthorityRequestWait) traps TERM, INT and HUP -- not only with --escalate-stop --
## so a wait ended by a signal withdraws its request in the questions store, instead of leaving it
## reply-pending for a later sweep to act on, and the withdraw post says WITHDREW. The Slack-post update is
## best effort and runs only where the record names a channel and a question ts. The functions are sourced
## and called directly; offline, with no curl on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInc="$rigPackage/sh-lib/questions/AgentsTools.Authority.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }
. "$rigInc"
rigFails=0 rigPasses=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi ; }
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsEscalationWaitTrapCheck.XXXXXX" )" || exit 1 ; trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
field(){ ## file, field
	LC_ALL=C awk -v key="$2" '
		$0 == "---" { dashes++ ; if ( dashes == 2 ) { exit ; } next ; }
		dashes == 1 && index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }
	' "$1" 2>/dev/null
}

echo "-- the withdraw post: WITHDREW where the record names a channel and a thread --"
rigPostRecord="$rigTmp/rec.md"
printf '%s\n' '---' 'owner: magic-coordinator' 'channel: D123' 'thread-ts: 1700000000.000001' 'address-to: human-owner' '---' > "$rigPostRecord"
rigOut="$( AgentsToolsAuthorityRequestWithdrawn "$rigPostRecord" 2>/dev/null )"
rigAssert "the withdraw post says WITHDREW for a request with a thread" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'WITHDREW' )" "1"
rigOut="$( AgentsToolsAuthorityRequestWithdrawn "$rigTmp/none" 2>/dev/null )"
rigAssert "a record with no channel and no ts posts nothing and fails nothing" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'WITHDREW' || : )" "0"

## A questions-store request, as --intern-op-pending-reply-open --store questions leaves it.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/questions"
rigStoreRecord(){ ## id
	printf -- '---\nstatus: reply-pending\nkind: permission\nquestion-ts: 1700000000.000100\n---\n\n# Ask\n\nMay I?\n' > "$rigWs/.local/questions/$1.md"
}

## One signal against a fresh wait: the waiter runs in a subshell that sources the include, the
## signal arrives after a short sleep, and the loop then finds it and withdraws within a second.
rigWaitSignal(){ ## id, signal
	rigStoreRecord "$1"
	( export MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_AUTHORITY_WAIT_READ_SECONDS=9999 MDAT_AUTHORITY_WAIT_PROGRESS_SECONDS=9999 \
		; . "$rigInc" ; AgentsToolsAuthorityRequestWait "$1" "" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" &
	local waitPid=$!
	sleep 1
	kill -"$2" "$waitPid" 2>/dev/null || :
	wait "$waitPid" 2>/dev/null
	local waitRc=$?
	printf '%s' "$waitRc"
}

echo "-- a wait interrupted by TERM discards its request --"
rigRcTerm="$( rigWaitSignal trap-term TERM )"
rigAssert "TERM ends the wait with rc 130" "$rigRcTerm" "130"
rigAssert "the request is marked withdrawn" "$( field "$rigWs/.local/questions/trap-term.md" status )" "withdrawn"
rigAssert "by the tooling, not by an answer" "$( field "$rigWs/.local/questions/trap-term.md" withdrawn-by )" "tooling (the wait was cancelled)"

echo "-- a wait interrupted by HUP discards its request --"
rigRcHup="$( rigWaitSignal trap-hup HUP )"
rigAssert "HUP ends the wait with rc 130" "$rigRcHup" "130"
rigAssert "the request is marked withdrawn" "$( field "$rigWs/.local/questions/trap-hup.md" status )" "withdrawn"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ ESCALATION_WAIT_TRAP FAILED: $rigFails of $(( rigPasses + rigFails ))" >&2 ; exit 1 ; fi
printf 'ESCALATION_WAIT_TRAP: OK (%d assertions)\n' "$rigPasses"
