#!/usr/bin/env bash
## Behavioural check on S6.27 stage 5: a routine's `deliverables:` reach whoever gives the verdict, and that
## verdict decides the frame. Held, through the review ops as the tooling runs them:
##   1. a handback copies the routine's own declaration onto the item as it enters review, joined by `; `
##   2. a person reviewer's prompt shows each deliverable as an item, so no verdict is asked blind
##   3. a return leaves the frame in force `current`; an accept then makes it `done`, and the frame below stays `open`
##   4. control: a routine declaring none leaves the item with no `deliverables:` header
##   5. a routine declaring deliverables with `review-by: none` is refused at save and at spawn; control: the same
##      `review-by: none` with no deliverables is not refused by that rule
## Offline: a fake `curl` first on PATH, a ps beside it listing the rig's own runs only, and every tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-copy.include.sh" || rigRefuse "the rig's copy helper is missing from the package: sh-test/check-fixtures/rig-copy.include.sh"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set, so the rig has no workspace temp folder}"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsReviewDeliverablesCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ -n "${KEEP_RIG:-}" ] || rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigMembers="$rigWs/.local/agents/members"
mkdir -p "$rigWs/.local/.agents" "$rigSpawned" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
rigRealTool ps "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-coordinator keeper-myx human-owner ; do
	mkdir -p "$rigMembers/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigMembers/$rigMember/SKILL.md"
done
## The routines the frames name: one declaring two deliverables, one declaring none, and the frame below.
printf -- '---\nreview-by: inherit\ndeliverables: the decision, in a named document\ndeliverables: the options weighed\n---\n\n# rig deliver\n' > "$rigMembers/keeper-myx/keeper-myx.rig-deliver.routine.md"
printf -- '---\nreview-by: inherit\n---\n\n# rig plain\n' > "$rigMembers/keeper-myx/keeper-myx.rig-plain.routine.md"
printf -- '---\nreview-by: inherit\n---\n\n# rig base\n' > "$rigMembers/keeper-myx/keeper-myx.rig-base.routine.md"
rigHost="$( hostname -s 2>/dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigMembers"
rigOwnerBoardReady
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One operation of the dispatcher, guarded to this rig's own trees; output into <result>, rc into <result>.rc.
rigOp(){ ## result file, operation and its words...
	local opResult="$1"
	shift
	: > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_SCENARIO="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opResult" 2>&1
	printf '%s' "$?" > "$opResult.rc"
}
## A live run whose record holds the session's stack, and the running item it was spawned for.
rigSession(){ ## spawn-id, item file name, the routine-stack lines
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$1"
	printf 'CRIGSESS1:1700000000.000%s\n' "${#1}" > "$rigWs/.local/agents/sessions/$1/session.thread"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nspawns: %s\nsession-thread: CRIGSESS1:1700000000.000%s\n' "$1" "$1" "$rigHost" "${2%.md}" "${#1}"
		printf 'routine-stack: %s\n' $3
		printf -- '---\n'
	} > "$rigSpawned/$1/$1.spawn.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-succeeded\nreview-by: human-owner\nspawn-id: %s\n---\n\n# rig dispatch\n' "$1" | rigOwnerBoardPut running "$2"
}
rigFramesOf(){ ## spawn id -- the frames its record holds, joined
	LC_ALL=C awk '$0 == "---" { if ( ++d == 2 ) exit ; next ; } d == 1 && index( $0, "routine-stack: " ) == 1 { printf "%s%s", ( n++ ? " -> " : "" ), substr( $0, 16 ) ; }' "$rigSpawned/$1/$1.spawn.md" 2> /dev/null
}
rigHeader(){ ## state, item file name, key
	LC_ALL=C awk -v want="$3: " '$0 == "---" { if ( ++d == 2 ) exit ; next ; } d == 1 && index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$rigData/board/$1/$2" 2> /dev/null
}
rigDlv="rig-dlv-$$-a1b2"
rigPlain="rig-plain-$$-c3d4"
## Both stand-in runs go into the rig's process list before the first operation, since the tooling keeps a read of it.
printf '900011 rig-run --session-id %s\n900012 rig-run --session-id %s\n' "$rigDlv" "$rigPlain" > "$rigTmp/ps.list"
rigSession "$rigDlv" dispatch-rig-dlv.md "keeper-myx.rig-deliver.routine.md:current keeper-myx.rig-base.routine.md:open"
rigSession "$rigPlain" dispatch-rig-plain.md "keeper-myx.rig-plain.routine.md:current keeper-myx.rig-base.routine.md:open"

