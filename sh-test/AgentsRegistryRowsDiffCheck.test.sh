#!/usr/bin/env bash
## Differential check on the spawned-sessions and pending-replies row builders: the
## one-awk-pass rows (AgentsTools.Registries.include + AgentsRegistryHeaderRows.awk)
## print byte-identical output to the per-file, per-column rows they replaced
## (check-fixtures/AgentsToolsRegistriesRows.legacy.sh), over crafted edge stores and,
## with --live-copy-from <workspace>, over a copy of that workspace's own stores.
## The live stores are only read: each record is copied into this rig up to and
## including its closing `---`, all a row reads. Offline; the rig is a mktemp tree.
## Prints the time each side took per store.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigLiveFrom=""
[ "${1:-}" != "--live-copy-from" ] || rigLiveFrom="${2:?⛔ ERROR: --live-copy-from needs a workspace}"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/AgentsTools.Registries.include" ] || rigRefuse "not found: $rigHere/AgentsTools.Registries.include"
[ -f "$rigHere/AgentsRegistryHeaderRows.awk" ] || rigRefuse "not found: $rigHere/AgentsRegistryHeaderRows.awk"
[ -f "$rigTest/check-fixtures/AgentsToolsRegistriesRows.legacy.sh" ] || rigRefuse "legacy rows fixture not found"
rigTmp="$( mktemp -d -t AgentsRegistryRowsDiffCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigHolderPid=""
trap '[ -z "$rigHolderPid" ] || kill "$rigHolderPid" 2>/dev/null ; chmod -R u+rwx "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## Runs one rows function against one rig workspace and data root, into a file, and
## prints the seconds it took.
rigRun(){ ## function, workspace, data root ("" for unset), output file
	(
		MMDAPP="$2"
		if [ -n "$3" ] ; then MDAT_DATA_ROOT="$3" ; else unset MDAT_DATA_ROOT ; fi
		. "$rigHere/AgentsTools.Registries.include"
		. "$rigTest/check-fixtures/AgentsToolsRegistriesRows.legacy.sh"
		rigStart="$SECONDS"
		"$1" > "$4" 2>"$4.err"
		printf '%s\n' "$(( SECONDS - rigStart ))"
	)
}

## Old and new over one store: identical bytes, stderr included, and a row count.
rigCompare(){ ## label, workspace, data root
	local cmpOldSecs cmpNewSecs cmpKind cmpOld cmpNew
	for cmpKind in SpawnedSessions PendingReplies ; do
		cmpOld="$rigTmp/out.$cmpKind.old" ; cmpNew="$rigTmp/out.$cmpKind.new"
		cmpOldSecs="$( rigRun "AgentsToolsRegistryLegacy${cmpKind}Rows" "$2" "$3" "$cmpOld" )"
		cmpNewSecs="$( rigRun "AgentsToolsRegistry${cmpKind}Rows" "$2" "$3" "$cmpNew" )"
		if cmp -s "$cmpOld" "$cmpNew" && cmp -s "$cmpOld.err" "$cmpNew.err" ; then
			rigAssert "$1: $cmpKind rows byte-identical ($( LC_ALL=C awk 'END { print NR + 0 ; }' "$cmpNew" ) rows; old ${cmpOldSecs}s, new ${cmpNewSecs}s)" same same
		else
			rigAssert "$1: $cmpKind rows byte-identical" "$( diff "$cmpOld" "$cmpNew" | head -20 ; diff "$cmpOld.err" "$cmpNew.err" | head -5 )" same
		fi
	done
}

