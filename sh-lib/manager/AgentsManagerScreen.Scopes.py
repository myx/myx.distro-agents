##
## AgentsManagerScreen.Scopes.py -- the folder `Scope Settings` of the root Settings: every scope of settings this workspace keeps, each a folder of its
## variables, to see, to edit and to take out (F11.7 of the refactorings epic).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##

## ---- the scopes: `Scope Settings` ----

## It is a plugin mounted on `Settings`, and its operations are `--manager-scope-*` (AgentsTools.ManagerScope.include): the screen draws what they print
## and takes the keys, and writes no file. A scope is a folder, named as its subsystem names it (`Agents: client-ndm`, `Remote: mdci01.ndm9.xyz`,
## `Common: user-myx`), and the variables of the scope are its rows. The left window shows a scope as a table of its variables and their values, and one
## variable as that table's one row. Enter edits a variable, `d` takes it out, with a confirmation; a scope is cleared of every variable (`c`) and, where
## its subsystem has many, deleted (`D`), each behind the word typed whole. A credential shows in its one form and is edited in the form of a credential,
## whose Reveal reads its value whole while the form is open (F11.8).

## The fields of a `scope` row of `--manager-scope-list` and `--manager-scope-read`, after its first, and those of a `key` row.
SCOPE_FIELDS = ("id", "label", "keys", "clear", "delete", "file")
SCOPE_KEY_FIELDS = ("name", "state", "value", "type", "description")
## The read that gives one value whole, for the form that edits it, and what the forms say meanwhile and where they cannot.
SCOPE_VALUE_READ = "full:scope-value"
SCOPE_SAYS = {
    "form": "Its value is shown in the form of a credential: its first quarter, then * for the rest. Reveal (Ctrl-R) shows it whole until this closes.",
    "reading": "its value is being read",
    "failed": "its value could not be read: %s",
    "wait": "nothing is saved yet: its value is still being read",
    "unset": "The variable is taken out of the file of its scope; the other variables stay. It is the setting reader of the scope that takes it out.",
    "clear": "Every variable of the scope is taken out of its file, one by one; the file and the other scopes stay.",
    "delete": "The scope is deleted: its file is removed, and every variable of it with it.",
}
## The dialogs: a variable edited, a credential edited, a variable taken out, a scope cleared, a scope deleted.
DIALOGS["scope-edit"] = {"title": "Edit", "feeds": "scopeedit", "first": "words", "reads": ("full:{kind}",),
                         "controls": ({"name": "about", "kind": "text"},
                                      {"name": "words", "kind": "input", "label": "Its value"}),
                         "buttons": (("ok", "OK"), ("cancel", "Cancel"))}
DIALOGS["scope-credential"] = {"title": "Edit", "feeds": "scopeedit", "first": "words", "reads": ("full:{kind}",),
                               "controls": ({"name": "about", "kind": "text"},
                                            {"name": "words", "kind": "input", "label": "Its value"}),
                               "buttons": (("ok", "OK"), ("reveal", "Reveal"), ("cancel", "Cancel"))}
DIALOGS["scope-unset"] = {"title": "Delete", "feeds": "scopeunset",
                          "controls": ({"name": "about", "kind": "text"},),
                          "buttons": (("ok", "Delete"), ("cancel", "Cancel"))}
DIALOGS["scope-clear"] = {"title": "Clear", "feeds": "scopeclear",
                          "controls": ({"name": "about", "kind": "text"},
                                       {"name": "word", "kind": "input", "label": "Type %s to clear" % KILL_WORD, "exactly": KILL_WORD,
                                        "required": "nothing is cleared: the word typed is not %s" % KILL_WORD}),
                          "buttons": (("ok", "Clear"), ("cancel", "Cancel"))}
