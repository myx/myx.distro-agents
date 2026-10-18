#!/usr/bin/env bash
## Records this round's request body and replays this round's canned stream. It opens
## no socket, and being first on PATH is the whole of this check's offline guarantee.
set -u
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		--data-binary) rigRequestFile="${2#@}" ; cp "$rigRequestFile" "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
## A scenario that changes the MCP registrations between rounds names the change here;
## it runs while round 1 is being answered, so round 2 is the first to see it. The
## request file is handed over, since it names the harness's own scratch directory.
[ "$rigRound" != 1 ] || [ -z "${RIG_AFTER_ROUND_1:-}" ] || RIG_REQUEST_FILE="${rigRequestFile:-}" sh -c "$RIG_AFTER_ROUND_1"
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
