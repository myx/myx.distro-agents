# AgentsTeamDataMergeSettle.awk -- the text of `git merge-file -p -L ours -L base -L theirs` on stdin, its conflict blocks resolved in place, no marker left.
# ours is the local side, theirs is origin. A block whose every non-blank line starts with a timestamp is a block of line records (logs, registries): the
# file is then a file of line records, and its timestamped lines are each kept once, in time order, between the lines before the first of them (a header)
# and the lines after the last. A block in the header of a document (between its first two --- lines) is settled by key: a key both sides changed ends
# with ONE line, the value of the side whose own change stamp (-v oursStamp, -v theirsStamp) is later, origin's where neither has one or they are equal;
# a key only one side holds is kept. Any other block is a document's body: origin's lines, then the lines of the local side that origin's do not hold, so
# both versions stand in the one file and none is lost.
function stamped(line) { return line ~ /^(- )?[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][T ][0-9][0-9]:[0-9][0-9]/ }
function put(line) { out[++nOut] = line }
function isKey(line) { return line ~ /^[A-Za-z0-9_.-]+:/ }
function keyOf(line,   key) { key = line; sub(/:.*/, "", key); return key }
function parseSide(lines, n, text, order,   at, key, count) {
	count = 0; key = ""
	for (at = 1; at <= n; at++) {
		if (isKey(lines[at])) { key = keyOf(lines[at]); if (!(key in text)) { order[++count] = key; text[key] = lines[at] } else text[key] = text[key] "\n" lines[at] }
		else if (key != "") text[key] = text[key] "\n" lines[at]
		else { order[++count] = "#" at; text["#" at] = lines[at] }
	}
	return count
}
function settleHeader(   at, nT, nO, key, pickOurs) {
	delete tText; delete oText; delete tOrder; delete oOrder
	nT = parseSide(theirs, nTheirs, tText, tOrder)
	nO = parseSide(ours, nOurs, oText, oOrder)
	pickOurs = (oursStamp != "" && oursStamp > theirsStamp)
	for (at = 1; at <= nT; at++) {
		key = tOrder[at]
		if ((key in oText) && oText[key] != tText[key] && pickOurs) put(oText[key]); else put(tText[key])
	}
	for (at = 1; at <= nO; at++) { key = oOrder[at]; if (!(key in tText)) put(oText[key]) }
}
function flush(   at, allStamped, hasRule) {
	hasRule = 0
	for (at = 1; at <= nOurs; at++) if (ours[at] == "---") hasRule = 1
	for (at = 1; at <= nTheirs; at++) if (theirs[at] == "---") hasRule = 1
	if (blockFm && !hasRule && (nOurs + nTheirs) > 0) { settleHeader(); nOurs = 0; nTheirs = 0; return }
	if (blockFm && hasRule) fm = 0
	allStamped = 1
	for (at = 1; at <= nOurs; at++) if (ours[at] != "" && !stamped(ours[at])) allStamped = 0
	for (at = 1; at <= nTheirs; at++) if (theirs[at] != "" && !stamped(theirs[at])) allStamped = 0
	if (allStamped && (nOurs + nTheirs) > 0) {
		records = 1
		for (at = 1; at <= nTheirs; at++) put(theirs[at])
		for (at = 1; at <= nOurs; at++) put(ours[at])
	} else {
		for (at = 1; at <= nTheirs; at++) { put(theirs[at]); held[theirs[at]] = 1 }
		for (at = 1; at <= nOurs; at++) if (!(ours[at] in held) || ours[at] == "") put(ours[at])
		delete held
	}
	nOurs = 0; nTheirs = 0
}
function finish(   at, first, last, total, pass, swap) {
	if (!records) { for (at = 1; at <= nOut; at++) print out[at]; return }
	first = 0; last = 0
	for (at = 1; at <= nOut; at++) if (stamped(out[at])) { if (!first) first = at; last = at }
	for (at = 1; at < first; at++) print out[at]
	total = 0
	for (at = first; at <= last; at++) if (stamped(out[at]) && !(out[at] in seen)) { seen[out[at]] = 1; list[++total] = out[at] }
	for (pass = 1; pass < total; pass++) for (at = 1; at <= total - pass; at++) if (list[at] > list[at + 1]) { swap = list[at]; list[at] = list[at + 1]; list[at + 1] = swap }
	for (at = 1; at <= total; at++) print list[at]
	for (at = first; at <= last; at++) if (!stamped(out[at]) && out[at] != "") print out[at]
	for (at = last + 1; at <= nOut; at++) print out[at]
}
/^<<<<<<< ours$/ && state == 0 { state = 1; nOurs = 0; nTheirs = 0; blockFm = (fm == 1); next }
/^\|\|\|\|\|\|\| / && state == 1 { state = 3; next }
/^=======$/ && (state == 1 || state == 3) { state = 2; next }
/^>>>>>>> theirs$/ && state == 2 { flush(); state = 0; next }
state == 1 { ours[++nOurs] = $0; next }
state == 3 { next }
state == 2 { theirs[++nTheirs] = $0; next }
{ if ($0 == "---" && state == 0) { if (NR == 1 || (!fmSeen && nOut == 0)) { fm = 1; fmSeen = 1 } else if (fm == 1) { fm = 0 } }
  put($0) }
END { if (state != 0) exit 1; finish() }
