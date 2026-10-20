#!/usr/bin/env bash
## Records this round's request body and replays this round's canned stream, for a MODEL request alone. A call to anything else -- the
## Slack API a wait of the tooling may read -- is logged to $RIG_SCENARIO/curl.other.log and refused at once, and does not count as a
## round, so the rounds of the rig are the model's. It opens no socket, and being first on PATH is the whole of this check's offline
## guarantee.
set -u
case " $* " in
	*" https://harness-idle-wait.invalid/"*) ;;
	*)
		printf '%s\n' "$*" >> "$RIG_SCENARIO/curl.other.log"
		cat > /dev/null
		exit 7
	;;
esac
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		--data-binary) rigRequestFile="${2#@}" ; cp "$rigRequestFile" "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
