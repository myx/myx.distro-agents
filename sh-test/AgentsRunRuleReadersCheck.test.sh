#!/usr/bin/env bash
## Behavioural check on the two readers that ask whether a run lives and act on the answer:
## TaskOutput (AgentsUniversalHarness.sh), whose result word says RUNNING or FINISHED, and the
## sweep of spawn sandboxes (AgentsToolsSpawnSandboxSweep, AgentsTools.SpawnSandbox.include),
## which empties input/ and tmp/ of a sandbox no run of which lives. Both tell a run by the
## one rule a run is recognised by (AgentsTools.Registries.include) and by no match of their
## own: its own --session-id or --resume word on its own command line, matched whole; else
## the process its record names as the one its launch started, while that is still the same
## process. A command line that only carries the id is no run of it: a process of the tooling
## that waits on the session, a participant whose line holds the session folder path, a brief
## that quotes it. So an ended founder reads FINISHED while such a process lives, and its
## sandbox is emptied; a live run reads RUNNING and keeps its sandbox, whichever way it is told.
## Offline: a ps first on PATH lists the rig's own runs only, stand-in processes under their
## own pids, never a real CLI; a curl beside it only logs, and nothing may call it; the board,
## the sandboxes and the workspace are this rig's own temp tree, guarded on every call.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigSandboxLib="$rigLib/AgentsTools.SpawnSandbox.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigSandboxLib" ] || rigRefuse "sandbox include not found: $rigSandboxLib"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
rigTmp="$( mktemp -d -t AgentsRunRuleReadersCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignal TERM $rigLivePids ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/running" "$rigWs/.local/.agents" "$rigSpawned" "$rigTmp/bin" "$rigTmp/nops"
## THE RIG'S OWN PROCESS LIST, as AgentsReviewFlowCheck keeps it: the ps first on PATH answers
## the whole-host listing from the rig's own list, beside it, one `<pid> <command line>` line
## a process, each a stand-in under its own pid and listed only while it lives; every other
## call, when a process began and which process started which, is handed to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
## A process list that cannot be read at all, for the one sweep that must then touch nothing.
printf '#!/bin/sh\nexit 1\n' > "$rigTmp/nops/ps"
printf '#!/bin/sh\necho "curl $*" >> "%s/net-calls"\nexit 1\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl" "$rigTmp/nops/ps"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A stand-in process under its own pid; with a command line given it stands in the rig's
## process list under that line, with none it stands in no list. Sets rigStandPid.
rigStandPid=""
rigStand(){ ## command line text (may be empty)
	sleep 300 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigLivePids="$rigLivePids $rigStandPid" ; rigProcNote "$rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	[ -z "${1:-}" ] || printf '%s %s\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
rigStart(){ ## pid -- when that process began, as one word, as a spawn record keeps it
	LC_ALL=C "$rigTmp/bin/ps.real" -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }'
}
rigRecord(){ ## spawn-id, status, sandbox folder (default: the spawn-id), extra frontmatter lines (may be empty)
	local recFolder="${3:-$1}"
	mkdir -p "$rigSpawned/$recFolder/input" "$rigSpawned/$recFolder/output"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-session-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n%s---\n' \
		"$recFolder" "$1" "$recFolder" "$rigHost" "$2" "${4:-}" > "$rigSpawned/$recFolder/$1.md"
}
rigItem(){ ## item stem, spawn-id -- the dispatch item TaskOutput reaches the run by
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\n---\n\n# rig dispatch\n' "$2" > "$rigData/board/running/dispatch-20261013T0000Z-$1.md"
}
rigLog(){ ## spawn-id, text (may be empty) -- the session log TaskOutput reads
	mkdir -p "$rigWs/.local/agents/sessions/$1"
	printf '%s' "${2:-}" > "$rigWs/.local/agents/sessions/$1/session.log"
}
## One served TaskOutput call of the harness, guarded to the rig's own trees and process list.
rigOutput(){ ## result file, item stem
	printf '{"handle":"dispatch-20261013T0000Z-%s.md"}\n' "$2" > "$rigTmp/tool.args"
	env -i HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v ps )" = "$RIG_TMP/bin/ps" ] || exit 98
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool TaskOutput < "$RIG_TMP/tool.args"
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}
rigWord(){ ## result file -- its first line
	LC_ALL=C sed -n '1p' "$1"
}
rigHas(){ ## result file, fixed text -- how many of its lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" || :
}
rigSaidLive='A process still carries this session id, so this log is STILL BEING WRITTEN: what follows is what exists so far, and its end is not the end of the work.'
rigSaidDone='No process carries this session id any more, so this log is complete.'

