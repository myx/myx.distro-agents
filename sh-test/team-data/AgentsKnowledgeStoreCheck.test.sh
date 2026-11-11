#!/usr/bin/env bash
## Behavioural check on the knowledge store (F8.2/F8.3): the query reads the `MAGIC.LanceDB` beside each MAGIC.md with
## the text, falling back to the text alone when the store is off, uninstalled or absent; the librarian's spread moves
## the sections that are not kept to the store and retires records from it. Held over a rig distro workspace (for the
## --add-source-docs source scan) and a rig store: the store's own Python is a stand-in that runs the real python3 with
## the lancedb stand-in module (sh-test/check-fixtures/knowledge-store-lancedb.stub), so nothing live is fetched and no
## LanceDB is installed. Held:
##   1. the store off (the default): a MAGIC.LanceDB that stands is not searched, the text alone answers
##   2. the store on and its Python standing: the record of the store answers with the MAGIC.md text, named by the
##      MAGIC.md reference
##   3. JSON: the store's entry has the MAGIC.md reference as its source, its caption as its section
##   4. spread: the sections not named by --keep move to the store, the MAGIC.md keeps the rest, and the query finds
##      the moved section through the store
##   5. retire: the records a --section names are deleted, and the query no longer finds them
##   6. refused, rc 1, nothing written: spread with no --keep, a keep that would remove every section, and either
##      operation with the store off; the index build with the store off (under its own label), with an argument,
##      and with no model in the store's environment
##   7. the engine: one row a section, keyed by the source and the heading path, with the eleven columns, and the
##      full-text index the fusion needs
##   8. a repeat of one heading path inside a file takes ~2 and ~3
##   9. an incremental pass re-embeds only the row whose hash changed
##  10. a section the walk no longer produces is deleted, and a pass that changes one section and loses another
##      reports one deletion
##  11. a model stamp mismatch rebuilds every row, and a fusion over a table with no full-text index answers 3
##  12. a build holds the index lock, and a read never creates the table
## Red before F8.2/F8.3: the store is not read, and the operations do not exist.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigKnowledge="$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixDir="$rigPackage/sh-test/check-fixtures"
rigLancedbStub="$rigFixDir/knowledge-store-lancedb.stub"
rigModelStub="$rigFixDir/knowledge-store-model2vec.stub"
rigPythonStub="$rigFixDir/knowledge-store.python.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigKnowledge" ] || rigRefuse "the knowledge tool is not at the origin: $rigKnowledge"
[ -f "$rigTool" ] || rigRefuse "the tools tool is not at the origin: $rigTool"
[ -f "$rigPythonStub" ] || rigRefuse "the Python stand-in is missing: $rigPythonStub"
[ -f "$rigLancedbStub/lancedb/__init__.py" ] || rigRefuse "the lancedb stand-in is missing: $rigLancedbStub/lancedb/__init__.py"
[ -f "$rigModelStub/model2vec/__init__.py" ] || rigRefuse "the model2vec stand-in is missing: $rigModelStub/model2vec/__init__.py"
command -v python3 > /dev/null 2>&1 || rigRefuse "no python3 on this machine, which the Python stand-in runs"
rigPythonDir="$( dirname "$( command -v python3 )" )"
. "$rigFixDir/rig-distro-workspace.include.sh" || exit 1
rigTmp="$( rigDistroTmp AgentsKnowledgeStoreCheck )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigDws="$rigTmp/dws" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigData" "$rigHome" "$rigTmp/skills"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigHolds(){ ## result name, text -- yes or no
	if LC_ALL=C grep -q -F -- "$2" "$rigTmp/$1.out" 2> /dev/null ; then printf yes ; else printf no ; fi
}

