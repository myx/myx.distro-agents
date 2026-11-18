#!/usr/bin/env bash
## Behavioural check on the knowledge index being built and kept fresh (the board item task-20261117T2330Z):
## the schedule's refresh (`AgentsToolsScheduleThreadKnowledgeKeep`, AgentsTools.ScheduleThread.include), the stamp the
## store writers leave (`AgentsToolsKnowledgeWantedMark`, AgentsTools.KnowledgeStore.include), the build's own stamp of a
## finished run, and the query saying which source answered it. Held, over a rig distro workspace and a rig team-data store,
## with the lancedb and model stand-ins, so no LanceDB is installed and nothing is fetched:
##   1. a write to a store the query reads leaves `wanted` newer than `built`
##   2. that write is not in the index yet, and one schedule pass puts it there: the query finds it
##   3. that pass wrote `built` newer than `wanted` and left no lock behind
##   4. a second pass with nothing changed builds nothing: `built` keeps the moment it had
##   5. a `built` older than the bound builds again, which is what catches a hand edit to a MAGIC.md
##   6. the bound at 0 never builds, whatever the stamps say
##   7. the query says which source answered, on stderr, and its answer text is unchanged by that line
## Red: on a tree without the refresh step every pass builds nothing, so assertion 2 fails at the pass that should have
## built; without the stamp in the write funnels assertion 1 fails; without the build's own stamp assertion 3 fails.
## Offline: a rig of this check alone, removed at its end; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigLib="$rigOrigin/myx/myx.distro-agents/sh-lib"
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigKnowledge="$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh"
rigFixDir="$rigPackage/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigKnowledge" ] || rigRefuse "the knowledge tool is not at the origin: $rigKnowledge"
[ -f "$rigFixDir/knowledge-store-lancedb.stub/lancedb/__init__.py" ] || rigRefuse "the lancedb stand-in is missing"
[ -f "$rigFixDir/knowledge-store-model2vec.stub/model2vec/__init__.py" ] || rigRefuse "the model2vec stand-in is missing"
command -v python3 > /dev/null 2>&1 || rigRefuse "no python3 on this machine, which the store's Python stand-in runs"
rigPythonDir="$( dirname "$( command -v python3 )" )"
. "$rigFixDir/rig-distro-workspace.include.sh" || exit 1
. "$rigFixDir/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigDistroTmp AgentsKnowledgeIndexKeepCheck )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigDws="$rigTmp/dws" rigData="$rigTmp/data" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigHolds(){ ## result name, text -- yes or no
	if LC_ALL=C grep -q -F -- "$2" "$rigTmp/$1.out" 2> /dev/null ; then printf yes ; else printf no ; fi
}

echo "-- the rig: a distro workspace, the store's Python and model stand-ins, an empty team-data store --"
rigDistroPath > /dev/null 2>&1 || rigRefuse "no myx.common on PATH, which the build's source scan needs"
rigDistroWorkspace "$rigDws" rig || rigRefuse "cannot make the rig workspace"
rigDistroProject "$rigDws" rig rig.alpha "" || rigRefuse "cannot make the rig project"
mkdir -p "$rigDws/source/rig/rig.alpha" "$rigData" "$rigHome" "$rigSkills" "$rigDws/.local/lancedb/venv/bin" "$rigDws/.local/lancedb/model/potion-base-8M" "$rigTmp/pylib"
printf '# Alpha\n\n## Alpha rules\n\nThe RIGDOCWORD in a rule.\n' > "$rigDws/source/rig/rig.alpha/MAGIC.md"
printf 'LANCEDB_MODEL_NAME=potion-base-8M\nLANCEDB_MODEL_REVISION=rig111\nLANCEDB_MODEL_DIM=2\n' > "$rigDws/.local/lancedb/lancedb.env"
cp "$rigFixDir/knowledge-store.python.stub.sh" "$rigDws/.local/lancedb/venv/bin/python" || rigRefuse "the Python stand-in is missing"
chmod +x "$rigDws/.local/lancedb/venv/bin/python"
cp -R "$rigFixDir/knowledge-store-lancedb.stub/lancedb" "$rigTmp/pylib/lancedb" || rigRefuse "cannot stage the lancedb stand-in"
cp -R "$rigFixDir/knowledge-store-model2vec.stub/model2vec" "$rigTmp/pylib/model2vec" || rigRefuse "cannot stage the model2vec stand-in"

