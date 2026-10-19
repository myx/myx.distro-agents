#!/usr/bin/env bash
## Behavioural check on --manager-session-transcript-read --session-id <id> [--run] [--tail <lines>] [--log], the
## console's read of what one run, or every run of one coworking session, did -- run rather than read, against a
## rig workspace built here: its own spawn records, the stores of its own runs, transcripts in a team data folder
## of its own, session logs, and a process list of its own.
## Held: the whole output, byte for byte. One `source` row a run first, saying where its lines are read from: its
## transcript, or its session log where it has none, or neither. Then the `feed` rows: each operation of the
## transcript as the line the tracking thread shows for it, with its emoji, by the tracking post's own template --
## a tool call with its outcome, a round with its tokens, a wait with its result, a message out -- with its
## moment, the run, its member, and the box it stands in. THE LAST LINES of a run are read, and never from the
## middle of a body: a --tail that would start inside the body of a tool line starts at that tool line. A
## transcript in two parts is read across its parts. THE LINES OF A SESSION come in the order of their times, each
## marked with its member; where its runs are cut, they start where every run's are held. --run reads the founder
## alone. A RUN WITH NO TRANSCRIPT shows the end of its session log, and its first line says so; --log asks for
## that of a run that has both. A log line is exact, a TAB written \t, a backslash \\ and a carriage return \r,
## and a value of the shape of a Slack token is [redacted] in a log line and in a feed line alike. An id that
## names nothing is one error line and status 1. A MEMBER THAT JOINS A RUNNING SESSION after the registry was
## built, its record added to the folder the session already has, is in the next read with its feed, whatever
## the clock says. It writes nothing but a registry it had to rebuild: no post is
## made, the wait set the tracking poster keeps beside a run's feed is not written, and no scratch file is left.
## A call from inside a member's session is refused. And the help pair, with the three row forms the output is
## checked against. A fake `curl` first on PATH would log a request: none is made. Offline; only the rig's own
## tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-transcript-read"
rigSyntaxTail="--session-id <id> [--run] [--tail <lines>] [--log]"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionTranscriptReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigPend="$rigAgents/pending" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigPend" "$rigStores" "$rigHome" "$rigSkills" "$rigData/audit"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"

## THE RIG'S OWN PROCESS LIST, as in AgentsManagerSessionListCheck. No run of this rig is alive: the list is empty.
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

rigRec(){ ## sandbox and spawn id, session id, owner, started-at
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: spawn-succeeded\nstarted-at: %s\nresolved-at: 2026-10-13 12:00 +0300\n---\n\n# Spawn session\n' "$2" "$1" "$rigHost" "$3" "$4" > "$rigSp/$1/$1.md"
}
rigTranscript(){ ## spawn id, file name in the rig's team data -- stdin: the lines of the transcript; the store's pointer names it
	mkdir -p "$rigStores/$1"
	cat > "$rigData/audit/$2"
	printf '%s\n' "$rigData/audit/$2" > "$rigStores/$1/transcript"
}
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
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
rigOthers(){ ## -- every file of the rig workspace and its team data but the two session registries, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws data -type f ! -name spawned-sessions.registry ! -name pending-replies.registry | LC_ALL=C sort | while IFS= read -r othersFile ; do printf '%s %s\n' "$othersFile" "$( cksum < "$othersFile" )" ; done ) | cksum
}
rigFeed(){ ## -- the feed rows of the last output as `<time> <spawn-id> <text>`, a line each
	LC_ALL=C awk -F'\t' '$1 == "feed" { print $2, $3, $7 }' "$rigTmp/out"
}

