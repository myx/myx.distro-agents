## Offline stand-in for imaplib, for the collection check: opens no socket, logs every command to $FIX_DIR/imap.log,
## answers from the mailbox the check keeps in $FIX_DIR/mailbox (one line `<uid> <unseen|seen|ghost>` for each message; a ghost is
## found by the search and has no message to fetch, as a UID expunged in between) and
## generates each message from its uid. A command that would change a read state (STORE, COPY, EXPUNGE, a SELECT that is
## not read-only) is logged under its own name and answered OK, so the check can count that none was sent.
## $FIX_DIR/login-fails, when present, makes the login fail. Test fixture only.
import os


def _log(line):
    with open(os.path.join(os.environ["FIX_DIR"], "imap.log"), "a") as handle:
        handle.write(line + "\n")


def _mailbox():
    rows = []
    path = os.path.join(os.environ["FIX_DIR"], "mailbox")
    if not os.path.exists(path):
        return rows
    with open(path) as handle:
        for line in handle:
            parts = line.split()
            if len(parts) == 2:
                rows.append((parts[0], parts[1]))
    return rows


def _message(uid):
    number = int(uid)
    return (
        "From: Sender %s <sender%s@rig.invalid>\r\nTo: rig@rig.invalid\r\nSubject: collect rig mail %s\r\n"
        "Date: Tue, 06 Oct 2026 10:%02d:00 +0000\r\nMessage-ID: <m%s@rig.invalid>\r\n\r\nBody of rig mail %s.\r\n"
        % (uid, uid, uid, number % 60, uid, uid)
    ).encode()


class IMAP4:
    class error(Exception):
        pass

    class abort(error):
        pass


class IMAP4_SSL(IMAP4):
    def __init__(self, host, *args, **kwargs):
        _log("CONNECT %s" % host)

    def login(self, user, password):
        if os.path.exists(os.path.join(os.environ["FIX_DIR"], "login-fails")):
            _log("LOGIN-REFUSED %s" % user)
            raise IMAP4.error("authentication failed")
        _log("LOGIN %s" % user)
        return "OK", [b"logged in"]

    def select(self, mailbox, readonly=False):
        _log("%s %s" % ("EXAMINE" if readonly else "SELECT", mailbox))
        return "OK", [str(len(_mailbox())).encode()]

    def uid(self, command, *args):
        _log("UID %s %s" % (command, " ".join(str(a) for a in args if a is not None)))
        if command == "SEARCH":
            unseen = [uid for (uid, state) in _mailbox() if state in ("unseen", "ghost")]
            return "OK", [" ".join(unseen).encode()]
        if command == "FETCH":
            uid = args[0]
            for (known, state) in _mailbox():
                if known == uid and state != "ghost":
                    body = _message(uid)
                    return "OK", [(("%s (UID %s BODY[] {%d}" % (uid, uid, len(body))).encode(), body), b")"]
            return "OK", [None]
        return "OK", [b"done"]

    def store(self, *args):
        _log("STORE %s" % " ".join(str(a) for a in args))
        return "OK", [b"done"]

    def copy(self, *args):
        _log("COPY %s" % " ".join(str(a) for a in args))
        return "OK", [b"done"]

    def expunge(self):
        _log("EXPUNGE")
        return "OK", [b"done"]

    def logout(self):
        _log("LOGOUT")
        return "BYE", []
