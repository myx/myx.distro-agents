##
## AgentsManagerScreen.Output.py -- the big output dialog: a command that is followed to its end.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## What the big output dialog says in its line of what it refuses and in its line of the
## result, and how many lines of what it followed it keeps, the last.
OUTPUT_SAYS = {
    "running": "It runs: Esc or Stop asks whether to stop it.",
    "asking": "Stop it? Stop it sends it SIGTERM; Go on and Esc let it run.",
    "stopping": "It was asked to stop: SIGTERM was sent to it.",
    "goon": "It runs on.",
    "status": "Ended with status %d, after %s.",
    "signal": "Ended by signal %d%s, after %s.",
    "unstarted": "It did not start: %s.",
    "waiting": "It waits for the answer: Cancel withdraws the request, Enqueue leaves it pending to act when the answer comes.",
    "cancelAsking": "Cancel it? Cancel sends it SIGTERM, which withdraws the request; Go on lets it wait.",
    "enqueued": "It was asked to leave the request pending: SIGUSR1 was sent to it.",
}
OUTPUT_KEPT = 5000


## The one way to run an operation in the big output dialog and follow it: its label, and
## its words as the dispatcher takes them, and, where it takes any, what goes to it on its standard input (never a word of its command).
## The screen starts it at its next turn (startCalls). `then`, where given, is a second operation that the dialog offers when this one has ended with status 0, as a button of
## its own: {"button": its label, "label": the label of its own dialog, "words": its words}. What decides that is the status the operation ended with, and nothing the screen reads.
def runFollowed(state, label, words, inputText=None, then=None, enqueue=False):
    state.follow = {"key": "follow:" + label, "label": label, "words": list(words), "started": False, "stop": None, "rest": "", "input": inputText, "then": then}
    openDialog(state, "output", {"result": {"lines": [OUTPUT_SAYS["waiting" if enqueue else "running"]]}}, about={"esc": "Cancel" if enqueue else "Stop", "enqueue": enqueue}, title=label)
    if enqueue:
        dialog = outputDialog(state)
        dialog["buttons"] = [("stop", "Cancel"), ("enqueue", "Enqueue")]


## The big output dialog, open or waiting to be.
def outputDialog(state):
    for dialog in [state.dialog] + state.waiting:
        if dialog is not None and dialog["name"] == "output":
            return dialog
    return None


## A line an operation wrote, for the eye: what a carriage return wrote over is gone, and so
## are the sequences of a terminal and every other control character; a tab is spaces.
def outputLine(text):
    text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text.rpartition("\r")[2]).expandtabs(8)
    return "".join(character for character in text if character >= " " or character == "\t")


## A short span of seconds for the eye.
def spanShown(seconds):
    return "%.1fs" % seconds if seconds < 60 else shortSpan(str(int(seconds)))


## What a followed operation wrote, taken into its dialog line by line, and at its end its
## result, in the look of its level: 0 good, an end asked for by Stop a warning, any other
## bad. Then the dialog has OK alone, and the status line says the same.
def followResult(state, result):
    follow = state.follow
    dialog = outputDialog(state)
    if follow is None or dialog is None or result["key"] != follow["key"]:
        return
    output = dialogControl(dialog, "output")
    if "chunk" in result:
        lines = (follow["rest"] + result["chunk"]).split("\n")
        follow["rest"] = lines.pop()
        output["lines"].extend(outputLine(line) for line in lines)
        output["dropped"] = output.get("dropped", 0) + max(0, len(output["lines"]) - OUTPUT_KEPT)
        del output["lines"][:-OUTPUT_KEPT]
        return
    if follow["rest"]:
        output["lines"].append(outputLine(follow["rest"]))
    status = result["status"]
    took = spanShown(result.get("seconds", 0.0))
    if result["error"]:
        said, look = OUTPUT_SAYS["unstarted"] % result["error"], LEVEL_BAD
    elif status < 0:
        try:
            name = " (%s)" % signal.Signals(-status).name
        except ValueError:
            name = ""
        said, look = OUTPUT_SAYS["signal"] % (-status, name, took), LEVEL_WARN if follow["stop"] else LEVEL_BAD
    else:
        said, look = OUTPUT_SAYS["status"] % (status, took), LEVEL_OK if status == 0 else LEVEL_WARN if status == 130 and follow["stop"] else LEVEL_BAD
    shown = dialogControl(dialog, "result")
    shown["lines"] = [said]
    shown["look"] = look
    dialog["buttons"] = [("ok", "OK")]
    if status == 0 and not result["error"] and follow.get("then"):
        dialog["buttons"].append(("then", follow["then"]["button"]))
        dialog["about"]["then"] = follow["then"]
    dialog["focus"] = 0
    dialog["says"] = ""
    dialog["about"].update(ended=True, asking=False, esc="Close")
    state.follow = None
    state.noticeOf = None
    state.notice = "%s: %s" % (follow["label"], said)
    readNow(state)


## Stop is asked about first, in the dialog itself: its buttons are then Stop it and Go on.
def askStop(dialog, asking):
    waits = dialog["about"].get("enqueue")
    dialog["about"].update(asking=asking, esc="Go on" if asking else ("Cancel" if waits else "Stop"))
    if waits:
        dialog["buttons"] = [("stop", "Cancel it"), ("goon", "Go on")] if asking else [("stop", "Cancel"), ("enqueue", "Enqueue")]
    else:
        dialog["buttons"] = [("stop", "Stop it"), ("goon", "Go on")] if asking else [("stop", "Stop")]
    dialog["focus"] = 0
    return OUTPUT_SAYS["cancelAsking" if waits else "asking"] if asking else OUTPUT_SAYS["goon"]


def submitOutput(state, dialog, button):
    if dialog["about"].get("ended") or state.follow is None:
        held = dialog["about"].get("then")
        if button == "then" and held:
            closeDialog(state)
            runFollowed(state, held["label"], held["words"])
        return None
    if button == "enqueue" and dialog["about"].get("enqueue"):
        state.follow["stop"] = "enqueue"
        return OUTPUT_SAYS["enqueued"]
    if button == "stop" and dialog["about"].get("asking"):
        askStop(dialog, False)
        state.follow["stop"] = "asked"
        return OUTPUT_SAYS["stopping"]
    return askStop(dialog, button == "stop")


## Esc while it runs asks whether to stop it, and while that is asked lets it run on;
## once it has ended Esc closes it.
def escapeOutput(state, dialog):
    if dialog["about"].get("ended") or state.follow is None:
        return False
    dialog["says"] = askStop(dialog, not dialog["about"].get("asking"))
    return True


DIALOG_HANDLERS["output"] = submitOutput
DIALOG_ESCAPES["output"] = escapeOutput


## A text that follows its end follows it again once it is scrolled down to the end, and
## stops following where it is scrolled up (drawDialog holds where its end is).
def textFollows(held):
    if held.get("follow"):
        held["following"] = held["top"] >= held.get("bottom", 0)

