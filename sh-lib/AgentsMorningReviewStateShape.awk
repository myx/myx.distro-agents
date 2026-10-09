#!/usr/bin/env awk
# The state-shape sample of --intern-op-morning-review-input-scan: board items
# whose own headers contradict the state folder they sit in. Each argument is a
# board item path, <...>/board/<state>/<item>.md. Only the frontmatter is read,
# never a body: each file is read with getline up to its closing `---`.
#
#   -v cap=<n>         samples printed per rule (default 3)
#   -v width=<n>       a header value is cut to this many characters (default 100)
#   -v endedFile=<p>   optional: one session-id per line, sessions the
#                      spawned-sessions registry knows and holds none live
#
# Rules, one line each `<rule>: <n>`, then `(capped, <cap> shown)` when n > cap:
#   blocked-no-blocker         blocked, no `condition` and no `blocked-by`
#   parked-no-recheck-date     parked, no `recheck-date`
#   running-session-ended      running, `session-id` names an ended session
#   review-no-review-by        review, no `review-by`
#   processed-no-processed-at  processed, no `processed-at`
# A file with no frontmatter carries none of these headers and counts as such.
BEGIN {
	if (cap == "") cap = 3
	if (width == "") width = 100
	nRules = split("blocked-no-blocker parked-no-recheck-date running-session-ended review-no-review-by processed-no-processed-at", rules, " ")
	nKeys = split("type status condition blocked-by recheck-date review-by session-id processed-at", keys, " ")
	if (endedFile != "") {
		while ((getline line < endedFile) > 0) { if (line != "") ended[line] = 1 }
		close(endedFile)
	}
	for (a = 1; a < ARGC; a++) {
		path = ARGV[a]
		n = split(path, parts, "/")
		if (n < 2) continue
		item = parts[n] ; state = parts[n - 1]
		split("", h) ; hasFm = 0 ; inFm = 0 ; lineNo = 0
		while ((getline line < path) > 0) {
			lineNo++
			sub(/\r$/, "", line)
			if (lineNo == 1) { if (line == "---") { inFm = 1 ; hasFm = 1 ; continue } else break }
			if (line == "---") break
			k = line ; sub(/:.*/, "", k)
			if (k == line || k ~ /[ \t]/) continue
			v = line ; sub(/^[^:]*:[ \t]*/, "", v)
			if (!(k in h)) h[k] = v
		}
		close(path)
		rule = ""
		if (state == "blocked" && !("condition" in h) && !("blocked-by" in h)) rule = "blocked-no-blocker"
		else if (state == "parked" && !("recheck-date" in h)) rule = "parked-no-recheck-date"
		else if (state == "running" && ("session-id" in h) && (h["session-id"] in ended)) rule = "running-session-ended"
		else if (state == "review" && !("review-by" in h)) rule = "review-no-review-by"
		else if (state == "processed" && !("processed-at" in h)) rule = "processed-no-processed-at"
		if (rule == "") continue
		count[rule]++
		if (count[rule] > cap) continue
		text = "  " state "/" item "\n"
		if (!hasFm) text = text "    (no frontmatter)\n"
		for (i = 1; i <= nKeys; i++) {
			if (!(keys[i] in h)) continue
			v = h[keys[i]]
			if (length(v) > width) v = substr(v, 1, width) "..."
			text = text "    " keys[i] ": " v "\n"
		}
		sample[rule] = sample[rule] text
	}
	for (r = 1; r <= nRules; r++) {
		rule = rules[r]
		c = count[rule] + 0
		printf "%s: %d%s\n", rule, c, (c > cap) ? " (capped, " cap " shown)" : ""
		if (c > 0) printf "%s", sample[rule]
	}
	exit 0
}
