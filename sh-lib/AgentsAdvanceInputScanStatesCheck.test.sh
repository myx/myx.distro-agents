#!/usr/bin/env bash
## Behavioural check on --magic-advance-input-scan, run rather than read, against a
## scenario board built here. Holds: one item placed in each active board state comes
## back as its own `## <state>/<item-filename>` row, except backlog, which is grooming's
## (the owner's "grooming reads backlog+inquiries+notes, advance does not"). Offline by construction.
## Also holds the scan's bookkeeping rows, each against a fake data root and a fake workspace
## of this rig's own, each with a control that holds on today's behaviour and a second pass
## that must change nothing: the reviewer rewrite on board/review items, dead and live dispatches,
## unclosed and live registry rows, nothing about it on stdout or stderr, one report post to the
## event-track thread (a fake curl first on PATH), and the processed-item GC taking its sandbox folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsAdvanceInputScanStatesCheck-XXXXXXXX" )" || exit 1
rigHolder=""
trap '[ -z "$rigHolder" ] || { kill "$rigHolder" ; wait "$rigHolder" ; } 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws" "$rigTmp/home/.claude/skills/magic-coordinator" "$rigTmp/data/inboxes/magic-coordinator"
printf '# magic-coordinator\n' > "$rigTmp/home/.claude/skills/magic-coordinator/SKILL.md"
for rigState in backlog pending running blocked parked ; do
	mkdir -p "$rigTmp/data/board/$rigState"
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item in %s\n' "$rigState" > "$rigTmp/data/board/$rigState/task-rig-$rigState.md"
done

rigOut="$( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
	bash "$rigTool" --magic-advance-input-scan magic-coordinator 2>/dev/null )" || rigRefuse "--magic-advance-input-scan magic-coordinator failed"

## The subject has to be reachable before anything is asserted about it.
printf '%s\n' "$rigOut" | grep -q '^## running/task-rig-running\.md$' || rigRefuse "the running item, which every revision scans, came back missing, so no state below would be measured"

rigFails=0 rigPasses=0
if printf '%s\n' "$rigOut" | grep -q '^## backlog/task-rig-backlog\.md$' ; then
	printf '  FAIL  the backlog item is in the scan, and backlog is grooming'"'"'s\n'
	rigFails=$(( rigFails + 1 ))
else
	printf '  PASS  the backlog item is not in the scan\n'
	rigPasses=$(( rigPasses + 1 ))
fi
for rigState in pending running blocked parked ; do
	if printf '%s\n' "$rigOut" | grep -q "^## $rigState/task-rig-$rigState\\.md\$" ; then
		printf '  PASS  the %s item comes back as a %s/ row\n' "$rigState" "$rigState"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  the %s item is missing from the scan\n' "$rigState"
		rigFails=$(( rigFails + 1 ))
	fi
done

rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigCheck(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigNew(){ ## rig name -- a fresh fake workspace, data root and home of this rig's own; sets rigW rigD rigH
	rigW="$rigTmp/$1/ws" rigD="$rigTmp/$1/data" rigH="$rigTmp/$1/home"
	mkdir -p "$rigW/.local/agents/spawned" "$rigD/inboxes/magic-coordinator" "$rigD/board/running" "$rigD/board/review" "$rigD/board/processed" "$rigH/.claude/skills/magic-coordinator"
	printf '# magic-coordinator\n' > "$rigH/.claude/skills/magic-coordinator/SKILL.md"
}
rigExtraEnv=()
rigRun(){ ## result file, DistroAgentsTools.fn.sh arguments... -- one op against the current rig, its rc into <result>.rc
	local runOut="$1" ; shift
	case "$rigW" in "$rigTmp"/*) ;; *) rigRefuse "the fake workspace is outside this rig's own tree: $rigW" ;; esac
	case "$rigD" in "$rigTmp"/*) ;; *) rigRefuse "the fake data root is outside this rig's own tree: $rigD" ;; esac
	## File descriptor 4 is the daemon line: a file of this rig's own when rigFd4 is set, closed otherwise.
	if [ -n "${rigFd4:-}" ] ; then
		rigRunBody "$@" > "$runOut" 2> "$runOut.err" 4>> "$rigFd4"
	else
		rigRunBody "$@" > "$runOut" 2> "$runOut.err" 4>&-
	fi
	printf '%s' "$?" > "$runOut.rc"
}
rigRunBody(){ ## DistroAgentsTools.fn.sh arguments...
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" \
		${rigExtraEnv[@]+"${rigExtraEnv[@]}"} bash "$rigTool" "$@" )
}
rigFd4=""
rigScan(){ ## result file -- one --magic-advance-input-scan pass
	rigRun "$1" --magic-advance-input-scan magic-coordinator
	[ "$( cat "$1.rc" )" = 0 ] || rigRefuse "--magic-advance-input-scan failed in the rig: $( tail -2 "$1.err" )"
}
rigSnap(){ ## rig name -- every file of that rig's workspace and data root with its checksum, one line each
	( cd "$rigTmp/$1" && find ws data -type f | LC_ALL=C sort | while IFS= read -r snapFile ; do printf '%s %s\n' "$snapFile" "$( cksum < "$snapFile" )" ; done )
}
rigSame(){ ## file, file -- same or different
	cmp -s "$1" "$2" && printf same || printf different
}
rigHk(){ ## file -- its housekeeping: lines, sorted
	LC_ALL=C grep '^housekeeping: ' "$1" 2> /dev/null | LC_ALL=C sort
}
rigLines(){ ## scenario dir -- the housekeeping: lines of the text posted to the fake Slack, sorted
	LC_ALL=C sed 's/","thread_ts".*//' "$1/bodies.log" 2> /dev/null | LC_ALL=C awk '{ gsub(/\\n/, "\n") ; print }' | LC_ALL=C grep '^housekeeping: ' | LC_ALL=C sort
}
rigNoHk(){ ## file -- everything but its housekeeping: lines
	LC_ALL=C grep -v '^housekeeping: ' "$1" 2> /dev/null || :
}
rigSameNoHk(){ ## file, file -- same or different, housekeeping: lines ignored in both
	rigNoHk "$1" | cmp -s - <( rigNoHk "$2" ) && printf same || printf different
}
rigLoc(){ ## item filename -- which board/<state>/ of the current rig holds it, or not-found
	local locDir
	for locDir in "$rigD"/board/*/ ; do
		[ -f "$locDir$1" ] && { basename "$locDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigHeader(){ ## file, header name -- that header's value, or absent
	LC_ALL=C awk -v want="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } index($0, want ": ") == 1 { print substr($0, length(want) + 3) ; found = 1 ; exit } END { if ( ! found ) print "absent" }' "$1" 2> /dev/null || printf 'absent'
}
rigHasLine(){ ## file, whole line -- yes or no
	LC_ALL=C grep -q -x -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
rigSection(){ ## scan output file, heading text -- the lines of that ## section
	LC_ALL=C awk -v want="## $2" '$0 == want { on = 1 ; next } /^## / { on = 0 } on' "$1"
}
rigPresent(){ ## path -- present or gone
	[ -e "$1" ] || [ -L "$1" ] && printf present || printf gone
}
rigStamp(){ ## hours ago -- a touch -t stamp, BSD or GNU date
	local stampEpoch=$(( $( date +%s ) - $1 * 3600 ))
	date -r "$stampEpoch" +%Y%m%d%H%M 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M
}
rigAge(){ ## path, hours ago -- ages that path and everything under it
	find "$1" -exec touch -t "$( rigStamp "$2" )" {} +
}
rigAgeMin(){ ## path, minutes ago -- ages that path and everything under it
	local stampEpoch=$(( $( date +%s ) - $2 * 60 )) stampText
	stampText="$( date -r "$stampEpoch" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M.%S )"
	find "$1" -exec touch -t "$stampText" {} +
}
rigItem(){ ## board state, item filename, type, status or none, review-by or none, session and spawn id or none
	{
		printf -- '---\ntype: %s\nowner: rig-member\n' "$3"
		[ "$4" = none ] || printf 'status: %s\n' "$4"
		[ "$5" = none ] || printf 'review-by: %s\n' "$5"
		[ "$6" = none ] || printf 'session-id: %s\nspawn-id: %s\n' "$6" "$6"
		printf -- '---\n\nrig item\n'
	} > "$rigD/board/$1/$2"
}
rigDispatch(){ ## session id, status -- a running dispatch item for that session
	rigItem running "dispatch-$1.md" dispatch "$2" none "$1"
}
rigSandbox(){ ## session id, host, status, extra header lines -- a sandbox with its session record, in the current rig
	local sbDir="$rigW/.local/agents/spawned/$1"
	mkdir -p "$sbDir/input" "$sbDir/output"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nowner: rig-member\nstatus: %s\nspawns: dispatch-%s\n' "$1" "$1" "$1" "$2" "$3" "$1"
		[ -z "${4:-}" ] || printf '%s\n' "$4"
		printf -- '---\n'
	} > "$sbDir/$1.md"
}
rigDone(){ ## session id, exit code, armed, extra header lines -- a closed record on this host
	rigSandbox "$1" "$rigHost" spawn-succeeded "exit-code: $2"$'\n'"armed: $3${4:+$'\n'$4}"
}
rigRegRow(){ ## scan output file, tracking name -- "status state" of that row of the spawned sessions section
	rigSection "$1" 'spawned sessions' | LC_ALL=C awk -v want="$2" '$1 == want && NF >= 13 { print $6 " " $NF ; found = 1 ; exit } END { if ( ! found ) print "no-row" }'
}
rigSum(){ ## file -- its checksum
	cksum < "$1"
}

## One process whose arguments carry a session id, started before the first scan below, so that
## one live session exists for every rig to see. It is the live control of the review, dispatch
## and registry rows alike.
( exec -a "rig-holder rig-live" sleep 300 ) &
rigHolder=$!
sleep 1

echo "-- board-review: the scan moves no review item, and rewrites review-by only for an ended reviewer session --"
rigNew b1
rigHeadings(){ ## scan output file -- how many stdout lines open a housekeeping or review queue section
	LC_ALL=C grep -c -E '^## (review queue|spawn housekeeping)' "$1" || :
}
rigSandbox rig-live "$rigHost" spawn-started
rigSandbox rig-ended "$rigHost" spawn-succeeded "exit-code: 0"$'\n'"armed: yes"
rigSandbox rig-asked "$rigHost" spawn-started ; rigAge "$rigW/.local/agents/spawned/rig-asked" 48
mkdir -p "$rigW/.local/agents/pending"
printf -- '---\nsession-id: rig-asked\nowner: rig-member\nstatus: reply-pending\nblocked-on: -\ncommunication-channel-id: -\n---\n' > "$rigW/.local/agents/pending/rig-asked-open.md"
rigItem review task-rig-rv-none.md task none none none
rigItem review task-rig-rv-human.md task none human-owner none
rigItem review task-rig-rv-barec.md task none magic-coordinator none
rigItem review task-rig-rv-bared.md task none magic-developer none
rigItem review task-rig-rv-ended.md task none rig-ended none
rigItem review task-rig-rv-endedm.md task none rig-ended:magic-developer none
rigItem review task-rig-rv-live.md task none rig-live none
rigItem review task-rig-rv-livem.md task none rig-live:magic-developer none
rigItem review task-rig-rv-asked.md task none rig-asked none
rigItem review task-rig-rv-young.md task none rig-nobody none
rigItem review task-rig-rv-aged.md task none rig-nobody2 none ; touch -t "$( rigStamp 48 )" "$rigD/board/review/task-rig-rv-aged.md"
rigItem review dispatch-rig-rv-triv.md dispatch dispatch-succeeded magic-coordinator rig-triv ; rigDone rig-triv 0 yes
rigItem review task-rig-rv-advr.md task none advance.routine none ; touch -t "$( rigStamp 48 )" "$rigD/board/review/task-rig-rv-advr.md"
rigRevSnap(){ ( cd "$rigD/board/review" && for revFile in *.md ; do printf '%s %s\n' "$revFile" "$( cksum < "$revFile" )" ; done ) }
rigUnchanged(){ ## item filename -- the checksum line of that item before and after the first scan
	[ "$( LC_ALL=C grep -F -x -- "$1 $( cksum < "$rigD/board/review/$1" )" "$rigTmp/b1.rev0" || printf missing )" != missing ] && printf same || printf different
}
rigRevSnap > "$rigTmp/b1.rev0"
LC_ALL=C grep -v '^review-by: ' "$rigD/board/review/task-rig-rv-ended.md" > "$rigTmp/b1.ended.before"
rigScan "$rigTmp/b1.s1" ; rigSnap b1 > "$rigTmp/b1.snap1"
rigScan "$rigTmp/b1.s2" ; rigSnap b1 > "$rigTmp/b1.snap2"
rigRb(){ ## item filename, expected review-by -- the review-by that item holds after the scan
	rigCheck "$1: review-by" "$( rigHeader "$rigD/board/review/$1" review-by )" "$2"
}
echo "   nothing leaves board/review"
rigCheck "control: all 13 review items are still in board/review"      "$( find "$rigD/board/review" -name '*.md' | LC_ALL=C grep -c . || : )" 13
rigCheck "control: the item with no review-by stays without one"        "$( rigHeader "$rigD/board/review/task-rig-rv-none.md" review-by )" absent
echo "   the reviewer rewrite"
rigRb task-rig-rv-ended.md  magic-coordinator
rigRb task-rig-rv-endedm.md magic-coordinator
rigRb task-rig-rv-aged.md   magic-coordinator
rigRb task-rig-rv-advr.md   advance.routine
rigCheck "a rewritten item keeps exactly one review-by line"            "$( LC_ALL=C grep -c '^review-by: ' "$rigD/board/review/task-rig-rv-ended.md" || : )" 1
rigCheck "a rewritten item keeps its body"                              "$( rigHasLine "$rigD/board/review/task-rig-rv-ended.md" 'rig item' )" yes
rigCheck "a rewritten item is identical to before except its review-by line" "$( LC_ALL=C grep -v '^review-by: ' "$rigD/board/review/task-rig-rv-ended.md" | cmp -s - "$rigTmp/b1.ended.before" && printf same || printf different )" same
rigRb task-rig-rv-human.md  human-owner
rigRb task-rig-rv-bared.md  magic-developer
rigRb task-rig-rv-live.md   rig-live
rigRb task-rig-rv-livem.md  rig-live:magic-developer
rigRb task-rig-rv-asked.md  rig-asked
rigRb task-rig-rv-young.md  rig-nobody
for rigKept in task-rig-rv-advr.md task-rig-rv-none.md task-rig-rv-human.md task-rig-rv-barec.md task-rig-rv-bared.md task-rig-rv-live.md task-rig-rv-livem.md task-rig-rv-asked.md task-rig-rv-young.md dispatch-rig-rv-triv.md ; do
	rigCheck "control: $rigKept is byte-identical after the scan"          "$( rigUnchanged "$rigKept" )" same
done
echo "   the scan's result carries nothing about it"
rigCheck "no stdout line opens a review queue or spawn housekeeping section" "$( rigHeadings "$rigTmp/b1.s1" )" 0
rigCheck "control: the review digest row of a review item is there"     "$( rigHasLine "$rigTmp/b1.s1" '## review/task-rig-rv-none.md' )" yes
rigCheck "control: the spawned sessions heading is there"               "$( rigHasLine "$rigTmp/b1.s1" '## spawned sessions' )" yes
echo "   second pass and the coordinator's own move"
rigCheck "a second pass changes nothing"                                "$( rigSame "$rigTmp/b1.snap1" "$rigTmp/b1.snap2" )" same
rigCheck "and prints no section either"                                 "$( rigHeadings "$rigTmp/b1.s2" )" 0
rigCheck "an aged advance.routine item is still advance.routine after the second scan" "$( rigHeader "$rigD/board/review/task-rig-rv-advr.md" review-by )" advance.routine
rigCheck "control: an aged item with an unregistered session id was rewritten, in the same two scans" "$( rigHeader "$rigD/board/review/task-rig-rv-aged.md" review-by )" magic-coordinator
rigRun "$rigTmp/b1.mv" --magic-board-to-processed magic-coordinator dispatch-rig-rv-triv.md --from-state:review
rigCheck "the coordinator's own move review -> processed succeeds"      "$( cat "$rigTmp/b1.mv.rc" )" 0
rigCheck "the item is now in board/processed"                           "$( rigLoc dispatch-rig-rv-triv.md )" processed
rigNew b1e
rigScan "$rigTmp/b1e.s1"
rigCheck "an empty board prints no such section either"                 "$( rigHeadings "$rigTmp/b1e.s1" )" 0

echo "-- dead dispatches: a dead session is closed, a live or recent one is not, twice --"
rigNew b2
rigDir(){ printf '%s\n' "$rigW/.local/agents/spawned/$1" ; }
rigSandbox rig-ldead "$rigHost" spawn-started ; rigDispatch rig-ldead dispatch-started ; rigAge "$( rigDir rig-ldead )" 48
rigSandbox rig-lfresh "$rigHost" spawn-started ; rigDispatch rig-lfresh dispatch-started ; rigAge "$( rigDir rig-lfresh )" 48 ; : > "$( rigDir rig-lfresh )/input/still-writing.md"
rigSandbox rig-live "$rigHost" spawn-started ; rigDispatch rig-live dispatch-started ; rigAge "$( rigDir rig-live )" 48
rigSandbox rig-fdead rig-elsewhere spawn-started ; rigDispatch rig-fdead dispatch-started ; rigAge "$( rigDir rig-fdead )" 48
rigSandbox rig-falive rig-elsewhere spawn-started ; rigDispatch rig-falive dispatch-started ; rigAge "$( rigDir rig-falive )" 1
mkdir -p "$( rigDir rig-nospawn )/input"
printf -- '---\nsession-id: rig-nospawn\ntracking-name: rig-nospawn\nhost: %s\nowner: rig-member\nstatus: spawn-started\nspawns: dispatch-rig-nospawn\n---\n' "$rigHost" > "$( rigDir rig-nospawn )/rig-nospawn.md"
rigItem running dispatch-rig-nospawn.md dispatch dispatch-started none none ; rigAge "$( rigDir rig-nospawn )" 48
rigSandbox rig-lask "$rigHost" spawn-started ; rigDispatch rig-lask dispatch-started ; rigAge "$( rigDir rig-lask )" 48
mkdir -p "$rigW/.local/agents/pending"
printf -- '---\nsession-id: rig-lask\nowner: rig-member\nstatus: reply-pending\nblocked-on: -\ncommunication-channel-id: -\n---\n' > "$rigW/.local/agents/pending/rig-lask-open.md"
rigSandbox rig-crec "$rigHost" spawn-succeeded "exit-code: 0" ; rigDispatch rig-crec dispatch-started ; rigAge "$( rigDir rig-crec )" 48
rigItem running dispatch-rig-norec-old.md dispatch dispatch-started none rig-norec-old ; touch -t "$( rigStamp 48 )" "$rigD/board/running/dispatch-rig-norec-old.md"
rigItem running dispatch-rig-norec-new.md dispatch dispatch-started none rig-norec-new
mkdir -p "$( rigDir rig-sb )/input"
printf -- '---\nsession-id: rig-sb\nspawn-id: rig-sb\ntracking-name: rig-sb\nhost: %s\nowner: rig-member\nstatus: spawn-started\nspawned-by: task-rig-sb\n---\n' "$rigHost" > "$( rigDir rig-sb )/rig-sb.md"
rigItem running task-rig-sb.md task dispatch-started none none ; rigAge "$( rigDir rig-sb )" 48
rigSandbox rig-l30 "$rigHost" spawn-started ; rigDispatch rig-l30 dispatch-started ; rigAgeMin "$( rigDir rig-l30 )" 30
rigSandbox rig-l5 "$rigHost" spawn-started ; rigDispatch rig-l5 dispatch-started ; rigAgeMin "$( rigDir rig-l5 )" 5
rigSandbox rig-sessold "$rigHost" spawn-started ; rigDispatch rig-sessold dispatch-started ; rigAge "$( rigDir rig-sessold )" 48
mkdir -p "$rigW/.local/agents/sessions/rig-sessold" ; : > "$rigW/.local/agents/sessions/rig-sessold/log.txt" ; rigAge "$rigW/.local/agents/sessions/rig-sessold" 48
rigSandbox rig-sessnew "$rigHost" spawn-started ; rigDispatch rig-sessnew dispatch-started ; rigAge "$( rigDir rig-sessnew )" 48
mkdir -p "$rigW/.local/agents/sessions/rig-sessnew" ; : > "$rigW/.local/agents/sessions/rig-sessnew/log.txt" ; rigAgeMin "$rigW/.local/agents/sessions/rig-sessnew" 5
rigSandbox rig-ldeadrb "$rigHost" spawn-started ; rigItem running dispatch-rig-ldeadrb.md dispatch dispatch-started rig-ldeadrb rig-ldeadrb ; rigAge "$( rigDir rig-ldeadrb )" 48
for rigId in rig-lfresh rig-live rig-falive rig-nospawn rig-lask rig-crec ; do
	printf '%s %s\n' "$rigId" "$( rigSum "$( rigDir "$rigId" )/$rigId.md" )"
done > "$rigTmp/b2.sums0"
rigScan "$rigTmp/b2.s1" ; rigSnap b2 > "$rigTmp/b2.snap1"
for rigId in rig-lfresh rig-live rig-falive rig-nospawn rig-lask rig-crec ; do
	printf '%s %s\n' "$rigId" "$( rigSum "$( rigDir "$rigId" )/$rigId.md" )"
done > "$rigTmp/b2.sums1"
rigScan "$rigTmp/b2.s2" ; rigSnap b2 > "$rigTmp/b2.snap2"
rigRec(){ ## session id -- that session's record file
	printf '%s\n' "$( rigDir "$1" )/$1.md"
}
rigItemFile(){ ## item filename -- that item's file in whichever state holds it
	printf '%s\n' "$rigD/board/$( rigLoc "$1" )/$1"
}
echo "   local dead session"
rigCheck "record status is spawn-ended-without-close" "$( rigHeader "$( rigRec rig-ldead )" status )" spawn-ended-without-close
rigCheck "record exit-code is unknown"                "$( rigHeader "$( rigRec rig-ldead )" exit-code )" unknown
rigCheck "record has a resolved-at"                   "$( [ "$( rigHeader "$( rigRec rig-ldead )" resolved-at )" != absent ] && printf yes || printf no )" yes
rigCheck "record has an armed"                        "$( [ "$( rigHeader "$( rigRec rig-ldead )" armed )" != absent ] && printf yes || printf no )" yes
rigCheck "the dispatch item moved to board/review"    "$( rigLoc dispatch-rig-ldead.md )" review
rigCheck "its status is dispatch-ended-without-close" "$( rigHeader "$( rigItemFile dispatch-rig-ldead.md )" status )" dispatch-ended-without-close
rigCheck "it has a resolved-at"                       "$( [ "$( rigHeader "$( rigItemFile dispatch-rig-ldead.md )" resolved-at )" != absent ] && printf yes || printf no )" yes
rigCheck "its body carries the Result block"          "$( rigHasLine "$( rigItemFile dispatch-rig-ldead.md )" '## Result' )" yes
rigCheck "the Result block says ended-without-close"  "$( rigHasLine "$( rigItemFile dispatch-rig-ldead.md )" 'status: ended-without-close' )" yes
rigCheck "the Result block says exit-code unknown"    "$( rigHasLine "$( rigItemFile dispatch-rig-ldead.md )" 'exit-code: unknown' )" yes
echo "   remote session, by the age of its newest file"
rigCheck "foreign dead: record status"                "$( rigHeader "$( rigRec rig-fdead )" status )" spawn-ended-without-close
rigCheck "foreign dead: item moved to board/review"   "$( rigLoc dispatch-rig-fdead.md )" review
rigCheck "foreign dead: item status"                  "$( rigHeader "$( rigItemFile dispatch-rig-fdead.md )" status )" dispatch-ended-without-close
rigCheck "control: foreign alive keeps its item in running"   "$( rigLoc dispatch-rig-falive.md )" running
echo "   sessions that must stay open"
rigCheck "control: live process keeps its item in running, though its files are 48 h old" "$( rigLoc dispatch-rig-live.md )" running
rigCheck "control: live process, record still spawn-started"  "$( rigHeader "$( rigRec rig-live )" status )" spawn-started
rigCheck "control: dead but a file written just now (still closing): item stays"   "$( rigLoc dispatch-rig-lfresh.md )" running
rigCheck "control: dead but a file written just now: record stays"                 "$( rigHeader "$( rigRec rig-lfresh )" status )" spawn-started
rigCheck "dead but an open ask against its session: item stays"                    "$( rigLoc dispatch-rig-lask.md )" running
rigCheck "dead but an open ask against its session: record stays"                  "$( rigHeader "$( rigRec rig-lask )" status )" spawn-started
rigCheck "a record with no spawn-id and a process list present is not closed"      "$( rigHeader "$( rigRec rig-nospawn )" status )" spawn-started
rigCheck "and its item stays in running"                                           "$( rigLoc dispatch-rig-nospawn.md )" running
rigCheck "no stdout line opens a review queue or spawn housekeeping section"        "$( rigHeadings "$rigTmp/b2.s1" )" 0
rigCheck "the open records are byte-identical after the scan"                      "$( rigSame "$rigTmp/b2.sums0" "$rigTmp/b2.sums1" )" same
echo "   items whose record is already closed or missing"
rigCheck "that item moved to board/review"                                "$( rigLoc dispatch-rig-crec.md )" review
rigCheck "with the record's outcome as its status"                        "$( rigHeader "$( rigItemFile dispatch-rig-crec.md )" status )" dispatch-succeeded
rigCheck "no record, item older than 24 h: moved to board/review"         "$( rigLoc dispatch-rig-norec-old.md )" review
rigCheck "and closed as ended-without-close"                              "$( rigHeader "$( rigItemFile dispatch-rig-norec-old.md )" status )" dispatch-ended-without-close
rigCheck "control: no record, item young: stays in running"               "$( rigLoc dispatch-rig-norec-new.md )" running
rigCheck "control: and stays dispatch-started"                            "$( rigHeader "$( rigItemFile dispatch-rig-norec-new.md )" status )" dispatch-started
echo "   the 15 minute local window and the session folder signal"
rigCheck "dead, newest file 30 minutes old: closed"                       "$( rigHeader "$( rigRec rig-l30 )" status )" spawn-ended-without-close
rigCheck "control: dead, newest file 5 minutes old: still open"           "$( rigHeader "$( rigRec rig-l5 )" status )" spawn-started
rigCheck "control: and its item stays in running"                         "$( rigLoc dispatch-rig-l5.md )" running
rigCheck "dead, sessions/<id>/ stale (48 h): closed"                      "$( rigHeader "$( rigRec rig-sessold )" status )" spawn-ended-without-close
rigCheck "control: dead, sessions/<id>/ written 5 minutes ago: open"      "$( rigHeader "$( rigRec rig-sessnew )" status )" spawn-started
rigCheck "control: and its item stays in running"                         "$( rigLoc dispatch-rig-sessnew.md )" running
echo "   nothing on stdout or stderr"
rigCheck "an acting scan prints no housekeeping text on stdout"           "$( LC_ALL=C grep -c -i -E 'housekeeping|^closed |closed the record' "$rigTmp/b2.s1" || : )" 0
rigCheck "with fd 4 closed, the acting scan's housekeeping lines are on stderr (the daemon line)" "$( [ "$( rigHk "$rigTmp/b2.s1.err" | LC_ALL=C awk 'END { print NR }' )" -ge 5 ] && printf yes || printf no )" yes
rigCheck "control: apart from those lines, its stderr is byte-identical to a scan with nothing to do" "$( rigSameNoHk "$rigTmp/b2.s1.err" "$rigTmp/b1e.s1.err" )" same
rigCheck "and the second scan puts no housekeeping line on stderr"        "$( LC_ALL=C grep -c '^housekeeping: ' "$rigTmp/b2.s2.err" || : )" 0
echo "   a close and the reviewer rewrite in the same scan"
rigCheck "the dead dispatch is moved to board/review"                     "$( rigLoc dispatch-rig-ldeadrb.md )" review
rigCheck "its review-by, naming the session just closed, is rewritten in that same scan" "$( rigHeader "$( rigItemFile dispatch-rig-ldeadrb.md )" review-by )" magic-coordinator
echo "   record linked by spawned-by"
rigCheck "the record is closed"                                           "$( rigHeader "$( rigRec rig-sb )" status )" spawn-ended-without-close
rigCheck "its item stays in its own state"                                "$( rigLoc task-rig-sb.md )" running
rigCheck "its item carries the Result block"                              "$( rigHasLine "$( rigItemFile task-rig-sb.md )" '## Result' )" yes
rigCheck "its item status names ended-without-close"                      "$( rigHeader "$( rigItemFile task-rig-sb.md )" status | LC_ALL=C grep -c 'ended-without-close$' || : )" 1
echo "   registry rows, rebuilt in the same pass"
rigCheck "the unclosed local row is now closed and finished"              "$( rigRegRow "$rigTmp/b2.s1" rig-ldead )" "spawn-ended-without-close finished"
rigCheck "the unclosed foreign row is now closed and finished"            "$( rigRegRow "$rigTmp/b2.s1" rig-fdead )" "spawn-ended-without-close finished"
rigCheck "control: the live row is untouched and running"                 "$( rigRegRow "$rigTmp/b2.s1" rig-live )" "spawn-started running"
rigCheck "control: the recent dead row stays unclosed"                    "$( rigRegRow "$rigTmp/b2.s1" rig-lfresh )" "spawn-started unclosed"
rigCheck "control: the foreign alive row stays unknown-foreign"           "$( rigRegRow "$rigTmp/b2.s1" rig-falive )" "spawn-started unknown-foreign"
rigCheck "control: the row with no spawn-id stays unclosed"               "$( rigRegRow "$rigTmp/b2.s1" rig-nospawn )" "spawn-started unclosed"
rigCheck "control: the row with an open ask stays waiting"                "$( rigRegRow "$rigTmp/b2.s1" rig-lask )" "spawn-started waiting"
echo "   second pass"
rigCheck "a second pass changes nothing"                                  "$( rigSame "$rigTmp/b2.snap1" "$rigTmp/b2.snap2" )" same
rigCheck "and prints no such section either"                                      "$( rigHeadings "$rigTmp/b2.s2" )" 0

echo "-- the report: one post to the advance spawn's event-track thread per acting pass, none otherwise --"
rigFake="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/check-fixtures/credential-exposure-check.curl.test.sh"
[ -f "$rigFake" ] || rigRefuse "the fake curl fixture is missing: $rigFake"
mkdir -p "$rigTmp/bin" && cp "$rigFake" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
rigPosts(){ ## scenario dir -- how many chat.postMessage calls reached the fake curl
	[ -f "$1/argv.log" ] || { printf 0 ; return 0 ; }
	LC_ALL=C grep -c 'chat.postMessage' "$1/argv.log" || :
}
rigPostSetup(){ ## rig name, thread file yes|no -- one rig with a dead local dispatch, a fake curl first on PATH and a spawn sandbox root
	rigNew "$1"
	mkdir -p "$rigW/.local/.agents" "$rigW/.local/temp" "$rigTmp/$1/scenario" "$rigTmp/$1/sandbox"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-token-%s\n' "$$" > "$rigW/.local/.agents/magic-team.agent.env"
	[ "$2" != yes ] || printf 'CRIG00001:1.000001\n' > "$rigTmp/$1/sandbox/event-track.thread"
	rigExtraEnv=( PATH="$rigTmp/bin:$PATH" TMPDIR="$rigW/.local/temp" RIG_SCENARIO="$rigTmp/$1/scenario" RIG_WS="$rigW" RIG_MODE=ok RIG_SENTINEL="rig-token-$$" RIG_SENTINEL_B64=none MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/$1/sandbox" )
	rigSandbox rig-d1 "$rigHost" spawn-started ; rigDispatch rig-d1 dispatch-started ; rigAgeMin "$rigW/.local/agents/spawned/rig-d1" 120
	rigSandbox rig-r1 "$rigHost" spawn-succeeded "exit-code: 0" ; rigItem review task-rig-r1.md task none rig-r1 none
}
rigPostSetup b5 yes
rigCheck "control: the fake curl is first on PATH"                        "$( PATH="$rigTmp/bin:$PATH" command -v curl )" "$rigTmp/bin/curl"
rigScan "$rigTmp/b5.s1"
rigCheck "the acting pass closed the dead dispatch"                       "$( rigLoc dispatch-rig-d1.md )" review
rigCheck "exactly one post reached the thread"                            "$( rigPosts "$rigTmp/b5/scenario" )" 1
rigPostText(){ ## scenario dir -- the text field of the posted body, the blocks copy cut off
	LC_ALL=C sed 's/","thread_ts".*//' "$1/bodies.log" 2> /dev/null
}
rigCheck "the post's text names the closed item"                          "$( rigPostText "$rigTmp/b5/scenario" | LC_ALL=C grep -o 'dispatch-rig-d1.md' | LC_ALL=C awk 'END { print NR ; }' )" 1
rigCheck "one line per action, each opening with 'housekeeping: ' (the record, the item, the review-by)" "$( rigPostText "$rigTmp/b5/scenario" | LC_ALL=C grep -o 'housekeeping: ' | LC_ALL=C awk 'END { print NR ; }' )" 3
rigCheck "the review-by action is one of those lines"                     "$( rigPostText "$rigTmp/b5/scenario" | LC_ALL=C grep -c 'housekeeping: task-rig-r1.md review-by -> magic-coordinator' || : )" 1
rigCheck "the post went to the thread named in event-track.thread"        "$( LC_ALL=C grep -c '1.000001' "$rigTmp/b5/scenario/bodies.log" 2> /dev/null || : )" 1
rigCheck "stdout carries none of the post's text"                         "$( LC_ALL=C grep -c -i -E 'housekeeping|closed the record' "$rigTmp/b5.s1" || : )" 0
rigCheck "with fd 4 closed, stderr carries the post's lines (the daemon line), the same set" "$( rigHk "$rigTmp/b5.s1.err" | cmp -s - <( rigLines "$rigTmp/b5/scenario" ) && printf same || printf different )" same
rigScan "$rigTmp/b5.s2"
rigCheck "the second pass posts nothing more"                             "$( rigPosts "$rigTmp/b5/scenario" )" 1
rigPostSetup b6 no
rigScan "$rigTmp/b6.s1"
rigCheck "no thread file: the scan still succeeds and closes the dispatch" "$( rigLoc dispatch-rig-d1.md )" review
rigCheck "no thread file: nothing is posted"                              "$( rigPosts "$rigTmp/b6/scenario" )" 0
rigCheck "no thread file: apart from the daemon lines stderr is that of a scan with nothing to do, so no error" "$( rigSameNoHk "$rigTmp/b6.s1.err" "$rigTmp/b1e.s1.err" )" same
rigCheck "no thread file: the daemon lines are still on stderr"          "$( rigHk "$rigTmp/b6.s1.err" | LC_ALL=C awk 'END { print NR }' )" 3
rigExtraEnv=()

echo "-- the daemon line: file descriptor 4 carries each report line, and never the agent's output --"
rigLines(){ ## scenario dir -- the housekeeping: lines of the posted text, sorted
	rigPostText "$1" | LC_ALL=C awk '{ gsub(/\\n/, "\n") ; print }' | LC_ALL=C grep '^housekeeping: ' | LC_ALL=C sort
}
rigPostSetup b7 yes
rigFd4="$rigTmp/b7.fd4" ; : > "$rigFd4"
rigScan "$rigTmp/b7.s1"
rigCheck "the acting scan wrote 3 lines on fd 4"                          "$( LC_ALL=C awk 'END { print NR }' "$rigFd4" )" 3
rigCheck "they are the same lines the event-track stub got"               "$( LC_ALL=C sort "$rigFd4" | cmp -s - <( rigLines "$rigTmp/b7/scenario" ) && printf same || printf different )" same
rigCheck "control: the stub did get a post"                               "$( rigPosts "$rigTmp/b7/scenario" )" 1
rigCheck "stdout carries none of them"                                    "$( LC_ALL=C grep -c 'housekeeping: ' "$rigTmp/b7.s1" || : )" 0
rigCheck "stderr carries none of them"                                    "$( LC_ALL=C grep -c 'housekeeping: ' "$rigTmp/b7.s1.err" || : )" 0
rigFd4Sum="$( rigSum "$rigFd4" )"
rigScan "$rigTmp/b7.s2"
rigCheck "second pass: nothing more on fd 4"                              "$( rigSum "$rigFd4" )" "$rigFd4Sum"
rigCheck "second pass: no second post"                                    "$( rigPosts "$rigTmp/b7/scenario" )" 1
rigFd4=""
rigPostSetup b8 yes
rigScan "$rigTmp/b8.s1"
rigCheck "control, fd 4 closed: the call still succeeds and posts once"   "$( rigPosts "$rigTmp/b8/scenario" )" 1
rigCheck "control, fd 4 closed: nothing on stdout"                        "$( LC_ALL=C grep -c 'housekeeping: ' "$rigTmp/b8.s1" || : )" 0
rigCheck "control, fd 4 closed: the lines go to stderr instead, the same set the stub got" "$( rigHk "$rigTmp/b8.s1.err" | cmp -s - <( rigLines "$rigTmp/b8/scenario" ) && printf same || printf different )" same
rigCheck "control, fd 4 closed: apart from those lines stderr is that of a scan with nothing to do" "$( rigSameNoHk "$rigTmp/b8.s1.err" "$rigTmp/b1e.s1.err" )" same
rigExtraEnv=()
echo "   the final GC reports to fd 4 too"
rigNew b9
rigSp="$rigW/.local/agents/spawned"
rigItem processed dispatch-rig-fd.md dispatch dispatch-succeeded none rig-fd ; touch -t 202001010000 "$rigD/board/processed/dispatch-rig-fd.md"
rigDone rig-fd 0 yes
rigFd4="$rigTmp/b9.fd4" ; : > "$rigFd4"
rigRun "$rigTmp/b9.g1" --intern-team-data-final-gc-deletion magic-coordinator
rigCheck "the GC removed the item and its folder"                         "$( rigLoc dispatch-rig-fd.md ) $( rigPresent "$rigSp/rig-fd" )" "not-found gone"
rigCheck "fd 4 holds its report line, naming the folder"                  "$( LC_ALL=C grep -c '^housekeeping: .*rig-fd' "$rigFd4" || : )" 1
rigCheck "stdout and stderr carry no housekeeping: line"                  "$( cat "$rigTmp/b9.g1" "$rigTmp/b9.g1.err" | LC_ALL=C grep -c 'housekeeping: ' || : )" 0
rigFd4=""
rigNew b9c
rigSp="$rigW/.local/agents/spawned"
rigItem processed dispatch-rig-fd.md dispatch dispatch-succeeded none rig-fd ; touch -t 202001010000 "$rigD/board/processed/dispatch-rig-fd.md"
rigDone rig-fd 0 yes
rigRun "$rigTmp/b9c.g1" --intern-team-data-final-gc-deletion magic-coordinator
rigCheck "control, fd 4 closed: the same GC removes the same folder"     "$( rigLoc dispatch-rig-fd.md ) $( rigPresent "$rigSp/rig-fd" )" "not-found gone"
rigCheck "control, fd 4 closed: stdout is the same as with fd 4 open"     "$( rigSame "$rigTmp/b9.g1" "$rigTmp/b9c.g1" )" same
rigCheck "control, fd 4 closed: apart from the daemon lines stderr is the same" "$( rigSameNoHk "$rigTmp/b9.g1.err" "$rigTmp/b9c.g1.err" )" same
rigCheck "control, fd 4 closed: the daemon lines are on stderr, the set fd 4 got" "$( rigHk "$rigTmp/b9c.g1.err" | cmp -s - <( rigHk "$rigTmp/b9.fd4" ) && printf same || printf different )" same

echo "   AgentsToolsDaemonLine itself"
rigDl="$( LC_ALL=C grep -l '^AgentsToolsDaemonLine()' "$MDLT_ORIGIN"/myx/myx.distro-agents/sh-lib/AgentsTools.*.include 2> /dev/null | head -1 )"
rigCheck "the function is defined in an include of this package"          "$( [ -n "$rigDl" ] && printf yes || printf no )" yes
if [ -n "$rigDl" ] ; then
	bash -c 'MDSC_CMD=rig ; . "$1" ; AgentsToolsDaemonLine "housekeeping: probe"' rig "$rigDl" 4>&- 2> "$rigTmp/dl.err.closed" > "$rigTmp/dl.out.closed"
	bash -c 'MDSC_CMD=rig ; . "$1" ; AgentsToolsDaemonLine "housekeeping: probe"' rig "$rigDl" 4> "$rigTmp/dl.fd4" 2> "$rigTmp/dl.err.open" > "$rigTmp/dl.out.open"
	rigCheck "control: with fd 4 open, the line is on fd 4"               "$( LC_ALL=C grep -c -x 'housekeeping: probe' "$rigTmp/dl.fd4" || : )" 1
	rigCheck "with fd 4 closed, the line is on stderr"                    "$( LC_ALL=C grep -c -x 'housekeeping: probe' "$rigTmp/dl.err.closed" || : )" 1
	rigCheck "with fd 4 closed, stderr holds that line and nothing else"  "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.err.closed" )" 1
	rigCheck "with fd 4 closed, stdout stays empty"                       "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.out.closed" )" 0
	rigCheck "with fd 4 open, stderr and stdout stay empty"               "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.err.open" "$rigTmp/dl.out.open" )" 0
