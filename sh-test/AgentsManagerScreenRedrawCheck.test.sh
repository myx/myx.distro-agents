#!/usr/bin/env bash
## Behavioural check on what stays on a real terminal after the manager screen (sh-lib/AgentsManagerScreen.py) drew on
## it, run rather than read. The real screen runs on a pseudo-terminal in front of a terminal that keeps its cells and
## answers where its cursor is (check-fixtures/manager-screen.vt.stub.py), and after each step every cell of that
## terminal is compared with what the screen drew last: nothing of an earlier frame may stand anywhere, no mark of the
## selection, no line of a frame, no shade of a scroll bar, no character of another view. Held on a terminal that
## moves one cell for an emoji a selector makes of a character of one cell and for a keycap, and each joined emoji in
## its own cells, as Terminal.app and GNU screen do (narrow), and on one that moves two for those and draws joined ones
## as one, as iTerm does (wide), the same screen on both: every emoji takes two cells, or its parts' where more, curses
## holds blanks there, and the emoji is written into them apart at its own column, so nothing after it moves however
## far the terminal moves for it. The views are the owner's: the members magic-architect (🏛️, ⚖️🔗 ⚠️🤔),
## magic-coordinator (🐭, all wide) and magic-devops (⚒️, 🚀 🔥 💸 🟢), the keycaps of the options of a question with
## 📋 and ⚙, the selection moved over the
## root list and over the members, the view scrolled so plain lines come where emoji lines stood, the split moved by
## its keys both ways and by the mouse, a menu walked item by item, the help opened and closed, the log of a session
## with emoji and then a session with a short one, the summary, a short list under a long one, the terminal resized
## both ways. A menu walked item by item changes the look of two items and no character; in every dialog the button
## that has the keys is the only one in its look, and the first one, the default, keeps its marks. A quiet tick sends
## the clock alone; a frame is sent whole only where its layout changed or what lay over it closed (`repaints` of the
## driver, check-fixtures/manager-screen.driver.py). At its end, by its key or
## by a signal, on a terminal with another screen and on one without, nothing of the screen stays and the cursor
## stands at the start of a blank line; a failure is said after the terminal was given back, and stays to be read.
## Offline: the only thing the real screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.stub.sh).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigVt="$rigFixtures/manager-screen.vt.stub.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigVt" ] || rigRefuse "the terminal of the screen tests is missing: $rigVt"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
rigTmp="$( mktemp -d -t AgentsManagerScreenRedrawCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
export MANAGER_SCREEN_RIG="$rigTmp/rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigFixtures/manager-screen.tools.stub.sh" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
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
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigVt(){ ## the emulation, narrow or wide, the steps, then settings of the environment -- what the terminal says of the run is kept in rigOut
	local vtEmulation="$1" ; shift
	printf '%s\n' "$1" > "$rigTmp/steps" ; shift
	rm -f "$rigTmp/rig/calls" "$rigTmp/rig/words" "$rigTmp/rig/ended" "$rigTmp/dump.json"
	rigOut="$( env "$@" MANAGER_SCREEN_VT_EMOJI="$vtEmulation" "$rigPython" -I -B "$rigVt" "$rigScreen" run 120 40 "$rigTmp/dump.json" -- \
		"$rigPython" -I -B "$rigVt" "$rigScreen" inner "$rigTmp/dump.json" -- --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" < "$rigTmp/steps" 2>&1 )"
}
rigClean(){ ## the checks of the run that found a cell of the terminal that is not what the screen drew, as `<step>:<cells>`, or `none`
	printf '%s\n' "$rigOut" | LC_ALL=C awk -F'=' '/\.differ=/ { checks++ ; if ( $2 != "0" ) { sub(/\.differ$/, "", $1) ; bad = bad " " $1 ":" $2 } } END { print ( checks ? ( bad == "" ? "none" : substr(bad, 2) ) : "no-check" ) }'
}

