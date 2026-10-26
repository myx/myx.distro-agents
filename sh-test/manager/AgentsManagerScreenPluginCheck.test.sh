#!/usr/bin/env bash
## Behavioural check on the plugin mechanism of the console app (F11.2 of the refactorings epic), run rather than read. The screen's own
## code (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py);
## no reader is started, the rows are put in the state as a read would put them. A stand-in app feature, a plugin of the rig's own, is
## registered into the screen the way every real one registers itself.
## Held (F11.2: "An app feature may implement its own root selection item in the selector pane, provide sub-items under it, update the top
## menu and status bar keys based on the current selection, and integrate into well-defined registries of other features where those
## features are available"; the scale note: "Level paths are strings used by FIXED_ROWS, SUMMARIES, MARKDOWN_ON, MARKDOWN_HELP and every
## action's views list"; the Settled paragraph: "buttons work whatever pane has the focus, so no TAB is needed to reach wrap or nowrap;
## the views keep their keys from clashing"):
##   1. its own root selection item: a registered plugin with a root has its row in the root list, its item in the Go menu, and its group
##   2. sub-items under it: its fixed rows stand under its root, and under a folder of its own
##   3. what the left window shows of its folder is made by the plugin's own function (its summary)
##   4. the top menu and the status line follow the selection: the plugin's command stands in its menu and names its key in the status line
##      only while a row it acts on is selected, runs by its key, and is in no menu and no status line elsewhere
##   5. the registries of other features: what it puts in the registry of the Markdown view stands there, and the mode keys of a text
##      apply at that place; where the feature or the registry is not there nothing is put anywhere and the build says so, and the entries
##      stand there once the feature registers
##   6. level paths: a plugin mounted under another has every path of its declaration under the other's root, in FIXED_ROWS, SUMMARIES,
##      READS, MARKDOWN_ON, MARKDOWN_HELP and the views of its commands; the same declaration mounted at the root has them without the
##      prefix, and nothing else differs; a mount that names no plugin leaves it out until that one registers
##   7. buttons: every command of a view that a menu and the status line name works whichever window has the keys, the wrap and the cut of the
##      long lines of the left window (w) among them, and the status line names it in both; a key of navigation (Enter, the arrows, paging)
##      stays with the window that has the keys
##   8. the views keep their keys: no two commands of one view and one window share a key with nothing to tell them apart (the screen as it
##      is, and with the plugin of the rig); a plugin whose command clashes is refused with an error naming both, and the registries stay
##      as they were; a name registered twice is refused
##   9. every app feature of the screen is such a plugin: the ten roots are registered by their own parts, and no part declares a root,
##      a fixed row or a summary of its own outside its plugin
## Red before F11.2: no plugin mechanism, the roots declared in the tables of Roots.py, wrap the left window's alone.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.4: the Dashboard is registered by the part of the local tools, LocalManagerScreen.Dashboard.py.
## Reconciled for F11.5: the plugins now include magic-team, activity and launch, with Pending Questions second after the Dashboard and standing at
## the root alone (20261021-refactorings.sketch.md, `Magic-Team` -> `Reorder`), and each is registered by its own part. The stand-in button takes
## `q`: the screen's own glance key `e` (full-table) is a command of every level, and a plugin may not take a key its view already has.
## Reconciled for the groups of the roots (owner, 2026-10-20): the stand-in root of the group `team` stands with Magic-Team (Agents); the Dashboard is in a group with Pending Questions.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigScreen="$rigPackage/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenPluginCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

cat > "$rigTmp/probe.py" <<'RIGPROBE'
import importlib.util, sys, os, traceback

screenFile, driverFile, packageRoot = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("rigdriver", driverFile)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
screen = driver.loadScreen(screenFile)


def say(name, value):
    print("%s=%s" % (name, value))


def attempt(name, function):
    try:
        function()
    except Exception as failure:
        say(name + ".error", "%s: %s" % (type(failure).__name__, str(failure)[:160].replace("\n", " ")))


