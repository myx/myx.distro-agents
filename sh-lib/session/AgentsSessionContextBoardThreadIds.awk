#!/usr/bin/env awk
# Prints one "channel:ts" pair per matched board file that names a Slack thread.
function strip(v) {
	sub(/^[^:]*:[ \t]*/, "", v)
	gsub(/^[ \t]+|[ \t]+$/, "", v)
	gsub(/^"|"$/, "", v)
	return v
}
function flush(   n, f) {
	n = split(val, f, ":")
	if (n == 3 && f[1] == "slack" && f[2] != "" && f[3] != "") { print f[2] ":" f[3]; }
	val = ""
}
FNR == 1 { flush(); }
/^communication-channel-id:/ { val = strip($0); next; }
END { flush(); }
