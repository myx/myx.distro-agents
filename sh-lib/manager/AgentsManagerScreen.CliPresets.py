##
## AgentsManagerScreen.CliPresets.py -- `CLI Presets and Tiers` of the root Configuration (F10.1, F10.2): the feature that says which CLI service each member of the team starts on, as a use
## case and not as variables. It replaces the item of the CLI services there, and the wizard of the CLI service stands in it. The summary shows two compact tables, the presets (the services you
## set up) and the tiers that are assigned (which preset, and which effort, each member and the team use for their low, normal and high tier); the two folders under it, `CLI Service Presets`
## and `Member Tier Assignments`, show each more of its own when selected. The tasks are the keys: `n` adds a preset, `c` configures one (the wizard, which makes, extends, sets the model, the
## effort, the cache and the credentials), `u` uses a preset for a member, `a` assigns a tier (who, which tier, then the two selectors, the preset and the effort), `D` deletes a preset, `s` selects
## the CLI the machine has. Enter on a preset or an owner goes into its variables, where each is changed by its kind: that is Scope Settings' (LocalManagerScreen.Scopes.py of `.local`), which stays as it was.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the order of its PARTS, and it is never run by itself. The part is plain text of the screen.
## The screen writes no file: --manager-scope-set, --manager-preset-new, --manager-scope-delete and the wizard's --manager-wizard-apply do, by the setting reader of the dispatcher.
##

## The fields of a `preset` row of `--manager-preset-list` after the six of a scope's, and of a `tier` row.
PRESET_FIELDS = ("extends", "service", "model", "effort", "used")
TIER_FIELDS = ("low", "normal", "high")
## the order and the titles the screen shows the three tiers by (the keys they are stored in are unchanged)
TIER_KEYS = (("SPAWN_TIER_NORMAL", "normal", "Default / Normal"), ("SPAWN_TIER_HIGH", "high", "High / Heavy"), ("SPAWN_TIER_LOW", "low", "Low / Easy"))
CALLS["preset-new"] = ["--manager-preset-new"]


def parsePresetRows(readKey, level, text):
    rows = []
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] != "preset" or len(fields) < 1 + len(SCOPE_FIELDS) + len(PRESET_FIELDS):
            continue
        scope = dict(zip(SCOPE_FIELDS, fields[1:1 + len(SCOPE_FIELDS)]))
        preset = dict(zip(PRESET_FIELDS, fields[1 + len(SCOPE_FIELDS):]))
        name = unspaced(scope["label"]).replace("Agents: preset-", "", 1)
        row = newRow(scope["id"], name, "preset", True, fields)
        row["scope"] = scope
        row["preset"] = dict(preset, name=name)
        row["tail"] = ("extends " + preset["extends"]) if absent(preset["extends"]) else absent(preset["service"])
        rows.append(row)
    return {level: rows}


## What a tier of an owner resolves to, as the spawner chooses (AgentsToolsPresetChosen): its own setting; else, for a member, the team's of that tier; else the member's normal, else the team's
## normal. Returns (value, how): how is "set", "inherits the team's" or "uses the normal tier".
def tierResolved(owners, owner, tier):
    team = next((one for one in owners if one["scope"]["id"] == "agents:magic-team"), None)
    own = absent(owner["tiers"][tier])
    if own:
        return own, "set"
    if owner is not team and team is not None and absent(team["tiers"][tier]):
        return absent(team["tiers"][tier]), "inherits the team's"
    if tier != "normal" and absent(owner["tiers"]["normal"]):
        return absent(owner["tiers"]["normal"]), "uses its normal tier"
    if team is not None and absent(team["tiers"]["normal"]):
        return absent(team["tiers"]["normal"]), ("uses the team's normal tier" if owner is not team else "uses the normal tier, used for all tiers")
    return "", "nothing is set"


def tierSlotText(owners, owner, tier):
    value, how = tierResolved(owners, owner, tier)
    if how == "set":
        return value
    return "unset (%s: %s)" % (how, value) if value else "unset (nothing is set)"


