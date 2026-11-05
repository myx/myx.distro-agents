#!/usr/bin/env awk
## The comms cache's events from one Slack read (S1.12 §2): stdin one raw conversations.history or
## conversations.replies body, stdout the fifteen columns of an event row without its `id`, one a line,
## compared against what the source's event files already hold (-v storeFiles, space-separated). A kind is
## emitted only where the store does not already hold it, and a mark the store holds and the read lacks is an
## `rx-`, which is the one removal a comparison can see (§2.5). Order and duplicates are the caller's:
## the rows are sorted and deduplicated before any id is pasted on. LC_ALL=C.
## The column meanings, the two escapes and the threshold live in myx.distro-agents/MAGIC.md (§ comms events).
BEGIN {
	jfLibrary = 1 ; jfLax = 1
	msgCount = 0 ; apiOk = "true" ; apiOkSeen = 0
	headBytes = (headBytes == "" ? 400 : headBytes + 0)
	lineBytes = (lineBytes == "" ? 2000 : lineBytes + 0)
	storeCount = split(storeFiles, storeList, " ")
	for (storeIndex = 1 ; storeIndex <= storeCount ; storeIndex++) {
		if (storeList[storeIndex] == "") continue
		storeDir = storeList[storeIndex] ; sub(/\/[^\/]*$/, "", storeDir)
		while ((getline storeLine < storeList[storeIndex]) > 0) storedEvent(storeLine, storeDir)
		close(storeList[storeIndex])
	}
}

## One stored event folded into what a new read is compared against: which messages are held, their text
## (from the body file where the line was cut), the live marks, the thread summary, the reply authors, the
## files and the unfurl targets.
function storedEvent(line, dir,   col, n, kind, mid, text) {
	n = split(line, col, "\t")
	if (n < 16) return
	kind = col[2] ; mid = col[3]
	if (kind == "msg" || kind == "post") { heldMsg[mid] = 1 ; heldText[mid] = storedText(col[7], dir, col[16]) ; return }
	if (kind == "edit") { heldText[mid] = storedText(col[7], dir, col[16]) ; return }
	if (kind == "rx") { heldMark[mid, col[4], col[7]] = 1 ; return }
	if (kind == "rx-") { delete heldMark[mid, col[4], col[7]] ; return }
	if (kind == "thr") { heldThr[mid] = col[5] "\036" col[6] ; return }
	if (kind == "thru") { heldThru[mid, col[4]] = 1 ; return }
	if (kind == "fl") { heldFl[mid, col[5]] = 1 ; return }
	if (kind == "att") { heldAtt[mid, col[5]] = 1 ; return }
}

## A stored body as the line would have carried it: the escaped column, or the body file's own text escaped
## the same way, so the two sides of a comparison are one form.
function storedText(column, dir, bodyName,   text, one) {
	if (bodyName == "") return column
	text = ""
	while ((getline one < (dir "/" bodyName)) > 0) text = (text == "" ? one : text "\n" one)
	close(dir "/" bodyName)
	return esc(text)
}

function esc(value) {
	gsub(/\r/, "", value)
	gsub(/\t/, "\\036", value)
	gsub(/\n/, "\\037", value)
	return value
}

## The message's own rendered body (§5): a tooling post's text from its blocks where a tracking mark is
## present, as AgentsSlackMessagesFormat.awk:227 decides it, and the `text` field otherwise.
function renderedBody(idx,   text) {
	text = ""
	if ((idx in trackingOf) && trackingOf[idx] != "tooling" && (idx in blockTextOf)) text = blockTextOf[idx]
	if (text == "") text = ((idx in textOf) ? textOf[idx] : "")
	return text
}

