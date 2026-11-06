#!/usr/bin/env python3
# ^^^ for syntax checking in the editor only; run by the store's own Python, never by PATH

##
## AgentsKnowledgeStore.py -- the index engine (F8.2/F8.3, S21.23): the one reader and writer of the LanceDB index, run
## by the store's own Python (the venv Python of `--install-knowledge-store`), never by a PATH python.
##
## One row a section of a markdown file, keyed by `<source>#<heading-path>` (`~2`, `~3` on a repeat inside one file):
## `source`, `heading-path`, `heading`, `text`, `hash` of the text, `vector`, `group`, `project-id`, `members`,
## `file-date`. One metadata row stands in `meta`: the model stamp and the schema version. A build re-embeds only a row
## whose hash changed, drops a row the walk no longer produces, and rebuilds whole when the stamp differs. It holds
## `<index>.lock`, and a read never creates the table.
##
## Subcommands:
##   build  --index <dir> --model-dir <dir> --model-stamp <name>@<revision>@<dim>
##                                        the one splitter's sections on stdin (AgentsKnowledgeScan.awk -v format=index,
##                                        `{"sections":[...]}`); prints what it did
##   dump   --store <dir>                 the records of the table, as markdown on stdout: `# <section>` then the
##                                        text, one section after the other, for the query to scan and merge. A store with
##                                        no table is skipped: a read never creates the table
##   add    --store <dir> --source <ref> --manifest <file>
##                                        the records the manifest names: one line a section, `<caption><TAB><body-file>`,
##                                        each added to the table (a record already there of the same caption is replaced)
##   remove --store <dir> --sections <file>
##                                        the records whose `section` matches a glob of the file (one glob a line) are
##                                        deleted; prints how many
##   query  --index <dir> --model-dir <dir> --out-dir <dir> --text <text> [--limit <n>]
##                                        the fused answer: full text and vector in one ranked call (RRF). Each hit's
##                                        section is written to a scratch file in --out-dir, holding the section as the
##                                        walk wrote it, and one `<scratch><TAB><source><TAB><store>` a line on stdout.
##                                        rc 3 when the index does not stand, so the caller answers with the text alone
##
## NOTE: the full-scan LanceDB call (`search(None).limit(...).to_list()`) is written against the pinned LanceDB
## 0.40.0 API and is the one part of this file that a live install must confirm: the query, spread and retire all
## stand behind it, and a store built another way is read the same way.
##

import sys

_LIMIT = 100000


def _refuse(text):
    sys.stderr.write("AgentsKnowledgeStore.py: \u26d4 ERROR: " + text + "\n")
    return 1


def _all_rows(table):
    # Full scan: no vector query. search(None) scans the whole table; limit is a bound above any store's size.
    return table.search(None).limit(_LIMIT).to_list()


def _glob_regex(glob):
    out = "^"
    at = 0
    while at < len(glob):
        ch = glob[at]
        if ch == "*":
            out += ".*"
        elif ch == "?":
            out += "."
        elif ch == "[":
            end = glob.find("]", at + 1)
            if end > 0:
                out += glob[at:end + 1]
                at = end
            else:
                out += "\\["
        elif ch in "\\^$.|+(){}":
            out += "\\" + ch
        else:
            out += ch
        at += 1
    return out + "$"


def _dump(argv):
    import re
    stores = []
    at = 0
    while at < len(argv):
        if argv[at] == "--store":
            stores.append(argv[at + 1])
            at += 2
        else:
            return _refuse("dump: invalid option: " + argv[at])
    import lancedb
    for store in stores:
        db = lancedb.connect(store)
        if "sections" not in db.table_names():
            continue
        for row in _all_rows(db.open_table("sections")):
            section = row.get("heading") or row.get("section", "")
            text = row.get("text", "")
            sys.stdout.write("# " + section + "\n" + text)
            if text and not text.endswith("\n"):
                sys.stdout.write("\n")
            sys.stdout.write("\n")
    return 0


def _add(argv):
    import os
    store = None
    source = None
    manifest = None
    at = 0
    while at < len(argv):
        word = argv[at]
        if word == "--store":
            store = argv[at + 1]
        elif word == "--source":
            source = argv[at + 1]
        elif word == "--manifest":
            manifest = argv[at + 1]
        else:
            return _refuse("add: invalid option: " + word)
        at += 2
    if store is None or source is None or manifest is None:
        return _refuse("add: --store, --source and --manifest are needed")
    import lancedb
    db = lancedb.connect(store)
    rows = []
    with open(manifest, "r") as handle:
        for line in handle:
            line = line.rstrip("\n")
            caption, body_file = line.split("\t", 1)
            with open(body_file, "r") as body:
                rows.append({"source": source, "section": caption, "text": body.read()})
    if not rows:
        return 0
    # Merge, not replace: the records already there stay, a record of the same caption is replaced by the new one, so a
    # spread of one MAGIC.md leaves the records another MAGIC.md put in the store untouched.
    by_caption = {}
    if "sections" in db.table_names():
        for row in _all_rows(db.open_table("sections")):
            by_caption[row.get("section", "")] = row
    for row in rows:
        by_caption[row.get("section", "")] = row
    if "sections" in db.table_names():
        db.drop_table("sections")
    db.create_table("sections", list(by_caption.values()))
    return 0


