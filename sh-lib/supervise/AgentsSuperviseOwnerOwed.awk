#!/usr/bin/env awk
## Which messages of the human-owner no other account answered (S13 `owner-owed`). Reads the comms cache's
## `YYYYMM/messages.txt` files named on the command line, one line a message, `<ts> | <author> | <text>`, and prints
## `owner-owed <ws> <conversation>:<ts> age=<n>m <first words>` for each of the owner's messages that no message of
## another account follows in its own thread. Its own thread is the conversation it was read in; for a message a thread
## folder carries, it is that thread.
## -v ws the workspace's name, owner the owner's account id, team the team channel's id, now the scan's clock,
## headBytes the head's length. A conversation is read when it is the team channel or a direct one, and nothing else:
## another channel, and a mentions or search partition, hold no conversation of his.
## THE FOLDER'S CONVERSATION AND THREAD COME FROM ITS OWN `.state.txt` PULLING LINE, `slack-conversation <target>` or
## `slack-thread <channel>:<thread ts>`, as the cache-to-inbox transfer reads them, or from the line of a thread folder our own
## post made, `slack-local-thread <channel>:<thread ts>`, which nothing pulls (AgentsToolsCommsCachePostStore): the store owns that fact, and a
## folder's name is no second owner of it. LC_ALL=C.

function tsAfter(one, two,   oneSec, twoSec, oneFrac, twoFrac) {
	if (two == "") return 1
	oneSec = one ; sub(/\..*/, "", oneSec) ; twoSec = two ; sub(/\..*/, "", twoSec)
	if (oneSec + 0 != twoSec + 0) return (oneSec + 0 > twoSec + 0)
	oneFrac = "000000" ; if (index(one, ".")) { oneFrac = substr(one, index(one, ".") + 1) ; oneFrac = substr(oneFrac "000000", 1, 6) }
	twoFrac = "000000" ; if (index(two, ".")) { twoFrac = substr(two, index(two, ".") + 1) ; twoFrac = substr(twoFrac "000000", 1, 6) }
	return (oneFrac + 0 > twoFrac + 0)
}

## A folder's own pulling line read into owedConv and owedThread: the conversation it is, and the thread where it is one.
function readPulling(   line, word, count, fields, target) {
	owedConv = "" ; owedThread = ""
	while ((getline line < (owedDir "/.state.txt")) > 0) {
		count = split(line, fields, " ")
		if (count < 2 || (fields[1] != "slack-conversation" && fields[1] != "slack-thread" && fields[1] != "slack-local-thread")) continue
		target = fields[2]
		if (fields[1] != "slack-conversation" && index(target, ":")) {
			owedThread = substr(target, index(target, ":") + 1)
			target = substr(target, 1, index(target, ":") - 1)
		}
		break
	}
	close(owedDir "/.state.txt")
	if (target ~ /^[CD][A-Z0-9]+$/ && (target == team || target ~ /^D/)) owedConv = target
}

FNR == 1 {
	owedDir = FILENAME
	sub(/\/[0-9][0-9][0-9][0-9][0-9][0-9]\/messages\.txt$/, "", owedDir)
	readPulling()
}

owedConv == "" { next }

{
	owedAt = index($0, " | ") ; if (owedAt == 0) next
	owedTs = substr($0, 1, owedAt - 1)
	if (owedTs !~ /^[0-9]+\.[0-9]+$/) next
	owedRest = substr($0, owedAt + 3)
	owedAt = index(owedRest, " | ") ; if (owedAt == 0) next
	owedWho = substr(owedRest, 1, owedAt - 1)
	owedText = substr(owedRest, owedAt + 3)
	if (owedWho == "") next
	owedKey = owedConv "\037" owedThread
	if (owedWho != owner) { if (tsAfter(owedTs, owedOther[owedKey])) owedOther[owedKey] = owedTs ; next }
	owedOwn = owedConv "\037" owedTs
	if (!(owedOwn in owedSeen)) {
		owedSeen[owedOwn] = ++owedCount
		owedList[owedCount] = owedOwn
		owedConvOf[owedOwn] = owedConv
		owedWhen[owedOwn] = owedTs
		owedBody[owedOwn] = owedText
		owedIn[owedOwn] = owedThread
	} else if (owedIn[owedOwn] == "" && owedThread != "") owedIn[owedOwn] = owedThread
}

END {
	for (owedIndex = 1 ; owedIndex <= owedCount ; owedIndex++) {
		owedOwn = owedList[owedIndex]
		owedAt = owedWhen[owedOwn]
		if (tsAfter(owedOther[owedConvOf[owedOwn] "\037" owedIn[owedOwn]], owedAt)) continue
		if (owedIn[owedOwn] == "" && tsAfter(owedOther[owedConvOf[owedOwn] "\037" owedAt], owedAt)) continue
		owedAge = int((now - substr(owedAt, 1, index(owedAt, ".") - 1)) / 60)
		if (owedAge < 0) owedAge = 0
		owedHead = owedBody[owedOwn]
		while (match(owedHead, /^\[[^]]*\] /)) owedHead = substr(owedHead, RLENGTH + 1)
		gsub(/[\036\037]/, " ", owedHead)
		gsub(/[[:space:]]+/, " ", owedHead)
		sub(/^ /, "", owedHead)
		printf "owner-owed %s %s:%s age=%dm %s\n", ws, owedConvOf[owedOwn], owedAt, owedAge, substr(owedHead, 1, headBytes)
	}
}
