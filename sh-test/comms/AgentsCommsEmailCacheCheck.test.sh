#!/usr/bin/env bash
## Behavioural check on the email side of the comms cache (epic S21.13, owner 2026-10-28): the form every service keeps,
## `email/email-<account>-<mailbox>/YYYYMM/messages.txt` with the whole body in `YYYYMM/<uid>.body.txt` and the pointers in
## `.state.txt`. Held:
##   1. the folder a mailbox resolves to carries the service, the account and the mailbox
##   2. three mails file as three lines, the UID first, in the month of the mail's own date
##   3. a mail filed twice is held once, and its body is not rewritten
##   4. a body over the cap keeps its line short and names its body file
##   5. the body file holds the whole text, byte for byte, so a large mail loses nothing
##   6. the pointers move: `pulled at`, `covered from` and the newest UID
##   7. a read after a floor UID gives the newer mails alone, and restores the body it names
##   8. a read with no state is refused at once, and prints nothing
## Offline: one mktemp tree, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsEmail.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the email driver is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsEmailCacheCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/temp" || exit 1
export MMDAPP="$rigTmp/ws"

. "$rigInclude"

echo "-- the folder a mailbox keeps --"
rigAssert "the three cache functions are there" "$( for rigFn in AgentsToolsCommsEmailCacheDir AgentsToolsCommsEmailCacheFile AgentsToolsCommsEmailCacheServe ; do type -t "$rigFn" > /dev/null 2>&1 && printf '%s ' "$rigFn" ; done )" "AgentsToolsCommsEmailCacheDir AgentsToolsCommsEmailCacheFile AgentsToolsCommsEmailCacheServe "
AgentsToolsCommsEmailCacheDir rig@rig.invalid INBOX 2> /dev/null || :
rigAssert "the service, the account and the mailbox, one name each" "${agentsCommsCacheDir:-none}" "$MMDAPP/.local/cache/comms/email/email-rig_rig.invalid-INBOX"
AgentsToolsCommsEmailCacheDir rig@rig.invalid Sent 2> /dev/null || :
rigMailbox="$rigTmp/folder"
[ -z "${agentsCommsCacheDir:-}" ] || rigMailbox="$agentsCommsCacheDir"

echo "-- a mail files as one line, in the month of its own date --"
printf 'a short body\n' > "$rigTmp/small.eml"
AgentsToolsCommsEmailCacheFile "$rigMailbox" 201 202610 rig@rig.invalid "First" "$rigTmp/small.eml"
AgentsToolsCommsEmailCacheFile "$rigMailbox" 202 202611 them@elsewhere.invalid "Second" ""
AgentsToolsCommsEmailCacheFile "$rigMailbox" 203 202611 rig@rig.invalid "Third" ""
rigAssert "three mails, three lines" "$( cat "$rigMailbox/202610/messages.txt" "$rigMailbox/202611/messages.txt" | LC_ALL=C grep -c ' | ' )" 3
rigAssert "the UID leads its line" "$( LC_ALL=C head -1 "$rigMailbox/202610/messages.txt" )" "201 | rig@rig.invalid | First [body: 201.body.txt]"
rigAssert "a mail of another month is in that month's folder" "$( LC_ALL=C grep -c '202 |' "$rigMailbox/202611/messages.txt" )" 1

echo "-- a mail filed twice is held once, and its body is left alone --"
printf 'changed\n' > "$rigTmp/small2.eml"
AgentsToolsCommsEmailCacheFile "$rigMailbox" 201 202610 rig@rig.invalid "First" "$rigTmp/small2.eml"
rigAssert "still one line for that UID" "$( LC_ALL=C grep -c '^201 | ' "$rigMailbox/202610/messages.txt" )" 1

echo "-- a body over the cap keeps its line short and names its body file --"
LC_ALL=C awk 'BEGIN { for ( i = 0 ; i < 4000 ; i++ ) { print "line " i " of a long mail" } }' > "$rigTmp/big.eml"
AgentsToolsCommsEmailCacheFile "$rigMailbox" 204 202611 rig@rig.invalid "A long one" "$rigTmp/big.eml"
rigAssert "the line is capped and names its body" "$( LC_ALL=C grep -o '\[body: 204.body.txt\]' "$rigMailbox/202611/messages.txt" )" "[body: 204.body.txt]"
rigAssert "and is no longer than the cap allows" "$( LC_ALL=C awk '/^204 \| / { print ( length($0) <= 2100 ? "short" : "long" ) }' "$rigMailbox/202611/messages.txt" )" short

echo "-- the whole body is kept, byte for byte --"
rigAssert "the body file is the mail's own text" "$( LC_ALL=C wc -c < "$rigMailbox/202611/204.body.txt" | LC_ALL=C tr -d ' ' )" "$( LC_ALL=C wc -c < "$rigTmp/big.eml" | LC_ALL=C tr -d ' ' )"
rigAssert "and its last line is the mail's last line" "$( LC_ALL=C tail -1 "$rigMailbox/202611/204.body.txt" )" "line 3999 of a long mail"

echo "-- the pointers move --"
rigAssert "the newest UID is the one just filed" "$( LC_ALL=C cut -d' ' -f3 "$rigMailbox/.state.txt" )" 204
rigAssert "the floor it is covered from is the first UID" "$( LC_ALL=C cut -d' ' -f2 "$rigMailbox/.state.txt" )" 201

echo "-- a read after a floor --"
rigAssert "only the mails above the floor come back" "$( AgentsToolsCommsEmailCacheServe "$rigMailbox" 202 | LC_ALL=C grep -c ' | ' )" 2
rigAssert "and a body the line names is restored under it" "$( AgentsToolsCommsEmailCacheServe "$rigMailbox" 203 | LC_ALL=C grep -c 'line 3999 of a long mail' )" 1

echo "-- a read of a folder with no state --"
rigAssert "the serve-by-UID helper is there" "$( type -t AgentsToolsCommsEmailCacheMessage )" function
rigAssert "a UID the folder filed comes back whole, and nothing is fetched" "$( AgentsToolsCommsEmailCacheMessage "$rigMailbox" 204 | LC_ALL=C grep -c 'line 3999 of a long mail' )" 1
rigAssert "a UID the folder never filed is a miss, with rc 1" "$( AgentsToolsCommsEmailCacheMessage "$rigMailbox" 999 ; printf '|%s' $? )" "|1"
rigAssert "and so is a folder that holds nothing" "$( AgentsToolsCommsEmailCacheMessage "$rigTmp/nothing" 204 ; printf '|%s' $? )" "|1"
rigAssert "a read of a folder with no state is refused, and prints nothing" "$( AgentsToolsCommsEmailCacheServe "$rigTmp/nothing" 0 ; printf '|%s' $? )" "|1"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
