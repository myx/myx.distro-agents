#!/usr/bin/env bash
## Behavioural check on the per-member routine lock (F4.2): a routine names the document it locks with the macro of
## the member of the start, `routine-lock-document: inbox:{{team-member}}:<note>.md`, so two members who run the same routine hold
## two documents and never contend on one fixed note. Held, with the advance routine's real note name, in a rig of this check's own:
##   1. THE VALIDATOR takes the macro, and refuses any other macro; the real advance routine declares the per-member form
##   2. A START BY THE COORDINATOR locks the note of its own inbox (running while it lives, finished after)
##   3. A START BY ANOTHER MEMBER locks the note of ITS inbox, made at its first start; the coordinator's note is left as it was;
##      the brief and the run's record name the filled document, never the macro
##   4. THE TWO LOCKS ARE INDEPENDENT: while one member holds its note the other takes its own, and a second take of the held one refuses
##   6. THE CONTRACT lists work-duty among the scans `input-scan-def:` may name
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutinePerMemberLockCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigCoordInbox="$rigData/inboxes/magic-coordinator/incoming"
## The lock note of a member other than magic-coordinator lives in its processed/, out of its work (AgentsToolsInboxNotePath).
rigKeeperInbox="$rigData/inboxes/rig-keeper/processed"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/magic-coordinator" "$rigSkills/rig-keeper" "$rigData/board" "$rigCoordInbox"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigAdvance="note-20260809T154715Z-advance-state-and-lock.md"
## The console stand-in: while the run is live it copies the brief and the run's own lock note.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'cp "$RIG_DATA/inboxes/$MDAT_SPAWN_AGENT/incoming/note-20260809T154715Z-advance-state-and-lock.md" "$RIG_SCENARIO/seen.$MDAT_SPAWN_AGENT" 2> /dev/null || cp "$RIG_DATA/inboxes/$MDAT_SPAWN_AGENT/processed/note-20260809T154715Z-advance-state-and-lock.md" "$RIG_SCENARIO/seen.$MDAT_SPAWN_AGENT" 2> /dev/null || :' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in magic-coordinator rig-keeper ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigNote(){ ## inbox dir, member, state, body word
	mkdir -p "$1"
	printf -- '---\ntype: note\nfrom: %s\nowner: %s\nstate: %s\n---\n\n%s\n' "$2" "$2" "$3" "$4" > "$1/$rigAdvance"
}
rigRoutine(){ ## owner member, the lock document
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: %s\nrequires-session-kind: standalone\nroutine-lock-document: %s\nruns-at: none\n---\n' "$1" "$1" "$2"
		printf '# %s.advance.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/$1/$1.advance.routine.md"
}
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## the member to start
	rm -f "$rigTmp"/brief.* "$rigTmp"/seen.*
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_DATA="$rigData" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-per-member "$1" --routine "$1.advance" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
}
rigTool2(){ ## the tool, as the tooling itself, in the rig
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" "$@" < /dev/null 2>&1 )
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
rigValidate(){ ## file -- the rows the routine validator says, then rc=<n>
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --intern-doc-validate routine "$1" 2>&1 < /dev/null ; echo "rc=$?" )
}

echo "-- 1. the validator, and the real advance routine --"
rigRoutine magic-coordinator "inbox:{{team-member}}:$rigAdvance"
rigOut="$( rigValidate "$rigSkills/magic-coordinator/magic-coordinator.advance.routine.md" )"
rigAssert "the macro form of the lock passes the routine validator" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^rc=0$' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'routine-lock-document' || : )" "1:0"
rigRoutine magic-coordinator "inbox:{{nobody}}:$rigAdvance"
rigOut="$( rigValidate "$rigSkills/magic-coordinator/magic-coordinator.advance.routine.md" )"
rigAssert "any other macro is a finding on routine-lock-document" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'routine-lock-document' || : )" "1"
rigAssert "the real advance routine declares the per-member lock" "$( LC_ALL=C grep -c -x "routine-lock-document: inbox:{{team-member}}:$rigAdvance" "$rigPackage/skillset/magic-team/magic-coordinator/magic-coordinator.advance.routine.md" || : )" "1"

