#!/usr/bin/env bash
## The poster of a question never answers it (AgentsSlackThreadAnswers.awk): the example reactions its own account places on the question, and a
## reply under its own account and sender, answer nothing, even where that account is among the accounts that answer. A reply another member
## sends through the same team account still answers. The rows are Q224's real thread on MDV, D0C4XUKBBQE:1794983971.392339, in the shape the
## formatter prints. Offline: awk over fixed text.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
[ -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" ] && [ -f "$rigHere/questions/AgentsEscalationVerdict.awk" ] || { echo "⛔ ERROR: the readers are not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigRoot(){ ## reactions annotations -- Q224's own post, with those reactions on it
	printf '1794985734.592889 | U0C4JFNT4Q7 | %s [sender: magic-devops] :hammer_and_pick: *_magic-devops_* @nine5s (work-duty) → :mouse: *_magic-coordinator_* <@U0BSXNNF9FV>. # :question: Question Q224  **:pushpin: About** magic-devops, work-duty (12fbbdd4)\n' "$1"
}
rigVerdict(){ ## reactions annotations, the reply lines after the root -- the verdict and its author, read with the team account among those that answer
	{ rigRoot "$1" ; printf '%s' "$2" ; } \
		| LC_ALL=C awk -v rootTs=1794985734.592889 -v askingUsers="" -v fromUsers="U0KGBC75G U0C4JFNT4Q7 magic-coordinator" -v tag="" -v threadCount=1 -v others="" \
			-f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" 2> /dev/null \
		| MDAT_VERDICT_KIND=question MDAT_VERDICT_SELECT=one MDAT_VERDICT_OPTIONS=$'run — reclaim space then install/updates on the six hosts, read back from each\nhold — no host is touched, and the six stay as they read' \
			MDAT_VERDICT_AUTHORS="U0KGBC75G U0C4JFNT4Q7 magic-coordinator" MDAT_VERDICT_ASKING="" LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" 2> /dev/null | head -1 | LC_ALL=C cut -f1-2
}
echo "-- 1. the asker's own example reaction on Q224 answers nothing --"
rigAssert "a lone example 'one' by the posting account is no verdict" "$( rigVerdict '[reactions: one x1 (U0C4JFNT4Q7)]' '' )" "RETURNED	"
rigAssert "control: the owner's 'two' beside the examples is his answer, credited to him" \
	"$( rigVerdict '[reactions: one x1 (U0C4JFNT4Q7)] [reactions: two x2 (U0C4JFNT4Q7,U0KGBC75G)]' '' )" "hold	U0KGBC75G"
echo "-- 2. a reply under the poster's account and sender answers nothing --"
rigAssert "the asker's own '1' through the team account is no answer" "$( rigVerdict '' '1794990000.000001 | U0C4JFNT4Q7 | [sender: magic-devops] 1'$'\n' )" "RETURNED	"
echo "-- 3. control: another member's reply through the same team account still answers --"
rigAssert "magic-coordinator's 'hold' through the team account is the answer" "$( rigVerdict '' '1794990000.000002 | U0C4JFNT4Q7 | [sender: magic-coordinator] hold'$'\n' )" "hold	U0C4JFNT4Q7"
if [ "$rigFailCount" -ne 0 ] ; then echo "⛔ ASK POSTER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1 ; fi
printf 'ASK_POSTER: OK (%d assertions, offline)\n' "$rigPassCount"
