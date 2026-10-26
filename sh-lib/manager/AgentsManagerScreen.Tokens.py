##
## AgentsManagerScreen.Tokens.py -- the tokens views of the Dashboard (F11.4): under `Agents: Tokens`, `Tokens By Day`, `Tokens By Preset`, `Tokens By Credential`,
## `Tokens By Agent` and `Tokens By Routine`, each the tokens summed by one key, with a switch between their sum and their average per run, and a switch
## between the data table and a chart of the distribution and the trend of the tokens.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## The screen renders what the Dispatcher gives and computes nothing: the average of a run and the shares come from `--manager-stats-tokens --average --share` (the switch only asks for the one or the other); `--manager-stats-tokens` is the
## Dispatcher's `--token-stats` (AgentsTools.ManagerStats.include), its rows `tokens <key> <runs> <in> <cache-read> <cache-write> <out>`.
##

## The id of the group of the Dashboard (the agents' `dashboard-panels.list`) these views stand in.
TOKEN_GROUP = "tokens"
## The views: the id of each, what it shows as, and the key of the Dispatcher's `--by` it is read by.
## The two panels are views of their own, first in the group: each shows one of the two charts.
TOKEN_PANELS = ("distribution", "trendview")
TOKEN_VIEWS = (("distribution", "Tokens, Distribution", "day"), ("trendview", "Tokens, Trend", "day"),
               ("day", "Tokens By Day", "day"), ("preset", "Tokens By Preset", "preset"), ("credential", "Tokens By Credential", "credential"),
               ("weekday", "Tokens By Weekday", "weekday"), ("hour", "Tokens By Hour", "hour"),
               ("agent", "Tokens By Agent", "member"), ("routine", "Tokens By Routine", "routine"))
## The fields of a `tokens` row after its first, and the columns they show as.
TOKEN_FIELDS = ("key", "runs", "in", "cacheRead", "cacheWrite", "out")
## The two fields `--share` adds after them: the share of the key's `in` tokens in the total of all keys, and in the largest key, each in whole percent.
TOKEN_SHARE_FIELDS = ("share", "peak")
TOKEN_HEADS = ("RUNS", "IN", "CACHE READ", "CACHE WRITE", "OUT")
## Whether the views show the average per run in place of the sum: one switch for all of them, `s`.
TOKENS_AVERAGE = [False]
## The height of a column of the charts, in cells, not counting its label line.
TOKEN_CHART_HEIGHT = 6
## The tallest the chart may stand: it takes what the pane has, up to this, so a tall pane gets
## a tall plot and a short one still gets a readable strip.
TOKEN_CHART_MAX = 12
## The synthetic level the day rows of the trend are kept under: the `also` read of every view, keyed by the pattern of the group.
def trendLevel():
    return pluginLevel("tokens") + "/*/trend"
## Whether the views show a chart in place of the table: one switch for all of them, `c`.
TOKENS_CHART = [True]
## The second chart view: a column divided by token kind. ONE key cycles the three views of the
## pane -- plain chart, stacked chart, table -- so this says which of the two charts is shown.
TOKENS_STACK = [False]


## Whether the level that is shown is the group of the tokens: the views stand in no other group of the Dashboard (a fixed row of the level asks).
def tokensGroupHere(state, path):
    return bool(path) and path[-1] == TOKEN_GROUP


## The numbers of one row as the views show them: how many runs, then the tokens, summed or, with the switch on, the average of a run (whole tokens).
def tokenCells(token):
    values = [token[name] for name in ("in", "cacheRead", "cacheWrite", "out")]
    return [token["runs"]] + [shortCount(value) if value.isdigit() else value for value in values]


## What `--manager-stats-tokens` printed, as rows: a `tokens` row is a key, shown by it and with its runs after it; a row too short, and a line of another name, is left out.
def parseTokenRows(readKey, level, text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] != "tokens" or len(fields) <= len(TOKEN_FIELDS):
            continue
        token = dict(zip(TOKEN_FIELDS, fields[1:1 + len(TOKEN_FIELDS)]))
        token.update(zip(TOKEN_SHARE_FIELDS, fields[1 + len(TOKEN_FIELDS):]))
        row = newRow(token["key"], token["key"], "record", False, fields)
        row["tokens"] = token
        row["tail"] = "%s run%s" % (token["runs"], "" if token["runs"] == "1" else "s")
        rows.append(row)
    return {level: rows}


