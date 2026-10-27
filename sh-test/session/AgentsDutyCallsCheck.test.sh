#!/usr/bin/env bash
## Behavioural check on what calls a work-duty at any hour (F7.12, the owner's rulings of 2026-10-20; AgentsToolsScheduleTagNews, AgentsToolsScheduleTeamTags,
## AgentsToolsScheduleDmTags, sh-lib/session/AgentsTools.DispatcherLoop.include, and AgentsTools.TrackingDrop.include). The real loop (--one) and the real
## spawner run, as in AgentsScheduleLoopCheck; the console, curl, date and every setting are this rig's own. GUARD: every tooling call goes through one `env -i`
## whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's tree and PATH holds no agent CLI. Held:
##   5. OUT OF THE FLAGS A CALL BY NAME KEEPS A DUTY, and nothing else does. A person's tag in the team channel and a person's DM keep a duty that has been idle
##      for hours; an untagged message does not; a tracking post of the tooling that names the member does not (the start post of a session its duty launched,
##      though the duty was rewound since it launched it); the hand-back of a run it launched that reports to nobody does not, one that reports to it does; a tag
##      the duty's own session has taken (its pointer, collect:<member>:tagged:<member>) is no news.
##   6. OUT OF THE FLAGS A CALL BY NAME STARTS A DUTY: a person's DM or tag does, a post of the tooling naming the member does not, nor an untagged message.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRealTemplate="$rigPackage/sh-lib/templates/spawn-brief.document.format.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyCallsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rigRemoveTree' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
## keeper-rig-01 holds the rig's autoruns; the cases use 02 to 10, and 11 is the member with nothing to work on.
rigScheduleSetup 18
## Monday 2026-10-19 in Etc/GMT-3: 13:00 (worktime) and 18:00 (after it).
rigMon13=1792404000 ; rigMon18=1792422000
rigIso(){ ## epoch -- the stamp of a milestone
	date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}
rigNo(){ ## member -- its number, 02 to 10
	printf '%s' "${1##*-}"
}
rigIdle(){ ## member, seconds idle at the clock of the rig -- the milestones of its run: it began, then waited, and a quiet round came back and waited again
	local idleNow idleSpawn
	idleNow="$( cat "$rigDir/now.epoch" )"
	eval "idleSpawn=\"\$rigSpawnOf$( rigNo "$1" )\""
	printf '%s start\n%s wait going idle\n%s wait going idle\n' "$( rigIso $(( idleNow - $2 - 300 )) )" "$( rigIso $(( idleNow - $2 )) )" "$( rigIso $(( idleNow - $2 + 200 )) )" > "$rigStores/$idleSpawn/milestones"
}
rigCache(){ ## member, read|wrote|nothing|none -- the log of its run: an older line of the other kind first, then the last round-1 line (none: a log with no such line)
	local cacheSpawn cacheRecord cacheLog
	eval "cacheSpawn=\"\$rigSpawnOf$( rigNo "$1" )\""
	cacheRecord="$rigSp/$cacheSpawn/$cacheSpawn.spawn.md" ; cacheLog="$rigStores/$cacheSpawn/rig-output.log"
	case "$2" in
		read) printf '%s\n' '   shared prefix -- round 1 cached nothing: the prefix is under the model minimum' '   some work' '   shared prefix -- round 1 read 4100 tokens from the cache' '   more work' > "$cacheLog" ;;
		wrote) printf '%s\n' '   shared prefix -- round 1 read 4100 tokens from the cache' '   some work' '   shared prefix -- round 1 wrote 4100 tokens to the cache for the next session' '   more work' > "$cacheLog" ;;
		nothing) printf '%s\n' '   shared prefix -- round 1 read 4100 tokens from the cache' '   some work' '   shared prefix -- round 1 cached nothing: the prefix is under the model minimum, or its markers were not honoured' '   more work' > "$cacheLog" ;;
		none) printf '%s\n' '   some work' '   more work' > "$cacheLog" ;;
	esac
	LC_ALL=C grep -v '^output-file: ' "$cacheRecord" | LC_ALL=C awk -v outlog="$cacheLog" '{ print } /^status: / { print "output-file: " outlog }' > "$cacheRecord.next" && mv -f "$cacheRecord.next" "$cacheRecord"
}
rigTold(){ ## run name, member -- how many lines of that iteration say the member's duty is told to go
	local toldSpawn
	eval "toldSpawn=\"\$rigSpawnOf$( rigNo "$2" )\""
	rigSaid "$1" "work-duty: $toldSpawn of $2 is told to go"
}