## The whole spawned-sessions render, old (per-row state forks) against new (one open-ask
## set), for every view and filter shape: identical bytes, stderr included. Both sides
## rebuild the rig's own registries, never a live one.
rigRenderCompare(){ ## label, workspace, data root, a session id to filter on
	local renderArgs renderOld renderNew renderOldSecs renderNewSecs renderView renderSession renderState renderTotalOld=0 renderTotalNew=0 renderBad=""
	for renderArgs in "||" "agents||" "sessions||" "agents|$4|" "sessions|$4|" "agents||running" "agents||waiting" "agents||unclosed" "agents||finished" "sessions||running" "sessions||unclosed" "sessions||waiting" ; do
		renderView="${renderArgs%%|*}" ; renderState="${renderArgs##*|}"
		renderSession="${renderArgs#*|}" ; renderSession="${renderSession%|*}"
		renderOld="$rigTmp/render.old" ; renderNew="$rigTmp/render.new"
		renderOldSecs="$( rigRender AgentsToolsRegistryLegacyRenderSpawnedSessions "$2" "$3" "$renderOld" "$renderView" "$renderSession" "$renderState" )"
		renderNewSecs="$( rigRender AgentsToolsRegistryRenderSpawnedSessions "$2" "$3" "$renderNew" "$renderView" "$renderSession" "$renderState" )"
		renderTotalOld=$(( renderTotalOld + renderOldSecs )) ; renderTotalNew=$(( renderTotalNew + renderNewSecs ))
		cmp -s "$renderOld" "$renderNew" && cmp -s "$renderOld.err" "$renderNew.err" \
			|| renderBad="$renderBad [$renderArgs] $( diff "$renderOld" "$renderNew" | head -6 | tr '\n' ' ' )"
	done
	rigAssert "$1: spawned-sessions render byte-identical in 12 view/filter shapes (old ${renderTotalOld}s, new ${renderTotalNew}s)" "${renderBad:-same}" same
}
rigRender(){ ## function, workspace, data root ("" for unset), output file, view, session filter, state filter
	(
		MMDAPP="$2"
		if [ -n "$3" ] ; then MDAT_DATA_ROOT="$3" ; else unset MDAT_DATA_ROOT ; fi
		. "$rigHere/AgentsTools.Registries.include"
		. "$rigTest/check-fixtures/AgentsToolsRegistriesRows.legacy.sh"
		rigStart="$SECONDS"
		"$1" "$5" "$6" "$7" > "$4" 2>"$4.err"
		printf '%s\n' "$(( SECONDS - rigStart ))"
	)
}

## --- crafted edge stores ---
rigWs="$rigTmp/crafted/ws"
rigData="$rigTmp/crafted/data"
rigSp="$rigWs/.local/agents/spawned"
rigPend="$rigWs/.local/agents/pending"
rigNl=$'\n'
mkdir -p "$rigSp" "$rigPend" "$rigData/board/running" "$rigData/board/blocked"

rigCompare "no store at all" "$rigTmp/none" ""

mkdir -p "$rigSp/s-empty/input" "$rigSp/s-other/sub.md" "$rigSp/s space name" "$rigSp/s\\back" "$rigSp/s${rigNl}nl" "$rigSp/.hidden" "$rigSp/s-multi" "$rigSp/s-odd" "$rigSp/s-unread" "$rigSp/s-links" "$rigTmp/real-sandbox"
printf 'note\n' > "$rigSp/s-other/notes.txt"
printf -- '---\nsession-id: hid\n---\n' > "$rigSp/.hidden/r.md"
## Multi-record sandbox: a record's own tracking-name carries on to the later records.
printf -- '---\ntracking-name: renamed-x\nsession-id: s1\nspawn-id: p1\nhost: h1\nowner: o1\nstatus: started\nexit-code: 0\nparent-session-id: -\nagent-log-thread: t1\nsession-thread: t2\nworkspace: ws1\n---\nbody\n' > "$rigSp/s-multi/a.md"
printf -- '---\nsession-id: s2\n---\n' > "$rigSp/s-multi/b.md"
printf 'no frontmatter at all\nstatus: body\n' > "$rigSp/s-multi/c.md"
printf -- '---\ntracking-name:   \nsession-id: s4\n---\n' > "$rigSp/s-multi/d.md"
: > "$rigSp/s-multi/e-empty.md"
## Odd shapes: no closing ---, a first empty value then a real one, inner whitespace,
## no space after the colon, a leading colon, a key with a trailing space, CR endings,
## headers before the first and after the second ---, a third block, `--- ` lookalike.
printf -- '---\nsession-id: open\nstatus: no-close\n' > "$rigSp/s-odd/1-noclose.md"
printf -- 'status: pre\n--- \n---\nstatus:\nstatus: started\nhost:  my  \t host \t\nowner:x\n:lead: y\nsession-id : bad\nspawn-id: abc\r\nexit-code: a:b: c\n---\nworkspace: post\n---\nworkspace: third\n---\n' > "$rigSp/s-odd/2-shapes.md"
printf -- '---\r\nsession-id: crlf\r\n---\r\n' > "$rigSp/s-odd/3-crlf.md"
printf -- '---\nsession-id: lastline-no-newline' > "$rigSp/s-odd/4-nonl.md"
printf -- '---\nsession-id: eq\n---\n' > "$rigSp/s-odd/a=b.md"
printf -- '---\nsession-id: dash\n---\n' > "$rigSp/s-odd/-.md"
printf -- '---\nsession-id: bs\\x\n---\n' > "$rigSp/s-odd/back\\slash.md"
printf -- '---\nsession-id: nl\n---\n' > "$rigSp/s-odd/new${rigNl}line.md"
printf -- '---\nsession-id: sp\n---\n' > "$rigSp/s-odd/with space.md"
printf -- '---\nsession-id: in-space-sandbox\n---\n' > "$rigSp/s space name/r.md"
printf -- '---\nsession-id: in-backslash-sandbox\n---\n' > "$rigSp/s\\back/r.md"
printf -- '---\nsession-id: in-newline-sandbox\n---\n' > "$rigSp/s${rigNl}nl/r.md"
printf -- '---\nsession-id: unread\n---\n' > "$rigSp/s-unread/r.md"
printf -- '---\nsession-id: read-after-unread\n---\n' > "$rigSp/s-unread/s.md"
chmod 000 "$rigSp/s-unread/r.md"
printf -- '---\nsession-id: via-link\n---\n' > "$rigTmp/real-sandbox/r.md"
ln -s "$rigTmp/real-sandbox" "$rigSp/s-linked"
ln -s "$rigTmp/real-sandbox/r.md" "$rigSp/s-links/linked.md"
ln -s "$rigTmp/nowhere.md" "$rigSp/s-links/dangling.md"
ln -s "$rigTmp/nowhere" "$rigSp/s-dangling"
printf 'x\n' > "$rigSp/not-a-dir.md"

