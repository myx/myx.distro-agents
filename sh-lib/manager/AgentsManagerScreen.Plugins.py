##
## AgentsManagerScreen.Plugins.py -- the plugin mechanism: how an app feature of the console puts itself on the screen, and into the registries of the others.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##
## An app feature (Sessions, Pending Questions, Team Members, Manuals, ...) is a plugin: one declaration, made by
## registerPlugin at the end of its own part, that says
##   - its own root selection item in the selector pane ("root"), or the item it stands as under another plugin's ("mount"),
##   - the sub-items under it ("rows"), what the left window shows of each folder ("summaries"), and what each level and view asks of the tooling ("reads"),
##   - the commands whose menu items and status keys follow the selection ("commands", each with the views and rows it belongs to),
##   - what it puts into the registries other features offer ("integrates"), and the registries it offers ("registries").
## The registries the rest of the screen reads, SECTIONS, FIXED_ROWS, SUMMARIES, READS, COMMANDS, ALPHABETICAL, MARKDOWN_ON, MARKDOWN_HELP and the
## others below, are built from the plugins registered and from the commands of the engine (ENGINE_COMMANDS), and from nothing
## else: a plugin is the one place its feature is declared in.
##
## LEVEL PATHS. A level of the list is a path of ids, root first, written `a/b/c` (`*` for the id of a record). Every path a
## plugin declares is written as it would be if the plugin stood at the root of the list, its own root id first: `sessions/launch`.
## Where the plugin is mounted under another (its "mount" names that plugin), the path of that plugin's root goes ahead of every
## one of them when the registries are built, in FIXED_ROWS, SUMMARIES, READS, MARKDOWN_ON, MARKDOWN_HELP and the views of every
## command alike, so a feature moves in the list by changing its "mount" and nothing else. `@name/rest` is the path
## `rest` below the root of the plugin of that name: how a plugin names a level of another; it is left out where that plugin is not registered.
##
## A declaration, every key but "name" optional:
##   "name"        the plugin, unique
##   "mount"       the name of the plugin whose root this one's root stands under; none: the root of the list
##   "root"        {"id", "label", "go": the item of the Go menu, hot letter between tildes, "group": of ROOT_GROUPS, "when": see SECTIONS_WHEN}
##   "rows"        {level: ((id, label, kind, dive), ...)} the rows the level always holds, ahead of its listed ones (FIXED_ROWS)
##   "summaries"   {level: {"lines": the function that makes the summary, ...}} (SUMMARIES)
##   "reads"       {read key: entry} (READS); the levels in a key and in "from" and "also" are paths as above
##   "commands"    ({command of COMMANDS}, ...) with its "views", "on" and "except" as paths as above; "window": the window it applies in alone;
##                 "after": the command it stands after in COMMANDS (default `exit`: ahead of the engine's own commands, which one that
##                 takes a key on a row of its own must precede); "with" / "exceptWith": ((feature, registry), ...), the views and
##                 rows the registries of other features add to its own, or take away
##   "go"          ({"name", "path", "label"}, ...) more levels with a command of the Go menu and a number key
##   "registries"  {registry: kind} what this feature offers others to put in: kind `place` (entries `level:kind`), `level` or `plain`
##   "integrates"  {feature: {registry: (entries, ...)}} what it puts there, where that feature offers that registry; else nothing is put
##                 anywhere, and the build says so in PLUGIN_NOTES
##
## A name registered twice, a root that is in no group, and a command whose key clashes with another's in a view (keyClashes) are refused
## by an error, and the registries stay as they were. A mount that names no plugin registered leaves the plugin out of the build
## until that one is (PLUGIN_UNMOUNTED).

class PluginError(Exception):
    pass


## The groups the roots of the list fall in, in their order: a spacer stands between two groups (spacersAt). A root names its group.
ROOT_GROUPS = ("team", "places", "setup", "manuals")