echo "-- the rig: a distro workspace, its MAGIC.md, and the store beside it --"
rigDistroPath > /dev/null 2>&1 || rigRefuse "no myx.common on PATH, which the source scan needs"
rigDistroWorkspace "$rigDws" rig || rigRefuse "cannot make the rig workspace"
rigDistroProject "$rigDws" rig rig.alpha "" || rigRefuse "cannot make the rig project"
rigDistroProject "$rigDws" rig util.workspace-rig "" || rigRefuse "cannot make the rig workspace project"
rigDistroProject "$rigDws" rig util.repository-rig "" || rigRefuse "cannot make the rig repository project"
mkdir -p "$rigDws/source/rig/rig.alpha/docs"
printf '# Alpha\n\n## Alpha rules\n\nThe RIGDOCWORD in a rule.\n\n## Alpha spread me\n\nThe RIGSPREADWORD stands in the file.\n\n## Alpha other\n\nNothing.\n' > "$rigDws/source/rig/rig.alpha/MAGIC.md"
printf 'The RIGDOCWORD of a readme.\n' > "$rigDws/source/rig/rig.alpha/README.md"
printf '# Workspace\n\nThe RIGDOCWORD of the workspace.\n' > "$rigDws/source/rig/util.workspace-rig/README.md"
printf '# Repository\n\nThe RIGDOCWORD of the repository.\n' > "$rigDws/source/rig/util.repository-rig/README.md"
mkdir -p "$rigDws/.local/lancedb/venv/bin"
cp "$rigPythonStub" "$rigDws/.local/lancedb/venv/bin/python" && chmod +x "$rigDws/.local/lancedb/venv/bin/python"
: > "$rigDws/.local/lancedb/lancedb.env"

rigQuery(){ ## result name, store setting (on|off), words...
	local queryName="$1" querySetting="$2" queryRc=0
	shift 2
	( cd "$rigDws" && env -i HOME="$rigHome" PATH="$( rigDistroPath ):$rigPythonDir" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-store-run \
		${querySetting:+MDAT_KNOWLEDGE_STORE="$querySetting"} RIG_LANCEDB_STUB="$rigLancedbStub" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 300 -- bash "$rigKnowledge" "$@" ) > "$rigTmp/$queryName.out" 2> "$rigTmp/$queryName.err" < /dev/null || queryRc=$?
	printf '%s' "$queryRc" > "$rigTmp/$queryName.rc"
}
rigStoreRun(){ ## result name, words... -- one store operation, the store on
	local runName="$1" runRc=0
	shift
	( cd "$rigDws" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_KNOWLEDGE_STORE=on RIG_LANCEDB_STUB="$rigLancedbStub" \
		bash "$rigTool" "$@" ) > "$rigTmp/$runName.out" 2> "$rigTmp/$runName.err" < /dev/null || runRc=$?
	printf '%s' "$runRc" > "$rigTmp/$runName.rc"
}

echo "-- 1. the store off: a store that stands is not searched, the text alone answers --"
mkdir -p "$rigDws/source/rig/rig.alpha/MAGIC.LanceDB"
printf '[{"section":"Stored note","text":"The RIGSTOREWORD lives in the store."}]' > "$rigDws/source/rig/rig.alpha/MAGIC.LanceDB/sections.json"
rigQuery off off --add-source-docs --query-keyword RIGSTOREWORD
rigAssert "the store record does not answer while the store is off" "$( cat "$rigTmp/off.rc" ):$( rigHolds off RIGSTOREWORD )" "0:no"
rigQuery offdoc off --add-source-docs --query-keyword RIGDOCWORD
rigAssert "the MAGIC.md text still answers" "$( cat "$rigTmp/offdoc.rc" ):$( rigHolds offdoc RIGDOCWORD )" "0:yes"

echo "-- 2. the store on: its record answers with the text, named by the MAGIC.md reference --"
rigQuery on on --add-source-docs --query-keyword RIGSTOREWORD
rigAssert "the store record answers, and its section is under the MAGIC.md reference" "$( cat "$rigTmp/on.rc" ):$( rigHolds on RIGSTOREWORD ):$( LC_ALL=C grep -c -x -F '# source/rig/rig.alpha/MAGIC.md' "$rigTmp/on.out" || : ):$( LC_ALL=C grep -c -x -F '## Stored note' "$rigTmp/on.out" || : )" "0:yes:1:1"
rigQuery onboth on --add-source-docs --query-keyword RIGDOCWORD
rigAssert "the text and the store answer the same query" "$( rigHolds onboth RIGDOCWORD ):$( rigHolds onboth 'Alpha rules' )" "yes:yes"

echo "-- 3. JSON: the store entry has the MAGIC.md reference and its caption --"
rigQuery onjson on --mdat-output-format json --add-source-docs --query-keyword RIGSTOREWORD
rigAssert "the JSON entry carries the reference, store docs, the caption and the snippet" "$( python3 -I -c 'import json, sys
data = json.load( open( sys.argv[1] ) )
entry = next( ( e for e in data["entries"] if "RIGSTOREWORD" in e.get("snippet","") ), None )
print( entry["source"] + ":" + entry["store"] + ":" + entry["section"] if entry else "none" )' "$rigTmp/onjson.out" 2> /dev/null )" "source/rig/rig.alpha/MAGIC.md:docs:Stored note"

