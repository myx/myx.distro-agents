#!/usr/bin/env bash
## Behavioural check on the server keys the console serves (C1 of the refactorings epic), run rather than read:
## --manager-keys-state, --manager-keys-add, --manager-keys-approve, --manager-keys-revoke and --manager-keys-remove,
## the key state machine kept in the workspace's own keys registry (.local/agents/keys.registry). Against a rig workspace
## built here, so nothing of the machine's own registry or ssh home is read or written.
## Held (the assumption this implementation states in its help): a key is a name, a state and the material it serves, one
## a line in the registry; the states are `pending` (added, not yet approved), `served` (approved and live -- the
## lifecycle's "active" and "served" are this one state) and `revoked` (deactivated, kept until removed). The lifecycle
## `add -> approve -> active -> served`:
##   1. state lists the registry, one `key` row each in its order; empty when nothing stands; with a name, that one key alone
##   2. add writes a key as `pending`, the material on standard input, never echoed and never an argument; a key of that name
##      already standing is refused
##   3. approve moves a `pending` key to `served`, live at once; a key that is none, or not pending, is refused
##   4. revoke moves a `served` key to `revoked` at once; a key that is none, or not served, is refused
##   5. remove takes a key out entirely; a `served` (active) key is refused -- it is revoked first ("leave active keys")
##   6. a name that is no name, a wrong count of words, and, from inside a member's session, each is refused; the help pair
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerKeysStateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigWs/source" "$rigWs/distro"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
printf 'MDLT_CONSOLE_ORIGIN=.local\n' > "$rigWs/.local/MDLT.settings.env"
rigReg="$rigWs/.local/agents/keys.registry"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## stdin-string, tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	local runInput="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "$runInput" || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigRegRows(){ LC_ALL=C awk -F'\t' '{ printf "%s=%s ", $1, $2 }' "$rigReg" ; }

echo "-- 1. state of an empty registry --"
rigRun "" --manager-keys-state
rigAssert "with nothing added, the state lists nothing, rc 0, and no registry file is made by the read" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( [ -e "$rigReg" ] && echo made || echo none )" "0 0 none"

echo "-- 2. add, then the lifecycle approve, revoke, remove --"
rigRun $'rig-material-one' --manager-keys-add one
rigAssert "add writes a key as pending, its material from stdin: one row, added, the key, its state and its material" "$rigRc $( rigTroubles ) $( rigFlat "$rigTmp/out" )" "0 0 added one pending rig-material-one/"
rigRun "" --manager-keys-state
rigAssert "state then lists it, one row, pending" "$rigRc $( rigFlat "$rigTmp/out" )" "0 key one pending rig-material-one/"
rigRun $'rig material two' --manager-keys-add two
rigAssert "a second key, whose material has a blank, reads that blank as _ in the row and in the registry" "$rigRc $( rigFlat "$rigTmp/out" ) $( rigRegRows )" "0 added two pending rig_material_two/ one=pending two=pending "
rigRun "" --manager-keys-approve one
rigAssert "approve makes a pending key served, live, one row" "$rigRc $( rigFlat "$rigTmp/out" )" "0 approved one served/"
rigRun "" --manager-keys-state one
rigAssert "its state reads served, and the other key is untouched" "$rigRc $( rigFlat "$rigTmp/out" ) $( rigRegRows )" "0 key one served rig-material-one/ one=served two=pending "
rigRun "" --manager-keys-revoke one
rigAssert "revoke deactivates a served key at once" "$rigRc $( rigFlat "$rigTmp/out" )" "0 revoked one revoked/"
rigRun "" --manager-keys-remove two
rigAssert "remove takes a pending key out entirely, one row, and the revoked key stays" "$rigRc $( rigFlat "$rigTmp/out" ) $( rigRegRows )" "0 removed two/ one=revoked "

echo "-- 3. what it refuses --"
rigRun $'again' --manager-keys-add one
rigAssert "a key of that name already standing is refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigRun $'x' --manager-keys-add 'bad;name'
rigAssert "a name that is no name of a key is refused and not repeated" "$rigRc $( LC_ALL=C grep -c -F -- 'bad;name' "$rigTmp/err" || : )" "1 0"
rigRun "" --manager-keys-approve one
rigAssert "a key that is not pending (revoked here) is not approved" "$rigRc $( LC_ALL=C grep -c -F -- 'not pending' "$rigTmp/err" || : )" "1 1"
rigRun "" --manager-keys-revoke one
rigAssert "a key that is not served (revoked here) is not revoked" "$rigRc $( LC_ALL=C grep -c -F -- 'not served' "$rigTmp/err" || : )" "1 1"
rigRun "" --manager-keys-remove no-such
rigAssert "a key that is none is not removed" "$rigRc" "1"
rigRun $'x' --manager-keys-add three
rigRun "" --manager-keys-approve three
rigRun "" --manager-keys-remove three
rigAssert "a served (active) key is never removed: refused, and it stays served" "$rigRc $( LC_ALL=C grep -c -F -- 'revoke it first' "$rigTmp/err" || : ) $( rigRegRows )" "1 1 one=revoked three=served "
rigRun "" --manager-keys-revoke three
rigRun "" --manager-keys-remove three
rigAssert "revoked first, the same key is removed" "$rigRc $( rigFlat "$rigTmp/out" ) $( rigRegRows )" "0 removed three/ one=revoked "
rigRun "" --manager-keys-state extra word
rigAssert "a second word after state is refused with its syntax" "$rigRc $( LC_ALL=C grep -c -F -- 'syntax is --manager-keys-state [<key>]' "$rigTmp/err" || : )" "1 1"
rigRun "" --manager-keys-add one extra
rigAssert "a second word after add is refused" "$rigRc" "1"

echo "-- 4. from inside a member's session, and the help pair --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigBad=""
for rigOp in state add approve revoke remove ; do
	rigRun "" "--manager-keys-$rigOp" one
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [$rigOp]"
done
rigPre=()
rigAssert "a member's session is refused each, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigBad=""
for rigOp in "state [<key>]" "add <key>" "approve <key>" "revoke <key>" "remove <key>" ; do
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh --manager-keys-$rigOp" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOp]"
	LC_ALL=C grep -q -x -F -- "		--manager-keys-$rigOp" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOp]"
done
rigAssert "each of the five has its syntax line and its help entry" "${rigBad:- all paired}" " all paired"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
