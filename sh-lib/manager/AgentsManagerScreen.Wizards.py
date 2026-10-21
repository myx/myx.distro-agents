##
## AgentsManagerScreen.Wizards.py -- the configuration wizards: a form of one step or of several, answered in dialogs, and then applied by the tooling (F11.7 of
## the refactorings epic).
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##

## ---- the wizards ----

## A wizard is what separates `Configuration` from a setting changed: it asks a few questions, and then performs the extra actions that apply the state change,
## the big output dialog following what the tooling writes. THE FORM OF EACH IS DECLARED BY THE FEATURE THAT HAS IT, in the registry `wizards` of the plugin
## `configuration`, as a plugin puts anything in a registry of another (Plugins.py): its name, its title, "read" the operation that gives the form what it cannot
## know (the choices, what stands now) and "parse" the function that sets that out, "steps" the functions that each give one step (title, controls, what fills them,
## and the check of its answers), and "apply" the function that makes the operation of what was answered. The screen asks the tooling for every choice and every
## rule of a value, and keeps none of its own: the operation refuses what it refuses.
## A step is a dialog of its own, declared when it is opened (DIALOGS), with Next, Back and Finish by where it stands among the steps that are not skipped.

## The read that gives a wizard its form, and what the dialog that waits for it says.
WIZARD_READ = "full:wizard"
WIZARD_SAYS = {
    "reading": "The choices of the wizard are being read.",
    "failed": "The choices of the wizard could not be read: %s",
}
DIALOGS["wizard-wait"] = {"title": "Wizard", "reads": ("full:{kind}",),
                          "controls": ({"name": "about", "kind": "text"},),
                          "buttons": (("cancel", "Cancel"),)}
READING_DIALOGS = READING_DIALOGS + ("wizard-wait",)
PLAN_FORMS["wizard-read"] = lambda text: text


## The wizard of that name, as a plugin declared it, or None.
def wizardNamed(name):
    for held in pluginRegistry("configuration", "wizards"):
        if held["name"] == name:
            return held
    return None


## Starts a wizard: if it has a form to read, a dialog waits for that read and opens the first step when it has come; else the first step opens at once.
## `context` is what the row it was started on says (a server key), kept for its steps.
def startWizard(state, name, context=None):
    wizard = wizardNamed(name)
    if wizard is None:
        return ""
    state.answer = None
    state.wizard = {"name": name, "context": context or {}, "data": None, "answers": {}, "step": -1, "viewKey": viewKeyOf(state)}
    if wizard.get("read"):
        state.plans.pop(WIZARD_READ, None)
        state.forced.add(WIZARD_READ)
        openDialog(state, "wizard-wait", {"about": {"lines": [WIZARD_SAYS["reading"]]}}, {"target": {"kind": "wizard", "id": wizard["name"]}}, wizard["title"])
    else:
        state.wizard["data"] = {}
        wizardStep(state, 1)
    return ""


## The dialog that waits for the form of a wizard, at every turn while it is open: once the read has answered, it closes and the first step opens in its place;
## where the read failed, it says so and stays for Cancel.
def fillWizardWait(state, dialog):
    held = state.wizard
    if held is None:
        return
    wizard = wizardNamed(held["name"])
    plan = state.plans.get(WIZARD_READ)
    if plan is None or plan["words"] != readWords(READS[WIZARD_READ], state, {"id": held["name"], "level": ""}, False):
        return
    state.plans.pop(WIZARD_READ, None)
    if plan["error"]:
        dialogControl(dialog, "about")["lines"] = [WIZARD_SAYS["failed"] % plan["error"]]
        return
    held["data"] = globals()[wizard["parse"]](plan["rows"])
    closeDialog(state)
    wizardStep(state, 1)


DIALOG_FILLS["wizard-wait"] = fillWizardWait


## The step after (direction 1) or before (-1) the one the wizard is at, one the step does not skip: opened as a dialog of its own. None before the first and after
## the last: the wizard is applied then, by the caller.
def wizardStepAt(state, direction):
    wizard = wizardNamed(state.wizard["name"])
    step = state.wizard["step"] + direction
    while 0 <= step < len(wizard["steps"]):
        made = globals()[wizard["steps"][step]](state, state.wizard)
        if not made.get("skip"):
            return step, made
        step += direction
    return None, None


