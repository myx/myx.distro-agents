# Stand-in for `lancedb.index`, for the knowledge checks: the one config object AgentsKnowledgeStore.py names, FTS, so
# a build creates the full-text index the fused query needs. Imported as `lancedb.index` through PYTHONPATH
# (sh-test/check-fixtures/knowledge-store-lancedb.stub), never installed anywhere.


class FTS(object):
    pass