## THE STORES. A session of three: its founder and a member wrote lines in turn, and a second member has a session
## log and no transcript.
rigRec sess-t sess-t magic-coordinator '2026-10-13 09:00 +0300'
rigRec run-m sess-t keeper-rig '2026-10-13 09:01 +0300'
rigRec run-q sess-t magic-tester '2026-10-13 09:02 +0300'
rigTranscript sess-t session-t.log <<'RIGLINES'
2026-10-13T07:00:01Z START session=sess-t member=magic-coordinator
2026-10-13T07:00:03Z TOOL Read path=/rig/notes/one.txt -> ok 120B/5L <1s
2026-10-13T07:00:05Z ROUND n=1 in=2 cache-read=10 cache-write=5 out=7
RIGLINES
rigTranscript run-m session-m.log <<'RIGLINES'
2026-10-13T07:00:02Z START session=run-m member=keeper-rig
2026-10-13T07:00:04Z TOOL Grep pattern=needle path=/rig/notes -> ok 30B/2L <1s
2026-10-13T07:00:06Z ROUND n=1 in=3 cache-read=20 cache-write=0 out=9
RIGLINES
mkdir -p "$rigStores/run-q"
printf 'the first line of the tester\nits second line\n' > "$rigStores/run-q/session.log"
## A lone run whose transcript ends with a tool line that has a body of five lines, then one round.
rigRec run-a run-a keeper-rig '2026-10-13 10:00 +0300'
rigTranscript run-a session-a.log <<'RIGLINES'
2026-10-13T07:10:00Z START session=run-a member=keeper-rig
2026-10-13T07:10:01Z ROUND n=1 in=2 cache-read=10 cache-write=5 out=7
2026-10-13T07:10:02Z TOOL mcp__myx_distro__execute cmd="make all" -> error "exit code 2" 50B/5L 3s
> make: *** No rule to make target
> line two
> line three
> line four
> line five
2026-10-13T07:10:03Z ROUND n=2 in=4 cache-read=30 cache-write=0 out=1
RIGLINES
## A lone run whose transcript rolled into a second part of three lines.
rigRec run-p run-p keeper-rig '2026-10-13 10:10 +0300'
rigTranscript run-p session-p.log <<'RIGLINES'
2026-10-13T07:20:00Z START session=run-p member=keeper-rig
2026-10-13T07:20:01Z ROUND n=1 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:02Z ROUND n=2 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:03Z ROUND n=3 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:04Z ROUND n=4 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:05Z ROUND n=5 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:06Z ROUND n=6 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:07Z ROUND n=7 in=1 cache-read=0 cache-write=0 out=1
2026-10-13T07:20:08Z ROLL -> session-p-part2.log
RIGLINES
printf '2026-10-13T07:20:08Z CONTINUED from session-p.log\n2026-10-13T07:20:09Z ROUND n=8 in=1 cache-read=0 cache-write=0 out=1\n2026-10-13T07:20:10Z ROUND n=9 in=1 cache-read=0 cache-write=0 out=1\n' > "$rigData/audit/session-p-part2.log"
## A lone run with a session log and no pointer to a transcript: a TAB, a backslash, a value of the shape of a
## Slack token, put together here so that no file of the package holds one, and a carriage return.
rigToken="xoxb-""1234567890""-abcdefABCDEF"
rigRec run-l run-l keeper-rig '2026-10-13 10:20 +0300'
mkdir -p "$rigStores/run-l"
printf 'the start of the log\na\ttab here\na back\\slash here\ntoken %s in a line\nlast\rline\n' "$rigToken" > "$rigStores/run-l/session.log"
## A lone run with both: a wait, then a message out with an ampersand and angle brackets, and a token in a command.
rigRec run-w run-w keeper-rig '2026-10-13 10:30 +0300'
rigTranscript run-w session-w.log <<RIGLINES
2026-10-13T07:30:00Z START session=run-w member=keeper-rig
2026-10-13T07:30:05Z WAIT-RESULT
> WAIT-RESULT: TIMEOUT (5s) NEXT: Wait mode=continue
> # sources: slack:CSESS:9.000900:conversation
2026-10-13T07:30:05Z TOOL mcp__myx_distro__Wait -> ok 80B/2L 5s
2026-10-13T07:30:06Z MSG-OUT to=session-current
> the answer is 42 & <done>
> its second line
2026-10-13T07:30:06Z TOOL mcp__myx_distro__SendMessage to=session-current message="the answer is 42 & <done>" -> ok 10B/1L 1s
2026-10-13T07:30:07Z TOOL mcp__myx_distro__execute cmd="curl -H $rigToken" -> ok 5B/1L 1s
RIGLINES
printf 'the raw log of the waiting run\n' > "$rigStores/run-w/session.log"
## A lone run with neither, and one whose pointer names a transcript that is gone, beside a session log.
rigRec run-n run-n keeper-rig '2026-10-13 10:40 +0300'
rigRec run-g run-g keeper-rig '2026-10-13 10:50 +0300'
mkdir -p "$rigStores/run-g"
printf '%s\n' "$rigData/audit/gone.log" > "$rigStores/run-g/transcript"
printf 'what is left of it\n' > "$rigStores/run-g/session.log"

