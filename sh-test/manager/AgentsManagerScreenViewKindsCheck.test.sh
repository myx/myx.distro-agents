#!/usr/bin/env bash
## Behavioural check on the view kinds of the console app (F11.3 of the refactorings epic), run rather than read. The screen's own code
## (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py); no reader is
## started. A stand-in app feature, a plugin of the rig's own, gives each of its rows a content of one kind by its focus handler, the way every real
## one does.
## Held (F11.3: "Content pane, left, these views: table, as now, plus a dashboard-like panel set; markdown, including tables; variable or
## parameter, as in settings: value, description, and more optional, a single-parameter view; a sequential content list of supported blocks in one
## panel view. The content pane, menu and key bindings update on the selector pane plugin's focus handler."):
##   1. the five kinds are registered: table, panels, markdown, parameter, sequence
##   2. a plugin's focus handler gives the content pane what a selected row shows, a spec of a kind: the table as a header and its rows, the panels as
##      boxes of figures, the Markdown rendered with its table, the parameter as its name, value, description and the rest it has, the sequence as its
##      blocks one after another in their order; another row, another content; a row the handler knows nothing of shows nothing of the plugin
##   3. the menu and the status line follow the focus: a command of the plugin for a row of one kind stands in the status line, and is a menu item that applies, on that row alone
##   4. every app feature gives its content through its focus handler: the ten plugins that show one declare it, and the left pane's chooser holds no
##      call of a feature's own function; the setting of the settings is a parameter
## Red before F11.3: no view kinds and no focus handlers, the left pane's content chosen by a chain of tests on the level and the row.
## Offline: no operation of the real tooling is called.
## Reconciled for F11.5: ten plugins show a content through their focus handler: Activity is one more.
## Reconciled for F11.7: three more: Scope Settings, Git Settings and Installed Subsystems.
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
rigTmp="$( rigTempDir AgentsManagerScreenViewKindsCheck )" || exit 1
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
import importlib.util, sys, os

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


def session(columns=130, lines=40):
    state = screen.ManagerState("")
    surface = driver.TextSurface(columns, lines)

    def turn(*keys):
        for key in keys or (None,):
            screen.screenTurn(surface, state, None, 0.0, key)

    def statusLine():
        return "".join(surface.cells[surface.lines - 1]).rstrip()

    def left():
        ## the lines of the left window, inside its frame
        box = screen.layoutOf(surface.columns, surface.lines, state.split)["boxes"]["view"]
        return ["".join(surface.cells[line][box[0] + 1:box[0] + box[2] - 1]).rstrip() for line in range(box[1] + 1, box[1] + box[3] - 1)]
    return state, surface, turn, statusLine, left


def selectRow(state, path, rowId):
    state.path = list(path)
    rows = screen.levelRows(state)
    index = [row["id"] for row in rows].index(rowId)
    state.cursors[screen.levelKey(path)] = {"key": screen.rowKey(rows[index]), "index": index, "top": 0}


attempt("kinds", lambda: say("kinds", " ".join(sorted(screen.VIEW_KINDS))))

SPECS = {
    "t": {"kind": "table", "heads": ("NAME", "KIND"), "rows": [["alpha", "first"], ["beta", "second"]]},
    "p": {"kind": "panels", "blocks": [{"key": "b1", "label": "Block One", "figures": [
        {"block": "b1", "key": "f1", "label": "Figure One", "value": "7", "unit": "-", "level": "ok", "share": "-"}]}]},
    "m": {"kind": "markdown", "text": "# Rig Title\n\nSome words here.\n\n| head a | head b |\n|---|---|\n| cell one | cell two |\n"},
    "v": {"kind": "parameter", "name": "alpha", "value": "seven", "description": "The first parameter, in words.", "more": [("key", "ALPHA_KEY"), ("saved in", "a file")]},
    "s": {"kind": "sequence", "blocks": [
        {"kind": "parameter", "name": "beta", "value": "8", "description": "Second."},
        {"kind": "table", "heads": ("COL",), "rows": [["row-in-sequence"]]}]},
}