## The environment every call of this rig runs in, as arguments of env.
rigEnvList=( HOME="$rigHome" PATH="$( rigDistroPath ):$rigPythonDir:/usr/bin:/bin" MMDAPP="$rigDws" MDLT_ORIGIN="$rigOrigin"
	MDLT_OPTION="--run-from-path $rigOrigin" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills"
	MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-index-keep MDAT_KNOWLEDGE_STORE=on
	RIG_LANCEDB_STUB="$rigTmp/pylib" )
rigPass(){ ## result name, the bound in seconds, extra environment as NAME=value... -- one schedule pass
	local passName="$1" passEvery="$2" passRc=0
	shift 2
	( cd "$rigDws" && env -i ${rigEnvList[@]+"${rigEnvList[@]}"} MDAT_SCHEDULE_KNOWLEDGE_INDEX_SECONDS="$passEvery" "$@" \
		bash -c '. "$1" ; AgentsToolsScheduleThreadKnowledgeKeep ; printf "%s\n" "$?"' _ "$rigLib/schedule/AgentsTools.ScheduleThread.include" ) \
		> "$rigTmp/$passName.out" 2> "$rigTmp/$passName.err" < /dev/null || passRc=$?
	printf '%s' "$passRc" > "$rigTmp/$passName.rc"
}
rigQuery(){ ## result name, store setting (on|off), words... -- one query
	local queryName="$1" querySetting="$2" queryRc=0
	shift 2
	( cd "$rigDws" && env -i ${rigEnvList[@]+"${rigEnvList[@]}"} ${querySetting:+MDAT_KNOWLEDGE_STORE="$querySetting"} \
		bash "$rigKnowledge" "$@" ) > "$rigTmp/$queryName.out" 2> "$rigTmp/$queryName.err" < /dev/null || queryRc=$?
	printf '%s' "$queryRc" > "$rigTmp/$queryName.rc"
}
rigIndexRoot="$rigDws/.local/knowledge-index"
rigStamp(){ printf '%s.%s.stamp' "$rigIndexRoot" "$1" ; }
rigMoment(){ ## path -- its mtime in seconds, or 0
	local momentAt=""
	momentAt="$( LC_ALL=C stat -f '%m' "$1" 2> /dev/null || LC_ALL=C stat -c '%Y' "$1" 2> /dev/null )" || momentAt=""
	case "$momentAt" in ''|*[!0123456789]*) printf '0' ;; *) printf '%s' "$momentAt" ;; esac
}
rigBodyCount=0
rigBody(){ ## text -- the path of a body file holding it
	rigBodyCount=$(( rigBodyCount + 1 ))
	printf '%s\n' "$1" > "$rigTmp/body$rigBodyCount"
	printf '%s' "$rigTmp/body$rigBodyCount"
}
rigVaultReady(){ ## word -- a vault document holding it, written by its store's owner
	rigStoreItem "$rigTmp" "$rigData" "$rigDws" keeper-rig "vault note-20261118T0100Z-$1.md" \
		"$( rigBody "$( printf -- '---\ntype: note\n---\n\n# A %s\n\nThe %s stands in this document.\n' "$1" "$1" )" )" > /dev/null 2>&1 \
		|| rigRefuse "could not build the vault fixture note-20261118T0100Z-$1.md"
}

echo "-- 1. a write to a store the query reads leaves wanted newer than built --"
rigPass firstbuild 900
rigVaultReady rigKEPTWORD
rigAssert "the first pass built the index"                       "$( [ -f "$rigIndexRoot/sections.json" ] && printf built || printf none )" built
rigAssert "the build stamped built"                              "$( [ -f "$( rigStamp built )" ] && printf yes || printf no )" yes
rigAssert "the vault write touched wanted, and it is newer than built" "$( [ -f "$( rigStamp wanted )" ] && printf yes || printf no ):$( [ "$( rigMoment "$( rigStamp wanted )" )" -ge "$( rigMoment "$( rigStamp built )" )" ] && printf newer || printf older )" "yes:newer"

