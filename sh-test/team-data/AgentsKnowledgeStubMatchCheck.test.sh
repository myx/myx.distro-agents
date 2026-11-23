#!/usr/bin/env bash
## Behavioural check on the lancedb stand-in the knowledge checks run against
## (sh-test/check-fixtures/knowledge-store-lancedb.stub): its matcher answers the predicate forms the store engine
## writes, and its search applies the predicate it is given. The stand-in is the only LanceDB any knowledge check sees,
## so a form it cannot read, or a predicate it drops, makes those checks agree with a fault instead of finding it.
## Held, over the stand-in called directly: no LanceDB is installed and nothing is fetched.
##   1. every predicate form the engine writes matches a row it holds, and a clause a row does not satisfy is refused
##   2. a grouped call answers only the groups asked for, even where rows of other groups would fill a limited answer
##   3. the full-text reader the engine's floor relies on answers the words a row shares with the query
## Red before the fix: the backticked column matched no row, and the predicate never reached the search.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigStub="$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/knowledge-store-lancedb.stub"
rigEngine="$rigOrigin/myx/myx.distro-agents/sh-lib/knowledge/AgentsKnowledgeStore.py"
rigModelStub="$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/knowledge-store-model2vec.stub"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigStub/lancedb/__init__.py" ] || rigRefuse "the lancedb stand-in is not at the origin: $rigStub/lancedb/__init__.py"
[ -f "$rigEngine" ] || rigRefuse "the store engine is not at the origin: $rigEngine"
[ -f "$rigModelStub/model2vec/__init__.py" ] || rigRefuse "the model2vec stand-in is not at the origin: $rigModelStub/model2vec/__init__.py"
command -v python3 > /dev/null 2>&1 || rigRefuse "no python3 on this machine, which both stand-ins run under"
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## Each program below is read into a variable before it runs: a quoted here-doc inside `$( ... )` has its body re-scanned,
## so the backticked column the engine writes would be run as a command instead of reaching Python.
rigReadProgram(){ ## variable name -- the program on stdin, into that variable
	IFS= read -r -d '' "$1" || :
}

echo "-- 1. every predicate form the engine writes, over the stand-in's own matcher --"
rigReadProgram rigPredicateProgram <<'PY'
import os, sys
sys.path.insert(0, os.environ["RIG_LANCEDB_STUB"])
import lancedb
## One row a form the engine writes: `source = '...'` and `section IN (...)` at _add and _remove, and the backticked
## `group` IN (...) at _query. A doubled quote inside a literal is one quote. The last row must be refused.
groupColumn = chr(96) + "group" + chr(96)
cases = [
    ("source = 'a'", {"source": "a"}, "source = 'a'", True),
    ("section IN ('a', 'b')", {"section": "b"}, "section IN ('a', 'b')", True),
    ("section = a doubled quote", {"section": "it's"}, "section = 'it''s'", True),
    ("two clauses joined by AND", {"source": "a", "section": "b"}, "source = 'a' AND section = 'b'", True),
    ("the backticked group column", {"group": "vault"}, groupColumn + " IN ('vault')", True),
    ("the backticked column on another group", {"group": "board"}, groupColumn + " IN ('vault')", False),
]
print( ",".join( "%s:%s" % ( name, "yes" if lancedb._matches( row, where ) == want else "no" ) for name, row, where, want in cases ) )
PY
rigPredicates="$( RIG_LANCEDB_STUB="$rigStub" python3 -I - <<< "$rigPredicateProgram" )" || rigRefuse "the stand-in could not be read by python3"
rigAssert "every form the engine writes matches, and a clause a row does not satisfy is refused" "$rigPredicates" \
	"source = 'a':yes,section IN ('a', 'b'):yes,section = a doubled quote:yes,two clauses joined by AND:yes,the backticked group column:yes,the backticked column on another group:yes"