echo "-- 1. TaskOutput: a command line that only carries a run's id is no run of it --"
## An ended founder, and a process of the tooling that waits on its session: its command line
## holds the session's id, which is the founder's own, as the argument of an operation.
rigRecord rig-founder-$$ spawn-succeeded
rigItem founder rig-founder-$$
rigLog rig-founder-$$ 'rig founder log
'
rigStand "bash $rigFn --intern-op-rig-waits-on-session rig-founder-$$"
rigOutput "$rigTmp/o1" founder
[ "$( cat "$rigTmp/o1.rc" )" = 0 ] && LC_ALL=C grep -q '^OUTPUT-RESULT: ' "$rigTmp/o1" || rigRefuse "the served TaskOutput gave no result, so nothing below would be measured: $( head -2 "$rigTmp/o1" "$rigTmp/o1.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "control: the rig's process list holds a tooling line that carries the founder's id" "$( LC_ALL=C grep -c -F -- "DistroAgentsTools.fn.sh --intern-op-rig-waits-on-session rig-founder-$$" "$rigTmp/ps.list" )" 1
rigAssert "an ended founder reads FINISHED while a process of the tooling waits on its session" "$( rigWord "$rigTmp/o1" )" "OUTPUT-RESULT: FINISHED"
rigAssert "in the words a finished run always had, and with its log" "$( rigHas "$rigTmp/o1" "$rigSaidDone" ):$( rigHas "$rigTmp/o1" "$rigSaidLive" ):$( rigHas "$rigTmp/o1" 'rig founder log' )" "1:0:1"
## An ended founder, and a participant of its session: the participant's line holds the
## session folder path, which carries the founder's id inside another word.
rigRecord rig-founder2-$$ spawn-succeeded
rigItem founder2 rig-founder2-$$
rigLog rig-founder2-$$ 'rig founder2 log
'
rigRecord rig-part-$$ spawn-started rig-founder2-$$
rigItem part rig-part-$$
rigLog rig-part-$$ 'rig participant log
'
rigStand "claude --add-dir $rigSpawned/rig-founder2-$$/input --session-id rig-part-$$ --agent keeper-myx Readable $rigSpawned/rig-founder2-$$/input"
rigOutput "$rigTmp/o2" founder2
rigOutput "$rigTmp/o3" part
rigAssert "an ended founder reads FINISHED while a participant's line holds its id inside a path" "$( rigWord "$rigTmp/o2" )" "OUTPUT-RESULT: FINISHED"
rigAssert "and that participant, alive by its own word, reads RUNNING" "$( rigWord "$rigTmp/o3" ):$( rigHas "$rigTmp/o3" 'rig participant log' )" "OUTPUT-RESULT: RUNNING:1"
## An id quoted in the text of another run's line, after that run's own word.
rigRecord rig-quoted-$$ spawn-started
rigItem quoted rig-quoted-$$
rigLog rig-quoted-$$ 'rig quoted log
'
rigStand "claude --session-id rig-quoter-$$ --agent keeper-myx Continue what was said by --session-id rig-quoted-$$"
rigOutput "$rigTmp/o4" quoted
rigAssert "an id quoted in the text of another run's line is no run: FINISHED" "$( rigWord "$rigTmp/o4" )" "OUTPUT-RESULT: FINISHED"

