#!/usr/bin/env bash
## Behavioural check on a fifo reader a check of sh-test starts: it ends with the check that started it,
## however that check ends -- a pass, a fail, or the check being ended at its own time bound.
## Held, in this order:
##   1. CONTROL, both directions, over tiny subjects this check writes itself. Flagged: a fifo and a
##      background reader opening it with no writer anywhere. Flagged too: a file that ends one process
##      through the shared helper and leaks a fifo reader beside it, which is the shape a file-wide
##      exemption misses. Not flagged: the same reader on a fifo the starting shell also holds open for
##      writing, so the read returns end of file when the last writing end goes; and a file that names a
##      fifo and reads it from nowhere.
##   2. THE GUARD over every file of sh-test, one judgement per reader, against the fifo that reader's own
##      file makes: a writing end held in that same file, or the shared helper, or the one allowance row.
##   3. THE MECHANISM, run rather than read: the two shapes are started as a shell that is then ended, and
##      the door's reader is gone while the bare one is still there -- which is what makes section 2's rule
##      the right rule and not a naming convention.
## The live fault this pins: two readers, pids 54299 and 61567, opened at 2026-11-23 04:20 +0200 by
## AgentsRunTestsIdentityCheck's RigLeak fixture, were still running 30 hours later, reparented to pid 1,
## their rig folder long gone, each holding one of the suite's three lanes. Why they outlived their run is
## UNMEASURED, and no cause is claimed here: the runner's bound path ends the ended test's whole process
## group and its process tree (runner-slot-keeper.py end_group, end_tree), and a reader of this shape is
## ended by that signal, so the bound cut is not shown to be the cause.
## Offline: every tree is the rig's own, and every process this check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
rigShTest="$( cd "$( dirname "$rigRunner" )" && pwd -P )"
. "$rigShTest/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigShTest/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsFifoReaderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the guard ----
## The population comes from each file's own `mkfifo` arguments, never from the shape the rule looks for,
## so a reader written some other way is still a candidate. A reader is a background process whose stdin is
## such a fifo: `exec 0<` inside its own script, or `<` redirecting it in. A door is a descriptor the same
## file holds writing that very fifo, `exec N<>` or `exec N>`, which the kernel closes whenever the file's
## process ends.
rigAwkReaders='
FNR == 1 { delete fifo ; nFifo = 0 }
{
	rest = $0
	while ( match( rest, /mkfifo[[:space:]]+("[^"]*"|[^[:space:];|&]+)/ ) ) {
		seg = substr( rest, RSTART, RLENGTH )
		sub( /^mkfifo[[:space:]]+/, "", seg ) ; gsub( /"/, "", seg )
		fifo[ ++nFifo ] = seg
		rest = substr( rest, RSTART + RLENGTH )
	}
	text[ FNR ] = $0
}
END {
	for ( i = 1 ; i <= FNR ; i++ ) {
		line = text[ i ]
		if ( line ~ /^[[:space:]]*#/ ) continue
		if ( line !~ /&[[:space:]]*\)?[[:space:]]*$/ ) continue
		reader = 0
		if ( line ~ /exec[[:space:]]+0[[:space:]]*</ ) reader = 1
		if ( line ~ /(^|[^0-9&>])<[[:space:]]*"/ ) reader = 1
		if ( !reader ) continue
		for ( k = 1 ; k <= nFifo ; k++ ) if ( index( line, fifo[ k ] ) ) { print i "\t" fifo[ k ] ; break }
	}
}'
rigAwkDoor='
BEGIN { want = ENVIRON[ "RIG_WANT" ] }
$0 ~ /^[[:space:]]*#/ { next }
/exec[[:space:]]+[0-9]+[[:space:]]*(<>|>)/ && index( $0, want ) { found = 1 }
END { if ( found ) print 1 }'
rigReaders(){ ## file -- each background fifo reader of that file as <line><tab><the fifo text its line names>
	LC_ALL=C awk "$rigAwkReaders" "$1" 2> /dev/null
}
rigDoor(){ ## file, fifo text -- 1 where that file holds a writing end on that fifo, empty otherwise
	RIG_WANT="$2" LC_ALL=C awk "$rigAwkDoor" "$1" 2> /dev/null
}
## The one allowance, and the reason it is one. The leak check's subject IS a process left running, so a
## door there would end the reader the moment the test's own shell closed and leave the net nothing to catch.
## Its own rows prove the net ends it on a run that finishes. A run ended at its bound is not covered by that
## proof: this check's live fault is exactly that path, so the row is named here rather than passed.
rigAllow(){ ## file, fifo text -- the reason this reader is allowed, or empty
	case "$1|$2" in
		"common/AgentsRunTestsLeakCheck.test.sh|"*'leak.$RIG_MARK.fifo')
			printf 'the net'"'"'s own subject: a door would end it before the net is asked' ;;
	esac
}
## A file that writes a fifo reader out as its own subject is not judged on it only where the subject has no door
## of its own: the check below writes three such subjects, and it is left out of the scan that way, as the signals
## check leaves itself out of its own. Every other file's heredoc bodies are read, since a fixture written by one
## holds both the reader and the door that ends it.
rigSelfName=""
rigLeaks(){ ## root -- each fifo reader there that no door, helper or allowance covers, as <file>:<line>:<fifo>
	[ -d "$1" ] || return 0
	if [ -z "$rigSelfName" ] ; then
		case "$0" in */*) rigSelfAbs="$( cd "${0%/*}" && pwd -P )/${0##*/}" ;; *) rigSelfAbs="$( pwd -P )/$0" ;; esac
		rigSelfName="${rigSelfAbs#"$( cd "$1" && pwd -P )"/}"
	fi
	( cd "$1" && find . -type f -name '*.sh' | LC_ALL=C sort ) | while IFS= read -r one ; do
		oneName="${one#./}"
		case "$oneName" in
			check-fixtures/rig-processes.include.sh|"$rigSelfName") continue ;;
		esac
		rigReaders "$1/$one" | while IFS="$( printf '\t' )" read -r oneLine oneFifo ; do
			[ -n "$( rigDoor "$1/$one" "$oneFifo" )" ] || [ -n "$( rigAllow "$oneName" "$oneFifo" )" ] \
				|| printf '%s:%s:%s\n' "$oneName" "$oneLine" "$oneFifo"
		done
	done
}