echo "-- 2. a start by the coordinator --"
rigRoutine magic-coordinator "inbox:{{team-member}}:$rigAdvance"
rigNote "$rigCoordInbox" magic-coordinator advance-finished "COORDINATOR-NOTE"
rigSpawn magic-coordinator
rigAssert "the start runs" "$rigRc:$( [ -e "$rigTmp/brief.magic-coordinator" ] && echo briefed || echo none )" "0:briefed"
rigAssert "live: the coordinator's note is advance-running with a session id" "$( rigField "$rigTmp/seen.magic-coordinator" state ):$( [ -n "$( rigField "$rigTmp/seen.magic-coordinator" session-id )" ] && echo id || echo none )" "advance-running:id"
rigAssert "after: the coordinator's note is advance-finished" "$( rigField "$rigCoordInbox/$rigAdvance" state )" "advance-finished"

echo "-- 3. a start by another member --"
rigRoutine rig-keeper "inbox:{{team-member}}:$rigAdvance"
rigNote "$rigCoordInbox" magic-coordinator advance-finished "COORDINATOR-NOTE"
rigBefore="$( cksum < "$rigCoordInbox/$rigAdvance" )"
rm -rf "$rigData/inboxes/rig-keeper"
rigSpawn rig-keeper
rigAssert "the start runs" "$rigRc:$( [ -e "$rigTmp/brief.rig-keeper" ] && echo briefed || echo none )" "0:briefed"
rigAssert "live: the keeper's own note is advance-running with a session id" "$( rigField "$rigTmp/seen.rig-keeper" state ):$( [ -n "$( rigField "$rigTmp/seen.rig-keeper" session-id )" ] && echo id || echo none )" "advance-running:id"
rigAssert "after: the keeper's note is advance-finished, in the keeper's inbox" "$( rigField "$rigKeeperInbox/$rigAdvance" state )" "advance-finished"
rigAssert "the coordinator's note is as it was" "$( cksum < "$rigCoordInbox/$rigAdvance" )" "$rigBefore"
rigAssert "the brief names the keeper's document, never the macro" "$( LC_ALL=C grep -q -F "inbox:rig-keeper:$rigAdvance" "$rigTmp/brief.rig-keeper" && echo named || echo missing ):$( LC_ALL=C grep -c -F '{{team-member}}' "$rigTmp/brief.rig-keeper" || : )" "named:0"
rigAssert "the run's record keeps the filled document" "$( LC_ALL=C grep -h -x "routine-lock: inbox:rig-keeper:$rigAdvance" "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | LC_ALL=C sort -u | LC_ALL=C grep -c . || : )" "1"

echo "-- 4. the two locks are independent --"
rigNote "$rigCoordInbox" magic-coordinator advance-finished "COORDINATOR-NOTE"
rigNote "$rigKeeperInbox" rig-keeper advance-finished "KEEPER-NOTE"
rigTool2 --intern-op-routine-lock-take advance magic-coordinator rig-session-one > "$rigTmp/take1.out"; rigTake1=$?
rigTool2 --intern-op-routine-lock-take advance rig-keeper rig-session-two > "$rigTmp/take2.out"; rigTake2=$?
rigTool2 --intern-op-routine-lock-take advance rig-keeper rig-session-three > "$rigTmp/take3.out"; rigTake3=$?
rigTool2 --intern-op-routine-lock-take advance magic-coordinator rig-session-four > "$rigTmp/take4.out"; rigTake4=$?
rigAssert "the coordinator takes its note, the keeper takes its own while that is held" "$rigTake1:$rigTake2" "0:0"
rigAssert "a second take of either held note refuses" "$rigTake3:$rigTake4" "1:1"
rigAssert "each note holds its own session" "$( rigField "$rigCoordInbox/$rigAdvance" session-id ):$( rigField "$rigKeeperInbox/$rigAdvance" session-id )" "rig-session-one:rig-session-two"

echo "-- 6. the contract's scan list and lock form --"
rigContract="$rigPackage/skillset/magic-team/magic-team/contracts/routine.contract.format.md"
rigAssert "routine-lock-document: states the {{team-member}} macro" "$( LC_ALL=C grep -A2 -F -e '- `routine-lock-document:` (optional)' "$rigContract" | LC_ALL=C grep -c -F -e '{{team-member}}' || : )" "1"
rigAssert "input-scan-def: lists work-duty among the scans" "$( LC_ALL=C grep -A2 -F -e '- `input-scan-def:` (optional)' "$rigContract" | LC_ALL=C grep -c -F -e '`work-duty`' || : )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE PER MEMBER LOCK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_PER_MEMBER_LOCK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
