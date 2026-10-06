#!/usr/bin/env bash
## Behavioural check on the Slack mention-id cache ($MMDAPP/.local/.agents/slack-mention-ids.cache), run rather than
## read, against a scenario workspace built here. A row is member=id and, once completed, member=id=handle=real name=
## display name=workspace domain, the account columns coming from one read-only users.info call. Holds: a fresh
## resolution writes the full row after exactly auth.test and users.info, with "=" and a backslash stripped from a value;
## an old member=id row is read unchanged and completed by exactly one users.info call, once; a member=- row gets no
## call; a users.info that answers ok:false leaves a complete row of "-" and is not asked again; the human-owner row is
## completed under the persona member's token; the old reader, `awk -F= '$1 == who { c = $2 }'`, still gives the id on
## every row shape and the file stays mode 600; the find-by-name function reads the cache and nothing else. A fake `curl`
## first on PATH answers auth.test and a stubbed users.info. Offline by construction; no real Slack call.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigInclude="$rigHere/AgentsTools.MemberCommsSlack.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigInclude" ] || rigRefuse "the Slack include is not at: $rigInclude"
rigTmp="$( mktemp -d -t AgentsSlackMentionIdCacheCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigData="$rigTmp/data" ; rigHome="$rigTmp/home"
mkdir -p "$rigTmp/bin" "$rigHome"
cp "$rigTest/check-fixtures/slack-mention-id-cache-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-mention-id-cache-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigCache="$rigWs/.local/.agents/slack-mention-ids.cache"
rigIdle="4294967295 0"
rigDomain="rig.example"
rigWorld(){ ## -- a fresh workspace: tokens for three members, the human-owner id, the team domain, an empty cache
	rm -rf "$rigWs" "$rigData"
	mkdir -p "$rigWs/.local/.agents" "$rigData/inboxes/magic-coordinator" "$rigTmp/skills"
	printf 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_WORKSPACE_DOMAIN=%s\n' "$rigDomain" > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-MVANE\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-OTHER\n' > "$rigWs/.local/.agents/client-x.agent.env"
	printf '{"ok":true,"user":{"name":"mvane","real_name":"Magic \\"Vane\\" a=b","profile":{"display_name":"Magic V"}}}\n' > "$rigTmp/users-info.json"
	rm -f "$rigTmp/users-info-fail"
	: > "$rigTmp/calls"
}
rigCacheWrite(){ ## rows... -- the cache holding the idle lock generation and these rows
	{ printf '%s\n' "$rigIdle" ; printf '%s\n' "$@" ; } > "$rigCache"
	chmod 600 "$rigCache"
}
rigCall(){ ## function and arguments... -- one cache function in a fresh shell over the real tooling; its stdout in $rigTmp/fn.out
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigData" RIG_TOOL="$rigTool" RIG_INCLUDE="$rigInclude" \
		bash -c '
			. "$RIG_TOOL"
			MDSC_CMD=rig
			rigArgs=( "$@" )
			set -- --rig-none ; . "$RIG_INCLUDE" > /dev/null 2>&1
			"${rigArgs[@]}"
		' rig "$@" ) > "$rigTmp/fn.out" 2> "$rigTmp/fn.err" < /dev/null
}
rigCalls(){ ## -- the Slack calls made since the world was built, one per line, method and token
	LC_ALL=C tr '\n' '|' < "$rigTmp/calls"
}
rigRows(){ ## -- the cache rows after the header, joined
	LC_ALL=C tail -n +2 "$rigCache" | LC_ALL=C tr '\n' '|'
}
rigMode(){ ## path
	LC_ALL=C ls -l "$1" | LC_ALL=C awk '{ print substr($1, 1, 10) }'
}
rigOldReader(){ ## member -- the reader this cache had before the columns
	LC_ALL=C awk -F= -v who="$1" '$1 == who { c = $2 } END { print c }' "$rigCache"
}

