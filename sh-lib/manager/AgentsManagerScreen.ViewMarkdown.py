##
## AgentsManagerScreen.ViewMarkdown.py -- a kind of view: a text of Markdown rendered, and the text of the help.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- a text of Markdown, rendered (MARKDOWN) ----

## Whether the left window shows the text of that row as Markdown: an item at one of the
## places of MARKDOWN_ON whose name ends as MARKDOWN says, or a text of the help (helpShown).
def markdownShown(state, row):
    return row is not None and ((placeOf(state, row) in MARKDOWN_ON and row["id"].lower().endswith(MARKDOWN["suffixes"]))
                                or helpShown(state, row))


## Whether the text of that row is of the help, at one of the places of MARKDOWN_HELP: an
## operation of it, or a folder whose summary the help is.
def helpShown(state, row):
    if placeOf(state, row) not in MARKDOWN_HELP:
        return False
    return row["kind"] == "help-entry" or (row["dive"] and SUMMARIES.get(levelPattern(state.path + [row["id"]]), {}).get("lines") == "helpSummary")


## The lines of the left window for a text of the help, the block of an operation or a summary:
## rendered (markdownLines), but in the raw mode of a text, where they are as the help gives
## them, a long one broken to the window (rawLines); the looks of the window go with them. Set
## out again only when the text, the width of the window, the marks or the mode have changed,
## so never on a tick.
def helpLines(state, row, lines):
    view = state.view
    if not markdownShown(state, row):
        view["looks"] = {}
        return lines
    stamp = (lines, state.viewWidth, MARKS["plain"], state.textMode)
    if view.get("helpFor") != stamp:
        view["helpFor"] = stamp
        view["helpText"] = (rawLines(lines, state.viewWidth), {}) if textRawShown(state) else markdownLines("\n".join(lines), state.viewWidth)
    view["looks"] = view["helpText"][1]
    return view["helpText"][0]


## The lines of the left window from the text a read gave as it is (applyResult): a Markdown
## one rendered (markdownLines), but in the raw mode of a text, and any other as it is, a long
## line broken to the window (rawLines). Set out again only when the text, the width of the
## window, its mode (setViewMode empties it) or the marks have changed, so never on a tick;
## the window keeps its place in the text, as a share.
def viewText(state, row):
    view = state.view
    rendered = markdownShown(state, row) and not textRawShown(state)
    stamp = (view["text"], state.viewWidth, state.viewMode, rendered, MARKS["plain"])
    if view.get("textFor") == stamp:
        return
    view["textFor"] = stamp
    before = len(view["lines"])
    if rendered:
        view["lines"], view["looks"] = markdownLines(view["text"], state.viewWidth)
    else:
        view["lines"], view["looks"] = rawLines(view["text"].splitlines(), state.viewWidth), {}
    if before and view["top"]:
        view["top"] = view["top"] * len(view["lines"]) // before


