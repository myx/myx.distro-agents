#!/usr/bin/env bash
## Behavioural check on CheckList, the harness tool a member keeps the checklist of its session
## tasks with -- the counterpart of the native TodoWrite, with its input shape -- run through
## --intern-tool, the path the myx.distro MCP serves every call by. Covers: one list a member a
## session, `<member>.checklist.md` in Markdown, shared by every run of that member, kept in the
## sandbox root of the spawn that founded the session, or in the session folder
## (.local/agents/sessions/<id>) of a session a root session founded; the next call replacing the
## whole list; a participant writing its own list alone; bad input refused with ERROR and nothing
## written; a call with no todos reading the caller's own list, with member another
## participant's, with `*` every participant's under its member name, an empty one shown as empty
## and never a row with no member name, a name that is no participant refused; no list of
## another session; a session whose member or place the harness does not know neither offered
## the tool, on the MCP floor or in a ToolSearch, nor served by it; the declaration's shape and
## words, and a ToolSearch finding it.
## Offline: MMDAPP, HOME and the skillset are this check's own temp tree; nothing reaches a host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh" || { echo "⛔ ERROR: the rig's reply fixture is missing from the package: sh-test/check-fixtures/rig-reply.include.sh -- refusing to report a result" >&2 ; exit 1 ; }
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigTool" ] || rigRefuse "the tooling is not found at the origin this workspace resolves: $rigTool"

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessTodoWriteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/agents/sessions" "$rigTmp/home" "$rigTmp/no-skills" || exit 1
for rigMember in magic-coordinator keeper-myx magic-tester magic-architect magic-developer ; do
	mkdir -p "$rigTmp/skills/$rigMember" && printf 'rig %s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" || exit 1
