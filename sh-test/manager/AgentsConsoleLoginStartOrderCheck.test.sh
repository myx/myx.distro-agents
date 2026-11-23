#!/usr/bin/env bash
## Behavioural check on the console's start path at a rig account's login: what runs in a screen window, and what runs
## when screen exits. Offline. The rig's `.bash_profile` is not written here from a guess: its two lines are taken from the
## source that writes them, so the profile this check runs is the profile the deploy will leave.
##   1. the login line, `source <myxroot>/include/console/bash/bash-login`, taken from the `bash-login` file under test.
##   2. the console autostart line, taken from the installer fragment that writes it,
##      `mdci-packages-myx/setup.machine-mdci/host/install/common-mdci.0.prepare.txt`, with `${mdciWorkspace}` resolved at
##      the rig's own workspace. A console that only runs in a window is a guard on that line, and this check reads the
##      line as it stands rather than as it is meant to be.
## Emulated, not measured: screen, the `-s` word, the `~/.screenrc` line `shell -$SHELL` and login's own flags. On a host
## with that rc line the rc wins over `-s`, so a window is a login bash only where BOTH name a bash: the `-s` word begins
## with a dash, and `$SHELL` at the call is a bash. A rig with no rc `shell` line would pass the `-s` row and still leave a
## login sh, so both are asserted. NOTHING here was measured on FreeBSD, on real screen, or on the rig's own console.
## Held:
##   1. in a screen window (TERM=screen) the login include starts no second screen, and the console autostart line runs
##      there, so each window gets a console. This row is also the probe's positive control: the same line is seen to run
##      here, so a line that does not print in row 3 was not run.
##   2. at a login over ssh outside screen, the window screen makes is a LOGIN BASH: the `-s` word is a bash and begins
##      with a dash, and `$SHELL` at the call is a bash. Today it is `-s bash` with the account's `/bin/sh`, whose login
##      window reads `.profile` and never the `.bash_profile` the console line is in.
##   3. at that same login, the console autostart line does not run on the raw ssh tty. The line carries its own guard,
##      `test "$TERM" = screen`, so it prints nothing outside a window. Today it has no guard and runs there as well as in
##      the windows, so a login starts the console twice, or once with no screen at all. `exec` is not the fix and is not
##      asserted: it would reach every bash ssh login on every host and change what `exit` does.
##   4. the line the deploy writes into the profile holds no `$`. `sudo -s` leaves a dollar sign unescaped, so the
##      shell it starts expands it at deploy time: `test "$TERM" = screen` reached the profile as `test "dumb" =
##      screen`, false in every window and outside one, so no window started a console. Held as the absence of the
##      character, which is the one form no shell sudo starts can change, and not by running sudo here.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTree="$MDLT_ORIGIN"
rigCommonRoot="$rigTree/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
rigLogin="$rigCommonRoot/include/console/bash/bash-login"
rigPrepare="$rigTree/myx/mdci-packages-myx/setup.machine-mdci/host/install/common-mdci.0.prepare.txt"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigLogin" ] || rigRefuse "the login include is not at the origin this workspace resolves: $rigLogin"
[ -f "$rigPrepare" ] || rigRefuse "the prepare fragment is not at the origin: $rigPrepare"
. "$rigTree/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleLoginStartOrderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigMake(){ ## file, text... -- an executable stand-in
	local rigFile="$1" ; shift
	printf '%s\n' "$@" > "$rigFile" ; chmod +x "$rigFile"
}

## THE MYXROOT of the rig: the login include and the files it sources, taken from the tree under test as they are.
rigRoot="$rigTmp/myxroot" rigBin="$rigTmp/bin" rigHome="$rigTmp/home"
rigWorkspace="$rigTmp/workspace.mdci" rigMdciHome="$rigTmp/mdci-home"
mkdir -p "$rigRoot/include/console/bash" "$rigRoot/include/console/etc" "$rigRoot/include/console/screen" "$rigBin" "$rigHome" \
	"$rigWorkspace" "$rigMdciHome" || exit 1
cp "$rigLogin" "$rigRoot/include/console/bash/bash-login" || exit 1
for rigFile in include/console/bash/common include/console/etc/fzf-load include/console/screen/screenrc include/console/etc/inputrc ; do
	if [ -f "$rigCommonRoot/$rigFile" ] ; then cp "$rigCommonRoot/$rigFile" "$rigRoot/$rigFile" || exit 1
	else : > "$rigRoot/$rigFile" || exit 1 ; fi
