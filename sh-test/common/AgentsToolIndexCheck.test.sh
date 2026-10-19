#!/usr/bin/env bash
## Behavioural check on the tool index (F7.1 of the refactorings epic): `--intern-op-tool-index` writes
## `.local/agents/tool-index.md`, generated, never written by hand, and the index is served to a session as one section
## of its Skill read, merged by --intern-merge-md-files (F2.1). It covers the shell operations of every DistroAgents*
## and Agent*Tools file and the harness and MCP tools. For the reading member, an operation it may call is listed with
## its one-line description; every other one only by its family, with its owner and a hint: ask that owner, or read
## `--help-syntax <op>`. Who may use what comes from the grants floor (AgentsToolsGrantsBuiltinText) and the project.inf
## permissions. It serves the input token cache: two generations are byte-identical, in a deterministic order, with no
## timestamps.
## Held:
##   1. the generator exits 0 and writes .local/agents/tool-index.md
##   2. it names every DistroAgents*.fn.sh and Agent*Tools.fn.sh file of the package, every harness tool of its tools
##      list, and the MCP server's own tools
##   3. two generations are byte-identical, and it holds no date or time
##   4. the coordinator's Skill read holds the index as one section; --magic-advance-lock-status, which it may call, is
##      listed there with its description
##   5. the tester's Skill read lists that operation by its family only, with its owner and the hint
##   6. a project.inf permission: WebFetch, allowed to magic-architect alone, is listed with its description in the
##      architect's read, and only by owner and hint in the tester's
##   7. the hint's help call: `--help-syntax <op>` prints that operation's syntax lines alone, a family prefix those of
##      its family alone, and a word that names none is refused
## Red before F7.1: no generator, no index (every case fails).
## Offline: a rig workspace and member set of this rig's own; the Skill reads are served calls.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigHarness" ] || rigRefuse "the tool or the harness is not at the origin this workspace resolves: $MDLT_ORIGIN"
## It names the advance scan, as text it looks for, never as a call: the guard reads names, so the rig ends threads all the same.
. "${rigHere%/sh-lib}/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsToolIndexCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigIndex="$rigWs/.local/agents/tool-index.md"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills"
for rigName in magic-coordinator magic-tester magic-architect ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nname: %s\ndescription: rig member\n---\n# %s\n\nRIG-SKILL-LINE\n' "$rigName" "$rigName" > "$rigTmp/skills/$rigName/SKILL.md"
	printf '# Basic\n\nRIG-BASIC-LINE\n' > "$rigTmp/skills/$rigName/$rigName.basic.md"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigGenerate(){ ## result name
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" --intern-op-tool-index ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
	printf '%s' "$?" > "$rigTmp/$1.rc"
}
rigSkill(){ ## member -- its served Skill read, in skill.<member>.out
	printf '{"skill":"%s"}' "$1" | ( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="rig-index-$1" bash "$rigHarness" --intern-tool Skill ) > "$rigTmp/skill.$1.out" 2> "$rigTmp/skill.$1.err"
}
## The line of a read that names the operation or tool, as `described` (its name and at least three more words, and no
## owner hint), `hinted` (its family or its name, with its owner and a hint), or `absent`.
rigListed(){ ## file, name, owner
	local listedLines
	listedLines="$( LC_ALL=C grep -F -- "$2" "$1" 2> /dev/null )"
	if [ -n "$( printf '%s\n' "$listedLines" | LC_ALL=C grep -F -- "$3" | LC_ALL=C grep -E -e 'ask' -e '--help-syntax' )" ] ; then printf hinted ; return 0 ; fi
	if [ -n "$( printf '%s\n' "$listedLines" | LC_ALL=C awk -v name="$2" '{ at = index( $0, name ) ; rest = substr( $0, at + length( name ) ) ; if ( split( rest, words, /[ \t]+/ ) >= 4 ) { print ; exit } }' )" ] ; then printf described ; return 0 ; fi
	printf absent
}
rigFamilyHinted(){ ## file, family prefix, owner -- whether a line names the family with its owner and a hint
	LC_ALL=C grep -F -- "$2" "$1" 2> /dev/null | LC_ALL=C grep -F -- "$3" | LC_ALL=C grep -q -E -e 'ask' -e '--help-syntax' && printf hinted || printf absent
}

echo "-- 1. the generator writes the index --"
rigGenerate g1
rigAssert "exit 0, and .local/agents/tool-index.md written"  "$( cat "$rigTmp/g1.rc" ):$( [ -s "$rigIndex" ] && printf written || printf none )" "0:written"
cp "$rigIndex" "$rigTmp/index.1" 2> /dev/null || : > "$rigTmp/index.1"

