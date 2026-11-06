# Stand-in for `lancedb.rerankers`, for the knowledge checks: the one reranker AgentsKnowledgeStore.py names, RRF, whose
# fusion the stand-in's own hybrid search already does. Imported as `lancedb.rerankers` through PYTHONPATH
# (sh-test/check-fixtures/knowledge-store-lancedb.stub), never installed anywhere.


class RRFReranker(object):
    pass