## Opens the next or the previous step. The steps are the dialogs `wizard:<name>:<step>`, declared here, each with the buttons its place among the steps
## that are not skipped has.
def wizardStep(state, direction):
    held = state.wizard
    step, made = wizardStepAt(state, direction)
    if step is None:
        return False
    held["step"] = step
    ## whether another step follows, and whether one stands before
    ## (a step that follows may be skipped by what this one answers: the button is Next while any is declared, and Next where none is left applies)
    ahead = step < len(wizardNamed(held["name"])["steps"]) - 1
    back = wizardStepAt(state, -1)[0] is not None
    name = "wizard:%s:%d" % (held["name"], step)
    buttons = [("next", "Next") if ahead else ("finish", made.get("finish", "Finish"))]
    if back:
        buttons.append(("back", "Back"))
    buttons.append(("cancel", "Cancel"))
    DIALOGS[name] = {"title": made["title"], "feeds": "wizard", "first": made.get("first"), "controls": tuple(made["controls"]), "buttons": tuple(buttons)}
    DIALOG_HANDLERS[name] = submitWizardStep
    openDialog(state, name, made.get("fill"), {"wizard": held["name"], "step": step}, made["title"])
    return True


## A button of a step: the answers of its controls are kept under the step; Back opens the step before; the check of the step, where it has one, may refuse
## and the dialog stays; Next opens the step after; Finish applies the wizard, in the big output dialog.
def submitWizardStep(state, dialog, button):
    held = state.wizard
    wizard = wizardNamed(held["name"])
    step = dialog["about"]["step"]
    answers = {}
    for control in dialog["controls"]:
        if control["kind"] not in ("text", "button"):
            answers[control["name"]] = list(control["value"]) if isinstance(control["value"], list) else control["value"]
    held["step"] = step
    if button == "back":
        held["answers"].pop(step, None)
        wizardStep(state, -1)
        return None
    held["answers"][step] = answers
    made = globals()[wizard["steps"][step]](state, held)
    if made.get("check"):
        refusal = globals()[made["check"]](state, held, answers)
        if refusal:
            return refusal
    if button == "next" and wizardStep(state, 1):
        return None
    label, words, inputText = globals()[wizard["apply"]](state, held)
    runFollowed(state, label, words, inputText)
    return None


## What a step answered, by the name of its control: "" where the step was not asked or the wizard has not got there.
def wizardAnswer(held, step, name, default=""):
    return held["answers"].get(step, {}).get(name, default)


## ---- the wizard of the CLI service: a preset, and the team's tiers (F10.1 to F10.3) ----

## What `--manager-wizard-read cli-service` printed: the choices (option rows), the credentials each service reads, what each preset holds (preset rows) and
## what the team holds (team rows). A credential is in its one form.
def parseCliWizard(text):
    data = {"services": [], "efforts": [], "presets": [], "credentials": {}, "held": {}, "team": {}}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "option" and len(fields) >= 4:
            key = {"cli-service": "services", "effort": "efforts", "preset": "presets"}.get(fields[1])
            if key:
                data[key].append(fields[2])
        elif fields[0] == "credential" and len(fields) >= 3:
            data["credentials"].setdefault(fields[1], []).append(fields[2])
        elif fields[0] == "preset" and len(fields) >= 5:
            data["held"].setdefault(fields[1], {})[fields[2]] = (fields[3], absent(fields[4]))
        elif fields[0] == "team" and len(fields) >= 4:
            data["team"][fields[1]] = (fields[2], absent(fields[3]))
    return data


## The value a preset holds of a key, or "" (the masked form of a credential).
def presetHeld(held, preset, key):
    return held["data"]["held"].get(preset, {}).get(key, ("missing", ""))[1]


## The preset the wizard is on: the one picked, else the new one named.
def wizardPreset(held):
    picked = wizardAnswer(held, 0, "preset")
    return picked or wizardAnswer(held, 0, "name").strip()