echo "-- 2. it covers the shell tool files, the harness tools and the MCP tools --"
rigMissing=""
for rigFile in "$rigPackage"/sh-scripts/DistroAgents*.fn.sh "$rigPackage"/sh-scripts/Agent*Tools.fn.sh ; do
	[ -f "$rigFile" ] || continue
	LC_ALL=C grep -q -F -- "${rigFile##*/}" "$rigTmp/index.1" || rigMissing="$rigMissing ${rigFile##*/}"
done
for rigName in $( LC_ALL=C grep -o '"name":"[A-Za-z]*"' "$rigHere/harness/AgentsOpenAiChatWire.sh" | LC_ALL=C sed 's/"name":"\(.*\)"/\1/' | LC_ALL=C sort -u ) execute Monitor ; do
	LC_ALL=C grep -q -w -- "$rigName" "$rigTmp/index.1" || rigMissing="$rigMissing $rigName"
done
rigAssert "every tool file and every harness and MCP tool is named" "[${rigMissing# }]" "[]"

echo "-- 3. it serves the token cache: byte-identical, no date or time --"
rigGenerate g2
rigAssert "two generations are byte-identical"                "$( [ -s "$rigTmp/index.1" ] && cmp -s "$rigTmp/index.1" "$rigIndex" && printf identical || printf different )" identical
rigAssert "and it holds no date or time"                      "$( LC_ALL=C grep -c -E '[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{8}T[0-9]{4}' "$rigIndex" 2> /dev/null || : )" 0

echo "-- 4. the coordinator's Skill read: the index as one section, its own operation described --"
rigSkill magic-coordinator
rigAssert "one section of the read is the index"              "$( LC_ALL=C grep -c -E '^#+ .*[Tt]ool' "$rigTmp/skill.magic-coordinator.out" )" 1
rigAssert "--magic-advance-lock-status, which it may call, with its description" "$( rigListed "$rigTmp/skill.magic-coordinator.out" --magic-advance-lock-status magic-coordinator )" described

echo "-- 5. the tester's Skill read: that operation by family only, with its owner and the hint --"
rigSkill magic-tester
rigAssert "not described to the tester"                       "$( rigListed "$rigTmp/skill.magic-tester.out" --magic-advance-lock-status magic-coordinator | LC_ALL=C sed 's/^hinted$/not-described/; s/^absent$/not-described/' )" not-described
rigAssert "its family, --magic-, with its owner and the hint" "$( rigFamilyHinted "$rigTmp/skill.magic-tester.out" '--magic-' magic-coordinator )" hinted

echo "-- 6. a project.inf permission: WebFetch for the architect alone --"
rigSkill magic-architect
rigAssert "the architect's read describes WebFetch"           "$( rigListed "$rigTmp/skill.magic-architect.out" WebFetch magic-architect )" described
rigAssert "the tester's read names it only with its owner and the hint" "$( rigListed "$rigTmp/skill.magic-tester.out" WebFetch magic-architect )" hinted

echo "-- 7. the hint's help call: --help-syntax <op> --"
rigHelp(){ ## result name, words... -- the help call, its stderr and rc
	local helpName="$1" ; shift
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" --help-syntax "$@" ) > /dev/null 2> "$rigTmp/$helpName.err"
	printf '%s' "$?" > "$rigTmp/$helpName.rc"
}
rigSyntaxOf(){ ## result name -- its syntax lines, as `<op>`, each once
	LC_ALL=C sed -n 's/^📘 syntax: [^ ]* \(--[^ ]*\).*/\1/p' "$rigTmp/$1.err" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigHelp h1 --magic-advance-lock-status
rigAssert "one operation: its syntax line alone"              "$( cat "$rigTmp/h1.rc" ):$( rigSyntaxOf h1 )" "0:--magic-advance-lock-status "
rigHelp h2 --magic-
rigAssert "a family prefix: its operations alone, more than one" "$( cat "$rigTmp/h2.rc" ):$( rigSyntaxOf h2 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -v -e '^--magic-' -e '^$' ):$( rigSyntaxOf h2 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c '^--magic-' )" "0:0:$( LC_ALL=C sed -n 's/^📘 syntax: [^ ]* \(--magic-[^ ]*\).*/\1/p' "${rigHere}/help/Help.DistroAgentsTools.help.md" | LC_ALL=C sort -u | LC_ALL=C grep -c . )"
rigHelp h3 --no-such-operation
rigAssert "a word that names none is refused"                 "$( cat "$rigTmp/h3.rc" ):$( LC_ALL=C grep -c -F -- '--help-syntax --no-such-operation: no operation is named so' "$rigTmp/h3.err" )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOL INDEX CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_INDEX: OK (%d assertions, offline)\n' "$rigPassCount"