rigWorld
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
[ "$( cat "$rigTmp/fn.out" )" = "URIGMVANE" ] || rigRefuse "the cache function did not answer through this rig: $( LC_ALL=C grep -v '^SystemContext\|^AgentsContext' "$rigTmp/fn.err" | head -2 | LC_ALL=C tr '\n' ' ' )"

echo "-- 1. a fresh resolution writes the full row --"
rigWorld
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "the id is answered"                                           "$( cat "$rigTmp/fn.out" )" URIGMVANE
rigAssert "exactly auth.test, then users.info, both under the member's token" "$( rigCalls )" "auth.test rig-user-token-MVANE|users.info rig-user-token-MVANE|"
rigAssert "the row has the id, handle, real name, display name and domain; = and a backslash are stripped" "$( rigRows )" "keeper-myx=URIGMVANE=mvane=Magic \"Vane\" ab=Magic V=$rigDomain|"
rigAssert "the cache stays mode 600"                                     "$( rigMode "$rigCache" )" "-rw-------"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "control: a second read answers from the cache, no further call" "$( cat "$rigTmp/fn.out" ) $( rigCalls )" "URIGMVANE auth.test rig-user-token-MVANE|users.info rig-user-token-MVANE|"

echo "-- 2. an old member=id row is read unchanged and completed once --"
rigWorld
rigCacheWrite "keeper-myx=URIGKEEPER" "client-x=URIGOTHERX" "nobody=-"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "the id comes out unchanged"                                   "$( cat "$rigTmp/fn.out" )" URIGKEEPER
rigAssert "the row is completed by exactly one users.info call, under that member's token and no auth.test" "$( rigCalls )" "users.info rig-user-token-MVANE|"
rigAssert "the completed row keeps its id and gains the columns"         "$( LC_ALL=C grep '^keeper-myx=' "$rigCache" )" "keeper-myx=URIGKEEPER=mvane=Magic \"Vane\" ab=Magic V=$rigDomain"
rigAssert "the other rows are untouched"                                 "$( LC_ALL=C grep -v '^keeper-myx=' "$rigCache" | LC_ALL=C tail -n +2 | LC_ALL=C tr '\n' '|' )" "client-x=URIGOTHERX|nobody=-|"
: > "$rigTmp/calls"
rigCall AgentsToolsCommsSlackMentionUserId nobody
rigAssert "a member=- row gets no call and no id"                        "id=[$( cat "$rigTmp/fn.out" )] calls=[$( rigCalls )]" "id=[] calls=[]"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "a second read of the completed row makes no call"             "$( cat "$rigTmp/fn.out" ) $( rigCalls )" "URIGKEEPER "
rigCall AgentsToolsCommsSlackMentionUserId client-x
rigAssert "another old row is completed by one call of its own"          "$( cat "$rigTmp/fn.out" ) $( rigCalls )" "URIGOTHERX users.info rig-user-token-OTHER|"

echo "-- 3. the old reader, byte for byte, and the mode --"
rigAssert "the old reader gives the id on a completed row"               "$( rigOldReader keeper-myx )" URIGKEEPER
rigAssert "and on a row that was never completed, an old row beside it"   "$( rigWorld ; rigCacheWrite "a=UA" "b=UB=h=n=d=x" "c=-" ; rigOldReader a )" UA
rigAssert "and on a new row"                                             "$( rigOldReader b )" UB
rigAssert "and on a - row"                                               "$( rigOldReader c )" "-"
rigWorld ; rigCacheWrite "keeper-myx=URIGKEEPER" ; chmod 644 "$rigCache"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "the cache file ends mode 600 after a backfill, whatever it was"  "$( rigMode "$rigCache" )" "-rw-------"

