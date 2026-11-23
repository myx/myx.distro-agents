#!/usr/bin/env bash
## Behavioural check on one cleanup sweep with two populations and two clocks: it removes the scratch whose
## own work has ended, and it removes no record, whatever its age. The claim is the design's: the sweep is
## `AgentsToolsCleanupSweep`, run by hand through `--intern-cleanup-sweep --preview|--apply`, and the summary
## line of one apply pass reads `removed=2 left-records=1`.
## Red before the build: no such operation exists, so the call answers with an unknown-operation error and
## prints no summary at all.
## Offline: a rig workspace and a rig store of this check's own, holding an aged and a fresh temp entry, one
## copy of a closed item's sandbox, one of an item in review, and one session folder 40 days old.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCleanupSweepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

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

## THE SCRATCH: one temp entry past the age setting, one inside it.
: > "$rigWs/.local/temp/mdat-rig-aged.tmp"
: > "$rigWs/.local/temp/mdat-rig-fresh.tmp"
touch -t 202611200000 "$rigWs/.local/temp/mdat-rig-aged.tmp"

## THE BOARD: one dispatch of this rig, closed, and one still in review. Each names the run whose sandbox
## holds the copy.
rigBoardStates "$rigData" processed review || rigRefuse "the rig's board was not made ready"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rigcl-closed\n---\n\n# rig work, closed\n' \
	| rigStoreItem "$rigData" board processed dispatch-rigcl-closed.md || rigRefuse "the closed board item was not written"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rigcl-review\n---\n\n# rig work, in review\n' \
	| rigStoreItem "$rigData" board review dispatch-rigcl-review.md || rigRefuse "the board item in review was not written"

## THE SANDBOXES: each past both settings, each holding one marked copy of a source tree in its output/.
rigSandbox(){ ## run -- its record links the board item of the same name, dispatch-<run>
	mkdir -p "$rigSp/$1/output/rig-member/rigpkg/.git" "$rigSp/$1/input/$1" || return 1
	printf '# rigpkg\n' > "$rigSp/$1/output/rig-member/rigpkg/MAGIC.md"
	: > "$rigSp/$1/output/rig-member/rigpkg/.git/HEAD"
	printf 'rigpkg\t%s\t0\t2026-11-20T00:00:00Z\n' "$rigSp/$1/output/rig-member/rigpkg" > "$rigSp/$1/output/copies.manifest"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: rig-member\nhost: %s\nstatus: spawn-succeeded\nspawned-by: dispatch-%s\n---\n' \
		"$1" "$1" "$rigHost" "$1" > "$rigSp/$1/$1.spawn.md"
	touch -t 202611200000 "$rigSp/$1/$1.spawn.md"
}
rigSandbox rigcl-closed || rigRefuse "the closed item's sandbox was not made"
rigSandbox rigcl-review || rigRefuse "the review item's sandbox was not made"

## THE RECORD: one session folder 40 days old, which no age of the sweep's may take.
mkdir -p "$rigSess/rigcl-session" || exit 1
printf 'rig log\n' > "$rigSess/rigcl-session/log" || exit 1
touch -t 202610140000 "$rigSess/rigcl-session" "$rigSess/rigcl-session/log"

echo "-- one apply pass over the rig --"
( cd "$rigWs" || exit 1
  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_TEAM_DATA_COMMIT_THREAD=off \
	bash "$rigTool" --intern-cleanup-sweep --apply ) > "$rigTmp/sweep.out" 2> "$rigTmp/sweep.err"
printf '%s' "$?" > "$rigTmp/sweep.rc"
rigSummary="$( LC_ALL=C grep -x -e 'removed=2 left-records=1' "$rigTmp/sweep.out" "$rigTmp/sweep.err" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigAssert "one apply pass says removed=2 left-records=1" "$( cat "$rigTmp/sweep.rc" ):$rigSummary" "0:1"
[ ! -s "$rigTmp/sweep.err" ] || printf '  # the sweep said: %s\n' "$( LC_ALL=C grep -e 'ERROR' -e 'invalid option' "$rigTmp/sweep.err" 2> /dev/null | LC_ALL=C sed -n 1p )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CLEANUP SWEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CLEANUP_SWEEP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
