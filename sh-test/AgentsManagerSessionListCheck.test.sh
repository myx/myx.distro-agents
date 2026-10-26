#!/usr/bin/env bash
## Behavioural check on --manager-session-list [--active], the first operation of the console's own family
## --manager-*, run rather than read, against a rig workspace built here: its own spawn sandboxes and records, its
## own asks, the stores of its own runs, and a process list of its own -- a ps first on PATH lists the rig's runs
## only, so no process of the host is ever seen, and an uptime beside it gives the rig's own load figure.
## Held: the whole output, byte for byte -- one `session` row a coworking session with its name, its state, its
## start, the date of its state, the count of its runs and the tally of their states; after it one `run` row for
## each of its runs, the earliest started first; the sessions by start date, the newest first, whatever offset
## each date was written with; one `counters` row last. A session reads what its agents read: running while a
## run of it has a live process and not every live one sits in a Wait; waiting while every live one sits in one,
## or while a run of it waits on an answer, or while a question it or a run of it asked is still open;
## unknown-foreign with an open record of another host, else unclosed, else finished. An open ask is what
## waits, whoever asked it -- a run withdraws its own when its record closes, so no session of this rig has
## one left behind -- and only a finished one has the date of its state. A record with no spawn id, an empty
## sandbox and a session of another host are rows.
## --active keeps the sessions that are not finished and can be acted on from this host, those that read running,
## waiting or unclosed, and the counters count the whole workspace either way. A live run counts
## as waiting when the last line of its milestones is `wait going idle` and its wait/state is older than that
## line or was never written, and as working otherwise; an ended run is not counted. The open asks are counted
## from the store, the paused sessions read 0. The call rebuilds both session registries, a record written after
## the last rebuild among them, and writes nothing else. A workspace with no session store prints the counters
## row alone and one note. THE STATE A CONTROL THREAD STORED, AND WHETHER THAT THREAD LIVES: three more fields at
## the end of each `session` row, after the eight of step one, which stand where they stood. The stored state and
## its date are what control/state in the session's folder holds, as the registry stored them at this rebuild, `-`
## in both for a session with none; it stands beside the state derived here, and where the two differ neither is
## changed. The control thread reads `alive` while the process its pid file or its lock names is still that
## process, `gone` where one of the two stands and names no such process -- one that is no more, or a pid
## another process has taken, begun at another time -- and `none` where neither stands. It is measured at each
## call and is in no registry: a thread that ends between two calls reads gone at the second, with the registry's
## state as it was. The stand-ins of a thread are processes of this rig's own, noted with when they began and
## ended through the rig's process helper. THE CALLER RULE, asked once where the family is dispatched: a call from no member's
## session runs, and one from inside a member's session, magic-coordinator's among them, is refused in one line
## and changes nothing. The second word of a --manager-* operation is never taken for a member to bring. And the
## help pair, with the three row forms the output is checked against. A fake `curl` first on PATH would log a
## request: none is made. Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-list"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionListCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every stand-in of a control thread this check starts: at its end each is ended, while it is still itself.
rigStarted=""
trap 'rigProcSignal KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigPend="$rigAgents/pending" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigPend" "$rigStores" "$rigHome" "$rigSkills"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigTab="$( printf '\t' )"

