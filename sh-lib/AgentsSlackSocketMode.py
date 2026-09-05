#!/usr/bin/env python3
##
## AgentsSlackSocketMode.py -- the team bot's socket-mode receiver: opens the
## connection, acknowledges every envelope, and files an app_mention into
## magic-coordinator's own inbox. Rationale and mechanism:
## myx.distro-agents/MAGIC.md.
##

import base64
import hashlib
import json
import os
import socket
import ssl
import struct
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from urllib.parse import urlparse

HANDSHAKE_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
OPCODE_CONTINUATION = 0x0
OPCODE_TEXT = 0x1
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA


def logLine(text):
    sys.stderr.write("%s AgentsSlackSocketMode.py: %s\n" % (
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), text))
    sys.stderr.flush()


def connectSocket(socketUrl):
    urlParts = urlparse(socketUrl)
    if urlParts.scheme != "wss":
        raise RuntimeError("only wss:// is supported, got %r" % urlParts.scheme)
    hostName = urlParts.hostname
    requestPath = (urlParts.path or "/") + (("?" + urlParts.query) if urlParts.query else "")

    rawSocket = socket.create_connection((hostName, urlParts.port or 443), timeout=30)
    wrappedSocket = ssl.create_default_context().wrap_socket(rawSocket, server_hostname=hostName)

    handshakeKey = base64.b64encode(os.urandom(16)).decode("ascii")
    wrappedSocket.sendall((
        "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\n"
        "Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n" % (requestPath, hostName, handshakeKey)
    ).encode("ascii"))

    # byte at a time: reading past the blank line consumes the first frame
    headBytes = b""
    while b"\r\n\r\n" not in headBytes:
        chunk = wrappedSocket.recv(1)
        if not chunk:
            raise RuntimeError("connection closed during handshake")
        headBytes += chunk

    headText = headBytes.decode("latin-1")
    if " 101 " not in headText.split("\r\n")[0]:
        raise RuntimeError("upgrade refused: %s" % headText.split("\r\n")[0])

    expectAccept = base64.b64encode(
        hashlib.sha1((handshakeKey + HANDSHAKE_GUID).encode("ascii")).digest()).decode("ascii")
    gotAccept = ""
    for headLine in headText.split("\r\n"):
        if headLine.lower().startswith("sec-websocket-accept:"):
            gotAccept = headLine.split(":", 1)[1].strip()
    if gotAccept != expectAccept:
        raise RuntimeError("bad Sec-WebSocket-Accept: expected %s, got %s" % (expectAccept, gotAccept))
    return wrappedSocket


def sendFrame(wrappedSocket, opcodeValue, framePayload=b""):
    frameHeader = struct.pack("!B", 0x80 | opcodeValue)
    payloadLength = len(framePayload)
    if payloadLength < 126:
        frameHeader += struct.pack("!B", 0x80 | payloadLength)
    elif payloadLength < (1 << 16):
        frameHeader += struct.pack("!BH", 0x80 | 126, payloadLength)
    else:
        frameHeader += struct.pack("!BQ", 0x80 | 127, payloadLength)
    frameMask = os.urandom(4)
    wrappedSocket.sendall(
        frameHeader + frameMask + bytes(b ^ frameMask[i % 4] for i, b in enumerate(framePayload)))


def recvExact(wrappedSocket, byteCount):
    readBytes = b""
    while len(readBytes) < byteCount:
        chunk = wrappedSocket.recv(byteCount - len(readBytes))
        if not chunk:
            return None
        readBytes += chunk
    return readBytes


def recvFrame(wrappedSocket):
    frameHead = recvExact(wrappedSocket, 2)
    if frameHead is None:
        return None, None, None
    opcodeValue = frameHead[0] & 0x0F
    isFinal = bool(frameHead[0] & 0x80)
    payloadLength = frameHead[1] & 0x7F
    isMasked = bool(frameHead[1] & 0x80)
    if payloadLength == 126:
        lengthBytes = recvExact(wrappedSocket, 2)
        if lengthBytes is None:
            return None, None, None
        payloadLength = struct.unpack("!H", lengthBytes)[0]
    elif payloadLength == 127:
        lengthBytes = recvExact(wrappedSocket, 8)
        if lengthBytes is None:
            return None, None, None
        payloadLength = struct.unpack("!Q", lengthBytes)[0]
    frameMask = recvExact(wrappedSocket, 4) if isMasked else None
    framePayload = recvExact(wrappedSocket, payloadLength) if payloadLength else b""
    if framePayload is None:
        return None, None, None
    if frameMask:
        framePayload = bytes(b ^ frameMask[i % 4] for i, b in enumerate(framePayload))
    return opcodeValue, framePayload, isFinal


