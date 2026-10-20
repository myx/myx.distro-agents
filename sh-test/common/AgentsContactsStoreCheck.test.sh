#!/usr/bin/env bash
## Behavioural check on the contacts store and its reads (F7.10 of the refactorings epic): DistroAgentsContacts.fn.sh --collect-organisation,
## --collect-contact, --find-contact, --all-contacts, --all-organisations and --contact-record, run rather than read, in a rig: a workspace with
## its team data root, a HOME, the real tooling. The store is the data root's contacts/ (one file a person, one an organisation); the records are
## written whole by the tool and read by its one reader, AgentsContactsIndex.awk. Held:
##   1. AN ORGANISATION is recorded, filled where it is known already (an empty field is filled, a known one stays and is said to, --correct replaces
##      it), unchanged where nothing is new (nothing is written), refused for an id that is none, no value, an option it does not know, a value too long.
##   2. A CONTACT is recorded with every field and the calling member in `reached-by:`; the file is exactly what the tool writes (front matter in
##      its order, an empty field left out, the title, the log with a dated line a change and a note). A second member's collect of the same id adds
##      that member and fills what is empty, keeps what is known and says so, replaces with --correct; the lists (coordinates, who holds it) only
##      grow, and --drop removes a coordinate. A key the tool does not know stays as it stands. Nothing is written for a call that adds nothing,
##      no temp file or lock is left, the mode is 644.
##   3. WHAT IS REFUSED, with nothing written: an id that is none, an organisation that is not recorded, a coordinate of a wrong shape (a Slack
##      id without its team, a team that is no bare name, an id in small letters, a handle without @, an e-mail that is none), --owner with a word
##      that is not yes or no, a value too long, a call with nothing to record, a new contact with neither a name nor a coordinate, a call from no
##      member's session without --reached-by, --reached-by naming another member than the session acts as, an option it does not know.
##   4. THE READS. --find-contact finds a contact by its id, a name (equal, or contained from three characters), a Slack id or conversation (with or
##      without its team, within --team), a handle (with or without @), an e-mail (without regard to case), and says what matched; --reached-by
##      keeps the ones a member holds; a miss ends 1 and says what was searched. --all-contacts and --all-organisations list by id, with their filters;
##      --contact-record prints the file whole and ends 1 for an id not recorded. A read creates nothing.
##   5. TWO CALLS AT ONCE do not lose one another: two members collecting one contact at the same moment both end up in it.
## Offline, rig tree only: nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactsStoreCheck )" || exit 1
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
mkdir -p "$rigWs/.local/temp" "$rigHome" "$rigData"
rigAs=""
rigRun(){ ## result prefix, tool words... -- one call of DistroAgentsContacts.fn.sh as the member in rigAs; rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
## A record as it stands, the stamps of its log lines made `<stamp>`, compared with the text it should be.
rigSame(){ ## file, expected text (given with a line break at its end)
	LC_ALL=C sed -E 's/^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4} -- /- <stamp> -- /' "$1" > "$rigTmp/actual.norm"
	printf '%s' "$2" > "$rigTmp/expected.norm"
	cmp -s "$rigTmp/actual.norm" "$rigTmp/expected.norm" && printf same || { printf 'DIFFERENT'; diff "$rigTmp/expected.norm" "$rigTmp/actual.norm" | head -8 | tr '\n' '~' ; }
}
rigPerson="$rigData/contacts/persons" rigOrg="$rigData/contacts/organisations"
rigBegin=$( date +%s )

echo "-- 1. an organisation --"
rigAs=client-ndm
rigRun "$rigTmp/o1" --collect-organisation --id ndm --name "NDM Ltd" --domain ndm.example
rigAssert "recorded: said so, rc 0" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/o1.out" )" "0 ORGANISATION: ndm created"
rigAssert "the file is what the tool writes: front matter, title, a dated log line of what was collected" "$( rigSame "$rigOrg/ndm.md" $'---\ntype: contact-organisation\norganisation-id: ndm\ndisplay-name: NDM Ltd\ndomain: ndm.example\n---\n# Organisation: NDM Ltd\n\n## Log\n\n- <stamp> -- client-ndm -- collected: display-name, domain\n' )" "same"
cp "$rigOrg/ndm.md" "$rigTmp/ndm.before"
rigRun "$rigTmp/o2" --collect-organisation --id ndm --name "NDM Ltd" --domain ndm.example
rigAssert "the same again: unchanged, and the file is not written" "$( LC_ALL=C sed -n 1p "$rigTmp/o2.out" ) $( cmp -s "$rigOrg/ndm.md" "$rigTmp/ndm.before" && printf same )" "ORGANISATION: ndm unchanged same"
rigRun "$rigTmp/o3" --collect-organisation --id ndm --name "NDM Limited" --note "the client of the rig"
rigAssert "a known name stays and is said to, an empty field is filled" "$( LC_ALL=C sed -n 1p "$rigTmp/o3.out" ) $( rigHas 'KEPT: display-name is NDM Ltd and stays; NDM Limited was given (--correct replaces a known value)' "$rigTmp/o3.out" ) $( LC_ALL=C sed -n 's/^display-name: //p' "$rigOrg/ndm.md" ) $( LC_ALL=C sed -n 's/^note: //p' "$rigOrg/ndm.md" )" "ORGANISATION: ndm updated 1 NDM Ltd the client of the rig"
rigRun "$rigTmp/o4" --collect-organisation --id ndm --name "NDM Limited" --correct
rigAssert "--correct replaces it, and the log says what it was" "$( LC_ALL=C sed -n 's/^display-name: //p' "$rigOrg/ndm.md" ) $( rigHas 'changed: display-name (corrected, was: NDM Ltd)' "$rigOrg/ndm.md" )" "NDM Limited 1"
rigRun "$rigTmp/o5" --collect-organisation --id Bad_Id --name x
rigRun "$rigTmp/o6" --collect-organisation --id other
rigRun "$rigTmp/o7" --collect-organisation --id other --name x --soon
rigRun "$rigTmp/o8" --collect-organisation --id other --name "$( printf 'x%.0s' $(seq 1 201) )"
rigAssert "an id that is none, nothing to record, an option it does not know, a name too long: refused, nothing written" "$( cat "$rigTmp/o5.err" "$rigTmp/o6.err" "$rigTmp/o7.err" "$rigTmp/o8.err" | LC_ALL=C grep -c 'DistroAgentsContacts: ⛔ ERROR' ) $( ls "$rigOrg" | LC_ALL=C grep -c . )" "4 1"

echo "-- 2. a contact --"
rigRun "$rigTmp/c1" --collect-contact --id alice-one --name "Alice One" --organisation ndm --role CTO --relationship "client lead" --how-to-meet "short messages, mornings" --owner no --slack client-ndm:U111ABC --slack-handle client-ndm:@alice --slack-conversation client-ndm:D222DEF --email Alice@Ndm.example --note "met in the client DM"
rigAssert "recorded: said so, rc 0, no warning" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/c1.out" ) $( LC_ALL=C grep -c . "$rigTmp/c1.out" )" "0 CONTACT: alice-one created 1"
rigAssert "the file is exactly what the tool writes: its fields in order, the title, a dated log line of what was collected, a line for the note" "$( rigSame "$rigPerson/alice-one.md" $'---\ntype: contact\ncontact-id: alice-one\ndisplay-name: Alice One\norganisation: ndm\nrole: CTO\nrelationship: client lead\nis-owner: no\nreached-by: client-ndm\nslack-id: client-ndm:U111ABC\nslack-handle: client-ndm:@alice\nslack-conversation: client-ndm:D222DEF\nemail: Alice@Ndm.example\nhow-to-meet: short messages, mornings\n---\n# Contact: Alice One\n\n## Log\n\n- <stamp> -- client-ndm -- collected: display-name, organisation, role, relationship, is-owner, how-to-meet, slack-id, slack-handle, slack-conversation, email, reached-by client-ndm\n- <stamp> -- client-ndm -- note: met in the client DM\n' )" "same"
rigAssert "the mode is 644 and no temp file or lock is left" "$( stat -f '%Lp' "$rigPerson/alice-one.md" 2> /dev/null || stat -c '%a' "$rigPerson/alice-one.md" ) $( ls -A "$rigPerson" | LC_ALL=C grep -c '\.write\.' ) $( ls "$rigWs/.local/agents/locks" 2> /dev/null | LC_ALL=C grep -c contacts-store )" "644 0 0"
cp "$rigPerson/alice-one.md" "$rigTmp/alice.before"
rigRun "$rigTmp/c2" --collect-contact --id alice-one --name "Alice One" --slack client-ndm:U111ABC --email alice@ndm.example
rigAssert "the same again, with an e-mail that differs only in case: unchanged, nothing written" "$( LC_ALL=C sed -n 1p "$rigTmp/c2.out" ) $( cmp -s "$rigPerson/alice-one.md" "$rigTmp/alice.before" && printf same )" "CONTACT: alice-one unchanged same"
rigAs=keeper-x
rigRun "$rigTmp/c3" --collect-contact --id alice-one --name "Alice X" --role CEO --relationship "friend of the house" --slack keeper-x:U999ZZZ --email a2@ndm.example
rigAssert "a second member: added to who holds it, what is empty is filled, what is known stays and is said to" "$( LC_ALL=C sed -n 1p "$rigTmp/c3.out" ) $( rigHas 'KEPT: display-name is Alice One and stays; Alice X was given (--correct replaces a known value)' "$rigTmp/c3.out" ) $( rigHas 'KEPT: role is CTO and stays; CEO was given (--correct replaces a known value)' "$rigTmp/c3.out" ) $( LC_ALL=C sed -n 's/^reached-by: //p' "$rigPerson/alice-one.md" ) $( LC_ALL=C sed -n 's/^display-name: //p' "$rigPerson/alice-one.md" )" "CONTACT: alice-one updated 1 1 client-ndm, keeper-x Alice One"
rigAssert "the lists only grew: both Slack ids, both e-mails" "$( LC_ALL=C sed -n 's/^slack-id: //p' "$rigPerson/alice-one.md" ) | $( LC_ALL=C sed -n 's/^email: //p' "$rigPerson/alice-one.md" )" "client-ndm:U111ABC, keeper-x:U999ZZZ | Alice@Ndm.example, a2@ndm.example"
rigRun "$rigTmp/c4" --collect-contact --id alice-one --role CEO --correct
rigAssert "--correct replaces a known value, and the log says what it was and who" "$( LC_ALL=C sed -n 's/^role: //p' "$rigPerson/alice-one.md" ) $( rigHas '-- keeper-x -- changed: role (corrected, was: CTO)' "$rigPerson/alice-one.md" )" "CEO 1"
rigRun "$rigTmp/c5" --collect-contact --id alice-one --drop keeper-x:U999ZZZ --drop A2@ndm.example
rigAssert "--drop removes a coordinate by the value as written, without regard to case; the others stay" "$( LC_ALL=C sed -n 's/^slack-id: //p' "$rigPerson/alice-one.md" ) | $( LC_ALL=C sed -n 's/^email: //p' "$rigPerson/alice-one.md" ) | $( rigHas 'changed: dropped keeper-x:U999ZZZ, A2@ndm.example' "$rigPerson/alice-one.md" )" "client-ndm:U111ABC | Alice@Ndm.example | 1"
## a key the tool does not know stays as it stands
LC_ALL=C awk 'NR > 1 && $0 == "---" && ! done { print "custom-key: kept as it stands" ; done = 1 } { print }' "$rigPerson/alice-one.md" > "$rigTmp/alice.custom" && cp "$rigTmp/alice.custom" "$rigPerson/alice-one.md"
rigRun "$rigTmp/c6" --collect-contact --id alice-one --note "second note"
rigAssert "a note alone is a log line and a rewrite, and a key the tool does not know stays: after the known ones, before the end of the front matter" "$( LC_ALL=C sed -n 1p "$rigTmp/c6.out" ) $( LC_ALL=C grep -n -x 'custom-key: kept as it stands' "$rigPerson/alice-one.md" | LC_ALL=C cut -d: -f1 ) $( LC_ALL=C grep -n -x -- '---' "$rigPerson/alice-one.md" | LC_ALL=C sed -n 2p | LC_ALL=C cut -d: -f1 ) $( rigHas 'note: second note' "$rigPerson/alice-one.md" )" "CONTACT: alice-one updated 15 16 1"
rigAssert "the log is in the order it happened" "$( LC_ALL=C sed -n '/^## Log/,$p' "$rigPerson/alice-one.md" | LC_ALL=C grep -c '^- ' ) $( LC_ALL=C sed -n '/^## Log/,$p' "$rigPerson/alice-one.md" | LC_ALL=C grep '^- ' | LC_ALL=C tail -1 | LC_ALL=C sed 's/^.* -- //' )" "6 note: second note"

echo "-- 3. what is refused --"
rigAs=client-ndm
before="$( ls -A "$rigPerson" | LC_ALL=C grep -c . )"
rigRun "$rigTmp/x1" --collect-contact --id Bad_Id --name x
rigRun "$rigTmp/x2" --collect-contact --id nobody-org --name x --organisation nowhere
rigRun "$rigTmp/x3" --collect-contact --id wrong-shape --slack U111ABC
rigRun "$rigTmp/x4" --collect-contact --id wrong-shape --slack "bad team:U111ABC"
rigRun "$rigTmp/x5" --collect-contact --id wrong-shape --slack client-ndm:u111abc
rigRun "$rigTmp/x6" --collect-contact --id wrong-shape --slack-handle client-ndm:alice
rigRun "$rigTmp/x7" --collect-contact --id wrong-shape --email not-an-address
rigRun "$rigTmp/x8" --collect-contact --id wrong-shape --name x --owner maybe
rigRun "$rigTmp/x9" --collect-contact --id wrong-shape --name "$( printf 'x%.0s' $(seq 1 201) )"
rigRun "$rigTmp/x10" --collect-contact --id wrong-shape
rigRun "$rigTmp/x11" --collect-contact --id wrong-shape --role CTO
rigRun "$rigTmp/x12" --collect-contact --id wrong-shape --name x --soon
rigAssert "an id that is none, an organisation not recorded, a Slack id without its team, a team that is no bare name, an id in small letters, a handle without @, an e-mail that is none, --owner with another word, a name too long, nothing to record, a new contact with no name and no coordinate, an unknown option: each refused" \
	"$( for rigN in 1 2 3 4 5 6 7 8 9 10 11 12 ; do rigRc="$( LC_ALL=C grep -c 'DistroAgentsContacts: ⛔ ERROR' "$rigTmp/x$rigN.err" )" ; printf '%s' "$rigRc" ; done )" "111111111111"
rigAssert "and nothing was written for any of them" "$( ls -A "$rigPerson" | LC_ALL=C grep -c . ) $before" "$before $before"
rigAssert "the reasons are said: the shape wanted, the organisation to record first" "$( rigHas 'a Slack coordinate is <team>:<value>' "$rigTmp/x3.err" ) $( rigHas 'record it first: --collect-organisation --id nowhere' "$rigTmp/x2.err" ) $( rigHas 'a Slack id is letters and digits in capitals' "$rigTmp/x5.err" ) $( rigHas 'a Slack handle is <team>:@<handle>' "$rigTmp/x6.err" ) $( rigHas 'not an e-mail address' "$rigTmp/x7.err" )" "1 1 1 1 1"
rigAs=""
rigRun "$rigTmp/x13" --collect-contact --id from-console --name "Console One"
rigAssert "from no member's session, without --reached-by: refused" "$rigRc $( rigHas 'comes from no member' "$rigTmp/x13.err" ) $( ls "$rigPerson" | LC_ALL=C grep -c 'from-console' )" "1 1 0"
rigRun "$rigTmp/x14" --collect-contact --id from-console --name "Console One" --reached-by keeper-y
rigAssert "with --reached-by: recorded as held by that member" "$rigRc $( LC_ALL=C sed -n 's/^reached-by: //p' "$rigPerson/from-console.md" ) $( rigHas '-- keeper-y -- collected:' "$rigPerson/from-console.md" )" "0 keeper-y 1"
rigAs=client-ndm
rigRun "$rigTmp/x15" --collect-contact --id from-console --note n --reached-by keeper-y
rigAssert "--reached-by naming another member than the session acts as: refused" "$rigRc $( rigHas 'it is for a call from no member' "$rigTmp/x15.err" )" "1 1"

echo "-- 4. the reads --"
rigRun "$rigTmp/o9" --collect-organisation --id acme --name "Acme"
rigAs=keeper-x
rigRun "$rigTmp/c7" --collect-contact --id bob-two --name "Bob Two" --organisation acme --slack keeper-x:U111ABC --slack-handle keeper-x:@bobby --email bob@acme.example
rigAs=""
rigFind(){ ## result prefix, find words... -- the rows as `id matched-on`, joined
	rigRun "$1" --find-contact "${@:2}"
	LC_ALL=C cut -f2,6 "$1.out" | LC_ALL=C tr '\t' ':' | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigAssert "by id" "$( rigFind "$rigTmp/f1" alice-one )" "alice-one:id"
rigAssert "by a name: equal, and contained from three characters; not contained under three" "$( rigFind "$rigTmp/f2" "alice one" ) | $( rigFind "$rigTmp/f3" bob ) | $( rigFind "$rigTmp/f4" ob ; printf '%s' "$rigRc" )" "alice-one:name | bob-two:name | 1"
rigAssert "by a Slack id: the two teams that hold the same id are two contacts, and --team keeps one" "$( rigFind "$rigTmp/f5" U111ABC ) | $( rigFind "$rigTmp/f6" U111ABC --team keeper-x ) | $( rigFind "$rigTmp/f7" keeper-x:U111ABC )" "alice-one:slack-id bob-two:slack-id | bob-two:slack-id | bob-two:slack-id"
rigAssert "by a conversation, with and without its team" "$( rigFind "$rigTmp/f8" D222DEF ) | $( rigFind "$rigTmp/f9" client-ndm:D222DEF )" "alice-one:slack-conversation | alice-one:slack-conversation"
rigAssert "by a handle, with or without @" "$( rigFind "$rigTmp/f10" @alice ) | $( rigFind "$rigTmp/f11" bobby )" "alice-one:slack-handle | bob-two:slack-handle"
rigAssert "by an e-mail, without regard to case" "$( rigFind "$rigTmp/f12" ALICE@NDM.EXAMPLE ) | $( rigFind "$rigTmp/f13" bob@acme.example )" "alice-one:email | bob-two:email"
rigAssert "--reached-by keeps the contacts a member holds" "$( rigFind "$rigTmp/f14" U111ABC --reached-by client-ndm ) | $( rigFind "$rigTmp/f15" U111ABC --reached-by keeper-x )" "alice-one:slack-id | alice-one:slack-id bob-two:slack-id"
rigRun "$rigTmp/f16" --find-contact nobody-at-all
rigAssert "a miss ends 1, prints nothing on stdout and says what was searched" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/f16.out" ) $( rigHas 'no contact matches "nobody-at-all"' "$rigTmp/f16.err" ) $( rigHas '3 contact(s)' "$rigTmp/f16.err" )" "1 0 1 1"
rigRun "$rigTmp/f17" --find-contact
rigRun "$rigTmp/f18" --find-contact a b
rigAssert "no value, or two: refused" "$( cat "$rigTmp/f17.rc" 2> /dev/null ) $( rigHas 'syntax is <value>' "$rigTmp/f17.err" ) $( rigHas 'one value, got a second' "$rigTmp/f18.err" )" " 1 1"
rigRun "$rigTmp/l1" --all-contacts
rigAssert "--all-contacts: a row each, by id: contact, id, name, organisation, who holds it" "$rigRc $( LC_ALL=C cut -f1-5 "$rigTmp/l1.out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "0 contact|alice-one|Alice One|ndm|client-ndm, keeper-x contact|bob-two|Bob Two|acme|keeper-x contact|from-console|Console One||keeper-y"
rigRun "$rigTmp/l2" --all-contacts --organisation ndm
rigRun "$rigTmp/l3" --all-contacts --reached-by keeper-y
rigRun "$rigTmp/l4" --all-contacts --organisation nowhere
rigAssert "the filters, and an empty answer that says so with rc 0" "$( LC_ALL=C cut -f2 "$rigTmp/l2.out" ) $( LC_ALL=C cut -f2 "$rigTmp/l3.out" ) $( LC_ALL=C grep -c . "$rigTmp/l4.out" ) $( rigHas 'no contact is recorded for the organisation nowhere' "$rigTmp/l4.err" ) $( cat "$rigTmp/l4.rc" 2> /dev/null )" "alice-one from-console 0 1 "
rigRun "$rigTmp/l5" --all-organisations
rigAssert "--all-organisations: a row each, by id, with the number of contacts" "$rigRc $( LC_ALL=C tr '\t' '|' < "$rigTmp/l5.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "0 organisation|acme|Acme||1 organisation|ndm|NDM Limited|ndm.example|1"
rigRun "$rigTmp/r1" --contact-record alice-one
rigAssert "--contact-record prints the file whole" "$( cmp -s "$rigTmp/r1.out" "$rigPerson/alice-one.md" && printf same )" "same"
rigRun "$rigTmp/r2" --contact-record nobody-at-all
rigRun "$rigTmp/r3" --contact-record Bad_Id
rigRun "$rigTmp/r4" --contact-record
rigAssert "an id not recorded, an id that is none, no id: each refused with the reason" "$( rigHas 'no contact nobody-at-all is recorded' "$rigTmp/r2.err" ) $( rigHas "lowercase letters, digits and hyphens: Bad_Id" "$rigTmp/r3.err" ) $( rigHas 'syntax is <id>' "$rigTmp/r4.err" )" "1 1 1"
rm -rf "$rigData/contacts"
rigRun "$rigTmp/n1" --all-contacts
rigRun "$rigTmp/n2" --find-contact x
rigRun "$rigTmp/n3" --all-organisations
rigAssert "a read of a store that is not there creates nothing and says it is empty" "$( cat "$rigTmp/n1.rc" 2> /dev/null ) $( [ -e "$rigData/contacts" ] && printf made || printf nothing-made ) $( rigHas 'no contact is recorded' "$rigTmp/n1.err" ) $( rigHas 'no organisation is recorded' "$rigTmp/n3.err" )" " nothing-made 1 1"

echo "-- 5. two calls at once --"
rigAs=client-ndm
rigRun "$rigTmp/s0" --collect-contact --id shared-one --name "Shared One" --email shared@example.com
( rigAs=client-ndm ; rigRun "$rigTmp/s1" --collect-contact --id shared-one --slack client-ndm:USHARED1 ) &
rigPid1=$!
( rigAs=keeper-x ; rigRun "$rigTmp/s2" --collect-contact --id shared-one --slack keeper-x:USHARED2 --email shared2@example.com ) &
rigPid2=$!
( rigAs=keeper-y ; rigRun "$rigTmp/s3" --collect-contact --id shared-two --name "Shared Two" --email two@example.com ) &
rigPid3=$!
wait "$rigPid1" "$rigPid2" "$rigPid3"
rigAssert "both members' coordinates are in the record, and who holds it" "$( LC_ALL=C sed -n 's/^slack-id: //p' "$rigPerson/shared-one.md" | LC_ALL=C tr ',' '\n' | LC_ALL=C sed 's/^ *//' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' ) | $( LC_ALL=C sed -n 's/^reached-by: //p' "$rigPerson/shared-one.md" | LC_ALL=C tr ',' '\n' | LC_ALL=C sed 's/^ *//' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "client-ndm:USHARED1 keeper-x:USHARED2  | client-ndm keeper-x "
rigAssert "the third, of another record, was written too, and the lock is given back" "$( ls "$rigPerson" | LC_ALL=C tr '\n' ' ' ) $( ls "$rigWs/.local/agents/locks" 2> /dev/null | LC_ALL=C grep -c contacts-store )" "shared-one.md shared-two.md  0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS STORE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_STORE: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
