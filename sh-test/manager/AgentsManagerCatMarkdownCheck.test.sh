#!/usr/bin/env bash
## Behavioural check on the tables of `myx.common lib/catMarkdown` (F12.3 of the refactorings epic), the one renderer the manager screen's
## Markdown view and every `--help` of the family use, run rather than read. A table that is part of a document is laid out to the width
## it is given, in the text form and for a program (--spans): the columns fitted to the width, the cells wrapped at their words, the header
## marked, and a rule between two rows where either takes more than one line. It has no alternating ground and no empty line between rows,
## which are the screen's own table view; and no colour for telling rows apart.
## Held:
##   1. with no width the output is what it was, byte for byte: the plain text, --strip-all, --force-tty, --spans, --spans --no-wrap,
##      --spans --ascii; --height alone changes nothing
##   2. with a width, in the text form: the table is fitted to it (no line wider, at every width from 30 to 100), wrapped, its header marked by a
##      rule, a rule under and above a row that wraps and none between rows of one line; a table that fits is as it was; the rest of the
##      text is as it was
##   3. with the codes of a terminal (--force-tty): the header bold, the borders and rules grey, and nothing else; NO_COLOR leaves them all out,
##      with --force-tty too, and also with no width
##   4. for a program (--spans) with a width: the same rows and rules, the header in the look head and the rules in the look rule; the other
##      lines as they were
##   5. on a terminal, with no width given: the width of the terminal; with the width given, that one
##   6. a character of two cells in a cell is counted in two
##   7. plain POSIX awk: every awk of this machine gives the same output (BSD and macOS awk, gawk also with --posix, mawk, BusyBox where there)
## Offline: only the renderer and its awk are run, on text made here.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRoot="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
rigCat="$rigRoot/bin/lib/catMarkdown.Common"
rigAwk="$rigRoot/include/data/catMarkdown.awk"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigCat" ] || rigRefuse "catMarkdown is not at the origin: $rigCat"
[ -f "$rigAwk" ] || rigRefuse "its awk is not at the origin: $rigAwk"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerCatMarkdownCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC
## the renderer of the origin under test, not the one installed, and no colour setting of the caller
export MYXROOT="$rigRoot"
unset NO_COLOR

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCatMd(){ ## the options... -- the renderer over the text of the rig, the way a pipe has it: not on a terminal
	sh "$rigCat" "$@" < "$rigTmp/doc.md"
}
cat > "$rigTmp/doc.md" <<'RIGDOC'
---
title: Rig
---
# The rig document

A paragraph with `code`, **strong words**, _emphasized words_ and enough plain words after them to be broken at a narrow width of the line.

## Lists

- first item with a long tail of words that wraps under its own text at a narrow width of the window
  - nested item
1. numbered one

> A quoted line that is long enough to wrap around a narrow width of the window.

---

### The table

| Name | Kind | Remark |
|------|:----:|-------:|
| alpha | one | short |
| beta | two words that wrap on and on over the lines | a longer remark that wraps too |
| gamma | six | 3 |

```sh
echo "a line of code that is longer than a narrow width of the window"
```

