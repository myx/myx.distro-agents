##
## AgentsManagerScreen.Menus.py -- the menus and the item the bar is on.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## ---- the menus ----

## The items of a menu in the view of now, in their order: the commands of that view
## COMMANDS places in it, group after group, and None where a line parts two groups.
def menuItems(state, menuName):
    listed = sorted((command for command in COMMANDS
                     if command.get("menu", ("",))[0] == menuName and commandInView(state, command)),
                    key=lambda command: command["menu"][1])
    items = []
    for command in listed:
        if items and items[-1]["menu"][1] != command["menu"][1]:
            items.append(None)
        items.append(command)
    return items


## The menus the bar holds in the view of now, each by its place in MENUS: those that
## hold a command of that view.
def menusShown(state):
    return [index for index, (menuName, label) in enumerate(MENUS) if menuItems(state, menuName)]


## The place in MENUS of the menu of the bar with that hot letter, or None.
def menuOfLetter(state, letter):
    for index in menusShown(state):
        if hotLetter(MENUS[index][1]) == letter.lower():
            return index
    return None


## Opens the pull-down of that menu, its bar on its first item.
def openMenu(state, index):
    state.menu = {"menu": index, "item": 0}


## One key while a menu is open. Left and Right go to the menu beside it in the bar, Up and Down move
## the bar, over the lines that part the groups, and around at the ends. Enter chooses the
## item the bar is on and the hot letter of an item chooses that one: the menu closes and
## the command is done, as its key would do it; an item that does not apply is not chosen,
## the menu stays open, and the status line says why (commandRefusal).
## Esc and F10 close the menu. The key that ends the screen ends it from here too.
def menuKey(state, key, layout):
    menu = state.menu
    items = menuItems(state, MENUS[menu["menu"]][0])
    if key in ("ESC", "F10"):
        state.menu = None
    elif key in ("LEFT", "RIGHT"):
        shown = menusShown(state)
        at = shown.index(menu["menu"]) if menu["menu"] in shown else 0
        openMenu(state, shown[(at + (1 if key == "RIGHT" else -1)) % len(shown)])
    elif key in ("UP", "DOWN"):
        step = 1 if key == "DOWN" else -1
        index = (menu["item"] + step) % len(items)
        while items[index] is None:
            index = (index + step) % len(items)
        menu["item"] = index
    elif key == "ENTER":
        chooseItem(state, items[menu["item"]], layout)
    elif key in commandKeys(commandNamed("exit")):
        state.quit = True
    elif key.startswith("ALT-"):
        if menuOfLetter(state, key[4:]) is not None:
            openMenu(state, menuOfLetter(state, key[4:]))
    elif len(key) == 1:
        for index, command in enumerate(items):
            if command is not None and hotLetter(command["label"]) == key.lower():
                menu["item"] = index
                chooseItem(state, command, layout)
                break


def chooseItem(state, command, layout):
    refusal = commandRefusal(state, command)
    if refusal:
        state.noticeOf = None
        state.notice = refusal
        return
    state.menu = None
    runCommand(state, command, layout)

