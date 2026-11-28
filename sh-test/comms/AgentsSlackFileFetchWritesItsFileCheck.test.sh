#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the file `--slack-file-fetch` leaves behind, run rather than read: the op is called through
## `DistroAgentsSlack.fn.sh` in a rig workspace, against a fake `curl` first on PATH that answers files.info and the
## private download. Held:
##   1. THE FILE IT REPORTS. The fetch ends 0, prints FETCH_STATE=fetched, and the DESTINATION it prints is a file
##      that is there, holding exactly the bytes files.info reported. No `.fetch.` temp of the op's own is left
##      beside it.
##   2. THE BYTE COUNT HAS TEETH. The same fetch over a body one byte short is refused, writes nothing, and says the
##      sizes must match exactly -- so section 1's count is a measurement, not a line that passes on its own.
## Red recipe: against `sh-lib/slack/AgentsTools.InternOpCommsSlackFileFetch.include` without this change's
## `trap - EXIT` before its diagnostic capture, the check fails 6 of its 9 assertions and ends red: section 1's five
## (the status, FETCH_STATE, the file there, its byte count, the printed destination) and section 2's exact-size
## sentence, which the fetch never reaches because it stops counting first. `no temp of the op's own is left beside
## it` passes in both, since the temp is gone by then either way. With the capture's own trap cleared, all 9 pass.
## Offline: the fake curl is first on PATH and refused otherwise, the rig is a folder of its own, and nothing leaves
## the machine.
##
## Guards: sh-lib/slack/AgentsTools.InternOpCommsSlackFileFetch.include
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=${MMDAPP%/}/.local}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsSlack.fn.sh"
rigFileId="FRIG0000001"
rigFileSize=4096

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the Slack tool is not at the origin this workspace resolves: $rigFn"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackFileFetchWritesItsFileCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigWs="$rigTmp/ws"
rigOut="$rigTmp/out"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/members/magic-team" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigOut"
printf '%s\n' magic-team > "$rigWs/.local/agents/members/magic-team/magic-team.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-FETCH\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## The fake curl: files.info answers this rig's one file, the private download writes RIG_FILE_BODY_BYTES of payload.
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
hdr="$( cat )"
outPath="" headerPath="" url="" prev=""
for arg in "$@" ; do
	case "$arg" in https://*) url="$arg" ;; esac
	case "$prev" in
		-o) outPath="$arg" ;;
		-D) headerPath="$arg" ;;
	esac
	prev="$arg"
done
case "$url" in
	*api/files.info*)
		printf '{"ok":true,"file":{"id":"%s","name":"shot.png","title":"shot.png","mimetype":"image/png","filetype":"png","size":%s,"timestamp":1795694000,"user":"URIGOWNER01","url_private":"https://files.slack.com/files-pri/TRIG-FRIG/shot.png","url_private_download":"https://files.slack.com/files-pri/TRIG-FRIG/download/shot.png"}}\n' \
			"${RIG_FILE_ID:-FRIG0000001}" "${RIG_FILE_SIZE:-4096}"
	;;
	*auth.test*)
		printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01","team":"TRIG"}\n'
	;;
	*files-pri*)
		printf 'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\n\r\n' > "$headerPath"
		LC_ALL=C awk -v n="${RIG_FILE_BODY_BYTES:-4096}" 'BEGIN { body = "rig-file-payload-" ; while ( length(body) < n ) { body = body "0123456789abcdef" ; } printf "%s", substr(body, 1, n) ; }' > "$outPath"
		printf '200 %s image/png' "${RIG_FILE_BODY_BYTES:-4096}"
	;;
	*)
		printf '{"ok":false,"error":"rig-unknown-method"}\n'
	;;
esac
exit 0
STUB
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One fetch as the op runs it: env -i, the rig workspace, the rig's own home, the fake curl on PATH.
rigFetch(){ ## destination, body bytes
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_FILE_ID="$rigFileId" RIG_FILE_SIZE="$rigFileSize" RIG_FILE_BODY_BYTES="$2" \
		bash "$rigFn" --slack-file-fetch --team-member magic-team "$rigFileId" "$1" 2>&1
}
rigBytes(){ ## path -- its byte count, or empty where there is no file
	[ -f "$1" ] || return 0
	LC_ALL=C wc -c < "$1" | LC_ALL=C tr -d '[:space:]'
}
rigField(){ ## field name, the fetch's output
	printf '%s\n' "$2" | LC_ALL=C sed -n "s/^$1=//p" | LC_ALL=C sed -n 1p
}

## SECTION 1. The fetch writes its file, and reports a path that holds the bytes.
rigWholeRc=0
rigWholeOut="$( rigFetch "$rigOut/shot.png" "$rigFileSize" )" || rigWholeRc=$?
rigAssert "the fetch of $rigFileId ends 0" "$rigWholeRc" 0
rigAssert "and says it fetched" "$( rigField FETCH_STATE "$rigWholeOut" )" fetched
rigAssert "the destination it printed is a file that is there" "$( [ -f "$( rigField DESTINATION "$rigWholeOut" )" ] && printf there || printf absent )" there
rigAssert "holding exactly the bytes files.info reported" "$( rigBytes "$rigOut/shot.png" )" "$rigFileSize"
rigAssert "and the VERIFIED_BYTES it printed agree with the file" "$( rigField VERIFIED_BYTES "$rigWholeOut" )" "$rigFileSize"
rigAssert "no temp of the op's own is left beside it" "$( LC_ALL=C ls -A "$rigOut" | LC_ALL=C grep -c '\.fetch\.' || : )" 0

## SECTION 2. A short body is refused and nothing is written, so the count above is a measurement.
rigShortRc=0
rigShortOut="$( rigFetch "$rigOut/short.png" "$(( rigFileSize - 1 ))" )" || rigShortRc=$?
rigAssert "a body one byte short is refused" "$( [ "$rigShortRc" != 0 ] && printf refused || printf accepted )" refused
rigAssert "and nothing is written at that destination" "$( [ -e "$rigOut/short.png" ] && printf there || printf absent )" absent
rigAssert "and it says the sizes must match exactly" "$( printf '%s\n' "$rigShortOut" | LC_ALL=C grep -c 'sizes must match EXACTLY' || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK FILE FETCH WRITES ITS FILE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_FILE_FETCH_WRITES_ITS_FILE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
