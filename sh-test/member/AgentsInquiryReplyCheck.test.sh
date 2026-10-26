#!/usr/bin/env bash
## Behavioural check on the reply-requested option of any inquiry (K2): `--upsert-inbox-inquiry ... --reply` sets `reply-requested: yes`,
## and marking the inquiry processed sends one note with the outcome to its requester, as `--request-update --reply` does for a librarian
## update request. Held, against temp stores only:
##   1. THE OPTION: an inquiry filed with --reply carries `reply-requested: yes`; one filed without it carries no such key.
##   2. THE BOUND: --reply is for an inquiry (inquiry-*): a note filed with --reply is refused, and nothing is written.
##   3. THE REPLY: marking a reply-requested inquiry processed files ONE note into the requester's inbox (from the member that processed
##      it, to the requester, saying it is processed, the request's name). Marking an inquiry filed without --reply files no note.
##   4. The reply note meets the note contract (the validator finds no row).
## Every call goes through one `env -i` whose child refuses to run outside this rig's mktemp tree; no Slack, no mail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInquiryReplyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/rig-other" "$rigSkills/magic-coordinator" "$rigData/inboxes/rig-member/incoming" "$rigData/inboxes/rig-member/processed" "$rigData/inboxes/rig-other/incoming" "$rigData/inboxes/rig-other/processed"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed text
	[ -f "$1" ] && LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigInc(){ printf '%s/inboxes/%s/incoming' "$rigData" "$1" ; }
rigNotes(){ ls "$( rigInc "$1" )" 2> /dev/null | LC_ALL=C grep -c '^note-' || : ; }
rigNoteName(){ ls "$( rigInc "$1" )" 2> /dev/null | LC_ALL=C grep '^note-.*-inquiry-reply-' | LC_ALL=C sed -n 1p ; }
rigValidateNote(){ ## file
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --intern-doc-validate inbox-item.note "$1"' rig "$1" 2> /dev/null | LC_ALL=C grep -c . || :
}
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}

echo "-- 1. the option --"
rigQ1=inquiry-20261021T0000Z-rig-ask.md
printf 'Please answer me.\n' | RIG_AGENT=rig-member rigOp "$rigTmp/r1" --upsert-inbox-inquiry rig-other "$rigQ1" --reply
rigAssert "a reply-requested inquiry is filed, the key is yes" "$( cat "$rigTmp/r1.rc" ):$( rigField "$( rigInc rig-other )/$rigQ1" reply-requested )" "0:yes"
rigQ2=inquiry-20261021T0001Z-rig-plain.md
printf 'No outcome wanted.\n' | RIG_AGENT=rig-member rigOp "$rigTmp/r2" --upsert-inbox-inquiry rig-other "$rigQ2"
rigAssert "an inquiry filed without --reply carries no reply-requested key" "$( cat "$rigTmp/r2.rc" ):$( rigField "$( rigInc rig-other )/$rigQ2" reply-requested )" "0:"

echo "-- 2. the bound --"
rigN1=note-20261021T0002Z-rig-note.md
printf 'a note\n' | RIG_AGENT=rig-member rigOp "$rigTmp/b1" --upsert-inbox-note rig-member "$rigN1" --reply
rigAssert "--reply is for an inquiry: a note is refused, nothing written" "$( cat "$rigTmp/b1.rc" ):$( [ -f "$( rigInc rig-member )/$rigN1" ] && echo written || echo absent ):$( rigHolds "$rigTmp/b1" '--reply is for an inquiry' )" "1:absent:yes"

echo "-- 3. the reply --"
RIG_AGENT=rig-other rigOp "$rigTmp/m1" --mark-inbox-processed rig-other "$rigQ1"
rigNote="$( rigNoteName rig-member )"
rigAssert "marking the reply-requested inquiry processed sends one note to the requester" "$( cat "$rigTmp/m1.rc" ):$( rigNotes rig-member ):$( [ -n "$rigNote" ] && echo one )" "0:1:one"
rigAssert "the note: from the member that processed it, to the requester, saying it is processed" "$( rigField "$( rigInc rig-member )/$rigNote" type ):$( rigField "$( rigInc rig-member )/$rigNote" from ):$( rigField "$( rigInc rig-member )/$rigNote" owner ):$( rigHolds "$( rigInc rig-member )/$rigNote" "# Note: your inquiry $rigQ1 is processed" )" "note:rig-other:rig-member:yes"
rigAssert "the note meets the note contract: the validator finds no row" "$( rigValidateNote "$( rigInc rig-member )/$rigNote" )" "0"
RIG_AGENT=rig-other rigOp "$rigTmp/m2" --mark-inbox-processed rig-other "$rigQ2"
rigAssert "marking an inquiry filed without --reply sends no note" "$( cat "$rigTmp/m2.rc" ):$( rigNotes rig-member )" "0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INQUIRY REPLY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INQUIRY_REPLY: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
