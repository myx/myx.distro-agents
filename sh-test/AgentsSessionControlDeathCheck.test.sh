#!/usr/bin/env bash
## Behavioural check on the death of a run, as the control thread of its session judges it, tells it and asks about
## it (--intern-session-control, sh-lib/session/AgentsTools.SessionControlDeath.include), run rather than read, against a rig
## workspace built here: spawn records, session stores, a board, and a process list and a Slack of the rig's own.
## Held:
##   1. WHAT A DEATH IS. The process of a run gone, its supervising shell gone, its record still open, and no word
##      on the record that it was killed: one line in control/dead of the session's folder, with its id, its member,
##      whether it was the executor or a participant and when it was found, written once, and the state reads
##      `member-dead`. No death: a run its supervising shell is still closing; a run that lives, whatever it handed
##      back; one that is resumed for its handback; a closed record, however it was closed; a run the console killed.
##   2. A RECORD THAT NAMES NO SUPERVISING SHELL is given its closing time (SESSION_CONTROL_CLOSING_SECONDS) from the
##      moment its process was first seen gone, kept in control/gone, which outlives the thread: no death before, a
##      death after, and an ordinary end where the record closes in time.
##   3. THE THREAD STAYS while a death is not settled, with a participant alive and with none, and asks once.
##   4. WHO IS TOLD AND WHO IS ASKED. No reviewer set: the message alone, in the thread of the session that requested
##      the run, or to the human-owner as a plain message where no session did; the record is then closed as ended
##      without close and the death is settled. A reviewer set: one question of the kind decision, as the team bot,
##      with four options: to the member that brought the run in where the reviewer is its live session, one post and
##      no note beside it; to the human-owner where the reviewer is a person or its session has ended, with one note
##      in the thread of the requesting session where that still runs and no handback stands there.
##   5. WHAT THE QUESTION SAYS, and that it is recorded as every decision is: its record open, its number emoji placed.
##   6. A POST THAT FAILS is tried again and asked once. A POST THAT HANGS holds no tick and is ended at its bound.
##   7. WHO SPEAKS: a death the thread keeps is the thread's while it lives, and a death it told is told by no other.
## Red before the change: every assertion but the controls. Offline: a curl first on PATH answers as Slack and opens
## no socket; a ps beside it lists the rig's runs only, stand-in processes, never a real CLI. Every thread, post and
## stand-in this check starts is ended by it, through the rig's helpers.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's helper for control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlDeathCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data" ; rigSlack="$rigTmp/slack"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions" ; rigPending="$rigWs/.local/agents/pending"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review" "$rigSlack"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
## Every thread and stand-in of this check, and every post a thread of it started: at its end each is ended, with
## what it started, while it is still itself. The Slack of the rig is let go first, so no post waits on it.
rigStarted=""
rigCleanup(){
	local cleanFile
	rm -f "$rigSlack/hang"
	rigControlThreadsEnd "$rigTmp"
	for cleanFile in "$rigStores"/*/control/post.* ; do
		case "$cleanFile" in *.result) continue ;; esac
		[ -f "$cleanFile" ] || continue
		rigProcNoteFrom "$cleanFile"
		rigProcSignalWithChildren KILL $( LC_ALL=C awk 'NF == 2 && $1 ~ /^[0-9]+$/ { print $1 }' "$cleanFile" 2> /dev/null )
	done
	rigProcSignalWithChildren KILL $rigStarted
}
trap 'rigCleanup ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST, as AgentsSessionControlStateCheck keeps it: the whole-host listing is the rig's own
## list, each line only while its process lives, and every other call goes to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
## THE RIG'S SLACK. Each call is logged with its method and the token it was made under, and each body it carried.
## A post gets a ts of its own. A line of slack/post-errors is the error the next post is answered with, and while
## slack/hang stands a post is not answered at all: the body of such a post is kept apart, in bodies.refused and in
## bodies.hung, so slack/bodies holds the posts that Slack took.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigDir="${0%/*}/../slack"
rigHeader="$( cat )"
rigMethod="" ; rigPrevArg="" ; rigBody=""
for rigArg in "$@" ; do
	case "$rigArg" in https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;; esac
	[ "$rigPrevArg" != "--data-binary" ] || rigBody="${rigArg#@}"
	rigPrevArg="$rigArg"
done
rigKeep(){ [ -z "$rigBody" ] || { printf '%s ' "$rigMethod" ; cat "$rigBody" ; echo ; } >> "$rigDir/$1" ; }
rigToken="${rigHeader#Authorization: Bearer }"
printf '%s %s\n' "$rigMethod" "$rigToken" >> "$rigDir/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	chat.postMessage)
		[ ! -e "$rigDir/hang" ] || { rigKeep bodies.hung ; exec sleep 30 ; }
		if [ -s "$rigDir/post-errors" ] ; then
			rigError="$( head -1 "$rigDir/post-errors" )"
			tail -n +2 "$rigDir/post-errors" > "$rigDir/post-errors.next" && mv "$rigDir/post-errors.next" "$rigDir/post-errors"
			rigKeep bodies.refused
			printf '{"ok":false,"error":"%s"}\n' "$rigError"
			exit 0
		fi
		rigKeep bodies
		rigTs="$( date +%s ).$( printf '%06d' "$$" )"
		printf '{"ok":true,"channel":"DRIG00001","ts":"%s","message":{"ts":"%s","user":"URIGBOT01"}}\n' "$rigTs" "$rigTs"
	;;
	reactions.add) [ ! -e "$rigDir/hang-react" ] || exec sleep 30 ; rigKeep bodies ; printf '{"ok":true}\n' ;;
	*) rigKeep bodies ; printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
## The closing time of a record is twelve seconds here, which two ticks of a loaded machine stay within, and a tick one. The bound of a post is thirty seconds, which
## no post of this rig reaches on a loaded machine, and two where a scenario is about the bound: a post that is
## ended at its bound is tried again, and what that does is held by those scenarios, not left to the load.
rigBound(){ ## seconds
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSESSION_CONTROL_TICK_SECONDS=1\nSESSION_CONTROL_CLOSING_SECONDS=12\nSESSION_CONTROL_POST_SECONDS=%s\n' "$1" > "$rigWs/.local/.agents/magic-team.agent.env.rig" \
		&& mv -f "$rigWs/.local/.agents/magic-team.agent.env.rig" "$rigWs/.local/.agents/magic-team.agent.env"
}
rigBound 30
for rigMember in keeper-rig keeper-myx magic-coordinator human-owner ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## A record is put in place by one rename, as the tooling closes one: no tick of a running thread reads half of it.
rigRec(){ ## run id, which is its sandbox too; session id; member; status; more frontmatter lines (may be empty)
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$3" "$4" "${5:-}" "$2" > "$rigSp/$1/$1.md.rig" && mv -f "$rigSp/$1/$1.md.rig" "$rigSp/$1/$1.md"
}
rigClosed='resolved-at: 2026-10-13 09:30 +0300
'
rigItem(){ ## item stem, run id, review-by (may be empty), board state (running where not given)
	printf -- '---\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# the rig task of %s\n' "$2" "${3:+review-by: $3
}" "$2" > "$rigData/board/${4:-running}/$1.md"
}
rigHeader(){ ## run id, header name -- its value in the frontmatter of that run's record
	LC_ALL=C awk -v wantName="$2: " '
		$0 == "---" { if ( ++fenceCount > 1 ) { exit ; } next ; }
		fenceCount == 1 && index( $0, wantName ) == 1 { print substr( $0, length( wantName ) + 1 ) ; exit ; }
	' "$rigSp/$1/$1.md" 2> /dev/null
}
## A stand-in process under its own pid that only waits; with a run id given it stands in the rig's process list
## as that run, by its own --session-id word. Sets rigStandPid.
rigStandPid=""
rigStand(){ ## run id (may be empty)
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	[ -z "${1:-}" ] || printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigIsStill(){ ## `<pid> <start>` -- that pid is still the process that began then
	case "$1" in *' '*) ;; *) return 1 ;; esac
	[ "$( rigProcBegan "${1%% *}" )" = "$1" ]
}
rigCall(){ ## the tooling, as a bare console of the rig workspace calls it
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" )
}
rigRc=0
rigOne(){ ## session id -- one tick; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	rigCall "$rigOp" --one --session-id "$1" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigThreadPid=""
rigThread(){ ## name of its output files, session id
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOp" --run --session-id "$2" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null &
	rigThreadPid=$!
	rigProcNote "$rigThreadPid" ; rigStarted="$rigStarted $rigThreadPid"
}
rigHolds(){ ## session id, pid -- the pid file of the session names that pid
	local holdsLine=""
	{ IFS= read -r holdsLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holdsLine" ] && [ "${holdsLine%% *}" = "$2" ]
}
rigThreadEnd(){ ## pid of a thread of this check -- TERM, and its end waited for
	rigProcSignal TERM "$1" ; rigWaitFor 20 rigEnded "$1" ; { wait "$1" ; } 2> /dev/null
}
rigState(){ ## session id -- the word of its state file
	LC_ALL=C sed -n 's/^state: //p' "$rigStores/$1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p'
}
rigStateIs(){ [ "$( rigState "$1" )" = "$2" ] ; } ## session id, word
rigControl(){ ## session id -- the names in its control folder, a space between them
	( cd "$rigStores/$1/control" 2> /dev/null && ls -A | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )
}
rigLogHas(){ ## session id, fixed text -- how many lines of its log hold it
	LC_ALL=C grep -c -F -- "$2" "$rigStores/$1/control/log" 2> /dev/null || :
}
rigLogSays(){ [ "$( rigLogHas "$1" "$2" )" -ge 1 ] ; } ## session id, fixed text
## The lines of control/dead: how many, for one run or for every run; the line of one run; and whether it holds a mark.
rigDeadLines(){ ## session id, run id (every run where not given)
	LC_ALL=C awk -v wantRun="${2:-}" 'NF && ( wantRun == "" || $1 == wantRun ) { lineCount++ } END { print lineCount + 0 }' "$rigStores/$1/control/dead" 2> /dev/null || printf '0\n'
}
rigDeadLine(){ ## session id, run id -- its line, the moments it holds written as WHEN
	LC_ALL=C awk -v wantRun="$2" '$1 == wantRun { print ; exit }' "$rigStores/$1/control/dead" 2> /dev/null | LC_ALL=C sed 's/=[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]*Z/=WHEN/g'
}
rigDeadIs(){ [ "$( rigDeadLines "$1" "$2" )" = "1" ] ; } ## session id, run id
rigDeadSettled(){ case " $( rigDeadLine "$1" "$2" ) " in *" settled="*) return 0 ;; esac ; return 1 ; } ## session id, run id
## A post of a session in flight: a marker of its control folder names a process that is still itself.
rigPosting(){ ## session id
	local postingFile postingLine
	for postingFile in "$rigStores/$1/control"/post.* ; do
		case "$postingFile" in *.result) continue ;; esac
		[ -f "$postingFile" ] || continue
		postingLine="" ; { IFS= read -r postingLine < "$postingFile" ; } 2> /dev/null
		! rigIsStill "$postingLine" || return 0
	done
	return 1
}
rigIdle(){ ! rigPosting "$1" ; } ## session id
rigSettle(){ ## session id -- its posts end, and one more tick takes what they left
	rigWaitFor 30 rigIdle "$1" ; rigOne "$1"
}
## THE POSTS THE RIG'S SLACK TOOK that hold a text: `<conversation> <thread, or - for none> <whom its author line addresses>`.
rigPosts(){ ## fixed text, a second fixed text (may be empty), a text it must not hold (may be empty)
	LC_ALL=C awk -v wantText="$1" -v wantMore="${2:-}" -v wantNot="${3:-}" '
		$1 != "chat.postMessage" || index( $0, wantText ) == 0 { next ; }
		wantMore != "" && index( $0, wantMore ) == 0 { next ; }
		wantNot != "" && index( $0, wantNot ) > 0 { next ; }
		{
			noteChannel = "-" ; noteThread = "-" ; noteWhom = "-" ;
			if ( match( $0, /"channel":"[^"]*"/ ) ) { noteChannel = substr( $0, RSTART + 11, RLENGTH - 12 ) ; }
			if ( match( $0, /"thread_ts":"[^"]*"/ ) ) { noteThread = substr( $0, RSTART + 13, RLENGTH - 14 ) ; }
			arrowAt = index( $0, "→ " ) ;
			if ( arrowAt > 0 ) { noteRest = substr( $0, arrowAt + length( "→ " ) ) ; noteEnd = index( noteRest, ".\\n" ) ; if ( noteEnd > 0 ) { noteWhom = substr( noteRest, 1, noteEnd - 1 ) ; } }
			## the name alone, as the author line shows it between its marks
			nameAt = index( noteWhom, "*_" ) ; if ( nameAt > 0 ) { noteWhom = substr( noteWhom, nameAt + 2 ) ; nameEnd = index( noteWhom, "_*" ) ; if ( nameEnd > 0 ) { noteWhom = substr( noteWhom, 1, nameEnd - 1 ) ; } }
			print noteChannel, noteThread, noteWhom ;
		}
	' "$rigSlack/bodies" 2> /dev/null
}
rigQuestions(){ rigPosts 'Decision' "\`$1\`" | LC_ALL=C tr '\n' ';' ; } ## run id -- the questions about that run
rigNotes(){ rigPosts 'died:' "\`$1\`" 'Decision' | LC_ALL=C tr '\n' ';' ; } ## run id -- the notes that it died
rigQuestionBody(){ LC_ALL=C grep -F -- 'Decision' "$rigSlack/bodies" 2> /dev/null | LC_ALL=C grep -F -- "\`$1\`" | LC_ALL=C sed -n '1p' ; } ## run id
## The open records of the kind decision that carry a session: `<address-to>` a line.
rigAsks(){ ## session id
	local asksFile
	for asksFile in "$rigPending"/*.md ; do
		[ -f "$asksFile" ] || continue
		LC_ALL=C grep -q -x -F -- 'kind: decision' "$asksFile" && LC_ALL=C grep -q -x -F -- 'status: reply-pending' "$asksFile" && LC_ALL=C grep -q -x -F -- "session-id: $1" "$asksFile" || continue
		LC_ALL=C sed -n 's/^address-to: //p' "$asksFile" | LC_ALL=C sed -n '1p'
	done | LC_ALL=C tr '\n' ';'
}
rigSaid(){ ## fixed text -- how many lines of the last stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
rigGoneNotes(){ ## session id, run id -- how many lines of control/gone note that run
	LC_ALL=C awk -v wantRun="$2" '$1 == wantRun && $2 ~ /^[0-9]+$/ { noteCount++ } END { print noteCount + 0 }' "$rigStores/$1/control/gone" 2> /dev/null || printf '0\n'
}

## What a record names as a supervising shell that is gone: a process of this check that has ended, with when it began.
rigStand '' ; rigGonePid="$rigStandPid"
rigGoneShell="$( rigProcBegan "$rigGonePid" )"
rigProcSignal TERM "$rigGonePid" ; rigWaitFor 10 rigEnded "$rigGonePid" || rigRefuse "the stand-in of a supervising shell that is gone did not end"
case "$rigGoneShell" in *' '*) ;; *) rigRefuse "when the stand-in of a supervising shell began could not be read" ;; esac
## The session that requests runs below: magic-coordinator runs as s-req, with its thread.
rigReqThread="CRIGSESS1:1700000001.000100"
rigRec s-req s-req magic-coordinator spawn-started "session-thread: $rigReqThread
"
rigStand s-req
rigAsked="parent-spawn-id: s-req
parent-session-id: s-req
parent-member: magic-coordinator
parent-thread: $rigReqThread
"

echo "-- 1. what a death is --"
rigItem item-gone d-gone human-owner
rigRec d-gone d-gone keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-gone
"
rigOne d-gone
rigAssert "a run that is gone, with its record open and its supervising shell gone, is a death after one tick: one line with its id, its member, that it was the executor and when it was found, and the state reads member-dead" \
	"$rigRc:$( rigDeadLines d-gone ):$( rigDeadLine d-gone d-gone | LC_ALL=C cut -d ' ' -f 1-4 ):$( rigState d-gone )" "0:1:d-gone member=keeper-rig role=executor found=WHEN:member-dead"
rigSettle d-gone
rigTen=0
while [ "$rigTen" -lt 10 ] ; do rigOne d-gone ; rigTen=$(( rigTen + 1 )) ; done
rigAssert "a death is recorded once and asked once: after ten more ticks one line, one question to its reviewer, one open record" \
	"$( rigDeadLines d-gone ):$( rigQuestions d-gone ):$( rigAsks d-gone )" "1:URIGOWNER - human-owner;:human-owner;"
## Its supervising shell is still closing it.
rigStand '' ; rigShell="$rigStandPid"
rigRec d-closng d-closng keeper-rig spawn-started "supervisor-process: $( rigProcBegan "$rigShell" )
"
rigOne d-closng ; rigOne d-closng ; rigOne d-closng
rigAssert "a run that its supervising shell is still closing is no death: three ticks record none, note no moment and write no state" \
	"$rigRc:$( rigDeadLines d-closng ):$( rigControl d-closng ):[$( rigState d-closng )]" "0:0::[]"
rigRec d-closng d-closng keeper-rig spawn-failed "$rigClosed"
rigOne d-closng
rigAssert "once that shell closed the record, with no handback, it made an ordinary end: finished, and no death" "$( rigState d-closng ):$( rigDeadLines d-closng )" "finished:0"
## It handed back and waits for its review: its process lives.
rigItem item-wait d-wait human-owner review
rigRec d-wait d-wait keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-wait
"
rigStand d-wait
rigOne d-wait
rigAssert "a run that handed back and waits for its review is alive: running, and no death" "$( rigState d-wait ):$( rigDeadLines d-wait )" "running:0"
## It is resumed for its handback: the process its record names lives, and no line of the list carries its word.
rigStand '' ; rigResumed="$rigStandPid"
rigRec d-resume d-resume keeper-rig spawn-started "run-process: $( rigProcBegan "$rigResumed" )
supervisor-process: $rigGoneShell
"
rigOne d-resume
rigAssert "a run that is resumed for its handback counts as alive: running, and no death" "$( rigState d-resume ):$( rigDeadLines d-resume )" "running:0"
## Closed records, their supervising shell gone.
rigRec d-done d-done keeper-rig spawn-succeeded "${rigClosed}supervisor-process: $rigGoneShell
"
rigRec d-adv d-adv keeper-rig spawn-ended-without-close "${rigClosed}supervisor-process: $rigGoneShell
"
rigOne d-done ; rigOne d-adv ; rigOne d-adv ; rigOne d-adv
rigAssert "a closed record is no death, whether its run handed back or the advance pass closed it as ended without close: finished, none recorded, nothing posted" \
	"$( rigState d-done ):$( rigDeadLines d-done ):$( rigState d-adv ):$( rigDeadLines d-adv ):$( rigPosts '`d-done`' | LC_ALL=C grep -c . ):$( rigPosts '`d-adv`' | LC_ALL=C grep -c . )" "finished:0:finished:0:0:0"
## The console killed it: its record says so, and is still open.
rigRec d-killed d-killed keeper-rig spawn-started "supervisor-process: $rigGoneShell
killed-by: rig
killed-at: 2026-10-13T06:10:00Z
"
rigOne d-killed ; rigOne d-killed ; rigOne d-killed
rigAssert "a run the console killed is no death: none recorded, no state, nothing posted" \
	"$rigRc:$( rigDeadLines d-killed ):[$( rigState d-killed )]:$( rigPosts '`d-killed`' | LC_ALL=C grep -c . )" "0:0:[]:0"

echo "-- 2. a record that names no supervising shell is given its closing time --"
rigItem item-old d-old human-owner
rigRec d-old d-old keeper-rig spawn-started "spawns: item-old
"
rigOne d-old
rigNoted="$( cat "$rigStores/d-old/control/gone" 2> /dev/null )"
rigAssert "its process gone and its record open: the first tick notes that moment for the run in control/gone, and records no death" \
	"$rigRc:$( printf '%s\n' "$rigNoted" | LC_ALL=C grep -c -E '^d-old [0-9]+$' ):$( rigDeadLines d-old ):[$( rigState d-old )]:$( rigSaid 'no run of it is alive on this host and 1 record(s) are still open' )" "0:1:0:[]:1"
rigOne d-old
rigAssert "a tick within the closing time records no death, and a thread started again reads the same moment: the closing time is not started anew" \
	"$( rigDeadLines d-old ):$( cat "$rigStores/d-old/control/gone" 2> /dev/null )" "0:$rigNoted"
sleep 13
rigOne d-old
rigAssert "after its closing time, its record still open, it is a death: one line, the state member-dead, and its note is gone from control/gone" \
	"$( rigDeadLines d-old d-old ):$( rigState d-old ):$( rigGoneNotes d-old d-old )" "1:member-dead:0"
rigRec d-oldok d-oldok keeper-rig spawn-started ''
rigOne d-oldok
rigOldNoted="$( rigGoneNotes d-oldok d-oldok )"
rigRec d-oldok d-oldok keeper-rig spawn-succeeded "$rigClosed"
rigOne d-oldok
rigAssert "a record that names no supervising shell and closes within its closing time is an ordinary end: no death, and its note is gone" \
	"$rigOldNoted:$( rigState d-oldok ):$( rigDeadLines d-oldok ):$( rigGoneNotes d-oldok d-oldok )" "1:finished:0:0"

echo "-- 3. the thread stays while a death is not settled --"
rigItem item-exec d-exec human-owner
rigRec d-exec d-exec keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-exec
"
rigRec p-exec d-exec keeper-myx spawn-started ''
rigStand p-exec
rigThread exec d-exec ; rigExec="$rigThreadPid"
rigWaitFor 20 rigHolds d-exec "$rigExec" || rigRefuse "the thread of d-exec did not start, so nothing below would be measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/exec.err" | cut -c1-600 )"
rigWaitFor 15 rigDeadIs d-exec d-exec
sleep 3
rigAssert "the death of the executor leaves the thread running while a participant lives: its line says executor, the state reads member-dead, and no line is made for the participant" \
	"$( rigEnded "$rigExec" && echo ended || echo alive ):$( rigDeadLine d-exec d-exec | LC_ALL=C cut -d ' ' -f 3 ):$( rigState d-exec ):$( rigDeadLines d-exec )" "alive:role=executor:member-dead:1"
rigThreadEnd "$rigExec"
## The only run of a session is a death, and its question is open: d-gone, of section 1.
rigCalls="$( LC_ALL=C grep -c '^chat.postMessage ' "$rigSlack/calls" )"
rigThread only d-gone ; rigOnly="$rigThreadPid"
rigWaitFor 20 rigHolds d-gone "$rigOnly" || rigRefuse "the thread of d-gone did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/only.err" | cut -c1-600 )"
sleep 10
rigAssert "the thread stays when the only run of its session is a death and its question is open: after ten ticks it lives, with its pid file and its lock, the state member-dead, and it has posted nothing more" \
	"$( rigEnded "$rigOnly" && echo ended || echo alive ):$( rigControl d-gone | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e pid -e lock ):$( rigState d-gone ):$( rigQuestions d-gone ):$(( $( LC_ALL=C grep -c '^chat.postMessage ' "$rigSlack/calls" ) - rigCalls ))" "alive:2:member-dead:URIGOWNER - human-owner;:0"
rigCall --manager-session-list > "$rigTmp/list.out" 2> "$rigTmp/list.err" < /dev/null
rigAssert "a session with no live run and an open question reads waiting in the list of sessions" \
	"$( LC_ALL=C awk '$1 == "session" && $2 == "d-gone" { for ( wordAt = 3 ; wordAt <= NF ; wordAt++ ) { if ( $wordAt == "waiting" ) { print "waiting" ; exit } } }' "$rigTmp/list.out" )" "waiting"
rigCall --member-pending-reply-read magic-coordinator --any-owner > "$rigTmp/pending.out" 2> "$rigTmp/pending.err" < /dev/null
rigGoneAsk="$( LC_ALL=C grep -l -x -F -- 'session-id: d-gone' "$rigPending"/*.md 2> /dev/null | LC_ALL=C sed -n '1p' )"
rigGoneAsk="${rigGoneAsk##*/}" ; rigGoneAsk="${rigGoneAsk%.md}"
rigAssert "the question is among the pending questions: one open record of the kind decision, addressed to the reviewer, with the id of the session, and the line of the death keeps its id" \
	"$( [ -n "$rigGoneAsk" ] && LC_ALL=C grep -c -F -- "$rigGoneAsk" "$rigTmp/pending.out" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "listed" : "not-listed" }' ):$( LC_ALL=C grep -c -x -F -e 'kind: decision' -e 'address-to: human-owner' -e 'session-id: d-gone' -e 'ask-identity: bot' "$rigPending/$rigGoneAsk.md" 2> /dev/null ):$( rigDeadLine d-gone d-gone | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F -- "asked=$rigGoneAsk" )" "listed:4:1"
