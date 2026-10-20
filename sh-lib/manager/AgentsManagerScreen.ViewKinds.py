##
## AgentsManagerScreen.ViewKinds.py -- the kinds of view the left window shows: table, panels, Markdown, parameter and sequence.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##
## What the left window shows of the row selected in the list is given by the focus handler of the plugin whose level the list is at (the
## "focus" of a plugin, localView): a spec of one of these kinds, a dict whose "kind" names it, or lines the feature sets out itself.
## The kinds, each a function (state, spec) that gives the lines:
##   table      the one table of the left window: "heads", "rows" (each a list of cells), and the optional "kinds" of the columns, "icons", "looks",
##              "numbered", and "pin", how many columns at the left stay while the table is scrolled sideways (tableSummaryLines)
##   panels     a dashboard-like set of panels, the boxes of figures: "blocks", each {"key", "label", "figures"} (blockGrid)
##   markdown   a text of Markdown rendered, tables included, which are catMarkdown's: "text" (markdownLines)
##   parameter  one variable or parameter: "name", "value", "description", and "more", the pairs (head, text) that follow, as in a setting
##   sequence   a list of blocks, each a spec of a kind, one after another in one view, a blank line between them: "blocks"

VIEW_KINDS = {}


def viewKind(name):
    def register(function):
        VIEW_KINDS[name] = function
        return function
    return register


## The lines a spec of a kind gives, for the left window of now.
def viewKindLines(state, spec):
    return VIEW_KINDS[spec["kind"]](state, spec)


## What the focus handler of a level gave, as the lines of the left window: the lines it set out itself as they are, a spec as its kind sets it out.
def focusLines(state, content):
    return viewKindLines(state, content) if isinstance(content, dict) else content


## A line with the parts of it that are drawn in a look of its own: the cell each starts at, how many cells, the look.
def lookedAt(text, spans):
    line = Looked(text)
    line.looks = list(spans or ())
    return line


@viewKind("table")
def tableKindLines(state, spec):
    return tableSummaryLines(state, spec["heads"], spec["rows"], spec.get("kinds"), spec.get("icons"), spec.get("looks"), spec.get("numbered", False), spec.get("pin"))


## Panels as lines that fill that many cells, each line with the looks of its parts.
def panelLines(blocks, width, place=None):
    lines, looks = blockGrid(blocks, width, place)
    return [lookedAt(line, looks.get(number)) for number, line in enumerate(lines)]


@viewKind("panels")
def panelsKindLines(state, spec):
    return panelLines(spec["blocks"], max(20, state.paneWidth - 2), spec.get("place"))


@viewKind("markdown")
def markdownKindLines(state, spec):
    lines, spans = markdownLines(spec["text"], state.viewWidth)
    return [lookedAt(line, spans.get(number)) for number, line in enumerate(lines)]


## One parameter: its name and its value as the head, bold and the value in the look the spec names for it where it names one; the notes, lines
## that follow the head; its description, broken to the pane, under a blank line; and the pairs of more after another blank line.
def parameterLines(spec, width):
    value = spec["value"]
    head = Looked("%s = %s" % (spec["name"], value))
    head.looks = [(0, textWidth(head), BOLD)] + ([(textWidth(head) - textWidth(value), textWidth(value), spec["valueLook"])] if spec.get("valueLook") is not None else [])
    lines = [head]
    lines.extend(spec.get("notes", ()))
    if spec.get("description"):
        lines.append("")
        lines.extend(wrapToCells(spec["description"], max(10, width - 1)))
    if spec.get("more") is not None:
        lines.append("")
        lines.extend(factLines(spec["more"], width))
    return lines


@viewKind("parameter")
def parameterKindLines(state, spec):
    return parameterLines(spec, state.viewWidth)


@viewKind("sequence")
def sequenceKindLines(state, spec):
    lines = []
    for block in spec["blocks"]:
        if lines:
            lines.append("")
        lines.extend(viewKindLines(state, block))
    return lines