DIALOGS["scope-delete"] = {"title": "Delete", "feeds": "scopedelete",
                           "controls": ({"name": "about", "kind": "text"},
                                        {"name": "word", "kind": "input", "label": "Type %s to delete" % KILL_WORD, "exactly": KILL_WORD,
                                         "required": "nothing is deleted: the word typed is not %s" % KILL_WORD}),
                           "buttons": (("ok", "Delete"), ("cancel", "Cancel"))}
READING_DIALOGS = READING_DIALOGS + ("scope-edit", "scope-credential")

CALLS["scope-set"] = ["--manager-scope-set", "{id}"]
CALLS["scope-unset"] = ["--manager-scope-unset", "{id}"]
CALLS["scope-clear"] = ["--manager-scope-clear", "{id}"]
CALLS["scope-delete"] = ["--manager-scope-delete", "{id}"]


## What `--manager-scope-list` printed, as rows, in the order they come: a scope a folder, by its label as its subsystem names it, with how many variables it
## holds at the end of its row. A line of another name, and one too short, is left out.
def parseScopeLevels(readKey, level, text):
    rows = []
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] != "scope" or len(fields) <= len(SCOPE_FIELDS):
            continue
        held = dict(zip(SCOPE_FIELDS, fields[1:]))
        row = newRow(held["id"], unspaced(held["label"]), "scope", True, fields)
        row["scope"] = held
        row["tail"] = held["keys"]
        rows.append(row)
    return {level: rows}


## What `--manager-scope-read <id>` printed, as rows: the variables of the scope in the order of its file, each by its name, one that holds nothing marked
## so at the end of its row. The scope is the row's too.
def parseScopeKeyLevels(readKey, level, text):
    rows = []
    scope = None
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "scope" and len(fields) > len(SCOPE_FIELDS):
            scope = dict(zip(SCOPE_FIELDS, fields[1:]))
        elif fields[0] == "key" and len(fields) > len(SCOPE_KEY_FIELDS) and scope is not None:
            held = dict(zip(SCOPE_KEY_FIELDS, fields[1:]), scope=scope["id"], scopeLabel=unspaced(scope["label"]))
            row = newRow(held["name"], held["name"], "scope-key", False, fields)
            row["scopeKey"] = held
            if held["state"] == "missing":
                row["tail"] = "empty"
                row["look"] = DIM
            rows.append(row)
    return {level: rows}


ROW_FORMS["scopes"] = parseScopeLevels
ROW_FORMS["scope-keys"] = parseScopeKeyLevels


## What a variable shows as in a table: its value as the operation printed it, a variable that holds nothing as that.
def scopeKeyValue(held):
    return "-" if held["state"] == "missing" else held["value"]


## The folder `Scope Settings` for the left pane: every scope as a table, its label, how many variables it holds and the file it is kept in. None until the
## read of the list has answered.
def scopesSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    held = [one["scope"] for one in rows if one.get("scope")]
    if not held:
        return [looked("The operation listed no scope.", BOLD)]
    place = placer(state)
    return tableSummaryLines(state, ("SCOPE", "KEYS", "FILE"), [[unspaced(one["label"]), one["keys"], place(absent(one["file"]) or "-")] for one in held],
                             ("key", "text", "text"))


## A scope selected, for the left pane: its variables and their values as a table of name and value, a credential in its one form, a variable that holds
## nothing in the colour of what is missing. None until the read of the scope has answered.
def scopeKeysSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    if not rows:
        return [looked("%s holds no variable." % row["label"], BOLD)]
    return tableSummaryLines(state, ("NAME", "VALUE"), [[one["scopeKey"]["name"], scopeKeyValue(one["scopeKey"])] for one in rows],
                             ("key", "text"), looks=[[None, LEVEL_WARN if one["scopeKey"]["state"] == "missing" else None] for one in rows])


