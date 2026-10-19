##
## AgentsManagerScreen.Settings.py -- the roots Settings and Configuration: the digest of the settings, one setting as a view of its own, to change one.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the settings and the configuration: `Settings`, `Configuration` ----

## The fields of a `line` row of `--manager-config-digest --full`, after its first, as the
## operation names them. "belongs", the last, is the root the line is of: the id of a
## section of SECTIONS, taken as it is printed. The screen knows no subject and no
## setting by its name: which root a line stands in, whether it is changed and how, is
## all in its row.
DIGEST_FIELDS = ("subject", "group", "key", "state", "value", "label", "description", "change", "kind",
                 "scope", "source", "values", "where", "belongs")
## What each subject of the digest holds, in words, for the head of its pane. A subject
## that is not listed here shows by its name alone.
SUBJECT_WORDS = {
    "workspace": "the paths of this workspace, and the places it knows",
    "cli": "the CLI service the workspace asks for, and each CLI the console knows",
    "systems": "each outside system, by the scopes that hold a setting of it",
    "loop": "the main loop and the heartbeat, as they last left their state",
    "scopes": "each scope that holds a key, with its keys",
    "interface": "how this console looks, saved for the user who runs it",
    "console": "how the consoles of this workspace behave",
    "control": "how long a console waits when it asks something of a session",
}
## What each <source> of a line shows as, after its value: where the value comes from.
## One that is not listed here shows as it is printed.
SOURCE_WORDS = {
    "environment": "named by the environment",
    "user": "saved for this user",
    "workspace": "saved for the workspace",
    "default": "the default",
}
## What each <scope> of a line shows as: whom a change of it is for. And what the dialog
## of a setting says OK does, by that scope: one saved for the workspace changes it for
## everybody, and the dialog says so. One that is not listed shows as it is printed.
SCOPE_WORDS = {
    "user": "this user, in this workspace",
    "workspace": "everybody who works in this workspace",
}
SCOPE_SAVES = {
    "user": "OK saves it for the user who runs this console",
    "workspace": "OK saves it for the WORKSPACE: it changes for everybody who works in it",
}
SCOPE_SAVES_OTHER = "OK saves it"
## The states of a line that say that something is not there, and those of a secret: of
## such a one only the state is ever shown.
STATES_MISSING = ("missing", "secret-missing")
STATES_SECRET = ("secret-set", "secret-missing")
## The word of <change> that says a line is changed from here; any other is `no`, with
## why not after a colon. And what stands for the reason where a row gives none.
CHANGE_YES = "yes"
CHANGE_SAYS = "it is not changed from here"
## The kinds of a setting that is changed from here, by the word of its row: the dialog
## of DIALOGS that changes one of that kind, the control of it that holds the value, and
## what the <values> of the row are: "choices", <value>=<label> with commas between, in
## the order to offer, or "range", <smallest>..<largest>. A kind that is not listed here
## is changed as a short text.
SETTING_KINDS = {
    "choice": {"dialog": "setting", "control": "choice", "values": "choices"},
    "number": {"dialog": "setting-number", "control": "number", "values": "range"},
}
SETTING_KIND_OTHER = {"dialog": "setting-text", "control": "words", "values": ""}
## The dialog of the setting of the style this screen is drawn in (STYLE_VARIABLE), whatever
## its kind: the styles of STYLES and the colours of COLOURS, each a group of radio buttons,
## saved as one value, `<style>-<colours>`, the colours by the style's own name of them.
STYLE_DIALOG = "setting-style"


