#!/usr/bin/env bash
## Behavioural check on the climb of a review (epic S6.28): the reviewer and the parent first, then the duty,
## then the human-owner, and no rung is skipped. Held at the verdict gate every verdict passes
## (sh-lib/board/AgentsTools.InternOpReview.include, its four verdict ops, and the rung read it asks,
## sh-lib/board/AgentsTools.ItemReviewer.include).
## The fault: the duty gives a verdict on an item whose own reviewer is a live parent run, so an item a
## session still needs is taken from it. Rows 1 and 2 are that fault; rows 3 to 7 are the controls, each a
## case the climb leaves exactly as it was: the parent gone, the duty's own item, the human-owner's own
## item, a bare member reviewer with no run of its own, and the reviewer's own run.
## Section 3 is the second fault: a dispatch a duty round spawns reads that round as its reviewer, and the
## round works through a run of its own, so the rung and the asking run are one session under two ids.
## Its first row is that case, and its second row is the control: the same asking run, and a rung that
## really is another session's.
## Offline: the fake `curl` first on PATH logs a Slack call and opens no socket; the board, the sandbox
## records and the workspace are this rig's own temp tree; the live parent is a stand-in of this check
## alone, ended at its end. Never the live team data or .local/agents.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPkg/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
[ -f "$rigPkg/sh-lib/board/AgentsTools.ItemReviewer.include" ] || rigRefuse "the reviewer include is missing from the package"
[ -f "$rigPkg/sh-lib/board/AgentsTools.InternOpReview.include" ] || rigRefuse "the review op include is missing from the package"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewClimbCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
rigSpawned="$rigWs/.local/agents/spawned"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigSpawned" "$rigTmp/bin" \
	"$rigData/inboxes/magic-coordinator/incoming" "$rigHome" "$rigSkills/magic-coordinator" || rigRefuse "could not create the rig"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The board is written by its own writer, never a file by hand.
. "$rigPkg/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigHome" rigOwnerSkills="$rigSkills" rigOwnerOrigin="$rigOrigin" rigOwnerMember=magic-coordinator
rigOwnerBoardReady

## One live run of this check's own: a process running as that session id, recorded as the run its record
## names, for the member its `owner:` names. Ended at the end of the check, and only while it is still the
## process this check started.
rigLiveRun(){ ## session id, the member that runs there
	bash -c 'sleep 240 ; :' rig-live-run --session-id "$1" > /dev/null 2>&1 < /dev/null &
	local livePid=$!
	rigLivePids="$rigLivePids $livePid"
	rigProcNote "$livePid"
	disown "$livePid" 2> /dev/null || :
	local liveBegan
	liveBegan="$( PATH="$rigProcPath" ps -o lstart= -p "$livePid" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	[ -n "$liveBegan" ] || rigRefuse "the live run stand-in did not start, so nothing below would be measured"
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nrun-process: %s %s\n---\n\n# rig live run\n' \
		"$1" "$1" "$1" "$rigHost" "$2" "$livePid" "$liveBegan" > "$rigSpawned/$1/$1.spawn.md"
}
## An item's own run: its record names the reviewer it reports to, which is how the tooling reads it.
rigChildRun(){ ## spawn id, reports-to value
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nhost: %s\nowner: keeper-rig\nstatus: spawn-started\nreports-to: %s\n---\n\n# rig child run\n' \
		"$1" "$1" "$rigHost" "$2" > "$rigSpawned/$1/$1.spawn.md"
}
## A run that joined a session: its own id, and the session its record names. A duty round works
## through such a run, so the run that gives a verdict is not the session id the item reads.
rigJoinedRun(){ ## run id, session id, the member that runs there
	bash -c 'sleep 240 ; :' rig-joined-run --session-id "$1" > /dev/null 2>&1 < /dev/null &
	local joinedPid=$!
	rigLivePids="$rigLivePids $joinedPid"
	rigProcNote "$joinedPid"
	disown "$joinedPid" 2> /dev/null || :
	local joinedBegan
	joinedBegan="$( PATH="$rigProcPath" ps -o lstart= -p "$joinedPid" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	[ -n "$joinedBegan" ] || rigRefuse "the joined run stand-in did not start, so nothing below would be measured"
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nrun-process: %s %s\n---\n\n# rig joined run\n' \
		"$2" "$1" "$1" "$rigHost" "$3" "$joinedPid" "$joinedBegan" > "$rigSpawned/$1/$1.spawn.md"
}
## A dispatch a session spawned: its own run, the session that spawned it, and the member there.
rigChildRunIn(){ ## spawn id, parent session id, parent member
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nhost: %s\nowner: keeper-rig\nstatus: spawn-started\nparent-session-id: %s\nparent-member: %s\n---\n\n# rig dispatch\n' \
		"$1" "$1" "$rigHost" "$2" "$3" > "$rigSpawned/$1/$1.spawn.md"
}
## A review item: its name, its own run's spawn id, and its own header lines.
rigReview(){ ## item stem, its run's spawn id, extra header lines
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# rig review item\n' \
		"$2" "${3:-}" | rigOwnerBoardPut review "$1.md"
}
## One verdict call of the tooling, from a run of the member given. Extra environment as NAME=value words in rigEnv.
rigEnv=()
rigVerdict(){ ## result file, the op's own words...
	local verdictOut="$1" ; shift
	: > "$rigTmp/calls"
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
			MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_DATA_ROOT="$rigData" \
			MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" MDAT_TEAM_DATA_COMMIT_THREAD=off \
			"${rigEnv[@]+"${rigEnv[@]}"}" bash "$rigFn" "$@"
	) > "$verdictOut" 2>&1
	printf '%s' "$?" > "$verdictOut.rc"
}
rigLoc(){ ## item stem -- the board state holding it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}

## The subjects. A live parent run of magic-coordinator in a session of its own is the rung below the duty.
rigLiveRun rig-parent-live magic-coordinator
rigLiveRun rig-own-run     keeper-myx
rigChildRun rig-child-live   rig-parent-live:magic-coordinator
rigChildRun rig-child-gone   rig-parent-gone:magic-coordinator
rigChildRun rig-child-bare   keeper-myx
rigChildRun rig-child-own    keeper-myx
rigReview task-rig-live-parent  rig-child-live  ""
rigReview task-rig-gone-parent  rig-child-gone  ""
rigReview task-rig-own-rung     ""              "review-by: magic-coordinator
"
rigReview task-rig-human-rung   ""              "review-by: human-owner
"
rigReview task-rig-bare-member  rig-child-bare  ""
rigReview task-rig-reviewer-run rig-child-own   "review-by: keeper-myx
"
## A duty round's run, joined into the round's own session, and the dispatch that session spawned.
rigJoinedRun  rig-duty-run      rig-duty-session  magic-coordinator
rigChildRunIn rig-child-owned   rig-duty-session  magic-coordinator
rigChildRunIn rig-child-other   rig-parent-live   magic-coordinator
rigReview task-rig-duty-own    rig-child-owned  ""
rigReview task-rig-duty-other  rig-child-other  ""
## The duty acts from a session of its own, never from the parent's.
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-duty-session )

