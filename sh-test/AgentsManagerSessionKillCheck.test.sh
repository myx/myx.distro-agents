#!/usr/bin/env bash
## Behavioural check on --manager-session-kill --session-id <id> [--run], the hard control of the
## console's own family --manager-*, run rather than read, against a rig workspace built here: its own spawn
## records, board items and transcripts, and A PROCESS LIST OF ITS OWN. Every process a call here can signal is one
## this rig started: a ps first on PATH answers the whole-host listing from the rig's list alone, one line a
## stand-in under its own pid, and lists a line only while that pid is still the process the rig started (the
## same pid begun at another time is another process), so no process of the host is ever seen, a pid the host has
## given out again among them. Which process started which, pid and ppid alone, is asked of the real ps.
## Held: the id of a session ends every live run of it and no run of another session; an id no session has is a
## run's own and ends that run alone; --run takes the id as a run's own, which ends one run alone also where its
## id is its session's, the run that founded it. A member that joined a session since the registry was last built
## is ended with its session. A run is found by the one rule a run is recognised by: its own --session-id word matched
## whole, or the process its record names and what that started, never a line that merely holds the id, never the
## tooling's own command line, never a process that runs as another spawn, never the caller of the operation.
## What the run started ends with it, to any depth: a helper server under its CLI, a tool command and the child
## of that command that hangs. A member the run brought in is a run of its own and lives on, and so does the
## shell that supervises that member, though both stand under the run; the run's own supervising shell stands
## above it and is never reached. TERM first, and KILL only to what is still there after the polite time. The ending is recorded before the
## signal, under the name the console's user has in the operating system: killed-by and killed-at on the run's
## record, one dismissed line in the Decisions of its own dispatch item, one ENDING line in its transcript. One
## row a run on stdout, in the form the help entry gives. A run that is not alive, one of another host and an id
## that names nothing are told apart, and nothing is signalled for them. A call from inside a member's session is
## refused and signals nothing. THROUGH THE REAL SPAWN PROXY, on a stand-in console: the supervising shell of a
## killed run closes its record as failed, its item holds the ending, and the handback retry does not start the
## run again, with no dispatch item and no transcript either; the control is a run that ends by itself with no
## handback, which the retry does start once more. A fake `curl` first on PATH answers as Slack and opens no
## socket. Offline; only the rig's own tree is read or written.
## Reconciled for the run with no spawn-id (section 18): the finish of a session reads a run by the same walk in one more place, so the places that ask for it are four.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"
rigOp="--manager-session-kill"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionKillCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigTmp/pids" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
: > "$rigTmp/ps.list" ; : > "$rigTmp/started" ; : > "$rigTmp/calls" ; : > "$rigTmp/bodies"

## THE RIG'S OWN PROCESS LIST. A line of it is `<pid> <when that process began> <command line>`. The ps first on
## PATH prints, for the whole-host listing, the lines whose pid is still that very process, and hands the listing
## of pid and ppid, and every other call, to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH to hand the other calls to"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		rigPsList="${0%/*}/../ps.list"
		rigPsPids="$( LC_ALL=C awk '{ printf "%s%s", ( NR > 1 ? "," : "" ), $1 }' "$rigPsList" 2> /dev/null )"
		[ -n "$rigPsPids" ] || exit 0
		rigPsWith=no ; case "$*" in *pid=*) rigPsWith=yes ;; esac
		LC_ALL=C "${0%/*}/ps.real" -o pid=,lstart= -p "$rigPsPids" 2> /dev/null | LC_ALL=C awk -v withPid="$rigPsWith" '
			FILENAME == "-" { rigPid = $1 ; $1 = "" ; sub( /^ +/, "" ) ; gsub( / +/, "_" ) ; rigBegan[rigPid] = $0 ; next ; }
			( $1 in rigBegan ) && rigBegan[$1] == $2 { rigPid = $1 ; rigLine = $0 ; sub( /^[^ ]+ [^ ]+ /, "", rigLine ) ; print ( withPid == "yes" ? rigPid " " : "" ) rigLine ; }
		' - "$rigPsList"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
## The console's user, as the operating system names it: `rig` here, whoever runs this check.
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo rig ; exit 0 ; }\nexec "${0%%/*}/id.real" "$@"\n' > "$rigTmp/bin/id"
cp "$rigFixture" "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/id" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v id )" = "$rigTmp/bin/id" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps, id and curl are not first on PATH, so this check would read the host's process list or issue a real request"
[ "$( id -un )" = "rig" ] || rigRefuse "the rig's own id does not answer as the user rig"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in rig-member-a magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

rigBegan(){ ## pid -- when that process began, as one word; nothing when there is none
	LC_ALL=C "$rigTmp/bin/ps.real" -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }'
}
## EVERY SIGNAL OF THIS CHECK GOES TO A PROCESS IT STARTED. Each one is kept with when it began, and is ended at
## the end only while its pid is still that process.
rigKeep(){ ## pid
	printf '%s %s\n' "$1" "$( rigBegan "$1" )" >> "$rigTmp/started"
}
rigCleanup(){
	local cleanPid cleanBegan
	cat "$rigTmp/started" "$rigTmp"/*/console.pid 2> /dev/null | while read -r cleanPid cleanBegan ; do
		[ -n "$cleanBegan" ] && [ "$( rigBegan "$cleanPid" )" = "$cleanBegan" ] || continue
		kill -KILL "$cleanPid" 2> /dev/null
	done
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"
}
trap 'rigControlThreadsEnd "$rigTmp" ; rigCleanup' EXIT

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

## The person at the console, `user-<account>`: the runs below report to it, so its kills hold the
## authority to end them (F6.10, AgentsTools.Authority.include).
rigConsoleUser="user-$( printf '%s' "$( id -un 2>/dev/null )" | LC_ALL=C tr -s ' \t\r\n' '_' )"
rigRec(){ ## sandbox folder, spawn id, session id, host, owner, status, started-at minute, more header lines (may be empty)
	mkdir -p "$rigSp/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: 2026-10-13 09:%s +0300\nreports-to: %s\n' "$3" "$2" "$1" "$4" "$5" "$6" "$7" "$rigConsoleUser"
		[ -z "${8:-}" ] || printf '%s\n' "$8"
		printf -- '---\n\n# Spawn session: %s\n' "$3"
	} > "$rigSp/$1/$2.spawn.md"
}
rigItem(){ ## item stem, spawn id, session id -- the run's own dispatch item, in running
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nsession-id: %s\nspawn-id: %s\n---\n\n# rig dispatch\n' "$3" "$2" > "$rigData/board/running/$1.md"
}
rigTranscript(){ ## spawn id -- the transcript pointer every writer resolves
	mkdir -p "$rigStores/$1"
	: > "$rigTmp/tr-$1.log"
	printf '%s\n' "$rigTmp/tr-$1.log" > "$rigStores/$1/transcript"
}
rigList(){ ## pid, command line -- a process the rig started, into the rig's process list
	printf '%s %s %s\n' "$1" "$( rigBegan "$1" )" "$2" >> "$rigTmp/ps.list"
}
rigLive(){ ## name, command line (default: a CLI that runs as that name by its own --session-id word)
	sleep 300 > /dev/null 2>&1 < /dev/null &
	printf '%s\n' "$!" > "$rigTmp/pids/$1"
	rigKeep "$!"
	rigList "$!" "${2:-claude --verbose --session-id $1 --agent rig-member the brief}"
	disown "$!" 2> /dev/null || :
}
rigPid(){ ## name
	cat "$rigTmp/pids/$1" 2> /dev/null
}
rigAlive(){ ## name... -- how many of them are still running
	local aliveCount=0 aliveName
	for aliveName in "$@" ; do ! kill -0 "$( rigPid "$aliveName" )" 2> /dev/null || aliveCount=$(( aliveCount + 1 )) ; done
	printf '%s' "$aliveCount"
}
## A call from a bare console, which names no workspace, runs the dispatcher with errexit on: `-e` in rigBash
## runs a call so.
rigPre=() rigKept=0 rigBash=( bash )
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} "${rigBash[@]}" "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	## Every output of the operation is kept, for the check of its rows against the form its help entry gives.
	rigKept=$(( rigKept + 1 ))
	[ "${1:-}" != "$rigOp" ] || cp "$rigTmp/out" "$rigTmp/out.kept.$rigKept"
}
rigOut(){ ## -- the `kill` rows of the last stdout, TAB written as a space: the rows of the kill itself, before those of what it finishes
	LC_ALL=C awk -F'\t' '$1 == "kill" { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigKillRows(){ ## -- the same rows as they were printed
	LC_ALL=C awk -F'\t' '$1 == "kill"' "$rigTmp/out"
}
rigItemAt(){ ## item stem -- where that item lies on the board now
	ls "$rigData"/board/*/"$1.md" 2> /dev/null | head -1
}
rigRowOf(){ ## spawn id -- its row in the last stdout, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantId="$1" '$1 == "kill" && $3 == wantId { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigHeader(){ ## record file, header -- its value, or nothing
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}
rigDecisions(){ ## item path, text after the date -- how many Decisions lines are a date and that text
	LC_ALL=C grep -c -E "^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z $2\$" "$1" 2> /dev/null || :
}
rigEndings(){ ## spawn id, text after the date -- how many lines of its transcript are a date and that text
	LC_ALL=C grep -c -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z $2\$" "$rigTmp/tr-$1.log" 2> /dev/null || :
}
rigStamped='[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}'
rigEndText='manager-kill: recorded only, the process is stopped by manager-kill'

