#!/usr/bin/env bash
## Behavioural check on what two manager reads OPEN: the sessions a list carries, and the board it does not carry.
## Every file of the rig is marked with an old access time and a later content time, and a read's own mark is an access
## time that moved while the content time stood: an open that read a file moves that file's access time, and a file the
## read rewrote is told from a file it only read by its content time. Wall time is never measured.
## Held:
##   0. the census itself: it counts a file the check reads, leaves out one nobody read, and the same comparison
##      reports a difference when it is pointed at a read that does scale
##   1. Active Sessions: three live sessions, once with no closed history and once with 1600 closed sessions, open the
##      same number of files, and no file of a closed session is among them
##   2. that read opens no item of a board state, so the pending-replies walk of board/running and board/blocked is gone
##   3. Epics: the read opens the vault's epic documents and nothing else, with 3 board items and with 1600
## Red before the build: the active read opens every sandbox, every session store and every board item, so 1 and 2 fail,
## and the counts are printed for both fixtures. Once the per-session stores land, the same check must pass unchanged.
## Offline: a rig workspace of this check's own with its own team data, and the real dispatcher of the origin.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
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

## The mark a read leaves, and the mark it does not: a file read has its access time moved past the cut, and a file
## only read has its content time where the mark left it. A file rewritten has both moved, and is no open to count.
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
rigVerdict(){ ## one count, another count -- `same` or `differs`, the comparison every case below rests on
	if [ "$1" = "$2" ] ; then printf 'same' ; else printf 'differs' ; fi
}

## THE RIG'S OWN PROCESS LIST, so a session is live by what the tooling reads, and no process of this host is seen.
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

## One session of a fixture: its spawn record, its session store and its state. A live one carries its process in the
## rig's list; a closed one is settled and gone.
rigSession(){ ## root, sandbox name, session id, record status, resolved-at (empty for none), started-at, phase, live
	local seRoot="$1" seBox="$2" seId="$3" seStatus="$4" seResolved="$5" seAt="$6" sePhase="$7" sePid=""
	mkdir -p "$seRoot/ws/.local/agents/spawned/$seBox" "$seRoot/ws/.local/agents/sessions/$seId/control" \
		|| rigRefuse "a session of the fixture could not be made: $seId"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-rig\nowner: magic-coordinator\nstatus: %s\nstarted-at: %s\n' \
			"$seId" "$seId" "$rigHost" "$seStatus" "$seAt"
		[ -z "$seResolved" ] || printf 'resolved-at: %s\n' "$seResolved"
		printf -- '---\n\n# Spawn session: %s\n' "$seId"
	} > "$seRoot/ws/.local/agents/spawned/$seBox/$seBox.spawn.md"
	printf 'phase: %s\n' "$sePhase" > "$seRoot/ws/.local/agents/sessions/$seId/control/state"
	if [ "$sePhase" = active ] ; then
		printf '1 1792000000 thinking\n' > "$seRoot/ws/.local/agents/sessions/$seId/activity"
		rigPid=$(( rigPid + 1 ))
		printf '%s claude --verbose --session-id %s --agent magic-coordinator the brief\n' "$rigPid" "$seId" >> "$seRoot/ps.list"
	fi
}