rigThreadEnd "$rigOnly"

echo "-- 4. who is told and who is asked --"
## No reviewer and no session that requested it: a plain message to the human-owner, and the record is closed.
rigRec d-plain d-plain keeper-rig spawn-started "supervisor-process: $rigGoneShell
session-comment: plain start
"
rigOne d-plain ; rigSettle d-plain
rigAssert "a dead run with no reviewer and no parent session is told to the human-owner as a plain message, in words that say it died: one message, no question, no record" \
	"$( rigNotes d-plain ):$( rigQuestions d-plain ):$( rigAsks d-plain ):$( LC_ALL=C grep -F -- '`d-plain`' "$rigSlack/bodies" | LC_ALL=C grep -c -F -- 'No session requested this run' )" "URIGOWNER - human-owner;:::1"
rigOne d-plain
rigAssert "its record is closed as ended without close, the line of the death is settled, and the session reads finished" \
	"$( rigHeader d-plain status ):$( rigDeadSettled d-plain d-plain && echo settled ):$( rigState d-plain )" "spawn-ended-without-close:settled:finished"
## No dispatch item, requested by a member of a live session: the note in the thread of that session, and no question.
rigRec d-noitm d-noitm keeper-rig spawn-started "${rigAsked}supervisor-process: $rigGoneShell
"
rigOne d-noitm ; rigSettle d-noitm
rigAssert "a dead run with no dispatch item gets the message and no question: one note in the thread of the session that requested it, addressed to the member that brought it in, no record, its record closed and the death settled" \
	"$( rigNotes d-noitm ):$( rigQuestions d-noitm ):$( rigAsks d-noitm ):$( rigHeader d-noitm status ):$( rigDeadSettled d-noitm d-noitm && echo settled )" "${rigReqThread%%:*} ${rigReqThread#*:} magic-coordinator;:::spawn-ended-without-close:settled"
