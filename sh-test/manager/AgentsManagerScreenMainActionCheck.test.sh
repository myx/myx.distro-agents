#!/usr/bin/env bash
## Check on the main action of an item (owner, 2026-10-20): where the selected item does not handle Enter itself, Enter runs the item's main action, one rule of the
## framework (mainActionOf, AgentsManagerScreen.Keys.py) and no rule of a view. The order: the action a command declares as main; else the first of edit, configure, change
## and open the item has; else any other action, one that destroys last (each of them asks for its confirmation, as it does by its own key); within a kind the first in the order
## of the commands, which is the status line's. An item that handles Enter itself is unchanged: it has no main action.
## Run on the screen's own code with the commands stood in, so that every order is measured: the words a command says, "main", "on". The screens that use it are checked by
## their own checks (Git Settings in AgentsManagerScreenWizardsCheck). Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
[ -f "$rigScreen" ] || { echo "⛔ ERROR: the screen is not at the origin: $rigScreen -- refusing to report a result" >&2 ; exit 1 ; }
rigPython="$( command -v python3 )" || { echo "⛔ ERROR: no python3 on PATH -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigResult="$( "$rigPython" -I -B - "$rigScreen" <<'RIGPY'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("S", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
def command(name, says, keys=("x",), **more):
    return dict({"name": name, "keys": keys, "says": says, "on": ("here:record",), "does": ("action", name), "status": name.capitalize()}, **more)
def mainOf(commands, enterHandled=None):
    m.COMMANDS = commands
    m.commandKeys = lambda one: one["keys"]
    m.commandInView = lambda state, one: True
    m.commandApplies = lambda state, one: True
    m.commandOfKey = lambda state, key: enterHandled
    chosen = m.mainActionOf(None)
    return chosen["name"] if chosen else "none"
print("only d", mainOf([command("delete", "delete", ("d",))]))
print("delete then configure", mainOf([command("delete", "delete", ("d",)), command("configure", "configure", ("c",))]))
print("regenerate, full, delete", mainOf([command("regenerate", "regenerate", ("R",)), command("full", "", ("f",)), command("delete", "delete", ("d",))]))
print("edit before configure before change", mainOf([command("change", "change"), command("configure", "configure"), command("edit", "edit")]))
print("two edits: the first", mainOf([command("a", "edit"), command("b", "edit")]))
print("declared main wins", mainOf([command("edit", "edit"), command("other", "run", main=True), command("delete", "delete")]))
print("delete only a heading: none", mainOf([]))
print("handled by its own Enter", mainOf([command("edit", "edit")], enterHandled={"name": "answer", "does": ("action", "answer")}))
print("enter is open itself", mainOf([command("delete", "delete")], enterHandled={"name": "open", "does": ("open",)}))
RIGPY
)"
rigGot(){ printf '%s\n' "$rigResult" | LC_ALL=C sed -n "s/^$1 //p" | head -1 ; }
rigAssert "an item with only d: Enter opens its delete (its confirmation, as d does)" "$( rigGot 'only d' )" "delete"
rigAssert "a configure before a delete, whatever the order they stand in" "$( rigGot 'delete then configure' )" "configure"
rigAssert "no edit, configure, change or open: any other action first (Full), the destructive ones after it, in their order" "$( rigGot 'regenerate, full, delete' )" "full"
rigAssert "edit, configure, change, open: in that order of kind, not of the commands" "$( rigGot 'edit before configure before change' )" "edit"
rigAssert "of one kind the first in the order of the commands, the status line's" "$( rigGot 'two edits: the first' )" "a"
rigAssert "an action a command declares as main wins over them all" "$( rigGot 'declared main wins' )" "other"
rigAssert "an item with no action has none: Enter does what it did" "$( rigGot 'delete only a heading: none' )" "none"
rigAssert "an item that handles Enter itself is unchanged: it has no main action" "$( rigGot 'handled by its own Enter' ) $( rigGot 'enter is open itself' )" "none delete"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MAIN ACTION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MAIN_ACTION: OK (%d assertions, offline)\n' "$rigPassCount"