def focus(state, row):
    return SPECS.get(row["id"])


screen.rigFocus = focus
screen.ACTION_HANDLERS["rigzed"] = lambda state, row: "zed on %s" % (row["id"] if row else "nothing")
RIG = {
    "name": "rigkinds",
    "root": {"id": "rigkinds", "label": "Rig Kinds", "go": "Rig ~K~inds", "group": "team"},
    "rows": {"rigkinds": (("t", "The table", "rigtable", False), ("p", "The panels", "rigpanels", False), ("m", "The markdown", "rigmarkdown", False),
                          ("v", "The parameter", "rigparam", False), ("s", "The sequence", "rigseq", False), ("x", "Nothing known", "rigother", False))},
    "focus": {"rigkinds": "rigFocus"},
    "commands": ({"name": "rigtabled", "keys": ("z",), "menu": ("question", 3), "label": "~Z~ed the table", "status": "Zed", "views": ("rigkinds",),
                  "for": "a table", "on": ("rigkinds:rigtable",), "does": ("action", "rigzed")},),
}
attempt("register", lambda: screen.registerPlugin(RIG))


def contents():
    state, surface, turn, statusLine, left = session()
    for rowId in ("t", "p", "m", "v", "s", "x"):
        selectRow(state, ["rigkinds"], rowId)
        turn()
        lines = left()
        text = "\n".join(lines)
        say("lines." + rowId, "|".join(line for line in lines if line))
        say("count." + rowId, len([line for line in lines if line]))
    selectRow(state, ["rigkinds"], "t")
    turn()
    lines = left()
    say("table", "%s" % (" ".join(lines[0].split()) if lines else ""))
    say("tableRows", " ".join(" ".join(line.split()) for line in lines if "alpha" in line or "beta" in line))
    selectRow(state, ["rigkinds"], "p")
    turn()
    text = "\n".join(left())
    say("panelsBox", "yes" if "Block One" in text and "Figure One" in text and "7" in text else "no")
    selectRow(state, ["rigkinds"], "m")
    turn()
    lines = left()
    text = "\n".join(lines)
    say("markdownRendered", "yes" if "Rig Title" in text and "# Rig Title" not in text else "no")
    say("markdownTable", "yes" if "cell one" in text and "cell two" in text and "head a" in text else "no")
    selectRow(state, ["rigkinds"], "v")
    turn()
    lines = [line for line in left() if line]
    say("paramHead", lines[0] if lines else "")
    text = "\n".join(lines)
    say("paramWords", "yes" if "The first parameter, in words." in text else "no")
    say("paramMore", " ".join(" ".join(line.split()) for line in lines if "ALPHA_KEY" in line or "saved in" in line))
    selectRow(state, ["rigkinds"], "s")
    turn()
    lines = left()
    text = "\n".join(lines)
    say("seqOrder", "yes" if 0 <= text.find("beta = 8") < text.find("COL") < text.find("row-in-sequence") else "no")
    at = [number for number, line in enumerate(lines) if "beta = 8" in line]
    blank = [number for number, line in enumerate(lines) if "COL" in line]
    say("seqApart", "yes" if at and blank and blank[0] - at[0] >= 3 else "no")


attempt("contents", contents)


def follows():
    state, surface, turn, statusLine, left = session()
    selectRow(state, ["rigkinds"], "x")
    turn()
    say("otherStatus", "Zed" in statusLine())
    selectRow(state, ["rigkinds"], "t")
    turn()
    say("tableStatus", "Zed" in statusLine())
    say("tableMenu", "rigtabled" in [command["name"] for command in screen.menuItems(state, "question") if command and screen.commandApplies(state, command)])
    selectRow(state, ["rigkinds"], "v")
    turn()
    say("paramStatus", "Zed" in statusLine())
    say("paramMenu", "rigtabled" in [command["name"] for command in screen.menuItems(state, "question") if command and screen.commandApplies(state, command)])


