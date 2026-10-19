#!/usr/bin/env awk
# Prints a caller-chosen, ordered subset of a board item's frontmatter keys.
BEGIN {
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
closed_fm { next ; }
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
	for (i = 1; i <= n; i++) {
		key = order[i]
		val = vals[key]
		if (!seen_fm && val == "") val = fallback[key]
		printf "%s: %s\n", key, val
	}
}
