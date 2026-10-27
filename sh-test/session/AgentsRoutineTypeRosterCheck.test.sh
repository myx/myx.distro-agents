#!/usr/bin/env bash
## Behavioural check on the `<type>-*` and `<type>-?` team-member contracts a routine's `executors` and `invitees`
## carry (20261021-refactorings.sketch.md, `Routines for <type>-* and <type>-? team-members contracts`), run rather
## than read, against a rig machine built here: a member set with two `client-*` members and none of any other
## external type, and routines of the team whose executors or invitees are a wildcard. Held, in the order the
## sketch states the contract:
##   1. the routine list shows the contract AS WRITTEN -- `<executors>` is the file's own frontmatter line, a glob
##      never rewritten to the members it expands to -- and reads a `<type>-*` with members startable, one with no
##      member not startable naming the type, and a `<type>-?` not startable, needing a member named;
##   2. the routine validator accepts `<type>-*` with members and `<type>-?`, and refuses both a `<type>-*` in
##      executors and one in invitees that name no member (a participant type included), in a row that names the
##      type and tells the writer what to pass instead;
##   3. the session spawner resolves the same tokens: a `<type>-*` with no member named partitions the run into one
##      session per member under an agent-less parent, and its parameters carry the resolved members (`MEMBERS=`
##      and `CHILDREN=`); a `<type>-*` that names none is refused with the type in its hint, a `<type>-?` is never
##      auto-selected and is started with the one member the caller names.
## This is the end-to-end check the unit check (AgentsTeamMemberContractCheck, the roster functions alone) and the
## list check (AgentsManagerRoutineListCheck, whose rig carries no wildcard) leave apart. Offline: a fake `curl`
## first on PATH answers every request the tooling makes, so nothing reaches Slack; only the rig's own tree is read
## or written, and no real CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-routine-list"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineTypeRosterCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigSkills="$rigTmp/members"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigHome/.agents/magic-team" "$rigData/board" "$rigSkills"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigTab="$( printf '\t' )"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE RIG MEMBER SET. Two `client-*` members, so a `client-*` names members and a `client-?` has a choice of two;
## no `warden-*` member at all, so a `warden-*` is a type no member carries (fail on NONE). The team itself, and the
## coordinator every routine belongs to.
rigMember(){ ## name
	mkdir -p "$rigSkills/$1"
	printf -- '---\nmaintainers: rig\nattendance: invited\n---\nrig identity\n' > "$rigSkills/$1/$1.basic.md"
	printf '# rig armed\n' > "$rigSkills/$1/$1.armed.md"
}
for rigMemberName in magic-team magic-coordinator client-ndm client-acme ; do rigMember "$rigMemberName" ; done
## A routine file that meets the whole routine contract, its own frontmatter lines given, so the validator's only
## possible row about it is the one this check is about.
rigRoutine(){ ## folder, file name, frontmatter lines
	{
		printf -- '---\ntype: routine\n%s\n---\n' "$3"
		printf '# %s — probe\n\n# Opening steps\n\n- one.\n\n# Steps\n\n- two.\n\n# Closure steps\n\n- three.\n\n# Routine'"'"'s local procedures\n\n- four.\n' "$2"
	} > "$rigSkills/$1/$2"
}
## executors: a wildcard with members, a wildcard with none, and a choice -- the three words of the sketch.
rigRoutine magic-coordinator magic-coordinator.clients.routine.md 'executors: client-*
maintainers: magic-coordinator
requires-session-kind: standalone'
rigRoutine magic-coordinator magic-coordinator.wardens.routine.md 'executors: warden-*
maintainers: magic-coordinator
requires-session-kind: standalone'
rigRoutine magic-coordinator magic-coordinator.one.routine.md 'executors: client-?
maintainers: magic-coordinator
requires-session-kind: standalone'
## The same tokens in `invitees`, the participants' header: a wildcard with members, one with none, a choice, and
## the standing keyword beside them.
rigRoutine magic-coordinator magic-coordinator.receivers.routine.md 'executors: magic-coordinator
maintainers: magic-coordinator
invitees: client-*
requires-session-kind: coworking'
rigRoutine magic-coordinator magic-coordinator.noneinv.routine.md 'executors: magic-coordinator
maintainers: magic-coordinator
invitees: warden-*
requires-session-kind: coworking'
rigRoutine magic-coordinator magic-coordinator.oneinv.routine.md 'executors: magic-coordinator
maintainers: magic-coordinator
invitees: client-?
requires-session-kind: coworking'
rigRoutine magic-coordinator magic-coordinator.present.routine.md 'executors: magic-coordinator
maintainers: magic-coordinator
invitees: all-present-members
requires-session-kind: coworking'
## The console a start runs: it records which member it was started as, and hands back. It says `--cli-configured`
## and writes the launch marker, so the spawn proxy can tell a configured start from a silent no-op.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records who was started.' \
	'cat > /dev/null' \
	'printf "%s\n" "$MDAT_SPAWN_AGENT" >> "$RIG_SCENARIO/started"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigRun(){ ## tool arguments... -- one dispatcher call from the rig machine; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" MDSC_CMD=DistroAgentsTools \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSpawn(){ ## selector, then the members named, if any -- the session spawner asked to start that routine; rc in rigRc, stdout in start.out, stderr in start.err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" MDSC_CMD=DistroAgentsTools \
		bash "$rigTool" --spawn-session --routine "$@" ) > "$rigTmp/start.out" 2> "$rigTmp/start.err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigRowOf(){ ## selector -- that routine's row in the last list output
	LC_ALL=C awk -F'\t' -v wantName="$1" '$1 == "routine" && $2 == wantName { print ; }' "$rigTmp/out"
}
rigFieldOf(){ ## selector, field number -- that field of its row, TABs kept out of it
	rigRowOf "$1" | LC_ALL=C awk -F'\t' -v field="$2" '{ print $field }'
}

