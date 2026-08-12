#!/usr/bin/env awk

# Converts epoch seconds (UTC, one per input line, on stdin) to a calendar date
# `YYYY-MM-DD`, printing one date per input line. The exact inverse of
# sh-lib/AgentsIsoToEpoch.awk's own date half, and written for the same reason
# that file states: there is no portable epoch->date via date(1) either.
# BSD spells it `date -r <epoch>`, GNU spells it `date -d @<epoch>`, and POSIX
# specifies neither -- date(1) is standardised only as a reader of the CURRENT
# time. Cross-platform correctness (Darwin/FreeBSD/Linux) is a hard requirement
# in this tree, so the conversion is integer arithmetic here instead: no
# date(1), no gawk strftime() (not POSIX awk), no locale, no $TZ, no timezone
# database. One code path, exercised on every platform by every run.
#
# UTC, always, with no option to ask for anything else. The one caller
# (--member-comms-slack-search-messages, for Slack's `after:` search operator) does not
# need local time and must not silently get it: a local-time answer would shift
# the derived date by a day near midnight depending on the machine's own $TZ,
# which is exactly the kind of environment-dependent boundary that op's
# deliberate one-day over-fetch exists to make harmless.
#
# Civil-from-days is Howard Hinnant's algorithm, the same one AgentsIsoToEpoch
# runs in the forward direction, so a value converted one way and back returns
# the day it started on.
#
# int() truncates toward zero, which equals floor only for non-negative values.
# Every epoch this tree handles is positive; a pre-1970 input is rejected rather
# than silently returning a date one day off.
#
# Exit status:
#   rc 0  every input line converted; the dates are on stdout.
#   rc 1  a line was not a non-negative integer number of seconds. Says so on
#         stderr and prints nothing for that line, rather than emitting a
#         plausible-looking wrong date.

function civilFromDays(z,   era, doe, yoe, y, doy, mp, d, m) {
	z += 719468
	era = int(z / 146097)
	doe = z - era * 146097
	yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
	y = yoe + era * 400
	doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
	mp = int((5 * doy + 2) / 153)
	d = doy - int((153 * mp + 2) / 5) + 1
	m = mp + (mp < 10 ? 3 : -9)
	if (m <= 2) y = y + 1
	return sprintf("%04d-%02d-%02d", y, m, d)
}

{
	value = $0
	## A fractional Slack ts (`1786394109.813549`) is a legitimate input here --
	## the seconds part is all that a calendar date depends on, so it is taken
	## and the fraction dropped. Anything else is refused.
	sub(/\.[0-9]*$/, "", value)
	if (value !~ /^[0-9]+$/) {
		printf("⛔ ERROR: AgentsEpochToIsoDate.awk: not a non-negative epoch-seconds value: %s\n", $0) > "/dev/stderr"
		bad = 1
		next
	}
	print civilFromDays(int(value / 86400))
}

END { if (bad) exit 1 }