done
## The spawn records of two sessions, each sandbox as the spawn proxy makes it. Session rig-root
## was founded by a root session, spawned by nobody: keeper-myx (two runs) and magic-tester were
## brought into it, each run with a sandbox of its own. Session rig-other was founded by the
## spawn rig-other, magic-architect; magic-developer was brought into it with a sandbox of its own.
rigRecord(){ ## sandbox folder, spawn id, session id, member
	mkdir -p "$rigSpawned/$1/input" "$rigSpawned/$1/output" || exit 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: rig\nowner: %s\nstatus: spawn-started\n---\n' "$3" "$2" "$1" "$4" > "$rigSpawned/$1/$2.md"
}
rigRecord sp-k sp-k rig-root keeper-myx
rigRecord sp-k2 sp-k2 rig-root keeper-myx
rigRecord sp-t sp-t rig-root magic-tester
rigRecord rig-other rig-other rig-other magic-architect
rigRecord sp-d sp-d rig-other magic-developer
## A run whose own record names a session id that is no bare name, and that the proxy named no session for.
rigRecord sp-bad sp-bad 'rig/bad' magic-developer

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPasses=$(( rigPasses + 1 ))
	else
		rigFails=$(( rigFails + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## The environment of one of the rig's callers, as the spawn proxy or a native client gives it:
## the root session of rig-root (its member the served default, magic-coordinator), a run of a
## participant, a root session with no team identity, or one with the session id given here.
rigEnv(){ ## caller -- runs the rest of the line in that caller's environment
	local envWho="$1" ; shift
	(
		unset MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SANDBOX_ROOT_REAL MDAT_SESSION_ID MDAT_MCP_SERVED_MARKER CLAUDE_CODE_SESSION_ID
		export HOME="$rigTmp/home" MMDAPP="$rigWs" MDAT_SKILLSET_ROOT="$rigTmp/skills"
		case "$envWho" in
			root) export CLAUDE_CODE_SESSION_ID=rig-root ;;
			keeper) export CLAUDE_CODE_SESSION_ID=sp-k MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=sp-k MDAT_SESSION_ID=rig-root MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-k" ;;
			keeper2) export CLAUDE_CODE_SESSION_ID=sp-k2 MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=sp-k2 MDAT_SESSION_ID=rig-root MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-k2" ;;
			tester) export CLAUDE_CODE_SESSION_ID=sp-t MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=sp-t MDAT_SESSION_ID=rig-root MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-t" ;;
			architect) export CLAUDE_CODE_SESSION_ID=rig-other MDAT_SPAWN_AGENT=magic-architect MDAT_SPAWN_SESSION_ID=rig-other MDAT_SESSION_ID=rig-other MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/rig-other" ;;
			developer) export CLAUDE_CODE_SESSION_ID=sp-d MDAT_SPAWN_AGENT=magic-developer MDAT_SPAWN_SESSION_ID=sp-d MDAT_SESSION_ID=rig-other MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-d" ;;
			developer-unnamed) export MDAT_SPAWN_AGENT=magic-developer MDAT_SPAWN_SESSION_ID=sp-d MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-d" ;;
			developer-badrecord) export MDAT_SPAWN_AGENT=magic-developer MDAT_SPAWN_SESSION_ID=sp-bad MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/sp-bad" ;;
			nobody) export CLAUDE_CODE_SESSION_ID=rig-root MDAT_SKILLSET_ROOT="$rigTmp/no-skills" ;;
			session=*) [ -z "${envWho#session=}" ] || export CLAUDE_CODE_SESSION_ID="${envWho#session=}" ;;
		esac
		cd "$rigWs" && "$@"
	)
}
rigCall(){ ## caller, arguments JSON -- one served CheckList call, its result on stdout
	printf '%s' "$2" | rigEnv "$1" "$BASH" "$rigHarness" --intern-tool CheckList 2>> "$rigTmp/stderr" | rigReplyBare
}
rigFirst(){ ## text
	printf '%s\n' "$1" | LC_ALL=C awk 'NR == 1 { print ; }'
}
rigStarts(){ ## text, prefix
	case "$( rigFirst "$1" )" in "$2"*) printf 'yes' ;; *) printf 'no: %s' "$( rigFirst "$1" )" ;; esac
}
rigHolds(){ ## text, fragment
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no: %s' "$( rigFirst "$1" )" ;; esac
}
rigKept(){ ## file under the rig workspace -- the list as kept, or the word none
	[ -f "$rigWs/$1" ] || { printf 'none' ; return 0 ; }
	cat "$rigWs/$1"
}
rigLeftovers(){ ## -- files a write left behind beside a list
	find "$rigWs" -name '*.checklist.md.*' | LC_ALL=C grep -c .
}
rigLists(){ ## -- every list kept in the rig, with its bytes
	find "$rigWs" -name '*.checklist.md' -o -name 'todos.json' | LC_ALL=C sort | while IFS= read -r rigFile ; do
		printf '%s %s\n' "${rigFile#$rigWs/}" "$( cksum < "$rigFile" | tr -s ' ' '-' )"
	done
}
rigRootPlace=".local/agents/sessions/rig-root"
rigOtherPlace=".local/agents/spawned/rig-other"

rigList1='[{"content":"Read the brief","status":"completed","activeForm":"Reading the brief"},{"content":"Write the check","status":"in_progress","activeForm":"Writing the check"},{"content":"Run the check","status":"pending","activeForm":"Running the check"}]'
rigMd1='- [x] Read the brief
- [ ] Write the check (in progress: Writing the check)
- [ ] Run the check'
rigList2='[{"content":"Hand back","status":"in_progress","activeForm":"Handing back"}]'
rigMd2='- [ ] Hand back (in progress: Handing back)'
rigList3='[{"content":"Fix the reader","status":"completed","activeForm":"Fixing the reader"},{"content":"Line one\nline two","status":"pending","activeForm":"Doing both lines"}]'
rigMd3='- [x] Fix the reader
- [ ] Line one line two'
rigList4='[{"content":"Draw the boundary","status":"in_progress","activeForm":"Drawing the boundary"}]'
rigMd4='- [ ] Draw the boundary (in progress: Drawing the boundary)'
rigList5='[{"content":"Second run step","status":"pending","activeForm":"Stepping"}]'
rigMd5='- [ ] Second run step'
rigList6='[{"content":"Check the idiom","status":"completed","activeForm":"Checking the idiom"}]'
rigMd6='- [x] Check the idiom'

