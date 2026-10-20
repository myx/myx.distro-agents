#!/usr/bin/env bash
## Behavioural check on the outbound contact gate over the contacts store (F7.10 of the refactorings epic): AgentsToolsContactAssertKnown
## (sh-lib/common/AgentsTools.InternContact.include), the check every real send (Slack, e-mail) makes right before its network call, run rather
## than read, in a rig: a workspace with its team data root and the real tooling; the contacts are recorded by the tool that keeps them
## (DistroAgentsContacts.fn.sh --collect-contact). Held:
##   1. KNOWN is a coordinate of a contact the acting member holds: a Slack id or a Slack conversation within the sending member's team, an e-mail
##      address without regard to case. Nothing is refused, and no refusal is recorded.
##   2. NOT KNOWN is refused with rc 1, a refusal id and a recorded refusal: a recipient of no contact; of a contact held by another member only;
##      a Slack id of another team (the id is unique within one Slack workspace only); a name, a contact's id or a handle (the gate is about a
##      recipient on record, and these are not addresses); a store that is not there. The error says which checks were made.
##   3. WHAT NEEDS NO RECORD stays so: a partner-* or human-owner member named by the sender, the human-owner's own configured address in any
##      case.
##   4. THE OLD NOTE IS NOT READ. A contacts note in the member's inbox, in the retired format, makes nothing known.
## Offline, rig tree only: a fake curl answers every request, so nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigContacts="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigContacts" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigContacts"
[ -f "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactsGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigTmp/bin"
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
printf 'EMAIL_USER=Owner@Rig.Example\n' > "$rigWs/.local/.agents/human-owner.agent.env"
rigAs=""
rigTool(){ ## result prefix, the tool's words... -- DistroAgentsContacts.fn.sh as the member in rigAs
	local toolOut="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash "$rigContacts" "$@" ) > "$toolOut.out" 2> "$toolOut.err" < /dev/null
}
rigGate(){ ## result prefix, the gate's words after the member... -- the gate asked as client-ndm in the session rig-session; rc in rigRc
	local gateOut="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SPAWN_SESSION_ID=rig-session MDAT_SPAWN_AGENT=client-ndm \
		bash -c '
			DistroAgentsTools(){ "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.BareName.include"
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternContact.include"
			AgentsToolsContactAssertKnown client-ndm "$@"' rig "$@" ) > "$gateOut.out" 2> "$gateOut.err" < /dev/null
	rigRc=$?
}
rigRefusals(){ ## -- the refusal records of the rig session
	ls "$rigWs/.local/agents/sessions/rig-session" 2> /dev/null | LC_ALL=C grep -c '^refusal-' || :
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigBegin=$( date +%s )

echo "-- 0. a store that is not there --"
rigGate "$rigTmp/g0" --tool member-comms-email-send --target alice@ndm.example --message hello
rigAssert "no store, no contact: refused with rc 1, a refusal id and one recorded refusal" "$rigRc $( rigHas 'REFUSAL-ID: refusal-' "$rigTmp/g0.err" ) $( rigRefusals )" "1 1 1"

echo "-- 1. what is known --"
rigAs=client-ndm
rigTool "$rigTmp/s1" --collect-organisation --id ndm --name "NDM Ltd"
rigTool "$rigTmp/s2" --collect-contact --id alice-one --name "Alice One" --organisation ndm --slack client-ndm:U111ABC --slack-conversation client-ndm:D222DEF --slack-handle client-ndm:@alice --email Alice@Ndm.example
rigAs=keeper-x
rigTool "$rigTmp/s3" --collect-contact --id bob-two --name "Bob Two" --slack keeper-x:UBOB00001 --email bob@acme.example
rigAs=client-ndm
rigTool "$rigTmp/s4" --collect-contact --id cara-three --name "Cara Three" --slack other-team:UCARA0001
rigAs=""
rigGate "$rigTmp/k1" --tool member-comms-slack-send-message --target U111ABC --team client-ndm --message hello
rigAssert "a Slack id of a contact the member holds, within the sending team" "$rigRc" "0"
rigGate "$rigTmp/k2" --tool member-comms-slack-send-message --target D222DEF --team client-ndm --message hello
rigAssert "a Slack conversation of that contact" "$rigRc" "0"
rigGate "$rigTmp/k3" --tool member-comms-email-send --target ALICE@NDM.EXAMPLE --message hello
rigAssert "an e-mail address of that contact, in any case, with no team" "$rigRc" "0"
rigGate "$rigTmp/k4" --tool member-comms-slack-send-message --target U111ABC --message hello
rigAssert "a Slack id with no team given (a caller that does not name one): matched by the id alone" "$rigRc" "0"
rigAssert "none of them was refused or recorded: nothing printed, no new refusal" "$( cat "$rigTmp/k1.out" "$rigTmp/k2.out" "$rigTmp/k3.out" "$rigTmp/k4.out" | LC_ALL=C grep -c . ) $( rigRefusals )" "0 1"

echo "-- 2. what is not --"
rigGate "$rigTmp/n1" --tool member-comms-email-send --target stranger@nowhere.example --message hello
rigAssert "a recipient of no contact: refused, rc 1, with a refusal id; the error says what the gate checked" "$rigRc $( rigHas 'REFUSAL-ID: refusal-' "$rigTmp/n1.err" ) $( rigHas "not a coordinate of a contact client-ndm holds (DistroAgentsContacts.fn.sh --find-contact), not one of the team's own configured addresses (human-owner or member)" "$rigTmp/n1.err" )" "1 1 1"
rigGate "$rigTmp/n2" --tool member-comms-email-send --target bob@acme.example --message hello
rigAssert "a contact held by another member only: refused" "$rigRc" "1"
rigGate "$rigTmp/n3" --tool member-comms-slack-send-message --target UCARA0001 --team client-ndm --message hello
rigAssert "a Slack id of another team: refused, as the id is unique within one Slack workspace only" "$rigRc" "1"
rigGate "$rigTmp/n3b" --tool member-comms-slack-send-message --target UCARA0001 --team other-team --message hello
rigAssert "and known when the send is of that team (the contact is held by the member)" "$rigRc" "0"
rigGate "$rigTmp/n4" --tool member-comms-slack-send-message --target "Alice One" --team client-ndm --message hello
rigGate "$rigTmp/n5" --tool member-comms-slack-send-message --target alice-one --team client-ndm --message hello
rigGate "$rigTmp/n6" --tool member-comms-slack-send-message --target @alice --team client-ndm --message hello
rigAssert "a name, a contact's id and a handle are no address: each refused" "$( cat "$rigTmp/n4.err" "$rigTmp/n5.err" "$rigTmp/n6.err" | LC_ALL=C grep -c 'REFUSED' )" "3"
rigAssert "each refusal was recorded (the first one of the empty store, and these six)" "$( rigRefusals )" "7"

echo "-- 3. what needs no record --"
rigGate "$rigTmp/p1" --tool member-comms-slack-send-message --target CPARTNER1 --named-member partner-acme-cto --message hello ; rigP="$rigRc"
rigGate "$rigTmp/p2" --tool member-comms-slack-send-message --target CHUMAN001 --named-member human-owner --message hello ; rigP="$rigP$rigRc"
rigGate "$rigTmp/p3" --tool member-comms-email-send --target owner@RIG.example --message hello ; rigP="$rigP$rigRc"
rigAssert "a partner-* member and the human-owner named by the sender, the human-owner's address in any case: known, nothing recorded" "$rigP $( rigRefusals )" "000 7"

echo "-- 4. the old note is not read --"
mkdir -p "$rigData/inboxes/client-ndm/incoming"
printf '%s\n' '| slack-id | contact | handle | email | organisation | permission level |' '| --- | --- | --- | --- | --- | --- |' '| UOLDNOTE1 | rig-old | @rig-old | old@example.com | rig | unset |' > "$rigData/inboxes/client-ndm/incoming/note-20260904T190756Z-contacts.md"
rigGate "$rigTmp/o1" --tool member-comms-slack-send-message --target UOLDNOTE1 --team client-ndm --message hello
rigGate "$rigTmp/o2" --tool member-comms-email-send --target old@example.com --message hello
rigAssert "a recipient listed only in a contacts note of the retired format: refused" "$( cat "$rigTmp/o1.err" "$rigTmp/o2.err" | LC_ALL=C grep -c 'REFUSED' )" "2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS GATE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_GATE: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
