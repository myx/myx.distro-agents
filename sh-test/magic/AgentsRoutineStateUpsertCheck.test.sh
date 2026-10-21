#!/usr/bin/env bash
## Behavioural check on the locked document's updates (F6.2 of the refactorings epic, open-names 32, settled by the
## owner): the spawner takes the routine lock at start and gives it back at the session's end. Participants never lock
## or unlock: they update the locked document with ONE general operation, ThisSession's `--update-routine-state`
## (DistroAgentsSession.fn.sh), as often as they have updates, and the tooling commits and pushes each update before the
## tool returns. The session knows its routine and the document it locked, so the call names neither a routine nor a
## path, and any participant of a locked session may make it. The per-routine `--magic-<routine>-state-upsert` operations
## retire with no alias; the old `--magic-<routine>-state-and-lock-upsert` and `--magic-<routine>-close-state-and-unlock`
## retire under the shim rule (MAGIC.md, "A superseded operation name stays as a working shim"): gone from the help,
## still answered by the dispatcher.
## Held, for the four routines that lock today (advance, daily, grooming, retro) and the morning review:
##   1. a run of the session that holds the lock updates its document through `--update-routine-state`, with no routine
##      name or path: the note holds the new text, and the team data's remote holds one commit more, with that text,
##      when the call returns
##   2. a participant of that session, another member whose record carries no lock of its own, updates it too
##   3. the lock-owned fields (type, from, date, owner, state, recheck-date, session-id) stay as the spawner left them,
##      whatever the content gives; header edits (`--header:upsert:`, `--header:remove:`) change the stored record's own fields
##   4. the morning review keeps its cut-off in its locked state: the librarian's session sets `last_reviewed_ts` through it
##   5. refused, with its reason and nothing written: a call from no session, a session that holds no lock, a lock given
##      back, a session holding several documents without `--document`; `--document` names the one
##   6. the per-routine `--magic-<routine>-state-upsert` and `--magic-morning-review-state-advance` answer `invalid option`
##   7. the old `-state-and-lock-upsert` and `-close-state-and-unlock` are gone from the help, and still answered
## Offline: the git remote is a bare repository of this rig; a fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigHelp="$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigSession" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSession"
[ -f "$rigHelp" ] || rigRefuse "the help of the tool is not in the package: $rigHelp"
command -v git > /dev/null 2>&1 || rigRefuse "no git on PATH, so no remote can be made"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineStateUpsertCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome"
for rigMember in magic-coordinator magic-librarian keeper-rig ; do
	mkdir -p "$rigTmp/skills/$rigMember"
	printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl" ; chmod +x "$rigTmp/bin/curl"
