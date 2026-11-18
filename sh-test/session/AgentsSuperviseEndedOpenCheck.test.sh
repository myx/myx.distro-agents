#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `ended-open` kind: a session whose control thread still lives while every run of it has ended, so
## the session still shows as open. Held:
##   1. a live control thread whose session's records are all closed reads `ended-open <ws> <session> control=<pid>`
##   2. the control: the same shape with a record still open reads none, its runs not ended
##   3. a thread inside its own closing window reads none either: a close takes time, and that is not the finding
## Red before the kind: no `ended-open` line exists at all. Offline: the rig is the check's own, and the threads are stand-ins.
set -u
rigCheckName="SUPERVISE_ENDED_OPEN"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

## The session whose runs have all ended: a closed record, and a live thread quiet past its closing window.
rigRunEnded rigends endrunx
python3 -I -B -c 'import time; time.sleep(300)' -- --intern-session-control rigends > /dev/null 2>&1 &
rigEndsPid="$!"
rigPids="$rigPids $rigEndsPid"
disown "$rigEndsPid" 2> /dev/null || :
sleep 1
rigControl rigends "$rigEndsPid"
rigControlQuiet rigends 900
## The control: a record of that session still open.
rigRun rigopen rigopen-run
python3 -I -B -c 'import time; time.sleep(300)' -- --intern-session-control rigopen > /dev/null 2>&1 &
rigOpenPid="$!"
rigPids="$rigPids $rigOpenPid"
disown "$rigOpenPid" 2> /dev/null || :
sleep 1
rigControl rigopen "$rigOpenPid"
rigControlQuiet rigopen 900
## The control: a thread inside its closing window.
rigRunEnded rigclos rigclos-run
python3 -I -B -c 'import time; time.sleep(300)' -- --intern-session-control rigclos > /dev/null 2>&1 &
rigClosPid="$!"
rigPids="$rigPids $rigClosPid"
disown "$rigClosPid" 2> /dev/null || :
sleep 1
rigControl rigclos "$rigClosPid"
rigControlQuiet rigclos 5
sleep 2

rigOut="$( rigScan )"
rigAssert "a session whose runs have all ended reads ended-open" "$( rigKindHas ended-open 'rigends' )" "1"
rigAssert "and its line names the thread that lived on" "$( rigKindHas ended-open 'rigends control=' )" "1"
rigAssert "the control, a session with a record still open, reads none" "$( rigKindHas ended-open 'rigopen' )" "0"
rigAssert "a thread inside its closing window reads none" "$( rigKindHas ended-open 'rigclos' )" "0"

rigScanDone
