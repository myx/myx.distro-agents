#!/usr/bin/env bash
## Behavioural check on AgentsToolsRequestThreadInto (sh-lib/comms/AgentsTools.SessionThreads.include), the one definition of the request thread of a run. Held:
##   1. THE ENV: the one word of MDAT_CONVERSATION_THREADS that is also MDAT_SESSION_THREAD sets the variable. Spaces around the word are ignored.
##   2. THE RECORD: with the env empty, the `conversation-threads:` and `session-thread:` lines of the run's spawn record are read, and only inside its frontmatter.
##   3. A THREAD JOINED FROM A BRIEF IS NO REQUEST: a word that is not the run's session thread answers 1, in the env, the sandbox record and the stored record.
##   4. NONE OR SEVERAL give 1 and set nothing. So does a word that is no `<CHANNEL>:<digits.digits>`.
##   5. THE MEMO: the record is read once for a run, and read again for another run.
##   6. NO FORK: the whole read works in a shell whose PATH holds no program, so it used no awk and no subshell.
##   7. THE STORED RECORD: with no sandbox root, the record is found as production finds it (AgentsSpawnRecordFindInto).
## Red before the change: a word of conversation-threads that is no session thread is answered as the request.
## Offline: temp spawn records, no Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/comms/AgentsTools.SessionThreads.include" ] || rigRefuse "the session-threads include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRequestThreadIntoCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## A rig inherits its runner's run, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS ; do unset "$rigDrop" 2> /dev/null || : ; done
export MMDAPP="$rigTmp" MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/sandbox"
mkdir -p "$MDAT_SPAWN_SANDBOX_ROOT" || rigRefuse "the rig could not make its sandbox"
. "$rigPackage/sh-lib/comms/AgentsTools.SessionThreads.include" || exit 1
rigRecord(){ ## run, the frontmatter lines after the opening mark, one an argument
	local recordRun="$1" recordLine
	shift
	{ printf -- '---\n' ; for recordLine in "$@" ; do printf '%s\n' "$recordLine" ; done ; printf -- '---\nbody\n' ; } > "$MDAT_SPAWN_SANDBOX_ROOT/$recordRun.spawn.md"
}
## One call: prints `<rc>:<value>`, the value empty where nothing was set.
rigThread(){
	local threadOut="" threadRc=0
	AgentsToolsRequestThreadInto threadOut 2> /dev/null || threadRc=$?
	printf '%s:%s' "$threadRc" "$threadOut"
}

echo "-- 1. the env --"
rigAssert "one word in the env that is the session thread" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:1794216240.000100' MDAT_SESSION_THREAD='C0RIG0001:1794216240.000100' rigThread )" "0:C0RIG0001:1794216240.000100"
rigAssert "spaces around the word are ignored" "$( MDAT_CONVERSATION_THREADS=' C0RIG0001:1794216240.000100  ' MDAT_SESSION_THREAD='C0RIG0001:1794216240.000100' rigThread )" "0:C0RIG0001:1794216240.000100"
rigAssert "a direct conversation id is a word too" "$( MDAT_CONVERSATION_THREADS='D0RIG0002:1794216240.000100' MDAT_SESSION_THREAD='D0RIG0002:1794216240.000100' rigThread )" "0:D0RIG0002:1794216240.000100"

echo "-- 2. the record --"
rigRecord rig-run-one 'session: one' 'conversation-threads: C0RIG0001:1794216240.000100 ' 'session-thread: C0RIG0001:1794216240.000100' 'other: x'
rigAssert "the lines of the record, the env empty" "$( MDAT_SPAWN_SESSION_ID=rig-run-one rigThread )" "0:C0RIG0001:1794216240.000100"
rigRecord rig-run-body 'session: body'
printf 'conversation-threads: C0RIG0009:1794216240.000100\nsession-thread: C0RIG0009:1794216240.000100\n' >> "$MDAT_SPAWN_SANDBOX_ROOT/rig-run-body.spawn.md"
rigAssert "a line after the frontmatter is not read" "$( MDAT_SPAWN_SESSION_ID=rig-run-body rigThread )" "1:"
rigAssert "a run with no record answers 1" "$( MDAT_SPAWN_SESSION_ID=rig-run-none rigThread )" "1:"
rigAssert "a caller with no run answers 1" "$( rigThread )" "1:"
rigAssert "the env wins over the record" "$( MDAT_SPAWN_SESSION_ID=rig-run-one MDAT_CONVERSATION_THREADS='C0RIG0002:1794216999.000100' MDAT_SESSION_THREAD='C0RIG0002:1794216999.000100' rigThread )" "0:C0RIG0002:1794216999.000100"
rigAssert "the list from the env and the session thread from the record" "$( MDAT_SPAWN_SESSION_ID=rig-run-one MDAT_CONVERSATION_THREADS='C0RIG0001:1794216240.000100' rigThread )" "0:C0RIG0001:1794216240.000100"

