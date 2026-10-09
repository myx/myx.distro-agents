#!/usr/bin/env bash
## 536: the per-send Slack log is best-effort. When its line cannot be appended the send
## says so once on stderr and its own result is unchanged -- a posted message still
## returns 0, a refused one still returns non-zero. The append is made to fail by
## putting a directory where the log file goes. Temp workspace only, the credential
## exposure rig's fake curl first on PATH, under one `env -i` guard. Also holds T10:
## the log is comms-slack-send.YYYY-MM.log (UTC month), its last column is the session
## id ('-' when none), and a pre-monthly comms-slack-send.log is split by month once
## and renamed .migrated, never deleted. And the socket-mode receiver's rows: they land
## in the same monthly log in the same eight columns, with no body and no token, and
## socket-status reads them from there. The receiver runs in-process against a fake
## socket and a fake apps.connections.open, so nothing leaves the machine.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsSlackSendLogAppendCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cp "$rigTest/check-fixtures/credential-exposure-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigSentinel="rig-sentinel-$$-TOKEN"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## mode (ok|fail), result file, [spawn session id]
	env -i ${3:+MDAT_SPAWN_SESSION_ID=$3} HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" TMPDIR="$rigWs/.local/temp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE="$1" RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --member-comms-slack-send-message magic-team magic-team --identity-bot rig-body
		' > "$2" 2>&1
	printf '%s' "$?" > "$2.rc"
}
rigWarned(){ ## result file
	LC_ALL=C grep -c 'could not append this send.s outcome to' "$1" || :
}

rigDir="$rigWs/.local/agents"
rigOld="$rigDir/comms-slack-send.log"
rigLog="$rigDir/comms-slack-send.$( date -u +%Y-%m ).log"
rigLines(){ LC_ALL=C awk 'END { print NR ; }' "$1" 2>/dev/null ; }

echo "-- control: the log is writable, and the pre-monthly log is migrated on the first write --"
mkdir -p "$rigDir"
printf '20250801T000000Z\tm\tt\tc\tbot\tok\t\n20250815T000000Z\tm\tt\tc\tbot\tfailed\tx\n20250930T235959Z\tm\tt\tc\tbot\tok\t\n' > "$rigOld"
rigOldSum="$( cksum < "$rigOld" )"
rigSend ok "$rigTmp/c" rig-session-1
LC_ALL=C grep -q 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/c" )"
rigAssert "a send succeeds, rc 0"                      "$( cat "$rigTmp/c.rc" )" 0
rigAssert "with no append warning"                     "$( rigWarned "$rigTmp/c" )" 0
rigAssert "and its line is in this UTC month's log, comms-slack-send.YYYY-MM.log" "$( rigLines "$rigLog" )" 1
rigAssert "the line has eight columns, the session id last" "$( LC_ALL=C awk -F'\t' '{ print NF " " $8 ; }' "$rigLog" )" "8 rig-session-1"
rigAssert "the first seven columns keep their places"  "$( LC_ALL=C awk -F'\t' '{ print ($1 ~ /^[0-9]{8}T[0-9]{6}Z$/) " " $2 " " $3 " " $5 " " $6 ; }' "$rigLog" )" "1 magic-team magic-team bot ok"
rigAssert "migration: the old log's August lines are in the August file" "$( rigLines "$rigDir/comms-slack-send.2025-08.log" )" 2
rigAssert "migration: its September line is in the September file"       "$( rigLines "$rigDir/comms-slack-send.2025-09.log" )" 1
rigAssert "migration: the old log is renamed .migrated, unchanged, never deleted" "$( [ ! -e "$rigOld" ] && cksum < "$rigOld.migrated" )" "$rigOldSum"
rigSend ok "$rigTmp/d"
rigAssert "a send with no session known logs '-' as its session" "$( LC_ALL=C awk -F'\t' 'END { print NF " " $8 ; }' "$rigLog" )" "8 -"
rigAssert "and appends to the same monthly file"       "$( rigLines "$rigLog" )" 2
printf '20250802T000000Z\tm\tt\tc\tbot\tok\t\n' > "$rigOld"
rigSend ok "$rigTmp/e"
rigAssert "an old log whose month already has a monthly file is left in place, not migrated again" "$( [ -f "$rigOld" ] && rigLines "$rigDir/comms-slack-send.2025-08.log" )" 2
rm -f "$rigOld"

