#!/usr/bin/env bash
## Behavioural check on AgentsToolsManagerRunActivity (sh-lib/manager/AgentsTools.ManagerSession.include), run rather than
## read: what the console calls a live run that sits inside a call waiting on a person. Held: a Wait writes `wait going idle`
## as it starts and its wait/state says whether it is over; an ask writes `ask going idle` as it starts and a later milestone
## of its own says it is over, so a member idle in Wait for its coordinator's verdict reads waiting, never running (owner
## 2026-10-31). An ended milestone that is neither reads working. A run with no store, no milestones and no bare id reads
## working. Offline; the rig is a directory of stores in this check's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerSession.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the manager session include is not at the origin: $rigInclude"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerRunActivityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigStores"
## The include is read for its definitions alone, by a shell that is not reading this check: its dispatcher answers
## no operation it is not given, and the dispatch names a command only its own caller sets.
MMDAPP="$rigWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; type AgentsToolsManagerRunActivity > /dev/null 2>&1' _ "$rigInclude" \
	|| rigRefuse "the manager session include could not be read with MMDAPP set"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigStat=gnu
[ "$( uname -s )" != "Darwin" ] || rigStat=bsd
rigActivity(){ ## spawn id -- what the console calls that run, from its store alone
	MMDAPP="$rigWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerRunActivity "$2" "$3"' _ "$rigInclude" "$1" "$rigStat"
}
rigStore(){ ## spawn id, the lines of its milestones, one a line
	rm -rf -- "$rigStores/$1"
	mkdir -p "$rigStores/$1"
	[ $# -le 1 ] || printf '%s\n' "$@" | tail -n +2 > "$rigStores/$1/milestones"
}
rigWaitEnded(){ ## spawn id, the time its wait/state takes, as touch -t reads it, in UTC
	mkdir -p "$rigStores/$1/wait"
	printf 'sources: slack:session-current\n' > "$rigStores/$1/wait/state"
	TZ=UTC touch -t "$2" "$rigStores/$1/wait/state"
}

echo "-- 1. a run inside a Wait, as it stood before the ask is counted --"
rigStore run-wait '2026-10-13T07:05:00Z message out' '2026-10-13T07:15:19Z wait going idle'
rigWaitEnded run-wait 202610130715.18
rigAssert "control: a live run inside a Wait reads waiting, its wait/state older than the line" "$( rigActivity run-wait )" waiting
rigStore run-idle '2026-10-13T07:15:19Z wait going idle'
rigAssert "control: and one whose wait/state was never written does too" "$( rigActivity run-idle )" waiting

echo "-- 2. a run blocked in an ask on a person --"
rigStore run-ask '2026-10-13T07:05:00Z message out' '2026-10-13T07:15:19Z ask going idle'
rigAssert "a run idle in an ask reads waiting, never working: the milestone the ask writes as it starts is what says so" "$( rigActivity run-ask )" waiting
printf '2026-10-13T07:20:00Z message out\n' >> "$rigStores/run-ask/milestones"
rigAssert "and it reads working again once the ask is answered and the run goes on: the line after it ends the block" "$( rigActivity run-ask )" working
rigStore run-ask-end '2026-10-13T07:15:19Z ask going idle' '2026-10-13T07:16:00Z ask ended'
rigAssert "an ask that ended with no answer ends the block too: ask ended reads working" "$( rigActivity run-ask-end )" working
rigStore run-ask-left '2026-10-13T07:15:19Z ask going idle' '2026-10-13T07:16:00Z ask going idle'
rigAssert "a run that asks again after an answered ask is waiting again, on the newer line" "$( rigActivity run-ask-left )" waiting

echo "-- 3. what this check does not call waiting --"
rigStore run-post '2026-10-13T07:15:19Z message out'
rigAssert "a run that has just posted reads working" "$( rigActivity run-post )" working
rigStore run-none
rigAssert "a run with no store reads working" "$( MMDAPP="$rigWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerRunActivity "$2" "$3"' _ "$rigInclude" run-nowhere "$rigStat" )" working
rigAssert "and so does one given no bare id at all" "$( MMDAPP="$rigWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerRunActivity "" "$2"' _ "$rigInclude" "$rigStat" )" working

echo "-- 4. the harness writes the milestone that says a run is inside an ask --"
rigTranscript="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionTranscript.include"
rigAskWs="$rigTmp/ask-ws" ; rigAskSid="ask-0000-4000-8000-000000000001"
rigAskDir="$rigAskWs/.local/agents/sessions/$rigAskSid"
mkdir -p "$rigAskDir" "$rigTmp/ask-store" "$rigTmp/ask-data"
printf '%s\n' "$rigTmp/ask-store/transcript.log" > "$rigAskDir/transcript"
: > "$rigTmp/ask-store/transcript.log"
printf '%s\n' "$rigTmp/ask-data" > "$rigAskDir/data-root"
rigAskTurn(){ ## tool name -- the last milestone of the run after that tool's start
	MMDAPP="$rigAskWs" MDAT_SPAWN_SESSION_ID="$rigAskSid" MDAT_DATA_ROOT="$rigTmp/ask-data" \
		bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsTranscriptToolStart "$2"' _ "$rigTranscript" "$1" > /dev/null 2>&1
	awk '{ $1 = "" ; print }' "$rigAskDir/milestones" 2> /dev/null | tail -1
}
rigAssert "an ask about to block writes ask going idle, as a Wait writes wait going idle: that line is what the console reads" "$( rigAskTurn AskQuestion )" " ask going idle"
rigAssert "a tool that waits on nobody writes no milestone of its own" "$( rigAskTurn Read )" " ask going idle"
rigAssert "a readback and a permission ask block the same way" "$( rigAskTurn ConfirmReadback )$( rigAskTurn RequestPermission )" " ask going idle ask going idle"

echo "-- 5. a run whose harness keeps no transcript of its own --"
rigBareWs="$rigTmp/no-transcript-ws" ; rigBareSid="bare-0000-4000-8000-000000000001"
rigBareDir="$rigBareWs/.local/agents/sessions/$rigBareSid"
mkdir -p "$rigBareDir" "$rigTmp/bare-data"
rigBareTurn(){ ## tool name -- the last milestone after that tool's start, for a run with no transcript
	MMDAPP="$rigBareWs" MDAT_SPAWN_SESSION_ID="$rigBareSid" MDAT_DATA_ROOT="$rigTmp/bare-data" \
		bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsTranscriptToolStart "$2"' _ "$rigTranscript" "$1" > /dev/null 2>&1
	awk '{ $1 = "" ; print }' "$rigBareDir/milestones" 2> /dev/null | tail -1
}
rigAssert "a run with no transcript of its own still records that it went into a Wait: that line is the console's only record" "$( rigBareTurn Wait )" " wait going idle"
rigAssert "and the console calls it waiting from that line alone" "$( MMDAPP="$rigBareWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerRunActivity "$2" "$3"' _ "$rigInclude" "$rigBareSid" "$rigStat" )" waiting
rigAssert "and an ask reads waiting there too" "$( rigBareTurn AskQuestion ):$( MMDAPP="$rigBareWs" bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; AgentsToolsManagerRunActivity "$2" "$3"' _ "$rigInclude" "$rigBareSid" "$rigStat" )" " ask going idle:waiting"

echo "-- the count --"
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'MANAGER RUN ACTIVITY: OK (%d assertions, offline)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ MANAGER RUN ACTIVITY CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
