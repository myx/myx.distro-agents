#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on S16 stage 2: a board item's due-ness, and the `held` line a scan prints
## of it, are functions of the DOCUMENT and never of the run that asks.
##   1. THE PREDICATE IS ONE FUNCTION, and the window it measures from is one constant in code.
##   2. ITS THREE INPUTS: the folder is one of the five active states, `recheck-date` is absent
##      or past, `last-round-at` is absent or older than the window. Each input is shown turning
##      the answer, and the window's own edge is shown both sides.
##   3. `last-round-at` HAS ONE WRITER, the round's own proof: `--advance-batch-outcome` stamps
##      it with a date-time the one ISO reader takes; a same-state edit that is no round does not.
##      Every outcome word the routines name is one the writer takes, and a round recorded for
##      any of the five active states carries the field.
##   4. `held` IS THE DOCUMENT'S: the scan prints the same holder for the holder's own run, for
##      another member and for the coordinator. An item that names no session names the live run
##      that holds it, for every asker alike.
##   5. THE SCAN PRINTS THE PREDICATE'S INPUTS: every line of the due section carries the
##      `recheck-date` and the `last-round-at` the answer came from.
##   6. A DOCUMENT IT COULD NOT READ IS NAMED, never dropped: a fault is never an empty sweep.
## Offline: a temp workspace, a data root, a HOME and a skillset of this check's own, a
## Slack-shaped fake curl first on PATH, no git.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigLib="$rigOrigin/myx/myx.distro-agents/sh-lib"
rigFn="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigFn"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardDueAndHeldCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigHome="$rigTmp/home"
mkdir -p "$rigTmp/bin" "$rigHome" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig" \
	"$rigData/board/running" "$rigData/board/processed" "$rigData/board/backlog"
for rigMember in magic-coordinator keeper-rig keeper-other ; do
	mkdir -p "$rigSkills/$rigMember"
	printf 'rig\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf 'rig\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The three detached threads a writer of the tooling can start, off, as the runner sets them for every test: a rig
## that starts one leaves a process of the tooling running after it, and this check reports its own leftover processes
## as a fault (runner-slot-keeper.py).
rigThreadsOff="MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One board item of this rig: <state> <name> <frontmatter lines...>. The lines are the whole
## frontmatter after `type:`, so an item states its own owner and never inherits a second one.
rigItem(){ ## state, name, frontmatter lines...
	local itemState="$1" itemName="$2" ; shift 2
	mkdir -p "$rigData/board/$itemState"
	{ printf -- '---\ntype: task\n' ; printf '%s\n' "$@" ; printf -- '---\n\nrig item\n' ; } > "$rigData/board/$itemState/$itemName"
}
## One date-time, shaped as the tooling's own stamp writes it, `n` seconds from now.
rigStamp(){ ## seconds from now (may be negative)
	date -u -r "$(( $( date +%s ) + $1 ))" +"%Y-%m-%d %H:%M +0000" 2> /dev/null \
		|| date -u -d "@$(( $( date +%s ) + $1 ))" +"%Y-%m-%d %H:%M +0000"
}
## A spawn record of this rig: `spawn-started` with no `exit-code` where live, else ended.
rigRecord(){ ## spawn id, member, live|ended
	{
		printf -- '---\n'
		printf 'session-id: %s\nspawn-id: %s\nowner: %s\nstatus: spawn-started\n' "$1" "$1" "$2"
		[ "$3" = live ] || printf 'exit-code: 0\n'
		printf -- '---\n'
	} > "$rigWs/.local/agents/spawned/rig/$1.spawn.md"
}
## The staleness window the code carries, in seconds, or nothing.
rigWindow(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" ; printf "%s" "${agentsBoardStaleWindowSeconds:-}"' rig 2> /dev/null
}
## What the predicate says of one file: `due`, `not-due`, or the fault that stopped it.
rigDue(){ ## item path
	local dueOut dueRc=0
	dueOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 90
			type AgentsToolsBoardItemDue > /dev/null 2>&1 || { echo "NO-PREDICATE" >&2 ; exit 91 ; }
			AgentsToolsBoardItemDue "$1" > /dev/null
		' rig "$1" 2>&1 )" || dueRc=$?
	case "$dueRc" in
		0) printf 'due' ;;
		1) printf 'not-due' ;;
		91) printf 'no-predicate' ;;
		90) printf 'no-states-include' ;;
		*) printf 'rc-%s:%s' "$dueRc" "$( printf '%s' "$dueOut" | LC_ALL=C tr '\n' ' ' )" ;;
	esac
}
## One operation of the dispatcher in the rig: <result file> <session id> <arguments...>
rigOp(){ ## result file, session id, then the operation and its arguments
	local opOut="$1" opSess="$2" ; shift 2
	# shellcheck disable=SC2086
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		$rigThreadsOff \
		MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID="$opSess" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 180 -- \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1 < /dev/null
	printf '%s' "$?" > "$opOut.rc"
}
## The scan of the rig board, in the sweep's own call shape, as one caller.
rigScan(){ ## session id
	local scanSess="$1"
	# shellcheck disable=SC2086
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDAT_WAIT_REMIND=off MDAT_SPAWN_SESSION_ID="$scanSess" $rigThreadsOff \
		bash "$rigFn" --intern-op-session-context-scan magic-coordinator \
			--state pending --state running --state review --state blocked --state parked \
			--all-types --no-inbox-inquiry --no-inbox-reflections --no-inbox-notes --no-slack --no-email --no-trello \
			--no-inbox-other --no-board-related --context rig-sweep 2> /dev/null < /dev/null
}
## The `held` line under one item's heading of a scan's text, or nothing.
rigHeldLine(){ ## scan text, item name
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '/^## / { on = ( index($0, "/" want) > 0 ) ; next } on && /^held / { print ; exit }'
}
## The due section of the coordinator's scan, printed on its own: the section the work-duty scan prints,
## called from the include that holds it, as sh-test/check-fixtures/board-round-scan.rig.sh calls the
## board's other sections. No tool operation prints this section alone, and the whole work-duty scan
## brings the inbox, the Slack collect and the registries, none of which this check is about.
rigDueSection(){
	# shellcheck disable=SC2086
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" $rigThreadsOff \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardRoundScan.include" || exit 90 ; AgentsToolsBoardRecheckDueSection' rig \
		| LC_ALL=C awk '/^## recheck dates due/ { on = 1 ; next } /^## / { on = 0 } on && NF'
}

