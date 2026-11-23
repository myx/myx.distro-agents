#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the per-call acceptable age of a cached read (sketch 20261102-refactorings line 53 and line 69: each call
## states its own acceptable TTL, so two callers with different ages share ONE entry). The option is `--ttl <seconds>`, approved
## at 17:33. One entry serves every caller: a caller asking the looser age is served an older entry, and only a caller whose own
## age the entry has passed reaches Slack.
## Held:
##   1. CONTROL: with no age given anywhere, one read reaches Slack and its repeat asks nothing -- the rig drives the cache
##   2. the same two reads at one stated age: the second asks Slack nothing
##   3. a looser age than the first caller's is served from the same entry, asking Slack nothing
##   4. a tighter age past its own bound reaches Slack, and the looser age still serves that entry without a call
##   5. control: two conversations are two entries, so a served read is told from a read that found nothing
## Offline: a Slack-shaped fake curl first on PATH, which counts every call it answers, so a served read is told by the count not
## moving. Each age row reads a DM of its own, so no row's entry decides another's.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
## The rig takes its turn in the machine's one line of test runs and lives in the workspace's own scratch, the way its
## siblings in sh-test/comms do (sh-test/check-fixtures/rig-temp.include.sh).
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsCacheAgePerCallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/cache/comms/slack" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGSELF1=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
## The reading account, kept where the cache reads it, so no call of the fake curl is spent asking who this member is.
printf '%s URIGSELF1\n' "$( date +%s )" > "$rigWs/.local/cache/comms/slack/.user-id-keeper-rig.txt"

## A Slack-shaped fake curl of this check's own: three messages, and every call counted in $rigScn/calls.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigAuth="$( LC_ALL=C sed -n 's/^Authorization: Bearer //p' | head -1 )"
rigMethod="" rigChannel=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		channel@*) [ -f "${rigArg#channel@}" ] && rigChannel="$( cat "${rigArg#channel@}" )" ;;
	esac
done
printf '%s %s\n' "$rigMethod" "$rigChannel" >> "$RIG_SCN/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"DRIGDMOTHER"}}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"user":"URIGOTHER"}}\n' "${rigChannel:-DRIGDMOTHER}" ;;
	conversations.history) printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-FIRST"},{"ts":"1793600000.000002","user":"URIGOTHER","text":"RIG-SECOND"},{"ts":"1793600000.000003","user":"URIGOTHER","text":"RIG-THIRD"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n' ;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## How many conversation reads the fake curl has answered: the fetch a served read spares. Calls of other methods are not
