##
## AgentsManagerScreen.Tokens.py -- the tokens views of the Dashboard (F11.4): under `Agents: Tokens`, `Tokens By Day`, `Tokens By Preset`, `Tokens By Credential`,
## `Tokens By Agent` and `Tokens By Routine`, each the tokens summed by one key, with a switch between their sum and their average per run.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##
## The screen renders what the Dispatcher gives and computes nothing but the average a switch asks for: `--manager-stats-tokens` is the Dispatcher's `--token-stats`
## (AgentsTools.ManagerStats.include), its rows `tokens <key> <runs> <in> <cache-read> <cache-write> <out>`.
##

## The id of the group of the Dashboard (the agents' `dashboard-panels.list`) these views stand in.
TOKEN_GROUP = "tokens"
## The views: the id of each, what it shows as, and the key of the Dispatcher's `--by` it is read by.
TOKEN_VIEWS = (("day", "Tokens By Day", "day"), ("preset", "Tokens By Preset", "preset"), ("credential", "Tokens By Credential", "credential"),
               ("agent", "Tokens By Agent", "member"), ("routine", "Tokens By Routine", "routine"))
## The fields of a `tokens` row after its first, and the columns they show as.
TOKEN_FIELDS = ("key", "runs", "in", "cacheRead", "cacheWrite", "out")
TOKEN_HEADS = ("RUNS", "IN", "CACHE READ", "CACHE WRITE", "OUT")
## Whether the views show the average per run in place of the sum: one switch for all of them, `s`.
TOKENS_AVERAGE = [False]


## Whether the level that is shown is the group of the tokens: the views stand in no other group of the Dashboard (a fixed row of the level asks).
def tokensGroupHere(state, path):
    return bool(path) and path[-1] == TOKEN_GROUP


## The numbers of one row as the views show them: how many runs, then the tokens, summed or, with the switch on, the average of a run (whole tokens).
def tokenCells(token):
    runs = int(token["runs"]) if token["runs"].isdigit() else 0
    values = [token[name] for name in ("in", "cacheRead", "cacheWrite", "out")]
    if TOKENS_AVERAGE[0]:
        values = [str(int(value) // runs) if runs and value.isdigit() else "0" for value in values]
    return [token["runs"]] + [shortCount(value) if value.isdigit() else value for value in values]


## What `--manager-stats-tokens` printed, as rows: a `tokens` row is a key, shown by it and with its runs after it; a row too short, and a line of another name, is left out.
def parseTokenRows(readKey, level, text):
    rows = []
    for line in text.split("\n"):
        fields = line.split("\t")
        if fields[0] != "tokens" or len(fields) <= len(TOKEN_FIELDS):
            continue
        token = dict(zip(TOKEN_FIELDS, fields[1:]))
        row = newRow(token["key"], token["key"], "record", False, fields)
        row["tokens"] = token
        row["tail"] = "%s run%s" % (token["runs"], "" if token["runs"] == "1" else "s")
        rows.append(row)
    return {level: rows}


ROW_FORMS["tokens"] = parseTokenRows


## The rows of a view as one table, with the total of them at its foot: the key, the runs, and the four kinds of tokens, summed or averaged by the switch.
def tokensSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    tokens = [held["tokens"] for held in rows if held.get("tokens")]
    label = next((view[1] for view in TOKEN_VIEWS if view[0] == form["view"]), form["view"])
    if not tokens:
        return [looked("%s: no run is recorded for it." % label, BOLD)]
    total = {"key": "all", "runs": str(sum(int(token["runs"]) for token in tokens if token["runs"].isdigit()))}
    for name in ("in", "cacheRead", "cacheWrite", "out"):
        total[name] = str(sum(int(token[name]) for token in tokens if token[name].isdigit()))
    lines = [looked("%s, %s" % (label, "the average of a run" if TOKENS_AVERAGE[0] else "summed over its runs"), BOLD)]
    lines.extend(tableSummaryLines(state, ("KEY",) + TOKEN_HEADS, [[token["key"]] + tokenCells(token) for token in tokens] + [["all"] + tokenCells(total)],
                                   ("key",) + ("enum",) * len(TOKEN_HEADS)))
    return lines


## ... of a row of a view: the same table, whichever row is selected.
def tokensFocus(state, row):
    view = next((held for held in TOKEN_VIEWS if levelPattern(state.path).endswith("/" + held[0])), None)
    return tokensSummary(state, state.path, row, {"view": view[0]}) if view else None


## `s`: the average per run in place of the sum, and back. The rows of the views are drawn from their tokens at every turn, so none is read again.
def tokensMode(state, row):
    TOKENS_AVERAGE[0] = not TOKENS_AVERAGE[0]
    state.view.pop("blocksFor", None)
    return "Tokens: %s" % ("the average of a run" if TOKENS_AVERAGE[0] else "summed over their runs")


ACTION_HANDLERS["tokensmode"] = tokensMode

registerPlugin({
    "name": "tokens",
    "mount": "dashboard",
    ## the views stand in the group of the tokens alone (tokensGroupHere): a row of the level of every group, shown in that one
    "rows": {
        "*": tuple((viewId, label, "tokens-view", True, "tokensGroupHere") for viewId, label, by in TOKEN_VIEWS),
    },
    "focus": dict(("*/" + viewId, "tokensFocus") for viewId, label, by in TOKEN_VIEWS),
    "summaries": dict(("*/" + viewId, {"lines": "tokensSummary", "view": viewId}) for viewId, label, by in TOKEN_VIEWS),
    "reads": dict(("list:*/" + viewId, {"operation": ["--manager-stats-tokens", "--by", by], "rows": "tokens", "once": True}) for viewId, label, by in TOKEN_VIEWS),
    "commands": (
        {"name": "tokensmode", "keys": ("s",), "menu": ("view", 3), "label": "~S~um or average", "status": "Sum/Avg",
         "views": tuple("*/" + viewId for viewId, label, by in TOKEN_VIEWS), "does": ("action", "tokensmode")},
    ),
})