rigWindowSeconds="$( rigWindow )"
case "$rigWindowSeconds" in
	''|*[!0123456789]*) rigWindowSeconds="" ;;
esac
rigStampForward="$( rigStamp 600 )"
rigStampBehind="$( rigStamp -600 )"

echo "-- 1. the predicate is one function, and the window is one constant --"
rigAssert "the code carries one staleness window, a whole number of seconds" \
	"$([ -n "$rigWindowSeconds" ] && [ "$rigWindowSeconds" -ge 60 ] && printf one || printf none)" one
rigItem running task-20261104T1000Z-rig-bare.md "owner: keeper-rig"
rigAssert "the predicate answers for a document that carries neither date" "$( rigDue "$rigData/board/running/task-20261104T1000Z-rig-bare.md" )" due

echo "-- 2. each of its three inputs turns the answer --"
rigItem backlog task-20261104T1001Z-rig-backlog.md "owner: keeper-rig"
rigAssert "a folder that is not one of the five active states is not due" "$( rigDue "$rigData/board/backlog/task-20261104T1001Z-rig-backlog.md" )" not-due
rigItem processed task-20261104T1002Z-rig-done.md "owner: keeper-rig"
rigAssert "a done state is not due" "$( rigDue "$rigData/board/processed/task-20261104T1002Z-rig-done.md" )" not-due
rigItem running task-20261104T1003Z-rig-future.md "owner: keeper-rig" "recheck-date: $rigStampForward"
rigAssert "a recheck-date still ahead is not due" "$( rigDue "$rigData/board/running/task-20261104T1003Z-rig-future.md" )" not-due
rigItem running task-20261104T1004Z-rig-past.md "owner: keeper-rig" "recheck-date: $rigStampBehind"
rigAssert "a recheck-date that has passed is due" "$( rigDue "$rigData/board/running/task-20261104T1004Z-rig-past.md" )" due
rigItem running task-20261104T1005Z-rig-fresh.md "owner: keeper-rig" "last-round-at: $( rigStamp -60 )"
rigAssert "a round inside the staleness window holds the document out of the sweep" "$( rigDue "$rigData/board/running/task-20261104T1005Z-rig-fresh.md" )" not-due
rigItem running task-20261104T1007Z-rig-inside.md "owner: keeper-rig" "last-round-at: $( rigStamp "$(( 0 - rigWindowSeconds + 120 ))" )"
rigItem running task-20261104T1006Z-rig-stale.md "owner: keeper-rig" "last-round-at: $( rigStamp "$(( 0 - rigWindowSeconds - 120 ))" )"
rigAssert "the window's own edge decides, both sides of it, from the constant the code carries" \
	"$( rigDue "$rigData/board/running/task-20261104T1007Z-rig-inside.md" ):$( rigDue "$rigData/board/running/task-20261104T1006Z-rig-stale.md" )" "not-due:due"

