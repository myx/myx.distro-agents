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
        openDialog(state, "wizard-wait", {"about": {"lines": [WIZARD_SAYS["reading"]]}}, {"target": {"kind": "wizard", "id": wizard["name"], "read": wizard.get("read")}}, wizard["title"])
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
    if plan is None or plan["words"] != readWords({"operation": wizard["read"]}, state, {"id": held["name"], "level": ""}, False):
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
## The answers a step already holds are put back into it when it opens again, over what its
## fill says stands now: going back to a step and on again applies what was answered there.
## Without this a step re-opened is filled from the tooling as it stands, the answers given
## to it before are gone, and the wizard applies nothing at all when they were the only
## change (`back` to look at the name, then Finish: the edit was never sent).
def wizardRestore(dialog, answers):
    for control in dialog["controls"]:
        if control["name"] not in answers:
            continue
        value = answers[control["name"]]
        if control["kind"] == "checks":
            control["value"] = list(value) if isinstance(value, list) else [value]
        elif control["kind"] in ("radios", "list"):
            ids = [option[0] for option in control["options"]]
            if value in ids:
                control["value"] = value
                control["at"] = ids.index(value)
        elif control["kind"] in ("input", "area"):
            control["value"] = value
            control["caret"] = len(value)
            control["seen"] = value


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
    wizardRestore(openDialog(state, name, made.get("fill"), {"wizard": held["name"], "step": step}, made["title"]), held["answers"].get(step, {}))
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
    data = {"services": [], "efforts": [], "caches": [], "presets": [], "credentials": {}, "held": {}, "team": {}}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0] == "option" and len(fields) >= 4:
            key = {"cli-service": "services", "effort": "efforts", "cache": "caches", "preset": "presets"}.get(fields[1])
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


## The preset the wizard is on: the one it was started on (edit), else the new one named in the form.
def wizardPreset(held):
    return held["context"].get("preset") or wizardAnswer(held, 0, "name").strip()


## The name the preset is written under: the name typed in the form, which on edit renames it, else the one it already has.
def wizardName(held):
    return wizardAnswer(held, 0, "name").strip() or wizardPreset(held)


## Whether the wizard edits a preset that is there rather than makes one: its context names the preset.
def cliEditing(held):
    return bool(held["context"].get("preset"))


## The input of the apply, from the answers that changed: a line `<key> <TAB> <value>` each.
def cliWriteInput(pairs):
    lines = []
    for key, answer, now in pairs:
        if answer != now:
            lines.append("%s\t%s\n" % (key, answer))
    return "".join(lines)


## The words and the input of the apply: the preset's name, a rename where the name changed, and the changed answers alone.
def cliApply(held, pairs):
    preset = wizardName(held)
    words = ["--manager-wizard-apply", "cli-service", "--preset", preset]
    if cliEditing(held) and wizardName(held) != wizardPreset(held):
        words += ["--rename-from", wizardPreset(held)]
    return "Configure CLI Service: %s" % preset, words, cliWriteInput(pairs)


## What a step of the CLI wizard titles itself: the preset's name, or a new one while it is not named yet.
def cliTitle(preset):
    return "Configure CLI Service: %s" % (preset or "a new preset")


## The form a preset belongs to: the one extending, the universal one, or a service of its own. The universal form writes
## the `standard-v1` service, which is the one the tooling carries for a server reached by URL; `universal` names the form alone.
def cliPresetKind(held, name):
    if presetHeld(held, name, "PRESET_EXTEND"):
        return "extend"
    if presetHeld(held, name, "PRESET_CLI_SERVICE") == "standard-v1":
        return "universal"
    return "service"


## The name field of every form: the new preset's name, or, on edit, its own, which renames it.
def cliNameControl():
    return {"name": "name", "kind": "input", "label": "Name of the preset, lower case",
            "required": "nothing is done: a preset needs a name"}