echo "-- 3. a thread joined from a brief is no request --"
rigRecord rig-run-link 'conversation-threads: C0RIGLNK1:1794216240.000800' 'session-thread: C0RIG0001:1794216240.000100'
rigAssert "the record names a permalink thread and another session thread" "$( MDAT_SPAWN_SESSION_ID=rig-run-link rigThread )" "1:"
rigRecord rig-run-nosession 'conversation-threads: C0RIG0001:1794216240.000100'
rigAssert "the record names no session thread" "$( MDAT_SPAWN_SESSION_ID=rig-run-nosession rigThread )" "1:"
rigAssert "the env names a thread that is not the session thread" "$( MDAT_CONVERSATION_THREADS='C0RIGLNK1:1794216240.000800' MDAT_SESSION_THREAD='C0RIG0001:1794216240.000100' rigThread )" "1:"
rigAssert "the env names a thread and no session thread is known" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:1794216240.000100' rigThread )" "1:"

echo "-- 4. none, several and a bad word --"
rigRecord rig-run-two 'conversation-threads: C0RIG0001:1794216240.000100 C0RIG0002:1794216241.000100' 'session-thread: C0RIG0001:1794216240.000100'
rigAssert "two words in the record are no request" "$( MDAT_SPAWN_SESSION_ID=rig-run-two rigThread )" "1:"
rigAssert "two words in the env are no request" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:1.1 C0RIG0002:2.2' MDAT_SESSION_THREAD='C0RIG0001:1.1' rigThread )" "1:"
rigAssert "a channel with no ts" "$( MDAT_CONVERSATION_THREADS='C0RIG0001' MDAT_SESSION_THREAD='C0RIG0001' rigThread )" "1:"
rigAssert "a ts with letters" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:12ab.5' MDAT_SESSION_THREAD='C0RIG0001:12ab.5' rigThread )" "1:"
rigAssert "a lowercase channel" "$( MDAT_CONVERSATION_THREADS='c0rig0001:1.1' MDAT_SESSION_THREAD='c0rig0001:1.1' rigThread )" "1:"
rigAssert "a ts with two dots" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:1.2.3' MDAT_SESSION_THREAD='C0RIG0001:1.2.3' rigThread )" "1:"
rigAssert "a third part" "$( MDAT_CONVERSATION_THREADS='C0RIG0001:1.1:9' MDAT_SESSION_THREAD='C0RIG0001:1.1:9' rigThread )" "1:"

echo "-- 5. the memo --"
rigRecord rig-run-memo 'conversation-threads: C0RIG0001:1.100000' 'session-thread: C0RIG0001:1.100000'
rigAssert "a first read, the memo kept, and a changed record read from the memo" "$(
	MDAT_SPAWN_SESSION_ID=rig-run-memo ; rigThread > /dev/null ; rigRecord rig-run-memo 'conversation-threads: C0RIG0002:2.200000' 'session-thread: C0RIG0002:2.200000' ; rigThread )" "0:C0RIG0001:1.100000"
rigAssert "another run reads its own record again" "$(
	MDAT_SPAWN_SESSION_ID=rig-run-memo ; rigThread > /dev/null ; MDAT_SPAWN_SESSION_ID=rig-run-one ; rigThread )" "0:C0RIG0001:1794216240.000100"
rigAssert "a run with no thread is memoised as none" "$(
	rigRecord rig-run-quiet 'session: quiet' ; MDAT_SPAWN_SESSION_ID=rig-run-quiet ; rigThread > /dev/null ; rigRecord rig-run-quiet 'conversation-threads: C0RIG0003:3.300000' 'session-thread: C0RIG0003:3.300000' ; rigThread )" "1:"

echo "-- 6. no fork: a shell with no program on its PATH still answers --"
rigAssert "the env, with an empty PATH" "$( PATH="$rigTmp/no-program" ; MDAT_CONVERSATION_THREADS='C0RIG0001:1.1' MDAT_SESSION_THREAD='C0RIG0001:1.1' rigThread )" "0:C0RIG0001:1.1"
rigAssert "the record, with an empty PATH" "$( PATH="$rigTmp/no-program" ; MDAT_SPAWN_SESSION_ID=rig-run-one rigThread )" "0:C0RIG0001:1794216240.000100"
rigAssert "no run, with an empty PATH, answers 1" "$( PATH="$rigTmp/no-program" ; rigThread )" "1:"

echo "-- 7. the stored record, found as production finds it --"
mkdir -p "$rigTmp/.local/agents/spawned/rig-track"
printf -- '---\nsession-id: rig-run-prod\nspawn-id: rig-run-prod\nconversation-threads: C0RIG0001:1794216240.000100\nsession-thread: C0RIG0001:1794216240.000100\n---\nbody\n' > "$rigTmp/.local/agents/spawned/rig-track/rig-run-prod.spawn.md"
printf -- '---\nsession-id: rig-run-plink\nspawn-id: rig-run-plink\nconversation-threads: C0RIGLNK1:1794216240.000800\nsession-thread: C0RIG0001:1794216240.000100\n---\nbody\n' > "$rigTmp/.local/agents/spawned/rig-track/rig-run-plink.spawn.md"
rigAssert "a run whose session thread is its conversation word" "$( unset MDAT_SPAWN_SANDBOX_ROOT ; MDAT_SPAWN_SESSION_ID=rig-run-prod rigThread )" "0:C0RIG0001:1794216240.000100"
rigAssert "a run that joined a permalink thread" "$( unset MDAT_SPAWN_SANDBOX_ROOT ; MDAT_SPAWN_SESSION_ID=rig-run-plink rigThread )" "1:"
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