echo "-- the socket-mode receiver writes its rows into the same monthly log --"
rigPython="$( command -v python3 )" || rigRefuse "python3 is not on PATH"
rigAppToken="xapp-1-ARIG-$$-SENTINEL"
rigMarker="RIG-SOCKET-BODY-$$"
printf 'SLACK_APP_TOKEN=%s\n' "$rigAppToken" >> "$rigWs/.local/.agents/magic-team.agent.env"
printf '#!/bin/sh\ncat > "%s"\necho "%s"\nexit 3\n' "$rigTmp/scenario/filed.log" "$rigAppToken" > "$rigTmp/bin/rig-file-tool"
chmod +x "$rigTmp/bin/rig-file-tool"
## Every way out is faked before the receiver runs as __main__: apps.connections.open,
## the TCP connect, TLS, and the 5 s pause before a reconnect, which stops it by SIGTERM.
cat > "$rigTmp/socket-rig.py" << 'RIG_PY'
import base64, hashlib, json, os, runpy, signal, socket, ssl, struct, sys, time, urllib.request
modPath, scopeName, bodyMarker, appToken = sys.argv[1:5]
def frame(opcodeValue, framePayload):
    frameHead = bytes([0x80 | opcodeValue])
    if len(framePayload) < 126:
        return frameHead + bytes([len(framePayload)]) + framePayload
    return frameHead + struct.pack("!BH", 126, len(framePayload)) + framePayload
def text(messageBody):
    return frame(0x1, json.dumps(messageBody).encode("utf-8"))
inboundFrames = (
    text({"type": "hello", "connection_info": {"app_id": "ARIG00001"}})
    + text({"type": "events_api", "envelope_id": "e1", "payload": {"event": {
        "type": "app_mention", "channel": "CRIG00001", "ts": "1700000000.000100",
        "user": "URIG00001", "text": "%s %s" % (bodyMarker, appToken)}}})
    + text({"type": "events_api", "envelope_id": "e2", "payload": {"event": {
        "type": "reaction_added", "channel": "CRIG00002", "event_ts": "1700000001.000200", "reaction": bodyMarker}}})
    + text({"type": "slash_commands", "envelope_id": "e3", "payload": {"text": bodyMarker}})
    + frame(0x1, ("not json " + bodyMarker).encode("utf-8"))
    + text({"type": "disconnect", "reason": "refresh_requested " + appToken}))
