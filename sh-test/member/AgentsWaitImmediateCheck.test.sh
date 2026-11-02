#!/usr/bin/env bash
## Behavioural check on the immediate sources of a run (S27.9): MEASURED on a real --wait-for-input call, never assumed.
##   1. A work-duty reads a mention that its last check of them is 30 s old for, at its 15 s DM poll, and not at the 60 s
##      TTL of the mentions -- and its floor carries its tags (tagged:<member>) beside its DMs and mentions.
##   2. A plain session does not: the same call, with its last check 1 s old, is quiet.
##   2b. The idle wait holds that same floor: the call --idle-wait makes names the session thread alone, and its sources still carry the duty's
##      DMs, mentions and tags.
##   3. An asking call's wait leaves the eyes reaction on what else it returns (MDAT_WAIT_SEEN_OWN_SOURCE names only its own source).
## Offline: a Slack-shaped fake curl first on PATH, and every tree is this rig's own. The wait runs in its default cadence, never a
## fixed poll interval, because the gap is what is measured. RIG_ONLY=<scene> runs one scene: duty, plain, idle or seen.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitImmediateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/magic-coordinator"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl.real" || rigRefuse "the fake curl fixture is missing from the package"
## The fake curl: the list of direct conversations waits for the scene's `release`, so a costly probe can be held on purpose,
## and a reaction is answered here, its conversation named, so the eyes reaction of a scene is counted from the calls log.
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$( date +%s )" "$*" >> "$RIG_SCENARIO/calls.log"
case " $* " in
	*conversations.list*) rigHeld=0 ; while [ -f "$RIG_SCENARIO/hold" ] && [ ! -f "$RIG_SCENARIO/release" ] && [ "$rigHeld" -lt 600 ] ; do sleep 1 ; rigHeld=$(( rigHeld + 1 )) ; done ;;
	*reactions.add*)
		rigWhere=""
		for rigArg in "$@" ; do
			case "$rigArg" in
				channel@*) rigWhere="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
				channel=*) rigWhere="${rigArg#channel=}" ;;
			esac
		done
		printf 'reactions.add %s\n' "${rigWhere:-unknown}" >> "$RIG_SCENARIO/reactions.log"
		printf '{"ok":true}\n' ; exit 0
	;;
esac
exec "$(dirname "$0")/curl.real" "$@"
EOF
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/curl.real"
trap 'for rigHold in "$rigTmp"/*/hold ; do [ ! -f "$rigHold" ] || : > "${rigHold%hold}release" ; done ; sleep 2 ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigOnly="${RIG_ONLY:-}"
rigWant(){ ## scene
	[ -z "$rigOnly" ] || [ "$rigOnly" = "$1" ]
}
rigNow="" rigWs="" rigData="" rigDir="" rigSession="rig-imm-session" rigOwnSeen="" rigDutyRoot="" rigTook=0
rigScene(){ ## name, duty (yes|no), the age in seconds of the last check of the mentions and the DMs (none: never checked)
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigWs="$rigDir/ws" rigData="$rigDir/data"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession/wait" "$rigData/inboxes/keeper-rig/incoming" "$rigData/board"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
	printf 'keeper-rig=URIGKEEP1=k=K=K=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
	: > "$rigDir/api.log"
	printf 'mentions:keeper-rig\t%s.000000\n' "$(( rigNow - 100 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"
	[ "$3" = "none" ] || printf 'mentions:keeper-rig\t%s\ndms:keeper-rig\t%s\n' "$(( rigNow - $3 ))" "$(( rigNow - $3 ))" > "$rigWs/.local/agents/sessions/$rigSession/wait/probed"
	rigDutyRoot=""
	if [ "$2" = "yes" ] ; then
		## The run's own sandbox, as a real run has it: the record is read at its exact path.
		mkdir -p "$rigWs/.local/agents/spawned/rig"
		rigDutyRoot="$rigWs/.local/agents/spawned/rig"
		printf -- '---\nrun-process: 1 x\nroutine: keeper-rig.work-duty.routine.md\n---\n' > "$rigWs/.local/agents/spawned/rig/$rigSession.spawn.md"
	fi
	printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' > "$rigDir/search.rig-user-KEEPER.json"
	## The tags are read with the team bot's token, its own search: empty here, so the source reads cleanly.
	printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' > "$rigDir/search.rig-bot-token-TEAM.json"
}
rigSearch(){ ## ts, text -- one mention, a reply in a thread of another conversation
	printf '{"ok":true,"messages":{"total":1,"paging":{"count":100,"total":1,"page":1,"pages":1},"matches":[{"ts":"%s","user":"URIGFRIEND","text":"%s","permalink":"https://rig.slack.com/archives/CRIGOTHER/p1?thread_ts=%s.000001&cid=CRIGOTHER","channel":{"id":"CRIGOTHER"}}]}}\n' "$1" "$2" "$(( rigNow - 5000 ))" > "$rigDir/search.rig-user-KEEPER.json"
}
rigCall(){ ## result name, op words... -- one call from the rig workspace, in the default cadence; rc, out, err, and rigTook the seconds it ran
	local callName="$1" callRc=0 callStart
	shift
	callStart="$( date +%s )"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigDir" MDAT_WAIT_REMIND=off ${rigOwnSeen:+MDAT_WAIT_SEEN_OWN=1 MDAT_WAIT_SEEN_OWN_SOURCE=ask:rig-own-answer} \
		${rigDutyRoot:+MDAT_SPAWN_SANDBOX_ROOT="$rigDutyRoot"} \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 300 -- bash "$rigTool" "$@" ) > "$rigDir/$callName.out" 2> "$rigDir/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigDir/$callName.rc"
	rigTook=$(( $( date +%s ) - callStart ))
}
rigHolds(){ ## result name, text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.out" || :
}
rigFirst(){ ## result name -- the first line of the result
	head -1 "$rigDir/$1.out"
}
rigReacted(){ ## conversation -- reacted where the rig's own fake Slack was asked to put a reaction there
	local reactCount=0
	[ ! -f "$rigDir/reactions.log" ] || reactCount="$( LC_ALL=C grep -c -F -- "reactions.add $1" "$rigDir/reactions.log" || : )"
	case "$reactCount" in ''|*[!0-9]*) reactCount=0 ;; esac
	[ "$reactCount" -lt 1 ] && printf none || printf reacted
}
rigFloorHas(){ ## result name, the sources -- yes where the result's sources line holds every one of them
	local floorOk=1 floorWant
	for floorWant in "${@:2}" ; do
		case " $( LC_ALL=C sed -n 's/^# sources: //p' "$rigDir/$1.out" | head -1 ) " in
			*" $floorWant "*) ;;
			*) floorOk=0 ;;
		esac
	done
	[ "$floorOk" = 0 ] && printf no || printf yes
}
rigShow(){ ## result name -- what a call said, for a scene that failed
	printf '  --- %s: rc %s, %ss\n' "$1" "$( cat "$rigDir/$1.rc" 2> /dev/null )" "$rigTook" ; head -c 1800 "$rigDir/$1.out" ; head -c 1200 "$rigDir/$1.err"
}
## One call of a single round: the mention is there at its start, the last check of the mentions is $3 seconds old, the bound 1 s.
rigMentionWait(){ ## result name, duty (yes|no), the age of the last check
	rigScene "$1" "$2" "$3"
	rigSearch "$(( rigNow - 10 )).000003" "RIG-MENTION-$1 <@URIGKEEP1> look"
	rigCall "$1" --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source mentions:keeper-rig --wait-since-utime "$(( rigNow - 100 ))" --wait-timeout 1
}

