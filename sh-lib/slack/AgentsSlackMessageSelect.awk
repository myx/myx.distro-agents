#!/usr/bin/env awk

# Reads one raw Slack conversations.replies (or conversations.history) JSON
# response on stdin and prints back the SAME response narrowed to exactly one
# message: the element whose own `ts` equals -v wantTs=<ts>, byte-verbatim,
# re-wrapped as {"ok":true,"messages":[<that message object>]}.
#
# WHY THIS EXISTS. `conversations.history` does not return thread replies at
# all: asked for a reply's own ts it answers {"ok":true,"messages":[],...} --
# success, empty array -- and a caller reads that as "no reply yet" rather than
# "wrong endpoint for this question." `conversations.replies` answers for a
# parent ts, a reply ts AND a plain non-threaded ts alike (measured, all three
# against a real DM), so it is the endpoint that can actually see everything it
# was asked to see. The cost of that is that it returns the surrounding thread,
# not one message -- so a single-message read has to pick its own message back
# out of the thread, which is this file's whole job. Without it, moving the
# read onto the right endpoint would silently change the op's contract from
# "one message" to "a thread."
#
# THREE OUTCOMES, all distinguishable by exit status, never by an empty stdout:
#
#   rc 0 -- read-and-found. The requested ts is present in the response;
#           its message object is printed on stdout.
#   rc 1 -- read-but-absent. The response parsed, but no element carries the
#           requested ts. This is a COULD-NOT-READ, never "no messages": a
#           caller must not be able to conclude "nothing there" from a call
#           that could not have seen the thing it asked about.
#   rc 2 -- could-not-parse / ok:false. The input was not a usable API
#           response (truncated body, error page, empty read) or Slack itself
#           refused. Kept distinct from rc 1 so "the read worked and the
#           message is not there" never reads the same as "the read did not
#           work."
#
# Selection is an EXACT ts match, tested positively on presence of a matching
# element -- never a negation against an empty array. Both sides are forced to
# string comparison (the `x ""` concatenations below), because a ts like
# 1786361564.517149 is a strnum to awk and a numeric comparison would happily
# equate two distinct ts values that differ only past the float's precision.
#
# WHAT THE OUTPUT ENVELOPE IS, AND IS NOT. The message object is reproduced
# exactly as Slack sent it -- every field, reaction, block and attachment
# untouched, since it is a raw substring of the response, not a re-serialised
# copy. The envelope around it is synthesised, and deliberately carries only
# `ok` and `messages`: the response's own `has_more`/`response_metadata`
# describe the THREAD's pagination, and carrying them beside a single selected
# message would describe something the output no longer contains.
#
# THE WALK IS THE PACKAGE'S ONE JSON ENGINE (sh-lib/harness/AgentsHarnessJsonField.awk),
# loaded with this file and handed every node through jfNodeHook. It holds the
# body as a chunk table and copies whole runs, so one body costs one pass. What
# this file must never do again is walk one whole-body string by index: on BWK
# awk every substr() costs the whole string's length, so that shape is
# quadratic -- measured 0.39 s on a 100 kB thread and 140 s on 2 MB, which is
# the shape that burned a core for half an hour on a live read.
#
# LC_ALL=C IS REQUIRED, as for the engine: every offset here is a byte offset.

BEGIN {
	jfLibrary = 1
	jfLax = 1
	msgCount = 0
	apiOk = "true"
	apiOkSeen = 0
	fatal = 0
	if ((wantTs "") == "") {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: -v wantTs=<ts> is required -- this script selects one message by its own exact ts and has nothing to select without one\n") > "/dev/stderr"
		fatal = 2
		exit 2
	}
}

## "" for anything that is not a direct element of the top-level messages
## array -- a nested object inside a message (a block, an attachment, a file)
## has a longer path and must NOT be captured as a message of its own.
function messageIndexOfPath(path,   rest) {
	if (index(path, "messages.") != 1) return ""
	rest = substr(path, length("messages.") + 1)
	if (rest !~ /^[0-9]+$/) return ""
	return rest
}

## Every node of the response, in document order. Only three things matter: the
## response's own `ok`/`error`, each message's own `ts`, and the source bytes of
## each message object, taken from the engine's own offsets -- never rebuilt
## from the fields this file happens to know, which is what keeps the selected
## message byte-identical to what Slack sent.
function jfNodeHook(path, nodeType, nodeValue, fromPos, toPos,   idx, rest, msgIdx) {
	if (nodeType == "s" || nodeType == "n" || nodeType == "t" || nodeType == "f" || nodeType == "z") {
		if (path == "ok") { apiOk = nodeValue; apiOkSeen = 1; return; }
		if (path == "error") { apiError = nodeValue; return; }
		if (index(path, "messages.") != 1) return
		rest = substr(path, length("messages.") + 1)
		idx = rest
		sub(/\..*/, "", idx)
		if (idx !~ /^[0-9]+$/) return
		if (idx + 1 > msgCount) msgCount = idx + 1
		if (rest == idx ".ts") { tsOf[idx] = nodeValue; return; }
		return
	}
	if (nodeType != "{") return
	msgIdx = messageIndexOfPath(path)
	if (msgIdx == "") return
	rawOf[msgIdx] = jfSlice(fromPos, toPos)
	if (msgIdx + 1 > msgCount) msgCount = msgIdx + 1
}

{ jfConsumeText($0) }

END {
	## A BEGIN-time refusal must not be re-decided here by the outcome tests
	## below, which would all read "nothing parsed" and report the wrong reason.
	if (fatal != 0) exit fatal

	## Outcome rc 2, first half: Slack itself refused. The calling op already
	## turns ok:false into a failure of its own, so this is the second line of
	## defence rather than the only one -- but a script that printed a clean
	## "message not found" for an ok:false response would be reporting the wrong
	## fact, so it is tested here too.
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 2
	}

	## Outcome rc 2, second half: COULD-NOT-PARSE, distinct from "parsed fine,
	## the message is not in there." Every real API response carries an `ok`
	## key, so reaching here having seen no `ok` AND no messages means the input
	## was not the JSON this script parses. Both conditions are required: a
	## response whose messages array came through did parse by definition, and a
	## missing `ok` there is a Slack-side shape change to notice separately.
	if (!apiOkSeen && msgCount == 0) {
		printf("⛔ ERROR: AgentsSlackMessageSelect.awk: could not parse the Slack response: no `ok` key and no messages -- the input was not a parseable API response (truncated body, error page, or empty read), NOT a conversation with nothing in it\n") > "/dev/stderr"
		exit 2
	}

	## Outcome rc 0: read-and-found. A positive test for an element carrying the
	## requested ts -- the loop concludes only by finding one, never by finding
	## the array empty.
	for (i = 0; i < msgCount; i++) {
		if (!(i in rawOf)) continue
		if ((tsOf[i] "") != (wantTs "")) continue
		printf("{\"ok\":true,\"messages\":[%s]}\n", rawOf[i])
		exit 0
	}

	## Outcome rc 1: read-but-absent. Named with the ts that was actually asked
	## for, and with how many messages were seen instead, so the report can be
	## acted on without a second investigation.
	printf("⛔ ERROR: AgentsSlackMessageSelect.awk: COULD NOT READ message ts=%s -- the call succeeded and returned %d message(s), none of them carrying that ts. This is a failed read, NOT an empty conversation: nothing here supports concluding that the message does not exist.\n", wantTs, msgCount) > "/dev/stderr"
	exit 1
}