## The CLI service the preset has: the one the second step chose, else the one it holds, else the one the preset it extends has.
def wizardService(held):
    preset = wizardPreset(held)
    seen = 0
    while preset and seen < 8:
        service = wizardAnswer(held, 1, "service") if seen == 0 else ""
        service = service or presetHeld(held, preset, "PRESET_CLI_SERVICE")
        if service:
            return service
        preset = presetHeld(held, preset, "PRESET_EXTEND")
        seen += 1
    return ""


def cliStepPreset(state, held):
    data = held["data"]
    options = [(name, name) for name in data["presets"]] + [("", "a new preset")]
    return {"title": "Configure CLI Service: the preset", "first": "preset", "check": "cliCheckPreset",
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "preset", "kind": "radios", "label": "Preset"},
                         {"name": "name", "kind": "input", "label": "Name of the new preset, lower case"}),
            "fill": {"about": {"lines": ["A preset is a block of settings for a CLI service: the service, its model or macro, its effort and the credentials of the service. Pick the preset to configure, or make a new one."]},
                     "preset": {"options": options, "value": held["context"].get("preset") or (data["presets"][0] if data["presets"] else "")}}}


def cliCheckPreset(state, held, answers):
    if not answers["preset"] and not answers["name"].strip():
        return "nothing is configured: a new preset needs a name"
    return ""


def cliStepSettings(state, held):
    data = held["data"]
    preset = wizardPreset(held)
    extends = presetHeld(held, preset, "PRESET_EXTEND")
    controls = [{"name": "about", "kind": "text"}]
    fill = {}
    lines = ["Preset: %s." % preset]
    if extends:
        lines.append("It extends %s, so its CLI service is the inherited one and is not edited here." % extends)
    else:
        controls.append({"name": "service", "kind": "radios", "label": "CLI service"})
        fill["service"] = {"options": [(name, name) for name in data["services"]], "value": presetHeld(held, preset, "PRESET_CLI_SERVICE") or data["services"][0]}
    controls.append({"name": "model", "kind": "input", "label": "Model or macro (low or easy, normal or default, high or hard, or a model name), or none"})
    controls.append({"name": "effort", "kind": "radios", "label": "Effort"})
    fill["about"] = {"lines": lines}
    fill["model"] = {"value": presetHeld(held, preset, "PRESET_MODEL_OR_MACRO")}
    fill["effort"] = {"options": [("", "not set")] + [(name, name) for name in data["efforts"]], "value": presetHeld(held, preset, "PRESET_EFFORT")}
    return {"title": "Configure CLI Service: %s" % preset, "first": "service" if not extends else "model", "controls": controls, "fill": fill}


def cliStepCredentials(state, held):
    data = held["data"]
    preset = wizardPreset(held)
    service = wizardService(held)
    keys = data["credentials"].get(service, [])
    if not keys:
        return {"skip": True}
    controls = [{"name": "about", "kind": "text"}]
    fill = {"about": {"lines": ["The credentials %s reads, for preset %s. A credential is shown in its one form, its first quarter and then * for the rest. Leave a field as it is to keep it; type a new value to replace it; empty it to take the credential out." % (service, preset)]}}
    for key in keys:
        controls.append({"name": key, "kind": "input", "label": key})
        fill[key] = {"value": presetHeld(held, preset, key)}
    return {"title": "Configure CLI Service: the credentials of %s" % service, "first": keys[0], "controls": controls, "fill": fill}


## What the wizard asks of the tooling, from the answers: each key whose answer is not what it held, one line `<key> <TAB> <value>` of the standard input of
## `--manager-wizard-apply cli-service --preset <name>`, which writes them in the order its checks need and refuses what they refuse.
def cliApply(state, held):
    data = held["data"]
    preset = wizardPreset(held)
    lines = []

    def ask(key, answer, now):
        if answer != now:
            lines.append("%s\t%s\n" % (key, answer))

    if not presetHeld(held, preset, "PRESET_EXTEND"):
        ask("PRESET_CLI_SERVICE", wizardAnswer(held, 1, "service"), presetHeld(held, preset, "PRESET_CLI_SERVICE"))
    ask("PRESET_MODEL_OR_MACRO", wizardAnswer(held, 1, "model").strip(), presetHeld(held, preset, "PRESET_MODEL_OR_MACRO"))
    ask("PRESET_EFFORT", wizardAnswer(held, 1, "effort"), presetHeld(held, preset, "PRESET_EFFORT"))
    service = wizardService(held)
    for key in data["credentials"].get(service, []):
        ask(key, wizardAnswer(held, 2, key, presetHeld(held, preset, key)), presetHeld(held, preset, key))
    return "Configure CLI Service: %s" % preset, ["--manager-wizard-apply", "cli-service", "--preset", preset], "".join(lines)


