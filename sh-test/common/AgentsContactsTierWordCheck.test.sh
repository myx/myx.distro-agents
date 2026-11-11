#!/usr/bin/env bash
## Behavioural check on a contact's tier as S6.36 and S6.17 settle it: the record holds the tier word itself, one of
## `ingest`, `basic`, `partner` and `recorded`, each including the tiers below it, and the tier is the human-owner's to
## set -- a member's call asks him once, in his own conversation, naming the contact and the proposed tier, and his
## verdict writes it. Run rather than read, in a rig: a workspace with its team data root, a HOME, the real tooling, and
## a Slack-shaped fake curl first on PATH. Held:
##   1. THE FOUR WORDS. Each of `ingest`, `basic`, `partner` and `recorded` is written to `tier:` by the call the
##      human-owner makes at the console, and a fifth word is refused, naming the four.
##   2. THE MEMBER'S CALL ASKS. It writes no tier: it posts one ask into his own conversation, naming the contact and
##      the proposed tier, prints `ASKED <contact> <tier> <ask>`, and ends 1. The second identical call asks nothing
##      more: it names the ask already standing.
##   3. HIS VERDICT WRITES IT. The request settled as his, with the tier word he chose, writes `tier:` when the action
##      it keeps is run; a request not answered by him writes nothing.
##   4. WHAT HIS ANSWER MEANS TO A LATER READER. `--contacted-by` prints the tier's own rules for each of the four
##      words, and each prints every tier below it.
## Red before this build: the record took `partner` and `recorded` only, a member's call was refused with no ask made,
## and `ingest` and `basic` were refused as no tier.
## Offline: the fake curl answers every request, so nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactsTierWordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigBin"
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigBin/curl" && chmod +x "$rigBin/curl" || rigRefuse "the fake curl could not be put in the rig"
## The account at the console that is the human-owner, and the conversation his asks go to.
rigAcct="$( id -un 2> /dev/null )" || rigAcct="unknown"
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
printf 'HUMAN_OWNER_CONSOLE_ACCOUNT=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigAcct" > "$rigWs/.local/.agents/magic-team.agent.env"
## The members the rig's calls act as: a send names one, and its skill folder must stand.
for rigMember in keeper-x client-ndm magic-coordinator human-owner ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
RIG_CURL_LOG="$rigTmp/curl.log" RIG_SCENARIO="$rigTmp"
export RIG_CURL_LOG RIG_SCENARIO
: > "$RIG_CURL_LOG"
rigAuth=""
rigRun(){ ## result prefix, tool, words... -- rc in rigRc
	local runOut="$1" runTool="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" RIG_CURL_LOG="$RIG_CURL_LOG" RIG_SCENARIO="$RIG_SCENARIO" \
		${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} ${rigSid:+MDAT_SPAWN_SESSION_ID="$rigSid"} ${rigAuth:+MDAT_AUTHORITY_REQUEST="$rigAuth"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$runTool" "$@" ) \
		> "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigContact(){ ## result prefix, words after --collect-contact
	local contactOut="$1" ; shift
	rigRun "$contactOut" "$rigTool" --collect-contact "$@"
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" 2> /dev/null || :
}
rigTier(){ ## contact id -- its `tier:` as it stands
	LC_ALL=C sed -n 's/^tier: //p' "$rigData/contacts/persons/$1.md" 2> /dev/null
}
rigPosts(){ ## -- how many messages the fake Slack was asked to post
	LC_ALL=C grep -c '^chat.postMessage$' "$RIG_CURL_LOG" 2> /dev/null || :
}
## One contact, held by a member, with no tier yet.
rigAs=keeper-x
rigContact "$rigTmp/bob" --id bob-one --name "Bob One"
rigAs=""
rigAssert "the rig's contact is recorded" "$rigRc $( rigHas 'CONTACT: bob-one created' "$rigTmp/bob.out" )" "0 1"

echo "-- 1. the four tier words, and no fifth --"
rigWords="tier-moot tier-contact tier-client tier-admin tier-owner"
rigWordOut=""
for rigWord in $rigWords ; do
	rigContact "$rigTmp/w-$rigWord" --id bob-one --tier "$rigWord" --reached-by keeper-x
	rigWordOut="$rigWordOut$( printf '%s:%s ' "$rigRc" "$( rigTier bob-one )" )"
done
rigAssert "each of the five tier words is written to the record's tier: by the human-owner's own call" "$rigWordOut" "0:tier-moot 0:tier-contact 0:tier-client 0:tier-admin 0:tier-owner "
rigContact "$rigTmp/w4" --id bob-one --tier partner --reached-by keeper-x
rigAssert "a retired old word (partner): refused, naming the five, and the record keeps its own" "$rigRc $( rigHas 'tier-moot, tier-contact, tier-client, tier-admin and tier-owner' "$rigTmp/w4.err" ) $( rigTier bob-one )" "1 1 tier-owner"
rigContact "$rigTmp/w5" --id bob-one --tier gold --reached-by keeper-x
rigAssert "a word that is none of the four: refused, naming the four, and the record keeps its own" "$rigRc $( rigHas 'tier-moot, tier-contact, tier-client, tier-admin and tier-owner' "$rigTmp/w5.err" ) $( rigTier bob-one )" "1 1 tier-owner"

echo "-- 2. a member's call asks him, and writes nothing --"
rigAs=client-ndm
rigContact "$rigTmp/m1" --id bob-one --tier tier-client
rigAssert "the member's call writes no tier" "$rigRc $( rigTier bob-one )" "1 tier-owner"
rigAssert "it says the tier is his to set, and names the contact and the tier asked" "$( rigHas "--tier is the human-owner's to set" "$rigTmp/m1.err" ) $( rigHas 'bob-one' "$rigTmp/m1.err" ) $( rigHas 'tier-client' "$rigTmp/m1.err" )" "1 1 1"
rigAssert "it posted exactly one ask, into his own conversation" "$( rigPosts ) $( LC_ALL=C grep -c 'URIGOWNER' "$rigTmp"/post.1 2> /dev/null || : )" "1 1"
rigAsk="$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/m1.out" | LC_ALL=C cut -f3 )"
cp "$rigWs/.local/questions/$rigAsk.md" "$rigTmp/ask.record" 2> /dev/null || :
rigAssert "it prints ASKED with the contact, the tier and the ask it opened" "$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/m1.out" | LC_ALL=C cut -f1,2 ) $( printf '%s' "$rigAsk" | LC_ALL=C grep -c '^[0-9a-f-][0-9a-f-]*$' )" "bob-one	tier-client 1"
rigContact "$rigTmp/m2" --id bob-one --tier tier-client
rigAssert "the same call again asks nothing more: it names the ask already standing" "$( rigPosts ) $( rigHas 'already asked as' "$rigTmp/m2.err" )" "1 1"
## D6: a member's call carrying a tier loses no field in silence, and a refusal about its own case is true about that case.
rigContact "$rigTmp/d6a" --id bob-one --role "Chief Buyer" --tier tier-client
rigAssert "D6: a member's call that also carries a role writes no field of it, and says plainly that nothing in the call was written" "$rigRc $( rigHas '^role: ' "$rigData/contacts/persons/bob-one.md" ) $( rigHas 'nothing in this call was written' "$rigTmp/d6a.err" )" "1 0 1"
rigContact "$rigTmp/d6b" --id bob-two --name "Bob Two" --tier tier-client
rigAssert "D6: a tier ask about a contact not yet recorded refuses truly: it says the ask needs the record, and that the tier call writes nothing" "$rigRc $( [ -f "$rigData/contacts/persons/bob-two.md" ] && printf recorded || printf absent ) $( rigHas 'nothing in this call was written' "$rigTmp/d6b.err" ) $( rigHas 'is not recorded' "$rigTmp/d6b.err" )" "1 absent 1 1"