The end, with a [link](https://example.invalid/x) in it.
RIGDOC

echo "-- 1. with no width the output is what it was --"
rigSum(){ cksum | LC_ALL=C tr ' ' ':' ; }
rigAssert "the plain text, and --strip-all which is the same here" "$( rigCatMd | rigSum ) $( rigCatMd --strip-all | rigSum )" "158522737:1435 158522737:1435"
rigAssert "with the codes of a terminal forced" "$( rigCatMd --force-tty | rigSum )" "1559861582:1690"
rigAssert "for a program, wrapped or not, and in ASCII" "$( rigCatMd --spans | rigSum ) $( rigCatMd --spans --no-wrap | rigSum ) $( rigCatMd --spans --ascii | rigSum )" "1077984325:1686 1077984325:1686 2481102321:1287"
rigAssert "--height alone, and --no-wrap alone, change nothing" "$( rigCatMd --height 20 | rigSum ) $( rigCatMd --no-wrap | rigSum )" "158522737:1435 158522737:1435"
rigAssert "the sed renderer, which no width reaches, is as it was" "$( rigCatMd --basic-sed | rigSum ) $( rigCatMd --basic-sed --width 40 | rigSum )" "911591636:729 911591636:729"
rigAssert "an option that needs a number says so, and nothing is rendered" "$( sh "$rigCat" --height x < "$rigTmp/doc.md" 2>&1 | head -1 ) $( sh "$rigCat" --width < "$rigTmp/doc.md" 2>&1 | head -1 | cut -c1-60 )" "⛔ ERROR: CatMarkdown: --height needs a number of rows ⛔ ERROR: CatMarkdown: --width needs a number of cells"

echo "-- 2. with a width, the text form --"
rigTable(){ ## the options... -- the lines of the table in the output, from its header to the line before its fence
	rigCatMd "$@" | LC_ALL=C awk '/^Name / { on = 1 } /^$/ { on = 0 } on'
}
rigAssert "a table that fits is as it was" "$( rigTable --width 120 | rigSum )" "$( rigTable | rigSum )"
cat > "$rigTmp/narrow.txt" <<'RIGNARROW'
Name  │ Kind                │ Remark
──────┼─────────────────────┼─────────────────────
alpha │ one                 │                short
──────┼─────────────────────┼─────────────────────
beta  │ two words that      │      a longer remark
      │ wrap on and on      │       that wraps too
      │ over the lines      │
──────┼─────────────────────┼─────────────────────
gamma │ six                 │                    3
RIGNARROW
rigAssert "narrower than it is, at 50: its columns fitted, its cells wrapped at their words, the header marked by a rule, a rule above and under the row that wraps and none between rows of one line" "$( rigTable --width 50 | rigSum )" "$( rigSum < "$rigTmp/narrow.txt" )"
rigWidest=""
for rigW in 30 31 32 33 34 35 36 38 40 44 48 52 56 60 66 72 80 90 100 ; do
	rigMax="$( rigTable --width "$rigW" | "$rigPython" -I -B -c 'import sys; print(max(len(line.rstrip("\n")) for line in sys.stdin))' )"
	[ "$rigMax" -le "$rigW" ] || rigWidest="$rigWidest $rigW:$rigMax"
done
rigAssert "at every width from 30 to 100 no line of the table is wider than it" "[$rigWidest]" "[]"
rigAssert "the rest of the text is as it was: nothing before the table or after it is reflowed" "$( rigCatMd --width 50 | LC_ALL=C awk '/^Name / { skip = 1 } !skip' | rigSum ) $( rigCatMd --width 50 | LC_ALL=C awk '/^echo / { on = 1 } on' | rigSum )" "$( rigCatMd | LC_ALL=C awk '/^Name / { skip = 1 } !skip' | rigSum ) $( rigCatMd | LC_ALL=C awk '/^echo / { on = 1 } on' | rigSum )"
rigAssert "--height is given and changes nothing" "$( rigCatMd --width 50 --height 7 | rigSum )" "$( rigCatMd --width 50 | rigSum )"

echo "-- 3. the codes of a terminal --"
rigEsc="$( printf '\033' )"
rigNarrowAnsi="$( rigCatMd --force-tty --width 50 | LC_ALL=C awk '/Name/ { on = 1 } /^$/ { on = 0 } on' )"
rigAssert "the header is bold, its borders and the rules are grey: the codes of the table and no other" "$( printf '%s\n' "$rigNarrowAnsi" | LC_ALL=C grep -c "${rigEsc}\[1mName${rigEsc}\[0m" ) $( printf '%s\n' "$rigNarrowAnsi" | LC_ALL=C grep -c "${rigEsc}\[90m" ) $( printf '%s\n' "$rigNarrowAnsi" | LC_ALL=C grep -c -e "${rigEsc}\[3[0-79]m" -e "${rigEsc}\[4[0-79]m" -e "${rigEsc}\[9[1-7]m" )" "1 9 0"
rigAssert "with the codes removed it is the plain table" "$( printf '%s\n' "$rigNarrowAnsi" | LC_ALL=C sed "s/${rigEsc}\[[0-9;]*m//g" | rigSum )" "$( rigSum < "$rigTmp/narrow.txt" )"
rigAssert "NO_COLOR leaves every code out, also when they are forced, and with no width" "$( NO_COLOR=1 rigCatMd --force-tty --width 50 | LC_ALL=C grep -c "$rigEsc" ) $( NO_COLOR=1 rigCatMd --force-tty | LC_ALL=C grep -c "$rigEsc" ) $( NO_COLOR='' rigCatMd --force-tty | LC_ALL=C grep -c "$rigEsc" | LC_ALL=C tr -d '\n' | LC_ALL=C awk '{ print ($1 > 0 ? "codes" : "none") }' )" "0 0 codes"

echo "-- 4. for a program, with a width --"
rigSpans(){ rigCatMd --spans --width 40 "$@" ; }
rigAssert "the header is in the look head and the borders in the look rule, as the table is broken in the columns" "$( rigSpans | LC_ALL=C awk -F'\t' '/^Name / { print $2 }' )" "0+4+head,5+5+rule,10+4+head,24+5+rule,29+6+head"
cat > "$rigTmp/rules.py" <<'RIGRULES'
import sys
rules = 0
for line in sys.stdin.read().split("\n"):
    text = line.split("\t")[0]
    if text and set(text) <= set("─┼") and "┼" in text:
        rules += 1
print(rules)
RIGRULES
rigAssert "a rule is a line of its own: one under the header, one above the row that wraps and one under it, none between rows of one line" "$( rigSpans | "$rigPython" -I -B "$rigTmp/rules.py" )" "3"
rigAssert "every line outside the table is as it was for a program, at the same width (the checksums are those of the lines before the table and after it from before)" "$( rigSpans | LC_ALL=C awk '/^Name / { skip = 1 } !skip' | rigSum ) $( rigSpans | LC_ALL=C awk '/^echo / { on = 1 } on' | rigSum )" "570410441:791 1902349282:131"
rigAssert "a table that fits is as it was for a program (the checksum is that of the whole from before)" "$( rigCatMd --spans --width 120 | rigSum )" "2137385058:1687"
rigAssert "with --no-wrap it keeps its width" "$( rigCatMd --spans --width 40 --no-wrap | rigSum )" "$( rigCatMd --spans | rigSum )"

echo "-- 5. on a terminal --"
cat > "$rigTmp/pty.py" <<'RIGPTY'
import fcntl, os, pty, struct, sys, termios
columns, term = sys.argv[1], sys.argv[2]
words = sys.argv[3:]
env = dict(os.environ, TERM=term)
env.pop("COLUMNS", None)
pid, master = pty.fork()
if pid == 0:
    os.execvpe(words[0], words, env)
fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, int(columns), 0, 0))
os.write(master, b"\n")
out = b""
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.buffer.write(out.replace(b"\r\n", b"\n"))
RIGPTY
rigPty(){ ## columns, term, words... -- the output of the renderer on a terminal of that many columns, TERM as given, over the text of the rig
	"$rigPython" -I -B "$rigTmp/pty.py" "$1" "$2" sh -c 'read go ; exec sh "$0" "$@" < "$RIG_DOC"' "$rigCat" "${@:3}"
}
export RIG_DOC="$rigTmp/doc.md"
rigMaxTable(){ ## the widest line of the table in the output on its stdin
	LC_ALL=C sed "s/$( printf '\033' )\[[0-9;]*m//g" | LC_ALL=C awk '/^Name/ { on = 1 } /^$/ { on = 0 } on' | "$rigPython" -I -B -c 'import sys; print(max(len(line.rstrip("\n")) for line in sys.stdin))'
}
rigAssert "with no width given a table is fitted to the terminal's own, 44 columns here, in the codes of a terminal that has colours" "$( rigPty 44 xterm-256color | rigMaxTable ) $( rigPty 44 xterm-256color | LC_ALL=C grep -c "$rigEsc" | LC_ALL=C awk '{ print ($1 > 0 ? "codes" : "none") }' )" "44 codes"
rigAssert "the width given is the one it takes, not the terminal's" "$( rigPty 44 xterm-256color --width 60 | rigMaxTable )" "$( rigTable --width 60 | rigMaxTable )"
rigAssert "a terminal with no colours gets the same table, plain" "$( rigPty 44 dumb | rigMaxTable ) $( rigPty 44 dumb | LC_ALL=C grep -c "$rigEsc" )" "44 0"
rigAssert "--strip-all on a terminal is plain too, and NO_COLOR leaves the codes out" "$( rigPty 44 xterm-256color --strip-all | LC_ALL=C grep -c "$rigEsc" ) $( NO_COLOR=1 rigPty 44 xterm-256color | LC_ALL=C grep -c "$rigEsc" )" "0 0"

echo "-- 6. a character of two cells --"
cat > "$rigTmp/wide.md" <<'RIGWIDE'
| Key | What |
|-----|------|
| a | 📘 a cell with an emoji in it, and enough words after it to wrap in a narrow column |
| 日本語 | 文字 and words |
RIGWIDE
cat > "$rigTmp/cells.py" <<'RIGCELLS'
import sys, unicodedata
width = int(sys.argv[1])
worst = 0
for line in sys.stdin.read().split("\n"):
    cells = sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in line)
    worst = max(worst, cells)
print("fits" if worst <= width else "wider:%d" % worst)
RIGCELLS
rigAssert "none of its lines is wider than the width in cells, a character of two cells counted twice, at 30 and at 40" "$( sh "$rigCat" --width 30 < "$rigTmp/wide.md" | "$rigPython" -I -B "$rigTmp/cells.py" 30 ) $( sh "$rigCat" --width 40 < "$rigTmp/wide.md" | "$rigPython" -I -B "$rigTmp/cells.py" 40 )" "fits fits"

echo "-- 7. plain POSIX awk: every awk of this machine gives the same output --"
rigAwks=""
for rigName in awk gawk mawk nawk original-awk ; do
	command -v "$rigName" > /dev/null 2>&1 && rigAwks="$rigAwks $rigName"
done
command -v busybox > /dev/null 2>&1 && busybox awk 'BEGIN { exit 0 }' > /dev/null 2>&1 && rigAwks="$rigAwks busybox-awk"
rigAwkRun(){ ## awk word, awk options -- the awk over the text with the options of the renderer
	local rigWho="$1" ; shift
	case "$rigWho" in
		busybox-awk) LC_ALL=C busybox awk -f "$rigAwk" -- "$@" < "$rigTmp/doc.md" ;;
		gawk-posix) LC_ALL=C gawk --posix -f "$rigAwk" -- "$@" < "$rigTmp/doc.md" ;;
		*) LC_ALL=C "$rigWho" -f "$rigAwk" -- "$@" < "$rigTmp/doc.md" ;;
	esac
}
command -v gawk > /dev/null 2>&1 && rigAwks="$rigAwks gawk-posix"
rigDiffering=""
for rigForm in "--width=50" "--use-ansi --width=40" "--spans --width=40" "--spans" "--use-ansi" "" ; do
	rigFirst=""
	for rigWho in $rigAwks ; do
		rigHere="$( rigAwkRun "$rigWho" $rigForm | rigSum )"
		if [ -z "$rigFirst" ] ; then rigFirst="$rigHere" ; elif [ "$rigHere" != "$rigFirst" ] ; then rigDiffering="$rigDiffering [$rigForm:$rigWho]" ; fi
	done
done
rigAssert "the awks of this machine (${rigAwks# }) agree on the text, laid out and not, in the codes and for a program" "[$rigDiffering]" "[]"
rigAssert "control: there is at least the awk of the system" "$( [ -n "$rigAwks" ] && echo yes || echo no )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CATMARKDOWN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CATMARKDOWN: OK (%d assertions, offline, awks:%s)\n' "$rigPassCount" "$rigAwks"