def session(columns=120, lines=30):
    state = screen.ManagerState("")
    surface = driver.TextSurface(columns, lines)

    def turn(*keys):
        for key in keys or (None,):
            screen.screenTurn(surface, state, None, 0.0, key)

    def statusLine():
        return "".join(surface.cells[surface.lines - 1]).rstrip()
    return state, surface, turn, statusLine


def selectRoot(state, rootId):
    rows = screen.levelRowsAt(state, [])
    state.path = []
    state.cursors[""] = {"key": "section:" + rootId, "index": [row["id"] for row in rows].index(rootId), "top": 0}


def selectRow(state, path, rowId):
    state.path = list(path)
    rows = screen.levelRows(state)
    index = [row["id"] for row in rows].index(rowId)
    state.cursors[screen.levelKey(path)] = {"key": screen.rowKey(rows[index]), "index": index, "top": 0}


def commandNames():
    return [command["name"] for command in screen.COMMANDS]


## ---- 9. the ten roots are plugins, declared by their own parts
def parts():
    names = [plugin["name"] for plugin in screen.PLUGIN_RECORDS]
    say("ten", " ".join(name for name in ("dashboard", "pending", "magic-team", "activity", "launch", "team", "teamdata", "places", "consoles", "settings", "configuration", "manuals") if name in names))
    say("sections", " ".join(sectionId for sectionId, label in screen.SECTIONS))
    owned = {"dashboard": "Dashboard", "activity": "Sessions", "launch": "Launch", "pending": "Pending", "magic-team": "MagicTeam", "team": "Members", "teamdata": "TeamData", "places": "Places",
             "consoles": "Consoles", "settings": "Settings", "configuration": "Configuration", "manuals": "Manuals"}
    registered = []
    for name, part in sorted(owned.items()):
        ## the Dashboard is the local tools' (F11.4), and so are the locations (F11.10): their parts stand in their package beside this one
        partFile = os.path.join(packageRoot, "..", "myx.distro-.local", "sh-lib", "manager", "LocalManagerScreen.%s.py" % part) if name in ("dashboard", "places") else os.path.join(packageRoot, "sh-lib", "manager", "AgentsManagerScreen.%s.py" % part)
        text = open(partFile, encoding="utf-8").read()
        registered.append("%s:%s" % (name, text.count('"name": "%s"' % name) == 1 and "registerPlugin(" in text))
    say("ownParts", " ".join(registered))
    roots = open(os.path.join(packageRoot, "sh-lib", "manager", "AgentsManagerScreen.Roots.py"), encoding="utf-8").read()
    windows = open(os.path.join(packageRoot, "sh-lib", "manager", "AgentsManagerScreen.Windows.py"), encoding="utf-8").read()
    say("noTables", " ".join(word for word in ("SECTIONS = (", "FIXED_ROWS = {", "SUMMARIES = {", "READS = {", "MARKDOWN_ON = (", "MARKDOWN_HELP = (", "GO_MORE = (")
                              if word in roots or word in windows) or "none")


attempt("parts", parts)

## ---- 8 (the screen as it is). the views keep their keys
attempt("clashBefore", lambda: say("clashBefore", "|".join(screen.keyClashes()) or "none"))

## ---- the stand-in app feature
screen.rigSummary = lambda state, path, row, form: ["rig summary of %s" % row["label"]]
screen.ACTION_HANDLERS["rigzed"] = lambda state, row: "zed on %s" % (row["id"] if row else "nothing")
screen.ACTION_HANDLERS["rigentered"] = lambda state, row: "entered %s" % (row["id"] if row else "nothing")
RIG = {
    "name": "rigfeature",
    "root": {"id": "rigroot", "label": "Rig Root", "go": "Rig ~R~oot", "group": "team"},
    "rows": {"rigroot": (("alpha", "Alpha Folder", "rigfolder", True),), "rigroot/alpha": (("beta", "Beta Item", "rigitem", False),)},
    "summaries": {"rigroot": {"lines": "rigSummary"}},
    "reads": {"list:rigroot": {"operation": ["--rig-list"], "rows": "records"}},
    "commands": ({"name": "rigzed", "keys": ("z",), "menu": ("question", 3), "label": "~Z~ed the rig", "status": "Zed",
                  "views": ("rigroot/alpha",), "for": "a rig item", "on": ("rigroot/alpha:rigitem",), "does": ("action", "rigzed")},),
    "integrates": {"markdown": {"on": ("rigroot/alpha:rigitem",)}},
}