attempt("follows", follows)


def own():
    names = [plugin["name"] for plugin in screen.PLUGIN_RECORDS if plugin.get("focus")]
    say("focused", " ".join(sorted(name for name in names if name != "rigkinds")))
    pane = open(os.path.join(packageRoot, "sh-lib", "manager", "AgentsManagerScreen.Pane.py"), encoding="utf-8").read()
    start = pane.index("def localView(")
    chooser = pane[start:pane.index("\n\n\n", start)]
    calls = [word for word in ("sessionLines(", "runLines(", "askLines(", "routineLines(", "memberLines(", "settingLines(", "groupLines(", "checkLines(",
                               "serverKeyLines(", "keyGroupLines(", "startLines(", "blocksView(", "cleanupLines(", "placeLines(", "placeCommandLines(", "grantLines(",
                               "grantKindLines(") if word in chooser]
    say("chooserCalls", " ".join(calls) or "none")
    settings = open(os.path.join(packageRoot, "sh-lib", "manager", "AgentsManagerScreen.Settings.py"), encoding="utf-8").read()
    body = settings[settings.index("def settingLines("):]
    body = body[:body.index("\n\n\n")]
    say("settingIsParameter", "yes" if "parameterLines(" in body else "no")


attempt("own", own)
RIGPROBE
rigOut="$( "$rigPython" -I -B "$rigTmp/probe.py" "$rigScreen" "$rigDriver" "$rigPackage" 2>&1 )"
rigVal(){ ## name -- the value of the first `<name>=` line, or the error of that step
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

echo "-- 1. the kinds --"
rigAssert "the five view kinds are registered" "$( rigVal kinds )" "markdown panels parameter sequence table"
rigAssert "the plugin of the rig registers with its focus handler" "$( rigErr register ) / $( rigErr contents )" "none / none"

echo "-- 2. the content a focus handler gives --"
rigAssert "a table: its header, then its rows" "$( rigVal table ) / $( rigVal tableRows )" "NAME KIND / alpha first beta second"
rigAssert "panels: a box with its label and its figure" "$( rigVal panelsBox )" "yes"
rigAssert "a Markdown text: rendered, its heading no longer marked, its table drawn" "$( rigVal markdownRendered ) / $( rigVal markdownTable )" "yes / yes"
rigAssert "a parameter: its name and its value as the head, its description, and the rest it holds" "$( rigVal paramHead ) / $( rigVal paramWords ) / $( rigVal paramMore )" "alpha = seven / yes / key ALPHA_KEY saved in a file"
rigAssert "a sequence: its blocks one after another, in their order, set apart" "$( rigVal seqOrder ) / $( rigVal seqApart )" "yes / yes"
rigAssert "a row the handler gives nothing for shows nothing" "$( rigVal count.x )" "0"

echo "-- 3. the menu and the keys follow the focus --"
rigAssert "the plugin's command for a table stands in the menu and the status line on the row of the table alone" \
	"$( rigVal tableStatus ) $( rigVal tableMenu ) / $( rigVal paramStatus ) $( rigVal paramMenu ) / $( rigVal otherStatus )" "True True / False False / False"

echo "-- 4. every app feature gives its content through its focus handler --"
rigAssert "the thirteen plugins that show a content declare their focus handler" "$( rigVal focused )" "activity configuration consoles dashboard git pending pending-in-team places scopes settings subsystems team teamdata"
rigAssert "the chooser of the left pane calls no function of a feature's" "$( rigVal chooserCalls )" "none"
rigAssert "the setting of the settings is a parameter" "$( rigVal settingIsParameter )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN VIEW KINDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_VIEW_KINDS: OK (%d assertions, offline, stand-in terminal)\n' "$rigPassCount"