done
## The console the autostart line sources, a stand-in of the rig's own: it marks the log and returns. It returns and does
## not exit, because it is sourced by the profile: a console that exited would end the profile there, which is its own
## fault and not the one this check measures.
rigMake "$rigWorkspace/DistroSourceConsole.sh" '#!/bin/sh' 'printf "CONSOLE-AUTOSTART\n" >> "$RIG_LOG"' ':'
rigMake "$rigBin/bash" '#!/bin/sh' 'exit 0'
rigMake "$rigBin/sh" '#!/bin/sh' 'exit 0'
rigMake "$rigBin/hostname" '#!/bin/sh' 'printf "rig\n"'
rigMake "$rigBin/which" '#!/bin/sh' \
	'case "$1" in' '	bash) printf "%s\n" "$RIG_BIN/bash" ;;' '	screen) printf "%s\n" "$RIG_BIN/screen" ;;' '	*) exit 1 ;;' 'esac' 'exit 0'
## screen: logs the `-s` word it was given and the SHELL it saw, then reports the window under BOTH rules, and which rule
## it took. The rc line is read from the screenrc of the tree under test, and `-$SHELL` is the only form it takes.
rigMake "$rigBin/screen" '#!/bin/sh' \
	'scSArg="" scSaw=""' \
	'for scWord in "$@" ; do' \
	'	if [ "$scSaw" = "-s" ] ; then scSArg="$scWord" ; scSaw="" ; continue ; fi' \
	'	case "$scWord" in -s) scSaw="-s" ;; esac' \
	'done' \
	'scRc=""' \
	'[ ! -f "$RIG_SCREENRC" ] || scRc="$( LC_ALL=C sed -n "s/^shell[ 	]*//p" "$RIG_SCREENRC" 2> /dev/null | LC_ALL=C sed -n 1p )"' \
	'case "$scRc" in' \
	'	-\$SHELL) scRc="-$SHELL" ;;' \
	'esac' \
	'if [ -n "$scRc" ] ; then scProg="$scRc" ; scFrom=rc ; else scProg="$scSArg" ; scFrom=arg ; fi' \
	'case "$scProg" in' \
	'	-*) scLogin=yes ;;' \
	'	*) scLogin=no ;;' \
	'esac' \
	'printf "SCREEN sArg=%s shell=%s\n" "${scSArg:-none}" "${SHELL:-none}" >> "$RIG_LOG"' \
	'printf "WINDOW prog=%s login=%s from=%s\n" "$scProg" "$scLogin" "$scFrom" >> "$RIG_LOG"' \
	'exit 0'

## THE PROFILE, from the two sources that write it: the login line, and the console autostart line as the fragment writes
## it. The fragment line is read between its own double quotes and run with ${mdciWorkspace} at the rig's workspace. Below
## both sits one unguarded marker line, which the deploy does not write: it is the control for row 3, since it proves the
## line below the login line is reached at all. So a console line that prints nothing outside a window did so because of
## its own guard, and not because the shell never reached the end of the profile.
rigConsoleLine="$( LC_ALL=C awk '/DistroSourceConsole\.sh/ && /^[[:space:]]*"/ { line = $0 ; sub( /^[^"]*"/, "", line ) ; sub( /"[^"]*$/, "", line ) ; print line ; exit ; }' "$rigPrepare" )"
[ -n "$rigConsoleLine" ] || rigRefuse "the prepare fragment writes no console autostart line this check can read: $rigPrepare"
printf 'source %s/include/console/bash/bash-login ### myx.common setup/console ###\n' "$rigRoot" > "$rigHome/.bash_profile" || exit 1
rigWrittenConsoleLine="$( mdciWorkspace="$rigWorkspace" eval "printf '%s\n' \"$rigConsoleLine\"" )" || exit 1
[ -n "$rigWrittenConsoleLine" ] || rigRefuse "the prepare fragment's console autostart line wrote nothing: $rigPrepare"
printf '%s\n' "$rigWrittenConsoleLine" >> "$rigHome/.bash_profile" || exit 1
printf 'printf "PROFILE-END-REACHED\\n" >> "$RIG_LOG"\n' >> "$rigHome/.bash_profile" || exit 1
: > "$rigHome/.profile" || exit 1

