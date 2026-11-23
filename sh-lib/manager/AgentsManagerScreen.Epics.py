##
## AgentsManagerScreen.Epics.py -- the root Epics: the epic items of the team's vault, the planning record of its process flow.
## A part of the manager screen (LocalManagerScreen.py of `myx.distro-.local`): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself.
##

## ---- the epic items of the vault: `Epics` ----

## The levels of the `epics` read: what `--epic-list` printed, a `<item name> <n> sections` line per epic item.
def epicsLevels(readKey, level, text):
    rows = []
    for line in text.splitlines():
        fields = line.split()
        if len(fields) != 3 or fields[2] != "sections" or not fields[1].isdigit():
            continue
        epicName = fields[0]
        row = newRow(epicName, epicName[:-3], "epic", False, fields)
        row["epic"] = {"name": epicName, "sections": fields[1]}
        rows.append(row)
    return {level: rows}


ROW_FORMS["epics"] = {"parse": epicsLevels}


## The table of Epics: each epic item by its name and how many sections it holds. Plainly where the vault holds none.
def epicsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    epicHeld = [held["epic"] for held in rows if held.get("epic")]
    if not epicHeld:
        return [looked("The vault holds no epic item.", BOLD)]
    return tableSummaryLines(state, ("EPIC", "SECTIONS"), [[epicOne["name"], epicOne["sections"]] for epicOne in epicHeld],
                             ("key", "enum"))


## ---- the plugin: `Epics` ----

registerPlugin({
    "name": "epics",
    "apps": ("agents",),
    "mount": "magic-team",
    "root": {"id": "epics", "label": "Epics", "go": "~E~pics", "group": "team",
             "when": {"shown": "teamDataHere", "says": "no team data is configured for this workspace"}},
    "summaries": {"epics": {"lines": "epicsSummary"}},
    "reads": {
        ## Every epic item of the vault, one read: `--epic-list` with no folder reads that store. Its kind is its own, so no other
        ## list holds this one's slot: one read of a kind runs at a time, and the session list's read runs long.
        "list:epics": {"operation": ["--epic-list"], "rows": "epics", "kind": "epics"},
        ## One epic, whole, read once it is selected.
        "view:epics:epic": {"operation": ["--epic-read", "{id}"], "once": True},
    },
    "integrates": {
        "markdown": {"on": ("epics:epic",)},
    },
})
