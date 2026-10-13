#!/usr/bin/env bash
## Behavioural check on AgentsToolsCommsSlackResolveIds's human-owner-target
## gate and its bounded users.list search, run rather than read, against a
## scenario workspace built here. Holds: a bare call never reaches users.list,
## paged or not -- that fetch is one explicit ask, --resolve-human-owner-target,
## never a side effect of asking for an identity. With that flag given, the
## fallback search asks users.list exactly once and never follows a cursor,
## even one Slack offers: capped, never paginated. A capped result and a total
## miss each print one SEARCH_HINT line naming how many users were searched; a
## clean match prints none. A fake curl first on PATH logs each method and
## cursor; every token is a literal. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSlackResolveIdsGateCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/users-list-pages" "$rigTmp/conversations-info-ok"

cp "$rigTest/check-fixtures/slack-resolve-ids-gate-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-resolve-ids-gate-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## No per-member env: the acting member below has no account of its own, so the
## team's bot token is what every call goes out under -- a literal to match on.
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=CRIGOWNERFAIL\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## A page with no match and a cursor to the next one.
printf '{"ok":true,"members":[{"id":"URIGOTHER1","name":"someone-else","profile":{}}],"response_metadata":{"next_cursor":"PAGE2TOKEN"}}\n' \
	> "$rigTmp/users-list-pages/page1"
## The matching page, served only under its own cursor key.
printf '{"ok":true,"members":[{"id":"URIGOWNER01","name":"myx","profile":{}}],"response_metadata":{"next_cursor":""}}\n' \
	> "$rigTmp/users-list-pages/PAGE2TOKEN"
## A single page that matches outright, for the early-exit-on-page-1 case.
printf '{"ok":true,"members":[{"id":"URIGOWNER01","name":"myx","profile":{}}],"response_metadata":{"next_cursor":"UNUSEDTOKEN"}}\n' \
	> "$rigTmp/users-list-pages/match-on-page1"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

rigRun(){ ## resolve-ids args... -- leaves $rigOut and $rigRc, resets $rigTmp/calls first
	: > "$rigTmp/calls"
	rigRc=0
	## -u MDAT_SPAWN_AGENT/_SESSION_ID: this very check is run from a spawned
	## session, and AgentsToolsMagicCallerCheck reads exactly those to learn
	## who it is acting as. Unset, the call reads as the console's own, which
	## --magic-comms-slack-resolve-ids accepts -- the same rule a live
	## magic-coordinator session meets.
	rigOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --magic-comms-slack-resolve-ids magic-team "$@" 2>&1 )" || rigRc=$?
}
rigUsersListCalls(){ LC_ALL=C grep -c '^users\.list ' "$rigTmp/calls" ; }

## The subject has to be reachable before anything is asserted about it.
rigRun
grep -q '^auth.test ' "$rigTmp/calls" || rigRefuse "auth.test never reached the fake curl at all, so nothing below would be measured"

rigAssert "a bare call never calls users.list" "$( rigUsersListCalls )" 0
rigAssert "a bare call reports USERS_LIST_OK=not-requested" \
	"$( printf '%s' "$rigOut" | grep -c '^USERS_LIST_OK=not-requested$' )" 1
rigAssert "a bare call prints no HUMAN_OWNER_TARGET line at all" \
	"$( printf '%s' "$rigOut" | grep -c '^HUMAN_OWNER_TARGET|' )" 0
rigAssert "a bare call still reports the identity it was asked for" \
	"$( printf '%s' "$rigOut" | grep -c '^AUTH_USER_ID=URIGSELF01$' )" 1

## --resolve-human-owner-target, hint on the very first page: one users.list
## call, not a page-to-exhaustion walk.
cp "$rigTmp/users-list-pages/match-on-page1" "$rigTmp/users-list-pages/page1"
rigRun --resolve-human-owner-target
rigAssert "a match on page 1 makes exactly one users.list call" "$( rigUsersListCalls )" 1
rigAssert "and the human-owner target is reported reachable" \
	"$( printf '%s' "$rigOut" | grep -c '^HUMAN_OWNER_TARGET|status=reachable|' )" 1
rigAssert "a clean hint match prints no SEARCH_HINT line" \
	"$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|' )" 0

## Put the no-match page back, with a cursor Slack offers to a further page that
## holds the match -- and prove that cursor is never followed: one bounded fetch,
## never paginated, so a match sitting on page 2 alone is not found at all.
printf '{"ok":true,"members":[{"id":"URIGOTHER1","name":"someone-else","profile":{}}],"response_metadata":{"next_cursor":"PAGE2TOKEN"}}\n' \
	> "$rigTmp/users-list-pages/page1"
rigRun --resolve-human-owner-target
rigAssert "no match on the one page fetched: exactly one users.list call, the cursor offered is not followed" \
	"$( rigUsersListCalls )" 1
rigAssert "the match that sits only on page 2 is not found" \
	"$( printf '%s' "$rigOut" | grep -c '^HUMAN_OWNER_TARGET|status=reachable|' )" 0
