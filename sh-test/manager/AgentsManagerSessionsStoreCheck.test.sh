#!/usr/bin/env bash
## Behavioural check on what two manager reads OPEN: the active sessions a list carries, and the board it does not.
## Every file of a rig is marked with an old access time and a later content time, and a read's own mark is an access time
## that moved while its content time stood. A file the read rewrote has both moved, and so is told from one it only read.
## Wall time is never measured.
## Held:
##   0. the screen's own declarations, and the census itself: it counts a file the check reads, and the same comparison
##      reports a difference when it is pointed at a read that does scale
##   1. Active Sessions: three live sessions, once with no closed history and once with 1600 closed ones, open the same
##      number of files, and no file of a closed session is among them
##   2. that read opens no item of a board state, at 3 board items and at 1600
##   3. Epics: the read opens the vault's epic documents and no other file, with 3 board items and with 1600
##   4. the writers: a session spawned and then closed leaves its runs block, its live block and its closed line, each
##      valid by the token its own source carries now
## Red before the build, at 2026-11-23 21:07 UTC on the tree as it then stood, with `--manager-session-list` as the active
## read: 10 files opened at 3 closed sessions against 3210 at 1600, among them 3200 of closed sessions, and 3 board items
## opened at 3 board items against 1600 at 1600.
## Red still at 2026-11-23 22:32 UTC, with the three stores, the board's kept index and the fixed runs-block writer in the
## tree: 9 files at 3 closed sessions against 3209 at 1600, among them 3200 of closed sessions. The screen's own Active
## Sessions declaration still names `--manager-session-list`, the whole-store read. The board half is measured done, at 0
## board items opened with 3 items and with 1600, and so are the Epics and the writers. The check goes green when that
## declaration names an operation that opens the live blocks alone.
## THE SCALE FIXTURES SEED THEIR CLOSED HISTORY AS FILES, and the writer case is what holds the writers to their stores. A
## fixture of 1600 sessions written by a writer call would be 1600 shell calls in a check of a read. The live sessions take
## the store's own writers in every fixture, so a broken writer reddens the scale case too.
## Offline: a rig workspace of this check's own, with its own team data, and the real dispatcher of the origin.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
## THE OPERATION THE SCREEN ITSELF DECLARES for each of the two lists, read from the screen's own source, so this check
## follows the screen rather than a name it chose. A screen that moves to another operation is measured by the one it names.
rigDeclaredOp(){ ## the screen file, the read key -- the operation the declaration names, or nothing
	LC_ALL=C grep -F "\"$2\":" "$rigPkg/sh-lib/manager/$1" 2> /dev/null | LC_ALL=C awk -F'"' '{ print $6 ; exit ; }'
}
rigOpActive="$( rigDeclaredOp AgentsManagerScreen.Sessions.py list:activity )"
rigOpEpic="$( rigDeclaredOp AgentsManagerScreen.Epics.py list:epics )"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin: $rigTool"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionsStoreCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigPid=920000

## THE MARK A READ LEAVES. An open whose content is read moves the file's access time. A file only opened, with nothing read
## of it, moves nothing, so a rewritten file is told from a read one by its content time alone.
rigAtimeMark="200001010000"
rigMtimeMark="201001010000"
rigACut="2001-01-01T00:00:00"
rigMCut="2011-01-01T00:00:00"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigVerdict(){ ## one count, another count -- `same` or `differs`
	if [ "$1" = "$2" ] ; then printf 'same' ; else printf 'differs' ; fi
}
rigYesNo(){ ## status of a test -- yes or no
	if [ "$1" = 0 ] ; then printf yes ; else printf no ; fi
}

