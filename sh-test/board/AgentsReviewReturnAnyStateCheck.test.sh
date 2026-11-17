#!/usr/bin/env bash
## Behavioural check on where a review return may start from (S6.34): a return's own resume works
## whatever state its item is in, as a dead run's verdict does. Held through the REAL
## `--return-review`, run against board items of this rig's own and a live child of this rig's own,
## with a Slack-shaped fake curl first on PATH.
##   1. a return on an item in `running` puts it running again, with the corrections;
##   2. the same for an item in `processed`, moved back into review first;
##   3. the same for an item in `pending`, moved back into review first;
##   4. a return on an item in `review` still works, as it always has.
## RED ON THE TREE BEFORE THE FIX: rows 1 to 3 are refused, `... is in running; this verdict
## applies to an item in: review`, and the item does not move. Row 4 passes there, and passes here:
## the review case is the control, and it is what shows the other three read the new branch.
## Offline: a stand-in for the child's process, a fake curl, and every store a folder of this rig's own.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigFixtures/rig-processes.include.sh" "$rigFixtures/rig-control-threads.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewReturnAnyStateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigScn="$rigTmp/scn"
rigSpawned="$rigWs/.local/agents/spawned"
. "$rigFixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="${rigWs:-$rigTmp/ws}" rigOwnerData="${rigData:-${rigD:-${rigStore:-${rigOut:-$rigTmp/data}}}}" rigOwnerHome="${rigHome:-$rigTmp/home}" rigOwnerSkills="${rigSkills:-$rigTmp/skills}"
rigOwnerBoardReady
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigSpawned" "$rigTmp/bin" "$rigScn"
cp "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
## THE RIG'S OWN PROCESS LIST: the child's liveness is read from ps -A, so a rig that read the host's
## list would find whatever command line of this host holds the id. The ps first on PATH answers that
## one listing from the rig's own list, and hands every other call to the real ps.
rigRealTool ps "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
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
chmod +x "$rigTmp/bin/ps"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-CHILD\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
## Both members the flow names: the child the return is delivered to, and the reviewer that sends it.
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRun(){ ## result file, tooling arguments...
	local runOut="$1" ; shift
	: > "$rigScn/calls" ; : > "$rigScn/bodies"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		RIG_SCENARIO="$rigScn" bash "$rigTool" "$@" ) > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigItem(){ ## state, item stem, spawn id -- a dispatch item of this rig, reviewed by magic-coordinator
	local itemExtra=""
	[ "$1" != review ] || itemExtra="review-since-epoch: 1000
"
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\n%s---\n\n# rig dispatch\n' "$3" "$itemExtra" | rigOwnerBoardPut "$1" "$2.md"
}
rigRecord(){ ## spawn id, session thread
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-rig\nstatus: spawn-started\nsession-thread: %s\n---\n' \
		"$1" "$1" "$1" "$rigHost" "$2" > "$rigSpawned/$1/$1.spawn.md"
}
rigLive(){ ## spawn id -- a stand-in process, listed in this rig's own process list under its own pid
	bash -c 'sleep 300 ; :' "$1" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	printf '%s rig-run --session-id %s\n' "$!" "$1" >> "$rigTmp/ps.list"
	disown "$!" 2> /dev/null || :
}
rigLoc(){ ## item stem -- the board state holding it
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}

## ONE ROW: an item in the state given, its live child, and the return that starts that child again.
## What is asserted is the same for every state, so a row that passes on one tree and fails on another
## is a difference in the flow and never in the words.
rigReturnFrom(){ ## state, item stem, child spawn id, thread
	local rowState="$1" rowItem="$2" rowSpawn="$3" rowThread="$4" rowOut
	rigItem "$rowState" "$rowItem" "$rowSpawn"
	rigRecord "$rowSpawn" "$rowThread"
	rigLive "$rowSpawn"
	sleep 1
	rowOut="$rigTmp/return-$rowState"
	rigRun "$rowOut" --return-review --team-member magic-coordinator "$rowItem" --message "corrections for the $rowState item"
	rigAssert "1. the return of an item in $rowState succeeds"     "$( cat "$rowOut.rc" )" 0
	rigAssert "2. the item is running again"                       "$( rigLoc "$rowItem" )" running
	rigAssert "3. the corrections are in its body"                 "$( LC_ALL=C grep -c -x "corrections for the $rowState item" "$rigData/board/running/$rowItem.md" 2> /dev/null || : )" 1
	rigAssert "4. and it was delivered to the live child"          "$( LC_ALL=C grep -c "RETURN: delivered to keeper-rig in ${rowThread%%:*}" "$rowOut" )" 1
}

echo "-- 1. a return on an item in running --"
rigReturnFrom running dispatch-20261117T0900Z-run "rig-child-run-$$" CRUN00001:1794900000.000100
echo "-- 2. a return on an item in processed --"
rigReturnFrom processed dispatch-20261117T0900Z-pro "rig-child-pro-$$" CPRO00001:1794900000.000200
echo "-- 3. a return on an item in pending --"
rigReturnFrom pending dispatch-20261117T0900Z-pen "rig-child-pen-$$" CPEN00001:1794900000.000300
echo "-- 4. a return on an item in review, the case that already worked --"
rigReturnFrom review dispatch-20261117T0900Z-rev "rig-child-rev-$$" CREV00001:1794900000.000400
rigAssert "the review row still clears its review mark"        "$( LC_ALL=C grep -c '^review-since-epoch:' "$rigData/board/running/dispatch-20261117T0900Z-rev.md" 2> /dev/null || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW RETURN ANY STATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  sh-lib/board/AgentsTools.ReviewFlow.include, the return arm -- never the assertion" >&2
	exit 1
fi
printf 'REVIEW_RETURN_ANY_STATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
