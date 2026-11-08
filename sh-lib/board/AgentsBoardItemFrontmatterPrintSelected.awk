#!/usr/bin/env awk
# Prints a caller-chosen, ordered subset of a board item's frontmatter keys; with -v title=1, led by the body's first heading as `title:`.
# A key the item lacks is left out: an empty value tells the reader nothing and costs every scan a line.
# THE TITLE IS OPT-IN: AgentsToolsRoutineKeyOwn (AgentsTools.RoutineRequirements.include) reads one key of a routine file through this program and takes
# the value off the one line it prints, so a line it did not ask for breaks every routine start. Only a caller that lists items asks for the title.
BEGIN {
	withTitle = ( title + 0 == 1 ) ; title = ""
	n = split(headers, order, "\034")
	for (i = 1; i <= n; i++) {
		vals[order[i]] = ""
		fallback[order[i]] = ""
	}
}
!seen_fm && $0 == "---" {
	seen_fm = 1
	in_fm = 1
	next
}
in_fm && $0 == "---" {
	in_fm = 0
	closed_fm = 1
	next
}
closed_fm {
	if (title == "" && substr($0, 1, 2) == "# ") title = substr($0, 3)
	next
}
{
	pos = index($0, ": ")
	if (pos > 0) {
		key = substr($0, 1, pos - 1)
		if (key in vals) {
			if (in_fm) {
				if (vals[key] == "") vals[key] = substr($0, pos + 2)
			} else {
				if (fallback[key] == "") fallback[key] = substr($0, pos + 2)
			}
		}
	}
}
END {
	if (title != "" && withTitle) printf "title: %s\n", title
	for (i = 1; i <= n; i++) {
		key = order[i]
		val = vals[key]
		if (!seen_fm && val == "") val = fallback[key]
		if (val != "") printf "%s: %s\n", key, val
	}
}
