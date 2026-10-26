#!/usr/bin/env bash
## Behavioural check on basic `less` paging and on the mouse setting of the manager screen (F11.0 of the refactorings epic), run rather
## than read. The screen's own code (sh-lib/manager/AgentsManagerScreen.py) runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls the stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which prints the case's fixture.
## Held:
##   1. the keys: Space and PgDn page down, PgUp pages up, Home and End go to the top and to the bottom, the arrows move a line; each
##      key is declared once, in the commands of the screen, and no key the pane already had is taken (b, l, g, v and the others keep
##      their commands); the terminal's Home and End keys are the screen's HOME and END, as its PgUp and PgDn are
##   2. in the left window, whatever it shows that scrolls: a long Markdown text, and a table of more rows than the window holds
##      (the table view): Space pages as PgDn does, PgUp pages back, End is the bottom, Home the top, a line a time by the arrows;
##      none of them changes the mode of the text; the keys of the screen's key help name them
##   3. in the list on the right, as the left window has them: Space pages the selection down as PgDn does, Home is its first row and
##      End its last
##   4. the mouse is on unless MDLT_MANAGER_MOUSE says `disable`, the console user's setting of .local beside MDLT_MANAGER_SPACERS: the
##      screen then asks the terminal to report none, so the terminal's own selection copies text; it is asked to report none whenever
##      the terminal is another's, whatever the setting says
## Red before F11.0's paging and mouse lines: Space, Home and End are no key of the screen, and the mouse is always reported.
## Offline: the only thing the screen calls here is the stand-in for the dispatcher.
## Reconciled for F11.5: the list of the sessions is Active Sessions of Activity, and Team Members is put at with `at @team`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenPagingCheck )" || exit 1
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

## What the screen module itself says of its keys and of the mouse: `<name>=<value>` a line.
cat > "$rigTmp/probe.py" <<'RIGPROBE'
import curses, importlib.util, os, sys, types
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec) ; spec.loader.exec_module(screen)


def say(name, value):
    print("%s=%s" % (name, value))


## 1. who has each key in the pane where the keys of the left window act: the folder of a participant's transcript. A key another
## feature takes in a view of its own is no key of this pane, so the pane's keys are asked for where the pane binds them.
pane = screen.ManagerState("")
pane.path = ["magic-team", "activity", "active-sessions", "session-id", "run-id"]


def owners(key):
    return ",".join(command["name"] for command in screen.COMMANDS
                     if key in screen.commandKeys(command) and screen.commandInView(pane, command))


for label, key in (("space", " "), ("pgdn", "PGDN"), ("pgup", "PGUP"), ("home", "HOME"), ("end", "END"), ("up", "UP"), ("down", "DOWN"),
                   ("b", "b"), ("l", "l"), ("g", "g"), ("v", "v"), ("w", "w")):
    say("own." + label, owners(key))
## the terminal's keys by the names of the screen
names = screen.CURSES_KEYS if hasattr(screen, "CURSES_KEYS") else {}
say("curses", " ".join("%s:%s" % (word, names.get(code, "-")) for word, code in (
    ("PGUP", curses.KEY_PPAGE), ("PGDN", curses.KEY_NPAGE), ("HOME", curses.KEY_HOME), ("END", curses.KEY_END), ("UP", curses.KEY_UP))))
say("words", " ".join("%s=%s" % (key, screen.KEY_WORDS.get(key, "-")) for key in ("HOME", "END", " ")))

## 4. the mouse: what the screen asks of the terminal when it takes it (Terminal.mouse)
asked = []
stand = types.SimpleNamespace(BUTTON1_PRESSED=1, BUTTON1_RELEASED=2, BUTTON1_CLICKED=4, BUTTON4_PRESSED=8, BUTTON5_PRESSED=16,
                              mousemask=lambda mask: asked.append(mask), mouseinterval=lambda value: None, error=Exception)
screen.curses = stand


def mouse(setting, reported):
    os.environ.pop("MDLT_MANAGER_MOUSE", None)
    if setting is not None:
        os.environ["MDLT_MANAGER_MOUSE"] = setting
    del asked[:]
    screen.CursesSurface.mouse(None, reported)
    return asked[-1] if asked else "none"


