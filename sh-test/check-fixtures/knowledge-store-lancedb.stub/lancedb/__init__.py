# Stand-in for the `lancedb` module, for the knowledge store checks: a store on disk is a plain JSON file,
# `<store>/sections.json`, a list of the records `{"source","section","text"}`, so a check reads and writes records
# without a live LanceDB. Mirrors the calls AgentsKnowledgeStore.py makes -- connect, table_names, open_table,
# create_table, drop_table, and search(None).limit(n).to_list() -- and nothing else. Imported as `lancedb` through
# PYTHONPATH (sh-test/check-fixtures/knowledge-store-lancedb.stub), never installed anywhere.

import json
import os


class _Search(object):
    def __init__(self, rows):
        self._rows = rows

    def limit(self, _count):
        return self

    def to_list(self):
        return list(self._rows)


class _Table(object):
    def __init__(self, store_dir, name):
        self._file = os.path.join(store_dir, name + ".json")

    def search(self, _query=None):
        rows = []
        if os.path.exists(self._file):
            with open(self._file, "r") as handle:
                rows = json.load(handle)
        return _Search(rows)


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

    def drop_table(self, name):
        path = os.path.join(self._dir, name + ".json")
        if os.path.exists(path):
            os.remove(path)


def connect(store_dir):
    return _Db(store_dir)