## A participant whose reviewer is the session that requested it, and the member that brought it in still runs there.
rigItem item-part d-part s-req
rigRec d-part s-req keeper-rig spawn-started "${rigAsked}session-thread: $rigReqThread
supervisor-process: $rigGoneShell
spawns: item-part
"
rigOne s-req ; rigSettle s-req
rigAssert "the question about a dead participant goes to the member that brought it in: one post in the thread of that session, the question, addressed to that member; no note beside it and nothing to the human-owner" \
	"$( rigQuestions d-part ):$( rigNotes d-part ):$( rigAsks s-req ):$( rigDeadLine s-req d-part | LC_ALL=C cut -d ' ' -f 3 ):$( rigState s-req )" "${rigReqThread%%:*} ${rigReqThread#*:} magic-coordinator;::magic-coordinator;:role=participant:member-dead"
## Its reviewer is a person, and the member that brought it in still runs in the session that requested it.
rigItem item-ho d-ho human-owner
rigRec d-ho d-ho keeper-myx spawn-started "${rigAsked}supervisor-process: $rigGoneShell
spawns: item-ho
session-comment: daily of Monday
"
rigReacts="$( LC_ALL=C grep -c -x -F -- 'reactions.add rig-bot-token-TEAM' "$rigSlack/calls" 2> /dev/null || : )"
rigOne d-ho ; rigSettle d-ho
rigReacts=$(( $( LC_ALL=C grep -c -x -F -- 'reactions.add rig-bot-token-TEAM' "$rigSlack/calls" 2> /dev/null || : ) - rigReacts ))
rigAssert "the question about a run whose item a person reviews goes where the run reports to, whatever its reviewer: one post in the thread of that session, to its member, and no note beside it" \
	"$( rigQuestions d-ho ):$( rigNotes d-ho ):$( rigAsks d-ho )" "${rigReqThread%%:*} ${rigReqThread#*:} magic-coordinator;::magic-coordinator;"