class FakeSocket:
    def __init__(self):
        self.inbound, self.handshaken = b"", False
    def sendall(self, sentBytes):
        if not self.handshaken:
            self.handshaken = True
            handshakeKey = sentBytes.split(b"Sec-WebSocket-Key: ")[1].split(b"\r\n")[0].decode("ascii")
            acceptKey = base64.b64encode(hashlib.sha1(
                (handshakeKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()).decode("ascii")
            self.inbound = ("HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: %s\r\n\r\n" % acceptKey).encode("ascii") + inboundFrames
    def recv(self, byteCount):
        chunk, self.inbound = self.inbound[:byteCount], self.inbound[byteCount:]
        return chunk
    def close(self):
        pass
class FakeContext:
    def wrap_socket(self, rawSocket, server_hostname=None):
        return rawSocket
class FakeResponse:
    def read(self):
        return json.dumps({"ok": True, "url": "wss://rig.invalid/link/?ticket=RIG"}).encode("utf-8")
def fakeUrlopen(openRequest, timeout=None):
    if openRequest.full_url != "https://slack.com/api/apps.connections.open":
        raise SystemExit("unexpected URL %s" % openRequest.full_url)
    return FakeResponse()
realSleep = time.sleep
def fakeSleep(seconds):
    os.kill(os.getpid(), signal.SIGTERM)
    realSleep(5)
    raise SystemExit("SIGTERM was not handled")
urllib.request.urlopen = fakeUrlopen
socket.create_connection = lambda address, timeout=None: FakeSocket()
ssl.create_default_context = lambda: FakeContext()
time.sleep = fakeSleep
sys.argv = [modPath, scopeName]
runpy.run_path(modPath, run_name="__main__")
RIG_PY
rigSendRows="$( LC_ALL=C awk -F'\t' '$3 != "socket"' "$rigLog" | cksum )"
env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" SOCKET_MODE_APP_TOKEN="$rigAppToken" \
	SOCKET_MODE_TOOL_PATH="$rigTmp/bin/rig-file-tool" SOCKET_MODE_LOG_DIR="$rigDir" \
	"$rigPython" -I "$rigTmp/socket-rig.py" "$rigHere/AgentsSlackSocketMode.py" magic-team "$rigMarker" "$rigAppToken" \
	> "$rigTmp/socket.out" 2>&1
rigSocketRc=$?
rigAssert "the receiver stops on SIGTERM, rc 0, nothing on stderr" "$rigSocketRc:$( cat "$rigTmp/socket.out" )" "0:"
rigAssert "control: the mention's body reached the filing tool" "$( LC_ALL=C grep -c -F "$rigMarker" "$rigTmp/scenario/filed.log" 2>/dev/null )" 1
rigSocketRows(){ LC_ALL=C awk -F'\t' '$3 == "socket"' "$rigLog" ; }
rigAssert "its rows are in this UTC month's comms-slack-send.YYYY-MM.log, one per event" "$( rigSocketRows | rigLines /dev/stdin )" 9
rigAssert "every row has the eight columns" "$( rigSocketRows | LC_ALL=C awk -F'\t' 'NF != 8 { bad++ } END { print bad + 0 ; }' )" 0
rigAssert "member is the app scope, target socket, identity app, session '-'" \
	"$( rigSocketRows | LC_ALL=C awk -F'\t' '{ print ($1 ~ /^[0-9]{8}T[0-9]{6}Z$/) " " $2 " " $3 " " $5 " " $8 ; }' | LC_ALL=C sort -u )" "1 magic-team socket app -"
rigAssert "column 6 is the event kind, in order" "$( rigSocketRows | LC_ALL=C awk -F'\t' '{ printf "%s%s", (NR > 1 ? " " : ""), $6 ; }' )" \
	"connected connected received error received received error reconnect stopped"
rigAssert "a received mention: channel column and reason event type plus channel:ts" \
	"$( rigSocketRows | LC_ALL=C awk -F'\t' '$6 == "received" && $7 ~ /^app_mention / { print $4 " " $7 ; }' )" "CRIG00001 app_mention CRIG00001:1700000000.000100"
rigAssert "a token-shaped string in a reason is redacted" "$( rigSocketRows | LC_ALL=C awk -F'\t' '$6 == "reconnect" { print $7 ; }' )" "reconnecting after: disconnect requested_ reason=refresh_requested redacted"
rigAssert "no row holds the body"  "$( LC_ALL=C grep -c -F "$rigMarker" "$rigLog" )" 0
rigAssert "no row holds the token" "$( LC_ALL=C grep -c -F -e "$rigAppToken" -e "ARIG-$$" "$rigLog" )" 0
rigAssert "the send rows before them are untouched" "$( LC_ALL=C awk -F'\t' '$3 != "socket"' "$rigLog" | cksum )" "$rigSendRows"
env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" TMPDIR="$rigWs/.local/temp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
	RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE=ok RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
	bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
		cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-comms-slack-socket-status magic-team
	' > "$rigTmp/status.out" 2> "$rigTmp/status.err"
rigAssert "socket-status names the monthly Slack log" "$( LC_ALL=C grep -c -F "log=$rigLog" "$rigTmp/status.out" )" 1
rigAssert "and reads the receiver's last row from it" "$( tail -n 1 "$rigTmp/status.out" )" "$( rigSocketRows | tail -n 1 )"
rigAssert "no slack-socket.<scope>.log is named or made any more" \
	"$( { ls "$rigWs/.local/temp" ; cat "$rigHere/AgentsTools.MemberCommsSlackSocket.include" "$rigTmp/status.out" ; } | LC_ALL=C grep -c 'slack-socket\.[^.]*\.log' )" 0

echo "-- the log cannot be appended --"
rm -f "$rigLog"
mkdir -p "$rigLog"
rigSend ok "$rigTmp/a"
rigAssert "a posted send still returns 0"              "$( cat "$rigTmp/a.rc" )" 0
rigAssert "and says once that its line was not kept"   "$( rigWarned "$rigTmp/a" )" 1
rigSend fail "$rigTmp/b"
rigAssert "a refused send still returns non-zero"      "$( [ "$( cat "$rigTmp/b.rc" )" != 0 ] && printf non-zero || printf zero )" non-zero
rigAssert "and says once that its line was not kept"   "$( rigWarned "$rigTmp/b" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEND LOG APPEND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_LOG_APPEND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
