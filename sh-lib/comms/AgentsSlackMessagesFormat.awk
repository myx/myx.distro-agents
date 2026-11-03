#!/usr/bin/env awk

# Parses one single-line Slack conversations.history/conversations.replies
# JSON response (stdin, LC_ALL=C for byte safety) and prints one clean
# "ts | user | text" line per message to stdout.
#
# A message's `reactions` array and its `reply_count`/`latest_reply` fields
# sit directly on the message object in both APIs. When present they go on
# that message's HEAD line, BEFORE the text, as "[reactions: NAME xCOUNT
# (USERS)]" (one bracket per distinct reaction) and "[thread: N replies,
# latest at TS]". Before and not after because message text can carry an
# embedded newline: appended, the annotation stranded itself on a trailing
# physical line, where the fan-out tagger read it as a continuation. The
# thread annotation names no author -- conversations.history has no field
# naming the latest reply's author, and `reply_users` is not parsed at all.
#
# Lives here (myx.distro-agents/sh-lib, not myx.common) because it's
# Slack/DistroAgentsTools-specific. Consumers, by call site: the two
# `AgentsToolsSlackCheck` reads in sh-lib/comms/AgentsTools.CommsSlack.include
# (per-DM fan-out leg, single-conversation path), the escalation-thread
# read in sh-lib/questions/AgentsTools.MemberEscalation.include, and the Wait thread
# probe in sh-lib/member/AgentsTools.MemberWait.include. NOT --intern-op-sweep-input-scan,
# which never invokes this file -- that op feeds AgentsSessionContextCommsItems.awk.
#
# agentMcpJsonParseRequest.awk; only the leaf-emission logic differs. Not a
# general-purpose formatter: only understands the flat messages[] array
# shape Slack's own API actually returns.

BEGIN { msgCount = 0; apiOk = "true"; apiOkSeen = 0; jfLibrary = 1 ; jfLax = 1 }

## A text with every Slack date token in it, `<!date^<epoch>^<token string>|<fallback>>`,
## as its fallback text: what a reader of this rendering can use, where the raw control
## string is noise. The tooling's own posts carry them (sh-lib/comms/AgentsSlackDate.awk, whose
## sldFallbacks this is, word for word; a copy, because this file runs with no other
## loaded, as it carries its JSON engine).
function dateFallbacks(textValue,   outText, tokenText, barAt) {
	outText = ""
	while (match(textValue, /<!date\^[0-9]+\^[^|>]*\|[^>]*>/)) {
		tokenText = substr(textValue, RSTART, RLENGTH)
		outText = outText substr(textValue, 1, RSTART - 1)
		textValue = substr(textValue, RSTART + RLENGTH)
		barAt = index(tokenText, "|")
		outText = outText substr(tokenText, barAt + 1, length(tokenText) - barAt - 1)
	}
	return outText textValue
}

