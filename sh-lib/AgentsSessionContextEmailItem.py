#!/usr/bin/env python3
##
## AgentsSessionContextEmailItem.py -- renders ONE fetched message, raw RFC822
## bytes on stdin, as the session-context document's own per-item block.
## NO BODY IS EMITTED. Exit 2: the message could not be parsed at all.
##

import email
import os
import sys
from email import policy


## A block is one `key: value` per line: an embedded newline would forge a key line.
def oneLine(value):
    for character in ("\n", "\r", "\t"):
        value = value.replace(character, " ")
    return value


## An absent value is stated, never an error, never a present-but-blank header.
def headerValue(message, name):
    try:
        raw = message[name]
    except Exception:
        return "<unreadable>"
    if raw is None:
        return "<none>"
    try:
        text = oneLine(str(raw)).strip()
    except Exception:
        return "<unreadable>"
    return text if text else "<none>"


uid = os.environ.get("AGENTS_EMAIL_UID", "").strip()
mailbox = os.environ.get("AGENTS_EMAIL_MAILBOX", "").strip() or "INBOX"
status = os.environ.get("AGENTS_EMAIL_STATUS", "").strip() or "unseen"

if not uid.isdigit():
    sys.stderr.write(
        "⛔ ERROR: AgentsSessionContextEmailItem: AGENTS_EMAIL_UID must be a bare numeric UID, got: %r\n" % uid
    )
    raise SystemExit(2)

## Binary, never the text parser: the raw bytes' charset is declared inside the message.
try:
    message = email.message_from_binary_file(sys.stdin.buffer, policy=policy.default)
except Exception as error:
    sys.stderr.write(
        "⛔ ERROR: AgentsSessionContextEmailItem: UID %s could not be parsed as RFC822 -- %s\n" % (uid, error)
    )
    raise SystemExit(2)

block = "## email-message %s\nmailbox: %s\nstatus: %s\nfrom: %s\ndate: %s\nsubject: %s\n" % (
    uid,
    oneLine(mailbox),
    oneLine(status),
    headerValue(message, "from"),
    headerValue(message, "date"),
    headerValue(message, "subject"),
)

## Encoded here rather than left to sys.stdout: every caller runs under LC_ALL=C.
sys.stdout.buffer.write(block.encode("utf-8", "replace"))
sys.stdout.buffer.flush()