## ---- the wizard of the git settings ----

## What `--manager-wizard-read git-settings` printed: the three settings as they stand, and the private keys git may be told to connect with.
def parseGitWizard(text):
    data = {"current": {}, "keys": []}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "current" and len(fields) >= 3:
            data["current"][fields[1]] = absent(fields[2])
        elif fields[0] == "option" and len(fields) >= 4 and fields[1] == "ssh-key":
            data["keys"].append((fields[2], unspaced(fields[3])))
    return data


def gitStepSettings(state, held):
    data = held["data"]
    current = data["current"]
    options = [("", "left as it is")] + [(path, "%s: %s" % (label, path)) for path, label in data["keys"]]
    return {"title": "Configure Git Settings", "first": "name",
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "name", "kind": "input", "label": "user.name"},
                         {"name": "email", "kind": "input", "label": "user.email"},
                         {"name": "key", "kind": "radios", "label": "The key git connects with (the -i of core.sshCommand)"}),
            "fill": {"about": {"lines": ["The global git settings of the account that runs the tools: who commits, and the private key git connects with. A field left as it is changes nothing."]},
                     "name": {"value": unspaced(current.get("user.name", ""))},
                     "email": {"value": unspaced(current.get("user.email", ""))},
                     "key": {"options": options, "value": ""}}}


def gitApply(state, held):
    current = held["data"]["current"]
    answers = held["answers"][0]
    lines = []
    for field, answer in (("user.name", answers["name"].strip()), ("user.email", answers["email"].strip()), ("ssh-key", answers["key"])):
        if answer and answer != unspaced(current.get(field, "")):
            lines.append("%s\t%s\n" % (field, answer))
    return "Configure Git Settings", ["--manager-wizard-apply", "git-settings"], "".join(lines)


## ---- the wizards of the server keys: made, replaced, removed, each behind its warning ----

## What each of the three says before it is done, and the word that confirms what cannot be undone, typed whole.
KEY_WIZARDS = {
    "generate": {"title": "Generate", "word": None, "finish": "Generate",
                 "says": "A new ed25519 key is made, with no passphrase, in the place the list names for it. Nothing that stands is replaced: a key that is there is refused."},
    "regenerate": {"title": "Regenerate", "word": "regenerate", "finish": "Regenerate",
                   "says": "WARNING: the key is replaced by a new one in the same files, and the old one is gone for good. Whoever trusts the old public key, the git hosts that list it and the targets that have it in their authorized keys, trusts nothing of the new one until it is registered there again."},
    "delete": {"title": "Delete", "word": "delete", "finish": "Delete",
               "says": "WARNING: the private key and its public file are removed, and cannot be got back. Whatever connects with this key fails until a key is made again."},
}


def keyStep(what):
    def step(state, held):
        context = held["context"]
        kind = KEY_WIZARDS[what]
        controls = [{"name": "about", "kind": "text"}]
        if kind["word"]:
            controls.append({"name": "word", "kind": "input", "label": "Type %s to go on" % kind["word"], "exactly": kind["word"],
                             "required": "nothing is done: the word typed is not %s" % kind["word"]})
        return {"title": "%s: %s" % (kind["title"], context["label"]), "first": "word" if kind["word"] else None, "finish": kind["finish"], "controls": controls,
                "fill": {"about": {"lines": [("key", context["label"]), ("file", context["file"]), kind["says"]]}}}
    return step


def keyApply(what):
    def apply(state, held):
        return "%s: %s" % (KEY_WIZARDS[what]["title"], held["context"]["label"]), ["--manager-keys-" + what, held["context"]["key"]], None
    return apply


for keyWhat in KEY_WIZARDS:
    globals()["keyStep" + keyWhat.capitalize()] = keyStep(keyWhat)
    globals()["keyApply" + keyWhat.capitalize()] = keyApply(keyWhat)