fi

echo "   the wrapper keeps fd 4 on the caller's stderr"
rigMcp="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMcpRequest.include"
rigSites(){ ## file, fixed text that marks a launch site -- "sites in-order": 4>&2 must come before the line's first stderr redirection, 2>&<fd> or 2>>
	LC_ALL=C awk -v mark="$2" '
		index($0, mark) {
			sites++ ; a = index($0, "4>&2") ; b1 = index($0, "2>&") ; b2 = index($0, "2>>")
			b = b1 ; if ( b == 0 || ( b2 > 0 && b2 < b ) ) { b = b2 }
			if ( a > 0 && b > 0 && a < b ) { ordered++ }
		}
		END { printf "%d %d", sites, ordered }' "$1"
}
rigCheck "the 4 execute and background launch sites each have 4>&2 before their stderr redirection" "$( rigSites "$rigMcp" '--intern-mcp-execute' )" "4 4"
rigDir4="$rigTmp/fd4wrap" ; mkdir -p "$rigDir4"
bash -c '( sh -c "echo out ; echo err >&2 ; echo diag >&4" ) 4>&2 > "$1" 2>&1' rig "$rigDir4/f1" 2> "$rigDir4/outer1"
rigCheck "mini-rig, 4>&2 first: the result file holds out and err only"   "$( LC_ALL=C tr '\n' ' ' < "$rigDir4/f1" )" "out err "
rigCheck "mini-rig, 4>&2 first: the outer stderr holds diag"              "$( LC_ALL=C tr '\n' ' ' < "$rigDir4/outer1" )" "diag "
bash -c '( sh -c "echo out ; echo err >&2 ; echo diag >&4" ) > "$1" 2>&1 4>&2' rig "$rigDir4/f2" 2> "$rigDir4/outer2"
rigCheck "control, order reversed: diag lands in the result file, so the rig can fail" "$( LC_ALL=C grep -c -x diag "$rigDir4/f2" || : )" 1
rigCheck "control, order reversed: the outer stderr is empty"             "$( LC_ALL=C awk 'END { print NR }' "$rigDir4/outer2" )" 0

