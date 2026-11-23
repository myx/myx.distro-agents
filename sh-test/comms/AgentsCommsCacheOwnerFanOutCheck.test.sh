#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the human-owner fan-out's cache use (sketch 20261102-refactorings lines 53 and 69: the cache is keyed by
## the real channel id, and the macros resolve above it). The fan-out reads both of the human-owner's DMs, one per identity
## (AgentsTools.CommsSlack.include, the `human-owner` arm), and until this work it went whole to Slack and kept nothing.
## Held:
##   1. CONTROL: a plain DM-id read asks Slack once and its repeat asks nothing, and two DM ids are two entries -- so this check is
##      not passing because nothing drove the cache at all
##   2. a read of `human-owner` registers interest in BOTH DMs it resolved, one mark per DM, each named for that DM id and the
##      account that read it, so the comms thread knows to fill both entries
##   3. a read of the concrete DM id resolves to the entry the macro read registered, so the macro and the DM id are one folder
## What the read does to an entry's contents is not asserted here. Who fills an entry is the comms thread's own question, and
## epic ruling 14 makes it the thread's alone (a reader never fetches from a service itself).
## Offline: a Slack-shaped fake curl first on PATH, which counts every call it answers. Each identity has a DM id of its own, so
## each leg of the fan-out has one to resolve.
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
rigTmp="$( rigTempDir AgentsCommsCacheOwnerFanOutCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/cache/comms/slack" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGSELF1=m=M=M=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
## The reading account, kept where the cache reads it (a day's file per member), so no call of the fake curl is spent asking who
## this member is.
printf '%s URIGSELF1\n' "$( date +%s )" > "$rigWs/.local/cache/comms/slack/.user-id-keeper-rig.txt"

## A Slack-shaped fake curl of this check's own. The token on the request says which identity is reading, so each identity has a DM
## of its own to open -- the two legs of the fan-out need exactly that. Every call is counted in $rigScn/calls.
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
printf '%s %s %s\n' "$rigMethod" "$rigChannel" "$rigAuth" >> "$RIG_SCN/calls"
case "$rigAuth" in
	rig-user-token-RIG) rigDm=DRIGDMUSER ;;
	rig-bot-token-TEAM) rigDm=DRIGDMBOT ;;
	*)                  rigDm=DRIGDMOTHER ;;
esac
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.open) printf '{"ok":true,"channel":{"id":"%s"}}\n' "$rigDm" ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"user":"URIGOWNER"}}\n' "${rigChannel:-$rigDm}" ;;
	conversations.history) printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOWNER","text":"RIG-FIRST"},{"ts":"1793600000.000002","user":"URIGOWNER","text":"RIG-SECOND"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n' ;;
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
## One --slack-read, its own cache, and the fake curl first on PATH. Its stderr is kept, so a refusal is read rather than guessed.
rigRead(){ ## target [read args...] -- the read's output
	local readTarget="$1"
	shift
	## MDAT_COMMS_READER=off: no comms thread starts in this rig, so the calls counted are this read's own and no
	## background pull's. Who fills an entry is the thread's own question and another check's.
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig MDAT_COMMS_READER=off HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_SESSION_ID=rig-session" \
		bash "$rigTools" --slack-read --team-member keeper-rig "$readTarget" "$@" ) 2> "$rigTmp/read.err"
}
## The cache's interest marks, one line each, named as the mark file is named.
rigMarks(){
	( cd "$rigWs/.local/cache/comms/.interest" 2> /dev/null && for rigOne in * ; do case "$rigOne" in *'*') continue ;; esac ; [ -f "$rigOne" ] && printf '%s\n' "$rigOne" ; done ) | LC_ALL=C sort
}
## Whether an entry holds a message yet: the control's own read is asserted to have stored what Slack answered, so a cache that
## kept nothing is told from one that kept the messages.
rigFilled(){ ## entry name
	if [ -z "$1" ] || [ ! -d "$rigWs/.local/cache/comms/slack/$1" ] ; then printf 'absent\n' ; return ; fi
	LC_ALL=C grep -q 'RIG-FIRST' "$rigWs/.local/cache/comms/slack/$1"/*/messages.txt 2> /dev/null && printf 'filled\n' || printf 'empty\n'
}
## The cache entry a member's own read of a conversation resolves to, by the cache's own key function: the folder's own name.
rigKey(){ ## conversation id
	( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" bash -c '. "$1" ; AgentsToolsCommsCacheSlackDir keeper-rig false "$2" || exit 1 ; printf "%s\n" "${agentsCommsCacheDir##*/}"' _ \
		"$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include" "$1" ) 2> /dev/null
}

