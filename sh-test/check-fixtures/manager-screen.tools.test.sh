#!/usr/bin/env bash
## The stand-in for the dispatcher in the tests of the manager screen: the screen calls it where it
## would call DistroAgentsTools.fn.sh. Each start appends one line, its arguments, to
## $MANAGER_SCREEN_RIG/calls, and the same arguments to $MANAGER_SCREEN_RIG/words, each between
## brackets, so that an argument with a space in it reads as the one word it was. What came on its
## standard input is kept byte for byte in $MANAGER_SCREEN_RIG/stdin.<its first argument>, where
## anything came. A start that comes to its own end, and is not ended from outside, appends its
## arguments to $MANAGER_SCREEN_RIG/ended. Then it does what the rig says for that start: the file
## $MANAGER_SCREEN_RIG/mode.<n> for the n-th start, else mode.<its first argument>, else mode:
##   rows          prints $MANAGER_SCREEN_RIG/rows.<n> for the n-th start, else rows.<its arguments, a
##                 space between them>, else rows.<its first argument>, else rows, and ends with
##                 status 0 (also where no file says anything)
##   sleep <n>     waits that many seconds first, then as rows
##   fail          writes a line that is no error and one error line to standard error, and ends with status 1
##   fail-rows     as rows, then one error line to standard error, and ends with status 1
set -u
: "${MANAGER_SCREEN_RIG:?⛔ ERROR: MANAGER_SCREEN_RIG is not set}"
printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/calls"
rigStart="$( LC_ALL=C grep -c '' "$MANAGER_SCREEN_RIG/calls" )"
rigWords=""
for rigWord in "$@" ; do rigWords="$rigWords[$rigWord]" ; done
printf '%s\n' "$rigWords" >> "$MANAGER_SCREEN_RIG/words"
rigInput="$MANAGER_SCREEN_RIG/stdin.$$"
cat > "$rigInput"
[ ! -s "$rigInput" ] || cat "$rigInput" >> "$MANAGER_SCREEN_RIG/stdin.${1:-}"
rm -f "$rigInput"
rigMode="$( cat "$MANAGER_SCREEN_RIG/mode.$rigStart" 2> /dev/null || cat "$MANAGER_SCREEN_RIG/mode.${1:-}" 2> /dev/null || cat "$MANAGER_SCREEN_RIG/mode" 2> /dev/null )"
case "$rigMode" in
	sleep\ *)
		sleep "${rigMode#sleep }"
	;;
	fail)
		echo "rig-tools: a line that is no error" >&2
		echo "rig-tools: ⛔ ERROR: the rig said fail" >&2
		printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/ended"
		exit 1
	;;
esac
if [ -f "$MANAGER_SCREEN_RIG/rows.$rigStart" ] ; then
	cat "$MANAGER_SCREEN_RIG/rows.$rigStart"
elif [ -f "$MANAGER_SCREEN_RIG/rows.$*" ] ; then
	cat "$MANAGER_SCREEN_RIG/rows.$*"
elif [ -f "$MANAGER_SCREEN_RIG/rows.${1:-}" ] ; then
	cat "$MANAGER_SCREEN_RIG/rows.${1:-}"
elif [ -f "$MANAGER_SCREEN_RIG/rows" ] ; then
	cat "$MANAGER_SCREEN_RIG/rows"
fi
printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/ended"
if [ "$rigMode" = "fail-rows" ] ; then
	echo "rig-tools: ⛔ ERROR: the rig said fail, after its rows" >&2
	exit 1
fi
exit 0