def parseTierRows(readKey, level, text):
    rows = []
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] != "tier" or len(fields) < 1 + len(SCOPE_FIELDS) + len(TIER_FIELDS):
            continue
        scope = dict(zip(SCOPE_FIELDS, fields[1:1 + len(SCOPE_FIELDS)]))
        tiers = dict(zip(TIER_FIELDS, fields[1 + len(SCOPE_FIELDS):]))
        row = newRow(scope["id"], unspaced(scope["label"]), "tier", True, fields)
        row["scope"] = scope
        row["tiers"] = tiers
        rows.append(row)
    held = {level: rows}
    for row in rows:
        ## the rows of an owner are its three tiers alone, each with what it resolves to: nothing else of its scope belongs here
        row["tail"] = absent(row["tiers"]["normal"]) or ("inherits: " + (tierResolved(rows, row, "normal")[0] or "-"))
        slots = []
        for key, tier, label in TIER_KEYS:
            slot = newRow(tier, label, "tier-slot", False)
            slot["tierSlot"] = {"key": key, "tier": tier, "owner": row, "text": tierSlotText(rows, row, tier), "own": absent(row["tiers"][tier]), "value": tierResolved(rows, row, tier)[0]}
            slot["tail"] = tierSlotText(rows, row, tier)
            slots.append(slot)
        held[level + "/" + row["id"]] = slots
    return held


## What the operation of the presets printed, for the level of the feature itself: it holds the two folders, and their rows are those of their own levels.
def parseCliPresetsRows(readKey, level, text):
    held = {level: []}
    held.update(parsePresetRows(readKey, pluginLevel("presets"), text))
    return held


ROW_FORMS["presets"] = parsePresetRows
ROW_FORMS["tiers"] = parseTierRows
ROW_FORMS["clipresets"] = parseCliPresetsRows


## The assigned tiers: the owners that have any of the three set (the team always, since it is the default of every member that has none).
def tiersAssigned(rows):
    return [one for one in rows if one.get("tiers") and (any(absent(value) for value in one["tiers"].values()) or one["scope"]["id"] == "agents:magic-team")]


def compactTable(state, heads, cells, kinds, width):
    head, blocks = paneTable(heads, cells, max(10, width - 1), None, state.wrap, kinds, "  ")
    return head + [line for block in blocks for line in block]


def presetCells(presets):
    return [[one["name"], absent(one["service"]) or "-", absent(one["model"]) or "-", absent(one["effort"]) or "-", unspaced(absent(one["used"])).replace("preset-", "") or "-"] for one in presets]


def tierCells(owners):
    return [[unspaced(one["scope"]["label"]), absent(one["tiers"]["normal"]) or "-", absent(one["tiers"]["high"]) or "-", absent(one["tiers"]["low"]) or "-"] for one in owners]


## The feature as the left pane shows it: the presets and the assigned tiers, two compact tables one under the other.
def cliPresetsSummary(state, path, row, form):
    presets = state.rows.get(pluginLevel("presets"))
    tiers = state.rows.get(pluginLevel("tiers"))
    if presets is None or tiers is None:
        return None
    held = [one["preset"] for one in presets if one.get("preset")]
    assigned = tiersAssigned(tiers)
    lines = headingLines("CLI Service Presets")
    lines += compactTable(state, ("PRESET", "CLI SERVICE", "MODEL", "EFFORT", "USED BY"), presetCells(held), ("key", "enum", "text", "enum", "text"), state.viewWidth) if held else [looked("No preset is set up yet. n adds one.", BOLD)]
    lines += headingLines("Member Tier Assignments")
    lines += compactTable(state, ("MEMBER", "DEFAULT", "HIGH", "LOW"), tierCells(assigned), ("key", "text", "text", "text"), state.viewWidth) if assigned else [looked("No tier is assigned. a assigns one.", BOLD)]
    others = len([one for one in tiers if one.get("tiers")]) - len(assigned)
    if others > 0:
        lines.append("%d more member%s the defaults." % (others, " uses" if others == 1 else "s use"))
    return lines


## The presets as one table: the preset, what it extends, the CLI service it comes to, its model or macro, its effort and by whom it is used.
def presetsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    presets = [held["preset"] for held in rows if held.get("preset")]
    if not presets:
        return [looked("No preset is set up in this workspace. n adds one.", BOLD)]
    return tableSummaryLines(state, ("PRESET", "EXTENDS", "CLI SERVICE", "MODEL", "EFFORT", "USED BY"),
                             [[one["name"], absent(one["extends"]) or "-", absent(one["service"]) or "-", absent(one["model"]) or "-", absent(one["effort"]) or "-",
                               unspaced(absent(one["used"])).replace("preset-", "") or "-"] for one in presets],
                             ("key", "key", "enum", "text", "enum", "text"))


def tierSlotsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if not rows:
        return None
    return compactTable(state, ("TIER", "SET HERE", "IN EFFECT"), [[one["label"], one["tierSlot"]["own"] or "unset", one["tierSlot"]["value"] or "-"] for one in rows if one.get("tierSlot")],
                        ("key", "text", "text"), state.viewWidth)


