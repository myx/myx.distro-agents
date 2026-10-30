#!/usr/bin/env bash
## Behavioural check on a spawn record's own `parent-member:` header -- who a handback of the run
## it starts is for when it names nobody itself (AgentsToolsSessionParentMember, AgentsToolsRunRoute).
## agent-spawn-proxy reads the caller's identity BEFORE minting the child (InternOpAgentSpawnProxy.include),
## and must use the same resolver every other caller uses (AgentsToolsTeamMember: a spawned session's own
## identity first, else its MDAT_TEAM_MEMBER), never the narrower AgentsToolsActingMember alone, which never
## reads MDAT_TEAM_MEMBER at all.
## Held, against the proxy with a console stand-in:
##   1. a bare console caller, no identity anywhere: no parent-member header, as it always was.
##   2. a root session's own caller, identity only in MDAT_TEAM_MEMBER, no spawn-chain record of its own:
##      parent-member names it (S18.1 load incident: a root console session's spawn carried none, so its
##      handback fell through to the human-owner instead of the session's own thread).
##   3. an already-spawned caller, identity from its own spawn-chain, MDAT_TEAM_MEMBER also set to someone
##      else: the spawn-chain identity wins, as AgentsToolsTeamMember's own order says.
## Offline: a fake console, a fake curl that answers Slack; every run an `env -i` child.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsSpawnParentMemberIdentityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/home/.agents/magic-team" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigSkills/magic-coordinator" "$rigData/board/running"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## the calling identity's env assignments (space-separated NAME=value, may be empty), the member to spawn
	: > "$rigTmp/brief"
	rm -rf "$rigWs/.local/agents/spawned"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	env -i $1 MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$1" --dispatch-doc:none --wait --context rig-spawn-parent-member
		' rig-spawn "$2" <<< "RIG-TASK-TEXT" > "$rigTmp/out.log" 2>&1
}
rigRecord(){ ## -- the run record the last spawn made
	ls -t "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | head -1
}
rigHeader(){ ## header -- its value in the run record, or `-` where it has none
	local headerFile headerValue
	headerFile="$( rigRecord )"
	[ -n "$headerFile" ] || { printf 'no-record' ; return 0 ; }
	headerValue="$( LC_ALL=C awk -v wantField="$1" 'NR == 1 && $0 != "---" { exit } $0 == "---" { dashes++ ; if (dashes == 2) exit ; next } index($0, wantField ": ") == 1 { print substr($0, length(wantField) + 3) ; exit }' "$headerFile" )"
	printf '%s' "${headerValue:--}"
}

echo "-- 1. a bare console caller, no identity anywhere: no parent-member header --"
rigSpawn "" keeper-myx
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" || rigRefuse "the fake console never received the context: $( LC_ALL=C grep ERROR "$rigTmp/out.log" | head -1 )"
rigAssert "no parent-member: header, as it always was" "$( rigHeader parent-member )" "-"

echo "-- 2. a root session's own caller, identity only in MDAT_TEAM_MEMBER, no spawn-chain record (S18.1) --"
rigSpawn "MDAT_TEAM_MEMBER=magic-coordinator" keeper-myx
rigAssert "parent-member names the root session's own member" "$( rigHeader parent-member )" "magic-coordinator"

echo "-- 3. an already-spawned caller: its own spawn-chain identity wins over MDAT_TEAM_MEMBER --"
rigSpawn "MDAT_SPAWN_AGENT=magic-coordinator MDAT_TEAM_MEMBER=keeper-myx" keeper-myx
rigAssert "parent-member names the spawn-chain identity, not the env fallback" "$( rigHeader parent-member )" "magic-coordinator"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PARENT MEMBER IDENTITY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PARENT_MEMBER_IDENTITY: OK (%d assertions, offline)\n' "$rigPassCount"
