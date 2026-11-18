#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `owner-ask` kind: every open question to the human-owner, with how long it has stood and how
## often it was reminded. Held:
##   1. an open question to the owner reads `owner-ask <ws> <id> age=<n>m reminders=<n>`
##   2. the control: a question to the human-owner answered and closed reads no line, so the kind is not every question
##   3. a question to the coordinator reads no `owner-ask` line, its own `ask` line alone
## Red before the kind: no `owner-ask` line exists at all. Offline: the rig is the check's own, and nothing is requested.
set -u
rigCheckName="SUPERVISE_OWNER_ASK"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

rigAsk rigowner human-owner "" "reminders: 2
last-reminder-at: $( date '+%Y-%m-%d %H:%M %z' )
"
rigAsk rigownrt human-owner
rigAsk rigcoord magic-coordinator
printf -- '---\nstatus: closed\nowner: magic-developer\nkind: question\naddress-to: human-owner\nsession-id: rigclosed\nquestion-ts: %s.000000\nasked-at: %s\n---\n' \
	"$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" > "$rigAgents/pending/rigclosed.md"

rigOut="$( rigScan )"
rigAssert "an open question to the owner reads owner-ask" "$( rigKindHas owner-ask 'rigowner' )" "1"
rigAssert "and its line carries its age and its reminder count" \
	"$( rigKindHas owner-ask 'rigowner age=' ):$( rigKindHas owner-ask 'reminders=2' )" "1:1"
rigAssert "a question never reminded says so" \
	"$( rigKind owner-ask | LC_ALL=C grep ' rigownrt ' | LC_ALL=C grep -c ' reminders=0$' )" "1"
rigAssert "the control, a closed question to the owner, reads none" "$( rigKindHas owner-ask 'rigclosed' )" "0"
rigAssert "a question to the coordinator reads none either" "$( rigKindHas owner-ask 'rigcoord' )" "0"
rigAssert "and it keeps its own ask line" "$( rigKindHas ask 'rigcoord' )" "1"

rigScanDone
