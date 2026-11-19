#!/usr/bin/env bash
## The verdict reader's click table read both ways (AgentsEscalationVerdict.awk): a click gives its verdict, and
## MDAT_VERDICT_CHOSEN gives back the emoji of that verdict, so a close keeps the chosen option's emoji and takes off
## the others. Held: for each kind, the chosen verdict names exactly its own emoji; a numbered option names its
## number, a selection of several every number it names; the words after a verdict change nothing; and the mode
## reads no input at all. Offline: awk over fixed text.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsEscalationVerdict.awk"
[ -f "$rigAwk" ] || { echo "⛔ ERROR: the verdict reader is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigChosen(){ ## kind, chosen verdict, answer form (may be empty), options (may be empty) -- the emoji named, space separated
	printf '1.000001 | UREADER | %s\n' "${2%% *}" | MDAT_VERDICT_CHOSEN="$2" MDAT_VERDICT_KIND="$1" MDAT_VERDICT_SELECT="${3:-}" MDAT_VERDICT_OPTIONS="${4:-}" MDAT_VERDICT_AUTHORS="UREADER" \
		LC_ALL=C awk -f "$rigAwk" 2> /dev/null | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigClicked(){ ## kind, emoji name, answer form (may be empty), options (may be empty) -- the verdict that click gives
	printf 'reaction on the question: [reactions: %s x1 (UREADER)]\n' "$2" | MDAT_VERDICT_KIND="$1" MDAT_VERDICT_SELECT="${3:-}" MDAT_VERDICT_OPTIONS="${4:-}" MDAT_VERDICT_AUTHORS="UREADER" \
		LC_ALL=C awk -f "$rigAwk" 2> /dev/null | LC_ALL=C cut -f1
}
rigOptions=$'resume: start it again from the context it kept\nfresh: start it again from its brief\nclose: leave it ended\nkill: end what still lives of its session'
echo "-- 1. the chosen verdict names its own emoji, and no other --"
rigAssert "a change approved: the three that approve, never the cross" "$( rigChosen change approve )" "+1 thumbsup white_check_mark"
rigAssert "a change rejected: the cross alone" "$( rigChosen change reject )" "x"
rigAssert "a proposal approved, and rejected" "$( rigChosen proposal approved ):$( rigChosen proposal rejected )" "white_check_mark:x"
rigAssert "a review returned" "$( rigChosen review return )" "leftwards_arrow_with_hook"
rigAssert "an undo reworked, and accepted" "$( rigChosen undo rework ):$( rigChosen undo accept )" "leftwards_arrow_with_hook:+1 thumbsup"
rigAssert "a permission allowed for the session, and a set allowed" "$( rigChosen permission allow-session ):$( rigChosen permission-set allow-set )" "repeat:unlock"
rigAssert "a readback confirmed takes every affirmation, and one stopped the cross" "$( rigChosen readback yes ):$( rigChosen readback no )" "+1 thumbsup ok_hand white_check_mark:x"
rigAssert "a yes-no question reads as a readback does" "$( rigChosen question no yes-no )" "x"
echo "-- 2. numbered options, and the words after a verdict --"
rigAssert "a decision answered fresh, with his words after it: its number alone" "$( rigChosen decision 'fresh -- from the brief, please' '' "$rigOptions" )" "two"
rigAssert "a selection of several: every number it names, in option order" "$( rigChosen question 'resume close' many "$rigOptions" )" "one three"
rigAssert "an edit given by reply has no emoji: nothing is named" "[$( rigChosen permission-set edit )]" "[]"
echo "-- 3. one table both ways: each click gives the verdict whose emoji it is named by --"
rigBoth=""
for rigRow in change:x change:+1 change:white_check_mark proposal:x proposal:white_check_mark review:+1 review:leftwards_arrow_with_hook review:x undo:leftwards_arrow_with_hook permission-set:unlock permission:one permission:repeat readback:ok_hand readback:x ; do
	rigKind="${rigRow%%:*}" ; rigName="${rigRow#*:}"
	rigGiven="$( rigClicked "$rigKind" "$rigName" )"
	case " $( rigChosen "$rigKind" "$rigGiven" ) " in *" $rigName "*) ;; *) rigBoth="$rigBoth $rigRow=>$rigGiven" ;; esac
done
rigAssert "for every click row, the verdict it gives names that emoji back" "[$rigBoth]" "[]"
rigAssert "control: a click no row holds gives no verdict" "$( rigClicked change rocket )" "RETURNED"
echo "-- 4. the mode reads no input --"
rigAssert "a reply that would be a verdict is not read: the output is the emoji names alone" "$( rigChosen change reject | LC_ALL=C grep -c -e RETURNED -e reject )" "0"

if [ "$rigFailCount" -ne 0 ] ; then echo "⛔ VERDICT CHOSEN EMOJI CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1 ; fi
printf 'VERDICT_CHOSEN_EMOJI: OK (%d assertions, offline)\n' "$rigPassCount"