## The plugins as they were registered, in order.
PLUGIN_RECORDS = []
## What the last build made of them: the path of each plugin's root by its name, the ones whose mount names no plugin registered,
## and what it left out and why. The registries of the features, by feature and registry: what each offers (REGISTRY_KINDS) and what
## has been put in it (REGISTRIES). The keys of READS that the plugins put there.
PLUGIN_BASES = {}
PLUGIN_UNMOUNTED = []
PLUGIN_NOTES = []
REGISTRY_KINDS = {}
REGISTRIES = {}
PLUGIN_READ_KEYS = []
## The last build, whole, to go back to where a build is refused.
PLUGIN_BUILT = None
## Whether the parts are all loaded: only then can a build tell a clash of keys, which asks the parts that come after this one.
PLUGINS_READY = False

## The roots of the list, in order, each (id, label); the groups they fall in, in order, each the ids of its roots; the root that
## stands only where what it shows is there: by id, the function that says so from what was read ("shown"), and why its item of
## the `Go` menu does nothing where it is not ("says"). The roots that stand in the list now, in order, which are those
## SECTIONS_WHEN does not name until a turn of the screen has said which of the others are there too (noteRoots).
SECTIONS = []
SECTION_GROUPS = ()
SECTIONS_WHEN = {}
SECTIONS_NOW = []
## The rows a level always holds, ahead of the rows its operation gives: id, what it shows as, kind, whether Enter dives into it.
FIXED_ROWS = {}
## What the left window shows of a folder, a row that opens a level of its own, while that row is selected, made from its rows
## in a form of its kind, by the function "lines" names (folderSummary).
SUMMARIES = {}
## What each level of the list and each view of the left pane asks the tooling for: the operation with its arguments, as the
## dispatcher takes them, and under "active" what the `a` filter adds. None: no operation yet, the task of that level or view
## names it. A level below a record is named with `*` in the place of that record's id, and {level} in an argument is that id. A view
## is named by its level and the kind of the row that is selected there, and {id} in an argument is the id of that row. An entry
## with "always" is read whatever is shown, since a status line counts by it, and "kind" then names the kind it runs as, beside
## the one list and the one view that are shown. "rows" names the form of what a list operation prints (parseLevels). A level with
## "from" has no read of its own: the read named there fills it. Beside the "view" of a row, its facts, stands its "feed", its
## lines, read as a kind of its own; "log" is what `l` adds to it. "needs" names what a row must carry for the read to be made at
## all. "acts" is what can be done with a row, read as one more part of it (VIEW_PARTS). "once": it is read when it is asked for, and
## never again because its period has passed (startDueReads). "seldom": a list that is read whatever is shown is read once, when
## the screen starts; it is read again, on the period and when a read is asked for, only while it is the list shown (seldomNow).
## "peek": a list that is read also while its section is the row the root stands on, since the left window then shows that
## section from its rows (wantedReads). "also": the reads made beside the list of a level, by their keys, while that level is
## shown and while the folder that opens it has the focus, as a kind of their own. "demand": it is read only when its command asks
## for it ("demand" in COMMANDS), never because it was not read yet or its period has passed, and "said" is what the status line
## says of it then. {parent} in an argument is the id of the level above the level read: the member of a folder of a member.
## "each": a read that is made for every row of the level it is named by that carries what it "needs", by the id of that row;
## its key is its name and, after a `|`, that id (readEntry). The list of a level is read also while the row that opens that level
## is the row selected, a folder that has the focus, as it would be on entering it (focusReads): once the selection has rested on
## that row (REST_SECONDS), so a selection that runs down a list starts none, and one such read at a time, as the kind "focus",
## beside the list shown, and once for each time the selection comes to rest there: while it stays, the period reads that list no
## more, and coming back reads it again only when its period has passed since. "peek" is read with no rest, and on the period.
## One that is read on "demand" alone is never started by the focus: its command asks for it there too.
VIEW_PARTS = ("view", "feed", "acts")
READS = {"view::section": None}
## The commands of the engine, declared in Windows.py; COMMANDS is built from them and from every command of the plugins, in the
## order they stand in, with a command of the Go menu for each root. The levels, besides the roots, that have a number key and a
## command of the Go menu (the plugins' "go").
ENGINE_COMMANDS = ()
COMMANDS = []
GO_MORE = []
## The registries the engine's own features offer. `alphabetical`: the lists whose rows the user may have by name instead of in the
## order the operation gave them, by the key of the command "alphabetical" (orderedRows). `on` and `help` of the Markdown view: the
## places of the texts that are Markdown, drawn rendered: a text that a read shows as it is, of an item whose name ends in
## one of MARKDOWN "suffixes", and the places of the help of the tooling, which is Markdown too (markdownLines).
ALPHABETICAL = ()
MARKDOWN_ON = ()
MARKDOWN_HELP = ()