echo "   a spawned child never inherits fd 4"
rigSpawnInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpAgentSpawnProxy.include"
rigCheck "the 4 console launch sites that redirect their own output each close fd 4 with 4>&-" "$( LC_ALL=C awk '
	index($0, "DistroAgentsConsole.sh\" \"${spawnCliArgs[@]}\" --non-interactive") && index($0, "\"$spawnContext\" >") > 0 { sites++ ; if ( index($0, "4>&-") > 0 ) { closed++ } }
	END { printf "%d %d", sites, closed }' "$rigSpawnInc" )" "4 4"
rigCheck "the fifth, the detached subshell's console, sits in a subshell whose closing line closes fd 4" "$( LC_ALL=C grep -c -F ') > "$outputFile" 2>&1 4>&- &' "$rigSpawnInc" || : )" 1
rigNew b10 ; rigSp="$rigW/.local/agents/spawned"
mkdir -p "$rigW/.local/.agents" "$rigTmp/b10/skills/rig-member" "$rigTmp/b10/home" "$rigW/source/rigrepo/rigpkg"
printf 'SPAWN_CLI_SERVICE=rig-cli\n' > "$rigW/.local/.agents/magic-team.agent.env"
printf '# rigpkg\n' > "$rigW/source/rigrepo/rigpkg/MAGIC.md" ; : > "$rigW/source/rigrepo/rigpkg/file.sh" ; printf '# workspace\n' > "$rigW/MAGIC.md"
printf '# rig armed\n' > "$rigTmp/b10/skills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/b10/skills/rig-member/rig-member.basic.md"
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nif [ -e /dev/fd/4 ] ; then echo open > "%s/b10/fd4.seen" ; else echo closed > "%s/b10/fd4.seen" ; fi\necho deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"\n' "$rigTmp" "$rigTmp" > "$rigW/DistroAgentsConsole.sh"
chmod +x "$rigW/DistroAgentsConsole.sh"
printf 'Work on rigrepo/rigpkg/file.sh following rig-member.armed.md.\n' \
	| env -i HOME="$rigTmp/b10/home" PATH="/usr/bin:/bin" MMDAPP="$rigW" MDAT_DATA_ROOT="$rigD" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/b10/skills" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_FD4="$rigTmp/b10/fd4.parent" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			exec 4> "$RIG_FD4"
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait
		' > "$rigTmp/b10/spawn.out" 2> "$rigTmp/b10/spawn.err"