## A fixture: three live sessions, the closed history and the board items it is given, and the same two epic documents
## in every fixture, so the two of a pair differ by one number and nothing else.
rigFixture(){ ## root, closed sessions, board items
	local fxRoot="$1" fxClosed="$2" fxBoards="$3" fxAt=0
	[ ! -e "$fxRoot" ] || rigRefuse "the fixture is already there: $fxRoot"
	mkdir -p "$fxRoot/ws/.local/.agents" "$fxRoot/ws/.local/agents/spawned" "$fxRoot/ws/.local/agents/pending" \
		"$fxRoot/ws/.local/agents/sessions" "$fxRoot/ws/.local/temp" "$fxRoot/home" "$fxRoot/skills" \
		"$fxRoot/data/board/running" "$fxRoot/data/board/blocked" "$fxRoot/data/vault" \
		|| rigRefuse "the fixture could not be made: $fxRoot"
	: > "$fxRoot/ps.list"
	fxAt=0
	while [ "$fxAt" -lt 3 ] ; do
		fxAt=$(( fxAt + 1 ))
		rigSession "$fxRoot" "active$fxAt" "s-active-$fxAt" spawn-started "" "2026-11-20 10:0$fxAt +0200" active
	done
	fxAt=0
	while [ "$fxAt" -lt "$fxClosed" ] ; do
		fxAt=$(( fxAt + 1 ))
		rigSession "$fxRoot" "closed$fxAt" "s-closed-$fxAt" spawn-succeeded "2025-06-01 11:00 +0200" "2025-06-01 09:00 +0200" closed
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

## Every file and folder of a fixture taken back to the two marks, so a read is the only thing that can move them.
rigMark(){ ## root
	local mkRoot="$1"
	find "$mkRoot/ws/.local" "$mkRoot/data" -type f -exec touch -a -t "$rigAtimeMark" {} + 2> /dev/null
	find "$mkRoot/ws/.local" "$mkRoot/data" -type f -exec touch -m -t "$rigMtimeMark" {} + 2> /dev/null
	find "$mkRoot/ws/.local" "$mkRoot/data" -type d -exec touch -a -t "$rigAtimeMark" {} + 2> /dev/null
	find "$mkRoot/ws/.local" "$mkRoot/data" -type d -exec touch -m -t "$rigMtimeMark" {} + 2> /dev/null
}

## The files a read opened, as the mark left them: the access time moved, the content time stood.
rigOpened(){ ## root
	find "$1/ws/.local" "$1/data" -type f -newerat "$rigACut" ! -newermt "$rigMCut" 2> /dev/null | LC_ALL=C sort
}
rigOpenedCount(){ ## root
	rigOpened "$1" | LC_ALL=C awk 'END { print NR + 0 ; }'
}
## A FOLDER IS NEVER COUNTED. `find` reads every folder it passes through, so the census would mark every folder of the
## fixture itself, and a listing would be told from no listing by nothing. The files are what the count is of.
## One read of the real dispatcher in a fixture, as the console makes it: a clean environment, that fixture's own
## workspace and team data store, and nothing of this machine.
rigRead(){ ## root, the operation and its words...
	local rdRoot="$1" ; shift
	rigRc=0
	( cd "$rdRoot/ws" && env -i AGENTS_REGISTRY_HOUSEKEEPING=1 HOME="$rdRoot/home" PATH="$rigTmp:$PATH" \
		MMDAPP="$rdRoot/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rdRoot/skills" MDAT_DATA_ROOT="$rdRoot/data" \
		bash "$rigTool" "$@" ) > "$rdRoot/out" 2> "$rdRoot/err" < /dev/null || rigRc=$?
}
rigSessionsListed(){ ## root -- the session ids the last read printed, sorted, so the order it lists them in is no finding
	LC_ALL=C awk -F'\t' '$1 == "session" { print $2 ; }' "$1/out" | LC_ALL=C sort | LC_ALL=C awk '{ printf "%s ", $0 ; }'
}
rigSessionRows(){ ## root
	LC_ALL=C awk -F'\t' '$1 == "session" { n++ ; } END { print n + 0 ; }' "$1/out"
}
## A read known to scale with the whole store: every spawn record of the fixture, read by the check itself. It is the
## known-bad subject the comparison is shown able to fail on. A file is READ here, not merely opened: an open whose
## content is never read moves no access time, and would count nothing.
rigWalkOpen(){ ## root -- the mark of reading every record of the store
	local wkFile
	for wkFile in "$1/ws/.local/agents/spawned"/*/*.spawn.md ; do
		[ -f "$wkFile" ] || continue
		cat -- "$wkFile" > /dev/null
	done
}

## THE FIXTURES. Two pairs, each differing by one number: the closed history, and the board.
for rigPair in active epic ; do
	for rigSide in few many ; do
		rigRoot="$rigTmp/$rigPair-$rigSide"
		case "$rigPair:$rigSide" in
			active:few)  rigFixture "$rigRoot" 0 3 ;;
			active:many) rigFixture "$rigRoot" 1600 3 ;;
			epic:few)    rigFixture "$rigRoot" 0 3 ;;
			epic:many)   rigFixture "$rigRoot" 0 1600 ;;
		esac
	done
done
rigActiveFew="$rigTmp/active-few"
rigActiveMany="$rigTmp/active-many"
rigEpicFew="$rigTmp/epic-few"
rigEpicMany="$rigTmp/epic-many"

echo "-- 0. the census itself: it counts a read, leaves an unread file alone, and reports a difference it is given --"
rigMark "$rigActiveFew"
cat "$rigActiveFew/data/vault/epic-blueprint-20260101T0000Z-alpha.md" > /dev/null 2>&1
rigAssert "the census counts the one file the check itself read from the fixture" "$( rigOpenedCount "$rigActiveFew" )" "1"
rigAssert "the comparison reports a difference it is given: two files then three" "$( rigVerdict 2 3 )" "differs"
rigAssert "and reports none between one number and itself" "$( rigVerdict 5 5 )" "same"
rigMark "$rigActiveFew" ; rigWalkOpen "$rigActiveFew" ; rigWalkFew="$( rigOpenedCount "$rigActiveFew" )"
rigMark "$rigActiveMany" ; rigWalkOpen "$rigActiveMany" ; rigWalkMany="$( rigOpenedCount "$rigActiveMany" )"
rigAssert "the same comparison, pointed at a read that walks the store, reports a difference: the assertion can fail" \
	"$( rigVerdict "$rigWalkFew" "$rigWalkMany" )" "differs"
printf '        a walk over the whole store opens %s files at 3 sessions and %s at 1600\n' "$rigWalkFew" "$rigWalkMany"

echo "-- 1. Active Sessions: the same three live sessions, with and without a closed history --"
rigMark "$rigActiveFew"
rigRead "$rigActiveFew" --manager-session-list
rigFewRc="$rigRc" ; rigFewRows="$( rigSessionRows "$rigActiveFew" )" ; rigFewLive="$( rigSessionsListed "$rigActiveFew" )"
rigFewFiles="$( rigOpenedCount "$rigActiveFew" )"
rigMark "$rigActiveMany"
rigRead "$rigActiveMany" --manager-session-list
rigManyRc="$rigRc" ; rigManyRows="$( rigSessionRows "$rigActiveMany" )" ; rigManyFiles="$( rigOpenedCount "$rigActiveMany" )"
rigAssert "the read is real in both fixtures: it ends 0 in each" "$rigFewRc $rigManyRc" "0 0"
rigAssert "the fixture with no closed history lists the three live sessions" "$rigFewLive" "s-active-1 s-active-2 s-active-3 "
rigAssert "the fixture with 1600 closed sessions is the one it says: the list carries 1603 sessions, so no case here is vacuous" \
	"$rigManyRows" "1603"
printf '        files opened by the active read: %s at 3 closed sessions, %s at 1600\n' "$rigFewFiles" "$rigManyFiles"
rigAssert "the active read opens the same number of files at 3 closed sessions and at 1600" \
	"$( rigVerdict "$rigFewFiles" "$rigManyFiles" )" "same"
rigClosedOpened="$( rigOpened "$rigActiveMany" | LC_ALL=C grep -c -E '/agents/(spawned/closed[0-9]+|sessions/s-closed-[0-9]+)/' || : )"
rigAssert "the active read opens no file of a closed session, of its sandbox or of its store" "$rigClosedOpened" "0"

echo "-- 2. the board a session list does not carry: no item of a board state is opened by that read --"
rigBoardOpened="$( rigOpened "$rigActiveMany" | LC_ALL=C grep -c -E '/board/(running|blocked)/' || : )"
rigAssert "the active read opens no item of the board's running or blocked states, so no walk of them is on its path" \
	"$rigBoardOpened" "0"

echo "-- 3. Epics: the vault's epic documents, and nothing that grows with the board --"
rigMark "$rigEpicFew"
rigRead "$rigEpicFew" --epic-list
rigEpicFewRc="$rigRc" ; rigEpicFewFiles="$( rigOpenedCount "$rigEpicFew" )"
rigEpicRows="$( LC_ALL=C grep -c -E '^epic-blueprint-[^ ]+ [0-9]+ sections$' "$rigEpicFew/out" || : )"
rigEpicDocs="$( rigOpened "$rigEpicFew" | LC_ALL=C sed "s#^$rigEpicFew##" | LC_ALL=C sort )"
rigMark "$rigEpicMany"
rigRead "$rigEpicMany" --epic-list
rigEpicManyRc="$rigRc" ; rigEpicManyFiles="$( rigOpenedCount "$rigEpicMany" )"
rigAssert "the Epics read is real in both fixtures: it ends 0 and lists the two epic documents" \
	"$rigEpicFewRc $rigEpicManyRc $rigEpicRows" "0 0 2"
printf '        files opened by the Epics read: %s at 3 board items, %s at 1600\n' "$rigEpicFewFiles" "$rigEpicManyFiles"
rigAssert "the Epics read opens the vault's epic documents, and no other file: the count is those documents plus zero" \
	"$rigEpicDocs" "/data/vault/epic-blueprint-20260101T0000Z-alpha.md
/data/vault/epic-blueprint-20260102T0000Z-beta.md"
rigAssert "the Epics read opens the same number of files with 3 board items and with 1600" \
	"$( rigVerdict "$rigEpicFewFiles" "$rigEpicManyFiles" )" "same"
rigEpicBoardOpened="$( rigOpened "$rigEpicMany" | LC_ALL=C grep -c -E '/board/(running|blocked)/' || : )"
rigAssert "the Epics read opens no item of a board state, whatever the board holds" "$rigEpicBoardOpened" "0"

echo
if [ "$rigFail" -gt 0 ] ; then
	echo "⛔ MANAGER SESSIONS STORE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)"
	exit 1
fi
echo "✅ MANAGER SESSIONS STORE CHECK: all $rigPass assertions hold"
exit 0
