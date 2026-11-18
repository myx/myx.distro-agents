#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `gate-as-message` kind: a run whose latest session-chat post opens a conformance gate, with no
## ask standing behind it, so the gate never reached the coordinator as a question. Held:
##   1. a live run whose latest post begins `gate: ` reads `gate-as-message <ws> <id> <member> <feature-id>`
##   2. the control: a run whose latest post is ordinary reading reads none
##   3. a run whose latest post opens a gate while its own ask stands open reads none, since the gate has an ask behind it
## Red before the kind: no `gate-as-message` line exists at all. Offline: the rig is the check's own.
set -u
rigCheckName="SUPERVISE_GATE_AS_MESSAGE"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

rigRun riggate magic-developer
rigMark riggate 60 "tool Wait"
rigTool riggate 60 Wait
rigChat riggate 30 magic-developer "gate: s13-19-scan-kinds"
rigStand riggate
rigRun rigchat magic-developer
rigMark rigchat 60 "tool Wait"
rigTool rigchat 60 Wait
rigChat rigchat 30 magic-developer "reading the include before the edit"
rigStand rigchat
rigRun riggated magic-developer
rigMark riggated 60 "tool Wait"
rigTool riggated 60 Wait
rigChat riggated 30 magic-developer "gate: s13-20-other-feature"
rigAsk riggated magic-coordinator
rigStand riggated
sleep 2

rigOut="$( rigScan )"
rigAssert "a gate posted with no ask behind it reads gate-as-message" "$( rigKindHas gate-as-message 'riggate' )" "1"
rigAssert "and the line names the feature the gate opens" "$( rigKindHas gate-as-message 's13-19-scan-kinds' )" "1"
rigAssert "the control, an ordinary latest post, reads none" "$( rigKindHas gate-as-message 'rigchat' )" "0"
rigAssert "a gate with its own ask standing reads none" "$( rigKindHas gate-as-message 'riggated' )" "0"
rigAssert "and that run's ask is counted" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^run ws riggated [^ ]* [^ ]* [^ ]* [^ ]* [^ ]* asks=1 ' )" "1"

rigAssert "the reading this stands on: a gate is a post opening `gate: ` with no ask behind it" "$( printf '%s' "$( rigKind gate-as-message )" | LC_ALL=C grep -c 'riggate' )" "1"

rigScanDone
