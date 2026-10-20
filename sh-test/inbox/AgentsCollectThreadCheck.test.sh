#!/usr/bin/env bash
## Behavioural check on the thread that updates the sources an input scan reads (F4.2, Settled): where other configured sources of the
## members a scan reads are long expired, which shows no daemon updates them, a scan carefully starts ONE thread that checks them all; a
## full team rig keeps it from the main loop, as it keeps its control threads. Held, against a fake imaplib and a fake curl, in rigs of
## this check's own, every process it starts ended by it through the rig's process helper:
##   1. THE CHECK a scan and the main loop make: off where MDAT_COLLECT_THREAD is off; nothing where nothing is configured; a thread
##      where a source is long expired (a scan) or configured (the main loop); none twice; the situation looked at once in five minutes
##   2. THE SCAN starts it for a source of ANOTHER member, and not for its own: a scan that used the one source of the one member it
##      acts for starts nothing
##   3. THE PROCESS: one on a host, shown as its operation, no run of any session; it collects by itself; its lock names it; TERM ends
##      it in order; a lock whose holder is gone is taken over; with nobody wanting it it ends by itself
##   4. A SOURCE THAT FAILED is left to the scans for ten minutes: the thread does not hammer it
##   5. ONE PASS (--one), and the places: the main loop, the runner, the rig fixture, no mode
## Offline: a fake imaplib and a fake curl first, every workspace a folder of the rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
for rigFixture in collect-sources.imaplib.stub.py collect-sources.curl.stub.sh rig-processes.include.sh rig-control-threads.include.sh rig-temp.include.sh ; do
	[ -f "$rigFixtures/$rigFixture" ] || rigRefuse "the fixture $rigFixture is missing from the package"
