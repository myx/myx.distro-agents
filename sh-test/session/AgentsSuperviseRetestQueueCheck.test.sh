#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `retest-queue` kind: the waiting count, the oldest request's asked stamp, and whether the drain
## lock's holder is alive. Held:
##   1. requests waiting read `retest-queue <ws> waiting=<n> oldest=<asked stamp> holder=<alive|stale|none>`
##   2. the owner's words: a lock whose holder lives reads `alive`, one left by a drain that ended reads `stale`
##   3. the control: an empty queue with no lock reads no line
## Red before the kind: no `retest-queue` line exists at all. Offline: the rig's HOME is its own, so the queue is the rig's.
set -u
rigCheckName="SUPERVISE_RETEST_QUEUE"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

rigRetestQueue
rigOut="$( rigScan )"
rigAssert "the control: an empty queue with no lock reads no line" "$( rigKindHas retest-queue 'waiting=' )" "0"

rigRetestRequest retest-20261118T010000Z-rig00001 "$( rigIso $(( rigNow - 1800 )) )"
rigRetestRequest retest-20261118T012000Z-rig00002 "$( rigIso $(( rigNow - 600 )) )"
rigOut="$( rigScan )"
rigAssert "two waiting requests read retest-queue" "$( rigKindHas retest-queue 'waiting=2' )" "1"
rigAssert "and the oldest of them sets the age" "$( rigKindHas retest-queue 'oldest=30m' )" "1"
rigAssert "and no lock reads holder=none" "$( rigKindHas retest-queue 'holder=none' )" "1"

mkdir -p "$rigHome/.agents/magic-team/retest-queue/drain.lock"
printf 'pid: %s\nstarted: %s\nsince: %s\n' "$$" "$( LC_ALL=C ps -o lstart= -p $$ 2> /dev/null )" "$( date '+%Y-%m-%d %H:%M %z' )" \
	> "$rigHome/.agents/magic-team/retest-queue/drain.lock/holder"
rigOut="$( rigScan )"
rigAssert "a lock whose holder lives reads holder=alive" "$( rigKindHas retest-queue 'holder=alive' )" "1"

printf 'pid: %s\nstarted: %s\nsince: %s\n' 999999 "Wed Nov 18 01:00:00 2026" "$( date '+%Y-%m-%d %H:%M %z' )" \
	> "$rigHome/.agents/magic-team/retest-queue/drain.lock/holder"
rigOut="$( rigScan )"
rigAssert "a lock left by an ended drain reads holder=stale" "$( rigKindHas retest-queue 'holder=stale' )" "1"

rigScanDone