def tierSlotFocus(state, row):
    slot = row.get("tierSlot")
    return None if slot is None else [looked(row["label"], BOLD)] + factLines([("set here", slot["own"] or "unset"), ("in effect", slot["value"] or "nothing is set"), ("enter", "opens the preset and the effort")], state.viewWidth)


def tiersSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    owners = [one for one in rows if one.get("tiers")]
    if not owners:
        return [looked("No tier is assigned. a assigns one.", BOLD)]
    return tableSummaryLines(state, ("MEMBER", "SET HERE (NORMAL)", "IN EFFECT (NORMAL)"),
                             [[unspaced(one["scope"]["label"]), absent(one["tiers"]["normal"]) or "unset", tierResolved(rows, one, "normal")[0] or "-"] for one in owners], ("key", "text", "text"))


## ---- a preset made ----

DIALOGS["preset-new"] = {"title": "New preset", "feeds": "presetnew", "first": "name",
                         "controls": ({"name": "about", "kind": "text"},
                                      {"name": "name", "kind": "input", "label": "Its name (lower case)"},
                                      {"name": "extends", "kind": "radios", "label": "It extends"},
                                      {"name": "service", "kind": "radios", "label": "Its CLI service, where it extends none"}),
                         "buttons": (("ok", "Make"), ("cancel", "Cancel"))}
PRESET_NONE = "-"


def askPresetNew(state, row):
    names = [held["preset"]["name"] for held in (state.rows.get(pluginLevel("presets")) or ()) if held.get("preset")]
    state.answer = None
    openDialog(state, "preset-new", {"about": {"lines": ["A preset extends another, and has that one's CLI service and what it does not set itself; or it extends none, and holds a CLI service of its own.",
                                                         "The rest of its parameters are set in its variables, once it is made."]},
                                     "name": {"value": ""},
                                     "extends": {"options": [(PRESET_NONE, "none: its own CLI service")] + [(name, name) for name in names], "value": PRESET_NONE},
                                     "service": {"options": [(service, service) for service in PRESET_SERVICES], "value": PRESET_SERVICES[0]}},
               {"viewKey": viewKeyOf(state)}, "New preset")
    return ""


PRESET_SERVICES = ("claude", "copilot", "grok", "gemini", "scaleway", "standard-v1", "claude-native", "copilot-native", "grok-native")


def submitPresetNew(state, dialog, button):
    name = dialogValue(dialog, "name").strip()
    extends = dialogValue(dialog, "extends")
    service = dialogValue(dialog, "service")
    if not name:
        return "the preset has no name yet"
    words = callWords("preset-new") + [name] + (["--extend", extends] if extends != PRESET_NONE else ["--cli-service", service])
    askCall(state, "scope", "preset-new/%s" % name, words, None, {"viewKey": dialog["about"]["viewKey"], "says": "made the preset %s" % name})
    state.notice = "the preset is asked of the tooling: %s" % name
    state.noticeOf = None
    return None


ACTION_HANDLERS["presetnew"] = askPresetNew
ACTION_FITS["presetnew"] = lambda state, row: True
ACTION_REFUSALS["presetnew"] = lambda state, row: ""
DIALOG_HANDLERS["preset-new"] = submitPresetNew


## ---- the tasks: use a preset for a member, assign a tier ----

DIALOGS["tier-who"] = {"title": "Assign a tier", "feeds": "tierwho", "first": "who",
                       "controls": ({"name": "about", "kind": "text"},
                                    {"name": "who", "kind": "radios", "label": "For"},
                                    {"name": "tier", "kind": "radios", "label": "Tier"}),
                       "buttons": (("ok", "Next"), ("cancel", "Cancel"))}


## Assign a tier, or use the preset selected for a member: who it is for and which of the three tiers come first; then the two selectors, the preset and the effort, which are those of the tier
## in Scope Settings, saved as one value, `<preset>[:<effort>]`, in the scope of the member by --manager-scope-set.
def askTierWho(state, row):
    owners = [one for one in state.rows.get(pluginLevel("tiers")) or () if one.get("tiers")]
    if not owners:
        return "The members are not listed yet."
    preset = row["preset"]["name"] if row and row.get("preset") else ""
    state.answer = None
    openDialog(state, "tier-who", {"about": {"lines": [("preset", preset)] + [] if preset else ["Which member, and which tier. The preset and the effort are chosen next."]},
                                   "who": {"options": [(one["scope"]["id"], unspaced(one["scope"]["label"])) for one in owners], "value": owners[0]["scope"]["id"]},
                                   "tier": {"options": [(key, label) for key, tier, label in TIER_KEYS], "value": "SPAWN_TIER_NORMAL"}},
               {"viewKey": viewKeyOf(state), "preset": preset}, "Assign a tier" if not preset else "Use %s for" % preset)
    return ""