done
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigFixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends threads is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCollectThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/bin" "$rigTmp/py"
cp "$rigFixtures/collect-sources.imaplib.stub.py" "$rigTmp/py/imaplib.py"
cp "$rigFixtures/collect-sources.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:/usr/bin:/bin"

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
rigCount(){ ## file, extended regex
	LC_ALL=C grep -c -E -- "$2" "$1" 2> /dev/null || :
}
rigDir="" rigFix="" rigRc=0 rigOpEnv=""
## A workspace: bare (members, nothing configured), conf (rig-member holds a mailbox and runs the sweep), two (conf, and client-rig holds a mailbox).
rigScene(){ ## name, kind
	rigDir="$rigTmp/$1" rigFix="$rigTmp/$1/fix"
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/data/inboxes" "$rigDir/data/board" "$rigFix" "$rigDir/skills/rig-member" "$rigDir/skills/client-rig"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/skills/rig-member/rig-member.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/skills/client-rig/client-rig.basic.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	case "$2" in
		conf|two)
			printf -- '---\ntype: routine\nexecutors: rig-member\ninput-scan-def: sweep\n---\n# rig-member.sweep.routine\n' > "$rigDir/skills/rig-member/rig-member.sweep.routine.md"
			printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=rig@rig.invalid\nEMAIL_APP_PASSWORD=rig-app-password-SECRET\n' > "$rigDir/ws/.local/.agents/rig-member.agent.env"
		;;
	esac
	case "$2" in
		two) printf 'EMAIL_IMAP_HOST=imap.rig.invalid\nEMAIL_USER=client@rig.invalid\nEMAIL_APP_PASSWORD=rig-app-password-SECRET\n' > "$rigDir/ws/.local/.agents/client-rig.agent.env" ;;
	esac
	printf '201 unseen\n202 unseen\n' > "$rigFix/mailbox"
}
## The tool in the scene's workspace: arguments are the operation's; output and errors kept as <name>.out and <name>.err, the status in rigRc.
rigRunTool(){ ## name, args...
	local runName="$1"
	shift
	rigRc=0
	: > "$rigFix/imap.log"
	( cd "$rigDir/ws" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigPath" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDAT_SKILLSET_ROOT="$rigDir/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" PYTHONPATH="$rigTmp/py" PYTHONDONTWRITEBYTECODE=1 FIX_DIR="$rigFix" MDAT_COLLECT_LOCK_TRIES=1 \
		$rigOpEnv bash "$rigTool" "$@" ) > "$rigDir/$runName.out" 2> "$rigDir/$runName.err" < /dev/null || rigRc=$?
}
rigOp(){ ## name, args... -- --intern-source-collect with them
	local opName="$1"
	shift
	rigRunTool "$opName" --intern-source-collect "$@"
}
rigWord(){ ## name -- the first word of what the operation said
	LC_ALL=C awk 'NR == 1 { print $1 }' "$rigDir/$1.out"
}
rigPidOf(){ ## name -- the pid a start said
	LC_ALL=C awk 'NR == 1 && ( $1 == "started" || $1 == "alive" ) && $2 ~ /^[0-9]+$/ { print $2 }' "$rigDir/$1.out"
}
rigNote(){ ## pid -- noted for the end of this check
	[ -z "$1" ] || { rigProcNote "$1" ; rigStarted="$rigStarted $1" ; }
}
rigLockPid(){
	readlink "$rigDir/ws/.local/agents/collect/thread.lock" 2> /dev/null | LC_ALL=C awk '{ print $1 }'
}
rigWaitFor(){ ## seconds*2, command... -- waits until the command succeeds
	local waitMax="$1" waitN=0
	shift
	while [ "$waitN" -lt "$waitMax" ] ; do
		"$@" && return 0
		sleep 0.5 ; waitN=$(( waitN + 1 ))
	done
	return 1
}
rigNotes(){ ## inbox member -- how many collected mails it holds
	ls -1 "$rigDir/data/inboxes/$1/incoming" 2> /dev/null | LC_ALL=C grep -c -- '-email-u' || :
}
rigHasNotes(){ ## inbox member, count
	[ "$( rigNotes "$1" )" -ge "$2" ]
}
rigLockGone(){
	[ ! -L "$rigDir/ws/.local/agents/collect/thread.lock" ]
}

echo "-- 1. the check --"
rigScene c-bare bare
rigOpEnv="MDAT_COLLECT_THREAD=off"
rigOp off --check
rigOpEnv=""
rigAssert "off where MDAT_COLLECT_THREAD is off, and nothing is wanted or started" "$rigRc:$( rigWord off ):$( [ -e "$rigDir/ws/.local/agents/collect/thread.wanted" ] && printf made )" "0:off:"
rigOp bare-main --check --main-loop
rigAssert "the main loop, with nothing configured: quiet" "$( rigWord bare-main ):$( [ -e "$rigDir/ws/.local/agents/collect/thread.lock" ] && printf lock ):$( [ -e "$rigDir/ws/.local/agents/collect/thread.checked" ] && printf checked )" "quiet::checked"
rigOp bare-again --check --main-loop
rigAssert "and not looked at again inside five minutes" "$( rigWord bare-again )" "waiting"
rigScene c-conf conf
rigOp conf-scan --check
rigPid="$( rigPidOf conf-scan )"
rigNote "$rigPid"
rigAssert "a scan's check, a source of a member a scan reads never checked: a thread is started" "$( rigWord conf-scan ):$( [ -n "$rigPid" ] && printf pid )" "started:pid"
rigWaitFor 20 test -L "$rigDir/ws/.local/agents/collect/thread.lock"
rigOp conf-again --check
rigAssert "the next check is told it lives, and starts nothing" "$( rigWord conf-again ):$( rigPidOf conf-again )" "alive:${rigPid:-none}"
rigAssert "it was wanted" "$( [ -s "$rigDir/ws/.local/agents/collect/thread.wanted" ] && printf yes )" yes
rigProcSignal TERM "${rigPid:-0}"
rigWaitFor 30 rigLockGone

echo "-- 2. the scan starts it for another member's source --"
rigScene s-one conf
rigScanOp(){ ## name -- a scan of rig-member's mail, with the thread allowed
	rigRunTool "$1" --intern-op-session-context-scan rig-member --all-types --do-email --no-slack --no-trello --no-board-related --no-inbox-notes --no-inbox-inquiry --no-inbox-reflections --no-inbox-other
}
rigScanOp scan-one
rigAssert "a scan that used the one source of the one member it acts for starts nothing" "$rigRc:$( [ -e "$rigDir/ws/.local/agents/collect/thread.lock" ] && printf lock ):$( rigCount "$rigDir/scan-one.out" '^## email-message (201|202)$' )" "0::2"
rigScene s-two two
rigScanOp scan-two
rigPid2="$( rigLockPid )"
rigWaitFor 20 test -L "$rigDir/ws/.local/agents/collect/thread.lock"
rigPid2="$( rigLockPid )"
rigNote "$rigPid2"
rigAssert "with another member's source long expired, the scan starts the thread" "$rigRc:$( [ -n "$rigPid2" ] && printf started )" "0:started"
rigWaitFor 40 rigHasNotes client-rig 2
rigAssert "which collects that source, on the client side, by itself" "$( rigNotes client-rig )" "2"
rigAssert "the scan itself had read its own, and the document is whole" "$( rigCount "$rigDir/scan-two.out" '^## email-message (201|202)$' )" "2"
rigProcSignal TERM "${rigPid2:-0}"
rigWaitFor 30 rigLockGone

echo "-- 3. the process --"
rigScene p-proc conf
## The member has swept up to 2026-10-09 12:00 UTC: the scan bounds the search of its mailbox by the day before, and so does the thread.
mkdir -p "$rigDir/data/inboxes/rig-member/incoming"
printf -- '---\nlast_swept_ts: 1791547200.000000\n---\n\n# sweep-state-note\n' > "$rigDir/data/inboxes/rig-member/incoming/note-20260812T231137Z-sweep-state.md"
rigOpEnv="MDAT_COLLECT_PASS_SECONDS=1"
rigOp proc-start --start
rigOpEnv=""
rigDaemon="$( rigPidOf proc-start )"
rigNote "$rigDaemon"
rigAssert "a start says it started a process" "$( rigWord proc-start )" started
rigWaitFor 20 test -L "$rigDir/ws/.local/agents/collect/thread.lock"
rigAssert "the lock names it: its pid, and when it began" "$( rigLockPid ):$( readlink "$rigDir/ws/.local/agents/collect/thread.lock" 2> /dev/null | LC_ALL=C awk 'NF == 2 { print "two" }' )" "${rigDaemon:-none}:two"
rigAssert "it shows in the process list as its operation, a process of its own" "$( LC_ALL=C ps -ww -o args= -p "${rigDaemon:-0}" 2> /dev/null | LC_ALL=C grep -c -F -e '--intern-source-collect --run' )" 1
rigAssert "it is no run of any session, by the rule that tells a run" "$( cd "$rigDir/ws" && MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/team-data/AgentsTools.Registries.include' ; ps -ww -o pid=,args= -p ${rigDaemon:-0} | AgentsToolsRegistryRunWords | wc -l | tr -d ' '" )" 0
rigWaitFor 40 rigHasNotes rig-member 2
rigAssert "it collects by itself: the mail is in the inbox of the member" "$( rigNotes rig-member )" "2"
rigAssert "bounded as the scan bounds it: since the day before the member's stored sweep position, not the backlog of years" "$( rigCount "$rigFix/imap.log" '^UID SEARCH UNSEEN SINCE 08-Oct-2026$' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "bounded" : "unbounded" }' )" bounded
rigAssert "its log says it started, and the start line names its process" "$( LC_ALL=C grep -c 'the source collector runs as pid' "$rigDir/ws/.local/agents/collect/thread.log" ):$( LC_ALL=C grep -c 'a start of the source collector is made: pid' "$rigDir/ws/.local/agents/collect/thread.log" )" "1:1"
rigOp proc-again --start
rigAssert "a second start is told it lives, and starts nothing" "$( rigWord proc-again ):$( rigPidOf proc-again )" "alive:${rigDaemon:-none}"
rigRunTool proc-second --intern-source-collect --run
rigAssert "a second process of it is refused while one holds the lock" "$rigRc:$( rigCount "$rigDir/proc-second.err" 'already runs as pid' )" "1:1"
printf '203 unseen\n' >> "$rigFix/mailbox"
rigAge(){ ## seconds -- the check time of the mailbox moved back, so that its TTL has passed
	LC_ALL=C awk -v old="$(( $(date +%s) - $1 ))" '$1 == "checked-at" { print "checked-at " old ; next ; } { print ; }' "$rigDir/ws/.local/agents/collect/mail.rig-member.state" > "$rigDir/ws/.local/agents/collect/mail.rig-member.state.new" && mv "$rigDir/ws/.local/agents/collect/mail.rig-member.state.new" "$rigDir/ws/.local/agents/collect/mail.rig-member.state"
}
rigAge 3600
rigWaitFor 40 rigHasNotes rig-member 3
rigAssert "and a new mail, once the TTL of the source has passed, with no scan asking" "$( rigNotes rig-member )" "3"
rigProcSignal TERM "${rigDaemon:-0}"
rigWaitFor 30 rigLockGone
rigAssert "TERM ends it in order: its lock is given back" "$( [ -L "$rigDir/ws/.local/agents/collect/thread.lock" ] && printf held || printf given )" given
rigAssert "and the process is gone" "$( rigProcStill "${rigDaemon:-0}" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "its log says how it ended" "$( LC_ALL=C grep -c 'ends: it was ended by TERM' "$rigDir/ws/.local/agents/collect/thread.log" )" 1
ln -s "999999 Mon_Jan__1_00:00:00_2001" "$rigDir/ws/.local/agents/collect/thread.lock"
rigOp proc-take --start
rigDaemon2="$( rigPidOf proc-take )"
rigNote "$rigDaemon2"
rigWaitFor 20 test "$( rigLockPid )" = "${rigDaemon2:-none}"
rigAssert "a lock whose holder is gone is taken over" "$( rigLockPid )" "${rigDaemon2:-none}"
rigProcSignal TERM "${rigDaemon2:-0}"
rigWaitFor 30 rigLockGone
rigScene p-idle conf
rigOpEnv="MDAT_COLLECT_IDLE_SECONDS=3 MDAT_COLLECT_PASS_SECONDS=1"
rigOp idle-start --start
rigOpEnv=""
rigDaemon3="$( rigPidOf idle-start )"
rigNote "$rigDaemon3"
rigWaitFor 40 test -z "$( rigProcStill "${rigDaemon3:-0}" )"
rigAssert "with nobody wanting it for the time set, it ends by itself, and gives its lock back" "$( rigProcStill "${rigDaemon3:-0}" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( [ -L "$rigDir/ws/.local/agents/collect/thread.lock" ] && printf held || printf given )" "0:given"
rigAssert "and says why in its log" "$( LC_ALL=C grep -c 'nobody has wanted it' "$rigDir/ws/.local/agents/collect/thread.log" )" 1

