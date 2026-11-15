#!/usr/bin/env python3
import base64
import hashlib
import os
import select
import signal
import socket
import ssl
import struct
import sys
import time
from urllib.parse import urlparse

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
OP_TEXT = 0x1
OP_CLOSE = 0x8
OP_PING = 0x9
OP_PONG = 0xA

deadline = 0.0


def fail(message):
    sys.stderr.write("⛔ ERROR: AgentsSlackWebsocketPresence.py: %s\n" % message)
    raise SystemExit(1)


def ttl():
    return float(os.environ.get("PRESENCE_TTL", "300"))


def extend(_signum, _frame):
    global deadline
    deadline = time.monotonic() + ttl()


def connect(url):
    parts = urlparse(url)
    if parts.scheme != "wss":
        fail("only wss:// is supported, got %r" % parts.scheme)
    host = parts.hostname
    path = (parts.path or "/") + (("?" + parts.query) if parts.query else "")

    raw = socket.create_connection((host, parts.port or 443), timeout=30)
    sock = ssl.create_default_context().wrap_socket(raw, server_hostname=host)

    key = base64.b64encode(os.urandom(16)).decode("ascii")
    sock.sendall((
        "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\n"
        "Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n" % (path, host, key)
    ).encode("ascii"))

    # byte at a time: reading past the blank line consumes the first frame
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(1)
        if not chunk:
            fail("connection closed during handshake")
        buf += chunk

    head = buf.decode("latin-1")
    if " 101 " not in head.split("\r\n")[0]:
        fail("upgrade refused: %s" % head.split("\r\n")[0])

    expect = base64.b64encode(hashlib.sha1((key + GUID).encode("ascii")).digest()).decode("ascii")
    got = ""
    for line in head.split("\r\n"):
        if line.lower().startswith("sec-websocket-accept:"):
            got = line.split(":", 1)[1].strip()
    if got != expect:
        fail("bad Sec-WebSocket-Accept: expected %s, got %s" % (expect, got))
    return sock


def send_frame(sock, opcode, payload=b""):
    header = struct.pack("!B", 0x80 | opcode)
    length = len(payload)
    if length < 126:
        header += struct.pack("!B", 0x80 | length)
    elif length < (1 << 16):
        header += struct.pack("!BH", 0x80 | 126, length)
    else:
        header += struct.pack("!BQ", 0x80 | 127, length)
    mask = os.urandom(4)
    sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))


def recv_exact(sock, count):
    buf = b""
    while len(buf) < count:
        chunk = sock.recv(count - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def recv_frame(sock):
    head = recv_exact(sock, 2)
    if head is None:
        return None, None
    opcode = head[0] & 0x0F
    length = head[1] & 0x7F
    masked = bool(head[1] & 0x80)
    if length == 126:
        ext = recv_exact(sock, 2)
        if ext is None:
            return None, None
        length = struct.unpack("!H", ext)[0]
    elif length == 127:
        ext = recv_exact(sock, 8)
        if ext is None:
            return None, None
        length = struct.unpack("!Q", ext)[0]
    mask = recv_exact(sock, 4) if masked else None
    payload = recv_exact(sock, length) if length else b""
    if payload is None:
        return None, None
    if mask:
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return opcode, payload


def self_test(sock):
    probe = b"presence-holder-self-test"
    send_frame(sock, OP_TEXT, probe)
    # some echo peers open with a banner frame; bounded so a never-echoing peer still fails
    for _ in range(8):
        opcode, payload = recv_frame(sock)
        if opcode is None:
            fail("peer closed before echoing the self-test payload")
        if opcode == OP_PING:
            send_frame(sock, OP_PONG, payload)
            continue
        if opcode == OP_TEXT and payload == probe:
            print("SELF-TEST OK echo=%d bytes" % len(payload))
            send_frame(sock, OP_CLOSE)
            sock.close()
            return
    fail("no echo of the self-test payload within 8 frames")


def hold(sock):
    global deadline
    signal.signal(signal.SIGUSR1, extend)
    deadline = time.monotonic() + ttl()
    while time.monotonic() < deadline:
        ready, _, _ = select.select([sock], [], [], max(0.0, min(30.0, deadline - time.monotonic())))
        if not ready:
            continue
        opcode, payload = recv_frame(sock)
        if opcode is None:
            fail("RTM connection closed by peer")
        if opcode == OP_PING:
            send_frame(sock, OP_PONG, payload)
        elif opcode == OP_CLOSE:
            fail("RTM sent close")
    send_frame(sock, OP_CLOSE)
    sock.close()


def main():
    url = os.environ.get("PRESENCE_WSS_URL", "").strip()
    if not url:
        fail("PRESENCE_WSS_URL is required")
    sock = connect(url)
    if os.environ.get("PRESENCE_SELF_TEST", ""):
        self_test(sock)
        return
    hold(sock)


if __name__ == "__main__":
    main()