echo "-- 1. a session a root session founded keeps its lists in the session folder --"
rigOut="$( rigCall root '{"todos":'"$rigList1"'}' )"
rigAssert "the call is answered OK" "$( rigStarts "$rigOut" 'OK: ' )" "yes"
rigAssert "the answer names the member, the session and the count" "$( rigHolds "$rigOut" 'checklist of magic-coordinator in session rig-root now holds 3 item(s): 1 pending, 1 in progress, 1 completed' )" "yes"
rigAssert "the answer names where it is kept" "$( rigHolds "$rigOut" "$rigRootPlace/magic-coordinator.checklist.md" )" "yes"
rigAssert "the list is kept as Markdown, byte for byte" "$( rigKept "$rigRootPlace/magic-coordinator.checklist.md" )" "$rigMd1"
rigAssert "no temporary file is left beside it" "$( rigLeftovers )" "0"

echo "-- 2. the next call replaces the whole list --"
rigOut="$( rigCall root '{"todos":'"$rigList2"',"description":"rig replace"}' )"
rigAssert "the call is answered OK" "$( rigStarts "$rigOut" 'OK: ' )" "yes"
rigAssert "the list kept is the new one alone" "$( rigKept "$rigRootPlace/magic-coordinator.checklist.md" )" "$rigMd2"

echo "-- 3. a participant writes its own list, in the session's place, and no other --"
rigOut="$( rigCall keeper '{"todos":'"$rigList3"'}' )"
rigAssert "the call is answered OK, naming its list" "$( rigHolds "$rigOut" "checklist of keeper-myx in session rig-root now holds 2 item(s): 1 pending, 0 in progress, 1 completed. Kept in $rigRootPlace/keeper-myx.checklist.md" )" "yes"
rigAssert "its list is kept in the session's place, a line an item" "$( rigKept "$rigRootPlace/keeper-myx.checklist.md" )" "$rigMd3"
rigAssert "the list of the root session is untouched" "$( rigKept "$rigRootPlace/magic-coordinator.checklist.md" )" "$rigMd2"
rigAssert "nothing is kept in its own sandbox" "$( find "$rigSpawned/sp-k" -type f ! -name 'sp-k.md' | LC_ALL=C grep -c . )" "0"

echo "-- 4. one member, one list: every run of a member reads and writes the same one --"
rigAssert "a second run of keeper-myx reads the list the first wrote" "$( rigCall keeper2 '{}' )" "CHECKLIST of keeper-myx in session rig-root ($rigRootPlace/keeper-myx.checklist.md):
$rigMd3"
rigOut="$( rigCall keeper2 '{"todos":'"$rigList5"'}' )"
rigAssert "its write replaces that one list" "$( rigKept "$rigRootPlace/keeper-myx.checklist.md" )" "$rigMd5"
rigAssert "the first run reads it so" "$( rigHolds "$( rigCall keeper '{}' )" "$rigMd5" )" "yes"
rigAssert "no second list is kept for it" "$( find "$rigWs" -name 'keeper-myx.checklist.md' | LC_ALL=C grep -c . )" "1"
rigOut="$( rigCall keeper '{"todos":'"$rigList3"'}' )"

echo "-- 5. bad input is refused, and nothing is written --"
rigBefore="$( rigLists )"
rigBad=0
while IFS='|' read -r rigLabel rigArgs rigWant ; do
	[ -n "$rigLabel" ] || continue
	rigBad=$(( rigBad + 1 ))
	rigOut="$( rigCall keeper "$rigArgs" )"
	rigAssert "$rigLabel: refused with ERROR" "$( rigStarts "$rigOut" 'ERROR: ' )" "yes"
	rigAssert "$rigLabel: the refusal says why" "$( rigHolds "$rigOut" "$rigWant" )" "yes"
	rigAssert "$rigLabel: the refusal says nothing was written" "$( rigHolds "$rigOut" 'Nothing was written.' )" "yes"
	rigAssert "$rigLabel: every list is unchanged" "$( rigLists )" "$rigBefore"
	rigAssert "$rigLabel: no temporary file is left" "$( rigLeftovers )" "0"