def register():
    screen.registerPlugin(RIG)
    say("registered", "yes")


attempt("register", register)


## ---- 1, 2, 3. the root, its sub-items, its summary
def rootAndRows():
    state, surface, turn, statusLine = session()
    say("rootRow", "yes" if "rigroot" in [row["id"] for row in screen.levelRowsAt(state, [])] else "no")
    say("rootLabel", [row["label"] for row in screen.levelRowsAt(state, []) if row["id"] == "rigroot"][0])
    say("rootDives", [row["dive"] for row in screen.levelRowsAt(state, []) if row["id"] == "rigroot"][0])
    say("goItem", " ".join(command["label"] for command in screen.COMMANDS if command["does"] == ("go", ("rigroot",))))
    say("group", "yes" if any("rigroot" in group and "magic-team" in group for group in screen.SECTION_GROUPS) else "no")
    say("under", " ".join(row["id"] for row in screen.levelRowsAt(state, ["rigroot"])))
    say("underFolder", " ".join(row["id"] for row in screen.levelRowsAt(state, ["rigroot", "alpha"])))
    selectRoot(state, "rigroot")
    turn()
    say("summary", "|".join(state.view["lines"]))


attempt("rootAndRows", rootAndRows)


## ---- 4. the menu and the status line follow the selection
def followsSelection():
    state, surface, turn, statusLine = session()
    selectRoot(state, "manuals")
    turn()
    say("elsewhereStatus", "Zed" in statusLine())
    say("elsewhereMenu", "rigzed" in [command["name"] for command in screen.menuItems(state, "question") if command])
    say("elsewhereBar", "Question" in "".join(surface.cells[0]))
    selectRow(state, ["rigroot"], "alpha")
    turn()
    say("folderStatus", "Zed" in statusLine())
    selectRow(state, ["rigroot", "alpha"], "beta")
    turn()
    say("rowStatus", "Zed" in statusLine())
    say("rowMenu", "rigzed" in [command["name"] for command in screen.menuItems(state, "question") if command])
    say("rowBar", "Question" in "".join(surface.cells[0]))
    turn("z")
    say("ran", state.notice)
    selectRow(state, ["rigroot"], "alpha")
    turn()
    say("leftStatus", "Zed" in statusLine())


attempt("followsSelection", followsSelection)


## ---- 5. the registries of other features
def registries():
    state, surface, turn, statusLine = session()
    say("markdownOn", "yes" if "rigroot/alpha:rigitem" in screen.MARKDOWN_ON else "no")
    state.path = ["rigroot", "alpha"]
    modeRaw = screen.commandNamed("mode-raw")
    say("rawKeyThere", "yes" if screen.commandInView(state, modeRaw) else "no")
    state.path = ["manuals"]
    screen.registerPlugin({"name": "rigguest", "integrates": {"rigabsent": {"things": ("a", "b")}}})
    say("absentHeld", screen.pluginRegistry("rigabsent", "things"))
    say("absentSaid", "yes" if any("rigabsent.things" in note for note in screen.pluginNotes()) else "no")
    screen.registerPlugin({"name": "rigabsent", "registries": {"things": "plain"}})
    say("absentLater", screen.pluginRegistry("rigabsent", "things"))
    say("absentSaidAfter", "yes" if any("rigabsent.things" in note for note in screen.pluginNotes()) else "no")