echo "-- 1. control, both directions: what the guard flags, and what it must not --"
mkdir -p "$rigTmp/subjects"
cat > "$rigTmp/subjects/red-shape.sh" <<'REDSHAPE'
mkfifo "$rigDir/leak.fifo" 2> /dev/null
bash -c 'exec 0<"$1" ; IFS= read -r rigLine' reader "$rigDir/leak.fifo" > /dev/null 2>&1 < /dev/null &
REDSHAPE
cat > "$rigTmp/subjects/door-shape.sh" <<'DOORSHAPE'
mkfifo "$rigDir/held.fifo" 2> /dev/null
exec 45<> "$rigDir/held.fifo"
bash -c 'exec 0<"$1" ; IFS= read -r rigLine' reader "$rigDir/held.fifo" 45>&- > /dev/null 2>&1 < /dev/null &
DOORSHAPE
cat > "$rigTmp/subjects/no-reader.sh" <<'NOREADER'
mkfifo "$rigDir/named.fifo" 2> /dev/null
printf 'a fifo named, and nothing reading it\n'
NOREADER
cat > "$rigTmp/subjects/helper-hides-one.sh" <<'HELPERHIDES'
sleep 30 &
rigProcSignalWithChildren KILL $!
mkfifo "$rigDir/leak.fifo" 2> /dev/null
bash -c 'exec 0<"$1" ; IFS= read -r rigLine' reader "$rigDir/leak.fifo" > /dev/null 2>&1 < /dev/null &
HELPERHIDES
cat > "$rigTmp/subjects/stdin-reader.sh" <<'STDINREADER'
mkfifo "$rigDir/feed" 2> /dev/null
bash -c 'IFS= read -r rigLine' reader < "$rigDir/feed" > /dev/null 2>&1 &
STDINREADER
rigAssert "a background reader on a fifo with no door is flagged" "$( rigLeaks "$rigTmp/subjects" | LC_ALL=C grep -c '^red-shape\.sh:' )" "1"
rigAssert "and the same reader on a door the shell holds is not flagged" "$( rigLeaks "$rigTmp/subjects" | LC_ALL=C grep -c '^door-shape\.sh:' || : )" "0"
rigAssert "and a file that names a fifo and reads it from nowhere is not flagged" "$( rigLeaks "$rigTmp/subjects" | LC_ALL=C grep -c '^no-reader\.sh:' || : )" "0"
rigAssert "and a file that ends another process through the helper does not thereby cover a reader it leaks" "$( rigLeaks "$rigTmp/subjects" | LC_ALL=C grep -c '^helper-hides-one\.sh:' )" "1"
rigAssert "and a reader whose stdin is redirected from the fifo, never through exec 0<, is found too" "$( rigLeaks "$rigTmp/subjects" | LC_ALL=C grep -c '^stdin-reader\.sh:' )" "1"

echo "-- 2. every fifo reader of sh-test ends with the check that starts it --"
rigAssert "no file of sh-test starts a fifo reader that outlives it: a door in that file, the shared helper, or the one named allowance" \
	"$( rigLeaks "$rigShTest" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" ""

echo "-- 3. the mechanism, run rather than read: a door ends its reader, and a bare fifo ends nothing --"
## The reading this check's rule rests on, measured here rather than trusted from a fixture's comment. Each arm
## starts a reader on a fifo of its own from THIS shell, then does the one thing that differs:
##   door -- this shell held the fifo open for writing on a descriptor, closed in the reader, and closes it now.
##   bare -- there was no such descriptor, so the reader waits in open() for a writer that never comes.
## The reader is noted through the package's helper, so the arm's own cleanup signals only what it started.
rigArmTry(){ ## door|bare -- prints "gone" or "alive", one read of the reader after the arm's own event
	local shape="$1" d readerPid
	d="$rigTmp/arm-$shape" ; mkdir -p "$d" || return 1
	rm -f "$d/held.fifo" ; mkfifo "$d/held.fifo" || return 1
	if [ "$shape" = door ] ; then
		exec 45<> "$d/held.fifo" || return 1
		bash -c 'exec 0<"$1" ; IFS= read -r rigLine' rig-fifo-arm "$d/held.fifo" 45>&- > /dev/null 2>&1 < /dev/null &
		readerPid=$! ; rigProcNote "$readerPid"
		sleep 1
		exec 45>&-
	else
		bash -c 'exec 0<"$1" ; IFS= read -r rigLine' rig-fifo-arm "$d/held.fifo" > /dev/null 2>&1 < /dev/null &
		readerPid=$! ; rigProcNote "$readerPid"
		sleep 1
	fi
	sleep 1
	rigArmWas="alive"
	ps -p "$readerPid" > /dev/null 2>&1 || rigArmWas="gone"
	printf '%s\n' "$rigArmWas"
	rigProcSignalWithChildren KILL "$readerPid" > /dev/null 2>&1
}
rigAssert "control: a reader on a fifo with no door is still there when nothing ends it" "$( rigArmTry bare )" "alive"
rigAssert "and the same reader on a door this shell holds goes when that door is closed" "$( rigArmTry door )" "gone"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS FIFO READER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_FIFO_READER: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
