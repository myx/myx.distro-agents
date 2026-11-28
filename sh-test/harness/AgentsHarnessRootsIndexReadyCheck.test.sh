#!/usr/bin/env bash
## Behavioural check of the roots index on a served call (AgentsHarnessRootsIndexText writes it, AgentsHarnessRootsIndexUse reads
## it): a call path reads the index's ready answer and does no work per root. The writer stores each kind's roots and resolutions
## finished, and names the rows whose answer depends on the disk at call time; the call tests those rows alone. Held:
##   1. the call's work does not grow with the roots: four hundred roots cost what forty cost, within fifty lines
##   2. the call starts no process but the fingerprint's one cksum: the member's extras take their sorted place with no sort
##   3. control: the answer is the computed set, the extras merged in C order, and a row of a root made since is resolved now
##   4. the index names the rows it leaves open, the only ones the harness start resolves: exactly those with no resolution
## Red before the change: every row is decoded and tested on every call, and the extras are merged through sort and awk.
## Offline: a rig workspace of this check's own, the producer stubbed; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessRootsIndexReadyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/roots" || exit 1
mkdir "$rigTmp"/roots/r{0..399} || exit 1

## One rig call: the index written for the first N roots (one of them absent), then the use traced. Prints the lines run inside the
## index use, the processes it started, and its answer as `root=resolution|` pairs, read set then write set.
rigCall(){ ## roots, member, keep: a third word keeps the index as it is instead of writing it
	HOME="$rigTmp/home" MDAT_SKILLSET_ROOT= bash -c '
		rigCount="$4" ; rigMember="$5" ; rigTop="$3" ; rigKeep="$6"
		AgentsToolsClientAccessRoots(){ { local at=0 ; while [ "$at" -lt "$rigCount" ] ; do printf "%s\n" "$rigTop/roots/r$at" ; at=$(( at + 1 )) ; done ; printf "%s\n" "$rigTop/absent" ; } | LC_ALL=C sort -u ; }
		AgentsToolsClientAccessReferenceRoots(){ printf "%s\n" "$rigTop/roots/r0" ; }
		AgentsToolsClientAccessGrantRoots(){ printf "%s\n%s\n" "$rigTop/roots/r1" "$rigTop/absent" ; }
		. "$1/sh-lib/harness/AgentsHarnessAccess.include" || exit 1
		. "$1/sh-lib/harness/AgentsHarnessRootsIndex.include" || exit 1
		[ -n "$rigKeep" ] || AgentsHarnessRootsIndexText "$2" > "$2/.local/agents/harness.roots.index" || { echo "INDEX-NOT-WRITTEN" ; exit 0 ; }
		MDLT_ORIGIN="$3/origin"
		harnessAccessRoots=() ; harnessWriteAccessRoots=()
		PS4="+\${FUNCNAME[0]}: " ; set -x
		AgentsHarnessRootsIndexUse "$2" "$rigMember" 0 ; rigRc=$?
		set +x
		[ "$rigRc" = 0 ] || { echo "INDEX-NOT-USED" ; exit 0 ; }
		rowAt=0 ; rowOut=""
		while [ "$rowAt" -lt "${#harnessAccessRoots[@]}" ] ; do rowOut="$rowOut${harnessAccessRoots[$rowAt]}=${harnessAccessRootsReal[$rowAt]}|" ; rowAt=$(( rowAt + 1 )) ; done
		rowOut="$rowOut W:" ; rowAt=0
		while [ "$rowAt" -lt "${#harnessWriteAccessRoots[@]}" ] ; do rowOut="$rowOut${harnessWriteAccessRoots[$rowAt]}=${harnessWriteAccessRootsReal[$rowAt]}|" ; rowAt=$(( rowAt + 1 )) ; done
		printf "ANSWER %s\n" "$rowOut"
		printf "OPEN %s W %s\n" "${harnessAccessRootsOpen[*]-unset}" "${harnessWriteAccessRootsOpen[*]-unset}"
	' rig "$rigPkg" "$rigWs" "$rigTmp" "$1" "$2" "${3:-}" 2>&1 | LC_ALL=C awk '
		/^\++AgentsHarnessRootsIndex(Use|Dec): / { lines++ }
		/^\++AgentsHarnessRootsIndexUse: (LC_ALL=C )?(sort|awk)( |$)/ { forks++ }
		/^(ANSWER|INDEX-NOT-USED|INDEX-NOT-WRITTEN)/ { answer = $0 }
		/^OPEN / { open = $0 }
		END { printf "%d\t%d\t%s\t%s\n", lines + 0, forks + 0, answer, open }'
}
rigSmall="$( rigCall 40 "" )"
rigLarge="$( rigCall 400 "" )"
case "$rigSmall$rigLarge" in *INDEX-NOT-*) echo "⛔ ERROR: the rig's index was not written or not used: $rigSmall | $rigLarge -- refusing to report a result" >&2 ; exit 1 ;; esac

