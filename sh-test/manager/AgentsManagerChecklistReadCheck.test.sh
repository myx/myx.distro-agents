#!/usr/bin/env bash
## Behavioural check on --manager-session-checklist-read: a participant's checklist is found
## where the harness that writes it puts it -- the session's spawn record, named
## <session-id>.spawn.md, in whatever folder of spawned/ holds it -- and not by assuming the
## folder is named by the session id. Offline: a rig workspace of its own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigWs="$( rigTempDir AgentsManagerChecklistReadCheck )" || exit 1
trap 'rm -rf -- "$rigWs"' EXIT
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/folder-x" "$rigWs/.local/agents/sessions" "$rigWs/bin"
printf '#!/bin/sh\nexit 7\n' > "$rigWs/bin/curl" ; chmod +x "$rigWs/bin/curl"

pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
run(){ ( cd "$rigWs" && env -i HOME="$rigWs" PATH="$rigWs/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) 2> /dev/null ; }

echo "-- the record in a folder not named by the session id --"
printf 'spawn-id: sess-abc\n' > "$rigWs/.local/agents/spawned/folder-x/sess-abc.spawn.md"
printf '# My list\n- [ ] one thing\n' > "$rigWs/.local/agents/spawned/folder-x/magic-tester.checklist.md"
check "the checklist is found there and printed whole" "$( run --manager-session-checklist-read --session-id sess-abc magic-tester | tr '\n' ' ' )" "# My list - [ ] one thing "

echo "-- the folder named by the id, and the fallback under sessions/ --"
mkdir -p "$rigWs/.local/agents/spawned/sess-plain"
printf 'spawn-id: sess-plain\n' > "$rigWs/.local/agents/spawned/sess-plain/sess-plain.spawn.md"
printf -- '- [x] done\n' > "$rigWs/.local/agents/spawned/sess-plain/keeper-rig.checklist.md"
check "a folder named by the id is found too" "$( run --manager-session-checklist-read --session-id sess-plain keeper-rig )" "- [x] done"

mkdir -p "$rigWs/.local/agents/sessions/sess-bare"
printf -- '- [ ] from the session store\n' > "$rigWs/.local/agents/sessions/sess-bare/magic-tester.checklist.md"
check "a session with no record reads from sessions/<id>" "$( run --manager-session-checklist-read --session-id sess-bare magic-tester )" "- [ ] from the session store"

echo "-- nothing to read is nothing, never an invention --"
check "a member with no checklist prints nothing" "$( run --manager-session-checklist-read --session-id sess-abc keeper-rig )" ""
check "a session that is not there prints nothing" "$( run --manager-session-checklist-read --session-id sess-gone magic-tester )" ""
check "and a bad member name is refused, not read" "$( run --manager-session-checklist-read --session-id sess-abc 'bad/name' > /dev/null 2>&1 ; echo $? )" 1

if [ "$fail" = 0 ] ; then printf 'MANAGER_CHECKLIST_READ: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ MANAGER_CHECKLIST_READ CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
