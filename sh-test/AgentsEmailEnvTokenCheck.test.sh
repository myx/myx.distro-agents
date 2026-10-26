#!/usr/bin/env bash
## Unit check on D4: the Email tool takes its credentials from the environment
## before any scope, so the platform tool stands alone with its keys exported. No
## dispatcher, no config store -- the credential reads' environment branch alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The include's own dispatcher references $1 at the top level; the helper under
## test is a plain function, so the unbound-reference guard is off while it is
## sourced.
set +u
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsEmail.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$((pass+1)) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$((fail+1)) ; fi ; }

## Scope reads fail loudly and are counted, so any reach into them is caught.
scopeReads=0
DistroAgentsTools(){ scopeReads=$((scopeReads+1)) ; echo "scope-read should not run: $*" >&2 ; return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
## curl is the observation point: what the operation hands it, args and stdin.
curlArgs=""
curlStdin=""
curl(){ curlArgs="$*" ; curlStdin="$( cat )" ; return 0 ; }

. "$rigInc"

## The environment's keys are used, before any scope read.
EMAIL_IMAP_HOST="env-imap-host"
EMAIL_USER="env-user"
EMAIL_APP_PASSWORD="env-app-password"
AgentsToolsCommsEmailMarkSeen routine-envtest 42
check "the environment's EMAIL_IMAP_HOST is used" "$( printf '%s' "$curlArgs" | grep -c 'imaps://env-imap-host/INBOX' )" "1"
check "the environment's EMAIL_USER/EMAIL_APP_PASSWORD are used" "$( printf '%s' "$curlStdin" | grep -c 'machine env-imap-host login env-user password env-app-password' )" "1"
check "no scope read happens when the environment holds the keys" "$scopeReads" "0"

## With no environment, the scope is asked.
unset EMAIL_IMAP_HOST EMAIL_USER EMAIL_APP_PASSWORD
curlArgs="" curlStdin="" scopeReads=0
DistroAgentsTools(){
	case "$4" in
		EMAIL_IMAP_HOST) printf 'scope-imap-host' ;;
		EMAIL_USER) printf 'scope-user' ;;
		EMAIL_APP_PASSWORD) printf 'scope-app-password' ;;
		*) echo "scope-read should not run: $*" >&2 ; return 1 ;;
	esac
}
AgentsToolsCommsEmailMarkSeen routine-envtest 42
check "with no environment the scope EMAIL_IMAP_HOST is used" "$( printf '%s' "$curlArgs" | grep -c 'imaps://scope-imap-host/INBOX' )" "1"
check "with no environment the scope EMAIL_USER/EMAIL_APP_PASSWORD are used" "$( printf '%s' "$curlStdin" | grep -c 'machine scope-imap-host login scope-user password scope-app-password' )" "1"

if [ "$fail" = 0 ] ; then printf 'EMAIL_ENV_TOKEN: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ EMAIL ENV TOKEN CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$((pass+fail))" ; exit 1
