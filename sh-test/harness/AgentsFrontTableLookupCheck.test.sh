#!/usr/bin/env bash
## Behavioural check of the front table's lookups on the call path (code-craft: a kept table is matched, never walked per call). Every
## start of a tool file asks whether its first word is a name of the table (AgentsToolsFrontAny, AgentsToolsFrontKnows). Held:
##   1. a lookup reads no row: an unknown name costs what a known one does, a handful of lines, with no read loop
##   2. every name of the table and of its stubs is known to its own file and to none other, as the row walk answered
##   3. --help-syntax is known to every file of the table, and unknown names to none
## Red before the change: each lookup read the table row by row, 169 rows for a name it does not hold.
## Offline: the include alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRun(){ bash -c '. "$1/sh-lib/harness/AgentsContext.FrontTable.include" || exit 1 ; shift ; '"$1" rig "$rigPkg" "${@:2}" ; }

echo "-- 1. a lookup reads no row --"
rigLines="$( rigRun 'PS4="+\${FUNCNAME[0]}: " ; set -x ; AgentsToolsFrontAny --no-such-name-at-all ; AgentsToolsFrontKnows DistroAgentsSession --no-such-name-at-all ; set +x' 2>&1 | LC_ALL=C grep -c '^+AgentsToolsFront' )"
rigAssert "two lookups of an unknown name run under twenty lines" "$( [ "$rigLines" -lt 20 ] && echo few || echo "$rigLines lines" )" few

echo "-- 2. and 3. every answer is the row walk's --"
rigBad="$( rigRun '
	walkAny(){ local f o w ; while IFS=$'"'"'\t'"'"' read -r f o w ; do [ "$o" = "$1" ] && return 0 ; done <<< "$agentsFrontTable" ; return 1 ; }
	walkKnows(){ local f o w ; while IFS=$'"'"'\t'"'"' read -r f o w ; do [ "$f" = "$1" ] || continue ; [ "$o" = "$2" ] || [ "$2" = "--help-syntax" ] || continue ; return 0 ; done <<< "$agentsFrontTable"$'"'"'\n'"'"'"$agentsFrontStubs" ; return 1 ; }
	files="$( printf "%s\n%s\n" "$agentsFrontTable" "$agentsFrontStubs" | cut -f1 | sort -u ) DistroAgentsNoSuchFile"
	ops="$( printf "%s\n%s\n" "$agentsFrontTable" "$agentsFrontStubs" | cut -f2 | sort -u ) --help-syntax --no-such-name --upsert"
	for o in $ops ; do
		a=0 ; AgentsToolsFrontAny "$o" || a=1 ; b=0 ; walkAny "$o" || b=1 ; [ "$a" = "$b" ] || echo "any:$o"
		for f in $files ; do a=0 ; AgentsToolsFrontKnows "$f" "$o" || a=1 ; b=0 ; walkKnows "$f" "$o" || b=1 ; [ "$a" = "$b" ] || echo "knows:$f:$o" ; done
	done
	a=0 ; AgentsToolsFrontAny --mdat-output-format json --wait-for-input || a=1 ; [ "$a" = 0 ] || echo "any:json-form"' 2>&1 | head -5 )"
rigAssert "answers that differ from the row walk" "${rigBad:-none}" none

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ FRONT TABLE LOOKUP CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'FRONT_TABLE_LOOKUP: OK (%d assertions, offline)\n' "$rigPass"
