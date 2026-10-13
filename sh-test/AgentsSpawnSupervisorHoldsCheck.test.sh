#!/usr/bin/env bash
## Behavioural check on the supervising shell of a run holding until it has closed its record, run rather than
## read, through the real spawn proxy on a stand-in console. The shell that starts a run's console waits on the
## run, resumes it once for a missing handback, closes the record, takes its item to review and posts the end. It
## must not end before that by itself: not by a command of its own that fails, not by a signal that can be held.
## Held:
##   1. A RETURN THAT RESUMES A HARNESS SESSION FROM ITS KEPT CONTEXT. The resume is recorded on its item by the
##      tooling, which leaves `set -e` behind in the shell that calls it: each such record is made in a subshell of
##      its own (AgentsToolsSpawnProxyHarnessResumeRun, AgentsTools.HarnessResume.include), so the supervising shell
##      goes on. When the resumed run ends, with status 0 or with any other, its record is closed with that status,
##      its item enters review, and the finish flag is put on its start post.
##   2. A SIGNAL TO THE SHELL OF A RUN THAT DOES NOT WAIT. A hangup, an interrupt and a polite end sent to the shell
##      itself do not end it and do not reach its run. The run then ends, and the shell closes its record and takes
##      its item to review. What it held is said in the run's log.
##   3. A POLITE END TO THE PROCESS GROUP OF SUCH A RUN, which the shell leads. The run ends by it. The shell closes
##      the record as failed, with the status of that end, and takes the item to review.
##   4. A START ITS CALLER WAITS ON: a polite end sent to the waiting shell while it resumes its run for a missing
##      handback is held, the retry is waited to its end, the record and the item are closed, the receipt is given.
##   5. A START ITS CALLER WAITS ON, WHOSE CALLER IS GONE: a write to the output that caller no longer reads does
##      not end the shell before its close.
##   6. THE CLOSE. The record is closed first and then the item, both files of this machine, and everything that is
##      posted follows: with every post refused by Slack the record is closed and the item is in review, and every
##      call to Slack made after the run ended finds them so. The record is put in place by one rename, never
##      written over. A close whose header writer fails once is made at the second try, and one that fails twice
##      leaves the record as it was and says so. The bound of the handback retry is ended with the sleep it stands
##      in: nothing of it is left in the run's group.
##   7. ONCE ITS CLOSE IS DONE the shell ends at a polite end, as any process does: held in the commit of its
##      transcript's end, which has no bound, it is ended by TERM. And its standard input is none of its caller's:
##      whatever it calls itself reads /dev/null.
##   8. THE HELPERS A SHELL KEEPS FOR THE WHOLE RUN, the poster of its feed, the poller of its launch and, where
##      its caller waits, the reader of its log, are signalled at the run's end only while each is still the
##      process the shell started: a number the process list then gives to a process that began at another time
##      is not signalled, and the close does not wait for it. A pid is not given again on demand, so the rig's
##      process list says it of the helper itself, which then stands for whoever has its number.
## Red before: in 1, every assertion after the run ends; the shell was gone, the record said spawn-started for good.
## In 2, the interrupt and the polite end. In 3, 4 and 5, the close. In 6, the order, the rename, the second try,
## the line that says a close failed, and the sleep left behind. In 7, the standard input. In 8, every helper:
## each was signalled by its number alone.
## Offline: a fake `curl` first on PATH answers as Slack and opens no socket. A ps beside it answers the whole-host
## listing from the rig's own list, which holds no line, so a run of this rig is the process its record names, and
## hands every other call to the real ps. The console is a stand-in, never a real CLI. The board, the sandboxes and
## the workspace are this rig's own temp tree. Every signal goes to a process this rig noted with when it began.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.test.sh"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigHelper" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.test.sh"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.test.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.test.sh"
rigTmp="$( mktemp -d -t AgentsSpawnSupervisorHoldsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/bin" "$rigTmp/held" "$rigWs/.local/.agents" "$rigSp" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigKept=""
## At the end every stand-in console still waiting is let go, with a handback, so that no supervising shell of
## this rig resumes it once more; then what is left of this rig's own processes is ended.
rigCleanup(){
	local cleanDir cleanLaunch
	for cleanDir in "$rigTmp"/*/ ; do
		[ -e "${cleanDir}record" ] || continue
		for cleanLaunch in first retry resume ; do : > "${cleanDir}handback-$cleanLaunch" ; : > "${cleanDir}release-$cleanLaunch" ; done
	done 2> /dev/null
	rigProcSignalKept KILL "$rigTmp"/*/first.began "$rigTmp"/*/retry.began "$rigTmp"/*/resume.began "$rigTmp"/*/git.began
	rigProcSignal KILL $rigKept
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"
}
trap 'rigControlThreadsEnd "$rigTmp" ; rigCleanup' EXIT

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's own list, beside
## it, which holds no line: no process of the host is ever read as a run, and a run of this rig lives by the
## process its record names. The listing of pid and ppid, and every other call, is handed to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
cp "$rigFixture" "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
## THE TOOLS A RUN OF THIS RIG FINDS FIRST ON ITS PATH, each the real one, or the rig's fake Slack, after what it notes.
## curl: where its scenario asks (the file order-on), every call made after the run ended (its first launch done)
## leaves what the record of the run said then, and where its item was. awk: the header change of a record's close
## (its temp file is named mdat-session-header-ops.*) fails, with nothing written, as often as its scenario says
## (the file close-fails). git: every call leaves who called it, and whether its standard input is /dev/null; where
## its scenario says so (the file git-stands-after-end) and the transcript of the run holds its END, it stands
## still, as a commit with no bound does. ps: asked when a pid began that its scenario names (the file
## ps-says-another, a pid a line), it answers as of a process that began at another time.
rigRealAwk="$( command -v awk )" || rigRefuse "no awk on PATH"
rigRealGit="$( command -v git )" || rigRefuse "no git on PATH"
cat > "$rigTmp/held/curl" <<'RIGCURL'
#!/bin/sh
if [ -e "$RIG_SCENARIO/order-on" ] && [ -e "$RIG_SCENARIO/first.done" ] ; then
	rigMethod=""
	for rigWord in "$@" ; do case "$rigWord" in https://slack.com/api/*) rigMethod="${rigWord#https://slack.com/api/}" ;; esac ; done
	rigSaid="$( sed -n 's/^status: //p' "$( head -1 "$RIG_SCENARIO/record" 2> /dev/null )" 2> /dev/null | head -1 )"
	rigPlace=elsewhere
	[ ! -f "$MDAT_DATA_ROOT/board/review/$( head -1 "$RIG_SCENARIO/item" 2> /dev/null )" ] || rigPlace=review
	printf '%s %s %s\n' "${rigMethod:-none}" "${rigSaid:-none}" "$rigPlace" >> "$RIG_SCENARIO/order"
fi
exec "$RIG_TMP/bin/curl" "$@"
RIGCURL
cat > "$rigTmp/held/awk" <<'RIGAWK'
#!/bin/sh
case " $* " in
	*"opsFile="*"mdat-session-header-ops"*)
		rigFailsLeft="$( cat "$RIG_SCENARIO/close-fails" 2> /dev/null )"
		case "$rigFailsLeft" in
			''|0|*[!0123456789]*) ;;
			*) echo "$(( rigFailsLeft - 1 ))" > "$RIG_SCENARIO/close-fails" ; exit 1 ;;
		esac
	;;
esac
exec "$RIG_REAL_AWK" "$@"
RIGAWK
cat > "$rigTmp/held/git" <<'RIGGIT'
#!/usr/bin/env bash
rigGitInput=other ; [ ! /dev/fd/0 -ef /dev/null ] || rigGitInput=null
printf '%s %s %s\n' "$PPID" "$( "$RIG_TMP/bin/ps.real" -o ppid= -p "$PPID" 2> /dev/null | tr -d ' ' )" "$rigGitInput" >> "$RIG_SCENARIO/git.calls" 2> /dev/null
if [ -e "$RIG_SCENARIO/git-stands-after-end" ] && [ ! -e "$RIG_SCENARIO/git.began" ] && [ -n "${MDAT_SPAWN_SESSION_ID:-}" ] \
	&& LC_ALL=C grep -q -E '^[0-9TZ:-]+ END( |$)' "$MDAT_DATA_ROOT"/audit/*/session-*"${MDAT_SPAWN_SESSION_ID:0:8}"*.log 2> /dev/null ; then
	. "$RIG_HELPER" 2> /dev/null && rigProcNoteFile "$RIG_SCENARIO/git.began" $$
	exec sleep 120
fi
exec "$RIG_REAL_GIT" "$@"
RIGGIT
cat > "$rigTmp/held/ps" <<'RIGHELDPS'
#!/bin/sh
if [ -s "$RIG_SCENARIO/ps-says-another" ] ; then
	case "$*" in
		*lstart=*)
			rigPsPid=""
			for rigPsWord in "$@" ; do rigPsPid="$rigPsWord" ; done
			if grep -q -x -- "$rigPsPid" "$RIG_SCENARIO/ps-says-another" 2> /dev/null ; then
				case "$*" in
					*pid=,stat=,lstart=*) printf '%5s S    Mon Jan  1 00:00:00 2001\n' "$rigPsPid" ;;
					*) printf 'Mon Jan  1 00:00:00 2001\n' ;;
				esac
				exit 0
			fi
		;;
	esac