echo "-- 1. the last lines of a run, never from the middle of a body --"
rigOthersBefore="$( rigOthers )"
rigRun "$rigOp" --session-id run-a
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: where the lines are read from, then each operation as the tracking thread shows it, with its moment, its run, its member and its box" "$( cat "$rigTmp/out" )" "$( {
	printf 'source\trun-a\tkeeper-rig\ttranscript\t%s\n' "$rigData/audit/session-a.log"
	printf 'feed\t2026-10-13T07:10:00Z\trun-a\tkeeper-rig\trun\tkeeper-rig\t▶️ run start\n'
	printf 'feed\t2026-10-13T07:10:01Z\trun-a\tkeeper-rig\tmember\tkeeper-rig\t🧠 round 1 · in 2 · cache 15 · out 7\n'
	printf 'feed\t2026-10-13T07:10:02Z\trun-a\tkeeper-rig\tmember\tkeeper-rig\t⛔ execute `make all` → error: exit code 2\n'
	printf 'feed\t2026-10-13T07:10:03Z\trun-a\tkeeper-rig\tmember\tkeeper-rig\t🧠 round 2 · in 4 · cache 30 · out 1\n'
} )"
rigRun "$rigOp" --session-id run-a --tail 3
rigAssert "control: the last three lines of that transcript start inside the body of five lines" "$( tail -n 3 "$rigData/audit/session-a.log" | LC_ALL=C cut -c1-12 | LC_ALL=C tr '\n' '|' )" "> line four|> line five|2026-10-13T0|"
rigAssert "a --tail that would start inside the body starts at the head line of that body: the tool line, then what follows it, and nothing of the body as a line of its own" "$rigRc $( rigFeed | LC_ALL=C tr '\n' '|' )" "0 2026-10-13T07:10:02Z run-a ⛔ execute \`make all\` → error: exit code 2|2026-10-13T07:10:03Z run-a 🧠 round 2 · in 4 · cache 30 · out 1|"
rigRun "$rigOp" --session-id run-a --tail 1
rigAssert "and a --tail that ends on a head line gives that line alone" "$rigRc $( rigFeed | LC_ALL=C tr '\n' '|' )" "0 2026-10-13T07:10:03Z run-a 🧠 round 2 · in 4 · cache 30 · out 1|"

echo "-- 2. a transcript in two parts --"
rigRun "$rigOp" --session-id run-p --tail 10
rigAssert "control: the second part holds three lines, and the first nine" "$( LC_ALL=C awk 'END { print NR }' "$rigData/audit/session-p.log" ) $( LC_ALL=C awk 'END { print NR }' "$rigData/audit/session-p-part2.log" )" "9 3"
rigAssert "--tail 10 holds the last seven lines of the first part, then the three of the second, in their order" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "feed" { text = $7 ; sub( / · in .*/, "", text ) ; printf "%s|", text }' "$rigTmp/out" )" "0 🧠 round 2|🧠 round 3|🧠 round 4|🧠 round 5|🧠 round 6|🧠 round 7|🔹 roll|🔹 continued|🧠 round 8|🧠 round 9|"
rigAssert "its source is the transcript, named by its first part" "$( LC_ALL=C awk -F'\t' '$1 == "source" { print $2, $4, $5 }' "$rigTmp/out" )" "run-p transcript $rigData/audit/session-p.log"
rigRun "$rigOp" --session-id run-p
rigAssert "with no --tail the whole of a short transcript is read, both parts: twelve lines" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "feed" { rows++ } END { print rows + 0 }' "$rigTmp/out" )" "0 12"

