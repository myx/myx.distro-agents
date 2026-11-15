#!/usr/bin/env awk

# Reads one single-line Slack conversations.info JSON response (fed on
# stdin, run under LC_ALL=C for byte safety) and prints the conversation's
# OWN counterparty -- the `channel.user` field of a DM -- and nothing else.
# Exactly one line of output for a DM, zero lines for anything that has no
# single counterparty (a public/private channel, an mpim).
#
# WHY THIS FILE EXISTS AT ALL, i.e. why the counterparty is parsed and not
# pattern-matched. The control in AgentsTools.CommsSlack.include used
# to read the counterparty with
#     sed -n 's/.*"user":"\([UW][^"]*\)".*/\1/p' | head -1
# and that is wrong by construction: BRE `.*` is greedy, so the leading
# `.*` eats as much as it can and the capture lands on the LAST
# `"user":"..."` in the payload, not the channel's own one. A real
# conversations.info body for a DM carries several of them --
#     {"ok":true,"channel":{"id":"D...","user":"<the counterparty>",
#       "latest":{"user":"<whoever spoke last>",
#         "bot_profile":{"user_id":"<the app's own user>"}}}}
# -- so the control was reporting the most recent speaker, or a bot profile,
# instead of the party the conversation is with.
#
# It passed its own verification anyway, by coincidence: at the time it was
# first checked, the newest message in that DM happened to be from the very
# party the control expected, so the last `"user"` incidentally equalled the
# expected one. The check was real; the mechanism underneath it had never
# once read the counterparty. Every green that control produced before the
# fix is unproven, not evidence.
#
# There is deliberately NO cleverer regex here. `sed` has no non-greedy
# quantifier in BRE, and the GNU-only constructs that could fake one (`\|`
# alternation, PCRE `.*?`) are exactly what this family forbids for
# Darwin/FreeBSD/Linux parity -- a greedy/non-greedy fight in a BRE is how
# this bug happened in the first place. The payload is therefore parsed
# structurally, by full key path, so `channel.user` is the only thing that
# can ever match: `channel.latest.user` and
# `channel.latest.bot_profile.user_id` are different paths and are ignored
# by construction, not by anchoring luck. Do not "simplify" this back into a
# one-liner.
#

BEGIN {
	jfLibrary = 1
	jfLax = 1
	apiOk = "true"
	apiOkSeen = 0
	channelSeen = 0
	isIm = ""
	counterparty = ""
}

## Full-path equality only -- never a substring/prefix test. `channel.user`
## is the channel object's own field; `channel.latest.user` and
## `channel.latest.bot_profile.user_id` are other paths entirely and fall
## through untouched, which is the whole point of parsing rather than
## matching. Fields are recorded here and judged in END: Slack's own field
## order is not something to depend on, so `is_im` may well arrive after
## `user`.
function jfNodeHook(path, nodeType, nodeValue, fromPos, toPos) {
	if (path == "ok") { apiOk = nodeValue; apiOkSeen = 1; return; }
	if (path == "error") { apiError = nodeValue; return; }
	if (path == "channel.id") { channelSeen = 1; return; }
	if (path == "channel.is_im") { isIm = nodeValue; return; }
	if (path == "channel.user") { counterparty = nodeValue; return; }
}

{ jfConsumeText($0) }

END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	# COULD-NOT-PARSE, distinct from "parsed fine, no counterparty to
	# report". Every real conversations.info response carries an `ok` key
	# and a channel object, so reaching END with neither means the input
	# was not the JSON this script parses -- a truncated body, an HTML
	# error page, an empty read. Without this, all three would print
	# nothing and be indistinguishable from a channel that legitimately
	# has no single counterparty.
	if (!apiOkSeen && !channelSeen) {
		printf("⛔ ERROR: could not parse Slack conversations.info response: no `ok` key and no channel object -- input was not a parseable API response (truncated body, error page, or empty read), not a conversation without a counterparty\n") > "/dev/stderr"
		exit 1
	}

	# Positive tests on presence, both of them: a DM says so with
	# is_im:true AND carries the party in channel.user. A conversation
	# missing either one prints nothing at all, which is what the caller
	# renders as "no single counterparty" -- never a guess drawn from
	# somewhere else in the payload.
	if (isIm == "true" && counterparty != "") print counterparty
}