## THE STORES. sess-one: its founder, two members that joined, one closed. sess-two: its founder, two members,
## one closed. sess-three: a founder alone, which nothing here ends. sess-done: every run closed. sess-far: of
## another host, its records open. Each a started-at of its own, so the rows come in one order.
rigRec sess-one sess-one sess-one "$rigHost" magic-coordinator spawn-started 00 ""
rigRec sess-one run-a sess-one "$rigHost" keeper-rig spawn-started 01 "spawns: dispatch-rig-run-a"
rigRec sess-one run-b sess-one "$rigHost" magic-tester spawn-started 02 ""
rigRec sess-one run-c sess-one "$rigHost" magic-developer spawn-succeeded 03 "resolved-at: 2026-10-13 09:30 +0300"
rigRec sess-two sess-two sess-two "$rigHost" magic-coordinator spawn-started 10 "spawns: dispatch-rig-sess-two"
rigRec sess-two run-x sess-two "$rigHost" keeper-rig spawn-started 11 ""
rigRec sess-two run-y sess-two "$rigHost" magic-tester spawn-started 12 ""
rigRec sess-two run-z sess-two "$rigHost" magic-developer spawn-failed 13 "resolved-at: 2026-10-13 09:40 +0300"
rigRec sess-three sess-three sess-three "$rigHost" magic-coordinator spawn-started 20 ""
rigRec sess-done sess-done sess-done "$rigHost" magic-coordinator spawn-succeeded 30 "resolved-at: 2026-10-13 09:50 +0300"
rigRec sess-done done-b sess-done "$rigHost" keeper-rig spawn-failed 31 "resolved-at: 2026-10-13 09:51 +0300"
rigRec sess-far sess-far sess-far elsewhere magic-coordinator spawn-started 40 ""
rigRec sess-far far-b sess-far elsewhere keeper-rig spawn-started 41 ""
rigItem dispatch-rig-run-a run-a sess-one
rigItem dispatch-rig-sess-two sess-two sess-two
for rigId in sess-one run-a run-b sess-two ; do rigTranscript "$rigId" ; done
for rigId in sess-one run-a run-b sess-two run-x run-y sess-three ; do rigLive "$rigId" ; done
## Lines that hold an id and are no run of it: one that runs as another spawn and holds run-a inside the path of
## a folder and quoted in its brief, a command line of the tooling that names run-a, and a process on this host
## that runs as the id of a run of another host.
rigLive other-holds-a "claude --add-dir $rigSp/run-a/input --session-id run-other --agent rig-member Readable $rigSp/run-a/input, as said by --session-id run-a"
rigLive tooling-names-a "bash $rigTool --intern-op-agent-spawn-proxy keeper-rig --session-id run-a"
rigLive here-as-far-b "claude --verbose --session-id far-b --agent rig-member the brief"
rigEvery="sess-one run-a run-b sess-two run-x run-y sess-three other-holds-a tooling-names-a here-as-far-b"
rigAssert "control: every stand-in of the rig runs, and the rig's process list holds each under its own pid" "$( rigAlive $rigEvery ) $( ps -A -ww -o pid=,args= | LC_ALL=C awk 'END { print NR + 0 }' )" "10 10"

echo "-- 1. a run's own id ends that run alone, the ending recorded first under the name of the console's user --"
rigRun "$rigOp" --session-id run-a
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "one row, of that run: its session, its id, its member, that it ended on the polite signal, the status of its record, the process signalled, its item" \
	"$( rigOut )" "kill sess-one run-a keeper-rig ended spawn-started $( rigPid run-a ) dispatch-rig-run-a"
rigAssert "its process is gone" "$( rigAlive run-a )" "0"
rigAssert "the founder of its session, the other member of it and the runs of the other sessions live on" "$( rigAlive sess-one run-b sess-two run-x run-y sess-three )" "6"
rigAssert "a line that holds the id inside another word and in its text, and a command line of the tooling that names it, are no run of it: neither is signalled" "$( rigAlive other-holds-a tooling-names-a )" "2"
rigAssert "its record says that it was killed, by whom and when, and its status is left to its supervising shell" \
	"$( rigHeader "$rigSp/sess-one/run-a.spawn.md" killed-by ) $( rigHeader "$rigSp/sess-one/run-a.spawn.md" killed-at | LC_ALL=C grep -c -x -E "$rigStamped" ) $( rigHeader "$rigSp/sess-one/run-a.spawn.md" status )" "rig 1 spawn-started"
rigAssert "the Decisions of its own dispatch item hold the ending, under the name of the console's user" \
	"$( rigDecisions "$rigData/board/running/dispatch-rig-run-a.md" "rig dismissed: $rigEndText \\(run-a\\)" )" "1"
rigAssert "and so does its transcript, in one ENDING line" "$( rigEndings run-a "ENDING item=dispatch-rig-run-a kind=dismissed by=rig text=\"$rigEndText\"" ) $( LC_ALL=C grep -c ' ENDING ' "$rigTmp/tr-run-a.log" )" "1 1"
rigAssert "no record, item or transcript of another run was written" "$( LC_ALL=C grep -l -e 'killed-' -e 'manager-kill' "$rigSp"/*/*.spawn.md "$rigData"/board/*/*.md "$rigTmp"/tr-*.log 2> /dev/null | LC_ALL=C sed "s|^$rigTmp/||" | LC_ALL=C tr '\n' ' ' )" "ws/.local/agents/spawned/sess-one/run-a.spawn.md data/board/running/dispatch-rig-run-a.md tr-run-a.log "
rigAssert "nothing was posted and nobody was asked: no Slack call was made" "$( wc -l < "$rigTmp/calls" | LC_ALL=C tr -d ' ' )" "0"

echo "-- 2. --run takes the id as a run's own: one run alone, also where its id is its session's --"
rigRun "$rigOp" --session-id sess-one --run
rigAssert "the founder of a session, its id given with --run: one row, of that run, ended, with no item of its own" \
	"$rigRc $( rigTroubles ) $( rigOut )" "0 0 kill sess-one sess-one magic-coordinator ended spawn-started $( rigPid sess-one ) -"
rigAssert "the founder is gone and the member of its session that still ran lives on: a kill of one agent reaches no other" "$( rigAlive sess-one ) $( rigAlive run-b )" "0 1"
rigAssert "a run with no dispatch item has its ending in its transcript, under the same name, and on its record" \
	"$( rigEndings sess-one 'ENDING kind=dismissed by=rig text="manager-kill: no dispatch item, the process is stopped by manager-kill"' ) $( rigHeader "$rigSp/sess-one/sess-one.spawn.md" killed-by )" "1 rig"

echo "-- 3. the id of a session ends every live run of it, and no run of another session --"
rigBash=( bash -e )
rigRun "$rigOp" --session-id sess-two
rigBash=( bash )
rigWant="$( {
	printf 'kill\tsess-two\tsess-two\tmagic-coordinator\tended\tspawn-started\t%s\tdispatch-rig-sess-two\n' "$( rigPid sess-two )"
	printf 'kill\tsess-two\trun-x\tkeeper-rig\tended\tspawn-started\t%s\t-\n' "$( rigPid run-x )"
	printf 'kill\tsess-two\trun-y\tmagic-tester\tended\tspawn-started\t%s\t-\n' "$( rigPid run-y )"
	printf 'kill\tsess-two\trun-z\tmagic-developer\tno-process\tspawn-failed\t-\t-\n'
} )"
rigAssert "the call ends 0, with no error and no warning, run with errexit on as a call from a bare console is" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: one row for each of its three live runs, each ended, and the closed run named as not running, with the status it closed with" "$( rigKillRows )" "$rigWant"
rigAssert "the three processes are gone" "$( rigAlive sess-two run-x run-y )" "0"
rigAssert "the run of another session lives on, and so does what is left of the first" "$( rigAlive sess-three run-b )" "2"
rigAssert "each run that was ended has the mark on its record, and the closed one has none" \
	"$( for rigId in sess-two run-x run-y run-z ; do printf '%s ' "$( rigHeader "$rigSp/sess-two/$rigId.spawn.md" killed-by )" ; done )" "rig rig rig  "
rigAssert "the item of the one run that has one holds its ending" "$( rigDecisions "$( rigItemAt dispatch-rig-sess-two )" "rig dismissed: $rigEndText \\(sess-two\\)" )" "1"

echo "-- 4. what is left of a session: the runs that are not alive are told, and only the live one is signalled --"
rigRun "$rigOp" --session-id sess-one
rigWant="$( {
	printf 'kill\tsess-one\tsess-one\tmagic-coordinator\tno-process\tspawn-started\t-\t-\n'
	printf 'kill\tsess-one\trun-a\tkeeper-rig\tno-process\tspawn-started\t-\t-\n'
	printf 'kill\tsess-one\trun-b\tmagic-tester\tended\tspawn-started\t%s\t-\n' "$( rigPid run-b )"
	printf 'kill\tsess-one\trun-c\tmagic-developer\tno-process\tspawn-succeeded\t-\t-\n'
} )"
rigAssert "the same id as in 2, given as the id of the session: every run of it has its row, the one still alive ended" "$rigRc $( rigKillRows )" "0 $rigWant"
rigAssert "a run that was ended before is not recorded a second time" "$( LC_ALL=C grep -c ' ENDING ' "$rigTmp/tr-run-a.log" ) $( LC_ALL=C grep -c ' ENDING ' "$rigTmp/tr-sess-one.log" ) $( LC_ALL=C grep -c 'dismissed: manager-kill' "$( rigItemAt dispatch-rig-run-a )" )" "1 1 1"

echo "-- 4b. a member that joined a session since the registry was last built is ended with it --"
rigRec sess-join sess-join sess-join "$rigHost" magic-coordinator spawn-started 25 ""
rigLive sess-join
rigRun "$rigOp" --session-id sess-one
## Its record goes into the folder its session already has, and the registry file is newer than it.
rigRec sess-join join-late sess-join "$rigHost" keeper-rig spawn-started 26 ""
rigLive join-late
sleep 1
touch "$rigAgents/spawned-sessions.registry"
rigAssert "control: the registry as it lies holds the founder and no row of the member that joined since, and is newer than its record and than the folder of the sandboxes" \
	"$( LC_ALL=C awk '$2 == "sess-join" { printf "%s ", $8 }' "$rigAgents/spawned-sessions.registry" )/ $( [ "$rigSp/sess-join/join-late.spawn.md" -nt "$rigAgents/spawned-sessions.registry" ] && echo record-newer ) $( [ "$rigSp" -nt "$rigAgents/spawned-sessions.registry" ] && echo folder-newer )" "sess-join /  "