echo "-- 2. TaskOutput: a live run still reads RUNNING, whichever way it is told --"
rigRecord rig-live-$$ spawn-started
rigItem live rig-live-$$
rigLog rig-live-$$ 'rig live log
'
rigStand "rig-run --session-id rig-live-$$"
rigOutput "$rigTmp/o5" live
rigAssert "a run alive by its own --session-id word reads RUNNING" "$( rigWord "$rigTmp/o5" )" "OUTPUT-RESULT: RUNNING"
rigAssert "in the words a running run always had, and with its log so far" "$( rigHas "$rigTmp/o5" "$rigSaidLive" ):$( rigHas "$rigTmp/o5" "$rigSaidDone" ):$( rigHas "$rigTmp/o5" 'rig live log' )" "1:0:1"
rigRecord rig-resumed-$$ spawn-started
rigItem resumed rig-resumed-$$
rigLog rig-resumed-$$ 'rig resumed log
'
rigStand "rig-run --resume rig-resumed-$$"
rigOutput "$rigTmp/o6" resumed
rigAssert "a run alive by its own --resume word reads RUNNING" "$( rigWord "$rigTmp/o6" )" "OUTPUT-RESULT: RUNNING"
rigRecord rig-quiet-$$ spawn-started
rigItem quiet rig-quiet-$$
rigLog rig-quiet-$$ ''
rigStand "rig-run --session-id rig-quiet-$$"
rigOutput "$rigTmp/o7" quiet
rigAssert "a live run that has written nothing yet reads EMPTY, as before" "$( rigWord "$rigTmp/o7" ):$( rigHas "$rigTmp/o7" 'this session has written NOTHING YET' )" "OUTPUT-RESULT: EMPTY:1"
## A run of a CLI that is given no session word: no line of the list runs as it or holds its
## id, and its record names the process its launch started.
rigStand ""
rigNoWordPid="$rigStandPid"
rigNoWordStart="$( rigStart "$rigNoWordPid" )"
[ -n "$rigNoWordStart" ] || rigRefuse "the stand-in of the run with no session word did not start, so nothing of it would be measured"
rigRecord rig-noword-$$ spawn-started "" "run-process: $rigNoWordPid $rigNoWordStart
"
rigItem noword rig-noword-$$
rigLog rig-noword-$$ 'rig noword log
'
rigOutput "$rigTmp/o8" noword
rigAssert "control: no line of the rig's process list runs as that spawn, or holds its id" "$( LC_ALL=C grep -c -F -- "rig-noword-$$" "$rigTmp/ps.list" )" 0
rigAssert "a run with no session word is told by the process its record names: RUNNING" "$( rigWord "$rigTmp/o8" )" "OUTPUT-RESULT: RUNNING"
rigStand "bash $rigFn --intern-op-rig-waits-on-session rig-noword-$$"
rigNoWordWaiter="$rigStandPid"
rigOutput "$rigTmp/o9" noword
rigAssert "and still RUNNING with a process of the tooling waiting on it" "$( rigWord "$rigTmp/o9" )" "OUTPUT-RESULT: RUNNING"

echo "-- 3. TaskOutput: a run with no session word that is gone reads FINISHED, whatever carries its id --"
rigProcSignal TERM "$rigNoWordPid"
rigLeft=20 ; while kill -0 "$rigNoWordPid" 2> /dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 0.25 ; rigLeft=$(( rigLeft - 1 )) ; done
rigOutput "$rigTmp/o10" noword
rigAssert "its recorded process gone, it reads FINISHED while the tooling's process still carries its id" "$( kill -0 "$rigNoWordWaiter" 2> /dev/null && printf waiting || printf gone ):$( rigWord "$rigTmp/o10" )" "waiting:OUTPUT-RESULT: FINISHED"
## A recorded pid that another process has taken: the same pid, begun at another time.
rigStand ""
rigRecord rig-reused-$$ spawn-started "" "run-process: $rigStandPid Mon_Jan__1_00:00:00_2001
"
rigItem reused rig-reused-$$
rigLog rig-reused-$$ 'rig reused log
'
rigStand "bash $rigFn --intern-op-rig-waits-on-session rig-reused-$$"
rigOutput "$rigTmp/o11" reused
rigAssert "a recorded pid that another process has taken is no run of it: FINISHED" "$( rigWord "$rigTmp/o11" )" "OUTPUT-RESULT: FINISHED"

echo "-- 4. the sweep: only a run that lives by the one rule holds its sandbox --"
rigFill(){ ## sandbox folder, record of it to age (may be empty: the record stays new)
	: > "$rigSpawned/$1/input/brief.md"
	mkdir -p "$rigSpawned/$1/tmp/AgentsUniversalHarness.rig" && printf 'rig\n' > "$rigSpawned/$1/tmp/AgentsUniversalHarness.rig/wait.err"
	[ -z "${2:-}" ] || touch -t 202001010000 "$rigSpawned/$1/$2.md"
}
## The only run of a sandbox has ended, its record older than ten minutes, and a process of
## the tooling whose command line holds that run's id waits on its session.
rigRecord rig-sw-ended-$$ spawn-succeeded
rigFill rig-sw-ended-$$ rig-sw-ended-$$
rigStand "bash $rigFn --intern-op-rig-waits-on-session rig-sw-ended-$$"
## A run alive by its own word.
rigRecord rig-sw-live-$$ spawn-started
rigFill rig-sw-live-$$ rig-sw-live-$$
rigStand "rig-run --session-id rig-sw-live-$$"
## A run with no session word, alive by the process its record names; nothing holds its id.
rigStand ""
rigRecord rig-sw-noword-$$ spawn-started "" "run-process: $rigStandPid $( rigStart "$rigStandPid" )
"
rigFill rig-sw-noword-$$ rig-sw-noword-$$
## A run with no session word that is gone, its recorded pid taken by another process, while
## the line of a run of another sandbox holds this sandbox's path, and so this run's id.
rigStand ""
rigRecord rig-sw-gone-$$ spawn-started "" "run-process: $rigStandPid Mon_Jan__1_00:00:00_2001
"
rigFill rig-sw-gone-$$ rig-sw-gone-$$
rigStand "claude --add-dir $rigSpawned/rig-sw-gone-$$/output --session-id rig-sw-reader-$$ --agent keeper-myx"
## A sandbox two runs share: its founder ended, a participant alive by its own word.
rigRecord rig-sw-shared-$$ spawn-succeeded
rigRecord rig-sw-joined-$$ spawn-started rig-sw-shared-$$
rigFill rig-sw-shared-$$ rig-sw-shared-$$
touch -t 202001010000 "$rigSpawned/rig-sw-shared-$$/rig-sw-joined-$$.md"
rigStand "claude --add-dir $rigSpawned/rig-sw-shared-$$/input --session-id rig-sw-joined-$$ --agent keeper-myx"
## A record under ten minutes old, with nothing running as it: it may still be launching.
rigRecord rig-sw-fresh-$$ spawn-started
rigFill rig-sw-fresh-$$ ""
rigSweep(){ ## result file, the folder whose ps is first on PATH
	env -i PATH="$2:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_LIB="$rigSandboxLib" RIG_PS="$2/ps" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v ps )" = "$RIG_PS" ] || exit 98
			MDSC_CMD=rig ; . "$RIG_LIB" ; AgentsToolsSpawnSandboxSweep rig-sweep
		' > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigInput(){ find "$rigSpawned/$1/input" -mindepth 1 | LC_ALL=C grep -c . || : ; }
