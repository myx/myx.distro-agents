#!/usr/bin/env bash
## Behavioural check on the end of a control thread whose session is gone from the disk: --intern-session-control
## --run --session-id <id> (sh-lib/session/AgentsTools.InternSessionControl.include), run rather than read, against a rig
## workspace built here, with spawn records, session stores and a process list of the rig's own, as
## AgentsSessionControlThreadCheck keeps them. A ps first on PATH lists nothing of the host, and a curl beside it
## only logs, and nothing may call it. Every session of the rig has one record of this host that is still open
## and no run alive: its thread writes no state, and stays.
## Held:
##   1. ITS CONTROL FOLDER ALONE IS REMOVED, and the folder of its session stands: the next tick makes it again,
##      with its pid file and its lock, and the thread is the same process. As before.
##   2. THE FOLDER OF ITS SESSION IS REMOVED: the thread ends by itself within a few ticks, with status 1. Nothing
##      is made again: not that folder, not its control folder, no name under the stores of the rig; its rows file
##      under .local/temp is given back. It writes nothing but one line on its standard error, which says why.
##      The thread of another session, whose folder stands, goes on.
##   3. THE STORE ABOVE IT IS REMOVED, the folder of all sessions: every thread of the workspace ends, each with
##      its one line, and the store is not there again.
##   4. THE WHOLE WORKSPACE IS REMOVED, as a rig that is taken down removes it: the thread ends, and no path of the
##      workspace is there again.
## Red before the fix: 2, 3 and 4. The thread stayed for good: its next tick made its control folder again, the
## whole removed path with it, took its lock again, and watched nothing.
## Offline: only the rig's own tree is read or written. Every thread this check starts is ended by it through
## check-fixtures/rig-control-threads.include.sh, by the notes kept beside the rig's stores, and through
## nothing else; it starts no other process that stays.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
command -v perl > /dev/null 2>&1 || rigRefuse "no perl on PATH to start a process with its signals at their defaults"
## The one way this check ends a thread: by its note, `<pid> <start>`, while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends the control threads of a rig is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlRemovedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigKept="$rigTmp/kept"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigKept"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
## The period of the tick, in the rig: one second.
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## THE RIG'S OWN PROCESS LIST, as AgentsSessionControlThreadCheck keeps it: the ps first on PATH answers the
## whole-host listing from the rig's own list, which is empty here, and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
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
rigRec(){ ## session id -- one record of a run of this host that is still open, the founder's
	mkdir -p "$rigSp/t-$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\n---\n\n# Spawn session: %s\n' \
		"$1" "$1" "$rigHost" "$1" > "$rigSp/t-$1/rec-$1.md.rig" && mv -f "$rigSp/t-$1/rec-$1.md.rig" "$rigSp/t-$1/rec-$1.md"
}
## A thread: a process of its own, started with its signals at their defaults, whatever this check itself was
## started with. Its pid in rigThreadPid. It is noted nowhere here: its own pid file is its note.
rigThreadPid=""
rigThreads=""
rigThread(){ ## session id
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		perl -e '$SIG{$_} = "DEFAULT" for qw( HUP INT QUIT PIPE TERM USR1 USR2 ) ; chdir $ENV{MMDAPP} or exit 98 ; exec @ARGV or exit 99' \
		bash "$rigTool" "$rigOp" --run --session-id "$1" > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null &
	rigThreadPid=$!
	rigThreads="$rigThreads $rigThreadPid"
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigLives(){ ## pid... -- how many of them are processes now
	local livesCount=0 livesPid
	for livesPid in "$@" ; do rigEnded "$livesPid" || livesCount=$(( livesCount + 1 )) ; done
	printf '%s' "$livesCount"
}
rigGot=""
rigStatusOf(){ ## pid of a job of this shell -- the status it ended with into rigGot, `alive` where it has not ended in fifteen seconds
	rigGot="alive"
	rigWaitFor 15 rigEnded "$1" || return 0
	{ wait "$1" ; rigGot=$? ; } 2> /dev/null
}
rigHolds(){ ## session id, pid -- the pid file of the session names that pid, and its lock is there
	local holdsLine=""
	{ IFS= read -r holdsLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holdsLine" ] && [ "${holdsLine%% *}" = "$2" ] && [ -L "$rigStores/$1/control/lock" ]
}
rigTicked(){ ## session id -- its thread has made a tick: it said in its log what it found
	[ "$( LC_ALL=C grep -c -F -- "record(s) are still open" "$rigStores/$1/control/log" 2> /dev/null || : )" -ge 1 ]
}
## A session of the rig with its thread, up and past its first tick. Then the notes of that thread are kept
## beside the stores, where a removal of its folder does not reach them: a copy of its pid file, which is what
## this check ends it by, and its log under a second name, the same file, so that what the thread still writes
## to its output and its errors once its folder is gone can be read.
rigUp(){ ## session id -- its thread's pid in rigThreadPid
	rigRec "$1"
	rigThread "$1"
	rigWaitFor 20 rigHolds "$1" "$rigThreadPid" && rigWaitFor 20 rigTicked "$1" || :
	mkdir -p "$rigKept/$1/control"
	cp "$rigStores/$1/control/pid" "$rigKept/$1/control/pid" 2> /dev/null
	ln "$rigStores/$1/control/log" "$rigKept/$1/control/log" 2> /dev/null
}
rigLogLines(){ ## session id -- how many lines the log of its thread holds, by its second name
	LC_ALL=C grep -c '' "$rigKept/$1/control/log" 2> /dev/null || :
}
rigLogGone(){ ## session id -- how many lines of that log say that the folder of its session is gone
	LC_ALL=C grep -c -F -- "ends: the folder of its session is gone" "$rigKept/$1/control/log" 2> /dev/null || :
}
rigNames(){ ## dir -- every name under it, sorted, as one sum; none where it is not there
	[ -e "$1" ] || { printf 'none\n' ; return 0 ; }
	( cd "$1" && find . | LC_ALL=C sort ) | cksum
}
rigRows(){ ## pid -- how many rows files of that thread lie under .local/temp of the rig
	ls "$rigWs/.local/temp/mdat-session-control.$1.rows" 2> /dev/null | LC_ALL=C grep -c . || :
}

echo "-- 1. its control folder alone is removed: it is made again, as before --"
rigUp sess-keep ; rigKeep="$rigThreadPid" ; rigKeepBegan="$( rigProcBegan "$rigKeep" )"
rigAssert "control: the thread of a session with an open record and no run alive is up, holds its session and has ticked" \
	"$( rigLives "$rigKeep" ):$( cat "$rigStores/sess-keep/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-keep/control/lock" 2> /dev/null ):$( rigTicked sess-keep && echo ticked )" "1:$rigKeepBegan:$rigKeepBegan:ticked"
rm -rf "$rigStores/sess-keep/control"
rigWaitFor 10 rigHolds sess-keep "$rigKeep"
rigAssert "its whole control folder is removed while the folder of its session stands: it is made again, with its pid file and its lock, by the same process" \
	"$( rigLives "$rigKeep" ):$( cat "$rigStores/sess-keep/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-keep/control/lock" 2> /dev/null )" "1:$rigKeepBegan:$rigKeepBegan"
rigAssert "and it does not say that its session is gone"            "$( rigLogGone sess-keep )" "0"

echo "-- 2. the folder of its session is removed: the thread ends, and makes nothing again --"
rigUp sess-gone ; rigGone="$rigThreadPid"
rigAssert "control: a second thread is up beside the first, and its rows file lies under .local/temp" \
	"$( rigLives "$rigKeep" "$rigGone" ):$( rigHolds sess-gone "$rigGone" && echo holds ):$( rigRows "$rigGone" )" "2:holds:1"
rigGoneLines="$( rigLogLines sess-gone )"
rm -rf "$rigStores/sess-gone"
rigGoneNames="$( rigNames "$rigAgents" )"
rigStatusOf "$rigGone"
rigAssert "the thread ends by itself, with status 1"                 "$rigGot" "1"
sleep 2
rigAssert "the folder of its session is not made again, nor any name under the stores of the rig" \
	"$( [ -e "$rigStores/sess-gone" ] && echo there || echo gone ):$( [ "$( rigNames "$rigAgents" )" = "$rigGoneNames" ] && echo same || echo other )" "gone:same"
rigAssert "its rows file under .local/temp is given back"            "$( rigRows "$rigGone" )" "0"
rigAssert "it wrote one line more, on its standard error, and that line says why" \
	"$(( $( rigLogLines sess-gone ) - rigGoneLines )):$( rigLogGone sess-gone ):$( LC_ALL=C sed -n '$p' "$rigKept/sess-gone/control/log" 2> /dev/null | LC_ALL=C grep -c -F -- "the control thread of session sess-gone, pid $rigGone, ends: the folder of its session is gone, $rigStores/sess-gone" || : )" "1:1:1"
rigAssert "the thread of the other session, whose folder stands, goes on" \
	"$( rigLives "$rigKeep" ):$( rigHolds sess-keep "$rigKeep" && echo holds )" "1:holds"

echo "-- 3. the store above it is removed: every thread of it ends --"
rigUp sess-store ; rigStore="$rigThreadPid"
rigAssert "control: two threads are up"                              "$( rigLives "$rigKeep" "$rigStore" ):$( rigHolds sess-store "$rigStore" && echo holds )" "2:holds"
rm -rf "$rigStores"
rigStatusOf "$rigKeep" ; rigGotKeep="$rigGot"
rigStatusOf "$rigStore"
rigAssert "both end by themselves, each with status 1"               "$rigGotKeep:$rigGot" "1:1"
sleep 2
rigAssert "the store of the sessions is not made again, and each said its one line" \
	"$( [ -e "$rigStores" ] && echo there || echo gone ):$( rigLogGone sess-keep ):$( rigLogGone sess-store )" "gone:1:1"
rigAssert "neither left its rows file"                               "$( rigRows "$rigKeep" ):$( rigRows "$rigStore" )" "0:0"

echo "-- 4. the whole workspace is removed, as a rig that is taken down removes it --"
mkdir -p "$rigStores"
rigUp sess-ws ; rigAll="$rigThreadPid"
rigAssert "control: a thread is up in the workspace"                 "$( rigLives "$rigAll" ):$( rigHolds sess-ws "$rigAll" && echo holds )" "1:holds"
rm -rf "$rigWs"
rigStatusOf "$rigAll"
rigAssert "it ends by itself, with status 1"                         "$rigGot" "1"
sleep 2
rigAssert "no path of the workspace is there again, and it said its one line" \
	"$( [ -e "$rigWs" ] && echo there || echo gone ):$( rigLogGone sess-ws )" "gone:1"

echo "-- 5. nothing is left running, and nothing was asked of the network --"
rigControlThreadsEnd "$rigTmp"
sleep 1
## What became of a job that was ended here is this shell's to collect, and not a line of the report.
{ wait $rigThreads ; } 2> /dev/null
rigAssert "every thread this check started is ended"                 "$( rigLives $rigThreads )" "0"
rigAssert "no request was made"                                      "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL REMOVED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_REMOVED: OK (%d assertions, offline)\n' "$rigPasses"
