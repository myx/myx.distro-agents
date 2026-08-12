#!/usr/bin/env awk

# Converts an ISO-8601 date-time (one per input line, on stdin) to epoch
# seconds (UTC), printing one number per input line.
#
# WHY THIS EXISTS AT ALL, rather than a date(1) call: there is no portable
# ISO->epoch via date(1), and that is not a difficulty -- it is impossible.
# POSIX specifies date only as a reader of the CURRENT time
# (`date [-u] [+format]`); parsing an arbitrary input date is not in the
# standard. GNU's `-d` and BSD's `-j -f` are both extensions to a spec with no
# such feature, so there is no common subset to write to. Cross-platform
# correctness (Darwin/FreeBSD/Linux) is a hard requirement in this tree, so the
# conversion is done here in pure integer arithmetic instead: no date(1), no
# gawk mktime() (not POSIX awk, and it interprets its argument in LOCAL time
# even where present), no locale, no $TZ, no timezone database. One code path,
# exercised on every platform by every run.
#
# Accepts `YYYY-MM-DDTHH:MM:SS`, `YYYY-MM-DD HH:MM:SS`, and truncations of
# either (a bare `YYYY-MM-DD` reads as 00:00:00), with an optional trailing
# `Z`, `+-HH:MM` or `+-HHMM` offset. Anything with no offset is read as UTC.
#
# Input is expected to be already shape-checked by its caller against
# `[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]*` -- the field extraction below
# is fixed-position and assumes zero-padded ISO-8601. A line that does not
# match that shape is reported on stderr and exits 1 rather than yielding a
# plausible-looking wrong number.
#
# int() truncates toward zero, which equals floor only for y >= 0. Fine for any
# real date; a negative year would need a floor helper first.

function isoToEpoch(s,   y, mo, d, h, mi, sec, n, c, sign, off, era, yoe, doy, doe, days) {
	y   = substr(s, 1, 4)  + 0
	mo  = substr(s, 6, 2)  + 0
	d   = substr(s, 9, 2)  + 0
	h   = substr(s, 12, 2) + 0
	mi  = substr(s, 15, 2) + 0
	sec = substr(s, 18, 2) + 0

	## An offset sign is only an offset sign when it sits INSIDE the time part,
	## i.e. at position 12 or later (past `YYYY-MM-DDT`). Without that guard a
	## bare `YYYY-MM-DD` reads its own month/day separator as a `-HH:MM`
	## offset -- measured: `2026-08-09` came back 29340 seconds off, a
	## plausible-looking number with no error anywhere.
	off = 0
	n = length(s)
	c = substr(s, n - 5, 1)
	if ((c == "+" || c == "-") && n - 5 >= 12) {      ## +-HH:MM
		sign = (c == "-") ? -1 : 1
		off  = sign * (substr(s, n - 4, 2) * 3600 + substr(s, n - 1, 2) * 60)
	} else {
		c = substr(s, n - 4, 1)
		if ((c == "+" || c == "-") && n - 4 >= 12) {  ## +-HHMM
			sign = (c == "-") ? -1 : 1
			off  = sign * (substr(s, n - 3, 2) * 3600 + substr(s, n - 1, 2) * 60)
		}
	}

	if (mo <= 2) { y = y - 1; }
	era  = int(y / 400)
	yoe  = y - era * 400
	doy  = int((153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5) + d - 1
	doe  = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
	days = era * 146097 + doe - 719468

	return days * 86400 + h * 3600 + mi * 60 + sec - off
}

{
	if ($0 !~ /^[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]/) {
		printf("⛔ ERROR: AgentsIsoToEpoch.awk: not an ISO-8601 date-time: %s\n", $0) > "/dev/stderr"
		exit 1
	}
	print isoToEpoch($0)
}
