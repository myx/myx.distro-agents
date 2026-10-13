#!/usr/bin/env bash
## Behavioural check on the working directory of a wait ($MMDAPP/.local/temp/mdat-member-wait.<member>.XXXXXX,
## sh-lib/AgentsTools.MemberWait.include) and on the sweep of the ones a killed wait left behind. A wait keeps its
## baselines and renderings there, so a wait whose directory is taken from under it reads nothing any more: every
## probe then ends on "No such file or directory", round after round, and the member hears nothing. Held here:
##   1. SEVERAL WAITS OF ONE MEMBER AT ONCE, two and then four, each of its own session on its own thread of the
##      Slack stand-in, each started while the earlier ones stand in their rounds: all their directories stand at
##      once, each wait ends on its own arrival and on no other, none says "No such file", and each removes its
##      own directory as it ends. Once with the find of this host and once with a find that rounds an age up to
##      whole days, as a BSD find does: to that one a directory two seconds old is a day old.
##   2. A LIVE WAIT WHOSE DIRECTORY LOOKS OLD: a wait rewrites its files in place, so its directory keeps the
##      modification time of its first round for as long as it stands. Set years back here, it is still the
##      directory of a wait that lives, and the next wait of that member leaves it alone. This is the case every
##      find takes for stale, whichever way it rounds.
##   3. THE SWEEP, on directories made by hand: one whose owner is no process any more goes, however new; one
##      whose owner's pid another process has (it began at another time) goes; one whose owner lives stays,
##      however old; one of another host stays; one with no whole record stays while new and goes once a day
##      old; one of another member is not this member's to sweep.
##   4. A mktemp THAT FAILS, and one that names what is no directory: the wait ends at once on one error line
##      that says why, reads nothing and leaves nothing behind.
##   5. A WAIT WHOSE DIRECTORY IS TAKEN FROM UNDER IT ends at once: ERROR and one line that names the directory,
##      long before its bound, and not on a missing file round after round.
##   6. A FILE A STEP WROTE THAT IS NOT THERE WHEN THE NEXT STEP READS IT, the directory still standing: the render
##      of the settle pass, as in the live case this was written after (`settle.1.rendered: No such file or
##      directory`, then `awk: can't open file .../now.1`), and the rendering of a round, which was returned as
##      RECEIVED with nothing in it. The wait ends at once on ERROR and one line that names the file, and keeps
##      its directory, with `kept`, which the sweep leaves for its day whoever owned it.
## When a process began is read by the tooling's own reading (AgentsToolsRegistryProcessStart) and by no second one.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only is beside it, and
## every scenario runs in its own workspace under this check's temp tree, in $MMDAPP/.local/temp. No process is
## signalled: every wait here is bounded and ends by itself.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigBound="${RIG_WAIT_BOUND:-90}"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTools"
[ -f "$rigHere/AgentsTools.Registries.include" ] || rigRefuse "the include that reads when a process began is missing from the package"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the wait would have no identity to read under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitFolderCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/bin-roundup" "$rigTmp/bin-nomktemp" "$rigTmp/bin-badmktemp" "$rigTmp/bin-loseawk" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the
## rig's own list, and hands every other call to the real ps, so no process of this host is
## taken for a run of the rig's. A process asked for by its pid is the real one.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
## A FIND THAT ROUNDS AN AGE UP TO WHOLE DAYS, as a BSD find does: the find of this host, asked to. Where the
## find of the host cannot (a GNU find rounds down and has no other way), the scenario runs with it all the same.
RIG_FIND_REAL="$( command -v find )" || rigRefuse "no find on PATH"
RIG_MKTEMP_REAL="$( command -v mktemp )" || rigRefuse "no mktemp on PATH"
RIG_AWK_REAL="$( command -v awk )" || rigRefuse "no awk on PATH"
export RIG_FIND_REAL RIG_MKTEMP_REAL RIG_AWK_REAL
printf '%s\n' '#!/bin/sh' 'COMMAND_MODE=legacy exec "$RIG_FIND_REAL" "$@"' > "$rigTmp/bin-roundup/find"
printf '%s\n' '#!/bin/sh' 'case "$*" in *mdat-member-wait.*) echo "mktemp: the rig refuses this directory" >&2 ; exit 1 ;; esac' 'exec "$RIG_MKTEMP_REAL" "$@"' > "$rigTmp/bin-nomktemp/mktemp"
printf '%s\n' '#!/bin/sh' 'case "$*" in *mdat-member-wait.*) echo "$RIG_SCENARIO/ws/.local/temp/mdat-member-wait.never-made" ; exit 0 ;; esac' 'exec "$RIG_MKTEMP_REAL" "$@"' > "$rigTmp/bin-badmktemp/mktemp"
chmod +x "$rigTmp/bin-roundup/find" "$rigTmp/bin-nomktemp/mktemp" "$rigTmp/bin-badmktemp/mktemp"
## AN AWK THAT TAKES AWAY WHAT IT JUST WROTE, where the scenario asks for it: the render of a settle pass
## (lose-settle-rendered) or the rendering of a round (lose-now). The file is gone the moment it is written and
## the directory stands, so what the next step of the wait reads is not there.
cat > "$rigTmp/bin-loseawk/awk" <<'RIGAWK'
#!/bin/sh
"$RIG_AWK_REAL" "$@"
rigAwkRc=$?
case "$*" in
	*AgentsSlackMessagesFormat.awk*) [ ! -f "$RIG_SCENARIO/lose-settle-rendered" ] || rm -f "$RIG_SCENARIO"/ws/.local/temp/mdat-member-wait.*/settle.*.rendered ;;
	*AgentsSlackThreadAnswers.awk*) [ ! -f "$RIG_SCENARIO/lose-now" ] || rm -f "$RIG_SCENARIO"/ws/.local/temp/mdat-member-wait.*/now.[0-9] ;;
