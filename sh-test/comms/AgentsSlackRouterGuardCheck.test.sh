#!/usr/bin/env bash
## Behavioural check on the arms of the member Slack router, AgentsTools.MemberCommsSlack.include. An arm whose whole
## body is one include load and one `return $?` hands its call to that include, so that load must run on every call. A
## load that shares its command with a test, such as `type <F> > /dev/null 2>&1 || . <file>`, runs only while that test
## fails. The first call of a process defines <F>, so later calls skip the include, and the arm returns the test's
## status: 0, having done nothing. Such an arm is a fault here.
## Held, run and not read:
##   1. THE ROUTER. No arm of it, at any case depth, has a body of one conditionally loaded include and its return.
##      An arm holding any other statement is no fault: the file-info arms of the two stubs load behind a test and call
##      their function in the same command, so they run either way.
##   2. THE INSTRUMENT. The reader on include files made by hand: a bare single-load arm, a guarded one, a guarded
##      inline one whose load sits on the label's own line, a guarded arm that calls its symbol after its load inside
##      a stub, an arm of several statements behind a guard, a load behind a `[ -f ] &&` test, and a file that is no
##      router. Each fixture is asserted beside the arm census the reader read, so a reader that never reached its
##      subject, or that lost case depth, fails there instead of passing here.
## Red recipe: on a router whose profile and search arms guard their load, section 1 fails naming those two arms, and
## section 2 passes. Offline: it reads files, and writes only inside its own rig folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigRouterName="AgentsTools.MemberCommsSlack.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigRouter="$MDLT_ORIGIN/$rigPackageRel/sh-lib/slack/$rigRouterName"
[ -f "$rigRouter" ] || rigRefuse "no $rigRouterName at the origin this workspace resolves: $MDLT_ORIGIN/$rigPackageRel/sh-lib/slack"
. "$MDLT_ORIGIN/$rigPackageRel/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackRouterGuardCheck )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] && echo "kept: $rigTmp" || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT

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

## The reader: one awk pass over an include file, tracking how deep in `case ... in` each line sits. An arm belongs to
## the depth it opens at, so an arm inside a stub is that stub's own body and never a top-level arm. An arm's body is
## read the same whether it starts on the label's own line or on the line after it, and is cut into statements at each
## `;`. A statement is a bare load, a load the statement can skip by standing it behind a test (`||`, `&&`), the arm's
## own `return $?`, or something else. An arm is a fault when its statements are one skippable load and one
## `return $?`, and nothing else. One line comes out per arm: `fault` or `ok`, the depth it opened at, and its label.
rigScan(){ ## include file
	LC_ALL=C awk '
		function closeArm(atDepth,   labelText) {
			labelText = labelAt[atDepth] ; labelAt[atDepth] = ""
			if ( atDepth < 1 ) { return ; }
			if ( loadAt[atDepth] == 1 && retAt[atDepth] == 1 && otherAt[atDepth] == 0 && skipGuardAt[atDepth] == 1 ) {
				printf "fault %d %s\n", atDepth, labelText ; return
			}
			printf "ok %d %s\n", atDepth, labelText
		}
		function judgePiece(atDepth, pieceText) {
			gsub(/^[ \t]+|[ \t]+$/, "", pieceText)
			if ( pieceText == "" ) { return ; }
			if ( pieceText == "return $?" ) { retAt[atDepth]++ ; return ; }
			if ( pieceText ~ /^\.[ \t]/ ) { loadAt[atDepth]++ ; return ; }
			if ( pieceText ~ /(\|\||&&)[ \t]*(\{[ \t]*)?\.[ \t]/ ) { loadAt[atDepth]++ ; skipGuardAt[atDepth] = 1 ; return ; }
			otherAt[atDepth]++
		}
		function armBody(atDepth, bodyText,   closesHere, pieceCount, pieceAt, pieceTexts) {
			sub(/^[ \t]+/, "", bodyText)
			closesHere = 0
			if ( bodyText ~ /^;;[ \t]*$/ ) { closeArm(atDepth) ; return ; }
			if ( bodyText ~ /;;[ \t]*$/ ) { closesHere = 1 ; sub(/;;[ \t]*$/, "", bodyText) ; }
			pieceCount = split(bodyText, pieceTexts, ";")
			for ( pieceAt = 1 ; pieceAt <= pieceCount ; pieceAt++ ) { judgePiece(atDepth, pieceTexts[pieceAt]) ; }
			if ( closesHere == 1 ) { closeArm(atDepth) ; }
		}
		{
			lineText = $0
			sub(/[ \t]+$/, "", lineText)
			if ( lineText ~ /^[ \t]*$/ ) { next ; }
			if ( lineText ~ /^[ \t]*#/ ) { next ; }
			if ( lineText ~ /^[ \t]*case[ \t]/ ) {
				if ( labelAt[depth] != "" ) { otherAt[depth]++ ; }
				depth++
				next
			}
			if ( lineText ~ /^[ \t]*esac[ \t]*$/ ) {
				if ( labelAt[depth] != "" ) { closeArm(depth) ; }
				depth--
				if ( depth < 0 ) { depth = 0 ; }
				next
			}
			if ( depth < 1 ) { next ; }
			if ( labelAt[depth] == "" && match(lineText, /^[ \t]*[^) \t][^)]*\)/) ) {
				armLabel = substr(lineText, 1, RLENGTH)
				sub(/^[ \t]*/, "", armLabel)
				sub(/\)$/, "", armLabel)
				labelAt[depth] = armLabel
				loadAt[depth] = 0 ; retAt[depth] = 0 ; otherAt[depth] = 0 ; skipGuardAt[depth] = 0
				armBody(depth, substr(lineText, RLENGTH + 1))
				next
			}
			if ( labelAt[depth] != "" ) { armBody(depth, lineText) ; }
		}
		END { if ( labelAt[depth] != "" ) { closeArm(depth) ; } ; }
	' "$1"
}