rigRun "$rigOp" --session-id sess-join
rigAssert "the session is ended whole: the member that joined since has its row, and both processes are gone" \
	"$rigRc $( rigOut | LC_ALL=C awk '{ printf "%s:%s ", $3, $5 }' )/ $( rigAlive sess-join join-late )" "0 sess-join:ended join-late:ended / 0"

echo "-- 5. a session with no live run is said to have none --"
rigMarksBefore="$( cat "$rigSp"/*/*.spawn.md | cksum )"
rigBash=( bash -e )
rigRun "$rigOp" --session-id sess-done
rigBash=( bash )
rigAssert "it ends 0 and prints a row for each of its runs, none signalled" "$rigRc $( rigTroubles ) $( rigOut | LC_ALL=C tr '\n' '/' )" \
	"0 0 kill sess-done sess-done magic-coordinator no-process spawn-succeeded - -/kill sess-done done-b keeper-rig no-process spawn-failed - -/"
rigAssert "and says in one note that no run of the session is alive" "$( rigWhole "$rigTmp/err" "# DistroAgentsTools $rigOp: no run of session sess-done is alive on this host, so nothing was signalled" )" "1"
rigRun "$rigOp" --session-id done-b
rigAssert "a run that is not alive, named by its own id: its row, a note, and status 0" "$rigRc $( rigOut ) $( rigWhole "$rigTmp/err" "# DistroAgentsTools $rigOp: run done-b is not alive on this host, so nothing was signalled" )" \
	"0 kill sess-done done-b keeper-rig no-process spawn-failed - - 1"
rigAssert "neither call wrote a record" "$( cat "$rigSp"/*/*.spawn.md | cksum )" "$rigMarksBefore"

echo "-- 6. a run of another host is not signalled --"
rigRun "$rigOp" --session-id sess-far
rigAssert "each of its rows says that the run is of another host, and the call ends 0" "$rigRc $( rigOut | LC_ALL=C tr '\n' '/' )" \
	"0 kill sess-far sess-far magic-coordinator other-host spawn-started - -/kill sess-far far-b keeper-rig other-host spawn-started - -/"
rigAssert "a process of this host that runs as the id of such a run is not signalled, and no record was written" "$( rigAlive here-as-far-b ) $( cat "$rigSp"/*/*.spawn.md | cksum )" "1 $rigMarksBefore"

echo "-- 7. a run that ignores TERM is ended by KILL, after the polite time --"
rm -f "$rigTmp/hard.ready"
perl -e '$SIG{TERM} = "IGNORE" ; open( my $rigReady, ">", $ARGV[0] ) ; close( $rigReady ) ; sleep 300' "$rigTmp/hard.ready" > /dev/null 2>&1 < /dev/null &
printf '%s\n' "$!" > "$rigTmp/pids/run-hard" ; rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigWaitFor 20 test -e "$rigTmp/hard.ready" || rigRefuse "the stand-in that ignores TERM did not start"
rigList "$( rigPid run-hard )" "claude --verbose --session-id run-hard --agent rig-member the brief"
rigRec sess-hard run-hard sess-hard "$rigHost" keeper-rig spawn-started 50 ""
kill -TERM "$( rigPid run-hard )" 2> /dev/null ; sleep 1
rigAssert "control: the stand-in is still there after a TERM of the rig's own" "$( rigAlive run-hard )" "1"
rigHardFrom="$SECONDS"
rigRun "$rigOp" --session-id sess-hard
rigHardTook=$(( SECONDS - rigHardFrom ))
rigAssert "its row says it took the hard kill, and its process is gone" "$rigRc $( rigOut ) $( rigAlive run-hard )" "0 kill sess-hard run-hard keeper-rig killed spawn-started $( rigPid run-hard ) - 0"
rigAssert "the hard kill came only after the polite time, two seconds" "$( [ "$rigHardTook" -ge 2 ] && echo waited || echo "after $rigHardTook s" )" "waited"

echo "-- 8. a run that neither signal ends is said not to be ended, and the call ends 1 --"
## A process that is gone and not yet collected by the one that started it: no signal changes it, and it is
## still there for as long as that one sleeps. It is this rig's own, as its starter is.
perl -e 'my $rigChild = fork() ; if ( $rigChild == 0 ) { exit 0 } open( my $rigSaid, ">", $ARGV[0] ) ; print $rigSaid "$rigChild\n" ; close( $rigSaid ) ; sleep 300' "$rigTmp/pids/run-stuck.tmp" > /dev/null 2>&1 < /dev/null &
rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigWaitFor 20 test -s "$rigTmp/pids/run-stuck.tmp" || rigRefuse "the stand-in that no signal ends did not start"
sleep 1
mv "$rigTmp/pids/run-stuck.tmp" "$rigTmp/pids/run-stuck"
rigList "$( rigPid run-stuck )" "claude --verbose --session-id run-stuck --agent rig-member the brief"
rigRec sess-stuck run-stuck sess-stuck "$rigHost" keeper-rig spawn-started 55 ""
rigBash=( bash -e )
rigRun "$rigOp" --session-id sess-stuck
rigBash=( bash )
rigAssert "its row says not-ended, with the process that is still there, and the call ends 1 with one error line" \
	"$rigRc $( rigOut ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: 1 run(s) could not be ended: TERM and then KILL were sent, and a process is still there -- see the not-ended row(s)" )" \
	"1 kill sess-stuck run-stuck keeper-rig not-ended spawn-started $( rigPid run-stuck ) - 1"
LC_ALL=C grep -v -e ' --session-id run-stuck ' "$rigTmp/ps.list" > "$rigTmp/ps.list.next" && mv "$rigTmp/ps.list.next" "$rigTmp/ps.list"

echo "-- 9. a run with no session word: the process its record names, and what that started, and no run of another spawn --"
## A stand-in console that started two processes: one of its own, and one that runs as another spawn by its
## own word, as a member this run brought in and waits for. No line of the rig's list runs as the run itself.
rm -f "$rigTmp/stand.children"
bash -c 'sleep 300 > /dev/null 2>&1 < /dev/null & rigOwn=$! ; sleep 300 > /dev/null 2>&1 < /dev/null & echo "$rigOwn $!" > "$1" ; wait' rig-stand "$rigTmp/stand.children" > /dev/null 2>&1 < /dev/null &
printf '%s\n' "$!" > "$rigTmp/pids/stand-console" ; rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigWaitFor 20 test -s "$rigTmp/stand.children" || rigRefuse "the stand-in console did not start, so nothing below would be measured"
read -r rigStandOwn rigStandOther < "$rigTmp/stand.children"
printf '%s\n' "$rigStandOwn" > "$rigTmp/pids/stand-own" ; printf '%s\n' "$rigStandOther" > "$rigTmp/pids/stand-other"
rigKeep "$rigStandOwn" ; rigKeep "$rigStandOther"
rigList "$rigStandOther" "claude --verbose --session-id run-brought-in --agent rig-member the brief"
rigRec sess-noword run-noword sess-noword "$rigHost" keeper-rig spawn-started 60 "run-process: $( rigPid stand-console ) $( rigBegan "$( rigPid stand-console )" )"
rigAssert "control: no line of the rig's process list runs as that spawn, or holds its id" "$( LC_ALL=C grep -c -F -- 'run-noword' "$rigTmp/ps.list" )" "0"
rigRun "$rigOp" --session-id run-noword
rigAssert "it is ended: the process its record names and the process that one started, both in its row" \
	"$rigRc $( rigOut | LC_ALL=C awk '{ print $1, $2, $3, $4, $5, $6, $8 }' ) $( rigOut | LC_ALL=C awk '{ print $7 }' | LC_ALL=C tr ',' '\n' | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' ) $( rigAlive stand-console stand-own )" \
	"0 kill sess-noword run-noword keeper-rig ended spawn-started - $( printf '%s\n%s\n' "$( rigPid stand-console )" "$rigStandOwn" | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' ) 0"
rigAssert "a process it started that runs as another spawn is another member's run: not signalled" "$( rigAlive stand-other )" "1"
## The same pid begun at another time is another process, and is never signalled.
bash -c 'sleep 300 > /dev/null 2>&1 < /dev/null & echo "$!" > "$1" ; wait' rig-stand "$rigTmp/stand.reused" > /dev/null 2>&1 < /dev/null &
printf '%s\n' "$!" > "$rigTmp/pids/reused-console" ; rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigWaitFor 20 test -s "$rigTmp/stand.reused" || rigRefuse "the second stand-in console did not start"
rigKeep "$( cat "$rigTmp/stand.reused" )"
rigRec sess-reused run-reused sess-reused "$rigHost" keeper-rig spawn-started 61 "run-process: $( rigPid reused-console ) Mon_Jan__1_00:00:00_2001"
rigRun "$rigOp" --session-id run-reused
rigAssert "a recorded pid that another process has taken is no run: nothing is signalled, and that process lives on" "$rigRc $( rigOut ) $( rigAlive reused-console )" "0 kill sess-reused run-reused keeper-rig no-process spawn-started - - 1"