esac
exit "$rigAwkRc"
RIGAWK
chmod +x "$rigTmp/bin-loseawk/awk"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

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
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigCount(){ ## file, extended pattern -> how many lines of the file hold it
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk -v wantPattern="$2" '$0 ~ wantPattern { hitCount++ ; } END { print hitCount + 0 ; }' "$1"
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/.local/temp" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The thread of one wait as conversations.replies returns it: the member's own first message, then what came.
rigThread(){ ## the wait's number, later messages (may be empty)
	printf '{"ok":true,"messages":[{"ts":"1700000001.000%s01","user":"URIGSELF1","text":"first"}%s],"has_more":false}\n' \
		"$1" "$2" > "$rigScenarioDir/replies.1700000001.000${1}01.json.next" && mv -f "$rigScenarioDir/replies.1700000001.000${1}01.json.next" "$rigScenarioDir/replies.1700000001.000${1}01.json"
}
rigAnswer(){ ## the wait's number -- somebody else writes into its thread
	rigThread "$1" "$( printf ',{"ts":"1700000001.000%s02","user":"URIGOTHER","text":"ANSWER-%s-HERE","thread_ts":"1700000001.000%s01"}' "$1" "$1" "$1" )"
}
## One wait of the member, in the background: of its own session, on its own thread, bounded.
rigWaitPid=()
rigWaitRc=()
rigWait(){ ## the wait's number, a directory to put first on PATH (may be empty)
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		PATH="${2:+$2:}$PATH" TMPDIR="$rigTmp/tmp" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		bash "$rigTools" --member-wait-for-input "$rigMember" --wait-default --wait-session-id "rig-waitfolder-$rigScenarioName-$1" \
			--wait-source "slack:CRIG00001:1700000001.000${1}01:conversation" --wait-since-utime "1700000001.000${1}01" --wait-timeout "$rigBound" --wait-poll-interval 1 ) \
		> "$rigScenarioDir/wait.$1.out" 2> "$rigScenarioDir/wait.$1.err" &
	rigWaitPid[$1]=$!
}
## One short wait of the member, of no session, on a file that holds something already: it sweeps on its way in
## and returns at once.
rigQuickWait(){
	printf 'RIG-PRESENT\n' > "$rigScenarioDir/drop.txt"
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		TMPDIR="$rigTmp/tmp" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_WAIT_REMIND=off \
		bash "$rigTools" --member-wait-for-input "$rigMember" --wait-source "file:$rigScenarioDir/drop.txt" --wait-since-utime 1 --wait-timeout 30 ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
}
rigWaitEnd(){ ## the wait's number
	rigWaitRc[$1]=0
	wait "${rigWaitPid[$1]}" 2>/dev/null || rigWaitRc[$1]=$?
}
## What one wait ended on: its status, its outcome, whether it holds its own arrival, how many arrivals of
## other waits it holds, and how many of its lines say a file of its directory was not there.
rigWaitSays(){ ## the wait's number
	printf '%s:%s:%s:%s:%s' "${rigWaitRc[$1]}" "$( rigFirstLine "$rigScenarioDir/wait.$1.out" )" \
		"$( rigCount "$rigScenarioDir/wait.$1.out" "ANSWER-$1-HERE" )" \
		"$(( $( rigCount "$rigScenarioDir/wait.$1.out" 'ANSWER-[0-9]-HERE' ) - $( rigCount "$rigScenarioDir/wait.$1.out" "ANSWER-$1-HERE" ) ))" \
		"$(( $( rigCount "$rigScenarioDir/wait.$1.err" 'No such file|can.t open file' ) + $( rigCount "$rigScenarioDir/wait.$1.out" 'No such file|can.t open file' ) ))"
}
rigFolders(){ ## the working directories of the member that stand in the scenario's workspace, a line each
	local folderDir
	for folderDir in "$rigScenarioDir/ws/.local/temp/mdat-member-wait.$rigMember."* ; do
		[ ! -d "$folderDir" ] || printf '%s\n' "$folderDir"
	done
}
rigFolderCount(){
	rigFolders | LC_ALL=C awk 'END { print NR + 0 ; }'
}
## The directory a wait just started made: the one that was not there before, once its first round stands in
## it. By then that wait is past its sweep.
rigFolderOfNew(){ ## the directories that stood before, a line each
	local newLeft=60 newDir
	while [ "$newLeft" -gt 0 ] ; do
		for newDir in "$rigScenarioDir/ws/.local/temp/mdat-member-wait.$rigMember."* ; do
			[ -d "$newDir" ] || continue
			case $'\n'"$1"$'\n' in *$'\n'"$newDir"$'\n'*) continue ;; esac
			[ -f "$newDir/base.1" ] && [ -f "$newDir/now.1" ] || continue
			printf '%s' "$newDir"
			return 0
		done
		sleep 1
		newLeft=$(( newLeft - 1 ))
	done
	return 1
}
## The modification time of a path, in epoch seconds, whichever stat this host has.
rigModified(){ ## path
	stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf '0'
}
rigIsDir(){ ## path
	[ -d "$1" ] && printf 'stands' || printf 'gone'
}

