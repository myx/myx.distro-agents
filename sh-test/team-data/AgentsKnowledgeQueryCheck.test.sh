#!/usr/bin/env bash
## Behavioural check on TeamKnowledge, `DistroAgentsKnowledge.fn.sh` (F7.3 of the refactorings epic, open-names 43): a
## query starts with AND (`--query-keyword <x>`, one or many, `--query-pattern`, `--query-glob`, and groups `--query-open-and`
## / `--query-open-or` ... `--query-close`), over the sources added (`--add-board-items`, `--add-inbox-items`,
## `--add-vault-items`, `--add-source-docs`); its result is text snippets with references to their source, in markdown by
## default (merged by the nesting engine of F2.1), and as JSON under F7.8's `--mdat-output-format json` (one mechanism, no
## `--output` of its own). The vault is kept (settled 2026-10-19): the source is accepted and reads what stands under
## `vault/`, which nothing can write yet. The unit a query is answered by is the section.
## Held, over a rig team data store, and a rig distro workspace for the docs:
##   1. --add-board-items --query-keyword: the snippet of the item that holds the word, with the item named, and not the
##      one that holds it not
##   2. two keywords are ANDed: only the item holding both is shown
##   3. --add-inbox-items reads the inbox the same way
##   4. --mdat-output-format json gives JSON entries, each with its source
##   5. --add-vault-items is taken: with no vault/ nothing is shown and rc 0; a text file under vault/ is read
##   6. --query-open-or, --query-open-and, --query-pattern, --query-glob, and a keyword in any case
##   7. the inbox is the acting member's own, incoming/ and processed/; the console reads every member's
##   8. the markdown is the engine's nesting: the source is a section, the section that answers is under it
##   9. --add-source-docs reads MAGIC.md, README.md and docs/**.md of the projects selected (the selector of ListDistroProjects, none:
##      every project) and the workspace's util.workspace-* always
##  10. refused, rc 1, nothing printed: no source, no term, a group not closed, a close that closes none, an unknown option
##  11. the index: a fused query answers a section whose words the query does not share and one an exact term finds, each
##      named by its heading path; with the store off or the index not standing the answer is today's text search, byte
##      for byte; a hit of a file the member may not read is dropped and counted; and one resolver answers the path the
##      index is built at
## Red before F7.3: there is no DistroAgentsKnowledge.fn.sh (every case fails).
## Offline: the rig's own team data store and workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigKnowledge="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsKnowledge.fn.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsKnowledgeQueryCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills" "$rigData/board/backlog" "$rigData/inboxes/keeper-rig/incoming"
printf -- '---\ntype: task\nowner: keeper-rig\n---\n\n# Rig task alpha\n\nThe RIGWORDONE and the RIGWORDTWO stand here together.\n' > "$rigData/board/backlog/task-20261019T0100Z-rig-alpha.md"
printf -- '---\ntype: task\nowner: keeper-rig\n---\n\n# Rig task beta\n\nOnly the RIGWORDONE stands here.\n' > "$rigData/board/backlog/task-20261019T0101Z-rig-beta.md"
printf -- '---\ntype: task\nowner: keeper-rig\n---\n\n# Rig task gamma\n\nNothing of the words here.\n' > "$rigData/board/backlog/task-20261019T0102Z-rig-gamma.md"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nThe RIGINBOXWORD of a note.\n' > "$rigData/inboxes/keeper-rig/incoming/note-20261019T0103Z-rig-note.md"
mkdir -p "$rigData/inboxes/keeper-rig/processed" "$rigData/inboxes/keeper-other/incoming"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nThe RIGPROCWORD of a note done.\n' > "$rigData/inboxes/keeper-rig/processed/note-20261019T0104Z-rig-done.md"
printf -- '---\ntype: note\nfrom: magic-coordinator\n---\n\nThe RIGOTHERWORD of another member.\n' > "$rigData/inboxes/keeper-other/incoming/note-20261019T0105Z-rig-other.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigQuery(){ ## result name, words... -- one query as keeper-rig's run; rc in <name>.rc
	local queryName="$1" queryRc=0
	shift
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-knowledge-run \
		bash "$rigKnowledge" "$@" ) > "$rigTmp/$queryName.out" 2> "$rigTmp/$queryName.err" < /dev/null || queryRc=$?
	printf '%s' "$queryRc" > "$rigTmp/$queryName.rc"
}
rigConsole(){ ## result name, words... -- one query as the console: no acting member; rc in <name>.rc
	local consoleName="$1" consoleRc=0
	shift
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigKnowledge" "$@" ) > "$rigTmp/$consoleName.out" 2> "$rigTmp/$consoleName.err" < /dev/null || consoleRc=$?
	printf '%s' "$consoleRc" > "$rigTmp/$consoleName.rc"
}
rigHolds(){ ## result name, text -- yes or no
	if LC_ALL=C grep -q -F -- "$2" "$rigTmp/$1.out" 2> /dev/null ; then printf yes ; else printf no ; fi
}