attempt("registries", registries)


## ---- 6. level paths: mounting
def kid(name, mount):
    declaration = {
        "name": name,
        "root": {"id": "kid", "label": "Kid", "go": "~K~id", "group": "team"},
        "rows": {"kid": (("deep", "Deep", "kidfolder", True),)},
        "summaries": {"kid": {"lines": "rigSummary"}, "kid/deep": {"lines": "rigSummary"}},
        "reads": {"list:kid": {"operation": ["--kid-list"], "rows": "records"}, "view:kid/deep:kidrow": {"operation": ["--kid-read", "{id}"]},
                  "list:kid/*": {"from": "list:kid"}},
        "commands": ({"name": name + "-act", "keys": ("x",), "menu": ("view", 3), "label": "~X~ act", "status": "Act",
                      "views": ("kid", "kid/deep"), "on": ("kid:kidrow", "kid/deep:kidrow"), "only": True, "does": ("action", "rigzed")},),
        "integrates": {"markdown": {"on": ("kid/deep:item",), "help": ("kid:kid-help",)}},
    }
    if mount:
        declaration["mount"] = mount
    return declaration


def strip(text):
    return str(text).replace("rigroot/parent/", "")


def registered(kind):
    ## what the registries hold of the declaration of kid(), as its paths without the mount: mounted under a plugin (prefix) or at the root
    if kind == "mounted":
        rows = [strip(key) for key in screen.FIXED_ROWS if key.startswith("rigroot/parent/kid")]
        summaries = [strip(key) for key in screen.SUMMARIES if key.startswith("rigroot/parent/kid")]
        reads = [strip(key) + "=" + strip(screen.READS[key]) for key in screen.READS if "rigroot/parent/kid" in key]
        on = [strip(place) for place in screen.MARKDOWN_ON if place.startswith("rigroot/parent/kid")]
        helps = [strip(place) for place in screen.MARKDOWN_HELP if place.startswith("rigroot/parent/kid")]
        name = "rigkid-act"
    else:
        rows = [key for key in screen.FIXED_ROWS if key == "kid" or key.startswith("kid/")]
        summaries = [key for key in screen.SUMMARIES if key == "kid" or key.startswith("kid/")]
        reads = [key + "=" + str(screen.READS[key]) for key in screen.READS if key.partition(":")[2].startswith("kid")]
        on = [place for place in screen.MARKDOWN_ON if place.startswith("kid")]
        helps = [place for place in screen.MARKDOWN_HELP if place.startswith("kid")]
        name = "rigkid2-act"
    command = [command for command in screen.COMMANDS if command["name"] == name][0]
    views = [strip(path) for path in tuple(command["views"]) + tuple(command["on"])]
    return {"rows": sorted(rows), "summaries": sorted(summaries), "reads": sorted(reads), "markdownOn": sorted(on), "markdownHelp": sorted(helps), "views": sorted(views)}


def mounting():
    ## a mount that names no plugin: left out
    screen.registerPlugin(kid("rigkid", "rigparent"))
    say("unmounted", " ".join(screen.PLUGIN_UNMOUNTED))
    say("unmountedBuilt", any(key.startswith("rigparent") or key.endswith("/kid") for key in screen.FIXED_ROWS))
    screen.registerPlugin({"name": "rigparent", "mount": "rigfeature", "root": {"id": "parent", "label": "Parent", "group": "team"}})
    say("mountedAfter", " ".join(screen.PLUGIN_UNMOUNTED) or "none")
    say("parentRow", " ".join(row[0] for row in screen.FIXED_ROWS.get("rigroot", ())))
    mounted = registered("mounted")
    screen.registerPlugin(kid("rigkid2", None))
    plain = registered("plain")
    for name in mounted:
        say("mount." + name, "same" if mounted[name] == plain[name] and mounted[name] else "differs: %s / %s" % (mounted[name], plain[name]))
    say("mountCounts", " ".join("%s=%d" % (name, len(mounted[name])) for name in sorted(mounted)))
    state, surface, turn, statusLine = session()
    say("reachable", " ".join(row["id"] for row in screen.levelRowsAt(state, ["rigroot", "parent", "kid"])))