## Several waits of the member at once: each started while the earlier ones stand in their rounds, at least two
## seconds after the one before, so that each later one sweeps on its way in past directories that have an age.
rigAtOnce(){ ## scenario name, how many, a directory to put first on PATH (may be empty), what it is called in a line
	local onceAt onceBefore onceStanding
	rigStart "$1"
	onceAt=0
	while [ "$onceAt" -lt "$2" ] ; do
		onceAt=$(( onceAt + 1 ))
		rigThread "$onceAt" ""
		onceBefore="$( rigFolders )"
		rigWait "$onceAt" "$3"
		rigFolderOfNew "$onceBefore" > /dev/null || :
		sleep 2
	done
	onceStanding="$( rigFolderCount )"
	onceAt=0
	while [ "$onceAt" -lt "$2" ] ; do onceAt=$(( onceAt + 1 )) ; rigAnswer "$onceAt" ; done
	onceAt=0
	while [ "$onceAt" -lt "$2" ] ; do onceAt=$(( onceAt + 1 )) ; rigWaitEnd "$onceAt" ; done
	rigAssert "$4, $2 waits of one member at once: a directory of each stands while they wait" "$onceStanding" "$2"
	onceAt=0
	while [ "$onceAt" -lt "$2" ] ; do
		onceAt=$(( onceAt + 1 ))
		rigAssert "$4, $2 waits of one member at once: wait $onceAt ends on its own arrival, on no other, and no file of its directory was missing" "$( rigWaitSays "$onceAt" )" "0:WAIT-RESULT: RECEIVED:1:0:0"
	done
	rigAssert "$4, $2 waits of one member at once: each removed its own directory as it ended" "$( rigFolderCount )" 0
}

