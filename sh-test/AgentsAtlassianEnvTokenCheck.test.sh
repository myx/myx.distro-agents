#!/usr/bin/env bash
## Unit check on D4: the Atlassian credential read takes its key from the environment before
## any scope, so the platform tool stands alone with its key exported. No dispatcher, no config
## store -- the environment branch of AgentsToolsAtlassianCall alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The include's own dispatcher references $1 at the top level; the function under test is a
## plain function, so the unbound-reference guard is off while it is sourced.
set +u
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternOpAtlassianCall.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$((pass+1)) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$((fail+1)) ; fi ; }

## The scope reader fails loudly if reached; the environment branch must not touch it.
DistroAgentsTools(){ echo "scope-read reached" >&2 ; return 1 ; }
## The member/side gates are not what is under test: they pass without touching any scope.
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
AgentsToolsCommsOwnSettingsApply(){ return 0 ; }
## curl stands in for the real request; a clean 200 answers, so a resolved credential runs to the end.
curl(){ cat >/dev/null 2>&1 ; printf '\n200\n' ; return 0 ; }

. "$rigInc"

MDSC_CMD='DistroAgentsTools'

unset JIRA_SITE JIRA_USER JIRA_API_TOKEN CONFLUENCE_SITE CONFLUENCE_USER CONFLUENCE_API_TOKEN

## Jira: with the three JIRA_* keys exported, the call resolves them from the environment.
## rc 0 proves it -- the scope stub returns empty, so a missed environment read would report
## missing keys (rc 6) instead of running the request to completion.
JIRA_SITE="env-jira.atlassian.net" JIRA_USER="env-jira@example.com" JIRA_API_TOKEN="env-jira-token"
jiraErr="$( AgentsToolsAtlassianCall routine-env jira GET /rest/api/3/issue/TEST-1 atlassian-env-check "" 2>&1 >/dev/null )"
jiraRc=$?
check "Jira reads JIRA_SITE/USER/API_TOKEN from the environment, before any scope" "$jiraRc" "0"
check "Jira's environment read never touches the scope reader" "$jiraErr" ""
unset JIRA_SITE JIRA_USER JIRA_API_TOKEN

## Confluence: the same shape under the CONFLUENCE_* keys.
CONFLUENCE_SITE="env-conf.atlassian.net" CONFLUENCE_USER="env-conf@example.com" CONFLUENCE_API_TOKEN="env-conf-token"
confErr="$( AgentsToolsAtlassianCall routine-env confluence GET /wiki/api/v2/pages/123 atlassian-env-check "" 2>&1 >/dev/null )"
confRc=$?
check "Confluence reads CONFLUENCE_SITE/USER/API_TOKEN from the environment, before any scope" "$confRc" "0"
check "Confluence's environment read never touches the scope reader" "$confErr" ""
unset CONFLUENCE_SITE CONFLUENCE_USER CONFLUENCE_API_TOKEN

## With no environment key, the read falls back to the scope (which the stub refuses), and
## reports the missing keys with rc 6.
noEnvErr="$( AgentsToolsAtlassianCall routine-env jira GET /rest/api/3/issue/TEST-1 atlassian-env-check "" 2>&1 >/dev/null )"
noEnvRc=$?
case "$noEnvErr" in
	*scope-read*) noEnvHit=reached ;;
	*) noEnvHit=clean ;;
esac
check "with no environment key it falls back to the scope" "$noEnvHit" "reached"
check "and reports the missing credentials (rc 6) rather than calling out" "$noEnvRc" "6"

if [ "$fail" = 0 ] ; then printf 'ATLASSIAN_ENV_TOKEN: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ ATLASSIAN ENV TOKEN CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$((pass+fail))" ; exit 1