attempt("mounting", mounting)


## ---- 7. the buttons work whatever window has the keys
def buttons():
    state, surface, turn, statusLine = session()
    turn()
    say("focusFirst", state.focus)
    say("wrapFirst", "yes" if state.wrap else "no")
    say("statusBefore", "Cut" in statusLine())
    turn("w")
    say("wrapAfter", "yes" if state.wrap else "no")
    say("noRefusal", "other window" not in state.notice)
    say("statusAfter", "Wrap" in statusLine())
    turn("w")
    say("wrapBack", "yes" if state.wrap else "no")
    say("menuItem", "wrap" in [command["name"] for command in screen.menuItems(state, "view") if command and screen.commandApplies(state, command)])
    turn("TAB")
    say("focusView", state.focus)
    turn("w")
    say("wrapFromView", "yes" if state.wrap else "no")


attempt("buttons", buttons)


## ---- 7. every button of a view works whichever window has the keys; the keys of navigation stay with the window that has them
def anyButton():
    screen.registerPlugin({
        "name": "rigbutton", "root": {"id": "rigbutton", "label": "Rig Button", "group": "team"},
        "rows": {"rigbutton": (("r1", "Row One", "rigrow", False),)},
        "commands": (
            {"name": "rigbtn", "keys": ("q",), "menu": ("question", 3), "label": "R~q~ig button", "status": "Btn", "window": "list",
             "views": ("rigbutton",), "does": ("action", "rigzed")},
            {"name": "rigentry", "keys": ("ENTER",), "label": "Ent~r~y", "status": "Entry", "window": "list", "views": ("rigbutton",),
             "on": ("rigbutton:rigrow",), "only": True, "does": ("action", "rigentered")},
        ),
    })
    state, surface, turn, statusLine = session()
    selectRow(state, ["rigbutton"], "r1")
    turn("TAB")
    say("btnFocus", state.focus)
    say("btnStatusLeft", "q Btn" in statusLine())
    say("btnEntryStatusLeft", "Entry" in statusLine())
    turn("q")
    say("btnLeft", state.notice)
    state.notice = ""
    turn("ENTER")
    say("btnEnterLeft", "[%s]" % state.notice)
    turn("TAB", "ENTER")
    say("btnEnterList", "%s %s" % (state.focus, state.notice))
    state.notice = ""
    turn("q")
    say("btnList", state.notice)
    say("btnMenuLeft", "rigbtn" in [command["name"] for command in screen.menuItems(state, "question") if command and screen.commandApplies(state, command)])


attempt("anyButton", anyButton)


## ---- 8. the views keep their keys
def clashes():
    say("clashWith", "|".join(screen.keyClashes()) or "none")
    names = commandNames()
    records = len(screen.PLUGIN_RECORDS)
    clashing = {"name": "rigclash", "root": {"id": "rigclash", "label": "Rig Clash", "group": "team"},
                "commands": ({"name": "rigclashed", "keys": ("a",), "menu": ("view", 1), "label": "Cl~a~sh", "status": "Clash",
                              "views": ("rigclash",), "does": ("action", "rigzed")},)}
    try:
        screen.registerPlugin(clashing)
        say("refused", "no")
    except Exception as failure:
        say("refused", "%s" % type(failure).__name__)
        say("refusedNames", "yes" if "rigclashed" in str(failure) and "filter" in str(failure) else "no: %s" % str(failure)[:200])
    say("kept", "yes" if commandNames() == names and len(screen.PLUGIN_RECORDS) == records and "rigclash" not in screen.PLUGIN_BASES else "no")
    ## the layered form is no clash: its rows' own key, ahead of the generic one
    screen.registerPlugin({"name": "rigenter", "root": {"id": "rigenter", "label": "Rig Enter", "group": "team"},
                           "commands": ({"name": "rigentered", "keys": ("ENTER",), "label": "E~n~ter", "status": "Enter", "views": ("rigenter",),
                                         "on": ("rigenter:rigrow",), "only": True, "does": ("action", "rigzed")},)})
    say("layered", "yes" if "rigentered" in commandNames() else "no")
    try:
        screen.registerPlugin({"name": "rigfeature"})
        say("twice", "no")
    except Exception as failure:
        say("twice", type(failure).__name__)


