#!/usr/bin/env bash
## Behavioural check on what follows the question about a dead run (--intern-session-control,
## sh-lib/AgentsTools.SessionControlDeath.include), run rather than read, in the rig of AgentsSessionControlDeathCheck:
## spawn records, session stores, a board, a stand-in console, and a process list and a Slack of the rig's own.
## Held:
##   1. THE REVIEW LIMIT IS HELD while a question about a death stands open in the session of a run that waits for
##      its review (AgentsReviewWaitLeft): no limit then, whichever run died; as before with no question, with a
##      question of another session, and with a death that is not asked yet; and once the question is closed the
##      limit counts from its close.
##   2. THE ANSWER IS READ from the record of the question, at a tick: a record that any closer closed with one of
##      the options is kept on the line of the death and carried out once; with no answer nothing is done; a
##      question that was withdrawn settles the death and is not asked again. The thread of the question is read by
##      a call apart, on its period, where every typed answer is read: a reply of the one who was asked closes the
##      record; a read that hangs holds no tick.
##   3. THE ANSWER IS CARRIED OUT. `fresh` and `resume`: the record of the dead run is closed as ended without
##      close and the member is started again in the same session, sandbox and item, by the return of its item; a
##      run that cannot be resumed is started as a new process, and that is said. Nothing is started while a
##      process runs as the run it would replace. `close`: the record closed, the item processed, nothing started.
##      `kill`: every live run of the session ended, the record of the dead run closed. What was done is told once,
##      to the one who answered and to the session that requested the run, and the state is what the runs say
##      again. A start that fails is said, and the death stays unsettled.
## Red before the change: every assertion but the controls. Offline: a curl first on PATH answers as Slack and opens
## no socket; a ps beside it lists the rig's runs only; the console is a stand-in, never a real CLI. Every thread,
## call and stand-in this check starts is ended by it, through the rig's helpers.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.test.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.test.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.test.sh" || rigRefuse "the rig's helper for control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.test.sh"
rigTmp="$( mktemp -d -t AgentsSessionControlDeathAnswerCheck )" || exit 1
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
	rm -f "$rigSlack/hang" "$rigSlack/hang-read" ; : > "$rigTmp/release"
	## Every run this check started again is let go, and its supervising shell is given time to close its record,
	## so that nothing writes into the tree while it is removed.
	local cleanLeft=40 cleanRun cleanOpen
	while [ "$cleanLeft" -gt 0 ] ; do
		cleanOpen=""
		while read -r cleanRun cleanFile ; do
			[ -z "$cleanRun" ] || ! LC_ALL=C grep -q -x -F -- 'status: spawn-started' "$rigSp"/*/"$cleanRun.md" 2> /dev/null || cleanOpen="yes"
		done < "$rigTmp/launches" 2> /dev/null
		[ -n "$cleanOpen" ] || break
		sleep 0.5 ; cleanLeft=$(( cleanLeft - 1 ))
	done
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
	case "$rigArg" in https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;; esac
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
	conversations.replies)
		[ ! -e "$rigDir/hang-read" ] || exec sleep 30
		if [ -s "$rigDir/replies.json" ] ; then cat "$rigDir/replies.json" ; else printf '{"ok":true,"messages":[],"has_more":false}\n' ; fi
	;;
	*) rigKeep bodies ; printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH to hand the other calls to"
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo rig ; exit 0 ; }\nexec "${0%%/*}/id.real" "$@"\n' > "$rigTmp/bin/id"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl" "$rigTmp/bin/id"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
## The closing time of a record is four seconds here, and a tick one. The bound of a post is thirty seconds, which
## no post of this rig reaches on a loaded machine, and two where a scenario is about the bound: a post that is
## ended at its bound is tried again, and what that does is held by those scenarios, not left to the load.
rigBound(){ ## seconds
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSESSION_CONTROL_TICK_SECONDS=1\nSESSION_CONTROL_CLOSING_SECONDS=4\nSESSION_CONTROL_POST_SECONDS=%s\nSESSION_CONTROL_ANSWER_READ_SECONDS=3\n' "$1" > "$rigWs/.local/.agents/magic-team.agent.env.rig" \
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
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_TMP="$rigTmp" bash "$rigTool" "$@" )
}
rigRc=0
rigOne(){ ## session id -- one tick; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	rigCall "$rigOp" --one --session-id "$1" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigThreadPid=""
rigThread(){ ## name of its output files, session id
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
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
rigAsked="parent-session-id: s-req
parent-member: magic-coordinator
parent-thread: $rigReqThread
"

## THE STAND-IN CONSOLE of a run that is started again: it keeps the brief it was given, says which run it is, and
## waits until this check lets every run go, so the run it stands for lives by the process its record names.
printf '%s\n' '#!/bin/sh' '## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > "$RIG_TMP/brief.$MDAT_SPAWN_SESSION_ID"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s %s\n" "$MDAT_SPAWN_SESSION_ID" "${MDAT_SESSION_ID:-none}" >> "$RIG_TMP/launches"' \
	'rigLeft=240' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_TMP/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
: > "$rigTmp/launches"
rigLaunches(){ wc -l < "$rigTmp/launches" | LC_ALL=C tr -d ' ' ; }
rigItemIn(){ ## item stem -- the board state that holds it
	local inState
	for inState in running review processed pending ; do [ ! -f "$rigData/board/$inState/$1.md" ] || { printf '%s' "$inState" ; return 0 ; } ; done
	printf 'nowhere'
}
rigAskId(){ ## session id, run id -- the id of the question of that death, as its line keeps it
	rigDeadLine "$1" "$2" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sed -n 's/^asked=//p' | LC_ALL=C sed -n '1p'
}
rigAsked(){ case "$( rigAskId "$1" "$2" )" in ''|none) return 1 ;; esac ; } ## session id, run id
## A death staged and asked: the run, dead from the start, with its item; ticks until its question is asked.
rigDeath(){ ## run id, session id, member, review-by, more frontmatter lines of its record (may be empty)
	rigItem "item-$1" "$1" "$4"
	rigRec "$1" "$2" "$3" spawn-started "supervisor-process: $rigGoneShell
spawns: item-$1
${5:-}"
	rigOne "$2" ; rigSettle "$2"
	rigAsked "$2" "$1" || { rigOne "$2" ; rigSettle "$2" ; }
	rigAsked "$2" "$1" || rigRefuse "the death of $1 was not asked, so nothing below would be measured: $( rigDeadLine "$2" "$1" )"
}
## The record of the question of a death closed with a verdict, as another closer closes one: through the close
## operation of the pending store.
rigAnswer(){ ## session id, run id, verdict
	rigCall --intern-op-pending-reply-close "$( rigAskId "$1" "$2" )" --if-open --status reply-received --verdict "$3" --answered-by URIGOWNER --context rig-answer > "$rigTmp/answer.out" 2>&1 < /dev/null
}
## The ticks that take an answer and carry it out, until the line of the death says what became of it: settled, or
## not carried out. A restart starts the control thread of its session, as the spawner does for every session:
## from then on that thread makes the ticks, and a tick of this check is refused by its lock, which changes nothing.
rigCarry(){ ## session id, run id
	local carryLeft=60
	while [ "$carryLeft" -gt 0 ] ; do
		case " $( rigDeadLine "$1" "$2" ) " in *" settled="*|*" failed="*) return 0 ;; esac
		rigOne "$1" ; rigWaitFor 30 rigIdle "$1" ; sleep 0.5
		carryLeft=$(( carryLeft - 1 ))
	done
	return 1
}
rigLines(){ ## fixed text, run id -- the posts that hold both: `<conversation> <thread> <whom>`, a `;` after each
	rigPosts "$1" "\`$2\`" | LC_ALL=C awk '{ print $1, ( $2 == "-" ? "-" : "thread" ), $3 }' | LC_ALL=C tr '\n' ';'
}
rigInside(){ ## lines of a script, run inside the tooling's own context in the rig workspace
	printf '%s\n' "$@" | rigCall --intern-mcp-execute 2> "$rigTmp/inside.err"
}

echo "-- 1. the review limit is held while a question about a death stands open --"
rigNowEpoch="$( date +%s )"
rigWaiter(){ ## run id, session id, seconds its item has been in review
	rigRec "$1" "$2" keeper-myx spawn-started "spawns: item-$1
"
	printf -- '---\nstatus: dispatch-started\nspawn-id: %s\nreview-by: human-owner\nreview-since-epoch: %s\n---\n\n# the rig task of %s\n' "$1" "$(( rigNowEpoch - $3 ))" "$1" > "$rigData/board/review/item-$1.md"
}
rigQuestion(){ ## session id, run id of the death, pending id, status, resolved seconds ago (may be empty) -- a line of control/dead that names a question, and its record
	mkdir -p "$rigStores/$1/control" "$rigPending"
	printf '%s member=keeper-rig role=participant found=2026-10-13T06:00:00Z told=none asked=%s\n' "$2" "$3" >> "$rigStores/$1/control/dead"
	printf -- '---\nstatus: %s\nowner: keeper-rig\nkind: decision\nsession-id: %s\n%s---\n\n# Question asked\n\nrig\n' "$4" "$1" "${5:+resolved-epoch: $(( rigNowEpoch - $5 ))
}" > "$rigPending/$3.md"
}
rigLeft(){ ## run id -- what the review limit gives its Wait: `<rc>:<what it printed>`
	rigInside '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ReviewFlow.include"' "rigOut=\"\$( AgentsReviewWaitLeft $1 )\" ; echo \"rig-left=\$?:\$rigOut\"" | LC_ALL=C sed -n 's/^rig-left=//p'
}
rigWaiter w-open h-open 7200 ; rigQuestion h-open x-open rig-q-open reply-pending
rigAssert "a participant two hours in review, while a question about the death of another run of its session stands open: no limit is given, so its Wait is not bounded and nobody is dismissed" "$( rigLeft w-open )" "1:"
rigWaiter w-none h-none 7200
rigAssert "with no question in its session the limit is as before: expired after two hours" "$( rigLeft w-none )" "0:expired"
rigWaiter w-other h-other 7200
rigAssert "a question of another session holds nothing" "$( rigLeft w-other )" "0:expired"
rigWaiter w-unasked h-unasked 7200 ; mkdir -p "$rigStores/h-unasked/control"
printf 'x-unasked member=keeper-rig role=participant found=2026-10-13T06:00:00Z\n' > "$rigStores/h-unasked/control/dead"
rigAssert "a death that is not asked yet holds nothing" "$( rigLeft w-unasked )" "0:expired"
rigWaiter w-closed h-closed 7200 ; rigQuestion h-closed x-closed rig-q-closed reply-received 600
rigClosedLeft="$( rigLeft w-closed )"
rigAssert "once the question is closed the limit counts from its close: closed ten minutes ago, fifty minutes are left" \
	"${rigClosedLeft%%:*}:$( [ "${rigClosedLeft#*:}" -ge 2940 ] 2> /dev/null && [ "${rigClosedLeft#*:}" -le 3000 ] 2> /dev/null && echo fifty-minutes || echo "${rigClosedLeft#*:}" )" "0:fifty-minutes"
rigWaiter w-old h-old 7200 ; rigQuestion h-old x-old rig-q-old reply-received 4000
rigAssert "a question closed longer ago than the limit dismisses as before" "$( rigLeft w-old )" "0:expired"

echo "-- 2. the answer is read from the record of the question, and the thread of the question on its period --"
rigDeath d-wait d-wait keeper-rig human-owner
rigOne d-wait ; rigSettle d-wait ; rigOne d-wait ; rigSettle d-wait
rigAssert "with no reply nothing is done: the record is open, the line holds no answer, the read of its thread was made, and no run was started or ended" \
	"$( rigAsks d-wait ):$( rigDeadLine d-wait d-wait | LC_ALL=C grep -c -F -- 'answer=' ):$( LC_ALL=C grep -c '^conversations.replies ' "$rigSlack/calls" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "read" : "not-read" }' ):$( rigLaunches ):$( rigHeader d-wait status )" "human-owner;:0:read:0:spawn-started"
## A reply of the one who was asked, in the thread of the question: read by the call apart, where every answer is read.
rigWaitTs="$( LC_ALL=C sed -n 's/^question-ts: //p' "$rigPending/$( rigAskId d-wait d-wait ).md" )"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the question"},{"ts":"%s","user":"URIGOWNER","text":"close"}],"has_more":false}\n' "$rigWaitTs" "$(( ${rigWaitTs%%.*} + 5 )).000001" > "$rigSlack/replies.json"
rigOne d-wait ; rigSettle d-wait
rm -f "$rigSlack/replies.json"
rigCarry d-wait d-wait
rigAssert "a reply of the one who was asked, by the first word of an option, closes the record with that option, and the line of the death holds it and what was done" \
	"$( LC_ALL=C sed -n 's/^verdict: //p' "$rigPending/$( rigAskId d-wait d-wait ).md" ):$( rigDeadLine d-wait d-wait | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e 'answer=close' -e 'how=close' ):$( rigHeader d-wait status ):$( rigItemIn item-d-wait )" "close:2:spawn-ended-without-close:processed"
## A question that was withdrawn.
rigDeath d-wdrn d-wdrn keeper-rig human-owner
rigCall --intern-op-pending-reply-close "$( rigAskId d-wdrn d-wdrn )" --if-open --status withdrawn --withdrawn-by magic-coordinator --withdraw-reason "the rig takes it back" --no-decision --context rig > /dev/null 2>&1 < /dev/null
rigCarry d-wdrn d-wdrn
rigAssert "a question that was withdrawn is not asked again: the line says so and the death is settled, one question was posted, and nothing was started" \
	"$( rigDeadLine d-wdrn d-wdrn | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F -- 'how=withdrawn' ):$( rigQuestions d-wdrn ):$( rigLaunches )" "1:URIGOWNER - human-owner;:0"
## The read of the thread, under a thread: on its period, and a read that hangs holds no tick.
rigItem item-d-rdb d-rdb human-owner
rigStand '' ; rigRdShell="$rigStandPid"
rigDeath d-rd s-rd keeper-rig human-owner
rigRec d-rdb s-rd keeper-myx spawn-started "supervisor-process: $( rigProcBegan "$rigRdShell" )
spawns: item-d-rdb
"
rigReadsFrom="$( LC_ALL=C grep -c '^conversations.replies ' "$rigSlack/calls" )"
: > "$rigSlack/hang-read"
rigThread rd s-rd ; rigRd="$rigThreadPid"
rigWaitFor 20 rigHolds s-rd "$rigRd" || rigRefuse "the thread of s-rd did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/rd.err" | cut -c1-600 )"
rigWaitFor 15 rigPosting s-rd
rigProcSignal TERM "$rigRdShell" ; rigWaitFor 10 rigEnded "$rigRdShell"
rigWaitFor 5 rigDeadIs s-rd d-rdb
rigAssert "a read that hangs does not hold the tick: the death of another run of the session is recorded within a few ticks, while the stub does not answer the read" \
	"$( rigDeadLines s-rd d-rdb ):$( rigEnded "$rigRd" && echo ended || echo alive )" "1:alive"
rm -f "$rigSlack/hang-read"
sleep 9
rigReads=$(( $( LC_ALL=C grep -c '^conversations.replies ' "$rigSlack/calls" ) - rigReadsFrom ))
rigThreadEnd "$rigRd"
rigAssert "the thread of an open question is read on its period, three seconds here, and not at every tick: a few reads in some fifteen seconds of ticks every second" \
	"$( [ "$rigReads" -ge 2 ] && [ "$rigReads" -le 12 ] && echo on-its-period || echo "$rigReads" )" "on-its-period"

echo "-- 3. the answer is carried out --"
## fresh: a participant of the session of the member that requested it.
rigDeath d-fresh s-req keeper-rig human-owner "${rigAsked}session-thread: $rigReqThread
"
rigAnswer s-req d-fresh fresh ; rigCarry s-req d-fresh
rigFreshNew="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/running/item-d-fresh.md" 2> /dev/null | LC_ALL=C sed -n '1p' )"
rigAssert "fresh starts a new process on the same brief: the record of the dead run is closed as ended without close, its item is back in running under a new run of the same session, and the console was started once, with no resume" \
	"$( rigHeader d-fresh status ):$( rigItemIn item-d-fresh ):$( [ -n "$rigFreshNew" ] && [ "$rigFreshNew" != "d-fresh" ] && echo new-run ):$( LC_ALL=C grep -c -x -F -- "$rigFreshNew s-req" "$rigTmp/launches" ):$( LC_ALL=C grep -c -F -- 'restart: new-process (a fresh start was asked for)' "$rigData/board/running/item-d-fresh.md" )" "spawn-ended-without-close:running:new-run:1:1"
rigAssert "the member that is started again is told why, in its brief, and what was done is told once to the one who answered, in the thread of the question, and once to the session that requested the run" \
	"$( LC_ALL=C grep -c -F -- 'Your run died, and human-owner answered `fresh`' "$rigTmp/brief.$rigFreshNew" 2> /dev/null | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "told" : "not-told" }' ):$( rigLines 'from its brief, with no context. human-owner answered `fresh`' d-fresh )" "told:DRIG00001 thread human-owner;${rigReqThread%%:*} thread magic-coordinator;"
rigFreshLaunches="$( rigLaunches )"
rigTen=0
while [ "$rigTen" -lt 6 ] ; do rigOne s-req ; sleep 1 ; rigTen=$(( rigTen + 1 )) ; done
rigWaitFor 20 rigStateIs s-req running
rigAssert "an answer is carried out once, the death is settled, and the session reads running again" \
	"$(( $( rigLaunches ) - rigFreshLaunches )):$( rigDeadLine s-req d-fresh | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F -- 'how=fresh' ):$( rigState s-req )" "0:1:running"
## resume, of a run that cannot be resumed: the executor of a session of its own.
rigDeath d-res d-res keeper-rig human-owner "session-thread: CRIGSESS3:1700000003.000100
"
rigAnswer d-res d-res resume ; rigCarry d-res d-res
rigWaitFor 20 rigStateIs d-res running
rigResNew="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/running/item-d-res.md" 2> /dev/null | LC_ALL=C sed -n '1p' )"
rigAssert "a run that cannot be resumed is started as a new process, and the thread of the question says so; the restart of the executor keeps the session: a run of its own id, in the old session, and the session reads running" \
	"$( rigLines 'as a new process from its brief: its context could not be resumed' d-res ):$( [ -n "$rigResNew" ] && [ "$rigResNew" != "d-res" ] && echo new-run ):$( LC_ALL=C grep -c -x -F -- "$rigResNew d-res" "$rigTmp/launches" ):$( LC_ALL=C sed -n 's/^session-id: //p' "$rigSp"/*/"$rigResNew.md" 2> /dev/null | LC_ALL=C sed -n '1p' ):$( rigState d-res )" "DRIG00001 thread human-owner;:new-run:1:d-res:running"
