#!/usr/bin/env bash
## Gate on the size of the split files (epic 20261026-refactorings, S28.1). A line count is a gate and never the measure of the split: the
## isolation checks (AgentsSlackPathIsolationCheck, AgentsWaitPathIsolationCheck) measure what a call parses, and this check only refuses a
## file that has grown back into the size the split removed. Held, run and not read:
##   1. THE ROUTER. sh-lib/comms/AgentsTools.MemberCommsSlack.include is at most 150 lines (the brief said 120, Q126: see rigRouterLimit below), and holds the body of no operation: no Slack API
##      method an operation asks (chat.postMessage, reactions.add, chat.delete, chat.update, files.getUploadURLExternal, search.messages,
##      conversations.history, files.info) is written in it.
##   2. THE FAMILY. Every sh-lib/comms/AgentsTools.MemberCommsSlack*.include is at most 1500 lines.
##   3. THE WAIT. Every sh-lib/member/AgentsTools.MemberWait*.include is at most 1500 lines.
##   4. THE INSTRUMENT. The counter is run on files made by hand: one of exactly the limit, one a line over, one with no newline at its end,
##      and an empty one. The verb reader is run on a file that holds a method and one that does not; and the control of section 1: each
##      method is found in some include of the family, so a reader that found none would be no reader.
## Red recipe: on the files of before the split the router is 3173 lines and writes all eight methods, and the wait include is 3989 lines.
## Controls on the same files: the presence, profile and socket includes (148, 580 and 143 lines) pass section 2.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

## THE NAMES AND THE LIMITS: one block.
rigPackageRel="myx/myx.distro-agents"
rigRouter="${RIG_SLACK_ROUTER:-AgentsTools.MemberCommsSlack.include}"
## The globs of the family (the router and the operation includes) and of the wait, in sh-lib/comms and sh-lib/member. RIG_SLACK_GLOBS and RIG_WAIT_GLOBS change them.
## The router limit of 150 is taken as ruled on the build owner's word, with magic-architect and keeper-myx accepting the built shape, and is open to the
## magic-coordinator's overrule (Q126, the brief said 120). RIG_ROUTER_LIMIT=120 holds the brief's.
rigSlackGlobs="${RIG_SLACK_GLOBS:-AgentsTools.MemberCommsSlack*.include AgentsTools.InternOpCommsSlack*.include}"
rigWaitGlobs="${RIG_WAIT_GLOBS:-AgentsTools.MemberWait*.include}"
rigRouterLimit="${RIG_ROUTER_LIMIT:-150}"
rigFileLimit=1500
rigVerbs="chat.postMessage reactions.add chat.delete chat.update files.getUploadURLExternal search.messages conversations.history files.info"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
[ -f "$rigPackage/sh-lib/comms/$rigRouter" ] || rigRefuse "no router at the origin this workspace resolves: $rigPackage/sh-lib/comms/$rigRouter"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSplitSizeGateCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigLines(){ ## file -- its lines, a last line with no newline counted
	LC_ALL=C awk 'END { print NR ; }' "$1"
}
rigWithin(){ ## file, limit -- `within`, or the lines it has
	local withinCount
	withinCount="$( rigLines "$1" )"
	if [ "$withinCount" -le "$2" ] ; then printf within ; else printf '%s lines' "$withinCount" ; fi
}
rigVerbsIn(){ ## file -- the methods of the list it writes in code (a comment line is no arm), in a line
	local verbName verbCode
	verbCode="$( LC_ALL=C grep -v '^[[:space:]]*#' "$1" || : )"
	for verbName in $rigVerbs ; do
		case "$verbCode" in *"$verbName"*) printf '%s ' "$verbName" ;; esac
	done
	return 0
}

echo "-- 4. the instrument: the counter and the verb reader on files made by hand --"
LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 1500 ; i++ ) print "x" ; }' > "$rigTmp/at-limit.txt"
LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 1501 ; i++ ) print "x" ; }' > "$rigTmp/over-limit.txt"
printf 'one\ntwo' > "$rigTmp/no-newline.txt"
: > "$rigTmp/empty.txt"
printf 'a\nreactions.add\nb\n' > "$rigTmp/has-verb.txt"
printf 'a\nreactions\nb\n' > "$rigTmp/no-verb.txt"
printf 'a\n\t# reactions.add is said in a comment\nb\n' > "$rigTmp/comment-verb.txt"
rigAssert "counter: a file of exactly the limit is within it" "$( rigWithin "$rigTmp/at-limit.txt" 1500 )" within
rigAssert "counter: a file a line over the limit is named, with its lines" "$( rigWithin "$rigTmp/over-limit.txt" 1500 )" "1501 lines"
rigAssert "counter: a last line with no newline is counted" "$( rigLines "$rigTmp/no-newline.txt" )" 2
rigAssert "counter: an empty file has no line" "$( rigLines "$rigTmp/empty.txt" )" 0
rigAssert "verb reader: a file that writes a method names it" "$( rigVerbsIn "$rigTmp/has-verb.txt" )" "reactions.add "
rigAssert "verb reader: a file that only has part of the name names none" "$( rigVerbsIn "$rigTmp/no-verb.txt" )" ""
rigAssert "verb reader: a method named in a comment line is no arm" "$( rigVerbsIn "$rigTmp/comment-verb.txt" )" ""

echo "-- 1. the router --"
rigAssert "the router is at most $rigRouterLimit lines" "$( rigWithin "$rigPackage/sh-lib/comms/$rigRouter" "$rigRouterLimit" )" within
rigAssert "the router writes no Slack API method an operation asks" "$( rigVerbsIn "$rigPackage/sh-lib/comms/$rigRouter" )" ""
rigFamilyVerbs="$( for rigGlob in $rigSlackGlobs ; do for rigFile in "$rigPackage"/sh-lib/comms/$rigGlob ; do [ -f "$rigFile" ] && rigVerbsIn "$rigFile" ; done ; done | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk 'NF' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"
rigAssert "control: each of those methods is written in some include of the family, so the reader can find them" \
	"$( printf '%s\n' $rigFamilyVerbs | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "$( printf '%s\n' $rigVerbs | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )"

echo "-- 2. every include of the Slack family --"
rigSeen=0
for rigGlob in $rigSlackGlobs ; do
	for rigFile in "$rigPackage"/sh-lib/comms/$rigGlob ; do
		[ -f "$rigFile" ] || continue
		rigSeen=$(( rigSeen + 1 ))
		rigAssert "${rigFile##*/} is at most $rigFileLimit lines" "$( rigWithin "$rigFile" "$rigFileLimit" )" within
	done
done
rigAssert "control: the family glob found files, the router among them" "$( [ "$rigSeen" -ge 1 ] && [ -f "$rigPackage/sh-lib/comms/$rigRouter" ] && printf found || printf none )" found

echo "-- 3. every include of the Wait --"
rigSeen=0
for rigGlob in $rigWaitGlobs ; do
	for rigFile in "$rigPackage"/sh-lib/member/$rigGlob ; do
		[ -f "$rigFile" ] || continue
		rigSeen=$(( rigSeen + 1 ))
		rigAssert "${rigFile##*/} is at most $rigFileLimit lines" "$( rigWithin "$rigFile" "$rigFileLimit" )" within
	done
done
rigAssert "control: the wait glob found files, the arm among them" "$( [ "$rigSeen" -ge 1 ] && [ -f "$rigPackage/sh-lib/member/AgentsTools.MemberWait.include" ] && printf found || printf none )" found

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPLIT SIZE GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPLIT_SIZE_GATE: OK (%d assertions, offline)\n' "$rigPassCount"