echo "-- 4. spread: the sections not kept move to the store, the MAGIC.md keeps the rest --"
rigStoreRun spread --knowledge-store-spread source/rig/rig.alpha/MAGIC.md --keep 'Alpha rules' --keep 'Alpha other'
rigAssert "spread succeeds and prints the reference" "$( cat "$rigTmp/spread.rc" ):$( LC_ALL=C cat "$rigTmp/spread.out" | LC_ALL=C tr -d '\n' )" "0:source/rig/rig.alpha/MAGIC.md"
rigAssert "the moved section is out of the MAGIC.md, the kept ones stay" "$( rigHolds spread 'RIGSPREADWORD' ):$( LC_ALL=C grep -c -F 'Alpha spread me' "$rigDws/source/rig/rig.alpha/MAGIC.md" || : ):$( LC_ALL=C grep -c -F 'Alpha rules' "$rigDws/source/rig/rig.alpha/MAGIC.md" || : )" "no:0:1"
rigQuery spreadq on --add-source-docs --query-keyword RIGSPREADWORD
rigAssert "the moved section is found through the store, not the text" "$( cat "$rigTmp/spreadq.rc" ):$( rigHolds spreadq RIGSPREADWORD ):$( rigHolds spreadq 'Alpha spread me' )" "0:yes:yes"

echo "-- 5. retire: the records a --section names are deleted, and the query no longer finds them --"
rigStoreRun retire --knowledge-store-retire source/rig/rig.alpha/MAGIC.md --section 'Alpha spread me' --section 'Stored note'
rigAssert "retire succeeds and reports two removed" "$( cat "$rigTmp/retire.rc" ):$( LC_ALL=C cat "$rigTmp/retire.out" | LC_ALL=C tr -d '\n' )" "0:2"
rigQuery retireq on --add-source-docs --query-keyword RIGSPREADWORD
rigQuery retireq2 on --add-source-docs --query-keyword RIGSTOREWORD
rigAssert "neither retired record answers any more" "$( cat "$rigTmp/retireq.rc" ):$( rigHolds retireq RIGSPREADWORD ):$( cat "$rigTmp/retireq2.rc" ):$( rigHolds retireq2 RIGSTOREWORD )" "0:no:0:no"