function jfNodeHook(path, nodeType, nodeValue, fromPos, toPos,   idx, rest, after, j, num, field) {
	if (path == "ok") { apiOk = nodeValue ; apiOkSeen = 1 ; return }
	if (path == "error") { apiError = nodeValue ; return }
	if (index(path, "messages.") != 1) return
	rest = substr(path, length("messages.") + 1)
	idx = rest
	sub(/\..*/, "", idx)
	if (idx !~ /^[0-9]+$/) return
	if (idx + 1 > msgCount) msgCount = idx + 1
	if (rest == idx ".ts") { tsOf[idx] = nodeValue ; return }
	if (rest == idx ".user") { userOf[idx] = nodeValue ; return }
	if (rest == idx ".bot_id") { botOf[idx] = nodeValue ; return }
	if (rest == idx ".subtype") { subOf[idx] = nodeValue ; return }
	if (rest == idx ".thread_ts") { threadTsOf[idx] = nodeValue ; return }
	if (rest == idx ".text") { textOf[idx] = nodeValue ; return }
	if (rest == idx ".reply_count") { replyCountOf[idx] = nodeValue ; return }
	if (rest == idx ".latest_reply") { latestReplyOf[idx] = nodeValue ; return }
	if (index(rest, idx ".") != 1) return
	after = substr(rest, length(idx) + 2)
	if (after == "edited.user") { editedByOf[idx] = nodeValue ; return }
	if (after == "metadata.event_payload.sender") { senderOf[idx] = nodeValue ; return }
	if (after == "metadata.event_payload.author_run") { authorRunOf[idx] = nodeValue ; return }
	if (after == "metadata.event_payload.addressee_run") { addresseeRunOf[idx] = nodeValue ; return }
	if (after == "metadata.event_payload.tracking") { trackingOf[idx] = nodeValue ; return }
	if (after == "metadata.event_payload.session") { sessionOf[idx] = nodeValue ; return }
	if (index(after, "blocks.") == 1 && after ~ /\.text$/) {
		j = substr(after, length("blocks.") + 1) ; sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		blockTextOf[idx] = blockTextOf[idx] ((idx in blockLastOf && blockLastOf[idx] != j) ? "\n" : "") nodeValue
		blockLastOf[idx] = j
		return
	}
	if (index(after, "reply_users.") == 1) { replyUsersOf[idx] = replyUsersOf[idx] " " nodeValue ; return }
	if (index(after, "reactions.") == 1) {
		rest = substr(after, length("reactions.") + 1) ; j = rest ; sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		num = extCount("reaction", idx) ; if (j + 1 > num) extSet("reaction", idx, j + 1)
		field = substr(rest, length(j) + 2)
		if (field == "name") reactionNameOf[idx, j] = nodeValue
		else if (field == "count") reactionCountOf[idx, j] = nodeValue
		else if (index(field, "users.") == 1) reactionUsersOf[idx, j] = reactionUsersOf[idx, j] (reactionUsersOf[idx, j] == "" ? "" : " ") nodeValue
		return
	}
	if (index(after, "files.") == 1) {
		rest = substr(after, length("files.") + 1) ; j = rest ; sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		num = extCount("file", idx) ; if (j + 1 > num) extSet("file", idx, j + 1)
		field = substr(rest, length(j) + 2)
		if (field == "id") fileIdOf[idx, j] = nodeValue
		else if (field == "name") fileNameOf[idx, j] = nodeValue
		else if (field == "size") fileSizeOf[idx, j] = nodeValue
		else if (field == "mimetype") fileTypeOf[idx, j] = nodeValue
		return
	}
	if (index(after, "attachments.") == 1) {
		rest = substr(after, length("attachments.") + 1) ; j = rest ; sub(/\..*/, "", j)
		if (j !~ /^[0-9]+$/) return
		num = extCount("attach", idx) ; if (j + 1 > num) extSet("attach", idx, j + 1)
		field = substr(rest, length(j) + 2)
		if (field == "text") attachTextOf[idx, j] = nodeValue
		else if (field == "from_url" || field == "original_url") attachUrlOf[idx, j] = nodeValue
		return
	}
}

## How many children of one nested array a message carries: awk 3 has no per-key count of its own, and a
## parallel name per array is one more thing to get wrong.
function extCount(kind, idx) { return (extCountOf[kind, idx] == "" ? 0 : extCountOf[kind, idx]) }
function extSet(kind, idx, value) { extCountOf[kind, idx] = value }

## The message id an unfurl points at, from Slack's own `/p<digits>` form (`…/p1793394716507419`).
function unfurlTarget(url,   digits) {
	if (!match(url, /\/p[0-9]+/)) return ""
	digits = substr(url, RSTART + 2, RLENGTH - 2)
	digits = substr(digits, 1, 10) "." substr(digits, 11)
	return digits
}

{ jfConsumeText($0) }