## rigLoginRun <name> <TERM> <ssh-connection> <SHELL> -- one login, as the rig account's: its .bash_profile sourced with the
## rig's own PATH and HOME. Sourced by name rather than through `bash --login`, because a login shell here reads
## /etc/profile, which puts this machine's PATH ahead of the rig's stubs.
rigLoginRun(){ ## name, term, ssh-connection, shell
	rm -f "$rigTmp/log.$1"
	( cd "$rigHome" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" TERM="$2" \
		SSH_CONNECTION="$3" SHELL="$4" USER="mdci" LOGNAME="mdci" MYXROOT="$rigRoot" MDCI_HOME="$rigMdciHome" \
		RIG_LOG="$rigTmp/log.$1" RIG_BIN="$rigBin" RIG_SCREENRC="$rigRoot/include/console/screen/screenrc" \
		/bin/bash --noprofile --norc -c '. "$HOME/.bash_profile"' ) > "$rigTmp/out.$1" 2> "$rigTmp/err.$1"
}
rigLog(){ ## name, text -- how many lines of that run's log hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/log.$1" 2> /dev/null || :
}
rigField(){ ## name, key -- that field of the WINDOW line
	LC_ALL=C grep '^WINDOW ' "$rigTmp/log.$1" 2> /dev/null | LC_ALL=C sed -n "s/.*[ ]$2=\([^ ]*\).*/\1/p" | LC_ALL=C sed -n 1p
}

echo "-- 0. the line the deploy writes into the profile holds no dollar sign --"
rigAssert "the written console line holds no \$" \
	"$( printf '%s\n' "$rigWrittenConsoleLine" | LC_ALL=C grep -c -F -- '$' || : )" "0"

echo "-- 1. in a screen window: no second screen, and the console autostart line runs (the probe's positive control) --"
rigLoginRun window screen "1.2.3.4 5000 22 5.6.7.8 22" /bin/sh
rigAssert "a window (TERM=screen) starts no screen of its own" "$( rigLog window 'SCREEN ' )" "0"
rigAssert "and the console autostart line runs there, exactly as the prepare fragment writes it" \
	"$( rigLog window 'CONSOLE-AUTOSTART' )" "1"

echo "-- 2. a login over ssh: the window screen makes is a login bash --"
rigLoginRun login xterm-256color "1.2.3.4 5000 22 5.6.7.8 22" /bin/sh
rigAssert "a login over ssh outside screen starts screen once" "$( rigLog login 'SCREEN ' )" "1"
rigAssert "the -s word names a bash and begins with a dash, so login marks it a login shell" \
	"$( LC_ALL=C sed -n 's/^SCREEN sArg=\([^ ]*\).*/\1/p' "$rigTmp/log.login" | LC_ALL=C sed -n 1p | LC_ALL=C sed -e 's|^-\(.*\)$|dash \1|' -e 's|.*/||' )" "dash bash"
rigAssert "and SHELL at the call is a bash, so the family screenrc line shell -\$SHELL names one too: today the account's sh" \
	"$( LC_ALL=C sed -n 's/^SCREEN sArg=[^ ]* shell=\([^ ]*\).*/\1/p' "$rigTmp/log.login" | LC_ALL=C sed -n 1p | LC_ALL=C sed 's|.*/||' )" "bash"
rigAssert "so the window the two rules leave is a login bash, which reads .bash_profile: login-ness alone is a login sh" \
	"$( rigField login login ) $( rigField login prog | LC_ALL=C sed -e 's|^-||' -e 's|.*/||' )" "yes bash"

echo "-- 3. and the console line below the login line does not also run in the outer shell --"
rigAssert "the console autostart line does not run in the login shell outside screen, which its own \$TERM guard gives" \
	"$( rigLog login 'CONSOLE-AUTOSTART' )" "0"
rigAssert "the control for that row: the unguarded marker below it is reached, so the profile does run to its end there" \
	"$( rigLog login 'PROFILE-END-REACHED' ) $( rigLog window 'PROFILE-END-REACHED' )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONSOLE LOGIN START ORDER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_LOGIN_START_ORDER: OK (%d assertions, offline, screen and login emulated, nothing run on FreeBSD)\n' "$rigPasses"
