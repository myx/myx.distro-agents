##
## AgentsManagerScreen.Presets.py -- `Presets` and `Tiers` of the root Settings (F10.1, F10.2, F11.7): the presets of this workspace as a list, each with what it extends and what it comes to;
## a preset made, extended, edited and deleted; and the tiers of the team and of every member, each chosen from the presets.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##
## A preset is a scope of the agents, `preset-<name>`, and a tier is a variable of the team's scope or of a member's, so the variables of both are the variables of Scope Settings (Scopes.py): the
## same forms edit them. What the operations print of such a variable now says its KIND (--manager-scope-read: choice, number, text, or locked, with why), so a CLI service, an effort, a lifetime
## of the input cache and a tier are chosen from their lists, a context size is a number, the CLI service of a preset that extends is locked, and a parameter the preset does not hold yet is offered
## as a variable that holds nothing. The screen writes no file: --manager-scope-set, --manager-preset-new and --manager-scope-delete do, by the setting reader of the dispatcher.
##

## The fields of a `preset` row of `--manager-preset-list` after the six of a scope's, and of a `tier` row.
PRESET_FIELDS = ("extends", "service", "model", "effort", "used")
TIER_FIELDS = ("low", "normal", "high")
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
        row["tail"] = absent(tiers["normal"]) or "-"
        rows.append(row)
    return {level: rows}


ROW_FORMS["presets"] = parsePresetRows
ROW_FORMS["tiers"] = parseTierRows


## The presets as one table: the preset, what it extends, the CLI service it comes to, its model or macro, its effort and by whom it is used.
def presetsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    presets = [held["preset"] for held in rows if held.get("preset")]
    if not presets:
        return [looked("No preset is held in this workspace. n makes one.", BOLD)]
    return tableSummaryLines(state, ("PRESET", "EXTENDS", "CLI SERVICE", "MODEL", "EFFORT", "USED BY"),
                             [[one["name"], absent(one["extends"]) or "-", absent(one["service"]) or "-", absent(one["model"]) or "-", absent(one["effort"]) or "-",
                               unspaced(absent(one["used"])).replace("preset-", "") or "-"] for one in presets],
                             ("key", "key", "enum", "text", "enum", "text"))


def tiersSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    held = [(one["scope"]["label"], one["tiers"]) for one in rows if one.get("tiers")]
    if not held:
        return [looked("The operation listed no tier.", BOLD)]
    return tableSummaryLines(state, ("OWNER", "LOW", "NORMAL", "HIGH"), [[unspaced(label), absent(tiers["low"]) or "-", absent(tiers["normal"]) or "-", absent(tiers["high"]) or "-"] for label, tiers in held],
                             ("key", "text", "text", "text"))


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


## ---- the plugins ----

def scopeKeyCommands(view):
    return (
        {"name": view + "edit", "keys": ("ENTER",), "menu": ("view", 3), "label": "~E~dit the variable", "status": "Edit", "window": "list",
         "views": (view + "/*",), "for": "a variable", "on": (view + "/*:scope-key",), "only": True, "enters": True, "says": "edit", "does": ("action", "scopeedit"), "calls": ("scope-set",)},
        {"name": view + "unset", "keys": ("d",), "menu": ("view", 3), "label": "~D~elete the variable", "status": "Delete", "window": "list",
         "views": (view + "/*",), "for": "a variable", "on": (view + "/*:scope-key",), "only": True, "says": "delete", "does": ("action", "scopeunset"), "calls": ("scope-unset",)},
    )


registerPlugin({
    "name": "presets",
    "mount": "settings",
    "root": {"id": "presets", "label": "Presets"},
    "focus": {"presets/*": "scopeKeyFocus"},
    "summaries": {"presets": {"lines": "presetsSummary"}, "presets/*": {"lines": "scopeKeysSummary"}},
    "reads": {
        "list:presets": {"operation": ["--manager-preset-list"], "rows": "presets", "once": True},
        "list:presets/*": {"operation": ["--manager-scope-read", "{level}"], "rows": "scope-keys", "once": True},
    },
    "commands": scopeKeyCommands("presets") + (
        {"name": "presetnew", "keys": ("n",), "menu": ("view", 3), "label": "~N~ew preset", "status": "New", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset", "presets:up"), "only": True, "says": "new", "does": ("action", "presetnew"), "calls": ("preset-new",)},
        {"name": "presetclear", "keys": ("c",), "menu": ("view", 3), "label": "~C~lear the preset", "status": "Clear", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset",), "only": True, "says": "clear", "does": ("action", "scopeclear"), "calls": ("scope-clear",)},
        {"name": "presetdelete", "keys": ("D",), "menu": ("view", 3), "label": "~D~elete the preset", "status": "Delete", "window": "list",
         "views": ("presets",), "for": "a preset", "on": ("presets:preset",), "only": True, "says": "delete", "does": ("action", "scopedelete"), "calls": ("scope-delete",)},
    ),
})

registerPlugin({
    "name": "tiers",
    "mount": "settings",
    "root": {"id": "tiers", "label": "Tiers"},
    "focus": {"tiers/*": "scopeKeyFocus"},
    "summaries": {"tiers": {"lines": "tiersSummary"}, "tiers/*": {"lines": "scopeKeysSummary"}},
    "reads": {
        "list:tiers": {"operation": ["--manager-preset-tiers"], "rows": "tiers", "once": True},
        "list:tiers/*": {"operation": ["--manager-scope-read", "{level}"], "rows": "scope-keys", "once": True},
    },
    "commands": scopeKeyCommands("tiers"),
})