echo "-- 4. a users.info that answers ok:false --"
rigWorld ; : > "$rigTmp/users-info-fail" ; rigCacheWrite "keeper-myx=URIGKEEPER"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "the id still comes out"                                       "$( cat "$rigTmp/fn.out" )" URIGKEEPER
rigAssert "the row ends with a complete set of -"                        "$( LC_ALL=C grep '^keeper-myx=' "$rigCache" )" "keeper-myx=URIGKEEPER=-=-=-=$rigDomain"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "it is not asked again: one users.info call in all"            "$( LC_ALL=C grep -c '^users.info' "$rigTmp/calls" || : )" 1
rigWorld ; rigCacheWrite "keeper-myx=URIGKEEPER"
rigCall AgentsToolsCommsSlackMentionUserId keeper-myx
rigAssert "sibling: the same old row with users.info answering is completed with the real columns" "$( LC_ALL=C grep '^keeper-myx=' "$rigCache" )" "keeper-myx=URIGKEEPER=mvane=Magic \"Vane\" ab=Magic V=$rigDomain"

echo "-- 5. the human-owner row --"
rigWorld
rigCall AgentsToolsCommsSlackMentionUserId human-owner
rigAssert "the owner's id is answered, from the configured target"       "$( cat "$rigTmp/fn.out" )" URIGOWNER
rigAssert "the users.info call is made under the persona member's token, never as the owner" "$( rigCalls )" "users.info rig-user-token-COORD|"
rigAssert "the row carries the columns"                                  "$( LC_ALL=C grep '^human-owner=' "$rigCache" )" "human-owner=URIGOWNER=mvane=Magic \"Vane\" ab=Magic V=$rigDomain"
rigWorld ; rigCacheWrite "human-owner=URIGOWNER"
rigCall AgentsToolsCommsSlackMentionUserId human-owner
rigAssert "an old human-owner row is completed under the persona member's token too" "$( cat "$rigTmp/fn.out" ) $( rigCalls )" "URIGOWNER users.info rig-user-token-COORD|"

echo "-- 6. finding a person by name --"
rigWorld
rigCacheWrite "a=UA=mvane=Magic Vane=Magic V=d" "b=UB=-=-=-=d" "c=UC" "d=-" "e=UE=other=Other One=O=d" "f=UF=shortrow"
rigAssert "the handle, any case: member TAB id"                          "$( rigCall AgentsToolsCommsSlackMentionFindByName MVANE ; LC_ALL=C tr '\t' '>' < "$rigTmp/fn.out" )" "a>UA"
rigAssert "the display name, any case"                                   "$( rigCall AgentsToolsCommsSlackMentionFindByName 'magic v' ; LC_ALL=C tr '\t' '>' < "$rigTmp/fn.out" )" "a>UA"
rigAssert "the real name, any case"                                      "$( rigCall AgentsToolsCommsSlackMentionFindByName 'MAGIC VANE' ; LC_ALL=C tr '\t' '>' < "$rigTmp/fn.out" )" "a>UA"
rigAssert "a name nobody has finds nothing"                              "$( rigCall AgentsToolsCommsSlackMentionFindByName nobody-here ; cat "$rigTmp/fn.out" )" ""
rigAssert "a row without columns never matches, nor does a - row, by the member's own name" "$( rigCall AgentsToolsCommsSlackMentionFindByName c ; cat "$rigTmp/fn.out" ) $( rigCall AgentsToolsCommsSlackMentionFindByName d ; cat "$rigTmp/fn.out" )" " "
rigAssert "a row with too few columns never matches, even where a column holds the name"   "$( rigCall AgentsToolsCommsSlackMentionFindByName shortrow ; cat "$rigTmp/fn.out" )" ""
rigAssert "a partial name does not match"                                "$( rigCall AgentsToolsCommsSlackMentionFindByName magic ; cat "$rigTmp/fn.out" )" ""
rigAssert "it reads the cache and nothing else: no Slack call was made"  "$( rigCalls )" ""
rigAssert "the include holds the function in a few lines on the cache alone: lines between its heading and its closing brace" "$( LC_ALL=C awk '/^AgentsToolsCommsSlackMentionFindByName\(\)/ { on = 1 } on { n++ } on && /^}/ { print n ; exit }' "$rigInclude" )" 3

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK MENTION ID CACHE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_MENTION_ID_CACHE: OK (%d assertions, offline)\n' "$rigPasses"
