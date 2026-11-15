#!/usr/bin/env bash
## Behavioural check of where an ask's record is found, and of who is told when an authority ask is answered:
## every Wait reader of an `ask:` source resolves its record in each store a record lives in (AgentsWaitAskRecord): the live
## pending store, its closed one, and the questions store an authority ask is kept in (a contact's tier); an id in none
## resolves to a path that is no file. The ask probe reads a closed record of the questions store as closed, never as an
## unreadable source. The run that asked is told the answer in its own session chat (AgentsToolsAuthorityRequesterTell):
## applied, or its action not applied with the exit status; a request with no run, or a run with no session folder, is told
## nothing and fails nothing. Offline: a temp workspace holding records and one session folder only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigCore="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/wait/AgentsTools.MemberWaitCore.include"
rigAskLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/wait/AgentsTools.MemberWaitAsk.include"
rigAuthority="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.Authority.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeed in "$rigCore" "$rigAskLib" "$rigAuthority" ; do
	[ -f "$rigNeed" ] || rigRefuse "a library is not at the origin: $rigNeed"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAskRecordStoresCheck )" || exit 1
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
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/pending/closed" "$rigWs/.local/questions" "$rigWs/.local/agents/sessions/rig-asking-run"
printf '%s\n' "CRIG00001:1700000000.000100" > "$rigWs/.local/agents/sessions/rig-asking-run/session.thread"
rigRecord(){ ## file, status, extra header lines
	printf -- '---\nstatus: %s\nowner: magic-coordinator\nkind: decision\naddress-to: human-owner\n%s---\n\n# ❓ Question\n\nRig question\n' "$2" "$3" > "$1"
}
rigRecord "$rigWs/.local/agents/pending/ask-live.md" reply-pending ""
rigRecord "$rigWs/.local/agents/pending/closed/ask-closed.md" reply-received ""
rigRecord "$rigWs/.local/questions/ask-authority.md" reply-received 'request-of: rig-contact
requester: magic-coordinator
requester-run: rig-asking-run
request-what: the tier of the contact rig-contact for the scope rig
'
rigRecord "$rigWs/.local/questions/ask-norun.md" reply-received 'requester: magic-coordinator
requester-run: none
'
rigRecord "$rigWs/.local/questions/ask-gone-run.md" reply-received 'requester: magic-coordinator
requester-run: rig-run-with-no-folder
'
rigCall(){ ## shell text, run with the libraries loaded
	( cd "$rigWs" && MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" 2> /dev/null ; . "$2" 2> /dev/null ; . "$3" 2> /dev/null ; eval "$4"' rig "$rigCore" "$rigAskLib" "$rigAuthority" "$1" )
}

echo "-- an ask's record is found in every store a record lives in --"
rigAssert "the live pending store"        "$( rigCall 'AgentsWaitAskRecord ask-live' )"      "$rigWs/.local/agents/pending/ask-live.md"
rigAssert "its closed store"              "$( rigCall 'AgentsWaitAskRecord ask-closed' )"    "$rigWs/.local/agents/pending/closed/ask-closed.md"
rigAssert "the questions store"           "$( rigCall 'AgentsWaitAskRecord ask-authority' )" "$rigWs/.local/questions/ask-authority.md"
rigAssert "an id in none: a path that is no file" "$( rigCall 'f="$( AgentsWaitAskRecord ask-none )" ; [ -f "$f" ] && printf file || printf no-file' )" "no-file"

echo "-- the ask probe reads a closed authority ask as closed, never as unreadable --"
rigAssert "rc 0, and the closed line" \
	"$( rigCall 'AgentsWaitProbeAsk magic-coordinator ask-authority "" "$MMDAPP/probe.out" ; printf "%s:" "$?" ; LC_ALL=C grep -c -x "# pending reply ask-authority is closed: reply-received" "$MMDAPP/probe.out"' )" "0:1"

echo "-- the run that asked is told, in its own session chat --"
rigCall 'AgentsToolsAuthorityRequesterTell "$MMDAPP/.local/questions/ask-authority.md" tier-admin human-owner 0'
rigChat="$rigWs/.local/agents/sessions/rig-asking-run/session.chat"
rigAssert "applied: one block to the member that asked" \
	"$( LC_ALL=C grep -c -F 'tooling -> magic-coordinator' "$rigChat" 2> /dev/null ):$( LC_ALL=C grep -c -F 'Your request ask-authority, the tier of the contact rig-contact for the scope rig, is answered: `tier-admin` by human-owner, and it is applied.' "$rigChat" 2> /dev/null )" "1:1"
rigCall 'AgentsToolsAuthorityRequesterTell "$MMDAPP/.local/questions/ask-authority.md" tier-admin human-owner 3'
rigAssert "not applied: said, with its exit status" \
	"$( LC_ALL=C grep -c -F 'and its action did NOT apply (exit 3)' "$rigChat" 2> /dev/null )" 1
rigAssert "a request with no run: told nothing, rc 0" \
	"$( rigCall 'AgentsToolsAuthorityRequesterTell "$MMDAPP/.local/questions/ask-norun.md" yes human-owner 0 ; printf %s $?' ):$( ls "$rigWs/.local/agents/sessions" | LC_ALL=C grep -c -v -x 'rig-asking-run' )" "0:0"
rigAssert "a run with no session folder: told nothing, rc 0, no folder made" \
	"$( rigCall 'AgentsToolsAuthorityRequesterTell "$MMDAPP/.local/questions/ask-gone-run.md" yes human-owner 0 ; printf %s $?' ):$( [ -e "$rigWs/.local/agents/sessions/rig-run-with-no-folder" ] && printf made || printf none )" "0:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK RECORD STORES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ASK_RECORD_STORES: OK (%d assertions, offline, temp workspace only)\n' "$rigPassCount"