echo "-- 2b. held is the document's, never a reading of who asks --"
rigRecord rig-sess-owner keeper-rig live
rigItem running task-20261104T1020Z-rig-held.md "owner: keeper-rig" "session-id: rig-sess-owner"
rigItem running task-20261104T1021Z-rig-free.md "owner: keeper-other"
rigScanAsOwner="$( rigScan rig-sess-owner )"
rigScanAsOther="$( rigScan rig-sess-other )"
rigScanAsCoord="$( rigScan rig-sess-coord )"
rigAssert "control: every scan listed the held item" \
	"$( printf '%s\n' "$rigScanAsOwner" "$rigScanAsOther" "$rigScanAsCoord" | LC_ALL=C grep -c -x -F '## running/task-20261104T1020Z-rig-held.md' )" 3
rigAssert "the holder's own run sees the holder" "$( rigHeldLine "$rigScanAsOwner" task-20261104T1020Z-rig-held.md )" "held (by keeper-rig (rig-sess-owner))"
rigAssert "another member sees the same holder" "$( rigHeldLine "$rigScanAsOther" task-20261104T1020Z-rig-held.md )" "held (by keeper-rig (rig-sess-owner))"
rigAssert "and so does the coordinator" "$( rigHeldLine "$rigScanAsCoord" task-20261104T1020Z-rig-held.md )" "held (by keeper-rig (rig-sess-owner))"
rigAssert "an item with no live holder shows no held line, to another member and to the coordinator" \
	"$( rigHeldLine "$rigScanAsOther" task-20261104T1021Z-rig-free.md ):$( rigHeldLine "$rigScanAsCoord" task-20261104T1021Z-rig-free.md )" ":"

echo "-- 2c. an item that names no session: the line still names the holding run --"
## The sweeper is itself a live magic-coordinator run, so an item the coordinator owns and no
## session names is held by whichever coordinator run is live. That is the DOCUMENT's fact.
## What the round's own rule does with it is a separate question, and the line gives the
## spawn id that question needs (S16 stage 2 item 4's ruling).
## `rigScanAsCoord` above is already that live run, so one more scan answers the other asker.
rigRecord rig-sess-coord magic-coordinator live
rigItem running task-20261104T1030Z-rig-own.md "owner: magic-coordinator"
rigScanAsOtherCoord="$( rigScan rig-sess-other-coord )"
rigScanAsHeldCoord="$( rigScan rig-sess-coord )"
rigAssert "an item the coordinator owns and no session names shows the live coordinator run" \
	"$( rigHeldLine "$rigScanAsOtherCoord" task-20261104T1030Z-rig-own.md )" "held (by magic-coordinator (rig-sess-coord))"
rigAssert "and the holding run itself reads the same line: the answer is the document's" \
	"$( rigHeldLine "$rigScanAsHeldCoord" task-20261104T1030Z-rig-own.md )" "held (by magic-coordinator (rig-sess-coord))"

echo "-- 3. last-round-at has one writer: the round's own proof --"
## A round's own outcome is `advanced`. It is the one word that stamps the field, so the round's
## proof and the field cannot drift apart.
rigItem running task-20261104T1010Z-rig-proof.md "owner: keeper-rig"
rigOp "$rigTmp/proof" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1010Z-rig-proof.md:advanced:round-one
rigAssert "the round's proof is recorded" "$( cat "$rigTmp/proof.rc" )" 0
rigAssert "and it stamps last-round-at with a date-time the one ISO reader reads" \
	"$( LC_ALL=C awk '/^last-round-at: /{ print substr($0, 16) ; exit }' "$rigData/board/running/task-20261104T1010Z-rig-proof.md" | LC_ALL=C awk -f "$rigOrigin/myx/myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk" 2> /dev/null | LC_ALL=C awk '{ print ( $1 ~ /^[0-9]+$/ ) ? "read" : "unread" }' )" read