## Never twice at once: a process runs as the run that would be replaced.
rigDeath d-twice d-twice keeper-rig human-owner
rigStand d-twice ; rigTwice="$rigStandPid"
rigTwiceLaunches="$( rigLaunches )"
rigAnswer d-twice d-twice fresh ; rigCarry d-twice d-twice
rigAssert "nothing is started while a process still runs as the run it would replace: no launch, the answer is said not to be carried out, with why, the death stays unsettled, and its record open" \
	"$(( $( rigLaunches ) - rigTwiceLaunches )):$( rigLines 'was not carried out: a process still runs as the run it would replace' d-twice ):$( rigDeadSettled d-twice d-twice && echo settled || echo unsettled ):$( rigHeader d-twice status )" "0:DRIG00001 thread human-owner;:unsettled:spawn-started"
rigProcSignal TERM "$rigTwice"
## A start that fails: the console of the rig is gone.
rigDeath d-fail d-fail keeper-rig human-owner
mv "$rigWs/DistroAgentsConsole.sh" "$rigTmp/console.kept"
rigAnswer d-fail d-fail fresh ; rigCarry d-fail d-fail ; rigOne d-fail ; rigSettle d-fail ; rigOne d-fail
mv "$rigTmp/console.kept" "$rigWs/DistroAgentsConsole.sh"
rigAssert "a restart that fails is said once, to the one who answered, the line of the death is not settled, and the state still reads member-dead" \
	"$( rigLines 'was not carried out' d-fail ):$( rigDeadSettled d-fail d-fail && echo settled || echo unsettled ):$( rigDeadLine d-fail d-fail | LC_ALL=C grep -c -F -- ' failed=' ):$( rigState d-fail )" "DRIG00001 thread human-owner;:unsettled:1:member-dead"
