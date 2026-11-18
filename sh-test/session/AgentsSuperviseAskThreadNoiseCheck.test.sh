#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `ask-thread-noise` kind: an open question whose thread another open question also names, so a
## reply in that thread can answer the wrong one. Held:
##   1. two open questions sharing one thread ts each read `ask-thread-noise <ws> <id> thread <ts>`
##   2. the control: an open question alone in its own thread reads none
##   3. a closed question in the same thread does not make it shared: only open asks count
## Red before the kind: no `ask-thread-noise` line exists at all. Offline: the rig is the check's own.
set -u
rigCheckName="SUPERVISE_ASK_THREAD_NOISE"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

rigAsk rignois1 magic-coordinator "1793600001.000001"
rigAsk rignois2 magic-coordinator "1793600001.000001"
rigAsk rigquie1 magic-coordinator "1793600002.000002"
printf -- '---\nstatus: closed\nowner: magic-developer\nkind: question\naddress-to: magic-coordinator\nthread-ts: 1793600002.000002\nsession-id: rigclosed\nquestion-ts: %s.000000\nasked-at: %s\n---\n' \
	"$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" > "$rigAgents/pending/rigclosed.md"

rigOut="$( rigScan )"
rigAssert "the first question of a shared thread reads ask-thread-noise" "$( rigKindHas ask-thread-noise 'rignois1' )" "1"
rigAssert "and the second one too" "$( rigKindHas ask-thread-noise 'rignois2' )" "1"
rigAssert "and the line names the thread" "$( rigKindHas ask-thread-noise 'thread 1793600001.000001' )" "2"
rigAssert "the control, a question alone in its thread, reads none" "$( rigKindHas ask-thread-noise 'rigquie1' )" "0"
rigAssert "a closed ask sharing a thread does not make it shared" "$( rigKindHas ask-thread-noise 'rigclosed' )" "0"
rigAssert "and both open questions keep their own ask line" "$( rigKindHas ask 'rignois1' ):$( rigKindHas ask 'rignois2' )" "1:1"

rigAssert "the reading this stands on: two OPEN asks naming one thread is noise" "$( rigKindHas ask-thread-noise 'thread 1793600001.000001' )" "2"

rigScanDone