fi
exec "$RIG_TMP/bin/ps" "$@"
RIGHELDPS
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl" "$rigTmp/held/curl" "$rigTmp/held/awk" "$rigTmp/held/git" "$rigTmp/held/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
## With its tracking conversation set, a run of this rig has its tracking thread, its feed and the poster of that feed.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in rig-member-a magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

## The stand-in console of the proxy's own runs. A launch says which record it runs under and notes itself, its
## pid and when it began: the first launch of a run as `first`, one that resumes for a missing handback as `retry`,
## one that resumes a kept harness context as `resume`, which also marks that it loaded that context, as the
## harness does. It runs until its scenario lets that launch go (the file release-<launch>), prints the line a
## handback leaves only where its scenario says so (handback-<launch>), and ends with the status its scenario
## names (exit-<launch>), 0 where it names none. Where its scenario says so (no-launch-marker) it leaves the
## launch unmarked, so the poller of that launch goes on looking for it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > /dev/null' \
	'rigLaunch=first ; [ -z "${MDAT_SPAWN_RESUME:-}" ] || rigLaunch=retry' \
	'[ -z "${MDAT_HARNESS_RESUME_CONTEXT:-}" ] || { rigLaunch=resume ; : > "$MDAT_HARNESS_RESUME_MARKER" ; }' \
	'[ -e "$RIG_SCENARIO/no-launch-marker" ] || printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s\n" "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.md" > "$RIG_SCENARIO/record"' \
	". '$rigHelper' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/\$rigLaunch.began\" \$\$" \
	'rigLeft=120' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release-$rigLaunch" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'[ ! -e "$RIG_SCENARIO/handback-$rigLaunch" ] || printf "📦 SubagentHandback\n"' \
	'echo finished > "$RIG_SCENARIO/$rigLaunch.done"' \
	'rigExit=0 ; [ ! -s "$RIG_SCENARIO/exit-$rigLaunch" ] || rigExit="$( head -1 "$RIG_SCENARIO/exit-$rigLaunch" )"' \
	'exit "$rigExit"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigBegan(){ ## pid -- when that process began, as one word, as a record keeps it; nothing when there is none
	LC_ALL=C "$rigTmp/bin/ps.real" -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }'
}
rigIsStill(){ ## `<pid> <start>` -- whether that pid is still the process that began then
	case "$1" in *' '*) ;; *) return 1 ;; esac
	[ "$( rigBegan "${1%% *}" )" = "${1#* }" ]
}
rigHasEnded(){ ! rigIsStill "$1" ; } ## `<pid> <start>`
rigHeader(){ ## record file, header name -- its value in the record's own frontmatter
	LC_ALL=C awk -v wantName="$2: " '
		$0 == "---" { if ( ++fenceCount > 1 ) { exit ; } next ; }
		fenceCount == 1 && index( $0, wantName ) == 1 { print substr( $0, length( wantName ) + 1 ) ; exit ; }
	' "$1" 2> /dev/null
}
## One call of the tooling in the rig workspace, as a bare console makes it: no session of its own, and the hangup,
## the interrupt and the quit at their defaults, as a console has them, whatever this check itself was started
## with: a check started in the background ignores the interrupt already, and then none would end anything here.
rigEnv(){ ## scenario folder, NAME=value words, then the command...
	local envDir="$1" envWords=()
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) envWords[${#envWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$envDir" RIG_HELPER="$rigHelper" RIG_REAL_AWK="$rigRealAwk" RIG_REAL_GIT="$rigRealGit" \
		${envWords[@]+"${envWords[@]}"} \
		perl -e '$SIG{HUP} = "DEFAULT" ; $SIG{INT} = "DEFAULT" ; $SIG{QUIT} = "DEFAULT" ; exec { $ARGV[0] } @ARGV or exit 127' "$@"
}
rigRunKept(){ [ -n "$( rigHeader "$rigRecord" run-process )" ] ; }
rigRecordClosed(){ case "$( rigHeader "$rigRecord" status )" in spawn-started|'') return 1 ;; esac ; }
rigItemIn(){ ## item stem -- the board state that holds it
	local inState
	for inState in running review ; do [ ! -f "$rigData/board/$inState/$1.md" ] || { printf '%s' "$inState" ; return 0 ; } ; done
	printf 'nowhere'
}
rigCalls(){ ## Slack method -- how many calls of it the scenario's fake Slack took
	LC_ALL=C grep -c "^$1 " "$rigDir/calls" 2> /dev/null || :
}
## Waits for the scenario's console, the launch named, and for that launch to be kept on its record; sets rigRecord
## and rigShell, what the record names as its supervising shell.
rigRunStarted(){ ## scenario, launch
	rigWaitFor 60 test -s "$rigDir/$2.began" || rigRefuse "the stand-in console never started in scenario $1: $( LC_ALL=C grep -h -m1 ERROR "$rigDir"/*.out 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
	rigRecord="$( head -1 "$rigDir/record" 2> /dev/null )"
	[ -n "$rigRecord" ] && [ -f "$rigRecord" ] || rigRefuse "the run of scenario $1 has no record"
	rigWaitFor 20 rigRunKept || rigRefuse "the proxy kept no process on the record of its run in scenario $1"
	rigShell="$( rigHeader "$rigRecord" supervisor-process )"
	rigIsStill "$rigShell" || rigRefuse "the record of scenario $1 names no supervising shell that lives while its run does, so nothing below would be measured: '$rigShell'"
}

