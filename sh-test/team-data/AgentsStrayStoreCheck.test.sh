#!/usr/bin/env bash
## AgentsStrayStoreCheck -- the stray store of a workspace that keeps no team data is listed and returned by a tool, never a
## hand (AgentsTools.StrayStore.include; epic S12.18, S12.19).
## Guards: the list names every file with its kind, state, owner and the rig a dispatch item was paid by; the plan moves
## nothing and names a move, an identical copy, a differing copy and the unplaced inbox and audit files; the apply moves the
## absent one to the rig's own store at the same path, removes the identical one, leaves the differing one and the unplaced
## ones; a second apply changes nothing; a rig named by a path, or one that is this workspace, places nothing; a workspace in
## team-rig mode is refused, and nothing is printed; an inbox item takes the one rig whose board holds a run of its writer
## covering its moment, is `ambiguous` where two do and `-` where none does, and the placed one moves with the apply; with
## `--inbox-to <rig>` the ambiguous and the unmatched inbox items take that rig, a placed one keeps its own, and a rig named by
## a path is refused.
## Red: a return that moves on the plan fails `the plan moves nothing`; one that overwrites fails `the differing copy is left`.
## Offline: a temp folder of this check alone, two workspaces beside each other, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsStrayStoreCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsStrayStoreCheck.XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigJust="$rigTmp/ws-just" ; rigRig="$rigTmp/ws-rig" ; rigStore="$rigJust/.local/agents/team-data-root" ; rigRoot="$rigRig/team-data"
mkdir -p "$rigStore/board/processed" "$rigStore/board/review" "$rigStore/inboxes/magic-tester/incoming" "$rigStore/audit/2026-11" \
	"$rigRig/.local/.agents" "$rigRoot/board/processed" "$rigJust/.local/.agents" || exit 1
printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigRoot" > "$rigRig/.local/.agents/magic-coordinator.agent.env"
rigItem(){ ## path, paying workspace, body word
	printf -- '---\ntype: dispatch\nowner: magic-tester\npaying-workspace: %s\nstatus: processed\n---\n\n# Item\n\n%s\n' "$2" "$3" > "$1"
}
rigItem "$rigStore/board/processed/dispatch-a.md" ws-rig alpha
rigItem "$rigStore/board/processed/dispatch-b.md" ws-rig beta
rigItem "$rigStore/board/processed/dispatch-c.md" ws-rig gamma
rigItem "$rigStore/board/review/dispatch-d.md" ../ws-rig delta
rigItem "$rigStore/board/review/dispatch-e.md" ws-just epsilon
cp "$rigStore/board/processed/dispatch-b.md" "$rigRoot/board/processed/dispatch-b.md"
rigItem "$rigRoot/board/processed/dispatch-c.md" ws-rig "gamma, changed on the rig"
printf -- '---\ntype: reflection\nowner: magic-tester\n---\n\n# Reflection\n' > "$rigStore/inboxes/magic-tester/incoming/reflection-x.md"
printf 'refusal\n' > "$rigStore/audit/2026-11/one.txt"
rigRun(){ ## mode (just-agents|team-rig), function, args...
	( MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE="$1" ; export MDLT_ORIGIN MDAT_WORKSPACE_MODE ; unset MMDAPP ; . "$rigLib/team-data/AgentsTools.StrayStore.include" ; shift ; "$@" ) 2> "$rigTmp/err"
}

echo "-- 1. the list names every file --"
rigRun just-agents AgentsToolsStrayStoreList "$rigJust" > "$rigTmp/list"
rigAssert "seven rows, one a file"                           "$( LC_ALL=C wc -l < "$rigTmp/list" | LC_ALL=C tr -d ' ' )" 7
rigAssert "a dispatch item names its kind, state, owner, rig" "$( LC_ALL=C grep -F 'dispatch-a.md' "$rigTmp/list" )" "$( printf 'board\tprocessed\tmagic-tester\tws-rig\tboard/processed/dispatch-a.md' )"
rigAssert "an inbox item names its member's state and owner" "$( LC_ALL=C grep -F 'reflection-x.md' "$rigTmp/list" )" "$( printf 'inbox\tincoming\tmagic-tester\t-\tinboxes/magic-tester/incoming/reflection-x.md' )"
rigAssert "an audit record is audit"                         "$( LC_ALL=C grep -F 'one.txt' "$rigTmp/list" | LC_ALL=C cut -f 1 )" audit
rigAssert "the summary counts them"                          "$( LC_ALL=C grep -c '^# 7 file(s) in the stray store' "$rigTmp/err" )" 1

