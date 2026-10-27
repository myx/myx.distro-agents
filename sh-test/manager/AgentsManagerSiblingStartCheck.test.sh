#!/usr/bin/env bash
## Behavioural check on `--manager` of the four sibling consoles' tools (S14.3, sketch 15.1), run rather than read:
## DistroLocalTools, DistroSourceTools, DistroDeployTools and DistroRemoteTools each start the one shared screen
## (LocalTools.InternManager.include) as the app of their own console. NO SCREEN IS STARTED: a `python3` of the rig
## stands first on the rig's PATH and writes down the arguments it was started with. Held: the screen file of the
## agents package, the rig workspace, the tool file of the package of that console and its app name are handed on;
## an extra word is refused with the usage line of that console, and nothing is started. Deploy and Remote are the
## controls, which had it already. Against a rig workspace built here: MMDAPP is the rig, so nothing of the real
## workspace is read or written. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackages="${rigHere%/myx.distro-agents/sh-lib}"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/manager/AgentsManagerScreen.py" ] || rigRefuse "the screen is not at the origin this workspace resolves"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSiblingStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/bin" "$rigWs/.local"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"

printf '#!/bin/sh\nfor rigArg in "$@" ; do printf "%%s\\n" "$rigArg" ; done > "%s/started"\n' "$rigTmp" > "$rigTmp/bin/python3"
chmod +x "$rigTmp/bin/python3"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigStart(){ ## tool name, package folder, words... -> its output and "rc=<status>"; the stand-in's arguments in $rigTmp/started
	local rigTool="$1" rigPackage="$2" rigOut rigRc=0
	shift 2
	rm -f "$rigTmp/started"
	rigOut="$( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" PATH="$rigTmp/bin:$PATH" bash -c '. "$1" ; shift ; "$@"' rig "$rigPackages/$rigPackage/sh-scripts/$rigTool.fn.sh" "$rigTool" "$@" 2>&1 )" || rigRc=$?
	printf '%s\nrc=%s' "$rigOut" "$rigRc"
}

for rigTool in "DistroDeployTools myx.distro-deploy deploy" "DistroRemoteTools myx.distro-remote remote" "DistroLocalTools myx.distro-.local local" "DistroSourceTools myx.distro-source source" ; do
	set -- $rigTool
	rigName="$1" rigFolder="$2" rigApp="$3"
	rigOut="$( rigStart "$rigName" "$rigFolder" --manager )"
	rigAssert "$rigName --manager: ends 0" "${rigOut##*rc=}" 0
	rigAssert "$rigName --manager: the shared screen is started as the $rigApp app of the rig workspace, with this tool file" \
		"$( tr '\n' ' ' < "$rigTmp/started" 2> /dev/null )" \
		"-I -B $rigHere/manager/AgentsManagerScreen.py --workspace $rigWs --tools $rigPackages/$rigFolder/sh-scripts/$rigName.fn.sh --app $rigApp "
	rigOut="$( rigStart "$rigName" "$rigFolder" --manager rig-extra-word )"
	rigUsage="  $rigName --manager [--style <name>]"
	rigVerdict="$rigOut"
	case "$rigOut" in
		*"$rigUsage"*rc=1) rigVerdict=refused ;;
	esac
	[ ! -e "$rigTmp/started" ] || rigVerdict="$rigVerdict:started"
	rigAssert "$rigName --manager <word>: refused with the usage line of this console, nothing started" "$rigVerdict" "refused"
done

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ MANAGER SIBLING START CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SIBLING_START: OK ($rigPasses assertions, offline)"