echo "-- 9b. what the run started ends with it, to any depth, and no run of another spawn --"
## A stand-in CLI that runs as the spawn by its own word, and under it: a helper server; a tool command whose own
## child hangs and ignores TERM; and a shell that supervises a member this run brought in and waits for, whose
## child runs as another spawn by its own word.
mkdir -p "$rigTmp/tree"
cat > "$rigTmp/bin/rig-cli-tree" <<'RIGTREE'
#!/usr/bin/env bash
sleep 300 > /dev/null 2>&1 < /dev/null &
echo "$!" > "$1/server"
bash -c 'perl -e '\''$SIG{TERM} = "IGNORE" ; open( my $rigSaid, ">", $ARGV[0] ) ; print $rigSaid "$$\n" ; close( $rigSaid ) ; sleep 300'\'' "$1" ; :' rig-tool "$1/hung" > /dev/null 2>&1 < /dev/null &
echo "$!" > "$1/tool"
bash -c 'sleep 300 > /dev/null 2>&1 < /dev/null & echo "$!" > "$1" ; wait' rig-supervisor "$1/brought" > /dev/null 2>&1 < /dev/null &
echo "$!" > "$1/supervisor"
wait
RIGTREE
chmod +x "$rigTmp/bin/rig-cli-tree"
"$rigTmp/bin/rig-cli-tree" "$rigTmp/tree" > /dev/null 2>&1 < /dev/null &
printf '%s\n' "$!" > "$rigTmp/pids/tree-cli" ; rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigTreeReady(){ [ -s "$rigTmp/tree/server" ] && [ -s "$rigTmp/tree/tool" ] && [ -s "$rigTmp/tree/hung" ] && [ -s "$rigTmp/tree/supervisor" ] && [ -s "$rigTmp/tree/brought" ] ; }
rigWaitFor 20 rigTreeReady || rigRefuse "the stand-in CLI with its processes did not start, so nothing below would be measured"
for rigName in server tool hung supervisor brought ; do
	cp "$rigTmp/tree/$rigName" "$rigTmp/pids/tree-$rigName" ; rigKeep "$( rigPid "tree-$rigName" )"
done
rigList "$( rigPid tree-cli )" "claude --verbose --session-id run-tree --agent rig-member the brief"
rigList "$( rigPid tree-brought )" "claude --verbose --session-id run-brought --agent rig-member the brief"
rigRec sess-tree run-tree sess-tree "$rigHost" keeper-rig spawn-started 62 ""
rigAssert "control: the run, the three processes under it, the hung one two deep, and the member it brought in with its supervisor all run" "$( rigAlive tree-cli tree-server tree-tool tree-hung tree-supervisor tree-brought )" "6"
rigRun "$rigOp" --session-id run-tree
rigAssert "the run is ended with what it started: its helper server, its tool command, and that command's own child that hangs, which took the hard kill" \
	"$rigRc $( rigOut | LC_ALL=C awk '{ print $1, $2, $3, $4, $5, $6, $8 }' ) $( rigAlive tree-cli tree-server tree-tool tree-hung )" "0 kill sess-tree run-tree keeper-rig killed spawn-started - 0"
rigAssert "its row names each process that was signalled: the four, and no other" \
	"$( rigOut | LC_ALL=C awk '{ print $7 }' | LC_ALL=C tr ',' '\n' | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' )" "$( for rigName in cli server tool hung ; do rigPid "tree-$rigName" ; done | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' )"
rigAssert "a member the run brought in is a run of its own, and the shell that supervises it is that run's: both stand under the killed run, and both live on" "$( rigAlive tree-supervisor tree-brought )" "2"

echo "-- 9c. what a stop left of a run is kept in the run's store, and a kill ends it --"
## A stand-in run whose tool command ignores TERM, stopped by the harness tool TaskStop without force: the run's
## own process ends, the command stays, and stands under no process of the run any more.
rm -f "$rigTmp/left.tool"
bash -c 'perl -e '"'"'$SIG{TERM} = "IGNORE" ; open( my $rigSaid, ">", $ARGV[0] ) ; print $rigSaid "$$\n" ; close( $rigSaid ) ; sleep 300'"'"' "$1" > /dev/null 2>&1 < /dev/null & wait' rig-left "$rigTmp/left.tool" > /dev/null 2>&1 < /dev/null &
printf '%s\n' "$!" > "$rigTmp/pids/left-run" ; rigKeep "$!" ; disown "$!" 2> /dev/null || :
rigWaitFor 20 test -s "$rigTmp/left.tool" || rigRefuse "the stand-in run with a tool command that ignores TERM did not start"
cp "$rigTmp/left.tool" "$rigTmp/pids/left-tool" ; rigKeep "$( rigPid left-tool )"
rigList "$( rigPid left-run )" "claude --verbose --session-id run-left --agent rig-member the brief"
rigRec sess-left run-left sess-left "$rigHost" keeper-rig spawn-started 63 ""
## The coordinator stops it, and the console kills it: the run reports to the console, and the owners
## role granted the coordinator the authority in its session, by a recorded permission (F6.10).
rigRun --intern-op-permission-refusal-log magic-coordinator --session-id sess-left --tool authority --target "$rigConsoleUser" --reason "rig: the coordinator stops this run"
rigGrantRefusal="$( LC_ALL=C grep -o -E 'refusal-[0-9a-f-]+' "$rigTmp/out" | head -1 )"
rigRun --intern-op-permission-grant-open human-owner --session-id sess-left --refusal-id "${rigGrantRefusal:-none}" --kind session
LC_ALL=C grep -q '^GRANT: session ' "$rigTmp/out" || rigRefuse "the grant of the authority over sess-left to the coordinator was not written: $( head -2 "$rigTmp/err" | LC_ALL=C tr '\n' ' ' )"
printf '{"task_id":"run-left"}\n' > "$rigTmp/stop.args"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
	RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" MDAT_SPAWN_AGENT=magic-coordinator bash "$rigHere/harness/AgentsUniversalHarness.sh" --intern-tool TaskStop < "$rigTmp/stop.args" ) > "$rigTmp/stop.out" 2>&1
rigAssert "control: a stop without force ends the run's own process and says that the command is still running, and the run's store keeps it, by its pid and when it began" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STILL-RUNNING' "$rigTmp/stop.out" ) $( rigAlive left-run ) $( rigAlive left-tool ) $( LC_ALL=C awk -v wantPid="$( rigPid left-tool )" '$1 == wantPid && NF == 2 { hit++ } END { print NR ":" hit + 0 }' "$rigStores/run-left/stop.left" 2> /dev/null )" "1 0 1 1:1"
rigRun "$rigOp" --session-id run-left
rigAssert "a kill of that run after the stop ends what the stop left: its row says so, the command is gone, and nothing is kept any more" \
	"$rigRc $( rigOut ) $( rigAlive left-tool ) $( [ -e "$rigStores/run-left/stop.left" ] && echo kept || echo cleared )" "0 kill sess-left run-left keeper-rig killed spawn-started $( rigPid left-tool ) - 0 cleared"
## An entry is a process only while its pid is still the process that began when the entry says: one whose pid
## another process has taken, and one whose process is gone, are nothing, and a read that finds nothing left
## clears the file. So a later start of the run never meets what an earlier one left behind in name alone.
rigRec sess-stale run-stale sess-stale "$rigHost" keeper-rig spawn-failed 64 "resolved-at: 2026-10-13 09:55 +0300"
mkdir -p "$rigStores/run-stale"
printf '%s Mon_Jan__1_00:00:00_2001\n999999 Mon_Jan__1_00:00:00_2001\n' "$( rigPid sess-three )" > "$rigStores/run-stale/stop.left"
rigRun "$rigOp" --session-id run-stale
rigAssert "a kept pid that another process has taken since, and one whose process is gone, are never signalled: the run has nothing left, the other process lives, and the file is cleared" \
	"$rigRc $( rigOut ) $( rigAlive sess-three ) $( [ -e "$rigStores/run-stale/stop.left" ] && echo kept || echo cleared )" "0 kill sess-stale run-stale keeper-rig no-process spawn-failed - - 1 cleared"

echo "-- 10. an id that names nothing is refused --"
rigAliveBefore="$( rigAlive $rigEvery stand-other reused-console tree-supervisor tree-brought )"
rigMarksBefore="$( cat "$rigSp"/*/*.spawn.md | cksum )"
rigBash=( bash -e )
rigRun "$rigOp" --session-id no-such-id
rigBash=( bash )
rigAssert "no record carries the id: one error line, nothing on stdout, status 1" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigTroubles ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no record of this workspace carries 'no-such-id' as the id of a session or the own id of a run -- nothing was signalled" )" "1 0 1 1"
rigRun "$rigOp" --session-id sess-far-none --run
rigAssert "nor as a run's own id" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no record of this workspace carries 'sess-far-none' as the own id of a run -- nothing was signalled" )" "1 0 1"
rigRun "$rigOp" --session-id run-other --run
rigAssert "an id that a process of this host runs as, and no record of this workspace carries, is no run of this team: refused, and the process lives" "$rigRc $( rigAlive other-holds-a )" "1 1"
rigRun "$rigOp" --session-id sess-three-x --run
rigAssert "nothing was signalled and no record written by a refused call" "$( rigAlive $rigEvery stand-other reused-console tree-supervisor tree-brought ) $( cat "$rigSp"/*/*.spawn.md | cksum )" "$rigAliveBefore $rigMarksBefore"

echo "-- 11. what it takes --"
rigSyntax="--session-id <id> [--run] [--plan]"
rigBadSyntax=""
for rigArgs in "" "--run" "--session-id" "--session-id -" "--spawn-name sess-three" "--session-id sess-three --active" "sess-three" "--yes --session-id sess-three" ; do
	rigRun "$rigOp" $rigArgs
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -F -- "⛔ ERROR: DistroAgentsTools $rigOp: " "$rigTmp/err" | LC_ALL=C grep -c -F -- "syntax is $rigSyntax" ) $( rigTroubles )" = "1 0 1 1" ] || rigBadSyntax="$rigBadSyntax [$rigArgs: rc $rigRc, $( head -c 200 "$rigTmp/err" )]"
done
rigAssert "one id, with or without --run, and nothing else: anything else is refused in one line with its syntax, rc 1, nothing on stdout" "${rigBadSyntax:-each refused}" "each refused"
rigAssert "and no refused call signalled the run it named" "$( rigAlive sess-three )" "1"

