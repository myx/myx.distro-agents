#!/usr/bin/env bash
## The fake `curl` for AgentsCredentialExposureCheck. It opens no socket; being first
## on PATH is that check's whole offline guarantee. On every call it records what a
## real curl would have been handed, and what the disk holds while the call is in
## flight, then answers as Slack or Atlassian would, succeeding or failing on
## $RIG_MODE. Its records, all under $RIG_SCENARIO:
##   stdin.log     what arrived on stdin, a Basic header also decoded (the control)
##   argv.log      its own argv
##   ps.log        `ps -o args=` for itself and for its parent
##   inflight.log  the mdat-* temp files present while it runs
##   probe.log     the control: the probe planted in $TMPDIR, as the one scan found it
##   disk.log      any file under the workspace's .local/temp or $TMPDIR holding the sentinel
##   bodies.log    the --data-binary body, so a body marker is shown to be visible
set -u
rigDir="$RIG_SCENARIO"
rigStdin="$( cat )"
printf '%s\n' "$rigStdin" >> "$rigDir/stdin.log"
case "$rigStdin" in
	*"Authorization: Basic "*)
		rigBasic="${rigStdin#*Authorization: Basic }"
		rigBasic="${rigBasic%%$'\n'*}"
		{ printf '%s' "$rigBasic" | base64 -d 2>/dev/null ; echo ; } >> "$rigDir/stdin.log"
	;;
esac
printf '%s\n' "$*" >> "$rigDir/argv.log"
{ ps -o args= -p "$$" ; ps -o args= -p "$PPID" ; } >> "$rigDir/ps.log" 2>/dev/null
ls -1 "$RIG_WS/.local/temp" 2>/dev/null | grep '^mdat-' >> "$rigDir/inflight.log"
## One scan over both folders, for the credential and for a probe sentinel planted in
## $TMPDIR: the probe found is the proof this very scan reaches $TMPDIR (the control).
printf 'RIG-TMPDIR-PROBE\n' > "$TMPDIR/rig-probe.$$"
grep -rl -F -e "$RIG_SENTINEL" -e "$RIG_SENTINEL_B64" -e RIG-TMPDIR-PROBE "$RIG_WS/.local/temp" "$TMPDIR" > "$rigDir/scan.$$" 2>/dev/null
rm -f "$TMPDIR/rig-probe.$$"
grep -F "/rig-probe.$$" "$rigDir/scan.$$" | sed 's/$/ RIG-TMPDIR-PROBE/' >> "$rigDir/probe.log"
grep -v -F "/rig-probe.$$" "$rigDir/scan.$$" >> "$rigDir/disk.log"
rm -f "$rigDir/scan.$$"

rigUrl="" rigPrevArg=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://*) rigUrl="$rigArg" ;;
	esac
	[ "$rigPrevArg" != "--data-binary" ] || { cat "${rigArg#@}" ; echo ; } >> "$rigDir/bodies.log"
	rigPrevArg="$rigArg"
done

case "$rigUrl" in
	https://slack.com/api/*)
		if [ "$RIG_MODE" = "ok" ] ; then
			case "${rigUrl#https://slack.com/api/}" in
				auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
				chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1.000001","message":{"ts":"1.000001","user":"URIGBOT01"}}\n' ;;
				*) printf '{"ok":false,"error":"unknown_method"}\n' ;;
			esac
		else
			printf '{"ok":false,"error":"channel_not_found"}\n'
		fi
	;;
	*)
		## Atlassian: the caller asks for the status on a line of its own, last.
		if [ "$RIG_MODE" = "ok" ] ; then
			printf '{"id":"10001"}\n201'
		else
			printf '{"errorMessages":["rig"]}\n404'
		fi
	;;
esac
exit 0
