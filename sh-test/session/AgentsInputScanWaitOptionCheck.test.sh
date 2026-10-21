#!/usr/bin/env bash
## Behavioural check on the `--wait <seconds>` option of an input-scan-def: line (F7.12, the owner's addition of 2026-10-20; AgentsToolsInputScanDefAwait,
## sh-lib/session/AgentsTools.InputScanDef.include, called by the spawn proxy before the lock): `input-scan-def: <scan> --wait 300`. Run through the spawn proxy
## with a stand-in console that records its brief and runs no model, as AgentsInputScanDefCheck does. Held:
##   1. a scan that is empty at the start and stays so for the whole time: the start ends with no spawn -- no brief reached a console, no sandbox, no record --
##      after the time, with one line that says nothing came
##   2. a scan that is empty at the start and gets input some seconds in (two items together): one spawn, long before the time is out, and the report it was
##      given holds both items
##   3. a scan with input at the start: the start goes on at once, the time is not waited
##   4. (the line form and its refusals are AgentsSkillsetValidateRoutineCheck's; the collect window of the work-duty scan is AgentsWorkDutyInputScanCheck's)
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsInputScanWaitOptionCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'## input/ is emptied when the run closes: what the scan left there is read while the run is live.' \
	'cp "$MDAT_SPAWN_SANDBOX_ROOT/input/input-scan.md" "$RIG_SCENARIO/input-scan.seen" 2> /dev/null || :' \
	'## The run is in its session: its pointers, then the first wait on a scan the spawner ran, and one on a scan it did not.' \
	'cp "$MMDAPP/.local/agents/sessions/$MDAT_SESSION_ID/session.chat.pointers" "$RIG_SCENARIO/pointers.seen" 2> /dev/null || :' \
	'bash "$RIG_FN" --wait-for-input "$MDAT_SPAWN_AGENT" --wait-source scan:permission-escalation --wait-timeout 0 > "$RIG_SCENARIO/wait.seen" 2> /dev/null < /dev/null || :' \
	'bash "$RIG_FN" --wait-for-input "$MDAT_SPAWN_AGENT" --wait-source scan:advance --wait-timeout 0 > "$RIG_SCENARIO/wait.control" 2> /dev/null < /dev/null || :' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRoutine(){ ## short name, the input-scan-def: line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
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
rigSumOf(){ ## file -- the sum of its bytes, as a wait keeps the sum of a report: <cksum>-<size>
	LC_ALL=C cksum < "$1" 2> /dev/null | LC_ALL=C awk '{ print $1 "-" $2 ; }'
}
rigPointerOf(){ ## scan -- the pointer the run's session holds for the scan of keeper-rig, or none
	cat "$rigTmp/pointers.seen" 2> /dev/null | LC_ALL=C awk -F '\t' -v want="scan:$1:keeper-rig" '$1 == want { print $2 ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }'
}
rigFirst(){ ## file -- its first line
	LC_ALL=C sed -n 1p "$1" 2> /dev/null
}
## One start of keeper-rig's routine through the spawn proxy, waiting for its run; the sandbox it made in rigSandbox.
rigSpawn(){ ## routine short name
	rm -f "$rigTmp"/brief.* "$rigTmp/input-scan.seen" "$rigTmp/pointers.seen" "$rigTmp/wait.seen" "$rigTmp/wait.control"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sandboxes"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-scan-def keeper-rig --routine "$1" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1
	rigSandbox="$( find "$rigWs/.local/agents/spawned" -type d -name input 2> /dev/null | head -1 )"
	rigSandbox="${rigSandbox%/input}"
}


rigRoutine rigwaitshort 'input-scan-def: member-work-session --wait 10'
rigRoutine rigwaitlong 'input-scan-def: member-work-session --wait 60'
mkdir -p "$rigData/inboxes/keeper-rig/incoming"
rigItem(){ ## name -- an inbox item of keeper-rig not yet processed
	printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\n# Note: %s\n\n%s\n' "$1" "$1" > "$rigData/inboxes/keeper-rig/incoming/note-20261021T0900Z-$1.md"
}
rigRecords(){ ## how many spawn records the rig holds
	find "$rigWs/.local/agents/spawned" -name '*.md' 2> /dev/null | LC_ALL=C grep -c . || :
}
rigTimed(){ ## routine short name -- one start, and its seconds in rigTook
	local timedAt
	timedAt="$( date +%s )"
	rigSpawn "$1"
	rigTook="$(( $( date +%s ) - timedAt ))"
}

echo "-- 1. empty, and nothing comes: no spawn --"
rigTimed rigwaitshort
rigAssert "the start waited its ten seconds and ended: nothing was spawned (no brief reached a console, no sandbox, no record)" "$( [ "$rigTook" -ge 10 ] && [ "$rigTook" -le 60 ] && echo waited || echo "took:$rigTook" ):$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . ):$( [ -n "$rigSandbox" ] && echo sandbox || echo none ):$( rigRecords )" "waited:0:none:0"
rigAssert "one line says so, naming the scan and the seconds" "$( LC_ALL=C grep -c -F 'nothing came on the member-work-session scan of magic-team.rigwaitshort.routine.md within 10 seconds: no agent was started' "$rigTmp/spawn.out" )" "1"

echo "-- 2. empty, then input at 4 seconds: one spawn, and the report holds both --"
( sleep 4 ; rigItem alpha ; rigItem beta ) &
rigLater=$!
rigTimed rigwaitlong
wait "$rigLater" 2> /dev/null
rigAssert "one spawn, started when the input came and not when the sixty seconds were out" "$( [ "$rigTook" -ge 3 ] && [ "$rigTook" -le 40 ] && echo early || echo "took:$rigTook" ):$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . ):$( rigRecords )" "early:1:1"
rigAssert "the report the start was given holds both items that came together (read by the live run)" "$( LC_ALL=C grep -c 'alpha' "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/yes/' ):$( LC_ALL=C grep -c 'beta' "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/yes/' )" "yes:yes"
rigAssert "and says nothing was waited on again: the spawn made no second scan folder" "$( ls "$rigWs/.local/agents/scratch" 2> /dev/null | LC_ALL=C grep -c '^scan-wait\.' || : )" "0"