echo "-- 6. refused, rc 1, nothing written --"
rigStoreRun nokeep --knowledge-store-spread source/rig/rig.alpha/MAGIC.md
rigAssert "spread with no --keep refuses" "$( cat "$rigTmp/nokeep.rc" ):$( LC_ALL=C grep -c -F -e 'at least one --keep' "$rigTmp/nokeep.err" || : )" "1:1"
rigStoreRun emptykeep --knowledge-store-spread source/rig/rig.alpha/MAGIC.md --keep 'No such section'
rigAssert "a keep that would remove every section refuses, and the MAGIC.md is left whole" "$( cat "$rigTmp/emptykeep.rc" ):$( LC_ALL=C grep -c -F -e 'remove every section' "$rigTmp/emptykeep.err" || : ):$( LC_ALL=C grep -c -F 'Alpha rules' "$rigDws/source/rig/rig.alpha/MAGIC.md" || : )" "1:1:1"
rigStoreOffRun(){ ## result name, words... -- a store operation, the store off
	local offName="$1" offRc=0
	shift
	( cd "$rigDws" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_LANCEDB_STUB="$rigLancedbStub" \
		bash "$rigTool" "$@" ) > "$rigTmp/$offName.out" 2> "$rigTmp/$offName.err" < /dev/null || offRc=$?
	printf '%s' "$offRc" > "$rigTmp/$offName.rc"
}
rigStoreOffRun offspread --knowledge-store-spread source/rig/rig.alpha/MAGIC.md --keep 'Alpha rules'
rigStoreOffRun offretire --knowledge-store-retire source/rig/rig.alpha/MAGIC.md --section 'Stored note'
rigAssert "with the store off both refuse, naming --install-knowledge-store" "$( cat "$rigTmp/offspread.rc" ):$( LC_ALL=C grep -c -F -e 'is off' "$rigTmp/offspread.err" || : ):$( cat "$rigTmp/offretire.rc" ):$( LC_ALL=C grep -c -F -e 'is off' "$rigTmp/offretire.err" || : )" "1:1:1:1"
rigStoreOffRun offbuild --knowledge-index-build
rigAssert "the index build refuses with the store off, under its own label, and builds nothing" "$( cat "$rigTmp/offbuild.rc" ):$( LC_ALL=C grep -c -F -e 'is off' "$rigTmp/offbuild.err" || : ):$( LC_ALL=C grep -c -F -e '--install-knowledge-store:' "$rigTmp/offbuild.err" || : ):$( [ -e "$rigDws/.local/knowledge-index" ] && printf built || printf none )" "1:1:0:none"
rigStoreRun argbuild --knowledge-index-build stray
rigAssert "the index build refuses an argument" "$( cat "$rigTmp/argbuild.rc" ):$( LC_ALL=C grep -c -F -e 'takes no arguments' "$rigTmp/argbuild.err" || : )" "1:1"
rigStoreRun nomodelbuild --knowledge-index-build
rigAssert "the index build refuses while the store names no model, and builds nothing" "$( cat "$rigTmp/nomodelbuild.rc" ):$( LC_ALL=C grep -c -F -e 'embedding model' "$rigTmp/nomodelbuild.err" || : ):$( [ -e "$rigDws/.local/knowledge-index" ] && printf built || printf none )" "1:1:none"
rigNoDataRc=0
( cd "$rigDws" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
	MDAT_DATA_ROOT="$rigTmp/no-data-root" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_KNOWLEDGE_STORE=on RIG_LANCEDB_STUB="$rigLancedbStub" \
	bash "$rigTool" --knowledge-index-build ) > "$rigTmp/nodatabuild.out" 2> "$rigTmp/nodatabuild.err" < /dev/null || rigNoDataRc=$?
rigAssert "the index build refuses with no team data root, and builds nothing" "$rigNoDataRc:$( LC_ALL=C grep -c -F -e 'no team data root' "$rigTmp/nodatabuild.err" || : ):$( [ -e "$rigDws/.local/knowledge-index" ] && printf built || printf none )" "1:1:none"

echo "-- 7 to 15. the index engine: one row a section, keyed by source and heading path --"
## The engine's own Python is the store's stand-in, so its `lancedb` and `model2vec` are staged side by side and imported
## through PYTHONPATH: the LanceDB stand-in as shipped, and the shared model stand-in, whose encode logs every text it
## was given.
mkdir -p "$rigTmp/pylib" "$rigTmp/model"
cp -R "$rigLancedbStub/lancedb" "$rigTmp/pylib/lancedb" || rigRefuse "cannot stage the lancedb stand-in"
cp -R "$rigModelStub/model2vec" "$rigTmp/pylib/model2vec" || rigRefuse "cannot stage the model2vec stand-in"
rigRunner(){ ## -- the engine's own Python, over the store's environment
	env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin:$rigPythonDir" RIG_LANCEDB_STUB="$rigTmp/pylib" RIG_MODEL_LOG="$rigTmp/model.log" \
		"$rigDws/.local/lancedb/venv/bin/python" "$rigPackage/sh-lib/team-data/AgentsKnowledgeStore.py" "$@"
}
rigBuild(){ ## stamp, files... -- one index build over those files; its rc in build.rc
	local buildStamp="$1" buildSections buildRc=0
	shift
	buildSections="$( printf '%s\n' "$@" | LC_ALL=C awk -v format=index -v wsRoot="${rigDws%/}/" -f "$rigPackage/sh-lib/team-data/AgentsKnowledgeScan.awk" )" || { printf '1' > "$rigTmp/build.rc" ; return 0 ; }
	printf '%s' "$buildSections" | rigRunner build --index "$rigTmp/index" --model-dir "$rigTmp/model" --model-stamp "$buildStamp" > "$rigTmp/build.out" 2> "$rigTmp/build.err" || buildRc=$?
	printf '%s' "$buildRc" > "$rigTmp/build.rc"
	return 0
}
rigIndexField(){ ## field -- that field of every stored row, one a line
	python3 -I -c 'import json, os, sys
path = sys.argv[1]
rows = json.load( open( path ) ) if os.path.exists( path ) else []
print( "".join( str( row.get( sys.argv[2], "" ) ) + "\n" for row in rows ), end = "" )' "$rigTmp/index/sections.json" "$1"
}
rigIndexShape(){ ## -- each row's column count, whether it holds exactly the eleven columns, and its vector length
	python3 -I -c 'import json, sys
want = ["section-id", "source", "heading-path", "heading", "text", "hash", "vector", "group", "project-id", "members", "file-date"]
rows = json.load( open( sys.argv[1] ) )
print( "".join( "%d:%s:%d\n" % ( len( row ), sorted( row ) == sorted( want ), len( row.get( "vector", [] ) ) ) for row in rows ), end = "" )' "$rigTmp/index/sections.json" | LC_ALL=C sort -u
}
rigEmbeds(){ ## -- how many texts the model was given, and how many were the changed one
	LC_ALL=C awk '/^TEXT/ { count++ ; } /^TEXT.*ONESHARED/ { changed++ ; } END { printf "%d:%d", count + 0, changed + 0 ; }' "$rigTmp/model.log" 2> /dev/null || printf '0:0'
}
rigIndexPairs(){ ## -- section id and hash of every row, sorted
	python3 -I -c 'import json, sys
rows = json.load( open( sys.argv[1] ) )
print( "".join( row[ "section-id" ] + "\t" + row[ "hash" ] + "\n" for row in rows ), end = "" )' "$rigTmp/index/sections.json" | LC_ALL=C sort
}
rigStamp(){ ## -- the model stamp the index carries
	python3 -I -c 'import json, sys
print( json.load( open( sys.argv[1] ) )[0]["model-stamp"] )' "$rigTmp/index/meta.json" 2> /dev/null || :
}