## ---- the folder `Git Settings` of the configuration ----

## What `--manager-wizard-read git-settings` printed, as the rows of the folder: the three settings as they stand, each by its name, its value at the end of its row.
def parseGitLevels(readKey, level, text):
    rows = []
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "current" and len(fields) >= 3:
            row = newRow(fields[1], fields[1], "record", False, fields)
            row["gitSetting"] = {"name": fields[1], "value": unspaced(absent(fields[2]))}
            row["tail"] = row["gitSetting"]["value"]
            rows.append(row)
    return {level: rows}


ROW_FORMS["git-settings"] = parseGitLevels


## The folder for the left pane: the settings and what they are, as a table; and the line that says how to change them. None until its read has answered.
def gitSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    return tableSummaryLines(state, ("SETTING", "VALUE"), [[held["gitSetting"]["name"], held["gitSetting"]["value"] or "-"] for held in rows if held.get("gitSetting")],
                             ("key", "text"))


def gitFocus(state, row):
    held = row.get("gitSetting")
    if held is None:
        return None
    return {"kind": "table", "heads": ("SETTING", "VALUE"), "rows": [[held["name"], held["value"] or "-"]], "kinds": ("key", "text")}


registerPlugin({
    "name": "git",
    "mount": "configuration",
    "root": {"id": "git", "label": "Git Settings"},
    "focus": {"git": "gitFocus"},
    "summaries": {"git": {"lines": "gitSummary"}},
    "reads": {
        ## The global git settings of the account that runs the tools. Read on entering it and when it is asked for, and again when a wizard has ended.
        "list:git": {"operation": ["--manager-wizard-read", "git-settings"], "rows": "git-settings", "once": True},
    },
})


## ---- the keys that start a wizard ----

## The wizard a row starts: the CLI service's on the subject of the CLI services of the configuration and on its lines, the git settings' on their folder and its lines.
def wizardOfRow(state, row):
    if row is None or row["kind"] == "up":
        return None
    here = pluginLevel("configuration")
    level = levelKey(state.path)
    if level == here + "/git" or (level == here and row["id"] == "git"):
        return "git-settings"
    if level == pluginLevel("clipresets") or (level == here and row["id"] == "clipresets"):
        return "cli-service"
    return None


def askWizard(state, row):
    name = wizardOfRow(state, row)
    return startWizard(state, name) if name else ""


ACTION_HANDLERS["wizard"] = askWizard
ACTION_FITS["wizard"] = lambda state, row: wizardOfRow(state, row) is not None
ACTION_REFUSALS["wizard"] = lambda state, row: "it has no wizard"


## `Auto-select CLI...` (F13.4), on the item of the CLI services in the configuration, where the wizard of the CLI service is: it runs the owner's check of which vendor CLI works here, in the big output dialog
## that a command of a workspace runs in, and where that ended with status 0 the dialog offers the apply as a button of its own. The screen computes nothing: which CLI works is what
## the check says, and whether the apply is offered is the status it ended with.
CLI_AUTO_CHECK = ["--owner-setup-cli-auto", "--check"]
CLI_AUTO_APPLY = {"button": "Apply", "label": "Auto-select CLI: apply", "words": ["--owner-setup-cli-auto", "--apply"]}


def askCliAuto(state, row):
    runFollowed(state, "Auto-select CLI", CLI_AUTO_CHECK, then=CLI_AUTO_APPLY)
    return ""


ACTION_HANDLERS["cliauto"] = askCliAuto
ACTION_FITS["cliauto"] = lambda state, row: wizardOfRow(state, row) == "cli-service"
ACTION_REFUSALS["cliauto"] = lambda state, row: "it has no CLI to select"


## The server keys that are the account's, which the wizards make, replace and remove (by their names, since a group is no longer a kind of key: F11.7);
## a host key of the server and a key it trusts are not.
KEY_MAKE_KEYS = ("deploy", "generated", "outgoing")


## A server key of the account, not a host key of the server.
def keyMine(row):
    held = row.get("serverKey") if row else None
    return held is not None and held["key"] in KEY_MAKE_KEYS


