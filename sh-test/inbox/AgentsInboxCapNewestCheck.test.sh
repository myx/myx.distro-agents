#!/usr/bin/env bash
## Behavioural check on the inbox sections of the session-context scan keeping the NEWEST items (T3, T2). The cap of a section used to keep the
## OLDEST 64 and hide the newest, so a session saw the pile and not the item just filed. Held, in a rig tree of this check's own:
##   1. A SECTION PAST ITS CAP shows the newest 64 items in full, the older ones as one `older:` line each (the next 64 by name, then a count), and
##      says so in its NOTE; a section under its cap is printed as before, with no note and no `older:` line
##   2. A PILE PAST THE LISTING shows the count of what is not listed, never every name
##   3. THE REFLECTIONS SECTION shows the newest 5, each cut at 1 KB, and a count in the note for the older ones, no names
## Red before the change: the newest items are not in the report and the note says OLDEST kept.
## Offline: a failing fake curl stands in for the network; every tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" ] || rigRefuse "the fixture rig-temp.include.sh is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxCapNewestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
rigIncoming="$rigData/inboxes/rig-member/incoming"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigIncoming" "$rigData/board/running" "$rigTmp/bin" "$rigSkills/rig-member"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, extended regex
	LC_ALL=C grep -c -E -- "$2" "$1" 2> /dev/null || :
}
## <prefix> <count> <body bytes> -- files <prefix>-NNN.md, NNN rising with the modification time (a minute apart), so the newest is the highest
rigFill(){
	local rigPrefix="$1" rigN="$2" rigBody="$3" rigI rigName
	rm -f "$rigIncoming"/*.md
	for rigI in $( seq 1 "$rigN" ) ; do
		rigName="$( printf '%s-%03d.md' "$rigPrefix" "$rigI" )"
		{ printf -- '---\ntitle: item %s\n---\n' "$rigI" ; head -c "$rigBody" /dev/zero | tr '\0' 'x' ; printf '\n' ; } > "$rigIncoming/$rigName"
		touch -t "$( printf '202610%02d%02d%02d.00' $(( 1 + rigI / 1440 )) $(( ( rigI / 60 ) % 24 )) $(( rigI % 60 )) )" "$rigIncoming/$rigName"
	done
}
rigScan(){ ## the scan's options
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-session-context-scan "$@"
		' rig rig-member --all-types --no-slack --no-board-related --no-email --no-trello --no-inbox-inquiry --no-inbox-other "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	[ "$rigRc" != 99 ] || rigRefuse "the scan was not contained in the rig tree"
}

echo "-- 1. a section past its cap shows the newest --"
rigFill note 70 40
rigScan --do-inbox-notes --no-inbox-reflections
rigAssert "the scan ran" "$rigRc" "0"
rigAssert "64 items in full" "$( rigCount "$rigTmp/out" '^## inbox/note-[0-9]+\.md$' )" "64"
rigAssert "the newest is shown and the oldest is not shown in full" "$( rigCount "$rigTmp/out" '^## inbox/note-070\.md$' ):$( rigCount "$rigTmp/out" '^## inbox/note-001\.md$' )" "1:0"
rigAssert "the 6 older are named, one line each, the oldest among them" "$( rigCount "$rigTmp/out" '^older: inbox/note-[0-9]+\.md$' ):$( rigCount "$rigTmp/out" '^older: inbox/note-001\.md$' )" "6:1"
rigAssert "the note says what was cut and which end was kept" "$( rigCount "$rigTmp/out" '^\*\*NOTE:\*\* truncated -- 70 items found, capped at 64 -- NEWEST kept in full, 6 older not shown in full$' )" "1"
rigFill note 30 40
rigScan --do-inbox-notes --no-inbox-reflections
rigAssert "a section under its cap is as before: 30 in full, no older line, no truncation note" "$( rigCount "$rigTmp/out" '^## inbox/note-' ):$( rigCount "$rigTmp/out" '^older:' ):$( rigCount "$rigTmp/out" 'truncated --' )" "30:0:0"

echo "-- 2. a pile past the listing is counted --"
rigFill note 150 40
rigScan --do-inbox-notes --no-inbox-reflections
rigAssert "64 in full, 64 older named, the rest counted" "$( rigCount "$rigTmp/out" '^## inbox/note-' ):$( rigCount "$rigTmp/out" '^older: inbox/note-' ):$( rigCount "$rigTmp/out" '^older: \(\+22 more, not listed\)$' )" "64:64:1"
rigAssert "the newest of the 150 is shown" "$( rigCount "$rigTmp/out" '^## inbox/note-150\.md$' )" "1"

echo "-- 3. reflections: the newest few, cut small, the rest counted --"
rigFill reflection 9 3000
rigScan --no-inbox-notes --do-inbox-reflections
rigAssert "5 reflections in full, the newest among them" "$( rigCount "$rigTmp/out" '^## inbox/reflection-' ):$( rigCount "$rigTmp/out" '^## inbox/reflection-009\.md$' ):$( rigCount "$rigTmp/out" '^## inbox/reflection-004\.md$' )" "5:1:0"
rigAssert "each body cut at 1 KB" "$( rigCount "$rigTmp/out" '^body-truncated: [0-9]+ bytes stored, capped at 1024 -- ' )" "5"
rigAssert "the older are a count in the note, with no names" "$( rigCount "$rigTmp/out" '^\*\*NOTE:\*\* truncated -- 9 items found, capped at 5 -- NEWEST kept in full, 4 older not shown in full$' ):$( rigCount "$rigTmp/out" '^older:' )" "1:0"
rigFill reflection 3 3000
rigScan --no-inbox-notes --do-inbox-reflections
rigAssert "3 reflections are all shown, cut at 1 KB, with no note" "$( rigCount "$rigTmp/out" '^## inbox/reflection-' ):$( rigCount "$rigTmp/out" 'truncated --' )" "3:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX CAP NEWEST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_CAP_NEWEST: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