echo "-- 4. a source that failed --"
rigScene f-fail conf
: > "$rigFix/login-fails"
rigOpEnv="MDAT_COLLECT_PASS_SECONDS=1"
rigOp fail-start --start
rigOpEnv=""
rigDaemon4="$( rigPidOf fail-start )"
rigNote "$rigDaemon4"
rigWaitFor 40 test -s "$rigDir/ws/.local/agents/collect/mail.rig-member.state"
sleep 4
rigAssert "is tried once and left to the scans: the thread does not hammer a mailbox that refuses the login every second" "$( rigCount "$rigFix/imap.log" '^LOGIN-REFUSED ' ):$( LC_ALL=C grep -c 'mail:rig-member: failed' "$rigDir/ws/.local/agents/collect/thread.log" )" "1:1"
rigProcSignal TERM "${rigDaemon4:-0}"
rigWaitFor 30 rigLockGone
rigAssert "a failed source is none of the stale ones that start a thread" "$( rigRunTool stale-fail --intern-op-collect-sources --report-stale ; rigCount "$rigDir/stale-fail.out" '^stale: ' )" "0"

echo "-- 5. one pass, and the places --"
rigScene o-one conf
rm -f "$rigFix/login-fails"
rigOp one-pass --one --force
rigAssert "--one makes one pass under the lock and ends, saying what it did" "$rigRc:$( rigCount "$rigDir/one-pass.err" 'mail:rig-member: 2 new' ):$( [ -L "$rigDir/ws/.local/agents/collect/thread.lock" ] && printf held ):$( rigNotes rig-member )" "0:1::2"
rigScene o-git conf
git init -q "$rigDir/data" && git -C "$rigDir/data" config user.name rig && git -C "$rigDir/data" config user.email rig@rig.invalid
git -C "$rigDir/data" commit -q -m base --allow-empty > /dev/null 2>&1
printf '801 unseen\n802 unseen\n803 unseen\n' > "$rigFix/mailbox"
rigOp one-git --one --force
rigAssert "a pass of three mails is one commit, holding the three notes" "$rigRc:$(( $( git -C "$rigDir/data" rev-list --count HEAD ) - 1 )):$( git -C "$rigDir/data" show --name-only --format= HEAD | LC_ALL=C grep -c -- '-email-u80[123]\.md' )" "0:1:3"
rigOp mode-none
rigAssert "no mode: a usage, and a failure" "$( [ "$rigRc" != 0 ] && printf failed ):$( LC_ALL=C grep -c -F -e '--run' "$rigDir/mode-none.err" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "usage" : "none" }' )" "failed:usage"
rigAssert "the main loop checks it on every iteration, as it checks the control threads" "$( LC_ALL=C grep -c -F 'AgentsToolsCollectThreadCheck main-loop' "$rigHere/magic/AgentsTools.InternMainLoop.include" )" 1
rigAssert "the runner of the checks keeps it from every test" "$( LC_ALL=C grep -c -F 'export MDAT_COLLECT_THREAD=off' "$rigPackage/sh-test/AgentsRunTests.sh" )" 1
rigAssert "the rig fixture that ends threads knows its start line and its lock" "$( LC_ALL=C grep -c -F -e 'collect/thread.log' -e 'collect/thread.lock' "$rigFixtures/rig-control-threads.include.sh" | LC_ALL=C awk '{ print ( $1 >= 2 ) ? "yes" : "no" }' )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COLLECT THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COLLECT_THREAD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
