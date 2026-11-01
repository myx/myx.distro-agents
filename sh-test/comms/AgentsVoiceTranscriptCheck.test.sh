#!/usr/bin/env bash
## Behavioural check on sketch 12.1b, epic S11 item 3: a voice message in Slack is read into text by the speech-to-text part of
## setup.feature-local-ai where it is installed, and stays marked untranscribed where it is not.
## Drives the real read path (--slack-read through DistroAgentsTools.fn.sh) against a fake curl, so the file's bytes are fetched from
## files.info's own url_private and the words come from the feature's own `transcribe` command. Offline by construction: the fake curl
## is first on PATH, and the feature's command is a stand-in under a rig origin.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsVoiceTranscriptCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigScenario"
cp "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/voice-read.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
RIG_SCENARIO="$rigScenario"
export RIG_SCENARIO
: > "$rigScenario/calls"

## The member the read acts as: a folder under this rig's skillset root, and the bot token of the identity that reads.
mkdir -p "$rigWs/.local/agents/members/keeper-myx"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigWs/.local/agents/members/keeper-myx/keeper-myx.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token\n' > "$rigWs/.local/.agents/magic-team.agent.env"
MDAT_SKILLSET_ROOT="$rigWs/.local/agents/members" ; export MDAT_SKILLSET_ROOT

## The conversation: one voice clip, then one message carrying an ordinary file. The clip's bytes are the download's answer.
## One line, as Slack answers: AgentsSlackMessagesFormat.awk reads one single-line response.
printf '%s\n' '{"ok":true,"messages":[{"ts":"1700000002.000200","user":"UVOICEPERSON","text":"a plain message","files":[{"id":"FPLAIN01","name":"notes.txt","size":24,"mimetype":"text/plain","url_private":"https://files.slack.com/FPLAIN01","url_private_download":"https://files.slack.com/FPLAIN01"}]},{"ts":"1700000001.000100","user":"UVOICEPERSON","text":"","files":[{"id":"FVOICE01","name":"clip.m4a","size":24,"mimetype":"audio/mp4","mode":"voice","url_private":"https://files.slack.com/FVOICE01","url_private_download":"https://files.slack.com/FVOICE01"}]}],"has_more":false}' \
	> "$rigScenario/history.C0RIG0001.json"
for rigFile in FVOICE01 FPLAIN01 ; do
	printf '{"ok":true,"file":{"id":"%s","name":"%s","size":24,"mimetype":"%s","url_private":"https://files.slack.com/%s","url_private_download":"https://files.slack.com/%s"}}\n' \
		"$rigFile" x "$( [ "$rigFile" = "FVOICE01" ] && printf 'audio/mp4' || printf 'text/plain' )" "$rigFile" "$rigFile" \
		> "$rigScenario/file.$rigFile.json"
done
## A thread whose parent carries the same voice clip: a thread read is rendered by the comms cache, not by the read operation, and
## that is the second of the three renderers the one function now serves.
printf '%s\n' '{"ok":true,"messages":[{"ts":"1700000003.000300","user":"UVOICEPERSON","text":"","thread_ts":"1700000003.000300","files":[{"id":"FVOICE02","name":"thread-clip.m4a","size":24,"mimetype":"audio/mp4","mode":"voice","url_private":"https://files.slack.com/FVOICE02","url_private_download":"https://files.slack.com/FVOICE02"}]}]}' \
	> "$rigScenario/replies.C0RIG0001.1700000003.000300.json"
printf '%s\n' '{"ok":true,"file":{"id":"FVOICE02","name":"thread-clip.m4a","size":24,"mimetype":"audio/mp4","url_private":"https://files.slack.com/FVOICE02","url_private_download":"https://files.slack.com/FVOICE02"}}' \
	> "$rigScenario/file.FVOICE02.json"

## Exactly the 24 bytes both files.info answers declare: the fetch refuses a body of any other length.
printf '%s' '0123456789abcdefghijklmn' > "$rigScenario/clip.bin"

## Two origins: one where the local AI feature is installed (its transcribe is a stand-in that logs its every call), and one where it is not.
rigOriginIn="$rigTmp/origin-in"
rigOriginOut="$rigTmp/origin-out"
mkdir -p "$rigOriginIn/myx" "$rigOriginOut/myx"
## Each rig origin holds the package under test and every package beside it, but never mdci-packages-myx: whether the local AI feature
## is installed there is the one thing the two origins differ in.
for rigSibling in "$rigOrigin/myx"/* ; do
	rigSiblingName="${rigSibling##*/}"
	case "$rigSiblingName" in mdci-packages-myx) continue ;; esac
	rigCopyTree "$rigSibling" "$rigOriginIn/myx/$rigSiblingName" || rigRefuse "the rig origin could not be copied: $rigSiblingName"
	rigCopyTree "$rigSibling" "$rigOriginOut/myx/$rigSiblingName" || rigRefuse "the rig origin could not be copied: $rigSiblingName"