## THE RIG'S OWN PROCESS LIST, so a session is alive by what the tooling reads, and no process of this host is seen.
rigRealPs="$( command -v ps 2> /dev/null )" || rigRefuse "no ps on PATH to hand the other calls to"
cat > "$rigTmp/ps" <<RIGPS
#!/bin/sh
case " \$* " in
	*" -A "*)
		case "\$*" in
			*pid=*) cat "\${0%/*}/ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "\${0%/*}/ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$rigRealPs" "\$@"
RIGPS
chmod +x "$rigTmp/ps" || rigRefuse "the rig's ps could not be made executable"

## THE STORE'S OWN WRITERS, in a clean environment of their own, against the rig's workspace: one shell call, so a block is
## never built by hand where a writer exists.
rigStoreFns='. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.Write.include" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStores.include" || exit 1'
rigStoreWrite(){ ## workspace, a call of the store's functions
	local storeWs="$1" storeText="$2" storeRc=0
	( cd "$storeWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp:$PATH" MMDAPP="$storeWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c "$rigStoreFns
$storeText" rig ) > "$rigTmp/store.out" 2> "$rigTmp/store.err" || storeRc=$?
	[ "$storeRc" -eq 0 ] || { printf '⛔ the store writer failed: %s\n%s\n' "$storeText" "$( LC_ALL=C grep -v '^#' "$rigTmp/store.err" 2> /dev/null )" >&2 ; return 1 ; }
	return 0
}

## One live session of a fixture, made by the store's OWN WRITERS: its state with a `seq:` token, its spawn record, and
## its live block, then its process in the rig's list so the tooling reads it as alive. A block built by hand would be a
## second renderer of the block, and would pass here after the writer broke.
rigLiveSession(){ ## root, sandbox name, session id, started-at
	local seRoot="$1" seBox="$2" seId="$3" seAt="$4" seWs="$1/ws"
	mkdir -p "$seWs/.local/agents/spawned/$seBox" "$seWs/.local/agents/sessions/$seId/control" \
		|| rigRefuse "a session of the fixture could not be made: $seId"
	printf 'state: running\nstate-at: %s\nreason: the rig says so\nseq: 1\n' "$seAt" \
		> "$seWs/.local/agents/sessions/$seId/control/state"
	printf 'state: running\nstate-at: %s\nreason: the rig says so\nseq: 1\n' "$seAt" \
		> "$rigTmp/record.$$"
	rigStoreWrite "$seWs" "{
		printf -- '---\nsession-id: $seId\nspawn-id: $seBox\nhost: $rigHost\nworkspace: ws-rig\nowner: magic-coordinator\nstatus: spawn-started\nstarted-at: $seAt\n'
		printf -- '---\n\n# Spawn session: $seId\n'
	} | AgentsSpawnRecordWrite $seBox $seBox" || rigRefuse "the spawn record of $seId could not be written"
	rigStoreWrite "$seWs" "AgentsToolsSessionLiveBlockWrite $seId 1" || rigRefuse "the live block of $seId could not be written"
	rigPid=$(( rigPid + 1 ))
	printf '%s started\n' "$rigPid" > "$seWs/.local/agents/sessions/$seId/control/pid"
	printf '1 1792000000 thinking\n' > "$seWs/.local/agents/sessions/$seId/activity"
	printf '%s claude --verbose --session-id %s --agent magic-coordinator the brief\n' "$rigPid" "$seId" >> "$seRoot/ps.list"
}

## One closed session of a fixture, seeded as plain files: its record, its state and its closed line. No writer runs here
## for it, since 1600 of them would be 1600 shell calls. Nothing in it may be opened by the active read, and that is the
## point of the fixture: if the read did reach one, the count of files would grow by it.
rigClosedSession(){ ## root, sandbox name, session id, started-at, resolved-at, sequence number
	local seWs="$1/ws" seBox="$2" seId="$3" seAt="$4" seResolved="$5" seSeq="$6"
	mkdir -p "$seWs/.local/agents/spawned/$seBox" "$seWs/.local/agents/sessions/$seId/control" \
		|| rigRefuse "a closed session of the fixture could not be made: $seId"
	printf 'state: finished\nstate-at: %s\nreason: the rig says so\nseq: 1\n' "$seResolved" \
		> "$seWs/.local/agents/sessions/$seId/control/state"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-rig\nowner: magic-tester\nstatus: spawn-succeeded\nstarted-at: %s\nresolved-at: %s\n---\n\n# Spawn session: %s\n' \
		"$seId" "$seBox" "$rigHost" "$seAt" "$seResolved" "$seId" > "$seWs/.local/agents/spawned/$seBox/$seBox.spawn.md"
	printf '%s\t%s\tmagic-tester\t-\t%s\t2025-06-01T10:00:00Z\tfinished\t%s\t-\t%s\n' \
		"$seSeq" "$seId" "$rigHost" "$seAt" "$seBox" >> "$seWs/.local/agents/closed-sessions.index"
}

## A fixture: three live sessions, the closed history and the board items it is given, and the same two epic documents in
## every fixture, so the two of a pair differ by one number and nothing else.
rigFixture(){ ## root, closed sessions, board items
	local fxRoot="$1" fxClosed="$2" fxBoards="$3" fxAt=0 fxWs="$1/ws"
	[ ! -e "$fxRoot" ] || rigRefuse "the fixture is already there: $fxRoot"
	mkdir -p "$fxWs/.local/.agents" "$fxWs/.local/agents/spawned" "$fxWs/.local/agents/pending" \
		"$fxWs/.local/agents/sessions" "$fxWs/.local/agents/live" "$fxWs/.local/temp" "$fxRoot/home" "$fxRoot/skills" \
		"$fxRoot/data/board/running" "$fxRoot/data/board/blocked" "$fxRoot/data/vault" \
		|| rigRefuse "the fixture could not be made: $fxRoot"
	: > "$fxRoot/ps.list"
	fxAt=0
	while [ "$fxAt" -lt 3 ] ; do
		fxAt=$(( fxAt + 1 ))
		rigLiveSession "$fxRoot" "active$fxAt" "s-active-$fxAt" "2026-11-20 10:0$fxAt +0200"
	done
	fxAt=0
	while [ "$fxAt" -lt "$fxClosed" ] ; do
		fxAt=$(( fxAt + 1 ))
		rigClosedSession "$fxRoot" "closed$fxAt" "s-closed-$fxAt" "2025-06-01 09:00 +0200" "2025-06-01 11:00 +0200" "$fxAt"
	done
	fxAt=0
	while [ "$fxAt" -lt "$fxBoards" ] ; do
		fxAt=$(( fxAt + 1 ))
		printf -- '---\ntype: task\nstatus: running\nowner: magic-coordinator\n---\n\n# board item %s\n' "$fxAt" \
			> "$fxRoot/data/board/running/task-20251101T0000Z-rig-$fxAt.md"
	done
	printf -- '---\ntype: epic-blueprint\n---\n\n# Epic alpha\n\n## Part 1\nx\n\n## Part 2\ny\n' > "$fxRoot/data/vault/epic-blueprint-20260101T0000Z-alpha.md"
	printf -- '---\ntype: epic-blueprint\n---\n\n# Epic beta\n\n## Part 1\nx\n' > "$fxRoot/data/vault/epic-blueprint-20260102T0000Z-beta.md"
}

## Every file of a fixture taken back to the two marks, so a read is the only thing that can move them.
rigMark(){ ## root
	find "$1/ws/.local" "$1/data" -type f -exec touch -a -t "$rigAtimeMark" {} + 2> /dev/null
	find "$1/ws/.local" "$1/data" -type f -exec touch -m -t "$rigMtimeMark" {} + 2> /dev/null
}
## THE FILES A READ OPENED: the access time moved, the content time stood. A folder is never counted, since `find` reads
## every folder it passes through, and would mark the whole fixture itself.
rigOpened(){ ## root
	find "$1/ws/.local" "$1/data" -type f -newerat "$rigACut" ! -newermt "$rigMCut" 2> /dev/null | LC_ALL=C sort
}
rigOpenedCount(){ ## root
	rigOpened "$1" | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigOpenedMatching(){ ## root, extended regular expression
	rigOpened "$1" | LC_ALL=C grep -c -E -- "$2" || :
}

## One read of the real dispatcher in a fixture, as the console makes it: a clean environment, that fixture's own workspace
## and team data store, and nothing of this machine.
rigRead(){ ## root, the operation and its words...
	local rdRoot="$1" ; shift
	rigRc=0
	( cd "$rdRoot/ws" && env -i AGENTS_REGISTRY_HOUSEKEEPING=1 HOME="$rdRoot/home" PATH="$rigTmp:$PATH" \
		MMDAPP="$rdRoot/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rdRoot/skills" MDAT_DATA_ROOT="$rdRoot/data" \
		bash "$rigTool" "$@" ) > "$rdRoot/out" 2> "$rdRoot/err" < /dev/null || rigRc=$?
}
rigSessionsListed(){ ## root -- the session ids the last read printed, sorted
	LC_ALL=C awk -F'\t' '$1 == "session" { print $2 ; }' "$1/out" | LC_ALL=C sort | LC_ALL=C awk '{ printf "%s ", $0 ; }'
}
rigSessionRows(){ ## root
	LC_ALL=C awk -F'\t' '$1 == "session" { n++ ; } END { print n + 0 ; }' "$1/out"
}
## A read known to scale with the whole store: every spawn record of a fixture, read by the check itself. It is the
## known-bad subject the comparison is shown able to fail on. A file is READ here, not merely opened.
rigWalkOpen(){ ## root
	local wkFile
	for wkFile in "$1/ws/.local/agents/spawned"/*/*.spawn.md ; do
		[ -f "$wkFile" ] || continue
		cat -- "$wkFile" > /dev/null
	done
}

