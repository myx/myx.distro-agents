#!/usr/bin/env bash
## Behavioural check on the `undo` ask kind (S13.19 stage 3): the kind is in the table of the
## asks, its template posts the act, its inverse and the material held, its Three answers are
## `accept`, `reject` and `rework`, and its verdict reader takes those three words and no other.
## Held:
##   1. the table of the asks names `undo`, with its template and the `verdict` answer form, and
##      a kind it does not name is still refused -- the negative control;
##   2. the post: who acted, the act by its kind and target, the step that undoes it, and the
##      material kept from cleanup;
##   3. the post that takes no answer any more: the same text with no How to answer, and one mark;
##   4. the emoji the tooling places: accept, reject and rework, and none of them the mark the
##      tooling puts on an answered question;
##   5. the verdict reader: `accept`, `reject` and `rework` each read as themselves, each carries
##      the words beside it, and `ok`, `yes`, `approve` and `return` name none of them, so a plain
##      affirmation never accepts an act here.
## Red recipe: take the `|undo|` row out of agentsAskTools (AgentsTools.AskPost.include), and
## cases 1 to 4 fail; take the `undo` arm out of AgentsEscalationVerdict.awk and case 5 fails.
## Offline: the template is filled straight, and the reader is an awk program on stdin. No
## curl, no network, no workspace and no team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigLib/questions/AgentsTools.AskPost.include" ] || rigRefuse "the ask table is not at the origin this workspace resolves: $rigLib"
[ -f "$rigLib/templates/undo-approve.post.format.md" ] || rigRefuse "the undo template is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's fixture that makes its folder is missing from the package"
rigTmp="$( rigTempDir AgentsUndoAskCheck )" || rigRefuse "the rig's own folder could not be made"
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One row of the ask table, by the tool name or the kind: `<name>|<kind>|<template>|<form>|`.
rigRow(){ ## name or kind
	( MDSC_CMD=rig ; . "$rigLib/questions/AgentsTools.AskPost.include"
		if AgentsToolsAskToolRow "$1" 2> /dev/null ; then printf '%s|%s|%s|%s|' "$agentsAskRowName" "$agentsAskRowKind" "$agentsAskRowTemplate" "$agentsAskRowForm"
		elif AgentsToolsAskKindRow "$1" 2> /dev/null ; then printf '%s|%s|%s|%s|' "$agentsAskRowName" "$agentsAskRowKind" "$agentsAskRowTemplate" "$agentsAskRowForm"
		else printf 'no-row' ; fi )
}
## The undo template filled straight, its slots from the caller's environment.
rigFill(){ ## want
	ASKP_WANT="$1" ASKP_FORM=verdict LC_ALL=C awk \
		-f "$rigLib/comms/AgentsToolingTemplateFill.awk" -f "$rigLib/questions/AgentsAskPostFill.awk" \
		"$rigLib/templates/undo-approve.post.format.md" 2>&1
}
## The verdict reader on one reply line, as a DM's thread gives it: `<verdict>|<author>`.
rigVerdict(){ ## the reply's first line
	printf '1700000001.000200 | URIGOWNER | %s\n' "$1" \
		| MDAT_VERDICT_WORDS=1 MDAT_VERDICT_KIND=undo MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
			LC_ALL=C awk -f "$rigLib/questions/AgentsEscalationVerdict.awk" 2>&1 | LC_ALL=C cut -f1-2 | LC_ALL=C tr '\t' '|'
}
## The verdict reader on one reaction held by him under the question.
rigClick(){ ## emoji name
	printf 'reaction on the question: [reactions: %s (URIGOWNER)]\n' "$1" \
		| MDAT_VERDICT_KIND=undo MDAT_VERDICT_AUTHORS=URIGOWNER MDAT_VERDICT_ASKING=URIGSELF1 \
			LC_ALL=C awk -f "$rigLib/questions/AgentsEscalationVerdict.awk" 2>&1 | LC_ALL=C cut -f1-2 | LC_ALL=C tr '\t' '|'
}
rigAct="$( printf '`file-write` on `/ws/source/myx/x.include`' )"
rigInverse="  step AgentsUniversalHarness --intern-tool /ws/source/myx/x.include"
rigHold="ws:source/myx/x.spawn/input"
rigFillPost(){ ASKP_F_member=lexr ASKP_F_act="$rigAct" ASKP_F_inverse="$rigInverse" ASKP_F_hold="$rigHold" rigFill "$1" ; }

echo "-- 1. the table of the asks --"
rigAssert "the kind undo is in the table, with its own template and the verdict form" \
	"$( rigRow undo )" "|undo|undo-approve.post.format.md|verdict|"
rigAssert "a kind outside the table is still refused" "$( rigRow not-a-kind )" "no-row"

echo "-- 2. the post --"
rigAssert "the post names who acted, the act, the step that undoes it, and what is held" \
	"$( rigFillPost post | LC_ALL=C grep -c -e '^lexr acted' -e '`file-write` on `/ws/source/myx/x.include`' -e '^  step AgentsUniversalHarness --intern-tool /ws/source/myx/x.include' -e '^ws:source/myx/x.spawn/input' )" 4
rigAssert "and it says how to answer, in the three words" \
	"$( rigFillPost post | LC_ALL=C grep -c -e '`accept`, `reject` or `rework`' -e 'rework needs your words' )" 2

echo "-- 3. the post that takes no answer any more --"
rigAssert "the closed post keeps the act and drops How to answer" \
	"$( rigFillPost closed | LC_ALL=C grep -c 'How to answer' ):$( rigFillPost closed | LC_ALL=C grep -c 'To undo it' )" "0:1"
rigAssert "and its one mark is the cancelled sign" \
	"$( ASKP_F_member=lexr ASKP_BLOCK=Marks/cancelled rigFill block )" "no_entry_sign"

echo "-- 4. the emoji the tooling places --"
rigAssert "the post carries accept, reject and rework, one a line, and never the answered mark" \
	"$( rigFillPost reactions | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "leftwards_arrow_with_hook +1 x"
rigAssert "none of them is white_check_mark" "$( rigFillPost reactions | LC_ALL=C grep -c white_check_mark )" 0

echo "-- 5. the verdict reader --"
rigAssert "accept reads as accept and carries his words" "$( rigVerdict 'accept, looks right' )" "accept -- looks right|URIGOWNER"
rigAssert "reject reads as reject and carries his words" "$( rigVerdict 'reject -- this changes a shared file' )" "reject -- this changes a shared file|URIGOWNER"
rigAssert "rework reads as rework and carries his words" "$( rigVerdict 'rework, do it as a copy first' )" "rework -- do it as a copy first|URIGOWNER"
rigAssert "a click accepts, a click rejects, and a click asks for a rework" \
	"$( rigClick +1 ):$( rigClick x ):$( rigClick leftwards_arrow_with_hook )" "accept|URIGOWNER:reject|URIGOWNER:rework|URIGOWNER"
rigAssert "a plain affirmation never accepts an act here" \
	"$( rigVerdict 'ok' ):$( rigVerdict 'yes please' ):$( rigVerdict 'approve' ):$( rigVerdict 'return' )" "RETURNED|:RETURNED|:RETURNED|:RETURNED|"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ UNDO ASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'UNDO_ASK: OK (%d assertions, offline)\n' "$rigPassCount"
