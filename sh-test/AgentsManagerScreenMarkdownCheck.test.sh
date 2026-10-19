#!/usr/bin/env bash
## Behavioural check on Markdown in the left window of the manager screen (sh-lib/manager/AgentsManagerScreen.py), run rather
## than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script
## (check-fixtures/manager-screen.tools.stub.sh), which notes each start and prints the fixture.
## Held: a skillset file and an item of the team data whose name ends in .md show rendered by lib/catMarkdown of
## myx.common, the window holding exactly what its --spans gives at the window's width (whole while lines are cut, the
## text as it is where no catMarkdown is there): its front matter, its
## headings with the line under them (an emoji in one counted as one character of two cells), its strong and emphasized
## words, an underscore inside a word and in code kept, its lists with their marks and nesting, a long item wrapped under
## its own text, its links as their text, its code without its fences, its table in columns with a line under its head,
## its rule and its quote, each part in its look (MARKDOWN_LOOKS); the title says [markdown]. The raw mode (`g`) shows
## the file as it is and says [raw]; the summary mode (`b`) renders it again. A text has that mode of its own, rendered
## first: the raw log of a session leaves it rendered, and its raw mode leaves the mode of a session as it was; shown
## raw, a line longer than the window is broken at its words, its own runs of blanks kept, and with the lines cut it stands whole. It is set out once for each width and
## not on a tick: a line put into the window stays through turns and goes with a new size, which sets it out again,
## narrower. A text that is no Markdown shows as it is; a text longer than the bound is rendered that far and the rest
## follows as it is, under a line that says so. Offline: no operation of the real tooling is called.
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
rigTmp="$( rigTempDir AgentsManagerScreenMarkdownCheck )" || exit 1
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
rigCase(){ ## name -- a rig of its own, every fixture of this check in it
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	cd "$MANAGER_SCREEN_RIG" || exit 1
	printf 'block\tteam-data\tTeam_Data\t2\nfigure\tteam-data\troot\tTeam_Data_Root\t/rig/td\t-\t-\t-\nfigure\tteam-data\tpresent\tTeam_Data_Present\tyes\t-\tok\t-\n' > "rows.--manager-dashboard-read"
	cp "rows.--manager-dashboard-read" "rows.--manager-dashboard-read team-data team-data-git loop"
	printf 'store\tboard\tpresent\t1\t0\nfolder\tboard\trunning\t1\n' > "rows.--manager-team-data-read board"
	printf 'item\tboard\trunning\ttask-a.md\t60\t-\n' > "rows.--manager-team-data-read board running"
	printf -- '---\ntitle: A\n---\n# Task A\n\n- step one\n' > "rows.--manager-team-data-read board running task-a.md"
	rigMember="member	keeper-rig	-	Rig	Keeper	-	keeper	/rig/ws	here	active	no-process	-"
	printf '%s\n' "$rigMember" > "rows.--manager-team-member-list"
	printf '%s\ninfo\tdescription\tA_rig_keeper\n' "$rigMember" > "rows.--manager-team-member-read --full keeper-rig"
	printf 'file\tSKILL.md\t900\tyes\nfile\tnotes.txt\t40\tyes\nfile\tbig.md\t2030\tyes\n' > "rows.--manager-team-member-files keeper-rig"
	cat > "rows.--manager-team-member-files keeper-rig SKILL.md" <<'RIGMD'
---
name: keeper-rig
description: A keeper of the rig.
---
# The rig keeper

Keeps the **rig** in order: calls `mcp__myx_distro__Wait` and reads *MDAT_MANAGER_STYLE* and snake_case_words.

## Lists

- first item
- second item with a [link to the spec](https://example.invalid/spec) inside, and a long tail of words that runs past the width of the window so that it wraps under its own text WRAPEND
  - nested item
1. numbered one

### 📘 Help

```sh
echo "code_block_line"
```

| Key | Value |
|-----|------:|
| a_b | `1` |

---

> A quoted line.
RIGMD
	printf '# not a heading\n**kept as it is**\n' > "rows.--manager-team-member-files keeper-rig notes.txt"
	{ "$rigPython" -I -c 'print("\n" * 1999)' ; printf '# after the bound\n**raw**\n' ; } > "rows.--manager-team-member-files keeper-rig big.md"
	: > "$MANAGER_SCREEN_RIG/calls"
	: > "$MANAGER_SCREEN_RIG/words"
	echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ ## the commands of the driver on standard input, after the ones that name the stand-in, the time and the size; what it printed is kept in rigOut
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 120 36\nroot dashboard\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}
rigLookOf(){ ## show tag, roles tag, text -- the letters of the looks (roles) of the cells under the text, on the first line that holds it
	printf '%s\n' "$rigOut" | "$rigPython" -I -c '
import sys
shown, roles, text = sys.argv[1:4]
lines = sys.stdin.read().split("\n")
texts = [line[len(shown) + 1:] for line in lines if line.startswith(shown + "|")]
letters = [line[len(roles) + 1:] for line in lines if line.startswith(roles + "|")]
for number, line in enumerate(texts):
    if text in line and number < len(letters):
        at = line.index(text)
        print(letters[number][at:at + len(text)])
        break
else:
    print("none")
' "$1" "$2" "$3"
}

echo "-- 1. a skillset file that is Markdown, rendered --"
rigCase files
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 4
wait list 10
keys DOWN ENTER
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
get md
show md
roles mdr
keys g
turn
get raw
show raw
keys b
turn
show back
get wide
viewline MARKER-LINE
turn 3
get held
size 80 36
turn
get narrow
show narrow
keys DOWN
wait view 10
show txt
keys DOWN
wait view 10
show big
RIGSCRIPT
rigAssert "the file is read by the member and its path, and its title says it is rendered" "$( rigVal md.selected ) $( rigHolds md 'SKILL.md [markdown] [wrap]' )" "SKILL.md 1"
rigAssert "its front matter shows as its lines, in the look of the front matter" "$( rigHolds md '│name: keeper-rig' ) $( rigHolds md '│---' ) $( rigLookOf md mdr 'name: keeper-rig' )" "1 0 DDDDDDDDDDDDDDDD"
rigAssert "a heading shows without its marks, a line under it, in the look of its level" "$( rigHolds md '│The rig keeper ' ) $( rigHolds md '│# The rig keeper' ) $( rigHolds md '│━━━━━━━━━━━━━━ ' ) $( rigLookOf md mdr 'The rig keeper' ) $( rigHolds md '│Lists ' ) $( rigHolds md '│───── ' )" "1 0 1 eeeeeeeeeeeeee 1 1"
rigAssert "an emoji in a heading is one character of two cells: the line under it is as long as that" "$( rigHolds md '│┄┄┄┄┄┄┄ ' ) $( rigHolds md '│┄┄┄┄┄┄┄┄' )" "1 0"
rigAssert "strong and emphasized words show without their marks, in their looks" "$( rigHolds md 'Keeps the rig in order' ) $( rigLookOf md mdr 'rig in' ) $( rigLookOf md mdr 'MDAT_MANAGER_STYLE' ) $( rigHolds md '**' )" "1 BBB... kkkkkkkkkkkkkkkkkk 0"
rigAssert "an underscore inside a word and in code is kept, the code in its look and without its marks" "$( rigHolds md 'mcp__myx_distro__Wait' ) $( rigHolds md 'snake_case_words.' ) $( rigLookOf md mdr 'mcp__myx_distro__Wait' ) $( rigHolds md '`' )" "1 1 DDDDDDDDDDDDDDDDDDDDD 0"
rigAssert "the items of a list have their marks, a nested one set in, a numbered one its number" "$( rigHolds md '│➤ first item' ) $( rigLookOf md mdr '➤ first' ) $( rigHolds md '│  ➤ nested item' ) $( rigHolds md '│1. numbered one' )" "1 e...... 1 1"
rigAssert "a long item wraps under its own text, and a link shows as its text" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^md|' | LC_ALL=C grep -c -E '│  [a-z].*WRAPEND' ) $( rigHolds md 'with a link to the spec inside' ) $( rigHolds md 'example.invalid' )" "1 1 0"
rigAssert "code shows without its fences, in the look of code" "$( rigHolds md '│echo "code_block_line"' ) $( rigHolds md '```' ) $( rigLookOf md mdr 'echo' )" "1 0 DDDD"
rigAssert "a table stands in columns, a line under its head, a column aligned to the right" "$( rigHolds md '│Key │ Value ' ) $( rigHolds md '│────┼──────' ) $( rigHolds md '│a_b │     1 ' ) $( rigLookOf md mdr 'Key' )" "1 1 1 BBB"
rigAssert "a rule and a quote" "$( rigHolds md '│────────────────────────────────────────' ) $( rigHolds md '│> A quoted line.' ) $( rigLookOf md mdr 'A quoted' )" "1 1 DDDDDDDD"
rigAssert "the raw mode shows the file as it is, and says so" "$( rigVal raw.textMode ) $( rigHolds raw '│# The rig keeper' ) $( rigHolds raw '│```sh' ) $( rigHolds raw '│| Key | Value |' ) $( rigHolds raw '│- first item' ) $( rigHolds raw 'SKILL.md [raw] [wrap]' )" "raw 1 1 1 1 1"
rigAssert "the summary mode renders it again" "$( rigHolds back '│The rig keeper ' ) $( rigHolds back '│# The rig keeper' ) $( rigHolds back 'SKILL.md [markdown] [wrap]' )" "1 0 1"
rigAssert "it is set out once: a line put into the window stays through turns" "$( rigVal held.viewLines )" "$(( $( rigVal wide.viewLines ) + 1 ))"
rigAssert "a new size sets it out again, narrower" "$( rigHolds narrow 'MARKER-LINE' ) $( [ "$( rigVal narrow.viewLines )" -gt "$( rigVal wide.viewLines )" ] && echo more || echo "not more: $( rigVal narrow.viewLines ) of $( rigVal wide.viewLines )" )" "0 more"
rigAssert "a text that is no Markdown shows as it is" "$( rigHolds txt '│# not a heading' ) $( rigHolds txt '│**kept as it is**' ) $( rigHolds txt '[markdown]' )" "1 1 0"
rigAssert "a text longer than the bound is rendered that far, the rest as it is under a line that says so" "$( rigHolds big '│The first 2000 lines are rendered; the 2 after them' ) $( rigHolds big '│follow as they are.' ) $( rigHolds big '│# after the bound' ) $( rigHolds big '│**raw**' )" "1 1 1 1"
rigOne="$( "$rigPython" -I -B - "$rigScreen" "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common" "$rigTmp/files/rows.--manager-team-member-files keeper-rig SKILL.md" <<'RIGPY' 2>&1
import importlib.util, os, subprocess, sys
spec = importlib.util.spec_from_file_location("AgentsManagerScreen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.setStyle("tv-system")
root, text = sys.argv[2], open(sys.argv[3], encoding="utf-8").read()
def given(*words):
    done = subprocess.run(["sh", os.path.join(root, "bin/lib/catMarkdown.Common"), "--spans"] + list(words), input=text.encode("utf-8"),
                          stdout=subprocess.PIPE, env=dict(os.environ, MYXROOT=root))
    records = [record.split(b"\t") for record in done.stdout.split(b"\n")[:-1]]
    while records and not records[-1][0]:
        records.pop()
    return records
def same(drawn, records):
    lines, looks = drawn
    if [str(line) for line in lines] != [record[0].decode("utf-8") for record in records]:
        return "lines-differ"
    for number, record in enumerate(records):
        want = []
        for span in [part for part in record[1].decode("ascii").split(",") if part]:
            start, length, look = span.split("+")
            start, length = int(start), int(length)
            want.append((module.textWidth(record[0][:start].decode("utf-8")), module.textWidth(record[0][start:start + length].decode("utf-8")), module.MARKDOWN_LOOKS[look]))
        if looks.get(number, []) != want:
            return "looks-differ"
    return "same"
print(same(module.markdownLines(text, 80), given("--width", "79")), same(module.markdownLines(text, module.UNWRAPPED_WIDTH), given("--no-wrap")))
module.MARKDOWN_FOUND["catMarkdownRoot"] = None
lines, looks = module.markdownLines(text, 80)
print("raw" if lines == module.rawLines(text.splitlines(), 80) and not looks else "rendered")
RIGPY
)"
rigAssert "the text is rendered by catMarkdown: the window holds exactly what its --spans gives at that width, each look where it says; cut, it is given whole (--no-wrap); with no catMarkdown there, the text as it is" "$( printf '%s' "$rigOne" | LC_ALL=C tr '\n' ' ' )" "same same raw"

echo "-- 2. an item of the team data that is Markdown, rendered --"
rigCase item
rigScript <<'RIGSCRIPT'
turn
wait list 10
keys 5
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
get item
show item
RIGSCRIPT
rigAssert "a board item is rendered: its front matter, its heading, its list" "$( rigVal item.selected ) $( rigHolds item '│title: A' ) $( rigHolds item '│Task A ' ) $( rigHolds item '│━━━━━━ ' ) $( rigHolds item '│➤ step one' ) $( rigHolds item 'task-a.md [markdown] [wrap]' )" "task-a.md 1 1 1 1 1"

echo "-- 3. a text has a mode of its own, rendered first; raw, its long lines are wrapped --"
rigCase textmode
printf -- '---\ntitle: A\n---\n# Task A\n\nRAWSTART one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five RAWEND\n\nSPACED  aa   bb    cc  dd   ee    ff  gg   hh    ii  jj   kk    ll  mm   nn    oo  pp   qq    rr  ss   tt    uu  vv   ww    xx  yy   zz    END2\n' \
	> "$MANAGER_SCREEN_RIG/rows.--manager-team-data-read board running task-a.md"
rigScript <<'RIGSCRIPT'
turn
wait list 10
mode raw
keys 5
wait list 10
keys DOWN DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait focus 10
keys ENTER
wait list 10
keys DOWN
wait view 10
get first
show first
keys g
turn
get raw
show raw
keys TAB w
turn
show cut
RIGSCRIPT
rigAssert "the raw log of a session leaves a Markdown text rendered: a text has a mode of its own, rendered first" \
	"$( rigVal first.viewMode ) $( rigVal first.textMode ) $( rigHolds first 'task-a.md [markdown] [wrap]' ) $( rigHolds first '│Task A ' )" "raw summary 1 1"
rigAssert "g shows that text raw, and leaves the mode of a session as it was" "$( rigVal raw.textMode ) $( rigVal raw.viewMode ) $( rigHolds raw 'task-a.md [raw] [wrap]' ) $( rigHolds raw '│# Task A' )" "raw raw 1 1"
rigAssert "raw, a line longer than the window is broken at its words, none of it cut, the rest set in under it" \
	"$( rigHolds raw '│RAWSTART one two' ) $( rigHolds raw 'RAWEND' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^raw|' | LC_ALL=C grep 'RAWSTART' | LC_ALL=C grep -c -F '…' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^raw|' | LC_ALL=C grep -c -E '│  [a-z-]+ .*RAWEND' )" "1 1 0 1"
rigAssert "raw, a line broken keeps its own runs of blanks in each piece, broken between words" \
	"$( rigHolds raw '│SPACED  aa   bb    cc  dd   ee    ff' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^raw|' | LC_ALL=C grep -c -E '│  [a-z]{2}  {1,3}[a-z]{2}  {1,3}[a-z]{2}' ) $( rigHolds raw 'END2' )" "1 1 1"
rigAssert "with the lines cut, the long line stands whole, cut at the window" "$( rigHolds cut 'RAWSTART one two' ) $( rigHolds cut 'RAWEND' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep '^cut|' | LC_ALL=C grep 'RAWSTART' | LC_ALL=C grep -c -F '…' ) $( rigHolds cut 'task-a.md [raw] [cut]' )" "1 0 1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN MARKDOWN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_MARKDOWN: OK (%d assertions, offline)\n' "$rigPassCount"
