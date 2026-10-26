#!/usr/bin/env python3
# ^^^ for syntax checking in the editor only; run by the store's own Python, never by PATH

##
## AgentsKnowledgeStore.py -- the LanceDB store beside a MAGIC.md (`MAGIC.LanceDB/`), the engine of F8.2/F8.3
## (DistroAgentsKnowledge.fn.sh reads it, the librarian's spread and retire write it). One table, `sections`, one
## record a section that was spread out of the MAGIC.md: `source` the MAGIC.md path below the workspace, `section`
## its caption, `text` its body without the heading line. Run by the store's own Python (the venv Python of
## `--install-knowledge-store`), never by a PATH python; it is the only reader and writer of the store, so the
## LanceDB call it makes is the one place the store's shape is decided.
##
## Subcommands:
##   dump   --store <dir>                 the records of the table, as markdown on stdout: `# <section>` then the
##                                        text, one section after the other, for the query to scan and merge
##   add    --store <dir> --source <ref> --manifest <file>
##                                        the records the manifest names: one line a section, `<caption><TAB><body-file>`,
##                                        each added to the table (a record already there of the same caption is replaced)
##   remove --store <dir> --sections <file>
##                                        the records whose `section` matches a glob of the file (one glob a line) are
##                                        deleted; prints how many
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


def _open(store_dir):
    import lancedb
    db = lancedb.connect(store_dir)
    return db.open_table("sections")


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
    for store in stores:
        for row in _all_rows(_open(store)):
            section = row.get("section", "")
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


def _main():
    if len(sys.argv) < 2:
        return _refuse("a subcommand is needed: dump | add | remove")
    subcommand = sys.argv[1]
    argv = sys.argv[2:]
    if subcommand == "dump":
        return _dump(argv)
    if subcommand == "add":
        return _add(argv)
    if subcommand == "remove":
        return _remove(argv)
    return _refuse("unknown subcommand: " + subcommand)


if __name__ == "__main__":
    sys.exit(_main())