## Its reviewer is a session that has ended.
rigRec s-over s-over magic-coordinator spawn-succeeded "${rigClosed}session-thread: CRIGSESS2:1700000002.000100
"
rigItem item-ended d-ended s-over
rigRec d-ended d-ended keeper-rig spawn-started "parent-spawn-id: s-over
parent-session-id: s-over
parent-member: magic-coordinator
parent-thread: CRIGSESS2:1700000002.000100
supervisor-process: $rigGoneShell
spawns: item-ended
"
rigOne d-ended ; rigSettle d-ended
rigAssert "the question about a run whose parent session has ended goes to the human-owner, and nothing is posted in a session thread" \
	"$( rigQuestions d-ended ):$( LC_ALL=C grep -c -F -- 'CRIGSESS2' "$rigSlack/bodies" ):$( rigAsks d-ended )" "URIGOWNER - human-owner;:0:human-owner;"
## It posted its handback in the thread of the session that requested it, and then died with its record open.
rigItem item-hb d-hb human-owner review
rigRec d-hb d-hb keeper-rig spawn-started "${rigAsked}supervisor-process: $rigGoneShell
spawns: item-hb
"
mkdir -p "$rigStores/d-hb"
printf '%s\n' "$rigStores/d-hb/session-transcript.log" > "$rigStores/d-hb/transcript"
printf '2026-10-13T06:00:00Z HANDBACK to=session-parent text="the rig step is done"\n' > "$rigStores/d-hb/session-transcript.log"
rigOne d-hb ; rigSettle d-hb
rigAssert "a run that died after its handback is a death, and gets the question where it reports to, and no note beside it" \
	"$( rigDeadLines d-hb d-hb ):$( rigQuestions d-hb ):$( rigNotes d-hb ):$( rigAsks d-hb )" "1:${rigReqThread%%:*} ${rigReqThread#*:} magic-coordinator;::magic-coordinator;"