## The lines of a text shown as it is, to that width of the window: a line that fits stays
## exactly as it is; a longer one is broken between its words, each piece with the blanks of
## the line as they are inside it, the first set in as far as the line is and the others two
## cells more; the blanks where it breaks go with the break, and a word longer than a piece is
## broken where the piece ends. While lines are cut the window is wide (UNWRAPPED_WIDTH), so
## they stand whole.
def rawLines(lines, width):
    room = max(10, width - 1)
    out = []
    for line in lines:
        if textWidth(line) <= room:
            out.append(line)
            continue
        text = line.expandtabs(4)
        after = " " * (min(len(text) - len(text.lstrip(" ")), room // 2) + 2)
        piece, used = "", 0
        for word in re.findall(r" +|[^ ]+", text):
            cells = textCells(word)
            wordWidth = sum(cell[1] for cell in cells)
            if used + wordWidth <= room:
                piece += word
                used += wordWidth
                continue
            if piece.strip():
                out.append(piece.rstrip(" "))
                piece, used = after, len(after)
            if word.startswith(" "):
                continue
            for cluster, clusterWidth in cells:
                if used + clusterWidth > room and piece.strip():
                    out.append(piece)
                    piece, used = after, len(after)
                piece += cluster
                used += clusterWidth
        if piece.strip():
            out.append(piece.rstrip(" "))
    return out


## The root of the myx.common whose catMarkdown renders Markdown in its form for a program
## (--spans): MYXROOT, as the tooling exports it, else the one of the source the screen runs
## from, else the one installed; the first that has it. None where none has. Found once.
def catMarkdownRoot():
    if "catMarkdownRoot" not in MARKDOWN_FOUND:
        MARKDOWN_FOUND["catMarkdownRoot"] = None
        origin = os.environ.get("MDLT_ORIGIN")
        for root in (os.environ.get("MYXROOT"), os.path.join(origin, "myx/myx.common/os-myx.common/host/tarball/share/myx.common") if origin else None,
                     "/usr/local/share/myx.common"):
            try:
                if root and "--spans" in open(os.path.join(root, "include/data/catMarkdown.awk"), encoding="utf-8", errors="replace").read():
                    MARKDOWN_FOUND["catMarkdownRoot"] = root
                    break
            except OSError:
                continue
    return MARKDOWN_FOUND["catMarkdownRoot"]


MARKDOWN_FOUND = {}


## A Markdown text as catMarkdown renders it for the left window, at that width: broken at its
## words where the window wraps its lines, whole where it cuts them (--no-wrap), in the marks of
## one byte on a terminal that is not UTF-8 (--ascii). Gives (lines, {number of a line: [(cell,
## cells, look)]}), each look by MARKDOWN_LOOKS, or None where it could not be rendered.
def catMarkdownSpans(text, width):
    root = catMarkdownRoot()
    if root is None:
        return None
    words = ["sh", os.path.join(root, MARKDOWN["command"]), "--spans"] + (
        ["--width", str(max(10, width - 1))] if width < UNWRAPPED_WIDTH else ["--no-wrap"]) + (["--ascii"] if MARKS["plain"] else [])
    try:
        done = subprocess.run(words, input=text.encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              timeout=MARKDOWN["seconds"], env=dict(os.environ, MYXROOT=root))
    except (OSError, subprocess.SubprocessError):
        return None
    if done.returncode != 0:
        return None
    lines, spansOf = [], {}
    for record in done.stdout.split(b"\n")[:-1]:
        raw, tab, spans = record.partition(b"\t")
        if not tab:
            return None
        looks = []
        for span in spans.decode("ascii", "replace").split(","):
            parts = span.split("+")
            if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit() and parts[2] in MARKDOWN_LOOKS:
                start, length = int(parts[0]), int(parts[1])
                cells = textWidth(raw[start:start + length].decode("utf-8", "replace"))
                if cells:
                    looks.append((textWidth(raw[:start].decode("utf-8", "replace")), cells, MARKDOWN_LOOKS[parts[2]]))
        if looks:
            spansOf[len(lines)] = looks
        lines.append(raw.decode("utf-8", "replace"))
    return lines, spansOf


## A Markdown text as the lines of the left window, set out to that width, and the looks of
## their parts, as the view holds them: (lines, {number of a line: [(cell, cells, look)]}), as
## catMarkdown renders it (catMarkdownSpans), its first "lines" lines; where it cannot, the
## text as it is (rawLines).
def markdownLines(text, width):
    source = text.expandtabs(4).splitlines()
    later = source[MARKDOWN["lines"]:]
    rendered = catMarkdownSpans("\n".join(source[:MARKDOWN["lines"]]), width)
    if rendered is None:
        return rawLines(text.splitlines(), width), {}
    lines, spansOf = rendered
    while lines and not lines[-1]:
        lines.pop()
    if later:
        lines.append("")
        for part in wrapToCells(MARKDOWN["bound"] % (MARKDOWN["lines"], len(later)), max(10, width - 1)):
            spansOf[len(lines)] = [(0, textWidth(part), MARKDOWN_LOOKS["meta"])]
            lines.append(part)
        lines.extend(later)
    return lines, spansOf


## ---- the plugin: the Markdown view ----

## What the Markdown view offers the others to put in (Plugins.py): `on`, the places of the texts that are Markdown, and `help`, the
## places of the help of the tooling, which is Markdown too (markdownShown, helpShown).
registerPlugin({"name": "markdown", "registries": {"on": "place", "help": "place"}})
