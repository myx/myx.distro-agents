#!/usr/bin/env bash
## Behavioural check on --manager-session-read --session-id <id> [--run], the console's read of one coworking
## session or of one run of it, run rather than read, against a rig workspace built here: its own spawn sandboxes
## and records, its own asks, the stores of its own runs, and a process list of its own -- a ps first on PATH lists
## the rig's runs only, so no process of the host is ever seen.
## Held: the whole output, byte for byte. For the id of a session: its `session` row and each `run` row exactly as
## the list prints them, with the name, the state and working or waiting; one `dispatch` row, what the session was
## started for, from its founder's record -- the routine, the dispatch item, the two threads and the description --
## and `no-record` where a client founded the session; one `control` row, the control thread of the session: the
## state it stored and when, read from the session's folder at every call, whether it lives -- `alive`, `gone` or
## `none`, as the `session` row says it in its three last fields -- and the process that is said of; then under
## each run a `header` row for every header of its
## record, as it stands, and one `store` row: whether it has a store, its model and tokens, its open asks, its
## marks, its last milestone with its time, what its stored wait waits on, who dismissed it, and where its session
## log and its transcript lie, `-` for each thing a run with no store cannot have. For the own id of a run that
## joined a session: that run alone, under the rows of the session it belongs to; --run takes the id as a run's
## own, which is how the founder is read alone. A free text is exact: a TAB written \t and a backslash \\. An id
## that names nothing is one error line and status 1. THE REGISTRIES ARE READ AS THEY LIE, while they hold the
## store as it is now: a call that finds them so rewrites neither. One is rebuilt first where it is missing, where
## spawned-sessions does not hold every sandbox folder with as many records as the folder has now, or holds no row
## of the id, and where pending-replies does not hold every ask by its name, or says another status of an ask of
## the session than the ask's record. No time is compared: A MEMBER THAT JOINS A RUNNING SESSION, its record added
## to the folder the session already has, is in the next read, with every time made older than the registry; so
## is a session started since, an ask asked since, and an ask answered. What a record of the session says, a
## status that moved among it, is read from the record at every call, and no registry is rewritten for that.
## Nothing else of the workspace is written, and no scratch file is left. Another session's record and store,
## made unreadable, change nothing.
## A call from inside a member's session is refused, as every operation of the family is. And the help pair,
## with the six row forms the output is checked against. A fake `curl` first on PATH would log a request: none
## is made. Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-read"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.test.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.test.sh"
rigTmp="$( mktemp -d -t AgentsManagerSessionReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every stand-in of a control thread this check starts: at its end each is ended, while it is still itself.
rigStarted=""
trap 'rigProcSignal KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigPend="$rigAgents/pending" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigPend" "$rigStores" "$rigHome" "$rigSkills" "$rigData/audit"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"

## THE RIG'S OWN PROCESS LIST, as in AgentsManagerSessionListCheck: the ps first on PATH answers the whole-host
## listing from the rig's own list and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigRecord(){ ## sandbox, record name -- stdin: the header lines of the record, as they are to stand
	mkdir -p "$rigSp/$1"
	{ printf -- '---\n' ; cat ; printf -- '---\n\n# Spawn session\n' ; } > "$rigSp/$1/$2.md"
}
rigAsk(){ ## record name, the id of the run that asked, status
	printf -- '---\nstatus: %s\nowner: keeper-rig\nsession-id: %s\nkind: question\n---\nq\n' "$3" "$2" > "$rigPend/$1.md"
}
rigLive(){ ## spawn id... -- the rig's process list: each a run by its own --session-id word
	local liveId livePid=900100
	: > "$rigTmp/ps.list"
	for liveId in "$@" ; do
		livePid=$(( livePid + 1 ))
		printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$livePid" "$liveId" >> "$rigTmp/ps.list"
	done
}
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRows(){ ## row kind -- the rows of that kind in the last output, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantKind="$1" '$1 == wantKind { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigPrint(){ ## file -- its inode and the sum of its bytes; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	printf '%s:%s\n' "$( ls -i "$1" | LC_ALL=C awk '{ print $1 ; exit }' )" "$( cksum < "$1" | LC_ALL=C tr -s ' \t' '-' )"
}
rigOthers(){ ## -- every file of the rig workspace but the two session registries, each with the sum of its bytes, as one sum
	( cd "$rigWs" && find . -type f ! -name spawned-sessions.registry ! -name pending-replies.registry | LC_ALL=C sort | while IFS= read -r othersFile ; do printf '%s %s\n' "$othersFile" "$( cksum < "$othersFile" )" ; done ) | cksum
}

