#!/usr/bin/env awk

# Slack's date format, the one implementation for every date or time the tooling itself
# writes into text it sends to Slack:
#   <!date^<epoch seconds>^<token string>|<fallback text>>
# Slack shows it in the timezone of each reader's own device. A client that cannot render
# it shows the fallback, which is the same moment as UTC text, with UTC in it. It is a
# control sequence: it works only unescaped, outside a code span or a code block, and in
# mrkdwn text. In a rich_text block the same moment is a `date` element, which
# AgentsSlackBlocksBuild.awk makes from this token. Run under LC_ALL=C.
#
# A LIBRARY FIRST. Every function is prefixed sld, so it loads beside another program
# (awk -f AgentsSlackDate.awk -f AgentsEventTrackPostFill.awk) without a name clash, and
# its own rules run only in standalone mode:
#   sldStandalone=token     stdin is one `<moment><TAB><style>` per line; prints the token
#                           of each. A moment or a style it cannot read prints nothing
#                           and exits 1, never a plausible wrong date.
#   sldStandalone=fallback  stdin is a text; prints it with every date token as its
#                           fallback text.
# The shell wrapper is AgentsToolsSlackDateToken (AgentsTools.SlackDate.include).
#
# A moment is epoch seconds (a Slack ts loses its fraction), or a date-time as this tree
# writes one: `YYYY-MM-DDTHH:MM:SSZ`, `YYYY-MM-DD HH:MM +HHMM`, a truncation of either
# (a bare date is 00:00:00), its offset `Z`, `+-HH:MM` or `+-HHMM` and none read as UTC;
# or the name form `YYYYMMDDTHHMM[SS]Z`. Integer arithmetic only, the rule and the reason
# of AgentsIsoToEpoch.awk and AgentsEpochToIsoDate.awk: no date(1), no strftime, no $TZ.
#
# A style keeps what its site showed before it was a token:
#   time-secs       {time_secs}             fallback 06:02:30 UTC
#   time            {time}                  fallback 06:02 UTC
#   date-time       {date_num} {time}       fallback 2026-10-09 05:10 UTC
#   date-time-secs  {date_num} {time_secs}  fallback 2026-10-09 05:10:42 UTC
#   date            {date_num}              fallback 2026-10-09 UTC
# A range is two tokens with the site's own separator between them. No label follows a
# token: the reader sees local time, and the fallback says UTC itself.

# The token string of a style; "" for a style there is none for.
function sldFormat(styleName) {
	if (styleName == "time-secs") return "{time_secs}"
	if (styleName == "time") return "{time}"
	if (styleName == "date-time") return "{date_num} {time}"
	if (styleName == "date-time-secs") return "{date_num} {time_secs}"
	if (styleName == "date") return "{date_num}"
	return ""
}

# Days from 1970-01-01 to a civil date (days-from-civil, as AgentsIsoToEpoch.awk).
function sldDays(yearValue, monthValue, dayValue,   eraValue, yearOfEra, dayOfYear, dayOfEra) {
	if (monthValue <= 2) yearValue = yearValue - 1
	eraValue = int(yearValue / 400)
	yearOfEra = yearValue - eraValue * 400
	dayOfYear = int((153 * (monthValue + (monthValue > 2 ? -3 : 9)) + 2) / 5) + dayValue - 1
	dayOfEra = yearOfEra * 365 + int(yearOfEra / 4) - int(yearOfEra / 100) + dayOfYear
	return eraValue * 146097 + dayOfEra - 719468
}