echo "-- 1. a return that resumes a harness session from its kept context: its supervising shell goes on to the close --"
## One item in running whose member is started again from a kept context, as the return of a review starts it
## (AgentsReviewRestart): the proxy's own run that does not wait, on the item itself.
rigResume(){ ## scenario, the status the resumed run ends with
	rigDir="$rigTmp/$1"
	rigItem="dispatch-20261013T0900Z-rig$1"
	mkdir -p "$rigDir"
	printf '%s\n' "$2" > "$rigDir/exit-resume"
	: > "$rigDir/handback-resume"
	printf -- '---\ntype: dispatch\nowner: rig-member-a\nstatus: dispatch-started\n---\n\n# rig dispatch\n' > "$rigData/board/running/$rigItem.md"
	printf '{"type":"context","session":"rig-old-%s"}\n' "$1" > "$rigDir/context.jsonl"
	( cd "$rigWs" && rigEnv "$rigDir" MDAT_SPAWN_RESUME_CONTEXT="$rigDir/context.jsonl" MDAT_SPAWN_RESUME_TEXT="redo the rig step" \
		bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --from-board "$rigItem.md" --board-state running --dispatch-doc:reuse --context rig-supervisor-holds > "$rigDir/proxy.out" 2>&1 < /dev/null )
	rigRunStarted "$1" resume
}
rigResumed(){ [ "$( LC_ALL=C grep -h -c 'restart: resumed-context' "$rigData"/board/*/"$rigItem.md" 2> /dev/null | head -1 )" = 1 ] ; }
rigResumeAsserts(){ ## the status the resumed run ended with, the status its record must then say
	rigWaitFor 20 rigResumed
	rigAssert "control: the resume is recorded on its item by the tooling, in the supervising shell, while its run lives" \
		"$( rigResumed && printf recorded || printf not-recorded ):$( rigIsStill "$rigShell" && printf shell-alive || printf shell-gone ):$( rigHeader "$rigRecord" status )" "recorded:shell-alive:spawn-started"
	: > "$rigDir/release-resume"
	rigWaitFor 45 rigRecordClosed
	rigAssert "when the resumed run ends with status $1, its supervising shell closes the record with it" \
		"$( rigHeader "$rigRecord" status ):$( rigHeader "$rigRecord" exit-code )" "$2:$1"
	rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
	rigAssert "its item enters review" "$( rigItemIn "$rigItem" )" "review"
	rigWaitFor 20 test "$( rigCalls reactions.add )" = 1
	rigAssert "and the finish flag is put on its start post" "$( rigCalls reactions.add )" "1"
}
rigResume resumed-zero 0
rigResumeAsserts 0 spawn-succeeded
rigResume resumed-three 3
rigResumeAsserts 3 spawn-failed