done <<'RIGBAD'
an unknown status|{"todos":[{"content":"x","status":"done","activeForm":"Doing x"}]}|status must be pending, in_progress or completed
no activeForm|{"todos":[{"content":"x","status":"pending"}]}|item 1 of 1: activeForm
an empty content|{"todos":[{"content":"","status":"pending","activeForm":"Doing x"}]}|item 1 of 1: content
a bad second item|{"todos":[{"content":"ok","status":"pending","activeForm":"Doing ok"},{"content":"y","status":"pending"}]}|item 2 of 2: activeForm
an item that is no object|{"todos":["do x"]}|item 1 of 1
todos that is no array|{"todos":"do x"}|todos must be an array
todos with member|{"todos":[],"member":"magic-tester"}|give todos, or member, not both
arguments that are no JSON|not json|no JSON object
RIGBAD
rigAssert "every bad input was tried" "$rigBad" "8"

echo "-- 6. a read: the caller's own list, another participant's, or every participant's --"
rigBefore="$( rigLists )"
rigAssert "with no member, a participant reads its own list" "$( rigCall keeper '{}' )" "CHECKLIST of keeper-myx in session rig-root ($rigRootPlace/keeper-myx.checklist.md):
$rigMd3"
rigAssert "and the root session its own" "$( rigCall root '{"description":"rig read"}' )" "CHECKLIST of magic-coordinator in session rig-root ($rigRootPlace/magic-coordinator.checklist.md):
$rigMd2"
rigAssert "a participant reads another's by its member name" "$( rigCall tester '{"member":"magic-coordinator"}' )" "CHECKLIST of magic-coordinator in session rig-root ($rigRootPlace/magic-coordinator.checklist.md):
$rigMd2"
rigAssert "a participant that kept no list reads as empty" "$( rigCall keeper '{"member":"magic-tester"}' )" "CHECKLIST of magic-tester in session rig-root ($rigRootPlace/magic-tester.checklist.md):
(empty)"
rigWant="CHECKLISTS of session rig-root: 3 participant(s), each under its member name.

## keeper-myx ($rigRootPlace/keeper-myx.checklist.md)
$rigMd3

## magic-coordinator ($rigRootPlace/magic-coordinator.checklist.md)
$rigMd2

## magic-tester ($rigRootPlace/magic-tester.checklist.md)
(empty)"
rigAssert "with *, a participant reads every participant's list" "$( rigCall keeper '{"member":"*"}' )" "$rigWant"
rigAssert "the root session reads the same" "$( rigCall root '{"member":"*"}' )" "$rigWant"
rigOut="$( rigCall keeper '{"member":"magic-architect"}' )"
rigAssert "a member of another session is refused" "$( rigStarts "$rigOut" 'ERROR: magic-architect is not a participant of session rig-root' )" "yes"
rigAssert "the refusal names the participants" "$( rigHolds "$rigOut" 'Its participants are: keeper-myx, magic-coordinator, magic-tester.' )" "yes"
rigAssert "a name that is no bare name is refused" "$( rigStarts "$( rigCall keeper '{"member":"../x"}' )" 'ERROR: ' )" "yes"
rigAssert "no read wrote anything" "$( rigLists )" "$rigBefore"

echo "-- 7. a session a spawn founded keeps its lists in that spawn's sandbox root --"
rigOut="$( rigCall architect '{"todos":'"$rigList4"'}' )"
rigAssert "the founder's list is kept in its sandbox root" "$( rigKept "$rigOtherPlace/magic-architect.checklist.md" )" "$rigMd4"
rigOut="$( rigCall developer '{"todos":'"$rigList6"'}' )"
rigAssert "a participant with a sandbox of its own keeps it there too" "$( rigKept "$rigOtherPlace/magic-developer.checklist.md" )" "$rigMd6"
rigAssert "a run the proxy named no session for finds it by its own record" "$( rigCall developer-unnamed '{}' )" "CHECKLIST of magic-developer in session rig-other ($rigOtherPlace/magic-developer.checklist.md):
$rigMd6"
rigAssert "it reads its own session alone" "$( rigCall architect '{"member":"*"}' )" "CHECKLISTS of session rig-other: 2 participant(s), each under its member name.

