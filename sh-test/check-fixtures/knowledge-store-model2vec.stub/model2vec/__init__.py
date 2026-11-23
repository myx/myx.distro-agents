# Stand-in for the `model2vec` module, for the knowledge checks: two concepts, so a word and its paraphrase share an
# axis and a fused query answers one from the other without a model on the machine. Mirrors the calls
# AgentsKnowledgeStore.py makes -- StaticModel.from_pretrained(folder) and encode(texts) -- and nothing else.
# RIG_MODEL_LOG names a file, and every text given to encode is appended as one `TEXT<TAB><first words>` line, which is
# how a check counts what a pass embedded. Imported as `model2vec` through PYTHONPATH
# (sh-test/check-fixtures/knowledge-store-model2vec.stub), never installed anywhere.

import os

CONCEPTS = {
    "undo": 0, "undoes": 0, "release": 0, "releases": 0, "rollback": 0, "revert": 0, "previous": 0,
    "deploy": 0, "deployment": 0, "deploys": 0,
    "cache": 1, "caches": 1, "stale": 1, "evict": 1, "eviction": 1, "key": 1, "entry": 1, "entries": 1,
}


class StaticModel(object):
    def __init__(self, folder):
        self.folder = folder

    @classmethod
    def from_pretrained(cls, folder):
        return cls(folder)

    def encode(self, texts):
        log = os.environ.get("RIG_MODEL_LOG")
        if log:
            with open(log, "a") as handle:
                handle.write("".join("TEXT\t" + " ".join(text.split())[:40] + "\n" for text in texts))
        return [self._vectorOf(text) for text in texts]

    def _vectorOf(self, text):
        # A REAL STATIC MODEL NEVER ANSWERS A ZERO VECTOR. A query of words it does not know still lands somewhere, and
        # the live potion-base-8M scores such a query 0.3347 against its nearest row. A stand-in that answered
        # [0.0, 0.0] gave the vector leg nothing to rank, so the shipped rig could not reproduce a query no section
        # holds and a check of that fault was green before any fix. The baseline stands under every text, and the
        # concepts stand far above it, so a query of known words still wins its own axis.
        vector = [0.05, 0.05]
        for word in text.lower().replace(">", " ").replace("-", " ").split():
            axis = CONCEPTS.get(word.strip(".,:;`'\"#*()"))
            if axis is not None:
                vector[axis] += 1.0
        return vector