# A moment as epoch seconds; "" for a text that is not a moment.
function sldEpoch(momentText,   restText, hourValue, minuteValue, secondValue, offsetText, offsetSign, offsetSeconds) {
	sub(/^[ \t]+/, "", momentText)
	sub(/[ \t]+$/, "", momentText)
	if (momentText ~ /^[0-9]+(\.[0-9]*)?$/) {
		sub(/\..*$/, "", momentText)
		return momentText + 0
	}
	if (momentText ~ /^[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9]([0-5][0-9])?Z$/) {
		secondValue = (length(momentText) == 16) ? substr(momentText, 14, 2) + 0 : 0
		return sldDays(substr(momentText, 1, 4) + 0, substr(momentText, 5, 2) + 0, substr(momentText, 7, 2) + 0) * 86400 + substr(momentText, 10, 2) * 3600 + substr(momentText, 12, 2) * 60 + secondValue
	}
	if (momentText !~ /^[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]/) return ""
	restText = substr(momentText, 11)
	if (restText !~ /^([T ][0-2][0-9](:[0-5][0-9](:[0-5][0-9])?)?)?[ ]?(Z|[+-][0-9][0-9]:?[0-9][0-9])?$/) return ""
	hourValue = 0 ; minuteValue = 0 ; secondValue = 0
	if (restText ~ /^[T ][0-2][0-9]/) hourValue = substr(restText, 2, 2) + 0
	if (restText ~ /^[T ][0-2][0-9]:[0-5][0-9]/) minuteValue = substr(restText, 5, 2) + 0
	if (restText ~ /^[T ][0-2][0-9]:[0-5][0-9]:[0-5][0-9]/) secondValue = substr(restText, 8, 2) + 0
	offsetSeconds = 0
	if (match(restText, /[+-][0-9][0-9]:?[0-9][0-9]$/)) {
		offsetText = substr(restText, RSTART)
		offsetSign = (substr(offsetText, 1, 1) == "-") ? -1 : 1
		gsub(/[^0-9]/, "", offsetText)
		offsetSeconds = offsetSign * (substr(offsetText, 1, 2) * 3600 + substr(offsetText, 3, 2) * 60)
	}
	return sldDays(substr(momentText, 1, 4) + 0, substr(momentText, 6, 2) + 0, substr(momentText, 9, 2) + 0) * 86400 + hourValue * 3600 + minuteValue * 60 + secondValue - offsetSeconds
}

# Epoch seconds as the UTC text of a style, the fallback of its token (civil-from-days,
# as AgentsEpochToIsoDate.awk); "" for a style there is none for.
function sldUtc(epochSeconds, styleName,   dayCount, secOfDay, eraValue, dayOfEra, yearOfEra, yearValue, dayOfYear, monthPrime, dayValue, monthValue, dateText, minuteText, secondText) {
	epochSeconds = int(epochSeconds)
	dayCount = int(epochSeconds / 86400)
	secOfDay = epochSeconds - dayCount * 86400
	dayCount += 719468
	eraValue = int(dayCount / 146097)
	dayOfEra = dayCount - eraValue * 146097
	yearOfEra = int((dayOfEra - int(dayOfEra / 1460) + int(dayOfEra / 36524) - int(dayOfEra / 146096)) / 365)
	yearValue = yearOfEra + eraValue * 400
	dayOfYear = dayOfEra - (365 * yearOfEra + int(yearOfEra / 4) - int(yearOfEra / 100))
	monthPrime = int((5 * dayOfYear + 2) / 153)
	dayValue = dayOfYear - int((153 * monthPrime + 2) / 5) + 1
	monthValue = monthPrime < 10 ? monthPrime + 3 : monthPrime - 9
	if (monthValue <= 2) yearValue++
	dateText = sprintf("%04d-%02d-%02d", yearValue, monthValue, dayValue)
	minuteText = sprintf("%02d:%02d", int(secOfDay / 3600), int((secOfDay % 3600) / 60))
	secondText = minuteText sprintf(":%02d", secOfDay % 60)
	if (styleName == "time-secs") return secondText " UTC"
	if (styleName == "time") return minuteText " UTC"
	if (styleName == "date-time") return dateText " " minuteText " UTC"
	if (styleName == "date-time-secs") return dateText " " secondText " UTC"
	if (styleName == "date") return dateText " UTC"
	return ""
}