rigArmLine(){ ## scan output, arm label, depth -- the one line the reader gave that arm
	printf '%s\n' "$1" | LC_ALL=C awk -v wantLabel="$2" -v wantDepth="$3" '$3 == wantLabel && $2 == wantDepth { print ; found = 1 ; } END { if ( found != 1 ) { print "absent" ; } ; }'
}

echo "-- 2. the instrument: the reader on include files made by hand --"
printf 'case "$1" in\n\t--intern-op-rig-bare)\n\t\t. "$MDLT_ORIGIN/rig/bare.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-bare.include"
printf 'case "$1" in\n\t--intern-op-rig-guarded)\n\t\ttype rigArmGuardProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/rig/guarded.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-guarded.include"
printf 'case "$1" in\n\t--intern-op-rig-inline) type rigArmGuardProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/rig/inline.include" ; return $? ;;\nesac\n' > "$rigTmp/rig-inline.include"
printf 'case "$1" in\n\t--rig-member-stub)\n\t\tcase "$1" in\n\t\t\t--rig-file-info) type rigArmGuardProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/rig/file-info.include" ; rigArmFileInfo "${@:2}" ; return $? ;;\n\t\tesac\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-stub-call.include"
printf 'case "$1" in\n\t--intern-op-rig-several)\n\t\ttype rigArmGuardProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/rig/several.include"\n\t\trigArmProbe "${@:2}"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-several.include"
printf 'case "$1" in\n\t--intern-op-rig-test-file)\n\t\t[ -f "$MDLT_ORIGIN/rig/test-file.include" ] && . "$MDLT_ORIGIN/rig/test-file.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-test-file.include"
printf 'rigArmProbe(){ : ; }\ntype rigArmGuardProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/rig/any.include"\n' > "$rigTmp/rig-no-router.include"

rigAssert "the reader passes a bare single-load arm, as one top-level arm" \
	"$( rigScan "$rigTmp/rig-bare.include" )" "ok 1 --intern-op-rig-bare"
rigAssert "the reader names a guarded single-load arm, at the depth it opened at" \
	"$( rigScan "$rigTmp/rig-guarded.include" )" "fault 1 --intern-op-rig-guarded"
rigAssert "the reader names a guarded single-load arm whose load sits on the label's own line" \
	"$( rigScan "$rigTmp/rig-inline.include" )" "fault 1 --intern-op-rig-inline"
rigAssert "the reader passes a guarded arm that calls its symbol after its load, and keeps case depth" \
	"$( rigScan "$rigTmp/rig-stub-call.include" )" "ok 2 --rig-file-info
ok 1 --rig-member-stub"
rigAssert "the reader passes an arm of several statements behind a guard" \
	"$( rigScan "$rigTmp/rig-several.include" )" "ok 1 --intern-op-rig-several"
rigAssert "the reader names a single-load arm whose load stands behind a [ -f ] test" \
	"$( rigScan "$rigTmp/rig-test-file.include" )" "fault 1 --intern-op-rig-test-file"
rigAssert "the reader reads a file that is no router as no arm at all" \
	"$( rigScan "$rigTmp/rig-no-router.include" )" ""

echo "-- 1. $rigRouterName: no arm of it is a silent no-op --"
rigOut="$( rigScan "$rigRouter" )"
rigAssert "$rigRouterName: no arm whose body is one conditional include load and its return" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C awk '$1 == "fault" { sub(/^fault [0-9]+ /, "") ; print ; }' )" ""
rigAssert "the reader reached the router's arms (control on the scan itself)" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C awk '$1 != "" { arms++ ; } END { print ( arms > 10 ) ? "many" : arms + 0 ; }' )" many
rigAssert "the reader kept case depth at the member stub's own send arm, which is no top-level arm" \
	"$( rigArmLine "$rigOut" --slack-send-message 2 )" "ok 2 --slack-send-message"
rigAssert "the reader kept case depth at the client stub's own send arm, which is no top-level arm" \
	"$( rigArmLine "$rigOut" --client-comms-slack-send-message 2 )" "ok 2 --client-comms-slack-send-message"
rigAssert "the reader passes the member stub's file-info arm, which calls its function after its guarded load" \
	"$( rigArmLine "$rigOut" --slack-file-info 2 )" "ok 2 --slack-file-info"
rigAssert "the reader passes the client stub's file-info arm, which calls its function after its guarded load" \
	"$( rigArmLine "$rigOut" --client-comms-slack-file-info 2 )" "ok 2 --client-comms-slack-file-info"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK ROUTER GUARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_ROUTER_GUARD: OK (%d assertions, offline)\n' "$rigPassCount"
