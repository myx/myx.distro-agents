#!/usr/bin/env bash
## Behavioural check on when a run is dismissed (F6.9 of the refactorings epic, "Dismissal, in detail"): an executor,
## the coordinator included, is not dismissed while another participant of its session is still running, whatever
## dismisses it: an accept, a DISMISSED from its reports-to, or the tooling. The tooling's own review-wait limit never
## dismisses a run while another participant of its session runs. A member that is not the executor is dismissed as
## soon as its reports-to dismisses it after its work is accepted. A run without the seat is no running participant.
## Seen live on 2026-10-18: three members dismissed on a review-wait expiry while their session was live and their
## work open, and a coordinator that left a coworking session before the others had finished.
## Held, through the served Wait of each run and the accept operation, each scene a workspace of its own:
##   1. past the review-wait limit, the coordinator, founder of a coworking session, is not dismissed while a member
##      it brought in runs, nor that member while the coordinator runs; no dismissal is recorded, both stay in review
##   2. an accept of a routine executor's handback does not dismiss it while a participant of its session runs
##   3. a DISMISSED from the executor's reports-to does not dismiss it while that participant runs
##   4. a member that is not the executor is dismissed when its reports-to dismisses it after the accept
##   5. once the others have ended, the last executor is dismissed at the limit, recorded once
##   6. a second run of the executor's own member, without the seat, does not hold the executor back
##   7. a lone run is dismissed at the limit, as today
##   8. a run is held from dismissal while a live run in a child session names it in `reports-to` (on its record) or
##      in `review-by` (on its item), and its dismissal is given at its first Wait after that run ends
## The participants of a session are its spawn records (F6.8: session-id is the team session); the executor is the
## run that founded the session (start-context spawned); a participant runs while its own process does.
## Red before F6.9: whatever reaches a run dismisses it, whoever else runs (1, 2, 3 and 8 fail).
## Offline: a Slack-shaped fake curl answers the served calls and the accept's sends; every run is a stand-in process
## of this rig carrying its own spawn id, which no other process carries; each workspace is this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigFn="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigFn"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigTest/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSessionDismissLastCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRunPids=""
trap 'rigProcSignal KILL $rigRunPids ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/served" "$rigTmp/tmp" "$rigTmp/skills"
for rigName in magic-coordinator keeper-myx magic-tester ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/served/curl" || rigRefuse "the fake curl fixture of the served calls is missing from the package"
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/served/$rigModel"
done
chmod +x "$rigTmp/served/"*
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
rigTag="${rigTmp##*.}"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---------------------------------------------------------------- scenes, sessions, runs, items
## A scene is a workspace of its own: its board, its spawn records, its fake Slack's posts and threads. A scene of
## the limit sets REVIEW_WAIT_LIMIT to one second, so every handback in it has waited past it; any other keeps the
## default, and its handbacks entered review just now.
rigScene(){ ## scene name, limit or deliberate
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/agents/pending" "$rigDir/ws/.local/agents/spawned" "$rigDir/data/board/review" "$rigDir/data/board/running" "$rigDir/data/board/processed"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n%s' "$( [ "$2" = limit ] && printf 'REVIEW_WAIT_LIMIT=1\n' )" > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	[ "$2" = limit ] && rigSince=1000 || rigSince="$( date +%s )"
}
rigThreadOf(){ ## session
	printf 'CDISM0001:1700000002.0002%02d' "$( printf '%s' "$1" | LC_ALL=C cksum | LC_ALL=C awk '{ print $1 % 100 }' )"
}
## A session's thread: its opener, then what a scene adds (each message led by a comma).
rigThread(){ ## session, extra messages JSON or empty
	local threadTs
	threadTs="$( rigThreadOf "$1" )" ; threadTs="${threadTs#*:}"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"session opened"}%s],"has_more":false}\n' "$threadTs" "${2:-}" > "$rigDir/replies.$threadTs.json"
}
## A DISMISSED from a member to a member, in the thread, as the team bot posts it in the sender's name.
rigDismissedJson(){ ## from, to
	printf ',{"ts":"1700000400.000001","user":"URIGBOT01","text":"*_%s_* @%s → *_%s_* @%s.\\nDISMISSED","metadata":{"event_type":"magic_sender","event_payload":{"sender":"%s"}}}' "$1" "$1" "$2" "$2" "$1"
}
rigRunNo=0
## A run of a session in the scene: its record, its live process, and its handback in review.
rigRun(){ ## variable to set, session, member, start-context, parent-spawn-id, reports-to
	local runId runItem
	rigRunNo=$(( rigRunNo + 1 ))
	runId="rig-dismiss-run-$rigTag-$rigRunNo-$RANDOM"
	runItem="dispatch-20261018T1000Z-rig-dismiss-$rigRunNo"
	mkdir -p "$rigDir/ws/.local/agents/spawned/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nstart-context: %s\nreports-to: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-18 10:%02d +0000\nsession-thread: %s\nspawns: %s\n---\n' \
		"$2" "$runId" "$5" "$4" "$6" "$2" "$rigHost" "$3" "$rigRunNo" "$( rigThreadOf "$2" )" "$runItem" > "$rigDir/ws/.local/agents/spawned/$2/$runId.spawn.md"
	printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: %s\nreview-reason: handback\nreview-since-epoch: %s\n---\n\n# rig dispatch\n\n## Decisions\n\n' \
		"$3" "$runId" "$rigSince" > "$rigDir/data/board/review/$runItem.md"
	perl -e 'sleep 600' -- --session-id "$runId" > /dev/null 2>&1 &
	eval "${1}Pid=\$!"
	rigRunPids="$rigRunPids $!" ; rigProcNote "$!" ; disown "$!" 2> /dev/null || :
	eval "$1=\$runId"
	eval "${1}Item=\$runItem"
}
## A run of a child session: its record names its parent session and where it reports, its item in running/ names its
## reviewer, and its process lives.
rigChildRun(){ ## variable to set, session, member, parent session, reports-to, review-by
	local runId runItem
	rigRunNo=$(( rigRunNo + 1 ))
	runId="rig-dismiss-run-$rigTag-$rigRunNo-$RANDOM"
	runItem="dispatch-20261018T1000Z-rig-dismiss-$rigRunNo"
	mkdir -p "$rigDir/ws/.local/agents/spawned/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nparent-session-id: %s\nstart-context: spawned\nreports-to: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-18 10:%02d +0000\nsession-thread: %s\nspawns: %s\n---\n' \
		"$2" "$runId" "$4" "$5" "$2" "$rigHost" "$3" "$rigRunNo" "$( rigThreadOf "$2" )" "$runItem" > "$rigDir/ws/.local/agents/spawned/$2/$runId.spawn.md"
	printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: %s\nreview-by: %s\n---\n\n# rig dispatch of a child session\n\n## Decisions\n\n' \
		"$3" "$runId" "$6" > "$rigDir/data/board/running/$runItem.md"
	perl -e 'sleep 600' -- --session-id "$runId" > /dev/null 2>&1 &
	eval "${1}Pid=\$!"
	rigRunPids="$rigRunPids $!" ; rigProcNote "$!" ; disown "$!" 2> /dev/null || :
	eval "$1=\$runId"
}
rigEnd(){ ## pid -- the run ends by itself
	rigProcSignal KILL "$1"
	sleep 1
}
## The served Wait of a run of the scene, as its CLI makes it; prints `dismissed` or `waits`.
rigWaits(){ ## run id, member, session
	local waitOut="$rigDir/$1.wait.out"
	( cd "$rigDir/ws" && printf '%s' '{"sources":"slack:session-current","since_utime":"1700000100","timeout":2}' | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SPAWN_CALLER_WAITS \
		PATH="$rigTmp/served:/usr/bin:/bin" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigDir/data" \
		MDAT_SESSION_ID="$3" MDAT_SESSION_THREAD="$( rigThreadOf "$3" )" MDAT_SPAWN_SESSION_ID="$1" MDAT_SPAWN_AGENT="$2" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool Wait > "$waitOut" 2> "$waitOut.err" )
	LC_ALL=C grep -q -x -F 'WAIT-RESULT: DISMISSED' "$waitOut" && printf dismissed || printf waits
}
## The accept of a handback by magic-coordinator, the reviewer; prints how many of the sends it made say DISMISSED.
rigAccepts(){ ## item
	rm -f "$rigDir"/post.* "$rigDir/posts"
	( cd "$rigDir/ws" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/served:/usr/bin:/bin:/usr/sbin:/sbin" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" \
		MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigDir/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigFn" --member-review-accept magic-coordinator "$1" --summary "The work is good." ) > "$rigDir/accept.out" 2>&1
	printf '%s' "$?" > "$rigDir/accept.rc"
	cat "$rigDir"/post.* 2> /dev/null | LC_ALL=C grep -c -F 'DISMISSED' || :
}
rigDismissals(){ ## item -- its Decisions lines that record the limit's dismissal
	LC_ALL=C grep -c -E '^- [0-9TZ:-]+ [a-z-]+ dismissed: review-wait-expired' "$rigDir/data/board/review/$1.md" 2> /dev/null || :
}
rigInReview(){ ## item
	[ -f "$rigDir/data/board/review/$1.md" ] && printf review || printf moved
}

## Reached, or nothing below means anything: a run alone in its session is dismissed by the limit, and an accept
## of a lone run's handback dismisses it.
rigScene solo limit
rigSolo="rig-dismiss-solo-$rigTag"
rigThread "$rigSolo" ""
rigRun rigAlone "$rigSolo" keeper-myx spawned none human-owner
[ "$( rigWaits "$rigAlone" keeper-myx "$rigSolo" )" = dismissed ] || rigRefuse "the review limit dismissed no lone run, so nothing below would be measured: $( head -2 "$rigDir/$rigAlone.wait.out" | LC_ALL=C tr '\n' ' ' ) $( head -2 "$rigDir/$rigAlone.wait.out.err" | LC_ALL=C tr '\n' ' ' )"
rigScene solo-accept deliberate
rigSoloB="rig-dismiss-solo-b-$rigTag"
rigThread "$rigSoloB" ""
rigRun rigAloneB "$rigSoloB" keeper-myx spawned none magic-coordinator
sleep 1
[ "$( rigAccepts "$rigAloneBItem" )" -ge 1 ] 2> /dev/null || rigRefuse "an accept of a lone run's handback sent it no DISMISSED, so nothing below would be measured: $( LC_ALL=C grep -m2 -i 'error' "$rigDir/accept.out" | LC_ALL=C tr '\n' ' ' )"

echo "-- 1. past the limit, neither the coordinator nor the member it brought in is dismissed while the other runs --"
rigScene cowork limit
rigSession="rig-dismiss-cowork-$rigTag"
rigThread "$rigSession" ""
rigRun rigCoord "$rigSession" magic-coordinator spawned none human-owner
rigRun rigKeeper "$rigSession" keeper-myx joined "$rigCoord" magic-coordinator
rigAssert "the coordinator's Wait at the limit is no dismissal"           "$( rigWaits "$rigCoord" magic-coordinator "$rigSession" )" waits
rigAssert "nor is the member's"                                           "$( rigWaits "$rigKeeper" keeper-myx "$rigSession" )" waits
rigAssert "no dismissal is recorded on either item"                       "$( rigDismissals "$rigCoordItem" ) $( rigDismissals "$rigKeeperItem" )" "0 0"
rigAssert "both items stay in review"                                     "$( rigInReview "$rigCoordItem" ) $( rigInReview "$rigKeeperItem" )" "review review"
rigCoworkDir="$rigDir"

echo "-- 2. an accept does not dismiss a routine's executor while a participant of its session runs --"
rigScene routine deliberate
rigRoutine="rig-dismiss-routine-$rigTag"
rigThread "$rigRoutine" "$( rigDismissedJson magic-coordinator keeper-myx )"
rigRun rigExec "$rigRoutine" keeper-myx spawned none magic-coordinator
rigRun rigPart "$rigRoutine" magic-tester joined "$rigExec" keeper-myx
sleep 1
rigAssert "the accept sends the executor no DISMISSED"                    "$( rigAccepts "$rigExecItem" )" 0

echo "-- 3. a DISMISSED from its reports-to does not dismiss the executor while that participant runs --"
rigAssert "the executor's Wait, the DISMISSED in its thread, is no dismissal" "$( rigWaits "$rigExec" keeper-myx "$rigRoutine" )" waits

## Added by the builder of F6.9: the dismissal held is given once the participant has ended.
echo "-- 3b. once that participant has ended, the executor's next Wait is its dismissal --"
rigEnd "$rigPartPid"
rigAssert "the participant has ended: the executor is dismissed"         "$( rigWaits "$rigExec" keeper-myx "$rigRoutine" )" dismissed

echo "-- 4. a member that is not the executor is dismissed when its reports-to dismisses it after the accept --"
rigScene member deliberate
rigMemberSession="rig-dismiss-member-$rigTag"
rigThread "$rigMemberSession" "$( rigDismissedJson magic-coordinator keeper-myx )"
rigRun rigLead "$rigMemberSession" magic-coordinator spawned none human-owner
rigRun rigMember "$rigMemberSession" keeper-myx joined "$rigLead" magic-coordinator
sleep 1
rigAssert "the accept of the member's handback sends it its DISMISSED"   "$( rigAccepts "$rigMemberItem" )" 1
rigAssert "and the member's Wait, the DISMISSED in its thread, is its dismissal" "$( rigWaits "$rigMember" keeper-myx "$rigMemberSession" )" dismissed

echo "-- 5. once the others have ended, the last executor is dismissed at the limit, recorded once --"
rigDir="$rigCoworkDir"
rigEnd "$rigKeeperPid"
rigAssert "the member has ended: the coordinator, the last one running, is dismissed" "$( rigWaits "$rigCoord" magic-coordinator "$rigSession" )" dismissed
rigWaits "$rigCoord" magic-coordinator "$rigSession" > /dev/null
rigAssert "one dismissal on its item, for two Waits"                      "$( rigDismissals "$rigCoordItem" )" 1
rigAssert "its item stays in review"                                      "$( rigInReview "$rigCoordItem" )" review

echo "-- 6. a second run of the executor's own member, without the seat, does not hold the executor back --"
rigScene second limit
rigSecond="rig-dismiss-second-$rigTag"
rigThread "$rigSecond" ""
rigRun rigFirstRun "$rigSecond" keeper-myx spawned none human-owner
rigRun rigSecondRun "$rigSecond" keeper-myx joined "$rigFirstRun" human-owner
rigAssert "the executor is dismissed at the limit, its second run live beside it" "$( rigWaits "$rigFirstRun" keeper-myx "$rigSecond" )" dismissed

echo "-- 7. a lone run is dismissed at the limit, as today --"
rigDir="$rigTmp/solo"
rigAssert "the lone run's dismissal is recorded once"                     "$( rigDismissals "$rigAloneItem" )" 1

echo "-- 8. a run is held while a live run of a child session names it, and dismissed at its first Wait after --"
rigScene child-reports limit
rigParentSession="rig-dismiss-parent-$rigTag"
rigChildSession="rig-dismiss-child-$rigTag"
rigThread "$rigParentSession" ""
rigThread "$rigChildSession" ""
rigRun rigParent "$rigParentSession" keeper-myx spawned none human-owner
rigChildRun rigChild "$rigChildSession" magic-tester "$rigParentSession" "$rigParentSession:keeper-myx" human-owner
rigAssert "named in a live child run's reports-to: its Wait at the limit is no dismissal" "$( rigWaits "$rigParent" keeper-myx "$rigParentSession" ):$( rigDismissals "$rigParentItem" )" "waits:0"
rigEnd "$rigChildPid"
rigAssert "that run ended: its first Wait after is its dismissal, recorded once" "$( rigWaits "$rigParent" keeper-myx "$rigParentSession" ):$( rigDismissals "$rigParentItem" )" "dismissed:1"
rigScene child-review limit
rigParentSession="rig-dismiss-parent-r-$rigTag"
rigChildSession="rig-dismiss-child-r-$rigTag"
rigThread "$rigParentSession" ""
rigThread "$rigChildSession" ""
rigRun rigParent "$rigParentSession" keeper-myx spawned none human-owner
rigChildRun rigChild "$rigChildSession" magic-tester "$rigParentSession" human-owner keeper-myx
rigAssert "named in a live child run's review-by: its Wait at the limit is no dismissal" "$( rigWaits "$rigParent" keeper-myx "$rigParentSession" ):$( rigDismissals "$rigParentItem" )" "waits:0"
rigEnd "$rigChildPid"
rigAssert "that run ended: its first Wait after is its dismissal, recorded once" "$( rigWaits "$rigParent" keeper-myx "$rigParentSession" ):$( rigDismissals "$rigParentItem" )" "dismissed:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION DISMISS LAST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_DISMISS_LAST: OK (%d assertions, offline)\n' "$rigPassCount"
