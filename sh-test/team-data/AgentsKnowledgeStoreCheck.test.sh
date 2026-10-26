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
##      operation with the store off
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
rigPythonStub="$rigFixDir/knowledge-store.python.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigKnowledge" ] || rigRefuse "the knowledge tool is not at the origin: $rigKnowledge"
[ -f "$rigTool" ] || rigRefuse "the tools tool is not at the origin: $rigTool"
[ -f "$rigPythonStub" ] || rigRefuse "the Python stand-in is missing: $rigPythonStub"
[ -f "$rigLancedbStub/lancedb/__init__.py" ] || rigRefuse "the lancedb stand-in is missing: $rigLancedbStub/lancedb/__init__.py"
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

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE STORE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWLEDGE_STORE: OK (%d assertions, offline, no LanceDB installed or fetched)\n' "$rigPasses"