echo "-- 12. never the caller: a command line that carries the id as the argument of this very operation is no run --"
rigLive run-w
rigRec sess-w run-w sess-w "$rigHost" keeper-rig spawn-started 70 ""
rm -f "$rigTmp/wrapper.said"
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" \
	bash -c 'printf "%s %s %s\n" "$$" "$( LC_ALL=C "$RIG_TMP/bin/ps.real" -o lstart= -p $$ | LC_ALL=C awk "NF { \$1 = \$1 ; gsub( / /, \"_\" ) ; print ; exit ; }" )" "bash -c the-console-wrapper --manager-session-kill --session-id run-w" >> "$RIG_TMP/ps.list" ; bash "$0" --manager-session-kill --session-id run-w > "$RIG_TMP/out" 2> "$RIG_TMP/err" ; echo "rc $?" > "$RIG_TMP/wrapper.said"' "$rigTool" ) < /dev/null > /dev/null 2>&1
rigAssert "the process that called the operation, whose own line reads as a run of that id, is not signalled: it goes on, and the run itself is ended" \
	"$( cat "$rigTmp/wrapper.said" 2> /dev/null ) $( rigOut | LC_ALL=C awk '{ print $3, $5, $7 }' ) $( rigAlive run-w )" "rc 0 run-w ended $( rigPid run-w ) 0"
LC_ALL=C grep -v -e 'the-console-wrapper' "$rigTmp/ps.list" > "$rigTmp/ps.list.next" && mv "$rigTmp/ps.list.next" "$rigTmp/ps.list"

echo "-- 13. the caller rule of the family: never from inside a member's session --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp" --session-id sess-three
rigPre=()
rigAssert "from inside a member's session, magic-coordinator's among them, it is refused in the family's one line, and the run lives" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" ) $( rigAlive sess-three ) $( rigHeader "$rigSp/sess-three/sess-three.spawn.md" killed-by )" "1 0 1 1 "

echo "-- 14. through the real spawn proxy: the supervising shell closes the record, and a killed run is not started again --"
## The stand-in console of the proxy's own runs: it keeps each launch, its pid and when it began, and runs until
## it is released or ended. A launch that resumes (the handback retry) is kept and ends at once, with no handback.
## With `with-word` in its scenario it stands in the rig's process list as a CLI by its own --session-id word;
## without, the run is the process its record names, as for a CLI that is given no such word. With `with-tree`
## it has started a helper server and a tool command with a child of its own before it says that it runs.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > /dev/null' \
	'printf "%s\n" "${MDAT_SPAWN_RESUME:-first}" >> "$RIG_SCENARIO/launches"' \
	'[ -z "${MDAT_SPAWN_RESUME:-}" ] || exit 0' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'rigBegan="$( LC_ALL=C "$RIG_TMP/bin/ps.real" -o lstart= -p $$ | LC_ALL=C awk "NF { \$1 = \$1 ; gsub( / /, \"_\" ) ; print ; exit ; }" )"' \
	'[ ! -e "$RIG_SCENARIO/with-word" ] || printf "%s %s rig-cli --session-id %s\n" "$$" "$rigBegan" "$MDAT_SPAWN_SESSION_ID" >> "$RIG_TMP/ps.list"' \
	'if [ -e "$RIG_SCENARIO/with-tree" ] ; then' \
	'	sleep 300 > /dev/null 2>&1 < /dev/null &' \
	'	echo "$!" > "$RIG_SCENARIO/server.raw"' \
	'	bash -c "sleep 300 > /dev/null 2>&1 < /dev/null & echo \$! > \"\$1\" ; wait" rig-tool "$RIG_SCENARIO/hung.raw" > /dev/null 2>&1 < /dev/null &' \
	'	echo "$!" > "$RIG_SCENARIO/tool.raw"' \
	'	while [ ! -s "$RIG_SCENARIO/hung.raw" ] ; do sleep 1 ; done' \
	'fi' \
	'printf "%s %s\n" "$$" "$rigBegan" > "$RIG_SCENARIO/console.pid"' \
	'rigLeft=120' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'echo finished > "$RIG_SCENARIO/console.done"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigSpawn(){ ## scenario, dispatch document mode (none, create), `with-word` or empty, `with-tree` or empty -- one run that is not waited for; sets rigDir and rigSpawnId
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	[ -z "${3:-}" ] || : > "$rigDir/with-word"
	[ -z "${4:-}" ] || : > "$rigDir/with-tree"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:"$2" --context rig-manager-kill <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 )
	rigSpawnId="$( LC_ALL=C sed -n 's|^OUTPUT_FILE=.*/sessions/\([^/]*\)/session\.log$|\1|p' "$rigDir/proxy.out" | head -1 )"
	rigWaitFor 40 test -s "$rigDir/console.pid" || rigRefuse "the stand-in console never started in scenario $1: $( LC_ALL=C grep -m1 ERROR "$rigDir/proxy.out" )"
	[ -n "$rigSpawnId" ] || rigRefuse "the proxy named no run in scenario $1"
	rigSpawnRecord="$( ls "$rigSp"/*/"$rigSpawnId.spawn.md" 2> /dev/null | head -1 )"
	rigWaitFor 20 rigRunRecorded || rigRefuse "the proxy kept no process on the record of its run in scenario $1"
	if [ -n "${4:-}" ] ; then
		for rigName in server tool hung ; do
			cp "$rigDir/$rigName.raw" "$rigTmp/pids/$1-$rigName" && rigKeep "$( rigPid "$1-$rigName" )" || rigRefuse "the stand-in console started no $rigName in scenario $1"
		done
	fi
	sleep 1
}
rigRunRecorded(){ [ -n "$( rigHeader "$rigSpawnRecord" run-process )" ] ; }
rigConsoleAlive(){ ## -- whether the console of the scenario still runs, as the process it was
	local consolePid consoleBegan
	read -r consolePid consoleBegan < "$rigDir/console.pid" 2> /dev/null || { printf gone ; return 0 ; }
	[ "$( rigBegan "$consolePid" )" = "$consoleBegan" ] && printf alive || printf gone
}
rigRecordClosed(){ case "$( rigHeader "$rigSpawnRecord" status )" in spawn-started|'') return 1 ;; esac ; }
rigLaunches(){ LC_ALL=C tr '\n' ' ' < "$rigDir/launches" 2> /dev/null ; }

## The control: a run that ends by itself with no handback is started once more, by the handback retry.
rigSpawn retry-control none ""
: > "$rigDir/release"
rigWaitFor 60 rigRecordClosed
rigAssert "control: a run that ends by itself with no handback is resumed once by the handback retry, and then its record is closed" "$( rigLaunches )/ $( rigHeader "$rigSpawnRecord" status )" "first true / spawn-succeeded"

## No dispatch item and no transcript: nothing but the run's own record says that it was killed.
rigSpawn kill-bare none with-word
rm -f "$rigStores/$rigSpawnId/transcript"
rigRun "$rigOp" --session-id "$rigSpawnId" --run
rigAssert "a run the proxy started, with no dispatch item and no transcript, found by its own word: ended, and said so" \
	"$rigRc $( rigOut | LC_ALL=C awk '{ print $1, $3, $4, $5, $6, $8 }' ) $( rigConsoleAlive )" "0 kill $rigSpawnId rig-member-a ended spawn-started - gone"
rigWaitFor 60 rigRecordClosed
rigAssert "its supervising shell saw it end and closed its record as failed, the mark of the kill still on it" \
	"$( rigHeader "$rigSpawnRecord" status ) $( rigHeader "$rigSpawnRecord" killed-by ) $( rigHeader "$rigSpawnRecord" killed-at | LC_ALL=C grep -c -x -E "$rigStamped" ) $( [ -n "$( rigHeader "$rigSpawnRecord" resolved-at )" ] && echo resolved )" "spawn-failed rig 1 resolved"
rigAssert "the handback retry did not start the run again: it was launched once, and the shell says why" \
	"$( rigLaunches )/ $( LC_ALL=C grep -c -F -- "no handback retry for spawn $rigSpawnId: its record says it was killed (by rig, " "$rigStores/$rigSpawnId/session.log" )" "first / 1"

## No dispatch item, with a transcript, and no session word: the process its record names.
rigSpawn kill-noitem none ""
rigRun "$rigOp" --session-id "$rigSpawnId"
rigAssert "a run with no session word, by the process its record names: ended, the id of a lone run being its session's too" \
	"$rigRc $( rigOut | LC_ALL=C awk '{ print $1, $2, $3, $5, $8 }' ) $( rigConsoleAlive )" "0 kill $rigSpawnId $rigSpawnId ended - gone"
rigWaitFor 60 rigRecordClosed
rigAssert "its transcript holds the ending under the name of the console's user, its record is closed as failed, and it was launched once" \
	"$( LC_ALL=C grep -h -c -E '^[0-9TZ:-]+ ENDING kind=dismissed by=rig text="manager-kill: ' "$rigData"/audit/*/session-*"${rigSpawnId:0:8}"*.log 2> /dev/null | head -1 ) $( rigHeader "$rigSpawnRecord" status ) $( rigLaunches )" "1 spawn-failed first "

## With a dispatch item: the ending on the item, which its supervising shell then takes to review.
rigSpawn kill-item create with-word with-tree
rigKillItem="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigDir/proxy.out" | head -1 )" ; rigKillItem="${rigKillItem%.md}"
## Its supervising shell is the process the proxy started for it (PID= of its receipt): the one that started
## the console, and the leader of the process group the run is in.
rigShell="$( LC_ALL=C sed -n 's/^PID=//p' "$rigDir/proxy.out" | head -1 )"
read -r rigConsolePid rigConsoleBegan < "$rigDir/console.pid"
rigAssert "control: the run's supervising shell started its console and leads the process group the run and what it started are in, so a signal to that group would end the shell that closes the record" \
	"$( [ -n "$rigShell" ] && [ "$( ps -o ppid= -p "$rigConsolePid" | LC_ALL=C tr -d ' ' )" = "$rigShell" ] && echo started-by-it ) $( for rigName in "$rigConsolePid" "$( rigPid kill-item-server )" "$( rigPid kill-item-hung )" "$rigShell" ; do [ "$( ps -o pgid= -p "$rigName" | LC_ALL=C tr -d ' ' )" = "$rigShell" ] && printf 'in-its-group ' ; done )" "started-by-it in-its-group in-its-group in-its-group in-its-group "