## Two runs of one session die between two ticks: a session a client founded, with no record under its own id.
rigItem item-two-a d-two-a human-owner
rigItem item-two-b d-two-b human-owner
rigRec d-two-a s-two keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-two-a
"
rigRec d-two-b s-two keeper-myx spawn-started "supervisor-process: $rigGoneShell
spawns: item-two-b
"
mkdir -p "$rigStores/s-two"
rigOne s-two
rigTwoLines="$( rigDeadLines s-two d-two-a ):$( rigDeadLines s-two d-two-b ):$( rigDeadLines s-two )"
rigSettle s-two ; rigOne s-two ; rigSettle s-two
rigAssert "two dead runs are two lines, and two questions, each naming one of them, with two open records" \
	"$rigTwoLines:$( rigQuestions d-two-a ):$( rigQuestions d-two-b ):$( rigAsks s-two )" "1:1:2:URIGOWNER - human-owner;:URIGOWNER - human-owner;:human-owner;human-owner;"

echo "-- 5. what the question says, and how it is posted --"
rigBody="$( rigQuestionBody d-ho )"
rigAssert "the question names the dead member and its session, says that it was the executor, and no id opens a line of it" \
	"$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -- 'keeper-myx died' ):$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -- 'daily of Monday' ):$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -- 'the executor' ):$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -e '\nd-ho' -e '\n`d-ho' )" "1:1:1:0"
