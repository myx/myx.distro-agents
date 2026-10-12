#!/usr/bin/env bash
## Behavioural check on the registries --make-agents-indices rebuilds, run rather than read, against a rig workspace
## built here: its own member registry and skillset, its own spawn sandboxes, its own asks and its own board. Held:
## the build, taking no argument, rebuilds all four registries -- team-members, team-members-names, spawned-sessions,
## pending-replies -- each whole, from its store, by the one rebuild function every other rebuild of that registry
## calls, and then makes the member index and the grants as before. A file that is behind its store is brought up
## to date. An occasion with no session store, a workspace as an install first meets it, ends 0: each registry is
## written with no rows, in a plain note, with no error and no warning, the build goes on to its indices, and no
## store is made. The board half of pending-replies is read through the data root the dispatcher itself resolves.
## Each registry is noted once on stderr with its file and its count of rows, nothing on stdout. The source-prepare
## builder is the same build. The build and a session's own rebuilds at once, each a process of its own, leave whole
## files and no temp name behind. The operation still takes no argument. And its help entry names the four. A fake
## `curl` first on PATH would log a request: none is made. Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRegInclude="$rigHere/AgentsTools.Registries.include"
rigBuilder="$rigPackage/builders/source-prepare/1201-agents-indices.sh"
rigOpName="--make-agents-indices"
rigAll="team-members team-members-names spawned-sessions pending-replies"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRegInclude" ] || rigRefuse "the registries include is not at: $rigRegInclude"
[ -f "$rigBuilder" ] || rigRefuse "the source-prepare builder is not at: $rigBuilder"
rigTmp="$( mktemp -d -t AgentsMakeIndicesRegistriesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigHome="$rigTmp/home"
rigAgents="$rigWs/.local/agents"
## The team data store where the dispatcher finds it for a workspace that names none: this check hands the build no
## data root, so a board item among the pending replies was read through the one the operation resolved itself.
rigData="$rigAgents/team-data-root"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSkills" "$rigHome"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a request of this check would be a real one"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The rig's stores. Every record of one round carries that round's word, so a file that holds it was built after it.
rigMember(){ ## member, Name as written, alias, mark -- its skillset folder and its row of this workspace's member registry
	mkdir -p "$rigSkills/$1" "$rigAgents"
	printf -- '---\nmaintainers: rig\n---\n# %s\n- **Name**: %s\n- **Alias**: `%s`.\n- **Unicode character**: %s\n' "$1" "$2" "$3" "$4" > "$rigSkills/$1/$1.basic.md"
	printf -- '---\nname: %s\nstatus: active\ndescription: rig\n---\n\n# %s\n' "$1" "$1" > "$rigSkills/$1/SKILL.md"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' "$1" "$rigWs" "myx/pkg/skillset/$1" "$rigWs/source/myx/pkg/skillset/$1" >> "$rigAgents/members.registry"
}
rigSpawn(){ ## sandbox, spawn id -- one spawn record in a sandbox of its own
	mkdir -p "$rigAgents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nowner: keeper-rig\nstatus: spawn-started\n---\nbody\n' "$2" "$2" > "$rigAgents/spawned/$1/$2.md"
}
rigAsk(){ ## record name -- one open ask
	mkdir -p "$rigAgents/pending"
	printf -- '---\nstatus: reply-pending\nsession-id: sess-of-%s\nowner: keeper-rig\ncommunication-channel-id: CRIG00001\n---\nq\n' "$1" > "$rigAgents/pending/$1.md"
}
rigBoard(){ ## item name -- one board item that waits on a reply
	mkdir -p "$rigData/board/running"
	printf -- '---\nblocked-on: human\nstatus: waiting\nsession-id: sess-of-%s\nowner: keeper-rig\n---\n' "$1" > "$rigData/board/running/$1.md"
}
rigRound(){ ## round word -- one more record in every store
	rigMember "keeper-$1" "Rig ${1}keeper." "alias$1" 🔧
	rigSpawn "s-$1" "spawn-$1"
	rigAsk "ask-$1"
	rigBoard "task-$1"
}
rigFile(){ ## registry name -- its file
	printf '%s\n' "$rigAgents/$1.registry"
}
rigLines(){ ## file -- its lines; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 }' "$1"
}
rigRows(){ ## registry name, first column -- how many rows of that registry's file carry it; no-file where there is none
	[ -f "$( rigFile "$1" )" ] || { printf 'no-file\n' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '$1 == want { n++ } END { print n + 0 }' "$( rigFile "$1" )"
}
rigHolds(){ ## round word -- for each of the four files, in the order of rigAll, how many of that round's records it holds: the board item last
	printf '%s %s %s %s %s\n' "$( rigRows team-members "keeper-$1" )" "$( rigRows team-members-names "keeper-$1" )" "$( rigRows spawned-sessions "s-$1" )" "$( rigRows pending-replies "ask-$1.md" )" "$( rigRows pending-replies "task-$1.md" )"
}
rigSizes(){ ## -- the lines of the four files, in the order of rigAll
	printf '%s %s %s %s\n' "$( rigLines "$( rigFile team-members )" )" "$( rigLines "$( rigFile team-members-names )" )" "$( rigLines "$( rigFile spawned-sessions )" )" "$( rigLines "$( rigFile pending-replies )" )"
}
rigRun(){ ## tool arguments... -- in the rig workspace; rc in rigRc, stdout in $rigTmp/out, stderr in $rigTmp/err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigBuild(){ ## -- the build, with no argument
	rigRun "$rigOpName"
}
rigNote(){ ## registry name -- the line the build notes that registry with, for its file as it stands now
	printf '# DistroAgentsTools %s: wrote %s (%s rows)\n' "$rigOpName" "$( rigFile "$1" )" "$( rigLines "$( rigFile "$1" )" )"
}
rigNotes(){ ## -- those lines for the four, in the order of rigAll
	local notesName
	for notesName in $rigAll ; do rigNote "$notesName" ; done
}
rigNoted(){ ## -- the lines of the last run's stderr that note a registry file, whole, in order
	LC_ALL=C grep -E -- '^# DistroAgentsTools --make-agents-indices: wrote .*\.registry \([0-9]+ rows\)$' "$rigTmp/err" || :
}
rigErrN(){ ## fixed text -- how many lines of the last run's stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
## The tool's own errors and warnings only. A rig workspace is no distro workspace, which the context says in a line
## of its own before the operation starts (SystemContext.SetInputSpec), in every rig of this package.
rigTroubles(){ ## files... (the last run's stderr where none is given) -- how many lines of them are an error or a warning of the tool's
	[ $# -gt 0 ] || set -- "$rigTmp/err"
	cat "$@" | LC_ALL=C grep -E -- 'ERROR|WARNING' | LC_ALL=C grep -c -F -- 'DistroAgentsTools' || :
}
rigOutBytes(){ ## -- the bytes of the last run's stdout
	wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' '
}
rigRowsOf(){ ## rows function, output file -- what that function prints for the rig's stores now, called by this check itself
	( MMDAPP="$rigWs" ; MDAT_DATA_ROOT="$rigData" ; MDAT_SKILLSET_ROOT="$rigSkills" ; export MMDAPP MDAT_DATA_ROOT MDAT_SKILLSET_ROOT
		. "$rigRegInclude" ; "$1" ) > "$2" 2> /dev/null
}
rigSame(){ ## rows function, registry name -- whether that registry's file is, byte for byte, what its rows function prints now
	rigRowsOf "$1" "$rigTmp/want.rows"
	if cmp -s "$rigTmp/want.rows" "$( rigFile "$2" )" ; then printf 'same\n' ; else printf 'differs\n' ; fi
}

echo "-- 1. an occasion with no store: a workspace as an install first meets it --"
rigAssert "control: the workspace holds no member registry, no sandbox, no ask and no team data, and no registry file" "$( ls "$rigWs/.local" | LC_ALL=C tr '\n' ' ' )$( [ -e "$rigAgents" ] && echo there || echo none )" "none"
rigBuild
rigAssert "the build ends 0 and prints nothing on stdout" "$rigRc $( rigOutBytes )" "0 0"
rigAssert "all four registries are written, each with no rows" "$( rigSizes )" "0 0 0 0"
rigAssert "each is noted once, in a plain line, in the order of the list" "$( rigNoted )" "$( rigNotes )"
rigAssert "with no error and no warning of the tool's" "$( rigTroubles )" "0"
rigAssert "the build goes on to what it made before: the member index and the grants index, each noted" "$( [ -f "$rigAgents/members.index" ] && echo index ) $( [ -f "$rigAgents/grants.index" ] && echo grants ) $( rigErrN "# DistroAgentsTools $rigOpName: wrote $rigAgents/members.index" ) $( rigErrN "# DistroAgentsTools $rigOpName: wrote $rigAgents/grants.index" )" "index grants 1 1"
rigAssert "and it made no store of its own: no sandbox root, no ask folder, no team data root" "$( [ -e "$rigAgents/spawned" ] && echo spawned ) $( [ -e "$rigAgents/pending" ] && echo pending ) $( [ -e "$rigData" ] && echo data )" "  "

echo "-- 2. stores that hold records the files do not: every file is brought up to date --"
rigRound one
rigAssert "control: the stores hold records the four files do not" "$( rigHolds one )" "0 0 0 0 0"
rigBuild
rigAssert "the build ends 0, nothing on stdout, no error and no warning of the tool's" "$rigRc $( rigOutBytes ) $( rigTroubles )" "0 0 0"
rigAssert "each file holds the record of its store, the board item among the pending replies: read through the dispatcher's own data root" "$( rigHolds one )" "1 1 1 1 1"
rigAssert "each is noted once with its file and the rows that file has, in the order of the list" "$( rigNoted )" "$( rigNotes )"
rigAssert "the names row is the member's basic.md, as the names registry writes it" "$( LC_ALL=C grep '^keeper-one ' "$( rigFile team-members-names )" )" "keeper-one 🔧 Rig onekeeper aliasone"
rigAssert "three of the files are, byte for byte, what the registry's own rows function prints" "$( rigSame AgentsToolsRegistryTeamMembersRows team-members ) $( rigSame AgentsToolsRegistrySpawnedSessionsRows spawned-sessions ) $( rigSame AgentsToolsRegistryPendingRepliesRows pending-replies )" "same same same"
rigAssert "control: the rows this check asked for are rows, and those of another store differ" "$( rigRowsOf AgentsToolsRegistryPendingRepliesRows "$rigTmp/want.rows" ; rigLines "$rigTmp/want.rows" ) $( rigSame AgentsToolsRegistrySpawnedSessionsRows pending-replies )" "2 differs"
rigAssert "the folder holds the four registries, the member index and the grants index, beside the stores, and nothing else" "$( ls "$rigAgents" | LC_ALL=C tr '\n' ' ' )" "grants.index members members.index members.registry pending pending-replies.registry spawned spawned-sessions.registry team-data-root team-members-names.registry team-members.registry "
rigRound two
rigAssert "control: a second round of records, and the files, now with rows, are behind again" "$( rigHolds two ) $( rigSizes )" "0 0 0 0 0 1 1 1 2"
rigBuild
rigAssert "the build brings them level again: both rounds in every file" "$rigRc $( rigHolds two ) $( rigHolds one ) $( rigSizes )" "0 1 1 1 1 1 1 1 1 1 1 2 2 2 4"
rm -f "$rigAgents/pending/ask-one.md" "$rigData/board/running/task-one.md" ; rm -rf "$rigAgents/spawned/s-one"
rigBuild
rigAssert "a rebuild is whole: a record gone from its store has no row left, the others stay" "$rigRc $( rigRows spawned-sessions s-one ) $( rigRows pending-replies ask-one.md ) $( rigRows pending-replies task-one.md ) $( rigSizes )" "0 0 0 0 2 2 1 2"

echo "-- 3. one writer a registry: the build's own list names the rebuild function of each of the four --"
rigListed="$( LC_ALL=C awk '/^AgentsToolsRegistryAgentsIndicesBuild\(\)\{/ { on = 1 } on { print } on && /^}/ { exit }' "$rigRegInclude" )"
rigAssert "control: the build's function was cut out of the registries include" "$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -F -- 'AgentsToolsRegistryFile' || : )" "1"
rigAssert "its list holds the four, each with the rebuild function of its name, in the order they are built" \
	"$( printf '%s\n' "$rigListed" | LC_ALL=C grep -E -- '^([[:space:]]*done <<< ")?[a-z-]+ AgentsToolsRegistry[A-Za-z]+Rebuild"?$' | LC_ALL=C sed -e 's/^[[:space:]]*done <<< "//' -e 's/"$//' | LC_ALL=C tr '\n' ' ' )" \
	"team-members AgentsToolsRegistryTeamMembersRebuild team-members-names AgentsToolsRegistryTeamMembersNamesRebuild spawned-sessions AgentsToolsRegistrySpawnedSessionsRebuild pending-replies AgentsToolsRegistryPendingRepliesRebuild "
rigAssert "the include has one writer call a registry, four in all, each from the rebuild function of that registry" \
	"$( LC_ALL=C grep -c -E -- '^[[:space:]]+AgentsToolsRegistryWrite [a-z-]+ AgentsToolsRegistry[A-Za-z]+Rows$' "$rigRegInclude" || : ) $( LC_ALL=C grep -c -F -- 'AgentsToolsRegistryWrite ' "$rigRegInclude" || : ) $( LC_ALL=C grep -c -E -- '^AgentsToolsRegistry(TeamMembers|TeamMembersNames|SpawnedSessions|PendingReplies)Rebuild\(\)\{$' "$rigRegInclude" || : )" "4 4 4"

echo "-- 4. the source-prepare builder is the same build --"
rigRound three
rigBuilderRc=0
( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPackage/sh-scripts:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
	sh "$rigBuilder" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigBuilderRc=$?
rigAssert "run as the source-prepare build runs it, the builder ends 0 and leaves all four level with their stores" "$rigBuilderRc $( rigHolds three ) $( rigTroubles )" "0 1 1 1 1 1 0"
rigAssert "and notes the four, as the build itself does" "$( rigNoted )" "$( rigNotes )"

echo "-- 5. the build and a session's own rebuilds at once, each a process of its own --"
## Stores of some size, so that the runs overlap in their reading and their writing.
rigNo=0
while [ "$rigNo" -lt 150 ] ; do
	rigNo=$(( rigNo + 1 ))
	rigSpawn "s-many-$rigNo" "spawn-many-$rigNo"
	rigAsk "ask-many-$rigNo"
done
rigRowsOf AgentsToolsRegistrySpawnedSessionsRows "$rigTmp/want.spawned" ; rigRowsOf AgentsToolsRegistryPendingRepliesRows "$rigTmp/want.pending"
rigAtOnceFailed=0 ; rigAtOnceBroken=0 ; rigAtOnceRound=0
while [ "$rigAtOnceRound" -lt 3 ] ; do
	rigAtOnceRound=$(( rigAtOnceRound + 1 ))
	rigAtOncePids=""
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOpName" ) > "$rigTmp/at-once.$rigAtOnceRound.build.out" 2> "$rigTmp/at-once.$rigAtOnceRound.build.err" < /dev/null &
	rigAtOncePids="$rigAtOncePids $!"
	for rigAtOnceNo in 1 2 ; do
		( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
			bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" && AgentsToolsRegistrySpawnedSessionsRebuild && AgentsToolsRegistryPendingRepliesRebuild && AgentsToolsRegistrySpawnedSessionsRebuild && AgentsToolsRegistryPendingRepliesRebuild' ) \
			> "$rigTmp/at-once.$rigAtOnceRound.$rigAtOnceNo.out" 2> "$rigTmp/at-once.$rigAtOnceRound.$rigAtOnceNo.err" < /dev/null &
		rigAtOncePids="$rigAtOncePids $!"
	done
	for rigAtOncePid in $rigAtOncePids ; do
		wait "$rigAtOncePid" || rigAtOnceFailed=$(( rigAtOnceFailed + 1 ))
	done
	cmp -s "$rigTmp/want.spawned" "$( rigFile spawned-sessions )" && cmp -s "$rigTmp/want.pending" "$( rigFile pending-replies )" || rigAtOnceBroken=$(( rigAtOnceBroken + 1 ))
done
rigAssert "control: the stores the runs read are of some size" "$( LC_ALL=C awk 'END { print ( NR > 150 ) ? "over 150" : NR }' "$rigTmp/want.spawned" ) $( LC_ALL=C awk 'END { print ( NR > 150 ) ? "over 150" : NR }' "$rigTmp/want.pending" )" "over 150 over 150"
rigAssert "three rounds, a build and two rebuilding processes at once: every one ends 0, with no error and no warning of the tool's" "$rigAtOnceFailed $( rigTroubles "$rigTmp"/at-once.*.err ) $( cat "$rigTmp"/at-once.*.[12].err | LC_ALL=C awk 'END { print NR + 0 }' )" "0 0 0"
rigAssert "each build noted both session registries" "$( cat "$rigTmp"/at-once.*.build.err | LC_ALL=C grep -c -F -- "wrote $( rigFile spawned-sessions ) (" || : ) $( cat "$rigTmp"/at-once.*.build.err | LC_ALL=C grep -c -F -- "wrote $( rigFile pending-replies ) (" || : )" "3 3"
rigAssert "after every round both files are whole: byte for byte what the rows functions print for the stores" "$rigAtOnceBroken" "0"
rigAssert "and no temp name is left beside the registries" "$( ls "$rigAgents" | LC_ALL=C grep -c -F -- '.registry.' || : )" "0"

echo "-- 6. the operation takes no argument, as before --"
rigSum="$( cat "$( rigFile team-members )" "$( rigFile team-members-names )" "$( rigFile spawned-sessions )" "$( rigFile pending-replies )" | cksum )"
rigRound six
rigRun "$rigOpName" spawned-sessions
rigAssert "a registry's name after it is refused as any argument is: exit 1, named, and nothing is rebuilt" "$rigRc $( rigErrN "$rigOpName takes no arguments, got: spawned-sessions" ) $( rigHolds six ) $( cat "$( rigFile team-members )" "$( rigFile team-members-names )" "$( rigFile spawned-sessions )" "$( rigFile pending-replies )" | cksum )" "1 1 0 0 0 0 0 $rigSum"
rigBuild
rigAssert "control: with no argument the same stores are built" "$rigRc $( rigHolds six )" "0 1 1 1 1 1"

echo "-- 7. the help entry names the four --"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigEntry="$( LC_ALL=C awk -v head="$( printf '\t\t%s' "$rigOpName" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd" )"
rigAssert "control: the entry was cut out of the help.md, up to the next operation's heading" "$( printf '%s\n' "$rigEntry" | LC_ALL=C grep -c -F -- 'grants.index' || : ) $( printf '%s\n' "$rigEntry" | LC_ALL=C grep -c -F -- 'DistroAgentsConsole.sh' || : )" "1 0"
rigAssert "it names each of the four registry files" "$( for rigName in $rigAll ; do printf '%s\n' "$rigEntry" | LC_ALL=C grep -c -F -- "\`$rigName.registry\`" || : ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 1 "
rigAssert "the syntax line is as it was: the operation alone, once in the help.md and once in the help include" "$( LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigOpName" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOpName\" >&2" "$rigHere/help/Help.DistroAgentsTools.include" || : )" "1 1"

echo "-- 8. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MAKE INDICES REGISTRIES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MAKE_INDICES_REGISTRIES: OK (%d assertions, offline)\n' "$rigPasses"