echo "-- 3. the lines of a session, in the order of their times --"
rigRun "$rigOp" --session-id sess-t
rigAssert "the whole output, byte for byte: a source for each of the three runs, the session log of the one with no transcript, then the lines of the two others in the order of their times, each marked with its member" "$rigRc $( cat "$rigTmp/out" )" "0 $( {
	printf 'source\tsess-t\tmagic-coordinator\ttranscript\t%s\n' "$rigData/audit/session-t.log"
	printf 'source\trun-m\tkeeper-rig\ttranscript\t%s\n' "$rigData/audit/session-m.log"
	printf 'source\trun-q\tmagic-tester\tsession-log\t%s\n' "$rigStores/run-q/session.log"
	printf 'log\trun-q\tmagic-tester\tthe first line of the tester\nlog\trun-q\tmagic-tester\tits second line\n'
	printf 'feed\t2026-10-13T07:00:01Z\tsess-t\tmagic-coordinator\trun\tmagic-coordinator\t▶️ run start\n'
	printf 'feed\t2026-10-13T07:00:02Z\trun-m\tkeeper-rig\trun\tkeeper-rig\t▶️ run start\n'
	printf 'feed\t2026-10-13T07:00:03Z\tsess-t\tmagic-coordinator\tmember\tmagic-coordinator\t📖 Read `notes/one.txt` → 120 B\n'
	printf 'feed\t2026-10-13T07:00:04Z\trun-m\tkeeper-rig\tmember\tkeeper-rig\t🔍 Grep `needle` in `rig/notes` → 2 lines\n'
	printf 'feed\t2026-10-13T07:00:05Z\tsess-t\tmagic-coordinator\tmember\tmagic-coordinator\t🧠 round 1 · in 2 · cache 15 · out 7\n'
	printf 'feed\t2026-10-13T07:00:06Z\trun-m\tkeeper-rig\tmember\tkeeper-rig\t🧠 round 1 · in 3 · cache 20 · out 9\n'
} )"
rigAssert "the lines of the two members come in turn, as they were written, and the newest is the last line of the output" "$( LC_ALL=C awk -F'\t' '$1 == "feed" { printf "%s ", $4 }' "$rigTmp/out" )/ $( tail -n 1 "$rigTmp/out" | LC_ALL=C cut -f2 )" "magic-coordinator keeper-rig magic-coordinator keeper-rig magic-coordinator keeper-rig / 2026-10-13T07:00:06Z"
rigRun "$rigOp" --session-id sess-t --tail 2
rigAssert "where the runs of a session are cut, its lines start where every run's are held: the founder's last two start at :03 and the member's at :04, so the lines start at :04, and no run is shown with a gap" "$rigRc $( rigFeed | LC_ALL=C awk '{ printf "%s:%s ", $1, $2 }' )" "0 2026-10-13T07:00:04Z:run-m 2026-10-13T07:00:05Z:sess-t 2026-10-13T07:00:06Z:run-m "
rigRun "$rigOp" --session-id sess-t --run
rigAssert "--run reads the founder alone, whose id is its session's: its source and its lines, and no other run's" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "source" { sources = sources $2 " " } $1 == "feed" { rows[$3]++ } $1 == "log" { logs++ } END { printf "%s/ %s %s %s", sources, rows["sess-t"] + 0, rows["run-m"] + 0, logs + 0 }' "$rigTmp/out" )" "0 sess-t / 3 0 0"
rigRun "$rigOp" --session-id run-m
rigAssert "the own id of a member that joined shows that run alone" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "source" { printf "%s ", $2 } $1 == "feed" { rows[$3]++ } END { for ( key in rows ) printf "%s=%s", key, rows[key] }' "$rigTmp/out" )" "0 run-m run-m=3"