echo "-- two and four waits of one member at once, with the find of this host --"
rigAtOnce two-host 2 "" "the find of this host"
rigAtOnce four-host 4 "" "the find of this host"

echo "-- the same with a find that rounds an age up to whole days --"
mkdir -p "$rigTmp/roundup-probe/aged" && sleep 2
if [ -n "$( "$rigTmp/bin-roundup/find" "$rigTmp/roundup-probe" -maxdepth 1 -type d -name aged -mtime +0 2>/dev/null )" ] ; then
	echo "# the rig's rounding find takes a directory two seconds old for a day old, as a BSD find does"
else
	echo "# the find of this host cannot be made to round an age up: the scenario runs with it as it is"
fi
rigAtOnce two-roundup 2 "$rigTmp/bin-roundup" "a find that rounds up"
rigAtOnce four-roundup 4 "$rigTmp/bin-roundup" "a find that rounds up"

echo "-- a live wait whose directory looks years old is left alone by the next wait of that member --"
rigStart old-live
rigThread 1 ""
rigThread 2 ""
rigWait 1 ""
rigOldDir="$( rigFolderOfNew "" )" || rigOldDir="$rigScenarioDir/no-directory-of-wait-1"
sleep 2
touch -t 202001010000 "$rigOldDir" 2>/dev/null
rigAssert "the directory of the first wait is set years back while that wait stands" "$( [ $(( $( date +%s ) - $( rigModified "$rigOldDir" ) )) -gt 172800 ] && printf 'years-old' || printf 'not-old' )" "years-old"
rigOldBefore="$( rigFolders )"
rigWait 2 ""
rigFolderOfNew "$rigOldBefore" > /dev/null || :
rigAssert "the next wait of that member, past its sweep, left the directory of the wait that lives" "$( rigIsDir "$rigOldDir" ):$( rigFolderCount )" "stands:2"
rigAnswer 1
rigAnswer 2
rigWaitEnd 1
rigWaitEnd 2
rigAssert "the wait whose directory looked old ends on its own arrival, and no file of its directory was missing" "$( rigWaitSays 1 )" "0:WAIT-RESULT: RECEIVED:1:0:0"
rigAssert "the wait that came after it ends on its own arrival" "$( rigWaitSays 2 )" "0:WAIT-RESULT: RECEIVED:1:0:0"
rigAssert "both removed their own directories as they ended" "$( rigFolderCount )" 0

