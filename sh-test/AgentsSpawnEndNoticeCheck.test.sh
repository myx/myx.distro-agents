#!/usr/bin/env bash
## Behavioural check on how the end of a run is told to whoever requested it, run rather than read: through the
## real spawn proxy on a stand-in console, the real kill of the console, a served TaskStop, the real advance lock
## take and the real return of a review. One message of the tooling for an end, a fact and no question, its words a
## block of the note template (sh-lib/templates/tooling-note.post.format.md, `# Session`), posted by the one
## function the note of a session is posted by, after the record and the item of the run are closed.
## Held:
##   1. A RUN THAT JOINED THE SESSION OF ITS PARENT and ends with no handback is told in the thread of that
##      session, addressed to the member that brought it in, as it always was.
##   2. A RUN IN A SESSION OF ITS OWN is told in the thread of the session that requested it, addressed to the member
##      that requested it, and not in its own session thread. A note that Slack refuses does not stop its close: the
##      record is closed, the item is in review, and one line of the run's log says where it was not told.
##   3. A RUN THAT HANDED BACK. One whose handback stands in the thread of the session that requested it gets no
##      second message there. One that handed back in another thread is told there as ended, in other words than
##      a missing handback. And no message says that a run posted no handback while its handback stands in that
##      thread: where the run's output shows the call as a native CLI's log shows it, the words of the call first
##      and the tool's name on the line after, the close reads no handback in that output, and the run's
##      transcript, which holds every handback that was delivered and where it went, is what is believed.
##      BY THE CLOSE TOO, through the one reading of what a run handed back (AgentsToolsSpawnProxyHandbacks): such a
##      run is not resumed for a handback it gave, and the tracking thread gets no box of a missing one. The
##      output is read only where the transcript holds no handback, or the run has no transcript.
##   4. A RUN NO SESSION REQUESTED, whose item names no reviewer, is told to the human-owner, in the bot's direct
##      conversation, as a plain message: addressed to him, no thread, no record of a question opened.
##   5. A KILLED RUN IS TOLD AS KILLED, AND BY WHOM. Killed from the console: by the name its user has in the
##      operating system, and when; one note, and none of a missing handback beside it; also where it had handed
##      back in that thread. Ended by a member's TaskStop: by that member. Ended by the tooling at the bound of a
##      start its caller waits on: by the tooling, with the bound. The control is 2: a run that ended by itself.
##   6. A DEAD RUN THE ADVANCE PASS CLOSES as ended without close is told in the thread of the session that
##      requested it, once: a second take of the lock posts nothing more. The take prints nothing of it. Not one
##      whose supervising shell still lives: that shell tells it at its own close.
##   7. A RETURN STARTS AN ENDED RUN AGAIN, in the same session, sandbox and item: one that ended with no handback
##      and was closed by its supervising shell, and one the advance pass closed.
##   8. THE WORDS ARE THE TEMPLATE'S: each block filled gives its words, and no line of code holds them.
## Red before: in 2 the place (the note stood in the run's own thread) and the line of the log; in 3 the run that
## handed back elsewhere (nothing was said) and the one whose output shows its handback as a native log does (it was
## told as one that posted no handback, under its own handback); 4 (the note stood in the run's own thread); all of 5 (a killed run was
## told as one that posted no handback, or not at all where it had handed back); the note of 6; the blocks of 8.
## And of the close: the native-shaped run was resumed once for a handback it had given, and its box said none was
## posted; the one reading did not exist.
## Offline: a fake `curl` first on PATH answers as Slack and opens no socket, each post with a ts of its own, so
## that each thread of the rig is another. A ps beside it answers the whole-host listing from the rig's own list,
## which holds no line, so a run of this rig is the process its record names, and hands every other call to the
## real ps. The console is a stand-in, never a real CLI. The board, the sandboxes and the workspace are this rig's
## own temp tree. Every signal goes to a process this rig noted with when it began, through the rig's helper.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigLib/harness/AgentsUniversalHarness.sh"
rigFixture="$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.sh"
rigNote="tooling-note.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is
## still that process; a control thread the advance pass of this rig starts is ended the same way, at the end.
. "$rigHelper" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's helper for control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnEndNoticeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigKept=""
## At the end every stand-in console still waiting is let go, so that no supervising shell of this rig waits on
## it; then what is left of this rig's own processes is ended, and the control threads its scans started.
rigLetAllGo(){
	local cleanDir cleanLaunch
	for cleanDir in "$rigTmp"/*/ ; do
		[ -e "${cleanDir}record" ] || continue
		for cleanLaunch in first retry ; do : > "${cleanDir}release-$cleanLaunch" ; done
	done 2> /dev/null
	rigProcSignalKept KILL "$rigTmp"/*/first.began "$rigTmp"/*/retry.began
	rigProcSignal KILL $rigKept
}
trap 'rigLetAllGo ; rigControlThreadsEnd "$rigTmp" ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's own list, beside
## it, which holds no line: no process of the host is ever read as a run, and a run of this rig lives by the
## process its record names. The listing of pid and ppid, and every other call, is handed to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH to hand the other calls to"
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
## The console's user, as the operating system names it: `rig` here, whoever runs this check.
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo rig ; exit 0 ; }\nexec "${0%%/*}/id.real" "$@"\n' > "$rigTmp/bin/id"
## THE RIG'S SLACK. The fixture answers every post with one ts; here each post gets a ts of its own, the second
## it was made in and the number of the process that made it, so a session of this rig that opens a thread has
## another thread than every other.
cp "$rigFixture" "$rigTmp/bin/curl.fixture" || rigRefuse "could not install the fake curl"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
"${0%/*}/curl.fixture" "$@" | sed "s/1\\.000001/$( date +%s ).$( printf '%06d' "$$" )/g"
RIGCURL
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/id" "$rigTmp/bin/curl" "$rigTmp/bin/curl.fixture"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v id )" = "$rigTmp/bin/id" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps, id and curl are not first on PATH, so this check would read the host's process list or issue a real request"
[ "$( id -un )" = "rig" ] || rigRefuse "the rig's own id does not answer as the user rig"
rigConfig(){ ## more lines of the team's settings (may be empty)
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n%s' "${1:-}" > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigConfig ""
for rigMember in rig-member-a rig-member-b magic-coordinator human-owner ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

## The stand-in console of the proxy's own runs. A launch says which record it runs under and notes itself, its
## pid and when it began: the first launch of a run as `first`, one that resumes for a missing handback as `retry`.
## It runs until its scenario lets that launch go (the file release-<launch>). Where its scenario says so (the
## file handback-<launch>, which holds the argument object of the call) it hands back before it ends, as a member
## does: the line the call leaves in the run's output, and the call itself, served by the tooling as the run's own
## member, which posts it, moves the item and writes the run's transcript. The line is the harness's own; with
## handback-as-native in its scenario it is the two lines the log of a native CLI holds for a call that says what
## it is for, the tool's name on the second.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > /dev/null' \
	'rigLaunch=first ; [ -z "${MDAT_SPAWN_RESUME:-}" ] || rigLaunch=retry' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s\n" "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.md" > "$RIG_SCENARIO/record"' \
	'printf "%s %s\n" "$rigLaunch" "$MDAT_SPAWN_SESSION_ID" >> "$RIG_SCENARIO/launches"' \
	". '$rigHelper' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/\$rigLaunch.began\" \$\$" \
	'rigLeft=120' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release-$rigLaunch" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'if [ -s "$RIG_SCENARIO/handback-$rigLaunch" ] ; then' \
	'	if [ -e "$RIG_SCENARIO/handback-as-native" ] ; then printf "  -> tool: Report the rig step back to whoever asked for it —\n       mcp__myx_distro__SubagentHandback\n" ; else printf "📦 SubagentHandback\n" ; fi' \
	"	MDAT_SPAWN_AGENT=rig-member-a bash '$rigHarness' --intern-tool SubagentHandback < \"\$RIG_SCENARIO/handback-\$rigLaunch\" > \"\$RIG_SCENARIO/handback-\$rigLaunch.out\" 2>&1" \
	'fi' \
	'echo finished > "$RIG_SCENARIO/$rigLaunch.done"' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
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
## One call of the tooling in the rig workspace: as a bare console makes it, or, with NAME=value words ahead of the
## command, as the session those words name. The hangup, the interrupt and the quit at their defaults, as a
## console has them, whatever this check itself was started with.
rigEnv(){ ## scenario folder, NAME=value words, then the command...
	local envDir="$1" envWords=()
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) envWords[${#envWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$envDir" RIG_HELPER="$rigHelper" \
		${envWords[@]+"${envWords[@]}"} \
		perl -e '$SIG{HUP} = "DEFAULT" ; $SIG{INT} = "DEFAULT" ; $SIG{QUIT} = "DEFAULT" ; exec { $ARGV[0] } @ARGV or exit 127' "$@"
}
rigRunKept(){ [ -n "$( rigHeader "$rigRecord" run-process )" ] ; }
rigRecordClosed(){ case "$( rigHeader "$rigRecord" status )" in spawn-started|'') return 1 ;; esac ; }
rigItemIn(){ ## item stem -- the board state that holds it
	local inState
	for inState in running review processed pending ; do [ ! -f "$rigData/board/$inState/$1.md" ] || { printf '%s' "$inState" ; return 0 ; } ; done
	printf 'nowhere'
}
## THE POSTS A SCENARIO'S SLACK TOOK that hold a text, but for the boxes of the tracking thread: one line each,
## `<conversation> <thread, or - for none> <whom its author line addresses>`.
rigNotes(){ ## scenario folder, fixed text
	LC_ALL=C awk -v wantText="$2" '
		index( $0, wantText ) == 0 || index( $0, "\"channel\":\"CRIGTRACK\"" ) > 0 { next ; }
		{
			noteChannel = "-" ; noteThread = "-" ; noteWhom = "-" ;
			if ( match( $0, /"channel":"[^"]*"/ ) ) { noteChannel = substr( $0, RSTART + 11, RLENGTH - 12 ) ; }
			if ( match( $0, /"thread_ts":"[^"]*"/ ) ) { noteThread = substr( $0, RSTART + 13, RLENGTH - 14 ) ; }
			arrowAt = index( $0, "→ " ) ;
			if ( arrowAt > 0 ) { noteRest = substr( $0, arrowAt + length( "→ " ) ) ; noteEnd = index( noteRest, ".\\n" ) ; if ( noteEnd > 0 ) { noteWhom = substr( noteRest, 1, noteEnd - 1 ) ; } }
			print noteChannel, noteThread, noteWhom ;
		}
	' "$1/bodies" 2> /dev/null
}
rigNoteCount(){ ## scenario folder, fixed text -- how many such posts
	rigNotes "$1" "$2" | LC_ALL=C awk 'END { print NR + 0 }'
}
## The whole text of the one such post, after its author line, as it was sent.
rigNoteText(){ ## scenario folder, fixed text
	LC_ALL=C awk -v wantText="$2" '
		index( $0, wantText ) == 0 || index( $0, "\"channel\":\"CRIGTRACK\"" ) > 0 { next ; }
		{
			textAt = index( $0, "\"text\":\"" ) ; if ( ! textAt ) { next ; }
			textRest = substr( $0, textAt + 8 ) ; textEnd = 0 ;
			textMarks[1] = "\",\"thread_ts\":" ; textMarks[2] = "\",\"blocks\":" ; textMarks[3] = "\",\"metadata\":" ;
			for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( textRest, textMarks[markNo] ) ; if ( markAt > 0 && ( textEnd == 0 || markAt < textEnd ) ) { textEnd = markAt ; } }
			if ( textEnd > 0 ) { textRest = substr( textRest, 1, textEnd - 1 ) ; }
			headEnd = index( textRest, "\\n" ) ; print ( headEnd ? substr( textRest, headEnd + 2 ) : textRest ) ; exit ;
		}
	' "$1/bodies" 2> /dev/null
}
rigRunId(){ basename "$rigRecord" .md ; }
rigShort(){ rigRunId | cut -c1-8 ; }

## THE SESSION THAT REQUESTS THE RUNS OF THIS RIG: rig-parent, of rig-member-b, with a session thread of its own.
rigParent="rig-parent-$$"
rigParentThread="CRIGPARENT:1700000000.000100"
mkdir -p "$rigSp/$rigParent"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nworkspace: ws\nowner: rig-member-b\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\nsession-thread: %s\n---\n\n# Spawn session: %s\n' \
	"$rigParent" "$rigParent" "$rigParent" "$rigHost" "$rigParentThread" "$rigParent" > "$rigSp/$rigParent/$rigParent.md"
## It runs: a stand-in process of this rig stands in the rig's process list as its run, by its own session word,
## so that the session lives for whoever measures it, the advance pass among them.
sleep 900 > /dev/null 2>&1 < /dev/null &
rigProcNote "$!" ; rigKept="$rigKept $!"
printf '%s rig-cli --session-id %s the brief\n' "$!" "$rigParent" >> "$rigTmp/ps.list"
disown "$!" 2> /dev/null || :
rigAsParent=( "MDAT_SPAWN_SESSION_ID=$rigParent" "MDAT_SPAWN_AGENT=rig-member-b" )
## Whom the author line of a post names where it is addressed to that member.
rigToB='🤖 *_rig-member-b_*'
rigJoined=( "MDAT_SESSION_ID=$rigParent" "MDAT_SESSION_THREAD=$rigParentThread" )

## Waits for the scenario's console, the launch named, and for that launch to be kept on its record; sets rigRecord,
## rigShell, what the record names as its supervising shell, rigItem, the stem of its dispatch item, and rigLog.
rigRunStarted(){ ## scenario, launch
	rigWaitFor 60 test -s "$rigDir/$2.began" || rigRefuse "the stand-in console never started in scenario $1: $( LC_ALL=C grep -h -m1 ERROR "$rigDir"/*.out 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
	rigRecord="$( head -1 "$rigDir/record" 2> /dev/null )"
	[ -n "$rigRecord" ] && [ -f "$rigRecord" ] || rigRefuse "the run of scenario $1 has no record"
	rigWaitFor 20 rigRunKept || rigRefuse "the proxy kept no process on the record of its run in scenario $1"
	rigShell="$( rigHeader "$rigRecord" supervisor-process )"
	rigItem="$( rigHeader "$rigRecord" spawns )"
	rigLog="$rigWs/.local/agents/sessions/$( rigRunId )/session.log"
}
## One run that is not waited for, on a dispatch item of its own: as the session the words name, or as a bare
## console where none is given.
rigStart(){ ## scenario, NAME=value words and options of the proxy...
	local startName="$1" startWords=() startOptions=()
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in MDAT_*=*) startWords[${#startWords[@]}]="$1" ;; *) startOptions[${#startOptions[@]}]="$1" ;; esac
		shift
	done
	rigDir="$rigTmp/$startName"
	mkdir -p "$rigDir"
	( cd "$rigWs" && rigEnv "$rigDir" ${startWords[@]+"${startWords[@]}"} bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create \
		${startOptions[@]+"${startOptions[@]}"} --context rig-end-notice <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 )
	rigRunStarted "$startName" first
}
rigEnded(){ ## -- the run of the scenario is closed, its item is in review, and its supervising shell is gone
	rigWaitFor 90 rigRecordClosed
	rigWaitFor 30 test -f "$rigData/board/review/$rigItem.md"
	rigWaitFor 60 rigHasEnded "$rigShell"
}
rigLetGo(){ : > "$rigDir/release-first" ; : > "$rigDir/release-retry" ; } ## -- the run ends by itself, and so does its one retry
rigMissing='and posted no handback. What it did is not reported in this thread.'

echo "-- 1. a run that joined the session of its parent and ends with no handback is told there --"
rigStart joined "${rigAsParent[@]}" "${rigJoined[@]}"
rigAssert "control: the run joined the session that requested it, and its record keeps that session's thread as where its parent is" \
	"$( rigHeader "$rigRecord" session-id ):$( rigHeader "$rigRecord" session-thread ):$( rigHeader "$rigRecord" parent-thread ):$( rigHeader "$rigRecord" parent-member )" "$rigParent:$rigParentThread:$rigParentThread:rig-member-b"
rigLetGo
rigEnded
rigAssert "it ends with no handback: its record is closed and its item is in review" "$( rigHeader "$rigRecord" status ):$( rigItemIn "$rigItem" )" "spawn-succeeded:review"
rigAssert "one note stands in the thread of that session, addressed to the member that brought it in" "$( rigNotes "$rigDir" "$rigMissing" )" "${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
rigAssert "its words: the member, its run, and that no handback was posted" "$( rigNoteText "$rigDir" "$rigMissing" )" "📦 rig-member-a ended its run \`$( rigShort )\` $rigMissing"

echo "-- 2. a run in a session of its own is told in the thread of the session that requested it --"
rigStart own "${rigAsParent[@]}" --session-new
rigOwnThread="$( rigHeader "$rigRecord" session-thread )"
rigAssert "control: the run opened a session of its own, with a thread of its own, and its record keeps the thread of the session that requested it" \
	"$( [ "$( rigHeader "$rigRecord" session-id )" = "$( rigRunId )" ] && printf own-session ):$( [ -n "$rigOwnThread" ] && [ "$rigOwnThread" != "$rigParentThread" ] && printf own-thread ):$( rigHeader "$rigRecord" parent-thread )" "own-session:own-thread:$rigParentThread"
rigLetGo
rigEnded
rigAssert "it ends with no handback: one note, in the thread of the requesting session, addressed to the member that requested it" "$( rigNotes "$rigDir" "$rigMissing" )" "${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
rigAssert "and none in its own session thread" "$( rigNotes "$rigDir" "$rigMissing" | LC_ALL=C grep -c -F -- " ${rigOwnThread#*:} " )" "0"
## The same, with every post refused by Slack from the moment the run ends.
rigStart own-refused "${rigAsParent[@]}" --session-new
rigNo=0 ; while [ "$rigNo" -lt 40 ] ; do echo channel_not_found ; rigNo=$(( rigNo + 1 )) ; done > "$rigDir/post-errors"
rigLetGo
rigEnded
rigAssert "a note that Slack refuses does not stop the close: the record is closed and the item is in review" "$( rigHeader "$rigRecord" status ):$( rigItemIn "$rigItem" )" "spawn-succeeded:review"
rigAssert "and one line of the run's log says that the thread of the requesting session was not told" \
	"$( LC_ALL=C grep -c -F "the handback-missing line was not posted in $rigParentThread" "$rigLog" 2> /dev/null )" "1"

echo "-- 3. a run that handed back: no second message where its handback stands, and told as ended where it stands elsewhere --"
rigStart handed-there "${rigAsParent[@]}" --session-new
printf '%s\n' '{"outcome":"the rig step is done"}' > "$rigDir/handback-first"
rigLetGo
rigEnded
rigAssert "control: its handback was posted in the thread of the session that requested it, and its item entered review by it" \
	"$( rigNotes "$rigDir" 'the rig step is done' | LC_ALL=C awk '{ print $1, $2 }' ):$( LC_ALL=C sed -n 's/^review-reason: //p' "$rigData/board/review/$rigItem.md" 2> /dev/null )" "${rigParentThread%%:*} ${rigParentThread#*:}:handback"
rigAssert "the run then ends: no note of its end is posted, there or anywhere" "$( rigNoteCount "$rigDir" 'ended its run' ):$( rigHeader "$rigRecord" status )" "0:spawn-succeeded"
rigStart handed-elsewhere "${rigAsParent[@]}" --session-new
printf '%s\n' '{"to":"session-current","outcome":"the rig step is done"}' > "$rigDir/handback-first"
rigOwnThread="$( rigHeader "$rigRecord" session-thread )"
rigLetGo
rigEnded
rigAssert "control: a run that hands back in its own session thread: its handback stands there, not in the thread of the session that requested it" \
	"$( rigNotes "$rigDir" 'the rig step is done' | LC_ALL=C awk '{ print $2 }' )" "${rigOwnThread#*:}"
rigAssert "its end is told in the thread of the session that requested it, addressed to the member that requested it" "$( rigNotes "$rigDir" 'ended its run' )" "${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
rigAssert "in words of its own: that it ended, and that its handback is in another thread" "$( rigNoteText "$rigDir" 'ended its run' )" "🏁 rig-member-a ended its run \`$( rigShort )\`. Its handback was posted in another thread, not in this one."
## As seen on a live run of a native CLI: its handback stands in the thread, and its output shows the call in a
## form no pattern reads as one. The close believes the transcript of the run, which holds that handback.
rigStart handed-native "${rigAsParent[@]}" "${rigJoined[@]}"
printf '%s\n' '{"outcome":"the rig step is done"}' > "$rigDir/handback-first"
: > "$rigDir/handback-as-native"
rigLetGo
rigEnded
rigAssert "control: a run whose handback stands in the thread of its session, while its output shows that call as a native log does: the output holds no line a pattern reads as a handback, and the close does not resume the run for one" \
	"$( rigNotes "$rigDir" 'the rig step is done' | LC_ALL=C awk '{ print $1, $2 }' ):$( LC_ALL=C grep -c -E '📦 SubagentHandback|^  -> tool: (mcp__myx_distro__)?SubagentHandback' "$rigLog" ):$( LC_ALL=C awk '{ printf "%s ", $1 }' "$rigDir/launches" )" "${rigParentThread%%:*} ${rigParentThread#*:}:0:first "
rigAssert "no message in that thread says that it posted no handback, or that it ended: its handback stands there" "$( rigNoteCount "$rigDir" 'posted no handback' ):$( rigNoteCount "$rigDir" 'ended its run' ):$( rigHeader "$rigRecord" status )" "0:0:spawn-succeeded"
rigAssert "nor does a box in the tracking thread say that none was posted" "$( LC_ALL=C grep -c -F 'none posted' "$rigDir/bodies" 2> /dev/null )" "0"
rigNativeRun="$( rigRunId )" ; rigNativeLog="$rigLog"
## THE ONE READING ITSELF (AgentsToolsSpawnProxyHandbacks): a line for each handback the transcript of a run holds, with
## where it went; the output only where the transcript holds none, or the run has no transcript.
rigRead(){ ## run, its output file -- what the one reading says of it, its lines side by side
	rigEnv "$rigTmp" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" ; AgentsToolsSpawnProxyHandbacks "$1" "$2"' rig "$1" "$2" 2> /dev/null | LC_ALL=C tr '\n' ' '
}
rigRunOf(){ basename "$( head -1 "$rigTmp/$1/record" 2> /dev/null )" .md ; } ## scenario -- the run of it
printf '📦 SubagentHandback\n' > "$rigTmp/harness-shaped.log"
printf '  -> tool: Report the rig step back to whoever asked for it —\n       mcp__myx_distro__SubagentHandback\n' > "$rigTmp/native-shaped.log"
rigAssert "the one reading, by the transcript of a run: the native-shaped run gave one handback, to where a handback goes that names no place; the one that handed back in its own thread gave one there; the one that ended with none gave none" \
	"[$( rigRead "$rigNativeRun" "$rigNativeLog" )][$( rigRead "$( rigRunOf handed-elsewhere )" "" )][$( rigRead "$( rigRunOf joined )" "$rigWs/.local/agents/sessions/$( rigRunOf joined )/session.log" )]" "[to: ][to:session-current ][]"
rigAssert "and by the output, only where the transcript holds none or the run has no transcript: seen where the output holds the harness's line of the call; nothing where it holds the two lines of a native log, which no pattern reads; nothing with no output" \
	"[$( rigRead "$( rigRunOf joined )" "$rigTmp/harness-shaped.log" )][$( rigRead "rig-no-transcript-$$" "$rigTmp/harness-shaped.log" )][$( rigRead "rig-no-transcript-$$" "$rigTmp/native-shaped.log" )][$( rigRead "rig-no-transcript-$$" "" )]" "[seen ][seen ][][]"
rigAssert "a run whose transcript holds its handback is read by it, whatever the output: the same line, with the harness's line beside it" "[$( rigRead "$rigNativeRun" "$rigTmp/harness-shaped.log" )]" "[to: ]"

echo "-- 4. a run no session requested, its item with no reviewer, is told to the human-owner as a plain message --"
rigStart unrequested --session-name-or-comment "the rig's own errand"
rigOwnThread="$( rigHeader "$rigRecord" session-thread )"
rigAssert "control: no session requested it, and its item names no reviewer" \
	"$( rigHeader "$rigRecord" parent-spawn-id ):$( rigHeader "$rigRecord" parent-thread ):$( LC_ALL=C grep -c '^review-by: ' "$rigData/board/running/$rigItem.md" 2> /dev/null )" "none::0"
rigLetGo
rigEnded
rigAssert "it ends with no handback: one message, in the bot's direct conversation with the human-owner, in no thread, addressed to him" "$( rigNotes "$rigDir" "$rigMissing" )" "URIGOWNER - 👤 *_human-owner_* <@URIGOWNER>"
rigAssert "its words: the same fact, and that no session requested the run, with the name of its session" "$( rigNoteText "$rigDir" "$rigMissing" )" \
	"📦 rig-member-a ended its run \`$( rigShort )\` $rigMissing No session requested this run, so its end is told here. Its session: the rig's own errand."
rigAssert "it is no ask: no record of a question is opened, and nothing is placed under it" "$( ls "$rigWs/.local/agents/pending" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' ):$( LC_ALL=C grep -c '^reactions.add .*' "$rigDir/calls" 2> /dev/null )" "0:1"
rigAssert "and its record is closed, its item in review" "$( rigHeader "$rigRecord" status ):$( rigItemIn "$rigItem" )" "spawn-succeeded:review"

echo "-- 4b. a run that reports to a member is told in that member's own conversation: its inbox, where it has no Slack DM --"
rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$rigLib/session/AgentsTools.SpawnSandbox.include" )"
rigToMember="rtm4b$$x"
mkdir -p "$rigSp/$rigToMember" "$rigTmp/s4b"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\n%s: rig-member-b\ntracking-name: %s\nhost: %s\nworkspace: ws\nowner: rig-member-a\nstatus: spawn-ended-without-close\nsession-thread: CRIGOWN4B:1700000004.000200\n---\n' \
	"$rigToMember" "$rigToMember" "$rigReportsTo" "$rigToMember" "$rigHost" > "$rigSp/$rigToMember/$rigToMember.md"
printf '%s\n' ". \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include\" ; AgentsToolsSpawnProxyEndNotice '$rigSp/$rigToMember/$rigToMember.md' missing ; printf 'SAID=%s\\n' \"\$agentsSpawnProxyEndNoticeSaid\"" \
	| rigEnv "$rigTmp/s4b" bash "$rigTool" --intern-mcp-execute > "$rigTmp/s4b/out" 2>&1
rigAssert "told once, in the inbox of the member it reports to, and in no conversation" \
	"$( LC_ALL=C grep -c -x 'SAID=posted' "$rigTmp/s4b/out" ):$( LC_ALL=C grep -l -F -- "${rigToMember:0:8}" "$rigData/inboxes/rig-member-b/incoming"/inquiry-*.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' ):$( rigNoteCount "$rigTmp/s4b" "${rigToMember:0:8}" )" "1:1:0"

echo "-- 4c. a run that reports to no one is told to no one --"
rigToNone="rtn4c$$x"
mkdir -p "$rigSp/$rigToNone" "$rigTmp/s4c"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\n%s: none\ntracking-name: %s\nhost: %s\nworkspace: ws\nowner: rig-member-a\nstatus: spawn-ended-without-close\nsession-thread: CRIGOWN4C:1700000004.000300\n---\n' \
	"$rigToNone" "$rigToNone" "$rigReportsTo" "$rigToNone" "$rigHost" > "$rigSp/$rigToNone/$rigToNone.md"
printf '%s\n' ". \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include\" ; AgentsToolsSpawnProxyEndNotice '$rigSp/$rigToNone/$rigToNone.md' missing ; printf 'SAID=%s\\n' \"\$agentsSpawnProxyEndNoticeSaid\"" \
	| rigEnv "$rigTmp/s4c" bash "$rigTool" --intern-mcp-execute > "$rigTmp/s4c/out" 2>&1
rigAssert "nothing said, nothing posted, nothing left in an inbox" \
	"$( LC_ALL=C grep -c -x 'SAID=none' "$rigTmp/s4c/out" ):$( rigNoteCount "$rigTmp/s4c" "${rigToNone:0:8}" ):$( LC_ALL=C grep -l -F -- "${rigToNone:0:8}" "$rigData"/inboxes/*/incoming/inquiry-*.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' )" "1:0:0"

echo "-- 5. a killed run is told as killed, and by whom --"
## One call of the console in the rig workspace, as a bare console makes it.
rigConsole(){ ## result file, tool arguments...
	local consoleOut="$1" ; shift
	( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" "$@" ) > "$consoleOut" 2> "$consoleOut.err" < /dev/null
}
## The run reports to rig-member-b, so the person at this console, user-rig, ends it by a grant
## of that authority over the run's session, opened by the owners role (F6.10).
rigConsoleGrant(){
	rigConsole "$rigDir/grant-refusal.out" --intern-op-permission-refusal-log user-rig --session-id "$( rigHeader "$rigRecord" session-id )" \
		--tool authority --target rig-member-b --reason "rig: the console ends this run"
	rigConsole "$rigDir/grant-open.out" --intern-op-permission-grant-open human-owner --session-id "$( rigHeader "$rigRecord" session-id )" \
		--refusal-id "$( LC_ALL=C grep -o -E 'refusal-[0-9a-f-]+' "$rigDir/grant-refusal.out" | head -1 )" --kind session
	LC_ALL=C grep -q '^GRANT: session ' "$rigDir/grant-open.out" || rigRefuse "the console's grant over the run's session was not written"
}
rigKilledWords='was killed from the console by rig'
rigStart killed "${rigAsParent[@]}" --session-new
rigConsoleGrant
rigConsole "$rigDir/kill.out" --manager-session-kill --session-id "$( rigRunId )" --run
rigAssert "control: the console's user kills the run, and its record holds who and when" \
	"$( LC_ALL=C awk -F'\t' '$1 == "kill" { print $5 }' "$rigDir/kill.out" ):$( rigHeader "$rigRecord" killed-by ):$( rigHeader "$rigRecord" killed-at | LC_ALL=C grep -c -x -E '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}' )" "ended:rig:1"
rigEnded
rigAssert "its supervising shell closes it as failed, and tells the thread of the session that requested it, addressed to the member that requested it" \
	"$( rigHeader "$rigRecord" status ):$( rigNotes "$rigDir" "$rigKilledWords" )" "spawn-failed:${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
rigAssert "the note says that the run was killed, and by whom, and when" \
	"$( rigNoteText "$rigDir" "$rigKilledWords" | LC_ALL=C sed -E 's/<!date\^[0-9]+\^[^|]*\|[^>]*>/WHEN/' )" "🛑 The run \`$( rigShort )\` of rig-member-a $rigKilledWords, WHEN."
rigAssert "a killed run gets one note: none of a missing handback beside it, and it was launched once" "$( rigNoteCount "$rigDir" "$rigKilledWords" ):$( rigNoteCount "$rigDir" 'posted no handback' ):$( LC_ALL=C awk 'END { print NR + 0 }' "$rigDir/launches" )" "1:0:1"
## Killed after it handed back: its handback stands in the thread of the requesting session, and it runs on.
rigStart killed-handed "${rigAsParent[@]}" --session-new
printf '%s\n' '{"outcome":"the rig step is done"}' | ( cd "$rigWs" && rigEnv "$rigDir" MDAT_SPAWN_AGENT=rig-member-a "MDAT_SPAWN_SESSION_ID=$( rigRunId )" "MDAT_SPAWN_SANDBOX_ROOT=${rigRecord%/*}" \
	bash "$rigHarness" --intern-tool SubagentHandback ) > "$rigDir/handback.out" 2>&1
printf '📦 SubagentHandback\n' >> "$rigLog"
rigAssert "control: the run handed back in the thread of the session that requested it, and still runs" \
	"$( rigNotes "$rigDir" 'the rig step is done' | LC_ALL=C awk '{ print $1, $2 }' ):$( rigIsStill "$( head -1 "$rigDir/first.began" )" && printf run-alive || printf run-gone )" "${rigParentThread%%:*} ${rigParentThread#*:}:run-alive"
rigConsoleGrant
rigConsole "$rigDir/kill.out" --manager-session-kill --session-id "$( rigRunId )" --run
rigWaitFor 90 rigRecordClosed ; rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "a killed run that had handed back is still told as killed, in that thread" "$( rigNotes "$rigDir" "$rigKilledWords" )" "${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
## Ended by a member's TaskStop: the member of the session that requested it stops it, by the served tool.
rigStart stopped "${rigAsParent[@]}" --session-new
printf '{"task_id":"%s"}\n' "$( rigRunId )" | ( cd "$rigWs" && rigEnv "$rigDir" "${rigAsParent[@]}" bash "$rigHarness" --intern-tool TaskStop ) > "$rigDir/stop.out" 2>&1
rigAssert "control: the TaskStop of rig-member-b ends the run, and the ending is recorded in its transcript under that member" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigDir/stop.out" ):$( LC_ALL=C grep -h -c -E '^[0-9TZ:-]+ ENDING .* by=rig-member-b text="taskstop: ' "$rigData"/audit/*/session-*"$( rigShort )"*.log 2> /dev/null | head -1 ):$( rigHeader "$rigRecord" killed-by )" "1:1:"
rigWaitFor 90 rigRecordClosed ; rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "it is told as stopped, and by which member, in the thread of the session that requested it; no note of a missing handback beside it" \
	"$( rigNoteText "$rigDir" 'with TaskStop' | LC_ALL=C sed -E 's/<!date\^[0-9]+\^[^|]*\|[^>]*>/WHEN/' ):$( rigNotes "$rigDir" 'with TaskStop' ):$( rigNoteCount "$rigDir" 'posted no handback' )" \
	"🛑 The run \`$( rigShort )\` of rig-member-a was stopped by rig-member-b, with TaskStop, WHEN.:${rigParentThread%%:*} ${rigParentThread#*:} $rigToB:0"
## Ended by the tooling: a start its caller waits on, with a bound of two seconds, which the run outstays.
rigConfig 'SPAWN_WAIT_TIMEOUT_SECONDS=2
'
rigDir="$rigTmp/bound"
mkdir -p "$rigDir"
: > "$rigDir/release-retry"
( cd "$rigWs" && rigEnv "$rigDir" "${rigAsParent[@]}" "${rigJoined[@]}" bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --wait --context rig-end-notice <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" ) &
rigCall=$!
rigProcNote "$rigCall" ; rigKept="$rigKept $rigCall"
rigRunStarted bound first
wait "$rigCall" 2> /dev/null
rigConfig ""
rigAssert "control: the wait of its caller reached the bound, the tooling ended the run, and its caller got the receipt of that" \
	"$( LC_ALL=C grep -c -x 'TIMEOUT_SECONDS=2' "$rigDir/proxy.out" ):$( LC_ALL=C grep -c -x 'STATUS=failed' "$rigDir/proxy.out" ):$( rigHeader "$rigRecord" status )" "1:1:spawn-failed"
rigAssert "it is told as ended by the tooling at its bound, in the thread of the session that requested it; no note of a missing handback beside it" \
	"$( rigNoteText "$rigDir" 'was ended by the tooling' ):$( rigNotes "$rigDir" 'was ended by the tooling' ):$( rigNoteCount "$rigDir" 'posted no handback' )" \
	"⏱ The run \`$( rigShort )\` of rig-member-a was ended by the tooling: it had run for its bound of 2 seconds.:${rigParentThread%%:*} ${rigParentThread#*:} $rigToB:0"

echo "-- 6. a dead run the advance pass closes is told in the thread of the session that requested it, once --"
## A run of this host that nobody closed: no process, no supervising shell, its record still started, and nothing
## of it changed for half an hour. Its session is its own; a member of rig-parent requested it.
rigDead="rig-dead-$$"
rigDeadItem="dispatch-20261013T0900Z-rigdead"
rigDir="$rigTmp/advance"
mkdir -p "$rigDir" "$rigSp/$rigDead/input" "$rigSp/$rigDead/output"
rigRecord="$rigSp/$rigDead/$rigDead.md"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nparent-session-id: %s\nparent-member: rig-member-b\nparent-thread: %s\ntracking-name: %s\nhost: %s\nworkspace: ws\nowner: rig-member-a\nstatus: spawn-started\nstarted-at: 2026-10-13 09:10 +0300\nsession-thread: CRIGDEAD:1700000001.000100\nspawns: %s\n---\n\n# Spawn session: %s\n' \
	"$rigDead" "$rigDead" "$rigParent" "$rigParent" "$rigParentThread" "$rigDead" "$rigHost" "$rigDeadItem" "$rigDead" > "$rigRecord"
printf -- '---\ntype: dispatch\nowner: rig-member-a\nstatus: dispatch-started\nsession-id: %s\nspawn-id: %s\nreview-by: %s\n---\n\n# rig dispatch\n\n## Brief\n\nRIG-BRIEF\n' "$rigDead" "$rigDead" "$rigParent" > "$rigData/board/running/$rigDeadItem.md"
rigStampText="$( rigStampEpoch=$(( $( date +%s ) - 1800 )) ; date -r "$rigStampEpoch" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$rigStampEpoch" +%Y%m%d%H%M.%S )"
find "$rigSp/$rigDead" -exec touch -t "$rigStampText" {} +
## And one more, the same but for its supervising shell, which its record names and which lives: a stand-in.
rigHeldRun="rig-held-$$"
sleep 900 > /dev/null 2>&1 < /dev/null &
rigProcNote "$!" ; rigKept="$rigKept $!"
rigHeldShell="$! $( rigBegan "$!" )"
disown "$!" 2> /dev/null || :
mkdir -p "$rigSp/$rigHeldRun"
LC_ALL=C sed -e "s/$rigDead/$rigHeldRun/g" -e "s/^spawns: .*\$/supervisor-process: $rigHeldShell/" "$rigRecord" > "$rigSp/$rigHeldRun/$rigHeldRun.md"
find "$rigSp/$rigHeldRun" -exec touch -t "$rigStampText" {} +
rigLock(){ ## result file -- the advance routine takes its lock, free, as the coordinator's session takes it: its housekeeping runs there
	rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20260809T154715Z-advance-state-and-lock.md"
	rigConsole "$1" --magic-advance-lock-acquire magic-coordinator rig-advance-pass
}
rigLock "$rigDir/scan1.out"
rigAssert "taking the lock closes its record as ended without close and takes its item to review" "$( rigHeader "$rigRecord" status ):$( rigItemIn "$rigDeadItem" )" "spawn-ended-without-close:review"
rigAssert "one note stands in the thread of the session that requested it, addressed to the member that brought it in" "$( rigNotes "$rigDir" "$rigMissing" )" "${rigParentThread%%:*} ${rigParentThread#*:} $rigToB"
rigAssert "the take of the lock prints nothing of it" "$( LC_ALL=C grep -c -F -e 'posted no handback' -e 'ended its run' "$rigDir/scan1.out" )" "0"
rigAssert "a dead run whose supervising shell still lives is closed by the pass and not told by it: that shell tells it at its own close" \
	"$( rigIsStill "$rigHeldShell" && printf shell-alive ):$( rigHeader "$rigSp/$rigHeldRun/$rigHeldRun.md" status ):$( LC_ALL=C grep -c -F "${rigHeldRun:0:8}" "$rigDir/bodies" 2> /dev/null )" "shell-alive:spawn-ended-without-close:0"
rigLock "$rigDir/scan2.out"
rigAssert "a second take of the lock posts nothing more for that run" "$( rigNoteCount "$rigDir" "$rigMissing" )" "1"

echo "-- 7. a return starts an ended run again, in the same session, sandbox and item --"
## The reviewer, the member of the session that requested the run, returns the item with corrections. The run that
## is started again is waited for, and let go: sets rigRecord and rigShell to its own.
rigReturn(){ ## scenario, item stem
	rigDir="$rigTmp/$1"
	rm -f "$rigDir/first.began" "$rigDir/release-first" "$rigDir/release-retry"
	( cd "$rigWs" && rigEnv "$rigDir" "${rigAsParent[@]}" bash "$rigTool" --member-review-return rig-member-b "$2" --message "redo the rig step" ) > "$rigDir/return.out" 2>&1 < /dev/null
	rigRunStarted "$1" first
}
rigRestarted(){ ## item stem, the run that ended, its session, its sandbox -- what the return said, where the item is, and what the record of the run started again says
	printf '%s:%s:%s:%s:%s:%s' "$( LC_ALL=C grep -c '^RETURN: restarted rig-member-a ' "$rigDir/return.out" )" "$( rigItemIn "$1" )" \
		"$( [ "$( rigRunId )" != "$2" ] && printf run-of-its-own || printf the-same-run )" "$( [ "$( rigHeader "$rigRecord" session-id )" = "$3" ] && printf same-session || printf another-session )" \
		"$( [ "${rigRecord%/*}" = "$rigSp/$4" ] && printf same-sandbox || printf another-sandbox )" "$( rigHeader "$rigRecord" spawned-by )"
}
## The run of 1: closed by its supervising shell, its item in review as ended without handback.
rigRecord="$( head -1 "$rigTmp/joined/record" )" ; rigItem="$( rigHeader "$rigRecord" spawns )"
rigOldRun="$( rigRunId )" ; rigOldItem="$rigItem" ; rigOldSandbox="$( rigHeader "$rigRecord" tracking-name )"
rigAssert "control: the item of the run of 1 is in review, its reason that the run ended without handback" "$( rigItemIn "$rigOldItem" ):$( LC_ALL=C sed -n 's/^review-reason: //p' "$rigData/board/review/$rigOldItem.md" 2> /dev/null )" "review:ended-without-handback"
rigReturn joined "$rigOldItem"
rigAssert "its reviewer returns it: the member is started again on that item, as a run of its own, in the same session and the same sandbox" \
	"$( rigRestarted "$rigOldItem" "$rigOldRun" "$rigParent" "$rigOldSandbox" )" "1:running:run-of-its-own:same-session:same-sandbox:$rigOldItem"
rigLetGo
rigWaitFor 90 rigRecordClosed ; rigWaitFor 60 rigHasEnded "$rigShell"
## The run of 6: closed by the advance pass, its item in review.
rigReturn advance "$rigDeadItem"
rigAssert "a run the advance pass closed, its record ended without close: its reviewer returns its item, and the member is started again the same way" \
	"$( rigHeader "$rigSp/$rigDead/$rigDead.md" status ):$( rigRestarted "$rigDeadItem" "$rigDead" "$rigDead" "$rigDead" )" "spawn-ended-without-close:1:running:run-of-its-own:same-session:same-sandbox:$rigDeadItem"
rigLetGo
rigWaitFor 90 rigRecordClosed ; rigWaitFor 60 rigHasEnded "$rigShell"

echo "-- 8. the words are the template's --"
## One block filled straight from its template, as the tooling fills it.
rigBlock(){ ## block `<Section>/<heading>` -- the slots come from the caller's environment
	ASKP_WANT=block ASKP_BLOCK="$1" ASKP_FORM="" LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigLib/questions/AgentsAskPostFill.awk" "$rigLib/templates/$rigNote" 2>&1
}
rigAssert "the line of a run that ended and handed back in another thread" "$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d rigBlock Session/run-ended )" \
	'🏁 keeper-rig ended its run `0a1b2c3d`. Its handback was posted in another thread, not in this one.'
rigAssert "the line of a run the console killed, with when" "$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d ASKP_F_by=rig ASKP_F_at='2026-10-13 11:20' rigBlock Session/run-killed )" \
	'🛑 The run `0a1b2c3d` of keeper-rig was killed from the console by rig, 2026-10-13 11:20.'
rigAssert "the same, where the record keeps no time" "$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d ASKP_F_by=rig rigBlock Session/run-killed )" \
	'🛑 The run `0a1b2c3d` of keeper-rig was killed from the console by rig.'
rigAssert "the line of a run a member's TaskStop ended" "$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d ASKP_F_by=magic-coordinator rigBlock Session/run-stopped )" \
	'🛑 The run `0a1b2c3d` of keeper-rig was stopped by magic-coordinator, with TaskStop.'
rigAssert "the line of a run the tooling ended at its bound" "$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d ASKP_F_seconds=3600 rigBlock Session/run-bound )" \
	'⏱ The run `0a1b2c3d` of keeper-rig was ended by the tooling: it had run for its bound of 3600 seconds.'
rigAssert "what is said of a run no session requested, with the name of its session and with none" \
	"$( ASKP_F_session='daily of Monday' rigBlock Session/unrequested )|$( rigBlock Session/unrequested )" \
	'No session requested this run, so its end is told here. Its session: daily of Monday.|No session requested this run, so its end is told here.'
rigAssert "each line of an end takes those words after its own, and stands as it was with none" \
	"$( for rigLine in handback-missing run-ended run-killed run-stopped run-bound ; do ASKP_F_member=k ASKP_F_run=r ASKP_F_by=b ASKP_F_seconds=1 ASKP_F_unrequested=UNREQUESTED rigBlock "Session/$rigLine" | LC_ALL=C grep -c ' UNREQUESTED$' | LC_ALL=C tr '\n' ' ' ; done )" "1 1 1 1 1 "
## Each text by words only it has; a comment line is no code.
rigInCode(){ ## fixed text -> how many code lines of the package hold it
	cat "$rigLib"/*/*.sh "$rigLib"/*/*.include "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- "$1" || :
}
for rigPhrase in 'posted no handback' 'Its handback was posted in another thread' 'was killed from the console' 'with TaskStop' 'was ended by the tooling' 'No session requested this run' ; do
	rigAssert "no code line holds: $rigPhrase" "$( rigInCode "$rigPhrase" )" 0
done
rigAssert "one function tells the end of a run, whoever closes it: the supervising shell in both its closes, and the advance pass" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigLib/session/AgentsTools.InternOpAgentSpawnProxy.include" | LC_ALL=C grep -c -F 'AgentsToolsSpawnProxyEndNotice "$sandboxTracking"' ):$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigLib/magic/AgentsTools.MagicAdvance.include" | LC_ALL=C grep -c -F 'AgentsToolsSpawnProxyEndNotice "$recordPath"' ):$( cat "$rigLib"/*/*.include "$rigLib"/*/*.sh | LC_ALL=C grep -c -E '^AgentsToolsSpawnProxy(EndNotice|SessionNotice)\(\)\{' )" "2:1:2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN END NOTICE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_END_NOTICE: OK (%d assertions, offline)\n' "$rigPasses"