## A text with no line of it reading as a message head. Message text carries embedded
## newlines, and every reader of this rendering knows a message by its head line,
## "<ts> | <user> |": a line of text shaped like one was read as a message of its own, by
## whoever it named and at the ts it named. So anyone who could post in a thread could put
## a reply there in another's name -- an owner's verdict on a permission -- and an asker could
## in its own question's words. Such a line is printed one space in, where no reader takes
## it for a head; nothing else of the text changes.
## A text that itself STARTS as one of this formatter's own annotations is printed one
## space in. A reader tells who sent a post, and what was clicked under it, by the
## annotation that stands ahead of the text -- AgentsSlackThreadAnswers.awk takes the
## answer of a member with no account of its own by `[sender: X]` -- so that place holds
## the formatter's word only, never what somebody typed.
function ownStart(textValue) {
	return (textValue ~ /^\[(sender|tracking|session|reactions|thread|file|voice): /) ? " " textValue : textValue
}

function ownLines(textValue,   outText) {
	outText = ""
	while (match(textValue, /\n[0-9]+\.[0-9]+ \| /)) {
		outText = outText substr(textValue, 1, RSTART) " "
		textValue = substr(textValue, RSTART + 1)
	}
	return outText textValue
}

## Slack-specific: track ts/user/bot_id/text plus each message's own
## reactions[] array and reply_count/latest_reply fields, per
## message index; print in END once every field has been seen -- field
## order in Slack's real API responses isn't something to depend on.
function jfNodeHook(path, nodeType, nodeValue, fromPos, toPos,   idx, rest, afterIdx, afterReactions, j, afterJ, jNum) {
	if (path == "ok") { apiOk = nodeValue; apiOkSeen = 1; return; }
	if (path == "error") { apiError = nodeValue; return; }
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1

	if (rest == idx ".ts") { tsOf[idx] = nodeValue; return; }
	if (rest == idx ".user") { userOf[idx] = nodeValue; return; }
	if (rest == idx ".bot_id" && !(idx in userOf)) { userOf[idx] = nodeValue; return; }
	if (rest == idx ".text") { textOf[idx] = nodeValue; return; }

	## Everything below is nested under messages.<idx>. -- pull off that
	## prefix once, then match the remaining sub-path.
	if (index(rest, idx ".") != 1) return
	afterIdx = substr(rest, length(idx) + 2)

	if (afterIdx == "reply_count") { replyCountOf[idx] = nodeValue; return; }
	if (afterIdx == "latest_reply") { latestReplyOf[idx] = nodeValue; return; }
	## `chat.postMessage`'s own `metadata.event_payload.sender` field, present
	## only when the sender asked for it and the read asked `include_all_metadata`
	## back. Absent for every message that carries neither, so this adds nothing
	## to a rendering with no such message.
	if (afterIdx == "metadata.event_payload.sender") { senderOf[idx] = nodeValue; return; }
	## S27.8: the run that wrote a tooling message, and the run it was for. They are what lets one run
	## of a member dismiss another run of that member, and never itself.
	if (afterIdx == "metadata.event_payload.author_run") { authorRunOf[idx] = nodeValue; return; }
	if (afterIdx == "metadata.event_payload.addressee_run") { addresseeRunOf[idx] = nodeValue; return; }
	## The tooling's own tracking posts (AgentsTools.InternOpEventTrackPost.include, the session root) carry `event_payload.tracking`, the kind of the
	## post: a reader that decides whether something is input tells them by this annotation, `[tracking: <kind>]`, never by their text.
	if (afterIdx == "metadata.event_payload.tracking") { trackingOf[idx] = nodeValue; return; }
	## and the spawn id of the session it belongs to, `[session: <id>]`, which says whose launch it is (AgentsTools.TrackingDrop.include).
	if (afterIdx == "metadata.event_payload.session") { sessionOf[idx] = nodeValue; return; }
	## The body of an event-track post is in its blocks, its `text` only the line a notification shows: the text leaves of its blocks are
	## kept, a block to a line, and stand in for its text (below), so a read of a tooling thread carries what it says. A `tooling` send keeps
	## its own text, whole, with the header `→ *_member_*.` the readers parse (AgentsTrackingDrop.awk, AgentsSessionChatImport.awk).
	if (index(afterIdx, "blocks.") == 1 && afterIdx ~ /\.text$/) {
		j = substr(afterIdx, length("blocks.") + 1)
		sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		if (idx in blockTextOf) blockTextOf[idx] = blockTextOf[idx] ((blockLastOf[idx] != j) ? "\n" : " ")
		blockTextOf[idx] = blockTextOf[idx] nodeValue
		blockLastOf[idx] = j
		return
	}
	## A message's files (Slack's files[]): each said on the head line as `[file: <id> <name> (<size> bytes, <type>)]`, so a reader and
	## the comms cache know it carried one; the id is what --slack-file-info takes.
	if (index(afterIdx, "files.") == 1) {
		afterReactions = substr(afterIdx, length("files.") + 1)
		j = afterReactions
		sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		jNum = j + 0
		if (!(idx in fileCountPerMsg) || jNum + 1 > fileCountPerMsg[idx]) fileCountPerMsg[idx] = jNum + 1
		afterJ = substr(afterReactions, length(j) + 2)
		if (afterJ == "id") fileIdOf[idx, j] = nodeValue
		else if (afterJ == "name") fileNameOf[idx, j] = nodeValue
		else if (afterJ == "size") fileSizeOf[idx, j] = nodeValue
		else if (afterJ == "mimetype") fileTypeOf[idx, j] = nodeValue
		return
	}
	if (index(afterIdx, "reactions.") == 1) {
		afterReactions = substr(afterIdx, length("reactions.") + 1)
		j = afterReactions
		sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		jNum = j + 0
		if (!(idx in reactionCountPerMsg) || jNum + 1 > reactionCountPerMsg[idx]) reactionCountPerMsg[idx] = jNum + 1
		afterJ = substr(afterReactions, length(j) + 2)
		if (afterJ == "name") reactionNameOf[idx, j] = nodeValue
		else if (afterJ == "count") reactionCountOf[idx, j] = nodeValue
		else if (index(afterJ, "users.") == 1) {
			if ((idx, j) in reactionUsersOf) reactionUsersOf[idx, j] = reactionUsersOf[idx, j] "," nodeValue
			else reactionUsersOf[idx, j] = nodeValue
		}
		return
	}
}

{ jfConsumeText($0) }

## Prints oldest-first (chronological), sorted on ts rather than taken from
## the body's own order: conversations.history returns newest-first and
## conversations.replies oldest-first. Reaction/thread annotations are
## appended to the same line, never a separate output line, so a
## "ts | user | text" parser downstream keeps working unchanged.
END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}

	## Fixed-width seconds then microseconds: the sort compares bytes, never a float, which at 1.8e9 cannot separate two ts a microsecond apart.
	for (keyPos = 0; keyPos < msgCount; keyPos++) {
		tsSeconds = tsOf[keyPos]
		tsFraction = tsOf[keyPos]
		sub(/\..*$/, "", tsSeconds)
		sub(/^[0-9]*\.?/, "", tsFraction)
		sortKeyOf[keyPos] = sprintf("%016d", tsSeconds) substr(tsFraction "000000", 1, 6)
		orderOf[keyPos] = keyPos
	}
	for (sortPos = 1; sortPos < msgCount; sortPos++) {
		sortIdx = orderOf[sortPos]
		sortScan = sortPos - 1
		while (sortScan >= 0 && sortKeyOf[orderOf[sortScan]] > sortKeyOf[sortIdx]) {
			orderOf[sortScan + 1] = orderOf[sortScan]
			sortScan--
		}
		orderOf[sortScan + 1] = sortIdx
	}

	for (emitPos = 0; emitPos < msgCount; emitPos++) {
		i = orderOf[emitPos]
		annotations = ""

		## S27.8: BOTH RUNS, on a message from the tooling, printed where the head's own annotations go
		## so the dismissal matcher reads them beside the sender it already reads.
		if (i in authorRunOf) annotations = annotations sprintf(" [author-run: %s]", authorRunOf[i])
		if (i in addresseeRunOf) annotations = annotations sprintf(" [addressee-run: %s]", addresseeRunOf[i])
		if (i in senderOf) annotations = annotations sprintf(" [sender: %s]", senderOf[i])
		if (i in trackingOf) annotations = annotations sprintf(" [tracking: %s]", trackingOf[i])
		if (i in sessionOf) annotations = annotations sprintf(" [session: %s]", sessionOf[i])

		if (i in reactionCountPerMsg) {
			for (j = 0; j < reactionCountPerMsg[i]; j++) {
				rName = ((i, j) in reactionNameOf) ? reactionNameOf[i, j] : "?"
				rCount = ((i, j) in reactionCountOf) ? reactionCountOf[i, j] : "?"
				rUsers = ((i, j) in reactionUsersOf) ? reactionUsersOf[i, j] : "?"
				annotations = annotations sprintf(" [reactions: %s x%s (%s)]", rName, rCount, rUsers)
			}
		}

		if ((i in replyCountOf) && replyCountOf[i] + 0 > 0) {
			annotations = annotations sprintf(" [thread: %s replies, latest at %s]", \
				replyCountOf[i], (i in latestReplyOf ? latestReplyOf[i] : "?"))
		}

		if (i in fileCountPerMsg) {
			for (j = 0; j < fileCountPerMsg[i]; j++) {
				if (!((i, j) in fileIdOf)) continue
				fName = ((i, j) in fileNameOf) ? fileNameOf[i, j] : "?"
				gsub(/[\]\n]/, "_", fName)
				annotations = annotations sprintf(" [file: %s %s (%s bytes, %s)]", fileIdOf[i, j], fName, \
					(((i, j) in fileSizeOf) ? fileSizeOf[i, j] : "?"), (((i, j) in fileTypeOf) ? fileTypeOf[i, j] : "?"))
			}
		}

		print sprintf("%s | %s |%s %s", tsOf[i], (i in userOf ? userOf[i] : "?"), annotations, ownStart(ownLines(dateFallbacks(((i in trackingOf) && trackingOf[i] != "tooling" && blockTextOf[i] != "") ? blockTextOf[i] : textOf[i]))))
	}
}