printf -- '---\nstatus: reply-pending\nsession-id: a1\nowner: magic-coordinator\ncommunication-channel-id: C1\n---\nq\n' > "$rigPend/ask-1.md"
printf -- '---\nstatus: received\nsession-id: a2\nblocked-on: human\n---\n' > "$rigPend/ask-2.md"
cp "$rigSp/s-odd/2-shapes.md" "$rigPend/ask-3-shapes.md"
cp "$rigSp/s-odd/1-noclose.md" "$rigPend/ask-4-noclose.md"
printf 'plain\n' > "$rigPend/ask-5-nofm.md"
printf -- '---\nstatus: x\n---\n' > "$rigPend/ask\\6.md"
printf -- '---\nstatus: y\n---\n' > "$rigPend/ask${rigNl}7.md"
printf -- '---\nstatus: z\n---\n' > "$rigPend/ask-8-unread.md"
chmod 000 "$rigPend/ask-8-unread.md"
mkdir -p "$rigPend/dir.md"
printf 'n\n' > "$rigPend/ignored.txt"
printf -- '---\nblocked-on: human\nstatus: waiting\nsession-id: b1\nowner: magic-devops\n---\n' > "$rigData/board/running/task-1.md"
printf -- '---\nstatus: running\nsession-id: b2\n---\n' > "$rigData/board/running/task-2-not-blocked.md"
printf -- '---\nblocked-on:\nblocked-on: later value\n---\n' > "$rigData/board/running/task-3.md"
printf -- '---\nblocked-on:   \n---\n' > "$rigData/board/running/task-4-empty.md"
printf -- 'blocked-on: outside\n---\n---\n' > "$rigData/board/blocked/task-5-outside.md"
printf -- '---\nblocked-on: q\n' > "$rigData/board/blocked/task-6-noclose.md"

rigCompare "crafted stores" "$rigWs" "$rigData"
rigCompare "crafted stores, MDAT_DATA_ROOT unset" "$rigWs" ""
rigCompare "crafted stores, data root without a board" "$rigWs" "$rigTmp/crafted/no-board"
rm -rf -- "$rigData/board/blocked"
rigCompare "crafted stores, no blocked/ state" "$rigWs" "$rigData"

## The crafted store is only a proof when it reaches the cases it names.
rigNewRows="$rigTmp/out.SpawnedSessions.new"
rigAssert "an empty sandbox is a no-session-record row" "$( grep -c '^s-empty - - - - no-session-record' "$rigNewRows" )" 1
rigAssert "a record's tracking-name carries to later records of its sandbox" "$( grep -c '^renamed-x ' "$rigNewRows" )" 5
rigAssert "the unreadable record is a row of dashes" "$( grep -c '^s-unread - - - - - - - - - -$' "$rigNewRows" )" 1