rigScratch(){ find "$rigSpawned/$1/tmp" -mindepth 1 2> /dev/null | LC_ALL=C grep -c . || : ; }
rigKept(){ ## sandbox folder -- what is left of its input/ and of its scratch
	printf '%s:%s' "$( rigInput "$1" )" "$( rigScratch "$1" )"
}
rigSweep "$rigTmp/s0" "$rigTmp/nops"
rigAssert "a process list that cannot be read tells nothing: the sweep touches no sandbox, as before" \
	"$( cat "$rigTmp/s0.rc" ):$( rigKept rig-sw-ended-$$ ) $( rigKept rig-sw-gone-$$ ) $( rigKept rig-sw-live-$$ )" "0:1:2 1:2 1:2"
rigSweep "$rigTmp/s1" "$rigTmp/bin"
rigAssert "the sweep ran" "$( cat "$rigTmp/s1.rc" )" 0
rigAssert "the sandbox of an ended run is emptied while a process of the tooling carries its id" "$( rigKept rig-sw-ended-$$ ):$( [ -d "$rigSpawned/rig-sw-ended-$$/input" ] && [ -d "$rigSpawned/rig-sw-ended-$$/tmp" ] && printf folders-kept )" "0:0:folders-kept"
rigAssert "and said, in the words the sweep always had" \
	"$( rigHas "$rigTmp/s1" "# rig: rig-sweep: emptied input/ of rig-sw-ended-$$, whose session is no longer running" ):$( rigHas "$rigTmp/s1" "# rig: rig-sweep: cleared the scratch left in tmp/ of rig-sw-ended-$$, whose session is no longer running" )" "1:1"
rigAssert "the sandbox of a run alive by its own word is left alone" "$( rigKept rig-sw-live-$$ )" "1:2"
rigAssert "the sandbox of a run with no session word, alive by the process its record names, is left alone" "$( rigKept rig-sw-noword-$$ )" "1:2"
rigAssert "the sandbox of a run that is gone is emptied while another run's line holds its path" "$( rigKept rig-sw-gone-$$ )" "0:0"
rigAssert "a sandbox two runs share is left alone while one of them lives" "$( rigKept rig-sw-shared-$$ )" "1:2"
rigAssert "a sandbox whose record is under ten minutes old is left alone, as before" "$( rigKept rig-sw-fresh-$$ )" "1:2"
rigAssert "nothing is said of a sandbox that is left alone" "$( LC_ALL=C grep -c -e "rig-sw-live-$$" -e "rig-sw-noword-$$" -e "rig-sw-shared-$$" -e "rig-sw-fresh-$$" "$rigTmp/s1" || : )" 0
[ ! -s "$rigTmp/net-calls" ] || rigRefuse "a request was made over the network: $( head -1 "$rigTmp/net-calls" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ RUN RULE READERS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: TaskOutput or the sandbox sweep takes a command line that only carries an id for" >&2
	echo "        the run of that id, or no longer sees a run that lives" >&2
	echo "  fix:  repair the reader -- never the assertion" >&2
	exit 1
fi
printf 'RUN_RULE_READERS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