printf '[user]\n\temail = rig@example.invalid\n\tname = rig\n' > "$rigHome/.gitconfig"
rigGit(){ env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" git "$@" ; }
rigNotes="advance:note-20260809T154715Z-advance-state-and-lock.md daily:note-20260811T120000Z-daily-state-and-lock.md grooming:note-20260809T154332Z-grooming-state-and-lock.md retro:note-20260811T120000Z-retro-state-and-lock.md"
rigMrNote="note-20261008T000000Z-morning-review-state.md"
## The team data: a clone of the rig's own bare remote, holding each routine's note, each locked by its own session.
rigGit init -q --bare "$rigTmp/remote.git" || rigRefuse "could not make the rig's bare remote"
rigGit clone -q "$rigTmp/remote.git" "$rigData" 2> /dev/null || rigRefuse "could not clone the rig's remote"
mkdir -p "$rigData/inboxes/magic-coordinator/incoming" "$rigData/inboxes/magic-librarian/incoming" "$rigData/board"
rigSeedNote(){ ## member, note, state word, session id
	printf -- '---\ntype: note\nfrom: %s\nowner: %s\nrecheck-date: 2099-01-01 00:00 +0000\nstate: %s-running\nsession-id: %s\nlast_reviewed_ts: 100\n---\n\nThe state of %s.\n' "$1" "$1" "$3" "$4" "$3" > "$rigData/inboxes/$1/incoming/$2"
}
for rigPair in $rigNotes ; do rigSeedNote magic-coordinator "${rigPair#*:}" "${rigPair%%:*}" "rig-sess-${rigPair%%:*}" ; done
rigSeedNote magic-librarian "$rigMrNote" morning-review rig-sess-mr
rigSeedNote magic-coordinator note-20261001T000000Z-rig-a-state.md rig-a rig-sess-multi
rigSeedNote magic-coordinator note-20261001T000000Z-rig-b-state.md rig-b rig-sess-multi
rigSeedNote magic-coordinator note-20261001T000000Z-rig-done-state.md rig-done rig-sess-done
sed -i.bak 's/^state: rig-done-running$/state: rig-done-finished/' "$rigData/inboxes/magic-coordinator/incoming/note-20261001T000000Z-rig-done-state.md" && rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261001T000000Z-rig-done-state.md.bak"
rigGit -C "$rigData" add -A && rigGit -C "$rigData" commit -q -m seed && rigGit -C "$rigData" push -q origin HEAD 2> /dev/null || rigRefuse "could not seed the rig's remote"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigTmp/remote.git" > "$rigWs/.local/.agents/magic-team.agent.env"
## The records of the runs: the run that took the lock carries `routine-lock:`, a participant's record carries none.
rigRecord(){ ## member, run id, session id, routine-lock value or nothing
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	{ printf -- '---\nowner: %s\nsession-id: %s\nspawn-id: %s\n' "$1" "$3" "$2" ; [ -z "$4" ] || printf 'routine-lock: %s\n' "$4" ; printf -- '---\n\nrig\n' ; } > "$rigWs/.local/agents/spawned/$1/$2.spawn.md"
}
for rigPair in $rigNotes ; do
	rigRecord magic-coordinator "rig-run-${rigPair%%:*}" "rig-sess-${rigPair%%:*}" "inbox:magic-coordinator:${rigPair#*:}"
	rigRecord keeper-rig "rig-run-${rigPair%%:*}-p" "rig-sess-${rigPair%%:*}" ""
done
rigRecord magic-librarian rig-run-mr rig-sess-mr "inbox:magic-librarian:$rigMrNote"
rigRecord magic-coordinator rig-run-multi rig-sess-multi "inbox:magic-coordinator:note-20261001T000000Z-rig-a-state.md,inbox:magic-coordinator:note-20261001T000000Z-rig-b-state.md"
rigRecord magic-coordinator rig-run-done rig-sess-done "inbox:magic-coordinator:note-20261001T000000Z-rig-done-state.md"
rigRecord magic-coordinator rig-run-nolock rig-sess-nolock ""

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call of ThisSession as a run of a session, rc in <name>.rc; no run id: a call from no session.
rigUpdate(){ ## result name, run id (or -), acting member, standard input text, arguments...
	local callName="$1" callRun="$2" callMember="$3" callIn="$4" callRc=0 callEnv=()
	shift 4
	[ "$callRun" = "-" ] || callEnv=( MDAT_SPAWN_SESSION_ID="$callRun" MDAT_SPAWN_AGENT="$callMember" )
	( cd "$rigWs" && printf '%s' "$callIn" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" ${callEnv[@]+"${callEnv[@]}"} \
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigSession" --update-routine-state "$@" ) > "$rigTmp/$callName.out" 2> "$rigTmp/$callName.err" || callRc=$?
	printf '%s' "$callRc" > "$rigTmp/$callName.rc"
}
rigCall(){ ## result name, operation words... -- one call of the tool as magic-coordinator's console run; rc in <name>.rc
	local callName="$1" callRc=0
	shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-coordinator \
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigTool" "$@" ) > "$rigTmp/$callName.out" 2> "$rigTmp/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigTmp/$callName.rc"
}
rigInvalid(){ ## result name, operation -- yes where the call answered `invalid option` naming it
	if LC_ALL=C grep -q -F -- "invalid option: $2" "$rigTmp/$1.err" "$rigTmp/$1.out" 2> /dev/null ; then printf yes ; else printf no ; fi
}
rigNotePath(){ ## member, note
	printf '%s/inboxes/%s/incoming/%s' "$rigData" "$1" "$2"
}
rigField(){ ## member, note, field -- the first value of a frontmatter field of the note
	LC_ALL=C awk -v want="$3: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$( rigNotePath "$1" "$2" )" 2> /dev/null
}

echo "-- 1. a run of the locking session updates its document with no routine name or path; committed and pushed --"
rigPushed=""
for rigPair in $rigNotes ; do
	rigRoutine="${rigPair%%:*}" ; rigNote="${rigPair#*:}"
	rigBefore="$( rigGit -C "$rigTmp/remote.git" rev-list --count HEAD 2> /dev/null )"
	rigUpdate "update-$rigRoutine" "rig-run-$rigRoutine" magic-coordinator "$( printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: %s-running\nsession-id: %s\n---\n\nRIG-STATE-UPDATE of %s.\n' "$rigRoutine" "rig-sess-$rigRoutine" "$rigRoutine" )"
	rigAfter="$( rigGit -C "$rigTmp/remote.git" rev-list --count HEAD 2> /dev/null )"
	rigRemoteText="$( rigGit -C "$rigTmp/remote.git" show "HEAD:inboxes/magic-coordinator/incoming/$rigNote" 2> /dev/null | LC_ALL=C grep -c -F "RIG-STATE-UPDATE of $rigRoutine" )"
	rigLocalText="$( LC_ALL=C grep -c -F "RIG-STATE-UPDATE of $rigRoutine" "$( rigNotePath magic-coordinator "$rigNote" )" 2> /dev/null )"
	[ "$( cat "$rigTmp/update-$rigRoutine.rc" ):${rigLocalText:-0}:$(( ${rigAfter:-0} - ${rigBefore:-0} )):${rigRemoteText:-0}" = "0:1:1:1" ] && rigPushed="$rigPushed $rigRoutine"
done
rigAssert "the routines whose update is in the note, one commit more on the remote, with it" "${rigPushed# }" "advance daily grooming retro"

echo "-- 2. a participant of the session updates it too --"
rigUpdate participant rig-run-daily-p keeper-rig "$( printf -- '---\nstate: x\n---\n\nRIG-FROM-PARTICIPANT.\n' )"
rigAssert "the participant's update is in the daily note" "$( cat "$rigTmp/participant.rc" ):$( LC_ALL=C grep -c -F 'RIG-FROM-PARTICIPANT.' "$( rigNotePath magic-coordinator note-20260811T120000Z-daily-state-and-lock.md )" )" "0:1"

echo "-- 3. the lock-owned fields stay; header edits change the stored record --"
rigUpdate keep rig-run-retro magic-coordinator "$( printf -- '---\nstate: retro-finished\nsession-id: hijack\nowner: someone\nrecheck-date: 2000-01-01 00:00 +0000\n---\n\nRIG-KEEP.\n' )"
rigAssert "state, session-id, owner and recheck-date as the spawner left them" "$( cat "$rigTmp/keep.rc" ):$( rigField magic-coordinator note-20260811T120000Z-retro-state-and-lock.md state ):$( rigField magic-coordinator note-20260811T120000Z-retro-state-and-lock.md session-id ):$( rigField magic-coordinator note-20260811T120000Z-retro-state-and-lock.md owner )" "0:retro-running:rig-sess-retro:magic-coordinator"
rigAssert "the recheck-date is the lock's, not the content's" "$( rigField magic-coordinator note-20260811T120000Z-retro-state-and-lock.md recheck-date | LC_ALL=C grep -c -F '2000-01-01' )" "0"
rigUpdate hdr rig-run-grooming magic-coordinator "" --header:upsert:cut-off:42 --header:upsert:label:a:b
rigAssert "an upserted header is in the note, the value's colon kept" "$( cat "$rigTmp/hdr.rc" ):$( rigField magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md cut-off ):$( rigField magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md label )" "0:42:a:b"
rigUpdate hdr2 rig-run-grooming magic-coordinator "" --header:upsert:cut-off:43 --header:remove:label
rigAssert "a second upsert replaces, a removed header is gone, the state stays" "$( cat "$rigTmp/hdr2.rc" ):$( rigField magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md cut-off ):$( LC_ALL=C grep -c '^label: ' "$( rigNotePath magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md )" ):$( rigField magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md state )" "0:43:0:grooming-running"

echo "-- 4. the morning review keeps its cut-off in its locked state --"
rigUpdate mr rig-run-mr magic-librarian "" --header:upsert:last_reviewed_ts:200
rigAssert "the librarian's session sets last_reviewed_ts, its lock fields as they were" "$( cat "$rigTmp/mr.rc" ):$( rigField magic-librarian "$rigMrNote" last_reviewed_ts ):$( LC_ALL=C grep -c '^last_reviewed_ts: ' "$( rigNotePath magic-librarian "$rigMrNote" )" ):$( rigField magic-librarian "$rigMrNote" state ):$( rigField magic-librarian "$rigMrNote" session-id )" "0:200:1:morning-review-running:rig-sess-mr"
rigAssert "committed and pushed with the value" "$( rigGit -C "$rigTmp/remote.git" show "HEAD:inboxes/magic-librarian/incoming/$rigMrNote" 2> /dev/null | LC_ALL=C grep -c -F 'last_reviewed_ts: 200' )" "1"

echo "-- 5. refused, with its reason, nothing written --"
rigUpdate nosession - magic-coordinator "x"
rigAssert "a call from no session"                     "$( cat "$rigTmp/nosession.rc" ):$( LC_ALL=C grep -c -F 'no session the tooling spawned' "$rigTmp/nosession.err" )" "1:1"
rigUpdate nolock rig-run-nolock magic-coordinator "x"
rigAssert "a session that holds no lock"               "$( cat "$rigTmp/nolock.rc" ):$( LC_ALL=C grep -c -F 'holds no routine lock' "$rigTmp/nolock.err" )" "1:1"
rigUpdate done rig-run-done magic-coordinator "$( printf -- '---\nstate: x\n---\n\nRIG-AFTER-UNLOCK.\n' )"
rigAssert "a lock given back"                          "$( cat "$rigTmp/done.rc" ):$( LC_ALL=C grep -c -F 'has been given back' "$rigTmp/done.err" ):$( LC_ALL=C grep -c -F 'RIG-AFTER-UNLOCK.' "$( rigNotePath magic-coordinator note-20261001T000000Z-rig-done-state.md )" )" "1:1:0"
rigUpdate multi rig-run-multi magic-coordinator "$( printf -- '---\nstate: x\n---\n\nRIG-MULTI-A.\n' )"
rigAssert "several documents and no --document"        "$( cat "$rigTmp/multi.rc" ):$( LC_ALL=C grep -c -F -- '--document <note>' "$rigTmp/multi.err" ):$( LC_ALL=C grep -c -F 'RIG-MULTI-A.' "$( rigNotePath magic-coordinator note-20261001T000000Z-rig-a-state.md )" )" "1:1:0"
rigUpdate multi2 rig-run-multi magic-coordinator "$( printf -- '---\nstate: x\n---\n\nRIG-MULTI-B.\n' )" --document note-20261001T000000Z-rig-b-state.md
rigAssert "--document names the one"                   "$( cat "$rigTmp/multi2.rc" ):$( LC_ALL=C grep -c -F 'RIG-MULTI-B.' "$( rigNotePath magic-coordinator note-20261001T000000Z-rig-b-state.md )" ):$( LC_ALL=C grep -c -F 'RIG-MULTI-B.' "$( rigNotePath magic-coordinator note-20261001T000000Z-rig-a-state.md )" )" "0:1:0"
rigUpdate multi3 rig-run-multi magic-coordinator "x" --document note-20261001T000000Z-nothing.md
rigAssert "a --document the session did not lock"      "$( cat "$rigTmp/multi3.rc" ):$( LC_ALL=C grep -c -F 'did not lock a document named' "$rigTmp/multi3.err" )" "1:1"
rigUpdate empty rig-run-advance magic-coordinator ""
rigAssert "empty content erases nothing"               "$( cat "$rigTmp/empty.rc" ):$( LC_ALL=C grep -c -F 'RIG-STATE-UPDATE of advance' "$( rigNotePath magic-coordinator note-20260809T154715Z-advance-state-and-lock.md )" )" "1:1"

echo "-- 6. the per-routine upserts and the morning review's advance are retired --"
rigStill=""
for rigOld in --magic-advance-state-upsert --magic-daily-state-upsert --magic-grooming-state-upsert --magic-retro-state-upsert --magic-heartbeat-state-upsert --magic-morning-review-state-advance ; do
	rigCall old "$rigOld" magic-coordinator
	[ "$( rigInvalid old "$rigOld" )" = yes ] || rigStill="$rigStill $rigOld"
done
rigAssert "each answers invalid option"                "[${rigStill# }]" "[]"
rigInHelp=""
for rigOld in --magic-advance-state-upsert --magic-daily-state-upsert --magic-grooming-state-upsert --magic-retro-state-upsert --magic-heartbeat-state-upsert --magic-morning-review-state-advance ; do
	LC_ALL=C grep -q -F -- "$rigOld" "$rigHelp" && rigInHelp="$rigInHelp $rigOld"
done
rigAssert "none stands in the help"                    "[${rigInHelp# }]" "[]"
rigAssert "the new operation does"                     "$( LC_ALL=C grep -c -F -- '--update-routine-state' "$rigHelp" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/stands/' )" "stands"

echo "-- 7. the old operations retire under the shim rule --"
rigInHelp=""
rigGone=""
for rigPair in $rigNotes ; do
	rigRoutine="${rigPair%%:*}"
	rigOlds="--magic-$rigRoutine-state-and-lock-upsert --magic-$rigRoutine-close-state-and-unlock"
	for rigOld in $rigOlds ; do
		LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh $rigOld " "$rigHelp" && rigInHelp="$rigInHelp $rigOld"
		LC_ALL=C grep -q -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigOld" "$rigHelp" && rigInHelp="$rigInHelp $rigOld"
		rigCall old "$rigOld"
		[ "$( rigInvalid old "$rigOld" )" = no ] || rigGone="$rigGone $rigOld"
	done
done
rigAssert "none of them stands in the help any more"   "[${rigInHelp# }]" "[]"
rigAssert "the dispatcher still answers every one of them" "[${rigGone# }]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE STATE UPSERT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_STATE_UPSERT: OK (%d assertions, offline)\n' "$rigPassCount"
