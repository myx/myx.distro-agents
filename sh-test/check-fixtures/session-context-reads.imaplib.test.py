## Offline stand-in for imaplib: opens no socket, logs every command to
## $FIX_DIR/imap.log, answers from a fixed mailbox. Test fixture only.
import os

def _log(line):
    with open(os.path.join(os.environ["FIX_DIR"], "imap.log"), "a") as h:
        h.write(line + "\n")

MESSAGES = {
    "101": b"From: Alice <alice@rig.invalid>\r\nTo: rig@rig.invalid\r\nSubject: first rig mail\r\nDate: Tue, 06 Oct 2026 10:00:00 +0000\r\nMessage-ID: <m101@rig.invalid>\r\n\r\nHello one.\r\n",
    "102": b"From: Bob <bob@rig.invalid>\r\nTo: rig@rig.invalid\r\nSubject: second rig mail\r\nDate: Tue, 06 Oct 2026 11:00:00 +0000\r\nMessage-ID: <m102@rig.invalid>\r\n\r\nHello two.\r\n",
}

class IMAP4:
    class error(Exception):
        pass
    class abort(error):
        pass

class IMAP4_SSL(IMAP4):
    def __init__(self, host, *a, **k):
        _log("CONNECT %s" % host)
    def login(self, user, password):
        _log("LOGIN %s" % user)
        return "OK", [b"logged in"]
    def select(self, mailbox, readonly=False):
        _log("%s %s" % ("EXAMINE" if readonly else "SELECT", mailbox))
        return "OK", [b"3"]
    def uid(self, command, *args):
        _log("UID %s %s" % (command, " ".join(str(a) for a in args if a is not None)))
        if command == "SEARCH":
            ## An old unseen message the SINCE bound excludes.
            return "OK", [b"101 102 103" if "SINCE" in args else b"99 101 102 103"]
        if command == "FETCH":
            uid = args[0]
            if uid in MESSAGES:
                body = MESSAGES[uid]
                return "OK", [(("%s (UID %s BODY[] {%d}" % (uid, uid, len(body))).encode(), body), b")"]
            return "OK", [None]
        return "BAD", [b"unsupported"]
    def logout(self):
        _log("LOGOUT")
        return "BYE", []