## THE FIXTURES. The closed history is the one thing the first two pairs differ by, and the board the one thing the last
## two differ by, so no other difference can account for a count that moves.
for rigPair in active board epic ; do
	for rigSide in few many ; do
		case "$rigPair:$rigSide" in
			active:few)  rigFixture "$rigTmp/active-few" 0 3 ;;
			active:many) rigFixture "$rigTmp/active-many" 1600 3 ;;
			board:few)   rigFixture "$rigTmp/board-few" 0 3 ;;
			board:many)  rigFixture "$rigTmp/board-many" 0 1600 ;;
			epic:few)    rigFixture "$rigTmp/epic-few" 0 3 ;;
			epic:many)   rigFixture "$rigTmp/epic-many" 0 1600 ;;
		esac
	done
done

echo "-- 0. the screen's own declarations, and the census itself --"
rigDeclared(){ ## a word -- `declared` where it is not empty, else `not-declared`. A function, since a `case` with an empty
	## pattern inside a command substitution is misread by the shell.
	if [ -n "${1:-}" ] ; then printf declared ; else printf not-declared ; fi
}
rigActiveArm="$( LC_ALL=C grep -c -F -e "${rigOpActive:-none})" "$rigPkg/sh-lib/manager/AgentsTools.ManagerSession.include" 2> /dev/null || : )"
rigAssert "the screen declares an operation for its Active Sessions list, and the tooling dispatches that one" \
	"$( rigDeclared "$rigOpActive" ) $rigActiveArm" "declared 1"