rigRenderCompare "crafted stores" "$rigWs" "$rigData" s4

## --- crafted state-derivation store: every live and state path, and every way an
## open ask's session id can match one ---
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigRWs="$rigTmp/render/ws"
rigRData="$rigTmp/render/data"
rigRSp="$rigRWs/.local/agents/spawned"
mkdir -p "$rigRSp" "$rigRWs/.local/agents/pending" "$rigRData/board/running" "$rigRData/board/blocked"
rigRunSpawn="rig-spawn-running-$$"
( exec -a "rig-holder $rigRunSpawn rig\\bs-$$ rig.star*-$$" sleep 600 ) &
rigHolderPid=$!
sleep 1
rigRec(){ ## sandbox, record, session-id, spawn-id, host, status
	mkdir -p "$rigRSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nstatus: %s\nowner: o\n---\n' "$3" "$4" "$5" "$6" > "$rigRSp/$1/$2.md"
}
rigAsk(){ ## file, session-id, status
	printf -- '---\nsession-id: %s\nstatus: %s\nowner: o\n---\n' "$2" "$3" > "$rigRWs/.local/agents/pending/$1.md"
}
rigRec r-finished-1 a s-fin p-fin "$rigHost" spawn-succeeded
rigRec r-finished-2 a s-fin2 p-fin2 elsewhere spawn-failed
rigRec r-finished-3 a s-open p-fin3 "$rigHost" spawn-ended-without-close
rigRec r-foreign a s-open p-foreign elsewhere started
rigRec r-running a s-run "$rigRunSpawn" "$rigHost" started
rigRec r-run-prefix a s-x "rig-spawn-running" "$rigHost" started
rigRec r-run-backslash a s-x "rig\\bs-$$" "$rigHost" started
rigRec r-run-meta a s-x "rig.star*-$$" "$rigHost" started
rigRec r-run-meta-miss a s-x "rig.sta?-$$" "$rigHost" started
rigRec r-nospawn a s-open - "$rigHost" started
rigRec r-nohost a s-open p-nohost - started
rigRec r-open-ask a s-open p-open "$rigHost" started
rigRec r-open-ask b s-open p-open-b "$rigHost" started
rigRec r-closed-ask a s-closed p-closed "$rigHost" started
rigRec r-board a s-board p-board "$rigHost" started
rigRec r-board-cleared a s-board-cleared p-board-cleared "$rigHost" started
rigRec r-numeric a 100 p-num "$rigHost" started
rigRec r-hex a 16 p-hex "$rigHost" started
rigRec r-numeric-miss a 101 p-num-miss "$rigHost" started
rigRec r-backslash a 'bs\x' p-bs "$rigHost" started
rigRec r-backslash-n a 'bs\n' p-bsn "$rigHost" started
rigRec r-dash a - p-dash "$rigHost" started
rigRec r-nosession a "" p-nosession "$rigHost" started
rigRec "r space tracking" a s-open p-space "$rigHost" started
rigRec r-prefix a s-ope p-prefix "$rigHost" started
mkdir -p "$rigRSp/r-empty"
rigAsk ask-open s-open reply-pending
rigAsk ask-closed s-closed received
rigAsk ask-numeric 1e2 reply-pending
rigAsk ask-hex 0x10 reply-pending
rigAsk ask-backslash 'bs\x' reply-pending
rigAsk ask-backslash-n 'bs\n' reply-pending
rigAsk ask-dash - reply-pending
printf -- '---\nblocked-on: human\nsession-id: s-board\n---\n' > "$rigRData/board/running/task-b.md"
printf -- '---\nsession-id: s-board-cleared\n---\n' > "$rigRData/board/blocked/task-c.md"
rigRenderCompare "state-derivation store" "$rigRWs" "$rigRData" s-open
rigRenderCompare "state-derivation store, MDAT_DATA_ROOT unset" "$rigRWs" "" 100
## The store is only a proof when its rows reach the states it names.
rigRenderOut="$rigTmp/render.state"
rigRender AgentsToolsRegistryRenderSpawnedSessions "$rigRWs" "$rigRData" "$rigRenderOut" agents "" "" > /dev/null
rigStateOf(){ ## tracking name -- the last column of its first row
	LC_ALL=C awk -v wantTracking="$1" '$1 == wantTracking && NF == 13 { print $13 ; exit ; }' "$rigRenderOut"
}
rigAssert "a closed status is finished" "$( rigStateOf r-finished-3 )" finished
rigAssert "another host is unknown-foreign" "$( rigStateOf r-foreign )" unknown-foreign
rigAssert "a live spawn is running" "$( rigStateOf r-running )" running
rigLiveOf(){ ## tracking name -- the live column of its first row
	LC_ALL=C awk -v wantTracking="$1" '$1 == wantTracking && NF == 13 { print $12 ; exit ; }' "$rigRenderOut"
}
rigAssert "a spawn id found inside a longer process argument is running" "$( rigLiveOf r-run-prefix )" running
rigAssert "a spawn id with a backslash is matched literally" "$( rigLiveOf r-run-backslash )" running
rigAssert "a spawn id with pattern characters is matched literally" "$( rigLiveOf r-run-meta )" running
rigAssert "a ? in a spawn id matches only itself" "$( rigLiveOf r-run-meta-miss )" no-process
rigAssert "an open ask makes waiting" "$( rigStateOf r-open-ask )" waiting
rigAssert "a received ask is unclosed" "$( rigStateOf r-closed-ask )" unclosed
rigAssert "a blocked board item makes waiting" "$( rigStateOf r-board )" waiting
rigAssert "awk's numeric == holds: 100 against an ask for 1e2" "$( rigStateOf r-numeric )" waiting
rigAssert "a backslash id goes through the function itself" "$( rigStateOf r-backslash )" "$( ( MMDAPP="$rigRWs" ; . "$rigHere/AgentsTools.Registries.include" ; AgentsToolsRegistryDeriveState started no-process 'bs\x' ) )"
rigAssert "a prefix of an open id is not open" "$( rigStateOf r-prefix )" unclosed
{ kill "$rigHolderPid" ; wait "$rigHolderPid" ; } 2>/dev/null ; rigHolderPid=""