## The number keys that take the list to a level: the roots have theirs by the order of the root list as it is shown (SECTIONS,
## SECTIONS_NOW), the first root 1, and are so given again whenever a root is added, moved, or comes and goes, so a root that
## is not there leaves no gap and has none (commandKeys asks at every lookup); the levels GO_MORE names, under a root, have the
## numbers after the last root, in its order. With each number, Alt with it. Nine numbers there are: what stands after the
## ninth has none, and is reached by its menu.
def goKeys(path):
    shown = [(sectionId,) for sectionId in SECTIONS_NOW] + list(GO_MORE)
    if tuple(path) not in shown:
        return ()
    number = shown.index(tuple(path)) + 1
    return (str(number), "ALT-%d" % number) if number <= 9 else ()


## The level, as the path `a/b/c` the registries and the state know it by, of a plugin's root, or of what is below it: `below` is
## written from the root down, `*/sessions`. None where no plugin of that name is registered.
def pluginLevel(name, below=""):
    base = PLUGIN_BASES.get(name)
    if base is None:
        return None
    return "/".join(list(base) + ([below] if below else []))


## The same as the list of the steps of the path.
def pluginPath(name, below=""):
    level = pluginLevel(name, below)
    return None if level is None else level.split("/")


## The rows the last good read of a plugin's level gave, or none where the plugin is not there.
def pluginRows(state, name, below=""):
    level = pluginLevel(name, below)
    return state.rows.get(level, ()) if level is not None else ()


## The plugin whose root a path is at or under, the deepest such one, and the steps of the path below that root: (None, the path)
## where it is at no plugin's root.
def pluginAt(path):
    path = list(path)
    best = None
    for name, base in PLUGIN_BASES.items():
        if base and path[:len(base)] == list(base) and (best is None or len(base) > len(PLUGIN_BASES[best])):
            best = name
    return (best, path[len(PLUGIN_BASES[best]):]) if best else (None, path)


## What the registry of a feature holds now, in the order it was put in: nothing where the feature or the registry is not there.
def pluginRegistry(feature, registry):
    return list(REGISTRIES.get((feature, registry), ()))


## Why a build left something out, one line each, in the order it did.
def pluginNotes():
    return list(PLUGIN_NOTES)


## A path a plugin declared, as the registries name it: below its mount; `@name/rest` as the rest below the root of that plugin,
## None where it is not registered.
def pluginPathOf(steps, text, bases):
    if text.startswith("@"):
        other, slash, rest = text[1:].partition("/")
        if other not in bases:
            return None
        return "/".join(list(bases[other]) + (rest.split("/") if rest else []))
    return "/".join(list(steps) + text.split("/")) if text else ""


## A place, `level:kind`, as the registries name it.
def pluginPlaceOf(steps, text, bases):
    level, colon, kind = text.partition(":")
    expanded = pluginPathOf(steps, level, bases)
    return None if expanded is None else expanded + colon + kind


## A key of READS, with its level as the registries name it. A key that names no level (`full:key`, `plan:kill:session`) stands as it is.
def pluginReadKeyOf(steps, key, bases):
    kind, colon, rest = key.partition(":")
    if kind in ("list", "each"):
        level = pluginPathOf(steps, rest, bases)
        return None if level is None else kind + colon + level
    if kind in ("view", "feed", "acts") and rest.partition(":")[0]:
        place = pluginPlaceOf(steps, rest, bases)
        return None if place is None else kind + colon + place
    return key