## close, with a participant alive, and on the last run of a session.
rigRec c-live c-sess keeper-myx spawn-started '' ; rigStand c-live
mkdir -p "$rigStores/c-sess"
rigDeath d-close c-sess keeper-rig human-owner
rigCloseLaunches="$( rigLaunches )"
rigAnswer c-sess d-close close ; rigCarry c-sess d-close ; rigOne c-sess ; rigWaitFor 10 rigStateIs c-sess running
rigAssert "close takes the end as final: the record of the dead run is closed as ended without close, its item is processed, no run is started, it is said once, and the session reads running again" \
	"$( rigHeader d-close status ):$( rigItemIn item-d-close ):$(( $( rigLaunches ) - rigCloseLaunches )):$( rigLines 'that died stays ended: its record is closed' d-close ):$( rigState c-sess )" "spawn-ended-without-close:processed:0:DRIG00001 thread human-owner;:running"
rigDeath d-last d-last keeper-rig human-owner
rigAnswer d-last d-last close ; rigCarry d-last d-last ; rigOne d-last ; rigWaitFor 10 rigStateIs d-last finished
rigAssert "close on the last run of a session ends it: its record is closed, its item is processed, and the state reads finished" \
	"$( rigHeader d-last status ):$( rigItemIn item-d-last ):$( rigState d-last )" "spawn-ended-without-close:processed:finished"
