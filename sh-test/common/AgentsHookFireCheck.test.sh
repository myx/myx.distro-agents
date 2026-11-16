#!/usr/bin/env bash
## Behavioural check on the event hook (AgentsTools.Hook.include) and the store-changed dispatcher
## (AgentsTools.StoreChangedHook.include), run rather than read, in a workspace built here. Held:
## a registered handler runs in registration order and receives the fire's arguments; a handler whose
## file this process never loaded is loaded on demand at the fire; a failing handler prints the one
## ERROR line and the fire returns that non-zero status while the next handler still runs; a fire of a
## hook with no handler returns 0, prints nothing and forks nothing; registering the same handler twice
## leaves one row; an unknown kind passed to the dispatcher is a no-op that returns 0 and does not
## fail the fire; and a registry rebuild whose owner declares no `registry-<name>` hook fails loudly,
## while a declared one is rebuilt by its owner. Offline: nothing is posted.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/common/AgentsTools.Hook.include" ] || rigRefuse "the hook's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHookFireCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'kill $( jobs -pr ) 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
export MMDAPP="$rigWs"
mkdir -p "$rigWs/.local/agents"
. "$rigHere/common/AgentsTools.Hook.include"
type AgentsHookFire > /dev/null 2>&1 || rigRefuse "AgentsHookFire is not defined by sourcing the hook's functions"

## A handler include of the rig's own, at a path relative to sh-lib/ so the fire's guarded load can find it.
rigHandlerFile="$rigTmp/AgentsHookProbe.include"
cat > "$rigHandlerFile" <<'EOF'
AgentsHookProbeOne(){ printf 'one:%s:%s\n' "$1" "$2" ; return 0 ; }
AgentsHookProbeTwo(){ printf 'two:%s:%s\n' "$1" "$2" ; return 0 ; }
AgentsHookProbeFail(){ printf 'fail-ran\n' ; return 7 ; }
AgentsHookProbeThree(){ printf 'three:%s:%s\n' "$1" "$2" ; return 0 ; }
EOF
## A link-free reachable copy under sh-lib/, so the fire's own relative include path resolves.
cp "$rigHandlerFile" "$rigHere/AgentsHookProbe.include"
trap 'kill $( jobs -pr ) 2> /dev/null ; rm -f "$rigHere/AgentsHookProbe.include" ; rm -rf -- "$rigTmp"' EXIT

## A fire of a hook with no handler: 0, silent, no fork.
rigChildCount(){ ps -o pid= --ppid "$$" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigBefore="$( rigChildCount )"
rigNoOut="$( AgentsHookFire no-such-hook a b 2>&1 )"
rigNoRc=$?
rigAfter="$( rigChildCount )"
rigAssert "a fire of a hook with no handler returns 0" "$rigNoRc" "0"
rigAssert "and prints nothing" "$rigNoOut" ""
rigAssert "and forks nothing" "$rigAfter" "$rigBefore"

## Registering is idempotent: the same row twice leaves one row.
AgentsHookRegister store-changed AgentsHookProbeOne AgentsHookProbe.include
AgentsHookRegister store-changed AgentsHookProbeOne AgentsHookProbe.include
rigAssert "registering the same handler twice leaves one row" "$( LC_ALL=C grep -c '^store-changed AgentsHookProbeOne ' "$rigWs/.local/agents/hooks.registry" )" "1"

## Handlers run in registration order and receive the fire's arguments, in a fresh process that never
## loaded the handler file: the fire's guarded load brings it in on demand.
AgentsHookRegister store-changed AgentsHookProbeTwo AgentsHookProbe.include
rigOrder="$( MMDAPP="$rigWs" MDLT_ORIGIN="${MDLT_ORIGIN:-$rigReal/.local}" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.Hook.include"
	AgentsHookFire store-changed argA argB
' 2>&1 )"
rigOrderRc=$?
rigAssert "a registered handler runs in a process that never loaded its file" "$rigOrderRc" "0"
rigAssert "handlers run in registration order, each with the fire's arguments" "$rigOrder" "one:argA:argB
two:argA:argB"

## A failing handler is loud and does not stop the next handler; the fire returns the first non-zero status.
AgentsHookRegister store-changed AgentsHookProbeFail AgentsHookProbe.include
AgentsHookRegister store-changed AgentsHookProbeThree AgentsHookProbe.include
rigFail="$( MMDAPP="$rigWs" MDLT_ORIGIN="${MDLT_ORIGIN:-$rigReal/.local}" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.Hook.include"
	AgentsHookFire store-changed a b
' 2>&1 )"
rigFailRc=$?
rigAssert "a failing handler makes the fire return non-zero" "$rigFailRc" "7"
rigAssert "its failure is named once, as handler and status" "$( printf '%s\n' "$rigFail" | LC_ALL=C grep -c 'hook store-changed: handler AgentsHookProbeFail answered 7' )" "1"
rigAssert "the next handler still runs after it" "$( printf '%s\n' "$rigFail" | LC_ALL=C grep -c '^three:a:b$' )" "1"

## The store-changed dispatcher: an unknown kind is a no-op that returns 0 and does not fail the fire.
## A fresh registry, holding only the dispatcher, isolates the no-op from the failing handlers above.
rm -f "$rigWs/.local/agents/hooks.registry"
AgentsHookRegister store-changed AgentsHookStoreChanged wait/AgentsTools.StoreChangedHook.include
. "$rigHere/wait/AgentsTools.StoreChangedHook.include"
rigKindRc=0
AgentsHookFire store-changed no-such-kind x y z || rigKindRc=$?
rigAssert "an unknown kind passed to the dispatcher is a no-op returning 0" "$rigKindRc" "0"

## A registry rebuild goes through its owner's `registry-<name>` hook (AgentsTools.Registries.include). With no
## owner declaring it, the rebuild fails with one ERROR line, never an empty fire that leaves a stale file.
rigAbsentOut="$( unset MDAT_DATA_ROOT ; . "$rigHere/team-data/AgentsTools.Registries.include" ; AgentsToolsRegistryRebuild no-such-registry 2>&1 )"
rigAbsentRc=$?
rigAssert "a rebuild of a registry no owner declares fails" "$rigAbsentRc" "1"
rigAssert "with one ERROR line naming the missing hook" "$( printf '%s\n' "$rigAbsentOut" | LC_ALL=C grep -c 'no owner declares the registry-no-such-registry hook' )" "1"
## Control: a declared registry is rebuilt by its owner, in the rig workspace, whose stores are empty.
rigDeclaredRc=0
( unset MDAT_DATA_ROOT ; . "$rigHere/team-data/AgentsTools.Registries.include" ; AgentsToolsRegistryRebuild pending-replies ) 2> /dev/null || rigDeclaredRc=$?
rigAssert "control: a declared registry is rebuilt by its owner's hook" "$rigDeclaredRc $( [ -f "$rigWs/.local/agents/pending-replies.registry" ] && echo written )" "0 written"

export MMDAPP="$rigReal"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ HOOK FIRE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "HOOK_FIRE: OK ($rigPasses assertions, offline)"