rigRun "$rigOp" --session-id "$rigSpawnId"
rigAssert "a run with a dispatch item: ended, and its row names the item" "$rigRc $( rigOut | LC_ALL=C awk '{ print $1, $3, $5, $8 }' ) $( rigConsoleAlive )" "0 kill $rigSpawnId ended $rigKillItem gone"
rigAssert "what its console had started is gone with it: the helper server, the tool command and that command's own child" "$( rigAlive kill-item-server kill-item-tool kill-item-hung )" "0"
rigItemInReview(){ [ -f "$rigData/board/review/$rigKillItem.md" ] ; }
rigWaitFor 60 rigRecordClosed ; rigWaitFor 40 rigItemInReview
rigAssert "its supervising shell closed the record as failed and took the item to review, where the item holds the ending under the name of the console's user" \
	"$( rigHeader "$rigSpawnRecord" status ) $( rigItemInReview && echo review ) $( rigDecisions "$rigData/board/review/$rigKillItem.md" "rig dismissed: $rigEndText \\($rigSpawnId\\)" )" "spawn-failed review 1"
rigAssert "and it was launched once: a killed run is not started again" "$( rigLaunches )" "first "

echo "-- 15. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntaxLine="📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntax"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s %s' "$rigOp" "$rigSyntax" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntaxLine\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntaxLine" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s %s' "$rigOp" "$rigSyntax" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm="$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(kill <.*>\)`$/\1/p' )"
rigAssert "its entry gives the form of a row" "$rigForm" "kill <session-id> <spawn-id> <member> <outcome> <status> <pids> <item>"
rigFormOf(){ ## row kind -- the form line of that row in the entry
	rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$1"' <.*>\)`$/\1/p'
}
rigAssert "and the forms of the rows that say what the kill of a session finished" "$( rigFormOf dismiss ) | $( rigFormOf close ) | $( rigFormOf finish )" \
	"dismiss <session-id> <pending-id> <asker> <outcome> | close <session-id> <spawn-id> <member> <outcome> <item> | finish <session-id> <ended> <dismissed> <closed> <state>"
rigAssert "and every row this check was given has exactly the fields its form names, each kind its own, and is of one of the four kinds" "$( for rigKind in kill close finish ; do cat "$rigTmp"/out.kept.* 2> /dev/null | LC_ALL=C awk -F'\t' -v wantKind="$rigKind" -v wantFields="$( rigFormOf "$rigKind" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' ; done ) $( cat "$rigTmp"/out.kept.* 2> /dev/null | LC_ALL=C awk -F'\t' '$1 != "kill" && $1 != "dismiss" && $1 != "close" && $1 != "finish" { other++ } END { print other + 0 }' )" "rows:0 rows:0 rows:0  0"
rigAssert "the entry names each outcome, the two marks of the record, the reason of the ending and the two signals" "$( for rigWord in ended killed not-ended no-process other-host no-spawn-id host-unrecorded killed-by killed-at manager-kill ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done ) $( rigEntry | LC_ALL=C grep -c -w -e 'TERM' -e 'KILL' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "y" : "n" }' )" "yyyyyyyyyy y"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntaxLine" "$rigTmp/err" || : )" "0 1"

echo "-- 16. how it is built --"
rigCode(){ ## file -- its lines that are no comment
	LC_ALL=C grep -v '^[[:space:]]*#' "$1"
}
rigAssert "the processes of a run are asked of the one place a run is recognised, when it is signalled and when what is left of it is read, and the family lists no process a second way: the plan of a kill reads a run by the same walk" \
	"$( rigCode "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -c -e 'AgentsToolsRegistryRunProcesses "' -e 'AgentsToolsRegistryRunLeft "' || : ) $( cat "$rigHere"/*/AgentsTools.Manager*.include | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'ps -' -e 'RunWords' -e 'pgrep' -e 'pkill' || : ) $( rigCode "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" | LC_ALL=C grep -c -E '^AgentsToolsRegistryRunProcesses\(\)\{' || : )" "4 0 1"
rigAssert "no process group is signalled, anywhere in the family" "$( cat "$rigHere"/*/AgentsTools.Manager*.include | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E 'kill +(-[A-Za-z0-9]+ +)?(-- +)?"?-[$"]' || : )" "0"
rigAssert "the polite time is set in one place, two seconds" "$( rigCode "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -c -x -e 'agentsManagerKillPoliteSeconds=2' || : )" "1"
rigAssert "the handback retry reads the mark of a kill on the record of its run" "$( rigCode "$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include" | LC_ALL=C grep -c -F -e 'AgentsToolsSpawnSandboxRecordHeader "$1" killed-at' || : )" "1"

echo "-- 17. the kill of a whole session finishes it: its questions dismissed, its open records closed --"
## A question that waits, asked as the tooling opens one: in the thread of its own post, by the team bot.
rigAskNo=0 ; rigPend=""
rigQuestion(){ ## the id that asked, a run's own or a session's -> rigPend, the id of the question
	rigAskNo=$(( rigAskNo + 1 ))
	rigPend="$( printf '# Ask\n\nMay I?\n' | ( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-op-pending-reply-open magic-coordinator --to CRIG00001 --session-id "$1" --kind question \
		--channel CRIG00001 --question-ts "1700000000.0007$( printf '%02d' "$rigAskNo" )" --thread-ts "1700000000.0007$( printf '%02d' "$rigAskNo" )" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' --ask-identity bot 2> /dev/null ) )"
	[ -n "$rigPend" ] || rigRefuse "no pending question could be opened in the rig"
}
## The errors and warnings of the last call, but for the one the dismissal of a question of this rig gives: such a
## question was opened with no post of its own to fill again, and the dismissal says so of each.
rigTroublesButPost(){
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -v -F -- 'SystemContext.SetInputSpec' | LC_ALL=C grep -c -v -F -- 'was not edited: its text could not be filled again from its record' || :
}
rigAsked(){ ## pending id, header -- its value in the record of that question
	rigHeader "$rigAgents/pending/$1.md" "$2"
}
rigStateOf(){ ## session id, further words of the list -- the state its row of the list of sessions reads, `not-listed` where it has none
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --manager-session-list ${2:-} ) 2> /dev/null < /dev/null | LC_ALL=C awk -F'\t' -v wantId="$1" '$1 == "session" && $2 == wantId { print $4 ; found = 1 } END { if ( ! found ) print "not-listed" }'
}
rigRowsOf(){ ## row kind -- the rows of that kind in the last stdout, TAB written as a space, a `/` between them
	LC_ALL=C awk -F'\t' -v wantKind="$1" '$1 == wantKind { gsub( /\t/, " " ) ; printf "%s%s", ( said++ ? " / " : "" ), $0 }' "$rigTmp/out"
}
rigPosted(){ ## text -- how many bodies posted so far hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/bodies" 2> /dev/null || :
}
## A WAITING SESSION, ITS ONE AGENT FINISHED: two questions of it still wait.
rigRec fin-wait fin-wait fin-wait "$rigHost" magic-coordinator spawn-succeeded 40 "resolved-at: 2026-10-13 09:45 +0300"
rigQuestion fin-wait ; rigAskOne="$rigPend"
rigQuestion fin-wait ; rigAskTwo="$rigPend"
rigAssert "control: a session whose one agent has finished and that has two questions waiting reads waiting, and is among the active ones" "$( rigStateOf fin-wait ) $( rigStateOf fin-wait --active ) $( rigAsked "$rigAskOne" status ) $( rigAsked "$rigAskTwo" status )" "waiting waiting reply-pending reply-pending"
rigRun "$rigOp" --session-id fin-wait
rigAssert "the kill of a session with nothing alive is no refusal: status 0, its run told as it stands, each question dismissed, and a last row that sums it: nothing ended, two dismissed, nothing closed, finished" \
	"$rigRc $( rigTroublesButPost ) $( rigRowsOf kill ) | $( LC_ALL=C awk -F'\t' '$1 == "dismiss" { gsub( /\t/, " " ) ; print }' "$rigTmp/out" | LC_ALL=C sed -e "s/$rigAskOne/ASK-ONE/" -e "s/$rigAskTwo/ASK-TWO/" | LC_ALL=C sort | LC_ALL=C tr '\n' '/' ) | $( rigRowsOf close ) | $( rigRowsOf finish )" \
	"0 0 kill fin-wait fin-wait magic-coordinator no-process spawn-succeeded - - | dismiss fin-wait ASK-ONE fin-wait dismissed/dismiss fin-wait ASK-TWO fin-wait dismissed/ |  | finish fin-wait 0 2 0 finished"
rigAssert "each question is withdrawn through the one dismissal of the console: by console:rig, with the reason that its session was killed from the console and by whom, and its trace is in its thread" \
	"$( rigAsked "$rigAskOne" status ) $( rigAsked "$rigAskTwo" status ) $( rigAsked "$rigAskOne" withdrawn-by ) [$( rigAsked "$rigAskTwo" withdraw-reason )] $( rigPosted 'the session was killed from the console by rig' )" \
	"withdrawn withdrawn console:rig [the session was killed from the console by rig] 2"
