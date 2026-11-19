#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `review-waiting` and `review-limit-near` kinds: a board item in review with no verdict, its age
## there, and its reviewer's rung; and, where the run that handed back still lives, the review-wait limit it is close to. Held:
##   1. an item in review reads `review-waiting <ws> <item> age=<n>m rung=<word>`
##   2. the rung words: `duty` for magic-coordinator and for an item with no reviewer of its own (magic-coordinator reviews it,
##      AgentsToolsItemIsReviewer), `owner` for the human-owner, `none` for nobody, else the reviewing member's own name
##   2a. the reviewer is read in the scanned workspace, whose spawn records name it, never in the caller's
##   3. `review-limit-near` reads only where the handing run still lives and the limit is close
##   4. the control: an item in `running` reads neither kind
## Red before the kinds: neither line exists at all. Offline: the rig's board is its own hidden store.
set -u
rigCheckName="SUPERVISE_REVIEW_WAITING"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
rigScanBegin "$rigCheckName"

rigReviewItem dispatch-rigduty rigduty 600 magic-coordinator
rigReviewItem dispatch-rigown rigown 600 human-owner
rigReviewItem dispatch-rigmemb rigmemb 600 magic-tester
rigReviewItem dispatch-riglive riglive 3540
rigRun riglive magic-developer
rigMark riglive 60 "tool Wait"
rigTool riglive 60 Wait
rigStand riglive
rigRun rigduty magic-developer spawn-succeeded
rigRun rigmemb magic-developer spawn-succeeded
rigReviewItem dispatch-rignorec rignorec 600
rigReviewItem dispatch-rignone rignone 600 none
rigReviewItem dispatch-rigroute rigroute 600
rigRun rigroute magic-developer "reports-to: magic-tester"
mkdir -p "$rigBoard/running"
printf -- '---\ntype: dispatch\ndate: %s\nowner: magic-developer\nspawn-id: rigrun\nreview-since-epoch: %s\n---\n\n# dispatch-rigrun\n' \
	"$( date '+%Y-%m-%d %H:%M %z' )" "$(( rigNow - 600 ))" > "$rigBoard/running/dispatch-rigrun.md"
sleep 2

rigOut="$( rigScan )"
rigAssert "an item in review reads review-waiting" "$( rigKindHas review-waiting 'dispatch-rigduty' )" "1"
rigAssert "and its line carries its age there" "$( rigKindHas review-waiting 'dispatch-rigduty age=10m' )" "1"
rigAssert "the coordinator's rung reads duty" "$( rigKindHas review-waiting 'dispatch-rigduty age=10m rung=duty' )" "1"
rigAssert "the owner's rung reads owner" "$( rigKindHas review-waiting 'dispatch-rigown age=10m rung=owner' )" "1"
rigAssert "any other reviewer reads its own member name" "$( rigKindHas review-waiting 'dispatch-rigmemb age=10m rung=magic-tester' )" "1"
rigAssert "an item whose run lives near its limit reads review-limit-near" "$( rigKindHas review-limit-near 'dispatch-riglive' )" "1"
rigAssert "and its line carries the seconds left" "$( rigKindHas review-limit-near 'left=' )" "1"
rigAssert "the control, an item in running, reads neither kind" \
	"$( rigKindHas review-waiting 'dispatch-rigrun' ):$( rigKindHas review-limit-near 'dispatch-rigrun' )" "0:0"

rigAssert "an item with no reviewer of its own reads duty, the rung that reviews it" "$( rigKindHas review-waiting 'dispatch-rignorec age=10m rung=duty' )" "1"
rigAssert "an item nobody reviews still reads none" "$( rigKindHas review-waiting 'dispatch-rignone age=10m rung=none' )" "1"
rigAssert "a reviewer its run's record names reads that member" "$( rigKindHas review-waiting 'dispatch-rigroute age=10m rung=magic-tester' )" "1"

rigAssert "the reading this stands on: rung is duty, owner, none, else the reviewer member" "$( rigKindHas review-waiting 'dispatch-rigduty age=10m rung=duty' ):$( rigKindHas review-waiting 'dispatch-rigown age=10m rung=owner' ):$( rigKindHas review-waiting 'dispatch-rigmemb age=10m rung=magic-tester' )" "1:1:1"

## The scan called from another workspace: the reviewer still comes from the scanned workspace's own records. A workspace
## other than the caller's is a rig by its own settings alone (AgentsToolsSuperviseRigIs), so the rig's settings say it.
printf 'MDAT_WORKSPACE_MODE=team-rig\n' >> "$rigWs/.local/.agents/magic-team.agent.env" || rigRefuse "the rig's settings could not be written"
rigForeign="$( rigScratch foreign-ws )"
mkdir -p "$rigForeign/.local/agents/spawned" "$rigForeign/.local/.agents" || rigRefuse "the foreign workspace could not be made"
rigOut="$( rigScan MMDAPP="$rigForeign" )"
rigAssert "called from another workspace, the scan still lists the item" "$( rigKindHas review-waiting 'dispatch-rigroute' )" "1"
rigAssert "and reads its reviewer in the scanned workspace" "$( rigKindHas review-waiting 'dispatch-rigroute age=10m rung=magic-tester' )" "1"

rigScanDone