done
mkdir -p "$rigOriginIn/myx/mdci-packages-myx/setup.feature-local-ai/data/local-ai"
cat > "$rigOriginIn/myx/mdci-packages-myx/setup.feature-local-ai/data/local-ai/mdci-local-ai" <<'RIGFEATURE'
#!/bin/sh
printf '%s\n' "$*" >> "$RIG_FEATURE_LOG"
printf '{"text": " these are the rig clip words"}\n'
RIGFEATURE
RIG_FEATURE_LOG="$rigScenario/feature.calls"
export RIG_FEATURE_LOG
: > "$RIG_FEATURE_LOG"

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigHas(){ ## text, literal substring -- yes or no
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}
## One read with the read cache off (MDAT_SLACK_THREAD_CACHE_SECONDS=0), so every case reads Slack again and what the rendering
## carries is the work of this pass, never a rendering some earlier read left in a cache.
rigRead(){ ## origin -- one read of the conversation, as the member, its rendering on stdout
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
		MDAT_TEAM_MEMBER=keeper-myx MDAT_SLACK_THREAD_CACHE_SECONDS=0 MMDAPP="$rigWs" MDLT_ORIGIN="$1" \
		bash "$1/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --slack-read C0RIG0001 2> "$rigTmp/stderr" )
}
## One thread rendered by the comms cache itself -- the second of the three renderers the one function serves, driven where the Wait
## drives it. The rendering lands in the file given; the cache's own folder is the rig workspace's.
rigCacheThread(){ ## origin, channel:ts, rendering file
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
		MDAT_TEAM_MEMBER=keeper-myx MMDAPP="$rigWs" MDLT_ORIGIN="$1" \
		bash -c '. "$1/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include" ; AgentsToolsCommsCacheSlackThread keeper-myx "$2" "$3" false "$( date +%s )"' _ "$1" "$2" "$3" 2> "$rigTmp/stderr" )
}
rigCount(){ ## file, literal substring
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

rigOut="$( rigRead "$rigOriginIn" )" || rigOut="$rigOut"
LC_ALL=C grep -q '^conversations.history ' "$rigScenario/calls" \
	|| rigRefuse "the conversation was never read through the fake curl, so nothing below would be measured"

echo "-- a voice message, where the local AI feature is installed --"
rigAssert "the clip is read into text, in the place its file annotation stood" \
	"$( rigHas "$rigOut" '[voice transcript: these are the rig clip words]' )" yes
rigAssert "the clip's own file annotation is gone, not left beside the words" \
	"$( rigHas "$rigOut" '[file: FVOICE01' )" no
rigAssert "the words come out on the line of that message, behind its ts and sender" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^1700000001\.000100 | UVOICEPERSON | \[voice transcript: these are the rig clip words\]' )" 1
rigAssert "the clip's bytes came from files.info's own download url, once" \
	"$( rigCount "$rigScenario/calls" 'download https://files.slack.com/FVOICE01' )" 1
rigAssert "the speech-to-text command was asked for that one clip, once" \
	"$( rigCount "$RIG_FEATURE_LOG" 'transcribe' )" 1
rigAssert "a message carrying an ordinary file keeps its file annotation" \
	"$( rigHas "$rigOut" '[file: FPLAIN01' )" yes
rigAssert "...and that file is never fetched to be read out" \
	"$( rigCount "$rigScenario/calls" 'files.info FPLAIN01' )" 0

echo "-- the same clip a second time costs no fetch and no speech call --"
: > "$RIG_FEATURE_LOG"
rigOut="$( rigRead "$rigOriginIn" )" || rigOut="$rigOut"
rigAssert "the words are there again" "$( rigHas "$rigOut" '[voice transcript: these are the rig clip words]' )" yes
rigAssert "the clip is not fetched again" "$( rigCount "$rigScenario/calls" 'download https://files.slack.com/FVOICE01' )" 1
rigAssert "the speech-to-text command is not asked again" "$( rigCount "$RIG_FEATURE_LOG" 'transcribe' )" 0

echo "-- a thread: the comms cache's own renderer, through the same one function --"
## The words of the conversation's clip are cleared first, so a transcript below can only be this read's own work.
rm -rf "$rigWs/.local/agents/schedule/voice"
: > "$RIG_FEATURE_LOG"
rigCacheThread "$rigOriginIn" 'C0RIG0001:1700000003.000300' "$rigTmp/thread.rendered" || rigRefuse "the comms cache could not render the thread"
rigOut="$( cat "$rigTmp/thread.rendered" )"
rigAssert "the thread parent's clip is read into text too" "$( rigHas "$rigOut" '[voice transcript: these are the rig clip words]' )" yes
rigAssert "...its file annotation gone as on the conversation's line" "$( rigHas "$rigOut" '[file: FVOICE02' )" no
rigAssert "...and the speech-to-text command was asked for it" "$( rigCount "$RIG_FEATURE_LOG" 'transcribe' )" 1

echo "-- where the feature is not installed, the message stays marked untranscribed --"
## The words of a clip that was transcribed by the case above are kept for the member, so this case starts without them.
rm -rf "$rigWs/.local/agents/schedule/voice"
: > "$rigScenario/calls"
rigOut="$( rigRead "$rigOriginOut" )" || rigOut="$rigOut"
rigAssert "the message is marked untranscribed" "$( rigHas "$rigOut" '[voice: untranscribed]' )" yes
rigAssert "no words are claimed for it" "$( rigHas "$rigOut" '[voice transcript:' )" no
rigAssert "nothing was fetched for a clip that could not be read anyway" \
	"$( rigCount "$rigScenario/calls" 'download https://files.slack.com/FVOICE01' )" 0
rigAssert "and the plain file is still named as a file" "$( rigHas "$rigOut" '[file: FPLAIN01' )" yes

echo "-- one line says why, where the reason is not in the rendering --"
rigAssert "the untranscribed reason names the feature that is not installed" \
	"$( LC_ALL=C grep -c 'setup.feature-local-ai is not installed on this machine' "$rigTmp/stderr" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ VOICE TRANSCRIPT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'VOICE_TRANSCRIPT: OK (%d assertions, offline, curl never reached Slack)\n' "$rigPasses"