rigDocs="$rigDws/source/rig/rig.alpha/docs"
mkdir -p "$rigDocs"
printf '# One\n\n## Shared\n\nThe ONESHAREDWORD stands in one file.\n\n## Twice\n\nThe first TWICEWORD.\n\n## Twice\n\nThe second TWICEWORD.\n' > "$rigDocs/one.md"
printf '# Two\n\n## Shared\n\nThe TWOSHAREDWORD stands in the other file.\n' > "$rigDocs/two.md"
: > "$rigTmp/model.log"
rigBuild 'potion-base-8M@aaa111@2' "$rigDocs/one.md" "$rigDocs/two.md"
rigAssert "1. the first build succeeds" "$( cat "$rigTmp/build.rc" )" "0"
rigAssert "2. one row a section, each keyed by its source and its heading path" "$( rigIndexField section-id | LC_ALL=C tr '\n' '|' )" "source/rig/rig.alpha/docs/one.md#One|source/rig/rig.alpha/docs/one.md#One>Shared|source/rig/rig.alpha/docs/one.md#One>Twice|source/rig/rig.alpha/docs/one.md#One>Twice~2|source/rig/rig.alpha/docs/two.md#Two|source/rig/rig.alpha/docs/two.md#Two>Shared|"
rigAssert "3. every row holds the eleven columns and an embedded vector" "$( rigIndexShape | LC_ALL=C tr '\n' '|' )" "11:True:2|"
rigAssert "4. the build makes the full-text index the fusion needs" "$( [ -f "$rigTmp/index/sections.fts" ] && LC_ALL=C cat "$rigTmp/index/sections.fts" || printf 'none' )" "text"
rigAssert "5. a repeat of one heading path inside a file takes ~2" "$( rigIndexField section-id | LC_ALL=C grep -c -e '#One>Twice$' || : ):$( rigIndexField section-id | LC_ALL=C grep -c -e '#One>Twice~2$' || : )" "1:1"
rigIndexPairs > "$rigTmp/pairs.before" || rigRefuse "cannot read the index the first build wrote"
: > "$rigTmp/model.log"
printf '# One\n\n## Shared\n\nThe ONESHAREDWORD is now changed.\n\n## Twice\n\nThe first TWICEWORD.\n\n## Twice\n\nThe second TWICEWORD.\n' > "$rigDocs/one.md"
rigBuild 'potion-base-8M@aaa111@2' "$rigDocs/one.md" "$rigDocs/two.md"
rigAssert "6. an incremental pass succeeds" "$( cat "$rigTmp/build.rc" )" "0"
rigAssert "7. it embeds one text, and that text is the changed section" "$( rigEmbeds )" "1:1"
rigIndexPairs > "$rigTmp/pairs.after" || rigRefuse "cannot read the index the second build wrote"
rigAssert "8. only the changed row's hash differs, and no other row moved" "$( LC_ALL=C comm -3 "$rigTmp/pairs.before" "$rigTmp/pairs.after" | LC_ALL=C grep -c -e 'one.md#One>Shared' || : ):$( LC_ALL=C comm -3 "$rigTmp/pairs.before" "$rigTmp/pairs.after" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "2:2"
: > "$rigTmp/model.log"
rigBuild 'potion-base-8M@aaa111@2' "$rigDocs/two.md"
rigAssert "9. the vanished file's rows are deleted, the rest stand, and nothing is embedded" "$( cat "$rigTmp/build.rc" ):$( rigIndexField section-id | LC_ALL=C tr '\n' '|' ):$( rigEmbeds )" "0:source/rig/rig.alpha/docs/two.md#Two|source/rig/rig.alpha/docs/two.md#Two>Shared|:0:0"
## A pass that changes one section and loses another counts one deletion, not both: a changed row is re-embedded.
printf '# Three\n\nThe KEEPMEWORD stands here.\n' > "$rigDocs/three.md"
printf '# Four\n\nThe VANISHWORD stands here.\n' > "$rigDocs/four.md"
rigBuild 'potion-base-8M@aaa111@2' "$rigDocs/two.md" "$rigDocs/three.md" "$rigDocs/four.md"
printf '# Three\n\nThe KEEPMEWORD is now changed.\n' > "$rigDocs/three.md"
rigBuild 'potion-base-8M@aaa111@2' "$rigDocs/two.md" "$rigDocs/three.md"
rigAssert "10. a pass that changes one section and loses another reports one deletion" "$( cat "$rigTmp/build.rc" ):$( LC_ALL=C sed -n 's/.*, \([0-9]*\) deleted.*/\1/p' "$rigTmp/build.out" )" "0:1"
: > "$rigTmp/model.log"
rigBuild 'potion-base-8M@bbb222@2' "$rigDocs/two.md"
rigAssert "11. a model stamp mismatch rebuilds every row" "$( cat "$rigTmp/build.rc" ):$( rigEmbeds ):$( rigStamp )" "0:2:0:potion-base-8M@bbb222@2"
## The control for case 4: the same fusion, over a table with no full-text index, is refused rather than answered.
rigNoFtsRc=0
mv "$rigTmp/index/sections.fts" "$rigTmp/index/sections.fts.kept"
rigRunner query --index "$rigTmp/index" --model-dir "$rigTmp/model" --out-dir "$rigTmp" --text 'anything' > "$rigTmp/nofts.out" 2> "$rigTmp/nofts.err" || rigNoFtsRc=$?
mv "$rigTmp/index/sections.fts.kept" "$rigTmp/index/sections.fts"
rigAssert "12. a fusion over a table with no full-text index answers 3, so the text alone answers" "$rigNoFtsRc" "3"
sleep 60 &
rigHoldPid=$!
mkdir -p "$rigTmp/index.lock"
printf '%s\n' "$rigHoldPid" > "$rigTmp/index.lock/pid"
rigBuild 'potion-base-8M@bbb222@2' "$rigDocs/two.md"
rigAssert "13. a build refuses while another holds the index lock, and names it" "$( cat "$rigTmp/build.rc" ):$( LC_ALL=C grep -c -e 'holds the index lock' "$rigTmp/build.err" || : )" "1:1"
kill "$rigHoldPid" 2> /dev/null || :
{ wait "$rigHoldPid" ; } 2> /dev/null || :
rigDumpRc=0
rigRunner dump --store "$rigTmp/nostore" > "$rigTmp/dump.out" 2> "$rigTmp/dump.err" || rigDumpRc=$?
rigAssert "14. a read of an index with no table answers nothing and creates none" "$rigDumpRc:$( [ -e "$rigTmp/nostore/sections.json" ] && printf yes || printf no )" "0:no"
## The control that proves 14's instrument sees a creation at all: the same probe, over the store a build did create.
rigAssert "15. the same probe sees a table a build did create" "$( [ -e "$rigTmp/index/sections.json" ] && printf yes || printf no )" "yes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE STORE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWLEDGE_STORE: OK (%d assertions, offline, no LanceDB installed or fetched)\n' "$rigPasses"