## THE STORES. One session of three: its founder, live and inside a Wait; a member, live and working; a member that
## closed and was dismissed. The founder's description holds a TAB and a backslash.
{
	printf 'session-id: sess-a\nspawn-id: sess-a\nparent-session-id: none\nhost: %s\nworkspace: rigws\ncli: claude-native\nowner: magic-coordinator\n' "$rigHost"
	printf 'routine: magic-team.daily.routine\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\n'
	printf 'agent-log-thread: CTRACK:1.000100\nsession-thread: CSESS:2.000200\n'
	printf 'description: Run the daily\tof Monday, and keep C:\\notes.\n'
	printf 'session-comment: daily of Monday\nspawns: dispatch-20261013T060000Z-spawn-proxy-1\n'
} | rigRecord sess-a sess-a
{
	printf 'session-id: sess-a\nspawn-id: run-b\nparent-session-id: sess-a\nparent-member: magic-coordinator\nhost: %s\nworkspace: rigws\ncli: grok-harness\nowner: keeper-rig\n' "$rigHost"
	printf 'status: spawn-started\nstarted-at: 2026-10-13 09:05 +0300\nagent-log-thread: CTRACK:1.000100\nsession-thread: CSESS:2.000200\n'
	printf 'description: Answer the daily.\nspawns: dispatch-20261013T060500Z-spawn-proxy-2\n'
} | rigRecord run-b run-b
{
	printf 'session-id: sess-a\nspawn-id: run-c\nparent-session-id: sess-a\nhost: %s\nworkspace: rigws\ncli: claude-native\nowner: magic-tester\n' "$rigHost"
	printf 'status: spawn-succeeded\nexit-code: 0\nstarted-at: 2026-10-13 09:10 +0300\nresolved-at: 2026-10-13 09:40 +0300\n'
} | rigRecord run-c run-c
## A lone run that closed and has no folder under sessions/.
printf 'session-id: sess-n\nspawn-id: sess-n\nhost: %s\nworkspace: rigws\nowner: magic-librarian\nstatus: spawn-failed\nexit-code: 3\nstarted-at: 2026-10-12 08:00 +0300\nresolved-at: 2026-10-12 08:30 +0300\n' "$rigHost" | rigRecord sess-n sess-n
## A session a desktop client founded: only its members have records.
printf 'session-id: sess-desk\nspawn-id: desk-b\nparent-session-id: sess-desk\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-succeeded\nstarted-at: 2026-10-11 10:00 +0300\nresolved-at: 2026-10-11 10:30 +0300\nagent-log-thread: CTRACK:5.000500\nsession-thread: CSESS:6.000600\n' "$rigHost" | rigRecord desk-b desk-b
printf 'session-id: sess-desk\nspawn-id: desk-c\nparent-session-id: sess-desk\nhost: %s\nworkspace: rigws\nowner: magic-tester\nstatus: spawn-started\nstarted-at: 2026-10-11 10:05 +0300\n' "$rigHost" | rigRecord desk-c desk-c
rigAsk ask-1 sess-a reply-pending
rigAsk ask-2 run-b reply-pending
rigAsk ask-3 run-b reply-pending
rigAsk ask-4 run-c reply-received
rigLive sess-a run-b
## The founder's store: inside a Wait (its wait/state one second older than its last line), a model, tokens, a
## session log, and a transcript in the team data.
mkdir -p "$rigStores/sess-a/wait"
printf '2026-10-13T06:00:02Z start\n2026-10-13T07:05:00Z message out\n2026-10-13T07:15:19Z wait going idle\n' > "$rigStores/sess-a/milestones"
printf 'sources: slack:CSESS:2.000200:conversation  inbox:magic-coordinator \naddressee: \ninclude-own: false\n' > "$rigStores/sess-a/wait/state"
TZ=UTC touch -t 202610130715.18 "$rigStores/sess-a/wait/state"
printf 'claude-sonnet-5\n' > "$rigStores/sess-a/model"
printf '608 87390597 685590 0\n' > "$rigStores/sess-a/tokens"
printf 'a line of the log\n' > "$rigStores/sess-a/session.log"
printf '2026-10-13T06:00:02Z START session=sess-a member=magic-coordinator\n' > "$rigData/audit/session-a.log"
printf '%s\n' "$rigData/audit/session-a.log" > "$rigStores/sess-a/transcript"
## The live member's: working, a model, a session log, no tokens, no wait, no transcript.
mkdir -p "$rigStores/run-b"
printf '2026-10-13T06:05:03Z start\n2026-10-13T07:20:00Z message out\n' > "$rigStores/run-b/milestones"
printf 'grok-4\n' > "$rigStores/run-b/model"
printf 'another line\n' > "$rigStores/run-b/session.log"
## The closed member's: dismissed, with its handback given and its end marked; its transcript pointer names a
## file that is gone.
mkdir -p "$rigStores/run-c"
printf '2026-10-13T06:10:01Z start\n2026-10-13T06:39:58Z end\n' > "$rigStores/run-c/milestones"
printf 'magic-coordinator (the daily is over)\n' > "$rigStores/run-c/dismissed"
: > "$rigStores/run-c/dismissed.handback"
: > "$rigStores/run-c/ended"
printf '%s\n' "$rigData/audit/gone.log" > "$rigStores/run-c/transcript"

