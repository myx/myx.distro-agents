#!/usr/bin/env bash
## AgentsOutputStylePredicatesCheck -- the predicates of the plain-language output floor, each on one sentence
## that fires it and one that does not (AgentsOutputStyleCheck.awk; epic S10.27 for the two produce-rule ones).
## Guards: word-cap fires on 26 words and not on 25; semicolon fires on one and not on a colon; attribution
## fires on `His ruling` and on `she said`, and not on a member's name or on the human-owner's title; session-id
## fires on a UUID and not on a short hex word; the relay group measures nothing; `textGroup=help` names every
## predicate measured. One fault line per predicate per sentence, the predicate's name first on the line.
## Red: a predicate dropped from the awk fails its `fires` row; one widened fails its `passes` row.
## Offline: a temp folder of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsOutputStyleCheck.awk"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsOutputStylePredicatesCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigFaults(){ ## group, text -- the predicate names that fired, space-joined
	printf '%s\n' "$2" | LC_ALL=C awk -v textGroup="$1" -f "$rigAwk" 2> /dev/null | LC_ALL=C cut -f1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigLong="one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty one two three four five"

echo "-- 1. the caps --"
rigAssert "word-cap fires on 26 words"                     "$( rigFaults report "$rigLong six." )" "word-cap"
rigAssert "and not on 25"                                  "$( rigFaults report "$rigLong." )" ""
rigAssert "semicolon fires on one"                         "$( rigFaults report "The gate reads the record; the record stands." )" "semicolon"
rigAssert "and not on a colon"                             "$( rigFaults report "The gate reads the record: the record stands." )" ""

echo "-- 2. the produce rule: no person's ruling, no session id --"
rigAssert "attribution fires on a possessive"              "$( rigFaults report "His ruling closed the question." )" "attribution"
rigAssert "and on a pronoun before said"                   "$( rigFaults message "Then she said the rig may stay." )" "attribution"
rigAssert "a member's name is no person"                   "$( rigFaults report "magic-tester's verdict stands, and the human-owner's answer is recorded." )" ""
rigAssert "a word that only starts with his is no pronoun" "$( rigFaults report "The history said nothing of the kind." )" ""
rigAssert "session-id fires on a UUID"                     "$( rigFaults brief "The run d3e0b482-9b84-4594-b681-c8b0e0ec0388 ended well." )" "session-id"
rigAssert "and not on a short hex word"                    "$( rigFaults brief "The commit d3e0b482 ended well." )" ""
rigAssert "two faults in one sentence are two lines"       "$( rigFaults report "His ruling on run d3e0b482-9b84-4594-b681-c8b0e0ec0388 stands." )" "attribution session-id"

echo "-- 3. the relay group and the help --"
rigAssert "relay measures nothing"                         "$( rigFaults relay "His ruling; d3e0b482-9b84-4594-b681-c8b0e0ec0388 and $rigLong six." )" ""
rigAssert "help names every predicate measured"            "$( LC_ALL=C awk -v textGroup=help -f "$rigAwk" < /dev/null 2> /dev/null | LC_ALL=C grep -c -e 'a sentence over' -e 'a semicolon' -e 'attributed to a person' -e 'a session id' )" "4"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ OUTPUT STYLE PREDICATES CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: a predicate of the plain-language floor fires wrong, or is gone" >&2
	echo "  fix:  sh-lib/comms/AgentsOutputStyleCheck.awk, and its help text" >&2
	exit 1
fi
echo "OUTPUT_STYLE_PREDICATES: OK ($rigPass assertions, offline)"
