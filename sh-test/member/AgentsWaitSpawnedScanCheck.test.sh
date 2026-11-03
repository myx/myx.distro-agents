#!/usr/bin/env bash
## Behavioural check on the hot path of a Wait (S27.9, epic 20261026-refactorings): a wait reads its run's own spawn record at
## its exact path, and never enumerates the spawned/ folders of other sessions. MEASURED on real --wait-for-input calls.
##   1. THE INSTRUMENT. A reader shim, first on PATH, records every path it is handed under the rig's spawned/ folder. Run over
##      the old shape of the read (`spawned/*/<session>.spawn.md`) it records every folder's record: it is able to see a scan.
##   2. THE FLOOR'S READ (`MemberWaitSources.include:222`). A work-duty session's wait hands no reader one path inside another
##      session's folder, reads its own record, and its floor carries tagged:<member> beside its DMs and mentions.
##   3. THE ASK BRANCH (`MemberWaitSources.include:404`). A wait on another session's ask is refused, reads its own record, and
##      hands no reader a foreign path before the refusal.
##   4. THE RUN'S OWN ID (`MemberWait.include:415`). The same wait carrying a real run's session id, as every spawned run does,
##      hands no reader a foreign path either. Scene 4 carries the run id and scenes 2 and 3 carry none, so a foreign count here
##      is the routine-lock read alone. Red recipe: it globs `spawned/*/<session>.spawn.md` once a call, so this rig's 50 folders
##      are handed over, while scenes 2 and 3 stay green on the very same code.
## Offline: a Slack-shaped fake curl first on PATH, and every tree is this rig's own. Default cadence, never a fixed poll interval.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitSpawnedScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## No scan is named by this check, so no control thread can be left behind: the rig alone goes.
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/magic-coordinator"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.armed.md"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl.real" || rigRefuse "the fake curl fixture is missing from the package"
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$( date +%s )" "$*" >> "$RIG_SCENARIO/calls.log"
case " $* " in
	*reactions.add*) printf '{"ok":true}\n' ; exit 0 ;;
esac
exec "$(dirname "$0")/curl.real" "$@"
EOF
## THE READER SHIM: every path a reader is handed under the rig's spawned/ folder is written down, then the real reader runs.
## One file, `scan.log`, a line `foreign <path>` inside another session's folder and `own <path>` inside the run's own.
for rigShim in grep cat ; do
	rigReal="$( command -v "$rigShim" )" || rigRefuse "no $rigShim on PATH"
	printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$rigReal" > "$rigTmp/bin/$rigShim.real" || rigRefuse "the real $rigShim could not be written"
	cat > "$rigTmp/bin/$rigShim" <<'EOF' || rigRefuse "the reader shim could not be written"