## The endpoint of the service, which the universal form and a service's own form both ask for: a service states no endpoint of its own
## where its leg reads one from the environment (the standard v1 service does not, and refuses to run without it), so a preset that names
## such a service is only ever pointed at one by this field, and Configuration has no other input for it. Asked in its one place, so that
## the two forms cannot come to ask it differently.
def cliEndpointControl():
    return {"name": "endpoint", "kind": "input", "label": "The endpoint URL: https, ending /v1 or /anthropic"}


def cliEndpointFill(held, preset):
    return {"endpoint": {"value": presetHeld(held, preset, "PRESET_ENDPOINT_URL")}}


## The options of a choice of a preset, and what it holds: a value the tooling's choices do not
## name is an option of its own, shown as it stands. The apply still takes a value an older
## release wrote (`default`, `hard` and `none` for the effort; a cache lifetime that is no
## longer offered), and a form that cannot show it falls back to its first option, which is
## "not set" -- so an edit that never touched it would send nothing for it, and nothing there
## takes the setting out. A person's own value is never taken out by an edit that left it alone.
def cliChoiceFill(held, preset, key, choices):
    options = [("", "not set")] + [(name, name) for name in choices]
    value = presetHeld(held, preset, key)
    if value and value not in [name for name, label in options]:
        options.append((value, "%s, as it is set" % value))
    return {"options": options, "value": value}


## The model, the effort, the input cache lifetime and the context, which every form sets for itself.
def cliModelFill(held, preset):
    return {"model": {"value": presetHeld(held, preset, "PRESET_MODEL_OR_MACRO")},
            "effort": cliChoiceFill(held, preset, "PRESET_EFFORT", [name for name in held["data"]["efforts"] if name != "unset"]),
            "cache": cliChoiceFill(held, preset, "PRESET_INPUT_CACHE_TIME", held["data"]["caches"]),
            "context": {"value": presetHeld(held, preset, "PRESET_CONTEXT_MAX_SIZE")}}


def cliModelControls():
    return ({"name": "model", "kind": "input", "label": "Model or macro (low or easy, normal or default, high or hard, or a model name), or none"},
            {"name": "effort", "kind": "radios", "label": "Effort"},
            {"name": "cache", "kind": "radios", "label": "Input cache lifetime"},
            {"name": "context", "kind": "input", "label": "Restart threshold (context size), whole tokens, or none"})


def cliModelPairs(held, preset):
    return [("PRESET_MODEL_OR_MACRO", wizardAnswer(held, 0, "model").strip(), presetHeld(held, preset, "PRESET_MODEL_OR_MACRO")),
            ("PRESET_EFFORT", wizardAnswer(held, 0, "effort"), presetHeld(held, preset, "PRESET_EFFORT")),
            ("PRESET_INPUT_CACHE_TIME", wizardAnswer(held, 0, "cache"), presetHeld(held, preset, "PRESET_INPUT_CACHE_TIME")),
            ("PRESET_CONTEXT_MAX_SIZE", wizardAnswer(held, 0, "context").strip(), presetHeld(held, preset, "PRESET_CONTEXT_MAX_SIZE"))]


## The credentials of a service: shown in their one form, kept where a field is left as it is.
def cliCredentialStep(held, preset, service, keys):
    if not keys:
        return {"skip": True}
    controls = [{"name": "about", "kind": "text"}]
    fill = {"about": {"lines": ["The credentials %s reads, for preset %s. A credential is shown in its one form, its first quarter and then * for the rest. Leave a field as it is to keep it; type a new value to replace it; empty it to take the credential out." % (service, preset)]}}
    for key in keys:
        controls.append({"name": key, "kind": "input", "label": key})
        fill[key] = {"value": presetHeld(held, preset, key)}
    return {"title": "Configure CLI Service: the credentials of %s" % service, "first": keys[0], "controls": controls, "fill": fill}


## ---- the service form ----