## The plugins in the order they are built in: in the order registered, a plugin after the one it is mounted under; and the path of each
## plugin's root, and of the level its declarations are written under.
def pluginsOrdered():
    ordered = []
    bases = {}
    steps = {}
    waiting = list(PLUGIN_RECORDS)
    progressed = True
    while waiting and progressed:
        progressed = False
        for plugin in list(waiting):
            mount = plugin.get("mount")
            if mount is not None and mount not in bases:
                continue
            steps[plugin["name"]] = tuple(bases[mount]) if mount is not None else ()
            bases[plugin["name"]] = steps[plugin["name"]] + ((plugin["root"]["id"],) if plugin.get("root") else ())
            ordered.append(plugin)
            waiting.remove(plugin)
            progressed = True
    return ordered, bases, steps, [plugin["name"] for plugin in waiting]


## Everything the plugins declare, built into the registries from scratch: the roots and their groups, the rows, the summaries, the
## reads, the commands and the registries of the features. A path of another plugin that is not registered, and a registry that
## no plugin offers, leave what names them out of the build and are said in PLUGIN_NOTES.
def pluginsBuilt():
    ordered, bases, stepsOf, unmounted = pluginsOrdered()
    built = {"bases": bases, "unmounted": unmounted, "notes": [], "sections": [], "groups": dict((group, []) for group in ROOT_GROUPS),
             "when": {}, "rows": {}, "summaries": {}, "reads": {}, "goMore": [], "registries": {}, "kinds": {}}
    notes = built["notes"]
    kinds = built["kinds"]
    for plugin in ordered:
        for registry, kind in plugin.get("registries", {}).items():
            kinds[(plugin["name"], registry)] = kind
    registries = built["registries"] = dict(((feature, registry), []) for feature, registry in kinds)
    goCommands = []
    goMore = []
    for plugin in ordered:
        name = plugin["name"]
        steps = stepsOf[name]
        root = plugin.get("root")
        if root:
            if not steps:
                built["sections"].append((root["id"], root["label"]))
                if root.get("group") not in built["groups"]:
                    raise PluginError("plugin %s: the root %s is in no group of ROOT_GROUPS (%s)" % (name, root["id"], ", ".join(ROOT_GROUPS)))
                built["groups"][root["group"]].append(root["id"])
                if root.get("when"):
                    built["when"][root["id"]] = root["when"]
            else:
                built["rows"]["/".join(steps)] = built["rows"].get("/".join(steps), ()) + ((root["id"], root["label"], "section", True),)
            if root.get("go"):
                goCommands.append({"name": root["id"], "keys": (), "menu": ("go", 1), "label": root["go"], "does": ("go", tuple(bases[name]))})
        for level, rows in plugin.get("rows", {}).items():
            path = pluginPathOf(steps, level, bases)
            if path is not None:
                built["rows"][path] = built["rows"].get(path, ()) + tuple(rows)
        for level, form in plugin.get("summaries", {}).items():
            path = pluginPathOf(steps, level, bases)
            if path is not None:
                ## the level whose read gave the chapters of a help is a path too
                built["summaries"][path] = dict(form, chapters=pluginPathOf(steps, form["chapters"], bases)) if "chapters" in form else form
        for key, entry in plugin.get("reads", {}).items():
            readKey = pluginReadKeyOf(steps, key, bases)
            if readKey is None:
                notes.append("plugin %s: the read %s names a plugin that is not registered" % (name, key))
                continue
            if entry is not None:
                entry = dict(entry)
                if "from" in entry:
                    entry["from"] = pluginReadKeyOf(steps, entry["from"], bases)
                if "also" in entry:
                    entry["also"] = tuple(found for found in (pluginReadKeyOf(steps, also, bases) for also in entry["also"]) if found is not None)
            built["reads"][readKey] = entry
        for command in plugin.get("go", ()):
            path = pluginPathOf(steps, command["path"], bases)
            if path is not None:
                goMore.append({"name": command["name"], "keys": (), "menu": ("go", 2), "label": command["label"],
                               "does": ("go", tuple(path.split("/")))})
        for feature, held in plugin.get("integrates", {}).items():
            for registry, entries in held.items():
                kind = kinds.get((feature, registry))
                if kind is None:
                    notes.append("plugin %s: %s.%s is offered by no plugin registered, nothing is put in it" % (name, feature, registry))
                    continue
                for entry in entries:
                    found = pluginPlaceOf(steps, entry, bases) if kind == "place" else pluginPathOf(steps, entry, bases) if kind == "level" else entry
                    if found is not None:
                        registries[(feature, registry)].append(found)
    built["goMore"] = [command["does"][1] for command in goMore]
    added = []
    for plugin in ordered:
        for command in plugin.get("commands", ()):
            made = dict(command)
            for field in ("views", "except"):
                if field in command:
                    made[field] = tuple(found for found in (pluginPathOf(stepsOf[plugin["name"]], level, bases) for level in command[field]) if found is not None)
            if "on" in command:
                made["on"] = tuple(found for found in (pluginPlaceOf(stepsOf[plugin["name"]], place, bases) for place in command["on"]) if found is not None)
            added.append(made)
    engine = [dict(command) for command in ENGINE_COMMANDS]
    for command in engine + added:
        for feature, registry in command.pop("with", ()):
            if (feature, registry) in kinds:
                held = registries[(feature, registry)]
                command["views"] = tuple(command.get("views", ())) + tuple(entry.partition(":")[0] for entry in held)
                if kinds[(feature, registry)] == "place":
                    command["on"] = tuple(command.get("on", ())) + tuple(held)
        for feature, registry in command.pop("exceptWith", ()):
            command["except"] = tuple(command.get("except", ())) + tuple(registries.get((feature, registry), ()))
    commands = engine
    standing = {}
    for command in added:
        anchor = command.pop("after", "exit")
        behind = standing.get(anchor, anchor)
        position = next((index for index, held in enumerate(commands) if held["name"] == behind), len(commands) - 1)
        commands.insert(position + 1, command)
        standing[anchor] = command["name"]
    place = next((index for index, held in enumerate(commands) if held["name"] == "line-up"), len(commands))
    commands[place:place] = goCommands + goMore
    built["commands"] = commands
    return built


