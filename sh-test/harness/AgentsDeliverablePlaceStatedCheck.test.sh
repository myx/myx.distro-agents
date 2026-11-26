#!/usr/bin/env bash
## Behavioural check on S6.31's closing check in the form the coordinator ruled: the requirement is stated in the
## tooling's own words and nothing is refused, because the shape a member writes is a name still unapproved. Held:
##   1. the handback tool tells its caller to name each declared deliverable with where it landed, in the
##      `<place>:<path>` shape the apply gate already reads
##   2. the report template's contract carries that same rule for the deliverable block
##   3. control: the tool declares no such requirement for a field it does not take, so the sentence is the rule's
##      own and not a phrase every declaration carries
##   4. control: the two sites are one wording, so a drift between them is a failure
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="${MDLT_ORIGIN}/myx/myx.distro-agents/sh-lib"
rigWire="$rigHere/harness/AgentsOpenAiChatWire.sh"
rigTemplate="$rigHere/templates/report.post.format.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigWire" ] || rigRefuse "the wire declarations are absent at $rigWire"
[ -f "$rigTemplate" ] || rigRefuse "the report template is absent at $rigTemplate"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRule="Each deliverable your routine declares is named in the outcome or the findings, with where it landed as <place>:<path>."

echo "-- 1. the handback tool states the requirement --"
rigAssert "the handback declaration carries the rule" "$( LC_ALL=C grep -c -F "$rigRule" "$rigWire" )" "1"
rigAssert "and it sits in the SubagentHandback declaration, not another tool's" \
	"$( LC_ALL=C grep -c "\"name\":\"SubagentHandback\".*Each deliverable your routine declares" "$rigWire" )" "1"

echo "-- 2. the report template's contract carries the same rule --"
rigAssert "the template names where a deliverable landed" "$( LC_ALL=C grep -c -F 'with where it landed as `<place>:<path>`' "$rigTemplate" )" "1"
rigAssert "and says the tooling states it and checks nothing yet" "$( LC_ALL=C grep -c -F 'The tooling states the rule and checks nothing yet' "$rigTemplate" )" "1"

echo "-- 3. controls: the sentence is the rule's own --"
rigAssert "control: another tool's declaration does not carry it" \
	"$( LC_ALL=C awk '/"name":"SubagentHandback"/ { next ; } /Each deliverable your routine declares/ { n++ } END { print n + 0 ; }' "$rigWire" )" "0"
rigAssert "control: the same pattern finds a phrase every declaration carries" \
	"$( LC_ALL=C grep -c -F 'A failure returns ERROR.' "$rigWire" )" "5"

echo "-- 4. control: the two sites say one thing --"
rigAssert "the wire's shape and the template's shape are the same words" \
	"$( LC_ALL=C grep -o -F '<place>:<path>' "$rigWire" | LC_ALL=C grep -c . ):$( LC_ALL=C grep -o -F '<place>:<path>' "$rigTemplate" | LC_ALL=C grep -c . )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DELIVERABLE PLACE STATED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DELIVERABLE_PLACE_STATED: OK (%d assertions, offline)\n' "$rigPassCount"