def submitTierWho(state, dialog, button):
    owners = [one for one in state.rows.get(pluginLevel("tiers")) or () if one.get("tiers")]
    who, key = dialogValue(dialog, "who"), dialogValue(dialog, "tier")
    owner = next((one for one in owners if one["scope"]["id"] == who), None)
    if owner is None:
        return "nothing is asked: no one is chosen"
    tier = next((name for tierKey, name, label in TIER_KEYS if tierKey == key), "normal")
    now = absent(owner["tiers"][tier])
    preset = dialog["about"].get("preset") or ""
    if preset and now.partition(":")[0] != preset:
        now = preset
    names = [held["preset"]["name"] for held in state.rows.get(pluginLevel("presets")) or () if held.get("preset")]
    closeDialog(state)
    return askScopeDeclared(state, key, now, who, unspaced(owner["scope"]["label"]),
                            {"kind": "tier", "choices": [(name, name) for name in names], "efforts": ["low", "normal", "high"], "range": None})


ACTION_HANDLERS["tierassign"] = askTierWho
ACTION_FITS["tierassign"] = lambda state, row: True
ACTION_REFUSALS["tierassign"] = lambda state, row: ""
ACTION_HANDLERS["tieruse"] = askTierWho
ACTION_FITS["tieruse"] = lambda state, row: bool(row and row.get("preset"))
ACTION_REFUSALS["tieruse"] = lambda state, row: "select a preset first"
DIALOG_HANDLERS["tier-who"] = submitTierWho


## The tasks on the feature itself, the row of it selected in the Configuration or the folder of it opened: they are those of the presets and of the tiers, with no row of theirs selected.
def cliHere(state, row):
    level = levelKey(state.path)
    return level == pluginLevel("clipresets") or (level == pluginLevel("configuration") and bool(row) and row["id"] == "clipresets")


ACTION_HANDLERS["clinew"] = lambda state, row: askPresetNew(state, row)
ACTION_FITS["clinew"] = cliHere
ACTION_REFUSALS["clinew"] = lambda state, row: "it is a task of the CLI presets"
ACTION_HANDLERS["cliassign"] = lambda state, row: askTierWho(state, None)
ACTION_FITS["cliassign"] = cliHere
ACTION_REFUSALS["cliassign"] = lambda state, row: "it is a task of the CLI presets"
## Configure the preset selected: the wizard of the CLI service, on that preset.
def askTierSlot(state, row):
    slot = row.get("tierSlot") if row else None
    if slot is None:
        return ""
    owner = slot["owner"]
    names = [held["preset"]["name"] for held in state.rows.get(pluginLevel("presets")) or () if held.get("preset")]
    return askScopeDeclared(state, slot["key"], absent(owner["tiers"][slot["tier"]]), owner["scope"]["id"], unspaced(owner["scope"]["label"]),
                            {"kind": "tier", "choices": [(name, name) for name in names], "efforts": ["low", "normal", "high"], "range": None})


ACTION_HANDLERS["tierslot"] = askTierSlot
ACTION_FITS["tierslot"] = lambda state, row: bool(row and row.get("tierSlot"))
ACTION_REFUSALS["tierslot"] = lambda state, row: "select a tier"


def askCliConfigure(state, row):
    return startWizard(state, "cli-service", {"preset": row["preset"]["name"]} if row and row.get("preset") else None)


ACTION_HANDLERS["cliconfigure"] = askCliConfigure
ACTION_FITS["cliconfigure"] = lambda state, row: True
ACTION_REFUSALS["cliconfigure"] = lambda state, row: ""


## ---- the plugins ----

def scopeKeyCommands(view):
    return (
        {"name": view + "edit", "keys": ("ENTER",), "menu": ("view", 3), "label": "~E~dit the variable", "status": "Edit", "window": "list",
         "views": (view + "/*",), "for": "a variable", "on": (view + "/*:scope-key",), "only": True, "enters": True, "says": "edit", "does": ("action", "scopeedit"), "calls": ("scope-set",)},
        {"name": view + "unset", "keys": ("d",), "menu": ("view", 3), "label": "~D~elete the variable", "status": "Delete", "window": "list",
         "views": (view + "/*",), "for": "a variable", "on": (view + "/*:scope-key",), "only": True, "says": "delete", "does": ("action", "scopeunset"), "calls": ("scope-unset",)},
    )