rigSessionRow="$( printf 'session\tsess-a\tdaily_of_Monday\trunning\t2026-10-13_09:00_+0300\t-\t3\trunning=2,finished=1\t-\t-\tnone' )"
rigControlRow="$( printf 'control\tsess-a\t-\t-\tnone\t-' )"
rigDispatchRow="$( printf 'dispatch\tsess-a\trecord\tmagic-coordinator\tmagic-team.daily.routine\tdispatch-20261013T060000Z-spawn-proxy-1\tCSESS:2.000200\tCTRACK:1.000100\tRun the daily\\tof Monday, and keep C:\\\\notes.' )"
rigFounderRows="$( {
	printf 'run\tsess-a\tsess-a\tmagic-coordinator\tspawn-started\trunning\trunning\t2026-10-13_09:00_+0300\t-\t%s\trigws\twaiting\n' "$rigHost"
	printf 'header\tsess-a\tsession-id\tsess-a\nheader\tsess-a\tspawn-id\tsess-a\nheader\tsess-a\tparent-session-id\tnone\nheader\tsess-a\thost\t%s\nheader\tsess-a\tworkspace\trigws\nheader\tsess-a\tcli\tclaude-native\nheader\tsess-a\towner\tmagic-coordinator\n' "$rigHost"
	printf 'header\tsess-a\troutine\tmagic-team.daily.routine\nheader\tsess-a\tstatus\tspawn-started\nheader\tsess-a\tstarted-at\t2026-10-13 09:00 +0300\n'
	printf 'header\tsess-a\tagent-log-thread\tCTRACK:1.000100\nheader\tsess-a\tsession-thread\tCSESS:2.000200\n'
	printf 'header\tsess-a\tdescription\tRun the daily\\tof Monday, and keep C:\\\\notes.\n'
	printf 'header\tsess-a\tsession-comment\tdaily of Monday\nheader\tsess-a\tspawns\tdispatch-20261013T060000Z-spawn-proxy-1\n'
	printf 'store\tsess-a\tstore\tclaude-sonnet-5\t608\t87390597\t685590\t0\task-1\t-\t2026-10-13T07:15:19Z\twait going idle\tslack:CSESS:2.000200:conversation inbox:magic-coordinator\t-\t%s\t%s\n' "$rigStores/sess-a/session.log" "$rigData/audit/session-a.log"
} )"
rigMemberRows="$( {
	printf 'run\tsess-a\trun-b\tkeeper-rig\tspawn-started\trunning\trunning\t2026-10-13_09:05_+0300\t-\t%s\trigws\tworking\n' "$rigHost"
	printf 'header\trun-b\tsession-id\tsess-a\nheader\trun-b\tspawn-id\trun-b\nheader\trun-b\tparent-session-id\tsess-a\nheader\trun-b\tparent-member\tmagic-coordinator\nheader\trun-b\thost\t%s\nheader\trun-b\tworkspace\trigws\nheader\trun-b\tcli\tgrok-harness\nheader\trun-b\towner\tkeeper-rig\n' "$rigHost"
	printf 'header\trun-b\tstatus\tspawn-started\nheader\trun-b\tstarted-at\t2026-10-13 09:05 +0300\nheader\trun-b\tagent-log-thread\tCTRACK:1.000100\nheader\trun-b\tsession-thread\tCSESS:2.000200\n'
	printf 'header\trun-b\tdescription\tAnswer the daily.\nheader\trun-b\tspawns\tdispatch-20261013T060500Z-spawn-proxy-2\n'
	printf 'store\trun-b\tstore\tgrok-4\t-\t-\t-\t-\task-2,ask-3\t-\t2026-10-13T07:20:00Z\tmessage out\t-\t-\t%s\t-\n' "$rigStores/run-b/session.log"
} )"
rigClosedRows="$( {
	printf 'run\tsess-a\trun-c\tmagic-tester\tspawn-succeeded\tno-process\tfinished\t2026-10-13_09:10_+0300\t2026-10-13_09:40_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'header\trun-c\tsession-id\tsess-a\nheader\trun-c\tspawn-id\trun-c\nheader\trun-c\tparent-session-id\tsess-a\nheader\trun-c\thost\t%s\nheader\trun-c\tworkspace\trigws\nheader\trun-c\tcli\tclaude-native\nheader\trun-c\towner\tmagic-tester\n' "$rigHost"
	printf 'header\trun-c\tstatus\tspawn-succeeded\nheader\trun-c\texit-code\t0\nheader\trun-c\tstarted-at\t2026-10-13 09:10 +0300\nheader\trun-c\tresolved-at\t2026-10-13 09:40 +0300\n'
	printf 'store\trun-c\tstore\t-\t-\t-\t-\t-\t-\tdismissed,dismissed.handback,ended\t2026-10-13T06:39:58Z\tend\t-\tmagic-coordinator (the daily is over)\t-\t-\n'
} )"

echo "-- 1. the id of a session: the session, what it was started for, and each participant in full --"
rigAssert "control: no registry is there before the first call" "$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "no-file no-file"
rigOthersBefore="$( rigOthers )"
rigRun "$rigOp" --session-id sess-a
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: the session, its dispatch, its control thread, then each run with the headers of its record and its store, the earliest started first" "$( cat "$rigTmp/out" )" "$rigSessionRow
$rigDispatchRow
$rigControlRow
$rigFounderRows
$rigMemberRows
$rigClosedRows"
rigAssert "the id of a session shows its participants with their states: the session's state and name, and one line for each of the three with its member, its state and working or waiting" \
	"$( rigRows session | LC_ALL=C awk '{ print $3, $4 }' ) / $( rigRows run | LC_ALL=C awk '{ printf "%s:%s:%s ", $4, $7, $NF }' )" "daily_of_Monday running / magic-coordinator:running:waiting keeper-rig:running:working magic-tester:finished:- "
rigAssert "each participant has its CLI, its model and its tokens: the CLI a header of its record, the model and the four token counts of its store" \
	"$( LC_ALL=C awk -F'\t' '$1 == "header" && $3 == "cli" { printf "%s=%s ", $2, $4 } $1 == "store" { printf "%s=%s/%s,%s,%s,%s ", $2, $4, $5, $6, $7, $8 }' "$rigTmp/out" )" "sess-a=claude-native sess-a=claude-sonnet-5/608,87390597,685590,0 run-b=grok-harness run-b=grok-4/-,-,-,- run-c=claude-native run-c=-/-,-,-,- "