attempt("clashes", clashes)
RIGPROBE
rigOut="$( "$rigPython" -I -B "$rigTmp/probe.py" "$rigScreen" "$rigDriver" "$rigPackage" 2>&1 )"
rigVal(){ ## name -- the value of the first `<name>=` line, or `-` where there is none
	local rigLine
	rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1 )"
	[ -n "$rigLine" ] || rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1\.error=/error: /p" | head -1 )"
	printf '%s\n' "${rigLine:--}"
}
rigErr(){ ## probe name -- the error a probe step ended with, or `none`
	local rigLine
	rigLine="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1\.error=//p" | head -1 )"
	printf '%s\n' "${rigLine:-none}"
}

echo "-- 1, 2, 3. the root, its sub-items, its summary --"
rigAssert "the stand-in feature registers itself (registerPlugin)" "$( rigErr register ) $( rigVal registered )" "none yes"
rigAssert "its own root selection item stands in the root list, labelled and entered into" "$( rigVal rootRow ) / $( rigVal rootLabel ) / $( rigVal rootDives ) / $( rigErr rootAndRows )" "yes / Rig Root / True / none"
rigAssert "its item of the Go menu is there, and its root is in the group of the work of the team" "$( rigVal goItem ) / $( rigVal group )" "Rig ~R~oot / yes"
rigAssert "sub-items stand under it, and under a folder of its own" "$( rigVal under ) / $( rigVal underFolder )" ".. alpha / .. beta"
rigAssert "what the left window shows of its folder is made by the plugin's own function" "$( rigVal summary )" "rig summary of Rig Root"

echo "-- 4. the menu and the status line follow the selection --"
rigAssert "elsewhere the plugin's key is in no menu, in no menu of the bar and in no status line" "$( rigVal elsewhereStatus ) / $( rigVal elsewhereMenu ) / $( rigVal elsewhereBar )" "False / False / False"
rigAssert "on a folder of the plugin, which is not a row its command acts on, the key is in no status line" "$( rigVal folderStatus ) / $( rigVal leftStatus )" "False / False"
rigAssert "on a row its command acts on, the status line names the key, and the bar has the menu that holds the command" "$( rigVal rowStatus ) / $( rigVal rowMenu ) / $( rigVal rowBar )" "True / True / True"
rigAssert "its key runs the plugin's action on that row" "$( rigVal ran )" "zed on beta"

echo "-- 5. the registries of other features --"
rigAssert "what the plugin puts in the registry of the Markdown view stands there, and the raw mode key applies at that level" "$( rigVal markdownOn ) / $( rigVal rawKeyThere ) / $( rigErr registries )" "yes / yes / none"
rigAssert "a registry no plugin offers gets nothing, and the build says so; the plugin is registered all the same" "$( rigVal absentHeld ) / $( rigVal absentSaid )" "[] / yes"
rigAssert "once the feature registers its registry, what was put for it stands there, and the build no longer says it was left out" "$( rigVal absentLater ) / $( rigVal absentSaidAfter )" "['a', 'b'] / no"

