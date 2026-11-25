#!/usr/bin/env bash
## Behavioural check: a contact's tier reaches every reader of a contact row, so no run has to guess it. A sweep wrote "he is at
## tier-contact" of a person whose record holds tier-admin, because neither the row of --find-contact nor the [sender: ...] mark carried a tier.
## Held:
##   1. THE ROW CARRIES THE TIER: --find-contact prints the record's own tier as its last column, and `-` where the record holds none.
##   2. THE MARK CARRIES THE TIER: the [sender: ...] mark of a line read names the tier of a contact that holds one, and names none for one that holds none.
## Red before the fix: row 1 reads eight columns and row 2's mark ends at the contact id.
## Offline: a folder of this rig's own stands for the team data. No Slack call is made: both accounts are known.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/contacts/AgentsContactsIndex.awk" ] || rigRefuse "the contacts index is not at $rigPackage"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactTierRowCheck )" || exit 1
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
	return 0
}

rigPersons="$rigTmp/data/contacts/persons"
mkdir -p "$rigPersons" "$rigTmp/ws/.local/agents" || exit 1
printf -- '---\ntype: contact\ncontact-id: rig-admin\ndisplay-name: Rig Admin\norganisation: rigorg\nreached-by: magic-coordinator\ntier: tier-admin\nslack-id: rigteam:URIGADMIN01\n---\n\n# Rig Admin\n' > "$rigPersons/rig-admin.md"
printf -- '---\ntype: contact\ncontact-id: rig-plain\ndisplay-name: Rig Plain\norganisation: rigorg\nreached-by: magic-coordinator\nslack-id: rigteam:URIGPLAIN01\n---\n\n# Rig Plain\n' > "$rigPersons/rig-plain.md"

echo "-- 1. the row --"
rigRow(){ ## contact id -- the row of --find-contact
	( cd "$rigTmp/ws" && env -i PATH=/usr/bin:/bin:/opt/homebrew/bin HOME="$rigTmp" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh" --find-contact "$1" 2> /dev/null )
}
rigAssert "a record with a tier: its own tier is the last column" "$( rigRow rig-admin | LC_ALL=C awk -F'\t' '{ print NF ":" $9 ; }' )" "9:tier-admin"
rigAssert "a record with none: a dash" "$( rigRow rig-plain | LC_ALL=C awk -F'\t' '{ print NF ":" $9 ; }' )" "9:-"

echo "-- 2. the mark --"
rigMark(){ ## line -- the line as the sender mark returns it
	printf '%s\n' "$1" | ( cd "$rigTmp/ws" && env -i PATH=/usr/bin:/bin:/opt/homebrew/bin HOME="$rigTmp" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" RIG_PACKAGE_DIR="$rigPackage" \
		bash -c '. "$RIG_PACKAGE_DIR/sh-lib/slack/AgentsTools.SlackSenderMark.include" && AgentsToolsMemberSlackSenderMark' 2> /dev/null )
}
rigAssert "a contact with a tier: the mark names it after the contact id" "$( rigMark '1700000000.000100 | URIGADMIN01 | a request' | LC_ALL=C grep -c '\[sender: Rig Admin, rigorg, contact rig-admin, tier-admin\]' )" "1"
rigAssert "a contact with none: the mark ends at the contact id" "$( rigMark '1700000000.000200 | URIGPLAIN01 | a request' | LC_ALL=C grep -c '\[sender: Rig Plain, rigorg, contact rig-plain\]' )" "1"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
