#!/usr/bin/env bash
## Behavioural check on the work-duty input scan (F4.1 of the refactorings epic): `--intern-op-work-duty-input-scan <team-member>
## [--session-id <id>]`, a scan a routine declares (`input-scan-def: work-duty`) and the spawner runs, since F6.4 no operation an agent
## calls. It collects the inbox items not yet processed (F4.3's incoming/ alone) and the Slack that is tagged to the member -- a
## mention of it in the team channel or its session thread, and any DM -- immediately, and the team channel over a collect window.
## COLLECT IS A WAIT, NOT A SLEEP, on the pointer-and-watch primitive the session chat file is read by: a pointer at the last message
## already seen, kept in the session (session.chat.pointers); a watch from it; and a return with everything accumulated when either the
## window elapses or an immediate message appears, whichever comes first, saying which on a `# returned: window|immediate` line.
## The window is the setting WAIT_COLLECT_SECONDS beside WAIT_ROUND_SECONDS in the settings catalogue (a minute when it is not set).
## Held:
##   1. the scan is one of the tooling's scans (the runner's names), runs for the member given, exit 0
##   2. the catalogue holds WAIT_COLLECT_SECONDS, among the CLI's workspace settings, beside WAIT_ROUND_SECONDS
##   3. a team channel message that tags nobody is collected over the window: the scan returns after the window, not before and not
##      long after, `# returned: window`, the message in the report
##   4. the inbox: the incoming item is listed, the processed one is not
##   5. a message that tags the member (@member, or its Slack account) ends the collect at once, `# returned: immediate`, long before
##      the window, with what was accumulated before it
##   6. any DM ends it at once; a mention in the session thread does
##   7. the pointer: a second scan of the session does not repeat what the first returned
##   9. a tagged message of a session chat thread where the member's own instance is present is no work: it is returned for
##      knowledge only, its row marked `[fyi: ...]` and a `# fyi: ... -- for your knowledge, not yours to answer` line before it,
##      and it starts nothing (the scan is no input for a start, no duty is started and the tags name no news). The same message in
##      that thread with the instance gone -- its run ended -- is a normal item, unmarked, and the scan is input.
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
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
rigTmp="$( rigTempDir AgentsWorkDutyInputScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"

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
rigNow="$( date +%s )"
rigWs="" rigData="" rigDir="" rigSession="rig-wd-session"
rigScene(){ ## name, the collect window in seconds
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigWs="$rigDir/ws" rigData="$rigDir/data"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession" "$rigData/inboxes/keeper-rig/incoming" "$rigData/inboxes/keeper-rig/processed" "$rigData/board"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=%s\n' "$2" > "$rigWs/.local/.agents/magic-team.agent.env"
	printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nRIG-INCOMING-NOTE\n' > "$rigData/inboxes/keeper-rig/incoming/note-20261019T0100Z-rig-open.md"
	printf -- '---\ntype: note\nfrom: magic-coordinator\nprocessed-at: 2026-10-19 01:05 +0000\n---\n\nRIG-PROCESSED-NOTE\n' > "$rigData/inboxes/keeper-rig/processed/note-20261019T0000Z-rig-done.md"
	: > "$rigDir/api.log"
	## The pointers of the session, a little behind now: what the last collect of this session had got to.
	printf 'collect:keeper-rig:slack:magic-team\t%s.000000\ncollect:keeper-rig:tagged:keeper-rig\t%s.000000\n' "$(( rigNow - 100 ))" "$(( rigNow - 100 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"
}
rigMsg(){ ## ts user text [thread ts]
	printf '{"ts":"%s","user":"%s","text":"%s"%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}"
}
rigHistory(){ ## channel, messages...
	local historyChannel="$1" historyOut="" historyOne
	shift
	for historyOne in "$@" ; do historyOut="$historyOut${historyOut:+,}$historyOne" ; done
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$historyOut" > "$rigDir/history.$historyChannel.json"
}
rigCall(){ ## result name, op words... -- one call from the rig workspace; rc, out, err and how long it took
	local callName="$1" callStart callRc=0
	shift
	callStart="$( date +%s )"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigDir" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigTool" "$@" ) > "$rigDir/$callName.out" 2> "$rigDir/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigDir/$callName.rc"
	printf '%s' "$(( $( date +%s ) - callStart ))" > "$rigDir/$callName.took"
}
rigHolds(){ ## result name, text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.out" || :
}
rigScan(){ ## result name
	rigCall "$1" --intern-op-work-duty-input-scan keeper-rig --session-id "$rigSession"
}
rigTook(){ cat "$rigDir/$1.took" ; }
## The run of the member in the rig's session, as the spawner records it: `spawn-started` until the tooling closes it, which is the one rule
## a run is over by; `spawn-succeeded` is a run that ended, and so no presence.
rigInstance(){ ## spawn id, status, host
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: rig-parent\nparent-member: keeper-rig\nstart-context: spawned\nowner: keeper-rig\nhost: %s\nstatus: %s\n---\n\n# Spawn session: %s\n' \
		"$rigSession" "$1" "$3" "$2" "$1" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigSeat(){ ## spawn id -- the member's seat in the rig's session, naming that run, as a start takes it
	mkdir -p "$rigWs/.local/agents/sessions/$rigSession/seats"
	printf '%s\n' "$1" > "$rigWs/.local/agents/sessions/$rigSession/seats/keeper-rig"
}
rigReportEmpty(){ ## result name -- rc 0 where the report holds nothing to start on (AgentsToolsInputScanReportEmpty)
	bash -c '. "$1/myx/myx.distro-agents/sh-lib/session/AgentsTools.InputScanDef.include" ; AgentsToolsInputScanReportEmpty "$2"' rig "$rigOrigin" "$rigDir/$1.out" 2> /dev/null && printf empty || printf input
}

echo "-- 1. the scan runs for the member, and is one of the tooling's scans --"
rigScene run 3
rigScan run
rigAssert "exit 0, no invalid option"                                "$( cat "$rigDir/run.rc" ):$( LC_ALL=C grep -c -F 'invalid option' "$rigDir/run.err" )" "0:0"
rigAssert "a scan name the runner and the validator know"            "$( bash -c ". '$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.InputScanDef.include' ; AgentsToolsInputScanNames | grep -c -x work-duty" )" 1
rigCall noarg --intern-op-work-duty-input-scan
rigAssert "with no member it says its syntax"                        "$( cat "$rigDir/noarg.rc" ):$( LC_ALL=C grep -c 'syntax is <team-member>' "$rigDir/noarg.err" )" "1:1"

echo "-- 2. the settings catalogue holds WAIT_COLLECT_SECONDS --"
rigCall digest --manager-config-digest
rigAssert "the digest prints it as a line of the CLI's workspace settings, beside WAIT_ROUND_SECONDS" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "cli" && $3 == "workspace" && ( $4 == "WAIT_COLLECT_SECONDS" || $4 == "WAIT_ROUND_SECONDS" ) { print $4 }' "$rigDir/digest.out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "WAIT_COLLECT_SECONDS WAIT_ROUND_SECONDS "
rigAssert "set to what the rig set, a whole number of seconds"        "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "cli" && $3 == "workspace" && $4 == "WAIT_COLLECT_SECONDS" { print $5 " " $6 }' "$rigDir/digest.out" )" "set 3"

echo "-- 3. the team channel is collected over the window --"
rigScene window 3
rigHistory CRIG00001 "$( rigMsg "$(( rigNow - 50 )).000001" URIGOTHER RIG-TEAM-PLAIN )"
rigScan window
rigAssert "after the window: not before it, and not long after"      "$( [ "$( rigTook window )" -ge 3 ] && [ "$( rigTook window )" -le 25 ] && echo window || echo "took:$( rigTook window )" )" window
rigAssert "saying so"                                                "$( rigHolds window '# returned: window' )" 1
rigAssert "the message that tags nobody is in the report"            "$( rigHolds window RIG-TEAM-PLAIN )" 1
rigAssert "behind the source it is of"                               "$( rigHolds window '# arrived on: slack:magic-team' )" 1

echo "-- 4. the inbox: what is not processed --"
rigAssert "the incoming note is listed, the processed one is not"    "$( rigHolds window note-20261019T0100Z-rig-open | LC_ALL=C sed -e 's/^[1-9][0-9]*$/listed/' ):$( rigHolds window note-20261019T0000Z-rig-done )" "listed:0"

echo "-- 5. a tag ends the collect at once --"
rigScene tagged 25
rigHistory CRIG00001 "$( rigMsg "$(( rigNow - 50 )).000001" URIGOTHER RIG-TEAM-EARLIER )" "$( rigMsg "$(( rigNow - 40 )).000001" URIGOTHER 'RIG-TEAM-TAGGED @keeper-rig please look' )"
rigScan tagged
rigAssert "long before the window"                                   "$( [ "$( rigTook tagged )" -lt 20 ] && echo quick || echo "took:$( rigTook tagged )" )" quick
rigAssert "returned: immediate"                                      "$( rigHolds tagged '# returned: immediate' )" 1
rigAssert "the tagged message and what was accumulated before it"    "$( rigHolds tagged RIG-TEAM-TAGGED ):$( rigHolds tagged RIG-TEAM-EARLIER )" "1:1"
rigScene account 25
printf 'keeper-rig=URIGKEEP1=rigk=Rig=Keeper=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
rigHistory CRIG00001 "$( rigMsg "$(( rigNow - 40 )).000001" URIGOTHER 'RIG-ACCOUNT-TAGGED <@URIGKEEP1> look' )"
rigScan account
rigAssert "a mention by its Slack account tags it too"               "$( [ "$( rigTook account )" -lt 20 ] && echo quick || echo "took:$( rigTook account )" ):$( rigHolds account '# returned: immediate' )" "quick:1"

echo "-- 6. any DM, and a mention in the session thread --"
rigScene dm 25
printf '[{"id":"DRIGDM001","is_im":true,"is_mpim":false,"user":"URIGFRIEND","is_user_deleted":false,"is_member":true}]\n' > "$rigDir/dms.json"
rigHistory DRIGDM001 "$( rigMsg "$(( rigNow - 30 )).000001" URIGFRIEND RIG-DM-HELLO )"
rigScan dm
rigAssert "a DM message, no mention in it, ends the collect at once"  "$( [ "$( rigTook dm )" -lt 20 ] && echo quick || echo "took:$( rigTook dm )" ):$( rigHolds dm '# returned: immediate' ):$( rigHolds dm RIG-DM-HELLO )" "quick:1:1"
rigAssert "behind the conversation it is of"                          "$( rigHolds dm '# in DRIGDM001' )" 1
rigScene thread 25
printf 'CRIGSES01:%s.000001\n' "$(( rigNow - 400 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
## The member's instance in that session: its run and the seat it holds. The thread is where that instance is present, so its messages are FYI.
rigInstance rig-run-instance spawn-started rig-elsewhere
rigSeat rig-run-instance
printf '{"ok":true,"messages":[%s,%s],"has_more":false}\n' "$( rigMsg "$(( rigNow - 400 )).000001" URIGOTHER RIG-THREAD-ROOT )" "$( rigMsg "$(( rigNow - 30 )).000001" URIGOTHER 'RIG-THREAD-MENTION @keeper-rig' "$(( rigNow - 400 )).000001" )" > "$rigDir/replies.CRIGSES01.$(( rigNow - 400 )).000001.json"
rigScan thread
rigAssert "a mention in the session thread ends it at once"           "$( [ "$( rigTook thread )" -lt 20 ] && echo quick || echo "took:$( rigTook thread )" ):$( rigHolds thread '# returned: immediate' ):$( rigHolds thread RIG-THREAD-MENTION ):$( rigHolds thread RIG-THREAD-ROOT )" "quick:1:1:0"
rigAssert "the session-thread mention is for its knowledge, not to answer"  "$( rigHolds thread 'for your knowledge, not yours to answer' )" 1
rigAssert "the row itself says it is FYI, right after its sender"       "$( rigHolds thread '[fyi: the session chat thread of keeper-rig' )" 1

echo "-- 7. the pointer --"
rigScene pointer 3
rigHistory CRIG00001 "$( rigMsg "$(( rigNow - 50 )).000001" URIGOTHER RIG-TEAM-ONCE )"
rigScan p1
rigScan p2
rigAssert "the first scan returns the message, the second of the session does not"  "$( rigHolds p1 RIG-TEAM-ONCE ):$( rigHolds p2 RIG-TEAM-ONCE )" "1:0"
rigAssert "the pointer is kept in the session, at the last message returned"        "$( LC_ALL=C awk -F'\t' '$1 == "collect:keeper-rig:slack:magic-team" { print $2 ; }' "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers" )" "$(( rigNow - 50 )).000001"

echo "-- 8. what the tooling posted itself is no input --"
##   The tooling marks what it posts itself (tracking and the spawn id of the session, AgentsSlackMessagesFormat.awk): the collect does not end on such a post,
##   though it names the member, and does not report it; a hand-back of a run that reports to the member is news, of one the member launched that reports to nobody is none.
rigMsgTool(){ ## ts, user, text, kind, session
	printf '{"ts":"%s","user":"%s","text":"%s","metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-team","tracking":"%s","session":"%s"}}}' "$1" "$2" "$3" "$4" "$5"
}
rigLaunched(){ ## spawn id, reports-to
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: rig-parent\nparent-member: keeper-rig\nstart-context: spawned\nowner: keeper-rig-other\nreports-to: %s\nstatus: spawn-succeeded\n---\n\n# Spawn session: %s\n' "$1" "$1" "$2" "$1" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigScene tooling 3
rigLaunched rig-launched none
rigHistory CRIG00001 "$( rigMsgTool "$(( rigNow - 40 )).000001" URIGBOT01 'RIG-TOOL-START @keeper-rig session started' session-root rig-launched )" "$( rigMsgTool "$(( rigNow - 30 )).000001" URIGBOT01 'RIG-TOOL-ACTIVITY @keeper-rig' activity rig-launched )"
rigScan tooling
rigAssert "a start post and an activity post of the tooling, both naming the member: the collect runs its window, and reports neither" "$( [ "$( rigTook tooling )" -ge 3 ] && echo window || echo "took:$( rigTook tooling )" ):$( rigHolds tooling '# returned: window' ):$( rigHolds tooling RIG-TOOL-START ):$( rigHolds tooling RIG-TOOL-ACTIVITY )" "window:1:0:0"
rigScene toolaway 3
rigLaunched rig-away none
rigHistory CRIG00001 "$( rigMsgTool "$(( rigNow - 40 )).000001" URIGBOT01 'RIG-AWAY-HANDBACK @keeper-rig done' handback rig-away )"
rigScan toolaway
rigAssert "the hand-back of a run the member launched that reports to nobody: no tag, the window runs" "$( [ "$( rigTook toolaway )" -ge 3 ] && echo window || echo "took:$( rigTook toolaway )" ):$( rigHolds toolaway RIG-AWAY-HANDBACK )" "window:0"
rigScene toolhome 25
rigLaunched rig-home keeper-rig
rigHistory CRIG00001 "$( rigMsgTool "$(( rigNow - 40 )).000001" URIGBOT01 'RIG-HOME-HANDBACK @keeper-rig done' handback rig-home )"
rigScan toolhome
rigAssert "the hand-back of a run that reports to the member is news: it ends the collect at once" "$( [ "$( rigTook toolhome )" -lt 20 ] && echo quick || echo "took:$( rigTook toolhome )" ):$( rigHolds toolhome '# returned: immediate' ):$( rigHolds toolhome RIG-HOME-HANDBACK )" "quick:1:1"
rigScene toolchat 25
rigHistory CRIG00001 "$( rigMsg "$(( rigNow - 40 )).000001" URIGOTHER 'RIG-PERSON-TAG @keeper-rig look' )"
rigScan toolchat
rigAssert "control: a person's tag in the same rig still ends it at once" "$( [ "$( rigTook toolchat )" -lt 20 ] && echo quick || echo "took:$( rigTook toolchat )" ):$( rigHolds toolchat '# returned: immediate' )" "quick:1"

echo "-- 9. a session thread where the member's instance is present is FYI, not work --"
rigScene fyi 3
rm -f "$rigData/inboxes/keeper-rig/incoming/"*.md
printf 'CRIGSES01:%s.000001\n' "$(( rigNow - 400 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
## A scan at a start runs before the run's own process exists: what is there is its record, spawn-started, and nothing to ask of a process.
rigInstance rig-run-live spawn-started rig-elsewhere
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigMsg "$(( rigNow - 30 )).000001" URIGOTHER 'RIG-FYI-MENTION @keeper-rig' "$(( rigNow - 400 )).000001" )" > "$rigDir/replies.CRIGSES01.$(( rigNow - 400 )).000001.json"
rigScan fyi
rigAssert "the message is returned, marked FYI in its row and said to be for knowledge only" "$( rigHolds fyi RIG-FYI-MENTION ):$( rigHolds fyi '[fyi: the session chat thread of keeper-rig' ):$( rigHolds fyi 'for your knowledge, not yours to answer' )" "1:1:1"
rigAssert "an FYI is no input for a start: the scan counts as empty"        "$( rigReportEmpty fyi )" empty
rigAssert "and the member is left no work and nothing to wait on: no duty started, no tag news" "$( [ -e "$rigWs/.local/agents/schedule/duty/keeper-rig" ] && echo duty || echo noduty ):$( [ -e "$rigWs/.local/agents/schedule/tags/keeper-rig" ] && echo tag || echo notag )" "noduty:notag"
rigScene fyiabsent 25
rm -f "$rigData/inboxes/keeper-rig/incoming/"*.md
printf 'CRIGSES01:%s.000001\n' "$(( rigNow - 400 ))" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
## The same session thread with the member's run ended: no instance is present there, so the mention is work again.
rigInstance rig-run-ended spawn-succeeded rig-elsewhere
printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigMsg "$(( rigNow - 30 )).000001" URIGOTHER 'RIG-ABSENT-MENTION @keeper-rig' "$(( rigNow - 400 )).000001" )" > "$rigDir/replies.CRIGSES01.$(( rigNow - 400 )).000001.json"
rigScan fyiabsent
rigAssert "no instance present there: the message is a normal item, unmarked" "$( rigHolds fyiabsent RIG-ABSENT-MENTION ):$( rigHolds fyiabsent '[fyi:' )" "1:0"
rigAssert "and the scan is input for a start"                              "$( rigReportEmpty fyiabsent )" input

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY INPUT SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_INPUT_SCAN: OK (%d assertions, offline)\n' "$rigPassCount"