## magic-architect ($rigOtherPlace/magic-architect.checklist.md)
$rigMd4

## magic-developer ($rigOtherPlace/magic-developer.checklist.md)
$rigMd6"
rigAssert "rig-root does not read it" "$( rigCall root '{"member":"*"}' )" "$rigWant"
rigAssert "nothing is kept in input/ or output/ of any sandbox" "$( find "$rigSpawned"/*/input "$rigSpawned"/*/output -type f | LC_ALL=C grep -c . )" "0"

echo "-- 8. an empty list is a valid list, shown as empty --"
rigOut="$( rigCall keeper '{"todos":[]}' )"
rigAssert "it is answered OK, with no item" "$( rigHolds "$rigOut" 'now holds 0 item(s)' )" "yes"
rigAssert "the list kept is empty" "$( rigKept "$rigRootPlace/keeper-myx.checklist.md" )" ""
rigAssert "a read shows it as empty" "$( rigHolds "$( rigCall root '{"member":"*"}' )" "## keeper-myx ($rigRootPlace/keeper-myx.checklist.md)
(empty)" )" "yes"

echo "-- 9. no team identity, no session, or a session id that is no bare name: no tool --"
rigBefore="$( rigLists )"
for rigWho in nobody session= session=../escape session=.. ; do
	for rigArgs in '{"todos":'"$rigList2"'}' '{}' ; do
		rigOut="$( rigCall "$rigWho" "$rigArgs" )"
		rigAssert "$rigWho $rigArgs: refused" "$( rigStarts "$rigOut" 'ERROR: ' )" "yes"
		rigAssert "$rigWho $rigArgs: it says the tool is not offered" "$( rigHolds "$rigOut" 'CheckList is not offered' )" "yes"
	done
done
rigAssert "none of them wrote anything" "$( rigLists )" "$rigBefore"
rigAssert "no todos.json is kept anywhere: there is one store" "$( find "$rigWs" -name 'todos.json*' | LC_ALL=C grep -c . )" "0"

echo "-- 10. offered only where the harness knows the member and the place, on the MCP floor --"
rigServed(){ ## caller -- yes when the server's tools/list offers CheckList, then a call's first line
	{
		printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
		printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
		printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"CheckList","arguments":{"todos":[{"content":"Served","status":"pending","activeForm":"Serving"}]}}}'
	} | rigEnv "$1" "$BASH" "$rigTool" --intern-mcp-server --run > "$rigTmp/served.wire" 2>> "$rigTmp/stderr"
	LC_ALL=C grep '"id":2,' "$rigTmp/served.wire" | LC_ALL=C grep -q -F '{"name":"CheckList",' && printf 'offered' || printf 'not-offered'
	LC_ALL=C grep '"id":3,' "$rigTmp/served.wire" | LC_ALL=C grep -q -F -e '"error"' -e '"isError":true' && printf ' refused' || printf ' served'
}
rigLists > "$rigTmp/lists.before"
rigAssert "the root session of rig-root is offered it, and served" "$( rigServed root )" "offered served"
rigAssert "a participant is offered it, and served" "$( rigServed tester )" "offered served"
rigLists > "$rigTmp/lists.served"
rigAssert "no team identity: not offered, and a call is refused" "$( rigServed nobody )" "not-offered refused"
rigAssert "no session: not offered, and a call is refused" "$( rigServed session= )" "not-offered refused"
rigAssert "a session id that is no bare name: not offered" "$( rigServed session=../escape )" "not-offered refused"
rigAssert "the refused calls wrote nothing" "$( rigLists )" "$( cat "$rigTmp/lists.served" )"
rigAssert "a run whose own record names no bare session id: not offered, and a call is refused" "$( rigServed developer-badrecord )" "not-offered refused"
rigAssert "the server asks once for its life: a second request is answered the same" "$( rigServed root )" "offered served"