echo "-- 0. the duties that stand when worktime ends --"
rigAt "$rigMon13"
rigOneRun idle0 ; rigWaitStarts
rigDutyMembers="12 13 14 15 16 17"
for rigM in $rigDutyMembers ; do rigItem keeper-rig-$rigM ; done
rigAt $(( rigMon13 + 20 ))
rigOneRun start0 ; rigWaitStarts
rigAssert "the items arrive: the duty of each member that has one is started; keeper-rig-11 and 18, with none, have none" "$( for rigM in $rigDutyMembers ; do rigDutyCount keeper-rig-$rigM ; done | tr -d '\n' ):$( rigDutyCount keeper-rig-11 ):$( rigDutyCount keeper-rig-18 )" "111111:0:0"
for rigM in $rigDutyMembers ; do
	rigLive keeper-rig-$rigM idle ; eval "rigSpawnOf$rigM=\"\$rigLiveSpawn\""
	rm -f "$rigData/inboxes/keeper-rig-$rigM/incoming/note-20261019T0900Z-rig-work.md"
	rigCache keeper-rig-$rigM read
done

echo "-- 5. out of the flags, a call by name keeps a duty; nothing else does --"
## A message of the team channel as Slack answers it: a person's, or one the tooling posted itself (tracking, and the session it belongs to).
rigMsg(){ ## ts, user, text [, tracking kind, session spawn id, sender]
	if [ -n "${4:-}" ] ; then
		printf '{"type":"message","user":"%s","text":"%s","ts":"%s","metadata":{"event_type":"magic_sender","event_payload":{"sender":"%s","tracking":"%s","session":"%s"}}}' "$2" "$3" "$1" "${6:-magic-team}" "$4" "$5"
	else
		printf '{"type":"message","user":"%s","text":"%s","ts":"%s"}' "$2" "$3" "$1"
	fi
}
rigHistory(){ ## messages... -- the team channel answers with them
	local historyAll="" historyOne
	for historyOne in "$@" ; do historyAll="$historyAll${historyAll:+,}$historyOne" ; done
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$historyAll" > "$rigScn/history-body"
}
rigLaunched(){ ## spawn id, launching member, reports-to (may be empty) -- the record of a session that member's duty launched, kept by the spawner and by nothing else
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: rig-parent\nparent-member: %s\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: keeper-rig-01\nstatus: spawn-succeeded\nstarted-at: 2026-10-19 17:00 +0300\n%s---\n\n# Spawn session: %s\n' "$1" "$1" "$2" "$rigHost" "${3:+reports-to: $3
}" "$1" > "$rigSp/$1/$1.spawn.md"
}
rigLaunched rig-launched-14 keeper-rig-14 none
rigLaunched rig-away-15 keeper-rig-15 none
rigLaunched rig-home-17 keeper-rig-17 keeper-rig-17
## The duty of keeper-rig-14 was rewound after it launched a session (a rewind is a milestone of its own run): it remembers nothing of it, and the tooling needs not.
rigAt $(( rigMon18 + 600 ))
rigNowTs=$(( rigMon18 + 595 ))
for rigM in 12 13 14 15 16 17 ; do rigIdle keeper-rig-$rigM 7200 ; done
rigSpawn14="$rigSpawnOf14" ; printf '%s rewind opening\n' "$( rigIso $(( rigMon18 + 600 - 7300 )) )" | cat - "$rigStores/$rigSpawn14/milestones" > "$rigStores/$rigSpawn14/milestones.next" && mv -f "$rigStores/$rigSpawn14/milestones.next" "$rigStores/$rigSpawn14/milestones"
printf '[{"id":"DRIGDM016","is_im":true,"is_mpim":false,"user":"URIGFRIEND","is_user_deleted":false,"is_member":true}]\n' > "$rigScn/dms.rig-user-token-16.json"
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigMsg "$rigNowTs.000700" URIGFRIEND "hello, are you there" )" > "$rigScn/history.DRIGDM016.json"
rigHistory \
	"$( rigMsg "$rigNowTs.000100" U1 "@keeper-rig-12 please look at this" )" \
	"$( rigMsg "$rigNowTs.000200" U2 "plain talk, nobody named" )" \
	"$( rigMsg "$rigNowTs.000300" URIGBOT01 "Session started by @keeper-rig-14, thread open" session-root rig-launched-14 )" \
	"$( rigMsg "$rigNowTs.000400" URIGBOT01 "Done, @keeper-rig-15, here is the result" handback rig-away-15 keeper-rig-01 )" \
	"$( rigMsg "$rigNowTs.000500" URIGBOT01 "Done, @keeper-rig-17, here is the result" handback rig-home-17 keeper-rig-01 )" \
	"$( rigMsg "$rigNowTs.000600" URIGBOT01 "activity of a run, @keeper-rig-13" activity rig-launched-14 keeper-rig-01 )"
