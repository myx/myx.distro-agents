#!/usr/bin/env bash
## Behavioural check on the one way a check of sh-test signals a process it kept for later
## (sh-test/check-fixtures/rig-processes.include.test.sh), and the guard over every other signal of sh-test.
## A process id is a number the system gives again, on a busy host within about a minute: a check that keeps the
## pid of a stand-in and signals it minutes later, in a cleanup or in a trap, signals whoever has that number then.
## Held here:
##   1. THE HELPER, run on stand-in processes of this check's own. A process it noted and that is still itself is
##      signalled. A pid it never noted is not. A NOTED PID WHOSE PROCESS IS GONE AND WHOSE NUMBER ANOTHER PROCESS
##      HAS TAKEN IS NOT SIGNALLED: the note says when its process began, the process that has the number now began
##      at another time, and it lives on, by a plain signal, with its children, from a note kept in a file, and as
##      a group. A process is signalled with what it started. A process group is signalled only while a process
##      this check noted is still itself and a member of it: by its leader, by a member noted earlier once the
##      leader is gone, never where none of its members was noted, never the group this check itself runs in. A
##      stand-in notes itself into a file, and a watchdog in a subshell has the notes of the shell that started it.
##      When a process began is read by the tooling's own reading and by no second one.
##   2. THE GUARD. Every signal a file of sh-test sends outside the helper is on the one list below, each with the
##      reason it is left as it is. A new one that is not on the list fails this check, and so does a line of the
##      list that no longer stands in the code as often as it says. A signal to a kept pid goes through the helper;
##      one is added to the list only with the reason its target cannot be gone and its number given again before
##      the signal. Not read as a signal: a probe (`kill -0`, perl `kill( 0, ... )`), which sends nothing; a
##      comment line; the word inside other text (the manager's kill key and operation, a row it prints).
## Red: without the start time in the note (a helper that signals any pid it once noted), section 1 fails on the
## number another process has taken; a `kill "$somePid"` added to any file of sh-test fails section 2.
## Offline: stand-ins of this check alone (sleep, a shell that waits), all ended at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigHelper="$rigTest/check-fixtures/rig-processes.include.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHelper" ] || rigRefuse "the rig's process helper is not at the origin this workspace resolves: $rigHelper"
. "$rigHelper" || rigRefuse "the rig's process helper could not be read: $rigHelper"
rigTmp="$( mktemp -d -t AgentsTestSignalsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every stand-in of this check, each with when it began, whatever a scenario does to the helper's own notes:
## at the end each is ended, with what it started, only while it is still itself.
rigStandIns="" rigCleanNoted=""
trap 'rigProcNoted="$rigCleanNoted" ; rigProcSignalWithChildren KILL $rigStandIns ; rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigKeep(){ ## pid... -- a stand-in of this check, for its end
	rigStandIns="$rigStandIns $*"
	rigCleanNoted="$rigCleanNoted
$( rigProcBegan "$@" )"
}
rigStand(){ ## -- a stand-in process that only waits; sets rigStandPid. The helper is not told of it: a scenario notes it or does not
	sleep 300 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	disown "$rigStandPid" 2> /dev/null || :
	rigKeep "$rigStandPid"
}
rigAlive(){ ## pid... -- how many of them are processes now
	local aliveCount=0 alivePid
	for alivePid in "$@" ; do ! kill -0 "$alivePid" 2> /dev/null || aliveCount=$(( aliveCount + 1 )) ; done
	printf '%s' "$aliveCount"
}
rigLeftAfter(){ ## pid... -- how many of them are still processes once they had five seconds to end
	local leftTurns=25
	while [ "$( rigAlive "$@" )" != 0 ] && [ "$leftTurns" -gt 0 ] ; do sleep 0.2 ; leftTurns=$(( leftTurns - 1 )) ; done
	rigAlive "$@"
}
rigWaitFile(){ ## file -- waits, ten seconds at most, for it to hold something
	local fileTurns=50
	while [ ! -s "$1" ] && [ "$fileTurns" -gt 0 ] ; do sleep 0.2 ; fileTurns=$(( fileTurns - 1 )) ; done
	[ -s "$1" ]
}
rigGroupOf(){ ## group id -- its members now, a space between them
	ps -A -o pid=,pgid= 2> /dev/null | LC_ALL=C awk -v wantGroup="$1" '$2 == wantGroup { printf "%s ", $1 ; }'
}
## A start that no process of this host has: the note of a process that had a number before the one that has it now.
rigOtherStart="Mon_Jan__1_00:00:00_2001"

