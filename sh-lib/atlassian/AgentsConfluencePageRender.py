#!/usr/bin/env python3
#
# AgentsConfluencePageRender.py -- one Confluence page body, rendered from its one source.
#
# WHY PYTHON. The inline conversions are capture-group matches over markdown, and the hand-edit
# report is a line diff. The fleet's awk has no match(s, re, arr) and no capture groups, which is
# the same reason AgentsConfluencePageCheck.py is Python.
#
# DETERMINISTIC BY CONSTRUCTION. No timestamp, no version number and no counter is emitted, so two
# renders of one source are byte-identical and a whole-body write is safe when its sources did not
# change. The page's own "last reviewed" field carries whatever date the source states; nothing here
# reads the clock.
#
# ONE OUTPUT LINE PER BLOCK, so a change to one source line changes exactly one output line. That is
# what makes the parity comparison a line diff rather than a byte diff, and what makes a hand edit
# to a live page report as the lines the render did not produce.
#
# THE PARAGRAPH AROUND AN ITEM AND A CELL IS PART OF THE BODY. A live body holds a list item's text and
# a table cell's inside a <p>, header cells included, so the render emits that wrapper too.
#
# WHAT CONFLUENCE ADDS AT SAVE, and what the comparison therefore normalises: a `local-id`
# attribute on every block, and a `ri:version-at-save` pin on every internal link. Measured on the
# stored bodies of 4919689217 and 4861362189. A render emits neither, so a raw byte comparison of a
# live body against a render reports every block as changed and measures nothing.
#
# Input: the source text on stdin. Environment:
#   AGENTS_RENDER_SOURCE_SPEC  the spec as the caller gave it; its own `Source:` line
#   AGENTS_RENDER_HEADING      the heading whose section is rendered (empty for the whole source)
#   AGENTS_RENDER_LIVE_FILE    optional: a file holding the live body, for the hand-edit report
import difflib
import html
import os
import re
import sys

REVIEW_LINE = "AI-generated \u2014 not yet reviewed"
headingShape = re.compile(r"^(#{1,6}) ")
inlineShape = re.compile(
    r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"
    r"|\[([^\]]+)\]\(([^)]+)\)"
    r"|\*\*([^*]+)\*\*"
    r"|`([^`]+)`"
    r"|(\[[MDI]: ?[^\]]*\])"
    r"|(\((?:dev|lib|arch)\b[^)]*\))"
)
orderedItemShape = re.compile(r"^(\d+)\. ")
addedAtSave = re.compile(r' local-id="[^"]*"| ri:version-at-save="[^"]*"')
frontmatterRule = re.compile(r"^---$")


def headingLevel(line):
    found = headingShape.match(line)
    return len(found.group(1)) if found else 0


def sectionLines(text, headingText):
    """The lines of one named section, its own heading excluded. Frontmatter is never rendered."""
    lines = text.split("\n")
    if not headingText:
        if lines and frontmatterRule.match(lines[0]):
            for index in range(1, len(lines)):
                if frontmatterRule.match(lines[index]):
                    lines = lines[index + 1:]
                    break
        return lines
    for index, line in enumerate(lines):
        level = headingLevel(line)
        if level and line[level + 1:].strip() == headingText:
            begin, outerLevel = index + 1, level
            break
    else:
        sys.exit("\u26d4 ERROR: AgentsConfluencePageRender.py: the source holds no heading %r, so "
                 "nothing was rendered -- a render that cannot reach its subject never prints a "
                 "body" % headingText)
    kept = []
    for line in lines[begin:]:
        level = headingLevel(line)
        if level and level <= outerLevel:
            break
        kept.append(line)
    return kept


def inline(text):
    """One line of markdown as storage-format inline markup. Every character outside a construct is
    HTML-escaped, so a source holding an ampersand or an angle bracket stays a source."""
    pieces, pos = [], 0
    for found in inlineShape.finditer(text):
        pieces.append(html.escape(text[pos:found.start()], quote=False))
        if found.group(1) is not None:
            title = found.group(1).strip()
            body = html.escape((found.group(2) or title).strip(), quote=False)
            pieces.append('<ac:link><ri:page ri:content-title="%s" /><ac:link-body>%s</ac:link-body>'
                          '</ac:link>' % (html.escape(title, quote=True), body))
        elif found.group(3) is not None:
            pieces.append('<a href="%s">%s</a>' % (html.escape(found.group(4).strip(), quote=True),
                                                   html.escape(found.group(3), quote=False)))
        elif found.group(5) is not None:
            pieces.append("<strong>%s</strong>" % html.escape(found.group(5), quote=False))
        elif found.group(6) is not None:
            pieces.append("<code>%s</code>" % html.escape(found.group(6), quote=False))
        elif found.group(7) is not None:
            ## An evidence mark is stored italic between its code spans, never one em around them.
            pieces.append(re.sub(r"`([^`]+)`", r"</em><code>\1</code><em>",
                                 "<em>%s</em>" % html.escape(found.group(7), quote=False)))
        else:
            pieces.append("<em>%s</em>" % html.escape(found.group(8), quote=False))
        pos = found.end()
    pieces.append(html.escape(text[pos:], quote=False))
    return "".join(pieces)


