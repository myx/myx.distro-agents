#!/usr/bin/env bash
## Unit check on D4: the Trello platform tool reads its credentials from the environment
## before any scope, so it stands alone with its key exported. No dispatcher, no config
## store -- the environment branch alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The include's own dispatcher references $1 at the top level; the function under test
## is a plain function, so the unbound-reference guard is off while it is sourced.
set +u
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsTrello.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }

scratch="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsTrelloEnvTokenCheck.XXXXXX" )" || { echo "⛔ ERROR: mktemp failed under the workspace's own temp folder" >&2 ; exit 1 ; }
trap 'rm -rf "$scratch"' EXIT
errFile="$scratch/err"

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$((pass+1)) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$((fail+1)) ; fi ; }

## The config-store read must not run while the environment holds the credential: it
## fails loudly if reached. The prerequisite guards (bare-name, own-side) merely pass,
## since they run before the credential read for any member and are not the scope read.
DistroAgentsTools(){ echo "scope-read should not run" >&2 ; return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
## curl is stubbed to record the header it is handed and succeed, so the credential
## branch is the only thing under test -- never the network.
capturedHeader=""
curl(){ capturedHeader="$( cat )" ; return 0 ; }

. "$rigInc"

## routine-* members skip the member-skill-directory check; the credential read is the
## same code path for any member name.
unset TRELLO_KEY TRELLO_TOKEN
TRELLO_KEY="env-key-ENV"
TRELLO_TOKEN="env-token-ENV"
capturedHeader=""
AgentsToolsCommsTrelloCheck routine-test 2>"$errFile"
rc=$?
check "the environment's key and token are used, before any scope read" "$rc" "0"
case "$capturedHeader" in
	*'oauth_consumer_key="env-key-ENV"'*) hkey=0 ;; *) hkey=1 ;;
esac
case "$capturedHeader" in
	*'oauth_token="env-token-ENV"'*) htok=0 ;; *) htok=1 ;;
esac
check "the request header carries the environment's key" "$hkey" "0"
check "the request header carries the environment's token" "$htok" "0"

unset TRELLO_KEY TRELLO_TOKEN
capturedHeader=""
: > "$errFile"
AgentsToolsCommsTrelloCheck routine-test 2>"$errFile"
rc=$?
check "with no environment credential it falls back to the scope" "$rc" "1"
if grep -q 'scope-read should not run' "$errFile" ; then reached=0 ; else reached=1 ; fi
check "the scope read is reached, and fails loudly" "$reached" "0"

if [ "$fail" = 0 ] ; then printf 'TRELLO_ENV_TOKEN: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ TRELLO ENV TOKEN CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$((pass+fail))" ; exit 1