echo "-- 6. level paths: a mount moves every path with it --"
rigAssert "a mount that names no plugin leaves the plugin out, and it is built once that plugin registers" "$( rigVal unmounted ) / $( rigVal unmountedBuilt ) / $( rigVal mountedAfter )" "rigkid / False / none"
rigAssert "the mounted root is a sub-item of the plugin it stands under" "$( rigVal parentRow )" "alpha parent"
rigAssert "FIXED_ROWS, SUMMARIES, READS, MARKDOWN_ON, MARKDOWN_HELP and the views of its commands carry the mount, and are the paths of the same declaration at the root with the prefix, nothing else different" \
	"$( rigVal mount.rows ) / $( rigVal mount.summaries ) / $( rigVal mount.reads ) / $( rigVal mount.markdownOn ) / $( rigVal mount.markdownHelp ) / $( rigVal mount.views )" "same / same / same / same / same / same"
rigAssert "and each holds what the declaration says" "$( rigVal mountCounts )" "markdownHelp=1 markdownOn=1 reads=3 rows=1 summaries=2 views=4"
rigAssert "the level under the mount is reachable in the list" "$( rigVal reachable ) / $( rigErr mounting )" ".. deep / none"

echo "-- 7. buttons --"
rigAssert "with the list holding the keys the status line names the cut of the lines (w), and w cuts them" "$( rigVal focusFirst ) $( rigVal wrapFirst ) $( rigVal statusBefore ) $( rigVal wrapAfter )" "list yes True no"
rigAssert "no refusal about the other window, and the status line then names the wrap" "$( rigVal noRefusal ) $( rigVal statusAfter )" "True True"
rigAssert "w wraps them again, and the menu holds the command as one that applies" "$( rigVal wrapBack ) $( rigVal menuItem )" "yes True"
rigAssert "and from the left window it works as before" "$( rigVal focusView ) $( rigVal wrapFromView )" "view no"

rigAssert "every button works whichever window has the keys: a command of the list alone, with a key that is no key of navigation, is named in the status line and runs from the left window, and from the list" "$( rigVal btnFocus ) $( rigVal btnStatusLeft ) / $( rigVal btnLeft ) / $( rigVal btnList ) / $( rigVal btnMenuLeft ) / $( rigErr anyButton )" "view True / zed on r1 / zed on r1 / True / none"
rigAssert "a key of navigation stays with the window that has the keys: Enter in the left window does not run the list's command and the status line does not name it, in the list it runs" "$( rigVal btnEntryStatusLeft ) / $( rigVal btnEnterLeft ) / $( rigVal btnEnterList )" "False / [] / list entered r1"

echo "-- 8. the views keep their keys --"
rigAssert "no two commands of one view and one window share a key with nothing to tell them apart, in the screen as it is and with the plugins of the rig" "$( rigVal clashBefore ) / $( rigVal clashWith )" "none / none"
rigAssert "a plugin whose command takes the key of another in its view is refused with an error that names both" "$( rigVal refused ) $( rigVal refusedNames )" "PluginError yes"
rigAssert "and the registries stay as they were" "$( rigVal kept )" "yes"
rigAssert "a command that is only on rows of its own, with a key the generic command of the view has, is no clash" "$( rigVal layered )" "yes"
rigAssert "a name registered twice is refused" "$( rigVal twice )" "PluginError"

echo "-- 9. every app feature is a plugin --"
rigAssert "the features are registered as plugins: the roots in the order of the list, Pending Questions second after the Dashboard, and the plugins that stand under Magic-Team (Agents), Launchpad among them" "$( rigVal ten ) / $( rigVal sections | cut -d' ' -f1-10 )" "dashboard pending magic-team activity launch team teamdata places consoles settings configuration manuals / dashboard pending magic-team places consoles workspace machine settings configuration manuals"
rigAssert "each is registered by its own part, once" "$( rigVal ownParts )" "activity:True configuration:True consoles:True dashboard:True launch:True magic-team:True manuals:True pending:True places:True settings:True team:True teamdata:True"
rigAssert "no table of the roots, the rows, the summaries, the reads, the Markdown places or the Go levels is left in Roots.py or Windows.py" "$( rigVal noTables )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PLUGIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PLUGIN: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