echo "-- 1. board items: the snippet holding the word, with its item named --"
rigQuery one --add-board-items --query-keyword RIGWORDONE
rigAssert "exit 0; alpha and beta shown, each named, gamma not" "$( cat "$rigTmp/one.rc" ):$( rigHolds one task-20261019T0100Z-rig-alpha ):$( rigHolds one task-20261019T0101Z-rig-beta ):$( rigHolds one task-20261019T0102Z-rig-gamma )" "0:yes:yes:no"
rigAssert "the snippet is the text that holds the word"         "$( rigHolds one 'Only the RIGWORDONE stands here.' )" "yes"
echo "-- 2. two keywords: AND --"
rigQuery two --add-board-items --query-keyword RIGWORDONE --query-keyword RIGWORDTWO
rigAssert "only alpha, which holds both"                        "$( cat "$rigTmp/two.rc" ):$( rigHolds two task-20261019T0100Z-rig-alpha ):$( rigHolds two task-20261019T0101Z-rig-beta )" "0:yes:no"
echo "-- 3. inbox items --"
rigQuery inbox --add-inbox-items --query-keyword RIGINBOXWORD
rigAssert "the note shown, named"                               "$( cat "$rigTmp/inbox.rc" ):$( rigHolds inbox note-20261019T0103Z-rig-note )" "0:yes"
echo "-- 4. JSON under --mdat-output-format json --"
rigQuery json --mdat-output-format json --add-board-items --query-keyword RIGWORDTWO
rigAssert "JSON, each entry with its source"                    "$( cat "$rigTmp/json.rc" ):$( python3 -I -c 'import json, sys
try:
	data = json.load( open( sys.argv[1] ) )
except Exception:
	print( "no-json" ) ; sys.exit( 0 )
text = json.dumps( data )
print( "json" if "task-20261019T0100Z-rig-alpha" in text else "json-without-source" )' "$rigTmp/json.out" 2> /dev/null )" "0:json"
echo "-- 5. the vault is kept: taken as a source, and read once it has content --"
rigQuery vault --add-vault-items --query-keyword RIGWORDONE
rigAssert "no vault/ yet: accepted, rc 0, nothing shown"                 "$( cat "$rigTmp/vault.rc" ):$( rigHolds vault RIGWORDONE ):$( LC_ALL=C grep -c . "$rigTmp/vault.out" || : )" "0:no:0"
mkdir -p "$rigData/vault"
printf -- '---\ntype: verbatim-note\n---\n\n# Rig vault item\n\nThe RIGVAULTWORD of a document.\n' > "$rigData/vault/verbatim-20261019T0200Z-rig-vault.md"
rigQuery vault2 --add-vault-items --query-keyword RIGVAULTWORD
rigAssert "a text file under vault/: shown, named"                       "$( cat "$rigTmp/vault2.rc" ):$( rigHolds vault2 verbatim-20261019T0200Z-rig-vault ):$( rigHolds vault2 'The RIGVAULTWORD of a document.' )" "0:yes:yes"