## The team as the owner's views have it: each member's icon, and in its view the line of its Unicode character, its
## favourites and the options of a question, among plain lines long enough to reach the border; a session with a long
## log of emoji, and one with a short one.
"$rigPython" -I - "$rigTmp/rig" <<'RIGROWS'
import sys
rig = sys.argv[1]
def member(name, icon, first, family, alias):
    return "\t".join(["member", name, icon, first, family, alias, "skill", "/ws/" + name, "here", "active", "", icon])
team = [("magic-architect", "\U0001f3db️", "Cassius", "Stone", "archspec", "⚖️\U0001f517 ⚠️\U0001f914"),
        ("magic-coordinator", "\U0001f42d", "Maggie", "Rowe", "magic", "\U0001f440 ⏳ ❓ \U0001f4e5 ✅"),
        ("magic-developer", "\U0001f9ec", "Theo", "Lang", "lexr", "\U0001f9d1‍\U0001f4bb \U0001f44d\U0001f3fd \U0001f1f3\U0001f1ff"),
        ("magic-devops", "⚒️", "Dee", "Vance", "ops", "\U0001f680 \U0001f525 \U0001f4b8 \U0001f7e2")]
rows = [member(name, icon, first, family, alias) for name, icon, first, family, alias, liked in team]
rows += [member("member-%02d" % number, "⚛️" if number % 2 else "\U0001f4e5", "Some", "One", "-") for number in range(16)]
open(rig + "/rows.--manager-team-member-list", "w").write("\n".join(rows) + "\n")
for name, icon, first, family, alias, liked in team:
    read = [member(name, icon, first, family, alias), "info\tdescription\tA member of the team, here to test how its view is drawn"]
    read += ["bullet\tPlain line %02d\tsome words that are long enough to reach the right border of the window, and more of them" % number for number in range(6)]
    read += ["bullet\tUnicode character\t" + icon, "bullet\tFavourites\t" + liked,
             "bullet\tOptions\t1️⃣provisioned 2️⃣not-provisioned 3️⃣other",
             "bullet\tAsked\t📋 the plan, ⚙ the settings"]
    read += ["bullet\tMore %02d\tplain words again, with no emoji at all in them" % number for number in range(40)]
    open(rig + "/rows.--manager-team-member-read " + name, "w").write("\n".join(read) + "\n")
open(rig + "/rows.--manager-session-list", "w").write(
    "session\ts1\tlong-log\trunning\t2026-10-14T01:00:00Z\t2026-10-14T01:00:00Z\t1\t-\n"
    "session\ts2\tshort\tended\t2026-10-14T01:00:00Z\t2026-10-14T01:00:00Z\t1\t-\n")
log = ["source\tsp1\tmagic-devops\tlog\t/x"]
log += ["log\tsp1\tmagic-devops\t%s line %02d of a long log, ⚒️ with \U0001f680 emoji ⚠️ and 1️⃣ keycaps and \U0001f9d1‍\U0001f4bb joined ones, long enough to wrap" % (
    "✅" if number % 3 else "✏️", number) for number in range(50)]
open(rig + "/rows.--manager-session-transcript-read --session-id s1", "w").write("\n".join(log) + "\n")
open(rig + "/rows.--manager-session-transcript-read --session-id s2", "w").write("source\tsp2\tmagic-coordinator\tlog\t/y\nlog\tsp2\tmagic-coordinator\tshort.\n")
RIGROWS

echo "-- the count: an emoji is one character, in two cells or in its parts' where more, the same on every terminal --"
rigOut="$( "$rigPython" -I -B - "$rigScreen" <<'RIGCOUNT'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen)
texts = (("selected", "\u2696\ufe0f"), ("keycap", "1\ufe0f\u20e3"), ("wide", "\U0001f517"), ("joined", "\U0001f9d1\u200d\U0001f4bb"),
         ("skin", "\U0001f44d\U0001f3fd"), ("flag", "\U0001f1f3\U0001f1ff"), ("symbol", "\u2699"), ("mark", "e\u0301"), ("cjk", "\u4e2d"),
         ("frame", "\u2550"), ("bar", "\u2592"))