def cliStepServiceFields(state, held):
    data = held["data"]
    preset = wizardPreset(held)
    editing = cliEditing(held)
    about = ["Preset: %s." % preset]
    controls = [{"name": "about", "kind": "text"}, cliNameControl()]
    fill = {"name": {"value": held["context"].get("preset", "")}}
    if editing:
        about.append("Its CLI service is %s: a service preset's own is not changed when it is edited." % presetHeld(held, preset, "PRESET_CLI_SERVICE"))
    else:
        controls.append({"name": "service", "kind": "radios", "label": "CLI service"})
        fill["service"] = {"options": [(name, name) for name in data["services"]], "value": data["services"][0]}
    ## The endpoint belongs to the service chosen just above, and is asked for on edit too, where the service itself is not: the preset
    ## that made the owner ask ("IF THERE IS NO INPUT FOR SERVICE URL?") is the one already there, pointed at a service with no leg.
    controls.append(cliEndpointControl())
    fill.update(cliEndpointFill(held, preset))
    controls += cliModelControls()
    fill["about"] = {"lines": about}
    fill.update(cliModelFill(held, preset))
    return {"title": cliTitle(preset), "first": "name", "controls": controls, "fill": fill}


def cliStepServiceCredentials(state, held):
    preset = wizardPreset(held)
    service = wizardAnswer(held, 0, "service", presetHeld(held, preset, "PRESET_CLI_SERVICE"))
    return cliCredentialStep(held, preset, service, held["data"]["credentials"].get(service, []))


def cliApplyService(state, held):
    preset = wizardPreset(held)
    service = wizardAnswer(held, 0, "service", presetHeld(held, preset, "PRESET_CLI_SERVICE"))
    endpoint = wizardAnswer(held, 0, "endpoint", presetHeld(held, preset, "PRESET_ENDPOINT_URL")).strip()
    pairs = [("PRESET_CLI_SERVICE", service, presetHeld(held, preset, "PRESET_CLI_SERVICE")),
             ("PRESET_ENDPOINT_URL", endpoint, presetHeld(held, preset, "PRESET_ENDPOINT_URL"))] + cliModelPairs(held, preset)
    for key in held["data"]["credentials"].get(service, []):
        pairs.append((key, wizardAnswer(held, 1, key, presetHeld(held, preset, key)), presetHeld(held, preset, key)))
    return cliApply(held, pairs)


## ---- the universal form ----

def cliStepUniversalFields(state, held):
    preset = wizardPreset(held)
    controls = [{"name": "about", "kind": "text"}, cliNameControl(), cliEndpointControl()]
    fill = {"about": {"lines": ["Preset: %s." % preset]},
            "name": {"value": held["context"].get("preset", "")}}
    fill.update(cliEndpointFill(held, preset))
    controls += cliModelControls()
    fill.update(cliModelFill(held, preset))
    return {"title": cliTitle(preset), "first": "name", "controls": controls, "fill": fill}


## The key the universal form asks for: the one its wire reads, chosen by the endpoint's path.
def cliUniversalKey(held):
    endpoint = wizardAnswer(held, 0, "endpoint", presetHeld(held, wizardPreset(held), "PRESET_ENDPOINT_URL"))
    return "ANTHROPIC_API_KEY" if "/anthropic" in endpoint else "OPENAI_API_KEY"


def cliStepUniversalCredential(state, held):
    preset = wizardPreset(held)
    return cliCredentialStep(held, preset, "standard-v1", [cliUniversalKey(held)])


def cliApplyUniversal(state, held):
    preset = wizardPreset(held)
    endpoint = wizardAnswer(held, 0, "endpoint", presetHeld(held, preset, "PRESET_ENDPOINT_URL")).strip()
    pairs = [("PRESET_CLI_SERVICE", "standard-v1", presetHeld(held, preset, "PRESET_CLI_SERVICE")),
             ("PRESET_ENDPOINT_URL", endpoint, presetHeld(held, preset, "PRESET_ENDPOINT_URL"))] + cliModelPairs(held, preset)
    key = cliUniversalKey(held)
    pairs.append((key, wizardAnswer(held, 1, key, presetHeld(held, preset, key)), presetHeld(held, preset, key)))
    return cliApply(held, pairs)


## ---- the extension form ----