echo "-- 1. the routine list shows the contract as written, and reads the three words --"
rigRun "$rigOp"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : )" "0 0"
rigAssert "a row for every routine file: the team's four contract words, and the standing keyword" "$( LC_ALL=C awk -F'\t' '$1 == "routine" { n++ } END { print n + 0 }' "$rigTmp/out" )" "7"
## THE CONTRACT IS THE FILE'S OWN LINE, never the members it expands to: the console offers choices from it, so
## the glob is what a reader must see.
rigAssert "executors shows client-*, warden-* and client-? exactly as the files write them" \
	"$( rigFieldOf magic-coordinator.clients.routine.md 5 ) $( rigFieldOf magic-coordinator.wardens.routine.md 5 ) $( rigFieldOf magic-coordinator.one.routine.md 5 )" \
	"client-* warden-* client-?"
rigAssert "invitees is never folded into the executors column: the participants' glob of each routine stays its own line, and no expanded member name is printed as a contract" \
	"$( rigFieldOf magic-coordinator.receivers.routine.md 5 ) $( LC_ALL=C grep -c -e 'client-acme' -e 'client-ndm' "$rigTmp/out" || : )" "magic-coordinator 0"
## The start word: a `<type>-*` with members starts by itself; one with none, and a `<type>-?`, do not.
rigAssert "a client-* with two members reads startable, and needs nothing named" \
	"$( rigFieldOf magic-coordinator.clients.routine.md 4 ) $( rigFieldOf magic-coordinator.clients.routine.md 10 )" "startable -"
rigAssert "a warden-* with no member reads not startable, and its reason names the type warden and tells what to pass" \
	"$( rigFieldOf magic-coordinator.wardens.routine.md 4 ) $( rigFieldOf magic-coordinator.wardens.routine.md 9 | LC_ALL=C tr '_' ' ' | LC_ALL=C grep -c -E 'type warden.*name the members instead' || : )" "not-startable 1"
rigAssert "a client-? reads not startable too even with two members available, says the members are asked for, and names the type in its reason" \
	"$( rigFieldOf magic-coordinator.one.routine.md 4 ) $( rigFieldOf magic-coordinator.one.routine.md 10 ) $( rigFieldOf magic-coordinator.one.routine.md 9 | LC_ALL=C grep -c -F -- 'client' || : )" "not-startable members 1"
rigAssert "the participants' words are no part of the start word: the invitees globs neither start nor block a routine whose executors is one member" \
	"$( LC_ALL=C awk -F'\t' '$3 == "magic-coordinator" && $2 ~ /\.(receivers|noneinv|oneinv|present)\.routine\.md$/ { printf "%s=%s ", $4, $10 }' "$rigTmp/out" )" "startable=- startable=- startable=- startable=- "

