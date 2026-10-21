#!/usr/bin/env bash
## Behavioural check on the width of text in the manager screen (owner, 2026-10-20: "in previous versions we solved EMOJI and width completely"): every text path of
## the left window measures a line with the one function of the screen (textCells, AgentsManagerScreen.Cells.py), so an emoji never makes a line wider than its
## pane and never breaks the border or the pane at its right. The block `as posted:` of a pending question holds the post as it was sent: keycap digits (a digit,
## U+FE0F, U+20E3), 📋 and ❓, an emoji joined by U+200D, a flag. Held:
##   1. every line the pane holds is at most as wide as the pane, by the function of the screen and by the stand-in terminal's own count
##   2. the border of the pane stands on the same cell in every row, and the pane at the right is the one it was without those lines
##   3. no text was put past the end of a line (a spill), and nothing is drawn in the cells of the border
## The stand-in terminal measures by itself (check-fixtures/manager-screen.driver.py), not by the screen's count. Offline.
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
rigTmp="$( rigTempDir AgentsManagerScreenEmojiWidthCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigAsk=4a4a4a4a-0000-4000-8000-000000000001
printf 'PENDING-REPLY: %s\nstatus: reply-pending\nowner: magic-tester\nkind: permission\nchannel: C0RIGCHAN01\nquestion-ts: 1791840000.000400\nthread-ts: 1791840000.000300\naddress-to: human-owner\nsession-id: 7a7a7a7a-0000-4000-8000-0000000000c3\nasked-at: 2026-10-13 02:05 +0300\nasker-live: running\nquestion: May I?\n\nPENDING-REPLIES: 1\n' \
	"$rigAsk" > "$rigTmp/one.ask"
## What the read of the ask by its id prints of the post: with the emoji, and without them (the same lines, the emoji taken out).
rigStored(){ ## with|without
	printf 'PENDING-REPLY-STORED: %s\nhost: rig-host\n' "$rigAsk"
	local postedLine
	while IFS= read -r postedLine ; do
		[ "$1" = with ] || postedLine="$( printf '%s' "$postedLine" | LC_ALL=C sed -e 's/1️⃣/1./g' -e 's/2️⃣/2./g' -e 's/3️⃣/3./g' -e 's/📋/#/g' -e 's/❓/?/g' -e 's/🧑‍💻/dev/g' -e 's/🇳🇿/NZ/g' )"
		printf 'posted: %s\n' "$postedLine"
	done <<'RIGPOSTED'
# 🔐 Permission
**📋 How to answer** - reply in this thread with one of these, or click the emoji under the post:
1️⃣ allow-once: let user-rig do it as proposed, for this one call only, and nothing else beyond that one call
2️⃣ allow-session: for as long as the session lives
3️⃣ deny: refuse it ❓ and say why if you like
🧑‍💻 the developer and 🇳🇿 the flag, 📋 a list ❓ a question, 1️⃣2️⃣3️⃣ in a row
RIGPOSTED
	printf 'field-question: May I?\n\n'
}
rigCase(){ ## name, with|without
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	: > "$MANAGER_SCREEN_RIG/calls"
	cp "$rigTmp/one.ask" "$MANAGER_SCREEN_RIG/rows"
	printf 'rows\n' > "$MANAGER_SCREEN_RIG/mode"
	rigStored "$2" > "$MANAGER_SCREEN_RIG/rows.--read-pending-reply magic-coordinator $rigAsk"
}
rigScript(){ ## the size, then the commands of the driver on standard input
	rigOut="$( { printf 'tools bash %s\ntable list:magic-team/activity none\nwall 2026-10-13 02:30 +0300\nsize %s\nroot active-sessions\n' "$rigTools" "$1" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
cat > "$rigTmp/measure.py" <<'RIGMEASURE'
import sys, unicodedata
## The stand-in terminal's own count of a text: wide characters two cells, joining marks none, an enclosing keycap mark one (it stands in the cell after its digit).
what, tag = sys.argv[1:3]
shown = [line[len(tag) + 1:].rstrip("\n") for line in sys.stdin.read().split("\n") if line.startswith(tag + "|")]
def cells(text):
    total = 0
    for character in text:
        code = ord(character)
        if code == 0x200D or 0xFE00 <= code <= 0xFE0F or unicodedata.combining(character) != 0:
            continue
        total += 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
    return total
if what == "border":
    ## the cell the first border character of the right edge of the left window stands on, per row: the same everywhere
    stands = set()
    for line in shown:
        text = line[1:]
        for mark in ("║", "│"):
            if mark in text:
                stands.add(cells(text[:text.index(mark)]))
                break
    print(" ".join(str(one) for one in sorted(stands)))
elif what == "widest":
    print(max(cells(line) for line in shown))
RIGMEASURE
rigRun(){ ## name, with|without
	rigCase "$1" "$2"
	rigScript "100 36" <<'RIGSCRIPT'
turn
keys 2
wait list 30
keys DOWN
wait view 30
wait view 30
turn
show pane
get w
RIGSCRIPT
}

echo "-- the post of a pending question, with keycap digits, 📋, ❓, a joined emoji and a flag --"
rigRun with with
rigWithOut="$rigOut"
rigRun without without
rigWithoutOut="$rigOut"
rigOut="$rigWithOut"
rigAssert "the pane shows the post (the lines with the emoji are there)" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^pane|' | LC_ALL=C grep -c -F -e '1️⃣' -e '📋' -e '❓' -e '🇳🇿' )" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^pane|' | LC_ALL=C grep -c -F -e '1️⃣' -e '📋' -e '❓' -e '🇳🇿' | LC_ALL=C awk '{ print ( $1 >= 4 ) ? $1 : "fewer than four lines" }' )"
rigAssert "the border of the left window stands on one cell in every row, with the emoji and without them" "$( printf '%s\n' "$rigWithOut" | "$rigPython" -I -B "$rigTmp/measure.py" border pane ) / $( printf '%s\n' "$rigWithoutOut" | "$rigPython" -I -B "$rigTmp/measure.py" border pane )" "$( printf '%s\n' "$rigWithoutOut" | "$rigPython" -I -B "$rigTmp/measure.py" border pane | LC_ALL=C awk '{ print ( NF == 1 ) ? $1 " / " $1 : "not one cell: " $0 }' )"
rigAssert "no text was put past the end of a line, with the emoji" "$( printf '%s\n' "$rigWithOut" | LC_ALL=C sed -n 's/^w.spills=//p' | head -1 )" "0"
rigAssert "no row is wider with the emoji than the same rows without them, by the terminal's own count" "$( printf '%s\n' "$rigWithOut" | "$rigPython" -I -B "$rigTmp/measure.py" widest pane )" "$( printf '%s\n' "$rigWithoutOut" | "$rigPython" -I -B "$rigTmp/measure.py" widest pane )"

