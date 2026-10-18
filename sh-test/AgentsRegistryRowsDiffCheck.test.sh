#!/usr/bin/env bash
## Differential check on the spawned-sessions and pending-replies row builders: the
## one-awk-pass rows (AgentsTools.Registries.include + AgentsRegistryHeaderRows.awk)
## print byte-identical output to the per-file, per-column rows they replaced
## (check-fixtures/AgentsToolsRegistriesRows.legacy.sh), over crafted edge stores and,
## with --live-copy-from <workspace>, over a copy of that workspace's own stores.
## The live stores are only read: each record is copied into this rig up to and
## including its closing `---`, all a row reads. Offline; the rig is a mktemp tree.
## Holds how a run is recognised too (AgentsToolsRegistryRunningSpawns): by the value of its own
## --session-id or --resume argument alone, matched whole, against a process list of this rig's
## own -- a ps first on PATH lists the rig's runs only, so no process of the host is ever seen.
## A run of a CLI that is given no session word is the process its record names
## (`run-process: <pid> <start>`), for as long as that same process lives: the rig's ps says
## when its own pids started, too.
## And how an open ask is matched to a session: an ask carries the id of the run that asked, so
## the ask of a run that joined a coworking session is an ask of that session, found through
## that run's own row.
## Holds the three columns appended after workspace as well -- started-at, resolved-at and
## session-comment, each as the record holds it, `-` where it has none -- and that the render,
## and a reader of the render, still count thirteen columns.
## And the two appended after those -- session-state and session-state-at, the state the control
## thread of a row's session keeps in the session's own folder, `-` in both where the session has
## none or the file cannot be read -- which the registry file holds after a rebuild, and which
## only a caller that asks for sixteen columns gets: one that asks for fourteen still gets fourteen.
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
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mktemp -d -t AgentsRegistryRowsDiffCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwx "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
## THE RIG'S OWN PROCESS LIST. A spawn is found running by a process list read from the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own, and another copy of this check for its own holder. So
## the ps first on PATH answers the whole-host listing from the rig's own list, beside it, one
## `<pid> <command line>` line a process, and hands every other call to the real ps. When one
## process started (-o lstart= -p <pid>) is answered from the rig's own table for a pid it
## holds, `<pid> <start as ps prints it>` a line, and by the real ps for any other.
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
: > "$rigTmp/ps.started"
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
	*" lstart= "*)
		rigPsPid=""
		for rigPsWord in "$@" ; do
			case "$rigPsWord" in ''|*[!0123456789]*) ;; *) rigPsPid="$rigPsWord" ;; esac
		done
		rigPsLine="$( grep "^$rigPsPid " "${0%/*}/../ps.started" 2> /dev/null )"
		[ -z "$rigPsLine" ] || { printf '%s\n' "${rigPsLine#* }" ; exit 0 ; }
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

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
## The state of a session, kept in the session's own folder: of one session of this store, of one
## whose id holds a backslash, and one file that names no state.
rigSt="$rigWs/.local/agents/sessions"
mkdir -p "$rigSt/s1/control" "$rigSt/bs\\x/control" "$rigSt/s2/control"
printf 'state: running\nstate-at: 2026-10-13 10:21 +0300\nreason: a run of the session is alive on this host\n' > "$rigSt/s1/control/state"
printf 'state: finished\nstate-at: 2026-10-13 11:00 +0300\nreason: every record of it is closed\n' > "$rigSt/bs\\x/control/state"
printf 'state: No State\nstate-at: 2026-10-13 11:00 +0300\n' > "$rigSt/s2/control/state"

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
rigAssert "the unreadable record is a row of dashes" "$( grep -c '^s-unread - - - - - - - - - - - - - - -$' "$rigNewRows" )" 1
rigAssert "the crafted store reaches the state of a session: the two last columns of its row hold it, also for an id with a backslash, and a file that names no state gives - in both" \
	"$( LC_ALL=C awk '$2 == "s1" { print $15, $16 }' "$rigNewRows" ) / $( LC_ALL=C awk '$2 == "bs\\x" { print $15, $16 }' "$rigNewRows" ) / $( LC_ALL=C awk '$2 == "s2" { print $15, $16 }' "$rigNewRows" )" "running 2026-10-13_10:21_+0300 / finished 2026-10-13_11:00_+0300 / - -"

rigRenderCompare "crafted stores" "$rigWs" "$rigData" s4

## --- crafted state-derivation store: every live and state path, and every way an
## open ask's session id can match one ---
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigRWs="$rigTmp/render/ws"
rigRData="$rigTmp/render/data"
rigRSp="$rigRWs/.local/agents/spawned"
mkdir -p "$rigRSp" "$rigRWs/.local/agents/pending" "$rigRData/board/running" "$rigRData/board/blocked"
rigRunSpawn="rig-spawn-running-$$"
## THE RUNS OF THIS STORE, as the command lines of the rig's process list. A run is its own
## --session-id word, or its own --resume word; nothing else on a line is one.
rigFounder="rig-founder-$$" ; rigResumed="rig-resumed-$$" ; rigForked="rig-forked-$$" ; rigForkedFrom="rig-forked-from-$$" ; rigQuoted="rig-quoted-$$"
{
	## a participant: its own id, with the session folder of the founding spawn in its paths and in its
	## brief, and another run quoted there by the very words a launcher uses
	printf '900001 claude --verbose --output-format stream-json --add-dir /rig/.local/agents/spawned/%s/input --session-id %s --agent rig-member Readable /rig/.local/agents/spawned/%s/input, and mind --session-id %s and %s too\n' "$rigFounder" "$rigRunSpawn" "$rigFounder" "$rigQuoted" "$rigFounder"
	## a run resumed under its own id
	printf '900002 claude --verbose --resume %s --agent rig-member go on\n' "$rigResumed"
	## a run resumed from another session and forked under its own id
	printf '900003 claude --resume %s --fork-session --session-id %s the brief\n' "$rigForkedFrom" "$rigForked"
	## the spawn proxy of a member that joined the founding spawn's session: an operation of the tooling, no run
	printf '900004 bash /rig/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --session-id %s\n' "$rigFounder"
	## ids that hold a backslash and pattern characters, each as a run's own word
	printf '900005 bash /rig/sh-lib/AgentsRigHarness.sh --session-id %s\n' "rig\\bs-$$"
	printf '900006 bash /rig/sh-lib/AgentsRigHarness.sh --resume %s\n' "rig.star*-$$"
	## a CLI that is given no session word, alive; and another process under a pid a run once had
	printf '9000001 grok --rules /rig/rules the brief of a run with no session word on its line\n'
	printf '9000003 sleep 600\n'
} > "$rigTmp/ps.list"
## When the rig's own pids started: the first as its record says, the reused one at another time.
printf '9000001 Mon Oct 12 07:00:00 2026\n9000003 Mon Oct 12 09:30:00 2026\n' > "$rigTmp/ps.started"
rigRec(){ ## sandbox, record, session-id, spawn-id, host, status
	mkdir -p "$rigRSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nstatus: %s\nowner: o\n---\n' "$3" "$4" "$5" "$6" > "$rigRSp/$1/$2.md"
}
rigAsk(){ ## file, session-id, status
	printf -- '---\nsession-id: %s\nstatus: %s\nowner: o\n---\n' "$2" "$3" > "$rigRWs/.local/agents/pending/$1.md"
}
## A spawn id that must have no process is this rig's own, as the live ones are.
rigNo="rig-none-$$"
rigRec r-finished-1 a s-fin "$rigNo-fin" "$rigHost" spawn-succeeded
rigRec r-finished-2 a s-fin2 "$rigNo-fin2" elsewhere spawn-failed
rigRec r-finished-3 a s-open "$rigNo-fin3" "$rigHost" spawn-ended-without-close
rigRec r-foreign a s-open "$rigNo-foreign" elsewhere started
rigRec r-running a s-run "$rigRunSpawn" "$rigHost" started
rigRec r-run-prefix a s-x "rig-spawn-running" "$rigHost" started
rigRec r-run-backslash a s-x "rig\\bs-$$" "$rigHost" started
rigRec r-run-meta a s-x "rig.star*-$$" "$rigHost" started
rigRec r-run-meta-miss a s-x "rig.sta?-$$" "$rigHost" started
rigRec r-founder a "$rigFounder" "$rigFounder" "$rigHost" started
rigRec r-resumed a s-x "$rigResumed" "$rigHost" started
rigRec r-forked a s-x "$rigForked" "$rigHost" started
rigRec r-forked-from a s-x "$rigForkedFrom" "$rigHost" started
rigRec r-quoted a s-x "$rigQuoted" "$rigHost" started
rigRecRun(){ ## sandbox, spawn-id, status, pid -- a record, named for its spawn as the launcher names it, that keeps the process its launch started, begun at 07:00:00
	mkdir -p "$rigRSp/$1"
	printf -- '---\nsession-id: s-x\nspawn-id: %s\nhost: %s\nstatus: %s\nowner: o\nrun-process: %s Mon_Oct_12_07:00:00_2026\n---\n' "$2" "$rigHost" "$3" "$4" > "$rigRSp/$1/$2.md"
}
rigRecRun r-noword-live "$rigNo-noword-live" started 9000001
rigRecRun r-noword-dead "$rigNo-noword-dead" started 9000002
rigRecRun r-noword-reused "$rigNo-noword-reused" started 9000003
rigRecRun r-noword-closed "$rigNo-noword-closed" spawn-succeeded 9000001
rigRec r-nospawn a s-open - "$rigHost" started
rigRec r-nohost a s-open "$rigNo-nohost" - started
rigRec r-open-ask a s-open "$rigNo-open" "$rigHost" started
rigRec r-open-ask b s-open "$rigNo-open-b" "$rigHost" started
rigRec r-closed-ask a s-closed "$rigNo-closed" "$rigHost" started
rigRec r-board a s-board "$rigNo-board" "$rigHost" started
rigRec r-board-cleared a s-board-cleared "$rigNo-board-cleared" "$rigHost" started
rigRec r-numeric a 100 "$rigNo-num" "$rigHost" started
rigRec r-hex a 16 "$rigNo-hex" "$rigHost" started
rigRec r-numeric-miss a 101 "$rigNo-num-miss" "$rigHost" started
rigRec r-backslash a 'bs\x' "$rigNo-bs" "$rigHost" started
rigRec r-backslash-n a 'bs\n' "$rigNo-bsn" "$rigHost" started
rigRec r-dash a - "$rigNo-dash" "$rigHost" started
rigRec r-nosession a "" "$rigNo-nosession" "$rigHost" started
rigRec "r space tracking" a s-open "$rigNo-space" "$rigHost" started
rigRec r-prefix a s-ope "$rigNo-prefix" "$rigHost" started
## A coworking session, every run of it gone and unclosed: its founder, whose spawn id is the
## session's id, a member that joined and asked, and one that joined and did not. The ask
## carries the id of the run that asked, which is no session's id. And another session, of
## which nobody asked; and a row with no spawn id, which an ask with no session id is not of.
rigRec r-cow-founder a "s-cow-$$" "s-cow-$$" "$rigHost" started
rigRec r-cow-joined a "s-cow-$$" "$rigNo-cow-joined" "$rigHost" started
rigRec r-cow-mate a "s-cow-$$" "$rigNo-cow-mate" "$rigHost" started
rigRec r-cow-other a "s-cow-other-$$" "$rigNo-cow-other" "$rigHost" started
rigRec r-nospawn-quiet a s-quiet - "$rigHost" started
mkdir -p "$rigRSp/r-empty"
rigAsk ask-open s-open reply-pending
rigAsk ask-closed s-closed received
rigAsk ask-numeric 1e2 reply-pending
rigAsk ask-hex 0x10 reply-pending
rigAsk ask-backslash 'bs\x' reply-pending
rigAsk ask-backslash-n 'bs\n' reply-pending
rigAsk ask-dash - reply-pending
rigAsk ask-cow-joined "$rigNo-cow-joined" reply-pending
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
rigAssert "a live run is running by its own --session-id word, whatever else is on its line" "$( rigLiveOf r-running )" running
rigAssert "and by its own --resume word" "$( rigLiveOf r-resumed ):$( rigStateOf r-resumed )" "running:running"
rigAssert "a run resumed from another session and forked is running under its own id, and the session it forks from is not" "$( rigLiveOf r-forked ):$( rigLiveOf r-forked-from )" "running:no-process"
rigAssert "a founding spawn whose process is gone is not running, though another participant's command line holds its session folder path, and a joiner's spawn proxy names its session" \
	"$( rigLiveOf r-founder ):$( rigStateOf r-founder ):$( LC_ALL=C grep -c -F -- "spawned/$rigFounder/input" "$rigTmp/ps.list" ):$( LC_ALL=C grep -c -F -- "--intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --session-id $rigFounder" "$rigTmp/ps.list" )" "no-process:unclosed:1:1"
rigAssert "an id quoted in another run's brief, even after the words --session-id, is no run" "$( rigLiveOf r-quoted )" no-process
rigAssert "the value is matched whole: a spawn id that is only the start of a longer one is no run" "$( rigLiveOf r-run-prefix )" no-process
rigAssert "a live run of a CLI that is given no session word is running, by the process its record names" "$( rigLiveOf r-noword-live ):$( rigStateOf r-noword-live )" "running:running"
rigAssert "one whose recorded process is gone is not running" "$( rigLiveOf r-noword-dead ):$( rigStateOf r-noword-dead )" "no-process:unclosed"
rigAssert "a pid taken again by another process, started at another time, is not taken for the run" "$( rigLiveOf r-noword-reused ):$( LC_ALL=C grep -c '^9000003 ' "$rigTmp/ps.list" )" "no-process:1"
rigAssert "a closed record is finished, whatever process it names" "$( rigStateOf r-noword-closed )" finished
rigAssert "a spawn id with a backslash is matched literally" "$( rigLiveOf r-run-backslash )" running
rigAssert "a spawn id with pattern characters is matched literally" "$( rigLiveOf r-run-meta )" running
rigAssert "a ? in a spawn id matches only itself" "$( rigLiveOf r-run-meta-miss )" no-process
rigAssert "an open ask makes waiting" "$( rigStateOf r-open-ask )" waiting
rigAssert "a received ask is unclosed" "$( rigStateOf r-closed-ask )" unclosed
rigAssert "a blocked board item makes waiting" "$( rigStateOf r-board )" waiting
rigAssert "awk's numeric == holds: 100 against an ask for 1e2" "$( rigStateOf r-numeric )" waiting
rigAssert "a backslash id goes through the function itself" "$( rigStateOf r-backslash )" "$( ( MMDAPP="$rigRWs" ; . "$rigHere/AgentsTools.Registries.include" ; AgentsToolsRegistryDeriveState started no-process 'bs\x' ) )"
rigAssert "a prefix of an open id is not open" "$( rigStateOf r-prefix )" unclosed
rigAssert "the ask of a run that joined a session is an ask of that session: the run that asked is waiting" "$( rigStateOf r-cow-joined )" waiting
rigAssert "and so are that session's other unclosed runs, as they are by its founder's ask" "$( rigStateOf r-cow-founder ):$( rigStateOf r-cow-mate )" "waiting:waiting"
rigAssert "a session of which nobody asked is not" "$( rigStateOf r-cow-other )" unclosed
rigAssert "a row with no spawn id is not matched by an ask with no session id" "$( rigStateOf r-nospawn-quiet ):$( LC_ALL=C awk '$3 == "-" && $5 == "reply-pending" { openDash++ ; } END { print openDash + 0 ; }' "$rigRWs/.local/agents/pending-replies.registry" )" "unclosed:1"
rigAssert "asked of one session alone, the function answers the same" "$( ( MMDAPP="$rigRWs" ; . "$rigHere/AgentsTools.Registries.include" ; AgentsToolsRegistryPendingSessionOpen "s-cow-$$" && printf open || printf none ; AgentsToolsRegistryPendingSessionOpen "s-cow-other-$$" && printf :open || printf :none ; AgentsToolsRegistryPendingSessionOpen s-quiet && printf :open || printf :none ) )" "open:none:none"
: > "$rigTmp/ps.list" ; : > "$rigTmp/ps.started"

## --- the dates of a run and the name of its session: three columns appended after workspace ---
rigDWs="$rigTmp/dated/ws"
rigDSp="$rigDWs/.local/agents/spawned"
rigDLive="rig-dated-live-$$"
mkdir -p "$rigDSp/d-closed" "$rigDSp/d-empty" "$rigDSp/d-live" "$rigDSp/d-named" "$rigDWs/.local/agents/pending"
printf -- '---\nsession-id: sd-closed\nspawn-id: pd-closed\nhost: elsewhere\nowner: o\nstatus: spawn-succeeded\nworkspace: wsd\nstarted-at: 2026-10-12 16:57 +0300\nresolved-at: 2026-10-12 17:40 +0300\n---\n' > "$rigDSp/d-closed/pd-closed.md"
printf -- '---\nsession-id: sd-live\nspawn-id: %s\nhost: %s\nowner: o\nstatus: spawn-started\nworkspace: wsd\nstarted-at: 2026-10-13 09:05 +0300\n---\n' "$rigDLive" "$rigHost" > "$rigDSp/d-live/$rigDLive.md"
printf -- '---\nsession-id: sd-named\nspawn-id: pd-named\nhost: elsewhere\nowner: o\nstatus: spawn-failed\nworkspace: wsd\nsession-comment: daily of Monday\n---\n' > "$rigDSp/d-named/pd-named.md"
rigRun AgentsToolsRegistrySpawnedSessionsRows "$rigDWs" "" "$rigTmp/dated.rows" > /dev/null
rigDatedRow(){ ## tracking name -- its row of the rows function, whole
	LC_ALL=C awk -v wantTracking="$1" '$1 == wantTracking { print ; exit ; }' "$rigTmp/dated.rows"
}
rigAssert "a row of a closed run carries both dates after workspace, each with _ where the record has a space" "$( rigDatedRow d-closed )" "d-closed sd-closed - elsewhere o spawn-succeeded - pd-closed - - wsd 2026-10-12_16:57_+0300 2026-10-12_17:40_+0300 - - -"
rigAssert "a row of a running run carries its start date, and - for the closing date" "$( rigDatedRow d-live )" "d-live sd-live - $rigHost o spawn-started - $rigDLive - - wsd 2026-10-13_09:05_+0300 - - - -"
rigAssert "the row of an empty sandbox reads no-session-record, with - in each of the three new columns" "$( rigDatedRow d-empty )" "d-empty - - - - no-session-record - - - - - - - - - -"
rigAssert "a row carries the comment of its session in the last column, and a record with none gives -" "$( rigDatedRow d-named | LC_ALL=C awk '{ print $12, $13, $14 }' ) / $( rigDatedRow d-live | LC_ALL=C awk '{ print $14 }' )" "- - daily_of_Monday / -"
## The render rebuilds the registry file, with its new columns, and prints thirteen as before; a
## reader that counts thirteen still finds its rows. The live run is in the rig's own process list.
printf '900011 claude --verbose --session-id %s --agent rig-member the brief\n' "$rigDLive" > "$rigTmp/ps.list"
rigRender AgentsToolsRegistryRenderSpawnedSessions "$rigDWs" "" "$rigTmp/dated.render" agents "" "" > /dev/null
rigDatedWhole(){ ## -- the rows of the registry file as it lies, and how many of them have sixteen columns
	LC_ALL=C awk 'NF == 16 { whole++ } END { print NR ":" whole + 0 }' "$rigDWs/.local/agents/spawned-sessions.registry" 2> /dev/null
}
rigAssert "the registry file the render rebuilt has its new columns: sixteen in each of its four rows" "$( rigDatedWhole )" "4:4"
rigAssert "the render still prints thirteen columns for each of them, live and state last" "$( LC_ALL=C awk '$1 ~ /^d-/ { rows++ ; if ( NF == 13 ) thirteen++ ; } END { print rows + 0 ":" thirteen + 0 }' "$rigTmp/dated.render" ) $( LC_ALL=C awk '$1 == "d-closed" || $1 == "d-live" { printf "%s %s %s ", $11, $12, $13 }' "$rigTmp/dated.render" )" "4:4 wsd other-host finished wsd running running "
rigAssert "a reader that counts thirteen columns still finds its rows: over that file, the collect of ended asks names the session of the live run as running" \
	"$( ( MMDAPP="$rigDWs" ; unset MDAT_DATA_ROOT ; . "$rigHere/AgentsTools.PendingReplyCollect.include" ; AgentsToolsPendingReplySessionsRunning ) 2> /dev/null | LC_ALL=C tr -d ' ' ) $( rigDatedWhole )" "sd-live 4:4"
: > "$rigTmp/ps.list"

## --- the state of a session: two columns appended after session-comment ---
rigSWs="$rigTmp/stated/ws"
rigSSp="$rigSWs/.local/agents/spawned"
rigSSt="$rigSWs/.local/agents/sessions"
rigSReg="$rigSWs/.local/agents/spawned-sessions.registry"
rigSLive="rig-stated-live-$$"
mkdir -p "$rigSSp/t-empty" "$rigSWs/.local/agents/pending"
rigStatedRec(){ ## sandbox, record name, session id, spawn id, host, status
	mkdir -p "$rigSSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: o\nstatus: %s\nworkspace: wss\nstarted-at: 2026-10-13 10:00 +0300\nsession-comment: stated one\n---\n' "$3" "$4" "$5" "$6" > "$rigSSp/$1/$2.md"
}
rigStatedFile(){ ## session id, the text of its state file
	mkdir -p "$rigSSt/$1/control" && printf '%s' "$2" > "$rigSSt/$1/control/state"
}
rigStatedRow(){ ## tracking name -- its row of the rows function, whole
	LC_ALL=C awk -v wantTracking="$1" '$1 == wantTracking { print ; exit ; }' "$rigTmp/stated.rows"
}
rigStatedRebuild(){ ## -- the rebuild of the registry file of this store; prints its rc and how many lines it said on stderr
	( MMDAPP="$rigSWs" ; unset MDAT_DATA_ROOT ; . "$rigHere/AgentsTools.Registries.include" ; AgentsToolsRegistrySpawnedSessionsRebuild ) > /dev/null 2> "$rigTmp/stated.rebuild.err"
	printf '%s:%s\n' "$?" "$( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/stated.rebuild.err" )"
}
rigStatedOf(){ ## session id -- the two last columns of each of its rows in the registry file as it lies, a row a word pair
	LC_ALL=C awk -v wantSession="$1" '$2 == wantSession { printf "%s%s %s", ( said++ ? " | " : "" ), $15, $16 }' "$rigSReg" 2> /dev/null
}
## A session of two runs with a state, one that never had a control thread, one whose thread
## wrote a word this code does not know, and four whose file gives no state: a word that is none,
## no word at all, a file that cannot be read, and a folder where the file would be.
rigStatedRec t-founder "$rigSLive" st-run "$rigSLive" "$rigHost" spawn-started
rigStatedRec t-member pt-member st-run pt-member "$rigHost" spawn-succeeded
rigStatedRec t-none pt-none st-none pt-none elsewhere spawn-succeeded
rigStatedRec t-word pt-word st-word pt-word elsewhere spawn-started
rigStatedRec t-bad pt-bad st-bad pt-bad elsewhere spawn-succeeded
rigStatedRec t-blank pt-blank st-blank pt-blank elsewhere spawn-succeeded
rigStatedRec t-unread pt-unread st-unread pt-unread elsewhere spawn-succeeded
rigStatedRec t-folder pt-folder st-folder pt-folder elsewhere spawn-succeeded
rigStatedFile st-run "$( printf 'state: running\nstate-at: 2026-10-13 10:21 +0300\nreason: a run of the session is alive on this host' )"$'\n'
rigStatedFile st-word "$( printf 'state: member-dead\nstate-at: 2026-10-13 10:30 +0300\nreason: a word a later task writes' )"$'\n'
rigStatedFile st-bad "$( printf 'state: Not A State\nstate-at: 2026-10-13 10:40 +0300\nreason: none' )"$'\n'
rigStatedFile st-blank "$( printf 'state-at: 2026-10-13 10:50 +0300\nreason: a file with no word' )"$'\n'
rigStatedFile st-unread "$( printf 'state: running\nstate-at: 2026-10-13 10:55 +0300\nreason: not to be read' )"$'\n'
chmod 000 "$rigSSt/st-unread/control/state"
mkdir -p "$rigSSt/st-folder/control/state"
rigRun AgentsToolsRegistrySpawnedSessionsRows "$rigSWs" "" "$rigTmp/stated.rows" > /dev/null
rigAssert "a row carries the state of its session in the two last columns, the date with _ where the file has a space" "$( rigStatedRow t-founder )" "t-founder st-run - $rigHost o spawn-started - $rigSLive - - wss 2026-10-13_10:00_+0300 - stated_one running 2026-10-13_10:21_+0300"
rigAssert "every row of that session carries the same two: the row of its other run too" "$( rigStatedRow t-member | LC_ALL=C awk '{ print NF, $15, $16 }' )" "16 running 2026-10-13_10:21_+0300"
rigAssert "a session that never had a control thread has - in both columns, and so has the row of an empty sandbox" "$( rigStatedRow t-none | LC_ALL=C awk '{ print NF, $15, $16 }' ) / $( rigStatedRow t-empty )" "16 - - / t-empty - - - - no-session-record - - - - - - - - - -"
rigAssert "the word is taken as the file holds it, whatever state it names: one a later task writes is stored as it stands" "$( rigStatedRow t-word | LC_ALL=C awk '{ print NF, $15, $16 }' )" "16 member-dead 2026-10-13_10:30_+0300"
rigAssert "a state file that cannot be read gives - in both: a word that is no state, no word at all, a file that cannot be opened, a folder in its place" \
	"$( for rigStatedBad in t-bad t-blank t-unread t-folder ; do rigStatedRow "$rigStatedBad" | LC_ALL=C awk '{ printf "%s:%s:%s ", NF, $15, $16 }' ; done )" "16:-:- 16:-:- 16:-:- 16:-:- "
rigAssert "and the rows function said nothing of them on standard error" "$( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/stated.rows.err" )" "0"
rigAssert "the rebuild does not fail over them: it ends 0 and says nothing, and the file has sixteen columns in each of its nine rows" "$( rigStatedRebuild ) $( LC_ALL=C awk 'NF == 16 { whole++ } END { print NR ":" whole + 0 }' "$rigSReg" 2> /dev/null )" "0:0 9:9"
## The registry stores the state at its rebuild: a state that moves is in the file after the next one.
rigAssert "control: the registry file holds the state its rebuild read, in each row of the session" "$( rigStatedOf st-run )" "running 2026-10-13_10:21_+0300 | running 2026-10-13_10:21_+0300"
rigStatedFile st-run "$( printf 'state: finished\nstate-at: 2026-10-13 10:58 +0300\nreason: no run of the session is alive and every record of it is closed' )"$'\n'
rigAssert "the state file moves to finished, and the registry file as it lies still holds running" "$( LC_ALL=C sed -n 's/^state: //p' "$rigSSt/st-run/control/state" ) / $( rigStatedOf st-run )" "finished / running 2026-10-13_10:21_+0300 | running 2026-10-13_10:21_+0300"
rigAssert "after the next rebuild it holds finished, with the new date" "$( rigStatedRebuild ) $( rigStatedOf st-run )" "0:0 finished 2026-10-13_10:58_+0300 | finished 2026-10-13_10:58_+0300"
## Only a caller that asks for the wider row gets it: the awk of the rows, asked as a reader that
## loaded its code before these columns asks it, over the same records and the same state file.
rigStatedAwk(){ ## the count of columns asked for ("" for none) -- how many columns each row of the two records and the empty sandbox has, and the last column of the first
	printf 'T%s\nDt-founder\nS%s\nDt-member\nS%s\nDt-empty\nE\n' "$rigSSt/st-run/control/state" "$rigSSp/t-founder/$rigSLive.md" "$rigSSp/t-member/pt-member.md" \
		| LC_ALL=C awk -v registryRows=spawned ${1:+-v registryColumns="$1"} -f "$rigHere/AgentsRegistryHeaderRows.awk" \
		| LC_ALL=C awk '{ printf "%s ", NF } NR == 1 { last = $NF } END { print last }'
}
rigAssert "a caller that asks for fourteen columns still gets fourteen, and no state: the comment of the session is its last column" "$( rigStatedAwk 14 )" "14 14 14 stated_one"
rigAssert "a caller that names no count still gets its eleven" "$( rigStatedAwk "" )" "11 11 11 wss"
rigAssert "and one that asks for sixteen gets the state last" "$( rigStatedAwk 16 )" "16 16 16 2026-10-13_10:58_+0300"
## The measured rows: the render's thirteen, the sixteen words of a caller that names no count,
## and eighteen, the state last, for the one that names sixteen.
printf '900021 claude --verbose --session-id %s --agent rig-member the brief\n' "$rigSLive" > "$rigTmp/ps.list"
rigStatedMeasured(){ ## the stored columns the caller counts ("" for none) -- the words of each measured row of the session, and the two last of the first
	( MMDAPP="$rigSWs" ; unset MDAT_DATA_ROOT ; . "$rigHere/AgentsTools.Registries.include" ; measuredRows="" ; measuredDated="" ; measuredAny=""
		AgentsToolsRegistryMeasureRows "$rigSReg" "$rigHost" st-run ${1:+"$1"} ; printf '%s' "$measuredDated" ) 2> /dev/null \
		| LC_ALL=C awk '{ printf "%s ", NF } NR == 1 { last = $( NF - 1 ) " " $NF } END { print last }'
}
rigAssert "a reader of the measured rows that names no count still gets sixteen words a row, the comment last" "$( rigStatedMeasured "" )" "16 16 - stated_one"
rigAssert "and one that names sixteen stored columns gets eighteen, the stored state and its date last" "$( rigStatedMeasured 16 )" "18 18 finished 2026-10-13_10:58_+0300"
rigRender AgentsToolsRegistryRenderSpawnedSessions "$rigSWs" "" "$rigTmp/stated.render" agents "" "" > /dev/null
rigAssert "the render prints thirteen columns with the state stored, live and state last, as before" \
	"$( LC_ALL=C awk '$1 ~ /^t-/ { rows++ ; if ( NF == 13 ) thirteen++ ; } END { print rows + 0 ":" thirteen + 0 }' "$rigTmp/stated.render" ) $( LC_ALL=C awk '$1 == "t-founder" || $1 == "t-member" { printf "%s %s %s ", $11, $12, $13 }' "$rigTmp/stated.render" )$( LC_ALL=C awk 'NF == 16 { whole++ } END { print NR ":" whole + 0 }' "$rigSReg" 2> /dev/null )" "9:9 wss running running wss no-process finished 9:9"
rigAssert "a reader that counts thirteen columns finds its rows with the state stored: over that file, the collect of ended asks names the session of the live run as running" \
	"$( ( MMDAPP="$rigSWs" ; unset MDAT_DATA_ROOT ; . "$rigHere/AgentsTools.PendingReplyCollect.include" ; AgentsToolsPendingReplySessionsRunning ) 2> /dev/null | LC_ALL=C tr -s ' ' '\n' | LC_ALL=C grep -c -x -F -- 'st-run' ) $( rigStatedOf st-run )" "1 finished 2026-10-13_10:58_+0300 | finished 2026-10-13_10:58_+0300"
: > "$rigTmp/ps.list"

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
	## The copy keeps the live hosts, and this host's rows are measured against the rig's
	## own process list, empty by now: none of them is running, on either side.
	rigRenderCompare "live copy of $rigLiveFrom" "$rigLiveWs" "$rigLiveData" "$( LC_ALL=C awk 'NF >= 2 && $2 != "-" { print $2 ; exit ; }' "$rigTmp/out.SpawnedSessions.new" 2>/dev/null )"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REGISTRY ROWS DIFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REGISTRY_ROWS_DIFF: OK (%d assertions, offline)\n' "$rigPassCount"
