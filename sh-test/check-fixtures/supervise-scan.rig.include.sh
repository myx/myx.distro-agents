#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The rig of a `--supervise-scan` check: one workspace, its spawn records, its session stores, its team data and its home, all
## this rig's own, and the scan run against them. Sourced by the checks of sh-test/session that hold one scan kind:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/supervise-scan.rig.include.sh"

##
## The caller sets MMDAPP (the workspace its scratch lives in) and MDLT_ORIGIN (the tree under test), then calls
## rigScanBegin <check name>. The folder comes from rig-temp.include.sh, so the check takes its turn in the machine's one line
## of test runs as every other check does. rigScanEnd ends the stand-in processes and removes the folder; the check ends by
## calling rigScanDone, and the trap removes the folder either way.
##
## The rig's files are the shapes the tooling reads: a spawn record with its frontmatter, the session folder's activity mark and
## chat, the pending ask with its own header, the control thread's pid file and log, and the board under the team-data root the
## workspace's settings name.
##

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1

rigPids=""
rigPass=0
rigFail=0

rigScanBegin(){ ## the check's name -- makes the rig, sets every path the helpers use
	rigName="$1"
	: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
	: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
	rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
	rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
	rigIsoAwk="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk"
	[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
	[ -f "$rigIsoAwk" ] || rigRefuse "the ISO reader is not at the origin: $rigIsoAwk"
	rigTmp="$( rigTempDir "$rigName" )" || rigRefuse "no scratch folder"
	rigTmp="$( cd "$rigTmp" && pwd -P )" || rigRefuse "the scratch folder does not resolve"
	trap 'rigScanEnd' EXIT
	rigWs="$rigTmp/ws"
	rigData="$rigTmp/data"
	rigHome="$rigTmp/home"
	rigAgents="$rigWs/.local/agents"
	mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigAgents/pending" "$rigWs/.local/.agents" \
		"$rigData/audit/2026-11" "$rigWs/.local/agents/team-data-root/board/review" "$rigHome" || rigRefuse "the rig could not be made: $rigTmp"
	## The board the scan resolves for this workspace is its own hidden store, which the settings name none of.
	rigBoard="$rigWs/.local/agents/team-data-root/board"
	rigNow="$( date +%s )"
}

rigScanEnd(){
	local reapOne
	for reapOne in $rigPids ; do kill -TERM "$reapOne" 2> /dev/null ; done
	for reapOne in ${rigGroups:-} ; do kill -TERM -- "-$reapOne" 2> /dev/null ; done
	sleep 0.3
	for reapOne in $rigPids ; do kill -KILL "$reapOne" 2> /dev/null ; done
	for reapOne in ${rigGroups:-} ; do kill -KILL -- "-$reapOne" 2> /dev/null ; done
	[ -z "${rigTmp:-}" ] || rm -rf -- "$rigTmp"
}

rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }

rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigScanDone(){ ## nothing -- the check's own end, once every assertion is made
	[ "$rigFail" -eq 0 ] || { echo "⛔ $rigName FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1 ; }
	printf '%s: OK (%d assertions, offline, rig tree only)\n' "$rigName" "$rigPass"
}

## A time the tooling reads, from an epoch: no portable date(1) prints one, so both spellings are tried.
rigIso(){ date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ; }

rigTranscriptPath(){ printf '%s/audit/2026-11/%s.log' "$rigData" "$1" ; }

rigRun(){ ## run id, member, extra frontmatter lines (may be empty)
	local runId="$1" runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $runId"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-supervise-kind-rig\nowner: %s\nstatus: spawn-started\nstarted-at: %s\n%s---\n' \
		"$runId" "$runId" "$runId" "$( hostname -s 2> /dev/null )" "$2" "$( date '+%Y-%m-%d %H:%M %z' )" \
		"${3:+$3
}" > "$runDir/$runId.spawn.md" || rigRefuse "the record could not be written: $runId"
	printf '%s\n' "$( rigTranscriptPath "$runId" )" > "$rigAgents/sessions/$1/transcript"
	: > "$( rigTranscriptPath "$runId" )"
}

rigTool(){ ## run id, seconds ago, tool name -- one tool line of the run's transcript
	printf '%s TOOL %s cmd="rig" -> ok 1B/1L <1s\n' "$( rigIso $(( rigNow - $2 )) )" "$3" >> "$( rigTranscriptPath "$1" )"
}

rigMark(){ ## run id, seconds ago, activity word -- the run's own log of what it is doing
	printf '1 %s %s\n' "$(( rigNow - $2 ))" "$3" > "$rigAgents/sessions/$1/activity"
}

rigChat(){ ## run id, seconds ago, who, text -- one post of the run's session chat
	printf '%s %s -> all: %s\n' "$( rigIso $(( rigNow - $2 )) )" "$3" "$4" >> "$rigAgents/sessions/$1/session.chat"
}

rigStand(){ ## run id -- a process carrying the id, so the run reads live
	python3 -I -B -c 'import time; time.sleep(240)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!"
	disown "$!" 2> /dev/null || :
}

rigLaunched(){ ## run id, pid -- the record's own run-process line, inside its frontmatter, as the launcher writes it
	local begun
	begun="$( LC_ALL=C ps -o lstart= -p "$2" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )" || begun=""
	[ -n "$begun" ] || rigRefuse "the stand-in process named no start: $2"
	rigRunProcess "$1" "$2 $begun"
}

rigRunProcess(){ ## run id, the kept `<pid> <start>` -- one more frontmatter line of that record, before its closing fence
	local recordFile="$rigAgents/spawned/$1/$1.spawn.md" tmpFile
	tmpFile="$( mktemp "$recordFile.XXXXXX" )" || rigRefuse "no temp beside the record: $recordFile"
	LC_ALL=C awk -v line="run-process: $2" '
		$0 == "---" { fence++ ; if ( fence == 2 && !wrote ) { print line ; wrote = 1 ; } ; print ; next ; }
		{ print ; }
	' "$recordFile" > "$tmpFile" || rigRefuse "the record could not be rewritten: $1"
	mv -f "$tmpFile" "$recordFile"
}

rigAsk(){ ## asking run id, address, thread ts (may be empty), extra header lines (may be empty)
	printf -- '---\nstatus: reply-pending\nowner: magic-developer\nkind: question\naddress-to: %s\nsession-id: %s\nquestion-ts: %s.000000\nasked-at: %s\n%s%s---\n' \
		"$2" "$1" "$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" "${3:+thread-ts: $3
}" "${4:-}" > "$rigAgents/pending/$1.md" || rigRefuse "the ask could not be written: $1"
}

