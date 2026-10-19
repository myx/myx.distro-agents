#!/usr/bin/env python3
"""Block Kit array (stdin) -> the text version of that message (stdout), for
DistroAgentsTools.fn.sh's --member-comms-slack-send-message --format blocks
path, used ONLY when the caller did not supply --message-text/--message-text-file.

THIS IS NOT THE OLD FALLBACK RENDERER, AND THE DIFFERENCE IS THE WHOLE POINT.
The deleted AgentsSlackBlocksFallbackText.py collected each node's own "text"
key and nothing else. A structured element has no "text" key, so it silently
dropped exactly the elements that mattered: "ping <@U75H0DK43>" came back as
"ping". That loss is what made it a defect rather than a component with a bug.

This generator emits every element in ITS OWN TEXT FORM instead:
  user       -> <@Uxxx>          (the escape form, which Slack parses in `text`)
  usergroup  -> <!subteam^Sxxx>
  channel    -> <#Cxxx>
  broadcast  -> <!here> / <!channel> / <!everyone>
  emoji      -> the unicode character where the payload carries one, else :name:
  link       -> the visible text where there is one, else the bare URL
  date       -> the fallback string Slack itself supplies
Simplified is fine. Lossy is not: an element this does not recognise is
reported to stderr and rendered as a visible placeholder rather than dropped,
so a gap shows up as something to fix instead of as silence.

Python rather than awk/POSIX sh for the same reason the IMAP helper is: this
needs real JSON parsing, and python3 is already an unconditional dependency of
this exact code branch (the Block Kit validator beside it).
"""
import json, sys

unhandled = []


def emoji(el):
    u = el.get("unicode")
    if u:
        try:
            return "".join(chr(int(p, 16)) for p in str(u).split("-"))
        except ValueError:
            pass
    name = el.get("name")
    return ":%s:" % name if name else ""


def inline(el):
    t = el.get("type")
    if t == "text":
        return el.get("text", "")
    if t == "user":
        return "<@%s>" % el.get("user_id", "")
    if t == "usergroup":
        return "<!subteam^%s>" % el.get("usergroup_id", "")
    if t == "channel":
        return "<#%s>" % el.get("channel_id", "")
    if t == "broadcast":
        return "<!%s>" % el.get("range", "channel")
    if t == "emoji":
        return emoji(el)
    if t == "link":
        return el.get("text") or el.get("url", "")
    if t == "date":
        return el.get("fallback") or el.get("timestamp", "")
    if t == "color":
        return el.get("value", "")
    unhandled.append(t)
    return "[%s]" % t


def elements(els):
    return "".join(inline(e) for e in els or [])


def textobj(o):
    if isinstance(o, dict):
        return o.get("text", "")
    return ""


def rich(el, depth=0):
    t = el.get("type")
    if t == "rich_text_section":
        return elements(el.get("elements"))
    if t == "rich_text_preformatted":
        return elements(el.get("elements"))
    if t == "rich_text_quote":
        body = elements(el.get("elements"))
        return "\n".join("> " + ln for ln in body.split("\n"))
    if t == "rich_text_list":
        indent = el.get("indent", 0)
        style = el.get("style", "bullet")
        out = []
        for n, item in enumerate(el.get("elements") or [], 1):
            marker = "%d." % n if style == "ordered" else "-"
            out.append("%s%s %s" % ("  " * indent, marker, rich(item, depth + 1)))
        return "\n".join(out)
    unhandled.append(t)
    return "[%s]" % t


def block(b):
    t = b.get("type")
    if t == "rich_text":
        return "\n".join(rich(e) for e in b.get("elements") or [])
    if t == "section":
        parts = []
        if "text" in b:
            parts.append(textobj(b["text"]))
        for f in b.get("fields") or []:
            parts.append(textobj(f))
        return "\n".join(p for p in parts if p)
    if t == "header":
        return textobj(b.get("text"))
    if t == "context":
        return " ".join(
            (textobj(e) if e.get("type") in ("mrkdwn", "plain_text") else inline(e))
            for e in b.get("elements") or []
        )
    if t == "divider":
        return "---"
    if t == "image":
        return b.get("alt_text") or b.get("image_url", "")
    if t == "video":
        return b.get("title_url") or b.get("alt_text", "")
    if t in ("actions", "input", "file"):
        return ""
    unhandled.append(t)
    return "[%s]" % t


def main():
    try:
        blocks = json.load(sys.stdin)
    except Exception as exc:
        sys.stderr.write("blocks->text: input is not valid JSON: %s\n" % exc)
        return 1
    if not isinstance(blocks, list):
        sys.stderr.write("blocks->text: input is not a Block Kit array\n")
        return 1
    parts = [block(b) for b in blocks if isinstance(b, dict)]
    out = "\n".join(p for p in parts if p != "")
    if unhandled:
        sys.stderr.write(
            "blocks->text: no text form for element type(s): %s -- rendered as a visible placeholder, NOT dropped. Supply --message-text, or add the type here.\n"
            % ", ".join(sorted(set(unhandled)))
        )
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