echo "-- 2. the validator holds the same tokens --"
rigCheck(){ ## routine file name -- rc in rigRc, the rows in check.out
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDSC_CMD=DistroAgentsTools \
		bash "$rigTool" --intern-doc-validate routine "$rigSkills/magic-coordinator/$1" ) > "$rigTmp/check.out" 2> "$rigTmp/check.err" || rigRc=$?
}
rigCheck magic-coordinator.clients.routine.md
rigAssert "executors: client-* with members is no fault: rc 0, no row" "$rigRc $( wc -c < "$rigTmp/check.out" | LC_ALL=C tr -d ' ' )" "0 0"
rigCheck magic-coordinator.one.routine.md
rigAssert "executors: client-? is a choice, a legal contract: rc 0, no row" "$rigRc $( wc -c < "$rigTmp/check.out" | LC_ALL=C tr -d ' ' )" "0 0"
rigCheck magic-coordinator.receivers.routine.md
rigAssert "invitees: client-* with members is no fault" "$rigRc $( wc -c < "$rigTmp/check.out" | LC_ALL=C tr -d ' ' )" "0 0"
rigCheck magic-coordinator.oneinv.routine.md
rigAssert "invitees: client-? is a choice, no fault" "$rigRc $( wc -c < "$rigTmp/check.out" | LC_ALL=C tr -d ' ' )" "0 0"
rigCheck magic-coordinator.present.routine.md
rigAssert "invitees: all-present-members is still the participants' keyword, no fault" "$rigRc $( wc -c < "$rigTmp/check.out" | LC_ALL=C tr -d ' ' )" "0 0"
rigCheck magic-coordinator.wardens.routine.md
rigAssert "executors: warden-* with no member is refused: rc 1, one row on line 3, the executors rule, naming the type warden and telling the writer to name the members" \
	"$rigRc $( LC_ALL=C awk -F': ' 'NF >= 2 { n++ } END { print n + 0 }' "$rigTmp/check.out" ) $( LC_ALL=C grep -c -E '\.routine\.md:3: executors: .*type warden.*name the members instead' "$rigTmp/check.out" || : )" "1 1 1"
rigCheck magic-coordinator.noneinv.routine.md
rigAssert "invitees: warden-* with no member is refused too -- the participants' header fails on NONE as executors does -- naming the type and what to pass" \
	"$rigRc $( LC_ALL=C grep -c -E '\.routine\.md:5: invitees: .*type warden.*name the members instead' "$rigTmp/check.out" || : )" "1 1"

echo "-- 3. the session spawner resolves them, and says the members it resolved --"
rigSpawn magic-coordinator.clients.routine.md
rigAssert "client-* with two members and none named starts by itself: rc 0, an agent-less parent session, one child session per member, and both members in MEMBERS=" \
	"$rigRc $( LC_ALL=C awk -F= '$1 == "SESSION_ID" && $2 != "" { print "session" }' "$rigTmp/start.out" ) $( LC_ALL=C awk -F= '$1 == "MEMBERS" { print $2 }' "$rigTmp/start.out" ) $( LC_ALL=C awk -F= '$1 == "CHILDREN" { print NF }' "$rigTmp/start.out" )" \
	"0 session client-acme client-ndm 2"
rigPartitionId="$( LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; exit }' "$rigTmp/start.out" )"
rigPartitionRecord="$rigWs/.local/agents/spawned/$rigPartitionId/$rigPartitionId.spawn.md"
rigLeft=60
while [ -n "$rigPartitionId" ] && [ -f "$rigPartitionRecord" ] && LC_ALL=C grep -q -x 'status: spawn-started' "$rigPartitionRecord" && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the parent says on its record that it is agent-less, and closes itself once its children are done" \
	"$( [ -f "$rigPartitionRecord" ] && LC_ALL=C grep -c -x -e 'agent-less: true' "$rigPartitionRecord" || : ) $( [ -f "$rigPartitionRecord" ] && LC_ALL=C grep -c -E '^status: spawn-(succeeded|failed)$' "$rigPartitionRecord" || : )" "1 1"
rigAssert "each resolved member ran its own console: the child sessions are the members, not one session of both" \
	"$( LC_ALL=C sort "$rigTmp/started" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "client-acme client-ndm "
