#!/usr/bin/env bash
## The stand-in for the dispatcher in the tests of the manager screen: the screen calls it where it
## would call DistroAgentsTools.fn.sh. Each start appends one line, its arguments, to
## $MANAGER_SCREEN_RIG/calls, and the same arguments to $MANAGER_SCREEN_RIG/words, each between
## brackets, so that an argument with a space in it reads as the one word it was. What came on its
## standard input is kept byte for byte in $MANAGER_SCREEN_RIG/stdin.<its first argument>, where
## anything came. A start that comes to its own end, and is not ended from outside, appends its
## arguments to $MANAGER_SCREEN_RIG/ended. Then it does what the rig says for that start: the file
## $MANAGER_SCREEN_RIG/mode.<n> for the n-th start, else mode.<its arguments, a space between them>,
## else mode.<its first argument>, else mode:
##   rows          prints $MANAGER_SCREEN_RIG/rows.<n> for the n-th start, else rows.<its arguments, a
##                 space between them>, else rows.<its first argument>, else rows, and ends with
##                 status 0 (also where no file says anything)
##   sleep <n>     waits that many seconds first, then as rows
##   fail          writes a line that is no error and one error line to standard error, and ends with status 1
##   fail-rows     as rows, then one error line to standard error, and ends with status 1
##   script <file> becomes the bash script $MANAGER_SCREEN_RIG/<file> (exec): what it writes, on either
##                 stream and when, how it ends, by a status or by a signal, are the script's own; such a
##                 start appends nothing to $MANAGER_SCREEN_RIG/ended
## The read that decides whether Team Data stands in the list (`--manager-dashboard-read team-data`) is the fourth, and is noted in the file `here` alone.
## Three operations the screen calls of its own accord, whatever a test is about, the list of the
## locations at every start (`--manager-place-list`), the blocks of the dashboard while the root
## stands on its first row (`--manager-dashboard-read`) and the count of the asks, whatever is shown
## (`--member-pending-reply-read ... --count`): a start of any is noted like any other,
## but is not counted among the starts that mode.<n> and rows.<n> number, and it is answered only by
## what the rig says of it by its own name (mode.<its first argument>, rows.<its arguments>,
## rows.<its first argument>), with no row where the rig says nothing: the catch-all `mode` and
## `rows` are the fixture of the view under test, and are not theirs.
set -u
: "${MANAGER_SCREEN_RIG:?⛔ ERROR: MANAGER_SCREEN_RIG is not set}"
## The read that decides whether Team Data stands in the list is made at every start and at every refresh, whatever a test is about: it is noted in
## $MANAGER_SCREEN_RIG/here, one line a start, and in none of the files that count the starts; it prints the rig's rows of the dashboard.
if [ "$*" = "--manager-dashboard-read team-data" ] ; then
	printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/here"
	if [ -f "$MANAGER_SCREEN_RIG/rows.$*" ] ; then cat "$MANAGER_SCREEN_RIG/rows.$*" ; elif [ -f "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read" ] ; then cat "$MANAGER_SCREEN_RIG/rows.--manager-dashboard-read" ; fi
	exit 0
fi
printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/calls"
rigOwn=""
case "${1:-}" in --manager-place-list|--manager-dashboard-read) rigOwn="yes" ;; esac
case "$*" in "--member-pending-reply-read "*" --count") rigOwn="yes" ;; esac
rigStart="$( LC_ALL=C grep -c -v -e '^--manager-place-list' -e '^--manager-dashboard-read' -e '^--member-pending-reply-read .* --count$' "$MANAGER_SCREEN_RIG/calls" )"
[ -z "$rigOwn" ] || rigStart="own"
rigWords=""
for rigWord in "$@" ; do rigWords="$rigWords[$rigWord]" ; done
printf '%s\n' "$rigWords" >> "$MANAGER_SCREEN_RIG/words"
rigInput="$MANAGER_SCREEN_RIG/stdin.$$"
cat > "$rigInput"
[ ! -s "$rigInput" ] || cat "$rigInput" >> "$MANAGER_SCREEN_RIG/stdin.${1:-}"
rm -f "$rigInput"
rigMode="$( cat "$MANAGER_SCREEN_RIG/mode.$rigStart" 2> /dev/null || cat "$MANAGER_SCREEN_RIG/mode.$*" 2> /dev/null || cat "$MANAGER_SCREEN_RIG/mode.${1:-}" 2> /dev/null || { [ -n "$rigOwn" ] && echo rows ; } || cat "$MANAGER_SCREEN_RIG/mode" 2> /dev/null )"
case "$rigMode" in
	sleep\ *)
		sleep "${rigMode#sleep }"
	;;
	script\ *)
		exec bash "$MANAGER_SCREEN_RIG/${rigMode#script }"
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
elif [ -z "$rigOwn" ] && [ -f "$MANAGER_SCREEN_RIG/rows" ] ; then
	cat "$MANAGER_SCREEN_RIG/rows"
fi
printf '%s\n' "$*" >> "$MANAGER_SCREEN_RIG/ended"
if [ "$rigMode" = "fail-rows" ] ; then
	echo "rig-tools: ⛔ ERROR: the rig said fail, after its rows" >&2
	exit 1
fi
exit 0