echo "-- 2. that write is not in the index yet, and one pass puts it there --"
rigQuery before on --add-vault-items --query-keyword rigKEPTWORD
rigAssert "the query does not answer the document the index has not seen" "$( cat "$rigTmp/before.rc" ):$( rigHolds before rigKEPTWORD )" "0:no"
rigPass afterwrite 900
rigQuery after on --add-vault-items --query-keyword rigKEPTWORD
rigAssert "one schedule pass put it in the index, and the query finds it" "$( cat "$rigTmp/after.rc" ):$( rigHolds after rigKEPTWORD )" "0:yes"

echo "-- 3. that pass wrote built newer than wanted, and left no lock --"
rigAssert "a build stands and built is newer than wanted"          "$( [ -f "$( rigStamp built )" ] && printf stands || printf absent ):$( [ "$( rigMoment "$( rigStamp built )" )" -ge "$( rigMoment "$( rigStamp wanted )" )" ] && printf newer || printf older )" "stands:newer"
rigAssert "no build lock stands after the pass"                  "$( [ -e "$rigIndexRoot.lock" ] && printf left || printf none )" none

echo "-- 4. a second pass with nothing changed builds nothing --"
## `wanted` is put a minute behind, since the stamps carry whole seconds and a write and a build inside one second cannot be ordered.
rigAgoStamp="$( date -r "$(( $( date +%s ) - 60 ))" '+%Y%m%d%H%M' 2> /dev/null || date -d "@$(( $( date +%s ) - 60 ))" '+%Y%m%d%H%M' 2> /dev/null )" || rigAgoStamp=""
[ -z "$rigAgoStamp" ] || touch -t "$rigAgoStamp" "$( rigStamp wanted )"
rigBuiltMoment="$( rigMoment "$( rigStamp built )" )"
rigPass secondpass 900
rigAssert "a build stands and it keeps the moment it had"        "$( [ -f "$( rigStamp built )" ] && printf stands || printf absent ):$( rigMoment "$( rigStamp built )" )" "stands:$rigBuiltMoment"

echo "-- 5. a built older than the bound builds again --"
touch -t 202001010000 "$( rigStamp built )"
rigPass stalebound 900
rigAssert "the pass built again, so built is fresh"               "$( [ -z "$( find "$( rigStamp built )" -mmin +1 2> /dev/null )" ] && printf fresh || printf stale )" fresh

echo "-- 6. the bound at 0 never builds --"
touch -t 202001010000 "$( rigStamp built )"
rigPass neverbound 0
rigAssert "nothing was built: built keeps the moment from 2020"    "$( [ -z "$( find "$( rigStamp built )" -newermt 2020-01-02 2> /dev/null )" ] && printf stale || printf fresh )" stale

echo "-- 7. the query says which source answered, on stderr, and its answer is unchanged --"
rigQuery fromindex on --add-vault-items --query-keyword rigKEPTWORD
mv "$rigIndexRoot" "$rigIndexRoot.aside"
rigQuery fromtext on --add-vault-items --query-keyword rigKEPTWORD
mv "$rigIndexRoot.aside" "$rigIndexRoot"
rigAssert "the index names itself on stderr"                     "$( LC_ALL=C grep -c -F 'answered from the index' "$rigTmp/fromindex.err" || : ):$( LC_ALL=C grep -c -F 'answered from the' "$rigTmp/fromindex.out" || : )" "1:0"
rigAssert "the text alone names itself and why, on stderr"        "$( LC_ALL=C grep -c -F 'answered from the text alone' "$rigTmp/fromtext.err" || : ):$( LC_ALL=C grep -c -F 'no index stands' "$rigTmp/fromtext.err" || : ):$( rigHolds fromtext rigKEPTWORD )" "1:1:yes"
rigAssert "the answer text is the document itself, unchanged by that line" "$( LC_ALL=C grep -c -F 'The rigKEPTWORD stands in this document.' "$rigTmp/fromtext.out" || : ):$( LC_ALL=C grep -c -F 'answered from' "$rigTmp/fromtext.out" || : )" "1:0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE INDEX KEEP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: the index is built once and then never refreshed, so a query answers from a corpus that moved under it" >&2
	echo "  fix:  AgentsToolsScheduleThreadKnowledgeKeep in sh-lib/schedule/AgentsTools.ScheduleThread.include, and the stamp in AgentsToolsItemUpsert and the inbox upsert" >&2
	exit 1
fi
echo "KNOWLEDGE_INDEX_KEEP: OK ($rigPasses assertions, offline)"