echo "-- 1a. a process that was noted and is still itself is signalled; one never noted is not --"
rigStand ; rigOwn="$rigStandPid"
rigProcNote "$rigOwn"
rigAssert "control: the note is the pid and when it began, as the tooling keeps a process" "$( printf '%s\n' "$rigProcNoted" | LC_ALL=C grep -c -E "^$rigOwn [A-Z][a-z]{2}_[A-Z][a-z]{2}_[0-9]{1,2}_[0-9:]{8}_[0-9]{4}\$" )" 1
rigProcSignal TERM "$rigOwn" ; rigRc=$?
rigAssert "a noted process that is still itself is signalled: rc 0, and it is gone" "$rigRc $( rigLeftAfter "$rigOwn" )" "0 0"
rigProcSignal KILL "$rigOwn" ; rigRc=$?
rigAssert "once it is gone and nobody has its number, there is nothing to signal: rc 1" "$rigRc" 1
rigStand ; rigNever="$rigStandPid"
rigProcSignal KILL "$rigNever" ; rigRc=$?
rigProcSignalWithChildren KILL "$rigNever" ; rigRcWith=$?
rigAssert "a pid that was never noted is not signalled, alone or with its children: rc 1, and it lives on" "$rigRc $rigRcWith $( rigAlive "$rigNever" )" "1 1 1"

echo "-- 1b. a noted pid whose process is gone and whose number another process has taken is not signalled --"
## The state a kept pid is in once its number came round: the note is of the process that had the number, with when
## that one began; the process that has the number now began at another time. It is a stand-in of this check, so
## that a helper that did signal it would end nothing of anyone else's.
rigStand ; rigTaken="$rigStandPid"
rigTakenChild="$rigTmp/taken.child"
bash -c 'sleep 300 > /dev/null 2>&1 < /dev/null & echo "$!" > "$1" ; wait' rig-taken "$rigTakenChild" > /dev/null 2>&1 < /dev/null &
rigTakenParent=$! ; disown "$rigTakenParent" 2> /dev/null || :
rigWaitFile "$rigTakenChild" || rigRefuse "the stand-in with a child did not start, so nothing below would be measured"
rigKeep "$rigTakenParent" "$( cat "$rigTakenChild" )"
rigNotedBefore="$rigProcNoted"
rigProcNoted="$rigTaken $rigOtherStart
$rigTakenParent $rigOtherStart"
rigProcSignal KILL "$rigTaken" ; rigRc=$?
rigAssert "its number taken by another process, a noted pid is not signalled: rc 1, and that process lives on" "$rigRc $( rigAlive "$rigTaken" )" "1 1"
rigProcSignalWithChildren KILL "$rigTakenParent" ; rigRc=$?
rigAssert "nor is what that other process started: rc 1, and it and its child live on" "$rigRc $( rigAlive "$rigTakenParent" "$( cat "$rigTakenChild" )" )" "1 2"
printf '%s %s\n' "$rigTaken" "$rigOtherStart" > "$rigTmp/taken.kept"
rigProcNoted=""
rigProcSignalKept KILL "$rigTmp/taken.kept" ; rigRc=$?
rigAssert "nor from a note kept in a file: rc 1, and it lives on" "$rigRc $( rigAlive "$rigTaken" )" "1 1"
rigProcNoted="$rigNotedBefore"
rigProcNote "$rigTaken"
rigProcSignal TERM "$rigTaken" ; rigRc=$?
rigAssert "control: the same process, noted as itself, is signalled: rc 0, and it is gone" "$rigRc $( rigLeftAfter "$rigTaken" )" "0 0"

echo "-- 1c. a process is signalled with what it started --"
rigProcNote "$rigTakenParent"
rigProcSignalWithChildren TERM "$rigTakenParent" ; rigRc=$?
rigAssert "a noted process and the child it started are both ended, though only the process was noted" "$rigRc $( rigLeftAfter "$rigTakenParent" "$( cat "$rigTakenChild" )" )" "0 0"