[ -f "$rigTmp/b10/fd4.seen" ] || rigRefuse "the fake console never ran, so fd 4 was never observed: $( tail -3 "$rigTmp/b10/spawn.err" )"
printf '#!/bin/sh\nif [ -e /dev/fd/4 ] ; then echo open ; else echo closed ; fi\n' > "$rigTmp/b10/probe.sh" ; chmod +x "$rigTmp/b10/probe.sh"
rigCheck "control: a child started with fd 4 open does list it"          "$( bash -c 'exec 4> "$1" ; "$2"' rig "$rigTmp/b10/fd4.ctl" "$rigTmp/b10/probe.sh" )" open
rigCheck "a console launched by the spawn proxy, with fd 4 open in its caller, does not"  "$( cat "$rigTmp/b10/fd4.seen" )" closed
rm -f "$rigTmp/b10/fd4.seen"
printf 'Work on rigrepo/rigpkg/file.sh following rig-member.armed.md.\n' \
	| env -i HOME="$rigTmp/b10/home" PATH="/usr/bin:/bin" MMDAPP="$rigW" MDAT_DATA_ROOT="$rigD" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/b10/skills" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_FD4="$rigTmp/b10/fd4.parent" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			exec 4> "$RIG_FD4"
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create
		' > "$rigTmp/b10/spawn2.out" 2> "$rigTmp/b10/spawn2.err"
