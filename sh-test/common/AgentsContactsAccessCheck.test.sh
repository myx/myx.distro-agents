#!/usr/bin/env bash
## Behavioural check on a contact's access and the two scenarios of the contacts subsystem (F7.10 of the refactorings epic):
## `contact:<id>` as a grantee of the permission model (the refusal log, grant-open, grant-read, --intern-op-permission-contact-holds) and
## DistroAgentsContacts.fn.sh --contact-access, --escalate-contact, --allow-contact, --contacted-by and --reach-contact, run rather than read, in a
## rig: a workspace, a team data root, a fake curl that answers every Slack request, the real tooling. Access is never stored by the contacts file:
## the permission model holds it, in the `allows:` of the record (what it names, standing) and in the grants of a session. Held:
##   1. A REFUSAL FOR A CONTACT is recorded with `contact:<id>` for its owner; a contact that is not recorded, a bad id and any other name with a
##      colon are refused.
##   2. A SESSION GRANT for a contact (grant-open --kind session on that refusal): written in the session's store, read by the chain for the contact
##      in that session and not in another, and never the asking member's own.
##   3. A STANDING GRANT FOR A CONTACT (grant-open --kind contact): an entry `contact:<tool>:<target>:<granted by>:<time>` joins the `allows:` of the
##      record and a line of its log says it; the chain reads it for the contact whatever the session, by the same tool and a target the entry
##      covers (a folder pattern too), and not for another; given twice it stands once; an entry whose signer does not hold what it names is ignored.
##   4. WHAT grant-open REFUSES: a contact is granted for a session or for the contact, not once and not for a task; the kind `contact` is for a
##      contact's refusal alone; the approver must hold what it approves (rc 3).
##   5. --contact-access answers with the chain's own words (`GRANT: ...` or `NO-GRANT: ...`, rc 1) for a call, and lists what the contact holds
##      standing without one; --intern-op-permission-contact-holds is the chain's listing.
##   6. --escalate-contact records the refusal for the contact, puts a line in its log and prints, from its template, the one call of the existing
##      escalation path that asks the human-owner (RequestPermission on that refusal); it sends nothing itself. Refused with no member's session, no
##      session, no contact, a missing part, a text too long. (The owner's answer to that request is AgentsHarnessPermissionContactCheck's.)
##   7. --allow-contact is a member's grant, through grant-open, signed by the member and bounded by what it holds (rc 3 otherwise), for the refusal of
##      that contact only, for the session or for the contact; never signed by the human-owner. Refused for a refusal of another contact or one not there,
##      a kind that is neither session nor contact, and a call from no member's session.
##   8. THE TWO SCENARIOS print the record and the template's text: being contacted (the access held, the tiers, the next step; a sender nobody
##      recorded; a value that names two contacts), and reaching one (its coordinates by channel, how to meet it, the send lines, a line left out
##      where the contact has none).
## Offline, rig tree only: a fake curl answers every request, so nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigContacts="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigChain="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigContacts" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigContacts"
[ -f "$rigPackage/sh-test/check-fixtures/change-approval.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactsAccessCheck )" || exit 1
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
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigScn="$rigTmp/scn"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigTmp/bin" "$rigScn"
cp "$rigPackage/sh-test/check-fixtures/change-approval.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
: > "$rigTmp/curl.log"
printf 'SLACK_BOT_TOKEN=rig-bot-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=UHUMAN001\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in client-ndm keeper-x ; do
	printf 'SLACK_USER_TOKEN=rig-user-%s\nSLACK_BOT_TOKEN=rig-bot-%s\n' "$rigMember" "$rigMember" > "$rigWs/.local/.agents/$rigMember.agent.env"
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
	printf '# armed\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.armed.md"
	printf -- '---\nname: %s\n---\n# %s\n' "$rigMember" "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
done
rigAs="" rigSid=""
rigEnv(){ ## the environment of every call
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigScn" RIG_CURL_LOG="$rigTmp/curl.log" \
		${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} ${rigSid:+MDAT_SPAWN_SESSION_ID="$rigSid"} "$@"
}
rigTool(){ ## result prefix, the contacts tool's words... -- rc in rigRc
	local toolOut="$1" ; shift
	( cd "$rigWs" && rigEnv bash "$rigContacts" "$@" ) > "$toolOut.out" 2> "$toolOut.err" < /dev/null
	rigRc=$?
}
rigOp(){ ## result prefix, the tools' words... -- DistroAgentsTools.fn.sh; rc in rigRc
	local opOut="$1" ; shift
	( cd "$rigWs" && rigEnv bash "$rigChain" "$@" ) > "$opOut.out" 2> "$opOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigKey(){ ## file, key
	LC_ALL=C awk -v want="$2: " 'NR == 1 { if ( $0 != "---" ) exit ; next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
rigRefusalId(){ ## result prefix -- the refusal id a refusal-log printed
	LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$1.out" | LC_ALL=C sed -n 1p
}
rigPerson="$rigData/contacts/persons"
rigGrantCount(){ ## pattern -- how many lines of the grants of the session sess-e match it (0 where there are none yet)
	[ -f "$rigWs/.local/agents/sessions/sess-e/grants" ] || { printf 0 ; return 0 ; }
	LC_ALL=C grep -c -- "$1" "$rigWs/.local/agents/sessions/sess-e/grants" || :
}
rigBegin=$( date +%s )

## the contacts
rigAs=client-ndm
rigTool "$rigTmp/s1" --collect-organisation --id ndm --name "NDM Ltd"
rigTool "$rigTmp/s2" --collect-contact --id alice-one --name "Alice One" --organisation ndm --role CTO --how-to-meet "short messages" --slack client-ndm:U111ABC --slack-conversation client-ndm:D222DEF --email alice@ndm.example
rigTool "$rigTmp/s3" --collect-contact --id bare-one --name "Bare One" --email bare@ndm.example
rigTool "$rigTmp/s4" --collect-contact --id alice-two --name "Alice Two" --slack client-ndm:U222XYZ
rigAs=""

echo "-- 1. a refusal for a contact --"
rigOp "$rigTmp/r1" --intern-op-permission-refusal-log contact:alice-one --session-id sess-a --tool dispatch --target job-17 --reason "Alice asks for a job run"
rigRefA="$( rigRefusalId "$rigTmp/r1" )"
rigAssert "recorded: an id, and the record in the session's store with the contact for its owner" "$rigRc $( printf '%s' "$rigRefA" | LC_ALL=C grep -c '^refusal-' ) $( rigKey "$rigWs/.local/agents/sessions/sess-a/$rigRefA.md" owner ) $( rigKey "$rigWs/.local/agents/sessions/sess-a/$rigRefA.md" tool ) $( rigKey "$rigWs/.local/agents/sessions/sess-a/$rigRefA.md" target )" "0 1 contact:alice-one dispatch job-17"
rigOp "$rigTmp/r2" --intern-op-permission-refusal-log contact:nobody-at-all --session-id sess-a --tool dispatch --target job-17
rigOp "$rigTmp/r3" --intern-op-permission-refusal-log contact:Bad_Id --session-id sess-a --tool dispatch --target job-17
rigOp "$rigTmp/r4" --intern-op-permission-refusal-log other:alice-one --session-id sess-a --tool dispatch --target job-17
rigAssert "a contact that is not recorded, a bad id, another name with a colon: refused, nothing recorded" "$( cat "$rigTmp/r2.err" "$rigTmp/r3.err" "$rigTmp/r4.err" | LC_ALL=C grep -c 'ASSERT' ) $( ls "$rigWs/.local/agents/sessions/sess-a" | LC_ALL=C grep -c '^refusal-' )" "3 1"

echo "-- 2. a session grant for a contact --"
rigOp "$rigTmp/g1" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefA" --kind session
rigAssert "granted for the session: said so, and a line in the session's grants" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/g1.out" | LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' ) $( LC_ALL=C grep -c "^session:dispatch:job-17:human-owner:[0-9TZ]*:$rigRefA\$" "$rigWs/.local/agents/sessions/sess-a/grants" )" "0 GRANT: session <ref> 1"
rigOp "$rigTmp/g2" --intern-op-permission-grant-read contact:alice-one --session-id sess-a --tool dispatch --target job-17
rigAssert "the chain reads it for the contact in that session" "$rigRc $( LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' "$rigTmp/g2.out" )" "0 GRANT: session <ref>"
rigOp "$rigTmp/g3" --intern-op-permission-grant-read contact:alice-one --session-id sess-b --tool dispatch --target job-17
rigAssert "and not in another session" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/g3.out" )" "1 0"
rigOp "$rigTmp/g4" --intern-op-permission-grant-read client-ndm --session-id sess-a --tool dispatch --target job-17
rigAssert "it is not the asking member's own: the member holds nothing by it" "$rigRc" "1"
rigOp "$rigTmp/g5" --intern-op-permission-grant-read contact:alice-two --session-id sess-a --tool dispatch --target job-17
rigAssert "nor another contact's" "$rigRc" "1"

echo "-- 3. a standing grant for a contact --"
rigOp "$rigTmp/h1" --intern-op-permission-refusal-log contact:alice-one --session-id sess-a --tool dispatch --target job-18
rigRefB="$( rigRefusalId "$rigTmp/h1" )"
rigOp "$rigTmp/h2" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefB" --kind contact
rigAssert "granted for the contact: said so" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/h2.out" | LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' )" "0 GRANT: contact <ref>"
rigAssert "an entry joined the allows: of the record, and a line of its log says it" "$( rigKey "$rigPerson/alice-one.md" allows | LC_ALL=C sed -E 's/[0-9]{8}T[0-9]{6}Z/<time>/' ) $( LC_ALL=C grep -c -E -- '-- human-owner -- allowed: dispatch job-18 \(standing\)$' "$rigPerson/alice-one.md" )" "contact:dispatch:job-18:human-owner:<time> 1"
rigOp "$rigTmp/h3" --intern-op-permission-grant-read contact:alice-one --session-id sess-zz --tool dispatch --target job-18
rigAssert "the chain reads it for the contact, whatever the session" "$rigRc $( LC_ALL=C cat "$rigTmp/h3.out" )" "0 GRANT: contact alice-one"
rigOp "$rigTmp/h4" --intern-op-permission-grant-read contact:alice-one --session-id sess-zz --tool dispatch --target job-19
rigOp "$rigTmp/h5" --intern-op-permission-grant-read contact:alice-one --session-id sess-zz --tool other-tool --target job-18
rigOp "$rigTmp/h6" --intern-op-permission-grant-read contact:alice-two --session-id sess-zz --tool dispatch --target job-18
rigAssert "not for another target, another tool, another contact" "$( cat "$rigTmp/h4.rc" 2> /dev/null )$( [ "$( LC_ALL=C grep -c . "$rigTmp/h4.out" )" = 0 ] && printf none ) $( LC_ALL=C grep -c . "$rigTmp/h5.out" ) $( LC_ALL=C grep -c . "$rigTmp/h6.out" )" "none 0 0"
rigOp "$rigTmp/h7" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefB" --kind contact
rigAssert "given again for the same call: it stands once, and the log does not repeat" "$rigRc $( rigKey "$rigPerson/alice-one.md" allows | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c . ) $( LC_ALL=C grep -c -- 'allowed: dispatch job-18' "$rigPerson/alice-one.md" )" "0 1 1"
rigOp "$rigTmp/h8" --intern-op-permission-refusal-log contact:alice-one --session-id sess-a --tool Read --target "/rig/projects/**"
rigRefC="$( rigRefusalId "$rigTmp/h8" )"
rigOp "$rigTmp/h9" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefC" --kind contact
rigOp "$rigTmp/h10" --intern-op-permission-grant-read contact:alice-one --session-id sess-zz --tool Read --target /rig/projects/one/two.md
rigAssert "a folder pattern covers what lies under it; the entry has the target's colons and commas escaped, and the chain reads it back" "$rigRc $( LC_ALL=C cat "$rigTmp/h10.out" ) $( rigKey "$rigPerson/alice-one.md" allows | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c . )" "0 GRANT: contact alice-one 2"
## an entry whose signer does not hold what it names counts for nothing
LC_ALL=C awk '$0 ~ /^allows: / { print $0 ",contact:Edit:/rig/secret.md:keeper-x:20261020T000000Z" ; next ; } { print }' "$rigPerson/alice-one.md" > "$rigTmp/alice.forged" && cp "$rigTmp/alice.forged" "$rigPerson/alice-one.md"
rigOp "$rigTmp/h11" --intern-op-permission-grant-read contact:alice-one --session-id sess-zz --tool Edit --target /rig/secret.md
rigAssert "an entry signed by a member that holds nothing of what it names is ignored" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/h11.out" )" "1 0"

echo "-- 4. what grant-open refuses --"
rigOp "$rigTmp/k1" --intern-op-permission-refusal-log contact:alice-one --session-id sess-a --tool dispatch --target job-20
rigRefD="$( rigRefusalId "$rigTmp/k1" )"
rigOp "$rigTmp/k2" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefD" --kind once
mkdir -p "$rigData/board/running" && printf -- '---\ntype: task\n---\n\nx\n' > "$rigData/board/running/task-rig-item.md"
rigOp "$rigTmp/k3" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefD" --kind task --task task-rig-item
rigAssert "a contact is granted for a session or for the contact, not once and not for a task: refused, no grant" "$( LC_ALL=C grep -c 'is a contact, granted for a session' "$rigTmp/k2.err" ) $( LC_ALL=C grep -c 'is a contact, granted for a session' "$rigTmp/k3.err" ) $( LC_ALL=C grep -c ":$rigRefD\$" "$rigWs/.local/agents/sessions/sess-a/grants" )" "1 1 0"
rigOp "$rigTmp/k4" --intern-op-permission-refusal-log keeper-x --session-id sess-a --tool dispatch --target job-21
rigRefE="$( rigRefusalId "$rigTmp/k4" )"
rigOp "$rigTmp/k5" --intern-op-permission-grant-open human-owner --session-id sess-a --refusal-id "$rigRefE" --kind contact
rigAssert "the kind contact is for a contact's refusal alone" "$rigRc $( LC_ALL=C grep -c -- '--kind contact is for the refusal of a contact' "$rigTmp/k5.err" )" "1 1"
rigOp "$rigTmp/k6" --intern-op-permission-grant-open keeper-x --session-id sess-a --refusal-id "$rigRefD" --kind contact
rigAssert "the approver must hold what it approves: a member that holds nothing of it cannot grant it, rc 3, and nothing is written" "$rigRc $( LC_ALL=C grep -c '^NOT-HOLDS: keeper-x dispatch job-20' "$rigTmp/k6.out" ) $( rigKey "$rigPerson/alice-one.md" allows | LC_ALL=C grep -c 'job-20' )" "3 1 0"

echo "-- 5. --contact-access and the chain's listing --"
rigSid=sess-zz
rigTool "$rigTmp/a1" --contact-access alice-one --tool dispatch --target job-18
rigAssert "a call the contact may ask for: the chain's own words, rc 0" "$rigRc $( LC_ALL=C cat "$rigTmp/a1.out" )" "0 GRANT: contact alice-one"
rigTool "$rigTmp/a2" --contact-access alice-one --tool dispatch --target job-99
rigAssert "a call it may not: NO-GRANT with the call, rc 1" "$rigRc $( LC_ALL=C cat "$rigTmp/a2.out" )" "1 NO-GRANT: contact:alice-one dispatch job-99"
rigSid=sess-a
rigTool "$rigTmp/a3" --contact-access alice-one --tool dispatch --target job-17
rigAssert "what a session grant allows, in that session" "$rigRc $( LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' "$rigTmp/a3.out" )" "0 GRANT: session <ref>"
rigSid=""
rigTool "$rigTmp/a4" --contact-access alice-one
rigAssert "with no call: what it holds standing, a row each (the forged entry is listed too: the call above is what refuses it)" "$rigRc $( LC_ALL=C cut -f1,2,3,4 "$rigTmp/a4.out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' ' ' )" "0 ALLOW|dispatch|job-18|human-owner ALLOW|Read|/rig/projects/**|human-owner ALLOW|Edit|/rig/secret.md|keeper-x "
rigTool "$rigTmp/a5" --contact-access nobody-at-all --tool dispatch --target x
rigTool "$rigTmp/a6" --contact-access alice-one --tool dispatch
rigTool "$rigTmp/a7" --contact-access alice-two
rigAssert "a contact that is not recorded, a tool without its target: refused; a contact with nothing standing lists none" "$( LC_ALL=C grep -c 'no contact nobody-at-all is recorded' "$rigTmp/a5.err" ) $( LC_ALL=C grep -c -- '--tool and --target come together' "$rigTmp/a6.err" ) $( LC_ALL=C grep -c . "$rigTmp/a7.out" ) $( cat "$rigTmp/a7.rc" 2> /dev/null )" "1 1 0 "
rigOp "$rigTmp/a8" --intern-op-permission-contact-holds keeper-x ; rigRc8="$rigRc"
rigOp "$rigTmp/a9" --intern-op-permission-contact-holds contact:nobody-at-all
rigAssert "the chain's listing refuses a name that is no contact, and one that is not recorded" "$rigRc8 $( LC_ALL=C grep -c 'contact:<id>' "$rigTmp/a8.err" ) $rigRc $( LC_ALL=C grep -c 'not recorded' "$rigTmp/a9.err" )" "1 1 1 1"

echo "-- 6. --escalate-contact --"
rigAs=client-ndm ; rigSid=sess-e
rigTool "$rigTmp/e1" --escalate-contact alice-two --tool dispatch --target job-30 --asked "Alice Two wants a job run for the rig."
rigRefF="$( LC_ALL=C sed -n 's/^REFUSAL-ID: //p' "$rigTmp/e1.out" )"
rigAssert "asked: the refusal id, rc 0" "$rigRc $( printf '%s' "$rigRefF" | LC_ALL=C grep -c '^refusal-' )" "0 1"
rigAssert "the refusal is the permission model's, recorded for the contact in the member's session" "$( rigKey "$rigWs/.local/agents/sessions/sess-e/$rigRefF.md" owner ) $( rigKey "$rigWs/.local/agents/sessions/sess-e/$rigRefF.md" tool ) $( rigKey "$rigWs/.local/agents/sessions/sess-e/$rigRefF.md" target )" "contact:alice-two dispatch job-30"
rigAssert "the log of the contact says it, with the member, the call, the words and the refusal" "$( LC_ALL=C grep -c -E -- "-- client-ndm -- escalated: dispatch job-30: Alice Two wants a job run for the rig\. \(refusal $rigRefF\)\$" "$rigPerson/alice-two.md" )" "1"
rigAssert "the way to ask, from the template: the one call of the existing escalation path on that refusal, and what his answer opens; this operation sent nothing itself" "$( rigHas "The refusal $rigRefF is recorded for the contact alice-two (Alice Two), in session sess-e. Ask the human-owner with \`RequestPermission refusal_id=$rigRefF reason=\"client-ndm asks about the contact alice-two: Alice Two wants a job run for the rig.\" task_ref=<the task this serves>\`." "$rigTmp/e1.out" ) $( rigHas 'His click or word opens the grant: for this session, or, with 👤, for the contact whatever the session.' "$rigTmp/e1.out" ) $( LC_ALL=C grep -c . "$rigTmp/curl.log" )" "1 1 0"
rigAs="" ; rigTool "$rigTmp/e2" --escalate-contact alice-two --tool dispatch --target job-31 --asked "x"
rigAs=client-ndm ; rigSid=""
rigTool "$rigTmp/e3" --escalate-contact alice-two --tool dispatch --target job-31 --asked "x"
rigSid=sess-e
rigTool "$rigTmp/e4" --escalate-contact nobody-at-all --tool dispatch --target job-31 --asked "x"
rigTool "$rigTmp/e5" --escalate-contact alice-two --tool dispatch --target job-31
rigTool "$rigTmp/e6" --escalate-contact alice-two --tool dispatch --target job-31 --asked "$( printf 'x%.0s' $(seq 1 401) )"
rigTool "$rigTmp/e7" --escalate-contact alice-two --tool dispatch --target job-31 --asked x --soon
rigAssert "from no member's session, with no session, for a contact not recorded, with the asked text missing or too long, with an option it does not know: each refused, no refusal recorded" "$( rigHas 'comes from no member' "$rigTmp/e2.err" ) $( rigHas 'names none: --session-id' "$rigTmp/e3.err" ) $( rigHas 'no contact nobody-at-all is recorded' "$rigTmp/e4.err" ) $( rigHas '--tool, --target and --asked are needed' "$rigTmp/e5.err" ) $( rigHas 'at most 400 characters' "$rigTmp/e6.err" ) $( rigHas 'unknown option: --soon' "$rigTmp/e7.err" ) $( ls "$rigWs/.local/agents/sessions/sess-e" | LC_ALL=C grep -c '^refusal-' )" "1 1 1 1 1 1 1"

echo "-- 7. --allow-contact: a member gives a contact what it holds --"
rigAs=client-ndm ; rigSid=sess-e
rigTool "$rigTmp/w1" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefF" --kind session
rigAssert "a member that does not hold what the call is cannot give it: rc 3, the holders up the chain named, nothing granted" "$rigRc $( rigHas 'NOT-HOLDS: client-ndm dispatch job-30' "$rigTmp/w1.out" ) $( rigGrantCount ":$rigRefF\$" )" "3 1 0"
rigTool "$rigTmp/w2" --escalate-contact alice-two --tool SendMessage --target rig-room --asked "Alice Two wants a note in the rig room."
rigRefG="$( LC_ALL=C sed -n 's/^REFUSAL-ID: //p' "$rigTmp/w2.out" )"
rigTool "$rigTmp/w3" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefG" --kind session
rigAssert "one it holds (a tool of the team floor): given for the session, signed by the member and not by the human-owner" "$rigRc $( LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' "$rigTmp/w3.out" ) $( LC_ALL=C grep -c "^session:SendMessage:rig-room:client-ndm:[0-9TZ]*:$rigRefG\$" "$rigWs/.local/agents/sessions/sess-e/grants" ) $( LC_ALL=C grep -c "human-owner:[0-9TZ]*:$rigRefG\$" "$rigWs/.local/agents/sessions/sess-e/grants" )" "0 GRANT: session <ref> 1 0"
rigAssert "the log says who gave it, for which session" "$( LC_ALL=C grep -c -E -- "-- client-ndm -- allowed for the session sess-e: SendMessage rig-room \(refusal $rigRefG\)\$" "$rigPerson/alice-two.md" )" "1"
rigTool "$rigTmp/w4" --contact-access alice-two --tool SendMessage --target rig-room
rigAssert "the chain says so for the contact in that session" "$rigRc $( LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' "$rigTmp/w4.out" )" "0 GRANT: session <ref>"
rigTool "$rigTmp/w5" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefG" --kind contact
rigAssert "for the contact, standing: an allows: entry signed by the member" "$rigRc $( LC_ALL=C sed 's/refusal-[0-9a-f-]*/<ref>/' "$rigTmp/w5.out" ) $( rigKey "$rigPerson/alice-two.md" allows | LC_ALL=C sed -E 's/[0-9]{8}T[0-9]{6}Z/<time>/' )" "0 GRANT: contact <ref> contact:SendMessage:rig-room:client-ndm:<time>"
rigSid=sess-nothing
rigTool "$rigTmp/w6" --contact-access alice-two --tool SendMessage --target rig-room
rigAssert "and read for the contact in any session" "$rigRc $( LC_ALL=C cat "$rigTmp/w6.out" )" "0 GRANT: contact alice-two"
rigSid=sess-e
rigTool "$rigTmp/w7" --allow-contact alice-one --session-id sess-e --refusal-id "$rigRefG" --kind session
rigTool "$rigTmp/w8" --allow-contact alice-two --session-id sess-e --refusal-id refusal-nothing --kind session
rigTool "$rigTmp/w9" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefG" --kind once
rigTool "$rigTmp/w10" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefG"
rigAs="" ; rigTool "$rigTmp/w11" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefG" --kind session
rigAs=client-ndm
rigAssert "a refusal of another contact, one not there, a kind that is neither, a part missing, a call from no member's session: each refused" "$( rigHas 'is not one recorded for contact:alice-one' "$rigTmp/w7.err" ) $( rigHas 'is not one recorded for contact:alice-two' "$rigTmp/w8.err" ) $( rigHas '--kind is session' "$rigTmp/w9.err" ) $( rigHas 'are needed' "$rigTmp/w10.err" ) $( rigHas 'comes from no member' "$rigTmp/w11.err" )" "1 1 1 1 1"
rigOp "$rigTmp/w12" --intern-op-permission-refusal-log keeper-x --session-id sess-e --tool SendMessage --target rig-room
rigRefH="$( rigRefusalId "$rigTmp/w12" )"
rigTool "$rigTmp/w13" --allow-contact alice-two --session-id sess-e --refusal-id "$rigRefH" --kind session
rigAssert "a refusal of a member is not a contact's: refused, nothing granted" "$( rigHas 'is not one recorded for contact:alice-two' "$rigTmp/w13.err" ) $( LC_ALL=C grep -c ":$rigRefH\$" "$rigWs/.local/agents/sessions/sess-e/grants" )" "1 0"

echo "-- 8. the two scenarios --"
rigAs=client-ndm ; rigSid=sess-e
rigTool "$rigTmp/b1" --contacted-by U111ABC
rigAssert "being contacted, the sender recorded: its record, then what it holds, the tiers and the next step" "$rigRc $( rigHas '# Contact: Alice One' "$rigTmp/b1.out" ) $( rigHas 'Access of alice-one: dispatch on job-18 (allowed by human-owner), Read on /rig/projects/** (allowed by human-owner), Edit on /rig/secret.md (allowed by keeper-x)' "$rigTmp/b1.out" ) $( rigHas 'Ingest, always: read and understand it.' "$rigTmp/b1.out" ) $( rigHas 'DistroAgentsContacts.fn.sh --contact-access alice-one --tool <tool> --target <target>' "$rigTmp/b1.out" ) $( rigHas '--escalate-contact alice-one --tool <tool> --target <target> --asked' "$rigTmp/b1.out" )" "0 1 1 1 1 1"
rigTool "$rigTmp/b2" --contacted-by bare@ndm.example
rigAssert "a contact that holds nothing: said so, Ingest and Basic only" "$rigRc $( rigHas 'Access of bare-one: nothing standing, so Ingest and Basic only' "$rigTmp/b2.out" )" "0 1"
rigTool "$rigTmp/b3" --contacted-by UNOBODY999
rigAssert "a sender nobody recorded: the next step, rc 1" "$rigRc $( rigHas 'No contact is recorded for UNOBODY999.' "$rigTmp/b3.out" ) $( rigHas 'DistroAgentsContacts.fn.sh --collect-contact --id <slug> --name <name> --slack <team>:<slack-id>' "$rigTmp/b3.out" )" "1 1 1"
rigTool "$rigTmp/b4" --contacted-by "alice"
rigAssert "a value that names two contacts: the rows, and the way to say which, rc 1" "$rigRc $( LC_ALL=C grep -c '^contact' "$rigTmp/b4.out" ) $( rigHas 'names 2 contacts' "$rigTmp/b4.err" )" "1 2 1"
rigTool "$rigTmp/b5" --contacted-by U111ABC --team other-team
rigAssert "within a Slack team that is not the contact's: nobody recorded" "$rigRc" "1"
rigTool "$rigTmp/b6" --reach-contact alice-one
rigAssert "reaching one: the contact, how to meet it, its Slack and its e-mail with the send lines" "$rigRc $( rigHas 'Reach alice-one, Alice One of ndm. How to meet them: short messages.' "$rigTmp/b6.out" ) $( rigHas 'Slack: conversations client-ndm:D222DEF, ids client-ndm:U111ABC. Send with `DistroAgentsSlack.fn.sh --slack-send-message <you> <conversation> <text>`.' "$rigTmp/b6.out" ) $( rigHas 'E-mail: alice@ndm.example. Send with `DistroAgentsMail.fn.sh --email-send <you> <address> -- <subject> -- <body>`.' "$rigTmp/b6.out" ) $( rigHas 'A send to an address that is no coordinate of a contact you hold is refused.' "$rigTmp/b6.out" )" "0 1 1 1 1"
rigTool "$rigTmp/b7" --reach-contact bare-one
rigAssert "a contact with no Slack, no organisation and no how-to: those lines are left out" "$rigRc $( rigHas 'Reach bare-one, Bare One.' "$rigTmp/b7.out" ) $( rigHas 'Slack:' "$rigTmp/b7.out" ) $( rigHas 'How to meet' "$rigTmp/b7.out" ) $( rigHas 'E-mail: bare@ndm.example.' "$rigTmp/b7.out" )" "0 1 0 0 1"
rigTool "$rigTmp/b8" --reach-contact nobody-at-all
rigTool "$rigTmp/b9" --reach-contact Bad_Id
rigAssert "a contact not recorded, an id that is none: refused" "$( rigHas 'no contact nobody-at-all is recorded' "$rigTmp/b8.err" ) $( rigHas "lowercase letters, digits and hyphens: Bad_Id" "$rigTmp/b9.err" )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS ACCESS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_ACCESS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