def cliStepExtendFields(state, held):
    data = held["data"]
    preset = wizardPreset(held)
    editing = cliEditing(held)
    about = ["Preset: %s." % preset]
    controls = [{"name": "about", "kind": "text"}, cliNameControl()]
    fill = {"name": {"value": held["context"].get("preset", "")}}
    if editing:
        about.append("It extends %s: what a preset extends is not changed when it is edited." % presetHeld(held, preset, "PRESET_EXTEND"))
    else:
        controls.append({"name": "extends", "kind": "radios", "label": "It extends"})
        fill["extends"] = {"options": [(name, name) for name in data["presets"]],
                           "value": data["presets"][0] if data["presets"] else ""}
    controls += cliModelControls()
    fill["about"] = {"lines": about}
    fill.update(cliModelFill(held, preset))
    return {"title": cliTitle(preset), "first": "name", "controls": controls, "fill": fill}


def cliApplyExtend(state, held):
    preset = wizardPreset(held)
    pairs = [("PRESET_EXTEND", wizardAnswer(held, 0, "extends", presetHeld(held, preset, "PRESET_EXTEND")),
              presetHeld(held, preset, "PRESET_EXTEND"))] + cliModelPairs(held, preset)
    return cliApply(held, pairs)
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


## ---- the wizards of the keys this account trusts: added and removed in its authorized keys (C1) ----

## What each of the two says before it is done, and the word that confirms what cannot be undone.
TRUST_KEY_WIZARDS = {
    "trust-add": {"title": "Add Trusted Key", "word": None, "finish": "Add",
                  "says": "The whole public key line is put into the account's own authorized_keys, so whoever holds its private key may then log in here as this account. Add only a key you trust."},
    "trust-delete": {"title": "Delete Trusted Key", "word": "delete", "finish": "Delete",
                     "says": "WARNING: the key is taken out of the account's authorized_keys, and whoever holds its private key can no longer log in here with it."},
}


def keyTrustAddStep(state, held):
    return {"title": "Add Trusted Key", "first": "line",
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "line", "kind": "input", "label": "The whole public key line, as one pastes it"}),
            "fill": {"about": {"lines": [TRUST_KEY_WIZARDS["trust-add"]["says"]]},
                     "line": {"value": ""}}}


def keyTrustDeleteStep(state, held):
    context = held["context"]
    kind = TRUST_KEY_WIZARDS["trust-delete"]
    return {"title": "%s: %s" % (kind["title"], context["label"]), "first": "word", "finish": kind["finish"],
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "word", "kind": "input", "label": "Type %s to go on" % kind["word"], "exactly": kind["word"],
                          "required": "nothing is done: the word typed is not %s" % kind["word"]}),
            "fill": {"about": {"lines": [("key", context["label"]), ("file", context["file"]), kind["says"]]}}}


def keyTrustAddApply(state, held):
    return "Add Trusted Key", ["--manager-keys-trust-add"], wizardAnswer(held, 0, "line").strip() + "\n"


def keyTrustDeleteApply(state, held):
    return "Delete Trusted Key: %s" % held["context"]["label"], ["--manager-keys-trust-delete", held["context"]["key"]], None


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


## ---- Configure Harness: two forms, each its own concern ----

## What `--manager-harness-read` printed: the three settings as they stand, `<key> <TAB> <value>`.
def parseHarnessSettings(text):
    values = {}
    for printed in text.split("\n"):
        fields = printed.split("\t")
        if fields[0]:
            values[fields[0]] = absent(fields[1]) if len(fields) > 1 else ""
    return {"values": values}


## The folder's two rows, each with what its form holds now at the end of the row. The folder's
## read is the same one the forms read, so what it says and what a form opens on cannot differ.
def parseHarnessForms(readKey, level, text):
    values = parseHarnessSettings(text)["values"]
    retries = "%s attempts, %s s before the first retry" % (values.get("HARNESS_STREAM_ATTEMPTS") or "3", values.get("HARNESS_RETRY_DELAY") or "1")
    protocol = "parallel tool calls %s" % (values.get("HARNESS_PARALLEL_TOOL_CALLS") or "off")
    rows = []
    for formId, label, tail in (("retries", "Retries", retries), ("protocol", "Protocol", protocol)):
        ## A form is no folder: Enter on it runs its wizard, as `c` does (the main action of a row that dives nowhere).
        row = newRow(formId, label, "harness-form", False)
        row["tail"] = tail
        rows.append(row)
    return {level: rows}


