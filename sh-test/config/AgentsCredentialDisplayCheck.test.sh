#!/usr/bin/env bash
## Behavioural check on the credential display form (F11.8 of the refactorings epic), on the surface the console's
## Configuration reads, `--manager-config-digest`: a credential is shown as the first 25 percent of its value, not
## less than 4 characters and not more than 20, every following character replaced by `*`, even for a long key.
## A quarter rounds down (open-names 56: the simplest form); most values are chosen so 25 percent is a whole number,
## and two are not, to hold the rounding. F11.8 replaces "A secret is
## never printed" (AgentsTools.ManagerConfig.include:18); AgentsCredentialExposureCheck and AgentsManagerConfigDigestCheck
## are reconciled in the same feature. The other printing surfaces are the builder's to enumerate first, and join here.
## Held, for credentials of the workspace scope, each a key the tooling knows as one:
##   1. 16 characters: the first 4, then 12 `*`
##   2. 40 characters: the first 10, then 30 `*`
##   3. 100 characters: the first 20 (the cap), then 80 `*`
##   4. 8 characters: the first 4 (the floor), then 4 `*`
##   5. 1700 characters, a long key: the first 20, then 1680 `*`
##   5b. a quarter that is no whole number rounds down: 18 characters show 4, 30 characters show 7
##   6. where a CLI's own line names the same credential, it shows the same form
##   7. a value of fewer than 4 characters is all `*`: 2 characters read `**`, 3 read `***`
##   8. a password inside a URL, under a key that is no credential: in the digest in full, which the settings views of
##      the console read, only its password part is masked in the same form and the line reads secret-set, the rest of
##      the URL, and a second URL beside it, standing as they are; in the digest not in full the mask is per key, the key
##      is none, and the value stands as it is
##   9. guard: no whole value, and nothing of a value past its shown head, appears on either stream
## Red before F11.8: every credential's value reads `-` (1 to 8 fail; 9 holds).
## The values start their filler letters at an offset of their own, so that the head one value shows is
## never the tail another value hides (guard 9).
## Offline: the rig workspace alone; a curl stand-in that fails.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsCredentialDisplayCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills" "$rigTmp/bin"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl" ; chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigValue(){ ## a head, a length, an offset -- that many characters: the head, then letters and digits that are the rig's own, from that place of them
	perl -e 'my ( $head, $length, $offset ) = @ARGV ; my $text = $head ; my $n = $offset ; while ( length( $text ) < $length ) { $text .= substr( "qwertzuiopasdfghjklyxcvbnm0123456789QWERTZUIOPASDFGHJKLYXCVBNM", $n++ % 62, 1 ) } print substr( $text, 0, $length )' "$1" "$2" "$3"
}
rigMask(){ ## value -- the F11.8 form: the first quarter, 4 to 20 characters, then a `*` for each character after it
	local maskValue="$1" maskLength maskShown
	maskLength="${#maskValue}"
	maskShown=$(( maskLength / 4 ))
	[ "$maskShown" -ge 4 ] || maskShown=4
	[ "$maskShown" -le 20 ] || maskShown=20
	printf '%s' "${maskValue:0:$maskShown}"
	[ "$maskLength" -le "$maskShown" ] || printf '%*s' $(( maskLength - maskShown )) '' | LC_ALL=C tr ' ' '*'
}
rigSlack="$( rigValue xoxbRIGa 16 0 )"
rigJira="$( rigValue jiraRIGb 40 9 )"
rigAnthropic="$( rigValue skantRIGc 100 18 )"
rigXai="$( rigValue xaiRIGd 8 27 )"
rigOauth="$( rigValue oauthRIGe 1700 36 )"
rigCopilot="$( rigValue copRIGf 18 45 )"
rigSlackApp="$( rigValue xappRIGg 30 54 )"
rigUrlPassword="$( rigValue urlpwRIGh 40 5 )"
{
	printf 'SLACK_BOT_TOKEN=%s\n' "$rigSlack"
	printf 'JIRA_API_TOKEN=%s\n' "$rigJira"
	printf 'ANTHROPIC_API_KEY=%s\n' "$rigAnthropic"
	printf 'XAI_API_KEY=%s\n' "$rigXai"
	printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$rigOauth"
	printf 'COPILOT_GITHUB_TOKEN=%s\n' "$rigCopilot"
	printf 'SLACK_APP_TOKEN=%s\n' "$rigSlackApp"
	printf 'SCALEWAY_DEEPSEEK=ab\n'
	printf 'SCALEWAY_GEMMA=xyz\n'
	printf 'WEB_ALLOW_PREFIXES=https://rigbot:%s@docs.rig.example/api/ https://plain.rig.example/\n' "$rigUrlPassword"
	printf 'SPAWN_CLI_SERVICE=claude\n'
} > "$rigWs/.local/.agents/magic-team.agent.env"
( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" --manager-config-digest ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" --manager-config-digest --full ) > "$rigTmp/out.full" 2> "$rigTmp/err.full" < /dev/null
rigShown(){ ## subject, group, key -- the value field of that line, `absent` where no such line; in the digest in full where rigFull is set
	LC_ALL=C awk -F'\t' -v wantSubject="$1" -v wantGroup="$2" -v wantKey="$3" '$1 == "line" && $2 == wantSubject && $3 == wantGroup && $4 == wantKey { print $6 ; found = 1 ; exit } END { if ( !found ) print "absent" }' "$rigTmp/out${rigFull:+.full}"
}