rigAssert "the screen declares an operation for its Epics list, and it is --epic-list" "$rigOpEpic" "--epic-list"
printf '        the Active Sessions read this check measures: %s\n' "$rigOpActive"
rigMark "$rigTmp/active-few"
cat "$rigTmp/active-few/data/vault/epic-blueprint-20260101T0000Z-alpha.md" > /dev/null 2>&1
rigAssert "the census counts the one file the check itself read from the fixture" "$( rigOpenedCount "$rigTmp/active-few" )" "1"
rigAssert "the comparison reports a difference it is given: two files then three" "$( rigVerdict 2 3 )" "differs"
rigMark "$rigTmp/active-few" ; rigWalkOpen "$rigTmp/active-few" ; rigWalkFew="$( rigOpenedCount "$rigTmp/active-few" )"
rigMark "$rigTmp/active-many" ; rigWalkOpen "$rigTmp/active-many" ; rigWalkMany="$( rigOpenedCount "$rigTmp/active-many" )"
rigAssert "the same comparison, pointed at a read that walks the store, reports a difference: the assertion can fail" \
	"$( rigVerdict "$rigWalkFew" "$rigWalkMany" )" "differs"
printf '        a walk over the whole store opens %s files at 3 sessions and %s at 1600\n' "$rigWalkFew" "$rigWalkMany"