rigAssert "what the session was started for is its founder's: the routine, the dispatch item, the session thread, the tracking thread, and the description, exact" \
	"$( LC_ALL=C awk -F'\t' '$1 == "dispatch" { print $3 "|" $4 "|" $5 "|" $6 "|" $7 "|" $8 "|" $9 }' "$rigTmp/out" )" 'record|magic-coordinator|magic-team.daily.routine|dispatch-20261013T060000Z-spawn-proxy-1|CSESS:2.000200|CTRACK:1.000100|Run the daily\tof Monday, and keep C:\\notes.'
rigAssert "a free text is one field: the TAB of the description is written \\t and its backslash \\\\, so every row has the fields of its kind and no line is of another kind" \
	"$( LC_ALL=C awk -F'\t' '{ want = ( $1 == "session" ) ? 11 : ( $1 == "dispatch" ) ? 9 : ( $1 == "control" ) ? 6 : ( $1 == "run" ) ? 12 : ( $1 == "header" ) ? 4 : ( $1 == "store" ) ? 16 : -1 ; if ( NF != want ) bad++ ; } END { print NR ":" bad + 0 }' "$rigTmp/out" )" "49:0"
rigAssert "a dismissed run shows its mark, and who dismissed it" "$( LC_ALL=C awk -F'\t' '$1 == "store" && $2 == "run-c" { print $10 " | " $14 }' "$rigTmp/out" )" "dismissed,dismissed.handback,ended | magic-coordinator (the daily is over)"
rigAssert "a run shows its last milestone with its time, what its stored wait waits on, and the ids of its open asks; a closed ask is none" \
	"$( LC_ALL=C awk -F'\t' '$1 == "store" { printf "%s[%s|%s|%s|%s] ", $2, $11, $12, $13, $9 }' "$rigTmp/out" )" "sess-a[2026-10-13T07:15:19Z|wait going idle|slack:CSESS:2.000200:conversation inbox:magic-coordinator|ask-1] run-b[2026-10-13T07:20:00Z|message out|-|ask-2,ask-3] run-c[2026-10-13T06:39:58Z|end|-|-] "
rigAssert "the paths of a run's session log and transcript are given where the files are, and a transcript whose file is gone is -" \
	"$( LC_ALL=C awk -F'\t' '$1 == "store" { printf "%s[%s|%s] ", $2, $15, $16 }' "$rigTmp/out" )" "sess-a[$rigStores/sess-a/session.log|$rigData/audit/session-a.log] run-b[$rigStores/run-b/session.log|-] run-c[-|-] "

echo "-- 2. the own id of a run --"
rigRun "$rigOp" --session-id run-b
rigAssert "the id of a member that joined a session shows that run alone -- its record, its state and its store -- under the rows of the session it belongs to" "$rigRc $( cat "$rigTmp/out" )" "0 $rigSessionRow
$rigDispatchRow
$rigControlRow
$rigMemberRows"
rigRun "$rigOp" --session-id sess-a --run
rigAssert "--run takes the id as a run's own: the founder alone, whose id is its session's" "$rigRc $( cat "$rigTmp/out" )" "0 $rigSessionRow
$rigDispatchRow
$rigControlRow
$rigFounderRows"
rigRun "$rigOp" --run --session-id run-c
rigAssert "and for a run that joined, --run changes nothing" "$rigRc $( cat "$rigTmp/out" )" "0 $rigSessionRow
$rigDispatchRow
$rigControlRow
$rigClosedRows"

echo "-- 3. a session whose founder has no record --"
rigRun "$rigOp" --session-id sess-desk
rigAssert "it ends 0 and prints the members, and one line says that the founder has no record; the threads are those its members carry" "$rigRc $( rigRows session ) / $( rigRows dispatch ) / $( rigRows run | LC_ALL=C awk '{ printf "%s:%s:%s ", $3, $4, $7 }' )" \
	"0 session sess-desk - unclosed 2026-10-11_10:00_+0300 - 2 unclosed=1,finished=1 - - none / dispatch sess-desk no-record - - - CSESS:6.000600 CTRACK:5.000500 - / desk-b:keeper-rig:finished desk-c:magic-tester:unclosed "
rigRun "$rigOp" --session-id sess-desk --run
rigAssert "its id is no run's own: with --run it names nothing, one error line and status 1" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no record of this workspace carries 'sess-desk' as the own id of a run -- nothing is shown" ) $( rigTroubles )" "1 0 1 1"

echo "-- 4. a run with no store --"
rigRun "$rigOp" --session-id sess-n
rigAssert "control: the record has no folder under sessions/" "$( [ -e "$rigStores/sess-n" ] && echo store || echo no-store )" "no-store"
rigAssert "the fields of the record are printed, each header as it stands" "$rigRc $( rigRows header | LC_ALL=C awk '{ printf "%s=%s ", $3, $4 }' )" "0 session-id=sess-n spawn-id=sess-n host=$rigHost workspace=rigws owner=magic-librarian status=spawn-failed exit-code=3 started-at=2026-10-12 resolved-at=2026-10-12 "
rigAssert "and - for the milestone, the sources of the wait and the marks, as for everything a store holds" "$( rigRows store )" "store sess-n no-store - - - - - - - - - - - - -"
rigAssert "its session is itself, finished, and it has no founder but itself" "$( rigRows session ) / $( rigRows dispatch )" "session sess-n - finished 2026-10-12_08:00_+0300 2026-10-12_08:30_+0300 1 finished=1 - - none / dispatch sess-n record magic-librarian - - - - -"