## A variable selected, for the left pane: its name, its value and its type as a table, and, where the catalogue of the owner setup describes it, its
## description under the table.
def scopeKeyFocus(state, row):
    held = row.get("scopeKey")
    if held is None:
        return None
    table = {"kind": "table", "heads": ("NAME", "VALUE", "TYPE"), "rows": [[held["name"], scopeKeyValue(held), held["type"]]], "kinds": ("key", "text", "enum"),
             "looks": [[None, LEVEL_WARN if held["state"] == "missing" else None, None]]}
    described = unspaced(absent(held["description"]))
    return {"kind": "sequence", "blocks": [table, {"kind": "markdown", "text": described}]} if described else table


## ---- a variable edited ----

def scopeKeyFits(state, row):
    return bool(row and row.get("scopeKey"))


## Enter on a variable: its form. A variable's value is read whole for the form that edits it and put in its field when it has come, and until then
## the form saves nothing; a credential's form shows its one form and reads its value whole only where Reveal is pressed. What is saved is what stands in
## the field, on the standard input of the operation, never a word of its command; a field that holds what the variable held, or the credential's form, saves nothing.
def askScopeEdit(state, row):
    held = row.get("scopeKey") if row else None
    if held is None:
        return ""
    secret = held["state"] == "secret-set"
    state.answer = None
    state.plans.pop(SCOPE_VALUE_READ, None)
    about = {"key": held, "target": {"kind": "scope-value", "id": held["name"], "level": held["scope"]}, "whole": None,
             "masked": held["value"], "asked": False, "viewKey": viewKeyOf(state)}
    lines = [("scope", held["scopeLabel"]), ("variable", held["name"]), ("type", held["type"])]
    if unspaced(absent(held["description"])):
        lines.append(unspaced(held["description"]))
    if secret:
        lines.append(SCOPE_SAYS["form"])
    openDialog(state, "scope-credential" if secret else "scope-edit", {"about": {"lines": lines}, "words": {"value": held["value"] if secret else ""}},
               about, "Edit: %s" % held["name"])
    if not secret:
        state.forced.add(SCOPE_VALUE_READ)
        about["asked"] = True
    return ""


## The form as it stands now, at every turn while it is open: once the read it asked for has answered, the value whole stands in its field, or the
## form says why it could not be read.
def fillScopeEdit(state, dialog):
    about = dialog["about"]
    target = about["target"]
    plan = state.plans.get(SCOPE_VALUE_READ)
    if not about["asked"] or plan is None or plan["words"] != readWords(READS[SCOPE_VALUE_READ], state, {"id": target["id"], "level": target["level"]}, False):
        return
    state.plans.pop(SCOPE_VALUE_READ, None)
    about["asked"] = False
    if plan["error"]:
        dialog["says"] = SCOPE_SAYS["failed"] % plan["error"]
        return
    about["whole"] = plan["rows"]
    dialogControl(dialog, "words")["value"] = plan["rows"]
    dialog["says"] = ""


## Reveal, which Ctrl-R presses: the value is read whole, once, and shown in the field by fillScopeEdit.
def revealScopeValue(state, dialog):
    about = dialog["about"]
    state.plans.pop(SCOPE_VALUE_READ, None)
    state.forced.add(SCOPE_VALUE_READ)
    about["asked"] = True
    return SCOPE_SAYS["reading"]


## OK, or Reveal, in the form of a variable or of a credential. The field is saved where it holds something else than what the variable held (the
## value read whole, or the credential's one form), through the operation, on its standard input.
def submitScopeEdit(state, dialog, button):
    about = dialog["about"]
    if button == "reveal":
        return revealScopeValue(state, dialog)
    held = about["key"]
    value = dialogValue(dialog, "words")
    if dialog["name"] == "scope-edit" and about["whole"] is None:
        return SCOPE_SAYS["wait"]
    if value in (about["masked"], about["whole"]) or "\n" in value:
        return None
    askCall(state, "scope", "%s/%s" % (held["scope"], held["name"]), callWords("scope-set", held["scope"]) + [held["name"]], value,
            {"viewKey": about["viewKey"], "says": "saved %s in %s" % (held["name"], held["scopeLabel"])})
    state.notice = "save asked of the tooling: %s" % held["name"]
    state.noticeOf = None
    return None


