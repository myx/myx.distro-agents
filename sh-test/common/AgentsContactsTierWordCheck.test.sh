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
rigWords="ingest basic partner recorded"
rigWordOut=""
for rigWord in $rigWords ; do
	rigContact "$rigTmp/w-$rigWord" --id bob-one --tier "$rigWord" --reached-by keeper-x
	rigWordOut="$rigWordOut$( printf '%s:%s ' "$rigRc" "$( rigTier bob-one )" )"
done
rigAssert "each of ingest, basic, partner and recorded is written to the record's tier: by the human-owner's own call" "$rigWordOut" "0:ingest 0:basic 0:partner 0:recorded "
rigContact "$rigTmp/w5" --id bob-one --tier gold --reached-by keeper-x
rigAssert "a word that is none of the four: refused, naming the four, and the record keeps its own" "$rigRc $( rigHas 'ingest, basic, partner and recorded' "$rigTmp/w5.err" ) $( rigTier bob-one )" "1 1 recorded"

echo "-- 2. a member's call asks him, and writes nothing --"
rigAs=client-ndm
rigContact "$rigTmp/m1" --id bob-one --tier partner
rigAssert "the member's call writes no tier" "$rigRc $( rigTier bob-one )" "1 recorded"
rigAssert "it says the tier is his to set, and names the contact and the tier asked" "$( rigHas "--tier is the human-owner's to set" "$rigTmp/m1.err" ) $( rigHas 'bob-one' "$rigTmp/m1.err" ) $( rigHas 'partner' "$rigTmp/m1.err" )" "1 1 1"
rigAssert "it posted exactly one ask, into his own conversation" "$( rigPosts ) $( LC_ALL=C grep -c 'URIGOWNER' "$rigTmp"/post.1 2> /dev/null || : )" "1 1"
rigAsk="$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/m1.out" | LC_ALL=C cut -f3 )"
cp "$rigWs/.local/questions/$rigAsk.md" "$rigTmp/ask.record" 2> /dev/null || :
rigAssert "it prints ASKED with the contact, the tier and the ask it opened" "$( LC_ALL=C sed -n 's/^ASKED\t//p' "$rigTmp/m1.out" | LC_ALL=C cut -f1,2 ) $( printf '%s' "$rigAsk" | LC_ALL=C grep -c '^[0-9a-f-][0-9a-f-]*$' )" "bob-one	partner 1"
rigContact "$rigTmp/m2" --id bob-one --tier partner
rigAssert "the same call again asks nothing more: it names the ask already standing" "$( rigPosts ) $( rigHas 'already asked as' "$rigTmp/m2.err" )" "1 1"
## D6: a member's call carrying a tier loses no field in silence, and a refusal about its own case is true about that case.
rigContact "$rigTmp/d6a" --id bob-one --role "Chief Buyer" --tier partner
rigAssert "D6: a member's call that also carries a role writes no field of it, and says plainly that nothing in the call was written" "$rigRc $( rigHas '^role: ' "$rigData/contacts/persons/bob-one.md" ) $( rigHas 'nothing in this call was written' "$rigTmp/d6a.err" )" "1 0 1"
rigContact "$rigTmp/d6b" --id bob-two --name "Bob Two" --tier partner
rigAssert "D6: a tier ask about a contact not yet recorded refuses truly: it says the ask needs the record, and that the tier call writes nothing" "$rigRc $( [ -f "$rigData/contacts/persons/bob-two.md" ] && printf recorded || printf absent ) $( rigHas 'nothing in this call was written' "$rigTmp/d6b.err" ) $( rigHas 'is not recorded' "$rigTmp/d6b.err" )" "1 absent 1 1"

echo "-- 3. his verdict writes it --"
rigAskTs="$( LC_ALL=C sed -n 's/^question-ts: //p' "$rigTmp/ask.record" 2> /dev/null )"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"Set the tier of the contact bob-one? client-ndm proposes the tier partner."},{"ts":"1700000500.000001","user":"URIGOWNER","text":"basic","thread_ts":"%s"}]}' "$rigAskTs" "$rigAskTs" > "$RIG_SCENARIO/replies.$rigAskTs.json"
rigRun "$rigTmp/v1" "$rigTools" --intern-op-pending-reply-collect --ended
rigAssert "his word in the ask's own thread is read, carried out, and is the tier the record takes" "$rigRc $( rigTier bob-one )" "0 basic"

## ONE ANSWER SETS A TIER ONCE (S6.36). His answer's own action is run again: the answer he already gave must set no second tier, and the second
## run must refuse. The run above is what stamps it acted on, so the stamp is read here too.
echo "-- 3b. his answer is used once: its action run again writes nothing --"
rigAssert "the answer his first run used is stamped as acted on" "$( LC_ALL=C grep -c '^acted-at: ' "$rigWs/.local/questions/$rigAsk.md" "$rigWs/.local/agents/pending/closed/$rigAsk.md" 2> /dev/null | LC_ALL=C awk -F: '{ t = t + $2 } END { print t + 0 }' )" 1
## The same answer run again: the record must not be set from it a second time.
rigAuth="$rigAsk"
rigRun "$rigTmp/a2" "$rigTools" --intern-op-contact-tier-apply bob-one --by keeper-x
cat "$rigTmp/a2.err" >&2
rigAssert "the same answer run again writes nothing, and refuses" "$rigRc $( rigTier bob-one )" "1 basic"
rigAuth=""

echo "-- 4. what a later reader is told --"
rigAs=""
rigContact "$rigTmp/r1" --id bob-one --tier recorded --reached-by keeper-x
rigRun "$rigTmp/c1" "$rigTool" --contacted-by bob-one
rigAssert "a recorded contact: every tier below it printed, and recorded besides" "$( rigHas 'Ingest, always' "$rigTmp/c1.out" ) $( rigHas 'Basic, no record needed' "$rigTmp/c1.out" ) $( rigHas 'Partner: talk about what the team does' "$rigTmp/c1.out" ) $( rigHas 'Recorded: what affects the board' "$rigTmp/c1.out" )" "1 1 1 1"
rigContact "$rigTmp/r2" --id bob-one --tier ingest --reached-by keeper-x
rigRun "$rigTmp/c2" "$rigTool" --contacted-by bob-one
rigAssert "an ingest contact: ingest alone, and no word of partner or recorded" "$( rigHas 'Ingest, always' "$rigTmp/c2.out" ) $( rigHas 'Partner: talk about what the team does' "$rigTmp/c2.out" ) $( rigHas 'Recorded: what affects the board' "$rigTmp/c2.out" )" "1 0 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS TIER WORD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_TIER_WORD: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