## What `--manager-config-digest --full` printed, as levels. A `subject` row names a
## subject and its label; each `line` row after it is one line of that subject, by the
## fields of DIGEST_FIELDS, and its last field names the root it stands in. Each root
## this read fills (READS) holds the subjects that have a line there, in the order of the
## operation, each a row that is entered; and the level of a subject in a root holds its
## lines of that root, each by its label alone, or by its key where it has none. A line
## of another root than those, and one too short to say its root, is left out. Of a
## secret nothing but its state is kept: the value its row might carry is never held. At
## the end of its row a subject shows how many of its lines are missing.
def parseDigestLevels(readKey, text):
    levels = dict((sectionId, []) for sectionId, sectionLabel in SECTIONS
                  if (listReadOf([sectionId]) or ("",))[0] == readKey)
    labels = {}
    subjectFields = {}
    held = {}
    ## what each group of a subject shows as, from its `group` row, which stands ahead of
    ## its lines: `group <subject> <group> <lines> <label>`. A digest of before prints none
    groupLabels = {}
    for printed in text.splitlines():
        fields = printed.split("\t")
        if fields[0] == "group" and len(fields) >= 5:
            groupLabels[(fields[1], fields[2])] = unspaced(absent(fields[4]))
        elif fields[0] == "subject" and len(fields) >= 3:
            labels[fields[1]] = unspaced(fields[-1]) if len(fields) >= 4 else ""
            subjectFields[fields[1]] = fields
        elif fields[0] == "line" and len(fields) > len(DIGEST_FIELDS) and fields[1] in labels:
            setting = dict(zip(DIGEST_FIELDS, fields[1:]))
            root, name = setting["belongs"], setting["subject"]
            if root not in levels:
                continue
            if (root, name) not in held:
                row = newRow(name, labels[name] or name, "record", True, subjectFields[name])
                row["subject"] = {"name": name, "label": labels[name], "lines": []}
                held[(root, name)] = row
                levels[root].append(row)
                levels[root + "/" + name] = []
            line = {"subject": name, "group": absent(setting["group"]), "key": absent(setting["key"]),
                    "state": setting["state"],
                    "value": "" if setting["state"] in STATES_SECRET else absent(setting["value"]),
                    "label": unspaced(setting["label"]), "description": unspaced(setting["description"]).strip(),
                    "change": setting["change"], "kind": absent(setting["kind"]), "scope": absent(setting["scope"]),
                    "source": absent(setting["source"]), "where": absent(setting["where"]), "choices": [], "range": None}
            form = SETTING_KINDS.get(line["kind"], SETTING_KIND_OTHER)["values"]
            values = absent(setting["values"])
            if form == "choices":
                line["choices"] = [(choice.partition("=")[0], unspaced(choice.partition("=")[2]) or choice.partition("=")[0])
                                   for choice in values.split(",") if choice]
            elif form == "range":
                low, dots, high = values.partition("..")
                line["range"] = (low, high) if low.isdigit() and high.isdigit() else None
            lineRow = newRow(setting["group"] + " " + setting["key"],
                             line["label"] or line["key"] or line["group"] or "-", "record")
            lineRow["line"] = line
            levels[root + "/" + name].append(lineRow)
            held[(root, name)]["subject"]["lines"].append(line)
    ## inside a subject that has more than one group its lines stand group by group, in the
    ## order the groups first come: a heading for each, by the label its `group` row
    ## gives, or by the word of the group as it comes where no row gives one, and its
    ## lines under it (groupedRows). The window of such a line is titled with that
    ## heading ahead of its label, since lines of several groups read alike. A
    ## subject of one group shows its lines alone, as they come; and so does one whose
    ## groups hold one line each, no two of them of one label: a heading over every line
    ## would tell nothing apart there.
    for (root, name), row in held.items():
        groups = []
        for lineRow in levels[root + "/" + name]:
            word = lineRow["line"]["group"]
            if word not in [group for group, members in groups]:
                groups.append((word, []))
            [members for group, members in groups if group == word][0].append(lineRow)
        labels = [member["label"] for group, members in groups for member in members]
        if len(groups) > 1 and (any(len(members) > 1 for group, members in groups) or len(set(labels)) < len(labels)):
            grouped = []
            for word, members in groups:
                said = groupLabels.get((name, word)) or word or "-"
                head = newRow("group " + word, said, "group")
                head["lineGroup"] = {"subject": name, "label": said, "lines": [member["line"] for member in members]}
                for member in members:
                    member["title"] = "%s: %s" % (said, member["label"])
                grouped.append((head, members))
            levels[root + "/" + name] = groupedRows(grouped)
    for row in held.values():
        missing = len([line for line in row["subject"]["lines"] if line["state"] in STATES_MISSING])
        if missing:
            row["tail"] = "%d missing" % missing
    return levels





## Why a line is not changed from here, in the words of its row, or "" for one that is.
def changeRefusal(line):
    answer, colon, reason = line["change"].partition(":")
    if answer == CHANGE_YES:
        return ""
    return unspaced(reason).strip() or CHANGE_SAYS


