#!/usr/bin/env bash
## Unit check on D4: the Slack bot-token resolver takes its credential from the environment
## before any scope, so the platform tool stands alone with its key exported. No dispatcher,
## no config store -- the resolver's environment branch alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The include's own dispatcher references $1 at the top level; the resolver under test is a
## plain function, so the unbound-reference guard is off while it is sourced.
set +u
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsSlack.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$((pass+1)) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$((fail+1)) ; fi ; }

## The resolver's environment branch runs before any scope read, so a stub scope reader that
## must never be called proves the branch is first.
DistroAgentsTools(){ echo "scope-read should not run" >&2 ; return 1 ; }
AgentsToolsSlackOwnSettingsApply(){ echo "scope-read should not run" >&2 ; return 1 ; }
AgentsToolsSlackClientSide(){ echo "scope-read should not run" >&2 ; return 1 ; }

. "$rigInc"

SLACK_BOT_TOKEN="env-bot-token-ENV"
check "the environment's bot token is used, before any scope" "$( AgentsToolsResolveSlackBotToken magic-team )" "environment-bot-token env-bot-token-ENV"
unset SLACK_BOT_TOKEN
check "with no environment token it asks the scope, and returns none where the stub refuses" "$( AgentsToolsResolveSlackBotToken magic-team 2>/dev/null ; echo rc=$? )" "rc=1"

if [ "$fail" = 0 ] ; then printf 'SLACK_ENV_TOKEN: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ SLACK ENV TOKEN CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$((pass+fail))" ; exit 1