echo "-- 4. a run with no transcript, and the raw log on request --"
rigRun "$rigOp" --session-id run-l --tail 4
rigAssert "control: the store has a session log and no pointer to a transcript" "$( [ -f "$rigStores/run-l/session.log" ] && echo log ) $( [ -e "$rigStores/run-l/transcript" ] && echo pointer || echo no-pointer )" "log no-pointer"
rigAssert "a run with no transcript shows its session log: the first line says that it is the session log, and its last lines follow, each exact -- a TAB written \\t, a backslash \\\\, a carriage return \\r" "$rigRc $( cat "$rigTmp/out" )" "0 $( {
	printf 'source\trun-l\tkeeper-rig\tsession-log\t%s\n' "$rigStores/run-l/session.log"
	printf 'log\trun-l\tkeeper-rig\ta\\ttab here\n'
	printf 'log\trun-l\tkeeper-rig\ta back\\\\slash here\n'
	printf 'log\trun-l\tkeeper-rig\ttoken [redacted] in a line\n'
	printf 'log\trun-l\tkeeper-rig\tlast\\rline\n'
} )"
rigAssert "a token in a session log is not printed: [redacted] stands in its place, and the log itself still holds it" "$( LC_ALL=C grep -c -F -- "$rigToken" "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -- '[redacted]' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -- "$rigToken" "$rigStores/run-l/session.log" || : )" "0 1 1"
rigAssert "every row has the fields of its kind: 5 of a source, 4 of a log" "$( LC_ALL=C awk -F'\t' '{ want = ( $1 == "source" ) ? 5 : ( $1 == "log" ) ? 4 : -1 ; if ( NF != want ) bad++ ; } END { print NR ":" bad + 0 }' "$rigTmp/out" )" "5:0"
rigRun "$rigOp" --session-id run-w
rigAssert "a run with both shows its transcript: a wait with its result and what it waited on, a message out with its first line, its ampersand and angle brackets as they were written, and a token in a command [redacted]" "$rigRc $( cat "$rigTmp/out" )" "0 $( {
	printf 'source\trun-w\tkeeper-rig\ttranscript\t%s\n' "$rigData/audit/session-w.log"
	printf 'feed\t2026-10-13T07:30:00Z\trun-w\tkeeper-rig\trun\tkeeper-rig\t▶️ run start\n'
	printf 'feed\t2026-10-13T07:30:05Z\trun-w\tkeeper-rig\tmember\tkeeper-rig\t⏳ Wait → TIMEOUT 5 s · on: thread · 5 s\n'
	printf 'feed\t2026-10-13T07:30:06Z\trun-w\tkeeper-rig\tmember\tkeeper-rig\t✉️ SendMessage → *session-current*: "the answer is 42 & <done>"\n'
	printf 'feed\t2026-10-13T07:30:07Z\trun-w\tkeeper-rig\tmember\tkeeper-rig\t💻 execute `curl -H [redacted]` → exit 0 · 1 s\n'
} )"
rigAssert "the wait set the tracking poster keeps beside a run's feed is not written by a read" "$( [ -e "$rigStores/run-w/event-track.wait-on" ] && echo written || echo not-written )" "not-written"
rigRun "$rigOp" --session-id run-w --log
rigAssert "--log gives the raw session log of that run, and no line of its transcript" "$rigRc $( cat "$rigTmp/out" )" "0 $( printf 'source\trun-w\tkeeper-rig\tsession-log\t%s\nlog\trun-w\tkeeper-rig\tthe raw log of the waiting run\n' "$rigStores/run-w/session.log" )"
rigRun "$rigOp" --session-id run-n
rigAssert "a run with neither says so in its source row, and has no further row" "$rigRc $( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )" "0 source run-n keeper-rig none -"
rigRun "$rigOp" --session-id run-g
rigAssert "a pointer to a transcript that is gone is no transcript: the session log is given" "$rigRc $( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" | LC_ALL=C tr '\n' '|' )" "0 source run-g keeper-rig session-log $rigStores/run-g/session.log|log run-g keeper-rig what is left of it|"
rigRun "$rigOp" --session-id sess-t --log
rigAssert "--log on a session gives the raw log of each run that has one, run by run, and says none of the others" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "source" { printf "%s:%s ", $2, $4 } $1 == "log" { printf "[%s] ", $4 } $1 == "feed" { printf "FEED " }' "$rigTmp/out" )" "0 sess-t:none run-m:none run-q:session-log [the first line of the tester] [its second line] "