echo "-- 6. the grammar: groups, pattern, glob, any case --"
rigQuery or --add-board-items --add-inbox-items --query-open-or --query-keyword RIGWORDTWO --query-keyword RIGINBOXWORD --query-close
rigAssert "open-or: the item with the one word and the note with the other, not the item with neither" "$( rigHolds or task-20261019T0100Z-rig-alpha ):$( rigHolds or note-20261019T0103Z-rig-note ):$( rigHolds or task-20261019T0101Z-rig-beta ):$( rigHolds or task-20261019T0102Z-rig-gamma )" "yes:yes:no:no"
rigQuery and --add-board-items --query-open-and --query-keyword RIGWORDONE --query-keyword RIGWORDTWO --query-close
rigAssert "open-and: both words, as two keywords at the top"             "$( rigHolds and task-20261019T0100Z-rig-alpha ):$( rigHolds and task-20261019T0101Z-rig-beta )" "yes:no"
rigQuery nested --add-board-items --query-keyword RIGWORDONE --query-open-or --query-keyword RIGWORDTWO --query-keyword gamma --query-close
rigAssert "a group inside the top AND: RIGWORDONE and (RIGWORDTWO or gamma)" "$( rigHolds nested task-20261019T0100Z-rig-alpha ):$( rigHolds nested task-20261019T0101Z-rig-beta ):$( rigHolds nested task-20261019T0102Z-rig-gamma )" "yes:no:no"
rigQuery case --add-board-items --query-keyword rigwordtwo
rigAssert "a keyword in any case"                                        "$( rigHolds case task-20261019T0100Z-rig-alpha )" "yes"
rigQuery pattern --add-board-items --query-pattern '^Only the RIG[A-Z]+ stands'
rigAssert "a pattern is an extended regular expression on a line"        "$( rigHolds pattern task-20261019T0101Z-rig-beta ):$( rigHolds pattern task-20261019T0100Z-rig-alpha )" "yes:no"
rigQuery glob --add-board-items --query-glob '*stand here together*'
rigAssert "a glob is shell-style on a whole line"                        "$( rigHolds glob task-20261019T0100Z-rig-alpha ):$( rigHolds glob task-20261019T0101Z-rig-beta )" "yes:no"

echo "-- 7. the inbox is the acting member's own; the console reads every member's --"
rigQuery own --add-inbox-items --query-keyword RIGPROCWORD
rigQuery other --add-inbox-items --query-keyword RIGOTHERWORD
rigAssert "keeper-rig: its processed/ note shown, another member's note not" "$( rigHolds own note-20261019T0104Z-rig-done ):$( rigHolds other note-20261019T0105Z-rig-other )" "yes:no"
rigConsole console --add-inbox-items --query-keyword RIGOTHERWORD
rigAssert "the console: another member's note shown too"                 "$( cat "$rigTmp/console.rc" ):$( rigHolds console note-20261019T0105Z-rig-other )" "0:yes"

echo "-- 8. the markdown is the nesting engine's --"
rigQuery shape --add-board-items --query-keyword RIGWORDONE
rigAssert "the source is a section and the section that answers is under it" "$( LC_ALL=C grep -c -x -F '# board/backlog/task-20261019T0101Z-rig-beta.md' "$rigTmp/shape.out" || : ):$( LC_ALL=C grep -c -x -F '## Rig task beta' "$rigTmp/shape.out" || : )" "1:1"
rigAssert "the front matter is not carried, and a section that does not answer is not there" "$( rigHolds shape 'owner: keeper-rig' ):$( rigHolds shape 'Rig task gamma' )" "no:no"
rigQuery shapejson --mdat-output-format json --add-board-items --query-keyword RIGWORDONE
rigAssert "JSON: an entry for each section, with its store and section"  "$( python3 -I -c 'import json, sys
data = json.load( open( sys.argv[1] ) )
print( ",".join( sorted( e["source"].split("/")[-1] + ":" + e["store"] + ":" + e["section"] for e in data["entries"] ) ) )' "$rigTmp/shapejson.out" 2> /dev/null )" "task-20261019T0100Z-rig-alpha.md:board:Rig task alpha,task-20261019T0101Z-rig-beta.md:board:Rig task beta"

