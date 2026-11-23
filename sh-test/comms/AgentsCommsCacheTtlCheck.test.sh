#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the one source-TTL table the Wait and the collection both read (sketch "RE: comms cache",
## its TTL bullets, and "Comms/Cache/Wait summary": the back-off lives in the Wait, and each source is read at its
## own default TTL). The table is `AgentsTools.SourceTtl.include`, read through `AgentsWaitTtlOf`. Held:
##   1. every source kind the sketch times has a TTL, and it is a whole number of seconds above nought
##   2. the session thread's TTL is no larger than any other timed kind's -- it is the shortest of the defaults
##   3. the email account's TTL is at least the sketch's three minutes, and longer than the thread's
##   4. a kind the table does not time reads as nought, so the Wait never skips it
##   5. the age a source reads as long expired is twenty of its TTLs, and nought where it has no TTL
##   6. the Wait reads the table through `AgentsWaitTtlOf`, so one read of a source gives one answer on both paths
## Offline: no workspace, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTtlInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.SourceTtl.include"
[ -f "$rigTtlInclude" ] || { echo "⛔ ERROR: the source-TTL table is not at the origin this workspace resolves: $rigTtlInclude" >&2 ; exit 1 ; }
rigWaitInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/wait/AgentsTools.MemberWaitCore.include"
[ -f "$rigWaitInclude" ] || { echo "⛔ ERROR: the Wait's own include is not at the origin: $rigWaitInclude" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One question of the table, asked in a shell of its own so nothing of a previous call stands: prints what the
## function printed, or "none" where it printed nothing at all.
rigTtl(){ ## the words to run after the table is sourced -- its answer, or none
	printf '%s' "$( bash -c '. "$1" || exit 9 ; shift ; "$@"' _ "$rigTtlInclude" "$@" 2> /dev/null )"
}
## A whole number of seconds, and one above nought: "yes" where both hold, so a kind timed at "15 s" or "" is caught.
rigTimed(){ ## source kind
	case "$( rigTtl AgentsToolsSourceTtlOf "$1" )" in ''|*[!0-9]*) printf 'no\n' ; return ;; esac
	case "$( rigTtl AgentsToolsSourceTtlOf "$1" )" in 0) printf 'no\n' ;; *) printf 'yes\n' ;; esac
}

echo "-- 1. every source kind the sketch times has a TTL above nought --"
for rigKind in chat:rig-session tagged:rig-member mentions:rig-member dms:rig-member slack:rig-channel mail:rig-member ; do
	rigAssert "a TTL is named for $rigKind" "$( rigTimed "$rigKind" )" "yes"
done

echo "-- 2. the session thread holds the shortest of the defaults --"
rigChat="$( rigTtl AgentsToolsSourceTtlOf chat:rig-session )"
rigLonger=""
for rigKind in tagged:rig-member mentions:rig-member dms:rig-member slack:rig-channel mail:rig-member ; do
	rigOne="$( rigTtl AgentsToolsSourceTtlOf "$rigKind" )"
	case "$rigOne" in ''|*[!0-9]*) continue ;; esac
	[ "$rigOne" -lt "$rigChat" ] && rigLonger="$rigLonger $rigKind"
done
rigAssert "no timed kind is read more often than the session thread" "${rigLonger:-none}" "none"

echo "-- 3. the email account is the slow one: three minutes at least, and slower than the thread --"
rigMail="$( rigTtl AgentsToolsSourceTtlOf mail:rig-member )"
case "$rigMail" in ''|*[!0-9]*) rigAssert "the email account's TTL is a number of seconds" "$rigMail" "a number" ;; *) rigAssert "the email account waits at least the sketch's three minutes" "$( [ "$rigMail" -ge 180 ] && echo at-least-180 || echo under-180 )" "at-least-180" ;; esac
rigAssert "and longer than the session thread's" "$( [ "$( rigTtl AgentsToolsSourceTtlOf mail:rig-member )" -gt "$rigChat" ] 2> /dev/null && echo longer || echo not-longer )" "longer"

echo "-- 4. a kind the table does not time reads as nought, so the Wait never skips it --"
rigAssert "an untimed kind has no TTL" "$( rigTtl AgentsToolsSourceTtlOf checklist:rig-member )" "0"
rigAssert "and one that looks like none of them has none either" "$( rigTtl AgentsToolsSourceTtlOf nothing-at-all )" "0"

echo "-- 5. long expired is twenty of its TTLs --"
rigAssert "the email account is long expired after twenty of its TTLs" "$( rigTtl AgentsToolsSourceStaleOf mail:rig-member )" "$(( $( rigTtl AgentsToolsSourceTtlOf mail:rig-member ) * 20 ))"
rigAssert "an untimed kind is never long expired" "$( rigTtl AgentsToolsSourceStaleOf checklist:rig-member )" "0"

echo "-- 6. the Wait reads the table through one function, so both paths answer the same --"
rigAssert "the Wait's own lookup answers with the table's value" \
	"$( bash -c '. "$1" ; . "$2" ; AgentsWaitTtlOf "$3"' _ "$rigTtlInclude" "$rigWaitInclude" slack:rig-channel 2> /dev/null )" \
	"$( rigTtl AgentsToolsSourceTtlOf slack:rig-channel )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS CACHE TTL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_CACHE_TTL: OK (%d assertions, offline)\n' "$rigPassCount"
