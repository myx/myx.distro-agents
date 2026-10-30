#!/usr/bin/env bash
## AgentsJsonEscapeUtf8Check -- S21.20, the DeepSeek half: a byte that cannot start or
## continue a valid UTF-8 character reaches AgentsMcpJsonEscape.awk unconverted, so the
## request body it builds carries invalid UTF-8. The provider's own JSON parser then
## refuses the whole request as "invalid unicode code point". The awk must replace each
## such byte with U+FFFD, and must leave every valid multi-byte character untouched.
## Offline by construction: no request, no host, awk and iconv alone.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigAwk="$rigHere/mcp/AgentsMcpJsonEscape.awk"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAwk" ] || rigRefuse "the escape awk is not in the package: $rigAwk"
command -v iconv > /dev/null 2>&1 || rigRefuse "iconv is not on PATH, the UTF-8 validity probe has no instrument"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## $1 valid or invalid UTF-8, through the plain POSIX form: no -o, stdout to /dev/null.
rigUtf8Validity(){
	printf '%s' "$1" | iconv -f UTF-8 -t UTF-8 > /dev/null 2>&1 && printf valid || printf invalid
}
rigEscapeValidity(){ ## raw bytes on $1, through the escape awk, then the same probe
	printf '%s' "$1" | LC_ALL=C awk -f "$rigAwk" | iconv -f UTF-8 -t UTF-8 > /dev/null 2>&1 && printf valid || printf invalid
}
rigEscapeBytes(){ ## raw bytes on $1, through the escape awk, as a hex dump
	printf '%s' "$1" | LC_ALL=C awk -f "$rigAwk" | od -An -tx1 | tr -d ' \n'
}

echo "-- the known positive: a lone continuation byte is invalid UTF-8 on its own --"
rigAssert "the raw byte itself is invalid UTF-8 (the probe can see the defect)" \
	"$( rigUtf8Validity "$( printf '\200' )" )" "invalid"

echo "-- a byte with no valid place in UTF-8 is replaced, not passed through --"
rigAssert "a lone continuation byte (0x80) comes out valid UTF-8" \
	"$( rigEscapeValidity "$( printf 'a\200b' )" )" "valid"
rigAssert "an overlong 2-byte lead (0xC0 0x80) comes out valid UTF-8" \
	"$( rigEscapeValidity "$( printf '\300\200' )" )" "valid"
rigAssert "a 3-byte sequence truncated at end of line comes out valid UTF-8" \
	"$( rigEscapeValidity "$( printf '\342\202' )" )" "valid"
rigAssert "a surrogate-range encoding (U+D800) comes out valid UTF-8" \
	"$( rigEscapeValidity "$( printf '\355\240\200' )" )" "valid"
rigAssert "a byte above the valid lead range (0xFF) comes out valid UTF-8" \
	"$( rigEscapeValidity "$( printf '\377' )" )" "valid"

echo "-- a valid multi-byte character passes through unchanged, not merely valid --"
rigAssert "a valid 2-byte character (e acute) is preserved byte for byte" \
	"$( rigEscapeBytes "$( printf 'caf\303\251' )" )" \
	"$( printf 'caf\303\251' | od -An -tx1 | tr -d ' \n' )"
rigAssert "a valid 4-byte character (U+1F600) is preserved byte for byte" \
	"$( rigEscapeBytes "$( printf '\360\237\230\200' )" )" \
	"$( printf '\360\237\230\200' | od -An -tx1 | tr -d ' \n' )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ JSON ESCAPE UTF-8 CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'JSON_ESCAPE_UTF8: OK (%d assertions, offline)\n' "$rigPassCount"