echo "-- 5. an id that names nothing, and what the operation takes --"
rigRun "$rigOp" --session-id no-such-id
rigAssert "the read of a transcript refuses an id that names nothing: one error line, status 1, nothing on stdout" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no record of this workspace carries 'no-such-id' as the id of a session or the own id of a run -- nothing is shown" ) $( rigTroubles )" "1 0 1 1"
rigRun "$rigOp"
rigAssert "with no --session-id it is refused in one line with its syntax" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigSyntaxTail, got no --session-id" )" "1 0 1"
rigTailBad=""
for rigTail in 0 x 3x -1 ; do
	rigRun "$rigOp" --session-id run-a --tail "$rigTail"
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --tail needs a count of lines, 1 or more, got: $rigTail -- syntax is $rigSyntaxTail" )" = "1 0 1" ] || rigTailBad="$rigTailBad [$rigTail: rc $rigRc]"
done
rigRun "$rigOp" --session-id run-a --tail
[ "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --tail needs a count of lines, 1 or more, got: nothing -- syntax is $rigSyntaxTail" )" = "1 1" ] || rigTailBad="$rigTailBad [no count: rc $rigRc]"
rigAssert "a --tail that is no count of one line or more is refused, rc 1, nothing on stdout, in one line with the syntax" "${rigTailBad:-each refused}" "each refused"
rigRun "$rigOp" --session-id run-a --raw
rigAssert "and so is an argument it does not take" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigSyntaxTail, got: --raw" )" "1 0 1"

echo "-- 6. it only reads --"
rigAssert "nothing of the workspace or of the team data was written by any call so far but the two registries, and no scratch file is left" "$( rigOthers ) $( find "$rigWs/.local/temp" -type f 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' )" "$rigOthersBefore 0"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigRun "$rigOp" --session-id sess-t
rigAssert "a call that finds the registries fresh rewrites neither" "$rigRc $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "0 $rigRegBefore"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigOp" --session-id sess-t
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"
rigAssert "the operation is one arm of the include of the sessions; a line of the feed is made by the tracking post's own renderer and its template, and the feed file its poster empties is never read" \
	"$( LC_ALL=C grep -c -x -e "	$rigOp)" "$rigHere/AgentsTools.ManagerSession.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerSession.include" | LC_ALL=C grep -c -e 'AgentsEventTrackPostRender feed ' || : ) $( cat "$rigHere"/AgentsTools.Manager*.include "$rigHere/AgentsManagerSessionTranscript.awk" "$rigHere/AgentsManagerSessionRead.awk" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e '/feed' -e 'feed\.posting' || : )" "1 1 0"