## Puts a build in the registries: the objects that other parts hold stay the same ones, changed in place.
def pluginsApplied(built):
    global SECTION_GROUPS, ALPHABETICAL, MARKDOWN_ON, MARKDOWN_HELP, PLUGIN_BUILT
    SECTIONS[:] = built["sections"]
    SECTION_GROUPS = tuple(tuple(built["groups"][group]) for group in ROOT_GROUPS if built["groups"][group])
    SECTIONS_WHEN.clear()
    SECTIONS_WHEN.update(built["when"])
    FIXED_ROWS.clear()
    FIXED_ROWS.update(built["rows"])
    SUMMARIES.clear()
    SUMMARIES.update(built["summaries"])
    ## a read a test set on the screen stands, until a plugin that names it is registered
    for key in PLUGIN_READ_KEYS:
        READS.pop(key, None)
    PLUGIN_READ_KEYS[:] = list(built["reads"])
    READS.update(built["reads"])
    GO_MORE[:] = built["goMore"]
    COMMANDS[:] = built["commands"]
    PLUGIN_BASES.clear()
    PLUGIN_BASES.update(built["bases"])
    PLUGIN_UNMOUNTED[:] = built["unmounted"]
    PLUGIN_NOTES[:] = built["notes"]
    REGISTRY_KINDS.clear()
    REGISTRY_KINDS.update(built["kinds"])
    REGISTRIES.clear()
    REGISTRIES.update(built["registries"])
    SECTIONS_NOW[:] = [sectionId for sectionId, sectionLabel in SECTIONS if sectionId not in SECTIONS_WHEN]
    ALPHABETICAL = tuple(REGISTRIES.get(("list", "alphabetical"), ()))
    MARKDOWN_ON = tuple(REGISTRIES.get(("markdown", "on"), ()))
    MARKDOWN_HELP = tuple(REGISTRIES.get(("markdown", "help"), ()))
    for command in COMMANDS:
        if command["does"][0] == "go":
            command["keys"] = goKeys(command["does"][1])
    PLUGIN_BUILT = built