rigAssert "and the document is then not due until the window passes" "$( rigDue "$rigData/board/running/task-20261104T1010Z-rig-proof.md" )" not-due
rigItem running task-20261104T1011Z-rig-edit.md "owner: keeper-rig"
rigOp "$rigTmp/edit" rig-session --intern-op-board-upsert-move-edit running task-20261104T1011Z-rig-edit.md --from-state:running \
	--header:upsert:condition:"a rig condition" --context rig-edit
rigAssert "a same-state edit ran" "$( cat "$rigTmp/edit.rc" )" 0
rigAssert "and a write that is no round stamps no last-round-at" \
	"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/running/task-20261104T1011Z-rig-edit.md" || : )" 0

echo "-- 3b. every outcome word the routines name is one the writer takes --"
## `magic-team.advance.routine.md:69` records a completed round as `advanced`, and
## `magic-coordinator.work-duty.routine.md:141` names all seven. The gate that refuses one of
## them stamps nothing at all, so the round's own proof never lands.
## One running item per word, then the two states a round is also given to.
rigItem running task-20261104T1040Z-rig-advanced.md "owner: keeper-rig"
rigOp "$rigTmp/advanced" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1040Z-rig-advanced.md:advanced:inline:round-two
rigAssert "a completed round's own outcome, advanced, is recorded" "$( cat "$rigTmp/advanced.rc" )" 0
rigAssert "and it stamps last-round-at, so that round counts as the document's visit" \
	"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/running/task-20261104T1040Z-rig-advanced.md" || : )" 1
rigItem running task-20261104T1041Z-rig-parkfail.md "owner: keeper-rig"
rigOp "$rigTmp/parkfail" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1041Z-rig-parkfail.md:parked-spawn-failed:inline:park-one
rigAssert "the spawn-failure park outcome, parked-spawn-failed, is recorded too" "$( cat "$rigTmp/parkfail.rc" )" 0

echo "-- 3c. a round in any state it is given to carries its proof --"
## The epic gives a round to `running` and to `review` (the model, "Per state, a sweep gives").
## A proof written for `running` alone leaves the review round with no visit, so the review
## document is due on every sweep. `blocked` and `parked` get a recheck, which is no round.
rigItem review task-20261104T1050Z-rig-in-review.md "owner: keeper-rig"
rigOp "$rigTmp/in-review" rig-session --advance-batch-outcome magic-coordinator \
	--items:task-20261104T1050Z-rig-in-review.md:advanced:inline:review-round
rigAssert "a round recorded for a review document succeeds" "$( cat "$rigTmp/in-review.rc" )" 0
rigAssert "and the review document carries last-round-at afterwards" \
	"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/review/task-20261104T1050Z-rig-in-review.md" || : )" 1
rigAssert "so the review document is no longer due inside the window" \
	"$( rigDue "$rigData/board/review/task-20261104T1050Z-rig-in-review.md" )" not-due
## The op writes where the document sits, whatever that is: a recheck's own record reaches
## `blocked` and `parked` too, and neither refuses for want of a `running/` path.
for rigState in pending blocked parked ; do
	rigItem "$rigState" "task-20261104T1055Z-rig-in-$rigState.md" "owner: keeper-rig"
	rigOp "$rigTmp/in-$rigState" rig-session --advance-batch-outcome magic-coordinator \
		--items:"task-20261104T1055Z-rig-in-$rigState.md:flagged-once:inline:state-$rigState"
	rigAssert "a record written for a document in $rigState succeeds, and not with rc 2" "$( cat "$rigTmp/in-$rigState.rc" )" 0
done
rigItem running task-20261104T1051Z-rig-unknown.md "owner: keeper-rig"
rigOp "$rigTmp/unknown" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1051Z-rig-unknown.md:not-an-outcome:inline:x
rigAssert "an outcome word nobody names is still refused" "$( cat "$rigTmp/unknown.rc" )" 1
rigAssert "and nothing was stamped on it" \
	"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/running/task-20261104T1051Z-rig-unknown.md" || : )" 0
rigItem review task-20261104T1052Z-rig-behind.md "owner: keeper-rig"
rigItem running task-20261104T1053Z-rig-after.md "owner: keeper-rig"
rigOp "$rigTmp/batch" rig-session --advance-batch-outcome magic-coordinator \
	--items:task-20261104T1052Z-rig-behind.md:advanced:inline:a,task-20261104T1053Z-rig-after.md:advanced:inline:b