echo "-- 1d. a process group is signalled only while a process this check noted is still itself and a member of it --"
## A job of this check under job control leads a group of its own. It starts a member, says which, and stays until
## the rig lets it go.
rigJob(){ ## name -- sets rigJobPid, the leader and the group id; the member's pid is in <name>.member
	rm -f "$rigTmp/$1.member" "$rigTmp/$1.go"
	set -m
	( sleep 300 > /dev/null 2>&1 < /dev/null & echo "$!" > "$rigTmp/$1.member" ; while [ ! -e "$rigTmp/$1.go" ] ; do sleep 0.2 ; done ) > /dev/null 2>&1 < /dev/null &
	rigJobPid=$!
	set +m
	disown "$rigJobPid" 2> /dev/null || :
	rigWaitFile "$rigTmp/$1.member" || rigRefuse "the job $1 did not start its member, so nothing of its group would be measured"
	rigKeep "$rigJobPid" "$( cat "$rigTmp/$1.member" )"
}
rigMember(){ cat "$rigTmp/$1.member" ; } ## name
rigJob led ; rigLed="$rigJobPid"
rigAssert "control: the job leads a group of its own, with its member in it, and that is not this check's group" \
	"$( rigGroupOf "$rigLed" | LC_ALL=C grep -c -w -e "$rigLed" ) $( rigGroupOf "$rigLed" | LC_ALL=C grep -c -w -e "$( rigMember led )" ) $( rigGroupOf "$rigLed" | LC_ALL=C grep -c -w -e "$$" )" "1 1 0"
rigProcGroupSignal TERM "$rigLed" ; rigRc=$?
rigAssert "a group none of whose members was noted is not signalled: rc 1, the leader and its member live on" "$rigRc $( rigAlive "$rigLed" "$( rigMember led )" )" "1 2"
rigNotedBefore="$rigProcNoted"
rigProcNoted="$rigLed $rigOtherStart"
rigProcGroupSignal KILL "$rigLed" ; rigRc=$?
rigAssert "nor a group whose leader's number is noted for a process begun at another time: rc 1, and they live on" "$rigRc $( rigAlive "$rigLed" "$( rigMember led )" )" "1 2"
rigProcNoted="$rigNotedBefore"
rigProcNote "$rigLed"
rigProcGroupSignal TERM "$rigLed" ; rigRc=$?
rigAssert "its leader noted and still itself, the group is signalled: rc 0, the leader and its member are gone" "$rigRc $( rigLeftAfter "$rigLed" "$( rigMember led )" )" "0 0"
## The leader gone, a member left: the group is its own still by that member, noted while the leader stood.
rigJob left ; rigLeft="$rigJobPid"
rigProcNote "$rigLeft"
rigProcGroupSignal 0 "$rigLeft" ; rigRc=$?
rigAssert "signal 0 sends nothing and notes the members: rc 0, both live on, and the member is noted" "$rigRc $( rigAlive "$rigLeft" "$( rigMember left )" ) $( printf '%s\n' "$rigProcNoted" | LC_ALL=C grep -c "^$( rigMember left ) " )" "0 2 1"
: > "$rigTmp/left.go"
rigAssert "control: the leader ends by itself, and its member stays in the group it led" "$( rigLeftAfter "$rigLeft" ) $( rigGroupOf "$rigLeft" | LC_ALL=C grep -c -w -e "$( rigMember left )" )" "0 1"
rigProcGroupSignal TERM "$rigLeft" ; rigRc=$?
rigAssert "the leader gone, the group is signalled by the member noted while it stood: rc 0, and the member is gone" "$rigRc $( rigLeftAfter "$( rigMember left )" )" "0 0"
## The same, with no member noted while the leader stood: nothing shows the group to be this check's own.
rigJob lost ; rigLost="$rigJobPid"
rigProcNote "$rigLost"
: > "$rigTmp/lost.go"
rigAssert "control: the leader, the one process of that group that was noted, is gone, and its member stays" "$( rigLeftAfter "$rigLost" ) $( rigAlive "$( rigMember lost )" )" "0 1"
rigProcGroupSignal KILL "$rigLost" ; rigRc=$?
rigAssert "the leader gone and no member noted, the group is not signalled: rc 1, and the member lives on" "$rigRc $( rigAlive "$( rigMember lost )" )" "1 1"
rigOwnGroup="$( ps -o pgid= -p $$ 2> /dev/null | LC_ALL=C tr -d ' ' )"
rigProcNote $$
rigProcGroupSignal 0 "$rigOwnGroup" ; rigRc=$?
rigAssert "the group this check itself runs in is never signalled, though the check is noted: rc 1" "${rigOwnGroup:+known} $rigRc" "known 1"