## The fourth answer, which ends the session: the executor is dead, two participants live. Its word is the note
## template's own, the first word of the fourth line of the options of the question.
rigFourth="$( LC_ALL=C awk '$0 == "## options" { inBlock = 1 ; next } inBlock && substr( $0, 1, 3 ) == "```" { if ( ++fenceCount == 2 ) { exit } next } inBlock && fenceCount == 1 { if ( ++optionCount == 4 ) { sub( /:.*$/, "" ) ; print ; exit } }' "$rigPackage/sh-lib/templates/tooling-note.post.format.md" )"
[ -n "$rigFourth" ] || rigRefuse "the fourth option of the question could not be read from the note template"
rigRec k-one d-kill keeper-myx spawn-started '' ; rigStand k-one ; rigKOne="$rigStandPid"
rigRec k-two d-kill keeper-myx spawn-started '' ; rigStand k-two ; rigKTwo="$rigStandPid"
rigDeath d-kill d-kill keeper-rig human-owner
rigAnswer d-kill d-kill "$rigFourth" ; rigCarry d-kill d-kill
rigWaitFor 10 rigEnded "$rigKOne" ; rigWaitFor 10 rigEnded "$rigKTwo"
rigAssert "the answer that ends the session ends every live run of it: both processes are gone, their records say who killed them, the record of the dead run is closed, it is said once, and the death is settled" \
	"$( rigEnded "$rigKOne" && rigEnded "$rigKTwo" && echo both-gone ):$( LC_ALL=C grep -l -x -F -- 'killed-by: rig' "$rigSp/k-one/k-one.md" "$rigSp/k-two/k-two.md" 2> /dev/null | LC_ALL=C grep -c . ):$( rigHeader d-kill status ):$( rigLines 'what still lived of it was killed' d-kill ):$( rigDeadLine d-kill d-kill | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F -- "how=$rigFourth" )" "both-gone:2:spawn-ended-without-close:DRIG00001 thread human-owner;:1"
rigAssert "every post of the rig was made as the team bot, and none under another account" \
	"$( LC_ALL=C awk '$1 == "chat.postMessage" && $2 != "rig-bot-token-TEAM" { otherCount++ } END { print otherCount + 0 }' "$rigSlack/calls" )" "0"

echo ""
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL DEATH ANSWER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: the review limit runs while a question about a death is open, or its answer is not read, or not carried out once" >&2
	echo "  fix:  sh-lib/AgentsTools.SessionControlDeath.include, AgentsReviewWaitLeft of sh-lib/AgentsTools.ReviewFlow.include, and the step of a death in sh-lib/AgentsTools.InternSessionControl.include -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_CONTROL_DEATH_ANSWER: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