echo "-- 3. input at the start: it goes on at once --"
rigItem gamma
rigTimed rigwaitlong
rigAssert "the start did not wait: one spawn, well inside the sixty seconds, the item in its report" "$( [ "$rigTook" -le 40 ] && echo quick || echo "took:$rigTook" ):$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -c 'gamma' "$rigTmp/input-scan.seen" 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/yes/' )" "quick:1:yes"

echo "-- 4. the wait reads its sources from the start of the line, not from its own first pass --"
##   What arrives between the scan's reading and the Wait's first pass is an arrival (the floor of the wait, --wait-since-utime), or it would wait out the whole time.
rigWaitOp(){ ## words... -- the first line of one --wait-for-input call of the rig
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c 'cd "$MMDAPP" && exec bash "$1" --wait-for-input keeper-rig "${@:2}"' _ "$rigTool" "$@" 2> /dev/null < /dev/null | head -n 1
}
rigItem delta
rigAssert "control: an item that is there when the Wait starts is its baseline: nothing is new, TIMEOUT" "$( rigWaitOp --wait-source inbox:keeper-rig --wait-timeout 2 | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"
rigAssert "with the floor of the line (a little earlier than the item) the item is an arrival: RECEIVED at once" "$( rigWaitOp --wait-source inbox:keeper-rig --wait-since-utime "$(( $( date +%s ) - 30 ))" --wait-timeout 2 )" "WAIT-RESULT: RECEIVED"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN WAIT OPTION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_WAIT_OPTION: OK (%d assertions, offline)\n' "$rigPassCount"
