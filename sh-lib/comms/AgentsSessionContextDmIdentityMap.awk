#!/usr/bin/env awk
# Maps a Slack dm= marker's channel id to its identity, where the marker states one.
/^## dm=/ {
	rest = $0
	sub(/^## dm=/, "", rest)
	id = rest ; sub(/ .*/, "", id)
	## identity= is optional -- without it, idn silently takes the channel id, and the read switches from bot token to member token.
	idn = ""
	if (rest ~ /identity=/) {
		idn = rest ; sub(/^.*identity=/, "", idn) ; sub(/ .*/, "", idn)
	}
	if (id != "" && idn != "") print id, idn
}