END {
	if (apiOkSeen && apiOk == "false") {
		printf("⛔ ERROR: Slack API call failed: ok:false%s\n", (apiError != "" ? " error=" apiError : "")) > "/dev/stderr"
		exit 1
	}
	for (i = 0 ; i < msgCount ; i++) {
		if (!(i in tsOf) || tsOf[i] == "") continue
		mid = tsOf[i]
		author = (i in userOf) ? userOf[i] : ((i in botOf) ? botOf[i] : "")
		botId = (i in botOf) ? botOf[i] : ""
		par = (i in threadTsOf) ? threadTsOf[i] : ""
		text = renderedBody(i)
		if (!(mid in heldMsg)) {
			emit("msg", mid, author, mid, "", esc(text), botId, ((i in subOf) ? subOf[i] : ""), par, ((i in senderOf) ? senderOf[i] : ""), ((i in trackingOf) ? trackingOf[i] : ""), ((i in sessionOf) ? sessionOf[i] : ""), ((i in authorRunOf) ? authorRunOf[i] : ""), ((i in addresseeRunOf) ? addresseeRunOf[i] : ""), "")
		} else if (esc(text) != heldText[mid]) {
			emit("edit", mid, ((i in editedByOf) ? editedByOf[i] : author), "", "", esc(text), "", "", "", "", "", "", "", "", "")
		}
		for (j = 0 ; j < extCount("reaction", i) ; j++) {
			name = ((i, j) in reactionNameOf) ? reactionNameOf[i, j] : ""
			if (name == "") continue
			userCount = split(((i, j) in reactionUsersOf) ? reactionUsersOf[i, j] : "", userList, " ")
			for (k = 1 ; k <= userCount ; k++) if (!((mid, userList[k], name) in heldMark)) emit("rx", mid, userList[k], "", "", name, "", "", "", "", "", "", "", "", "")
		}
		for (markKey in heldMark) {
			split(markKey, markKeyParts, SUBSEP)
			if (markKeyParts[1] != mid) continue
			if (!reactedNow(i, markKeyParts[2], markKeyParts[3])) emit("rx-", mid, markKeyParts[2], "", "", markKeyParts[3], "", "", "", "", "", "", "", "", "")
		}
		threadNow = ((i in replyCountOf) ? replyCountOf[i] : "") "\036" ((i in latestReplyOf) ? latestReplyOf[i] : "")
		if (threadNow != "\036" && threadNow != ((mid in heldThr) ? heldThr[mid] : "")) emit("thr", mid, "", ((i in replyCountOf) ? replyCountOf[i] : ""), ((i in latestReplyOf) ? latestReplyOf[i] : ""), "", "", "", "", "", "", "", "", "", "")
		userCount = split(((i in replyUsersOf) ? replyUsersOf[i] : ""), userList, " ")
		for (k = 1 ; k <= userCount ; k++) if (userList[k] != "" && !((mid, userList[k]) in heldThru)) emit("thru", mid, userList[k], "", "", "", "", "", "", "", "", "", "", "", "")
		for (j = 0 ; j < extCount("file", i) ; j++) {
			fileId = ((i, j) in fileIdOf) ? fileIdOf[i, j] : ""
			if (fileId == "" || ((mid, fileId) in heldFl)) continue
			emit("fl", mid, "", fileId, (((i, j) in fileSizeOf) ? fileSizeOf[i, j] : "") " " (((i, j) in fileTypeOf) ? fileTypeOf[i, j] : ""), ((i, j) in fileNameOf) ? fileNameOf[i, j] : "", "", "", "", "", "", "", "", "", "")
		}
		for (j = 0 ; j < extCount("attach", i) ; j++) {
			target = unfurlTarget(((i, j) in attachUrlOf) ? attachUrlOf[i, j] : "")
			if (((mid, target) in heldAtt)) continue
			emit("att", mid, "", target, "", esc(((i, j) in attachTextOf) ? attachTextOf[i, j] : ""), "", "", "", "", "", "", "", "", "")
		}
	}
}

## Whether the read still carries a mark the store holds: asked of the walk's own collected users.
function reactedNow(idx, user, name,   j, userCount, userList) {
	for (j = 0 ; j < extCount("reaction", idx) ; j++) {
		if (((idx, j) in reactionNameOf) && reactionNameOf[idx, j] == name) {
			userCount = split(((idx, j) in reactionUsersOf) ? reactionUsersOf[idx, j] : "", userList, " ")
			for (k = 1 ; k <= userCount ; k++) if (userList[k] == user) return 1
		}
	}
	return 0
}

function emit(kind, mid, u, v1, v2, x, bot, subtype, par, sender, track, sess, arun, adrun, body) {
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", esc(kind), esc(mid), esc(u), esc(v1), esc(v2), x, esc(bot), esc(subtype), esc(par), esc(sender), esc(track), esc(sess), esc(arun), esc(adrun), esc(body)
}
