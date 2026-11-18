#!/usr/bin/env bash
## Behavioural check on where the CheckList tool keeps a list: through the session owner's one locator,
## AgentsSessionChecklistFileInto, which the Wait's checklist probe already asks. Through the real harness
## (--intern-tool CheckList and --intern-checklist-place), against the locator's own answer, computed here.
## Held:
##   1. a session no record names keeps its list in the session store, where the locator says
##   2. CONTROL, both directions agree: a session a spawn founded keeps its list beside that spawn's
##      record, and the tool's folder and the locator's answer are the same one
##   3. ONE FOLDER: a session whose own record names another session -- the two spellings the tool and the
##      locator used to tell apart -- writes where the locator says, not in its own record's folder
##   4. --intern-checklist-place, the native hook's question, names the folder the tool writes
##   5. the messages are as they were: member, session, counts, no path, no temp file left beside a list,
##      and a bad write refused with the list unchanged
## Offline: MMDAPP, HOME and the skillset are this check's own temp tree; nothing reaches a host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
. "$rigPackage/sh-test/check-fixtures/rig-reply.include.sh" || rigRefuse "the reply fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the temp fixture is missing from the package"
rigTmp="$( rigTempDir AgentsCheckListPlaceCheck )" || rigRefuse "the rig's folder could not be made"
rigTmp="$( cd "$rigTmp" && pwd -P )" || rigRefuse "the rig's folder could not be resolved"
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigStore="$rigWs/.local/agents/sessions"
for rigMember in magic-coordinator magic-developer ; do
	mkdir -p "$rigTmp/skills/$rigMember" || rigRefuse "the rig skillset could not be made"
	printf 'rig %s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" || rigRefuse "the rig skillset could not be made"