## One run that is not waited for, started as a bare console starts it, on a dispatch item of its own; sets rigItem,
## its item's stem, and rigLog, its session log.
rigStart(){ ## scenario, the launches that leave a handback (first, retry; a space between them; may be empty)
	local startLaunch
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	for startLaunch in ${2:-} ; do : > "$rigDir/handback-$startLaunch" ; done
	( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --context rig-supervisor-holds <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 )
	rigItem="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigDir/proxy.out" | head -1 )" ; rigItem="${rigItem%.md}"
	[ -n "$rigItem" ] || rigRefuse "the proxy named no dispatch item in scenario $1"
	printf '%s.md\n' "$rigItem" > "$rigDir/item"
	rigRunStarted "$1" first
	rigLog="$rigWs/.local/agents/sessions/$( basename "$rigRecord" .md )/session.log"
}
rigHeldSaid(){ ## signal -- how many lines of the run's log say that the shell held it
	LC_ALL=C grep -c -F "was sent $1 before its close was done" "$rigLog" 2> /dev/null || :
}
rigClosedAndInReview(){ ## -- what the record says, and where the item is
	printf '%s:%s' "$( rigHeader "$rigRecord" status )" "$( rigItemIn "$rigItem" )"
}

echo "-- 2. a signal to the supervising shell of a run that does not wait: held until its close is done --"
rigSignalled(){ ## scenario, signal
	rigStart "$1" first
	rigProcNote "${rigShell%% *}"
	rigProcSignal "$2" "${rigShell%% *}"
	sleep 2
	rigAssert "$2 sent to the supervising shell of a live run does not end it, and its run goes on" \
		"$( rigIsStill "$rigShell" && printf shell-alive || printf shell-gone ):$( rigIsStill "$( head -1 "$rigDir/first.began" )" && printf run-alive || printf run-gone )" "shell-alive:run-alive"
	: > "$rigDir/release-first"
	rigWaitFor 45 rigRecordClosed
	rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
	rigAssert "then the run ends, and the shell closes its record and takes its item to review" "$( rigClosedAndInReview )" "spawn-succeeded:review"
}
rigSignalled held-hup HUP
rigSignalled held-int INT
rigAssert "the interrupt it held is said in the run's log" "$( rigHeldSaid INT )" "1"
rigSignalled held-term TERM
rigAssert "and so is the polite end" "$( rigHeldSaid TERM )" "1"

