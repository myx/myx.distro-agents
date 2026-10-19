#!/usr/bin/env python3
##
## AgentsImapSweepFetch.py -- the session-context scan's whole email read, in
## ONE IMAP session: one login, one EXAMINE, one UID SEARCH, then a UID FETCH
## per message the scan will render. The scan used to log in once for the
## search (twice: STATUS and SEARCH) and once more per message, through
## --member-comms-email-check and --member-comms-email-read.
##
## Same read discipline as AgentsImapFetchMessage.py, whose header says why it
## is imaplib and not curl: EXAMINE opens the mailbox read-only, and BODY.PEEK[]
## fetches without the \Seen side effect, so unread stays unread.
##
## Environment (credentials only ever here, never argv):
##   AGENTS_IMAP_HOST, AGENTS_IMAP_USER, AGENTS_IMAP_PASS
##   AGENTS_IMAP_MAILBOX   default INBOX
##   AGENTS_IMAP_SINCE     optional dd-Mon-yyyy; adds SINCE to the search
##   AGENTS_IMAP_MAX       how many of the found UIDs to fetch, in search order
##   AGENTS_IMAP_OUT_DIR   where <uid>.eml (raw bytes) and <uid>.rc land
##
## stdout: the search answer as one "* SEARCH <uid>..." line, the shape the
## scan already reads. Per fetched UID, <uid>.rc holds 0 (fetched), 3 (the
## server refused that FETCH) or 4 (no such UID) -- the codes of
## AgentsImapFetchMessage.py. A UID whose turn never came because the session
## broke has no .rc file at all.
##
## Exit: 0 the search answered (fetches may still have failed one by one);
## 2 connection, login, EXAMINE or SEARCH failed -- nothing is known.
##

import os
import re
import sys
import imaplib


def fail(code, message):
    sys.stderr.write("%s\n" % message)
    raise SystemExit(code)


host = os.environ.get("AGENTS_IMAP_HOST", "").strip()
user = os.environ.get("AGENTS_IMAP_USER", "").strip()
password = os.environ.get("AGENTS_IMAP_PASS", "")
mailbox = os.environ.get("AGENTS_IMAP_MAILBOX", "").strip() or "INBOX"
since = os.environ.get("AGENTS_IMAP_SINCE", "").strip()
maxText = os.environ.get("AGENTS_IMAP_MAX", "").strip()
outDir = os.environ.get("AGENTS_IMAP_OUT_DIR", "").strip()

if not host or not user or not password:
    fail(2, "AgentsImapSweepFetch: IMAP host/user/password not supplied in the environment")
if since and not re.match(r"^[0-9]{1,2}-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-[0-9]{4}$", since):
    fail(2, "AgentsImapSweepFetch: AGENTS_IMAP_SINCE must be dd-Mon-yyyy, got: %r" % since)
if not maxText.isdigit():
    fail(2, "AgentsImapSweepFetch: AGENTS_IMAP_MAX must be a count, got: %r" % maxText)
if not outDir or not os.path.isdir(outDir):
    fail(2, "AgentsImapSweepFetch: AGENTS_IMAP_OUT_DIR is not a directory: %r" % outDir)
maxFetch = int(maxText)

try:
    connection = imaplib.IMAP4_SSL(host)
except Exception as error:
    fail(2, "AgentsImapSweepFetch: cannot connect to imaps://%s -- %s" % (host, error))

try:
    try:
        connection.login(user, password)
    except Exception as error:
        fail(2, "AgentsImapSweepFetch: login failed for %s on imaps://%s -- %s" % (user, host, error))

    status, _ = connection.select(mailbox, readonly=True)
    if status != "OK":
        fail(2, "AgentsImapSweepFetch: EXAMINE %s refused on imaps://%s" % (mailbox, host))

    criteria = ["UNSEEN"]
    if since:
        criteria += ["SINCE", since]
    try:
        status, data = connection.uid("SEARCH", None, *criteria)
    except Exception as error:
        fail(2, "AgentsImapSweepFetch: UID SEARCH %s failed on imaps://%s/%s -- %s" % (" ".join(criteria), host, mailbox, error))
    if status != "OK":
        fail(2, "AgentsImapSweepFetch: UID SEARCH %s returned %s on imaps://%s/%s" % (" ".join(criteria), status, host, mailbox))
    uids = []
    for part in data or []:
        if isinstance(part, bytes):
            part = part.decode("ascii", "replace")
        if part:
            uids += [u for u in part.split() if u.isdigit()]
    sys.stdout.write("* SEARCH%s\n" % "".join(" " + u for u in uids))
    sys.stdout.flush()

    for uid in uids[:maxFetch]:
        try:
            status, parts = connection.uid("FETCH", uid, "(BODY.PEEK[])")
        except (imaplib.IMAP4.abort, OSError) as error:
            ## The session itself is gone: every UID still to come stays without
            ## an .rc file, which the scan states as not read.
            sys.stderr.write("AgentsImapSweepFetch: the session broke at UID %s on imaps://%s/%s -- %s\n" % (uid, host, mailbox, error))
            break
        except Exception as error:
            sys.stderr.write("AgentsImapSweepFetch: UID FETCH %s failed on imaps://%s/%s -- %s\n" % (uid, host, mailbox, error))
            status, parts = "NO", None
        code = 3
        if status == "OK":
            body = None
            for part in parts or []:
                if isinstance(part, tuple) and len(part) > 1 and part[1] is not None:
                    body = part[1]
                    break
            if body is None:
                code = 4
            else:
                with open(os.path.join(outDir, uid + ".eml"), "wb") as handle:
                    handle.write(body)
                code = 0
        with open(os.path.join(outDir, uid + ".rc"), "w") as handle:
            handle.write("%d\n" % code)
finally:
    try:
        connection.logout()
    except Exception:
        pass
