#!/usr/bin/env bash
## Behavioural check on the help viewer of the console completion (sh-lib/manager/AgentsConsole.HelpViewer.fn.include),
## run rather than read, on a terminal of its own -- the viewer is shown only where python, curses and the terminal that
## saves and restores its screen are all there, so the check makes that terminal itself and nothing is stood in for.
## Held: AgentsConsoleHelpShow <command> --find <prefix> runs the VIEWER SCRIPT with python and gives it the help text on
## its standard input -- the text is the viewer's input, never its program -- and the view opens scrolled to the first
## line that begins with the prefix: that line is on the screen, and the lines above it, out of the view, are not. The
## viewer's own status line is on the screen, so it is the viewer that drew it, and no error of python's option parser
## is said anywhere. Offline; only the rig's own tree is read or written.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsConsole.HelpViewer.fn.include"
rigViewer="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsConsoleHelpViewer.py"
rigPython="$( command -v python3 )" || { echo "⛔ ERROR: no python3 on PATH, so the viewer can be shown nowhere" >&2 ; exit 1 ; }
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the help viewer's include is not at the origin: $rigInclude" >&2 ; exit 1 ; }
[ -f "$rigViewer" ] || { echo "⛔ ERROR: the viewer script is not at the origin: $rigViewer" >&2 ; exit 1 ; }

## The body of the check, as the terminal the outer check made runs it: the help of the rig's command,
## opened with the prefix of the option being typed. The viewer takes the screen, and `q` leaves it.
if [ "${1:-}" = "--on-the-terminal" ] ; then
	: "${RIG_HELP_VIEWER_TMP:?⛔ ERROR: RIG_HELP_VIEWER_TMP names no folder, so there is no rig command to read}"
	. "$rigInclude"
	AgentsConsoleHelpShow "$RIG_HELP_VIEWER_TMP/rig-help.fn.sh" "--rig-find-me"
	exit $?
fi

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleHelpViewerFindCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The command whose help is opened: forty lines, the option the prefix names past the middle, so a view
## that has scrolled to it has left the first line behind. Its help is its own `--help`.
rigHelp="$rigTmp/rig-help.fn.sh"
{
	printf '#!/usr/bin/env bash\n'
	printf 'printf -- "RIG-HELP-FIRST the line at the top\\n"\n'
	for rigLine in $( seq 2 29 ) ; do printf 'printf -- "rig-help line %s\\n"\n' "$rigLine" ; done
	printf 'printf -- "  --rig-find-me   the option the completion is typing\\n"\n'
	for rigLine in $( seq 31 40 ) ; do printf 'printf -- "rig-help line %s\\n"\n' "$rigLine" ; done
} > "$rigHelp"
chmod +x "$rigHelp"

## The terminal: a pty of thirty rows and a hundred columns, the whole check run on it, and `q` sent once
## the view has had the time to be drawn. What the terminal was given is kept for the assertions.
rigCapture="$rigTmp/capture"
"$rigPython" - "$rigTmp" "$0" "$rigCapture" <<'PY' || { echo "⛔ ERROR: the terminal of the check could not be made" >&2 ; exit 1 ; }
import fcntl, os, pty, select, struct, sys, termios, time
rigTmp, script, capture = sys.argv[1], sys.argv[2], sys.argv[3]
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.environ["RIG_HELP_VIEWER_TMP"] = rigTmp
    os.execvp("bash", ["bash", script, "--on-the-terminal"])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
output = bytearray()
start = time.time()
sent = False
while time.time() - start < 20:
    ready = select.select([fd], [], [], 0.1)[0]
    if ready:
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        output.extend(data)
    if not sent and time.time() - start > 2.0:
        os.write(fd, b"q")
        sent = True
try:
    os.close(fd)
except OSError:
    pass
os.waitpid(pid, 0)
with open(capture, "wb") as handle:
    handle.write(output)
PY

## What the terminal was given, with the escapes of the screen taken out, so the words the view drew are read.
rigScreen="$( LC_ALL=C tr -d '\033' < "$rigCapture" | LC_ALL=C sed -e 's/\[[0-9;?]*[A-Za-z]//g' -e 's/\r//g' )"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigAssert "the viewer opened the help it was given, with its own status line on the screen" \
	"$( printf '%s' "$rigScreen" | LC_ALL=C grep -c -F -- 'Help: Up/Down by a line' || : )" "1"
rigAssert "the help text is the viewer's input, not its program: python is given the viewer script, and says no error of its own" \
	"$( printf '%s' "$rigScreen" | LC_ALL=C grep -c -F -- 'Unknown option: --find' || : )" "0"
rigAssert "the view opened at the line the prefix names, and the lines above it are out of the view" \
	"$( printf '%s' "$rigScreen" | LC_ALL=C grep -q -F -- 'the option the completion is typing' && printf 1 || printf 0 ):$( printf '%s' "$rigScreen" | LC_ALL=C grep -c -F -- 'RIG-HELP-FIRST' || : )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AGENTS CONSOLE HELP VIEWER FIND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "AGENTS_CONSOLE_HELP_VIEWER_FIND: OK ($rigPassCount assertions, offline, on a terminal of its own)"
