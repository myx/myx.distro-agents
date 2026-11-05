#!/usr/bin/env bash
## Behavioural check on S6.38, the human-owner's ruling: a reaction OUR BOT places is readable and is no event, so it is no
## input to a scan or a Wait. The test is the AUTHOR, U0BT7PCNG7Q on this estate, never the emoji.
## Holds:
##   1. A REACTION THE TOOLING PLACES UNDER THE BOT IDENTITY PUTS THE BOT'S OWN ACCOUNT where the wait reads our accounts:
##      the real reaction operation, on a fake Slack that answers auth.test, writes slack/.user-id-magic-team.txt.
##   2. THE WAIT'S OWN READ CARRIES IT: AgentsToolsWaitOursReactIds answers the accounts of that file and the mention cache.
##   3. THE ARRIVAL IS DROPPED: a rendering whose post holds the bot's eyes reads `-` on the reactions side, and nothing is
##      returned for it.
##   4. CONTROL, BOTH WAYS: a person's eyes on the same post is returned, so the read is proved to work.
## Red before the fix: the file is never written, the id is not in the list, and the bot's eyes comes back as an arrival.
## Offline: a curl first on PATH answers as Slack and opens no socket; every file is this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigReplies="$rigPkg/sh-lib/member/AgentsTools.MemberWaitReplies.include"
rigAwk="$rigPkg/sh-lib/member/AgentsWaitOwnPostReplies.awk"
rigDismiss="$rigPkg/sh-lib/questions/AgentsDismissalMatch.awk"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
[ -f "$rigReplies" ] || rigRefuse "the replies include is not at the origin: $rigReplies"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitBotReactionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## THE RIG'S SLACK: no socket, each method logged, and auth.test answering the bot's own account. The reaction itself is
## answered ok, so the operation takes its success path.
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/cache/comms/slack" "$rigTmp/skills/magic-team"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/magic-team/magic-team.basic.md"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigDir="${0%/*}/.."
rigHeader="$( cat )"
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$rigDir/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	reactions.add|reactions.remove) printf '{"ok":true}\n' ;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## One call of the real tooling in this rig's own tree.
rigRun(){ ## the tool's words...
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" TMPDIR="${TMPDIR:-/tmp}" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-team \
		bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" < /dev/null
}
## The wait's own read of our reacting accounts, over this rig's files.
rigOurs(){
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash -c '. "$1" > /dev/null 2>&1 || exit 9 ; AgentsToolsWaitOursReactIds' rig "$rigReplies" ) 2> /dev/null
}
## One rendering of a thread whose root is the run's own post, holding the reactions named; the reactions side is printed.
rigReactions(){ ## reactions annotation
	local rigFile="$rigTmp/render.$RANDOM"
	printf '1760000000.000001 | URIGSELF |%s ROOT POST\n' "${1:+ $1}" > "$rigFile"
	LC_ALL=C awk -v threadTs="1760000000.000001" -v addressees="all" -v siblingsMax=1000000 -v postTs="1760000000.000001" \
		-v floorTs="1760000000.000001" -v callerName="magic-developer" -v deliver=1 -v side="$rigFile.side" \
		-v oursReactIds="$( rigOurs )" -v callerId="URIGSELF" \
		-f "$rigDismiss" -f "$rigAwk" < "$rigFile" > "$rigFile.out" 2> /dev/null || :
	LC_ALL=C awk '$1 == "reactions" { sub(/^reactions /, "") ; print ; }' "$rigFile.side" 2> /dev/null
}

echo "-- 1. a reaction the tooling places under the bot identity keeps the bot's own account --"
rigRun --slack-react magic-team CRIG00001:1760000000.000001 eyes --identity-bot
rigAssert "the reaction operation succeeded" "$( [ -s "$rigTmp/run.out" ] && printf answered || printf refused )" answered
rigAssert "the bot's own account is kept where the wait reads our accounts" \
	"$( LC_ALL=C awk '$2 ~ /^U[A-Z0-9]+$/ { print $2 }' "$rigWs/.local/cache/comms/slack/.user-id-magic-team.txt" 2> /dev/null )" "URIGBOT01"

echo "-- 2. the wait's own read carries it --"
rigAssert "the accounts the wait reads hold the bot's own" \
	"$( rigOurs | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x 'URIGBOT01' )" 1

echo "-- 3. the bot's eyes on the run's own post is no arrival --"
rigAssert "a reaction only the bot holds reads as nothing to handle" "$( rigReactions '[reactions: eyes x1 (URIGBOT01)]' )" "-"

echo "-- 4. control: a person's eyes is still an arrival --"
rigAssert "a person's reaction is returned" "$( rigReactions '[reactions: eyes x1 (URIGHUM1)]' )" "[reactions: eyes x1 (URIGHUM1)]"
rigAssert "and the bot's beside it leaves the person's alone" \
	"$( rigReactions '[reactions: eyes x1 (URIGHUM1)] [reactions: eyes x1 (URIGBOT01)]' )" "[reactions: eyes x1 (URIGHUM1)]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT BOT REACTION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	printf 'WAIT_BOT_REACTION: FAILED (%d compared, %d assertion(s))\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"
	exit 1
fi
printf 'WAIT_BOT_REACTION: OK (%d assertions, offline)\n' "$rigPassCount"
exit 0