rigAssert "the session reads finished, and has left the active ones" "$( rigStateOf fin-wait ) $( rigStateOf fin-wait --active )" "finished not-listed"
## AN UNCLOSED SESSION: a record left open, no process behind it, nobody to close it.
rigRec fin-open fin-open fin-open "$rigHost" magic-coordinator spawn-started 41 "spawns: dispatch-rig-fin-open
session-thread: CRIG00001:1700000000.000941"
rigItem dispatch-rig-fin-open fin-open fin-open ; rigTranscript fin-open
rigAssert "control: a session with an open record and no process reads unclosed" "$( rigStateOf fin-open )" "unclosed"
rigRun "$rigOp" --session-id fin-open
rigAssert "its record is closed: one close row, with the item the ending is recorded on, and the sum: nothing ended, nothing dismissed, one closed, finished" \
	"$rigRc $( rigTroubles ) $( rigRowsOf kill ) | $( rigRowsOf close ) | $( rigRowsOf finish )" \
	"0 0 kill fin-open fin-open magic-coordinator no-process spawn-started - - | close fin-open fin-open magic-coordinator closed dispatch-rig-fin-open | finish fin-open 0 0 1 finished"
rigAssert "the record is closed as a run that ended without its close, marked as killed from the console, by whom and when; its ending is on its item, once, and the item is where a closed run's item goes" \
	"$( rigHeader "$rigSp/fin-open/fin-open.spawn.md" status ) $( rigHeader "$rigSp/fin-open/fin-open.spawn.md" killed-by ) $( rigHeader "$rigSp/fin-open/fin-open.spawn.md" killed-at | LC_ALL=C grep -c -E "^$rigStamped\$" ) $( rigDecisions "$rigData/board/review/dispatch-rig-fin-open.md" "rig dismissed: $rigEndText \\(fin-open\\)" ) $( [ -e "$rigData/board/running/dispatch-rig-fin-open.md" ] && echo still-running || echo moved )" \
	"spawn-ended-without-close rig 1 1 moved"
rigAssert "what is told of it says that its record was closed from the console, and not that a process was killed" "$( rigPosted 'had ended and left its record open: the record was closed from the console by rig' ) $( LC_ALL=C grep -F -- 'fin-open' "$rigTmp/bodies" | LC_ALL=C grep -c -F -- 'was killed from the console' )" "1 0"
rigAssert "the session reads finished" "$( rigStateOf fin-open ) $( rigStateOf fin-open --active )" "finished not-listed"
## A RUNNING SESSION WITH A QUESTION: its run is ended, its question dismissed, its record closed.
rigRec fin-run fin-run fin-run "$rigHost" magic-coordinator spawn-started 42 "spawns: dispatch-rig-fin-run
session-thread: CRIG00001:1700000000.000942"
rigItem dispatch-rig-fin-run fin-run fin-run ; rigTranscript fin-run ; rigLive fin-run
rigQuestion fin-run ; rigAskRun="$rigPend"
rigRun "$rigOp" --session-id fin-run
rigAssert "a running session with a question: its run is ended, its question dismissed, its record, which no shell is left to close, closed, and the sum says one of each, finished" \
	"$rigRc $( rigTroublesButPost ) $( rigRowsOf kill ) | $( rigRowsOf dismiss | LC_ALL=C sed "s/$rigAskRun/ASK-RUN/" ) | $( rigRowsOf close ) | $( rigRowsOf finish ) | $( rigAlive fin-run )" \
	"0 0 kill fin-run fin-run magic-coordinator ended spawn-started $( rigPid fin-run ) dispatch-rig-fin-run | dismiss fin-run ASK-RUN fin-run dismissed | close fin-run fin-run magic-coordinator closed dispatch-rig-fin-run | finish fin-run 1 1 1 finished | 0"
rigAssert "its ending is recorded once, and it is told as a run that was killed, which it was" \
	"$( rigDecisions "$rigData/board/review/dispatch-rig-fin-run.md" "rig dismissed: $rigEndText \\(fin-run\\)" ) $( rigEndings fin-run "ENDING item=dispatch-rig-fin-run kind=dismissed by=rig text=\"$rigEndText\"" ) $( LC_ALL=C grep -F -- 'fin-run' "$rigTmp/bodies" | LC_ALL=C grep -c -F -- 'was killed from the console by rig' ) $( rigAsked "$rigAskRun" status ) $( rigStateOf fin-run )" "1 1 1 withdrawn finished"
## NEVER TWICE: a second kill finds nothing left.
rigPostsBefore="$( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/calls" )"
rigRun "$rigOp" --session-id fin-run
rigAssert "a second kill of the same session finds nothing left and says so with zeros, status 0: nothing is dismissed, closed, recorded or told a second time" \
	"$rigRc $( rigRowsOf kill ) | $( rigRowsOf dismiss ) | $( rigRowsOf close ) | $( rigRowsOf finish ) | $( rigDecisions "$rigData/board/review/dispatch-rig-fin-run.md" "rig dismissed: $rigEndText \\(fin-run\\)" ) $(( $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/calls" ) - rigPostsBefore ))" \
	"0 kill fin-run fin-run magic-coordinator no-process spawn-ended-without-close - - |  |  | finish fin-run 0 0 0 finished | 1 0"
## A FINISHED SESSION with nothing pending.
rigRec fin-done fin-done fin-done "$rigHost" magic-coordinator spawn-succeeded 43 "resolved-at: 2026-10-13 09:50 +0300"
rigRun "$rigOp" --session-id fin-done
rigAssert "a session that is finished with nothing pending answers with its run as it stands and the summing row, zeros, status 0" "$rigRc $( rigRowsOf kill ) | $( rigRowsOf finish ) | $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/out" )" \
	"0 kill fin-done fin-done magic-coordinator no-process spawn-succeeded - - | finish fin-done 0 0 0 finished | 2"
## THE PLAN: the same rows, and nothing done.
rigRec fin-plan fin-plan fin-plan "$rigHost" magic-coordinator spawn-started 44 "spawns: dispatch-rig-fin-plan"
rigRec fin-plan plan-b fin-plan "$rigHost" keeper-rig spawn-started 45 ""
rigItem dispatch-rig-fin-plan fin-plan fin-plan ; rigTranscript fin-plan ; rigLive fin-plan
rigQuestion plan-b ; rigAskPlan="$rigPend"
rigPostsBefore="$( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/calls" )"
rigRun "$rigOp" --session-id fin-plan --plan
rigAssert "--plan prints what a kill would do, in the rows a kill prints, and a last row that sums it with the state as it is now: one run to end, one question to dismiss, two records to close" \
	"$rigRc $( rigTroubles ) $( rigRowsOf kill ) | $( rigRowsOf dismiss | LC_ALL=C sed "s/$rigAskPlan/ASK-PLAN/" ) | $( rigRowsOf close ) | $( rigRowsOf finish )" \
	"0 0 kill fin-plan fin-plan magic-coordinator would-end spawn-started $( rigPid fin-plan ) - / kill fin-plan plan-b keeper-rig no-process spawn-started - - | dismiss fin-plan ASK-PLAN plan-b would-dismiss | close fin-plan fin-plan magic-coordinator would-close - / close fin-plan plan-b keeper-rig would-close - | finish fin-plan 1 1 2 running"
rigAssert "and does nothing: the run lives, the question waits, both records are open and unmarked, nothing was posted" \
	"$( rigAlive fin-plan ) $( rigAsked "$rigAskPlan" status ) $( rigHeader "$rigSp/fin-plan/fin-plan.spawn.md" status ) $( rigHeader "$rigSp/fin-plan/plan-b.spawn.md" status ) [$( rigHeader "$rigSp/fin-plan/fin-plan.spawn.md" killed-by )] $(( $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/calls" ) - rigPostsBefore )) $( rigStateOf fin-plan )" \
	"1 reply-pending spawn-started spawn-started [] 0 running"
## ONE RUN ALONE: as before, and the questions that very run asked are dismissed with it.
rigQuestion fin-plan ; rigAskFounder="$rigPend"
rigRec fin-plan plan-c fin-plan "$rigHost" keeper-rig spawn-started 46 "" ; rigLive plan-c
rigQuestion plan-c ; rigAskPart="$rigPend"
rigRun "$rigOp" --session-id plan-c --run
rigAssert "the kill of one run ends that run and dismisses the questions that very run asked, with the reason that the run that asked was killed; no record is closed and no sum is printed" \
	"$rigRc $( rigRowsOf kill | LC_ALL=C awk '{ print $2, $3, $5 }' ) | $( rigRowsOf dismiss | LC_ALL=C sed "s/$rigAskPart/ASK-PART/" ) | $( rigRowsOf close ) | $( rigRowsOf finish ) | [$( rigAsked "$rigAskPart" withdraw-reason )]" \
	"0 fin-plan plan-c ended | dismiss fin-plan ASK-PART plan-c dismissed |  |  | [the run that asked it was killed from the console by rig]"
rigAssert "the other runs of its session and their questions are as they were: the founder lives, its question and that of the run with no process wait, and the record of the killed run is left open" \
	"$( rigAlive fin-plan ) $( rigAsked "$rigAskFounder" status ) $( rigAsked "$rigAskPlan" status ) $( rigHeader "$rigSp/fin-plan/plan-c.spawn.md" status ) $( rigStateOf fin-plan )" "1 reply-pending reply-pending spawn-started running"
rigRun "$rigOp" --session-id fin-plan
rigAssert "and the kill of that whole session then ends its founder, dismisses the two questions that are left, closes its three records and leaves it finished" \
	"$rigRc $( rigRowsOf finish ) $( rigAsked "$rigAskFounder" status ) $( rigAsked "$rigAskPlan" status ) $( rigStateOf fin-plan ) $( rigStateOf fin-plan --active )" "0 finish fin-plan 1 2 3 finished withdrawn withdrawn finished not-listed"