echo "-- 9. the project docs, over a rig distro workspace --"
rigDws="$rigTmp/dws"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-distro-workspace.include.sh" || { echo "⛔ ERROR: the distro workspace fixture is missing -- refusing to report a result" >&2 ; exit 1 ; }
if rigDistroPath > /dev/null && rigDistroWorkspace "$rigDws" rig && rigDistroProject "$rigDws" rig rig.alpha $'Requires: \\\n\trig/rig.beta \\\n\n' && rigDistroProject "$rigDws" rig rig.beta "" && rigDistroProject "$rigDws" rig util.workspace-rig "" && rigDistroProject "$rigDws" rig util.repository-rig "" ; then
	mkdir -p "$rigDws/source/rig/rig.alpha/docs/sub"
	printf '# Alpha\n\n## Alpha rules\n\nThe RIGDOCWORD in a rule.\n\n## Other\n\nNothing.\n' > "$rigDws/source/rig/rig.alpha/MAGIC.md"
	printf 'The RIGDOCWORD of a readme, ahead of its first heading.\n\n# Alpha readme\n\nMore.\n' > "$rigDws/source/rig/rig.alpha/README.md"
	printf '# Guide\n\nThe RIGDOCWORD in a guide.\n' > "$rigDws/source/rig/rig.alpha/docs/guide.md"
	printf '# Deep\n\nThe RIGDOCWORD deep down.\n' > "$rigDws/source/rig/rig.alpha/docs/sub/deep.md"
	printf '# Beta\n\nThe RIGDOCWORD of beta.\n' > "$rigDws/source/rig/rig.beta/README.md"
	printf '# Workspace\n\nThe RIGDOCWORD of the workspace.\n' > "$rigDws/source/rig/util.workspace-rig/README.md"
	printf '# Repository\n\nThe RIGDOCWORD of the repository.\n' > "$rigDws/source/rig/util.repository-rig/README.md"
	rigDocs(){ ## result name, words...
		local docsName="$1" docsRc=0
		shift
		( cd "$rigDws" && env -i HOME="$rigTmp/home" PATH="$( rigDistroPath )" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 300 -- bash "$rigKnowledge" "$@" ) > "$rigTmp/$docsName.out" 2> "$rigTmp/$docsName.err" < /dev/null || docsRc=$?
		printf '%s' "$docsRc" > "$rigTmp/$docsName.rc"
	}
	rigDocs docs --add-source-docs --query-keyword RIGDOCWORD
	rigAssert "no selector: every project's MAGIC.md, README.md and docs/**.md, the repository's and the workspace's" "$( cat "$rigTmp/docs.rc" ):$( for rigSrc in rig.alpha/MAGIC.md rig.alpha/README.md rig.alpha/docs/guide.md rig.alpha/docs/sub/deep.md rig.beta/README.md util.workspace-rig/README.md util.repository-rig/README.md ; do rigHolds docs "# source/rig/$rigSrc" ; done | LC_ALL=C tr '\n' ' ' )" "0:yesyesyesyesyesyesyes"
	rigAssert "the MAGIC.md section that answers is under its source; the one that does not is not there" "$( LC_ALL=C grep -c -x -F '### Alpha rules' "$rigTmp/docs.out" || : ):$( rigHolds docs 'Nothing.' )" "1:no"
	rigAssert "the lines ahead of a README's first heading answer too"      "$( rigHolds docs 'The RIGDOCWORD of a readme, ahead of its first heading.' ):$( rigHolds docs 'More.' )" "yes:no"
	rigDocs one --select-one-project rig/rig.alpha --add-source-docs --query-keyword RIGDOCWORD
	rigAssert "a selector: that project's docs, and the workspace's and its repository's still, not another project's" "$( cat "$rigTmp/one.rc" ):$( rigHolds one '# source/rig/rig.alpha/MAGIC.md' ):$( rigHolds one '# source/rig/rig.beta/README.md' ):$( rigHolds one '# source/rig/util.workspace-rig/README.md' ):$( rigHolds one '# source/rig/util.repository-rig/README.md' )" "0:yes:no:yes:yes"
	rigDocs req --select-one-project rig/rig.alpha --select-required --add-source-docs --query-keyword RIGDOCWORD
	rigAssert "--select-required, as ListDistroProjects reads it: the selected project's required project's docs are searched, only with it" "$( cat "$rigTmp/req.rc" ):$( rigHolds req '# source/rig/rig.beta/README.md' ):$( rigHolds req '# source/rig/rig.alpha/MAGIC.md' ):$( rigHolds one '# source/rig/rig.beta/README.md' )" "0:yes:yes:no"
else
	rigAssert "a rig distro workspace could be made (myx.common on PATH, the fixture)" "no" "yes"
fi

echo "-- 10. refused, rc 1, nothing on stdout --"
rigQuery r1 --query-keyword RIGWORDONE
rigQuery r2 --add-board-items
rigQuery r3 --add-board-items --query-open-or --query-keyword RIGWORDONE
rigQuery r4 --add-board-items --query-keyword RIGWORDONE --query-close
rigQuery r5 --add-board-items --query-keyword RIGWORDONE --bogus
rigAssert "no source, no term, a group not closed, a close that closes none, an unknown option" "$( for rigN in r1 r2 r3 r4 r5 ; do printf '%s:%s ' "$( cat "$rigTmp/$rigN.rc" )" "$( LC_ALL=C grep -c . "$rigTmp/$rigN.out" || : )" ; done )" "1:0 1:0 1:0 1:0 1:0 "
rigAssert "each says what is wrong"                                      "$( LC_ALL=C grep -c -F -e 'no source added' "$rigTmp/r1.err" ):$( LC_ALL=C grep -c -F -e 'no query term' "$rigTmp/r2.err" ):$( LC_ALL=C grep -c -F -e 'not closed' "$rigTmp/r3.err" ):$( LC_ALL=C grep -c -F -e 'closes no group' "$rigTmp/r4.err" ):$( LC_ALL=C grep -c -F -e 'invalid option: --bogus' "$rigTmp/r5.err" )" "1:1:1:1:1"