## THE RIG'S OWN PROCESS LIST, as in AgentsRegistryRowsDiffCheck: the ps first on PATH answers the whole-host
## listing from the rig's own list, one `<pid> <command line>` line a process, and hands every other call to the
## real ps. And the rig's own load: an uptime that prints the line this host's uptime prints, with the rig's figures.
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
printf '#!/bin/sh\ncat "${0%%/*}/../uptime.line" 2> /dev/null\n' > "$rigTmp/bin/uptime"
## And the rig's own hostname. The short name is the host's own, as every record of this rig says it. The full
## name, `-f`, is the rig's: by default that short name and `.rig.invalid`; with a word in hostname.mode it does
## not resolve, answers `localhost`, or is slow, waiting until hostname.release is there. Every `-f` is counted in
## hostname.asked. The plain name is the line of hostname.plain, the short name where that file is not there.
ln -s "$( command -v hostname )" "$rigTmp/bin/hostname.real" || rigRefuse "no hostname on PATH to hand the short name to"
cat > "$rigTmp/bin/hostname" <<'RIGHOSTNAME'
#!/bin/sh
rigHostnameDir="${0%/*}/.."
case "$*" in
	-s) exec "${0%/*}/hostname.real" -s ;;
	-f)
		echo asked >> "$rigHostnameDir/hostname.asked"
		case "$( cat "$rigHostnameDir/hostname.mode" 2> /dev/null )" in
			unresolved) echo "hostname: nodename nor servname provided, or not known" >&2 ; exit 1 ;;
			localhost) echo localhost ; exit 0 ;;
			slow)
				trap 'echo ended >> "$rigHostnameDir/hostname.ended" ; exit 143' TERM
				rigHostnameTurns=0
				while [ ! -e "$rigHostnameDir/hostname.release" ] && [ "$rigHostnameTurns" -lt 300 ] ; do sleep 0.1 ; rigHostnameTurns=$(( rigHostnameTurns + 1 )) ; done
				echo slow.rig.invalid ; exit 0
			;;
		esac
		echo "$( "${0%/*}/hostname.real" -s ).rig.invalid" ; exit 0
	;;
	'')
		[ ! -f "$rigHostnameDir/hostname.plain" ] || { cat "$rigHostnameDir/hostname.plain" ; exit 0 ; }
		exec "${0%/*}/hostname.real" -s
	;;
esac
exit 1
RIGHOSTNAME
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 3.25 2.00 1.00\n' > "$rigTmp/uptime.line"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/uptime" "$rigTmp/bin/hostname" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v uptime )" = "$rigTmp/bin/uptime" ] && [ "$( command -v hostname )" = "$rigTmp/bin/hostname" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps, uptime, hostname and curl are not first on PATH, so this check would read the host's process list, ask its resolver or issue a real request"
## The full name of this host, as the rig's hostname says it, and the file the tooling keeps it in.
rigFull="$rigHost.rig.invalid"
rigKept="$rigHome/.agents/magic-team/host-full-name"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigRec(){ ## sandbox, record name, session id, spawn id ("" for none), host, owner, status, started-at ("" for none), resolved-at ("" for none), session-comment ("" for none)
	mkdir -p "$rigSp/$1"
	{
		printf -- '---\nsession-id: %s\n' "$3"
		[ -z "$4" ] || printf 'spawn-id: %s\n' "$4"
		printf 'host: %s\nworkspace: rigws\nowner: %s\nstatus: %s\n' "$5" "$6" "$7"
		[ -z "$8" ] || printf 'started-at: %s\n' "$8"
		[ -z "$9" ] || printf 'resolved-at: %s\n' "$9"
		[ -z "${10}" ] || printf 'session-comment: %s\n' "${10}"
		printf -- '---\n\n# Spawn session: %s\n' "$3"
	} > "$rigSp/$1/$2.spawn.md"
}
rigAsk(){ ## record name, session id, status
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
rigStore(){ ## spawn id, last milestone line ("" for no milestones file), wait/state time as touch -t takes it, in UTC ("" for no wait/state)
	mkdir -p "$rigStores/$1"
	[ -z "$2" ] || printf '2026-10-13T07:00:00Z start\n2026-10-13T07:05:00Z message out\n%s\n' "$2" > "$rigStores/$1/milestones"
	[ -z "$3" ] || { mkdir -p "$rigStores/$1/wait" && printf 'sources: slack:session-current\n' > "$rigStores/$1/wait/state" && TZ=UTC touch -t "$3" "$rigStores/$1/wait/state" ; }
}
rigPre=()
rigRunIn(){ ## workspace, tool arguments... -- one dispatcher call from that workspace; rc in rigRc, stdout in out, stderr in err
	local runWs="$1" ; shift
	rigRc=0
	( cd "$runWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRun(){ ## tool arguments... -- in the rig workspace
	rigRunIn "$rigWs" "$@"
}
rigRows(){ ## row kind -- the rows of that kind in the last output, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantKind="$1" '$1 == wantKind { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigRowOf(){ ## row kind, the id in its second or third field -- that row, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantKind="$1" -v wantId="$2" '$1 == wantKind && ( ( wantKind == "session" && $2 == wantId ) || ( wantKind == "run" && $3 == wantId ) ) { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
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

## THE STORES. Every date is another minute, and two of a session are written with another offset, so the
## order by the text of a date and the order by its time differ.
rigRec sess-run2 sess-run2 sess-run2 sess-run2 "$rigHost" magic-coordinator spawn-started '2026-10-13 10:00 +0300' '' ''
rigRec run-d run-d sess-run2 run-d "$rigHost" keeper-rig spawn-started '2026-10-13 10:02 +0300' '' ''
rigRec run-e run-e sess-run2 run-e "$rigHost" magic-tester spawn-started '2026-10-13 10:01 +0300' '' ''
rigRec sess-run sess-run sess-run sess-run "$rigHost" magic-coordinator spawn-started '2026-10-13 09:00 +0300' '' ''
rigRec run-c run-c sess-run run-c "$rigHost" magic-developer spawn-started '2026-10-13 09:05 +0300' '' ''
rigRec run-b run-b sess-run run-b "$rigHost" magic-tester spawn-succeeded '2026-10-13 09:10 +0300' '2026-10-13 09:40 +0300' 'daily of Monday'
rigRec sess-fin sess-fin sess-fin sess-fin "$rigHost" magic-coordinator spawn-succeeded '2026-10-12 16:57 +0300' '2026-10-12 18:00 +0300' ''
rigRec sess-fin fin-b sess-fin fin-b "$rigHost" keeper-rig spawn-failed '2026-10-12 16:10 +0200' '2026-10-12 17:30 +0200' ''
rigRec sess-ask sess-ask sess-ask sess-ask "$rigHost" magic-coordinator spawn-started '2026-10-11 12:00 +0300' '' ''
rigRec sess-askrun sess-askrun sess-askrun sess-askrun "$rigHost" magic-coordinator spawn-succeeded '2026-10-11 11:00 +0300' '2026-10-11 11:55 +0300' ''
rigRec run-asker run-asker sess-askrun run-asker "$rigHost" keeper-rig spawn-succeeded '2026-10-11 11:20 +0300' '2026-10-11 11:50 +0300' ''
rigRec sess-foreign sess-foreign sess-foreign sess-foreign elsewhere magic-coordinator spawn-started '2026-10-10 10:00 +0300' '' ''
rigRec sess-foreign for-b sess-foreign for-b elsewhere keeper-rig spawn-started '2026-10-10 10:05 +0300' '' ''
rigRec sess-nospawn old sess-nospawn '' "$rigHost" magic-librarian spawn-succeeded '2026-10-09 08:00 +0300' '2026-10-09 08:30 +0300' ''
rigRec sess-unclosed sess-unclosed sess-unclosed sess-unclosed "$rigHost" magic-coordinator spawn-started '2026-10-08 07:00 +0300' '' ''
mkdir -p "$rigSp/box-empty"
## Two open asks and five closed ones: of a session, of a session with no record; and the ones of runs that
## finished are closed, since a run settles its own questions when its record closes.
rigAsk ask-1 sess-ask reply-pending
rigAsk ask-2 run-asker reply-received
rigAsk ask-3 root-with-no-record reply-pending
rigAsk ask-4 sess-fin reply-received
rigAsk ask-5 sess-unclosed withdrawn
rigAsk ask-6 fin-b reply-unknown
rigAsk ask-7 sess-run reply-received
## The live runs, and the store of each: no milestones; inside a Wait, its wait/state one second older than the
## line; the wait ended, the state one second newer; a `wait going idle` and no wait/state at all; another last
## line. And an ended run whose store looks like a wait.
rigLive sess-run sess-run2 run-c run-d run-e
rigStore sess-run '' ''
rigStore sess-run2 '2026-10-13T07:15:19Z wait going idle' 202610130715.18
rigStore run-c '2026-10-13T07:15:19Z wait going idle' 202610130715.20
rigStore run-d '2026-10-13T07:15:19Z wait going idle' ''
rigStore run-e '2026-10-13T07:15:19Z handback' 202610130715.18
rigStore run-b '2026-10-13T06:35:00Z wait going idle' ''

echo "-- 1. the whole list: every session with its runs, then the counters --"
rigOthersBefore="$( rigOthers )"
rigRun "$rigOp"
rigWant="$( {
	printf 'session\tsess-run2\t-\trunning\t2026-10-13_10:00_+0300\t-\t3\trunning=3\n'
	printf 'run\tsess-run2\tsess-run2\tmagic-coordinator\tspawn-started\trunning\trunning\t2026-10-13_10:00_+0300\t-\t%s\trigws\twaiting\n' "$rigHost"
	printf 'run\tsess-run2\trun-e\tmagic-tester\tspawn-started\trunning\trunning\t2026-10-13_10:01_+0300\t-\t%s\trigws\tworking\n' "$rigHost"
	printf 'run\tsess-run2\trun-d\tkeeper-rig\tspawn-started\trunning\trunning\t2026-10-13_10:02_+0300\t-\t%s\trigws\twaiting\n' "$rigHost"
	printf 'session\tsess-run\tdaily_of_Monday\trunning\t2026-10-13_09:00_+0300\t-\t3\trunning=2,finished=1\n'
	printf 'run\tsess-run\tsess-run\tmagic-coordinator\tspawn-started\trunning\trunning\t2026-10-13_09:00_+0300\t-\t%s\trigws\tworking\n' "$rigHost"
	printf 'run\tsess-run\trun-c\tmagic-developer\tspawn-started\trunning\trunning\t2026-10-13_09:05_+0300\t-\t%s\trigws\tworking\n' "$rigHost"
	printf 'run\tsess-run\trun-b\tmagic-tester\tspawn-succeeded\tno-process\tfinished\t2026-10-13_09:10_+0300\t2026-10-13_09:40_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tsess-fin\t-\tfinished\t2026-10-12_16:57_+0300\t2026-10-12_17:30_+0200\t2\tfinished=2\n'
	printf 'run\tsess-fin\tsess-fin\tmagic-coordinator\tspawn-succeeded\tno-process\tfinished\t2026-10-12_16:57_+0300\t2026-10-12_18:00_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'run\tsess-fin\tfin-b\tkeeper-rig\tspawn-failed\tno-process\tfinished\t2026-10-12_16:10_+0200\t2026-10-12_17:30_+0200\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tsess-ask\t-\twaiting\t2026-10-11_12:00_+0300\t-\t1\twaiting=1\n'
	printf 'run\tsess-ask\tsess-ask\tmagic-coordinator\tspawn-started\tno-process\twaiting\t2026-10-11_12:00_+0300\t-\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tsess-askrun\t-\tfinished\t2026-10-11_11:00_+0300\t2026-10-11_11:55_+0300\t2\tfinished=2\n'
	printf 'run\tsess-askrun\tsess-askrun\tmagic-coordinator\tspawn-succeeded\tno-process\tfinished\t2026-10-11_11:00_+0300\t2026-10-11_11:55_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'run\tsess-askrun\trun-asker\tkeeper-rig\tspawn-succeeded\tno-process\tfinished\t2026-10-11_11:20_+0300\t2026-10-11_11:50_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tsess-foreign\t-\tunknown-foreign\t2026-10-10_10:00_+0300\t-\t2\tunknown-foreign=2\n'
	printf 'run\tsess-foreign\tsess-foreign\tmagic-coordinator\tspawn-started\tother-host\tunknown-foreign\t2026-10-10_10:00_+0300\t-\telsewhere\trigws\t-\n'
	printf 'run\tsess-foreign\tfor-b\tkeeper-rig\tspawn-started\tother-host\tunknown-foreign\t2026-10-10_10:05_+0300\t-\telsewhere\trigws\t-\n'
	printf 'session\tsess-nospawn\t-\tfinished\t2026-10-09_08:00_+0300\t2026-10-09_08:30_+0300\t1\tfinished=1\n'
	printf 'run\tsess-nospawn\t-\tmagic-librarian\tspawn-succeeded\tno-spawn-id\tfinished\t2026-10-09_08:00_+0300\t2026-10-09_08:30_+0300\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tsess-unclosed\t-\tunclosed\t2026-10-08_07:00_+0300\t-\t1\tunclosed=1\n'
	printf 'run\tsess-unclosed\tsess-unclosed\tmagic-coordinator\tspawn-started\tno-process\tunclosed\t2026-10-08_07:00_+0300\t-\t%s\trigws\t-\n' "$rigHost"
	printf 'session\tbox-empty\t-\tunclosed\t-\t-\t1\tunclosed=1\n'
	printf 'run\tbox-empty\t-\t-\tno-session-record\tno-spawn-id\tunclosed\t-\t-\t-\t-\t-\n'
	printf 'counters\t2\t0\t3\t2\t2\t3.25\t%s\n' "$rigFull"
} )"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigStepOne(){ ## -- the last output with each `session` row cut to the eight fields step one printed, and every other row as it is
	LC_ALL=C awk -F'\t' '$1 == "session" { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 ; next } { print }' "$rigTmp/out"
}
rigAssert "the fields of step one stand where they stood: the first eight fields of each session row, and every run row and the counters row, byte for byte -- each session with its runs, the sessions by start date, the newest first, and the counters last" "$( rigStepOne )" "$rigWant"
rigAssert "each session row ends with three more fields: the stored state and its date, - in both for a session with no state file, and its control thread, none where it never had one" "$( LC_ALL=C awk -F'\t' '$1 == "session" { rows++ ; if ( NF == 13 && $9 == "-" && $10 == "-" && $11 == "none" ) plain++ } END { print rows + 0 ":" plain + 0 }' "$rigTmp/out" )" "9:9"
rigAssert "a session with one running run reads running: its row, with a count of 3, and its run rows read running, running and finished" "$( rigRowOf session sess-run | LC_ALL=C awk '{ print $4, $7 }' ) $( rigRows run | LC_ALL=C awk '$2 == "sess-run" { printf "%s ", $7 }' )" "running 3 running running finished "
rigAssert "a session whose runs are all closed reads finished: its start is the earliest of its runs and the date of its state the latest closing, by their times and not by their text" "$( rigRowOf session sess-fin | LC_ALL=C awk '{ print $4, $5, $6 }' )" "finished 2026-10-12_16:57_+0300 2026-10-12_17:30_+0200"
rigAssert "a session shows its name, the first session-comment among its records, and one with none shows -" "$( rigRowOf session sess-run | LC_ALL=C awk '{ print $3 }' ) $( rigRowOf session sess-fin | LC_ALL=C awk '{ print $3 }' )" "daily_of_Monday -"
rigAssert "a session with an open ask and no live process reads waiting, its run waiting too; and one whose runs have finished and whose ask was closed with them reads finished" "$( rigRowOf session sess-ask | LC_ALL=C awk '{ print $4 }' ) $( rigRowOf run sess-ask | LC_ALL=C awk '{ print $7 }' ) $( rigRowOf session sess-askrun | LC_ALL=C awk '{ print $4 }' )" "waiting waiting finished"
rigAssert "a session of another host is not called finished: it reads unknown-foreign, and so does each of its runs" "$( rigRowOf session sess-foreign | LC_ALL=C awk '{ print $4 }' ) $( rigRows run | LC_ALL=C awk '$2 == "sess-foreign" { printf "%s ", $7 }' )" "unknown-foreign unknown-foreign unknown-foreign "
rigAssert "a record with no spawn id is still a row, with no-spawn-id in live, and its session is listed" "$( rigRows run | LC_ALL=C awk '$2 == "sess-nospawn" { print $3, $6 }' ) $( rigRows session | LC_ALL=C awk '$2 == "sess-nospawn" { n++ } END { print n + 0 }' )" "- no-spawn-id 1"
rigAssert "every row has the fields of its kind: 13 of a session, 12 of a run, 8 of the counters, and no line is of another kind" "$( LC_ALL=C awk -F'\t' '{ want = ( $1 == "session" ) ? 13 : ( $1 == "run" ) ? 12 : ( $1 == "counters" ) ? 8 : -1 ; if ( NF != want ) bad++ ; } END { print NR ":" bad + 0 }' "$rigTmp/out" )" "26:0"

echo "-- 2. the counters --"
rigAssert "the counter of running sessions agrees with the rows: two read running and three finished" "$( rigRows counters | LC_ALL=C awk '{ print $2 }' ) $( rigRows session | LC_ALL=C awk '$4 == "running" { n++ } END { print n + 0 }' ) $( rigRows session | LC_ALL=C awk '$4 == "finished" { n++ } END { print n + 0 }' )" "2 2 3"
rigAssert "a live run that sits in a wait counts as waiting and not as working: its wait/state is older than its last line, wait going idle" "$( rigRowOf run sess-run2 | LC_ALL=C awk '{ print $NF }' )" "waiting"
rigAssert "a live run whose wait has ended counts as working: its wait/state is newer than that line" "$( rigRowOf run run-c | LC_ALL=C awk '{ print $NF }' )" "working"
rigAssert "a live run with no milestones counts as working" "$( [ -e "$rigStores/sess-run/milestones" ] && echo has-milestones || echo no-milestones ) $( rigRowOf run sess-run | LC_ALL=C awk '{ print $NF }' )" "no-milestones working"
rigAssert "a live run whose wait going idle has no wait/state yet counts as waiting, and one whose last line is another counts as working" "$( rigRowOf run run-d | LC_ALL=C awk '{ print $NF }' ) $( rigRowOf run run-e | LC_ALL=C awk '{ print $NF }' )" "waiting working"
rigAssert "the counters of working and waiting agents count the live runs, and an ended run with the store of a wait is neither" "$( rigRows counters | LC_ALL=C awk '{ print $4, $5 }' ) $( rigRowOf run run-b | LC_ALL=C awk '{ print $6, $NF }' )" "3 2 no-process -"
rigAssert "the counter of open asks agrees with the store: two records are reply-pending and five are closed" "$( rigRows counters | LC_ALL=C awk '{ print $6 }' ) $( LC_ALL=C grep -l -x 'status: reply-pending' "$rigPend"/*.md | LC_ALL=C awk 'END { print NR + 0 }' ) $( ls "$rigPend" | LC_ALL=C awk 'END { print NR + 0 }' )" "2 2 7"
## EVERY LIVE AGENT IN A WAIT MAKES THE SESSION WAIT: the state follows the agents, not the other way.
rigStore run-e '2026-10-13T07:15:19Z wait going idle' 202610130715.18
rigRun "$rigOp"
rigAssert "a session whose every live run sits in a Wait reads waiting, and so does each of its runs: none is working" "$( rigRowOf session sess-run2 | LC_ALL=C awk '{ print $4 }' ) $( rigRows run | LC_ALL=C awk '$2 == "sess-run2" { printf "%s ", $NF }' )" "waiting waiting waiting waiting "
rigStore run-e '2026-10-13T07:15:19Z handback' 202610130715.18
rigRun "$rigOp"
rigAssert "and one that is working again keeps its session running" "$( rigRowOf session sess-run2 | LC_ALL=C awk '{ print $4 }' ) $( rigRows run | LC_ALL=C awk '$2 == "sess-run2" { printf "%s ", $NF }' )" "running waiting working waiting "
rigAssert "the counter of paused sessions is there, and reads 0" "$( rigRows counters | LC_ALL=C awk '{ print NF, $3 }' )" "8 0"
rigAssert "the full name of this host stands last in the row, as its hostname -f says it, and not the short one the rows of its runs carry" "$( rigRows counters | LC_ALL=C awk '{ print $8 }' ) $( rigRows run | LC_ALL=C awk -v wantHost="$rigHost" '$10 == wantHost { n++ } END { print ( n > 0 ) ? "runs-short" : "no-run-short" }' )" "$rigFull runs-short"
rigAssert "the load average is the host's one-minute figure, as its uptime says it" "$( rigRows counters | LC_ALL=C awk '{ print $7 }' )" "3.25"
printf ' 02:54:11 up 4 days,  6:19, 12 users,  load average: 0.50, 0.25, 0.10\n' > "$rigTmp/uptime.line"
rigRun "$rigOp" --active
rigAssert "and in the other form an uptime prints it, one average and commas" "$( rigRows counters | LC_ALL=C awk '{ print $7 }' )" "0.50"
printf 'no figure in this line\n' > "$rigTmp/uptime.line"
rigRun "$rigOp" --active
rigAssert "a load that cannot be read is -, and the call still ends 0" "$rigRc $( rigRows counters | LC_ALL=C awk '{ print $7 }' )" "0 -"
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 3.25 2.00 1.00\n' > "$rigTmp/uptime.line"

echo "-- 3. --active --"
rigStates(){ ## -- the sessions of the last output, each with its state, in the order they stand
	rigRows session | LC_ALL=C awk '{ printf "%s=%s ", $2, $4 }'
}
rigRun "$rigOp"
rigAssert "control: without --active every session is listed, whatever its state: two running, one waiting, two unclosed, three finished, and one of another host" "$rigRc $( rigStates )" \
	"0 sess-run2=running sess-run=running sess-fin=finished sess-ask=waiting sess-askrun=finished sess-foreign=unknown-foreign sess-nospawn=finished sess-unclosed=unclosed box-empty=unclosed "
rigPlainRuns="$( rigRows run | LC_ALL=C awk '$2 != "sess-fin" && $2 != "sess-foreign" && $2 != "sess-nospawn" && $2 != "sess-askrun"' )"
rigRun "$rigOp" --active
rigAssert "--active ends 0 and keeps every session that is not finished and can be acted on from this host: those that read running, waiting, and unclosed, a record of theirs still open" "$rigRc $( rigStates )" \
	"0 sess-run2=running sess-run=running sess-ask=waiting sess-unclosed=unclosed box-empty=unclosed "
rigAssert "each kept session has all its runs, the ended ones among them, and the rows of those runs are as they are without --active" "$( rigRows run | LC_ALL=C awk '{ printf "%s ", $3 }' )/ $( [ "$( rigRows run )" = "$rigPlainRuns" ] && echo same-rows || echo other-rows )" \
	"sess-run2 run-e run-d sess-run run-c run-b sess-ask sess-unclosed - / same-rows"
rigAssert "it leaves out the sessions that have finished, and the one of another host, with which nothing can be done from here" "$( rigRows session | LC_ALL=C awk '$4 == "finished" || $4 == "unknown-foreign" || $2 == "sess-fin" || $2 == "sess-nospawn" || $2 == "sess-foreign" { n++ } END { print n + 0 }' )" "0"
rigAssert "the counters count the whole workspace either way" "$( rigRows counters )" "counters 2 0 3 2 2 3.25 $rigFull"
: > "$rigTmp/ps.list"
rigRun "$rigOp" --active
rigAssert "with no live process at all no session reads running, and --active still keeps those that wait or were left unclosed, the two that ran among them; the counters are those of the whole list" "$rigRc $( rigStates )/ $( rigRows counters )" \
	"0 sess-run2=unclosed sess-run=unclosed sess-ask=waiting sess-unclosed=unclosed box-empty=unclosed / counters 0 0 0 0 2 3.25 $rigFull"
rigRun "$rigOp"
rigAssert "and the sessions that were running read unclosed, their runs with no process: a session is active by its processes alone" "$( rigRowOf session sess-run | LC_ALL=C awk '{ print $4, $8 }' ) $( rigRowOf session sess-run2 | LC_ALL=C awk '{ print $4, $8 }' )" "unclosed unclosed=2,finished=1 unclosed unclosed=3"
rigLive sess-run sess-run2 run-c run-d run-e

echo "-- 4. a reader that passes by updates the registries, and writes nothing else --"
rigRun "$rigOp"
rigAssert "the two session registries are written, the first with sixteen columns in each of its 16 rows" "$( LC_ALL=C awk 'NF == 16 { whole++ } END { print NR ":" whole + 0 }' "$rigAgents/spawned-sessions.registry" ) $( LC_ALL=C awk 'END { print NR + 0 }' "$rigAgents/pending-replies.registry" )" "16:16 7"
rigAssert "nothing else of the workspace was written by any call so far: every other file is as it was" "$( rigOthers )" "$rigOthersBefore"
## The registry file is made older than a record written now.
TZ=UTC touch -t 202610010000.00 "$rigAgents/spawned-sessions.registry" "$rigAgents/pending-replies.registry"
rigRec sess-late sess-late sess-late sess-late "$rigHost" magic-coordinator spawn-started '2026-10-07 06:00 +0300' '' 'late one'
rigAsk ask-late sess-late reply-pending
rigAssert "control: a record and an ask are newer than the registries, which hold no row of them" "$( [ "$rigSp/sess-late/sess-late.spawn.md" -nt "$rigAgents/spawned-sessions.registry" ] && echo newer ) $( LC_ALL=C grep -c -e 'sess-late' "$rigAgents/spawned-sessions.registry" "$rigAgents/pending-replies.registry" | LC_ALL=C tr '\n' ' ' )" "newer $rigAgents/spawned-sessions.registry:0 $rigAgents/pending-replies.registry:0 "
rigRun "$rigOp"
rigAssert "a record written after the last rebuild has its row in the output: its one run is open with nothing behind it, and the ask written with it is an open ask of that run, so the session waits on it" "$( rigRowOf session sess-late )" "session sess-late late_one waiting 2026-10-07_06:00_+0300 - 1 waiting=1 - - none - -"
rigAssert "and in the registry files, which the call rebuilt: the row with its start and its comment, the ask, and the counter of open asks one more" "$( LC_ALL=C awk '$2 == "sess-late" { print $12, $13, $14 }' "$rigAgents/spawned-sessions.registry" ) $( LC_ALL=C awk '$1 == "ask-late.md" { print $5 }' "$rigAgents/pending-replies.registry" ) $( rigRows counters | LC_ALL=C awk '{ print $6 }' )" "2026-10-07_06:00_+0300 - late_one reply-pending 3"

echo "-- 5. a workspace with no session store --"
rigBare="$rigTmp/ws-bare" ; mkdir -p "$rigBare/.local/.agents"
rigRunIn "$rigBare" "$rigOp"
rigAssert "it ends 0 and prints no session and no run: the counters row alone, all zero" "$rigRc $( cat "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "0 counters 0 0 0 0 0 3.25 $rigFull"
rigAssert "and says so in one note on standard error, with no error and no warning" "$( rigWhole "$rigTmp/err" "# DistroAgentsTools $rigOp: no spawn sandbox root exists yet, so no session has run in this workspace" ) $( LC_ALL=C grep -c -F -- "$rigOp" "$rigTmp/err" || : ) $( rigTroubles )" "1 1 0"
rigAssert "it made no store of its own" "$( [ -e "$rigBare/.local/agents/spawned" ] && echo spawned ) $( [ -e "$rigBare/.local/agents/pending" ] && echo pending ) $( [ -e "$rigBare/.local/agents/sessions" ] && echo sessions )" "  "

echo "-- 6. the caller rule: the console's own, never a member's session's --"
rigRefusedLine(){ ## the member the session acts as -- how many lines of the last stderr are the one plain line of the rule, whole
	rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as $1, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done"
}
rigRun "$rigOp"
rigAssert "control: a call from no session, a person at a console or a script, runs" "$rigRc $( rigRows counters | LC_ALL=C awk '{ print NF }' )" "0 8"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigCallerBad=""
for rigCaller in "MDAT_SPAWN_AGENT=keeper-rig keeper-rig" "MDAT_SPAWN_AGENT=magic-coordinator magic-coordinator" "harnessAgent=magic-tester magic-tester" "MDAT_SPAWN_SESSION_ID=run-c magic-developer" ; do
	rigPre=( "${rigCaller% *}" )
	rigRun "$rigOp"
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefusedLine "${rigCaller#* }" ) $( rigTroubles )" = "1 0 1 1" ] || rigCallerBad="$rigCallerBad [$rigCaller: rc $rigRc, $( LC_ALL=C grep -e 'ERROR' -e 'WARNING' "$rigTmp/err" | LC_ALL=C grep -v -F -- 'SystemContext.SetInputSpec' | head -2 )]"
	rigRun "$rigOp" --active
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefusedLine "${rigCaller#* }" )" = "1 0 1" ] || rigCallerBad="$rigCallerBad [$rigCaller --active: rc $rigRc]"
done
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in one plain line that says it is the console's own: a member's by its spawn, magic-coordinator's, a harness's, and one known by its spawn record alone" "${rigCallerBad:-each refused}" "each refused"
rigAssert "and a refused call rebuilt nothing: both registries are the files they were" "$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "$rigRegBefore"
rigPre=( "CLAUDE_CODE_SESSION_ID=rig-client-session-with-no-record" )
rigRun "$rigOp" --active
rigPre=()
rigAssert "a client's own session that no spawn started acts as no member, so it is the console's, as it is for every --magic-* operation" "$rigRc $( rigRows counters | LC_ALL=C awk '{ print NF }' )" "0 8"
rigAssert "the rule is asked where the family is dispatched, once, defined once, and asked in no include of the family" \
	"$( LC_ALL=C grep -c -F -e '--manager-*) AgentsToolsManagerCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;' "$rigTool" || : ) $( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh "$rigTool" | LC_ALL=C grep -c -E '^[[:space:]]*AgentsToolsManagerCallerCheck\(\)\{' || : ) $( cat "$rigHere"/*/AgentsTools.Manager*.include | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 1 0"

echo "-- 7. the place of the family --"
rigRun --manager-no-such-operation
rigAssert "an operation the family does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-no-such-operation" )" "1 1"
rigRun --manager-session-no-such
rigAssert "and so is one its subject does not have" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-session-no-such" )" "1 1"
rigRun "$rigOp" --all
rigAssert "an argument the list does not take is refused, rc 1, nothing on stdout, in one line with its syntax" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is [--active], got: --all" )" "1 0 1"
## The second word of a --manager-* operation is never a member to bring: one the machine's members index knows as
## a member of another workspace is this operation's own argument, refused by the operation itself.
mkdir -p "$rigHome/.agents/magic-team"
{
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-rig "$rigWs" myx/pkg/skillset/keeper-rig "$rigWs/source/myx/pkg/skillset/keeper-rig"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-far "$rigTmp/ws-far" myx/pkg/skillset/keeper-far "$rigTmp/ws-far/source/myx/pkg/skillset/keeper-far"
} > "$rigHome/.agents/magic-team/members.registry"
rigRun "$rigOp" keeper-far
rigAssert "a second word the machine's index knows as another workspace's member is no member to this family: refused in the operation's own line" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is [--active], got: keeper-far" ) $( LC_ALL=C grep -c -F -- "is in the team members index" "$rigTmp/err" || : )" "1 1 0"
rigRun --member-help keeper-far
rigAssert "control: the same index does make the dispatcher take that word for a member, in an operation that names one" "$rigRc $( LC_ALL=C grep -c -F -- "member 'keeper-far' is in the team members index but is present in no tracked workspace" "$rigTmp/err" || : )" "1 1"
rm -rf "$rigHome/.agents"
rigAssert "the dispatcher has one arm for the family, which sources the family's include, and that one sources the include of the sessions" \
	"$( LC_ALL=C grep -c -x -e '		--manager-\*)' "$rigTool" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.Manager.include"' "$rigTool" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerSession.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1 1"