echo "-- 5. an id that names nothing, and what the operation takes --"
rigRun "$rigOp" --session-id no-such-id
rigAssert "the read of a session refuses an id that names nothing: one error line, status 1, nothing on stdout" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no record of this workspace carries 'no-such-id' as the id of a session or the own id of a run -- nothing is shown" ) $( rigTroubles )" "1 0 1 1"
rigRun "$rigOp"
rigAssert "with no --session-id it is refused in one line with its syntax" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is --session-id <id> [--run], got no --session-id" )" "1 0 1"
rigRun "$rigOp" --session-id
rigAssert "and so is --session-id with no id" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --session-id needs an id -- syntax is --session-id <id> [--run]" )" "1 1"
rigRun "$rigOp" --session-id sess-a --all
rigAssert "and an argument it does not take" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is --session-id <id> [--run], got: --all" )" "1 0 1"
rigRun "$rigOp" sess-a
rigAssert "a bare word is no id: the second word of the operation is its own argument, refused by the operation itself" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is --session-id <id> [--run], got: sess-a" )" "1 1"

echo "-- 6. the registries are read as they lie --"
rigAssert "the first call found no registry and built both: a missing registry is rebuilt first" "$( LC_ALL=C awk 'NF == 16 { whole++ } END { print NR ":" whole + 0 }' "$rigAgents/spawned-sessions.registry" ) $( LC_ALL=C awk 'END { print NR + 0 }' "$rigAgents/pending-replies.registry" )" "6:6 4"
rigAssert "nothing else of the workspace was written by any call so far, and no scratch file is left" "$( rigOthers ) $( find "$rigWs/.local/temp" -type f 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' )" "$rigOthersBefore 0"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigRun "$rigOp" --session-id sess-a
rigAssert "a call that finds the registries fresh rewrites neither: both are the files they were" "$rigRc $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "0 $rigRegBefore"
## Another session's record and store are made unreadable: a read of one session opens neither.
chmod 000 "$rigSp/sess-n/sess-n.md" "$rigSp/desk-c/desk-c.md" ; chmod 000 "$rigStores/run-c"
rigRun "$rigOp" --session-id run-b
rigAssert "the records of other sessions, and the store of another run, made unreadable, change nothing in the read of one run: no error, no warning" "$rigRc $( rigTroubles ) $( cat "$rigTmp/out" )" "0 0 $rigSessionRow
$rigDispatchRow
$rigControlRow
$rigMemberRows"
chmod 644 "$rigSp/sess-n/sess-n.md" "$rigSp/desk-c/desk-c.md" ; chmod 755 "$rigStores/run-c"

echo "-- 7. a registry is taken as it lies only while it holds the store as it is now, whatever the clock says --"
## Every time below is set by hand, so that no comparison of times could tell: the registries read newer than
## everything in the store, as they do for a change made in the second they were built.
rigOld(){ ## path... -- each made older than any registry of this rig
	TZ=UTC touch -t 202610010000.00 "$@"
}
rigNoneNewer(){ ## registry file, path... -- none-newer where no path is newer than the registry by its time
	local newerRegistry="$1" newerPath newerSeen="none-newer"
	shift
	for newerPath in "$@" ; do [ ! "$newerPath" -nt "$newerRegistry" ] || newerSeen="newer:$newerPath" ; done
	printf '%s\n' "$newerSeen"
}
## A session started since the registry was built: a sandbox folder and an ask the registries do not hold.
printf 'session-id: sess-late\nspawn-id: sess-late\nhost: %s\nworkspace: rigws\nowner: magic-coordinator\nstatus: spawn-succeeded\nstarted-at: 2026-10-07 06:00 +0300\nresolved-at: 2026-10-07 06:30 +0300\nsession-comment: late one\n' "$rigHost" | rigRecord sess-late sess-late
rigAsk ask-late sess-late reply-pending
rigOld "$rigSp/sess-late/sess-late.md" "$rigSp/sess-late" "$rigSp" "$rigPend/ask-late.md" "$rigPend"
rigAssert "control: nothing of the two stores is newer than its registry, and the registries hold no row of the new session or its ask" "$( rigNoneNewer "$rigAgents/spawned-sessions.registry" "$rigSp" "$rigSp/sess-late" "$rigSp/sess-late/sess-late.md" ) $( rigNoneNewer "$rigAgents/pending-replies.registry" "$rigPend" "$rigPend/ask-late.md" ) $( cat "$rigAgents/spawned-sessions.registry" "$rigAgents/pending-replies.registry" | LC_ALL=C grep -c -e 'sess-late' || : )" "none-newer none-newer 0"
rigRun "$rigOp" --session-id sess-late
rigAssert "a session started after the last rebuild is read: a registry that does not hold a sandbox folder the store has now is rebuilt first, and the asks' one that does not hold an ask, so the session waits on the ask written with it" "$rigRc $( rigRows session ) / $( rigRows store | LC_ALL=C awk '{ print $9 }' )" "0 session sess-late late_one waiting 2026-10-07_06:00_+0300 - 1 finished=1 - - none / ask-late"
## A registry that reads newer than everything, by a time years ahead, and still does not hold a folder.
printf 'session-id: sess-missed\nspawn-id: sess-missed\nhost: %s\nworkspace: rigws\nowner: magic-coordinator\nstatus: spawn-succeeded\nstarted-at: 2026-10-06 06:00 +0300\nresolved-at: 2026-10-06 06:30 +0300\n' "$rigHost" | rigRecord sess-missed sess-missed
TZ=UTC touch -t 203001010000.00 "$rigAgents/spawned-sessions.registry"
rigRun "$rigOp" --session-id sess-missed
rigAssert "a registry years newer than the store by its time is not taken for that: it does not hold the folder, so it is rebuilt, and the session is read" "$rigRc $( rigRows session ) $( LC_ALL=C grep -c -e 'sess-missed' "$rigAgents/spawned-sessions.registry" || : )" "0 session sess-missed - finished 2026-10-06_06:00_+0300 2026-10-06_06:30_+0300 1 finished=1 - - none 1"
## A MEMBER JOINS A RUNNING SESSION: its record is added to the sandbox folder the session already has, which is
## where a spawn that joins a session by its id keeps it. No folder is new, and the id has its rows already.
printf 'session-id: sess-a\nspawn-id: run-j\nparent-session-id: sess-a\nhost: %s\nworkspace: rigws\ncli: claude-native\nowner: magic-librarian\nstatus: spawn-started\nstarted-at: 2026-10-13 09:20 +0300\n' "$rigHost" | rigRecord sess-a run-j
rigOld "$rigSp/sess-a/run-j.md" "$rigSp/sess-a" "$rigSp"
rigLive sess-a run-b run-j
rigAssert "control: the member's record stands in the session's own folder, nothing there is newer than the registry, and the registry holds the session and not the member" "$( ls "$rigSp/sess-a" | LC_ALL=C tr '\n' ' ' )$( rigNoneNewer "$rigAgents/spawned-sessions.registry" "$rigSp" "$rigSp/sess-a" "$rigSp/sess-a/run-j.md" "$rigSp/sess-a/sess-a.md" ) $( LC_ALL=C awk '$2 == "sess-a" { rows++ } $8 == "run-j" { joined++ } END { print rows + 0 ":" joined + 0 }' "$rigAgents/spawned-sessions.registry" )" "run-j.md sess-a.md none-newer 3:0"
rigRun "$rigOp" --session-id sess-a
rigAssert "a member that joined a running session after the registry was built is in the next read of that session: the session counts four runs, three of them running, and the member has its row, the headers of its record and its store row" \
	"$rigRc $( rigRows session | LC_ALL=C awk '{ print $7, $8 }' ) / $( rigRows run | LC_ALL=C awk '{ printf "%s ", $3 }' )/ $( rigRows run | LC_ALL=C awk '$3 == "run-j"' ) / $( LC_ALL=C awk -F'\t' '$1 == "header" && $2 == "run-j" { headers++ } $1 == "store" && $2 == "run-j" { print headers + 0, $3 }' "$rigTmp/out" )" \
	"0 4 running=3,finished=1 / sess-a run-b run-c run-j / run sess-a run-j magic-librarian spawn-started running running 2026-10-13_09:20_+0300 - $rigHost rigws working / 9 no-store"