print("cells=%s" % " ".join("%s:%s" % (name, ",".join(str(cells) for cluster, cells in screen.textCells(text))) for name, text in texts))
print("line=%d" % screen.textWidth("Favourites: \u2696\ufe0f\U0001f517 \u26a0\ufe0f\U0001f914"))
## every mark Magic draws and every name it gives a key: one cell each, as text and never as an emoji
screen.setStyle("magic")
marks = "".join("".join(screen.styleMark(name)) for name in ("rim", "focus", "field", "rule", "barUp", "barDown",
                                                             "barTrack", "barThumb", "checks", "radios", "shadow", "folder"))
marks += "".join(screen.keyWords().values())
print("magic=%s %s" % (sorted(set(cells for cluster, cells in screen.textCells(marks))), any(screen.isEmoji(character) for character in marks)))
RIGCOUNT
)"
rigAssert "each emoji is one character of two cells, a joined one and one with a skin in the cells of their parts; a mark joins its letter; a frame and a scroll bar one cell" \
	"$( rigVal cells )" "selected:2 keycap:2 wide:2 joined:4 skin:4 flag:2 symbol:2 mark:1 cjk:2 frame:1 bar:1"
rigAssert "the owner's line of favourites takes the cells of its words and two for each emoji" "$( rigVal line )" "21"
rigAssert "every mark of Magic and every name it gives a key is one cell, as text, none an emoji" "$( rigVal magic )" "[1] False"

echo "-- a frame is sent whole only where its layout changed or what lay over it closed --"
rigOut="$( printf '%s\n' 'size 120 40' 'root sessions' 'turn' 'get a' 'keys DOWN' 'get b' 'turn 3' 'get c' 'keys [' 'get d' 'keys ]' 'get e' 'keys m' 'get f' \
	'keys DOWN' 'get g' 'keys ESC' 'get h' 'keys ?' 'get i' 'keys ESC' 'get j' 'size 100 30' 'get k' 'turn' 'get l' \
	| "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
rigAssert "none at the start, on a move of the selection and on quiet turns; once for each move of the split, once when a menu closes, not when it opens or its bar moves, once when a dialog closes, once for a new size" \
	"$( for tag in a b c d e f g h i j k l ; do printf '%s ' "$( rigVal "$tag.repaints" )" ; done )" "0 0 0 1 2 2 2 3 3 4 5 5 "