## What one line of the digest reads as. A secret reads only as configured or not: the
## value of its row is never looked at. A line that offers choices reads as the label of
## the one it is set to. A scope of an outside system reads as set, with the keys it
## lacks, or as missing them; a CLI is usable or not; any other line by its value, a
## missing one marked as that.
def valueWords(subjectName, line):
    value = line["value"]
    if line.get("choices"):
        return dict(line["choices"]).get(value, value)
    if line["state"] in STATES_SECRET:
        return settingWords(line["state"], "")
    if subjectName == "systems" and line["state"] == "set":
        return "set" + (", lacks " + value.replace(",", ", ") if value else "")
    if subjectName == "systems" and line["state"] == "missing":
        return "missing" + (": " + value.replace(",", ", ") if value else "")
    if line["key"] == "usable":
        return value or line["state"]
    if registryEpoch(value) is not None:
        value = unspaced(value)
    return settingWords(line["state"], value)


## The same, and after it where the value comes from, for a line whose row says so.
def digestWords(subjectName, line):
    return valueWords(subjectName, line) + (", " + SOURCE_WORDS.get(line["source"], line["source"]) if line.get("source") else "")


## The subjects of the digest whose lines a table sets out by their group, in a column of its
## own that these words head, then each line's key and what it reads as: a row a line, with no
## heading row and no column of labels (the owner: "Pointless: SETTING VALUE KEY.... Make
## MEMBER KEY VALUE", and the CLI view the same). The group is the word the digest gives it.
GROUP_COLUMNS = {"scopes": "MEMBER", "cli": "CLI"}


## Lines of the digest as the rows of a table of the left pane, group by group, each group
## under a heading of its own where there is more than one: each line by its label, what it
## reads as, a missing one in its colour, where its value comes from, and its key where its
## label is not the key. A line with no label shows by its key. Where the missing ones stand
## first (SUMMARIES) they are the first group, each with its own group after its key. A
## subject of GROUP_COLUMNS: each line by its group, its key and what it reads as, in the
## same order. Gives the heads, the rows, the kinds and the looks, a column no line has a
## word for left out.
def digestTable(subjectName, lines, missingFirst=False):
    ahead = [line for line in lines if line["state"] in STATES_MISSING] if missingFirst else []
    groups = []
    for line in lines:
        if line in ahead:
            continue
        if not groups or groups[-1][0] != line["group"]:
            groups.append((line["group"], []))
        groups[-1][1].append(line)
    if ahead:
        groups.insert(0, (None, ahead))
    if subjectName in GROUP_COLUMNS:
        ordered = [line for group, members in groups for line in members]
        return ([GROUP_COLUMNS[subjectName], "KEY", "VALUE"],
                [[line["group"] or "-", line["key"] or "-", valueWords(subjectName, line) or "-"] for line in ordered], ["key", "key", "text"],
                [[None, None, LEVEL_WARN if line["state"] in STATES_MISSING else None] for line in ordered])
    heads = ("SETTING", "VALUE", "SOURCE", "KEY")
    rows = []
    looks = []
    for group, members in groups:
        if len(groups) > 1:
            rows.append("missing, first" if group is None else group or "-")
            looks.append(None)
        for line in members:
            key = line["key"] if line.get("label") and line["key"] and line["label"] != line["key"] else ""
            rows.append([line.get("label") or line["key"] or ("no scope" if subjectName == "systems" else "-"),
                         valueWords(subjectName, line), line.get("source") or "",
                         (key + (" in %s" % line["group"] if group is None and line["group"] else "")).strip()])
            looks.append([None, LEVEL_WARN if line["state"] in STATES_MISSING else None, None, None])
    shown = [index for index in range(len(heads)) if index < 2 or any(row[index] for row in rows if not isinstance(row, str))]
    rows = [row if isinstance(row, str) else [row[index] or "-" for index in shown] for row in rows]
    looks = [look if look is None else [look[index] for index in shown] for look in looks]
    return [heads[index] for index in shown], rows, [("key", "text", "enum", "text")[index] for index in shown], looks


## The selected subject of the digest for the left pane: its label, how many lines and how
## many of them missing as its caption, what it holds in words, dim, and its lines as a
## table (digestTable), as many as the pane shows, or every row while `e` shows them all.
def subjectLines(state, subject, missingFirst=False):
    heads, rows, kinds, looks = digestTable(subject["name"], subject["lines"], missingFirst)
    return tableSummaryLines(state, heads, rows, kinds, looks=looks)


## A subject of the digest as a folder: its lines, as its row shows them, in the form its
## root declares.
def subjectSummary(state, path, row, form):
    return subjectLines(state, row["subject"], form.get("missingFirst", False)) if row.get("subject") else None