echo "-- 1. no rung is skipped: a live parent's item is not the duty's to settle --"
rigVerdict "$rigTmp/c1" --accept-review --team-member magic-coordinator task-rig-live-parent
rigAssert "the duty gives no verdict on it"                    "$( cat "$rigTmp/c1.rc" ):$( rigLoc task-rig-live-parent )" 1:review
rigVerdict "$rigTmp/c2" --reject-review --team-member magic-coordinator task-rig-live-parent --message "not its call"
rigAssert "and a reject waits for that rung too"               "$( cat "$rigTmp/c2.rc" ):$( rigLoc task-rig-live-parent )" 1:review
rigLocNow="$( rigLoc task-rig-live-parent )"
rigAssert "so the item carries no verdict of the duty's"       "${rigLocNow}:$( [ -f "$rigData/board/$rigLocNow/task-rig-live-parent.md" ] && LC_ALL=C grep -c '^## Review: ' "$rigData/board/$rigLocNow/task-rig-live-parent.md" )" "review:0"

echo "-- 2. the controls: every case the climb leaves as it was --"
rigVerdict "$rigTmp/c3" --accept-review --team-member magic-coordinator task-rig-gone-parent
rigAssert "the parent gone: the duty accepts, as last resort"  "$( cat "$rigTmp/c3.rc" ):$( rigLoc task-rig-gone-parent )" 0:processed
rigVerdict "$rigTmp/c4" --accept-review --team-member magic-coordinator task-rig-own-rung
rigAssert "the duty's own rung accepts"                        "$( cat "$rigTmp/c4.rc" ):$( rigLoc task-rig-own-rung )" 0:processed
rigVerdict "$rigTmp/c5" --accept-review --team-member magic-coordinator task-rig-bare-member
rigAssert "a bare member reviewer with no run: last resort"    "$( cat "$rigTmp/c5.rc" ):$( rigLoc task-rig-bare-member )" 0:processed
rigEnv=()
rigVerdict "$rigTmp/c6" --accept-review --team-member human-owner task-rig-human-rung
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-duty-session )
rigAssert "the human-owner acts on his own item"               "$( cat "$rigTmp/c6.rc" ):$( rigLoc task-rig-human-rung )" 0:processed
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-own-run )
rigVerdict "$rigTmp/c7" --accept-review --team-member keeper-myx task-rig-reviewer-run
rigEnv=()
rigAssert "the reviewer's own run accepts its own item"        "$( cat "$rigTmp/c7.rc" ):$( rigLoc task-rig-reviewer-run )" 0:processed

echo "-- 3. a duty round settles the dispatch it spawned, and only that --"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-duty-run )
rigVerdict "$rigTmp/c8" --accept-review --team-member magic-coordinator task-rig-duty-own
rigAssert "the round's run accepts the dispatch it spawned"     "$( cat "$rigTmp/c8.rc" ):$( rigLoc task-rig-duty-own )" 0:processed
rigVerdict "$rigTmp/c9" --accept-review --team-member magic-coordinator task-rig-duty-other
rigAssert "a rung in another live session still comes first"    "$( cat "$rigTmp/c9.rc" ):$( rigLoc task-rig-duty-other )" 1:review
rigEnv=()

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW CLIMB CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_CLIMB: OK (%d assertions, offline)\n' "$rigPassCount"