# The date token of a moment with a token string of the caller's own, such as
# `{date_short_pretty} at {time}` or `{ago}`, and the fallback of a style; "" when the moment
# or the style cannot be read, or the token string is empty or holds a character that would
# end the token (`^`, `|`, `<`, `>`), so a caller keeps the text it had.
function sldTokenAs(momentText, formatText, styleName,   epochSeconds, utcText) {
	epochSeconds = sldEpoch(momentText)
	if (epochSeconds == "" || epochSeconds < 0) return ""
	utcText = sldUtc(epochSeconds, styleName)
	if (utcText == "" || formatText == "" || formatText ~ /[|^<>]/) return ""
	return "<!date^" sprintf("%d", epochSeconds) "^" formatText "|" utcText ">"
}

# The date token of a moment in a style; "" when either cannot be read, so a caller keeps
# the text it had.
function sldToken(momentText, styleName) {
	return sldTokenAs(momentText, sldFormat(styleName), styleName)
}

# A text with every date token in it as its fallback text: how a message read back from
# Slack shows one, to an agent or a scan. Any token Slack takes, a link in it too.
function sldFallbacks(textValue,   outText, tokenText, barAt) {
	outText = ""
	while (match(textValue, /<!date\^[0-9]+\^[^|>]*\|[^>]*>/)) {
		tokenText = substr(textValue, RSTART, RLENGTH)
		outText = outText substr(textValue, 1, RSTART - 1)
		textValue = substr(textValue, RSTART + RLENGTH)
		barAt = index(tokenText, "|")
		outText = outText substr(tokenText, barAt + 1, length(tokenText) - barAt - 1)
	}
	return outText textValue
}

# A text whose Slack control characters were escaped as entities, with each date token of
# sldToken's own making back as the control sequence, so a renderer that escapes a value
# still sends its date as one. Only that exact shape is restored: digits, one of the
# token strings above, a fallback of digits, `-`, `:` and spaces ending in UTC, and no
# link. Anything else stays escaped, so no value can make a token of its own.
function sldKeep(textValue,   outText, tokenText, formatText) {
	outText = ""
	while (match(textValue, /&lt;!date\^[0-9]+\^[^|^&<>]+\|[0-9: -]+ UTC&gt;/)) {
		tokenText = substr(textValue, RSTART + 4, RLENGTH - 8)
		outText = outText substr(textValue, 1, RSTART - 1)
		textValue = substr(textValue, RSTART + RLENGTH)
		formatText = substr(tokenText, 1, index(tokenText, "|") - 1)
		sub(/^!date\^[0-9]+\^/, "", formatText)
		if (formatText == "{time_secs}" || formatText == "{time}" || formatText == "{date_num} {time}" || formatText == "{date_num} {time_secs}" || formatText == "{date_num}") outText = outText "<" tokenText ">"
		else outText = outText "&lt;" tokenText "&gt;"
	}
	return outText textValue
}

# How many bytes of a text to keep when it is cut at capBytes, so that no date token is
# cut in two: capBytes, or the bytes before the token capBytes falls inside.
function sldCutAt(textValue, capBytes,   doneBytes, tokenStart, tokenEnd) {
	doneBytes = 0
	while (match(textValue, /<!date\^[0-9]+\^[^|>]*\|[^>]*>/)) {
		tokenStart = doneBytes + RSTART
		tokenEnd = tokenStart + RLENGTH - 1
		if (tokenStart > capBytes) break
		if (tokenEnd > capBytes) return tokenStart - 1
		doneBytes = tokenEnd
		textValue = substr(textValue, RSTART + RLENGTH)
	}
	return capBytes
}

sldStandalone == "token" {
	sldTabAt = index($0, "\t")
	sldOne = (sldTabAt > 0) ? sldToken(substr($0, 1, sldTabAt - 1), substr($0, sldTabAt + 1)) : ""
	if (sldOne == "") exit 1
	print sldOne
	next
}

sldStandalone == "fallback" {
	print sldFallbacks($0)
	next
}
