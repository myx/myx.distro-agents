#!/usr/bin/env awk
## Which events of one comms source a reader must be handed (S1.12 stage 2, item 12). Reads one source's `YYYYMM/events.txt`, the
## file argument, and prints:
##   MSG <TAB> <event id> <TAB> <message id> <TAB> <channel> <TAB> <the message's own minute, YYYYMMDD'T'HHmm'Z'> <TAB> <text>
##   LAST <TAB> <the greatest event id in the file>
## A message qualifies when its event sorts after the pointer, its kind is `msg` or `edit`, its author is not the reader, and either
## the source is a direct conversation the reader is party to or its text carries `<@the reader's id>`. The tag is tested on the raw
## column, before any escape is undone, because Slack's own text holds it as `<@U…>`.
## -v target is the source's own target, `<channel>:<ts>` or `D…`. -v dir names the month folder a long body's file sits in.
## THE TEXT IS PRINTED STILL ESCAPED, as the store keeps it: `\037` a newline, `\036` a TAB. One event is one physical line here, so
## the caller reads it whole by a line, and it is the caller that undoes the escapes where a body is written. LC_ALL=C.

function stamp(ts,   ms, dayCount, secOfDay, eraValue, dayOfEra, yearOfEra, yearValue, dayOfYear, monthPrime, dayValue, monthValue) {
	ms = int(ts * 1000)
	dayCount = int(ms / 86400000) + 719468
	secOfDay = int((ms % 86400000) / 1000)
	eraValue = int(dayCount / 146097)
	dayOfEra = dayCount - eraValue * 146097
	yearOfEra = int((dayOfEra - int(dayOfEra / 1460) + int(dayOfEra / 36524) - int(dayOfEra / 146096)) / 365)
	yearValue = yearOfEra + eraValue * 400
	dayOfYear = dayOfEra - (365 * yearOfEra + int(yearOfEra / 4) - int(yearOfEra / 100))
	monthPrime = int((5 * dayOfYear + 2) / 153)
	dayValue = dayOfYear - int((153 * monthPrime + 2) / 5) + 1
	monthValue = monthPrime < 10 ? monthPrime + 3 : monthPrime - 9
	if (monthValue <= 2) yearValue++
	return sprintf("%04d%02d%02dT%02d%02dZ", yearValue, monthValue, dayValue, int(secOfDay / 3600), int((secOfDay % 3600) / 60))
}

function esc(value) {
	gsub(/\r/, "", value)
	gsub(/\t/, "\\036", value)
	gsub(/\n/, "\\037", value)
	return value
}

BEGIN {
	FS = "\t"
	channel = target
	sub(/:.*/, "", channel)
	direct = (target ~ /^D/)
	greatest = ""
}

NF < 16 { next }

{
	if (greatest == "" || $1 > greatest) greatest = $1
	if ($1 <= pointer) next
	if ($2 != "msg" && $2 != "edit") next
	if ($4 == myId) next
	text = $7
	if ($16 != "") {
		text = ""
		while ((getline one < (dir "/" $16)) > 0) text = (text == "" ? one : text "\n" one)
		close(dir "/" $16)
		text = esc(text)
	}
	if (!direct && index(text, "<@" myId ">") == 0) next
	printf "MSG\t%s\t%s\t%s\t%s\t%s\n", $1, $3, channel, stamp($3), text
}

END {
	if (greatest != "") printf "LAST\t%s\n", greatest
}
