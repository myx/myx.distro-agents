#!/usr/bin/env bash
## Behavioural check on the coordinator's forwarding stub, sh-lib/comms/AgentsTools.CoordinatorComms.include: every flag an
## Atlassian operation itself parses is accepted at the stub, so the form its help approves is reachable through the entry
## point a coordinator uses. A flag the operation parses and the stub was not told of is refused as `unexpected: --flag`,
## which reads as the caller's mistake and is the stub's.
##
## The stub reaches an operation by four shapes of arm, and every one of them is read here: a `stub` arm declares its flags
## in fwdStubValues/fwdStubNoValues, and a `limit`, `commentRead`, `commentReadConf` or `none` arm declares them in its own
## hand-written case. A drift in any of those shapes is the same defect.
##
## Both sides are text, so the comparison is text. No socket, no store and no call is opened.
##
## Red recipe: before `--if-version` was declared at confluence-page-update, this check named exactly that one flag. Every
## other operation read clean both before and after, which is the control that the comparison is not blind.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
pkg="$MDLT_ORIGIN/myx/myx.distro-agents"
stub="$pkg/sh-lib/comms/AgentsTools.CoordinatorComms.include"
[ -f "$stub" ] || { echo "⛔ ERROR: no $stub" >&2 ; exit 1 ; }

## The flags one operand list holds that another does not, space separated, or `none`.
rigMissing(){ ## declared, parsed
	local declared="$1" parsed="$2" flag missing=""
	for flag in $parsed ; do
		case " $declared " in
			*" $flag "*) continue ;;
		esac
		missing="${missing}${missing:+ }$flag"
	done
	printf '%s' "${missing:-none}"
}

## The flags an Atlassian operation parses: the case arms of its argument loop, less the two every operation's definition
## line carries. A flag only its help names is not parsed, and is not this check's subject.
rigParsed(){ ## operation file
	LC_ALL=C grep -o -- '--[a-z][a-z-]*)' "$1" \
		| LC_ALL=C sed 's/)$//' \
		| LC_ALL=C sort -u \
		| LC_ALL=C grep -v -x -e '--member' -e '--context' \
		| tr '\n' ' '
}

## The flags the stub accepts for one operation, by the shape of its arm.
rigDeclared(){ ## the arm's own line
	local armLine="$1" restKind="" declared=""
	restKind="$( printf '%s\n' "$armLine" | LC_ALL=C sed -n 's/.*fwdRestKind=\([A-Za-z]*\).*/\1/p' )"
	declared="$( printf '%s\n' "$armLine" | LC_ALL=C sed -n 's/.*fwdSecondFlag=\(--[a-z][a-z-]*\).*/\1/p' )"
	declared="$declared $( printf '%s\n' "$armLine" | LC_ALL=C sed -n "s/.*fwdStubValues='\([^']*\)'.*/\1/p" )"
	declared="$declared $( printf '%s\n' "$armLine" | LC_ALL=C sed -n "s/.*fwdStubNoValues='\([^']*\)'.*/\1/p" )"
	case "$restKind" in
		limit) declared="$declared --limit" ;;
		commentRead) declared="$declared --format --start-at" ;;
		commentReadConf) declared="$declared --inline --since" ;;
		pageComment) declared="$declared --comment-id" ;;
	esac
	printf '%s' "$declared"
}

rigPass=0 rigFail=0 rigOps=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## Every operation the stub forwards, one line each, taken from the arm case itself.
while IFS= read -r rigRow ; do
	rigOp="$( printf '%s\n' "$rigRow" | LC_ALL=C sed -n 's/^[[:space:]]*\([a-z][a-z-]*\)).*/\1/p' )"
	[ -n "$rigOp" ] || continue
	case "$rigRow" in *fwdRestKind=*) ;; *fwdSecondFlag=*) ;; *) continue ;; esac
	rigOpFile=""
	for rigCandidate in "$pkg"/sh-lib/atlassian/AgentsTools.InternOpAtlassian*.include ; do
		case "$rigCandidate" in *InternOpAtlassianCall*|*InternOpAtlassianCheck*) continue ;; esac
		LC_ALL=C grep -q -F -- "--intern-op-atlassian-$rigOp\`" "$rigCandidate" || continue
		rigOpFile="$rigCandidate" ; break
	done
	if [ -z "$rigOpFile" ] ; then
		rigAssert "$rigOp: its own operation file names it" 'no file' 'one file in sh-lib/atlassian'
		continue
	fi
	rigOps=$(( rigOps + 1 ))
	rigAssert "$rigOp: every flag it parses is accepted at the stub" "$( rigMissing "$( rigDeclared "$rigRow" )" "$( rigParsed "$rigOpFile" )" )" none
done < "$stub"

rigAssert 'the stub forwards at least one operation' "$( [ "$rigOps" -gt 0 ] && echo yes )" yes
## The controls, both directions, over one fixed pair: a flag the declaration lacks is reported, and one it holds is not.
rigAssert 'control: a flag the declaration lacks is reported' "$( rigMissing '--version --title' '--version --if-version' )" '--if-version'
rigAssert 'control: a flag the declaration holds is not reported' "$( rigMissing '--version --if-version' '--version --if-version' )" none

if [ "$rigFail" -ne 0 ] ; then
	printf '⛔ ATLASSIAN COORDINATOR FLAGS CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" >&2
	exit 1
fi
printf 'ATLASSIAN_COORDINATOR_FLAGS: OK (%s assertions, %s operations)\n' "$rigPass" "$rigOps"
