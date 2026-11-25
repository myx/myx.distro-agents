#!/usr/bin/env bash
## Behavioural check on the ONE parse of a routine's `executors:` value (P1 of the routine-override pieces): the
## parenthetical is taken whole before any split, so a comma or a space inside it never reaches a member test.
## Read over the four mechanisms that read that line: the parse (AgentsToolsRoutineExecutorsEntries,
## AgentsToolsRoutineExecutorsMemberList, AgentsToolsRoutineExecutorsParams), the routine validator, the executors
## roster a start resolves by, and the partition reader of --spawn-session. Held:
##   1. the parse answers one member and the whole parenthetical, for a four-parameter parenthetical
##   2. the validator accepts that declaration, and no row names a fragment of it
##   3. the roster answers the one member, rc 0
##   4. the partition reader takes its members from the parse, never from a split of its own
##   5. a space-separated value is the same two members to the validator and to the roster
##   6. the member set of every executors value this skillset carries today is unchanged
##   7. the instruments answer both ways, so a red here reads about the declared fault
## Offline: a rig member directory and rig routine files only; nothing is started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -d "$rigPackage/sh-lib" ] || rigRefuse "no package at the origin: $rigPackage"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineExecutorsParseCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigMembers="$rigTmp/members" rigRoutines="$rigTmp/routines"
mkdir -p "$rigWs/.local" "$rigHome" "$rigMembers" "$rigRoutines"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
for rigName in magic-tester magic-coordinator magic-librarian ; do
	mkdir -p "$rigMembers/$rigName"
	printf 'rig\n' > "$rigMembers/$rigName/$rigName.basic.md"