rigAssert "and the registry was rebuilt for it: it holds the member now" "$( LC_ALL=C awk '$2 == "sess-a" { rows++ } $8 == "run-j" { joined++ } END { print rows + 0 ":" joined + 0 }' "$rigAgents/spawned-sessions.registry" )" "4:1"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigRun "$rigOp" --session-id sess-a
rigAssert "the read after it changes nothing: where the registries hold the store as it is, neither is rewritten" "$rigRc $( rigRows session | LC_ALL=C awk '{ print $7 }' ) $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "0 4 $rigRegBefore"
## A RECORD THAT CHANGED IN PLACE, with no new file: the member closes, as the spawner closes a record.
{
	printf 'session-id: sess-a\nspawn-id: run-b\nparent-session-id: sess-a\nparent-member: magic-coordinator\nhost: %s\nworkspace: rigws\ncli: grok-harness\nowner: keeper-rig\n' "$rigHost"
	printf 'status: spawn-succeeded\nexit-code: 0\nstarted-at: 2026-10-13 09:05 +0300\nresolved-at: 2026-10-13 09:50 +0300\n'
} > "$rigTmp/run-b.closed"
{ printf -- '---\n' ; cat "$rigTmp/run-b.closed" ; printf -- '---\n\n# Spawn session\n' ; } > "$rigSp/run-b/run-b.md"
rigOld "$rigSp/run-b/run-b.md" "$rigSp/run-b"
rigLive sess-a run-j
rigAssert "control: the record is not newer than the registry, which still says the member is started" "$( rigNoneNewer "$rigAgents/spawned-sessions.registry" "$rigSp/run-b/run-b.md" "$rigSp/run-b" ) $( LC_ALL=C awk '$8 == "run-b" { print $6 }' "$rigAgents/spawned-sessions.registry" )" "none-newer spawn-started"
rigRun "$rigOp" --session-id sess-a
rigAssert "what a record of the session says is read from the record at every call: the member reads finished, with the date it closed, and the session's tally follows" "$rigRc $( rigRows session | LC_ALL=C awk '{ print $4, $8 }' ) $( rigRows run | LC_ALL=C awk '$3 == "run-b" { print $5, $6, $7, $9, $NF }' )" "0 running running=2,finished=2 spawn-succeeded no-process finished 2026-10-13_09:50_+0300 -"
rigAssert "and no registry is rewritten for that: the file is the one it was" "$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "$rigRegBefore"
## AN ASK THAT CHANGED: the founder's is answered, its record put in place as a close puts it, and a new one is asked.
rigAsk ask-1 sess-a reply-received
rigOld "$rigPend/ask-1.md" "$rigPend"
rigAssert "control: the ask is not newer than its registry, which still says it waits for a reply" "$( rigNoneNewer "$rigAgents/pending-replies.registry" "$rigPend/ask-1.md" "$rigPend" ) $( LC_ALL=C awk '$1 == "ask-1.md" { print $5 }' "$rigAgents/pending-replies.registry" )" "none-newer reply-pending"
rigRun "$rigOp" --session-id sess-a
rigAssert "an ask of the session that was answered is no open ask in the next read: its status is read from its record, and the asks' registry is rebuilt where it says another" "$rigRc $( rigRows store | LC_ALL=C awk '{ printf "%s=%s ", $2, $9 }' )$( LC_ALL=C awk '$1 == "ask-1.md" { print $5 }' "$rigAgents/pending-replies.registry" )" "0 sess-a=- run-b=ask-2,ask-3 run-c=- run-j=- reply-received"
rigAsk ask-9 run-j reply-pending
rigOld "$rigPend/ask-9.md" "$rigPend"
rigRun "$rigOp" --session-id sess-a
rigAssert "and an ask asked since is one: the asks' registry is rebuilt where it does not hold an ask the store has now" "$rigRc $( rigNoneNewer "$rigAgents/pending-replies.registry" "$rigPend/ask-9.md" ) $( rigRows store | LC_ALL=C awk '$2 == "run-j" { print $9 }' )" "0 none-newer ask-9"
: > "$rigTmp/ps.list"
rigRun "$rigOp" --session-id sess-a
rigAssert "with no live process the session reads waiting, on the open asks of its runs, and its founder waiting with no activity: live is measured at each call and never stored" "$rigRc $( rigRows session | LC_ALL=C awk '{ print $4 }' ) $( rigRows run | LC_ALL=C awk '$3 == "sess-a" { print $6, $7, $NF }' )" "0 waiting no-process waiting -"
rigLive sess-a