echo "-- 3. his verdict writes it --"
rigAskTs="$( LC_ALL=C sed -n 's/^question-ts: //p' "$rigTmp/ask.record" 2> /dev/null )"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"Set the tier of the contact bob-one? client-ndm proposes the tier partner."},{"ts":"1700000500.000001","user":"URIGOWNER","text":"tier-contact","thread_ts":"%s"}]}' "$rigAskTs" "$rigAskTs" > "$RIG_SCENARIO/replies.$rigAskTs.json"
rigRun "$rigTmp/v1" "$rigTools" --intern-op-pending-reply-collect --ended
rigAssert "his word in the ask's own thread is read, carried out, and is the tier the record takes" "$rigRc $( rigTier bob-one )" "0 tier-contact"

## ONE ANSWER SETS A TIER ONCE (S6.36). His answer's own action is run again: the answer he already gave must set no second tier, and the second
## run must refuse. The run above is what stamps it acted on, so the stamp is read here too.
echo "-- 3b. his answer is used once: its action run again writes nothing --"
rigAssert "the answer his first run used is stamped as acted on" "$( LC_ALL=C grep -c '^acted-at: ' "$rigWs/.local/questions/$rigAsk.md" "$rigWs/.local/agents/pending/closed/$rigAsk.md" 2> /dev/null | LC_ALL=C awk -F: '{ t = t + $2 } END { print t + 0 }' )" 1
## The same answer run again: the record must not be set from it a second time.
rigAuth="$rigAsk"
rigRun "$rigTmp/a2" "$rigTools" --intern-op-contact-tier-apply bob-one --by keeper-x
cat "$rigTmp/a2.err" >&2
rigAssert "the same answer run again writes nothing, and refuses" "$rigRc $( rigTier bob-one )" "1 tier-contact"
rigAuth=""