#!/usr/bin/env bash
## Every path this reader is handed under the rig's spawned/ folder is written down, then the real reader runs.
for rigArg in "$@" ; do
	case "$rigArg" in
		"${RIG_SPAWNED:-/nonexistent}"/*)
			case "$rigArg" in
				"${RIG_SPAWNED:-/nonexistent}/${RIG_SESSION:-none}"/*) printf 'own %s\n' "$rigArg" ;;
				*) printf 'foreign %s\n' "$rigArg" ;;
			esac >> "${RIG_SCENARIO:-/dev/null}/scan.log"
		;;
	esac
done
exec "$(dirname "$0")/$( basename "$0" ).real" "$@"
EOF
	chmod +x "$rigTmp/bin/$rigShim" "$rigTmp/bin/$rigShim.real"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigSession="rig-scan-session" rigOther="rig-other-session"
rigDir="$rigTmp/scene" rigWs="$rigDir/ws" rigData="$rigDir/data" rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/sessions/$rigSession/wait" \
	"$rigData/inboxes/keeper-rig/incoming" "$rigData/board" "$rigWs/.local/agents/pending"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-KEEPER\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'keeper-rig=URIGKEEP1=k=K=K=d\n' > "$rigWs/.local/.agents/slack-mention-ids.cache"
printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' > "$rigDir/search.rig-user-KEEPER.json"
printf '{"ok":true,"messages":{"total":0,"paging":{"count":100,"total":0,"page":1,"pages":1},"matches":[]}}\n' > "$rigDir/search.rig-bot-token-TEAM.json"
: > "$rigDir/api.log"
: > "$rigWs/.local/agents/sessions/$rigSession/session.chat.pointers"
## The run's own record: a work-duty, at the path the registry gives it.
mkdir -p "$rigSpawned/$rigSession"
printf -- '---\nrun-process: 1 x\nroutine: keeper-rig.work-duty.routine.md\n---\n' > "$rigSpawned/$rigSession/$rigSession.spawn.md"
## Fifty other sessions' folders. Each holds a record of this same session id, which is the shape a resumed or re-spawned run
## leaves: a glob `spawned/*/<session>.spawn.md` finds every one of them, an exact path finds the one above.
for rigN in $( seq 1 50 ) ; do
	mkdir -p "$rigSpawned/rig-other-$( printf '%02d' "$rigN" )"
	printf -- '---\nrun-process: 1 x\nroutine: keeper-rig.plain.routine.md\n---\n' > "$rigSpawned/rig-other-$( printf '%02d' "$rigN" )/$rigSession.spawn.md"
done
## An ask record whose session is another: the one thing the ask branch's folder read is guarded by. The guard reads it under
## the wait's own workspace.
printf -- '---\ntype: ask\nsession-id: %s\n---\n\n# Rig ask of another session\n' "$rigOther" > "$rigWs/.local/agents/pending/ask-rig-Q1.md"
rigScanCount(){ ## own|foreign -- how many paths the readers were handed in that role
	local scanCount=0
	[ ! -f "$rigDir/scan.log" ] || scanCount="$( LC_ALL=C grep -c "^$1 " "$rigDir/scan.log" || : )"
	case "$scanCount" in ''|*[!0-9]*) scanCount=0 ;; esac
	printf '%s' "$scanCount"
}
rigCall(){ ## result name, run id (yes|no), op words...
	local callName="$1" callRun="$2" callRc=0 callRunId=""
	shift 2
	[ "$callRun" != yes ] || callRunId="$rigSession"
	: > "$rigDir/scan.log"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigDir" \
		RIG_SPAWNED="$rigSpawned" RIG_SESSION="$rigSession" MDAT_WAIT_REMIND=off MDAT_SPAWN_AGENT=keeper-rig \
		MDAT_SPAWN_SESSION_ID="$callRunId" \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 400 -- bash "$rigTool" "$@" ) > "$rigDir/$callName.out" 2> "$rigDir/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigDir/$callName.rc"
}
rigFloorHas(){ ## result name, the sources -- yes where the result's sources line holds every one of them
	local floorOk=1 floorWant
	for floorWant in "${@:2}" ; do
		case " $( LC_ALL=C sed -n 's/^# sources: //p' "$rigDir/$1.out" | head -1 ) " in
			*" $floorWant "*) ;;
			*) floorOk=0 ;;
		esac
	done
	[ "$floorOk" = 0 ] && printf no || printf yes
}
rigShow(){ ## result name
	printf '  --- %s: rc %s\n' "$1" "$( cat "$rigDir/$1.rc" 2> /dev/null )" ; head -c 1500 "$rigDir/$1.out" ; head -c 800 "$rigDir/$1.err"
}
rigWaitCall(){ ## result name, run id (yes|no)
	rigCall "$1" "$2" --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source "chat:$rigSession" --wait-timeout 1
}
rigSaid(){ ## result name -- the first line of what the call said
	head -1 "$rigDir/$1.out"
}

echo "-- 1. the instrument: the old shape of the read hands every folder's record to the reader --"
: > "$rigDir/scan.log"
( cd "$rigWs" && env -i PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigTmp/home" \
	RIG_SCENARIO="$rigDir" RIG_SPAWNED="$rigSpawned" RIG_SESSION="$rigSession" \
	bash -c 'LC_ALL=C grep -h -m1 -E "^routine: [A-Za-z0-9-]+\.work-duty\.routine\.md$" "$RIG_SPAWNED"/*/"$RIG_SESSION.spawn.md" > /dev/null' ) || :
rigAssert "a reader handed the glob's paths records all 50 of another session's folders" "$( rigScanCount foreign )" "50"
rigAssert "...and it records the run's own record too" "$(( $( rigScanCount own ) >= 1 ))" "1"

echo "-- 2. the floor's read: a work-duty session's wait hands no reader a foreign path --"
rigWaitCall floor no
printf '  measured: rc %s, first line "%s", own record read %s time(s)\n' "$( cat "$rigDir/floor.rc" )" "$( rigSaid floor )" "$( rigScanCount own )"
[ "$( cat "$rigDir/floor.rc" )" = 0 ] || rigShow floor
rigAssert "the floor's read touches no other session's folder" "$( rigScanCount foreign )" "0"
rigAssert "the run's own record is read at its exact path" "$(( $( rigScanCount own ) >= 1 ))" "1"
rigAssert "the floor carries the duty's tags beside its DMs and mentions" \
	"$( rigFloorHas floor "tagged:keeper-rig" dms:keeper-rig mentions:keeper-rig )" "yes"

echo "-- 3. the ask branch: a refused ask of another session scans no folder first --"
rigCall ask no --intern-op-wait-for-input keeper-rig --wait-default --wait-session-id "$rigSession" --wait-source ask:ask-rig-Q1 --wait-timeout 1
printf '  measured: rc %s, first line "%s", own record read %s time(s)\n' "$( cat "$rigDir/ask.rc" )" "$( rigSaid ask )" "$( rigScanCount own )"
rigAssert "the call is refused for an ask of another session" "$( rigScanCount foreign ):$( LC_ALL=C grep -c 'is a question asked by session' "$rigDir/ask.err" )" "0:1"

echo "-- 4. the run's own id: the routine-lock read hands no reader a foreign path --"
rigWaitCall lock yes
printf '  measured: rc %s, first line "%s", own record read %s time(s)\n' "$( cat "$rigDir/lock.rc" )" "$( rigSaid lock )" "$( rigScanCount own )"
[ "$( cat "$rigDir/lock.rc" )" != 0 ] || :
rigAssert "a call carrying the run's own id touches no other session's folder" "$( rigScanCount foreign )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT SPAWNED SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_SPAWNED_SCAN: OK (%d assertions, offline)\n' "$rigPassCount"