rigAssert "a batch succeeds across two states" "$( cat "$rigTmp/batch.rc" )" 0
rigAssert "and one item's state stops none of the batch behind it" \
	"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/running/task-20261104T1053Z-rig-after.md" || : )" 1

echo "-- 3d. a document gets its next round: the guard holds one window, not for ever --"
## ONE WRITER IS FOR ONE ROUND (S26.4, re-scoped by S16 stage 2 item 1). Inside a window a
## different value would overwrite what that window's round decided. Outside it the document
## is due a new round, and the new round's proof must land, or the duty spends a round an hour
## on that document for ever. A document already carrying an outcome, or moved on by a plain
## move, is the case that matters, and 69 active documents carry one today.
rigItem running task-20261104T1070Z-rig-r1.md "owner: keeper-rig"
rigOp "$rigTmp/r1" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1070Z-rig-r1.md:advanced:inline:r1
rigAssert "the first round's proof lands" "$( cat "$rigTmp/r1.rc" )" 0
rigOp "$rigTmp/r2" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1070Z-rig-r1.md:advanced:inline:r2
rigAssert "a second, different proof inside the same window is refused" "$( cat "$rigTmp/r2.rc" )" 1
rigAssert "and the refusal says the window is what holds it" \
	"$( LC_ALL=C grep -c -F 'this window' "$rigTmp/r2" || : )" 1
RIG_OLD="$( rigStamp "$(( 0 - rigWindowSeconds - 120 ))" )" LC_ALL=C awk '/^last-round-at: /{ print "last-round-at: " ENVIRON["RIG_OLD"] ; next } { print }' "$rigData/board/running/task-20261104T1070Z-rig-r1.md" > "$rigTmp/r1.aged"
mv -f "$rigTmp/r1.aged" "$rigData/board/running/task-20261104T1070Z-rig-r1.md"
rigAssert "the window has passed over that document, whose receipt still says r1" \
	"$( LC_ALL=C awk '/^execution-receipt: /{ print substr($0, 20) ; exit }' "$rigData/board/running/task-20261104T1070Z-rig-r1.md" )" "inline:r1"
rigAssert "the document is due again once the window has passed" "$( rigDue "$rigData/board/running/task-20261104T1070Z-rig-r1.md" )" due
rigOp "$rigTmp/r3" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1070Z-rig-r1.md:advanced:inline:r3
rigAssert "so the next round's proof lands, with its own receipt" "$( cat "$rigTmp/r3.rc" )" 0
rigAssert "and the item now carries that round's receipt" \
	"$( LC_ALL=C awk '/^execution-receipt: /{ print substr($0, 20) ; exit }' "$rigData/board/running/task-20261104T1070Z-rig-r1.md" )" "inline:r3"
rigItem blocked task-20261104T1071Z-rig-moved.md "owner: keeper-rig"
rigOp "$rigTmp/moved1" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1071Z-rig-moved.md:advanced:inline:m1
rigAssert "a document records one round, then a plain move carries its headers with it" "$( cat "$rigTmp/moved1.rc" )" 0
rigOp "$rigTmp/moved2" rig-session --intern-op-board-upsert-move-edit running task-20261104T1071Z-rig-moved.md --from-state:blocked --context rig-move
rigAssert "the move runs" "$( cat "$rigTmp/moved2.rc" )" 0
rigAssert "and the outcome travels with the document" \
	"$( LC_ALL=C grep -c '^outcome: advanced$' "$rigData/board/running/task-20261104T1071Z-rig-moved.md" || : )" 1
rigOp "$rigTmp/moved3" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1071Z-rig-moved.md:advanced:inline:m2
rigAssert "inside the window the moved document is still held to its round" "$( cat "$rigTmp/moved3.rc" )" 1

echo "-- 3e. only a round stamps last-round-at --"
## The epic gives `blocked` and `parked` a recheck, "which is not a round", and gives the field the
## meaning "when a round last visited". A recheck that stamped it would cost a full window.
for rigPair in "advanced:1" "no-action:0" "parked-spawn-failed:0" "nudged:0" "flagged-once:0" ; do
	rigOutcomeWord="${rigPair%:*}" rigWanted="${rigPair#*:}"
	rigItem running "task-20261104T1080Z-rig-stamp-$rigOutcomeWord.md" "owner: keeper-rig"
	rigOp "$rigTmp/stamp-$rigOutcomeWord" rig-session --advance-batch-outcome magic-coordinator \
		--items:"task-20261104T1080Z-rig-stamp-$rigOutcomeWord.md:$rigOutcomeWord:inline:stamp"
	rigAssert "a $rigOutcomeWord record is accepted" "$( cat "$rigTmp/stamp-$rigOutcomeWord.rc" )" 0
	rigAssert "and for $rigOutcomeWord the field is stamped $rigWanted time(s)" \
		"$( LC_ALL=C grep -c '^last-round-at: ' "$rigData/board/running/task-20261104T1080Z-rig-stamp-$rigOutcomeWord.md" || : )" "$rigWanted"
