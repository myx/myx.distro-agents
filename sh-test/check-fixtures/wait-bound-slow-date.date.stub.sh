#!/bin/sh
## A date for the check of the bound inside a round: asked for a file's time (`date -r <file>`, which the inbox probe of a wait
## makes for each item) it sleeps three seconds first, where the check has put its `slow` flag; every other call goes to the real
## date at once. RIG_DATE_REAL is that date and RIG_SCENARIO the folder of the scenario.
case "$1" in
	-r) [ ! -f "$RIG_SCENARIO/slow" ] || sleep 3 ;;
esac
exec "$RIG_DATE_REAL" "$@"