echo "-- the owner's views on a terminal that moves one cell for a selector and a keycap (narrow) and on one that moves two (wide) --"
rigSteps='await Sessions (Activity)
check start
idle 3
keys \eOB
keys \eOB
keys \eOA
check root
keys 4
await magic-devops
check team
keys \eOB
check member1
keys \eOB
check member2
keys \eOB
check member3
keys \eOA
check member4
keys \eOA
check member5
keys \eOA
check member6
keys \t
keys \e[6~
check scrolled
keys \e[5~
check scrolledBack
keys \t
keys \eOB
check member7
keys [
check wider
keys ]
keys ]
check narrower
drag 60
check dragged
keys m
items m0
keys \eOB
items m1
keys \eOB
items m2
keys \e
check menuClosed
keys ?
check help
keys \e
check helpClosed
keys 2
await long-log
keys \eOB
keys \eOB
keys l
await line 49
check log
keys \eOB
check logShort
keys \eOA
check logBack
keys b
check summary
keys 1
check shorter
size 100 30
check smaller
size 120 40
check larger
keys \x18
end end'
for rigEmulation in narrow wide ; do
	rigVt "$rigEmulation" "$rigSteps"
	rigAssert "$rigEmulation: the screen comes up, the views it is taken through come up, and it ends by its key" \
		"$( rigVal 'await.Sessions_(Activity)' ) $( rigVal await.magic-devops ) $( rigVal await.long-log ) $( rigVal await.line_49 ) $( rigVal end.rc )" "yes yes yes yes 0"
	rigAssert "$rigEmulation: after every step every cell of the terminal is what the screen drew last" "$( rigClean )" "none"
	rigAssert "$rigEmulation: so no mark of the selection, no line of a frame and no shade of a scroll bar stands anywhere it was not drawn" \
		"$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'=' '/\.(marks|frames|shades)=/ && !/^idle\./ { sum += $2 } END { print sum + 0 }' )" "0"
	rigAssert "$rigEmulation: the bar moved over a menu item by item changes no character, each item the same text at every step, and the look of two items a move, the one it left and the one it came to" \
		"$( printf '%s\n' "$rigOut" | LC_ALL=C awk '/^m[012]\.item\./ { split($0, kv, "=") ; split(kv[1], key, ".") ; text = kv[2] ; sub(/@[0-9,]*$/, "", text) ; looks = kv[2] ; sub(/^.*@/, "", looks)
			if ( ( key[3] in seen ) && seen[key[3]] != text ) { moved++ } ; seen[key[3]] = text ; look[substr(key[1], 2) + 0, key[3]] = looks ; items[key[3]] = 1 }
			END { out = moved + 0 ; for ( step = 1 ; step <= 2 ; step++ ) { changed = 0 ; for ( item in items ) { if ( look[step, item] != look[step - 1, item] ) { changed++ } } ; out = out " " changed } ; print out }' )" "0 2 2"
	rigAssert "$rigEmulation: a quiet tick sends the clock and nothing else: under a hundred bytes a second" \
		"$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'=' '/^idle\.bytes=/ { print ( $2 > 0 && $2 < 300 ) ? "yes" : "no: " $2 }' )" "yes"
done