def keyWizardFits(what):
    return lambda state, row: keyMine(row) and (row["serverKey"]["state"] != KEY_PRESENT) == (what == "generate")


def askKeyWizard(what):
    def ask(state, row):
        held = row["serverKey"]
        return startWizard(state, "server-key-" + what, {"key": held["key"], "label": unspaced(held["label"]) or held["key"], "file": absent(held["file"])})
    return ask


for keyWhat in KEY_WIZARDS:
    ACTION_HANDLERS["key" + keyWhat] = askKeyWizard(keyWhat)
    ACTION_FITS["key" + keyWhat] = keyWizardFits(keyWhat)
    ACTION_REFUSALS["key" + keyWhat] = (lambda what: lambda state, row: (
        "a host key of the server is the system's: it is not made, replaced or removed here" if row and row.get("serverKey") and not keyMine(row)
        else "there is no key to replace or remove there: it is generated" if what != "generate" else "the key is there already: it is replaced"))(keyWhat)


## ---- the plugin: the wizards ----

registerPlugin({
    "name": "wizards",
    "integrates": {"configuration": {"wizards": (
        {"name": "cli-service", "title": "Configure CLI Service", "read": ["--manager-wizard-read", "cli-service"], "parse": "parseCliWizard",
         "steps": ("cliStepPreset", "cliStepSettings", "cliStepCredentials"), "apply": "cliApply"},
        {"name": "git-settings", "title": "Configure Git Settings", "read": ["--manager-wizard-read", "git-settings"], "parse": "parseGitWizard",
         "steps": ("gitStepSettings",), "apply": "gitApply"},
        {"name": "server-key-generate", "title": "Generate Server Key", "steps": ("keyStepGenerate",), "apply": "keyApplyGenerate"},
        {"name": "server-key-regenerate", "title": "Regenerate Server Key", "steps": ("keyStepRegenerate",), "apply": "keyApplyRegenerate"},
        {"name": "server-key-delete", "title": "Delete Server Key", "steps": ("keyStepDelete",), "apply": "keyApplyDelete"},
    )}},
    "reads": {
        ## What the form of a wizard needs, read when its dialog waits for it by the name of the wizard, and never before.
        WIZARD_READ: {"operation": ["--manager-wizard-read", "{id}"], "rows": "wizard-read", "kind": "plan", "demand": True},
    },
    "commands": (
        {"name": "configure", "keys": ("c",), "menu": ("view", 3), "label": "~C~onfigure", "status": "Configure", "window": "list",
         "views": ("@configuration", "@clipresets", "@configuration/git"),
         "for": "a feature that is configured by a wizard", "on": ("@configuration:record", "@configuration:section", "@clipresets:section", "@configuration/git:record"),
         "only": True, "says": "configure", "does": ("action", "wizard")},
        {"name": "cliauto", "keys": ("s",), "menu": ("view", 3), "label": "Auto-~s~elect CLI...", "status": "Auto-select", "window": "list",
         "views": ("@configuration", "@clipresets"),
         "for": "the CLI services", "on": ("@configuration:section", "@clipresets:section"),
         "only": True, "says": "auto-select", "does": ("action", "cliauto")},
        {"name": "keygenerate", "keys": ("n",), "menu": ("view", 3), "label": "~N~ew key, generate it", "status": "Generate", "window": "list",
         "views": ("@configuration/keys",), "for": "a key that is not there", "on": ("@configuration/keys:record",), "only": True, "says": "generate",
         "does": ("action", "keygenerate")},
        {"name": "keyregenerate", "keys": ("R",), "menu": ("view", 3), "label": "~R~egenerate the key", "status": "Regenerate", "window": "list",
         "views": ("@configuration/keys",), "for": "a key that is there", "on": ("@configuration/keys:record",), "only": True, "says": "regenerate",
         "does": ("action", "keyregenerate")},
        {"name": "keydelete", "keys": ("d",), "menu": ("view", 3), "label": "~D~elete the key", "status": "Delete", "window": "list",
         "views": ("@configuration/keys",), "for": "a key that is there", "on": ("@configuration/keys:record",), "only": True, "says": "delete",
         "does": ("action", "keydelete")},
    ),
})