echo "-- 11. the declaration: the native item shape, todos optional, and what it is --"
rigFloor="$( bash "$rigHere/AgentsHarnessMcpMirror.sh" "" "Bash Monitor" 2> /dev/null )" || rigFloor=""
rigFloor='{"t":'"$rigFloor"'}'
rigSchema="" rigText="" rigIndex=0
while : ; do
	rigName="$( printf '%s\n' "$rigFloor" | LC_ALL=C awk -v path="t.$rigIndex.name" -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" 2> /dev/null )" || rigName=""
	[ -n "$rigName" ] || break
	if [ "$rigName" = "CheckList" ] ; then
		rigSchema="$( printf '%s\n' "$rigFloor" | LC_ALL=C awk -v path="t.$rigIndex.inputSchema" -v mode=raw -f "$rigHere/AgentsHarnessJsonField.awk" 2> /dev/null )"
		rigText="$( printf '%s\n' "$rigFloor" | LC_ALL=C awk -v path="t.$rigIndex.description" -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" 2> /dev/null )"
		break
	fi
	rigIndex=$(( rigIndex + 1 ))
done
rigAssert "CheckList is declared" "$( [ -n "$rigSchema" ] && printf 'declared' || printf 'absent' )" "declared"
rigAssert "no parameter is required" "$( rigHolds "$rigSchema" '},"required":[]}' )" "yes"
rigAssert "each item takes content, status and activeForm, all required" "$( rigHolds "$rigSchema" '"required":["content","status","activeForm"]' )" "yes"
rigAssert "status is one of the three native states" "$( rigHolds "$rigSchema" '"enum":["pending","in_progress","completed"]' )" "yes"
rigAssert "member is a string parameter" "$( rigHolds "$rigSchema" '"member":{"type":"string"' )" "yes"
for rigWord in TodoWrite checklist 'session tasks' 'NOT the team board' 'NOT an inbox' 'returns your own list' 'with member set to *' 'one list in a session' ; do
	rigAssert "its description says: $rigWord" "$( rigHolds "$rigText" "$rigWord" )" "yes"
done

echo "-- 12. a ToolSearch finds it by the words a member reaches for, where it is offered --"
rigSearch(){ ## caller, query -- the names of the tools found, in order
	printf '{"query":"%s"}' "$2" | rigEnv "$1" "$BASH" "$rigHarness" --intern-tool ToolSearch 2>> "$rigTmp/stderr" \
		| LC_ALL=C grep -o '"name":"[A-Za-z_]*","parameters":' | sed 's/^"name":"//; s/".*$//' | tr '\n' ' '
}
rigFound(){ ## names found, name
	case " $1" in *" $2 "*) printf 'found' ;; *) printf 'not found: %s' "$1" ;; esac
}
rigAssert "TodoWrite finds it first" "$( rigSearch root TodoWrite | cut -d' ' -f1 )" "CheckList"
rigAssert "checklist finds it first" "$( rigSearch root checklist | cut -d' ' -f1 )" "CheckList"
rigAssert "session tasks finds it" "$( rigFound "$( rigSearch root 'session tasks' )" CheckList )" "found"
rigAssert "with no team identity, no search finds it" "$( rigFound "$( rigSearch nobody TodoWrite )" CheckList )" "not found: "

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CHECKLIST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: CheckList does not keep, replace, refuse, read or offer the checklists of a session" >&2
	echo "        as it is meant to, or one session's list reaches another" >&2
	echo "  fix:  repair AgentsHarnessToolCheckList in sh-lib/AgentsUniversalHarness.sh, or the floor in" >&2
	echo "        sh-lib/AgentsTools.InternMcpRequest.include -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_CHECKLIST: OK (%d assertions, offline)\n' "$rigPasses"