echo "-- 3. a polite end to the process group of a run that does not wait: the run ends, the shell closes its record --"
rigStart group-term retry
: > "$rigDir/release-retry"
rigProcNoteFrom "$rigDir/first.began"
rigProcGroupSignal TERM "${rigShell%% *}"
rigWaitFor 60 rigRecordClosed
rigAssert "the run ends by it, and its supervising shell, the leader of that group, closes the record as failed with the status of that end" \
	"$( rigIsStill "$( head -1 "$rigDir/first.began" )" && printf run-alive || printf run-gone ):$( rigHeader "$rigRecord" status ):$( rigHeader "$rigRecord" exit-code )" "run-gone:spawn-failed:143"
rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
rigAssert "its item enters review, and its log says what the shell held" "$( rigItemIn "$rigItem" ):$( rigHeldSaid TERM )" "review:1"

echo "-- 4. a start its caller waits on: a polite end during the handback retry is held until the close is done --"
rigDir="$rigTmp/waited-term"
mkdir -p "$rigDir"
( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_HELPER="$rigHelper" RIG_REAL_AWK="$rigRealAwk" RIG_REAL_GIT="$rigRealGit" \
	bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --wait --context rig-supervisor-holds <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" ) &
rigCall=$!
rigProcNote "$rigCall" ; rigKept="$rigKept $rigCall"
rigCallIs="$rigCall $( rigBegan "$rigCall" )"
rigRunStarted waited-term first
rigItem="$( rigHeader "$rigRecord" spawns )"
: > "$rigDir/release-first"
rigWaitFor 90 test -s "$rigDir/retry.began" || rigRefuse "the handback retry of scenario waited-term never started its console: $( tail -2 "$rigDir/proxy.err" | LC_ALL=C tr '\n' ' ' )"
rigProcSignal TERM "$rigCall"
sleep 2
rigAssert "TERM sent to the waiting shell while it resumes its run for a handback does not end it, and the retry goes on" \
	"$( rigIsStill "$rigCallIs" && printf shell-alive || printf shell-gone ):$( rigIsStill "$( head -1 "$rigDir/retry.began" )" && printf retry-alive || printf retry-gone )" "shell-alive:retry-alive"
: > "$rigDir/handback-retry" ; : > "$rigDir/release-retry"
rigCallRc=0
wait "$rigCall" 2> /dev/null || rigCallRc=$?
rigAssert "the retry ends, the shell closes the record and the item, and its caller gets the receipt" \
	"$rigCallRc:$( rigClosedAndInReview ):$( LC_ALL=C grep -c -x 'STATUS=succeeded' "$rigDir/proxy.out" )" "0:spawn-succeeded:review:1"

echo "-- 5. a start its caller waits on, whose caller is gone: a write to it does not end the shell before its close --"
rigDir="$rigTmp/waited-gone"
mkdir -p "$rigDir"
: > "$rigDir/handback-first"
## The caller reads nothing and then leaves: from then on nobody reads what the waiting shell writes.
( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_HELPER="$rigHelper" RIG_REAL_AWK="$rigRealAwk" RIG_REAL_GIT="$rigRealGit" \
	bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --wait --context rig-supervisor-holds <<< "RIG-BRIEF" ) 2>&1 \
	| ( while [ ! -e "$rigDir/reader-leaves" ] ; do sleep 1 ; done ) &
rigReader=$!
rigRunStarted waited-gone first
rigItem="$( rigHeader "$rigRecord" spawns )"
: > "$rigDir/reader-leaves"
wait "$rigReader" 2> /dev/null
: > "$rigDir/release-first"
rigWaitFor 45 rigRecordClosed
rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
rigAssert "the run ends with nobody reading what its waiting shell writes, and the shell closes the record and the item all the same" "$( rigClosedAndInReview )" "spawn-succeeded:review"

echo "-- 6. the close: the record first, then the item, and what is posted after them --"
rigStart close-order ""
## The poller of its launch says what it saw while the run still runs, one post, at a moment of its own: waited
## for here, before the run is let go, so that every call noted from the run's end on is one of its close.
rigLaunchSaid(){ [ "$( rigCalls chat.postMessage )" -ge 3 ] ; }
rigWaitFor 20 rigLaunchSaid
: > "$rigDir/order-on"
## From here the fake Slack refuses every post.
rigNo=0 ; while [ "$rigNo" -lt 40 ] ; do echo channel_not_found ; rigNo=$(( rigNo + 1 )) ; done > "$rigDir/post-errors"
: > "$rigDir/release-first"
rigWaitFor 90 test -s "$rigDir/retry.began" || rigRefuse "the handback retry of scenario close-order never started its console"
rigRetryNamed(){ [ "$( rigHeader "$rigRecord" run-process )" = "$( head -1 "$rigDir/retry.began" )" ] ; }
rigWaitFor 20 rigRetryNamed
rigRecordFile(){ ls -i "$rigRecord" 2> /dev/null | LC_ALL=C awk '{ print $1 ; exit }' ; }
rigFileBefore="$( rigRecordFile )"
: > "$rigDir/release-retry"
rigWaitFor 60 rigRecordClosed
rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
rigAssert "a run that ends with no handback, every post about it refused by Slack: its record is closed all the same, and its item enters review" "$( rigClosedAndInReview )" "spawn-succeeded:review"
rigAssert "the close puts the record in place by one rename: another file than the one the launch left, never that one written over" \
	"$( [ -n "$rigFileBefore" ] && [ "$( rigRecordFile )" != "$rigFileBefore" ] && printf renamed || printf written-over )" "renamed"
rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "every call to Slack after the run ended, the lines of a missing handback, the end post and the finish flag, found the record closed and the item in review" \
	"$( LC_ALL=C awk '{ orderAll++ ; if ( $1 == "chat.postMessage" ) { orderPosts++ } if ( $2 ~ /^spawn-(succeeded|failed)$/ && $3 == "review" ) { orderAfter++ } } END { printf "%s:%s", ( orderPosts >= 3 ? "posts-tried" : orderPosts + 0 " posts tried" ), ( orderAll > 0 && orderAll == orderAfter ? "all-after-the-close" : orderAfter + 0 " of " orderAll + 0 " after the close" ) }' "$rigDir/order" 2> /dev/null )" \
	"posts-tried:all-after-the-close"
rigAssert "the bound of the handback retry is ended with the sleep it stood in: nothing of it is left in the run's group" \
	"$( "$rigTmp/bin/ps.real" -axww -o pgid=,command= | LC_ALL=C awk -v runGroup="${rigShell%% *}" '$1 == runGroup && $2 == "sleep" && $3 == "180" { boundLeft++ } END { print boundLeft + 0 }' )" "0"
rigStart close-twice first
echo 1 > "$rigDir/close-fails"
: > "$rigDir/release-first"
rigWaitFor 45 rigRecordClosed
rigAssert "a close whose header writer fails once is made at the second try" "$( rigHeader "$rigRecord" status ):$( cat "$rigDir/close-fails" )" "spawn-succeeded:0"
rigStart close-never first
echo 2 > "$rigDir/close-fails"
: > "$rigDir/release-first"
rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "a close that fails twice leaves the record as it was, and the run's log says so" \
	"$( rigHeader "$rigRecord" status ):$( cat "$rigDir/close-fails" ):$( LC_ALL=C grep -c -F 'could not be closed as spawn-succeeded' "$rigLog" 2> /dev/null )" "spawn-started:0:1"

echo "-- 7. once its close is done a polite end ends the shell; and its standard input is none of its caller's --"
mkdir -p "$rigTmp/after-close"
: > "$rigTmp/after-close/git-stands-after-end"
rigStart after-close first
: > "$rigDir/release-first"
rigWaitFor 45 rigRecordClosed
rigWaitFor 45 test -s "$rigDir/git.began" || rigRefuse "the git of the rig was never called for the end of the transcript of scenario after-close, so the shell was never held past its close"
rigAssert "control: its close done, the shell stands in the commit of its transcript's end, which has no bound" \
	"$( rigClosedAndInReview ):$( rigIsStill "$rigShell" && printf shell-alive || printf shell-gone )" "spawn-succeeded:review:shell-alive"
rigProcNote "${rigShell%% *}"
rigProcSignal TERM "${rigShell%% *}"
rigWaitFor 10 rigHasEnded "$rigShell"
rigAssert "a polite end sent to it then ends it, as it ends any process" "$( rigHasEnded "$rigShell" && printf shell-gone || printf shell-alive )" "shell-gone"
rigAssert "whatever the supervising shell called itself read nothing of its caller: the standard input of each such git is /dev/null" \
	"$( LC_ALL=C awk -v shellPid="${rigShell%% *}" '$1 == shellPid || $2 == shellPid { gitOwn++ ; if ( $3 == "null" ) { gitNull++ } } END { if ( ! gitOwn ) { print "no git called by the shell" } else if ( gitOwn == gitNull ) { print "none-of-its-caller" } else { print gitNull + 0 " of " gitOwn " read /dev/null" } }' "$rigDir/git.calls" 2> /dev/null )" \
	"none-of-its-caller"

echo "-- 8. the helpers a shell keeps for the whole run are signalled only while each is still the process it started --"
## The helpers under a process: the copies of the proxy it started, which are the poster of the feed and the poller
## of the launch, and the reader of the log a waiting shell starts.
rigHelpers(){ ## the process that started them
	"$rigTmp/bin/ps.real" -axww -o pid=,ppid=,command= | LC_ALL=C awk -v leadPid="$1" '$2 == leadPid && ( index( $0, "--intern-op-agent-spawn-proxy" ) || ( $3 == "tail" && $4 == "-n" ) ) { print $1 }'
}
rigHelpersAre(){ [ "$( rigHelpers "$1" | LC_ALL=C awk 'END { print NR + 0 }' )" = "$2" ] ; } ## the process that started them, how many
rigHelpersStill(){ rigProcStill $rigHelperPids | LC_ALL=C awk 'END { print NR + 0 }' ; }
mkdir -p "$rigTmp/helpers"
: > "$rigTmp/helpers/no-launch-marker"
rigStart helpers first
rigWaitFor 20 rigHelpersAre "${rigShell%% *}" 2
rigHelperPids="$( rigHelpers "${rigShell%% *}" | LC_ALL=C tr '\n' ' ' )"
rigProcNote $rigHelperPids ; rigKept="$rigKept $rigHelperPids"
rigAssert "control: beside its run the shell keeps two helpers, the poster of its feed and the poller of its launch, which has seen no launch" "$( rigHelpersStill )" "2"
printf '%s\n' $rigHelperPids > "$rigDir/ps-says-another"
: > "$rigDir/release-first"
rigWaitFor 45 rigRecordClosed
rigWaitFor 20 test -f "$rigData/board/review/$rigItem.md"
sleep 2
rigAssert "the run closes, its record and its item, and neither number is signalled: as the process list tells it, each is another process's by then" \
	"$( rigClosedAndInReview ):$( rigHelpersStill )" "spawn-failed:review:2"
rigProcSignal KILL $rigHelperPids
rigDir="$rigTmp/helpers-waited"
mkdir -p "$rigDir"
: > "$rigDir/no-launch-marker" ; : > "$rigDir/handback-first"
( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_HELPER="$rigHelper" RIG_REAL_AWK="$rigRealAwk" RIG_REAL_GIT="$rigRealGit" \
	bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --wait --context rig-supervisor-holds <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" ) &
rigCall=$!
rigProcNote "$rigCall" ; rigKept="$rigKept $rigCall"
rigRunStarted helpers-waited first
rigItem="$( rigHeader "$rigRecord" spawns )"
rigWaitFor 20 rigHelpersAre "$rigCall" 3
rigHelperPids="$( rigHelpers "$rigCall" | LC_ALL=C tr '\n' ' ' )"
rigProcNote $rigHelperPids ; rigKept="$rigKept $rigHelperPids"
rigAssert "control: a waiting shell keeps three, the reader of its run's log among them" "$( rigHelpersStill )" "3"
printf '%s\n' $rigHelperPids > "$rigDir/ps-says-another"
: > "$rigDir/release-first"
wait "$rigCall" 2> /dev/null
sleep 2
rigAssert "its run closes and the call returns, and none of the three numbers is signalled" "$( rigClosedAndInReview ):$( rigHelpersStill )" "spawn-failed:review:3"
rigProcSignal KILL $rigHelperPids

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SUPERVISOR HOLDS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SUPERVISOR_HOLDS: OK (%d assertions, offline)\n' "$rigPasses"