echo "-- 1e. a stand-in notes itself into a file, and a subshell has the notes of the shell that started it --"
bash -c '. "$1" ; rigProcNoteFile "$2" $$ ; exec sleep 300' rig-self "$rigHelper" "$rigTmp/self.began" > /dev/null 2>&1 < /dev/null &
rigSelf=$! ; disown "$rigSelf" 2> /dev/null || :
rigWaitFile "$rigTmp/self.began" || rigRefuse "the stand-in that notes itself did not start, so nothing of its note would be measured"
rigKeep "$rigSelf"
rigAssert "the note a stand-in keeps of itself is its own pid and when it began, one line" "$( LC_ALL=C awk -v wantPid="$rigSelf" '$1 == wantPid && NF == 2 { hit++ ; } END { print NR + 0, hit + 0 ; }' "$rigTmp/self.began" )" "1 1"
rigAssert "control: this shell had no note of it" "$( printf '%s\n' "$rigProcNoted" | LC_ALL=C grep -c "^$rigSelf " )" 0
rigProcSignalKept KILL "$rigTmp/self.began" ; rigRc=$?
rigAssert "it is signalled from the note it kept: rc 0, and it is gone" "$rigRc $( rigLeftAfter "$rigSelf" )" "0 0"
rigStand ; rigGuarded="$rigStandPid"
rigProcNote "$rigGuarded"
( sleep 1 ; rigProcSignal TERM "$rigGuarded" ) > /dev/null 2>&1 &
wait $!
rigAssert "a watchdog in a subshell signals what was noted before it was started: gone" "$( rigLeftAfter "$rigGuarded" )" 0

echo "-- 1f. when a process began is read by the tooling's own reading, and by no second one --"
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment
rigAssert "the helper reads it through AgentsToolsRegistryProcessesBegan of the tooling, and names no start column of ps itself" \
	"$( rigCode "$rigHelper" | LC_ALL=C grep -c -F 'AgentsToolsRegistryProcessesBegan' ) $( rigCode "$rigHelper" | LC_ALL=C grep -c -e 'lstart' -e 'etime' -e 'start_time' )" "2 0"
rigAssert "that reading stands in the tooling" "$( LC_ALL=C grep -c '^AgentsToolsRegistryProcessesBegan(){' "$rigPackage/sh-lib/AgentsTools.Registries.include" )" 1
rigAssert "and nothing of the tooling is defined in the check that sourced the helper" "$( type AgentsToolsRegistryProcessesBegan > /dev/null 2>&1 && echo defined || echo not-defined )" "not-defined"