ROW_FORMS["harness-forms"] = parseHarnessForms


def harnessFocus(state, row):
    held = row.get("harness-form")
    return None


def harnessSummary(state, path, row, form):
    rows = state.rows.get(pluginLevel("harness")) or ()
    if not rows:
        return None
    return tableSummaryLines(state, ("FORM", "HOLDS NOW"), [[one["label"], one["tail"]] for one in rows], ("key", "text"))


## The settings a form changes, and the words it writes them with.
def harnessFormSettings(formId):
    return ("HARNESS_STREAM_ATTEMPTS", "HARNESS_RETRY_DELAY") if formId == "retries" else ("HARNESS_PARALLEL_TOOL_CALLS",)


def harnessStepRetries(state, held):
    values = held["data"]["values"]
    return {"title": "Configure Harness: retries", "first": "attempts",
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "attempts", "kind": "input", "label": "Attempts of one round, 1 to 10"},
                         {"name": "delay", "kind": "input", "label": "Seconds before the first retry, 0 to 30; each later one doubles"}),
            "fill": {"about": {"lines": ["A round that fails on a temporary refusal is retried; a final refusal ends it at once.",
                                         "The delay doubles after every failed attempt, never past 30 seconds."]},
                     "attempts": {"value": values.get("HARNESS_STREAM_ATTEMPTS", "")},
                     "delay": {"value": values.get("HARNESS_RETRY_DELAY", "")}}}


def harnessStepProtocol(state, held):
    values = held["data"]["values"]
    return {"title": "Configure Harness: protocol", "first": "parallel",
            "controls": ({"name": "about", "kind": "text"},
                         {"name": "parallel", "kind": "radios", "label": "Parallel tool calls"}),
            "fill": {"about": {"lines": ["Only a server known to take parallel tool calls should be told so.",
                                         "Unset asks for nothing, so a server that does not take the field is never asked it."]},
                     "parallel": {"options": [("off", "off: ask for nothing"), ("on", "on: the server may take several calls at once")],
                                  "value": values.get("HARNESS_PARALLEL_TOOL_CALLS") or "off"}}}


def harnessApplyCommon(state, held, formId):
    values = held["data"]["values"]
    lines = []

    def ask(key, answer):
        if answer != values.get(key, ""):
            lines.append("%s\t%s\n" % (key, answer))

    if formId == "retries":
        ask("HARNESS_STREAM_ATTEMPTS", wizardAnswer(held, 0, "attempts").strip())
        ask("HARNESS_RETRY_DELAY", wizardAnswer(held, 0, "delay").strip())
        title = "Configure Harness: retries"
    else:
        ask("HARNESS_PARALLEL_TOOL_CALLS", wizardAnswer(held, 0, "parallel"))
        title = "Configure Harness: protocol"
    return title, ["--manager-harness-apply"], "".join(lines)


def harnessApplyRetries(state, held):
    return harnessApplyCommon(state, held, "retries")


def harnessApplyProtocol(state, held):
    return harnessApplyCommon(state, held, "protocol")


## ---- the folder `Configure Harness` of the configuration ----

