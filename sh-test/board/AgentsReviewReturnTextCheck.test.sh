#!/usr/bin/env bash
## Behavioural check on the text a returned review carries to its member (S6.3 of
## `20261102-refactorings.epic.md`): "A returned review reaches its member as plainly its own:
## addressed to it, naming its item, and saying the work is open again."
##
## Held through the REAL `--return-review`, run against a board item of this rig's own and a live
## child of this rig's own, with a Slack-shaped fake curl first on PATH. The body the child's thread
## receives is read from what was posted, never from the code that composes it.
##   1. the return is delivered to the live child, in its own thread;
##   2. the body says the work is open again;
##   3. the body names the item it is about;
##   4. the body carries the corrections the reviewer gave;
##   5. the item is running again, so "open again" is what actually happened.
##
## WHY IT IS RED ON THE TREE BEFORE THE FIX: the body reads `RETURNED for corrections on <item>.
## Continue the same task, then hand back again.` It never says the work is open again, so a member
## reading it has to infer that from the word RETURNED alone -- and the member that read one as
## another session's handback kept waiting.
##
## Offline: a stand-in for the child's process, a fake curl, and every store a folder of this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigFixtures/rig-processes.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewReturnTextCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigScn="$rigTmp/scn"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigWs/.local/.agents" "$rigWs/.local/temp" \
	"$rigSpawned" "$rigTmp/bin" "$rigScn"
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
rigItem(){ ## state, item stem, spawn id
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nspawn-id: %s\nreview-by: magic-coordinator\nreview-since-epoch: 1000\n---\n\n# rig dispatch\n' "$3" \
		> "$rigData/board/$1/$2.md"
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

rigChild="rig-child-$$"
rigItem review dispatch-20261103T0100Z-ret "$rigChild"
rigRecord "$rigChild" CRET00001:1793660000.000400
rigLive "$rigChild"
sleep 1
rigRun "$rigTmp/v1" --return-review --team-member magic-coordinator dispatch-20261103T0100Z-ret --message 'the brief named one file and the fix touched two'
rigAssert "the return op succeeded"                            "$( cat "$rigTmp/v1.rc" )" 0
rigAssert "1. it was delivered to the live child, in its own thread" "$( LC_ALL=C grep -c 'RETURN: delivered to keeper-rig in CRET00001' "$rigTmp/v1" )" 1
rigBody="$( cat "$rigScn/bodies" 2> /dev/null )"
rigAssert "and one message was posted"                         "$( [ -n "$rigBody" ] && printf yes || printf no )" yes
rigAssert "2. the body says the work is open again"            "$( printf '%s' "$rigBody" | LC_ALL=C grep -c -i 'open again' )" 1
rigAssert "3. the body names the item it is about"             "$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F 'dispatch-20261103T0100Z-ret' )" 1
rigAssert "4. the body carries the corrections the reviewer gave" "$( printf '%s' "$rigBody" | LC_ALL=C grep -c -F 'the brief named one file and the fix touched two' )" 1
rigAssert "5. the item is running again, so it is open indeed" "$( rigLoc dispatch-20261103T0100Z-ret )" running

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW RETURN TEXT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_RETURN_TEXT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
