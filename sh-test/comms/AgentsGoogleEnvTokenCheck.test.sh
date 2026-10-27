#!/usr/bin/env bash
## Unit check on D4: the Google member resolver takes its credentials from the environment
## before any scope, so the platform tool stands alone with its keys exported. No dispatcher,
## no config store -- the resolver's environment branch alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The include's own dispatcher references $1 at the top level; the resolver under test is a
## plain function, so the unbound-reference guard is off while it is sourced.
set +u
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsGoogle.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$((pass+1)) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$((fail+1)) ; fi ; }

## The resolver under test is plain credential resolution: the side check and the bare-name
## check are neutral, and the config store (DistroAgentsTools) is the one thing that must not
## run while an environment key is present. scopeMode=off makes it fail loudly if reached;
## scopeMode=on makes it answer, for the fall-back-to-scope leg.
scopeMode="off"
DistroAgentsTools(){
	if [ "$scopeMode" = "on" ] ; then
		case "$*" in
			*"--select GOOGLE_CLIENT_ID"*)     printf '%s' "scope-client-id" ; return 0 ;;
			*"--select GOOGLE_CLIENT_SECRET"*) printf '%s' "scope-client-secret" ; return 0 ;;
			*"--select GOOGLE_REFRESH_TOKEN"*) printf '%s' "scope-refresh-token" ; return 0 ;;
			*) echo "scope-read reached an unexpected --select: $*" >&2 ; return 1 ;;
		esac
	fi
	echo "scope-read should not run: $*" >&2
	return 1
}
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }

. "$rigInc"

## Environment first: all three keys set, so no config-store read runs at all.
GOOGLE_CLIENT_ID="env-client-id"
GOOGLE_CLIENT_SECRET="env-client-secret"
GOOGLE_REFRESH_TOKEN="env-refresh-token"
googleClientId="" googleClientSecret="" googleRefreshToken=""
AgentsToolsGoogleResolveMember google-whoami routine-envtest
check "GOOGLE_CLIENT_ID comes from the environment, before any scope" "$googleClientId" "env-client-id"
check "GOOGLE_CLIENT_SECRET comes from the environment, before any scope" "$googleClientSecret" "env-client-secret"
check "GOOGLE_REFRESH_TOKEN comes from the environment, before any scope" "$googleRefreshToken" "env-refresh-token"

## No environment key: the scope is asked, and its value is used.
unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN
scopeMode="on"
googleClientId="" googleClientSecret="" googleRefreshToken=""
AgentsToolsGoogleResolveMember google-whoami routine-envtest
check "with no environment key the scope is asked for GOOGLE_CLIENT_ID" "$googleClientId" "scope-client-id"
check "with no environment key the scope is asked for GOOGLE_CLIENT_SECRET" "$googleClientSecret" "scope-client-secret"
check "with no environment key the scope is asked for GOOGLE_REFRESH_TOKEN" "$googleRefreshToken" "scope-refresh-token"

if [ "$fail" = 0 ] ; then printf 'GOOGLE_ENV_TOKEN: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ GOOGLE ENV TOKEN CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$((pass+fail))" ; exit 1