rigAssert "the question of a dead participant says that it was a participant" "$( rigQuestionBody d-part | LC_ALL=C grep -c -F -- 'a participant' )" "1"
rigAssert "it offers four numbered options whose first words are resume, fresh, close and kill, in that order" \
	"$( printf '%s' "$rigBody" | LC_ALL=C awk '{ atOne = index( $0, "1️⃣ resume:" ) ; atTwo = index( $0, "2️⃣ fresh:" ) ; atThree = index( $0, "3️⃣ close:" ) ; atFour = index( $0, "4️⃣ kill:" ) ; print ( atOne > 0 && atTwo > atOne && atThree > atTwo && atFour > atThree ) ? "four-in-order" : atOne ":" atTwo ":" atThree ":" atFour ; exit }' )" "four-in-order"
rigAssert "it is posted as any decision is: filled from the template of a decision, and the number emoji of its four options are placed under it by the team bot" \
	"$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -- '🧭 Decision' ):$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F -- 'How to answer' ):$rigReacts" "1:1:4"
rigAssert "every post of the rig was made as the team bot, and none under another account" \
	"$( LC_ALL=C awk '$1 == "chat.postMessage" && $2 != "rig-bot-token-TEAM" { otherCount++ } END { print otherCount + 0 }' "$rigSlack/calls" )" "0"

