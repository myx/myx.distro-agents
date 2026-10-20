#!/usr/bin/env python3
##
## AgentsCollectMailDate.py -- the UTC date of ONE message, as the naming Rule writes a date in an item's name: the raw RFC822
## bytes on stdin, `YYYYMMDD'T'HHmm'Z'` on stdout; `-` where the message has no Date header or none that can be read. The
## collection of a mailbox (AgentsTools.Collect.include) names the note of a message by it. Nothing else is read or kept.
##

import datetime
import email
import sys
from email import policy
from email.utils import parsedate_to_datetime

try:
    message = email.message_from_bytes(sys.stdin.buffer.read(), policy=policy.default)
    moment = parsedate_to_datetime(str(message["Date"]))
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=datetime.timezone.utc)
    sys.stdout.write(moment.astimezone(datetime.timezone.utc).strftime("%Y%m%dT%H%MZ") + "\n")
except Exception:
    sys.stdout.write("-\n")
