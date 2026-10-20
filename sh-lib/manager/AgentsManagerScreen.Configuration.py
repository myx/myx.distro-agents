##
## AgentsManagerScreen.Configuration.py -- the folders of the root Configuration: the Config Checker, the Server Keys and the Tooling Commands.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the checks of the installation: `Config Checker` ----

## The fields of a `check` row of `--manager-check-run`, after its first, and those of its
## last row, `summary`. The reason has `_` for a blank; the remedy is a command, printed
## with its blanks, and is shown as it is; an absent one is `-`.
CHECK_FIELDS = ("domain", "section", "key", "label", "state", "reason", "remedy")
CHECK_SUMMARY = ("checks", "ok", "warn", "fail", "skipped", "seconds")
## The look of the row of a check, by its state as the operation prints it, which stands
## at the end of the row. A state that is not listed here is drawn plain.
CHECK_LOOKS = {"ok": PLAIN, "warn": BOLD, "fail": BOLD, "skipped": DIM}
## What the folder says of the checks under their counts.
CHECKS_SAY = ("It is the read-only diagnosis of each part of the installation: it changes nothing, "
              "it takes up to a minute, and some of it asks outside this machine.")


## What `--manager-check-run` printed, as rows, in the order they come: a check by its
## label, its state at the end of its row. Each keeps the counts of the row `summary`.
def parseCheckRows(text):
    rows = []
    summary = {}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "check" and len(fields) > len(CHECK_FIELDS):
            check = dict(zip(CHECK_FIELDS, fields[1:]))
            row = newRow(" ".join(fields[1:4]), unspaced(check["label"]) or absent(check["key"]) or check["domain"], "record")
            row["check"] = check
            row["tail"] = check["state"]
            row["look"] = CHECK_LOOKS.get(check["state"], PLAIN)
            rows.append(row)
        elif fields[0] == "summary" and len(fields) > len(CHECK_SUMMARY):
            summary.update(zip(CHECK_SUMMARY, fields[1:]))
    for row in rows:
        row["checked"] = summary
    return rows


## The selected check for the left pane: its state first, then why, in the words of the
## check, then the command that mends it, as it is printed, and where the check is from.
## The screen runs no remedy.
def checkLines(check, width):
    lines = factLines([("state", check["state"], stateLook(check["state"]))], width)
    reason = unspaced(check["reason"]).strip()
    if reason:
        lines.append("")
        lines.extend(wrapToCells(reason, max(10, width - 1)))
    lines.append("")
    lines.extend(factLines([("remedy", absent(check["remedy"])), ("domain", check["domain"]),
                             ("section", absent(check["section"])), ("key", absent(check["key"]))], width))
    if absent(check["remedy"]):
        lines.extend(["", "The remedy is a command for a console: the screen runs none."])
    return lines


## What `Config Checker` holds, for the left pane while its row or the row that goes up
## inside it is selected: as its caption that the checks were not run yet, or how many
## there are by their states, how long the run took and when it answered; while they run,
## that they do, and before a first run the key that runs them, dim. Then every check of the
## last run as a table (tableSummaryLines), the worst first: its label, its state in its
## colour, its domain and why. The focus alone never runs them (READS, "demand").
def checksSummary(state, path, row, form):
    shown = listReadOf(path)
    rows = state.rows.get(levelKey(path))
    if bool(shown) and shown[0] in state.reading.values():
        return [looked("They are running now.", LEVEL_WARN)]
    if rows is None:
        return [looked("The checks were not run yet in this run of the screen.", BOLD), looked("%s runs them. %s" % (commandKeys(commandNamed("check"))[0], CHECKS_SAY), DIM)]
    if not rows:
        return [looked("The last run gave no check.", BOLD)]
    ordered = sorted(rows, key=lambda held: -STATE_RANKS.index(stateLook(held["check"]["state"])) if stateLook(held["check"]["state"]) in STATE_RANKS else 0)
    return tableSummaryLines(state, ("CHECK", "STATE", "DOMAIN", "REASON"), [
        [held["label"], held["check"]["state"], held["check"]["domain"] or "-", unspaced(held["check"]["reason"]).strip() or "-"] for held in ordered],
        ("key", "enum", "enum", "text"), looks=[[None, stateLook(held["check"]["state"]), None, None] for held in ordered])