ACTION_HANDLERS["scopeedit"] = askScopeEdit
ACTION_FITS["scopeedit"] = scopeKeyFits
ACTION_REFUSALS["scopeedit"] = lambda state, row: "that is no variable of a scope"
DIALOG_HANDLERS["scope-edit"] = submitScopeEdit
DIALOG_HANDLERS["scope-credential"] = submitScopeEdit
DIALOG_FILLS["scope-edit"] = fillScopeEdit
DIALOG_FILLS["scope-credential"] = fillScopeEdit
DIALOG_KEYS["scope-credential"] = ("CTRL-r", "Reveal", lambda state, dialog: pressButton(state, "reveal"))
PLAN_FORMS["scope-value"] = lambda text: text.rstrip("\n")


## ---- a variable taken out, a scope cleared, a scope deleted ----

def scopeFits(state, row):
    return bool(row and row.get("scope"))


def scopeClearFits(state, row):
    return scopeFits(state, row) and row["scope"]["clear"] == "yes"


def scopeDeleteFits(state, row):
    return scopeFits(state, row) and row["scope"]["delete"] == "yes"


## `d` on a variable: asked first, in a box that names it and its scope. OK takes it out, through the operation, with the scope and the name as its words.
def askScopeUnset(state, row):
    held = row.get("scopeKey") if row else None
    if held is None:
        return ""
    state.answer = None
    openDialog(state, "scope-unset", {"about": {"lines": [("scope", held["scopeLabel"]), ("variable", held["name"]), SCOPE_SAYS["unset"]]}},
               {"scope": held["scope"], "name": held["name"], "label": held["scopeLabel"], "viewKey": viewKeyOf(state)}, "Delete: %s" % held["name"])
    return ""


def submitScopeUnset(state, dialog, button):
    about = dialog["about"]
    askCall(state, "scope", "%s/%s" % (about["scope"], about["name"]), callWords("scope-unset", about["scope"]) + [about["name"]], None,
            {"viewKey": about["viewKey"], "says": "removed %s from %s" % (about["name"], about["label"])})
    state.notice = "removal asked of the tooling: %s" % about["name"]
    state.noticeOf = None
    return None


## `c` and `D` on a scope: asked first, by the word typed whole, as a kill is. OK clears the scope of every variable, or deletes it, through the operation.
def askScopeWhole(state, row, what):
    held = row.get("scope") if row else None
    if held is None:
        return ""
    state.answer = None
    openDialog(state, "scope-" + what, {"about": {"lines": [("scope", unspaced(held["label"])), ("variables", held["keys"]), SCOPE_SAYS[what]]}},
               {"scope": held["id"], "label": unspaced(held["label"]), "what": what, "viewKey": viewKeyOf(state)},
               "%s: %s" % (what.capitalize(), unspaced(held["label"])))
    return ""


def submitScopeWhole(state, dialog, button):
    about = dialog["about"]
    askCall(state, "scope", about["scope"], callWords("scope-" + about["what"], about["scope"]), None,
            {"viewKey": about["viewKey"], "says": "%s %s" % ("cleared" if about["what"] == "clear" else "deleted", about["label"])})
    state.notice = "%s asked of the tooling: %s" % (about["what"], about["label"])
    state.noticeOf = None
    return None