## Not waited for by the proxy, so this waits for the detached spawn's own close: the record leaving spawn-started.
rigWaitLoop=0
while [ "$rigWaitLoop" -lt 120 ] && { [ ! -f "$rigTmp/b10/fd4.seen" ] || LC_ALL=C grep -q -l 'status: spawn-started' "$rigSp"/*/*.md 2> /dev/null ; } ; do
	sleep 0.5 ; rigWaitLoop=$(( rigWaitLoop + 1 ))
done
[ -f "$rigTmp/b10/fd4.seen" ] || rigRefuse "the detached fake console never ran: $( tail -3 "$rigTmp/b10/spawn2.err" )"
rigCheck "a console launched by the detached branch does not list fd 4 either"  "$( cat "$rigTmp/b10/fd4.seen" )" closed

echo "   a Slack that is not set up never fails the scan"
rigPostSetup b11 yes
rigExtraEnv+=( RIG_MODE=fail )
rigScan "$rigTmp/b11.s1"
rigCheck "the post is refused by the fake Slack and the scan still succeeds, closing the dispatch" "$( rigLoc dispatch-rig-d1.md )" review
rigCheck "the daemon lines are still on stderr"                           "$( rigHk "$rigTmp/b11.s1.err" | LC_ALL=C awk 'END { print NR }' )" 3
rigCheck "and no error line besides the known context noise"              "$( rigNoHk "$rigTmp/b11.s1.err" | cmp -s - <( rigNoHk "$rigTmp/b1e.s1.err" ) && printf same || printf different )" same
rigExtraEnv=()

echo "-- execute: merge_stderr puts a script's stderr in the result, or leaves it on the daemon side --"
rigMcpOpen(){ ## name -- a real stdio server of its own, its stdin a fifo kept open on fd 7
	rigMd="$rigTmp/mcp.$1" ; mkdir -p "$rigMd/ws/.local/temp" ; mkfifo "$rigMd/in"
	( cd "$rigMd/ws" && env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MMDAPP="$rigMd/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-mcp-server --run 2> "$rigMd/server.err" ) < "$rigMd/in" > "$rigMd/replies" &
	rigMcpPid=$!
	exec 7> "$rigMd/in"
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"rig","version":"1"}}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' >&7
	rigMcpAwait 1
}
rigMcpAwait(){ ## id -- waits, bounded, for that reply
	local awaitLoop=0
	while [ "$awaitLoop" -lt 200 ] && ! LC_ALL=C grep -q "\"id\":$1," "$rigMd/replies" 2> /dev/null ; do sleep 0.2 ; awaitLoop=$(( awaitLoop + 1 )) ; done
	LC_ALL=C grep -q "\"id\":$1," "$rigMd/replies" || rigRefuse "the server gave no reply to request $1: $( tail -2 "$rigMd/server.err" )"
}
rigMcpCall(){ ## id, tool, arguments object -- sends one tools/call and waits for its reply
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3" >&7
	rigMcpAwait "$1"
}
rigMcpText(){ ## id -- the text of that reply, newlines still written as \n
	LC_ALL=C grep "\"id\":$1," "$rigMd/replies" | LC_ALL=C sed -n 's/.*"text":"\(.*\)"}\],"isError".*/\1/p' | head -1
}
rigMcpClose(){
	exec 7>&-
	local closeLoop=0
	while [ "$closeLoop" -lt 50 ] && kill -0 "$rigMcpPid" 2> /dev/null ; do sleep 0.2 ; closeLoop=$(( closeLoop + 1 )) ; done
	kill "$rigMcpPid" 2> /dev/null ; wait "$rigMcpPid" 2> /dev/null || :
}
rigMcpOpen m1
printf '{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n' >&7 ; rigMcpAwait 2
rigCheck "the execute tool's schema declares merge_stderr as a boolean"   "$( LC_ALL=C grep '"id":2,' "$rigMd/replies" | LC_ALL=C grep -c '"merge_stderr":{"type":"boolean"' || : )" 1
rigMcpCall 3 execute '{"command":"echo rigout ; echo errdefault >&2"}'
rigCheck "default (no argument): stderr is in the result"                 "$( rigMcpText 3 )" 'rigout\nerrdefault'
rigMcpCall 4 execute '{"command":"echo rigout ; echo errtrue >&2","merge_stderr":true}'
rigCheck "merge_stderr true: stderr is in the result"                     "$( rigMcpText 4 )" 'rigout\nerrtrue'
rigMcpCall 5 execute '{"command":"echo rigout ; echo errfalse >&2","merge_stderr":false}'
rigCheck "merge_stderr false: only stdout is in the result"               "$( rigMcpText 5 )" 'rigout'
rigCheck "control: with false the stderr is not lost, it is on the server's own stderr" "$( LC_ALL=C grep -c -x 'errfalse' "$rigMd/server.err" || : )" 1
rigCheck "control: with true it was not on the server's own stderr"       "$( LC_ALL=C grep -c -x 'errtrue' "$rigMd/server.err" || : )" 0
rigMcpCall 6 execute '{"command":"echo rigout ; echo errstr >&2","merge_stderr":"no"}'
rigCheck "only the literal false changes anything: any other value merges" "$( rigMcpText 6 )" 'rigout\nerrstr'
rigMcpCall 7 execute '{"command":"{ echo rigout ; echo errown >&2 ; } 2>&1","merge_stderr":true}'
rigMcpCall 8 execute '{"command":"{ echo rigout ; echo errown >&2 ; } 2>&1","merge_stderr":false}'
rigCheck "a script with its own 2>&1: the result with true"                "$( rigMcpText 7 )" 'rigout\nerrown'
rigCheck "a script with its own 2>&1: the result with false is the same"   "$( rigMcpText 8 )" "$( rigMcpText 7 )"
rigCheck "and nothing of it reached the server's own stderr"              "$( LC_ALL=C grep -c -x 'errown' "$rigMd/server.err" || : )" 0
echo "   background execute"
rigMcpBg(){ ## first id, merge value, marker -- starts a background job, polls it to its end, prints everything it returned
	local bgId="$1" bgJob bgLoop=0 bgAll="" bgPoll
	rigMcpCall "$bgId" execute "{\"command\":\"echo rigout ; echo $3 >&2\",\"background\":true,\"merge_stderr\":$2}"
	bgJob="$( rigMcpText "$bgId" | LC_ALL=C sed -n 's/^\[job \([0-9]*\) started.*/\1/p' )"
	[ -n "$bgJob" ] || rigRefuse "no job id in the background start reply: $( rigMcpText "$bgId" )"
	while [ "$bgLoop" -lt 40 ] ; do
		bgPoll=$(( bgId * 100 + bgLoop ))
		rigMcpCall "$bgPoll" execute "{\"job\":$bgJob}"
		bgAll="$bgAll$( rigMcpText "$bgPoll" )"
		case "$bgAll" in *"finished, exit code"*) break ;; esac
		sleep 0.3 ; bgLoop=$(( bgLoop + 1 ))
	done
	printf '%s' "$bgAll"
}
rigBgFalse="$( rigMcpBg 20 false errbgfalse )"
rigCheck "background with false: the job's output has the stdout"          "$( printf '%s' "$rigBgFalse" | LC_ALL=C grep -c -F rigout || : )" 1
rigCheck "background with false: the job's output has no stderr"           "$( printf '%s' "$rigBgFalse" | LC_ALL=C grep -c -F errbgfalse || : )" 0
rigCheck "background with false: the job finished"                         "$( printf '%s' "$rigBgFalse" | LC_ALL=C grep -c -F 'finished, exit code' || : )" 1
rigCheck "background with false: the stderr is on the server's own stderr" "$( LC_ALL=C grep -c -x 'errbgfalse' "$rigMd/server.err" || : )" 1
rigBgTrue="$( rigMcpBg 21 true errbgtrue )"
rigCheck "control, background with true: the job's output has the stderr"  "$( printf '%s' "$rigBgTrue" | LC_ALL=C grep -c -F errbgtrue || : )" 1
echo "   Monitor is unchanged"
rigMcpCall 30 Monitor '{"command":"echo rigout ; echo errmon >&2 ; sleep 1","description":"rig monitor","timeout_ms":20000,"merge_stderr":false}'
rigMonErr="$( rigMcpText 30 | LC_ALL=C sed -n 's/.*\[stderr file: \([^]]*\)\].*/\1/p' )"
rigMonOut="$( rigMcpText 30 | LC_ALL=C sed -n 's/.*\[log file: \([^]]*\)\].*/\1/p' )"
[ -n "$rigMonErr" ] && [ -n "$rigMonOut" ] || rigRefuse "the Monitor start reply names no stderr or log file: $( rigMcpText 30 )"
rigMonLoop=0
while [ "$rigMonLoop" -lt 50 ] && ! LC_ALL=C grep -q -x errmon "$rigMonErr" 2> /dev/null ; do sleep 0.2 ; rigMonLoop=$(( rigMonLoop + 1 )) ; done
rigCheck "Monitor, whatever merge_stderr says: its stderr is kept in its own stderr file" "$( LC_ALL=C grep -c -x errmon "$rigMonErr" || : )" 1
rigCheck "Monitor: its log file has the stdout"                           "$( LC_ALL=C grep -c -x rigout "$rigMonOut" || : )" 1
rigCheck "Monitor: its log file has no stderr"                            "$( LC_ALL=C grep -c errmon "$rigMonOut" || : )" 0
rigCheck "Monitor: nothing of it on the server's own stderr"              "$( LC_ALL=C grep -c -x errmon "$rigMd/server.err" || : )" 0
rigMcpClose

