#!/usr/bin/env bash
## Behavioural check on the three guards one cleanup apply pass honours: it never takes a sandbox whose run
## still lives, one an open undo record promises, or one whose work is still in review, and it does take the
## one with nothing behind it. The claim is the design's: the outcome of one pass over four sandboxes of the
## same age reads `running=kept undo=kept review=kept zombie=removed`.
## Red before the build: the sweep does not exist, so the pass removes nothing and the sandbox with nothing
## behind it survives -- the assertion's last word reads `kept` where it wants `removed`.
## Offline: a rig workspace and a rig store of this check's own; the live run is a stand-in process carrying
## its own spawn id.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCleanupSweepGuardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do rigProcSignalWithChildren KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigData="$rigWs/.local/agents/team-data-root"
rigSp="$rigWs/.local/agents/spawned"
rigSess="$rigWs/.local/agents/sessions"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigSp" "$rigSess" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1

## THE BOARD: the item of the sandbox whose review is open, and the closed item of the one with nothing behind it.
rigBoardStates "$rigData" review processed || rigRefuse "the rig's board was not made ready"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rigcl-review\n---\n\n# rig work, in review\n' \
	| rigStoreItem "$rigData" board review dispatch-rigcl-review.md || rigRefuse "the board item in review was not written"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rigcl-zombie\n---\n\n# rig work, closed\n' \
	| rigStoreItem "$rigData" board processed dispatch-rigcl-zombie.md || rigRefuse "the closed board item was not written"

## THE UNDO RECORD: one open record of the rig's own session store, named by the marker of its sandbox.
## A record is written as AgentsTools.OpUndoRecord.include writes it: `<key>: <value>` lines and no fence.
## The reader stops at the first line equal to `---`, so a fenced record reads as no state at all.
mkdir -p "$rigSess/rigcl-undo/undo/rigcl-record" || exit 1
{
	printf 'record-id: rigcl-record\n'
	printf 'session-id: rigcl-undo\n'
	printf 'actor: none\n'
	printf 'kind: prune\n'
	printf 'state: open\n'
	printf 'at: 2026-11-27T04:00:00Z\n'
	printf 'target: a run folder\n'
} > "$rigSess/rigcl-undo/undo/rigcl-record/record" || exit 1

## THE FOUR SANDBOXES: the same age, past both settings, each with one file in its output/ so a pass has
## something of its own to take.
rigSandbox(){ ## run, its linked board item `dispatch-<run>` (`-` for none), its undo hold (`yes` for one)
	mkdir -p "$rigSp/$1/output/rig-member" "$rigSp/$1/input/$1" || return 1
	printf 'rig deliverable\n' > "$rigSp/$1/output/rig-member/note.md" || return 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: rig-member\nhost: %s\nstatus: spawn-succeeded\n' "$1" "$1" "$rigHost" > "$rigSp/$1/$1.spawn.md" || return 1
	[ "$2" = - ] || printf 'spawned-by: dispatch-%s\n' "$1" >> "$rigSp/$1/$1.spawn.md"
	printf -- '---\n' >> "$rigSp/$1/$1.spawn.md"
	[ "$3" != yes ] || printf 'rigcl-undo/rigcl-record\n' > "$rigSp/$1/undo.hold"
	## The output tree is aged with the folder: the sweep reads the newest entry inside it, so a file written now
	## keeps the sandbox whatever the folder's own time says.
	touch -t 202611200000 "$rigSp/$1/$1.spawn.md" "$rigSp/$1" "$rigSp/$1/output" "$rigSp/$1/output/rig-member" "$rigSp/$1/output/rig-member/note.md" || return 1
	[ "$3" = yes ] || true
}
rigSandbox rigcl-running - no || rigRefuse "the running sandbox was not made"
rigSandbox rigcl-undo - yes || rigRefuse "the undo-held sandbox was not made"
rigSandbox rigcl-review review no || rigRefuse "the review sandbox was not made"
rigSandbox rigcl-zombie processed no || rigRefuse "the dead sandbox was not made"
## The run of the first one, alive while the pass runs: a stand-in process carrying its own spawn id.
python3 -I -B -c 'import time; time.sleep(600)' -- --session-id rigcl-running > /dev/null 2>&1 &
rigPids="$rigPids $!"
disown "$!" 2> /dev/null || :
rigProcNote "$!"
sleep 2

rigSurvives(){ ## run -- `kept` while that sandbox's output/ still holds its file, `removed` once it is empty
	[ -n "$( find "$rigSp/$1/output" -mindepth 1 2> /dev/null | head -1 )" ] && printf kept || printf removed
}

echo "-- one apply pass over the four sandboxes --"
( cd "$rigWs" || exit 1
  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_TEAM_DATA_COMMIT_THREAD=off \
	bash "$rigTool" --intern-cleanup-sweep --apply ) > "$rigTmp/sweep.out" 2> "$rigTmp/sweep.err"
printf '%s' "$?" > "$rigTmp/sweep.rc"
rigOutcome="running=$( rigSurvives rigcl-running ) undo=$( rigSurvives rigcl-undo ) review=$( rigSurvives rigcl-review ) zombie=$( rigSurvives rigcl-zombie )"
rigAssert "the guards hold and the dead sandbox goes" "$rigOutcome" "running=kept undo=kept review=kept zombie=removed"
## The word, not only the folder: `missing` keeps a folder too, so the outcome above passes on a record no reader can parse.
rigAssert "the marker of the rig's open record reads held" "$( MMDAPP="$rigWs" bash -c '. "$1" ; AgentsToolsUndoHoldState "$2"' rig "$rigPackage/sh-lib/undo/AgentsTools.UndoHold.include" "$rigSp/rigcl-undo/undo.hold" 2> /dev/null )" "held"
printf '  # the pass returned %s%s\n' "$( cat "$rigTmp/sweep.rc" )" \
	"$( [ ! -s "$rigTmp/sweep.err" ] || printf ', saying: %s' "$( LC_ALL=C grep -e 'ERROR' -e 'invalid option' "$rigTmp/sweep.err" 2> /dev/null | LC_ALL=C sed -n 1p )" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CLEANUP SWEEP GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CLEANUP_SWEEP_GUARD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
