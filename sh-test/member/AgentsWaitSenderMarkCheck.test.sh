#!/usr/bin/env bash
## Behavioural check on the sender mark a Wait puts on every message from a person outside the team (AgentsWaitSenderMark.awk): a run never
## starts from a bare Slack id. Held, run and not read:
##   1. An account the contact store knows: its head line carries `[sender: <name>, <organisation>, contact <id>]`, and the rest of the line stands.
##   2. An account the store does not know: `[sender: no record: do not address by name, escalate]`, never a name.
##   3. The human-owner's own messages are not marked.
##   4. A team post (its text names a member as `*_member_*`) is not marked.
##   5. A line that is no message head, and a head whose author is no Slack account id, is printed as it stands.
##   6. The mark sits right after the two fields every reader parses, so the reply address after it is still found by the reply-address reader.
## Offline: the renderings are made here, and only the mark awk is run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigAwk="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/member/AgentsWaitSenderMark.awk"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigAwk" ] || rigRefuse "the sender-mark awk is not at the origin this workspace resolves: $rigAwk"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigTmp="$( mktemp -d )" || rigRefuse "no temporary folder"
trap 'rm -rf "$rigTmp"' EXIT
printf 'UKNOWN001\tJulia Stepanova, ndmsystems, contact julia-stepanova\n' > "$rigTmp/map"
rigMark(){ ## the marked rendering of stdin
	LC_ALL=C awk -v map="$rigTmp/map" -v owner=UOWNER001 -f "$rigAwk"
}

echo "-- 1. a known account carries who it is --"
rigOut="$( printf '%s\n' '1794295463.464499 | UKNOWN001 | [reply-to: slack:D1:1794295463.464499] hello' | rigMark )"
rigAssert "name, organisation and contact id on the head line" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^1794295463.464499 | UKNOWN001 | \[sender: Julia Stepanova, ndmsystems, contact julia-stepanova\] \[reply-to: slack:D1:1794295463.464499\] hello$' )" "1"

echo "-- 2. an unknown account is told to be escalated, with no name --"
rigOut="$( printf '%s\n' '1794303093.674579 | UNOREC0001 | a question' | rigMark )"
rigAssert "no record: do not address by name, escalate" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^1794303093.674579 | UNOREC0001 | \[sender: no record: do not address by name, escalate\] a question$' )" "1"

echo "-- 3. the owner is not marked --"
rigOut="$( printf '%s\n' '1794293140.109929 | UOWNER001 | his word' | rigMark )"
rigAssert "the line stands as it was" "$rigOut" "1794293140.109929 | UOWNER001 | his word"

echo "-- 4. a team post is not marked --"
rigOut="$( printf '%s\n' '1794295882.624879 | UBOT000001 | :mouse: *_magic-coordinator_* @dispatchr → someone' | rigMark )"
rigAssert "the line stands as it was" "$rigOut" "1794295882.624879 | UBOT000001 | :mouse: *_magic-coordinator_* @dispatchr → someone"

echo "-- 5. what is no message head stands --"
rigOut="$( printf '%s\n' '# in D1' '1794295463.464499 | notanid | text' 'plain line' | rigMark )"
rigAssert "marker, a non-account author and a plain line are unchanged" "$rigOut" "$( printf '%s\n' '# in D1' '1794295463.464499 | notanid | text' 'plain line' )"

echo "-- 6. the reply address after the mark is still found --"
rigAddr="${MDLT_ORIGIN}/myx/myx.distro-agents/sh-lib/member/AgentsWaitReplyAddress.awk"
if [ -f "$rigAddr" ] ; then
	rigOut="$( printf '%s\n' '# in D1' '1794295463.464499 | UKNOWN001 | hello' | LC_ALL=C awk -v kind=dms -v source="dms:x" -f "$rigAddr" | rigMark )"
	rigAssert "one head line with both the sender and the reply address" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '\[sender: Julia Stepanova, ndmsystems, contact julia-stepanova\] \[reply-to: slack:D1:1794295463.464499\]' )" "1"
fi

echo
if [ "$rigFails" -eq 0 ] ; then echo "✅ WAIT SENDER MARK CHECK OK: $rigPasses assertion(s)" ; exit 0 ; fi
echo "⛔ WAIT SENDER MARK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" ; exit 1