echo "-- 11. the index: fused, the fallback, the read set, and the one resolver --"
## A rig workspace of its own: the store's Python standing, an index built at the resolver's root, and a vault of two
## documents, one of which the acting member may not read. The model stand-in gives a paraphrase and the words it
## answers one axis of its vector, so the fused call answers a text that shares no word with the query.
rigIx="$rigTmp/ix" rigIxData="$rigTmp/ixdata"
rigPythonDir="$( dirname "$( command -v python3 )" )"
rigIxPackage="$rigOrigin/myx/myx.distro-agents"
rigIxLib="$rigTmp/ixlib"
mkdir -p "$rigIx/.local/lancedb/venv/bin" "$rigIx/.local/lancedb/model/potion-base-8M" "$rigIx/.local/agents" "$rigIxData/vault" "$rigIxLib"
cp "$rigIxPackage/sh-test/check-fixtures/knowledge-store.python.stub.sh" "$rigIx/.local/lancedb/venv/bin/python" || rigRefuse "the Python stand-in is missing"
chmod +x "$rigIx/.local/lancedb/venv/bin/python"
printf 'LANCEDB_MODEL_NAME=potion-base-8M\nLANCEDB_MODEL_REVISION=rig111\nLANCEDB_MODEL_DIM=2\n' > "$rigIx/.local/lancedb/lancedb.env"
cp -R "$rigIxPackage/sh-test/check-fixtures/knowledge-store-lancedb.stub/lancedb" "$rigIxLib/lancedb" || rigRefuse "cannot stage the lancedb stand-in"
cp -R "$rigIxPackage/sh-test/check-fixtures/knowledge-store-model2vec.stub/model2vec" "$rigIxLib/model2vec" || rigRefuse "cannot stage the model2vec stand-in"
printf -- '---\ntype: note\n---\n\n# A deployment\n\nA failed deployment goes back to the earlier build.\n' > "$rigIxData/vault/note-20260101T0000Z-deploy.md"
printf -- '---\ntype: note\n---\n\n# An exact term\n\nThe RIGIXEXACTWORD stands here.\n' > "$rigIxData/vault/note-20260101T0001Z-exact.md"
printf -- '---\ntype: note\n---\n\n# A secret\n\nA failed release returns to the previous build.\n' > "$rigIxData/vault/note-20260101T0002Z-secret.md"
printf 'keeper-rig:ix:workspace:Read(/%s/vault/note-20260101T0000Z-deploy.md)\nkeeper-rig:ix:workspace:Read(/%s/vault/note-20260101T0001Z-exact.md)\n' "$rigIxData" "$rigIxData" > "$rigIx/.local/agents/permissions.registry"
rigIxSections="$( printf '%s\n' "$rigIxData/vault/note-20260101T0000Z-deploy.md" "$rigIxData/vault/note-20260101T0001Z-exact.md" "$rigIxData/vault/note-20260101T0002Z-secret.md" | LC_ALL=C awk -v format=index -v dataRoot="${rigIxData%/}/" -f "$rigIxPackage/sh-lib/team-data/AgentsKnowledgeScan.awk" )"
if printf '%s' "$rigIxSections" | env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" RIG_LANCEDB_STUB="$rigIxLib" \
	"$rigIx/.local/lancedb/venv/bin/python" "$rigIxPackage/sh-lib/team-data/AgentsKnowledgeStore.py" build --index "$rigIx/.local/knowledge-index" \
	--model-dir "$rigIx/.local/lancedb/model/potion-base-8M" --model-stamp 'potion-base-8M@rig111@2' > "$rigTmp/ixbuild.out" 2> "$rigTmp/ixbuild.err" ; then
	rigIxQuery(){ ## result name, store setting, words... -- a query as keeper-rig's run, over the index rig
		local ixName="$1" ixSetting="$2" ixRc=0
		shift 2
		( cd "$rigIx" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" MMDAPP="$rigIx" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_DATA_ROOT="$rigIxData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-index-run \
			${ixSetting:+MDAT_KNOWLEDGE_STORE="$ixSetting"} RIG_LANCEDB_STUB="$rigIxLib" \
			bash "$rigKnowledge" "$@" ) > "$rigTmp/$ixName.out" 2> "$rigTmp/$ixName.err" < /dev/null || ixRc=$?
		printf '%s' "$ixRc" > "$rigTmp/$ixName.rc"
	}
	rigIxQuery fused on --add-vault-items --query-keyword 'undo the last release'
	rigAssert "a fused query answers a section whose words the query does not share, naming its file and heading path" "$( cat "$rigTmp/fused.rc" ):$( rigHolds fused 'A failed deployment goes back to the earlier build.' ):$( rigHolds fused 'undo' ):$( LC_ALL=C grep -c -x -F '# vault/note-20260101T0000Z-deploy.md' "$rigTmp/fused.out" || : ):$( LC_ALL=C grep -c -x -F '## A deployment' "$rigTmp/fused.out" || : )" "0:yes:no:1:1"
	rigIxQuery exact on --add-vault-items --query-keyword RIGIXEXACTWORD
	rigAssert "an exact term is answered by the section that holds it, named by its heading path" "$( cat "$rigTmp/exact.rc" ):$( rigHolds exact 'The RIGIXEXACTWORD stands here.' )" "0:yes"
	rigIxQuery keptoff off --add-vault-items --query-keyword RIGIXEXACTWORD
	mv "$rigIx/.local/knowledge-index" "$rigIx/.local/knowledge-index.aside"
	rigIxQuery keptgone on --add-vault-items --query-keyword RIGIXEXACTWORD
	mv "$rigIx/.local/knowledge-index.aside" "$rigIx/.local/knowledge-index"
	rigIxQuery plain off --add-vault-items --query-keyword RIGIXEXACTWORD
	rigAssert "with the store off, or the index not standing, the answer is today's text search" "$( cat "$rigTmp/keptoff.rc" ):$( cat "$rigTmp/keptgone.rc" ):$( cmp -s "$rigTmp/keptoff.out" "$rigTmp/keptgone.out" && printf same || printf differs ):$( cmp -s "$rigTmp/keptoff.out" "$rigTmp/plain.out" && printf same || printf differs ):$( rigHolds keptgone RIGIXEXACTWORD )" "0:0:same:same:yes"
	rigIxQuery dropped on --add-vault-items --query-keyword 'undo the last release'
	rigAssert "a hit of a file the member may not read is dropped, and the drop is counted" "$( cat "$rigTmp/dropped.rc" ):$( rigHolds dropped 'A failed release returns to the previous build.' ):$( LC_ALL=C grep -c -F -e 'section(s) of the index were left out' "$rigTmp/dropped.err" || : )" "0:no:1"
	rigIxQuery fusedjson on --mdat-output-format json --add-vault-items --query-keyword 'undo the last release'
	rigAssert "the JSON shape is unchanged on the fused path: its source, its store and its heading path" "$( python3 -I -c 'import json, sys