if rigWant duty ; then
	echo "-- a work-duty reads a mention its last check is 30 s old for, at the 15 s DM poll --"
	rigMentionWait duty yes 30
	rigAssert "a duty's round returns the mention: its mentions are due at 15 s, not at the 60 s TTL" \
		"$( rigFirst duty ):$( rigHolds duty RIG-MENTION-duty )" "WAIT-RESULT: RECEIVED:1"
	rigAssert "a duty's floor carries its tags (tagged:<member>) beside its DMs and mentions" \
		"$( LC_ALL=C grep -c '^# sources: .*tagged:keeper-rig' "$rigDir/duty.out" )" "1"
	printf '  measured: the duty'"'"'s call ran %ss\n' "$rigTook"
fi

if rigWant plain ; then
	echo "-- a plain session does not: the same call, with its last check 1 s old, is quiet --"
	rigMentionWait plain no 1
	if [ "$rigTook" -ge 55 ] ; then
		printf '  NOTE  the call ran %ss, so its last check was over the 60 s TTL when it read: the quiet-round assertion is skipped on a host this slow\n' "$rigTook"
	else
		rigAssert "a plain session's round is quiet: its mentions are not due before the 60 s TTL" \
			"$( rigFirst plain ):$( rigHolds plain RIG-MENTION-plain )" "WAIT-RESULT: TIMEOUT:0"
	fi
	rigAssert "a plain session's floor carries no tags source" \
		"$( LC_ALL=C grep -c '^# sources: .*tagged:' "$rigDir/plain.out" )" "0"
fi

if rigWant idle ; then
	echo "-- the call --idle-wait makes names the session thread alone, and still holds the duty's floor --"
	rigScene idle yes 30
	rigCall idle --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source "chat:$rigSession" --wait-timeout 1
	rigAssert "the idle wait's sources carry the duty's DMs, mentions and tags beside its own thread" \
		"$( rigFloorHas idle "chat:$rigSession" dms:keeper-rig mentions:keeper-rig tagged:keeper-rig )" "yes"
fi

if rigWant seen ; then
	echo "-- an asking call's wait leaves the eyes reaction on what else it returns --"
	rigScene seen no none
	rigSearch "$(( rigNow - 10 )).000005" 'RIG-SEEN-MENTION <@URIGKEEP1>'
	rigOwnSeen=1
	rigCall seen --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source mentions:keeper-rig --wait-since-utime "$(( rigNow - 100 ))" --wait-timeout 1
	rigOwnSeen=""
	rigAssert "a mention returned to an asking call is returned, and an eyes reaction is asked for in its conversation" \
		"$( rigHolds seen RIG-SEEN-MENTION ):$( rigReacted CRIGOTHER )" "1:reacted"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT IMMEDIATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_IMMEDIATE: OK (%d assertions, offline)\n' "$rigPassCount"