## The settings of the harness form two subjects, `Retries` and `Protocol`, each a row of this
## folder by what its read gives (parseHarnessForms): it is one folder and not two, since the
## read is the one read of the three settings and no form owns a setting alone. Enter enters
## the folder and shows what each form holds now; `c` on the folder starts the retries form,
## and Enter on a form, like `c`, starts that form's wizard, which this file declares in the
## wizards registry of the configuration (wizardOfRow, and the `configure` command below,
## which names this folder's rows so that its key reaches them). Mounted after `Git Settings`
## and registered here, so that its folder stands after it and ahead of the folders of
## `.local` (Plugins.py).
registerPlugin({
    "name": "harness",
    "mount": "configuration",
    "root": {"id": "harness", "label": "Configure Harness"},
    "focus": {"harness": "harnessFocus"},
    "summaries": {"harness": {"lines": "harnessSummary"}},
    "reads": {
        ## The three settings as they stand, read on entering the folder and when it is asked
        ## for, never on the period: a form that opens says what the folder says, since this
        ## is the read the forms fill themselves from too (WIZARDS).
        "list:harness": {"operation": ["--manager-harness-read"], "rows": "harness-forms", "once": True},
    },
})


## ---- the keys that start a wizard ----

## The wizard a row starts: the CLI service's on `CLI Presets and Tiers` of the configuration and on its lines, the git settings' on their folder and its lines.
def wizardOfRow(state, row):
    if row is None or row["kind"] == "up":
        return None
    here = pluginLevel("configuration")
    level = levelKey(state.path)
    if level == here + "/git" or (level == here and row["id"] == "git"):
        return "git-settings"
    if level == pluginLevel("clipresets") or (level == here and row["id"] == "clipresets"):
        return "cli-service"
    if level == pluginLevel("harness"):
        return {"retries": "harness-retries", "protocol": "harness-protocol"}.get(row["id"])
    if level == here and row["id"] == "harness":
        return "harness-retries"
    return None


def askWizard(state, row):
    name = wizardOfRow(state, row)
    return startWizard(state, name) if name else ""


ACTION_HANDLERS["wizard"] = askWizard
ACTION_FITS["wizard"] = lambda state, row: wizardOfRow(state, row) is not None
ACTION_REFUSALS["wizard"] = lambda state, row: "it has no wizard"


## `Auto-select CLI...` (F13.4), on `CLI Presets and Tiers` in the configuration, where the wizard of the CLI service is: it runs the owner's check of which vendor CLI works here, in the big output dialog
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
        "a key this account trusts is read-only: it is not made, replaced or removed here" if keyTrustedKey(row)
        else "a host key of the server is the system's: it is not made, replaced or removed here" if row and row.get("serverKey") and not keyMine(row)
        else "there is no key to replace or remove there: it is generated" if what != "generate" else "the key is there already: it is replaced"))(keyWhat)


## The keys this account trusts, which the wizards add and remove in its authorized keys: the group `trusted` of the list
## is where a key is added, and a key of it is where one is removed. The account's own keys and the host keys are not.
def keyTrustedGroup(row):
    return bool(row and row.get("keyGroup")) and row["keyGroup"]["key"] == "trusted"


def keyTrustedKey(row):
    held = row.get("serverKey") if row else None
    return held is not None and held["key"].startswith("trusted-")


def askKeyTrustAdd(state, row):
    group = row["keyGroup"] if row else None
    return startWizard(state, "server-key-trust-add", {"key": "trusted", "label": group["label"] if group else "Keys We Trust"})


def askKeyTrustDelete(state, row):
    held = row["serverKey"]
    return startWizard(state, "server-key-trust-delete", {"key": held["key"], "label": unspaced(held["label"]) or held["key"], "file": absent(held["file"])})


ACTION_HANDLERS["keytrustadd"] = askKeyTrustAdd
ACTION_FITS["keytrustadd"] = lambda state, row: keyTrustedGroup(row)
ACTION_REFUSALS["keytrustadd"] = lambda state, row: "this is not the keys we trust"

ACTION_HANDLERS["keytrustdelete"] = askKeyTrustDelete
ACTION_FITS["keytrustdelete"] = lambda state, row: keyTrustedKey(row)
ACTION_REFUSALS["keytrustdelete"] = lambda state, row: "this is not a key we trust"


## ---- the plugin: the wizards ----

