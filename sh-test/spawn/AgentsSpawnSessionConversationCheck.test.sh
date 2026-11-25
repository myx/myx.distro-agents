#!/usr/bin/env bash
## Behavioural check on `--spawn-session --conversation <channel>:<thread ts>`, the address of the person's message a session is started for. The real
## spawn-session runs in a rig tree. Its proxy is a recorder that prints a session id, and the agent-less parent's own start and launch are recorders too,
## so nothing is started and no process outlives this check. Every row is an assertion. Held:
##   1. A valid word reaches the proxy of the first spawn and of each later spawn of the call.
##   2. Several words all reach it, in the order given.
##   3. With no word the proxy is given none.
##   4. A partitioned call keeps the word in the arguments file its children are started from.
##   5. A word in no <channel>:<thread ts> shape ends the call at once with one error, and starts nothing.
## Offline: no model, no socket, and the rig's own trees only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnSessionConversationCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/magic-coordinator" "$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigData/board"
for rigMember in magic-coordinator rig-member-a rig-member-b ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n        proxy calls: %s\n' "$1" "$2" "$3" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/proxy-calls" 2> /dev/null )" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The real spawn-session, over recorders: the proxy writes one line a call (its words), the parent's start writes the arguments file its children are
## started from, one word a line, and the parent's launch starts no watcher.
rigRun(){ ## --spawn-session arguments... -- its output and, on the last line, its status
	: > "$rigTmp/proxy-calls" ; : > "$rigTmp/partition-args"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" || exit 98
			. "$RIG_FN"
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSessionParent.include"
			eval "$( declare -f DistroAgentsTools | LC_ALL=C sed "1s/^DistroAgentsTools /rigOriginalTools /" )"
			DistroAgentsTools(){
				case "$1" in
					--intern-op-agent-spawn-proxy)
						cat > /dev/null
						printf "%s\n" "$*" >> "$RIG_TMP/proxy-calls"
						printf "SESSION_ID=rig-stub-session\n"
					;;
					*) rigOriginalTools "$@" ;;
				esac
			}
			AgentsToolsSpawnSessionParentStart(){
				local startFile=""
				AgentsSpawnPartitionFileInto startFile "$MMDAPP" "$1" args || return 1
				LC_ALL=C tr "\0" "\n" < "$startFile" > "$RIG_TMP/partition-args"
				printf "rig-child-%s\n" "$2"
			}
			AgentsToolsSpawnSessionParentLaunch(){ return 0 ; }
			rigStatus=0
			DistroAgentsTools --spawn-session "$@" < /dev/null || rigStatus=$?
			printf "RIG_STATUS=%s\n" "$rigStatus"
		' rig-run "$@" 2>&1
}
rigCalls(){ LC_ALL=C grep -c . "$rigTmp/proxy-calls" 2> /dev/null || : ; }
rigWith(){ ## text -- how many proxy calls carry it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/proxy-calls" 2> /dev/null || :
}

echo "-- 0. control: the recorder is the proxy of the call --"
rigOut="$( rigRun --routine-default rig-member-a )"
rigAssert "the recorder took both proxy calls, each led by the proxy's own operation" "$( rigCalls ):$( LC_ALL=C grep -c '^--intern-op-agent-spawn-proxy ' "$rigTmp/proxy-calls" )" "2:2"

echo "-- 1. a valid word reaches every spawn of the call --"
rigOut="$( rigRun --routine-default --conversation CRIGREQ01:1700000000.000500 rig-member-a )"
rigAssert "the call ends well and starts two spawns, the executor and the member" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^RIG_STATUS=0$' ):$( rigCalls )" "1:2"
rigAssert "the first spawn, which starts the session, carries the word" "$( LC_ALL=C sed -n 1p "$rigTmp/proxy-calls" | LC_ALL=C grep -c -F -- '--conversation CRIGREQ01:1700000000.000500 --session-new' )" "1"
rigAssert "the later spawn, which joins it, carries the word as well" "$( LC_ALL=C sed -n 2p "$rigTmp/proxy-calls" | LC_ALL=C grep -c -F -- '--conversation CRIGREQ01:1700000000.000500' )" "1"
rigAssert "both calls carry it once" "$( rigWith '--conversation CRIGREQ01:1700000000.000500' )" "2"

echo "-- 2. several words all reach it, in order --"
rigOut="$( rigRun --routine-default --conversation CRIGREQ01:1700000000.000500 --conversation CRIGREQ02:1700000000.000600 rig-member-a )"
rigAssert "each call carries both, in the order given" "$( rigWith '--conversation CRIGREQ01:1700000000.000500 --conversation CRIGREQ02:1700000000.000600' )" "2"

echo "-- 3. no word, none given --"
rigOut="$( rigRun --routine-default rig-member-a )"
rigAssert "the call ends well and no proxy call carries --conversation" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^RIG_STATUS=0$' ):$( rigCalls ):$( rigWith '--conversation' )" "1:2:0"

echo "-- 4. a partitioned call keeps the word for its children --"
rigOut="$( rigRun --routine-default --conversation CRIGREQ01:1700000000.000500 rig-member-a rig-member-b )"
rigAssert "the arguments file the children are started from names the word, after its flag" "$( LC_ALL=C grep -x -A1 -e '--conversation' "$rigTmp/partition-args" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "--conversation CRIGREQ01:1700000000.000500 "
rigAssert "and the call itself started no spawn of its own" "$( rigCalls )" "0"

echo "-- 5. a word in no shape is refused, and nothing starts --"
rigOut="$( rigRun --routine-default --conversation 'not a thread' rig-member-a )"
rigAssert "one error names the word, the call fails, and no spawn is made" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- '--conversation requires <channel>:<thread-ts>, got: not a thread' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^RIG_STATUS=1$' ):$( rigCalls )" "1:1:0"
rigOut="$( rigRun --routine-default rig-member-a --conversation )"
rigAssert "a flag with no word is refused the same way" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- '--conversation requires <channel>:<thread-ts>' ):$( rigCalls )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN SESSION CONVERSATION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SESSION_CONVERSATION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