echo "-- 1. a handback carries the routine's own declaration onto the item --"
rigOp "$rigTmp/h1" --intern-op-review-handback keeper-myx --session-id "$rigDlv" --summary "rig work done"
rigAssert "the handback moves the item into review" "$( cat "$rigTmp/h1.rc" ):$( [ -f "$rigData/board/review/dispatch-rig-dlv.md" ] && echo review )" "0:review"
rigAssert "the item carries the routine's two deliverables, joined by '; '" "$( rigHeader review dispatch-rig-dlv.md deliverables )" "the decision, in a named document; the options weighed"

echo "-- 2. a person reviewer's prompt shows each deliverable as an item --"
rigAssert "the prompt names the first deliverable as an item" "$( LC_ALL=C grep -c -F -- '- the decision, in a named document' "$rigTmp/bodies" 2> /dev/null || : )" 1
rigAssert "and the second" "$( LC_ALL=C grep -c -F -- '- the options weighed' "$rigTmp/bodies" 2> /dev/null || : )" 1

echo "-- 3. a return leaves the frame current; an accept then makes it done --"
rigOp "$rigTmp/r1" --intern-op-review-return magic-coordinator dispatch-rig-dlv.md --message "the decision document is missing"
rigAssert "the return moves the item back to running" "$( cat "$rigTmp/r1.rc" ):$( [ -f "$rigData/board/running/dispatch-rig-dlv.md" ] && echo running )" "0:running"
rigAssert "after the return the frame in force is still current" "$( rigFramesOf "$rigDlv" )" "keeper-myx.rig-deliver.routine.md:current -> keeper-myx.rig-base.routine.md:open"
rigOp "$rigTmp/h2" --intern-op-review-handback keeper-myx --session-id "$rigDlv" --summary "the document is written"
rigOp "$rigTmp/a1" --intern-op-review-accept magic-coordinator dispatch-rig-dlv.md
rigAssert "the accept moves the item to processed" "$( cat "$rigTmp/h2.rc" ):$( cat "$rigTmp/a1.rc" ):$( [ -f "$rigData/board/processed/dispatch-rig-dlv.md" ] && echo processed )" "0:0:processed"
rigAssert "after the accept the frame is done, and the frame below stays open" "$( rigFramesOf "$rigDlv" )" "keeper-myx.rig-deliver.routine.md:done -> keeper-myx.rig-base.routine.md:open"

echo "-- 4. control: a routine declaring none --"
rigOp "$rigTmp/h3" --intern-op-review-handback keeper-myx --session-id "$rigPlain" --summary "rig work done"
rigAssert "control: the handback moves that item into review" "$( cat "$rigTmp/h3.rc" ):$( [ -f "$rigData/board/review/dispatch-rig-plain.md" ] && echo review )" "0:review"
rigAssert "control: the item carries no deliverables" "$( rigHeader review dispatch-rig-plain.md deliverables )" ""

echo "-- 5. deliverables with review-by: none are refused at save and at spawn --"
printf -- '---\nreview-by: none\ndeliverables: the decision, in a named document\n---\n\n# rig unjudged\n' > "$rigTmp/unjudged.routine.md"
printf -- '---\nreview-by: none\n---\n\n# rig unreviewed\n' > "$rigTmp/unreviewed.routine.md"
rigVerdict(){ ## routine file, phase -- the verdict word of the review-by requirement
	( MMDAPP="$rigWs" ; . "$rigLib/routine/AgentsTools.RoutineRequirements.include" && AgentsToolsRoutineRequirement review-by "$2" "$1" 2> /dev/null ) | LC_ALL=C awk -F'\t' 'NR == 1 { print $1 ; }'
}
rigAssert "deliverables with review-by: none are refused at save" "$( rigVerdict "$rigTmp/unjudged.routine.md" save )" reject
rigAssert "and at spawn" "$( rigVerdict "$rigTmp/unjudged.routine.md" spawn )" reject
rigAssert "control: review-by: none with no deliverables is not refused by that rule" "$( rigVerdict "$rigTmp/unreviewed.routine.md" save )" validate

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW DELIVERABLES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_DELIVERABLES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
