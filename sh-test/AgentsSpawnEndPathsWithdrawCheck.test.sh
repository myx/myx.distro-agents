#!/usr/bin/env bash
## Behavioural check on a run ended by a TERM signal to its spawn with a question of its own still open, run rather than read: through the
## real spawn proxy on a stand-in console that asks and then does not end by itself.
## Held: the TERM ends the spawn, and the close it makes settles the question: the record closes as withdrawn, and no open question of the run is left
## in the store. (A run killed outright, with no close, reads `waiting` while its question is open: it is parked, resumable on the answer, and the advance
## pass leaves it to the control thread of its session, so it is not held here.)
## Offline: the same rig as AgentsSpawnCloseWithdrawCheck.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigNote="tooling-note.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnEndPathsWithdrawCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents" ; rigPend="$rigAgents/pending" ; rigFn="$rigTool"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/source/rigrepo/rigpkg" "$rigHome" "$rigSkills/rig-member" "$rigData/board/running"
printf 'SLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigWs/.local/.agents/preset-rig-cli.agent.env"
printf '# rigpkg\n' > "$rigWs/source/rigrepo/rigpkg/MAGIC.md"
printf '# workspace\n' > "$rigWs/MAGIC.md"
printf '# rig routine\n' > "$rigSkills/rig-member/magic-team.rig.routine.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the rig's file, which holds
## no line at all, so no run of this rig is ever "running", and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
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
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\ncat "${0%%/*}/../uptime.line" 2> /dev/null\n' > "$rigTmp/bin/uptime"
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 1.25 1.00 1.00\n' > "$rigTmp/uptime.line"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/uptime"

## THE STAND-IN CONSOLE: it asks one question of its own session, says so, and then waits for good: the rig ends it.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCLI'
#!/bin/sh
## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)
cat > /dev/null
[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "rig-cli" > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_TMP/run-id.$RIG_CASE"
printf '# Ask\n\nMay I?\n' | bash "$RIG_FN" --intern-op-pending-reply-open rig-member --to CRIG00001 \
	--session-id "$MDAT_SPAWN_SESSION_ID" --kind question --address-to URIGOWNER --addressees URIGOWNER \
	--asking-accounts ' URIGSELF1 ' --ask-identity member > "$RIG_TMP/ask.$RIG_CASE" 2> "$RIG_TMP/ask.$RIG_CASE.err"
echo "$$" > "$RIG_TMP/console-pid.$RIG_CASE"
exec sleep 120
RIGCLI
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigHeader(){ ## record file, header -- its value in the frontmatter, empty where absent
	[ -f "$1" ] || return 0
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++dashes > 1 ) exit ; next ; } dashes == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit ; }' "$1" 2> /dev/null
}
rigAsked(){ ## pending id, header -- from the live store, or from the one a close moved it to
	if [ -f "$rigPend/$1.md" ] ; then rigHeader "$rigPend/$1.md" "$2" ; else rigHeader "$rigPend/closed/$1.md" "$2" ; fi
}
rigStart(){ ## case name -- starts a run in the background, prints the pid of its spawn
	printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
		| env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
			MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_CASE="$1" \
			bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait' > "$rigTmp/spawn.$1.out" 2> "$rigTmp/spawn.$1.err" &
	echo $!
}
rigAwaitAsk(){ ## case name -- until the run has asked
	local waited=0
	while [ ! -s "$rigTmp/console-pid.$1" ] && [ "$waited" -lt 60 ] ; do sleep 1 ; waited=$(( waited + 1 )) ; done
	[ -s "$rigTmp/console-pid.$1" ]
}
rigAwaitEnd(){ ## pid
	local waited=0
	while kill -0 "$1" 2> /dev/null && [ "$waited" -lt 60 ] ; do sleep 1 ; waited=$(( waited + 1 )) ; done
}

echo "-- 1. a run ended by a TERM to its spawn settles its question --"
rigPid="$( rigStart term )"
rigAwaitAsk term || { cat "$rigTmp/spawn.term.err" | head ; rigRefuse "the stand-in console never asked" ; }
rigAsk="$( cat "$rigTmp/ask.term" )"
rigAssert "the question is open while the run lives" "$( rigAsked "$rigAsk" status )" "reply-pending"
kill -TERM "$rigPid" 2> /dev/null
rigAwaitEnd "$rigPid"
kill "$( cat "$rigTmp/console-pid.term" )" 2> /dev/null || :
rigAssert "after the TERM the question is withdrawn" "$( rigAsked "$rigAsk" status )" "withdrawn"
rigAssert "and it is out of the open store" "$( [ -f "$rigPend/$rigAsk.md" ] && echo open || echo closed )" "closed"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ AGENT SPAWN END PATHS WITHDRAW CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
echo "AGENT SPAWN END PATHS WITHDRAW: OK ($rigPasses assertions, offline)"