echo "-- 2. the guard: every signal of sh-test outside the helper is on the list, with its reason --"
## THE REASONS a signal is left outside the helper, each by its name.
rigReasons(){
	printf '%s\n' \
		'@at-once|sent in the statement after its target was started, or was read from the process list or from the live state of a run the rig holds open: no time for the number to come round' \
		'@probed|a job of this shell, in a group the rig made itself (set -m) where a group is signalled: a probe in the statement before, and at each turn of its wait since it was started, found it running; where a second signal follows it comes a second or two later, to what the first left' \
		'@running-job|only while the shell lists it among its running jobs (jobs -pr), which no process of another has ever been, with what is under it read at that moment' \
		'@kept-start|kept with when it began and signalled only while its pid is still that process: the keep this check made for itself before the shared helper' \
		'@own-watch|the watch of this very call: it lives until the call returns and a second at most beyond, and is signalled in the statement after the call returned' \
		'@self|to the process itself, which sends it to see that it handles it' \
		'@uncollected|its own child, which it has not collected yet: the number of such a child is never given again' \
		'@own-path|a sweep by pattern that only the processes of this rig can match: the pattern is the path of a file in the temp folder this run made for itself (mktemp), which only the wait this rig started, and the reader of this very sweep, carry on their command lines; reached only when that wait did not come back' \
		'@handed-on|no signal of the check: a stand-in for the `kill -0` of the tooling under test, which hands every other call of the tooling on as it came' \
		'@text|no signal: the word is text, a row the kill operation of the manager prints, the form of such a row, or a pattern the check reads the code of the tooling with' \
		'@kept-copy|NOT SAFE, AND LEFT: the kept copy of the previous hooks file, which its diff check holds as it was; its watchdog signals the pid of a hook sixty seconds later, as the present sh-lib/AgentsHarnessHooks.sh does, and both are for the owner of the tooling'
}
## THE LIST. One line a signal: file, under sh-test|how many times it stands there|the text of the signal|its reason,
## by name (@...) or written out. The longest text of a file is taken first.
rigList(){
	printf '%s\n' \
		'AgentsAdvanceInputScanStatesCheck.test.sh|1|kill -TERM "$( cat "$rigTmp/b10/console.pid" )"|read from the pid file its stand-in console wrote seconds before, in the statement after the tooling'"'"'s own reading found that pid and its start to be the process the record names; the signal is what the check asserts on' \
		'AgentsAdvanceInputScanStatesCheck.test.sh|1|kill "$rigMcpPid"|@probed' \
		'AgentsEscalationVerdictFirstLineCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsEscalationVerdictFirstLineCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskCheck.test.sh|1|kill -TERM -- "-$askPid"|@probed' \
		'AgentsHarnessAskCheck.test.sh|1|kill -KILL -- "-$askPid"|@probed' \
		'AgentsHarnessAskForgedMarkCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskForgedMarkCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskFormsCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskFormsCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskMemberSenderCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskMemberSenderCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskNumberedReplyCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskNumberedReplyCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskOptionsSelectCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskOptionsSelectCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskOwnerBotCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskOwnerBotCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskPlaceCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskPlaceCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskRewaitCheck.test.sh|1|kill -TERM -- "-$askPid"|@probed' \
		'AgentsHarnessAskRewaitCheck.test.sh|1|kill -KILL -- "-$askPid"|@probed' \
		'AgentsHarnessAskSessionWaitCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskSessionWaitCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessAskThreadCheck.test.sh|1|kill -TERM -- "-$askPid"|@probed' \
		'AgentsHarnessAskThreadCheck.test.sh|1|kill -KILL -- "-$askPid"|@probed' \
		'AgentsHarnessAskVerdictWordsCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessAskVerdictWordsCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessEscalationEdgeCheck.test.sh|2|kill "$rigGonePid"|@at-once' \
		'AgentsHarnessPermissionCheck.test.sh|1|kill -TERM -- "-$rigAskPid"|@probed' \
		'AgentsHarnessPermissionCheck.test.sh|1|kill -KILL -- "-$rigAskPid"|@probed' \
		'AgentsHarnessPermissionFolderCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionFolderCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionJoinCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionJoinCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionProjectCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionProjectCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionSetAskCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessPermissionSetAskCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessProposeApproveCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsHarnessProposeApproveCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsHarnessWaitCheck.test.sh|2|kill -TERM "$opPid"|@probed' \
		'AgentsHarnessWaitCheck.test.sh|2|kill -KILL "$opPid"|@probed' \
		'AgentsHarnessWaitCheck.test.sh|2|kill -TERM "$opWatchPid"|@own-watch' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill -KILL "$cleanPid"|@kept-start' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill -TERM "$( rigPid run-hard )"|a stand-in started seconds before, which has just said it is ready and stays five minutes; the TERM it ignores is the control of the scenario' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill sess-one run-a keeper-rig ended spawn-started|@text' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill <.*>|@text' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill <session-id> <spawn-id> <member> <outcome> <status> <pids> <item>|@text' \
		'AgentsManagerSessionKillCheck.test.sh|1|kill +(-[A-Za-z0-9]+ +)?(-- +)?|@text' \
		'AgentsNeedsReplyMarkerCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsNeedsReplyMarkerCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsPendingReplyOwnWordsCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsPendingReplyOwnWordsCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsPendingReplyRemindCheck.test.sh|1|kill -TERM -- "-$rigAskPid"|a job of this shell in a group the rig made itself (set -m), which waits for an answer that never comes: a probe each second until two seconds before found it running' \
		'AgentsPendingReplyRemindCheck.test.sh|1|kill -KILL -- "-$rigAskPid"|a job of this shell in a group the rig made itself (set -m), which waits for an answer that never comes: a probe each second until two seconds before found it running' \
		'AgentsPermissionPostLeadCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsPermissionPostLeadCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsRefusedTargetDecodeCheck.test.sh|1|kill -TERM -- "-$askPid"|@probed' \
		'AgentsRefusedTargetDecodeCheck.test.sh|1|kill -KILL -- "-$askPid"|@probed' \
		'AgentsReviewFlowCheck.test.sh|1|kill "$pipedPid"|@probed' \
		'AgentsRootSessionEndCheck.test.sh|1|kill -INT -"$rigRootPid"|to the group its own stand-in for a terminal made (setpgrp), a second after a probe found its leader waiting; the interrupt is what the check asserts on' \
		'AgentsRootSessionEndCheck.test.sh|1|kill -KILL -"$rigRootPid"|@probed' \
		'AgentsRunTests.sh|1|kill "-$endSignal" "$endPid"|@at-once' \
		'AgentsRunTests.sh|1|kill "$watchSleep"|the one sleep this watch waits on at that very moment: the variable is emptied as soon as that wait returns' \
		'AgentsRunTests.sh|1|kill "$runStallPid"|@running-job' \
		'AgentsRunTestsQueueCheck.test.sh|1|kill -TERM "$rigTicketB"|the pid of its ticket, read in the statement before from the line of a run this rig started and holds waiting behind a lock' \
		'AgentsRunTestsQueueCheck.test.sh|1|kill -KILL "$rigSlotGiver" "$rigPidA"|@at-once' \
		'AgentsRunTestsQueueCheck.test.sh|1|kill -KILL "$rigSlotPid"|@at-once' \
		'AgentsRunTestsStallCheck.test.sh|1|kill -KILL "$1" $( rigUnder "$1" )|@running-job' \
		'AgentsRunTestsStallCheck.test.sh|1|kill -STOP "$rigWorkerPid"|@at-once' \
		'AgentsSessionAddressCheck.test.sh|1|kill -TERM -- "-$askPid"|@probed' \
		'AgentsSessionAddressCheck.test.sh|1|kill -KILL -- "-$askPid"|@probed' \
		'AgentsSlackSendLogAppendCheck.test.sh|1|os.kill(os.getpid(), signal.SIGTERM)|@self' \
		'AgentsSpawnConsoleRunCheck.test.sh|1|kill(){|@handed-on' \
		'AgentsSpawnConsoleRunCheck.test.sh|1|builtin kill "$@"|@handed-on' \
		'AgentsSpawnDetachCheck.test.sh|1|kill "$!"|@at-once' \
		'AgentsSpawnProxyCloseCommitCheck.test.sh|1|kill -TERM -- "-$rigProxyPid"|four seconds after the rig started it as its own job, in a group of its own (set -m); the interrupt is what the check asserts on' \
		'AgentsSpawnProxyCloseCommitCheck.test.sh|1|kill -KILL -- "-$rigProxyPid"|@probed' \
		'AgentsWaitRoundCheck.test.sh|1|kill -TERM -- "-$callPid"|@probed' \
		'AgentsWaitRoundCheck.test.sh|1|kill -KILL -- "-$callPid"|@probed' \
		'AgentsWaitRoundCheck.test.sh|1|pkill -TERM -P "$rigOpPid"|@probed' \
		'AgentsWaitRoundCheck.test.sh|1|kill -TERM "$rigOpPid"|@probed' \
		'AgentsWaitRoundCheck.test.sh|1|kill -TERM "$rigOpLeft"|@own-path' \
		'check-fixtures/AgentsHarnessHooks.legacy.sh|1|kill -TERM "$hookRunPid"|@kept-copy' \
		'check-fixtures/AgentsHarnessHooks.legacy.sh|1|kill -TERM "$hookWatchPid"|@kept-copy' \
		'check-fixtures/manager-screen.driver.test.py|1|process.kill()|@uncollected'
}
## THE READER. A signal is the word of a command that sends one, where it stands as a command: first of its line,
## after what ends or opens a command, or after a word that takes a command; or a call of that name in perl or
## python. A probe sends nothing and is not one. What the list holds for the file is taken out of the line first;
## a signal that is left is not on the list.
rigGuard(){ ## list file, then the files
	LC_ALL=C awk -F'|' '
		function guardSignal( text,    word, pre, post, last ) {
			while ( match( text, /pkill|killall|killpg|kill|\.terminate[ \t]*\(|\.send_signal[ \t]*\(/ ) ) {
				word = substr( text, RSTART, RLENGTH ) ;
				pre = substr( text, 1, RSTART - 1 ) ;
				post = substr( text, RSTART + RLENGTH ) ;
				text = post ;
				if ( substr( word, 1, 1 ) == "." ) { return 1 ; }
				if ( pre ~ /[A-Za-z0-9_]$/ || post ~ /^[A-Za-z0-9_-]/ ) { continue ; }
				if ( post ~ /^[ \t]*\(/ ) {
					if ( post ~ /^[ \t]*\([ \t]*0[ \t]*,/ || post ~ /^[ \t]*\([^,()]*,[ \t]*0[ \t]*\)/ ) { continue ; }
					return 1 ;
				}
				if ( pre ~ /\.$/ ) { continue ; }
				if ( post != "" && post !~ /^[ \t]/ ) { continue ; }
				sub( /[ \t]+$/, "", pre ) ;
				last = pre ; sub( /^.*[^A-Za-z0-9_-]/, "", last ) ;
				if ( pre == "" || pre ~ /[;&|(){!`\047"]$/ || last ~ /^(do|then|else|elif|if|while|until|builtin|command|exec|-exec|xargs|nohup|time|sudo|and|or|unless)$/ ) {
					if ( post ~ /^[ \t]+-0([ \t]|$)/ || post ~ /^[ \t]+-s[ \t]+0([ \t]|$)/ || post ~ /^[ \t]+0[ \t]*(,|=>)/ ) { continue ; }
					return 1 ;
				}
			}
			return 0 ;
		}
		FNR == NR {
			if ( $0 == "" ) { next ; }
			if ( NF != 4 || $2 !~ /^[0-9]+$/ || $3 == "" || $4 == "" ) { print "LIST: not `file|times|text|reason`: " $0 ; next ; }
			listTotal++ ; listFile[listTotal] = $1 ; listWant[listTotal] = $2 + 0 ; listText[listTotal] = $3 ; listGot[listTotal] = 0 ;
			next ;
		}
		{
			lineText = $0 ; sub( /^[ \t]+/, "", lineText ) ;
			if ( substr( lineText, 1, 1 ) == "#" ) { next ; }
			if ( lineText !~ /kill|\.terminate|\.send_signal/ ) { next ; }
			## the longest text of the list first, so no signal is taken for the start of a longer one
			do {
				bestAt = 0 ; bestLen = 0 ;
				for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
					if ( listFile[listAt] == FILENAME && length( listText[listAt] ) > bestLen && index( lineText, listText[listAt] ) ) { bestAt = listAt ; bestLen = length( listText[listAt] ) ; }
				}
				if ( bestAt ) {
					textAt = index( lineText, listText[bestAt] ) ; listGot[bestAt]++ ;
					lineText = substr( lineText, 1, textAt - 1 ) " " substr( lineText, textAt + bestLen ) ;
				}
			} while ( bestAt ) ;
			if ( guardSignal( lineText ) ) { print "NOT ON THE LIST: " FILENAME ":" FNR ": " $0 ; }
		}
		END {
			for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
				if ( listGot[listAt] != listWant[listAt] ) { print "LIST: " listFile[listAt] " holds `" listText[listAt] "` " listGot[listAt] " time(s), the list says " listWant[listAt] ; }
			}
		}
	' "$@"
}
rigList > "$rigTmp/list"
rigReasons > "$rigTmp/reasons"
## Every file of sh-test but two: the helper, where the signals of a kept pid are meant to stand, and this check, whose
## list and controls are the texts of signals. What this check itself sends is read further down.
rigSelf="${0##*/}"
( cd "$rigTest" && find . -type f | LC_ALL=C sed 's|^\./||' | LC_ALL=C grep -v -x -F -e 'check-fixtures/rig-processes.include.test.sh' -e "$rigSelf" | LC_ALL=C sort ) > "$rigTmp/files"
rigAssert "control: the files of sh-test are read, the runner, the fixtures and the checks among them, and none has a space in its name" \
	"$( [ "$( wc -l < "$rigTmp/files" | LC_ALL=C tr -d ' ' )" -ge 200 ] && echo many ) $( LC_ALL=C grep -c -x -F -e 'AgentsRunTests.sh' -e 'check-fixtures/manager-screen.driver.test.py' -e 'check-fixtures/AgentsHarnessHooks.legacy.sh' -e 'AgentsReviewFlowCheck.test.sh' "$rigTmp/files" || : ) $( LC_ALL=C grep -c ' ' "$rigTmp/files" || : )" "many 4 0"
rigGuardOut="$( cd "$rigTest" && rigGuard "$rigTmp/list" $( cat "$rigTmp/files" ) )"
rigAssert "every signal of sh-test outside the helper is on the list, and every line of the list stands in the code as often as it says (a signal to a pid that was kept goes through the helper, or is listed with the reason its target cannot be gone and its number given again)" "${rigGuardOut:-none}" "none"
rigAssert "every line of the list gives its reason: one of the named ones, or one written out" \
	"$( LC_ALL=C awk -F'|' 'FNR == NR { reasonNamed[$1] = 1 ; next ; } { if ( substr( $4, 1, 1 ) == "@" ? ! ( $4 in reasonNamed ) : length( $4 ) < 20 ) { bad++ ; } } END { print FNR + 0 " lines, " bad + 0 " without a reason" ; }' "$rigTmp/reasons" "$rigTmp/list" )" "$( wc -l < "$rigTmp/list" | LC_ALL=C tr -d ' ' ) lines, 0 without a reason"
rigAssert "and every named reason is used, and says why" "$( LC_ALL=C awk -F'|' 'FNR == NR { reasonUsed[$4] = 1 ; next ; } { if ( ! ( $1 in reasonUsed ) || length( $2 ) < 20 ) { bad++ ; } } END { print bad + 0 ; }' "$rigTmp/list" "$rigTmp/reasons" )" 0
## CONTROL LINES: the reader does find a new signal, in each shape, takes a listed one, and reads no probe, no comment, no other text
mkdir -p "$rigTmp/probe/check-fixtures"
printf '%s\n' '	## a comment that says kill "$probePid" is not read' \
	'	while kill -0 "$probePid" 2> /dev/null ; do sleep 1 ; done' \
	'	rigProcSignal TERM "$probePid"' \
	'	rigAssert "the kill key asks first" "[ keys: k kill l log]" "[--manager-session-kill]"' \
	'	{ kill -TERM -- "-$probeOld" ; sleep 1 ; wait "$probeOld" ; } 2> /dev/null' \
	'	trap '"'"'for probeEach in $probePids ; do pkill -P "$probeEach" ; done'"'"' EXIT' \
	'	[ -z "$probeNew" ] || kill "$probeNew" 2> /dev/null' \
	'	( sleep 60 ; kill -KILL -- "-$probeGroup" ) &' \
	'	killall -u "$USER" sleep' \
	'	bash -c '"'"'kill "$1"'"'"' rig-probe "$probeQuoted"' > "$rigTmp/probe/Probe.test.sh"
printf '%s\n' 'if process.poll() is None:' '    process.terminate()' '    os.kill(childPid, signal.SIGTERM)' '    os.kill(childPid, 0)' > "$rigTmp/probe/check-fixtures/probe.py"
printf '%s\n' 'Probe.test.sh|1|kill -TERM -- "-$probeOld"|a reason long enough to stand in a control' > "$rigTmp/probe/list"
rigAssert "control: each signal that is not on the list is found, with its file and line, whatever its shape, and nothing else of those files is" \
	"$( cd "$rigTmp/probe" && rigGuard "$rigTmp/probe/list" Probe.test.sh check-fixtures/probe.py | LC_ALL=C sed 's/^\(NOT ON THE LIST: [^:]*:[0-9]*\):.*/\1/' | LC_ALL=C tr '\n' ' ' )" \
	"NOT ON THE LIST: Probe.test.sh:6 NOT ON THE LIST: Probe.test.sh:7 NOT ON THE LIST: Probe.test.sh:8 NOT ON THE LIST: Probe.test.sh:9 NOT ON THE LIST: Probe.test.sh:10 NOT ON THE LIST: check-fixtures/probe.py:2 NOT ON THE LIST: check-fixtures/probe.py:3 "
printf '%s\n' 'Probe.test.sh|2|kill -TERM -- "-$probeOld"|a reason long enough to stand in a control' 'Probe.test.sh|1|pkill -P "$probeEach"|a reason long enough to stand in a control' 'Probe.test.sh|1|kill "$probeNew"|a reason long enough to stand in a control' \
	'Probe.test.sh|1|kill -KILL -- "-$probeGroup"|a reason long enough to stand in a control' 'Probe.test.sh|1|killall -u "$USER" sleep|a reason long enough to stand in a control' 'Probe.test.sh|1|kill "$1"|a reason long enough to stand in a control' \
	'check-fixtures/probe.py|1|process.terminate()|a reason long enough to stand in a control' 'check-fixtures/probe.py|1|os.kill(childPid, signal.SIGTERM)|a reason long enough to stand in a control' > "$rigTmp/probe/list"
rigAssert "control: with each of them listed nothing is found, and a line of the list that the code holds another number of times is said" \
	"$( cd "$rigTmp/probe" && rigGuard "$rigTmp/probe/list" Probe.test.sh check-fixtures/probe.py )" 'LIST: Probe.test.sh holds `kill -TERM -- "-$probeOld"` 1 time(s), the list says 2'
## END OF CONTROL LINES
## This check itself: what it sends goes through the helper, and nothing else does. Its list, its reasons and its
## control lines are texts of signals and are taken out before it is read.
LC_ALL=C sed -e '/^rigList(){$/,/^}$/d' -e '/^rigReasons(){$/,/^}$/d' -e '/^## CONTROL LINES/,/^## END OF CONTROL LINES/d' "$0" > "$rigTmp/Self.test.sh"
printf '%s\n' 'Self.test.sh|0|nothing of this check is listed|whatever it signals goes through the helper' > "$rigTmp/self.list"
rigAssert "this check itself sends no signal outside the helper" "$( cd "$rigTmp" && rigGuard "$rigTmp/self.list" Self.test.sh )$( LC_ALL=C grep -c 'rigProcSignal' "$rigTmp/Self.test.sh" | LC_ALL=C awk '{ print ( $1 > 5 ) ? "" : " and too few through the helper: " $1 ; }' )" ""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TEST SIGNALS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TEST_SIGNALS: OK (%d assertions, offline)\n' "$rigPasses"