rigAssert "the list reads its rows from the one place a row's live and state are derived, and lists no run a second way" \
	"$( LC_ALL=C awk '/^AgentsToolsManagerSessionRows\(\)\{/ { on = 1 } on { print } on && /^\}/ { exit }' "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'AgentsToolsRegistryMeasureRows "' || : ) $( cat "$rigHere"/*/AgentsTools.Manager*.include "$rigHere/manager/AgentsManagerSessionRows.awk" | LC_ALL=C grep -v -e '^[[:space:]]*#' -e 'checklist' | LC_ALL=C grep -c -e 'ps -' -e 'spawned"/\*' -e 'RunWords' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" | LC_ALL=C grep -c -e 'rowLive="other-host"' || : )" "1 0 1"

echo "-- 8. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp [--active]"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s [--active]' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s [--active]' "$rigOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm(){ ## row kind -- the form line of that row in the entry, its back quotes and its indent taken off
	rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$1"' <.*>\)`$/\1/p'
}
rigAssert "its entry gives the form of each of the three rows" "$( rigForm session ) | $( rigForm run ) | $( rigForm counters )" \
	"session <session-id> <name> <state> <started-at> <state-at> <run-count> <state-tally> <session-state> <session-state-at> <control-thread> <tokens> <usage-limit> | run <session-id> <spawn-id> <member> <status> <live> <state> <started-at> <resolved-at> <host> <workspace> <activity> | counters <sessions-running> <sessions-paused> <agents-working> <agents-waiting> <pending-answers> <load-average> <host>"
rigRun "$rigOp"
rigAssert "and every row printed has exactly the fields its form names" "$( for rigKind in session run counters ; do LC_ALL=C awk -F'\t' -v wantKind="$rigKind" -v wantFields="$( rigForm "$rigKind" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" ; done )" "rows:0 rows:0 rows:0 "
rigAssert "the entry names the two registries it rebuilds, each state of a session, and the two words of an agent's activity" "$( for rigWord in spawned-sessions pending-replies running waiting unknown-foreign unclosed finished working ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyy"
rigAssert "control: the entry was cut up to the next operation's heading" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C grep -c -F -- '--grooming-to-backlog' || : )" "1 0"
rigAssert "the notes of the help say whose the family is, once" "$( LC_ALL=C grep -c -F -- 'The `--manager-*` operations are the console'"'"'s own' "$rigHelpMd" || : )" "1"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"
rigAssert "no member's help lists the family: the member help names no --manager prefix" "$( LC_ALL=C grep -c -e '--manager' "$rigHere/member/AgentsTools.MemberHelp.include" || : )" "0"

echo "-- 9. the state a control thread stored for a session, and whether that thread lives --"
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
rigControl(){ ## session id, the state word ("" for no state file), its date, what the pid file names ("" for no pid file), what the lock names ("" for no lock)
	mkdir -p "$rigStores/$1/control"
	[ -z "$2" ] || printf 'state: %s\nstate-at: %s\nreason: said by the rig\n' "$2" "$3" > "$rigStores/$1/control/state"
	[ -z "$4" ] || printf '%s\n' "$4" > "$rigStores/$1/control/pid"
	[ -z "$5" ] || ln -s "$5" "$rigStores/$1/control/lock"
}
rigStand ; rigLivePid="$rigStandPid" ; rigLiveNamed="$rigStandNamed"
rigStand ; rigDeadPid="$rigStandPid" ; rigDeadNamed="$rigStandNamed"
rigAssert "control: the two stand-ins are processes of this rig, each named by its pid and when it began" "$( [ "${rigLiveNamed%% *}" = "$rigLivePid" ] && [ "${rigLiveNamed#* }" != "$rigLiveNamed" ] && echo named ) $( [ "${rigDeadNamed%% *}" = "$rigDeadPid" ] && [ "${rigDeadNamed#* }" != "$rigDeadNamed" ] && echo named )" "named named"
## Seven sessions: a thread that lives; one that was killed; one whose pid another process has taken; one that
## never had a thread; one that ended in order; one whose thread holds its lock and has no pid file yet; and one
## with no live run, an open record, a stored `running` and a lock left by a thread that is no more.
rigRec ctl-alive ctl-alive ctl-alive ctl-alive "$rigHost" magic-coordinator spawn-started '2026-10-06 10:01 +0300' '' ''
rigRec ctl-killed ctl-killed ctl-killed ctl-killed "$rigHost" magic-coordinator spawn-started '2026-10-06 10:02 +0300' '' ''
rigRec ctl-taken ctl-taken ctl-taken ctl-taken "$rigHost" magic-coordinator spawn-started '2026-10-06 10:03 +0300' '' ''
rigRec ctl-never ctl-never ctl-never ctl-never "$rigHost" magic-coordinator spawn-succeeded '2026-10-06 10:04 +0300' '2026-10-06 10:30 +0300' ''
rigRec ctl-ended ctl-ended ctl-ended ctl-ended "$rigHost" magic-coordinator spawn-succeeded '2026-10-06 10:05 +0300' '2026-10-06 10:40 +0300' ''
rigRec ctl-ended ended-b ctl-ended ended-b "$rigHost" keeper-rig spawn-succeeded '2026-10-06 10:06 +0300' '2026-10-06 10:41 +0300' ''
rigRec ctl-lock ctl-lock ctl-lock ctl-lock "$rigHost" magic-coordinator spawn-started '2026-10-06 10:07 +0300' '' ''
rigRec ctl-stale ctl-stale ctl-stale ctl-stale "$rigHost" magic-coordinator spawn-started '2026-10-06 10:08 +0300' '' ''
rigControl ctl-alive running '2026-10-13 10:21 +0300' "$rigLiveNamed" "$rigLiveNamed"
rigControl ctl-killed running '2026-10-13 10:22 +0300' "$rigDeadNamed" "$rigDeadNamed"
rigControl ctl-taken running '2026-10-13 10:23 +0300' "$rigLivePid Thu_Jan__1_00:00:00_1970" ''
rigControl ctl-ended finished '2026-10-13 10:45 +0300' '' ''
rigControl ctl-lock running '2026-10-13 10:27 +0300' '' "$rigLiveNamed"
rigControl ctl-stale running '2026-10-13 10:28 +0300' '' "$rigDeadNamed"
rigAssert "control: the stand-in of the killed thread is ended, and is no process any more" "$( rigGone "$rigDeadPid" )" "gone"
rigLive sess-run sess-run2 run-c run-d run-e ctl-alive ctl-killed ctl-lock
rigOthersBefore="$( rigOthers )"
rigRun "$rigOp"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "a session with a live control thread reads alive: its pid file names a process that began when the file says, and its row ends with running, the date of that state, and alive" "$( rigRowOf session ctl-alive )" "session ctl-alive - running 2026-10-06_10:01_+0300 - 1 running=1 running 2026-10-13_10:21_+0300 alive - -"
rigAssert "a control thread that was killed reads gone: its pid file and its lock name a process id that no process has" "$( rigRowOf session ctl-killed )" "session ctl-killed - running 2026-10-06_10:02_+0300 - 1 running=1 running 2026-10-13_10:22_+0300 gone - -"
rigAssert "a process id another process has taken reads gone: the process lives, and began at another time than the pid file says" "$( rigProcBegan "$rigLivePid" | LC_ALL=C awk 'END { print NR + 0 }' ) $( rigRowOf session ctl-taken )" "1 session ctl-taken - unclosed 2026-10-06_10:03_+0300 - 1 unclosed=1 running 2026-10-13_10:23_+0300 gone - -"
rigAssert "a session that never had a control thread reads -, - and none: it has no folder control/" "$( [ -e "$rigStores/ctl-never/control" ] && echo control || echo no-control ) $( rigRowOf session ctl-never )" "no-control session ctl-never - finished 2026-10-06_10:04_+0300 2026-10-06_10:30_+0300 1 finished=1 - - none - -"
rigAssert "a session that ended in order reads finished twice and none: the derived state, the stored one with its date, and no pid file and no lock" "$( rigRowOf session ctl-ended )" "session ctl-ended - finished 2026-10-06_10:05_+0300 2026-10-06_10:41_+0300 2 finished=2 finished 2026-10-13_10:45_+0300 none - -"
rigAssert "a thread that holds its lock and has no pid file yet reads alive by its lock" "$( rigRowOf session ctl-lock | LC_ALL=C awk '{ print $4, $9, $11 }' )" "running running alive"
rigAssert "where the stored state and the derived one differ, each is shown as it is: a session with no live run and an open record reads unclosed, its stored state running, and its thread gone by the lock it left" "$( rigRowOf session ctl-stale )" "session ctl-stale - unclosed 2026-10-06_10:08_+0300 - 1 unclosed=1 running 2026-10-13_10:28_+0300 gone - -"
rigAssert "the fields of step one stand where they stood here too: of every session row the first eight are those of a row with no state, and every row has the fields of its kind" "$( rigStepOne | LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "ctl-alive" { print $3, $4, $5, $6, $7, $8 }' ) $( LC_ALL=C awk -F'\t' '{ want = ( $1 == "session" ) ? 13 : ( $1 == "run" ) ? 12 : ( $1 == "counters" ) ? 8 : -1 ; if ( NF != want ) bad++ ; } END { print bad + 0 }' "$rigTmp/out" )" "- running 2026-10-06_10:01_+0300 - 1 running=1 0"
rigAssert "the registry stores the state and its date, in the two last of its sixteen columns, and never whether a thread lives" "$( LC_ALL=C awk '$2 == "ctl-alive" { print NF, $15, $16 }' "$rigAgents/spawned-sessions.registry" ) $( LC_ALL=C awk '{ for ( wordAt = 1 ; wordAt <= NF ; wordAt++ ) { if ( $wordAt == "alive" || $wordAt == "gone" || $wordAt == "none" ) said++ } } END { print said + 0 }' "$rigAgents/spawned-sessions.registry" )" "16 running 2026-10-13_10:21_+0300 0"
rigAssert "the list wrote nothing but the two registries: the folders control/ are as they were" "$( rigOthers )" "$rigOthersBefore"
## Liveness is measured at each call: the thread ends between two calls, and nothing of the store changes.
rigAssert "control: the stand-in of the live thread is ended" "$( rigGone "$rigLivePid" )" "gone"
rigRun "$rigOp"
rigAssert "a thread that ended since the last call reads gone at the next, by its pid file and by its lock alone, with the stored state as it was" "$( rigRowOf session ctl-alive | LC_ALL=C awk '{ print $9, $10, $11 }' ) / $( rigRowOf session ctl-lock | LC_ALL=C awk '{ print $9, $11 }' )" "running 2026-10-13_10:21_+0300 gone / running gone"
rigRun "$rigOp" --active
rigAssert "--active keeps the sessions it keeps with the same three fields at the end of each row: the five that run, and those that wait or were left unclosed, the one with a stale state among them" "$rigRc $( rigRowOf session ctl-killed | LC_ALL=C awk '{ print $9, $10, $11 }' ) $( rigRowOf session ctl-stale | LC_ALL=C awk '{ print $4, $9, $11 }' ) $( rigRows session | LC_ALL=C awk '$4 == "running" { running++ } $4 != "running" && $4 != "waiting" && $4 != "unclosed" { bad++ } NF != 13 { bad++ } END { print running + 0 ":" bad + 0 }' ) $( rigRows session | LC_ALL=C awk '$2 == "ctl-never" || $2 == "ctl-ended" { n++ } END { print n + 0 }' )" "0 running 2026-10-13_10:22_+0300 gone unclosed running gone 5:0 0"
rigAssert "the one function that says whether a control thread lives reads the process list through the registry's own reading of when a process began, and no process list of its own" "$( LC_ALL=C awk '/^AgentsToolsManagerSessionControls\(\)\{/ { on = 1 } on { print } on && /^\}/ { exit }' "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'AgentsToolsRegistryProcessesBegan' || : ) $( LC_ALL=C awk '/^AgentsToolsManagerSessionControls\(\)\{/ { on = 1 } on { print } on && /^\}/ { exit }' "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'ps -' -e 'pgrep' || : )" "1 0"
rigLive sess-run sess-run2 run-c run-d run-e

echo "-- 10. the tokens of a session, as one number at the end of its row --"
## The same four sessions as the read is checked with: two runs that run; one that runs and one that ended; two
## that ended; and three that ended, of which one keeps figures that are no four numbers and one has no store.
rigTokRun(){ ## session id, spawn id, status, started-at, resolved-at ("" for none), the line of its tokens ("" for no store)
	rigRec "$2" "$2" "$1" "$2" "$rigHost" keeper-rig "$3" "$4" "$5" ""
	[ -z "$6" ] || { mkdir -p "$rigStores/$2" && printf '%s\n' "$6" > "$rigStores/$2/tokens" ; }
}
rigTokRun tok-two tok-two spawn-started '2026-10-05 09:00 +0300' '' '100 2000 30 4'
rigTokRun tok-two two-b spawn-started '2026-10-05 09:01 +0300' '' '1 2 3 4'
rigTokRun tok-mix tok-mix spawn-started '2026-10-04 09:00 +0300' '' '10 20 30 40'
rigTokRun tok-mix mix-b spawn-succeeded '2026-10-04 09:01 +0300' '2026-10-04 09:30 +0300' '5 5 5 5'
rigTokRun tok-done tok-done spawn-succeeded '2026-10-03 09:00 +0300' '2026-10-03 09:40 +0300' '7 0 0 3'
rigTokRun tok-done done-b spawn-failed '2026-10-03 09:01 +0300' '2026-10-03 09:30 +0300' '4000000000 4000000000 1 1'
rigTokRun tok-part tok-part spawn-succeeded '2026-10-02 09:00 +0300' '2026-10-02 09:40 +0300' '9 9 9 9'
rigTokRun tok-part part-b spawn-succeeded '2026-10-02 09:01 +0300' '2026-10-02 09:30 +0300' '12 x 3 4'
rigTokRun tok-part part-c spawn-succeeded '2026-10-02 09:02 +0300' '2026-10-02 09:20 +0300' ''
rigLive tok-two two-b tok-mix
rigTokOf(){ ## session id -- its state and the tokens field of its row in the last output
	rigRowOf session "$1" | LC_ALL=C awk '{ print $4 "=" $12 }'
}
rigRun "$rigOp"
rigTokBefore="$( rigOthers )"
rigRun "$rigOp"
rigAssert "the call ends 0, with no error and no warning, and every session row has its thirteen fields" "$rigRc $( rigTroubles ) $( rigRows session | LC_ALL=C awk 'NF != 13 { bad++ } END { print bad + 0 }' )" "0 0 0"
rigAssert "a session of two runs that both run ends with the four figures of the two added, as one number; so does one with a run that runs and one that ended" "$( rigTokOf tok-two ) $( rigTokOf tok-mix )" "running=2144 running=120"
rigAssert "a session whose runs have all ended carries its total too, a whole number above four thousand million" "$( rigTokOf tok-done )" "finished=8000000012"
rigAssert "a session with a run whose figures are not known says with + that its number is not the whole; one with no known figure at all reads -" "$( rigTokOf tok-part ) $( rigTokOf sess-fin ) $( rigTokOf sess-nospawn )" "finished=36+ finished=- finished=-"
rigRun "$rigOp" --active
rigAssert "--active keeps the same number at the end of each row it keeps" "$rigRc $( rigTokOf tok-two ) $( rigTokOf tok-mix ) $( rigRows session | LC_ALL=C awk '$2 == "tok-done" { n++ } END { print n + 0 }' )" "0 running=2144 running=120 0"
rigAssert "nothing but the two registries is written for it" "$( [ "$( rigOthers )" = "$rigTokBefore" ] && echo unchanged || echo changed )" "unchanged"

echo "-- 10b. the usage-limit flag of a session: the provider's own message, and the date it reopens --"
## The message is the provider's own, kept exactly as the harness keeps it beside a run's record
## (AgentsHarnessRefusalKeep): the fixture holds it, and the one parser makes the one wording.
rigLimitFixture="$rigPackage/sh-test/check-fixtures/provider-usage-limit.refused.txt"
rigLimitInclude="$rigPackage/sh-lib/session/AgentsTools.UsageLimit.include"
rigLimitText="stopped on the provider usage limit: reopens 2026-11-01 00:00 UTC"
[ -f "$rigLimitFixture" ] || rigRefuse "the usage-limit fixture is missing: $rigLimitFixture"
( MMDAPP="$rigWs" ; . "$rigLimitInclude" ; AgentsToolsUsageLimitMark tok-two "$( cat "$rigLimitFixture" )" ) \
	|| rigRefuse "the usage-limit flag could not be kept in the store of tok-two"
rigFlagOf(){ ## session id -- the usage-limit flag of its row in the last output, one field
	LC_ALL=C awk -F'\t' -v wantId="$1" '$1 == "session" && $2 == wantId { print $NF ; }' "$rigTmp/out"
}
rigRun "$rigOp"
rigAssert "the provider's message is kept as one wording, with the date it reopens, in the last field of the session row" "$( rigFlagOf tok-two )" "$rigLimitText"
rigAssert "the tokens stand before it, and the state is not changed by the flag" "$( rigTokOf tok-two ) $( rigRowOf session tok-two | LC_ALL=C awk '{ print $4 }' )" "running=2144 running"
rigAssert "no session whose runs were not refused carries a flag" "$( rigRows session | LC_ALL=C awk '$NF != "-" { n++ } END { print n + 0 }' )" "1"
rigAssert "a second call reads the same flag, from the run's own store" "$( rigRun "$rigOp" ; rigFlagOf tok-two )" "$rigLimitText"

echo "-- 11. the name of this host in the counters row: its full name, asked once and kept --"
rigHostOf(){ ## -- the last field of the counters row of the last output
	rigRows counters | LC_ALL=C awk '{ print $NF }'
}
rigAsked(){ ## -- how often the full name was asked of the host so far
	LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/hostname.asked" 2> /dev/null || echo 0
}
rigAskedBefore="$( rigAsked )"
rigRun "$rigOp" ; rigHostOne="$( rigHostOf )"
rigRun "$rigOp" --active
rigAssert "the full name is kept for the calls that follow: two more calls show it and ask the host nothing, and the file it is kept in names the short name, the full one, when it was asked and for how long it is kept, a day" \
	"$rigHostOne $( rigHostOf ) $(( $( rigAsked ) - rigAskedBefore )) $( LC_ALL=C awk -v wantShort="$rigHost" -v wantFull="$rigFull" 'NF == 4 && $1 == wantShort && $2 == wantFull && $3 ~ /^[0-9]+$/ && $4 == 86400 { ok++ } END { print NR ":" ok + 0 }' "$rigKept" 2> /dev/null )" "$rigFull $rigFull 0 1:1"
printf 'other-name other-name.rig.invalid %s 86400\n' "$( date +%s )" > "$rigKept"
rigAskedBefore="$( rigAsked )"
rigRun "$rigOp"
rigAssert "a name kept for another short name, a machine that was renamed, is not taken: the host is asked again, once" "$( rigHostOf ) $(( $( rigAsked ) - rigAskedBefore ))" "$rigFull 1"
printf '%s stale.rig.invalid %s 86400\n' "$rigHost" "$(( $( date +%s ) - 90000 ))" > "$rigKept"
rigAskedBefore="$( rigAsked )"
rigRun "$rigOp"
rigAssert "nor is a name kept longer ago than it was to be kept: asked again, once" "$( rigHostOf ) $(( $( rigAsked ) - rigAskedBefore ))" "$rigFull 1"
## A host whose full name does not resolve: the plain name stands in its place, and is kept for an hour.
rm -f "$rigKept" ; printf 'unresolved\n' > "$rigTmp/hostname.mode" ; printf 'plain-of-the-rig\n' > "$rigTmp/hostname.plain"
rigAskedBefore="$( rigAsked )"
rigRun "$rigOp" ; rigHostOne="$( rigHostOf )"
rigRun "$rigOp"
rigAssert "a host whose full name does not resolve shows its plain name, with no error and no warning, and is not asked again at the next call: what stands in its place is kept, for an hour" \
	"$rigRc $( rigTroubles ) $rigHostOne $( rigHostOf ) $(( $( rigAsked ) - rigAskedBefore )) $( LC_ALL=C awk '{ print $2, $4 }' "$rigKept" 2> /dev/null )" "0 0 plain-of-the-rig plain-of-the-rig 1 plain-of-the-rig 3600"
rm -f "$rigKept" ; : > "$rigTmp/hostname.plain"
rigRun "$rigOp"
rigAssert "with no plain name either the short name stands there: the field is never empty, and the row has its eight fields" "$( rigHostOf ) $( LC_ALL=C awk -F'\t' '$1 == "counters" { print NF }' "$rigTmp/out" )" "$rigHost 8"
rm -f "$rigKept" ; printf 'localhost\n' > "$rigTmp/hostname.mode" ; printf 'plain-of-the-rig\n' > "$rigTmp/hostname.plain"
rigRun "$rigOp"
rigAssert "a full name that reads localhost is no name of this host: the plain name stands in its place" "$( rigHostOf )" "plain-of-the-rig"
## A slow resolver: the lookup is given a second, then ended, and is not made again at each call.
rm -f "$rigKept" "$rigTmp/hostname.ended" ; printf 'slow\n' > "$rigTmp/hostname.mode"
rigAskedBefore="$( rigAsked )" ; rigSlowFrom="$( date +%s )"
rigRun "$rigOp" ; rigHostOne="$( rigHostOf )" ; rigSlowTook=$(( $( date +%s ) - rigSlowFrom ))
rigSlowLeft=25 ; while [ ! -s "$rigTmp/hostname.ended" ] && [ "$rigSlowLeft" -gt 0 ] ; do sleep 0.2 ; rigSlowLeft=$(( rigSlowLeft - 1 )) ; done
rigAssert "a resolver that does not answer does not hold the list: the call ends 0 within seconds with the plain name, and the lookup it had started was ended" \
	"$rigRc $rigHostOne $( [ "$rigSlowTook" -le 15 ] && echo in-time || echo "after ${rigSlowTook}s" ) $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/hostname.ended" 2> /dev/null )" "0 plain-of-the-rig in-time 1"
rigSlowFrom="$( date +%s )"
rigRun "$rigOp" ; rigHostOne="$( rigHostOf )"
rigRun "$rigOp"
rigAssert "and it is not asked again at each call: the two calls that follow show the plain name, ask nothing, and end no lookup" \
	"$rigHostOne $( rigHostOf ) $(( $( rigAsked ) - rigAskedBefore )) $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/hostname.ended" 2> /dev/null )" "plain-of-the-rig plain-of-the-rig 1 1"
: > "$rigTmp/hostname.release" ; rm -f "$rigTmp/hostname.mode" "$rigTmp/hostname.plain" "$rigKept"
rigRun "$rigOp"
rigAssert "the short name of this host is as it was everywhere else: the rows of its runs carry it, and a run of this host still reads as one of this host" "$( rigHostOf ) $( rigRowOf run tok-two | LC_ALL=C awk '{ print $6, $10 }' )" "$rigFull running $rigHost"

echo "-- 12. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION LIST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_LIST: OK (%d assertions, offline)\n' "$rigPasses"