echo "-- 2. a grouped call answers only the groups asked for --"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigWork="$( mktemp -d "$MMDAPP/.local/temp/AgentsKnowledgeStubMatchCheck.XXXXXX" )" || rigWork=""
[ -n "$rigWork" ] || rigRefuse "no writable folder in the workspace for the stand-in's store"
trap 'rm -rf -- "$rigWork"' EXIT
rigReadProgram rigGroupedProgram <<'PY'
import os, subprocess, sys
stub = os.environ["RIG_LANCEDB_STUB"]
sys.path.insert(0, stub)
import lancedb
work = os.environ["RIG_WORK"]
rows = []
for at in range(5):
    rows.append({"section-id": "board%d" % at, "source": "board/t%d.md" % at, "heading-path": "B%d" % at,
                 "heading": "B%d" % at, "text": "a board section about the query words", "hash": "h",
                 "vector": [1.0, 0.0], "group": "board", "project-id": "", "members": "", "file-date": ""})
rows.append({"section-id": "vault0", "source": "vault/one.md", "heading-path": "V0", "heading": "V0",
             "text": "a vault section about the query words", "hash": "h", "vector": [0.9, 0.0],
             "group": "vault", "project-id": "", "members": "", "file-date": ""})
index = os.path.join(work, "index")
lancedb.connect(index).create_table("sections", rows)
from lancedb.index import FTS
lancedb.connect(index).open_table("sections").create_index("text", config=FTS())
for made in ("model", "out"):
    os.makedirs(os.path.join(work, made))
run = subprocess.run([sys.executable, os.environ["RIG_ENGINE"], "query", "--index", index,
                      "--model-dir", os.path.join(work, "model"), "--out-dir", os.path.join(work, "out"),
                      "--text", "query words", "--groups", "vault", "--limit", "1"],
                     capture_output=True, text=True,
                     env=dict(os.environ, RIG_LANCEDB_STUB=stub,
                              PYTHONPATH=stub + os.pathsep + os.environ["RIG_MODEL_STUB"]))
print("%d:%s" % (run.returncode, ",".join(sorted(line.split("\t")[1] for line in run.stdout.splitlines() if line.strip()))))
PY
rigGrouped="$( RIG_LANCEDB_STUB="$rigStub" RIG_MODEL_STUB="$rigModelStub" RIG_ENGINE="$rigEngine" RIG_WORK="$rigWork" python3 -I - <<< "$rigGroupedProgram" )" || rigRefuse "the grouped call could not be made"
rigAssert "with --groups vault and one row allowed, the answer is the vault row, never a board row" "$rigGrouped" "0:vault/one.md"

echo "-- 3. the full-text reader the engine's floor relies on answers the words a row shares with the query --"
rigReadProgram rigTextLegProgram <<'PY'
import os, sys
sys.path.insert(0, os.environ["RIG_LANCEDB_STUB"])
import lancedb
store = os.path.join(os.environ["RIG_WORK"], "textleg")
lancedb.connect(store).create_table("sections", [
    {"section-id": "hit", "source": "s.md", "heading-path": "H", "heading": "H",
     "text": "the words the query shares stand here", "hash": "h", "vector": [0.0, 1.0], "group": "docs",
     "project-id": "", "members": "", "file-date": ""},
    {"section-id": "miss", "source": "m.md", "heading-path": "M", "heading": "M",
     "text": "nothing of the kind", "hash": "h", "vector": [1.0, 0.0], "group": "docs",
     "project-id": "", "members": "", "file-date": ""}])
from lancedb.index import FTS
lancedb.connect(store).open_table("sections").create_index("text", config=FTS())
hits = lancedb.connect(store).open_table("sections").search("query shares", query_type="fts").limit(10).to_list()
print(",".join(sorted(hit.get("section-id", "") for hit in hits)))
PY
rigTextLeg="$( RIG_LANCEDB_STUB="$rigStub" RIG_WORK="$rigWork" python3 -I - <<< "$rigTextLegProgram" )" || rigRefuse "the full-text reader could not be read"
rigAssert "the reader answers the row holding the query's words, and not the one that does not" "$rigTextLeg" "hit"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE STUB MATCH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  fix:  the matcher and the search of the lancedb stand-in, sh-test/check-fixtures/knowledge-store-lancedb.stub"
	exit 1
fi
echo "KNOWLEDGE_STUB_MATCH: OK ($rigPasses assertions, offline)"