echo "-- 1. CONTROL: a plain DM-id read asks Slack once, its repeat asks nothing, and two DM ids are two entries --"
rigRead DRIGDMOTHER --oldest 1 > "$rigTmp/control1.txt" || rigRefuse "the control's own first read failed; see $rigTmp/read.err"
rigCallsAfterFirst="$( rigCalls )"
rigRead DRIGDMOTHER --oldest 1 > "$rigTmp/control2.txt" || rigRefuse "the control's own second read failed; see $rigTmp/read.err"
rigAssert "the control's first read reached Slack" "$( [ "${rigCallsAfterFirst:-0}" -ge 1 ] && printf asked || printf no-call )" "asked"
rigAssert "and its repeat inside the age asked Slack nothing" "$( rigCalls )" "$rigCallsAfterFirst"
rigAssert "the control's read left its entry, and one entry only" "$( rigFilled 'slack-URIGSELF1-DRIGDMOTHER' )" "filled"
rigAssert "control: the two DM ids are two entries, so the key is no single name" "$( [ "$( rigKey DRIGDMOTHER )" != "$( rigKey DRIGDMBOT )" ] && printf two || printf one )" two

echo "-- 2. a read of human-owner registers interest in BOTH DMs it resolved --"
## The control's own mark is cleared, so the marks judged below are the fan-out's and no other.
rm -rf "$rigWs/.local/cache/comms/.interest"
rigRead human-owner --oldest 1 > "$rigTmp/owner.txt"
rigOwnerRc=$?
printf '# this check does not judge whether the human-owner read is served: the read path has its own check. rc was %s\n' "$rigOwnerRc"
rigAssert "the fan-out resolved and read both of his DMs, one per identity" "$( LC_ALL=C grep -c '^## dm=DRIGDM' "$rigTmp/owner.txt" )" 2
rigAssert "a mark is kept for the DM the user identity reads" "$( rigMarks | LC_ALL=C grep -c 'DRIGDMUSER' )" 1
rigAssert "and one for the DM the bot identity reads" "$( rigMarks | LC_ALL=C grep -c 'DRIGDMBOT' )" 1
rigAssert "the user identity's mark names that DM id and the account that read it" "$( rigMarks | LC_ALL=C grep 'DRIGDMUSER' | head -1 )" "slack-URIGSELF1-DRIGDMUSER"
rigAssert "and the bot identity's names the bot as its account" "$( rigMarks | LC_ALL=C grep 'DRIGDMBOT' | head -1 )" "slack-bot-DRIGDMBOT"
rigAssert "so the marks are those two and no other" "$( rigMarks | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 2
rigAssert "and none is named for the macro itself" "$( rigMarks | LC_ALL=C grep -c 'human-owner' )" 0

echo "-- 3. a read of the concrete DM id resolves to the entry the macro read registered --"
rigAssert "the DM id's own cache entry is the name the macro read marked" "$( rigKey DRIGDMUSER )" "$( rigMarks | LC_ALL=C grep 'DRIGDMUSER' | head -1 )"
rigAssert "and the other leg's DM id resolves to its own entry, so the two are two" "$( [ "$( rigKey DRIGDMUSER )" != "$( rigKey DRIGDMBOT )" ] && printf two || printf one )" two
rigAssert "neither entry is named for the macro or for a member's own name" "$( rigMarks | LC_ALL=C grep -c -e 'human-owner' -e 'keeper-rig' )" 0

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_CACHE_OWNER_FAN_OUT: OK (%s assertions, offline)\n' "$rigPassCount"