echo "-- stage 2: the daemon line, exit codes in both merge modes, and the withdrawn filter's names --"
echo "   bash: $( bash --version | head -1 ) (the rig runs every script below under this bash)"
## A copy of this package's own tree with one throwaway op in its dispatcher, so the daemon line is measured
## through the real entry point. Nothing outside this rig's own tree is touched.
rigO2="$rigTmp/s2origin"
mkdir -p "$rigO2/myx"
for rigEntry in "$MDLT_ORIGIN"/* ; do [ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigO2/${rigEntry##*/}" ; done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do [ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigO2/myx/${rigEntry##*/}" ; done
mkdir "$rigO2/myx/myx.distro-agents"
( cd "$MDLT_ORIGIN/myx/myx.distro-agents" && tar cf - --exclude=.git . ) | ( cd "$rigO2/myx/myx.distro-agents" && tar xf - )
rigTool2="$rigO2/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigArms="$rigTmp/s2arms.txt"
cat > "$rigArms" <<'RIGARMS'
		--rig-daemon) . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" ; AgentsToolsDaemonLine "housekeeping: rig-daemon" ; echo "daemon-op-stdout" ; return 0 ;;
RIGARMS
rigDisp="$rigTool2"
LC_ALL=C awk -v armsFile="$rigArms" '{ print } !done && $0 == "\tcase \"$1\" in" { while ( ( getline armLine < armsFile ) > 0 ) { print armLine } ; done = 1 }' "$rigDisp" > "$rigDisp.new" && mv "$rigDisp.new" "$rigDisp" && chmod +x "$rigDisp"
rigCheck "control: the throwaway op is in the rig copy's dispatcher"      "$( LC_ALL=C grep -c -e '--rig-daemon)' "$rigDisp" || : )" 1
rigNew s2
rigS2(){ ## result prefix, fd4 (open|closed), arguments... -- one call; <prefix>.out .err .fd4 .rc
	local s2p="$1" s2fd4="$2" ; shift 2
	: > "$s2p.fd4"
	if [ "$s2fd4" = open ] ; then
		( cd "$rigW" && env -u MDAT_SKILLSET_ROOT HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigO2" MDAT_DATA_ROOT="$rigD" bash "$rigTool2" "$@" ) > "$s2p.out" 2> "$s2p.err" 4>> "$s2p.fd4"
	else
		( cd "$rigW" && env -u MDAT_SKILLSET_ROOT HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigO2" MDAT_DATA_ROOT="$rigD" bash "$rigTool2" "$@" ) > "$s2p.out" 2> "$s2p.err" 4>&-
	fi
	printf '%s' "$?" > "$s2p.rc"
}
rigN(){ ## file, fixed text -- how many lines of the file contain it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
echo "   the daemon line"
rigS2 "$rigTmp/s2j" open --rig-daemon
rigCheck "fd 4 open: the line is on fd 4"                                 "$( LC_ALL=C grep -c -x 'housekeeping: rig-daemon' "$rigTmp/s2j.fd4" || : )" 1
rigCheck "fd 4 open: it is not on stdout"                                 "$( rigN "$rigTmp/s2j.out" 'housekeeping: rig-daemon' )" 0
rigCheck "fd 4 open: it is not on stderr"                                 "$( rigN "$rigTmp/s2j.err" 'housekeeping: rig-daemon' )" 0
rigCheck "control: the op's own stdout is there"                          "$( LC_ALL=C grep -c -x 'daemon-op-stdout' "$rigTmp/s2j.out" || : )" 1
rigS2 "$rigTmp/s2l" closed --rig-daemon
rigCheck "fd 4 closed: the line is on stderr"                             "$( LC_ALL=C grep -c -x 'housekeeping: rig-daemon' "$rigTmp/s2l.err" || : )" 1
rigCheck "fd 4 closed: and never on stdout"                               "$( rigN "$rigTmp/s2l.out" 'housekeeping: rig-daemon' )" 0
rigCheck "fd 4 closed: stdout is the op's own line and nothing else"      "$( LC_ALL=C grep -c . "$rigTmp/s2l.out" || : )" 1
echo "   the daemon line function alone, under /bin/sh, bash 3.2, bash --posix and dash (fd 4 closed, a file, read-only)"
rigDlFn="$rigTmp/daemonline.fn.sh"
LC_ALL=C awk '/^AgentsToolsDaemonLine\(\)/ { on = 1 } on { print } on && /^}/ { exit }' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" > "$rigDlFn"
rigCheck "control: the function text was cut out of the include"          "$( LC_ALL=C grep -c '^AgentsToolsDaemonLine()' "$rigDlFn" || : )" 1
printf 'unchanged\n' > "$rigTmp/dl.ro"
rigDlRun(){ ## label, fd 4 mode (closed|file|ro), shell and its options... -- <label>.out .err .status; the shell's own status line says it lived on
	local dlLabel="$1" dlMode="$2" ; shift 2
	: > "$rigTmp/dl.$dlLabel.rw"
	case "$dlMode" in
		closed) "$@" -c '. "$1" ; AgentsToolsDaemonLine "housekeeping: probe" ; echo "status=$? alive" > "$2"' x "$rigDlFn" "$rigTmp/dl.$dlLabel.status" 4>&- > "$rigTmp/dl.$dlLabel.out" 2> "$rigTmp/dl.$dlLabel.err" ;;
		file)   "$@" -c '. "$1" ; AgentsToolsDaemonLine "housekeeping: probe" ; echo "status=$? alive" > "$2"' x "$rigDlFn" "$rigTmp/dl.$dlLabel.status" 4>> "$rigTmp/dl.$dlLabel.rw" > "$rigTmp/dl.$dlLabel.out" 2> "$rigTmp/dl.$dlLabel.err" ;;
		ro)     "$@" -c '. "$1" ; AgentsToolsDaemonLine "housekeeping: probe" ; echo "status=$? alive" > "$2"' x "$rigDlFn" "$rigTmp/dl.$dlLabel.status" 4< "$rigTmp/dl.ro" > "$rigTmp/dl.$dlLabel.out" 2> "$rigTmp/dl.$dlLabel.err" ;;
	esac
}
for rigDlSpec in "sh:/bin/sh" "bash:/bin/bash" "bash-posix:/bin/bash --posix" "dash:/bin/dash" ; do
	rigDlName="${rigDlSpec%%:*}" ; rigDlCmd="${rigDlSpec#*:}"
	[ -x "${rigDlCmd%% *}" ] || { rigCheck "${rigDlCmd%% *} exists on this machine" no yes ; continue ; }
	rigDlRun "$rigDlName.c" closed $rigDlCmd
	rigCheck "[$rigDlName] fd 4 closed: the line is on stderr once"        "$( LC_ALL=C grep -c -x 'housekeeping: probe' "$rigTmp/dl.$rigDlName.c.err" || : )" 1
	rigCheck "[$rigDlName] fd 4 closed: nothing on stdout"                 "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.$rigDlName.c.out" )" 0
	rigCheck "[$rigDlName] fd 4 closed: status 0 and the shell is alive"   "$( cat "$rigTmp/dl.$rigDlName.c.status" 2> /dev/null )" "status=0 alive"
	rigDlRun "$rigDlName.f" file $rigDlCmd
	rigCheck "[$rigDlName] fd 4 open to a file: the line is in the file once" "$( LC_ALL=C grep -c -x 'housekeeping: probe' "$rigTmp/dl.$rigDlName.f.rw" || : )" 1
	rigCheck "[$rigDlName] fd 4 open to a file: nothing on stdout or stderr" "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.$rigDlName.f.out" "$rigTmp/dl.$rigDlName.f.err" )" 0
	rigCheck "[$rigDlName] fd 4 open to a file: status 0 and alive"        "$( cat "$rigTmp/dl.$rigDlName.f.status" 2> /dev/null )" "status=0 alive"
	rigDlRun "$rigDlName.r" ro $rigDlCmd
	rigCheck "[$rigDlName] fd 4 read-only: the line is on stderr once"     "$( LC_ALL=C grep -c -x 'housekeeping: probe' "$rigTmp/dl.$rigDlName.r.err" || : )" 1
	rigCheck "[$rigDlName] fd 4 read-only: nothing on stdout"              "$( LC_ALL=C awk 'END { print NR }' "$rigTmp/dl.$rigDlName.r.out" )" 0
	rigCheck "[$rigDlName] fd 4 read-only: status 0 and alive"             "$( cat "$rigTmp/dl.$rigDlName.r.status" 2> /dev/null )" "status=0 alive"