echo "-- control: the digest lists each credential of the scope --"
rigAssert "the five lines are there"                            "$( for rigKey in SLACK_BOT_TOKEN JIRA_API_TOKEN ANTHROPIC_API_KEY XAI_API_KEY CLAUDE_CODE_OAUTH_TOKEN ; do [ "$( rigShown scopes magic-team "$rigKey" )" = absent ] && printf ' %s' "$rigKey" ; done ; printf '.' )" "."

echo "-- 1 to 5. the form, by length --"
rigAssert "16 characters: 4 shown, 12 *"                         "$( rigShown scopes magic-team SLACK_BOT_TOKEN )" "$( rigMask "$rigSlack" )"
rigAssert "40 characters: 10 shown, 30 *"                        "$( rigShown scopes magic-team JIRA_API_TOKEN )" "$( rigMask "$rigJira" )"
rigAssert "100 characters: 20 shown (the cap), 80 *"             "$( rigShown scopes magic-team ANTHROPIC_API_KEY )" "$( rigMask "$rigAnthropic" )"
rigAssert "8 characters: 4 shown (the floor), 4 *"               "$( rigShown scopes magic-team XAI_API_KEY )" "$( rigMask "$rigXai" )"
rigAssert "1700 characters: 20 shown, 1680 *"                    "$( rigShown scopes magic-team CLAUDE_CODE_OAUTH_TOKEN | LC_ALL=C cksum )" "$( { rigMask "$rigOauth" ; echo ; } | LC_ALL=C cksum )"

rigAssert "18 characters: a quarter is 4.5, so 4 shown, 14 *"     "$( rigShown scopes magic-team COPILOT_GITHUB_TOKEN )" "${rigCopilot:0:4}**************"
rigAssert "30 characters: a quarter is 7.5, so 7 shown, 23 *"     "$( rigShown scopes magic-team SLACK_APP_TOKEN )" "${rigSlackApp:0:7}***********************"

echo "-- 6. a CLI's own line shows the same form --"
rigAssert "claude's ANTHROPIC_API_KEY and grok's XAI_API_KEY"    "$( rigShown cli claude ANTHROPIC_API_KEY ) $( rigShown cli grok XAI_API_KEY )" "$( rigMask "$rigAnthropic" ) $( rigMask "$rigXai" )"

echo "-- 7. a value of fewer than 4 characters is all * --"
rigAssert "2 characters read **, 3 read ***: in the scope, and on the CLI's own line" "$( rigShown scopes magic-team SCALEWAY_DEEPSEEK ) $( rigShown scopes magic-team SCALEWAY_GEMMA ) $( rigShown cli scaleway SCALEWAY_DEEPSEEK ) $( rigShown cli scaleway SCALEWAY_GEMMA )" "** *** ** ***"

echo "-- 8. a password inside a URL: that part alone is masked, in the digest in full --"
rigAssert "not in full, the mask is per key: a key that is no credential shows its value as it is, the password with it, and reads set" "$( rigShown scopes magic-team WEB_ALLOW_PREFIXES ) $( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "scopes" && $4 == "WEB_ALLOW_PREFIXES" { print $5 }' "$rigTmp/out" )" "https://rigbot:$rigUrlPassword@docs.rig.example/api/_https://plain.rig.example/ set"
rigFull=1
rigAssert "in full, in the form of a credential; the URL stands, and so does a second beside it" "$( rigShown scopes magic-team WEB_ALLOW_PREFIXES )" "https://rigbot:$( rigMask "$rigUrlPassword" )@docs.rig.example/api/_https://plain.rig.example/"
rigAssert "and the line reads secret-set, as a credential's does" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "scopes" && $4 == "WEB_ALLOW_PREFIXES" { print $5 }' "$rigTmp/out.full" )" "secret-set"
rigAssert "in full a credential of a key is shown the same as not in full" "$( rigShown scopes magic-team JIRA_API_TOKEN )" "$( rigMask "$rigJira" )"
rigFull=""

echo "-- 9. guard: nothing of a value past its shown head --"
rigLeaks=""
for rigSecret in "$rigSlack" "$rigJira" "$rigAnthropic" "$rigXai" "$rigOauth" "$rigCopilot" "$rigSlackApp" ; do
	rigHead="$( rigMask "$rigSecret" | LC_ALL=C tr -d '*' )"
	## the eight characters right after the shown head: none of a value's hidden part stands anywhere, but on the line of the URL,
	## whose password stands whole outside the digest in full and is held on its own below
	rigTail="${rigSecret:${#rigHead}:8}"
	cat "$rigTmp/out" "$rigTmp/err" "$rigTmp/out.full" "$rigTmp/err.full" | LC_ALL=C grep -v -F -- WEB_ALLOW_PREFIXES | LC_ALL=C grep -q -F -- "$rigTail" && rigLeaks="$rigLeaks ${rigSecret:0:6}"
done
## the password of a URL is none of that outside the digest in full: there it stands whole, so only the full one is held
rigHead="$( rigMask "$rigUrlPassword" | LC_ALL=C tr -d '*' )"
cat "$rigTmp/out.full" "$rigTmp/err.full" | LC_ALL=C grep -q -F -- "${rigUrlPassword:${#rigHead}:8}" && rigLeaks="$rigLeaks ${rigUrlPassword:0:6}"
rigAssert "no hidden part of any of the eight on either stream, the password of the URL in the digest in full"   "[${rigLeaks# }]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CREDENTIAL DISPLAY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CREDENTIAL_DISPLAY: OK (%d assertions, offline)\n' "$rigPassCount"