## The one place the receiver leaves Slack's protocol for the team's own
## machinery: an arriving mention becomes triage input magic-coordinator
## already reads, reached through the tool rather than by writing a file.
def fileInquiry(eventBody, toolPath):
    channelId = eventBody.get("channel", "")
    messageTs = eventBody.get("ts", "")
    itemName = "inquiry-%s-slack-mention-%s.md" % (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"), channelId)
    itemBody = (
        "---\n"
        "type: inquiry\n"
        "from: magic-team\n"
        "date: %s\n"
        "owner: magic-coordinator\n"
        "communication-channel-id: slack:%s:%s\n"
        "---\n"
        "\n"
        "# The team bot was mentioned in Slack\n"
        "\n"
        "- user: %s\n"
        "- channel: %s\n"
        "- message: %s\n"
        "\n"
        "## Text\n"
        "\n"
        "%s\n"
    ) % (
        datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %z"),
        channelId, eventBody.get("thread_ts", "") or messageTs,
        eventBody.get("user", ""), channelId, messageTs,
        eventBody.get("text", ""),
    )
    filingResult = subprocess.run(
        [toolPath, "--member-upsert-member-inquiry", "magic-coordinator", itemName],
        input=itemBody.encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if filingResult.returncode != 0:
        logLine("FILING FAILED %s rc=%d -- the envelope is already acknowledged, so Slack will not resend it: %s" % (
            itemName, filingResult.returncode, filingResult.stdout.decode("utf-8", "replace").strip()))
        return
    logLine("filed %s" % itemName)


def pumpSocket(wrappedSocket, toolPath):
    pendingPayload = None
    while True:
        opcodeValue, framePayload, isFinal = recvFrame(wrappedSocket)
        if opcodeValue is None:
            raise RuntimeError("connection closed by peer")
        if opcodeValue == OPCODE_PING:
            sendFrame(wrappedSocket, OPCODE_PONG, framePayload)
            continue
        if opcodeValue == OPCODE_CLOSE:
            raise RuntimeError("peer sent close")
        if opcodeValue == OPCODE_TEXT:
            pendingPayload = framePayload
        elif opcodeValue == OPCODE_CONTINUATION and pendingPayload is not None:
            pendingPayload += framePayload
        else:
            continue
        if not isFinal:
            continue
        messageBytes = pendingPayload
        pendingPayload = None

        try:
            messageBody = json.loads(messageBytes.decode("utf-8"))
        except Exception:
            logLine("frame that is not readable JSON ignored, and not acknowledged")
            continue

        ## Acknowledge first: Slack resends anything unacknowledged within three
        ## seconds, and the handling below takes longer than that.
        envelopeId = messageBody.get("envelope_id", "")
        if envelopeId:
            sendFrame(wrappedSocket, OPCODE_TEXT,
                      json.dumps({"envelope_id": envelopeId}).encode("utf-8"))

        messageType = messageBody.get("type", "")
        if messageType == "hello":
            logLine("hello: app_id=%s" % messageBody.get("connection_info", {}).get("app_id", ""))
            continue
        if messageType == "disconnect":
            raise RuntimeError("disconnect requested, reason=%s" % messageBody.get("reason", ""))
        if messageType != "events_api":
            logLine("envelope type=%s carries nothing this receiver consumes" % messageType)
            continue
        eventBody = messageBody.get("payload", {}).get("event", {})
        if eventBody.get("type") != "app_mention":
            logLine("event type=%s is not declared in the manifest and is ignored" % eventBody.get("type", ""))
            continue
        fileInquiry(eventBody, toolPath)


def main():
    appToken = os.environ.get("SOCKET_MODE_APP_TOKEN", "").strip()
    toolPath = os.environ.get("SOCKET_MODE_TOOL_PATH", "").strip()
    if not appToken or not toolPath:
        logLine("SOCKET_MODE_APP_TOKEN and SOCKET_MODE_TOOL_PATH are both required")
        raise SystemExit(1)

    while True:
        wrappedSocket = None
        try:
            openResponse = urllib.request.urlopen(urllib.request.Request(
                "https://slack.com/api/apps.connections.open", data=b"",
                headers={"Authorization": "Bearer " + appToken}), timeout=30)
            openBody = json.loads(openResponse.read().decode("utf-8"))
            if not openBody.get("ok"):
                logLine("apps.connections.open refused: %s" % openBody.get("error", "<no error field>"))
            else:
                wrappedSocket = connectSocket(openBody.get("url", ""))
                logLine("connected")
                pumpSocket(wrappedSocket, toolPath)
        except Exception as connectionFailure:
            logLine("reconnecting after: %s" % connectionFailure)
        if wrappedSocket is not None:
            try:
                sendFrame(wrappedSocket, OPCODE_CLOSE)
                wrappedSocket.close()
            except Exception:
                pass
        time.sleep(5)


if __name__ == "__main__":
    main()
