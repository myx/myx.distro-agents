#!/usr/bin/env bash
## Behavioural check on --manager-session-restart --session-id <id> [--run] (S7.19, the restart, by the human-owner's ruling: a start
## again of what has stopped or finished, never of what runs; AgentsTools.ManagerSession.include), run rather than read, against a rig
## workspace built here with its own spawn records, its own board and a sleeper of its own as the one live run (its record names
## it as its launch, `run-process`, which is how a run is known to live). Held:
##   1. A run that still lives is not touched: one `restart` row, `live`, and no restart is tried.
##   2. A finished run no board item names cannot be started again: `no-item`.
##   3. A finished run with a board item reaches the one restart path (AgentsReviewRestart): its row names the item and, on this rig
##      with no member to start, says `failed` with the restart's own RETURN line.
##   4. A session's id takes its founding run; --run takes the id as one run's own; an id no record names gives one `none` row; an id
##      that is no bare name is refused.
##   5. The syntax is refused with its line where --session-id is missing or has no value.
## Red before the restart was built: every call fails on `invalid option`.
## Offline: no process of this host is touched, and no message is posted (a fake curl first on PATH would log a request: none is made).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionRestartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigSp" "$rigWs/.local/agents/sessions" "$rigWs/.local/.agents" "$rigHome" "$rigData/board/running" "$rigSkills/magic-coordinator" "$rigTmp/bin" || exit 1
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
## A fake curl first on PATH logs any request made: none may be.
printf '#!/bin/sh\nprintf "%%s\\n" "\$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
## THE LIVE RUN: a run is alive while the process its record names as its launch, `run-process: <pid> <start>`, is still that
## process (AgentsToolsRegistryRecordedRunAlive), as the kill reads it. The rig's stand-in is a sleeper of its own, ended at the end.
rigPids=""
trap '[ -z "$rigPids" ] || rigProcSignal KILL $rigPids ; rm -rf -- "$rigTmp"' EXIT
rigAlive(){ ## -- starts the sleeper; its pid in rigAlivePid, its start as the tooling writes it in rigAliveStart
	python3 -I -B -c 'import time; time.sleep(180)' > /dev/null 2>&1 &
	rigAlivePid=$! ; rigProcNote "$rigAlivePid" ; rigPids="$rigPids $rigAlivePid" ; disown "$rigAlivePid" 2> /dev/null || :
	sleep 1
	rigAliveStart="$( LC_ALL=C ps -o lstart= -p "$rigAlivePid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	[ -n "$rigAliveStart" ] || rigRefuse "the stand-in process of the live run gives no start"
}
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRec(){ ## session id, spawn id, member, status, the dispatch item it spawns ("" for none), its launched process `<pid> <start>` ("" for none)
	mkdir -p "$rigSp/$2"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nstatus: %s\nhost: %s\nworkspace: rigws\nstart-context: spawned\nstarted-at: 2026-11-08 05:00 +0000\n' "$1" "$2" "$3" "$4" "$rigHost"
		[ -z "$5" ] || printf 'spawns: %s\n' "$5"
		[ -z "${6:-}" ] || printf 'run-process: %s\n' "$6"
		printf -- '---\n\n# Spawn session: %s\n' "$2"
	} > "$rigSp/$2/$2.spawn.md"
}
rigItem(){ ## item name, member, spawn id, session id -- a running dispatch item of the rig's board
	printf -- '---\ntype: dispatch\nowner: %s\nstatus: running\nspawn-id: %s\nsession-id: %s\n---\n\n# Dispatch: %s\n\nThe rig brief.\n' "$2" "$3" "$4" "$1" > "$rigData/board/running/$1.md"
}
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigAlive
rigRec sess-one sess-one magic-coordinator spawn-started "" "$rigAlivePid $rigAliveStart"
rigRec sess-one run-a keeper-rig spawn-succeeded dispatch-rig-run-a ""
rigRec sess-one run-z magic-tester spawn-succeeded "" ""
rigRec sess-two sess-two magic-coordinator spawn-succeeded dispatch-rig-sess-two ""
rigItem dispatch-rig-run-a keeper-rig run-a sess-one
rigItem dispatch-rig-sess-two magic-coordinator sess-two sess-two
rigRc=0
rigRun(){ ## tool arguments... -- rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRows(){ ## kind -- those rows of the last stdout, TAB as a space
	LC_ALL=C awk -F'\t' -v kind="$1" '$1 == kind { gsub( /\t/, " " ) ; print }' "$rigTmp/out"
}
rigHead(){ ## kind, how many fields -- the first fields of those rows, TAB as a space
	LC_ALL=C awk -F'\t' -v kind="$1" -v count="$2" '$1 == kind { line = $1 ; for ( at = 2 ; at <= count ; at++ ) line = line " " $at ; print line }' "$rigTmp/out"
}
rigCurls(){ [ -f "$rigTmp/curl.calls" ] && LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/curl.calls" || printf 0 ; }

echo "-- 1. a run that still lives is not touched --"
rigRun --manager-session-restart --session-id sess-one
rigAssert "rc 0, one restart row, live, saying what comes first" "$rigRc [$( rigRows restart | LC_ALL=C tr '\n' '|' )]" "0 [restart sess-one sess-one magic-coordinator live the run still lives: stop or kill it first|]"
rigAssert "nothing was tried: no record was written to, no process signalled, no request made" "$( LC_ALL=C grep -c -e '^killed-' -e '^restart' "$rigSp/sess-one/sess-one.spawn.md" ) $( rigCurls )" "0 0"

echo "-- 2. a finished run no board item names --"
rigRun --manager-session-restart --session-id run-z --run
rigAssert "one restart row, no-item" "$rigRc [$( rigRows restart | LC_ALL=C tr '\n' '|' )]" "0 [restart sess-one run-z magic-tester no-item no board item names this run, so nothing can start it again|]"

echo "-- 3. a finished run with a board item reaches the restart path --"
rigRun --manager-session-restart --session-id run-a --run
rigAssert "rc 0, one restart row of that run, failed on this rig, the detail naming the item and the restart's own RETURN line" \
	"$rigRc [$( rigHead restart 5 )] $( rigRows restart | LC_ALL=C awk '{ print ( $6 == "dispatch-rig-run-a:" ) ? "item" : "no-item:" $6 }' ) $( rigRows restart | LC_ALL=C grep -c -F 'not restarted' )" "0 [restart sess-one run-a keeper-rig failed] item 1"
rigAssert "no request was made of Slack" "$( rigCurls )" "0"

echo "-- 4. a session's id takes its founding run; an id nobody has, and one that is no name --"
rigRun --manager-session-restart --session-id sess-two
rigAssert "the founding run of the session, finished, is the one started again: its row names it and its item" "$rigRc [$( rigHead restart 5 )] $( rigRows restart | LC_ALL=C awk '{ print ( $6 == "dispatch-rig-sess-two:" ) ? "item" : "no-item:" $6 }' )" "0 [restart sess-two sess-two magic-coordinator failed] item"
rigRun --manager-session-restart --session-id sess-none
rigAssert "one none row, rc 0" "$rigRc [$( rigRows none | LC_ALL=C cut -d' ' -f1,2 )]" "0 [none sess-none]"
rigRun --manager-session-restart --session-id '../x'
rigAssert "a name with a slash is refused: rc 1, a word on stderr, no row" "$rigRc $( [ -s "$rigTmp/err" ] && printf said || printf silent ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 said 0"

echo "-- 5. the syntax --"
rigRun --manager-session-restart
rigAssert "no --session-id is refused with the syntax" "$rigRc $( LC_ALL=C grep -c -F 'syntax is --session-id <id> [--run]' "$rigTmp/err" )" "1 1"
rigRun --manager-session-restart --session-id
rigAssert "--session-id with no value is refused" "$rigRc $( LC_ALL=C grep -c -F 'needs an id' "$rigTmp/err" )" "1 1"
rigHelpInclude="$rigPackage/sh-lib/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh --manager-session-restart --session-id <id> [--run]"
rigAssert "the help pair holds the form: its echo in the include, its line and its entry in the markdown, once each" \
	"$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t--manager-session-restart --session-id <id> [--run]' )" "$rigHelpMd" )" "1 1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION RESTART CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SESSION_RESTART: OK ($rigPassCount assertions, offline)"