echo "-- 3c. a member's --scope-tier asks him too, and his answer writes that scope --"
rigAs=client-ndm
rigPostsBefore="$( rigPosts )"
rigContact "$rigTmp/sc1" --id bob-one --scope-tier rmm2=partner
rigAssert "the member's scope call writes no scope tier, says it is his to set, and asked once more" "$rigRc [$( LC_ALL=C sed -n 's/^scope-tiers: //p' "$rigData/contacts/persons/bob-one.md" )] $( rigHas "--scope-tier is the human-owner's to set" "$rigTmp/sc1.err" ) $(( $( rigPosts ) - rigPostsBefore ))" "1 [] 1 1"
rigScopeAsk="$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/sc1.out" | LC_ALL=C cut -f3 )"
rigAssert "it prints ASKED with the contact and the scope=tier proposed" "$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/sc1.out" | LC_ALL=C cut -f1,2 )" "bob-one	rmm2=tier-client"
rigContact "$rigTmp/sc2" --id bob-one --scope-tier rmm2=partner
rigAssert "the same call again asks nothing more: the ask for that scope stands" "$(( $( rigPosts ) - rigPostsBefore )) $( rigHas 'already asked as' "$rigTmp/sc2.err" )" "1 1"
rigContact "$rigTmp/sc3" --id bob-one --scope-tier rmm2=partner --scope-tier ndmp=partner
rigAssert "two scopes in a member's call are refused, nothing asked" "$rigRc $( rigHas 'one --scope-tier at a time' "$rigTmp/sc3.err" ) $(( $( rigPosts ) - rigPostsBefore ))" "1 1 1"
cp "$rigWs/.local/questions/$rigScopeAsk.md" "$rigTmp/scope.record" 2> /dev/null || :
rigScopeTs="$( LC_ALL=C sed -n 's/^question-ts: //p' "$rigTmp/scope.record" 2> /dev/null )"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"Set the tier of the contact bob-one for the scope rmm2?"},{"ts":"1700000600.000001","user":"URIGOWNER","text":"tier-admin","thread_ts":"%s"}]}' "$rigScopeTs" "$rigScopeTs" > "$RIG_SCENARIO/replies.$rigScopeTs.json"
rigRun "$rigTmp/sc4" "$rigTools" --intern-op-pending-reply-collect --ended
rigAssert "his word is carried out: the scope takes it, the record's own tier stays" "$rigRc $( LC_ALL=C sed -n 's/^scope-tiers: //p' "$rigData/contacts/persons/bob-one.md" ) $( rigTier bob-one )" "0 rmm2=tier-admin tier-contact"
rigAs=""

echo "-- 4. what a later reader is told --"
rigAs=""
rigContact "$rigTmp/r1" --id bob-one --tier recorded --reached-by keeper-x
rigRun "$rigTmp/c1" "$rigTool" --contacted-by bob-one
rigAssert "a recorded contact: every tier below it printed, and recorded besides" "$( rigHas 'Moot, always' "$rigTmp/c1.out" ) $( rigHas 'Contact, no record needed' "$rigTmp/c1.out" ) $( rigHas 'Client: talk about what the team does' "$rigTmp/c1.out" ) $( rigHas 'Admin: what affects the board' "$rigTmp/c1.out" )" "1 1 1 1"
rigContact "$rigTmp/r2" --id bob-one --tier ingest --reached-by keeper-x
rigRun "$rigTmp/c2" "$rigTool" --contacted-by bob-one
rigAssert "an ingest contact: ingest alone, and no word of partner or recorded" "$( rigHas 'Moot, always' "$rigTmp/c2.out" ) $( rigHas 'Client: talk about what the team does' "$rigTmp/c2.out" ) $( rigHas 'Admin: what affects the board' "$rigTmp/c2.out" )" "1 0 0"

