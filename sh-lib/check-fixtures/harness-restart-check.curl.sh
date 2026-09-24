#!/usr/bin/env bash
## Records this round's request body and replays this round's canned stream. It opens
## no socket, and being first on PATH is the whole of this check's offline guarantee.
set -u
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > "$RIG_SCENARIO/stdin.$rigRound"
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