## counted -- a lookup of a sender's name is the tooling's own and moves with the messages, not with the cache.
rigCalls(){ LC_ALL=C grep -c '^conversations.history ' "$rigScn/calls" 2> /dev/null | LC_ALL=C tr -d ' ' ; }
## One --slack-read against the fake curl. Its rc is the read's own and is asserted, never fatal: a row that fails must not hide
## the rows after it.
rigReadRc=0
rigRead(){ ## target [read args...] -- the read's output, its own rc in rigReadRc
	local readTarget="$1"
	shift
	rigReadRc=0
	## MDAT_COMMS_READER=off: no comms thread starts in this rig, so the calls counted are this read's own and no
	## background pull's. Who fills an entry is the thread's own question and another check's.
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig MDAT_COMMS_READER=off MDAT_SLACK_THREAD_CACHE_SECONDS=600 \
		HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_SESSION_ID=rig-session" \
		bash "$rigTools" --slack-read --team-member keeper-rig "$readTarget" "$@" ) 2> "$rigTmp/read.err" || rigReadRc=$?
}
## The cache entry one conversation resolves to, by the cache's own key function: the folder's own name.
rigEntry(){ ## conversation id
	( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" bash -c '. "$1" ; AgentsToolsCommsCacheSlackDir keeper-rig false "$2" || exit 1 ; printf "%s\n" "${agentsCommsCacheDir##*/}"' _ \
		"$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include" "$1" ) 2> /dev/null
}
## Puts an entry's pull moment back by the given seconds, so its age against a caller's own age is a stated number. Only the first
## field of the state file's first line moves: the pointers and the recipe stay as the cache wrote them.
rigAge(){ ## conversation id, seconds old
	local ageEntry ageDir ageWas ageNow
	ageEntry="$( rigEntry "$1" )"
	ageDir="$rigWs/.local/cache/comms/slack/$ageEntry"
	[ -f "$ageDir/.state.txt" ] || return 1
	ageNow=$(( $( date +%s ) - $2 ))
	ageWas="$( LC_ALL=C sed -n 1p "$ageDir/.state.txt" )"
	{
		printf '%s %s\n' "$ageNow" "${ageWas#* }"
		LC_ALL=C sed -n '2,$p' "$ageDir/.state.txt"
	} > "$ageDir/.state.txt.age"
	mv -f "$ageDir/.state.txt.age" "$ageDir/.state.txt"
}

echo "-- 1. CONTROL: with no age named by the call, one read reaches Slack and its repeat asks nothing --"
## The environment's own age is 600 s here, so a loaded machine cannot let the entry expire between two back-to-back reads.
## What each row below states is the CALL's own age, and that is what the option under test carries.
rigRead DRIGDMOTHER --oldest 1 > "$rigTmp/control1.txt"
rigAssert "the control's first read is served" "$rigReadRc" 0
rigCallsAfterFirst="$( rigCalls )"
rigRead DRIGDMOTHER --oldest 1 > "$rigTmp/control2.txt"
rigAssert "the control's first read reached Slack" "$( [ "${rigCallsAfterFirst:-0}" -ge 1 ] && printf asked || printf no-call )" "asked"
rigAssert "and its repeat asked Slack nothing, so a read is served from the cache at all" "$( rigCalls )" "$rigCallsAfterFirst"
rigAssert "and it was served the messages, not an empty answer" "$( LC_ALL=C grep -c -F -e 'RIG-FIRST' -e 'RIG-SECOND' -e 'RIG-THIRD' "$rigTmp/control2.txt" )" 3

echo "-- 5. control: two conversations are two entries --"
rigAssert "the two conversations resolve two entries" "$( [ "$( rigEntry DRIGDMOTHER )" != "$( rigEntry DRIGDMTWO )" ] && printf two || printf one )" two

echo "-- 2. two reads at one stated age: the second asks Slack nothing --"
rigRead DRIGDMONE --oldest 1 --ttl 60 > "$rigTmp/one1.txt"
rigAssert "a read stating its own age is served" "$rigReadRc" 0
rigCallsOne="$( rigCalls )"
rigRead DRIGDMONE --oldest 1 --ttl 60 > "$rigTmp/one2.txt"
rigAssert "the second read at the same age is served, asking Slack nothing" "$( [ "$rigReadRc" = 0 ] && [ "$( rigCalls )" = "$rigCallsOne" ] && printf served-no-call || printf 'rc='"$rigReadRc"-calls="$( rigCalls )" )" "served-no-call"
rigAssert "and it is served the entry the first one filled" "$( LC_ALL=C grep -c -F 'RIG-FIRST' "$rigTmp/one2.txt" )" 1

echo "-- 3. a looser age than the first caller's is served from the same entry --"
rigRead DRIGDMONE --oldest 1 --ttl 600 > "$rigTmp/loose.txt"
rigAssert "the looser age is served, asking Slack nothing" "$( [ "$rigReadRc" = 0 ] && [ "$( rigCalls )" = "$rigCallsOne" ] && printf served-no-call || printf 'rc='"$rigReadRc"-calls="$( rigCalls )" )" "served-no-call"
rigAssert "with the messages the tighter caller's read filled it with" "$( LC_ALL=C grep -c -F 'RIG-FIRST' "$rigTmp/loose.txt" )" 1

echo "-- 4. a tighter age past its own bound reaches Slack, and the looser age still serves the entry --"
## From one entry two callers read: the entry is older than the tight caller's age and younger than the loose one's.
rigAssert "an entry exists to age, from the read at a stated age above" "$( rigAge DRIGDMONE 100 && printf present || printf absent )" present
rigRead DRIGDMONE --oldest 1 --ttl 600 > "$rigTmp/loose2.txt"
rigAssert "the looser caller is still served, asking nothing" "$( [ "$rigReadRc" = 0 ] && [ "$( rigCalls )" = "$rigCallsOne" ] && printf served-no-call || printf 'rc='"$rigReadRc"-calls="$( rigCalls )" )" "served-no-call"
rigAssert "and the entry's age did reach it, so this is the entry and not a fresh read" "$( LC_ALL=C grep -c -F 'RIG-FIRST' "$rigTmp/loose2.txt" )" 1
rigRead DRIGDMONE --oldest 1 --ttl 15 > "$rigTmp/tight.txt"
rigAssert "the tighter caller's read is served" "$rigReadRc" 0
rigCallsTight="$( rigCalls )"
rigAssert "and it reached Slack once, its own age having passed" "$( [ "${rigCallsTight:-0}" -gt "${rigCallsOne:-0}" ] && printf asked || printf served )" "asked"
rigRead DRIGDMONE --oldest 1 --ttl 600 > "$rigTmp/loose3.txt"
rigAssert "then the looser caller is served again with no call, from the entry the tight read refreshed" "$( rigCalls )" "$rigCallsTight"
rigAssert "control: the two ages remain one entry, not one entry each" "$( [ "$( rigEntry DRIGDMONE )" != "$( rigEntry DRIGDMTWO )" ] && printf one-per-conversation || printf one )" one-per-conversation

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_CACHE_AGE_PER_CALL: OK (%s assertions, offline)\n' "$rigPassCount"
