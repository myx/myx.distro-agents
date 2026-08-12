#!/usr/bin/env python3
##
## Fetches one full RFC822 message by UID and writes its raw bytes to stdout.
##
## Exists because curl cannot do this at all. curl has exactly two IMAP fetch
## routes and BOTH are wrong here:
##   --request "UID FETCH <uid> BODY.PEEK[]"  -- curl's custom-request path
##       prints the untagged response header line and then STOPS: it never
##       consumes the IMAP literal that follows. The whole observed defect was
##       this -- 44 bytes of "* 108 FETCH (UID 108 BODY[] {38263}" + "* * *"
##       on stdout, rc=0, against a 38263-byte message that arrived intact on
##       the wire and was thrown away by curl's own parser.
##   imaps://host/INBOX;UID=<uid>  -- curl's URL-addressing path DOES consume
##       the literal, but it issues a plain FETCH BODY[], and curl exposes no
##       BODY.PEEK variant, so it sets \Seen as an unavoidable protocol side
##       effect. That would silently consume the unseen state that
##       --member-comms-email-check reports on and --member-comms-email-mark-seen owns.
## imaplib gets both halves right: EXAMINE opens the mailbox read-only (so the
## server cannot set \Seen even in principle, not merely "we asked it not to"),
## and BODY.PEEK[] asks for the body without the flag side effect.
##
## Credentials arrive ONLY through the environment, never argv -- argv is
## world-readable in the process list. The caller reads them through the
## sanctioned --agents-config-option --select reader and hands them over here;
## nothing in this file names a credential variable from .local/.agents.
##
## Exit codes are the contract that keeps "nothing there" distinguishable from
## "broken", which is precisely what the defect destroyed by returning rc=0 for
## a failed read:
##   0  message fetched, raw bytes on stdout
##   2  connection/login/protocol-level failure -- nothing was read
##   3  server refused the FETCH (NO/BAD) -- nothing was read
##   4  the UID does not exist in the mailbox -- a real, empty, non-error
##      answer, reported as its own status rather than as success-with-no-bytes
##

import os
import sys
import imaplib


def fail(code, message):
    sys.stderr.write("%s\n" % message)
    raise SystemExit(code)


host = os.environ.get("AGENTS_IMAP_HOST", "").strip()
user = os.environ.get("AGENTS_IMAP_USER", "").strip()
password = os.environ.get("AGENTS_IMAP_PASS", "")
mailbox = os.environ.get("AGENTS_IMAP_MAILBOX", "").strip() or "INBOX"
uid = os.environ.get("AGENTS_IMAP_UID", "").strip()

if not host or not user or not password:
    fail(2, "AgentsImapFetchMessage: IMAP host/user/password not supplied in the environment")
if not uid.isdigit():
    fail(2, "AgentsImapFetchMessage: AGENTS_IMAP_UID must be a bare numeric UID, got: %r" % uid)

try:
    connection = imaplib.IMAP4_SSL(host)
except Exception as error:
    fail(2, "AgentsImapFetchMessage: cannot connect to imaps://%s -- %s" % (host, error))

try:
    try:
        connection.login(user, password)
    except Exception as error:
        fail(2, "AgentsImapFetchMessage: login failed for %s on imaps://%s -- %s" % (user, host, error))

    ## readonly=True is EXAMINE, not SELECT: the server itself refuses to
    ## mutate flags on this session, so a read provably cannot mark \Seen.
    status, _ = connection.select(mailbox, readonly=True)
    if status != "OK":
        fail(3, "AgentsImapFetchMessage: EXAMINE %s refused on imaps://%s" % (mailbox, host))

    try:
        status, parts = connection.uid("FETCH", uid, "(BODY.PEEK[])")
    except Exception as error:
        fail(3, "AgentsImapFetchMessage: UID FETCH %s failed on imaps://%s/%s -- %s" % (uid, host, mailbox, error))

    if status != "OK":
        fail(3, "AgentsImapFetchMessage: UID FETCH %s returned %s on imaps://%s/%s" % (uid, status, host, mailbox))

    ## A missing UID is an OK response whose data carries no literal part at
    ## all (imaplib renders it as [None]). That is genuinely "no such message",
    ## not a failure and not an empty message -- it gets its own exit code so a
    ## caller can never read it as a successful empty fetch.
    body = None
    for part in parts or []:
        if isinstance(part, tuple) and len(part) > 1 and part[1] is not None:
            body = part[1]
            break

    if body is None:
        fail(4, "AgentsImapFetchMessage: UID %s does not exist in %s on imaps://%s" % (uid, mailbox, host))

    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()
finally:
    try:
        connection.logout()
    except Exception:
        pass
