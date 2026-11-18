#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `leftover-group` kind: a process group of an ended run that still holds a process. Held:
##   1. a record whose kept leader is gone, and whose group still holds a process, reads `leftover-group <ws> <id> pid=<n> age=<n>m`
##   2. the control: a record whose kept leader still lives reads none, its run not ended
##   3. the control: a kept leader number another process has taken reads none, so a reused number is no finding
## Red before the kind: no `leftover-group` line exists at all. Offline: the rig is the check's own, and every group is a stand-in.
set -u
rigCheckName="SUPERVISE_LEFTOVER_GROUP"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

## The group left behind: its leader ended, its member alive.
rigRunEnded riggroup magic-developer
rigOrphanGroup riggroup
## The control: a record whose kept leader is a process that still lives, and is no run of the scan's.
rigRunEnded riglead magic-developer
rigStand riglead
rigLaunched riglead "$( LC_ALL=C ps -A -ww -o pid=,args= | LC_ALL=C awk -v want="--session-id riglead" 'index( $0, want ) { print $1 ; exit }' )"
## The control: a kept leader number a stranger holds, and no process of that group.
rigRunEnded rigreus magic-developer
rigRunProcess rigreus "1 1_rig_unused"
sleep 2

rigOut="$( rigScan )"
rigAssert "an ended run's group that still holds a process reads leftover-group" "$( rigKindHas leftover-group 'riggroup' )" "1"
rigAssert "and its line names the group and the record's age" \
	"$( rigKindHas leftover-group 'riggroup pid=' ):$( rigKindHas leftover-group 'age=' )" "1:1"
rigAssert "the control, a record whose leader still lives, reads none" "$( rigKindHas leftover-group 'riglead' )" "0"
rigAssert "the control, a kept number a stranger holds, reads none" "$( rigKindHas leftover-group 'rigreus' )" "0"

rigAssert "the reading this stands on: the kept leader is gone and its group still holds a process" "$( rigKindHas leftover-group 'riggroup pid=' )" "1"

rigScanDone