echo "-- 5. an organisation's members hold tier-contact, and a tier per scope --"
rigAs=keeper-x
rigRun "$rigTmp/org" "$rigTool" --collect-organisation --id acme-org --name "Acme"
rigPostsBefore="$( rigPosts )"
rigContact "$rigTmp/o1" --id carol-one --name "Carol One" --organisation acme-org
rigAs=""
rigAssert "a new contact of an organisation, given no tier, holds tier-contact without an ask: no message was posted for it" "$rigRc $( rigTier carol-one ) $(( $( rigPosts ) - rigPostsBefore ))" "0 tier-contact 0"
rigAs=keeper-x
rigContact "$rigTmp/o2" --id dave-one --name "Dave One"
rigAs=""
rigAssert "a contact of no organisation holds no tier until he sets one" "$rigRc [$( rigTier dave-one )]" "0 []"
rigAs=keeper-x
rigContact "$rigTmp/s1" --id carol-one --scope-tier rmm2=tier-client --reached-by keeper-x
rigAs=""
rigAssert "a member's --scope-tier is refused as his to set, and writes nothing" "$rigRc $( rigHas "--scope-tier is the human-owner's to set" "$rigTmp/s1.err" ) [$( LC_ALL=C sed -n 's/^scope-tiers: //p' "$rigData/contacts/persons/carol-one.md" )]" "1 1 []"
rigContact "$rigTmp/s2" --id carol-one --scope-tier rmm2=partner --reached-by keeper-x
rigAssert "his --scope-tier is written, an old word read as its new one" "$rigRc $( LC_ALL=C sed -n 's/^scope-tiers: //p' "$rigData/contacts/persons/carol-one.md" )" "0 rmm2=tier-client"
rigContact "$rigTmp/s3" --id carol-one --scope-tier ndmp=tier-admin --scope-tier rmm2=tier-admin --reached-by keeper-x
rigAssert "a second scope is added and the first scope's entry is replaced, one entry a scope" "$rigRc $( LC_ALL=C sed -n 's/^scope-tiers: //p' "$rigData/contacts/persons/carol-one.md" )" "0 ndmp=tier-admin,rmm2=tier-admin"
rigContact "$rigTmp/s4" --id carol-one --scope-tier rmm2 --reached-by keeper-x
rigAssert "a --scope-tier without its tier is refused" "$rigRc $( rigHas "is <scope>=<tier>" "$rigTmp/s4.err" )" "1 1"
rigContact "$rigTmp/s5" --id carol-one --scope-tier rmm2=gold --reached-by keeper-x
rigAssert "a --scope-tier with a word that is no tier is refused" "$rigRc $( rigHas 'tier-moot, tier-contact, tier-client, tier-admin and tier-owner' "$rigTmp/s5.err" )" "1 1"
rigRun "$rigTmp/c5" "$rigTool" --contacted-by carol-one --team ndmp
rigAssert "contacted for a scope, the tier of that scope reads back: ndmp is admin" "$( rigHas 'This contact is an admin.' "$rigTmp/c5.out" )" 1
rigRun "$rigTmp/c6" "$rigTool" --contacted-by carol-one
rigAssert "contacted for no scope, the record's own tier reads back: tier-contact" "$( rigHas 'This contact stands at Contact.' "$rigTmp/c6.out" )" 1

## An older record, written before the organisation grant: an organisation and no tier. Read, it stands at tier-contact, and nothing is written by the read.
printf -- '---\ntype: contact\ncontact-id: erin-one\ndisplay-name: Erin One\norganisation: acme-org\nemail: erin@example.invalid\n---\n# Contact: Erin One\n\n## Log\n\n' > "$rigData/contacts/persons/erin-one.md"
rigErinBefore="$( cksum < "$rigData/contacts/persons/erin-one.md" )"
rigRun "$rigTmp/c7" "$rigTool" --contacted-by erin-one
rigAssert "an older record with an organisation and no tier reads as tier-contact, and the read writes nothing" "$( rigHas 'This contact stands at Contact.' "$rigTmp/c7.out" ) $( [ "$( cksum < "$rigData/contacts/persons/erin-one.md" )" = "$rigErinBefore" ] && printf same || printf changed )" "1 same"