echo "-- 2. the plan moves nothing and names each verdict --"
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJust" > "$rigTmp/plan"
rigAssert "the plan moves nothing"                           "$( [ -f "$rigStore/board/processed/dispatch-a.md" ] && [ ! -e "$rigRoot/board/processed/dispatch-a.md" ] && printf yes || printf no )" yes
rigAssert "absent at the rig: move, to the same path"        "$( LC_ALL=C grep -F 'dispatch-a.md' "$rigTmp/plan" )" "$( printf 'move\tboard/processed/dispatch-a.md\t%s/board/processed/dispatch-a.md' "$rigRoot" )"
rigAssert "identical at the rig: same"                       "$( LC_ALL=C grep -F 'dispatch-b.md' "$rigTmp/plan" | LC_ALL=C cut -f 1 )" same
rigAssert "differing at the rig: differs"                    "$( LC_ALL=C grep -F 'dispatch-c.md' "$rigTmp/plan" | LC_ALL=C cut -f 1 )" differs
rigAssert "a rig named by a path: unplaced"                  "$( LC_ALL=C grep -F 'dispatch-d.md' "$rigTmp/plan" | LC_ALL=C cut -f 1 )" unplaced
rigAssert "a rig that is this workspace: unplaced"           "$( LC_ALL=C grep -F 'dispatch-e.md' "$rigTmp/plan" | LC_ALL=C cut -f 1 )" unplaced
rigAssert "inbox and audit: unplaced"                        "$( LC_ALL=C grep -e 'reflection-x.md' -e 'one.txt' "$rigTmp/plan" | LC_ALL=C cut -f 1 | LC_ALL=C tr '\n' ' ' )" "unplaced unplaced "

echo "-- 3. the apply moves, removes and leaves as planned --"
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJust" --apply > "$rigTmp/apply"
rigAssert "the absent one is moved"                          "$( [ ! -e "$rigStore/board/processed/dispatch-a.md" ] && LC_ALL=C grep -c '^alpha$' "$rigRoot/board/processed/dispatch-a.md" 2> /dev/null )" 1
rigAssert "and said moved"                                   "$( LC_ALL=C grep -F 'dispatch-a.md' "$rigTmp/apply" | LC_ALL=C cut -f 1 )" moved
rigAssert "the identical one is removed here, kept there"    "$( [ ! -e "$rigStore/board/processed/dispatch-b.md" ] && [ -f "$rigRoot/board/processed/dispatch-b.md" ] && printf yes || printf no )" yes
rigAssert "the differing copy is left"                       "$( [ -f "$rigStore/board/processed/dispatch-c.md" ] && LC_ALL=C grep -c 'changed on the rig' "$rigRoot/board/processed/dispatch-c.md" )" 1
rigAssert "the unplaced stay"                                "$( [ -f "$rigStore/board/review/dispatch-d.md" ] && [ -f "$rigStore/board/review/dispatch-e.md" ] && [ -f "$rigStore/inboxes/magic-tester/incoming/reflection-x.md" ] && [ -f "$rigStore/audit/2026-11/one.txt" ] && printf yes || printf no )" yes
rigAssert "the summary"                                      "$( LC_ALL=C grep -c '1 moved, 1 removed as identical, 5 left' "$rigTmp/err" )" 1

echo "-- 4. a second apply changes nothing --"
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJust" --apply > "$rigTmp/apply2"
rigAssert "nothing moved or removed"                         "$( LC_ALL=C grep -c '0 moved, 0 removed as identical, 5 left' "$rigTmp/err" )" 1

echo "-- 5. a workspace in team-rig mode is refused --"
rigAssert "refused, nothing printed"                         "$( rigRun team-rig AgentsToolsStrayStoreList "$rigJust" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'keeps team data' "$rigTmp/err" )" "0:1"