## A MEMBER JOINS A RUNNING SESSION after the registry was built: its record is added to the sandbox folder the
## session already has, and every time is made older than the registry, so that no comparison of times could tell.
printf -- '---\nsession-id: sess-t\nspawn-id: run-j\nhost: %s\nworkspace: rigws\nowner: magic-librarian\nstatus: spawn-succeeded\nstarted-at: 2026-10-13 09:03 +0300\nresolved-at: 2026-10-13 12:00 +0300\n---\n\n# Spawn session\n' "$rigHost" > "$rigSp/sess-t/run-j.md"
rigTranscript run-j session-j.log <<'RIGLINES'
2026-10-13T07:00:07Z START session=run-j member=magic-librarian
2026-10-13T07:00:08Z ROUND n=1 in=1 cache-read=0 cache-write=0 out=1
RIGLINES
TZ=UTC touch -t 202610010000.00 "$rigSp/sess-t/run-j.md" "$rigSp/sess-t" "$rigSp"
rigJoinNewer="none-newer"
for rigJoinPath in "$rigSp" "$rigSp/sess-t" "$rigSp/sess-t/run-j.md" ; do [ ! "$rigJoinPath" -nt "$rigAgents/spawned-sessions.registry" ] || rigJoinNewer="newer:$rigJoinPath" ; done
rigAssert "control: the member's record stands in the session's own folder, nothing there is newer than the registry, and the registry holds the session and not the member" "$( ls "$rigSp/sess-t" | LC_ALL=C tr '\n' ' ' )$rigJoinNewer $( LC_ALL=C awk '$2 == "sess-t" { rows++ } $8 == "run-j" { joined++ } END { print rows + 0 ":" joined + 0 }' "$rigAgents/spawned-sessions.registry" )" "run-j.md sess-t.md none-newer 3:0"
rigRun "$rigOp" --session-id sess-t
rigAssert "a member that joined a running session after the registry was built is in the next read of that session, with its feed: its source row, and its lines after the others, in the order of their times" \
	"$rigRc $( LC_ALL=C awk -F'\t' '$1 == "source" { printf "%s:%s ", $2, $4 }' "$rigTmp/out" )/ $( rigFeed | LC_ALL=C awk '$2 == "run-j"' | LC_ALL=C tr '\n' '|' ) $( LC_ALL=C awk -F'\t' '$1 == "feed" { rows++ } END { print rows + 0 }' "$rigTmp/out" )" \
	"0 sess-t:transcript run-m:transcript run-q:session-log run-j:transcript / 2026-10-13T07:00:07Z run-j ▶️ run start|2026-10-13T07:00:08Z run-j 🧠 round 1 · in 1 · cache 0 · out 1| 8"
rigRegBefore="$( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )"
rigRun "$rigOp" --session-id sess-t
rigAssert "and the read after it rewrites no registry" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "source" { rows++ } END { print rows + 0 }' "$rigTmp/out" ) $( rigPrint "$rigAgents/spawned-sessions.registry" ) $( rigPrint "$rigAgents/pending-replies.registry" )" "0 4 $rigRegBefore"

echo "-- 7. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntaxTail"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s %s' "$rigOp" "$rigSyntaxTail" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s %s' "$rigOp" "$rigSyntaxTail" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp " "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp " "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm(){ ## row kind -- the form line of that row in the entry, its back quotes and its indent taken off
	rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$1"' <.*>\)`$/\1/p'
}
rigAssert "its entry gives the form of each of the three rows" "$( rigForm source ) | $( rigForm log ) | $( rigForm feed )" \
	"source <spawn-id> <member> <kind> <path> | log <spawn-id> <member> <text> | feed <time> <spawn-id> <member> <subject> <regarding> <text>"
rigKindsBad=""
for rigCall in "sess-t" "run-w" "run-l" "sess-t --log" ; do
	rigRun "$rigOp" --session-id $rigCall
	for rigKind in source log feed ; do
		rigKindsBad="$rigKindsBad$( LC_ALL=C awk -F'\t' -v wantKind="$rigKind" -v wantFields="$( rigForm "$rigKind" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind && NF != wantFields { bad++ } $1 != "source" && $1 != "log" && $1 != "feed" { bad++ } END { if ( bad ) printf " [%s: %s rows]", wantKind, bad }' "$rigTmp/out" )"
	done
done
rigAssert "and every row printed has exactly the fields its form names, and no line is of another kind" "${rigKindsBad:-each as its form}" "each as its form"
rigAssert "the entry says how a free text is written, the kinds of a source, the boxes of a line, what --tail counts and what --log gives" "$( for rigWord in '\t' '\\' '\r' '[redacted]' 'transcript' 'session-log' 'none' 'member' 'run' 'session' 'system' '--tail' '--log' '--run' ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyyyyyyyy"
rigAssert "control: the entry was cut up to the next operation's heading" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C grep -c -e '^		--' || : )" "1 0"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

echo "-- 8. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION TRANSCRIPT READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_TRANSCRIPT_READ: OK (%d assertions, offline)\n' "$rigPasses"