## ---- the public keys of this server: `Server Keys` ----

## The fields of a `key` row of `--manager-keys-list`, after its first; a row that has one
## more ends with the whole public line of the key, as it is pasted, `_` for a blank. A
## public key is shown whole wherever the screen shows one, and its <short> is never
## shown: only a secret is ever hidden or shortened. And the fields of a `group` row,
## which stands ahead of the keys of its group: how many keys, its label, and a note,
## why none of its keys can be read, or `-`. The groups stand in the order of the
## operation, and the screen knows none by its name. And the state of a key whose public
## file can be read.
KEY_FIELDS = ("key", "label", "group", "purpose", "type", "fingerprint", "short", "file", "state")
GROUP_FIELDS = ("group", "keys", "label", "note")
KEY_PRESENT = "present"
## What the view and the box of a key say of its whole line.
KEY_SAYS = {
    "reading": "Its public line is being read.",
    "failed": "Its public line could not be read:",
    "none": "The operation printed no line to paste for it.",
    "line": "Its public line, whole, as it is pasted:",
    "copy": "The whole line, to copy as one line: where it is broken here it goes on with nothing between.",
    "register": "It is to be registered on each of these repositories:",
}


## What a group shows as where no row of the operation names it: its word, the dashes as
## blanks, capitalised.
def keyGroupLabel(group):
    return group.replace("-", " ").capitalize()


## What `--manager-keys-list` printed, as rows: group after group in the order the
## operation gives them, by its `group` rows, and a group that only a key names where it
## first stands. A group is a row of its own, by its label, and under it stand its keys, a
## key by its label; one whose public file cannot be read has its state at the end of its
## row, and one that can is read whole by its name (READS, "each").
def parseKeyRows(text):
    groups = []
    byGroup = {}

    def groupOf(name):
        if name not in byGroup:
            byGroup[name] = {"key": name, "label": "", "note": "", "keys": []}
            groups.append(byGroup[name])
        return byGroup[name]

    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "group" and len(fields) >= len(GROUP_FIELDS):
            named = dict(zip(GROUP_FIELDS, fields[1:]))
            groupOf(named["group"]).update(label=unspaced(named["label"]), note=unspaced(named.get("note", "-")).strip())
        elif fields[0] == "key" and len(fields) > len(KEY_FIELDS):
            held = dict(zip(KEY_FIELDS, fields[1:]))
            held["line"] = unspaced(fields[len(KEY_FIELDS) + 1]) if len(fields) > len(KEY_FIELDS) + 1 else ""
            groupOf(held["group"])["keys"].append(held)
    grouped = []
    for group in groups:
        group["label"] = group["label"] or keyGroupLabel(group["key"])
        head = newRow("group " + group["key"], group["label"], "group")
        head["keyGroup"] = group
        members = []
        for held in group["keys"]:
            held["groupLabel"] = group["label"]
            row = newRow(held["key"], unspaced(held["label"]) or held["key"], "record")
            row["serverKey"] = held
            if held["state"] == KEY_PRESENT:
                row["readable"] = True
            else:
                row["tail"] = held["state"]
                row["look"] = DIM
            members.append(row)
        grouped.append((head, members))
    return groupedRows(grouped)


## What `--manager-keys-read <key>` printed: the line to paste, with its blanks as they
## are printed, and the repositories the key is to be registered on, each a project and
## its address.
def parseKeyRead(text):
    read = {"paste": "", "registers": []}
    for printed in text.split("\n"):
        name, tab, rest = printed.partition("\t")
        if name == "paste":
            read["paste"] = rest
        elif name == "register" and rest:
            read["registers"].append(tuple((rest.split("\t") + [""])[:2]))
    return read