def tableRow(line):
    return [one.strip() for one in line.strip().strip("|").split("|")]


def isTableRule(line):
    return bool(re.match(r"^\|?[\s:-]*-[\s|:-]*$", line.strip()))


def renderBlocks(lines, sourceSpec):
    blocks = ["<p>Source: %s</p>" % html.escape(sourceSpec, quote=False),
              "<p>%s</p>" % REVIEW_LINE]
    items, rows, para = [], [], []
    listTag, listStart = "ul", 1

    def flushItems():
        nonlocal listTag, listStart
        if items:
            if listTag == "ol":
                blocks.append('<ol start="%d">%s</ol>'
                              % (listStart, "".join("<li><p>%s</p></li>" % inline(one) for one in items)))
            else:
                blocks.append("<ul>%s</ul>"
                              % "".join("<li><p>%s</p></li>" % inline(one) for one in items))
            del items[:]
            listTag, listStart = "ul", 1

    def flushRows():
        if not rows:
            return
        head, rest = rows[0], rows[1:]
        cells = "".join("<th><p>%s</p></th>" % inline(one) for one in head)
        body = "".join("<tr>%s</tr>" % "".join("<td><p>%s</p></td>" % inline(one) for one in row)
                       for row in rest)
        blocks.append("<table><tbody><tr>%s</tr>%s</tbody></table>" % (cells, body))
        del rows[:]

    def flushPara():
        if para:
            blocks.append("<p>%s</p>" % inline(" ".join(para)))
            del para[:]

    def flushAll():
        flushItems()
        flushRows()
        flushPara()

    for line in lines:
        stripped = line.rstrip()
        if not stripped.strip():
            flushAll()
            continue
        level = headingLevel(stripped)
        if level:
            flushAll()
            text = stripped[level + 1:].strip()
            blocks.append("<h%d>%s</h%d>" % (level, inline(text), level))
        elif stripped.startswith("- "):
            flushRows()
            flushPara()
            itemText = stripped[2:].strip()
            foundNumber = orderedItemShape.match(itemText)
            foundTag = "ol" if foundNumber else "ul"
            if listTag != foundTag:
                flushItems()
            if foundNumber:
                if not items:
                    listTag, listStart = "ol", int(foundNumber.group(1))
                itemText = itemText[foundNumber.end():].strip()
            items.append(itemText)
        elif stripped.startswith("|"):
            flushItems()
            flushPara()
            if not isTableRule(stripped):
                rows.append(tableRow(stripped))
        elif stripped.startswith("> "):
            flushAll()
            blocks.append("<blockquote><p>%s</p></blockquote>" % inline(stripped[2:].strip()))
        elif stripped.startswith("    "):
            flushAll()
            blocks.append("<pre>%s</pre>" % html.escape(stripped[4:], quote=False))
        else:
            flushItems()
            flushRows()
            para.append(stripped.strip())
    flushAll()
    return blocks


def normalise(bodyText):
    """The live form and the render form of one body, with what a save adds taken out."""
    return [addedAtSave.sub("", one).strip() for one in bodyText.split("\n") if one.strip()]


def reportHandEdit(renderText, liveText):
    """What the live page holds that the render does not produce, and the other way round. Returns
    the count of lines only the live page carries: those are the hand edits."""
    liveOnly, renderOnly = [], []
    for change in difflib.unified_diff(normalise(renderText), normalise(liveText), n=0, lineterm=""):
        if change.startswith("---") or change.startswith("+++") or change.startswith("@@"):
            continue
        if change.startswith("-"):
            renderOnly.append(change[1:])
        elif change.startswith("+"):
            liveOnly.append(change[1:])
    sys.stderr.write("# page-render: the live page and the render differ: %d line(s) only in the "
                     "live page, %d only in the render\n" % (len(liveOnly), len(renderOnly)))
    for one in liveOnly[:10]:
        sys.stderr.write("# page-render: HAND EDIT, only in the live page: %s\n" % one)
    for one in renderOnly[:10]:
        sys.stderr.write("# page-render: only in the render, so a write would add it: %s\n" % one)
    return len(liveOnly)


sourceSpec = os.environ.get("AGENTS_RENDER_SOURCE_SPEC", "").strip()
headingText = os.environ.get("AGENTS_RENDER_HEADING", "").strip()
liveFile = os.environ.get("AGENTS_RENDER_LIVE_FILE", "").strip()

sourceText = sys.stdin.read()
renderText = "\n".join(renderBlocks(sectionLines(sourceText, headingText), sourceSpec)) + "\n"

if liveFile:
    try:
        with open(liveFile, encoding="utf-8") as handle:
            liveText = handle.read()
    except OSError as error:
        sys.exit("\u26d4 ERROR: AgentsConfluencePageRender.py: the live body could not be read "
                 "(%s), so whether the page was hand edited is UNKNOWN and nothing was reported"
                 % error)
    differing = reportHandEdit(renderText, liveText)
    sys.stdout.write(renderText)
    sys.exit(1 if differing else 0)

sys.stdout.write(renderText)
