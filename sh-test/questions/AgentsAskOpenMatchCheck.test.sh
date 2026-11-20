#!/usr/bin/env bash
## A reply with no question number in a thread several asks share (AgentsSlackThreadAnswers.awk) answers an ask only where no other stood
## open there when it came. Where several did, no ask takes it, and the reader that asks (-v whichMark=1) gets its head marked once as
## AMBIGUOUS-REPLY, so the tooling asks its author which one it answers. Who answers an ask: never the account that posted it,
## a member on that account only in text, and the human-owner's own account always. Offline: awk over fixed text.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
[ -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" ] || { echo "⛔ ERROR: the renderer is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
## The thread: Q1 posted, then Q2, then his reply `yes`, with no number. Both posted by the team account for one member.
rigThread=$'1700000100.000001 | UBOT | [sender: rig-member] # :question: Question Q1\n1700000100.000002 | UBOT | [sender: rig-member] # :question: Question Q2\n1700000100.000003 | UOWNER | yes\n'
rigRender(){ ## root ts, tag, others, [whichMark] -- the lines the renderer gives that ask's reader
	printf '%s' "$rigThread" | LC_ALL=C awk -v rootTs="$1" -v tag="$2" -v threadCount=2 -v others="$3" -v whichMark="${4:-}" -v askingUsers="" -v fromUsers="UOWNER" \
		-f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" 2> /dev/null
}
echo "-- 1. two asks open when he replied: neither takes the reply --"
rigAssert "Q2, the later one, does not take it" "$( rigRender 1700000100.000002 Q2 '1700000100.000001/open' | LC_ALL=C grep -c '^1700000100.000003 | UOWNER | yes' )" 0
rigAssert "for the reader that asks, its head is marked once as AMBIGUOUS-REPLY" "$( rigRender 1700000100.000002 Q2 '1700000100.000001/open' 1 | LC_ALL=C grep -c '^AMBIGUOUS-REPLY 1700000100.000003 | UOWNER | yes' )" 1
rigAssert "Q1, the earlier one, does not take it either" "$( rigRender 1700000100.000001 Q1 '1700000100.000002/open' | LC_ALL=C grep -c '^1700000100.000003 | UOWNER | yes' )" 0
echo "-- 2. one ask open when he replied: it takes the reply --"
rigAssert "Q1, the only one open, Q2 closed before the reply, takes it" "$( rigRender 1700000100.000001 Q1 '1700000100.000002/1700000099' | LC_ALL=C grep -c '^1700000100.000003 | UOWNER | yes' )" 1
rigAssert "control: an ask alone in its thread takes it" "$( printf '%s' "$rigThread" | LC_ALL=C awk -v rootTs=1700000100.000002 -v tag=Q2 -v threadCount=1 -v others="" -v askingUsers="" -v fromUsers="UOWNER" -f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" 2> /dev/null | LC_ALL=C grep -c '^1700000100.000003 | UOWNER | yes' )" 1
echo "-- 3. the human-owner's own reply answers an ask addressed to a member: Q224, addressed to magic-coordinator, on its real thread --"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAskOpenMatchCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/agents/cache" && printf '%s\n' 'human-owner=U0KGBC75G=-=-=-=-' 'magic-coordinator=U0BSXNNF9FV=-=-=-=-' > "$rigTmp/ws/.local/agents/cache/slack-identities.cache"
rigAuthors="$( env -i MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" PATH="/usr/bin:/bin" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.AskThread.include" > /dev/null 2>&1 ; AgentsToolsAskAnsweringAccountsInto rigOut U0BSXNNF9FV 2> /dev/null ; printf "%s" "${rigOut:-U0BSXNNF9FV}"' )"
rigAssert "the accounts that answer Q224: its addressee, then the human-owner" "$rigAuthors" "U0BSXNNF9FV U0KGBC75G"
rigQ224=$'1794985734.592889 | U0C4JFNT4Q7 | [reactions: one x1 (U0C4JFNT4Q7)] [reactions: two x1 (U0C4JFNT4Q7)] [sender: magic-devops] :hammer_and_pick: *_magic-devops_* @nine5s (work-duty) → :mouse: *_magic-coordinator_* <@U0BSXNNF9FV>. # :question: Question Q224\n1795002000.000001 | U0KGBC75G | hold\n'
rigAssert "his plain 'hold' on Q224's thread is its answer, by him" \
	"$( printf '%s' "$rigQ224" | LC_ALL=C awk -v rootTs=1794985734.592889 -v askingUsers="U0C4JFNT4Q7" -v fromUsers="$rigAuthors" -v tag="" -v threadCount=1 -v others="" \
		-f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" 2> /dev/null \
		| MDAT_VERDICT_KIND=question MDAT_VERDICT_SELECT=one MDAT_VERDICT_OPTIONS=$'run — reclaim space then install/updates on the six hosts, read back from each\nhold — no host is touched, and the six stay as they read' \
			MDAT_VERDICT_AUTHORS="$rigAuthors" MDAT_VERDICT_ASKING="U0C4JFNT4Q7" LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" 2> /dev/null | head -1 | LC_ALL=C cut -f1-2 )" "hold	U0KGBC75G"
