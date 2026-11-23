#!/usr/bin/env bash
## Behavioural check on the Knowledge lookup being advertised, in the served tool list and in the help page
## (DistroAgentsKnowledge.fn.sh, TeamKnowledge F7.3): every member knows the lookup exists, what it answers, and the
## call form to reach for instead of a hand search. Held, offline, over the tree MDLT_ORIGIN names:
##   1. the served tool list carries the lookup: the operation list a run is given names `--add-source-docs`, the word a
##      lookup call begins with, built by the same filter the harness builds it with
##   2. that word is one a call may begin with, as the gate asks it, so the served name is a call and not just text
##   3. the help page names the lookup and its call form in its own Summary, and does not call a bare call a query
##   4. a bare call really prints the syntax lines, which is why the page may not say otherwise
## Red before the fix: the served list named eight operations and not the lookup, and the Summary named no call form.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHelp="$rigPackage/sh-lib/help/Help.DistroAgentsKnowledge.help.md"
rigKnowledge="$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHelp" ] || rigRefuse "the Knowledge help page is not at the origin: $rigHelp"
[ -f "$rigKnowledge" ] || rigRefuse "the Knowledge tool is not at the origin: $rigKnowledge"
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigSays(){ ## text, fixed word -- yes where the text holds it at least once, no where it does not
	if printf '%s' "$1" | LC_ALL=C grep -q -F -e "$2" ; then printf yes ; else printf no ; fi
}
## The served list, built exactly as the harness builds it: the manual's syntax lines whose first word is an option, each
## once, joined by "; ". Copied from AgentsUniversalHarness.sh's own reader rather than re-invented, so the two agree.
rigServedList(){
	LC_ALL=C sed -n "s/^📘 syntax: DistroAgentsKnowledge\.fn\.sh \(--[a-z0-9-].*\)$/\1/p" "$rigHelp" \
		| LC_ALL=C grep -v '^--help' \
		| LC_ALL=C awk '!seen[$0]++ { out = out ( out == "" ? "" : "; " ) $0 ; } END { printf "%s", out ; }'
}

echo "-- 1. the served tool list carries the lookup --"
rigServed="$( rigServedList )" || rigRefuse "the served list could not be built from $rigHelp"
rigAssert "the served list names the word a lookup call begins with" "$( rigSays "$rigServed" '; --add-source-docs' )" yes
rigAssert "and it names the terms a lookup answers by" "$( rigSays "$rigServed" '--query-keyword' )" yes

echo "-- 2. that word is one a call may begin with, as the gate asks it --"
rigOpWord="$( . "$rigPackage/sh-lib/harness/AgentsContext.FrontTable.Help.include" && AgentsToolsFrontSyntaxLines DistroAgentsKnowledge --add-source-docs operation-word | LC_ALL=C grep -c . || : )"
rigAssert "the gate takes --add-source-docs as a word a Knowledge call begins with" "$( [ "${rigOpWord:-0}" -ge 1 ] && printf yes || printf no )" yes

echo "-- 3. the help page names the lookup and its call form, in its own Summary --"
rigSummary="$( LC_ALL=C awk '/^##  Summary:/ { inside = 1 ; next ; } /^##  / { inside = 0 ; } inside { print ; }' "$rigHelp" )" || rigSummary=""
rigAssert "the Summary names the sources a lookup call adds" "$( rigSays "$rigSummary" '--add-source-docs' )" yes
rigAssert "the Summary names the terms it answers by" "$( rigSays "$rigSummary" '--query-keyword' )" yes
rigAssert "the Summary calls the lookup by its own name" "$( rigSays "$( printf '%s' "$rigSummary" | LC_ALL=C tr 'A-Z' 'a-z' )" 'lookup' )" yes
rigAssert "the page no longer says a bare call is a query" \
	"$( LC_ALL=C grep -q -F -e 'bare call' "$rigHelp" && printf says-so || printf silent )" silent

echo "-- 4. a bare call really prints the syntax lines --"
rigPyDir="$( dirname "$( command -v python3 )" )"
rigBare="$( cd "$rigOrigin" && env -i HOME="$rigOrigin" PATH="$rigPyDir:/usr/bin:/bin" MMDAPP="${MMDAPP:-$rigOrigin}" \
	MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" bash "$rigKnowledge" 2>&1 || : )"
rigAssert "a bare call prints syntax lines, and no answer" \
	"$( printf '%s' "$rigBare" | LC_ALL=C grep -c -F -e '📘 syntax:' || : ):$( printf '%s' "$rigBare" | LC_ALL=C grep -c -F -e 'answered from' || : )" "7:0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE LOOKUP ADVERTISED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  fix:  the Knowledge syntax line and Summary in sh-lib/help/Help.DistroAgentsKnowledge.help.md"
	exit 1
fi
echo "KNOWLEDGE_LOOKUP_ADVERTISED: OK ($rigPasses assertions, offline)"