say("mouse.default", mouse(None, True))
say("mouse.empty", mouse("", True))
say("mouse.disable", mouse("disable", True))
say("mouse.other", mouse("rig-own", True))
say("mouse.disableLeave", mouse("disable", False))
say("mouse.leave", mouse(None, False))
RIGPROBE
rigProbe="$( cd "$rigTmp" && "$rigPython" -I -B "$rigTmp/probe.py" "$rigScreen" 2>&1 )" || rigProbe="$rigProbe"$'\n'"PROBE-FAILED rc=$?"
rigGot(){ ## name -- the value of the first `<name>=` line of the probe
	printf '%s\n' "$rigProbe" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
[ -n "$( rigGot own.space )" ] || [ -n "$( rigGot own.pgdn )" ] || rigRefuse "the probe of the screen gave nothing: $( printf '%s\n' "$rigProbe" | LC_ALL=C grep -m3 -e PROBE-FAILED -e Traceback -e Error )"

echo "-- 1. the keys --"
rigAssert "Space pages down as PgDn does: one command has both" "$( rigGot own.space ) / $( rigGot own.pgdn )" "page-down / page-down"
rigAssert "PgUp pages up" "$( rigGot own.pgup )" "page-up"
rigAssert "Home goes to the top and End to the bottom: a command each, which no other key shares" "$( rigGot own.home ) / $( rigGot own.end )" "go-top / go-bottom"
rigAssert "the arrows move a line" "$( rigGot own.up ) / $( rigGot own.down )" "line-up / line-down"
rigAssert "no key the pane already binds is taken: b, l, g, v and w keep their commands" "$( rigGot own.b ) $( rigGot own.l ) $( rigGot own.g ) $( rigGot own.v ) $( rigGot own.w )" "mode-summary mode-log mode-raw mode wrap"
rigAssert "the terminal's Home and End are HOME and END, as its PgUp and PgDn are PGUP and PGDN, and its arrows" "$( rigGot curses )" "PGUP:PGUP PGDN:PGDN HOME:HOME END:END UP:UP"
rigAssert "the keys have names for the menus and the help" "$( rigGot words )" "HOME=Home END=End  =Space"

## The rig: a workspace of the stand-in dispatcher, with the fixtures of this check.
rigRow(){ ## the fields of one row, joined by TAB
	local rowText="$1" ; shift
	while [ $# -gt 0 ] ; do rowText="$rowText"$'\t'"$1" ; shift ; done
	printf '%s\n' "$rowText"
}
rigS1=11111111-0000-4000-8000-000000000001
rigCase(){ ## name members files -- a rig of its own: that many team members and that many files in the member keeper-rig
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	( cd "$MANAGER_SCREEN_RIG" || exit 1
	rigRow session "$rigS1" daily_of_Monday running 2026-10-12_16:57_+0000 - 1 running=1 running 2026-10-12_16:58_+0000 gone > "rows"
	rigRow run "$rigS1" "$rigS1" magic-coordinator spawn-started running running 2026-10-12_16:57_+0000 - rig-host ws-rig waiting >> "rows"
	rigRow counters 1 0 1 0 1 0.42 >> "rows"
	{
		rigRow member keeper-rig :triangular_ruler: Sage Bourne cronjob keeper ws-rig here active running
		for rigN in $( seq 1 "$2" ) ; do rigRow member "member-$( printf '%02d' "$rigN" )" :ear_of_rice: Thea Vance farmhand keeper ws-far elsewhere active no-process ; done
	} > "rows.--manager-team-member-list"
	rigMember="$( rigRow member keeper-rig - Rig Keeper - keeper /rig/ws here active no-process - )"
	printf '%s\ninfo\tdescription\tA_rig_keeper\n' "$rigMember" > "rows.--manager-team-member-read --full keeper-rig"
	{
		rigRow file SKILL.md 900 yes
		for rigN in $( seq 1 "$3" ) ; do rigRow file "file-$( printf '%02d' "$rigN" ).txt" 40 yes ; done
	} > "rows.--manager-team-member-files keeper-rig"
	{
		printf -- '---\nname: keeper-rig\n---\n# The rig keeper\n\n'
		for rigN in $( seq 1 150 ) ; do printf -- '- item %d of the list\n' "$rigN" ; done
	} > "rows.--manager-team-member-files keeper-rig SKILL.md"
	: > "calls" ; : > "words"
	echo rows > "mode" )
}
rigScript(){ ## size -- the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\ntable list:pending none\ntable view:magic-team/activity/active-sessions:record none\nwall 2026-10-13 02:30 +0000\nsize %s\n' "$rigTools" "$1" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}

echo "-- 2. the left window: a long Markdown text --"
rigCase text 3 8
rigScript "120 36" <<'RIGSCRIPT'
turn
wait list 10
at @team
turn
wait list 10
keys DOWN ENTER
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
keys TAB
get top
keys PGDN
get page
keys HOME
keys SPACE
get space
keys SPACE
get space2
keys PGUP
get back
keys END
get end
keys UP
get endUp
keys HOME
get home
keys DOWN DOWN DOWN
get lines
keys END HOME
get homeAgain
RIGSCRIPT
rigPage="$( rigVal page.viewTop )"
rigAssert "the control: the text is longer than three pages, the left window has the keys, and PgDn pages by the height of the window" "$( rigVal top.focus ) $( rigVal top.viewTop ) $( [ "$( rigVal top.viewLines )" -gt $(( 3 * rigPage )) ] && echo long || echo "short: $( rigVal top.viewLines ) of $rigPage" )" "view 0 long"
rigAssert "Space pages down as PgDn does, and again" "$( rigVal space.viewTop ) $( rigVal space2.viewTop )" "$rigPage $(( 2 * rigPage ))"
rigAssert "PgUp pages back up" "$( rigVal back.viewTop )" "$rigPage"
rigAssert "End goes to the bottom: the last page, and a line up from there is one line before" "$( rigVal end.viewTop ) $( rigVal endUp.viewTop )" "$(( $( rigVal end.viewLines ) - rigPage )) $(( $( rigVal end.viewLines ) - rigPage - 1 ))"
rigAssert "Home goes to the top, and the arrows move a line a time" "$( rigVal home.viewTop ) $( rigVal lines.viewTop ) $( rigVal homeAgain.viewTop )" "0 3 0"
rigAssert "the mode of the text is as it was after all of them" "$( rigVal home.textMode ) $( rigVal homeAgain.textMode ) $( rigVal top.textMode )" "summary summary summary"

echo "-- 2b. the left window: the table view, a table of more rows than the window holds --"
rigCase table 80 3
rigScript "120 30" <<'RIGSCRIPT'
root active-sessions
turn
wait sessions 30
root team
turn 2
turn
keys ENTER
wait list 10
turn
keys TAB
get top
keys PGDN
get page
keys HOME
keys SPACE
get space
keys END
get end
keys PGUP
get back
keys HOME
get home
RIGSCRIPT
rigTablePage="$( rigVal page.viewTop )"
rigAssert "control: the members stand in the table of the left window, more than a page of it, and PgDn pages it" "$( rigVal top.focus ) $( rigVal top.viewTop ) $( [ "$( rigVal top.viewLines )" -gt $(( 2 * rigTablePage )) ] && [ "$rigTablePage" -gt 0 ] && echo long || echo "short: $( rigVal top.viewLines ) of $rigTablePage" )" "view 0 long"
rigAssert "Space pages it down as PgDn does" "$( rigVal space.viewTop )" "$rigTablePage"
rigAssert "End is the bottom of the table, PgUp a page up from it, Home its top" "$( rigVal end.viewTop ) $( rigVal back.viewTop ) $( rigVal home.viewTop )" "$(( $( rigVal end.viewLines ) - rigTablePage )) $(( $( rigVal end.viewLines ) - 2 * rigTablePage )) 0"

echo "-- 3. the list on the right --"
rigCase list 3 100
rigScript "120 36" <<'RIGSCRIPT'
turn
wait list 10
at @team
turn
wait list 10
keys DOWN ENTER
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
get top
keys PGDN
get page
keys HOME
keys SPACE
get space
keys END
get end
keys PGUP
get back
keys HOME
get home
keys DOWN DOWN
get lines
RIGSCRIPT
rigListPage="$(( $( rigVal page.index ) - $( rigVal top.index ) ))"
rigAssert "control: the list of the files is longer than a page, the list has the keys, and PgDn pages the selection by a page" "$( rigVal top.focus ) $( rigVal top.index ) $( [ "$( rigVal top.rows )" -gt $(( 2 * rigListPage )) ] && [ "$rigListPage" -gt 0 ] && echo long || echo "short: $( rigVal top.rows ) of $rigListPage" )" "list 0 long"
rigAssert "Space pages the selection down as PgDn does" "$( rigVal space.index )" "$( rigVal page.index )"
rigAssert "End is the last row, PgUp a page up from it, Home the first row" "$( rigVal end.index ) $( rigVal back.index ) $( rigVal home.index )" "$(( $( rigVal top.rows ) - 1 )) $(( $( rigVal top.rows ) - 1 - rigListPage )) 0"
rigAssert "the arrows move a row" "$( rigVal lines.index )" "2"

echo "-- 3a. the left arrow in the right pane: pages up the list; on a list's first row it stays there, and climbs nowhere --"
rigCase climb 3 100
rigScript "120 36" <<'RIGSCRIPT'
turn
wait list 10
at @team
turn
wait list 10
keys DOWN ENTER
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys PGDN DOWN
get deep
keys LEFT
get paged
keys HOME LEFT
get up0
keys HOME LEFT
get up1
keys HOME LEFT
get up2
keys HOME LEFT
get up3
keys BACKSPACE BACKSPACE BACKSPACE BACKSPACE
wait list 10
keys DOWN DOWN LEFT
get root1
keys LEFT
get root2
keys LEFT LEFT LEFT
get root5
RIGSCRIPT
rigDepth(){ ## path -- how many levels it has
	[ -n "$1" ] && printf '%s\n' "$1" | LC_ALL=C awk -F/ '{ print NF }' || echo 0
}
rigAssert "control: the list stands four levels down (Magic-Team, Team Members, the member, its folder), on a row in the middle of its page, not on its first row" "$( rigDepth "$( rigVal deep.path )" ) $( [ "$( rigVal deep.index )" -gt 1 ] && echo middle || echo "first: $( rigVal deep.index )" ) $( rigVal deep.focus )" "4 middle list"
rigAssert "Left from the middle of the list pages it up, as PgUp does, and climbs nowhere" "$( rigDepth "$( rigVal paged.path )" ) $( [ "$( rigVal paged.index )" -lt "$( rigVal deep.index )" ] && echo up || echo "not up: $( rigVal paged.index ) of $( rigVal deep.index )" ) $( rigVal paged.focus )" "4 up list"
rigAssert "on the first row of a list Left stays there: the level, the row and the keys do not change" "$( rigDepth "$( rigVal up1.path )" ) $( rigDepth "$( rigVal up2.path )" ) $( rigDepth "$( rigVal up3.path )" ) $( rigVal up1.focus ) $( rigVal up3.focus ) $( rigVal up1.index ) $( rigVal up2.index ) $( rigVal up3.index )" "4 4 4 list list 0 0 0"
rigAssert "Left never leaves the list: at the root, off the first row it pages up to it, and on that row it stays" "$( rigDepth "$( rigVal root1.path )" ) $( rigDepth "$( rigVal root5.path )" ) $( rigVal root1.index ) $( rigVal root2.index ) $( rigVal root5.index ) $( rigVal root5.focus )" "0 0 0 0 0 list"
rigAssert "and on the root's first row it does nothing more: the level, the selection, the keys and the status line are as they were, and it never dives out of the pane" \
	"$( rigVal root5.path )|$( rigVal root5.index )|$( rigVal root5.selected )|$( rigVal root5.focus )|$( rigVal root5.notice )" "|0|$( rigVal root1.selected )|list|"

echo "-- 3b. the keys help names them --"
rigCase help 3 8
rigScript "120 36" <<'RIGSCRIPT'
turn
wait list 10
keys ?
get help
RIGSCRIPT
rigAssert "the box of the keys names the arrows by a line, the page keys with Space by a page, and Home and End to the top and the bottom" "$( rigVal help.dialogHolds | LC_ALL=C grep -F 'move by a line' | LC_ALL=C grep -F 'Space by a page' | LC_ALL=C grep -c -F 'Home and End to the top and the bottom' )" "1"

echo "-- 4. the mouse --"
rigAssert "on by default: the screen asks the terminal to report the first button and the wheel" "$( rigGot mouse.default )" "31"
rigAssert "a setting that names nothing is the default" "$( rigGot mouse.empty )" "31"
rigAssert "MDLT_MANAGER_MOUSE=disable: the screen asks the terminal to report none" "$( rigGot mouse.disable )" "0"
rigAssert "a setting that is not disable is the default" "$( rigGot mouse.other )" "31"
rigAssert "while the terminal is another's it is reported none, whatever the setting says" "$( rigGot mouse.disableLeave ) $( rigGot mouse.leave )" "0 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN PAGING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_PAGING: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
