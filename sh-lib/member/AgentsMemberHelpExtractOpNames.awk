#!/usr/bin/env awk
# Prints every backtick-quoted op name under a "## DistroAgentsTools magic-tooling operations" heading.
/^## DistroAgentsTools magic-tooling operations/ { inBlock=1; next; }
inBlock && /^## / { inBlock=0; }
inBlock && /^- `--/ {
	## Every backtick-quoted op on the bullet is read, not just the first.
	line=$0;
	while (match(line, /`--[^`]*`/)) {
		tok = substr(line, RSTART + 1, RLENGTH - 2);
		## Trim any argument spec inside the backticks (e.g. --member-help <team-member>) -- the op name is the first whitespace-delimited word.
		sub(/[ \t].*$/, "", tok);
		if (tok != "") { print tok; };
		line = substr(line, RSTART + RLENGTH);
	}
}