registerPlugin({
    "name": "clipresets",
    "mount": "configuration",
    "root": {"id": "clipresets", "label": "CLI Presets and Tiers"},
    "summaries": {"clipresets": {"lines": "cliPresetsSummary"}},
    "reads": {
        ## The presets, and with them the tiers, for the summary: read as the other levels are, on entering it and when it is asked for.
        "list:clipresets": {"operation": ["--manager-preset-list"], "rows": "clipresets", "once": True, "also": ("list:@tiers",)},
    },
    "commands": (
        {"name": "clinew", "keys": ("n",), "menu": ("view", 3), "label": "~N~ew preset", "status": "New", "window": "list",
         "views": ("clipresets", "@configuration"), "for": "a preset", "on": ("clipresets:section", "@configuration:section"), "only": True, "says": "new", "does": ("action", "clinew"), "calls": ("preset-new",)},
        {"name": "cliassign", "keys": ("a",), "menu": ("view", 3), "label": "~A~ssign a tier", "status": "Assign", "window": "list",
         "views": ("clipresets", "@configuration"), "for": "a tier", "on": ("clipresets:section", "@configuration:section"), "only": True, "says": "assign", "does": ("action", "cliassign"), "calls": ("scope-set",)},
    ),
})

registerPlugin({
    "name": "presets",
    "mount": "clipresets",
    "root": {"id": "presets", "label": "CLI Service Presets"},
    "focus": {"presets/*": "scopeKeyFocus"},
    "summaries": {"presets": {"lines": "presetsSummary"}, "presets/*": {"lines": "scopeKeysSummary"}},
    "reads": {
        "list:presets": {"operation": ["--manager-preset-list"], "rows": "presets", "once": True, "also": ("list:@tiers",)},
        "list:presets/*": {"operation": ["--manager-scope-read", "{level}"], "rows": "scope-keys", "once": True},
    },
    "commands": scopeKeyCommands("presets") + (
        {"name": "presetnew", "keys": ("n",), "menu": ("view", 3), "label": "~N~ew preset", "status": "New", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset", "presets:up"), "only": True, "says": "new", "does": ("action", "presetnew"), "calls": ("preset-new",)},
        {"name": "presetconfigure", "keys": ("c",), "menu": ("view", 3), "label": "~C~onfigure the preset", "status": "Configure", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset",), "only": True, "says": "configure", "does": ("action", "cliconfigure")},
        {"name": "presetuse", "keys": ("f",), "menu": ("view", 3), "label": "Use the preset ~f~or a member", "status": "Use", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset",), "only": True, "says": "use", "does": ("action", "tieruse"), "calls": ("scope-set",)},
        {"name": "presetdelete", "keys": ("D",), "menu": ("view", 3), "label": "~D~elete the preset", "status": "Delete", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset",), "only": True, "says": "delete", "does": ("action", "scopedelete"), "calls": ("scope-delete",)},
    ),
})

registerPlugin({
    "name": "tiers",
    "mount": "clipresets",
    "root": {"id": "tiers", "label": "Member Tier Assignments"},
    "focus": {"tiers/*": "tierSlotFocus"},
    "summaries": {"tiers": {"lines": "tiersSummary"}, "tiers/*": {"lines": "tierSlotsSummary"}},
    "reads": {
        "list:tiers": {"operation": ["--manager-preset-tiers"], "rows": "tiers", "once": True, "also": ("list:@presets",)},
    },
    "commands": (
        {"name": "tierslot", "keys": ("ENTER", "a"), "menu": ("view", 3), "label": "~A~ssign the tier", "status": "Assign", "window": "list",
         "views": ("tiers/*",), "for": "a tier", "on": ("tiers/*:tier-slot",), "only": True, "enters": True, "says": "assign", "does": ("action", "tierslot"), "calls": ("scope-set",)},
        {"name": "tierassign", "keys": ("a",), "menu": ("view", 3), "label": "~A~ssign a tier", "status": "Assign", "window": "list",
         "views": ("tiers",), "for": "a tier", "on": ("tiers:tier", "tiers:up"), "only": True, "says": "assign", "does": ("action", "tierassign"), "calls": ("scope-set",)},
    ),
})