echo "-- 4. who answers an ask: Q7, posted by the team bot for magic-devops, addressed to rig-member, which has no account of its own --"
rigOptions=$'run — the hosts are touched\nhold — no host is touched'
rigWho(){ ## the thread -- the verdict and its author the readers give Q7, `-` where none
	printf '%s' "$1" | LC_ALL=C awk -v rootTs=1700000200.000001 -v askingUsers="UBOT" -v fromUsers="rig-member UOWNER" -v tag="Q7" -v threadCount=1 -v others="" \
		-f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/slack/AgentsSlackThreadAnswers.awk" 2> /dev/null \
		| MDAT_VERDICT_KIND=question MDAT_VERDICT_SELECT=one MDAT_VERDICT_OPTIONS="$rigOptions" MDAT_VERDICT_AUTHORS="rig-member UOWNER" MDAT_VERDICT_ASKING="UBOT" \
			LC_ALL=C awk -f "$rigHere/questions/AgentsEscalationVerdict.awk" 2> /dev/null | LC_ALL=C awk -F'\t' '$1 != "" && $1 != "RETURNED" { print $1 "/" $2 ; found = 1 ; exit ; } END { if ( ! found ) print "-" ; }'
}
rigRoot='1700000200.000001 | UBOT | [reactions: one x1 (UBOT)] [reactions: two x1 (UBOT)] [sender: magic-devops] # :question: Question Q7'
rigAssert "the account that posted the ask never answers it: the option emoji it placed, one and two, are no verdict" "$( rigWho "$rigRoot"$'\n' )" "-"
rigAssert "a member on the poster's account answers only in text, Q7: and its option: its click is the poster's own and no verdict, its reply is the verdict, by it" \
	"$( rigWho "$rigRoot"$'\n' ):$( rigWho "$rigRoot"$'\n1700000200.000002 | UBOT | [sender: rig-member] Q7: hold\n' )" "-:hold/rig-member"
rigAssert "the human-owner's own account answers: his click on two, and his reply" \
	"$( rigWho '1700000200.000001 | UBOT | [reactions: one x1 (UBOT)] [reactions: two x2 (UBOT,UOWNER)] [sender: magic-devops] # :question: Question Q7'$'\n' ):$( rigWho "$rigRoot"$'\n1700000200.000003 | UOWNER | run\n' )" "hold/UOWNER:run/UOWNER"

if [ "$rigFailCount" -ne 0 ] ; then echo "⛔ ASK OPEN MATCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1 ; fi
printf 'ASK_OPEN_MATCH: OK (%d assertions, offline)\n' "$rigPassCount"
