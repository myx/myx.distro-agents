#!/usr/bin/env bash
## Behavioural check on the include the send arm of the Slack router hands its call to. An arm whose whole body is
## one include load and one `return $?` does nothing itself: the call is that include's. So the include must answer
## the arm's own word as a case arm of its own, must write the method the operation posts by, and must be loaded
## every call. Held, run and not read:
##   1. THE SEND ARM. The arm --intern-op-comms-slack-send-message of AgentsTools.MemberCommsSlack.include names an
##      include that is there, that holds that case arm, and that writes chat.postMessage. Its load is unguarded, so
##      a second send of the same process sources it again rather than passing a `type` test and returning 0.
##   2. THE INSTRUMENT. The readers on subjects made by hand: an include that answers the arm and one that does not,
##      a guarded load, a body of two loads, a method written in code and the same word in a comment.
## Red recipe: on the router whose send arm names AgentsTools.CommsSlackPresentation.include, section 1 fails on the
## case arm and on the method, and the guarded-load assertion passes, since that arm loads unguarded too.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigRouterName="AgentsTools.MemberCommsSlack.include"
rigSendArm="--intern-op-comms-slack-send-message"
rigSendMethod="chat.postMessage"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
rigRouter="$rigPackage/sh-lib/slack/$rigRouterName"
[ -f "$rigRouter" ] || rigRefuse "no $rigRouterName at the origin this workspace resolves: $rigPackage/sh-lib/slack"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackArmIncludeCheck )" || exit 1
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

## THE READERS. The include an exact-shape arm loads, whether that load is guarded, and what an include answers.
rigArmInclude(){ ## file, arm word -- the include that arm loads, or nothing where it is no operation body
	LC_ALL=C awk -v word="$2" '
		FNR == 1 { inArm = 0 ; }
		{
			line = $0
			if ( inArm == 0 && line ~ /^[[:space:]]*--[A-Za-z0-9*-]+\)[[:space:]]*$/ ) {
				arm = line ; sub(/^[[:space:]]*/, "", arm) ; sub(/\)[[:space:]]*$/, "", arm)
				loads = 0 ; rets = 0 ; others = 0 ; load = "" ; inArm = 1 ; next
			}
			if ( inArm == 1 ) {
				if ( line ~ /^[[:space:]]*;;[[:space:]]*$/ ) {
					if ( arm == word && loads == 1 && rets == 1 && others == 0 ) print load
					inArm = 0 ; next
				}
				if ( line ~ /^[[:space:]]*$/ ) next
				if ( line ~ /^[[:space:]]*return \$\?[[:space:]]*$/ ) { rets++ ; next ; }
				if ( match(line, /\$MDLT_ORIGIN[^"]*\.include/) ) { loads++ ; load = substr(line, RSTART, RLENGTH) ; next ; }
				others++ ; next
			}
		}
	' "$1"
}
rigArmGuarded(){ ## file, arm word -- `guarded` where a load of that arm's include stands behind a type test
	LC_ALL=C awk -v word="$2" '
		FNR == 1 { inArm = 0 ; }
		{
			line = $0
			if ( inArm == 0 && line ~ /^[[:space:]]*--[A-Za-z0-9*-]+\)[[:space:]]*$/ ) {
				arm = line ; sub(/^[[:space:]]*/, "", arm) ; sub(/\)[[:space:]]*$/, "", arm)
				guard = "unguarded" ; inArm = 1 ; next
			}
			if ( inArm == 1 ) {
				if ( line ~ /^[[:space:]]*;;[[:space:]]*$/ ) {
					if ( arm == word ) print guard
					inArm = 0 ; next
				}
				if ( line ~ /\.include"/ && line ~ /\|[[:space:]]*\./ ) guard = "guarded"
				next
			}
		}
	' "$1"
}
rigAnswers(){ ## include file, arm word -- `answers` where it holds a case arm beginning with that word
	LC_ALL=C awk -v prefix="$2" '
		/^[[:space:]]*#/ { next ; }
		/^[[:space:]]*--/ {
			label = $0 ; sub(/^[[:space:]]*/, "", label) ; sub(/\).*$/, "", label)
			labelCount = split(label, part, "|")
			for ( partAt = 1 ; partAt <= labelCount ; partAt++ ) { if ( index(part[partAt], prefix) == 1 ) { found = 1 ; exit ; } ; }
		}
		END { exit found ? 0 : 1 ; }
	' "$1"
}
rigWrites(){ ## include file, a method -- `writes` where the include writes that method outside a comment
	LC_ALL=C awk -v method="$2" '/^[[:space:]]*#/ { next ; } { if ( index($0, method) > 0 ) { found = 1 ; exit ; } ; } END { exit found ? 0 : 1 ; }' "$1"
}

