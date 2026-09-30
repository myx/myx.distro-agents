#!/usr/bin/env awk
# Prints every backtick-quoted op name under a "## DistroAgentsTools magic-tooling operations" heading.
/^## DistroAgentsTools magic-tooling operations/ { inBlock=1; next; }
inBlock && /^## / { inBlock=0; }
inBlock && /^- `--/ {
	## Every backtick-quoted op on the bullet, not just the
	## first. The previous form cut the line at its first
	## closing backtick, so a bullet naming two or more ops
	## yielded only the leading one -- against the real
	## magic-team.armed.md that silently dropped three
	## (--owner-workspace-upsert, --owner-workspace-forget,
	## --magic-heartbeat-state-upsert) from the set a member is
	## told it may use, while members are instructed to execute
	## nothing outside that set. Under-reporting here does not
	## fail loudly; it quietly narrows the mandate a member
	## believes it has.
	line=$0;
	while (match(line, /`--[^`]*`/)) {
		tok = substr(line, RSTART + 1, RLENGTH - 2);
		## Trim any argument spec carried inside the backticks
		## (e.g. `--member-help <team-member>`) -- the op name
		## is the first whitespace-delimited word.
		sub(/[ \t].*$/, "", tok);
		if (tok != "") { print tok; };
		line = substr(line, RSTART + RLENGTH);
	}
}