## The whole public line of a key, where it is to be registered, and what stands for the
## line while there is none: the line as the read of that one key gives it, with its
## blanks as they are, once that has come, and until then from its row of the list where
## that carries it; the read also gives where the key is registered.
def keyWholeOf(state, path, held):
    plan = state.plans.get("each:%s|%s" % (levelPattern(path), held["key"]))
    read = plan["rows"] if plan and not plan["error"] else None
    line = (read["paste"] if read else "") or held.get("line", "")
    if line:
        note = ""
    elif plan is None:
        note = KEY_SAYS["reading"]
    elif plan["error"]:
        note = "%s %s" % (KEY_SAYS["failed"], plan["error"])
    else:
        note = KEY_SAYS["none"]
    return line, (read["registers"] if read else []), note


## A text whole in lines of the pane, set in by that much: broken between its words, a
## word longer than a line where the line ends, and what goes on stands further in under
## the first line. Nothing of it is cut.
def wholeLines(text, width, indent):
    parts = wrapToCells(text, max(10, width - len(indent) - 5))
    return [indent + parts[0]] + [indent + "    " + part for part in parts[1:]]


## Groups of keys for the left pane as one table (paneTable), each group under its label,
## its note first, dim, where its row gives one: every key by its label, its type, and its
## whole public line, never cut, or why none can be read, its state in its colour.
def keyGroupLines(state, path, groups):
    rows = []
    looks = []
    for group in groups:
        rows.append(group["label"])
        looks.append(None)
        if group["note"] or not group["keys"]:
            rows.append(["-", "-", group["note"] or "no key"])
            looks.append([None, None, DIM])
        for held in group["keys"]:
            if held["state"] != KEY_PRESENT:
                line, look = "%s: %s" % (held["state"], absent(held["file"])), stateLook(held["state"]) or LEVEL_WARN
            else:
                line, registers, note = keyWholeOf(state, path, held)
                line, look = line or note, None
            rows.append([unspaced(held["label"]) or held["key"], absent(held["type"]) or "-", line])
            looks.append([None, None, look])
    ## the line of a key has its room first: the label gives way before it
    return tableSummaryLines(state, ("KEY", "TYPE", "PUBLIC LINE"), rows, ("text", "enum", "whole"), looks=looks)


## The selected key for the left pane: what it is for; its type, its fingerprint, its
## public file, its group, its name and its state; its whole public line, as it is
## pasted; where it is to be registered; and the key that shows it alone in a box. One
## whose public file cannot be read says so in place of a line.
def serverKeyLines(state, path, held, width):
    lines = []
    purpose = unspaced(held["purpose"]).strip()
    if purpose:
        lines.extend(wrapToCells(purpose, max(10, width - 1)) + [""])
    lines.extend(factLines([("type", absent(held["type"])), ("fingerprint", absent(held["fingerprint"])),
                            ("file", absent(held["file"])), ("group", held["groupLabel"]),
                            ("key", held["key"]), ("state", held["state"], stateLook(held["state"]) or LEVEL_WARN)], width))
    if held["state"] != KEY_PRESENT:
        return lines + ["", "No public key can be read at its file."]
    line, registers, note = keyWholeOf(state, path, held)
    lines.extend(headingLines(KEY_SAYS["line"]) + wholeLines(line or note, width, "  "))
    if registers:
        lines.extend(headingLines(KEY_SAYS["register"]))
        for register in registers:
            lines.extend(wholeLines("%s  %s" % register, width, "  "))
    return lines


## What `Server Keys` holds, for the left pane while its row or the row that goes up
## inside it is selected: its groups in the order of the operation, each key with its
## fingerprint and its whole public line. None until its read has answered.
def serverKeysSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    groups = [held["keyGroup"] for held in rows if held.get("keyGroup")]
    if not groups:
        return ["The operation listed no key of this server."]
    return keyGroupLines(state, path, groups)


## Whether the whole line of that row can be shown: a key whose public file can be read.
def keyLineFits(state, row):
    return bool(row and row.get("serverKey")) and row["serverKey"]["state"] == KEY_PRESENT


