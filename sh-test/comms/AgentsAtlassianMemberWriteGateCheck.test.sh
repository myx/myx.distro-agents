#!/usr/bin/env bash
## Text check of the forwarder's stub-operation gate (sh-lib/comms/AgentsTools.CoordinatorComms.include, the `fwdRuns` case):
## the four Confluence page writes run as magic-coordinator or magic-librarian; every member actualises the Jira state of its
## own item, held by the acting-member check (the epic's floor, 2026-11-25, and the answer to Q495); a delete stays the
## coordinator's. The file is a dispatcher, not a library, so its gate is read as the text it is, as the flags check beside
## it reads its own subject. No socket, no store and no call is opened.
## RED RECIPE, measured 2026-11-25 17:0x +0200 against the librarian-only gate: assertions 2 and 3 fail with `no`, because
## that gate named no acting-member check; the page-write and delete controls pass before and after.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
pkg="$MDLT_ORIGIN/myx/myx.distro-agents"
stub="$pkg/sh-lib/comms/AgentsTools.CoordinatorComms.include"
[ -f "$stub" ] || { echo "⛔ ERROR: no $stub" >&2 ; exit 1 ; }
gate="$( LC_ALL=C sed -n '/local fwdRuns=/,/local fwdStubArg/p' "$stub" )"
[ -n "$gate" ] || { echo "⛔ ERROR: the fwdRuns gate is not found in $stub" >&2 ; exit 1 ; }
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigHas(){ ## the text the gate must carry, or must not, read from the gate alone
	case "$gate" in
		*"$1"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}

rigAssert "the gate carries the Jira state writes" "$( rigHas 'jira-issue-update' )" yes
rigAssert "the Jira writes run as the acting member" "$( rigHas 'fwdActingWrites' )" yes
rigAssert "and the acting-member check holds each to itself" "$( rigHas 'AgentsToolsActingMemberCheck' )" yes
rigAssert "a Jira delete stays the coordinator's" "$( rigHas 'jira-issue-delete' )" no
rigAssert "the page writes stay with the librarian, as the control" "$( rigHas 'confluence-page-update' )" yes
rigAssert "the stub gate's refusal line still stands" "$( LC_ALL=C grep -c -F 'runs only as ${fwdRuns// / or }' "$stub" 2> /dev/null || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ATLASSIAN MEMBER WRITE GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'ATLASSIAN_MEMBER_WRITE_GATE: OK (%d assertions, text of the gate only)\n' "$rigPassCount"