rigMentionCache ; rigOneRun tag1
rigAssert "a person's tag of keeper-rig-12 (the team channel), out of worktime, idle for two hours, no input: its duty stays" "$( rigTold tag1 keeper-rig-12 )" "0"
rigAssert "an untagged message of the channel keeps nothing: keeper-rig-13 (named only in a tracking post of the tooling) is told to go" "$( rigTold tag1 keeper-rig-13 )" "1"
rigAssert "the start post of a session its duty launched, naming keeper-rig-14, is the tooling's own: told to go, though the duty was rewound since it launched it" "$( rigTold tag1 keeper-rig-14 )" "1"
rigAssert "the hand-back of a run keeper-rig-15's duty launched that reports to nobody, naming it: told to go" "$( rigTold tag1 keeper-rig-15 )" "1"
rigAssert "a DM to keeper-rig-16 from a person counts as a tag: its duty stays" "$( rigTold tag1 keeper-rig-16 )" "0"
rigAssert "the hand-back of a run keeper-rig-17 launched that reports to it is news: its duty stays" "$( rigTold tag1 keeper-rig-17 )" "0"
## The duty's own session keeps its pointer into the tagged source (collect:<member>:tagged:<member>, session.chat.pointers); a tag it has been given is not news.
rigSession12="$( LC_ALL=C sed -n 's/^session-id: //p' "$rigSp/$rigSpawnOf12/$rigSpawnOf12.spawn.md" | head -1 )"
mkdir -p "$rigStores/$rigSession12"
printf 'collect:keeper-rig-12:tagged:keeper-rig-12\t%s.000100\n' "$rigNowTs" >> "$rigStores/$rigSession12/session.chat.pointers"
rigAt $(( rigMon18 + 620 ))
rigMentionCache ; rigOneRun tag1b
rigAssert "the tag is the duty's own pointer's now (its session took it): nothing newer calls keeper-rig-12, and it is told to go" "$( rigTold tag1b keeper-rig-12 )" "1"

echo "-- 6. out of the flags, a call by name starts a duty; nothing else does --"
rigAt $(( rigMon18 + 700 ))
rigNowTs=$(( rigMon18 + 695 ))
rigHistory \
	"$( rigMsg "$rigNowTs.000100" URIGBOT01 "Session started by @keeper-rig-11 and @keeper-rig-18" session-root rig-launched-11 )" \
	"$( rigMsg "$rigNowTs.000200" U2 "plain talk, nobody named" )"
## A DM of a person to keeper-rig-11 is already there; out of worktime the DMs of a member are read once in five minutes, and its last look was at tag1.
printf '[{"id":"DRIGDM011","is_im":true,"is_mpim":false,"user":"URIGFRIEND","is_user_deleted":false,"is_member":true}]\n' > "$rigScn/dms.rig-user-token-11.json"
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigMsg "$rigNowTs.000700" URIGFRIEND "hello, keeper" )" > "$rigScn/history.DRIGDM011.json"
rigMentionCache ; rigOneRun tag2 ; rigWaitStarts
rigAssert "a post of the tooling naming them, and an untagged message: no duty is started for keeper-rig-11 or keeper-rig-18; and the DM, a hundred seconds after the last look, is not read yet" "$( rigDutyCount keeper-rig-11 ):$( rigDutyCount keeper-rig-18 )" "0:0"
rigAt $(( rigMon18 + 1000 ))
rigNowTs=$(( rigMon18 + 995 ))
rigMentionCache ; rigOneRun tag3 ; rigWaitStarts
rigAssert "five minutes on, the DM from a person to keeper-rig-11 starts its duty out of worktime; keeper-rig-18, with none, still has none" "$( rigDutyCount keeper-rig-11 ):$( rigDutyCount keeper-rig-18 ):$( rigSaid tag3 'work-duty: started the duty of keeper-rig-11' )" "1:0:1"
## S11.2, sketch 12.3 (settled): the seen reaction goes on when the member is handed the message
## (its Wait, or the work-duty scan's collect: AgentsWaitOwnerDmsCheck), never when the loop only notices it. The loop reads the DM and starts the duty; it reacts to nothing.
rigEyesOn(){ ## ts -- how many eyes reactions the fake curl logged on that message
	LC_ALL=C grep -F -- "$1" "$rigScn/reactions" 2> /dev/null | LC_ALL=C grep -c -F eyes || :
}
rigAssert "the loop noticed the DM to keeper-rig-11 and started its duty, and gave no eyes at all (the other reactions in the rig are none of this row's): none yet" "$( rigEyesOn "$(( rigMon18 + 695 )).000700" ):$( LC_ALL=C grep -c -F eyes "$rigScn/reactions" 2> /dev/null || : ):$( [ -e "$rigWs/.local/agents/schedule/seen/keeper-rig-11" ] && echo store || echo none )" "0:0:none"
rigAt $(( rigMon18 + 1100 ))
rigNowTs=$(( rigMon18 + 1095 ))
rigHistory "$( rigMsg "$rigNowTs.000100" U1 "@keeper-rig-18 are you there" )"
rigMentionCache ; rigOneRun tag4 ; rigWaitStarts
rigAssert "a person's tag of keeper-rig-18 starts its duty; and keeper-rig-11's, given its DM, is not started a second time" "$( rigDutyCount keeper-rig-18 ):$( rigDutyCount keeper-rig-11 )" "1:1"
rigAssert "the person's tag of keeper-rig-18 starts its duty and gets no eyes from the loop either" "$( rigEyesOn "$rigNowTs.000100" )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY CALLS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_CALLS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
