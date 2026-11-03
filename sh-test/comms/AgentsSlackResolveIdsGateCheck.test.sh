#!/usr/bin/env bash
## Behavioural check on AgentsToolsCommsSlackResolveIds's bounded --user-name
## search and its id route, run rather than read, against a scenario workspace
## built here. Holds: a bare call never reaches users.list, paged or not -- that
## fetch is one explicit ask, --user-name, never a side effect of asking for an
## identity. With a name given, the search asks users.list exactly once and never
## follows a cursor, even one Slack offers: capped, never paginated. A capped
## result and a total miss each print one SEARCH_HINT line naming how many users
## were searched; a clean match prints none. An ID-shaped term is asked of
## users.info instead, one call for it, and the directory is fetched only when a
## term is no id -- so an id the page misses is still named, with its real name
## and its e-mail, and an id Slack refuses is reported unresolved in Slack's own
## words rather than guessed at. --resolve-human-owner-target is gone -- there is
## no human-owner-target step left to gate, and naming it is refused as an
## unknown option. A fake curl first on PATH logs each method, cursor and user;
## every token is a literal. Offline by construction.
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

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackResolveIdsGateCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/users-list-pages" "$rigTmp/users-info" "$rigTmp/conversations-info-ok"

cp "$rigTest/check-fixtures/slack-resolve-ids-gate-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-resolve-ids-gate-check.curl.stub.sh"
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
	## --slack-resolve-ids accepts -- the same rule a live
	## magic-coordinator session meets.
	rigOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --slack-resolve-ids --team-member magic-team "$@" 2>&1 )" || rigRc=$?
}
rigUsersListCalls(){ LC_ALL=C grep -c '^users\.list ' "$rigTmp/calls" ; }
rigUsersInfoCalls(){ LC_ALL=C grep -c '^users\.info ' "$rigTmp/calls" ; }
rigUsersInfoIds(){ LC_ALL=C sed -n 's/^users\.info cursor=- user=\([^ ]*\) .*/\1/p' "$rigTmp/calls" | LC_ALL=C tr '\n' ' ' ; }

## The subject has to be reachable before anything is asserted about it.
rigRun
grep -q '^auth.test ' "$rigTmp/calls" || rigRefuse "auth.test never reached the fake curl at all, so nothing below would be measured"

rigAssert "a bare call never calls users.list" "$( rigUsersListCalls )" 0
rigAssert "a bare call reports USERS_LIST_OK=not-requested" \
	"$( printf '%s' "$rigOut" | grep -c '^USERS_LIST_OK=not-requested$' )" 1
rigAssert "a bare call still reports the identity it was asked for" \
	"$( printf '%s' "$rigOut" | grep -c '^AUTH_USER_ID=URIGSELF01$' )" 1

## --resolve-human-owner-target names a step that no longer exists: refused as
## an unknown option, before any credential or network step runs, same as any
## other unrecognised flag.
rigRun --resolve-human-owner-target
rigAssert "--resolve-human-owner-target is refused as an unknown option" "$rigRc" 1
rigAssert "naming it so" "$( printf '%s' "$rigOut" | grep -c 'invalid option: --resolve-human-owner-target' )" 1
rigAssert "and never reaches auth.test" "$( LC_ALL=C grep -c '^auth.test ' "$rigTmp/calls" )" 0

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

## ---- AN ID IS ASKED OF users.info, NOT OF THE DIRECTORY. This is the field case:
## U0B9DMADT0A sat in the 417-user page, users.info named her, and the resolver
## held her as nobody because an id was only ever compared against names. The
## page below is EMPTY here, so a match can come from nowhere but users.info.
## The body is Slack's own shape for a live person, measured 2026-11-03 16:51Z:
## real_name at the top AND inside profile, the e-mail only inside profile.
printf '{"ok":true,"user":{"id":"URIGPERSON1","name":"rig.person","real_name":"Rig Person","profile":{"display_name":"rig.person","real_name":"Rig Person","email":"rig.person@rig.example"}}}\n' \
	> "$rigTmp/users-info/URIGPERSON1"