ROW_FORMS["tokens"] = parseTokenRows


## The one value a chart draws of a row, the `in` tokens, summed or, with the switch on, the average of a run (whole tokens), as the table shows them.
def tokenChartValue(token):
    return token["in"]


## The tokens of a view as a chart, in place of the table: two panels of the Dashboard's own drawing, the distribution of the `in` tokens over
## the keys (each a share of their total) and their trend (each a share of the largest), a bar for every key, drawn by the block drawing the
## Dashboard uses (blockGrid, the bar of a share). The title above them says what the table's would.
def tokensChart(state, tokens, label, view=None):
    def figure(token, held):
        return {"block": "tokens", "key": token["key"], "label": token["key"], "value": tokenChartValue(token),
                "unit": "count", "level": "ok", "share": str(held)}
    ## VERTICAL BAR CHARTS, fitted to the room the pane has: a column per key, as many as fit,
    ## each at most `col` cells wide with its label, value and share cut to that width -- so a
    ## narrow pane or many keys never overflows, it only shortens what a column can say.
    def columns(title, names, numbers, labels, percents, room, height=TOKEN_CHART_HEIGHT, kinds=None):
        count = max(1, len(names))
        gap = 1 if count > 1 else 0
        ## A column is a BAND, not a wall: it never grows past a readable width, and it shrinks
        ## to fit when there are many keys or the pane is narrow.
        ## FITTING THE PANE: the columns take the width it has and no more, and the chart takes
        ## the HEIGHT it has -- a wide, squat plot reads as a strip, not as a chart.
        ## FIT OR SCROLL: with WRAP on the chart fills the pane it has -- the columns share its
        ## width and no more, whatever the room. With WRAP off it is drawn WIDE, at a readable
        ## column, and the pane pans over it (LEFT/RIGHT), which is what nowrap is for.
        if wrapOn:
            col = min(6, max(2, (room - gap * (count - 1)) // count))
        else:
            col = 10
        top = max(numbers + [0])
        ## EIGHTHS: a bar is measured in eighths of a cell, so its top stands on a partial block
        ## (▁▂▃▄▅▆▇█) and two values a tenth apart no longer draw the same height.
        EIGHTHS = " ▁▂▃▄▅▆▇█"
        eighths = [max(0, (value * height * 8 + top // 2) // top) if value and top else 0 for value in numbers]
        bars = [max(1, (value * height + top // 2) // top) if value and top else 0 for value in numbers]
        def cut(text):
            text = str(text)
            if len(text) <= col:
                return text
            return (text[:col - 1] + "~") if col > 1 else text[:col]
        ## A BAR IS NARROW: at most three cells of block inside its column's band, centred, so a
        ## chart reads as bars with air around them and not as a wall of blocks.
        KIND_GLYPHS = ("\u2588", "\u2593", "\u2592", "\u2591")
        def stackedCells(amounts, top):
            total = sum(amounts)
            glyphs = [" "] * height
            if total and top:
                spans = [max(1, (amount * height + total // 2) // total) if amount else 0 for amount in amounts]
                while sum(spans) > height:
                    spans[spans.index(max(spans))] -= 1
                position = height - 1
                for index, span in enumerate(spans):
                    for _ in range(span):
                        if position < 0:
                            break
                        glyphs[position] = KIND_GLYPHS[index]
                        position -= 1
            return glyphs
        bar = "\u2588" * min(2, col)
        pad = " " * ((col - len(bar)) // 2)
        cell = pad + bar + " " * (col - len(bar) - len(pad))
        ## THE AXIS IS NEVER A FULL NAME: the columns are numbered, the interval is said on top,
        ## and the legend below maps a number to its key -- a wide key never widens the chart.
        interval = ""
        if len(names) > 1:
            interval = " -- %s .. %s" % (str(names[0])[:24], str(names[-1])[:24])
        out = [looked(title + interval, BOLD)]
        filler = " " * col
        kindCells = []
        for index in range(len(numbers)):
            amounts = kinds[index] if kinds and index < len(kinds) else [numbers[index], 0, 0, 0]
            kindCells.append(stackedCells(amounts, top))
        for level in range(height, 0, -1):
            if TOKENS_STACK[0]:
                ## A SEGMENT OF A STACK CARRIES ITS OWN COLOUR: the shade glyph of a kind maps to a
                ## look of its own, so `in`, `cache read`, `cache write` and `out` are four colours
                ## as well as four shades, and a reader who cannot tell the shades still sees them.
                KIND_LOOK = {"\u2588": BOLD, "\u2593": LEVEL_OK, "\u2592": LEVEL_WARN, "\u2591": LEVEL_BAD}
                pieces, spans, at = [], [], 0
                for index in range(len(numbers)):
                    glyphs = kindCells[index][level - 1]
                    text = pad + "".join(glyph * len(bar) for glyph in glyphs) + " " * (col - len(bar) * len(glyphs) - len(pad))
                    held = at + len(pad)
                    for glyph in glyphs:
                        spans.append((held, len(bar), KIND_LOOK.get(glyph, BOLD)))
                        held += len(bar)
                    pieces.append(text)
                    at += col + len(filler)
                out.append(lookedAt("".join(pieces).rstrip(), spans))
            else:
                def plainCell(index, level):
                    held = eighths[index]
                    full = held // 8
                    rest = held % 8
                    if level <= full:
                        return looked(cell, BOLD) if False else cell
                    if level == full + 1 and rest:
                        glyph = EIGHTHS[rest]
                        return (pad + glyph * len(bar) + " " * (col - len(bar) - len(pad)))
                    return " " * col
                out.append(looked(filler.join(plainCell(index, level) for index in range(len(numbers))).rstrip(), BOLD))
        out.append(looked(filler.join("-" * col for name in names).rstrip(), DIM))
        ## THE AXIS CARRIES THE SHORT OF A KEY, never the whole of it: a date is its day, an hour
        ## its hour, and a name is itself while it fits its column. Only what does not fit is
        ## numbered, and then a LEGEND below maps the number -- wrapped, several to a line.
        def axisOf(name):
            text = str(name)
            if len(text) == 10 and text[4] == "-" and text[7] == "-":
                return text[8:10]
            if len(text) >= 16 and text[10] == " " and text[13] == ":":
                return text[11:16]
            if len(text) >= 13 and text[10] == "T" and text[13] == ":":
                return text[11:13] + "h"
            return text
        short = [axisOf(name) for name in names]
        fitting = all(len(name) <= col for name in short)
        ## EVERY FIELD OF A COLUMN IS CENTRED IN ITS BAND, as the bar is: a label left-aligned
        ## under a centred bar sits a cell or two off it, and an operator reads that as a wrong
        ## chart rather than as a misaligned caption.
        def centred(text):
            text = str(text)
            return text.center(col) if len(text) <= col else text[:col]
        if fitting:
            out.append(looked(filler.join(centred(name) for name in short).rstrip(), DIM))
        else:
            out.append(looked(filler.join(centred(index + 1) for index in range(len(names))).rstrip(), DIM))
        for field in ([labels] + ([percents] if percents else [])):
            out.append(looked(filler.join(centred(cut(item)) for item in field).rstrip(), DIM))
        if not fitting:
            line = "  "
            for index, name in enumerate(short):
                entry = "%d=%s" % (index + 1, cut(name))
                if len(line) + len(entry) + 2 > room and line.strip():
                    out.append(looked(line.rstrip(), None))
                    line = "  "
                line += entry + "  "
            if line.strip():
                out.append(looked(line.rstrip(), None))
        return out
    room = max(12, state.viewWidth - 2)
    wrapOn = bool(getattr(state, "wrap", True))
    ## THE KEY, THE NUMBER AND THE LABEL OF EVERY TOKEN, before anything decides what to draw with
    ## them: the short-pane branch below reads them too, and taking them after it raised a
    ## NameError that left the whole pane empty (which is what a short terminal showed).
    numbers = [int(tokenChartValue(token)) if tokenChartValue(token).isdigit() else 0 for token in tokens]
    labels = [tokenChartValue(token) for token in tokens]
    names = [token.get("key") or token.get("member") or "" for token in tokens]
    ## A PANE TOO SHORT FOR A PLOT GETS A SPARKLINE: one line of eighths, the labels beneath, so
    ## the shape is still there when the height is not (T11: "doesn't fit").
    if (getattr(state, "viewHeight", 0) or 0) < 14:
        return sparkLines(names, numbers, labels, room)
    ## a taller pane, a taller chart: six cells is a strip, not a plot
    chartHeight = max(6, min(TOKEN_CHART_MAX, (getattr(state, "viewHeight", 0) or 0) - 9))
    chart = [looked("%s, %s" % (label, "the average of a run" if TOKENS_AVERAGE[0] else "summed over its runs"), BOLD)]
    kinds = [[int(held) if str(held).isdigit() else 0 for held in (
        token.get("in", "0"), token.get("cacheRead", "0"), token.get("cacheWrite", "0"), token.get("out", "0"))] for token in tokens]
    ## A panel view shows its own panel alone; a data view shows both.
    dedicated = view in TOKEN_PANELS
    ## ONE CHART A VIEW: the Distribution view draws the distribution, the Trend view the
    ## trend, and a data view (day, preset, …) draws the ONE chart of what it groups -- never
    ## two charts of the same rows in one pane, which is what made the pair read as a duplicate.
    wantDistribution = (not dedicated) or view == "distribution"
    wantTrend = view == "trendview"
    if wantDistribution:
        chart += columns("Distribution of the tokens (in)", names, numbers, labels, ["%s%%" % token.get("share", "0") for token in tokens], room, kinds=kinds)
    ## THE TREND IS OVER ITS DAY BUCKETS, not over the view's keys: the `trend` read of every
    ## view is the same `--by day` rows (trendLevel), so the second chart shows the tokens moving
    ## over the days even when the first one splits them by preset, credential, member or routine.
    trendRows = state.rows.get(trendLevel()) or []
    ## A chart of BUCKETS holds the rows that are a bucket: the total a view may carry beside them
    ## is no key of the chart, and plotting it as one drew a nameless column over the days.
    trendTokens = [held for held in trendRows if held.get("tokens") and held.get("key")]
    if not wantTrend:
        return chart
    if trendTokens:
        ## A row of the trend that carries no key is named by its member, and by nothing at all
        ## where it has neither: a missing name must not take the whole screen down.
        trendNames = [held.get("key") or held.get("member") or "" for held in trendTokens]
        trendNumbers = [int(held["tokens"]["in"]) if held["tokens"].get("in", "").isdigit() else 0 for held in trendTokens]
        trendLabels = [held["tokens"]["in"] for held in trendTokens]
        trendPeak = max(trendNumbers + [0])
        ## A TIME SERIES PLOTS THE VALUES, not a share of its own peak: normalising by the peak
        ## makes the largest bar always 100% and hides whether the series rose or fell -- a
        ## manipulated axis (the classic "avoid manipulated axes" rule). The scale is stated in
        ## the title instead, so the reader knows what 12 cells mean.
        chart += columns("Trend of the tokens (in) -- up to %s a day" % trendLabels[trendNumbers.index(trendPeak)] if trendPeak else "Trend of the tokens (in)",
                         trendNames, trendNumbers, trendLabels, None, room, height=chartHeight)
    else:
        chart += columns("Trend of the tokens (in)", names, numbers, labels, ["%s%%" % token.get("peak", "0") for token in tokens], room, height=chartHeight)
    return chart


## The rows of a view as one table: the key, the runs, and the four kinds of tokens, as the Dispatcher gave them, summed or averaged by the switch (the read is made again with `--average`).
def tokensSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        ## A PANE THAT IS READING SAYS SO: it never stands empty, which reads as a screen that
        ## has nothing to show (and is what a half-read flow looks like on a real terminal).
        return [looked("Tokens: the runs are being read...", BOLD)]
    tokens = [held["tokens"] for held in rows if held.get("tokens")]
    label = next((view[1] for view in TOKEN_VIEWS if view[0] == form["view"]), form["view"])
    if not tokens:
        return [looked("%s: no run is recorded for it." % label, BOLD)]
    if TOKENS_CHART[0]:
        return tokensChart(state, tokens, label, form.get("view"))
    lines = [looked("%s, %s" % (label, "the average of a run" if TOKENS_AVERAGE[0] else "summed over its runs"), BOLD)]
    lines.extend(tableSummaryLines(state, ("KEY",) + TOKEN_HEADS, [[token["key"]] + tokenCells(token) for token in tokens],
                                   ("key",) + ("enum",) * len(TOKEN_HEADS)))
    return lines


## ... of a row of a view: the same table, whichever row is selected.
def tokensFocus(state, row):
    view = next((held for held in TOKEN_VIEWS if levelPattern(state.path).endswith("/" + held[0])), None)
    return tokensSummary(state, state.path, row, {"view": view[0]}) if view else None


## The words the switch adds to the read of a view: `--average` while the averages are shown (readWords).
def tokensWords(state):
    return ["--average"] if TOKENS_AVERAGE[0] else []


## `s`: the average per run in place of the sum, and back. The read of every view has other words with the switch on (tokensWords), so it is made again by the Dispatcher.
def tokensMode(state, row):
    TOKENS_AVERAGE[0] = not TOKENS_AVERAGE[0]
    state.view.pop("blocksFor", None)
    return "Tokens: %s" % ("the average of a run" if TOKENS_AVERAGE[0] else "summed over their runs")


ACTION_HANDLERS["tokensmode"] = tokensMode


## `c`: the chart in place of the table, and back. The rows of the views are drawn from their tokens at every turn, so none is read again.
def tokensChartMode(state, row):
    ## ONE key cycles the three views of this pane: plain chart -> stacked chart -> table -> plain.
    if not TOKENS_CHART[0]:
        TOKENS_CHART[0] = True ; TOKENS_STACK[0] = False
    elif not TOKENS_STACK[0]:
        TOKENS_STACK[0] = True
    else:
        TOKENS_CHART[0] = False ; TOKENS_STACK[0] = False
    if not TOKENS_CHART[0]:
        return "Tokens: a table"
    return "Tokens: a chart, %s" % ("stacked by kind" if TOKENS_STACK[0] else "one total a column")


ACTION_HANDLERS["tokenschart"] = tokensChartMode


## `k`: both charts stacked by token kind, and back to one total a column.
def tokensStackMode(state, row):
    TOKENS_STACK[0] = not TOKENS_STACK[0]
    return "Tokens: %s" % ("stacked by kind" if TOKENS_STACK[0] else "one total a column")


ACTION_HANDLERS["tokensstack"] = tokensStackMode

registerPlugin({
    "name": "tokens",
    "mount": "dashboard",
    ## the views stand in the group of the tokens alone (tokensGroupHere): a row of the level of every group, shown in that one
    "rows": {
        "*": tuple((viewId, label, "tokens-view", True, "tokensGroupHere") for viewId, label, by in TOKEN_VIEWS),
    },
    "focus": dict(("*/" + viewId, "tokensFocus") for viewId, label, by in TOKEN_VIEWS),
    "summaries": dict(("*/" + viewId, {"lines": "tokensSummary", "view": viewId}) for viewId, label, by in TOKEN_VIEWS),
    "reads": dict(
        [("list:*/" + viewId, ({"operation": ["--manager-stats-tokens", "--by", by, "--share"], "rows": "tokens", "extra": "tokensWords"}
                              if viewId in TOKEN_PANELS else
                              {"operation": ["--manager-stats-tokens", "--by", by, "--share"], "rows": "tokens", "once": True, "extra": "tokensWords",
                               "also": () if viewId == "day" else ("list:*/trend",)}))
         for viewId, label, by in TOKEN_VIEWS]
        + [("list:*/trend", {"operation": ["--manager-stats-tokens", "--by", "day"], "rows": "tokens", "once": True})]
    ),
    "commands": (
        {"name": "tokensmode", "keys": ("s",), "menu": ("view", 3), "label": "~S~um or average", "status": "Sum/Avg",
         "views": tuple("*/" + viewId for viewId, label, by in TOKEN_VIEWS), "does": ("action", "tokensmode")},
        {"name": "tokenschart", "keys": ("v",), "menu": ("view", 3), "label": "~V~iew: chart, stacked, table", "status": "View",
         "views": tuple("*/" + viewId for viewId, label, by in TOKEN_VIEWS), "does": ("action", "tokenschart")},
        {"name": "tokensstack", "keys": ("k",), "menu": ("view", 4), "label": "~K~inds or total", "status": "Kinds",
         "views": tuple("*/" + viewId for viewId, label, by in TOKEN_VIEWS), "does": ("action", "tokensstack")},
    ),
})