echo "-- 8. the caller rule, and the place of the operation --"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigOp" --session-id sess-a
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family, and nothing was rebuilt" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" ) $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "1 0 1 $rigRegBefore"
rigAssert "the operation is one arm of the include of the sessions, and asks nobody who calls" "$( LC_ALL=C grep -c -x -e "	$rigOp)" "$rigHere/AgentsTools.ManagerSession.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerSession.include" | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 0"
rigAssert "the rows of the one session are measured in the one place a row's live and state are derived, once, and no run is found a second way: no process list, no rule of its own, and the store is listed by its names to hold the registry to it, never walked for a run" \
	"$( LC_ALL=C awk '/^AgentsToolsManagerSessionScope\(\)\{/ { on = 1 } on { print } on && /^\}/ { exit }' "$rigHere/AgentsTools.ManagerSession.include" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'AgentsToolsRegistryMeasureRows "' || : ) $( cat "$rigHere"/AgentsTools.Manager*.include "$rigHere/AgentsManagerSessionRows.awk" "$rigHere/AgentsManagerSessionRead.awk" "$rigHere/AgentsManagerSessionScope.awk" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'ps -' -e 'spawned"/\*' -e 'RunWords' || : ) $( LC_ALL=C awk '/^AgentsToolsManagerSessionScope\(\)\{/ { on = 1 } on { print } on && /^\}/ { exit }' "$rigHere/AgentsTools.ManagerSession.include" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e ' -nt ' -e ' -ot ' || : )" "1 0 0"

echo "-- 9. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp --session-id <id> [--run]"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s --session-id <id> [--run]' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s --session-id <id> [--run]' "$rigOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp " "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp " "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm(){ ## row kind -- the form line of that row in the entry, its back quotes and its indent taken off
	rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$1"' <.*>\)`$/\1/p'
}
rigAssert "its entry gives the form of each of the six rows" "$( rigForm session ) | $( rigForm dispatch ) | $( rigForm control ) | $( rigForm run ) | $( rigForm header ) | $( rigForm store )" \
	"session <session-id> <name> <state> <started-at> <state-at> <run-count> <state-tally> <session-state> <session-state-at> <control-thread> | dispatch <session-id> <founder> <member> <routine> <dispatch-item> <session-thread> <tracking-thread> <description> | control <session-id> <session-state> <session-state-at> <control-thread> <control-pid> | run <session-id> <spawn-id> <member> <status> <live> <state> <started-at> <resolved-at> <host> <workspace> <activity> | header <spawn-id> <name> <value> | store <spawn-id> <store> <model> <tokens-in> <tokens-cache-read> <tokens-cache-write> <tokens-out> <open-asks> <marks> <milestone-at> <milestone> <wait-sources> <dismissed-by> <session-log> <transcript>"
rigRun "$rigOp" --session-id sess-a
rigAssert "and every row printed has exactly the fields its form names" "$( for rigKind in session dispatch control run header store ; do LC_ALL=C awk -F'\t' -v wantKind="$rigKind" -v wantFields="$( rigForm "$rigKind" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" ; done )" "rows:0 rows:0 rows:0 rows:0 rows:0 rows:0 "
rigAssert "the session and run rows have the forms the entry of the list gives them, word for word" "$( rigForm session ) | $( rigForm run )" "$( LC_ALL=C sed -n -e 's/^[[:space:]]*`\(session <.*>\)`$/\1/p' -e 's/^[[:space:]]*`\(run <.*>\)`$/\1/p' "$rigHelpMd" | LC_ALL=C awk 'NR == 1 { first = $0 } NR == 2 { print first " | " $0 }' )"
rigAssert "the entry says how a free text is written, what --run is for, and what is not told apart" "$( for rigWord in '\t' '\\' '--run' 'no-record' 'no-store' 'working' ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyy"
rigAssert "control: the entry was cut up to the next operation's heading" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C grep -c -e '^		--' || : )" "1 0"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