## The whole public line of the selected key alone, in a box to copy: it is read anew
## for the box, by the name of the key, and the box says so until it has come (fillKeyLine).
def askKeyLine(state, row):
    if not keyLineFits(state, row):
        return ""
    held = row["serverKey"]
    target = {"kind": "key", "id": held["key"]}
    state.plans.pop("full:" + target["kind"], None)
    state.forced.add("full:" + target["kind"])
    fillKeyLine(state, openDialog(state, "keyline", None, {"target": target, "serverKey": held},
                                  unspaced(held["label"]) or held["key"]))
    return ""


## The box of a key as it stands now, at every turn while it is open: that its line is
## being read, that it could not be, or the line whole, set out so that it is broken only
## where the box is full, and under it where the key is to be registered.
def fillKeyLine(state, dialog):
    held = dialog["about"]["serverKey"]
    target = dialog["about"]["target"]
    key = "full:" + target["kind"]
    plan = state.plans.get(key)
    if plan is None or plan["words"] != readWords(READS[key], state, {"id": target["id"]}, False):
        lines = [KEY_SAYS["reading"]]
    elif plan["error"]:
        lines = [KEY_SAYS["failed"], plan["error"]]
    elif not plan["rows"]["paste"]:
        lines = [KEY_SAYS["none"]]
    else:
        lines = [("group", held["groupLabel"]), ("type", absent(held["type"])),
                 "fingerprint " + held["fingerprint"], KEY_SAYS["copy"], " " + plan["rows"]["paste"]]
        if plan["rows"]["registers"]:
            lines.append(KEY_SAYS["register"])
            lines.extend(" %s  %s" % register for register in plan["rows"]["registers"])
    dialogControl(dialog, "text")["lines"] = lines


ACTION_HANDLERS["line"] = askKeyLine
ACTION_FITS["line"] = keyLineFits
ACTION_REFUSALS["line"] = lambda state, row: "no public key can be read there"
DIALOG_FILLS["keyline"] = fillKeyLine


## ---- the commands a console user calls by name: `Tooling Commands` ----

## The folder of a project that holds its tooling commands.
COMMAND_FOLDER = "sh-scripts"


## What `--manager-command-list` printed, as rows, in the order they come: a command a
## line, by its name as it is typed, and after a TAB the file it resolves to, `-` for none.
## Each is an entry of the help: what the left pane shows of it is its help (MARKDOWN_HELP).
def parseCommandRows(text):
    rows = []
    for line in text.split("\n"):
        name, tab, path = line.partition("\t")
        if name.strip():
            rows.append(newRow(name, name, "help-entry"))
            rows[-1]["path"] = path.strip() or "-"
    return rows


## Where a project lies, from its folder: as `<workspace>:<project path>` where it lies in the
## folder of the projects of a workspace the locations know, the longest winning (the owner:
## "Just a workspace:project_path"); else that folder by the rule of the locations where the
## view takes it, or as it is; `-` for none.
def projectPlace(state, folder, placing):
    if folder == "-":
        return folder
    found = None
    for held in state.rows.get(pluginLevel("places")) or ():
        place = held.get("place")
        under = pathUnder(folder, place["path"].rstrip("/") + "/" + PLACES["projects"]) if place and place["kind"] == PLACES["workspace"] else None
        if under and under != "." and (found is None or len(place["path"]) > len(found[0]["path"])):
            found = (place, under)
    if found:
        return "%s:%s" % (found[0]["key"], found[1])
    return placedLine(state, folder)[0] if placing else folder


## Where a tooling command is located, from the file it resolves to: the project whose
## COMMAND_FOLDER holds it (projectPlace); `-` where it resolves to none.
def commandPlace(state, file, placing):
    if file == "-":
        return file
    folder = file.rpartition("/")[0]
    if folder.endswith("/" + COMMAND_FOLDER):
        folder = folder[:-len(COMMAND_FOLDER) - 1]
    return projectPlace(state, folder, placing)