echo "-- 6. a post that fails is tried again; a post that hangs holds no tick and is ended at its bound --"
rigItem item-retry d-retry human-owner
rigRec d-retry d-retry keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-retry
"
printf 'channel_not_found\n' > "$rigSlack/post-errors"
rigOne d-retry ; rigSettle d-retry
rigAssert "the stub refuses the first post: no question stands, no record is open, the line of the death keeps no question, and the log of the thread says that it failed" \
	"[$( rigQuestions d-retry )]:[$( rigAsks d-retry )]:$( rigDeadLine d-retry d-retry | LC_ALL=C grep -c -F -- 'asked=' ):$( rigLogHas d-retry 'it is tried again' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "said" : "not-said" }' ):$( LC_ALL=C grep -c -F -- '`d-retry`' "$rigSlack/bodies.refused" 2> /dev/null )" "[]:[]:0:said:1"
rigOne d-retry ; rigSettle d-retry
rigAssert "and takes the second: one question stands where it was sent, and one record is open" "$( rigQuestions d-retry ):$( rigAsks d-retry )" "URIGOWNER - human-owner;:human-owner;"
## The post is ended at its bound after Slack took the question and before the post could mark it: the stub does
## not answer the first emoji.
rigItem item-cut d-cut human-owner
rigRec d-cut d-cut keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-cut
"
rigBound 2 ; : > "$rigSlack/hang-react"
rigOne d-cut ; rigSettle d-cut
rigCutFirst="$( rigQuestions d-cut ):$( rigAsks d-cut ):$( rigDeadLine d-cut d-cut | LC_ALL=C grep -c -F -- 'asked=' ):$( rigLogHas d-cut 'did not end within its bound of 2 seconds' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "said" : "not-said" }' )"
rm -f "$rigSlack/hang-react" ; rigBound 30
rigOne d-cut ; rigSettle d-cut ; rigOne d-cut ; rigSettle d-cut
rigAssert "a post that is ended at its bound after Slack took the question is not posted again: the next try finds its record, places its emoji and keeps its id on the line, and one question stands with one record" \
	"$rigCutFirst|$( rigQuestions d-cut ):$( rigAsks d-cut ):$( rigDeadLine d-cut d-cut | LC_ALL=C grep -c -F -- 'asked=' )" "URIGOWNER - human-owner;:human-owner;:0:said|URIGOWNER - human-owner;:human-owner;:1"
## The post was made and its record could not be written: what the send answered is kept, and nothing else of it.
rigItem item-sent d-sent human-owner
rigRec d-sent d-sent keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-sent
"
mkdir -p "$rigStores/d-sent/control"
printf 'SENT_MESSAGE_CHANNEL=DRIG00001\nSENT_MESSAGE_TS=1700000009.000900\nSENT_MESSAGE_ADDRESSEES=URIGOWNER\n' > "$rigStores/d-sent/control/post.d-sent.sent"
rigOne d-sent ; rigSettle d-sent
rigAssert "a question that was posted while its record could not be written gets its record at the next try, and no second post" \
	"[$( rigQuestions d-sent )]:$( rigAsks d-sent ):$( LC_ALL=C grep -l -x -F -- 'question-ts: 1700000009.000900' "$rigPending"/*.md 2> /dev/null | LC_ALL=C grep -c . ):$( [ -e "$rigStores/d-sent/control/post.d-sent.sent" ] && echo kept || echo taken )" "[]:human-owner;:1:taken"
