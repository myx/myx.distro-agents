#!/usr/bin/env bash
## Behavioural check that the harness comment about a work-duty's cache-prefix
## names the policy the code acts on. The code's Member+ layer is built for the
## routines that declare `cache-prefix: extended`, and the comment says so; the
## line about the routine layer must not claim a work-duty is `armed`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigSrc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessSkills.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSrc" ] || rigRefuse "the harness include is missing: $rigSrc"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The control: the include really is the file this check is about.
rigAssert "the include is read" "$( [ "$( LC_ALL=C grep -c 'AgentsHarnessMemberPlusText' "$rigSrc" || : )" -gt 0 ] && echo yes || echo no )" "yes"
rigAssert "the comment says the Member+ layer is for cache-prefix: extended" "$( [ "$( LC_ALL=C grep -c 'declare `cache-prefix: extended` (a work-duty' "$rigSrc" || : )" -gt 0 ] && echo yes || echo no )" "yes"
rigAssert "no comment claims a work-duty is cache-prefix: armed" "$( LC_ALL=C grep -c 'cache-prefix: armed' "$rigSrc" || : )" "0"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'WORK_DUTY_CACHE_PREFIX_COMMENT: OK\n'