## A group of the lines of a subject for the left pane, while its heading is selected in
## the list: its label, how many lines it holds and how many of them are missing, then its
## lines as a table (digestTable), the missing ones first.
def groupLines(group, width, wrap=True, pane=None):
    heads, rows, kinds, looks = digestTable(group["subject"], [line for line in group["lines"] if line["state"] in STATES_MISSING]
                                            + [line for line in group["lines"] if line["state"] not in STATES_MISSING])
    if group["subject"] in GROUP_COLUMNS:
        ## the title names the group: its column would say it again on every row
        heads, rows, kinds, looks = heads[1:], [row[1:] for row in rows], kinds[1:], [look[1:] for look in looks]
    head, blocks = paneTable(heads, rows, max(10, width - 1), wrap=wrap, kinds=kinds, looks=looks, pane=pane)
    return head + [line for block in blocks for line in block]


## The selected line of a subject for the left pane, from its row: what it is now first,
## of a secret only its state; the style this screen is drawn in where that is not what
## the line says; its description; then its key, its group, its state, where its value
## comes from, whom a change is for, what it takes, the file it is saved in, and whether
## Enter changes it, or why not, in the words of its row.
def settingLines(line, width):
    value = valueWords(line["subject"], line)
    value += " (%s)" % line["value"] if line["choices"] and value != line["value"] else ""
    head = Looked("%s = %s" % (line.get("label") or line["key"] or "-", value))
    head.looks = [(0, textWidth(head), BOLD)] + ([(textWidth(head) - textWidth(value), textWidth(value), stateLook(line["state"]))]
                                                 if line["state"] in STATES_MISSING else [])
    lines = [head]
    if line["key"] == STYLE_VARIABLE and STYLE["value"] != line["value"]:
        lines.append("This screen is drawn in %s now." % styleLabel())
    if line["description"]:
        lines.append("")
        lines.extend(wrapToCells(line["description"], max(10, width - 1)))
    lines.append("")
    refusal = changeRefusal(line)
    lines.extend(factLines([
        ("key", line["key"]),
        ("group", line["group"]),
        ("state", line["state"]),
        ("source", SOURCE_WORDS.get(line["source"], line["source"])),
        ("scope", SCOPE_WORDS.get(line["scope"], line["scope"])),
        ("takes", ", ".join(label for value, label in line["choices"]) or ("a whole number from %s to %s" % line["range"] if line["range"] else "")),
        ("saved in", line["where"]),
        ("change", "no: " + refusal if refusal else "yes"),
    ], width))
    return lines


## Whether Enter changes that row: a line whose row says it is changed from here.
def settingFits(state, row):
    return bool(row and row.get("line")) and not changeRefusal(row["line"])


## Why Enter changes nothing on a line that is not changed from here: the words of its row.
def settingRefusal(state, row):
    return changeRefusal(row["line"]) if row and row.get("line") else CHANGE_SAYS


## Enter on a setting: the dialog of its kind (SETTING_KINDS), with what it is now, its key
## and whom OK saves it for: its choices as radio buttons, on the one it is set to; a
## number to type, with the range it takes; or a short text. The style of the interface
## has a dialog of its own (STYLE_DIALOG), on the style and the colours this screen is
## drawn in. Nothing of a secret is put into a field.
def askSetting(state, row):
    line = row.get("line") if row else None
    if line is None or changeRefusal(line):
        return ""
    state.answer = None
    kind = SETTING_KINDS.get(line["kind"], SETTING_KIND_OTHER)
    own = line["key"] == STYLE_VARIABLE
    saves = SCOPE_SAVES.get(line["scope"], SCOPE_SAVES_OTHER) + (", and this screen takes it at once" if own else "")
    fill = {"about": {"lines": [("now", digestWords(line["subject"], line)), ("key", line["key"]),
                                saves + (". Space chooses." if kind["values"] == "choices" else ".")]}}
    if own:
        fill["style"] = {"options": [(name, style["label"]) for name, style in STYLES], "value": STYLE["name"]}
        fill["colours"] = {"options": list(COLOURS), "value": COLOURS[colourPlace()][0]}
        kind = {"dialog": STYLE_DIALOG}
    elif kind["values"] == "choices":
        fill[kind["control"]] = {"options": list(line["choices"]), "value": line["value"]}
    elif kind["values"] == "range" and line["range"]:
        fill[kind["control"]] = {"value": line["value"], "label": "A whole number from %s to %s" % line["range"]}
    else:
        fill[kind["control"]] = {"value": line["value"]}
    openDialog(state, kind["dialog"], fill, {"line": line, "viewKey": viewKeyOf(state)}, line.get("label") or line["key"])
    return ""


