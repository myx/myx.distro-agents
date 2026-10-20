#!/usr/bin/env bash
## Behavioural check on TeamDispatcher (F7.4 of the refactorings epic, sh-scripts/DistroAgentsDispatcher.fn.sh): the spawner
## console tool command, the interface of the runs for agent tools, the shell console and shell automation alike. Held, run and
## not read, over a rig workspace with sessions of its own:
##   1. The lists call the very function the manager list uses (Settled 2026-10-19): --all-sessions prints what
##      --manager-session-list prints, --active-sessions what --manager-session-list --active prints, byte for byte, and the
##      function is named once, in the include both operations call.
##   2. --waiting-sessions prints the sessions the list reads as `waiting`, each with its runs, and the counters row: no
##      session that is running, unclosed or finished.
##   3. The kinds of F6.1 are distinguished: --kind standalone|coworking|ad-hoc keeps the sessions of that kind on any of the three
##      lists, the kind read from the run's routine (`requires-session-kind:`), ad-hoc for a run with no routine. A word that
##      is no kind is refused with the three named, and nothing is printed.
##   4. The lists are for a member's session too: --manager-session-list is refused from one, the Dispatcher's lists are not.
##   5. --session-record <session-id> [--run] prints what --manager-session-read prints, through the one function both use;
##      refused, rc 1, with no id, with an id no record carries, and with a word it does not know.
##   6. The predecessor question: --routine-completed <routine> --since "<YYYY-MM-DD HH:MM>" prints the run and ends 0 when a
##      run of that routine closed `spawn-succeeded` at or after that time; ends 1 with a NOT-COMPLETED line naming the routine
##      and the time when none did (a run that failed, one that closed before, one still open, and a run of another routine
##      are none); refused with a form that is no time, or no --since.
##   7. An operation the file does not know is refused; every operation has its help entry.
## Red before F7.4: there is no DistroAgentsDispatcher.fn.sh (every case fails).
## Offline: a ps first on PATH lists the rig's own runs only (none), an uptime and a curl of the rig's own; every tree is the rig's.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHelp="$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md"
unset MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT CLAUDE_CODE_SESSION_ID harnessSessionId harnessAgent
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDispatcherSessionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigTmp/home" "$rigSkills/rig-member"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
printf '#!/bin/sh\ncase " $* " in *" -A "*) exit 0 ;; esac\nexec "${0%%/*}/ps.real" "$@"\n' > "$rigTmp/bin/ps"
printf '#!/bin/sh\nprintf " 2:54  up 4 days,  6:19, 12 users, load averages: 3.25 2.00 1.00\\n"\n' > "$rigTmp/bin/uptime"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/uptime" "$rigTmp/bin/curl"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
for rigKind in coworking standalone ; do
	printf -- '---\ntype: routine\nrequires-session-kind: %s\nexecutors: rig-member\nmaintainers: rig-member\n---\n# Steps\n' "$rigKind" > "$rigSkills/rig-member/rig-member.$rigKind-one.routine.md"
done
printf -- '---\ntype: routine\nrequires-session-kind: standalone\nexecutors: rig-member\nmaintainers: rig-member\n---\n# Steps\n' > "$rigSkills/rig-member/rig-member.report.routine.md"
printf -- '---\ntype: routine\nrequires-session-kind: standalone\nexecutors: rig-member\nmaintainers: rig-member\n---\n# Steps\n' > "$rigSkills/rig-member/rig-member.other.routine.md"