echo "-- the real screen on a terminal that keeps its cells (a Mac's, narrow and wide in what it advances for an emoji): every cell is what the screen drew --"
rigVt="$rigFixtures/manager-screen.vt.stub.py"
[ -f "$rigVt" ] || rigRefuse "the terminal of the screen tests is missing: $rigVt"
mkdir -p "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTools" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
rigCase vt with
for rigEmulation in narrow wide ; do
	printf '%s\n' 'await Magic-Team (Agents)' 'keys 2' 'await Pending Questions' 'keys \eOB' 'await as posted' 'idle 1' 'check post' 'show post' 'keys \x18' 'end end' > "$rigTmp/steps"
	rm -f "$MANAGER_SCREEN_RIG/calls" "$rigTmp/dump.json"
	rigOut="$( env MANAGER_SCREEN_VT_EMOJI="$rigEmulation" "$rigPython" -I -B "$rigVt" "$rigScreen" run 120 40 "$rigTmp/dump.json" -- \
		"$rigPython" -I -B "$rigVt" "$rigScreen" inner "$rigTmp/dump.json" -- --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" < "$rigTmp/steps" 2>&1 )"
	rigAssert "$rigEmulation: the post stands in the pane, and the screen ends by its key" "$( rigVal 'await.as_posted' ) $( rigVal end.rc )" "yes 0"
	rigAssert "$rigEmulation: every cell of the terminal is what the screen drew, so no emoji reaches into the border or the pane at its right" "$( rigVal post.differ )" "0"
done

echo "-- a Markdown text rendered by catMarkdown, which counts the width of an emoji by itself: no line of it is wider than the window by the count of the screen --"
rigMd="$( "$rigPython" -I -B - "$rigScreen" <<'RIGMD'
import importlib.util, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("S", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
## what catMarkdown gave for a window of 40 cells, by its own count: the lines hold emoji it counted as one cell, and one line carries a look
lines = ["1️⃣ allow-once: for this call 📋 only ❓ and 🧑\u200d💻 and 🇳🇿 1️⃣2️⃣3️⃣ in a row", "short", "- 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 📋 end"]
fitted, looks = m.markdownFitted(lines, {0: [(0, 12, 1)]}, 40)
print(max(m.textWidth(line) for line in fitted), len(fitted) > len(lines), 0 in looks and looks[0][0][0] == 0, "short" in fitted)
head, blocks = m.paneTable(["KEY", "WHAT"], [["a", "📋📋📋📋📋📋📋📋 📋📋📋📋📋📋📋📋 ok"], ["b", "plain words that wrap in a narrow table all the same"]], 34, wrap=True)
tableLines = head + [line for block in blocks for line in block]
print(max(m.textWidth(line) for line in tableLines), sum(1 for line in tableLines if m.MARKS["cut"] in line), "ok" in "".join(tableLines) and "".join(tableLines).count("📋") == 16)
whole, same = m.markdownFitted(["short", "line"], {1: [(0, 4, 1)]}, 40)
print(whole == ["short", "line"], same == {1: [(0, 4, 1)]})
RIGMD
)"
rigAssert "every line is held to the window (39 cells at most), longer ones broken between words, the looks of the first piece kept, a line that fits left as it was" "$( printf '%s\n' "$rigMd" | head -1 | LC_ALL=C awk '{ print ( $1 <= 39 ) ? "fits" : "wider " $1 }' ) $( printf '%s\n' "$rigMd" | head -1 | LC_ALL=C cut -d' ' -f2- )" "fits True True True"
rigAssert "and a text that fits comes back as it was, with its looks" "$( printf '%s\n' "$rigMd" | tail -1 )" "True True"
rigAssert "a table cell with emoji is broken to its width by the count of the screen: no line wider than the table, none cut where it should be broken, every word of it there" "$( printf '%s\n' "$rigMd" | sed -n 2p | LC_ALL=C awk '{ print ( $1 <= 34 ) ? "fits " $2 " " $3 : "wider " $1 }' )" "fits 0 True"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN EMOJI WIDTH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_EMOJI_WIDTH: OK (%d assertions, offline, stand-in terminal and stand-in dispatcher)\n' "$rigPassCount"
