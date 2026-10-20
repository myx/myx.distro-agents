# AgentsContactsIndex.awk -- the one reader of the contact records (F7.10), over the person files of the store given as the input
# files. One row a record that is asked for, TAB-separated:
#   contact <id> <display-name> <organisation> <reached-by> <matched-on>
# The mode (-v mode=):
#   all      every record; -v orgfilter=<slug> keeps one organisation's, -v member=<name> the ones that member holds. matched-on is `-`.
#   find     the records -v want=<text> names: its id, a name (equal, or contained from three characters), a coordinate (a Slack id, conversation
#            or handle, with or without its team, an e-mail), whichever it is first. -v team=<scope> keeps the Slack coordinates of that team;
#            -v member=<name> keeps the records that member holds.
#   known    the outbound gate's question: a record -v member=<name> holds with a coordinate EQUAL to -v want=<value> (a Slack id, a Slack
#            conversation id, an e-mail); no name and no handle. -v team=<scope> keeps the Slack coordinates of that team.
# The record is read as the tool writes it: front matter lines `key: value`, the values of a coordinate a list `a, b`, a Slack entry `<team>:<value>`.

function lower(text) { return tolower(text) }
function trim(text) { sub(/^[ \t]+/, "", text) ; sub(/[ \t]+$/, "", text) ; return text }
function inlist(list, item,    count, parts, at) {
	count = split(list, parts, /, */)
	for (at = 1 ; at <= count ; at++) if (lower(trim(parts[at])) == lower(item)) return 1
	return 0
}
## A Slack coordinate list: `<team>:<value>` entries. Equal to the wanted text as a whole entry, or by its value, within the team asked for.
function slackHas(list, text,    count, parts, at, entry, colon, entryTeam, entryValue) {
	count = split(list, parts, /, */)
	for (at = 1 ; at <= count ; at++) {
		entry = trim(parts[at])
		colon = index(entry, ":")
		if (colon == 0) continue
		entryTeam = substr(entry, 1, colon - 1) ; entryValue = substr(entry, colon + 1)
		if (team != "" && lower(entryTeam) != lower(team)) continue
		if (lower(entry) == text || lower(entryValue) == text) return 1
	}
	return 0
}
## A handle list: `<team>:@<handle>`, the `@` optional on either side.
function handleHas(list, text,    count, parts, at, entry, colon, entryTeam, entryValue, bare) {
	bare = text ; sub(/^@/, "", bare)
	count = split(list, parts, /, */)
	for (at = 1 ; at <= count ; at++) {
		entry = trim(parts[at])
		colon = index(entry, ":")
		if (colon == 0) continue
		entryTeam = substr(entry, 1, colon - 1) ; entryValue = substr(entry, colon + 1) ; sub(/^@/, "", entryValue)
		if (team != "" && lower(entryTeam) != lower(team)) continue
		if (lower(entryValue) == bare) return 1
	}
	return 0
}
function reset() {
	id = "" ; name = "" ; recOrg = "" ; reached = "" ; slackId = "" ; slackHandle = "" ; slackConv = "" ; email = ""
	front = 0 ; seen = 0
}
function flush(    matched) {
	if (! seen || id == "") return
	matched = "-"
	if (mode == "all" && orgfilter != "" && lower(orgOf()) != lower(orgfilter)) return
	if (member != "" && ! inlist(reached, member)) return
	if (mode == "find") {
		matched = ""
		if (lower(id) == want) matched = "id"
		else if (lower(name) == want) matched = "name"
		else if (length(want) >= 3 && index(lower(name), want) > 0) matched = "name"
		else if (slackHas(slackId, want)) matched = "slack-id"
		else if (slackHas(slackConv, want)) matched = "slack-conversation"
		else if (handleHas(slackHandle, want)) matched = "slack-handle"
		else if (inlist(email, want)) matched = "email"
		if (matched == "") return
	} else if (mode == "known") {
		matched = ""
		if (slackHas(slackId, want)) matched = "slack-id"
		else if (slackHas(slackConv, want)) matched = "slack-conversation"
		else if (inlist(email, want)) matched = "email"
		if (matched == "") return
	}
	printf "contact\t%s\t%s\t%s\t%s\t%s\n", id, name, orgOf(), reached, matched
}
function orgOf() { return (recOrg == "none" ? "" : recOrg) }
BEGIN { mode = (mode == "" ? "all" : mode) ; want = lower(want) ; reset() }
FNR == 1 { flush() ; reset() }
{
	if (FNR == 1) { if ($0 == "---") front = 1 ; next }
	if (front == 1) {
		if ($0 == "---") { front = 2 ; next }
		at = index($0, ": ")
		if (at == 0) next
		key = substr($0, 1, at - 1) ; value = substr($0, at + 2)
		if (key == "type" && value == "contact") seen = 1
		else if (key == "contact-id") id = value
		else if (key == "display-name") name = value
		else if (key == "organisation") recOrg = value
		else if (key == "reached-by") reached = value
		else if (key == "slack-id") slackId = value
		else if (key == "slack-handle") slackHandle = value
		else if (key == "slack-conversation") slackConv = value
		else if (key == "email") email = value
	}
}
END { flush() }