rigRec(){ ## session id, spawn id, status, started-at, resolved-at ("" for none), routine file ("" for none)
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: rig-member\nstatus: %s\nstarted-at: %s\n' "$1" "$2" "$rigHost" "$3" "$4"
		[ -z "${5:-}" ] || printf 'resolved-at: %s\n' "$5"
		[ -z "${6:-}" ] || printf 'routine: %s\n' "$6"
		printf -- '---\n\n# Spawn session: %s\n' "$2"
	} > "$rigWs/.local/agents/spawned/$1/$2.md"
}
rigAsk(){ ## ask name, session id
	printf -- '---\nstatus: reply-pending\nowner: rig-member\nsession-id: %s\nkind: question\n---\nq\n' "$2" > "$rigWs/.local/agents/pending/$1.md"
}
## Five sessions of five states and kinds: two wait (a coworking one and one with no routine), one is unclosed (standalone),
## two are finished (a coworking one and a standalone one, the second with the runs of the predecessor question).
rigRec rig-s-cow rig-s-cow spawn-started '2026-10-19 08:00 +0300' '' rig-member.coworking-one.routine.md
rigAsk rig-ask-1 rig-s-cow
rigRec rig-s-adhoc rig-s-adhoc spawn-started '2026-10-19 08:10 +0300' '' ''
rigAsk rig-ask-2 rig-s-adhoc
rigRec rig-s-solo rig-s-solo spawn-started '2026-10-19 08:20 +0300' '' rig-member.standalone-one.routine.md
rigRec rig-s-cowdone rig-s-cowdone spawn-succeeded '2026-10-18 08:00 +0300' '2026-10-18 09:00 +0300' rig-member.coworking-one.routine.md
rigRec rig-s-done rig-s-done spawn-succeeded '2026-10-18 10:00 +0300' '2026-10-18 10:30 +0300' rig-member.standalone-one.routine.md
rigRec rig-rc-a rig-rc-a spawn-succeeded '2026-10-19 09:00 +0300' '2026-10-19 09:30 +0300' rig-member.report.routine.md
rigRec rig-rc-b rig-rc-b spawn-failed '2026-10-19 11:00 +0300' '2026-10-19 12:00 +0300' rig-member.report.routine.md
rigRec rig-rc-c rig-rc-c spawn-succeeded '2026-10-19 12:30 +0300' '2026-10-19 13:00 +0300' rig-member.other.routine.md
rigRec rig-rc-d rig-rc-d spawn-started '2026-10-19 14:00 +0300' '' rig-member.report.routine.md

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
rigCall(){ ## result name, script, words... -- one call from the rig workspace; its stdout in <name>.out, stderr in <name>.err, rc in <name>.rc
	local callName="$1" callScript="$2"
	shift 2
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TZ=Etc/GMT-3 MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} bash "$callScript" "$@" ) > "$rigTmp/$callName.out" 2> "$rigTmp/$callName.err" < /dev/null
	printf '%s' "$?" > "$rigTmp/$callName.rc"
}
rigAs=""
rigSame(){ ## result name, result name -- `same` where rc and stdout are the same, else the first difference
	if [ "$( cat "$rigTmp/$1.rc" )" = "$( cat "$rigTmp/$2.rc" )" ] && cmp -s "$rigTmp/$1.out" "$rigTmp/$2.out" ; then printf 'same'
	else printf 'rc %s/%s, %s' "$( cat "$rigTmp/$1.rc" )" "$( cat "$rigTmp/$2.rc" )" "$( diff "$rigTmp/$1.out" "$rigTmp/$2.out" | head -3 | tr '\n' '|' )"
	fi
}
rigSessions(){ ## result name -- the session rows of its stdout as `<id>=<state>`, in order
	LC_ALL=C awk -F'\t' '$1 == "session" { printf "%s=%s ", $2, $4 }' "$rigTmp/$1.out"
}
rigHas(){ ## result name, kind -- how many rows of that kind its stdout has
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { n++ } END { print n + 0 }' "$rigTmp/$1.out"
}

echo "-- 1. the lists are the manager list --"
rigCall list "$rigTool" --manager-session-list
rigCall listActive "$rigTool" --manager-session-list --active
rigAssert "control: the manager list reads the five sessions of the rig by state" "$( rigSessions list )" \
	"rig-rc-d=unclosed rig-rc-c=finished rig-rc-b=finished rig-rc-a=finished rig-s-solo=unclosed rig-s-adhoc=waiting rig-s-cow=waiting rig-s-done=finished rig-s-cowdone=finished "
rigCall all "$rigDispatcher" --all-sessions
rigAssert "--all-sessions: the same rows, the same exit" "$( [ -f "$rigTmp/all.out" ] && rigSame all list )" "same"
rigCall active "$rigDispatcher" --active-sessions
rigAssert "--active-sessions: the same rows as --manager-session-list --active" "$( [ -f "$rigTmp/active.out" ] && rigSame active listActive )" "same"
rigAssert "the function of the rows is named in the Dispatcher's include and in the manager's, and the Dispatcher builds no row of its own" \
	"$( LC_ALL=C grep -l 'AgentsToolsManagerSessionRows ' "$rigPackage/sh-lib/session/AgentsTools.Dispatcher.include" "$rigPackage/sh-lib/manager/AgentsTools.ManagerSession.include" 2> /dev/null | wc -l | tr -d ' ' ):$( LC_ALL=C grep -c 'AgentsManagerSessionRows.awk' "$rigPackage/sh-lib/session/AgentsTools.Dispatcher.include" 2> /dev/null || :)" "2:0"