## What `Tooling Commands` holds, for the left pane while its row or the row that goes up
## inside it is selected: how many as its caption, then every command as the operation
## names it, in its order, as a table (tableSummaryLines): its name and where it is located
## (commandPlace), set out before the table so it is broken to the pane as it shows. None
## until its read has answered.
def commandsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    if not rows:
        return [looked("The operation listed no command.", BOLD)]
    placing = placedShown(state)
    return tableSummaryLines(state, ("NAME", "PATH"), [[held["label"], commandPlace(state, held["path"], placing)] for held in rows],
                             ("key", "text"))


## What the left pane shows of a check, of a server key and of a group of them.
def checksFocus(state, row):
    return checkLines(row["check"], state.viewWidth) if row.get("check") else None


def keysFocus(state, row):
    if row.get("serverKey"):
        return serverKeyLines(state, state.path, row["serverKey"], state.viewWidth)
    if row.get("keyGroup"):
        return keyGroupLines(state, state.path, [row["keyGroup"]])
    return None


## ---- the plugin: `Configuration` ----

registerPlugin({
    "name": "configuration",
    "root": {"id": "configuration", "label": "Configuration", "go": "~C~onfiguration", "group": "setup"},
    ## The wizards that configure a feature (Wizards.py): each feature declares its own form and puts it here.
    "registries": {"wizards": "plain"},
    "rows": {
        "configuration": (("checker", "Config Checker", "checker", True), ("keys", "Server Keys", "keys", True)),
    },
    "focus": {"configuration/*": "settingsFocus", "configuration/checker": "checksFocus", "configuration/keys": "keysFocus"},
    "summaries": {
        "configuration": {"lines": "digestSummary"},
        "configuration/*": {"lines": "subjectSummary", "missingFirst": True},
        "configuration/checker": {"lines": "checksSummary"},
        "configuration/keys": {"lines": "serverKeysSummary"},
    },
    "reads": {
        ## The settings and the configuration come from the one read of the settings.
        "list:configuration": {"from": "list:@settings"},
        "list:configuration/*": {"from": "list:@settings"},
        ## The checks of the installation, by the owner's own read-only diagnosis of each part
        ## of it: a row a check, with its state, why, and the command that mends it. It takes
        ## up to a minute and some of it asks outside this machine, so it is made on demand
        ## alone, and as a kind of its own, beside the lists.
        "list:configuration/checker": {"operation": ["--manager-check-run"], "rows": "checks", "kind": "check", "demand": True,
                                       "said": "it takes up to a minute"},
        ## The public keys of this server, those to add to git and those to trust when
        ## connecting, each with its fingerprint and its key shortened. Read on entering and
        ## when it is asked for, not on the period.
        "list:configuration/keys": {"operation": ["--manager-keys-list"], "rows": "keys", "once": True},
        ## One of those keys whole: the line to paste, and where the deploy key is registered.
        ## Read when its box opens, by the name of the key, and never before (askKeyLine).
        "full:key": {"operation": ["--manager-keys-read", "{id}"], "rows": "key-read", "kind": "plan", "once": True},
        ## The same read for each key of the list whose public file can be read, by its name:
        ## once when the folder is opened and when it is asked for, never on the period. It
        ## gives the whole line of a key where its row of the list does not carry it, and
        ## where the key is to be registered.
        "each:configuration/keys": {"operation": ["--manager-keys-read", "{id}"], "rows": "key-read", "kind": "plan", "once": True, "needs": "readable"},
    },
    "commands": (
        {"name": "check", "keys": ("r",), "menu": ("view", 1), "label": "Run the ~c~hecks", "status": "Run",
         "views": ("configuration", "configuration/checker"), "for": "the checker", "does": ("demand",)},
        {"name": "keyline", "keys": ("f",), "menu": ("view", 3), "label": "~F~ull public line", "status": "Full",
         "views": ("configuration/keys",), "for": "a server key", "on": ("configuration/keys:record",), "does": ("action", "line")},
    ),
})