def _remove(argv):
    import re
    store = None
    sections_file = None
    at = 0
    while at < len(argv):
        word = argv[at]
        if word == "--store":
            store = argv[at + 1]
        elif word == "--sections":
            sections_file = argv[at + 1]
        else:
            return _refuse("remove: invalid option: " + word)
        at += 2
    if store is None or sections_file is None:
        return _refuse("remove: --store and --sections are needed")
    import lancedb
    with open(sections_file, "r") as handle:
        patterns = [re.compile(_glob_regex(line.rstrip("\n"))) for line in handle if line.rstrip("\n")]
    if not patterns:
        return 0
    db = lancedb.connect(store)
    table = db.open_table("sections")
    rows = _all_rows(table)
    kept = []
    removed = 0
    for row in rows:
        caption = row.get("section", "")
        if any(pattern.match(caption) for pattern in patterns):
            removed += 1
        else:
            kept.append(row)
    db.drop_table("sections")
    if kept:
        db.create_table("sections", kept)
    sys.stdout.write(str(removed) + "\n")
    return 0


_SCHEMA_VERSION = 1

## The query's own 3: the index does not stand, so the caller answers with the text alone.
_NO_INDEX = 3


def _lockHolder(lockDir):
    import os
    try:
        with open(os.path.join(lockDir, "pid"), "r") as handle:
            return int(handle.read().strip())
    except (IOError, OSError, ValueError):
        return None


def _processLives(processId):
    import errno
    import os
    try:
        os.kill(processId, 0)
    except OSError as fault:
        return fault.errno == errno.EPERM
    return True


def _unlockIndex(lockDir):
    import shutil
    shutil.rmtree(lockDir, ignore_errors=True)


def _lockIndex(lockDir):
    # os.mkdir is atomic on every POSIX filesystem, and a holder whose process is gone is reclaimed
    import os
    import time
    attempt = 0
    while attempt < 120:
        attempt += 1
        try:
            os.mkdir(lockDir)
        except FileExistsError:
            holderPid = _lockHolder(lockDir)
            if holderPid is not None and not _processLives(holderPid):
                _unlockIndex(lockDir)
                continue
            time.sleep(0.25)
            continue
        with open(os.path.join(lockDir, "pid"), "w") as handle:
            handle.write(str(os.getpid()) + "\n")
        return True
    return False


def _sectionIds(sections):
    # a repeat of one heading path inside a file takes ~2, ~3, so every row's id is unique
    seen = {}
    keyed = []
    for section in sections:
        key = section.get("source", "") + "#" + section.get("heading-path", "")
        seen[key] = seen.get(key, 0) + 1
        keyed.append((key if seen[key] == 1 else key + "~" + str(seen[key]), section))
    return keyed


def _fileDate(path):
    import datetime
    import os
    try:
        changed = os.path.getmtime(path)
    except OSError:
        return ""
    return datetime.datetime.fromtimestamp(changed).astimezone().strftime("%Y-%m-%d %H:%M %z")


def _sectionRow(sectionId, section, digest):
    return {
        "section-id": sectionId,
        "source": section.get("source", ""),
        "heading-path": section.get("heading-path", ""),
        "heading": section.get("heading", ""),
        "text": section.get("text", ""),
        "hash": digest,
        "vector": [],
        "group": section.get("store", ""),
        "project-id": "",
        "members": "",
        "file-date": _fileDate(section.get("path", "")),
    }


