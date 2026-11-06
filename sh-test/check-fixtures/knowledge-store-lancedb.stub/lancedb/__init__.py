# Stand-in for the `lancedb` module, for the knowledge store checks: a store on disk is a plain JSON file,
# `<store>/sections.json`, and `<store>/sections.fts` records that the full-text index stands. Mirrors the calls
# AgentsKnowledgeStore.py makes -- connect, table_names, open_table, create_table, drop_table, count_rows, create_index,
# search(None).limit(n).to_list(), and the hybrid builder's search(query_type=...).vector().text().rerank().limit().to_list()
# -- and nothing else. A fused answer here ranks by reciprocal rank over two legs, the vector leg by dot product and the
# text leg by the words a row shares with the query, which is enough for a check to tell a vector-only hit from a
# text-only one. A fusion over a store with no full-text index raises ValueError, as the real LanceDB does. Imported as
# `lancedb` through PYTHONPATH (sh-test/check-fixtures/knowledge-store-lancedb.stub), never installed anywhere.

import json
import os

_RRF_K = 60.0


def _dot(left, right):
    if not left or not right or len(left) != len(right):
        return 0.0
    return sum(one * two for one, two in zip(left, right))


def _wordsOf(text):
    return set(word.strip(".,:;`'\"#*()").lower() for word in text.split() if word.strip(".,:;`'\"#*()"))


class _Search(object):
    def __init__(self, table, query=None, vector=None, text=""):
        self._table = table
        self._vector = vector
        self._text = text
        self._count = 0

    def vector(self, vector):
        self._vector = vector
        return self

    def text(self, text):
        self._text = text
        return self

    def rerank(self, reranker=None, normalize="score"):
        return self

    def where(self, condition, prefilter=True):
        return self

    def select(self, columns):
        return self

    def limit(self, count):
        self._count = count
        return self

    def to_list(self):
        rows = self._table.rows()
        if self._vector is None and not self._text:
            return rows[:self._count]
        if not self._table.hasIndex():
            raise ValueError("Invalid input, Cannot perform full text search unless an INVERTED index has been created on at least one column")
        wanted = _wordsOf(self._text)
        scores = [0.0] * len(rows)
        for rank, at in enumerate(sorted(range(len(rows)), key=lambda at: -_dot(rows[at].get("vector", []), self._vector or []))):
            if _dot(rows[at].get("vector", []), self._vector or []) > 0:
                scores[at] += 1.0 / (_RRF_K + rank + 1)
        for rank, at in enumerate(sorted(range(len(rows)), key=lambda at: -len(wanted & _wordsOf(rows[at].get("text", ""))))):
            if wanted & _wordsOf(rows[at].get("text", "")):
                scores[at] += 1.0 / (_RRF_K + rank + 1)
        fused = [at for at in sorted(range(len(rows)), key=lambda at: -scores[at]) if scores[at] > 0]
        return [rows[at] for at in fused[:self._count]]


class _Table(object):
    def __init__(self, store_dir, name):
        self._file = os.path.join(store_dir, name + ".json")
        self._indexFile = os.path.join(store_dir, name + ".fts")

    def rows(self):
        if not os.path.exists(self._file):
            return []
        with open(self._file, "r") as handle:
            return json.load(handle)

    def hasIndex(self):
        return os.path.exists(self._indexFile)

    def count_rows(self):
        return len(self.rows())

    def search(self, query=None, **options):
        vector = query if isinstance(query, list) else None
        text = query if isinstance(query, str) else ""
        return _Search(self, vector=vector, text=text)

    def create_index(self, column, config=None, **options):
        with open(self._indexFile, "w") as handle:
            handle.write(column + "\n")

    def list_indices(self):
        return [1] if self.hasIndex() else []


class _Db(object):
    def __init__(self, store_dir):
        self._dir = store_dir

    def open_table(self, name):
        return _Table(self._dir, name)

    def table_names(self):
        if not os.path.isdir(self._dir):
            return []
        return [entry[:-5] for entry in os.listdir(self._dir) if entry.endswith(".json")]

    def create_table(self, name, rows):
        if not os.path.isdir(self._dir):
            os.makedirs(self._dir)
        with open(os.path.join(self._dir, name + ".json"), "w") as handle:
            json.dump(rows, handle)
        return _Table(self._dir, name)

    def drop_table(self, name):
        for suffix in (".json", ".fts"):
            path = os.path.join(self._dir, name + suffix)
            if os.path.exists(path):
                os.remove(path)


def connect(store_dir):
    return _Db(store_dir)