echo "-- 6. an inbox item takes the rig of the session that wrote it --"
rigTwo="$rigTmp/two" ; rigJ2="$rigTwo/ws-just" ; rigStore2="$rigJ2/.local/agents/team-data-root"
rigRigMake(){ ## name, owner of its one run, start, end
	mkdir -p "$rigTwo/$1/.local/.agents" "$rigTwo/$1/team-data/board/processed"
	printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigTwo/$1/team-data" > "$rigTwo/$1/.local/.agents/magic-coordinator.agent.env"
	printf 'MDAT_WORKSPACE_MODE=team-rig\n' > "$rigTwo/$1/.local/.agents/magic-team.agent.env"
	printf -- '---\ntype: dispatch\nowner: %s\nstarted-at: %s\nresolved-at: %s\nstatus: processed\n---\n\n# Run\n' "$2" "$3" "$4" > "$rigTwo/$1/team-data/board/processed/dispatch-run.md"
}
rigRigMake rig-one magic-tester '2026-11-06 10:00 +0000' '2026-11-06 12:00 +0000'
rigRigMake rig-two magic-tester '2026-11-06 11:30 +0000' '2026-11-06 14:00 +0000'
rigRigMake rig-three keeper-x '2026-11-06 00:00 +0000' '2026-11-07 00:00 +0000'
mkdir -p "$rigStore2/inboxes/magic-tester/incoming" "$rigJ2/.local/.agents"
rigInbox(){ ## file, from, date
	printf -- '---\ntype: inquiry\nfrom: %s\nowner: magic-coordinator\ndate: %s\n---\n\n# Inquiry\n' "$2" "$3" > "$rigStore2/inboxes/magic-tester/incoming/$1"
}
rigInbox inquiry-placed.md magic-tester '2026-11-06 12:30 +0200'
rigInbox inquiry-ambiguous.md magic-tester '2026-11-06 13:45 +0200'
rigInbox inquiry-none.md magic-tester '2026-11-06 20:00 +0200'
## An item the inbox write stamped with the writer's workspace: it names its rig itself, no run needed.
printf -- '---\ntype: inquiry\nfrom: magic-tester\nowner: magic-coordinator\nfrom-workspace: rig-three\nfrom-session: rig-session-x\ndate: 2026-11-06 20:00 +0200\n---\n\n# Inquiry\n' > "$rigStore2/inboxes/magic-tester/incoming/inquiry-stamped.md"
rigRun just-agents AgentsToolsStrayStoreList "$rigJ2" > "$rigTmp/list2"
rigAssert "one rig covers the moment: that rig"              "$( LC_ALL=C grep -F 'inquiry-placed.md' "$rigTmp/list2" | LC_ALL=C cut -f 4 )" rig-one
rigAssert "two rigs cover it: ambiguous"                     "$( LC_ALL=C grep -F 'inquiry-ambiguous.md' "$rigTmp/list2" | LC_ALL=C cut -f 4 )" ambiguous
rigAssert "none covers it: -"                                "$( LC_ALL=C grep -F 'inquiry-none.md' "$rigTmp/list2" | LC_ALL=C cut -f 4 )" -
rigAssert "a stamped item names its rig itself"             "$( LC_ALL=C grep -F 'inquiry-stamped.md' "$rigTmp/list2" | LC_ALL=C cut -f 4 )" rig-three
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJ2" --apply > "$rigTmp/apply3"
rigAssert "the placed one is moved to its rig's inbox"       "$( [ -f "$rigTwo/rig-one/team-data/inboxes/magic-tester/incoming/inquiry-placed.md" ] && [ ! -e "$rigStore2/inboxes/magic-tester/incoming/inquiry-placed.md" ] && printf yes || printf no )" yes
rigAssert "the stamped one is moved to the rig it names"     "$( [ -f "$rigTwo/rig-three/team-data/inboxes/magic-tester/incoming/inquiry-stamped.md" ] && printf yes || printf no )" yes
rigAssert "the ambiguous and the unplaced stay"              "$( [ -f "$rigStore2/inboxes/magic-tester/incoming/inquiry-ambiguous.md" ] && [ -f "$rigStore2/inboxes/magic-tester/incoming/inquiry-none.md" ] && printf yes || printf no )" yes
rigAssert "the summary"                                      "$( LC_ALL=C grep -c '2 moved, 0 removed as identical, 2 left' "$rigTmp/err" )" 1
rigAssert "no runs table is left behind"                     "$( ls -d "${TMPDIR:-/tmp}"/stray-runs.* 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 7. the owner names the rig of what no run placed --"
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJ2" --inbox-to rig-two > "$rigTmp/plan4"
rigAssert "the ambiguous and the unmatched go to the named rig" "$( LC_ALL=C grep -e 'inquiry-ambiguous.md' -e 'inquiry-none.md' "$rigTmp/plan4" | LC_ALL=C awk -F'\t' '{ print $1 ":" ( index($3, "/rig-two/team-data/inboxes/") ? "rig-two" : $3 ) }' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "move:rig-two "
rigAssert "the plan moved nothing"                           "$( [ -f "$rigStore2/inboxes/magic-tester/incoming/inquiry-none.md" ] && printf yes || printf no )" yes
rigRun just-agents AgentsToolsStrayStoreReturn "$rigJ2" --apply --inbox-to rig-two > "$rigTmp/apply4"
rigAssert "applied, both stand at rig-two"                   "$( [ -f "$rigTwo/rig-two/team-data/inboxes/magic-tester/incoming/inquiry-ambiguous.md" ] && [ -f "$rigTwo/rig-two/team-data/inboxes/magic-tester/incoming/inquiry-none.md" ] && [ -z "$( ls "$rigStore2/inboxes/magic-tester/incoming" )" ] && printf yes || printf no )" yes
rigAssert "a rig named by a path is refused"                 "$( rigRun just-agents AgentsToolsStrayStoreReturn "$rigJ2" --inbox-to ../rig-two | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c 'takes a rig.s own name' "$rigTmp/err" )" "0:1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ STRAY STORE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: work written into a wrong data root is returned by hand or not at all, or a return overwrites a rig's own copy" >&2
	echo "  fix:  AgentsToolsStrayStoreList and AgentsToolsStrayStoreReturn in sh-lib/team-data/AgentsTools.StrayStore.include" >&2
	exit 1
fi
echo "STRAY_STORE: OK ($rigPass assertions, offline)"