ACTION_HANDLERS["scopeunset"] = askScopeUnset
ACTION_FITS["scopeunset"] = scopeKeyFits
ACTION_REFUSALS["scopeunset"] = lambda state, row: "that is no variable of a scope"
ACTION_HANDLERS["scopeclear"] = lambda state, row: askScopeWhole(state, row, "clear")
ACTION_FITS["scopeclear"] = scopeClearFits
ACTION_REFUSALS["scopeclear"] = lambda state, row: "it holds no variable to take out" if scopeFits(state, row) else "that is no scope"
ACTION_HANDLERS["scopedelete"] = lambda state, row: askScopeWhole(state, row, "delete")
ACTION_FITS["scopedelete"] = scopeDeleteFits
ACTION_REFUSALS["scopedelete"] = lambda state, row: ("it is the workspace's own or the user's own, one of each: it is cleared, never deleted" if scopeFits(state, row)
                                                       else "that is no scope")
DIALOG_HANDLERS["scope-unset"] = submitScopeUnset
DIALOG_HANDLERS["scope-clear"] = submitScopeWhole
DIALOG_HANDLERS["scope-delete"] = submitScopeWhole


## What an operation of a scope answered, for the left pane and the status line: its row, `saved`, `removed`, `cleared` or `deleted`, set out.
def scopeAnswer(text, about, width):
    for printed in text.splitlines():
        fields = printed.split("\t")
        if fields[0] in ("saved", "removed", "cleared", "deleted") and len(fields) >= 2:
            return "the change", fieldLines([(fields[0], " ".join(fields[1:]))], width), about.get("says", fields[0])
    return "the change", [line for line in text.splitlines() if line.strip()], "the operation printed no row of what it did"


ACTION_ANSWERS["scope"] = scopeAnswer


## ---- the plugin: `Scope Settings` ----

registerPlugin({
    "name": "scopes",
    "mount": "settings",
    "root": {"id": "scopes", "label": "Scope Settings"},
    "focus": {"scopes/*": "scopeKeyFocus"},
    "summaries": {
        "scopes": {"lines": "scopesSummary"},
        "scopes/*": {"lines": "scopeKeysSummary"},
    },
    "reads": {
        ## The scopes of the workspace, a row each. Read on entering and when it is asked for, and again when a change was made.
        "list:scopes": {"operation": ["--manager-scope-list"], "rows": "scopes", "once": True},
        ## One scope: its variables, a credential in its one form.
        "list:scopes/*": {"operation": ["--manager-scope-read", "{level}"], "rows": "scope-keys", "once": True},
        ## One value whole, read when a form asks for it by the scope and the name and never before.
        SCOPE_VALUE_READ: {"operation": ["--manager-scope-reveal", "{level}", "{id}"], "rows": "scope-value", "kind": "plan", "demand": True},
    },
    "commands": (
        {"name": "scopeedit", "keys": ("ENTER",), "menu": ("view", 3), "label": "~E~dit the variable", "status": "Edit", "window": "list",
         "views": ("scopes/*",), "for": "a variable", "on": ("scopes/*:scope-key",), "only": True, "enters": True, "says": "edit",
         "does": ("action", "scopeedit"), "calls": ("scope-set",)},
        {"name": "scopeunset", "keys": ("d",), "menu": ("view", 3), "label": "~D~elete the variable", "status": "Delete", "window": "list",
         "views": ("scopes/*",), "for": "a variable", "on": ("scopes/*:scope-key",), "only": True, "says": "delete",
         "does": ("action", "scopeunset"), "calls": ("scope-unset",)},
        {"name": "scopeclear", "keys": ("c",), "menu": ("view", 3), "label": "~C~lear the scope", "status": "Clear", "window": "list",
         "views": ("scopes",), "for": "a scope", "on": ("scopes:scope",), "only": True, "says": "clear",
         "does": ("action", "scopeclear"), "calls": ("scope-clear",)},
        {"name": "scopedelete", "keys": ("D",), "menu": ("view", 3), "label": "~D~elete the scope", "status": "Delete", "window": "list",
         "views": ("scopes",), "for": "a scope", "on": ("scopes:scope",), "only": True, "says": "delete",
         "does": ("action", "scopedelete"), "calls": ("scope-delete",)},
    ),
})