## A post that is not answered, under a thread: a second run of the session dies meanwhile.
rigBound 2
rigItem item-hang d-hang human-owner
rigItem item-hangc c-hang human-owner
rigStand '' ; rigHangShell="$rigStandPid"
rigRec d-hang s-hang keeper-rig spawn-started "supervisor-process: $rigGoneShell
spawns: item-hang
"
rigRec c-hang s-hang keeper-myx spawn-started "supervisor-process: $( rigProcBegan "$rigHangShell" )
spawns: item-hangc
"
mkdir -p "$rigStores/s-hang"
: > "$rigSlack/hang"
rigThread hang s-hang ; rigHang="$rigThreadPid"
rigWaitFor 20 rigHolds s-hang "$rigHang" || rigRefuse "the thread of s-hang did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/hang.err" | cut -c1-600 )"
rigWaitFor 15 rigPosting s-hang
rigJob="" ; { IFS= read -r rigJob < "$rigStores/s-hang/control/post.d-hang" ; } 2> /dev/null
rigProcSignal TERM "$rigHangShell" ; rigWaitFor 10 rigEnded "$rigHangShell"
rigWaitFor 4 rigDeadIs s-hang c-hang
rigAssert "a post that hangs does not hold the tick: the death of another run of the session is recorded within a few ticks, while the stub does not answer" \
	"$( rigDeadLines s-hang c-hang ):$( rigEnded "$rigHang" && echo ended || echo alive )" "1:alive"
rigWaitFor 15 rigLogSays s-hang 'did not end within its bound of 2 seconds'
rigAssert "a post that hangs is ended after its bound: the process that posted is no more, no record is opened, and the log of the thread says so" \
	"$( rigIsStill "$rigJob" && echo still-there || echo ended ):$( rigAsks s-hang ):$( rigLogHas s-hang 'did not end within its bound of 2 seconds' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "said" : "not-said" }' )" "ended::said"
rigHangAsked(){ [ -n "$( rigQuestions d-hang )" ] && [ -n "$( rigQuestions c-hang )" ] ; }
rm -f "$rigSlack/hang" ; rigBound 30
rigWaitFor 40 rigHangAsked
sleep 4
rigAssert "and it is tried again once the stub answers: one question for each of the two dead runs, and two open records" \
	"$( rigQuestions d-hang ):$( rigQuestions c-hang ):$( rigAsks s-hang )" "URIGOWNER - human-owner;:URIGOWNER - human-owner;:human-owner;human-owner;"

echo "-- 7. who speaks: the thread while it lives, and a death it told is told by no other --"
rigInside(){ ## lines of a script, run inside the tooling's own context in the rig workspace
	printf '%s\n' "$@" | rigCall --intern-mcp-execute 2> "$rigTmp/inside.err"
}
rigHeld="$( rigInside '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionControlDeath.include"' 'AgentsToolsSessionControlDeathHeld s-hang d-hang ; echo "rig-held=$?"' 'AgentsToolsSessionControlDeathHeld d-plain d-plain ; echo "rig-settled=$?"' | LC_ALL=C grep '^rig-' | LC_ALL=C tr '\n' ' ' )"
rigThreadEnd "$rigHang"
rigHeldAfter="$( rigInside '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionControlDeath.include"' 'AgentsToolsSessionControlDeathHeld s-hang d-hang ; echo "rig-held=$?"' | LC_ALL=C grep '^rig-' | LC_ALL=C tr '\n' ' ' )"
rigAssert "a death the thread keeps and has not settled is held by it while it lives, for the advance pass to leave alone; a settled one is not, and none is once the thread has ended" \
	"$rigHeld$rigHeldAfter" "rig-held=0 rig-settled=1 rig-held=1 "
rigBodies="$( wc -l < "$rigSlack/bodies" | LC_ALL=C tr -d ' ' )"
rigInside '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"' "AgentsToolsSpawnProxyEndNotice '$rigSp/d-hang/d-hang.md' ; AgentsToolsSpawnProxyEndNotice '$rigSp/d-ho/d-ho.md' missing" > /dev/null
rigAssert "a death the thread told is told by no other closer: the record keeps that it was told, and the one function that tells an end says nothing more of that run" \
	"$( [ -n "$( rigHeader d-hang death-told )" ] && [ -n "$( rigHeader d-ho death-told )" ] && echo marked ):$(( $( wc -l < "$rigSlack/bodies" | LC_ALL=C tr -d ' ' ) - rigBodies ))" "marked:0"
rigRec d-other d-other keeper-rig spawn-ended-without-close "${rigClosed}${rigAsked}supervisor-process: $rigGoneShell
"
rigInside '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"' "AgentsToolsSpawnProxyEndNotice '$rigSp/d-other/d-other.md' missing" > /dev/null
rigAssert "control: a run no thread told is told by that function as before, as one that posted no handback" \
	"$( rigPosts 'posted no handback' '`d-other`' | LC_ALL=C tr '\n' ';' )" "${rigReqThread%%:*} ${rigReqThread#*:} magic-coordinator;"
rigAssert "no text the thread posts is written in its code: each is a block of the note template" \
	"$( LC_ALL=C grep -c -e 'died:' -e 'What should be done' -e 'resume:' "$rigPackage/sh-lib/session/AgentsTools.SessionControlDeath.include" "$rigPackage/sh-lib/session/AgentsTools.InternSessionControl.include" 2> /dev/null | LC_ALL=C awk -F: '{ textCount += $NF } END { print textCount + 0 }' ):$( LC_ALL=C grep -c -x -e '## run-died' -e '## question' -e '## options' -e '## context' "$rigPackage/sh-lib/templates/tooling-note.post.format.md" )" "0:4"

echo ""
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL DEATH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: the control thread of a session does not tell a death from an ordinary end, or does not tell it and ask about it once" >&2
	echo "  fix:  sh-lib/session/AgentsTools.SessionControlDeath.include and the tick of sh-lib/session/AgentsTools.InternSessionControl.include -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_CONTROL_DEATH: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