data = json.load( open( sys.argv[1] ) )
print( ",".join( sorted( e["source"] + ":" + e["store"] + ":" + e["section"] for e in data["entries"] ) ) )' "$rigTmp/fusedjson.out" 2> /dev/null )" "vault/note-20260101T0000Z-deploy.md:vault:A deployment,vault/note-20260101T0001Z-exact.md:vault:An exact term"
	rigAssert "the one resolver answers the path the index was built at, and nothing else names it" "$( env -i MMDAPP="$rigIx" MDLT_ORIGIN="$rigOrigin" bash -c '. "'"$rigOrigin"'/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.KnowledgeStore.include" ; AgentsToolsKnowledgeIndexRoot' ):$( [ -f "$rigIx/.local/knowledge-index/sections.json" ] && printf built || printf absent ):$( LC_ALL=C grep -c -F -e '.local/knowledge-index' "$rigIxPackage/sh-lib/team-data/AgentsTools.KnowledgeStore.include" || : )" "$rigIx/.local/knowledge-index:built:1"
else
	rigAssert "the rig index could be built (the store's Python and the two stand-ins)" "$( LC_ALL=C head -2 "$rigTmp/ixbuild.err" | LC_ALL=C tr '\n' ' ' )" "built"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE QUERY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWLEDGE_QUERY: OK (%d assertions, offline)\n' "$rigPassCount"