done
rigCheck "and the read-only file was left as it was"                       "$( cat "$rigTmp/dl.ro" )" unchanged
echo "   exit status is the same whether stderr is merged or not"
rigNew s2rc
rigMcpOpen m3
rigCall=40
for rigMerge in true false ; do
	rigCall=$(( rigCall + 1 ))
	rigMcpCall "$rigCall" execute "{\"command\":\"DistroAgentsTools --magic-advance-input-scan magic-coordinator --bad 2> /dev/null ; echo rc=\$?\",\"merge_stderr\":$rigMerge}"
	rigCheck "a failing op, merge_stderr $rigMerge: it exits 1"           "$( rigMcpText "$rigCall" | LC_ALL=C grep -c 'rc=1$' || : )" 1
	rigCall=$(( rigCall + 1 ))
	rigMcpCall "$rigCall" execute "{\"command\":\"MDAT_DATA_ROOT=$rigD DistroAgentsTools --intern-team-data-final-gc-deletion magic-coordinator 2> /dev/null ; echo rc=\$?\",\"merge_stderr\":$rigMerge}"
	rigCheck "an op with nothing to do, merge_stderr $rigMerge: it exits 2" "$( rigMcpText "$rigCall" | LC_ALL=C grep -c 'rc=2$' || : )" 1
	rigCall=$(( rigCall + 1 ))
	rigItem processed "dispatch-rig-rc-$rigCall.md" dispatch dispatch-succeeded none none ; touch -t 202001010000 "$rigD/board/processed/dispatch-rig-rc-$rigCall.md"
	rigMcpCall "$rigCall" execute "{\"command\":\"MDAT_DATA_ROOT=$rigD DistroAgentsTools --intern-team-data-final-gc-deletion magic-coordinator 2> /dev/null ; echo rc=\$?\",\"merge_stderr\":$rigMerge}"
	rigCheck "an op that deletes something, merge_stderr $rigMerge: it exits 0"        "$( rigMcpText "$rigCall" | LC_ALL=C grep -c 'rc=0$' || : )" 1
done
rigMcpClose
echo "   the withdrawn filter's names are gone from the package"
rigNameA="MDAT_TOOLS_""NESTED" ; rigNameB="MDAT_MCP_STDERR_""MERGE"
rigNameScan(){ ## directory -- how many files under it carry either name, this check's own file excluded
	LC_ALL=C grep -r -l --exclude-dir=.git --exclude='AgentsAdvanceInputScanStatesCheck.test.sh' -e "$rigNameA" -e "$rigNameB" "$1" 2> /dev/null | LC_ALL=C awk 'END { print NR }'
}
mkdir -p "$rigTmp/namectl" ; printf 'x %s y\n' "$rigNameA" > "$rigTmp/namectl/probe.txt"
rigCheck "control: the same scan finds a name in a temp file that carries it" "$( rigNameScan "$rigTmp/namectl" )" 1
rigCheck "neither name appears anywhere in the package's code"            "$( rigNameScan "$MDLT_ORIGIN/myx/myx.distro-agents" )" 0

echo "-- processed-item GC: a deleted item takes its sandbox folder, nothing else goes, twice --"
rigNew b4
rigGc(){ ## run number
	rigRun "$rigTmp/b4.g$1" --intern-team-data-final-gc-deletion magic-coordinator
}
rigProcessed(){ ## session id, spawn-id or none -- an aged processed dispatch item
	rigItem processed "dispatch-$1.md" dispatch dispatch-succeeded none none
	[ "$2" = none ] || printf 'spawn-id: %s\n' "$2" >> "$rigD/board/processed/dispatch-$1.md"
	touch -t 202001010000 "$rigD/board/processed/dispatch-$1.md"
}
rigPresent(){ ## path -- present or gone
	[ -e "$1" ] || [ -L "$1" ] && printf present || printf gone
}
rigSp="$rigW/.local/agents/spawned"
rigSandbox rig-orphan "$rigHost" spawn-succeeded "exit-code: 0"
rigItem processed dispatch-rig-young.md dispatch dispatch-succeeded none rig-young ; rigDone rig-young 0 yes
mkdir -p "$rigD/inboxes/rig-member/processed"
printf -- '---\ntype: note\nowner: rig-member\nspawn-id: rig-inbox\n---\n\nrig inbox item\n' > "$rigD/inboxes/rig-member/processed/note-rig-inbox.md"
touch -t 202001010000 "$rigD/inboxes/rig-member/processed/note-rig-inbox.md" ; rigDone rig-inbox 0 yes
mkdir -p "$rigD/trash"
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rig-trash\n---\n\nrig trash item\n' > "$rigD/trash/dispatch-rig-trash.md"
touch -t 202001010000 "$rigD/trash/dispatch-rig-trash.md" ; rigDone rig-trash 0 yes
echo "   closed folder, nothing else links to it"
rigProcessed rig-g1 rig-g1 ; rigDone rig-g1 0 yes ; printf 'deliverable\n' > "$rigSp/rig-g1/output/result.txt"
rigGc 1
rigCheck "exit 0, a deletion happened"                                    "$( cat "$rigTmp/b4.g1.rc" )" 0
rigCheck "the item is deleted"                                            "$( rigLoc dispatch-rig-g1.md )" not-found
rigCheck "its sandbox folder is deleted with it"                          "$( rigPresent "$rigSp/rig-g1" )" gone
rigCheck "the summary names one removed folder"                           "$( LC_ALL=C grep -c -F ' 1 sandbox-folders removed.' "$rigTmp/b4.g1" || : )" 1
rigCheck "control: the orphan folder, no item, is left alone"             "$( rigPresent "$rigSp/rig-orphan/rig-orphan.md" )" present
rigCheck "control: the young item and its folder are both kept"           "$( rigLoc dispatch-rig-young.md ) $( rigPresent "$rigSp/rig-young/rig-young.md" )" "processed present"
rigCheck "control: an inbox item is deleted and touches no sandbox"       "$( [ -f "$rigD/inboxes/rig-member/processed/note-rig-inbox.md" ] && printf kept || printf deleted ) $( rigPresent "$rigSp/rig-inbox/rig-inbox.md" )" "deleted present"
rigCheck "control: a trash item is deleted and touches no sandbox"        "$( [ -f "$rigD/trash/dispatch-rig-trash.md" ] && printf kept || printf deleted ) $( rigPresent "$rigSp/rig-trash/rig-trash.md" )" "deleted present"
echo "   another board item still links to the folder"
rigProcessed rig-g2 rig-g2 ; rigDone rig-g2 0 yes
rigItem running dispatch-rig-g2-other.md dispatch dispatch-started none rig-g2
rigGc 2
rigCheck "exit 0, a deletion happened"                                    "$( cat "$rigTmp/b4.g2.rc" )" 0
rigCheck "the item is deleted"                                            "$( rigLoc dispatch-rig-g2.md )" not-found
rigCheck "the folder is kept"                                             "$( rigPresent "$rigSp/rig-g2/rig-g2.md" )" present
rigCheck "no sandbox sentence"                                            "$( LC_ALL=C grep -c -F 'sandbox-folders' "$rigTmp/b4.g2" || : )" 0
echo "   folder holds a spawn-started record"
rigProcessed rig-g3 rig-g3 ; rigSandbox rig-g3 "$rigHost" spawn-started
rigGc 3
rigCheck "exit 2, nothing was deleted"                                    "$( cat "$rigTmp/b4.g3.rc" )" 2
rigCheck "the item is kept this pass, still in processed"                 "$( rigLoc dispatch-rig-g3.md )" processed
rigCheck "the folder is kept"                                             "$( rigPresent "$rigSp/rig-g3/rig-g3.md" )" present
rigCheck "no sandbox sentence"                                            "$( LC_ALL=C grep -c -F 'sandbox-folders' "$rigTmp/b4.g3" || : )" 0
echo "   no folder at all"
rigProcessed rig-g4 rig-g4 ; rigProcessed rig-g4b none
rigGc 4
rigCheck "control: the item with a spawn-id and no folder is deleted"     "$( rigLoc dispatch-rig-g4.md )" not-found
rigCheck "control: the item with no spawn-id is deleted"                  "$( rigLoc dispatch-rig-g4b.md )" not-found
rigCheck "control: no sandbox sentence"                                   "$( LC_ALL=C grep -c -F 'sandbox-folders' "$rigTmp/b4.g4" || : )" 0
rigCheck "control: the held folder of the kept item is still there"       "$( rigPresent "$rigSp/rig-g3/rig-g3.md" )" present
echo "   a symlinked folder and a name with a slash are refused"
mkdir -p "$rigTmp/b4/elsewhere" "$rigW/.local/agents/victim"
printf -- '---\nspawn-id: rig-sym\nstatus: spawn-succeeded\n---\n' > "$rigTmp/b4/elsewhere/rig-sym.md"
ln -s "$rigTmp/b4/elsewhere" "$rigSp/rig-sym"
printf 'keep\n' > "$rigW/.local/agents/victim/keep.txt"
rigProcessed rig-sym rig-sym ; rigProcessed rig-esc '../victim'
rigGc 5 ; rigSnap b4 > "$rigTmp/b4.snap5"
rigCheck "the symlink target is kept"                                     "$( rigPresent "$rigTmp/b4/elsewhere/rig-sym.md" )" present
rigCheck "the symlink is kept"                                            "$( [ -L "$rigSp/rig-sym" ] && printf present || printf gone )" present
rigCheck "a folder outside the sandbox root, named by a slash, is kept"   "$( rigPresent "$rigW/.local/agents/victim/keep.txt" )" present
echo "   second pass"
rigGc 6 ; rigSnap b4 > "$rigTmp/b4.snap6"
rigGc 7 ; rigSnap b4 > "$rigTmp/b4.snap7"
rigCheck "exit 2 when nothing is left to delete"                          "$( cat "$rigTmp/b4.g7.rc" )" 2
rigCheck "a second pass changes nothing"                                  "$( rigSame "$rigTmp/b4.snap6" "$rigTmp/b4.snap7" )" same
rigCheck "and the first of them changed nothing either"                   "$( rigSame "$rigTmp/b4.snap5" "$rigTmp/b4.snap6" )" same

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ ADVANCE INPUT SCAN STATES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) row(s)" >&2 ; exit 1
fi
printf 'ADVANCE_INPUT_SCAN_STATES: OK (%d rows, offline)\n' "$rigPasses"