echo "-- 2. --waiting-sessions --"
rigCall waiting "$rigDispatcher" --waiting-sessions
rigAssert "the sessions the list reads as waiting, and no other; the runs of those, and the counters row"  "$( rigSessions waiting)|$( rigHas waiting run)|$( rigHas waiting counters)|$( cat "$rigTmp/waiting.rc" )" \
	"rig-s-adhoc=waiting rig-s-cow=waiting |2|1|0"

echo "-- 3. --kind --"
rigCall kindCow "$rigDispatcher" --all-sessions --kind coworking
rigAssert "--kind coworking keeps the sessions whose routine is of the coworking kind"           "$( rigSessions kindCow )" "rig-s-cow=waiting rig-s-cowdone=finished "
rigCall kindSolo "$rigDispatcher" --all-sessions --kind standalone
rigAssert "--kind standalone keeps the standalone ones"                                          "$( rigSessions kindSolo )" "rig-rc-d=unclosed rig-rc-c=finished rig-rc-b=finished rig-rc-a=finished rig-s-solo=unclosed rig-s-done=finished "
rigCall kindAdhoc "$rigDispatcher" --all-sessions --kind ad-hoc
rigAssert "--kind ad-hoc keeps the run with no routine"                                          "$( rigSessions kindAdhoc )" "rig-s-adhoc=waiting "
rigCall kindActive "$rigDispatcher" --active-sessions --kind standalone
rigAssert "--kind goes with --active-sessions: the active ones of that kind"                     "$( rigSessions kindActive )" "rig-rc-d=unclosed rig-s-solo=unclosed "
rigCall kindWaiting "$rigDispatcher" --waiting-sessions --kind coworking
rigAssert "--kind goes with --waiting-sessions: the waiting ones of that kind"                   "$( rigSessions kindWaiting )" "rig-s-cow=waiting "
rigAssert "a kept session keeps its runs and the counters row"                                   "$( rigHas kindCow run ):$( rigHas kindCow counters )" "2:1"
rigCall kindBad "$rigDispatcher" --all-sessions --kind sidekick
rigAssert "a word that is no kind is refused with the three kinds named, and nothing is printed" "$( cat "$rigTmp/kindBad.rc" ):$( wc -c < "$rigTmp/kindBad.out" | tr -d ' ' ):$( LC_ALL=C grep -c 'standalone.*coworking.*ad-hoc' "$rigTmp/kindBad.err" )" "1:0:1"

echo "-- 4. for a member's session too --"
rigAs="rig-member"
rigCall listMember "$rigTool" --manager-session-list
rigCall allMember "$rigDispatcher" --all-sessions
rigAs=""
rigAssert "control: the manager list is refused from a member's session"                         "$( cat "$rigTmp/listMember.rc" ):$( wc -c < "$rigTmp/listMember.out" | tr -d ' ' )" "1:0"
rigAssert "the Dispatcher's list is not: the same rows as the console's"                         "$( [ -f "$rigTmp/allMember.out" ] && rigSame allMember list )" "same"

echo "-- 5. --session-record --"
rigCall read "$rigTool" --manager-session-read --session-id rig-s-cow
rigCall record "$rigDispatcher" --session-record rig-s-cow
rigAssert "--session-record prints what --manager-session-read prints"                           "$( [ -f "$rigTmp/record.out" ] && rigSame record read )" "same"
rigAssert "the record is the session's: its row names it"                                        "$( LC_ALL=C grep -c 'rig-s-cow' "$rigTmp/record.out" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "named"
rigCall readRun "$rigTool" --manager-session-read --session-id rig-s-cow --run
rigCall recordRun "$rigDispatcher" --session-record rig-s-cow --run
rigAssert "--run: the same as --manager-session-read --session-id <id> --run"                    "$( [ -f "$rigTmp/recordRun.out" ] && rigSame recordRun readRun )" "same"
rigCall recordNone "$rigDispatcher" --session-record
rigAssert "no id is refused, rc 1, nothing printed"                                              "$( cat "$rigTmp/recordNone.rc" ):$( wc -c < "$rigTmp/recordNone.out" | tr -d ' ' )" "1:0"
rigCall recordGone "$rigDispatcher" --session-record rig-no-such-session
rigAssert "an id no record carries is refused, rc 1"                                             "$( cat "$rigTmp/recordGone.rc" ):$( wc -c < "$rigTmp/recordGone.out" | tr -d ' ' )" "1:0"
rigCall recordWord "$rigDispatcher" --session-record rig-s-cow --everything
rigAssert "a word it does not know is refused, rc 1, nothing printed"                            "$( cat "$rigTmp/recordWord.rc" ):$( wc -c < "$rigTmp/recordWord.out" | tr -d ' ' )" "1:0"