done
mkdir -p "$rigStore" "$rigSpawned/rig-found" "$rigSpawned/rig-carried" "$rigTmp/home" || rigRefuse "the rig workspace could not be made"
## A session founded by the spawn rig-found; and a run, rig-carried, whose own record names the session
## rig-found -- the second spelling of the store the tool and the locator used to place differently.
printf -- '---\nsession-id: rig-found\nspawn-id: rig-found\ntracking-name: rig-found\nhost: rig\nowner: magic-coordinator\nstatus: spawn-started\n---\n' > "$rigSpawned/rig-found/rig-found.spawn.md" || rigRefuse "the rig record could not be made"
printf -- '---\nsession-id: rig-found\nspawn-id: rig-carried\ntracking-name: rig-carried\nhost: rig\nowner: magic-developer\nstatus: spawn-started\n---\n' > "$rigSpawned/rig-carried/rig-carried.spawn.md" || rigRefuse "the rig record could not be made"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigEnv(){ ## session id, member -- runs the rest of the line in that caller's environment
	local envSession="$1" envMember="$2" ; shift 2
	(
		unset CLAUDE_CODE_SESSION_ID CLAUDE_CODE_ENTRYPOINT MDAT_MCP_SERVED_MARKER MDAT_DATA_ROOT MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS
		export HOME="$rigTmp/home" MMDAPP="$rigWs" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$envMember"
		[ -z "$envSession" ] || export MDAT_SESSION_ID="$envSession"
		export MDAT_SPAWN_SESSION_ID="$envSession" MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/$envSession"
		cd "$rigWs" && "$@"
	)
}
rigCall(){ ## session id, member, arguments JSON -- the tool's own result
	printf '%s' "$3" | rigEnv "$1" "$2" "$BASH" "$rigHarness" --intern-tool CheckList 2> /dev/null | rigReplyBare
}
rigPlace(){ ## session id, member -- the hook's answer, or the word none
	rigEnv "$1" "$2" "$BASH" "$rigHarness" --intern-checklist-place < /dev/null 2> /dev/null | LC_ALL=C sed -n 's/^CHECKLIST-PLACE: //p'
}
## THE LOCATOR'S OWN ANSWER, asked here rather than the tool's: one shell, the owner's include, its answer.
rigLocator(){ ## session id, member -- the file the session owner says holds the list
	rigEnv "$1" "$2" "$BASH" -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.include" || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CheckListSeed.include" || exit 1
		AgentsSessionChecklistFileInto locatorFile "$1" "$2" || exit 1
		printf "%s\n" "${locatorFile%/*}"' rigLocator "$1" "$2"
}
rigKept(){ ## path under the rig workspace -- the list as kept, or the word none
	[ -f "$rigWs/$1" ] || { printf 'none' ; return 0 ; }
	cat "$rigWs/$1"
}
rigLeftovers(){ ## -- how many temp files a write left beside a list
	find "$rigWs" -name '*.checklist.md.*' | LC_ALL=C grep -c . || :
}
rigHolds(){ ## text, fragment -- yes where the text holds it
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigItem='[{"content":"Check the idiom","status":"completed","activeForm":"Checking the idiom"}]'
rigItemMd='- [x] Check the idiom'

echo "-- 1. a session no record names keeps its list in the session store --"
rigOut="$( rigCall rig-sess magic-developer '{"todos":'"$rigItem"'}' )"
rigAssert "the list is kept in the session's own folder, the locator's answer" "$( rigKept '.local/agents/sessions/rig-sess/magic-developer.checklist.md' )" "$rigItemMd"
rigAssert "the locator agrees" "$( rigLocator rig-sess magic-developer )" "$rigStore/rig-sess"
rigAssert "the hook names the same folder" "$( rigPlace rig-sess magic-developer )" "$rigStore/rig-sess"

echo "-- 2. control, both directions agree: a session a spawn founded --"
rigOut="$( rigCall rig-found magic-coordinator '{"todos":'"$rigItem"'}' )"
rigAssert "its list is kept beside its spawn record" "$( rigKept '.local/agents/spawned/rig-found/magic-coordinator.checklist.md' )" "$rigItemMd"
rigAssert "the locator agrees" "$( rigLocator rig-found magic-coordinator )" "$rigSpawned/rig-found"
rigAssert "the hook agrees" "$( rigPlace rig-found magic-coordinator )" "$rigSpawned/rig-found"
rigAssert "the answer names the member, the session and the count" "$( rigHolds "$rigOut" 'checklist of magic-coordinator in session rig-found now holds 1 item(s): 0 pending, 0 in progress, 1 completed' )" "yes"
rigAssert "the answer names no path" "$( rigHolds "$rigOut" "$rigSpawned" )" "no"
rigAssert "no temporary file is left beside it" "$( rigLeftovers )" "0"

echo "-- 3. one folder: a session whose own record names another session --"
rigOut="$( rigCall rig-carried magic-developer '{"todos":'"$rigItem"'}' )"
rigAssert "the locator places it in the named session's founder folder" "$( rigLocator rig-carried magic-developer )" "$rigSpawned/rig-found"
rigAssert "the list is kept where the locator says" "$( rigKept '.local/agents/spawned/rig-found/magic-developer.checklist.md' )" "$rigItemMd"
rigAssert "and not in its own record's folder" "$( rigKept '.local/agents/spawned/rig-carried/magic-developer.checklist.md' )" "none"
rigAssert "the hook names the folder the tool wrote" "$( rigPlace rig-carried magic-developer )" "$rigSpawned/rig-found"

echo "-- 4. a read and the leftovers are as they were --"
rigAssert "a read names the member and the session on its first line" "$( rigCall rig-sess magic-developer '{}' | LC_ALL=C sed -n '1p' )" "CHECKLIST of magic-developer in session rig-sess:"
rigAssert "and it reads the list it wrote" "$( rigHolds "$( rigCall rig-sess magic-developer '{}' )" "$rigItemMd" )" "yes"

echo "-- 5. a bad write is refused, and the list kept before stays --"
rigOut="$( rigCall rig-sess magic-developer '{"todos":[{"content":"x","status":"done","activeForm":"Doing x"}]}' )"
rigAssert "refused as before, saying nothing was written" "$( rigHolds "$rigOut" 'status must be pending, in_progress or completed, got: done. Nothing was written.' )" "yes"
rigAssert "the refused write left the list as it was" "$( rigKept '.local/agents/sessions/rig-sess/magic-developer.checklist.md' )" "$rigItemMd"
rigOut="$( rigCall '' magic-developer '{}' )"
rigAssert "a caller with no session at all is still refused, naming RootSession" "$( rigHolds "$rigOut" 'call RootSession operation=mint' )" "yes"
rigAssert "no write or read left a temp file" "$( rigLeftovers )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CHECKLIST PLACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CHECKLIST_PLACE: OK (%d assertions, offline)\n' "$rigPassCount"