printf '{"ok":true,"members":[],"response_metadata":{"next_cursor":""}}\n' > "$rigTmp/users-list-pages/page1"
rigRun --user-name URIGPERSON1
rigAssert "an id is one users.info call for that id" "$( rigUsersInfoCalls )|$( rigUsersInfoIds )" "1|URIGPERSON1 "
rigAssert "and it costs no directory fetch at all" "$( rigUsersListCalls )" 0
rigAssert "and the page being empty changes nothing" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|URIGPERSON1|URIGPERSON1|rig.person|rig.person|Rig Person|rig.person@rig.example$' )" 1
rigAssert "its row carries the name, the real name and the e-mail, so no reader looks an id up" \
	"$( printf '%s' "$rigOut" | LC_ALL=C awk -F '|' '$1 == "USER_MATCH" && $2 == "URIGPERSON1" { printf "%s/%s/%s/%s", $4, $5, $6, $7 }' )" \
	"rig.person/rig.person/Rig Person/rig.person@rig.example"
rigAssert "a found id prints no SEARCH_HINT line" "$( printf '%s' "$rigOut" | grep -c '^SEARCH_HINT|' )" 0
rigAssert "and the call still ends 0" "$rigRc" 0

## An id Slack will not show this token is REPORTED, with Slack's own reason, and
## never given an origin the call did not read: "outside this workspace or a
## Connect guest" was such a claim, and a reader took it for a fact about them.
rigRun --user-name URIGGONE01
rigAssert "an unknown id is one users.info call, and no directory fetch" "$( rigUsersInfoCalls )|$( rigUsersListCalls )" "1|0"
rigAssert "and it is reported unresolved, in users.info's own words" \
	"$( printf '%s' "$rigOut" | grep -c '^UNRESOLVED|URIGGONE01|users.info refused it: user_not_found$' )" 1
rigAssert "and no row is invented for it" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|' )" 0
rigAssert "and no origin is guessed for it" "$( printf '%s' "$rigOut" | LC_ALL=C grep -c -i -e 'guest' -e 'outside this workspace' )" 0
rigAssert "an unresolved id does not end the call in failure" "$rigRc" 0

## ok:true carrying no user object at all is the same answer, said as one: a row
## is printed only where the answer holds a user id, and never a blank one.
printf '{"ok":true,"user":{}}\n' > "$rigTmp/users-info/URIGEMPTY1"
rigRun --user-name URIGEMPTY1
rigAssert "an answer with no user object is reported unresolved" \
	"$( printf '%s' "$rigOut" | grep -c '^UNRESOLVED|URIGEMPTY1|the users.info answer carried no user object this reader could read$' )" 1
rigAssert "and no blank row is printed for it" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|' )" 0

## The control for the id route: a term that is no id still takes the search, so
## the branch above did not swallow every term. Its counts differ both ways.
printf '{"ok":true,"members":[{"id":"URIGOWNER01","name":"myx","profile":{}}],"response_metadata":{"next_cursor":""}}\n' \
	> "$rigTmp/users-list-pages/page1"
rigRun --user-name myx
rigAssert "a name costs no users.info call" "$( rigUsersInfoCalls )" 0
rigAssert "and one directory fetch, where the match is" "$( rigUsersListCalls )" 1
rigAssert "and it is still found" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|myx|URIGOWNER01|myx|' )" 1

## Both kinds in one call: one users.info for the id, one directory fetch for the
## name, and a row for each -- neither route costs the other anything.
rigRun --user-name URIGPERSON1 --user-name myx
rigAssert "an id and a name together: one users.info and one directory fetch" "$( rigUsersInfoCalls )|$( rigUsersListCalls )" "1|1"
rigAssert "and the id is named from its own lookup" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|URIGPERSON1|URIGPERSON1|' )" 1
rigAssert "and the name from the page" "$( printf '%s' "$rigOut" | grep -c '^USER_MATCH|myx|URIGOWNER01|' )" 1

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