## OK in the dialog of a setting: the choice, or what was typed, as it stands, is saved
## through the operation, once, by the key of the line; the style of the interface is
## taken by this screen at once. A number that is not one of the range of its row is not
## sent: the dialog says so and stays, and nothing is called.
def submitSetting(state, dialog, button):
    line = dialog["about"]["line"]
    kind = SETTING_KINDS.get(line["kind"], SETTING_KIND_OTHER)
    if dialog["name"] == STYLE_DIALOG:
        ## the colours by the style's own name of them
        setStyle("%s-%s" % (dialogValue(dialog, "style"), dialogValue(dialog, "colours")))
        value = STYLE["value"]
    else:
        value = dialogValue(dialog, kind["control"])
    if kind["values"] == "range" and line["range"] and dialog["name"] != STYLE_DIALOG:
        low, high = line["range"]
        if not (value.isdigit() and str(int(value)) == value and int(low) <= int(value) <= int(high)):
            return "nothing is saved: it takes a whole number from %s to %s, written with its digits alone" % (low, high)
    says = "%s: %s" % (line.get("label") or line["key"], dict(line["choices"]).get(value, value))
    if line["key"] == STYLE_VARIABLE:
        setStyle(value)
    askCall(state, "setting", line["key"], callWords("set", line["key"]) + [value], None,
            {"viewKey": dialog["about"]["viewKey"], "says": says})
    state.notice = "save asked of the tooling: %s" % says
    state.noticeOf = None
    return None


## What the save of a setting printed: its row `saved`, the key, the value as it was read
## back, whom it is saved for, and the file, set out for the left pane, and what the
## status line says of it.
def settingAnswer(text, says, width):
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "saved" and len(fields) >= 5:
            return fieldLines([("saved", fields[1]), ("value", fields[2]), ("scope", fields[3]), ("in", fields[4])], width), "saved: %s" % says
    return [line for line in text.splitlines() if line.strip()], "the save printed no row of what it saved"


ACTION_HANDLERS["setting"] = askSetting
ACTION_FITS["setting"] = settingFits
ACTION_REFUSALS["setting"] = settingRefusal
for dialogName in set(kind["dialog"] for kind in list(SETTING_KINDS.values()) + [SETTING_KIND_OTHER]) | {STYLE_DIALOG}:
    DIALOG_HANDLERS[dialogName] = submitSetting


## What a root of the digest holds, for the left pane while its section or the row that
## goes up inside it is selected: how many subjects, lines and missing ones as its caption,
## and what the root is, dim; then its subjects as a table, those with a missing line first,
## each with how many lines it holds, how many of them are missing, in their colour, and
## what it holds in words; and the folders the root holds beside them (FIXED_ROWS), each
## with how many rows it holds where they were read already, and what it holds (FOLDER_WORDS).
## None until the read of the digest has answered.
def digestSummary(state, path, row, form):
    root = levelKey(path)
    if root not in state.rows:
        return None
    subjects = [held["subject"] for held in state.rows[root] if held.get("subject")]
    lacks = lambda subject: len([line for line in subject["lines"] if line["state"] in STATES_MISSING])
    ordered = sorted(subjects, key=lambda subject: 0 if lacks(subject) else 1)
    rows = [[subject.get("label") or subject["name"], str(len(subject["lines"])), str(lacks(subject)) if lacks(subject) else "-",
             SUBJECT_WORDS.get(subject["name"], "-")] for subject in ordered]
    looks = [[None, None, LEVEL_WARN if lacks(subject) else None, None] for subject in ordered]
    for folderId, label, kind, dive in FIXED_ROWS.get(root, ()):
        held = state.rows.get(levelKey(path + [folderId]))
        rows.append([label, str(len([one for one in held if one["kind"] != "group"])) if held is not None else "-", "-", FOLDER_WORDS.get(folderId, "-")])
        looks.append(None)
    if not rows:
        return ["No subjects."]
    return tableSummaryLines(state, ("SUBJECT", "LINES", "MISSING", "WHAT"), rows, ("key", "text", "text", "text"), looks=looks)