done

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One call in the rig's own environment: no variable of this session reaches the code under test.
rigShell(){ ## script, its arguments...
	( cd "$rigWs" && env -i HOME="$rigHome" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigMembers" \
		bash -c "$1" rig "${@:2}" ) 2> /dev/null
}

## The parse's entries, one `<member>|<parameters>` a segment.
rigEntries(){ ## executors value
	rigShell '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.RoutineExecutors.include"
		AgentsToolsRoutineExecutorsEntries "$1" | LC_ALL=C tr "\t" "|" | LC_ALL=C tr "\n" "/"' "$1"
}
## The parse's members, one a name, sorted.
rigParseSet(){ ## executors value
	rigShell '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.RoutineExecutors.include"
		AgentsToolsRoutineExecutorsMembers "$1" | LC_ALL=C tr " " "\n" | LC_ALL=C sort' "$1"
}
## The two readings the tree made before the parse, for the regression table.
rigOldValidatorSet(){ ## executors value
	printf '%s\n' "$1" | LC_ALL=C awk '{ n = split( $0, a, /[, \t]+/ ) ; for ( i = 1 ; i <= n ; i++ ) if ( a[i] != "" ) print a[i] }' | LC_ALL=C sort
}
rigOldSpawnerSet(){ ## executors value
	printf '%s\n' "$1" | LC_ALL=C tr ',' '\n' | LC_ALL=C sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | LC_ALL=C grep -v '^$' | LC_ALL=C sort
}
## The executors roster, as `<rc>:<first line>:<lines printed>`.
rigRoster(){ ## executors value
	rigShell '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnRoutine.include"
		out="$( AgentsToolsSpawnRoutineExecutorsRoster "$1" )" ; rc=$?
		printf "%s:%s:%s" "$rc" "$( printf "%s" "$out" | LC_ALL=C sed -n 1p | LC_ALL=C tr "\t" "|" )" "$( printf "%s\n" "$out" | LC_ALL=C grep -c . || : )"' "$1"
}
## The routine validator's exit status for a routine file.
rigValidateRc(){ ## routine file
	rigShell '"$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh" --skillset-validate-routine "$1"
		printf "%s" "$?"' "$1"
}
## The routine validator's fault rows, the file path cut off.
rigValidateRows(){ ## routine file
	rigShell '"$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh" --skillset-validate-routine "$1" 2>&1' "$1" \
		| LC_ALL=C sed -e 's/^[^ :]*myx\.distro-agents\///'
}
## How many times a split of the executors value appears in one function's own body, and whether the function calls
## the parse: `<splits>:<parse-calls>`.
rigFunctionProbe(){ ## file, function name, the split's own text
	LC_ALL=C awk -v fn="$2" -v splitText="$3" '
		index( $0, fn "(){" ) == 1 { inBody = 1 ; next ; }
		inBody && $0 == "}" { inBody = 0 ; next ; }
		!inBody { next ; }
		{ if ( index( $0, splitText ) > 0 ) splits++ ; if ( index( $0, "AgentsToolsRoutineExecutorsParse " ) > 0 || index( $0, "AgentsToolsRoutineExecutorsEntries \"" ) > 0 || index( $0, "AgentsToolsRoutineExecutorsMemberList \"" ) > 0 ) calls++ ; }
		END { printf "%d:%d", splits, calls }
	' "$1"
}
## A routine complete by the contract, its executors as given, on line 3.
rigRoutine(){ ## name, executors value
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-tester\nrequires-session-kind: coworking\n' "$2"
		printf 'runs-at: none\n---\n# magic-tester.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n' "$1"
		printf '# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n'
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigRoutines/magic-tester.$1.routine.md"
	printf '%s' "$rigRoutines/magic-tester.$1.routine.md"
}
## The four-word parenthetical: four comma-separated parameters, each with a space after its comma.
rigFour='magic-tester (preset:gemini, effort:high, model:opus, high)'

echo "-- 1. the parse takes the parenthetical whole --"
rigAssert "one member, and the whole parenthetical after it"   "$( rigEntries "$rigFour" )" "magic-tester|preset:gemini, effort:high, model:opus, high/"
rigAssert "the member list is that one member"                  "$( rigParseSet "$rigFour" )" "magic-tester"
rigAssert "a declaration with no parenthetical is one member"   "$( rigEntries 'magic-tester' )" "magic-tester|/"
rigAssert "that declaration's parameters are empty"             "$( rigShell '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.RoutineExecutors.include" ; AgentsToolsRoutineExecutorsParams "magic-tester" magic-tester' )" ""
rigAssert "a two-parameter parenthetical is still one member"   "$( rigEntries 'magic-tester (preset:gemini,effort:high)' )" "magic-tester|preset:gemini,effort:high/"

echo "-- 2. the validator accepts it, and names no fragment --"
rigAssert "the validator accepts the four-word parenthetical"   "$( rigValidateRc "$( rigRoutine four "$rigFour" )" )" "0"
rigAssert "...and its rows name no fragment of it"              "$( rigValidateRows "$( rigRoutine four "$rigFour" )" | LC_ALL=C grep -c -F -e '(preset' -e 'high)' -e 'effort:high ' || : )" "0"

echo "-- 3. the roster answers that one member --"
rigAssert "one member, rc 0"                                    "$( rigRoster "$rigFour" )" "0:magic-tester:1"

echo "-- 4. the partition reader takes its members from the parse --"
rigAssert "the member list carries a wildcard whole"            "$( rigParseSet 'magic-* (effort:high)' )" "magic-*"
rigAssert "--spawn-session takes its partition members from the parse" \
	"$( LC_ALL=C grep -c 'AgentsToolsRoutineExecutorsMemberList "$routineExecutorsLine"' "$rigPackage/sh-lib/spawn/AgentsTools.SpawnSession.include" || : )" "1"
rigAssert "--spawn-session holds no split of that line of its own" \
	"$( LC_ALL=C grep -c 'routineExecutorsLine//,/ }' "$rigPackage/sh-lib/spawn/AgentsTools.SpawnSession.include" || : )" "0"
rigAssert "the executors roster splits nothing itself, and calls the parse" \
	"$( rigFunctionProbe "$rigPackage/sh-lib/spawn/AgentsTools.SpawnRoutine.include" AgentsToolsSpawnRoutineExecutorsRoster "IFS=','" )" "0:1"
rigAssert "the validator's executors loop splits nothing itself, and calls the parse" \
	"$( LC_ALL=C awk '
		/for routineKeyName in executors invitees maintainers/ { inLoop = 1 }
		inLoop { print }
		inLoop && $0 == "\tdone" { inLoop = 0 }
	' "$rigPackage/sh-lib/team-data/AgentsTools.DocValidateRuleSets.include" | LC_ALL=C awk '
		{ if ( index( $0, "routineLine//,/ }" ) > 0 ) splits++ ; if ( index( $0, "AgentsToolsRoutineExecutorsMembers " ) > 0 ) calls++ ; }
		END { printf "%d:%d", splits, calls }
	' )" "0:1"

echo "-- 5. a space-separated value reads as it did before --"
rigAssert "the names parse names both"                          "$( rigParseSet 'magic-tester magic-librarian' )" "magic-librarian
magic-tester"
rigAssert "the validator accepts it, as it always did"          "$( rigValidateRc "$( rigRoutine space 'magic-tester magic-librarian' )" )" "0"
rigAssert "the roster still refuses it, as it always did: one entry names no member" \
	"$( rigRoster 'magic-tester magic-librarian' )" "1:no-member|magic-tester magic-librarian:1"

echo "-- 6. every declaration this skillset carries today reads as before --"
rigDeclared=0 rigMoved=""
while IFS= read -r rigValue ; do
	[ -n "$rigValue" ] || continue
	rigDeclared=$(( rigDeclared + 1 ))
	[ "$( rigParseSet "$rigValue" )" = "$( rigOldValidatorSet "$rigValue" )" ] || rigMoved="$rigMoved|$rigValue:validator"
	[ "$( rigParseSet "$rigValue" )" = "$( rigOldSpawnerSet "$rigValue" )" ] || rigMoved="$rigMoved|$rigValue:spawner"
done <<< "$( LC_ALL=C grep -rh '^executors: ' "$rigPackage/skillset/" | LC_ALL=C sed 's/^executors: //' | LC_ALL=C sort -u )"
rigAssert "the declarations were read at all"                   "$( [ "$rigDeclared" -gt 0 ] && echo read || echo none )" "read"
rigAssert "no declaration moved a member"                       "${rigMoved:-(none)}" "(none)"

echo "-- 7. the instruments answer, both ways --"
rigAssert "the roster names two members of a comma list"        "$( rigRoster 'magic-coordinator, magic-librarian' )" "0:magic-coordinator:2"
rigAssert "a name no member answers to is refused"              "$( rigRoster 'nosuch-member' )" "1:no-member|nosuch-member:1"
rigAssert "a doubled comma still leaves a row of its own"       "$( rigRoster 'magic-tester,,magic-librarian' )" "1:empty-name:1"
rigAssert "the parse reproduces that empty row"                 "$( rigEntries 'magic-tester,,magic-librarian' )" "magic-tester|/|/magic-librarian|/"
rigAssert "a name a fragment of the parenthetical would answer to is refused" "$( rigRoster '(preset:gemini' | cut -d: -f1 )" "1"
rigAssert "the two old readings do differ, so the table above can fail" \
	"$( [ "$( rigOldValidatorSet 'magic-* (effort:high)' )" = "$( rigOldSpawnerSet 'magic-* (effort:high)' )" ] && echo same || echo differ )" "differ"
rigParseEvery(){ ## -- one line a file that does not parse
	local parseFile
	for parseFile in sh-lib/spawn/AgentsRoutineExecutorsParse.awk sh-lib/spawn/AgentsTools.RoutineExecutors.include sh-lib/spawn/AgentsTools.SpawnRoutine.include sh-lib/spawn/AgentsTools.SpawnSession.include sh-lib/team-data/AgentsTools.DocValidateRuleSets.include ; do
		if [ "$parseFile" = sh-lib/spawn/AgentsRoutineExecutorsParse.awk ] ; then
			LC_ALL=C awk -f "$rigPackage/$parseFile" < /dev/null > /dev/null 2>&1 || printf 'broken:%s\n' "$parseFile"
		else
			bash -n "$rigPackage/$parseFile" || printf 'broken:%s\n' "$parseFile"
		fi
	done
}
rigAssert "the files under test parse, so a green here reads about behaviour" "$( rigParseEvery | LC_ALL=C grep -c . || : )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE EXECUTORS PARSE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_EXECUTORS_PARSE: OK (%d assertions, %d declarations, offline)\n' "$rigPassCount" "$rigDeclared"