echo "-- the end: nothing of the screen stays, the cursor at the start of an empty line, a failure said after it --"
echo "-- Magic on both terminals: its edges, rims, shadows, tabs, slim scroll bar, chips and the marks of its buttons --"
rigMagicSteps='await Sessions (Activity)
check magicStart
keys \eOB
keys \eOB
check magicMoved
keys 4
await magic-devops
check magicTeam
keys \t
keys \e[6~
check magicScrolled
keys \e[5~
keys \t
keys [
check magicWider
keys m
items mm0
keys \eOB
items mm1
keys \e
check magicMenuClosed
keys ?
check magicHelp
keys \e
check magicHelpClosed
size 100 30
check magicSmaller
keys \x18
end end'
for rigEmulation in narrow wide ; do
	rigVt "$rigEmulation" "$rigMagicSteps" MDAT_MANAGER_STYLE=magic
	rigAssert "$rigEmulation, Magic: the screen comes up in Magic, the team comes up, and it ends by its key" \
		"$( rigVal 'await.Sessions_(Activity)' ) $( rigVal await.magic-devops ) $( rigVal end.rc )" "yes yes 0"
	rigAssert "$rigEmulation, Magic: after every step every cell of the terminal is what the screen drew last" "$( rigClean )" "none"
done

for rigOther in with without ; do
	rigNoAlt="$( [ "$rigOther" = without ] && echo 1 || echo 0 )"
	rigVt narrow "$( printf '%s\n' 'await Sessions (Activity)' 'keys \x18' 'end end' 'left key' )" MANAGER_SCREEN_VT_NOALT="$rigNoAlt"
	rigAssert "$rigOther another screen, ended by its key: no cell of the screen stands, the cursor at the start of a blank line" \
		"$( rigVal end.rc ) $( rigVal key.cells ) $( rigVal key.cursor | LC_ALL=C sed 's/^.*,//' ) $( rigVal key.lineBlank )" "0 0 0 yes"
	rigVt narrow "$( printf '%s\n' 'await Sessions (Activity)' 'signal SIGTERM' 'end end' 'left term' )" MANAGER_SCREEN_VT_NOALT="$rigNoAlt"
	rigAssert "$rigOther another screen, ended by a signal: the same" \
		"$( rigVal end.rc ) $( rigVal term.cells ) $( rigVal term.cursor | LC_ALL=C sed 's/^.*,//' ) $( rigVal term.lineBlank )" "143 0 0 yes"
done
rigVt narrow "$( printf '%s\n' 'await Sessions (Activity)' 'end end' 'left failed' )" MANAGER_SCREEN_VT_NOALT=1 MANAGER_SCREEN_VT_RAISE=1
rigAssert "a failure of the drawing, without another screen: what it says stands alone on the terminal once it was given back" \
	"$( rigVal end.rc ) $( rigVal failed.first | LC_ALL=C grep -c -F 'the screen failed, and the terminal was given back first: RuntimeError' )" "1 1"

echo "-- every dialog: the button that has the keys is the only one in its look, and the default keeps its marks --"
rigDialogs="$( "$rigPython" -I -B - "$rigScreen" <<'RIGDIALOGS'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
screen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(screen)
print(len(screen.DIALOGS))
RIGDIALOGS
)"
rigSteps="await Dialog message"
for rigDialog in $( seq 1 "$rigDialogs" ) ; do
	rigSteps="$rigSteps
buttons d$rigDialog.0"
	for rigTab in 1 2 3 4 ; do rigSteps="$rigSteps
keys \\t
buttons d$rigDialog.$rigTab" ; done
	rigSteps="$rigSteps
keys \\e"
done
rigVt narrow "$( printf '%s\n' "$rigSteps" 'check dialogs' 'keys \x18' 'end end' )" MANAGER_SCREEN_VT_DIALOGS=all
rigButtons="$( printf '%s\n' "$rigOut" | LC_ALL=C awk '
	/^d[0-9]+\.[0-9]+\.button\./ { split($0, kv, "=") ; split(kv[1], key, ".") ; tag = key[1] "." key[2] ; text = kv[2] ; sub(/@[0-9,]*$/, "", text) ; looks = kv[2] ; sub(/^.*@/, "", looks)
		button[tag, key[4]] = looks ; buttons[tag] = buttons[tag] " " key[4] ; dialogs[key[1]] = 1
		if ( ( key[1], key[4] ) in texts && texts[key[1], key[4]] != text ) { moved++ } ; texts[key[1], key[4]] = text
		if ( key[4] == 0 && text !~ /»/ ) { unmarked++ } ; if ( key[4] != 0 && text ~ /»/ ) { marked++ } }
	/^d[0-9]+\.[0-9]+\.focus=/ { split($0, kv, "=") ; split(kv[1], key, ".") ; focus[key[1] "." key[2]] = kv[2] }
	END {
		for ( tag in buttons ) { if ( focus[tag] != "None" ) { focused[button[tag, focus[tag]]] = 1 ; split(tag, part, ".") ; reached[part[1]] = 1 } }
		for ( tag in buttons ) { n = split(buttons[tag], list, " ") ; for ( i = 1 ; i <= n ; i++ ) { if ( list[i] != focus[tag] && ( button[tag, list[i]] in focused ) ) { lookalike++ } } }
		looks = 0 ; for ( one in focused ) { looks++ }
		count = 0 ; for ( one in dialogs ) { count++ } ; steps = 0 ; for ( one in reached ) { steps++ }
		print count " dialogs, " steps " with the keys on a button at a step, " looks " look of the keys, " ( lookalike + 0 ) " other buttons in it, " ( moved + 0 ) " moved, " ( unmarked + 0 ) " defaults unmarked, " ( marked + 0 ) " others marked" }' )"
rigAssert "in each of the dialogs, Tab after Tab: one look of the keys, worn by the button that has them and no other; no button moves; the first has its marks and no other" \
	"$rigButtons" "$rigDialogs dialogs, $rigDialogs with the keys on a button at a step, 1 look of the keys, 0 other buttons in it, 0 moved, 0 defaults unmarked, 0 others marked"
rigAssert "and nothing of them stays when the last has closed" "$( rigClean )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN REDRAW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_REDRAW: OK (%d assertions, offline, the real screen on pseudo-terminals in front of a terminal that keeps its cells)\n' "$rigPassCount"
