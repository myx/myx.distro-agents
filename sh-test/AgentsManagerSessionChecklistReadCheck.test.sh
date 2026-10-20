#!/usr/bin/env bash
## Behavioural check on --manager-session-checklist-read --session-id <id> <member> (F11.5 of the refactorings epic: the CheckList of a session
## participant), the console's read of the checklist one member keeps in one coworking session -- run rather than read, against a rig workspace built
## here: its own spawn records and session stores.
## Held: the file <member>.checklist.md that the CheckList tool keeps in the place of the session, as it stands, byte for byte; that place is the folder
## of the record of the spawn that founded the session (spawn-id the session id) where there is one, else the folder sessions/<id> of the workspace; a
## member that kept none gives nothing and status 0; one member's list is never another's; a missing --session-id, a missing member, a second member, an
## option it does not take, and a name that is no bare name are each refused, status 1, nothing on stdout, in one line with the syntax; from inside a
## member's session it is refused as every --manager-* operation is; it writes nothing, and leaves no scratch file. And the help pair: its syntax echo, its
## syntax line and its entry, once each. Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-checklist-read"
rigSyntax="--session-id <id> <member>"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionChecklistReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents" ; rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigTree(){ ## -- every file of the rig workspace with the sum of its bytes, as one sum
	( cd "$rigWs" && find . -type f | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}

## THE STORES. A session that a spawn founded: its record in a sandbox folder of its own, the lists of two members in that folder; and a session that no
## record names: its lists in the folder sessions/<id>. Each list holds an item done, one not yet and one in progress.
mkdir -p "$rigSp/sess-c" "$rigStores/sess-c" "$rigStores/sess-d"
printf -- '---\nsession-id: sess-c\nspawn-id: sess-c\nhost: rig-host\nworkspace: rigws\nowner: magic-coordinator\nstatus: spawn-succeeded\nstarted-at: 2026-10-13 09:00 +0300\n---\n\n# Spawn session\n' > "$rigSp/sess-c/sess-c.md"
printf -- '- [x] read the brief\n- [ ] write the check (in progress: writing the check)\n- [ ] report\n' > "$rigSp/sess-c/keeper-rig.checklist.md"
printf -- '- [ ] the other member item\n' > "$rigSp/sess-c/magic-tester.checklist.md"
printf -- '- [ ] this one is in the wrong place\n' > "$rigStores/sess-c/keeper-rig.checklist.md"
printf -- '- [x] a list kept in the session folder\n' > "$rigStores/sess-d/magic-tester.checklist.md"
rigBefore="$( rigTree )"

echo "-- the lists --"
rigRun "$rigOp" --session-id sess-c keeper-rig
rigAssert "the list of a session a spawn founded is read from the folder of that spawn's record, as it stands" "$rigRc $( cat "$rigTmp/out" | cksum )" "0 $( printf -- '- [x] read the brief\n- [ ] write the check (in progress: writing the check)\n- [ ] report\n' | cksum )"
rigRun "$rigOp" --session-id sess-c magic-tester
rigAssert "another member's list in that session is that member's own" "$rigRc $( cat "$rigTmp/out" )" "0 - [ ] the other member item"
rigRun "$rigOp" --session-id sess-d magic-tester
rigAssert "a session no record names has its lists in the folder sessions/<id>" "$rigRc $( cat "$rigTmp/out" )" "0 - [x] a list kept in the session folder"
rigRun "$rigOp" --session-id sess-d keeper-rig
rigAssert "a member that kept none gives nothing, and status 0" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -E 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -e SystemContext.SetInputSpec | LC_ALL=C tr -d ' ' )" "0 0 0"
rigRun "$rigOp" --session-id no-such-session keeper-rig
rigAssert "so does a session nothing has run in" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "0 0"

echo "-- the refusals --"
rigRun "$rigOp" keeper-rig
rigAssert "with no --session-id it is refused in one line with its syntax" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -e "$rigOp: syntax is $rigSyntax, got no --session-id" "$rigTmp/err" | LC_ALL=C tr -d ' ' )" "1 0 1"
rigRun "$rigOp" --session-id sess-c
rigAssert "with no member, the same" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -e "$rigOp: syntax is $rigSyntax, got no member" "$rigTmp/err" | LC_ALL=C tr -d ' ' )" "1 0 1"
rigRun "$rigOp" --session-id sess-c keeper-rig magic-tester
rigAssert "a second member, the same" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -e "got a second member: magic-tester" "$rigTmp/err" | LC_ALL=C tr -d ' ' )" "1 0 1"
rigRun "$rigOp" --session-id sess-c --all keeper-rig
rigAssert "an option it does not take, the same" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -e "got: --all" "$rigTmp/err" | LC_ALL=C tr -d ' ' )" "1 0 1"
rigBad=""
for rigName in '../keeper-rig' 'a/b' '.' 'two words' ; do
	rigRun "$rigOp" --session-id sess-c "$rigName"
	rigBad="$rigBad[$rigRc/$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )]"
	rigRun "$rigOp" --session-id "$rigName" keeper-rig
	rigBad="$rigBad[$rigRc/$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )]"
done
rigAssert "a name that is no bare name, as the member or as the session, is refused, and nothing is read from beyond the folder" "$rigBad" "[1/0][1/0][1/0][1/0][1/0][1/0][1/0][1/0]"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigOp" --session-id sess-c keeper-rig
rigPre=()
rigAssert "from inside a member's session it is refused, in the one line of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"

echo "-- it writes nothing --"
rigAssert "no file of the rig workspace was changed, made or left behind by any call" "$( rigTree )" "$rigBefore"

echo "-- the help pair --"
rigAssert "$rigOp $rigSyntax has its syntax echo, its syntax line and its entry, once each" \
	"$( rigWhole "$rigHere/help/Help.DistroAgentsTools.include" "echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntax\" >&2" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntax" ) $( rigWhole "$rigHere/help/Help.DistroAgentsTools.help.md" "$( printf '\t\t%s' "$rigOp $rigSyntax" )" )" "1 1 1"
rigAssert "the operation is one arm of the include of the sessions" "$( LC_ALL=C grep -c -x -e "	$rigOp)" "$rigHere/manager/AgentsTools.ManagerSession.include" || : )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION CHECKLIST READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_CHECKLIST_READ: OK (%d assertions, offline)\n' "$rigPassCount"