def _query(argv):
    import os
    indexDir = None
    modelDir = None
    outDir = None
    text = None
    limit = 24
    at = 0
    while at < len(argv):
        word = argv[at]
        if word == "--index":
            indexDir = argv[at + 1]
        elif word == "--model-dir":
            modelDir = argv[at + 1]
        elif word == "--out-dir":
            outDir = argv[at + 1]
        elif word == "--text":
            text = argv[at + 1]
        elif word == "--limit":
            limit = int(argv[at + 1])
        else:
            return _refuse("query: invalid option: " + word)
        at += 2
    if indexDir is None or modelDir is None or outDir is None or text is None:
        return _refuse("query: --index, --model-dir, --out-dir and --text are needed")
    import lancedb
    db = lancedb.connect(indexDir)
    if "sections" not in db.table_names():
        return _NO_INDEX
    import model2vec
    from lancedb.rerankers import RRFReranker
    model = model2vec.StaticModel.from_pretrained(modelDir)
    vector = [float(value) for value in model.encode([text])[0]]
    table = db.open_table("sections")
    try:
        hits = table.search(query_type="hybrid").vector(vector).text(text).rerank(RRFReranker()).limit(limit).to_list()
    except ValueError:
        # LanceDB refuses a fusion over a table with no full-text index, and the text alone answers then.
        return _NO_INDEX
    # One scratch file a hit: one heading line naming the row's whole heading path, then the body without the section's
    # own heading line. The scanner then reads the hit as a section whose caption is that path, in both output shapes.
    for number, hit in enumerate(hits, 1):
        scratch = os.path.join(outDir, "hit-" + str(number) + ".md")
        lines = hit.get("text", "").split("\n")
        if lines and lines[0].lstrip().startswith("#"):
            lines = lines[1:]
        with open(scratch, "w") as handle:
            handle.write("## " + hit.get("heading-path", "") + "\n" + "\n".join(lines).strip("\n") + "\n")
        sys.stdout.write(scratch + "\t" + hit.get("source", "") + "\t" + hit.get("group", "") + "\n")
    return 0


def _buildLocked(indexDir, modelDir, modelStamp, sections):
    import hashlib
    import lancedb
    db = lancedb.connect(indexDir)
    storedRows = {}
    storedStamp = ""
    if "sections" in db.table_names():
        for row in _all_rows(db.open_table("sections")):
            storedRows[row.get("section-id", "")] = row
    if "meta" in db.table_names():
        for row in _all_rows(db.open_table("meta")):
            storedStamp = row.get("model-stamp", "")
    rebuild = storedStamp != modelStamp
    rows = []
    needsEmbed = []
    for sectionId, section in _sectionIds(sections):
        text = section.get("text", "")
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        before = storedRows.get(sectionId)
        if not rebuild and before is not None and before.get("hash") == digest:
            before["file-date"] = _fileDate(section.get("path", ""))
            rows.append(before)
            continue
        rows.append(_sectionRow(sectionId, section, digest))
        needsEmbed.append(len(rows) - 1)
    if needsEmbed:
        import model2vec
        model = model2vec.StaticModel.from_pretrained(modelDir)
        for at, vector in zip(needsEmbed, model.encode([rows[at]["text"] for at in needsEmbed])):
            rows[at]["vector"] = [float(value) for value in vector]
    # A vanished row is one whose id the pass no longer produces: a changed row is re-embedded, never deleted.
    deleted = len(set(storedRows) - set(row["section-id"] for row in rows))
    if "sections" in db.table_names():
        db.drop_table("sections")
    if rows:
        db.create_table("sections", rows)
        # The full-text side the fused query needs; a store built without it answers as no index.
        from lancedb.index import FTS
        db.open_table("sections").create_index("text", config=FTS())
    if "meta" in db.table_names():
        db.drop_table("meta")
    db.create_table("meta", [{"model-stamp": modelStamp, "schema-version": _SCHEMA_VERSION}])
    sys.stdout.write("built: %d section(s), %d embedded, %d deleted%s\n" % (len(rows), len(needsEmbed), deleted, ", rebuilt" if rebuild else ""))
    return 0


def _build(argv):
    import json
    indexDir = None
    modelDir = None
    modelStamp = None
    at = 0
    while at < len(argv):
        word = argv[at]
        if word == "--index":
            indexDir = argv[at + 1]
        elif word == "--model-dir":
            modelDir = argv[at + 1]
        elif word == "--model-stamp":
            modelStamp = argv[at + 1]
        else:
            return _refuse("build: invalid option: " + word)
        at += 2
    if indexDir is None or modelDir is None or modelStamp is None:
        return _refuse("build: --index, --model-dir and --model-stamp are needed")
    try:
        sections = json.load(sys.stdin).get("sections", [])
    except ValueError:
        return _refuse("build: the splitter's sections could not be read on stdin")
    lockDir = indexDir + ".lock"
    if not _lockIndex(lockDir):
        return _refuse("build: another build holds the index lock: " + lockDir)
    try:
        return _buildLocked(indexDir, modelDir, modelStamp, sections)
    finally:
        _unlockIndex(lockDir)


def _main():
    if len(sys.argv) < 2:
        return _refuse("a subcommand is needed: build | dump | add | remove | query")
    subcommand = sys.argv[1]
    argv = sys.argv[2:]
    if subcommand == "build":
        return _build(argv)
    if subcommand == "dump":
        return _dump(argv)
    if subcommand == "add":
        return _add(argv)
    if subcommand == "remove":
        return _remove(argv)
    if subcommand == "query":
        return _query(argv)
    return _refuse("unknown subcommand: " + subcommand)


if __name__ == "__main__":
    sys.exit(_main())