## The scope tiers in the reads: the last field of a row, and a filter by scope or by scope=tier.
rigRun "$rigTmp/c8" "$rigTool" --all-contacts
rigAssert "--all-contacts: carol-one's row ends in her scope tiers, erin-one's in -" "$( LC_ALL=C awk -F'\t' '$2 == "carol-one" { print $7 }' "$rigTmp/c8.out" ) $( LC_ALL=C awk -F'\t' '$2 == "erin-one" { print $7 }' "$rigTmp/c8.out" )" "ndmp=tier-admin,rmm2=tier-admin -"
rigRun "$rigTmp/c9" "$rigTool" --all-contacts --scope ndmp
rigAssert "--all-contacts --scope ndmp keeps the contacts holding that scope, and only them" "$( LC_ALL=C cut -f2 "$rigTmp/c9.out" | LC_ALL=C tr '\n' ' ' )" "carol-one "
rigRun "$rigTmp/c10" "$rigTool" --all-contacts --scope rmm2=tier-client
rigAssert "--scope rmm2=tier-client keeps nobody, as her rmm2 tier is tier-admin" "$( LC_ALL=C grep -c '^contact' "$rigTmp/c10.out" || true )" 0
rigRun "$rigTmp/c11" "$rigTool" --find-contact carol-one --scope rmm2=tier-admin
rigAssert "--find-contact with --scope rmm2=tier-admin finds her, matched on id, scope tiers last" "$( LC_ALL=C awk -F'\t' '{ print $2 " " $6 " " $7 }' "$rigTmp/c11.out" )" "carol-one id ndmp=tier-admin,rmm2=tier-admin"

## How an ask to a tier closes: the first answer for tier-owner, a quorum for tier-admin, stuck where no quorum can come.
rigClose(){ ## tier, holders, answers... -- what the decision prints
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.Contacts.include" 2> /dev/null ; AgentsToolsContactsTierClosing "$@"' rig "$@" 2>&1
}
rigAssert "tier-owner with no answer is open" "$( rigClose tier-owner 3 )" open
rigAssert "tier-owner closes on the first answer, a no among later yeses" "$( rigClose tier-owner 3 a=no b=yes c=yes )" "closed no"
rigAssert "tier-admin, three hold it, one yes: open" "$( rigClose tier-admin 3 a=yes )" open
rigAssert "tier-admin, three hold it, two yes: closed yes" "$( rigClose tier-admin 3 a=yes b=yes )" "closed yes"
rigAssert "tier-admin, a no then two yes: closed yes, the quorum is two" "$( rigClose tier-admin 3 a=no b=yes c=yes )" "closed yes"
rigAssert "tier-admin, one yes one no, one still to come: open" "$( rigClose tier-admin 3 a=yes b=no )" open
rigAssert "tier-admin, four hold it, two and two: stuck, the quorum is three" "$( rigClose tier-admin 4 a=yes b=yes c=no d=no )" stuck
rigAssert "one contact counts once, the latest answer" "$( rigClose tier-admin 3 a=yes a=yes b=no )" open
rigAssert "an owner in the admin quorum: two admins agree, the one owner silent, three hold it: closed" "$( rigClose tier-admin 3 a=yes b=yes )" "closed yes"
rigAssert "an owner's answer overrides the admins' quorum at once" "$( rigClose tier-admin 3 a=yes b=yes o@tier-owner=no )" "closed no"
rigAssert "an owner's answer alone needs no quorum" "$( rigClose tier-admin 5 o@tier-owner=yes )" "closed yes"
rigAssert "two owners: the first to answer decides" "$( rigClose tier-admin 4 p@tier-owner=no q@tier-owner=yes )" "closed no"
rigAssert "a tier with no rule of its own is refused" "$( rigClose tier-client 3 a=yes )" "rig: ⛔ ERROR: tier closing: only tier-admin and tier-owner close an ask by their own rule: tier-client"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS TIER WORD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_TIER_WORD: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