## A plugin registered: put in the registries at once. A name registered twice is refused, and so is a plugin whose command clashes
## with another's (keyClashes): the registries stay as they were.
def registerPlugin(plugin):
    if not plugin.get("name"):
        raise PluginError("a plugin has a name")
    if any(record["name"] == plugin["name"] for record in PLUGIN_RECORDS):
        raise PluginError("plugin %s is registered already" % plugin["name"])
    PLUGIN_RECORDS.append(plugin)
    try:
        before = PLUGIN_BUILT
        pluginsApplied(pluginsBuilt())
        clashes = keyClashes() if PLUGINS_READY else []
        if clashes:
            if before is not None:
                pluginsApplied(before)
            raise PluginError("plugin %s: %s" % (plugin["name"], "; ".join(clashes)))
    except PluginError:
        PLUGIN_RECORDS.remove(plugin)
        raise


## The parts are all loaded: from here a build asks for the clash of keys, and the first one does (AgentsManagerScreen.py).
def pluginsReady():
    global PLUGINS_READY
    PLUGINS_READY = True
    clashes = keyClashes()
    if clashes:
        raise PluginError("; ".join(clashes))


## ---- the keys of the views do not clash ----

## The key two commands take together in one view and one window with nothing to tell which is meant, or None. A command that is
## `only` on some rows takes its key on those rows alone and gives it to a generic command elsewhere, which is layering and no clash;
## two that are `only` clash where their rows are the same; a command that `tells` or `asks` is told from the other by what its
## action acts on as it is now (ACTION_FITS).
def commandsClash(first, second, levels):
    shared = set(commandKeys(first)) & set(commandKeys(second))
    if not shared:
        return None
    windows = (commandWindow(first), commandWindow(second))
    ## a key of navigation is the window's that has the keys; any other is a button of every window
    shared = set(key for key in shared if key not in NAVIGATION_KEYS or windows[0] is None or windows[1] is None or windows[0] == windows[1])
    if not shared:
        return None
    if first.get("tells") or second.get("tells") or first.get("asks") or second.get("asks"):
        return None
    if bool(first.get("only")) != bool(second.get("only")):
        return None
    if first.get("only") and not set(first["on"]) & set(second["on"]):
        return None
    if not commandLevelsOf(first, levels) & commandLevelsOf(second, levels):
        return None
    return sorted(shared)[0]


## Every level a command could be at: those the list has and those a command names.
def commandLevels():
    levels = set([""]) | set(FIXED_ROWS) | set(sectionId for sectionId, sectionLabel in SECTIONS)
    for command in COMMANDS:
        levels.update(command.get("views", ()))
        levels.update(command.get("except", ()))
    return levels


## The levels a command belongs to: those it names, else every one, but those it takes out.
def commandLevelsOf(command, levels):
    return (set(command["views"]) if "views" in command else set(levels)) - set(command.get("except", ()))


## One line for each pair of commands of COMMANDS that clash; none where the views keep their keys.
def keyClashes():
    found = []
    levels = commandLevels()
    for index, first in enumerate(COMMANDS):
        for second in COMMANDS[index + 1:]:
            key = commandsClash(first, second, levels)
            if key is not None:
                where = sorted(commandLevelsOf(first, levels) & commandLevelsOf(second, levels))
                found.append("the commands %s and %s both take the key %s at %s" % (first["name"], second["name"], key, where[0] if where else "every level"))
    return found