rigSpawn magic-coordinator.wardens.routine.md
rigAssert "warden-* with no member is refused by the spawner: rc 1, no session, and a hint that names the type and tells the caller to name the members" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/start.out" || : ) $( LC_ALL=C grep -c -E "warden-\*.*type warden.*name the members" "$rigTmp/start.err" || : )" "1 0 1"
rigSpawn magic-coordinator.one.routine.md
rigAssert "client-? is never auto-selected, even with two members available: rc 1, no session, and the hint asks for ONE member" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/start.out" || : ) $( LC_ALL=C grep -c -F -- 'name the one member to start' "$rigTmp/start.err" || : ) $( LC_ALL=C grep -c -x -e '  client-ndm' -e '  client-acme' "$rigTmp/start.err" || : )" "1 0 1 2"
rigSpawn magic-coordinator.one.routine.md client-acme
rigAssert "client-? asked with one member named starts exactly that member, and MEMBERS= carries it" \
	"$rigRc $( LC_ALL=C awk -F= '$1 == "MEMBERS" { print $2 }' "$rigTmp/start.out" )" "0 client-acme"
## The choice is the caller's, not the directory's: the other member of the type is not in the session.
rigSpawn magic-coordinator.one.routine.md client-ndm
rigAssert "the same routine asked with the other member starts the other member: the choice, not the first of the type" \
	"$rigRc $( LC_ALL=C awk -F= '$1 == "MEMBERS" { print $2 }' "$rigTmp/start.out" )" "0 client-ndm"

echo "-- 4. the slots a form offers, by the same rule, and the facts-only list --"
rigSlots(){ ## selector -- its slot rows, TABs shown as |, one line
	rigRun --manager-routine-slots "$1"
	LC_ALL=C tr '\t' '|' < "$rigTmp/out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigAssert "client-*: all, both members; warden-*: none; client-?: choose, both candidates; the call ends 0 and starts nothing" \
	"$( rigSlots magic-coordinator.clients.routine.md )/$( rigSlots magic-coordinator.wardens.routine.md )/$( rigSlots magic-coordinator.one.routine.md )/$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : )" \
	"$( printf 'slot|executors|client-*|all|%s ' "$( rigRun --manager-routine-slots magic-coordinator.clients.routine.md ; LC_ALL=C cut -f5- "$rigTmp/out" | LC_ALL=C tr '\t' '|' )" )/slot|executors|warden-*|none /$( printf 'slot|executors|client-?|choose|%s ' "$( rigRun --manager-routine-slots magic-coordinator.one.routine.md ; LC_ALL=C cut -f5- "$rigTmp/out" | LC_ALL=C tr '\t' '|' )" )/0 0"
rigAssert "the members of a choice and of a type are the members of the type" \
	"$( rigRun --manager-routine-slots magic-coordinator.one.routine.md ; LC_ALL=C cut -f5- "$rigTmp/out" | LC_ALL=C tr '\t' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "client-acme client-ndm "
rigAssert "participants: a named executor and a client-* choice side by side, and the standing keyword with none present" \
	"$( rigSlots magic-coordinator.oneinv.routine.md | LC_ALL=C sed 's/client-acme|client-ndm/C/; s/client-ndm|client-acme/C/' )/$( rigSlots magic-coordinator.present.routine.md )" \
	"slot|executors|magic-coordinator|named|magic-coordinator slot|participants|client-?|choose|C /slot|executors|magic-coordinator|named|magic-coordinator slot|participants|all-present-members|none "
rigRun --manager-routine-slots
rigAssert "no selector: refused, rc 1" "$rigRc $( LC_ALL=C grep -c -F 'syntax is <routine selector>' "$rigTmp/err" )" "1 1"
rigRun --manager-routine-list --facts-only
rigAssert "facts-only: client-* is startable, as the spawner partitions it; client-? still needs its member named" \
	"$( rigFieldOf magic-coordinator.clients.routine.md 4 ) $( rigFieldOf magic-coordinator.one.routine.md 4 ) $( rigFieldOf magic-coordinator.one.routine.md 10 )" "startable not-startable members"

## The runs the starts made close their records apart from this check.
rigLeft=90
while LC_ALL=C grep -l -x 'status: spawn-started' "$rigWs"/.local/agents/spawned/*/*.spawn.md > /dev/null 2>&1 && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ ROUTINE TYPE ROSTER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_TYPE_ROSTER: OK (%d assertions, offline)\n' "$rigPasses"
