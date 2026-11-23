#!/usr/bin/env bash
## Behavioural check on the spawn proxy's own reading of a CLI service (`AgentsToolsSpawnProxyCliKind`,
## sh-lib/spawn/AgentsTools.SpawnProxyLaunch.include): whether a resolved CLI runs in this package's harness or
## is a vendor CLI. The question decides the tier a start passes and whether a resume may reuse the run.
## The leg is a file `sh-lib/harness/Agents<Name>Harness.sh`, and its service name is `<Name>` in lower case, which
## is the console's own rule. A service whose name carries a hyphen therefore has a leg whose file name does not:
## `standard-v1` is `AgentsStandardV1Harness.sh`. Held:
##   1. every service of the preset list that this package ships a leg for reads `harness`, `standard-v1` among them.
##   2. control: the same reading is not a blanket yes, and a service with no leg reads `native`.
##   3. control: the three `-native` services and `none` keep their own answers.
## Red before the fix: `standard-v1` reads `native`, because the comparison drops the hyphen from the leg's name and
## keeps it in the service's.
## Offline: the package's own harness folder, read through $MDLT_ORIGIN; no CLI is started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigLaunch="$rigPackage/sh-lib/spawn/AgentsTools.SpawnProxyLaunch.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigLaunch" ] || rigRefuse "the spawn launch include is not at $rigLaunch"
[ -d "$rigPackage/sh-lib/harness" ] || rigRefuse "the harness folder is not in the package: $rigPackage"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}
rigKind(){ ## a resolved cli
	bash -c '. "$1" ; AgentsToolsSpawnProxyCliKind "$2"' rig-kind "$rigLaunch" "$1"
}

echo "-- 1. a service this package ships a leg for reads harness, whatever its name holds --"
rigAssert "claude has a leg and reads harness"          "$( rigKind claude )" harness
rigAssert "standard-v1 has a leg and reads harness"      "$( rigKind standard-v1 )" harness
rigAssert "scaleway has a leg and reads harness"         "$( rigKind scaleway )" harness
rigAssert "deepseek has a leg and reads harness"         "$( rigKind deepseek )" harness

echo "-- 2. control: the reading is not a blanket yes --"
rigAssert "a service with no leg reads native"           "$( rigKind no-such-service )" native

echo "-- 3. control: the answers that were never a leg keep their own --"
rigAssert "none reads none"                              "$( rigKind none )" none
rigAssert "claude-native reads native"                   "$( rigKind claude-native )" native

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN CLI KIND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SPAWN_CLI_KIND: OK (%d assertions, offline, package files only)\n' "$rigPassCount"