echo "-- the sweep: by whose a directory is, never by how old it looks --"
rigStart sweep
rigTempOf="$rigScenarioDir/ws/.local/temp"
rigHost="$( hostname -s 2>/dev/null )" || rigHost="unknown"
## A pid no process has: a process of this check's own that has ended and was collected.
( exit 0 ) &
rigGonePid=$!
wait "$rigGonePid" 2>/dev/null
## A process that lives through the scenario: this check's own shell, and when it began by the tooling's own reading.
rigLivePid="$$"
rigLiveStart="$( set +u ; . "$rigHere/AgentsTools.Registries.include" > /dev/null 2>&1 ; AgentsToolsRegistryProcessStart "$rigLivePid" )"
[ -n "$rigLiveStart" ] || rigRefuse "the tooling's own reading does not say when this check's shell began, so no live owner can be recorded"
rigMade(){ ## directory name, host (empty: no record), process (may be empty), "old" to set it years back
	mkdir -p "$rigTempOf/$1" && : > "$rigTempOf/$1/now.1"
	[ -z "$2" ] || { printf 'host: %s\n' "$2" ; [ -z "$3" ] || printf 'process: %s\n' "$3" ; } > "$rigTempOf/$1/owner"
	[ "${4:-}" != "old" ] || touch -t 202001010000 "$rigTempOf/$1"
}
rigMade "mdat-member-wait.$rigMember.gone001" "$rigHost" "$rigGonePid Mon_Jan__1_00:00:00_2001" ""
rigMade "mdat-member-wait.$rigMember.taken01" "$rigHost" "$rigLivePid Mon_Jan__1_00:00:00_2001" ""
rigMade "mdat-member-wait.$rigMember.alive01" "$rigHost" "$rigLivePid $rigLiveStart" old
rigMade "mdat-member-wait.$rigMember.other01" "rig-another-host" "$rigGonePid Mon_Jan__1_00:00:00_2001" old
rigMade "mdat-member-wait.$rigMember.bare001" "" "" ""
rigMade "mdat-member-wait.$rigMember.bare002" "" "" old
rigMade "mdat-member-wait.$rigMember.part001" "$rigHost" "" ""
rigMade "mdat-member-wait.magic-coordinator.gone001" "$rigHost" "$rigGonePid Mon_Jan__1_00:00:00_2001" ""
rigMade "mdat-member-wait.$rigMember.kept001" "$rigHost" "$rigGonePid Mon_Jan__1_00:00:00_2001" ""
: > "$rigTempOf/mdat-member-wait.$rigMember.kept001/kept"
rigMade "mdat-member-wait.$rigMember.kept002" "$rigHost" "$rigGonePid Mon_Jan__1_00:00:00_2001" ""
: > "$rigTempOf/mdat-member-wait.$rigMember.kept002/kept" ; touch -t 202001010000 "$rigTempOf/mdat-member-wait.$rigMember.kept002"
rigQuickWait
rigAssert "the wait that swept ran: it returned what stood in its file" "$( rigFirstLine "$rigScenarioDir/op.out" )" "WAIT-RESULT: RECEIVED"
rigSwept=""
for rigSweptName in "$rigMember.gone001" "$rigMember.taken01" "$rigMember.alive01" "$rigMember.other01" "$rigMember.bare001" "$rigMember.bare002" "$rigMember.part001" "magic-coordinator.gone001" "$rigMember.kept001" "$rigMember.kept002" ; do
	rigSwept="$rigSwept${rigSweptName#*.}=$( rigIsDir "$rigTempOf/mdat-member-wait.$rigSweptName" ) "
done
rigAssert "owner gone: goes, however new. Its pid taken by another process: goes. Owner alive: stays, however old. Another host's: stays. No whole record: stays while new, goes a day old. Another member's: not this member's to sweep. Kept by its wait: stays its day, whoever owned it" \
	"$rigSwept" "gone001=gone taken01=gone alive01=stands other01=stands bare001=stands bare002=gone part001=stands gone001=stands kept001=stands kept002=gone "
rigAssert "the wait that swept left no directory of its own" "$( rigFolderCount )" 5

echo "-- a mktemp that fails ends the wait on one line that says why --"
## What such a wait ended on: its status, its outcome, how many error lines of its own it said, how many of its
## lines say a file was not there, how many directories of the member stand, and how many reads of a thread it made.
rigFailed(){ ## scenario name, the directory whose mktemp is first on PATH
	rigStart "$1"
	rigThread 1 ""
	rigWait 1 "$2"
	rigWaitEnd 1
	printf '%s:%s:%s:%s:%s:%s' "${rigWaitRc[1]}" "$( rigFirstLine "$rigScenarioDir/wait.1.out" )" \
		"$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*--member-wait-for-input: ' )" \
		"$( rigCount "$rigScenarioDir/wait.1.err" 'No such file|can.t open file' )" \
		"$( rigFolderCount )" "$( [ ! -f "$rigScenarioDir/calls" ] && printf '0' || rigCount "$rigScenarioDir/calls" '^conversations[.]replies ' )"
}
rigAssert "a mktemp that fails: status 1, ERROR, one error line of the wait, no missing file, no directory, nothing read" "$( rigFailed no-mktemp "$rigTmp/bin-nomktemp" )" "1:WAIT-RESULT: ERROR:1:0:0:0"
rigAssert "and that one line says what mktemp said" "$( rigCount "$rigTmp/no-mktemp/wait.1.err" 'ERROR.*could not create a working directory.*the rig refuses this directory' )" 1
rigAssert "a mktemp that names what is no directory: status 1, ERROR, one error line of the wait, no missing file, no directory, nothing read" "$( rigFailed bad-mktemp "$rigTmp/bin-badmktemp" )" "1:WAIT-RESULT: ERROR:1:0:0:0"
rigAssert "and that one line says the name is no directory" "$( rigCount "$rigTmp/bad-mktemp/wait.1.err" 'ERROR.*could not create a working directory.*mdat-member-wait[.]never-made, which is no directory' )" 1