rigAssert "every row of what a kill finished has the fields its form names: the rows of the questions it dismissed too" "$( cat "$rigTmp"/out.kept.* 2> /dev/null | LC_ALL=C awk -F'\t' -v wantFields="$( rigFormOf dismiss | LC_ALL=C awk '{ print NF }' )" '$1 == "dismiss" { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' )" "rows:0"

echo "-- 18. a run with no spawn-id in its record is finished like any other: closed, or the call says it could not --"
rigRecBare(){ ## sandbox folder, file stem, session id, owner, started-at (a date and a time) -- the record of a run written with no spawn-id: it is found by its session
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nstarted-at: %s +0300\nreports-to: %s\n---\n\n# Spawn session: %s\n' "$3" "$1" "$rigHost" "$4" "$5" "$rigConsoleUser" "$3" > "$rigSp/$1/$2.spawn.md"
}
## A LONE RUN, FOUNDERLESS, OLD: one record named by its session, no spawn-id, nothing runs as it.
rigRecBare lone-ns lone-ns lone-ns magic-coordinator "2026-09-30 10:28"
rigAssert "control: a lone run whose record has no spawn-id, left open for weeks with nothing alive, reads unclosed, among the active sessions" "$( rigStateOf lone-ns ) $( rigStateOf lone-ns --active )" "unclosed unclosed"
rigRun "$rigOp" --session-id lone-ns
grep DEBUG "$rigTmp/err" | cut -c1-600 >&2
rigAssert "the kill of that session closes its record: one close row, closed, and a sum that says nothing ended, nothing dismissed, one closed, finished; status 0 and nothing else said" \
	"$rigRc $( rigTroubles ) | $( rigRowsOf close ) | $( rigRowsOf finish )" "0 0 | close lone-ns lone-ns magic-coordinator closed - | finish lone-ns 0 0 1 finished"
rigAssert "the record is closed as a run that ended without its close, marked as closed from the console, and the session has left the active ones" \
	"$( rigHeader "$rigSp/lone-ns/lone-ns.spawn.md" status ) $( rigHeader "$rigSp/lone-ns/lone-ns.spawn.md" killed-by ) $( rigStateOf lone-ns ) $( rigStateOf lone-ns --active )" "spawn-ended-without-close rig finished not-listed"
rigRun "$rigOp" --session-id lone-ns
rigAssert "a second kill of it finds nothing left: the sum of zeros, status 0" "$rigRc $( rigRowsOf close ) | $( rigRowsOf finish )" "0  | finish lone-ns 0 0 0 finished"
## A FOUNDERLESS RUN WITH A MEMBER THAT JOINED: both records closed, and the question of the lone one dismissed.
rigRecBare join-ns join-ns join-ns magic-coordinator "2026-10-01 08:00"
rigRec join-ns join-b join-ns "$rigHost" keeper-rig spawn-started 47 ""
rigQuestion join-ns ; rigAskJoin="$rigPend"
rigRun "$rigOp" --session-id join-ns
rigAssert "a session whose founder has no spawn-id and that a member joined: both records are closed, its question dismissed, finished" \
	"$rigRc $( rigRowsOf finish ) $( rigAsked "$rigAskJoin" status ) $( rigHeader "$rigSp/join-ns/join-ns.spawn.md" status ) $( rigHeader "$rigSp/join-ns/join-b.spawn.md" status ) $( rigStateOf join-ns )" \
	"0 finish join-ns 0 1 2 finished withdrawn spawn-ended-without-close spawn-ended-without-close finished"
## A RECORD THE KILL CANNOT FIND: its file is not named by its session. The call does not report success: it says which, and fails.
mkdir -p "$rigSp/odd-ns"
printf -- '---\nsession-id: odd-ns\ntracking-name: odd-ns\nhost: %s\nowner: magic-coordinator\nstatus: spawn-started\nstarted-at: 2026-09-29 09:00 +0300\nreports-to: %s\n---\n\n# Spawn session: odd-ns\n' "$rigHost" "$rigConsoleUser" > "$rigSp/odd-ns/some-other-name.spawn.md"
rigRun "$rigOp" --session-id odd-ns
rigAssert "a run whose record it cannot find to close: status 1, a close row that says not-closed, the state it still reads, and an error that names the session; nothing is reported as done" \
	"$rigRc | $( rigRowsOf close ) | $( rigRowsOf finish ) | $( LC_ALL=C grep -c -F -- 'session odd-ns still reads unclosed after it' "$rigTmp/err" || : ) $( rigStateOf odd-ns )" \
	"1 | close odd-ns odd-ns magic-coordinator not-closed - | finish odd-ns 0 0 0 unclosed | 1 unclosed"
rigRun "$rigOp" --session-id odd-ns --plan
rigAssert "the plan of it is no failure: its rows and the state, status 0" "$rigRc $( rigRowsOf finish )" "0 finish odd-ns 0 0 0 unclosed"
## A CHECKLIST IN THE FOLDER: <member>.checklist.md, which the CheckList tool keeps in the sandbox of a session, is no record of a run.
## Every record of the session is closed and the folder holds one: the session reads finished, and its kill has nothing to close. (Seen
## on a session whose kill failed, "a record of it could not be closed": the file stood in the registry as a run with no spawn-id,
## no member and no status, which reads unclosed for ever.)
rigRec chk-ns chk-ns chk-ns "$rigHost" magic-coordinator spawn-succeeded 20 "resolved-at: 2026-10-13 09:40 +0300"
rigRec chk-ns chk-b chk-ns "$rigHost" magic-devops spawn-succeeded 21 "resolved-at: 2026-10-13 09:41 +0300"
printf -- '- [x] an item done\n- [ ] an item not yet\n' > "$rigSp/chk-ns/magic-coordinator.checklist.md"
rigAssert "control: a session whose records are all closed, with a checklist in its folder, reads finished, and is not among the active ones" "$( rigStateOf chk-ns ) $( rigStateOf chk-ns --active )" "finished not-listed"
rigAssert "the checklist is no run of the session: its list names the two runs of the records and no other" "$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" bash "$rigTool" --manager-session-list 2> /dev/null < /dev/null | LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "chk-ns" { print $7 }' )" "2"
rigRun "$rigOp" --session-id chk-ns
rigAssert "the kill of it ends well: status 0 and nothing else said, nothing ended, dismissed or closed, the session finished" \
	"$rigRc $( rigTroubles ) | $( rigRowsOf close ) | $( rigRowsOf finish )" "0 0 |  | finish chk-ns 0 0 0 finished"
## ANY OTHER TYPE OF FILE: a record is a <spawn id>.spawn.md, found by its name alone (those of the sections above with no spawn-id too);
## a file of another type (<name>.<type>.md) is none, whatever it holds: a backlog is no run, and the session reads finished.
rigRec note-ns note-ns note-ns "$rigHost" magic-coordinator spawn-succeeded 22 "resolved-at: 2026-10-13 09:42 +0300"
printf -- '---\nsession-id: note-ns\nstatus: spawn-started\n---\n\n# a backlog\n' > "$rigSp/note-ns/notes.backlog.md"
rigAssert "control: a session whose records are all closed, with a notes.backlog.md in its folder (even one that carries a session-id and an open status), reads finished" "$( rigStateOf note-ns ) $( rigStateOf note-ns --active )" "finished not-listed"
rigRun "$rigOp" --session-id note-ns
rigAssert "the kill of it ends well: status 0 and nothing else said, nothing closed, the session finished" \
	"$rigRc $( rigTroubles ) | $( rigRowsOf close ) | $( rigRowsOf finish )" "0 0 |  | finish note-ns 0 0 0 finished"
## THE STORED REGISTRY OF AN EARLIER BUILD: it holds the checklist as a row of its own, as the code that took every .md wrote it (all
## columns `-`, the session's tracking name first). The registry is rebuilt at the next call, for the folder now has fewer records than the
## registry has rows of it, and the session reads finished: no repair of the stored data is needed.
rigRec old-ns old-ns old-ns "$rigHost" magic-coordinator spawn-succeeded 23 "resolved-at: 2026-10-13 09:43 +0300"
rigRec old-ns old-b old-ns "$rigHost" magic-devops spawn-succeeded 24 "resolved-at: 2026-10-13 09:44 +0300"
printf -- '- [x] an item done\n' > "$rigSp/old-ns/magic-coordinator.checklist.md"
rigStateOf old-ns > /dev/null
printf 'old-ns - - - - - - - - - - - - - - -\n' >> "$rigAgents/spawned-sessions.registry"
rigAssert "control: the registry holds the old row of the checklist, a run with no session-id" "$( LC_ALL=C awk '$1 == "old-ns" && $2 == "-" { rows++ } END { print rows + 0 }' "$rigAgents/spawned-sessions.registry" )" "1"
rigAssert "the session reads finished at once, and the old row is gone from the registry" "$( rigStateOf old-ns ) $( LC_ALL=C awk '$1 == "old-ns" && $2 == "-" { rows++ } END { print rows + 0 }' "$rigAgents/spawned-sessions.registry" )" "finished 0"
printf 'old-ns - - - - - - - - - - - - - - -\n' >> "$rigAgents/spawned-sessions.registry"
rigRun "$rigOp" --session-id old-ns
rigAssert "its kill, on the registry as the earlier build left it: status 0 and nothing else said, the sum of zeros, finished" \
	"$rigRc $( rigTroubles ) | $( rigRowsOf close ) | $( rigRowsOf finish )" "0 0 |  | finish old-ns 0 0 0 finished"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION KILL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_KILL: OK (%d assertions, offline)\n' "$rigPasses"