rigAssert "and the total miss prints one SEARCH_HINT line naming the one user searched" \
	"$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|searched=1|note=repeating this same call changes nothing -- narrow the term, or give a known id$' )" 1

## Control: the configured alias, when it IS reachable, needs no users.list at all.
mkdir -p "$rigTmp/conversations-info-ok"
: > "$rigTmp/conversations-info-ok/CRIGOWNERFAIL"
rigRun --resolve-human-owner-target
rigAssert "a reachable configured alias short-circuits before any users.list call" \
	"$( rigUsersListCalls )" 0
rigAssert "and reports the alias as the source" \
	"$( printf '%s' "$rigOut" | grep -c '^HUMAN_OWNER_TARGET|status=reachable|target=CRIGOWNERFAIL|source=config-alias$' )" 1

## A configured value that is already a Slack user id (U*/W*) needs no search, and no
## conversations.info either: conversations.open is reached directly on it.
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNERKNOWN\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRun --resolve-human-owner-target
rigAssert "a configured user id makes no users.list call at all" "$( rigUsersListCalls )" 0
rigAssert "nor a conversations.info call" "$( LC_ALL=C grep -c '^conversations.info ' "$rigTmp/calls" )" 0
rigAssert "exactly one conversations.open call" "$( LC_ALL=C grep -c '^conversations.open ' "$rigTmp/calls" )" 1
rigAssert "and the target is reported reachable, sourced from it directly" \
	"$( printf '%s' "$rigOut" | grep -c '^HUMAN_OWNER_TARGET|status=reachable|target=DRIGOPENED1|source=conversations.open|hint=-|user_id=URIGOWNERKNOWN$' )" 1

## --raw with no term at all is refused, before any credential or network step.
rigRun --raw
rigAssert "--raw alone, no term, is refused" "$rigRc" 1
rigAssert "naming why" "$( printf '%s' "$rigOut" | grep -c 'needs --user-name or --channel-name' )" 1
rigAssert "and never reaches auth.test" "$( LC_ALL=C grep -c '^auth.test ' "$rigTmp/calls" )" 0

## --user-name's own search is one bounded fetch too: a match on page 1 is found,
## exactly one users.list call, no cursor followed even though one is offered.
printf '{"ok":true,"members":[{"id":"URIGOWNER01","name":"myx","profile":{}}],"response_metadata":{"next_cursor":"PAGE2TOKEN"}}\n' \
	> "$rigTmp/users-list-pages/page1"
rigRun --user-name myx
rigAssert "--user-name makes exactly one users.list call, cursor offered or not" "$( rigUsersListCalls )" 1
rigAssert "and finds the page-1 match" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|myx|URIGOWNER01|myx|' )" 1
rigAssert "a clean --user-name match prints no SEARCH_HINT line" \
	"$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|' )" 0

## Put a no-match page back with the same cursor, to prove a match sitting only on
## page 2 is not found by --user-name either.
printf '{"ok":true,"members":[{"id":"URIGOTHER1","name":"someone-else","profile":{}}],"response_metadata":{"next_cursor":"PAGE2TOKEN"}}\n' \
	> "$rigTmp/users-list-pages/page1"
printf '{"ok":true,"members":[{"id":"URIGOWNER01","name":"myx","profile":{}}],"response_metadata":{"next_cursor":""}}\n' \
	> "$rigTmp/users-list-pages/PAGE2TOKEN"
rigRun --user-name myx
rigAssert "still exactly one users.list call" "$( rigUsersListCalls )" 1
rigAssert "the page-2-only match is not found" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|' )" 0
rigAssert "and the total miss prints one SEARCH_HINT line naming the one user searched" \
	"$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|searched=1|note=repeating this same call changes nothing -- narrow the term, or give a known id$' )" 1

## The match cap is a fixed 10, not a setting: eleven queries, eleven members on
## the one page, each matching its own query exactly -- only 10 USER_MATCH lines
## come back.
rigCapMembers="" rigCapNames=""
for rigCapN in 1 2 3 4 5 6 7 8 9 10 11 ; do
	rigCapMembers="$rigCapMembers${rigCapMembers:+,}{\"id\":\"URIGCAP$rigCapN\",\"name\":\"rig-cap-$rigCapN\",\"profile\":{}}"
	rigCapNames="$rigCapNames${rigCapNames:+,}rig-cap-$rigCapN"
done
printf '{"ok":true,"members":[%s],"response_metadata":{"next_cursor":""}}\n' "$rigCapMembers" > "$rigTmp/users-list-pages/page1"
rigRun --user-name "$rigCapNames"
rigAssert "eleven real matches on one page, the cap still holds at 10" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c '^USER_MATCH|' )" 10
rigAssert "and the capped result prints one SEARCH_HINT line naming all eleven users searched" \
	"$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|searched=11|note=repeating this same call changes nothing -- narrow the term, or give a known id$' )" 1

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