echo "-- 1. Active Sessions: the same three live sessions, with and without a closed history --"
rigMark "$rigTmp/active-few"
rigRead "$rigTmp/active-few" "$rigOpActive"
rigFewRc="$rigRc" ; rigFewRows="$( rigSessionRows "$rigTmp/active-few" )"
rigFewFiles="$( rigOpenedCount "$rigTmp/active-few" )"
rigFewLive="$( rigSessionsListed "$rigTmp/active-few" )"
rigMark "$rigTmp/active-many"
rigRead "$rigTmp/active-many" "$rigOpActive"
rigManyRc="$rigRc" ; rigManyRows="$( rigSessionRows "$rigTmp/active-many" )"
rigManyFiles="$( rigOpenedCount "$rigTmp/active-many" )"
rigAssert "the read is real in both fixtures: it ends 0, lists three sessions, and opens files" \
	"$rigFewRc $rigFewRows $rigManyRc $rigManyRows $( rigYesNo "$(( rigFewFiles > 0 ? 0 : 1 ))" )" "0 3 0 3 yes"
rigAssert "the fixture with no closed history lists the three live sessions" "$rigFewLive" "s-active-1 s-active-2 s-active-3 "
printf '        files opened by the active read: %s at 3 closed sessions, %s at 1600\n' "$rigFewFiles" "$rigManyFiles"
rigAssert "the active read opens the same number of files at 3 closed sessions and at 1600" \
	"$( rigVerdict "$rigFewFiles" "$rigManyFiles" )" "same"
rigAssert "the active read opens no file of a closed session, of its sandbox, its store or its block, at 1600 closed sessions" \
	"$( rigOpenedMatching "$rigTmp/active-many" '/agents/(spawned/closed[0-9]+|sessions/s-closed-[0-9]+|live/s-closed-[0-9]+)' )" "0"

echo "-- 2. the board a session list does not carry: the pending-replies walk, at 3 items and at 1600 --"
rigMark "$rigTmp/board-few"
rigRead "$rigTmp/board-few" "$rigOpActive"
rigBoardFewRc="$rigRc" ; rigBoardFewRows="$( rigSessionRows "$rigTmp/board-few" )"
rigBoardFew="$( rigOpenedMatching "$rigTmp/board-few" '/board/(running|blocked)/' )"
rigMark "$rigTmp/board-many"
rigRead "$rigTmp/board-many" "$rigOpActive"
rigBoardManyRc="$rigRc" ; rigBoardManyRows="$( rigSessionRows "$rigTmp/board-many" )"
rigBoardMany="$( rigOpenedMatching "$rigTmp/board-many" '/board/(running|blocked)/' )"
rigBoardManyFiles="$( rigOpenedCount "$rigTmp/board-many" )"
rigAssert "the pair is the one it says: the same three sessions read over 3 board items and over 1600" \
	"$rigBoardFewRc $rigBoardFewRows $rigBoardManyRc $rigBoardManyRows" "0 3 0 3"
printf '        board items opened by the active read: %s at 3 board items, %s at 1600 (all files opened: %s)\n' \
	"$rigBoardFew" "$rigBoardMany" "$rigBoardManyFiles"
rigAssert "the active read opens no item of the board's running or blocked states, so no walk of them is on its path" \
	"$rigBoardFew" "0"
rigAssert "the active read opens the same number of board files at 3 board items and at 1600" \
	"$( rigVerdict "$rigBoardFew" "$rigBoardMany" )" "same"

echo "-- 3. Epics: the vault's epic documents, and nothing that grows with the board --"
rigMark "$rigTmp/epic-few"
rigRead "$rigTmp/epic-few" "$rigOpEpic"
rigEpicFewRc="$rigRc" ; rigEpicFewFiles="$( rigOpenedCount "$rigTmp/epic-few" )"
rigEpicDocs="$( rigOpened "$rigTmp/epic-few" | LC_ALL=C sed "s#^$rigTmp/epic-few##" | LC_ALL=C sort )"
rigEpicRows="$( LC_ALL=C grep -c -E '^epic-blueprint-[^ ]+ [0-9]+ sections$' "$rigTmp/epic-few/out" || : )"
rigMark "$rigTmp/epic-many"
rigRead "$rigTmp/epic-many" "$rigOpEpic"
rigEpicManyRc="$rigRc" ; rigEpicManyFiles="$( rigOpenedCount "$rigTmp/epic-many" )"
rigAssert "the Epics read is real in both fixtures: it ends 0 and lists the two epic documents" \
	"$rigEpicFewRc $rigEpicManyRc $rigEpicRows" "0 0 2"
