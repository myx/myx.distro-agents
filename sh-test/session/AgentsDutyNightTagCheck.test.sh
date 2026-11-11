#!/usr/bin/env bash
## Out of its flags a member is started by a person's tag alone. A tag that another member's message made (a message carrying `[sender: <member>]`)
## is kept as the member's tag but not as a person's, so the team's own talk at night starts no duty and spends no budget. Held, run and not read:
##   1. A TAG OF A PERSON is kept in tags-person/<member> as well as tags/<member>; a tag of a member's message only in tags/<member>.
##   2. THE NEWS OUT OF FLAGS reads tags-person: a tag only a member made is no news there, a person's is, and one older than the member's pointer is not.
##   3. THE NEWS WITHIN FLAGS reads tags, as before: a member's tag is news there.
## Offline: the functions are sourced over a folder of the rig's own, and nothing is started or read from Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyNightTagCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/schedule" "$rigTmp/home" "$rigTmp/skills"
rigDir="$rigWs/.local/agents/schedule"
rigFn(){ ## the function and its arguments... -- run in the loop's include; prints its rc as yes or no
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" ${RIG_SUB:+RIG_SUB=$RIG_SUB} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			[ -z "${RIG_SUB:-}" ] || agentsScheduleTagsSub="$RIG_SUB"
			"$@"
		' rig "$@" > /dev/null 2>&1 && printf yes || printf no
}
rigNews(){ ## member, "human" for the out-of-flags read
	if [ "${2:-}" = human ] ; then [ "$( RIG_SUB=tags-person rigFn AgentsToolsScheduleTagNews "$1" )" = yes ] && printf news || printf none
	else [ "$( rigFn AgentsToolsScheduleTagNews "$1" )" = yes ] && printf news || printf none ; fi
}
echo "-- 1. what is kept --"
rigFn AgentsToolsScheduleTagNote keeper-a 1794300000.000100 "" > /dev/null
rigAssert "a member's message: tags kept, tags-person not" "$( cat "$rigDir/tags/keeper-a" ) $( [ -e "$rigDir/tags-person/keeper-a" ] && printf has || printf none )" "1794300000.000100 none"
rigFn AgentsToolsScheduleTagNote keeper-b 1794300001.000100 1794300001.000100 > /dev/null
rigAssert "a person's message: both kept" "$( cat "$rigDir/tags/keeper-b" ) $( cat "$rigDir/tags-person/keeper-b" )" "1794300001.000100 1794300001.000100"
rigFn AgentsToolsScheduleTagNote keeper-b 1794300009.000100 "" > /dev/null
rigAssert "a later member's message moves tags, not tags-person" "$( cat "$rigDir/tags/keeper-b" ) $( cat "$rigDir/tags-person/keeper-b" )" "1794300009.000100 1794300001.000100"
echo "-- 2. out of flags --"
rigAssert "only a member made the tag: no news out of flags" "$( rigNews keeper-a human )" none
rigAssert "a person made a tag: news out of flags" "$( rigNews keeper-b human )" news
mkdir -p "$rigDir/handed" ; printf '1794300001.000100\n' > "$rigDir/handed/keeper-b"
rigAssert "the person's tag is not newer than the pointer: no news" "$( rigNews keeper-b human )" none
echo "-- 3. within flags --"
rigAssert "a member's tag is news within flags" "$( rigNews keeper-a )" news
if [ "$rigFail" -ne 0 ] ; then echo "⛔ DUTY NIGHT TAG CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1 ; fi
printf 'DUTY_NIGHT_TAG: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