registerPlugin({
    "name": "wizards",
    "integrates": {"configuration": {"wizards": (
        {"name": "harness-retries", "title": "Configure Harness: retries", "read": ["--manager-harness-read"], "parse": "parseHarnessSettings",
         "steps": ("harnessStepRetries",), "apply": "harnessApplyRetries"},
        {"name": "harness-protocol", "title": "Configure Harness: protocol", "read": ["--manager-harness-read"], "parse": "parseHarnessSettings",
         "steps": ("harnessStepProtocol",), "apply": "harnessApplyProtocol"},
        {"name": "cli-service", "title": "Configure CLI Service", "read": ["--manager-wizard-read", "cli-service"], "parse": "parseCliWizard",
         "steps": ("cliStepServiceFields", "cliStepServiceCredentials"), "apply": "cliApplyService"},
        {"name": "cli-service-universal", "title": "Configure CLI Service: universal", "read": ["--manager-wizard-read", "cli-service"], "parse": "parseCliWizard",
         "steps": ("cliStepUniversalFields", "cliStepUniversalCredential"), "apply": "cliApplyUniversal"},
        {"name": "cli-service-extend", "title": "Configure CLI Service: extending", "read": ["--manager-wizard-read", "cli-service"], "parse": "parseCliWizard",
         "steps": ("cliStepExtendFields",), "apply": "cliApplyExtend"},
        {"name": "git-settings", "title": "Configure Git Settings", "read": ["--manager-wizard-read", "git-settings"], "parse": "parseGitWizard",
         "steps": ("gitStepSettings",), "apply": "gitApply"},
        {"name": "server-key-generate", "title": "Generate Server Key", "steps": ("keyStepGenerate",), "apply": "keyApplyGenerate"},
        {"name": "server-key-regenerate", "title": "Regenerate Server Key", "steps": ("keyStepRegenerate",), "apply": "keyApplyRegenerate"},
        {"name": "server-key-delete", "title": "Delete Server Key", "steps": ("keyStepDelete",), "apply": "keyApplyDelete"},
        {"name": "server-key-trust-add", "title": "Add Trusted Key", "steps": ("keyTrustAddStep",), "apply": "keyTrustAddApply"},
        {"name": "server-key-trust-delete", "title": "Delete Trusted Key", "steps": ("keyTrustDeleteStep",), "apply": "keyTrustDeleteApply"},
    )}},
    "reads": {
        ## What the form of a wizard needs, read when its dialog waits for it by the name of the wizard, and never before.
        WIZARD_READ: {"operation": ["--manager-wizard-read", "{id}"], "rows": "wizard-read", "kind": "plan", "demand": True},
    },
    "commands": (
        {"name": "configure", "keys": ("c",), "menu": ("view", 3), "label": "~C~onfigure", "status": "Configure", "window": "list",
         "views": ("@configuration", "@clipresets", "@configuration/git", "@configuration/harness"),
         "for": "a feature that is configured by a wizard", "on": ("@configuration:record", "@configuration:section", "@clipresets:section", "@configuration/git:record", "@configuration/harness:harness-form"),
         "only": True, "says": "configure", "does": ("action", "wizard")},
        {"name": "cliauto", "keys": ("s",), "menu": ("view", 3), "label": "Auto-~s~elect CLI...", "status": "Auto-select", "window": "list",
         "views": ("@configuration", "@clipresets"),
         "for": "the CLI presets", "on": ("@configuration:section", "@clipresets:section"),
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
        {"name": "keytrustadd", "keys": ("A",), "menu": ("view", 3), "label": "~A~dd a key to trust", "status": "Add", "window": "list",
         "views": ("@configuration/keys",), "for": "the keys we trust", "on": ("@configuration/keys:group",), "only": True, "says": "add",
         "does": ("action", "keytrustadd")},
        {"name": "keytrustdelete", "keys": ("D",), "menu": ("view", 3), "label": "~D~elete the trusted key", "status": "Delete", "window": "list",
         "views": ("@configuration/keys",), "for": "a key we trust", "on": ("@configuration/keys:record",), "only": True, "says": "delete",
         "does": ("action", "keytrustdelete")},
    ),
})