done
rigItem blocked task-20261104T1081Z-rig-recheck.md "owner: keeper-rig"
rigOp "$rigTmp/recheck" rig-session --advance-batch-outcome magic-coordinator --items:task-20261104T1081Z-rig-recheck.md:no-action:inline:recheck
rigAssert "a recheck on a blocked document leaves it due, since it was given no round" \
	"$( rigDue "$rigData/board/blocked/task-20261104T1081Z-rig-recheck.md" )" due

echo "-- 3f. only the five active states take a record --"
## The model gives a round to the five active states. A write into `processed` or `backlog`
## is no round, and the op refuses it rather than stamping a document nobody sweeps.
for rigState in processed backlog ; do
	rigItem "$rigState" "task-20261104T1090Z-rig-out-$rigState.md" "owner: keeper-rig"
	rigOp "$rigTmp/out-$rigState" rig-session --advance-batch-outcome magic-coordinator \
		--items:"task-20261104T1090Z-rig-out-$rigState.md:advanced:inline:out-$rigState"
	rigAssert "a record for a $rigState document is refused, and says why" \
		"$( cat "$rigTmp/out-$rigState.rc" ):$( LC_ALL=C grep -c -F 'no active state holds' "$rigTmp/out-$rigState" || : )" "1:1"
	rigAssert "and nothing was written into it" \
		"$( LC_ALL=C grep -c '^outcome: ' "$rigData/board/$rigState/task-20261104T1090Z-rig-out-$rigState.md" || : )" 0
done

echo "-- 5. the scan prints the predicate's inputs --"
rigDueText="$( rigDueSection )"
rigAssert "control: the due section printed, and listed the item whose recheck-date has passed" \
	"$( printf '%s\n' "$rigDueText" | LC_ALL=C grep -c -F 'running/task-20261104T1004Z-rig-past.md' || : )" 1
rigAssert "its line carries the recheck-date it read, and names the absent last-round-at" \
	"$( printf '%s\n' "$rigDueText" | LC_ALL=C grep -c -x -F -- "- running/task-20261104T1004Z-rig-past.md recheck-date $rigStampBehind last-round-at -" || : )" 1
rigAssert "a document a round visited inside the window is not listed" \
	"$( printf '%s\n' "$rigDueText" | LC_ALL=C grep -c -F 'rig-fresh.md' || : )" 0
rigAssert "a document whose recheck-date is still ahead is not listed" \
	"$( printf '%s\n' "$rigDueText" | LC_ALL=C grep -c -F 'rig-future.md' || : )" 0

echo "-- 6. a document the section could not read is named, never silently dropped --"
## An unreadable item among due ones made the section print `(none)`, and the duty reads the
## section. A fault that reads as an empty sweep is the one failure the guarantee cannot have.
rigItem running task-20261104T1060Z-rig-one.md "owner: keeper-rig" "recheck-date: $rigStampBehind"
rigItem running task-20261104T1061Z-rig-blind.md "owner: keeper-rig"
chmod 000 "$rigData/board/running/task-20261104T1061Z-rig-blind.md"
rigBlindText="$( rigDueSection )"
chmod 644 "$rigData/board/running/task-20261104T1061Z-rig-blind.md"
rigAssert "the due section names the item it could not read" \
	"$( printf '%s\n' "$rigBlindText" | LC_ALL=C grep -c -F 'running/task-20261104T1061Z-rig-blind.md' || : )" 1
rigAssert "and it still lists the item it could read, never (none) over a due document" \
	"$( printf '%s\n' "$rigBlindText" | LC_ALL=C grep -c -x -F -- "- running/task-20261104T1060Z-rig-one.md recheck-date $rigStampBehind last-round-at -" || : )" 1
rigAssert "and it says the answer is incomplete, in words" \
	"$( printf '%s\n' "$rigBlindText" | LC_ALL=C grep -c -i -e 'not read' -e 'could not' || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD DUE AND HELD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_DUE_AND_HELD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
