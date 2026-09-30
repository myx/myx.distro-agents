#!/usr/bin/env awk
# Maps a Slack dm= marker's channel id to its identity, where the marker states one.
/^## dm=/ {
	rest = $0
	sub(/^## dm=/, "", rest)
	id = rest ; sub(/ .*/, "", id)
	## `identity=` IS OPTIONAL ON THIS MARKER -- the same
	## optionality AgentsSessionContextCommsItems.awk already
	## honours at its own copy of this rule. Without this
	## positive test the sub() below simply does not match,
	## `idn` keeps the whole remainder, and the first word of
	## it -- the channel id itself -- is recorded as though it
	## were an identity name. That mapping is then non-empty,
	## so the follow-up thread read takes the "some identity
	## was mapped" branch and silently reads under the member
	## token where it had been reading under the bot token.
	idn = ""
	if (rest ~ /identity=/) {
		idn = rest ; sub(/^.*identity=/, "", idn) ; sub(/ .*/, "", idn)
	}
	if (id != "" && idn != "") print id, idn
}