echo "-- a wait whose directory is taken from under it ends at once, on one line that names it --"
rigStart taken
rigThread 1 ""
rigWait 1 ""
rigTakenDir="$( rigFolderOfNew "" )" || rigTakenDir="$rigScenarioDir/no-directory-of-wait-1"
sleep 2
rigTakenAt="$( date +%s )"
rm -rf -- "$rigTakenDir"
rigWaitEnd 1
rigAssert "status 1, ERROR, one error line of the wait and it names the directory as gone, no round after round of missing files, long before its bound" \
	"${rigWaitRc[1]}:$( rigFirstLine "$rigScenarioDir/wait.1.out" ):$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*--member-wait-for-input: ' ):$( rigCount "$rigScenarioDir/wait.1.err" "ERROR: .*${rigTakenDir##*/}, is gone" ):$( [ "$( rigCount "$rigScenarioDir/wait.1.err" 'No such file|can.t open file' )" -le 2 ] && printf 'no-rounds-of-it' || printf 'round-after-round' ):$( [ $(( $( date +%s ) - rigTakenAt )) -lt 30 ] && printf 'at-once' || printf 'at-its-bound' )" \
	"1:WAIT-RESULT: ERROR:1:1:no-rounds-of-it:at-once"

echo "-- a file a step wrote that is not there when the next step reads it: the wait ends on it and keeps its directory --"
rigStart lost-settle
: > "$rigScenarioDir/lose-settle-rendered"
rigThread 1 ""
rigWait 1 "$rigTmp/bin-loseawk"
rigLostDir="$( rigFolderOfNew "" )" || rigLostDir="$rigScenarioDir/no-directory-of-wait-1"
rigAnswer 1
rigWaitEnd 1
rigAssert "the render of the settle pass gone as it is written: status 1, ERROR, one error line of the wait, and it names that file" \
	"${rigWaitRc[1]}:$( rigFirstLine "$rigScenarioDir/wait.1.out" ):$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*--member-wait-for-input: ' ):$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*/settle[.]1[.]rendered, which a step of this wait wrote, is not there' )" \
	"1:WAIT-RESULT: ERROR:1:1"
rigAssert "its directory is kept as it stands, says what was missed, and is named in that line" \
	"$( rigIsDir "$rigLostDir" ):$( rigCount "$rigLostDir/kept" '^missed: .*/settle[.]1[.]rendered$' ):$( rigCount "$rigScenarioDir/wait.1.err" "kept as it stands.*${rigLostDir##*/}" )" "stands:1:1"
rigQuickWait
rigAssert "the next wait of that member leaves the kept directory, though the wait that made it is gone" "$( rigFirstLine "$rigScenarioDir/op.out" ):$( rigIsDir "$rigLostDir" )" "WAIT-RESULT: RECEIVED:stands"
rigStart lost-now
: > "$rigScenarioDir/lose-now"
rigThread 1 ""
rigWait 1 "$rigTmp/bin-loseawk"
rigWaitEnd 1
rigAssert "the rendering of a round gone as it is written is no arrival: status 1, ERROR, one error line of the wait and it names that file, nothing said to have arrived, no file opened that is not there" \
	"${rigWaitRc[1]}:$( rigFirstLine "$rigScenarioDir/wait.1.out" ):$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*--member-wait-for-input: ' ):$( rigCount "$rigScenarioDir/wait.1.err" 'ERROR: .*/now[.]1, which a step of this wait wrote, is not there' ):$( rigCount "$rigScenarioDir/wait.1.out" 'arrived on' ):$( rigCount "$rigScenarioDir/wait.1.err" 'can.t open file' )" \
	"1:WAIT-RESULT: ERROR:1:1:0:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT FOLDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_FOLDER: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