echo "-- 10. the control thread of the session: its row --"
## A stand-in of a control thread: a process of this rig's own that only waits, noted with when it began.
## Sets rigStandPid, and rigStandNamed: `<pid> <start>`, as a thread names itself in its pid file and its lock.
rigStandPid="" ; rigStandNamed=""
rigStand(){
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	rigStandNamed="$( rigProcBegan "$rigStandPid" )"
}
rigGone(){ ## pid -- ends that stand-in, and waits until it is no process any more; prints gone or still-there
	local goneLeft=50
	rigProcSignal KILL "$1"
	while [ -n "$( rigProcBegan "$1" )" ] && [ "$goneLeft" -gt 0 ] ; do sleep 0.2 ; goneLeft=$(( goneLeft - 1 )) ; done
	if [ -z "$( rigProcBegan "$1" )" ] ; then echo gone ; else echo still-there ; fi
}
rigControlRows(){ ## -- the `control` rows of the last output, TAB written as a space, and how many there are
	printf '%s / %s\n' "$( rigRows control )" "$( rigRows control | LC_ALL=C awk 'END { print NR + 0 }' )"
}
rigRun "$rigOp" --session-id sess-n
rigAssert "a session that never had a control thread has its one control row all the same: no state, no date, none and no process" "$rigRc $( [ -e "$rigStores/sess-n/control" ] && echo control || echo no-control ) $( rigControlRows )" "0 no-control control sess-n - - none - / 1"
rigStand ; rigLivePid="$rigStandPid" ; rigLiveNamed="$rigStandNamed"
mkdir -p "$rigStores/sess-a/control"
printf 'state: running\nstate-at: 2026-10-13 10:21 +0300\nreason: a run of the session is alive on this host\n' > "$rigStores/sess-a/control/state"
printf '%s\n' "$rigLiveNamed" > "$rigStores/sess-a/control/pid"
ln -s "$rigLiveNamed" "$rigStores/sess-a/control/lock"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigRun "$rigOp" --session-id sess-a
rigAssert "the read of one session prints its control row: the stored state, its date, alive and the process id of the thread" "$rigRc $( rigTroubles ) $( rigControlRows )" "0 0 control sess-a running 2026-10-13_10:21_+0300 alive $rigLivePid / 1"
rigAssert "the control row stands after the dispatch row and before the first run, and the session row ends with the same three" "$( LC_ALL=C awk -F'\t' '{ printf "%s ", $1 } NR == 3 { exit }' "$rigTmp/out" )/ $( rigRows session | LC_ALL=C awk '{ print $9, $10, $11 }' )" "session dispatch control / running 2026-10-13_10:21_+0300 alive"
rigAssert "the state was read from the session's folder at this call, with its records: the registry held none of it, and was not rewritten for it" "$( LC_ALL=C awk '$2 == "sess-a" { printf "%s %s ", $15, $16 }' "$rigAgents/spawned-sessions.registry" )/ $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "- - - - - - - - / $rigRegBefore"
rigRun "$rigOp" --session-id run-b
rigAssert "the read of one run of the session carries the control row of its session" "$rigRc $( rigControlRows )" "0 control sess-a running 2026-10-13_10:21_+0300 alive $rigLivePid / 1"
printf 'state: finished\nstate-at: 2026-10-13 10:58 +0300\nreason: no run of the session is alive and every record of it is closed\n' > "$rigStores/sess-a/control/state.rig" && mv -f "$rigStores/sess-a/control/state.rig" "$rigStores/sess-a/control/state"
rigRun "$rigOp" --session-id sess-a
rigAssert "a state that moved is in the next read, beside the derived state, which is as it was: neither changes the other" "$( rigRows session | LC_ALL=C awk '{ print $4, $9, $10 }' ) / $( rigControlRows )" "running finished 2026-10-13_10:58_+0300 / control sess-a finished 2026-10-13_10:58_+0300 alive $rigLivePid / 1"
rigAssert "control: the stand-in of the thread is ended, and is no process any more" "$( rigGone "$rigLivePid" )" "gone"
rigRun "$rigOp" --session-id sess-a
rigAssert "a control thread that was killed reads gone, and the row still names the process its pid file names" "$rigRc $( rigControlRows )" "0 control sess-a finished 2026-10-13_10:58_+0300 gone $rigLivePid / 1"
printf 'no process is named here\n' > "$rigStores/sess-a/control/pid" ; rm -f "$rigStores/sess-a/control/lock"
rigRun "$rigOp" --session-id sess-a
rigAssert "a pid file that names no process reads gone, with - for the process" "$rigRc $( rigTroubles ) $( rigControlRows )" "0 0 control sess-a finished 2026-10-13_10:58_+0300 gone - / 1"
rm -rf "$rigStores/sess-a/control"
rigRun "$rigOp" --session-id sess-a
rigAssert "and with the folder control/ gone the session reads as one that never had a thread" "$rigRc $( rigControlRows ) / $( rigRows session | LC_ALL=C awk '{ print $9, $10, $11 }' )" "0 control sess-a - - none - / 1 / - - none"

echo "-- 11. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_READ: OK (%d assertions, offline)\n' "$rigPasses"