## --- a copy of a live workspace's stores ---
if [ -n "$rigLiveFrom" ] ; then
	rigLiveWs="$rigTmp/live/ws"
	rigLiveData="$rigTmp/live/data"
	rigCopyHead(){ ## source file, target file -- up to and including the closing ---
		LC_ALL=C awk '{ print ; } $0 == "---" { fenceCount++ ; if (fenceCount >= 2) exit ; }' "$1" > "$2" 2>/dev/null || :
	}
	mkdir -p "$rigLiveWs/.local/agents/spawned" "$rigLiveWs/.local/agents/pending"
	for rigDir in "$rigLiveFrom/.local/agents/spawned"/*/ ; do
		[ -d "$rigDir" ] || continue
		rigName="${rigDir%/}" ; rigName="${rigName##*/}"
		mkdir -p "$rigLiveWs/.local/agents/spawned/$rigName"
		for rigFile in "$rigDir"*.md ; do
			[ -f "$rigFile" ] || continue
			rigCopyHead "$rigFile" "$rigLiveWs/.local/agents/spawned/$rigName/${rigFile##*/}"
		done
	done
	for rigFile in "$rigLiveFrom/.local/agents/pending"/*.md ; do
		[ -f "$rigFile" ] || continue
		rigCopyHead "$rigFile" "$rigLiveWs/.local/agents/pending/${rigFile##*/}"
	done
	if [ -n "${MDAT_DATA_ROOT:-}" ] ; then
		for rigState in running blocked ; do
			[ -d "$MDAT_DATA_ROOT/board/$rigState" ] || continue
			mkdir -p "$rigLiveData/board/$rigState"
			for rigFile in "$MDAT_DATA_ROOT/board/$rigState"/*.md ; do
				[ -f "$rigFile" ] || continue
				rigCopyHead "$rigFile" "$rigLiveData/board/$rigState/${rigFile##*/}"
			done
		done
	fi
	rigCompare "live copy of $rigLiveFrom" "$rigLiveWs" "$rigLiveData"
	## The copy keeps the live hosts, so this host's rows are measured against this
	## host's own process list: a spawn starting or ending between the two sides of
	## one shape would show as a difference, and is the one way this can be noisy.
	rigRenderCompare "live copy of $rigLiveFrom" "$rigLiveWs" "$rigLiveData" "$( LC_ALL=C awk 'NF >= 2 && $2 != "-" { print $2 ; exit ; }' "$rigTmp/out.SpawnedSessions.new" 2>/dev/null )"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REGISTRY ROWS DIFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REGISTRY_ROWS_DIFF: OK (%d assertions, offline)\n' "$rigPassCount"