echo "-- 1. the call does no work per root --"
rigSmallLines="${rigSmall%%	*}" ; rigLargeLines="${rigLarge%%	*}"
rigAssert "control: the trace reaches the index use" "$( [ "$rigSmallLines" -gt 0 ] && echo reached || echo none )" reached
rigAssert "four hundred roots cost what forty cost, within fifty lines ($rigSmallLines, $rigLargeLines)" "$( [ "$(( rigLargeLines - rigSmallLines ))" -le 50 ] && echo flat || echo grows )" flat

echo "-- 2. the extras take their place with no sort and no awk --"
rigMember="$( rigCall 40 alpha )"
rigForks="${rigMember#*	}" ; rigForks="${rigForks%%	*}"
rigAssert "with the origin and a member to merge in, the index use starts no sort and no awk" "$rigForks" 0

echo "-- 3. control: the answer is the computed set --"
rigWant="$( LC_ALL=C bash -c '
	{ at=0 ; while [ "$at" -lt 40 ] ; do printf "%s\n" "$1/roots/r$at" ; at=$(( at + 1 )) ; done
	  printf "%s\n%s\n%s\n%s\n" "$1/absent" "$1/origin/myx/myx.distro-agents/skillset" "$2/.local/temp/member/alpha" "$2/.local/temp/task/alpha" ; } | LC_ALL=C sort -u | while IFS= read -r one ; do
		case "$one" in "$1/roots/"*) printf "%s=%s|" "$one" "$one" ;; "$1/absent") printf "%s=%s|" "$one" "$one" ;; *) printf "%s=|" "$one" ;; esac
	done
	printf " W:%s=%s|%s=|%s=|%s=%s|%s=%s|" "$1/roots/r0" "$1/roots/r0" "$2/.local/temp/member/alpha" "$2/.local/temp/task/alpha" "$1/roots/r1" "$1/roots/r1" "$1/absent" "$1/absent"
' _ "$rigTmp" "$rigWs" )"
rigMemberAnswer="${rigMember#*	*	}" ; rigMemberAnswer="${rigMemberAnswer%%	*}"
rigAssert "the read and write sets, resolved, extras in C order" "$rigMemberAnswer" "ANSWER $rigWant"
rigCall 40 "" > /dev/null
mkdir "$rigTmp/absent" || exit 1
rigMadeAll="$( rigCall 40 "" keep )"
rigMade="${rigMadeAll#*	*	}" ; rigMade="${rigMade%%	*}"
rigAssert "a root made since the index was written is resolved now, not answered as stored" "$( case "$rigMade" in (*"$rigTmp/absent=|"*) echo now ;; (*) echo stored ;; esac )" now

echo "-- 4. the index names the rows it leaves open --"
## The positions of the pairs with no resolution, read set then write set, as `OPEN <read> W <write>` names them.
rigOpenOf(){ ## the ANSWER line
	printf '%s\n' "$1" | LC_ALL=C awk '{ sub(/^ANSWER /, "") ; split($0, part, " W:") ; for ( side = 1 ; side <= 2 ; side++ ) { n = split(part[side], pair, "|") ; out = "" ; at = 0 ; for ( i = 1 ; i < n ; i++ ) { if ( pair[i] ~ /=$/ ) out = out ( out == "" ? "" : " " ) at ; at++ } ; o[side] = out } ; printf "OPEN %s W %s\n", o[1], o[2] }'
}
rigAssert "with the origin and a member: the open rows are exactly the unresolved ones" "${rigMember##*	}" "$( rigOpenOf "$rigMemberAnswer" )"
rigAssert "with a root made since: that row is open too, and no other" "${rigMadeAll##*	}" "$( rigOpenOf "$rigMade" )"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS ROOTS INDEX READY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ROOTS_INDEX_READY: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