rigRunEnded(){ ## run id, member -- a record whose run has ended, as a closed one reads
	local runId="$1" runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $runId"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-supervise-kind-rig\nowner: %s\nstatus: spawn-succeeded\nstarted-at: %s\n---\n' \
		"$runId" "$runId" "$runId" "$( hostname -s 2> /dev/null )" "$2" "$( date '+%Y-%m-%d %H:%M %z' )" > "$runDir/$runId.spawn.md" \
		|| rigRefuse "the record could not be written: $runId"
}

rigControl(){ ## session id, pid -- a control thread's pid file, naming the process and when it began
	local begun
	begun="$( LC_ALL=C ps -o lstart= -p "$2" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )" || begun=""
	mkdir -p "$rigAgents/sessions/$1/control" || rigRefuse "the control folder could not be made: $1"
	printf '%s %s\n' "$2" "$begun" > "$rigAgents/sessions/$1/control/pid"
	: > "$rigAgents/sessions/$1/control/state"
}

rigControlQuiet(){ ## session id, seconds ago -- the thread's log written that long ago
	local logFile="$rigAgents/sessions/$1/control/log"
	[ -f "$logFile" ] || : > "$logFile"
	python3 -I -B -c 'import os,sys; t = os.path.getmtime(sys.argv[1]) - int(sys.argv[2]); os.utime(sys.argv[1], (t, t))' \
		"$logFile" "$2" || rigRefuse "the thread's log date could not be set back: $1"
}

rigScratch(){ ## a folder under this rig -- for a queue or a copy the check owns
	mkdir -p "$rigTmp/$1" || rigRefuse "the rig folder could not be made: $1"
	printf '%s\n' "$rigTmp/$1"
}

rigReviewItem(){ ## item name, spawn id, review seconds ago, review-by (may be empty)
	local itemFile="$rigBoard/review/$1.md"
	mkdir -p "$rigBoard/review" || rigRefuse "the board could not be made: $rigBoard"
	printf -- '---\ntype: dispatch\ndate: %s\nowner: magic-developer\nspawn-id: %s\n%sreview-since-epoch: %s\n---\n\n# %s\n\nA hand-back waiting on its verdict.\n' \
		"$( date '+%Y-%m-%d %H:%M %z' )" "$2" "${4:+review-by: $4
}" "$(( rigNow - $3 ))" "$1" > "$itemFile" \
		|| rigRefuse "the review item could not be written: $1"
}

rigOrphanGroup(){ ## run id -- a process group whose leader ends and whose child lives on
	local groupPid
	python3 -I -B -c 'import os,time; os.setpgid(0,0)
pid = os.fork()
if pid == 0:
    time.sleep(600)
else:
    time.sleep(1)
    os._exit(0)' > /dev/null 2>&1 &
	groupPid="$!"
	rigGroups="${rigGroups:-} $groupPid"
	disown "$groupPid" 2> /dev/null || :
	rigRunProcess "$1" "$groupPid $( LC_ALL=C ps -o lstart= -p "$groupPid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	sleep 2
}

rigRetestQueue(){ ## the machine's queue folder this rig stands in, so the scan's own read is the rig's
	mkdir -p "$rigHome/.agents/magic-team/retest-queue/waiting" "$rigHome/.agents/magic-team/retest-queue/running" \
		"$rigHome/.agents/magic-team/retest-queue/done" || rigRefuse "the retest queue could not be made"
	printf '%s\n' "$rigHome/.agents/magic-team/retest-queue"
}

rigRetestRequest(){ ## request name, the asked stamp
	printf 'id: %s\nasked: %s\npriority: no-wait\nby: magic-developer\nwhy: the rig says so\nabout: live\ntest: AgentsRigOnlyCheck\n' \
		"$1" "$2" > "$rigHome/.agents/magic-team/retest-queue/waiting/$1.request"
}

## The scan, run by the dispatcher of the origin under test, on this rig's workspace alone. HOME is the rig's, so the machine's
## retest queue the scan reads is the rig's own too.
rigScan(){ ## extra NAME=value words...
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" "$@" \
		bash "$rigFn" --supervise-scan --workspace "$rigWs" 2>&1
}

rigKind(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" '$1 == want' ; }   ## kind -- its lines
rigKindHas(){ rigKind "$1" | LC_ALL=C grep -c -F -- "$2" ; }                    ## kind, text -- how many lines hold it
