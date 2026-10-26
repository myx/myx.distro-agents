#!/usr/bin/env awk
# Reads ONE routine file once and prints, one record a line, the frontmatter facts and
# root-heading facts AgentsToolsDocValidateRoutine asks. Each record is separated by the
# file-separator character \034 (a value can be empty, so a blank field must survive):
#   K  <key>  <raw value>  <trimmed value>  <line of the first `key: ` line>
#   I  <included routine name>  <section>
#   W  <wait-sources line>
#   S  <input-scan-def line>  <line of the first line equal to `input-scan-def: <line>`>
#   H  <count>  <first line>  <heading>
# An absent key's line is 0; an input-scan-def line no line equals exactly has line 0; a
# heading that is not there has count 0 and first line 0. The raw value is what
# AgentsBoardItemFrontmatterPrintSelected.awk reads (the first non-empty value, untrimmed);
# the trimmed value is the raw value with leading and trailing blanks off.

BEGIN {
	nk = split("type\034requires-session-kind\034executors\034maintainers\034invitees\034tracking-item\034start-context\034review-by\034cache-prefix\034allows\034operations\034routine-lock-document\034runs-at\034runs-after\034includes\034wait-sources", keyOrder, "\034")
	for (i = 1 ; i <= nk ; i++) keyWant[keyOrder[i]] = 1
	nh = split("Opening steps\034Steps\034Closure steps\034Routine's local procedures", headOrder, "\034")
	for (i = 1 ; i <= nh ; i++) headWant[headOrder[i]] = 1
}

NR == 1 && $0 == "---" { inFront = 1 ; next }
inFront && $0 == "---" { inFront = 0 ; next }

inFront {
	pos = index($0, ": ")
	if (pos > 0) {
		key = substr($0, 1, pos - 1)
		if (key in keyWant) {
			if (keyLine[key] == 0) keyLine[key] = NR
			if (keyRaw[key] == "") keyRaw[key] = substr($0, pos + 2)
		}
	}
	if (index($0, "includes: ") == 1) {
		rest = substr($0, 11)
		colon = index(rest, ": ")
		if (colon > 0) {
			incName = substr(rest, 1, colon - 1)
			tail = substr(rest, colon + 2)
			m = split(tail, parts, ",")
			for (j = 1 ; j <= m ; j++) {
				part = parts[j]
				gsub(/^[ \t]+|[ \t]+$/, "", part)
				if (part != "") { incNameBuf[++incN] = incName ; incSectionBuf[incN] = part }
			}
		}
	}
	if (index($0, "wait-sources: ") == 1) {
		w = substr($0, length("wait-sources: ") + 1)
		gsub(/^[ \t]+|[ \t]+$/, "", w)
		if (w != "") waitBuf[++waitN] = w
	}
	if (index($0, "input-scan-def: ") == 1) {
		raw = substr($0, length("input-scan-def: ") + 1)
		val = raw
		gsub(/^[ \t]+|[ \t]+$/, "", val)
		if (val != "") {
			scanValBuf[++scanN] = val
			scanExactBuf[scanN] = ( raw == val ) ? NR : 0
		}
	}
	next
}

# Outside the frontmatter: the root headings, outside code fences.
$0 ~ /^```/ { fence = !fence ; next }
!fence && substr($0, 1, 2) == "# " {
	heading = substr($0, 3)
	if (heading in headWant) {
		if (headCount[heading] == 0) headFirst[heading] = NR
		headCount[heading]++
	}
}

END {
	for (i = 1 ; i <= nk ; i++) {
		key = keyOrder[i]
		trimmed = keyRaw[key]
		gsub(/^[ \t]+|[ \t]+$/, "", trimmed)
		printf "K\034%s\034%s\034%s\034%d\n", key, keyRaw[key], trimmed, ( keyLine[key] == 0 ? 1 : keyLine[key] )
	}
	for (i = 1 ; i <= incN ; i++) printf "I\034%s\034%s\n", incNameBuf[i], incSectionBuf[i]
	for (i = 1 ; i <= waitN ; i++) printf "W\034%s\n", waitBuf[i]
	# The first line whose whole text equals `input-scan-def: <value>`, per value.
	for (i = 1 ; i <= scanN ; i++) {
		val = scanValBuf[i]
		if (scanExactBuf[i] != 0 && !(val in firstExact)) firstExact[val] = scanExactBuf[i]
	}
	for (i = 1 ; i <= scanN ; i++) {
		val = scanValBuf[i]
		printf "S\034%s\034%d\n", val, ( val in firstExact ? firstExact[val] : 1 )
	}
	for (i = 1 ; i <= nh ; i++) {
		heading = headOrder[i]
		printf "H\034%d\034%d\034%s\n", headCount[heading], headFirst[heading], heading
	}
}