echo "-- 6. --routine-completed --"
rigCall done1 "$rigDispatcher" --routine-completed rig-member.report.routine.md --since "2026-10-19 09:00"
rigAssert "a run of the routine closed spawn-succeeded after the time: rc 0, the run printed"     "$( cat "$rigTmp/done1.rc" ):$( LC_ALL=C awk -F'\t' '$1 == "run" { print $2, $3, $5 }' "$rigTmp/done1.out" )" "0:rig-rc-a rig-rc-a spawn-succeeded"
rigCall done2 "$rigDispatcher" --routine-completed rig-member.report.routine.md --since "2026-10-19 09:30"
rigAssert "closed at the time itself counts"                                                      "$( cat "$rigTmp/done2.rc" ):$( LC_ALL=C awk -F'\t' '$1 == "run" { print $3 }' "$rigTmp/done2.out" )" "0:rig-rc-a"
rigCall done3 "$rigDispatcher" --routine-completed rig-member.report.routine.md --since "2026-10-19 09:31"
rigAssert "none since: rc 1, a NOT-COMPLETED line names the routine and the time; the run that failed, the one still open and the one before the time are none" \
	"$( cat "$rigTmp/done3.rc" ):$( LC_ALL=C grep -c '^NOT-COMPLETED: rig-member.report.routine.md since 2026-10-19 09:31' "$rigTmp/done3.out" ):$( rigHas done3 run )" "1:1:0"
rigCall done4 "$rigDispatcher" --routine-completed rig-member.other.routine.md --since "2026-10-19 09:00"
rigAssert "a routine of its own: the run of that routine, not another's"                          "$( cat "$rigTmp/done4.rc" ):$( LC_ALL=C awk -F'\t' '$1 == "run" { print $3 }' "$rigTmp/done4.out" )" "0:rig-rc-c"
rigCall done5 "$rigDispatcher" --routine-completed report --since "2026-10-19 09:00"
rigAssert "the routine is named as --routine names one: a part of its file name"                  "$( cat "$rigTmp/done5.rc" ):$( LC_ALL=C awk -F'\t' '$1 == "run" { print $3 }' "$rigTmp/done5.out" )" "0:rig-rc-a"
rigCall done6 "$rigDispatcher" --routine-completed rig-member.report.routine.md --since "yesterday"
rigAssert "a time that is not YYYY-MM-DD HH:MM is refused, rc 1"                                  "$( cat "$rigTmp/done6.rc" ):$( wc -c < "$rigTmp/done6.out" | tr -d ' ' )" "1:0"
rigCall done7 "$rigDispatcher" --routine-completed rig-member.report.routine.md
rigAssert "no --since is refused, rc 1"                                                           "$( cat "$rigTmp/done7.rc" ):$( wc -c < "$rigTmp/done7.out" | tr -d ' ' )" "1:0"
rigCall done8 "$rigDispatcher" --routine-completed rig-member.no-such --since "2026-10-19 09:00"
rigAssert "a routine that matches no file is refused, rc 1"                                       "$( cat "$rigTmp/done8.rc" ):$( wc -c < "$rigTmp/done8.out" | tr -d ' ' )" "1:0"

echo "-- 7. refusal and help --"
rigCall unknown "$rigDispatcher" --no-such-operation
rigAssert "an operation the file does not know is refused, rc 1"                                  "$( cat "$rigTmp/unknown.rc" ):$( LC_ALL=C grep -c 'invalid option' "$rigTmp/unknown.err" )" "1:1"
for rigOp in --all-sessions --active-sessions --waiting-sessions --session-record --routine-completed ; do
	rigAssert "$rigOp has its help entry, as the Dispatcher's operation" "$( LC_ALL=C grep -c -E "^		$rigOp( |\$)" "$rigHelp" ):$( LC_ALL=C awk -v op="$rigOp" '$1 == op { on = 1 ; next } on && /DistroAgentsDispatcher.fn.sh/ { found = 1 } on && /^		--/ { on = 0 } END { print found + 0 }' "$rigHelp" )" "1:1"
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISPATCHER SESSIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DISPATCHER_SESSIONS: OK (%d assertions, offline)\n' "$rigPassCount"