echo "-- 2. the instrument: the readers on subjects made by hand --"
printf 'case "$1" in\n\t--intern-op-rig-fixed)\n\t\t. "$MDLT_ORIGIN/x/rig.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-arm.include"
printf 'case "$1" in\n\t--intern-op-rig-fixed)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-answers.include"
printf 'case "$1" in\n\t--intern-op-other)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-silent.include"
printf 'case "$1" in\n\t--intern-op-rig-fixed)\n\t\ttype rigTruth > /dev/null 2>&1 || . "$MDLT_ORIGIN/x/rig.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-guarded.include"
printf 'case "$1" in\n\t--intern-op-rig-fixed)\n\t\t. "$MDLT_ORIGIN/x/rig.include"\n\t\t. "$MDLT_ORIGIN/x/rig.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-two-loads.include"
printf 'chat.postMessage\n' > "$rigTmp/rig-sends.include"
printf '# chat.postMessage is said in a comment only\n' > "$rigTmp/rig-comment.include"
rigAssert "the reader names the include an operation-body arm loads" "$( rigArmInclude "$rigTmp/rig-arm.include" --intern-op-rig-fixed )" '$MDLT_ORIGIN/x/rig.include'
rigAssert "the reader marks an unguarded load" "$( rigArmGuarded "$rigTmp/rig-arm.include" --intern-op-rig-fixed )" unguarded
rigAssert "the reader marks a guarded load" "$( rigArmGuarded "$rigTmp/rig-guarded.include" --intern-op-rig-fixed )" guarded
rigAssert "the reader passes over a body of two loads, which is no operation body" "$( rigArmInclude "$rigTmp/rig-two-loads.include" --intern-op-rig-fixed )" ""
rigAssert "the reader answers for an include that holds the arm" "$( rigAnswers "$rigTmp/rig-answers.include" --intern-op-rig-fixed && printf answers || printf silent )" answers
rigAssert "the reader says silent for an include that holds no such arm" "$( rigAnswers "$rigTmp/rig-silent.include" --intern-op-rig-fixed && printf answers || printf silent )" silent
rigAssert "the method reader sees a method in code" "$( rigWrites "$rigTmp/rig-sends.include" chat.postMessage && printf writes || printf quiet )" writes
rigAssert "the method reader says quiet for a method said in a comment" "$( rigWrites "$rigTmp/rig-comment.include" chat.postMessage && printf writes || printf quiet )" quiet

echo "-- 1. the send arm hands its call to the include that sends --"
rigSendLoad="$( rigArmInclude "$rigRouter" "$rigSendArm" )"
rigAssert "$rigRouterName: the send arm hands its call to an include" "$( [ -n "$rigSendLoad" ] && printf names || printf none )" names
[ -n "$rigSendLoad" ] || rigRefuse "the send arm of $rigRouterName names no include"
rigSendInclude="$rigPackage/${rigSendLoad#\$MDLT_ORIGIN/$rigPackageRel/}"
rigAssert "${rigSendInclude##*/}: the include the send arm names is there" \
	"$( [ -f "$rigSendInclude" ] && printf there || printf missing )" there
[ -f "$rigSendInclude" ] || rigRefuse "the send arm of $rigRouterName names no include of the origin"
rigAssert "${rigSendInclude##*/}: it answers the send arm's own word" \
	"$( rigAnswers "$rigSendInclude" "$rigSendArm" && printf answers || printf silent )" answers
rigAssert "${rigSendInclude##*/}: it writes $rigSendMethod, so the call posts" \
	"$( rigWrites "$rigSendInclude" "$rigSendMethod" && printf writes || printf quiet )" writes
rigAssert "$rigRouterName: the send arm loads its include on every call" \
	"$( rigArmGuarded "$rigRouter" "$rigSendArm" )" unguarded

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK ARM INCLUDE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_ARM_INCLUDE: OK (%d assertions, offline)\n' "$rigPassCount"