printf '        files opened by the Epics read: %s at 3 board items, %s at 1600\n' "$rigEpicFewFiles" "$rigEpicManyFiles"
rigAssert "the Epics read opens the vault's two epic documents, and no other file" "$rigEpicDocs" \
	"/data/vault/epic-blueprint-20260101T0000Z-alpha.md
/data/vault/epic-blueprint-20260102T0000Z-beta.md"
rigAssert "the Epics read opens the same number of files with 3 board items and with 1600" \
	"$( rigVerdict "$rigEpicFewFiles" "$rigEpicManyFiles" )" "same"
rigAssert "the Epics read opens no item of a board state, whatever the board holds" \
	"$( rigOpenedMatching "$rigTmp/epic-many" '/board/(running|blocked)/' )" "0"

echo "-- 4. the writers: a session spawned and then closed, and the three stores it leaves --"
rigWrWs="$rigTmp/writers/ws"
mkdir -p "$rigWrWs/.local/agents/sessions/s-write/control" "$rigWrWs/.local/temp" "$rigTmp/writers/home" \
	"$rigWrWs/.local/.agents" || rigRefuse "the writer rig could not be made"
printf 'state: running\nstate-at: 2026-11-20 10:00 +0200\nreason: the rig says so\nseq: 2\n' \
	> "$rigWrWs/.local/agents/sessions/s-write/control/state"
cat > "$rigTmp/writers/record" <<RIGRECORD
---
session-id: s-write
spawn-id: run-write
host: $rigHost
workspace: ws-rig
owner: magic-coordinator
status: spawn-started
started-at: 2026-11-20 10:00 +0200
---

# Spawn session: s-write
RIGRECORD
rigStoreWrite "$rigWrWs" "AgentsSpawnRecordWrite run-write run-write < \"$rigTmp/writers/record\"" \
	|| rigRefuse "the spawn record writer failed"
rigWrRuns="$rigWrWs/.local/agents/spawned-rows/run-write.rows"
rigAssert "a spawn record's own writer leaves that folder's runs block" \
	"$( rigYesNo "$( [ -f "$rigWrRuns" ] && printf 0 || printf 1 )" )" "yes"
rigAssert "the runs block's token is the three headers its record carries now" \
	"$( LC_ALL=C awk '/^src: / { print substr( $0, 6 ) ; exit ; }' "$rigWrRuns" 2> /dev/null )" "spawn-started - -"
rigStoreWrite "$rigWrWs" "AgentsToolsSessionLiveBlockWrite s-write 2" || rigRefuse "the live block writer failed"
rigWrLive="$rigWrWs/.local/agents/live/s-write.rows"
rigAssert "the live block's writer leaves the session's block" \
	"$( rigYesNo "$( [ -f "$rigWrLive" ] && printf 0 || printf 1 )" )" "yes"
rigAssert "the live block's token is the seq its session's state carries now" \
	"$( LC_ALL=C awk '/^seq: / { print substr( $0, 6 ) ; exit ; }' "$rigWrLive" 2> /dev/null )" "2"
rigStoreWrite "$rigWrWs" "AgentsToolsSessionClosedAppend s-write finished -" || rigRefuse "the closed-line writer failed"
rigWrClosed="$rigWrWs/.local/agents/closed-sessions.index"
rigAssert "the close's own writer appends one line, naming the session it closed" \
	"$( LC_ALL=C awk -F'\t' '$2 == "s-write" { n++ ; } END { print n + 0 ; }' "$rigWrClosed" 2> /dev/null )" "1"
rigAssert "the closed line carries its sequence number first, and the end word in the seventh field" \
	"$( LC_ALL=C awk -F'\t' '$2 == "s-write" { print $1, $7 ; }' "$rigWrClosed" 2> /dev/null )" "1 finished"

echo
if [ "$rigFail" -gt 0 ] ; then
	echo "⛔ MANAGER SESSIONS STORE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)"
	exit 1
fi
echo "✅ MANAGER SESSIONS STORE CHECK: all $rigPass assertions hold"
exit 0
