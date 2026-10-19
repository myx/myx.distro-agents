#!/usr/bin/env bash
## Behavioural check on the per-session scan cache (F3.2 of the refactorings epic): a scan writes its result to a file
## in the session folder and returns the file's path, in F2.4's form. Within five minutes a further call in that
## session returns the same file and reads no source; a change in a source does not refresh it. A spawn uses the cache
## of the session it runs in. The cache is per session, on the report of every --*-input-scan.
## Held, for --magic-advance-input-scan and --magic-heartbeat-input-scan, each called as a run of a team session:
##   1. the reply is the path of a file in the session's folder, with its size, a preview and a hint, not the report
##   2. a second call within five minutes returns the same file, unchanged, though a board item was added between
##   3. another run of the same session, a spawn joined to it, is served the same file
##   4. control: a run of another session scans afresh, and sees the new item
##   5. once the cache is older than five minutes, the next call scans afresh
## The age of the cache is taken from its file's modification time, which this rig sets back.
## Red before F3.2: every call returns the whole report, read afresh (1, 2, 3 and 5 fail).
## Offline: a ps first on PATH lists the rig's own runs only (none); a Slack-shaped fake curl logs any call; every tree
## is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A scan starts the control thread of a session of its rig that is not finished: what was started is ended before the tree is removed.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInputScanCacheCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*)\n\t\tcase "$*" in\n\t\t\t*pid=*) cat "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\t\t*) sed '"'"'s/^[^ ]* //'"'"' "${0%%/*}/../ps.list" 2> /dev/null ;;\n\t\tesac\n\t\texit 0\n\t;;\nesac\nexec "${0%%/*}/ps.real" "$@"\n' > "$rigTmp/bin/ps"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigW="$rigTmp/ws" rigD="$rigTmp/data" rigH="$rigTmp/home"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator" "$rigH"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item in %s\n' "$rigState" > "$rigD/board/$rigState/task-rig-$rigState.md"
done
rigNewItem(){ ## item stem -- one more pending item, which a fresh scan shows
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item added later\n' > "$rigD/board/pending/$1.md"
}
## One scan, called as a run of a team session: out, err, and the file the reply names.
rigScan(){ ## result name, scan operation, session, run id
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$3" MDAT_SPAWN_SESSION_ID="$4" MDAT_SPAWN_AGENT=magic-coordinator bash "$rigTool" "$2" magic-coordinator ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" 4> /dev/null
	printf '%s' "$?" > "$rigTmp/$1.rc"
}
rigFileOf(){ ## result name, session, what to print where it names none -- the first path of the reply to a file in that session's folder
	local fileOf
	for fileOf in $( LC_ALL=C grep -o -E '/[^ "]+' "$rigTmp/$1.out" 2> /dev/null ) ; do
		case "$fileOf" in "$rigW/.local/agents/sessions/$2/"*) ;; *) continue ;; esac
		[ -f "$fileOf" ] && { printf '%s' "$fileOf" ; return 0 ; }
	done
	printf '%s' "${3:-none}"
}
rigInFolder(){ ## path, session -- whether it is in that session's folder
	case "$1" in "$rigW/.local/agents/sessions/$2/"*) printf session-folder ;; *) printf '%s' "$1" ;; esac
}
rigShows(){ ## result name, item stem, session -- whether the scan's report shows the item, in its reply or in the file it names
	local showsFile
	showsFile="$( rigFileOf "$1" "$3" )"
	cat "$rigTmp/$1.out" "$( [ "$showsFile" = none ] && printf /dev/null || printf '%s' "$showsFile" )" 2> /dev/null | LC_ALL=C grep -q -F -- "$2" && printf shows || printf hides
}
rigStamp(){ ## minutes ago -- a touch -t stamp, BSD or GNU date
	local stampEpoch=$(( $( date +%s ) - $1 * 60 ))
	date -r "$stampEpoch" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M.%S
}

for rigOp in --magic-advance-input-scan --magic-heartbeat-input-scan ; do
	rigTag="${rigOp#--magic-}" ; rigTag="${rigTag%-input-scan}"
	rigSession="rig-cache-$rigTag" ; rigRunA="rig-cache-$rigTag-run-a" ; rigRunB="rig-cache-$rigTag-run-b"
	echo "-- $rigOp --"
	rigScan "$rigTag.1" "$rigOp" "$rigSession" "$rigRunA"
	[ "$( cat "$rigTmp/$rigTag.1.rc" )" = 0 ] || rigRefuse "$rigOp failed in the rig: $( tail -2 "$rigTmp/$rigTag.1.err" | LC_ALL=C tr '\n' ' ' )"
	rigFirst="$( rigFileOf "$rigTag.1" "$rigSession" )"
	echo "   1. the reply is the path of a file in the session's folder"
	rigAssert "$rigTag: a file in the session's folder is named" "$( [ "$rigFirst" != none ] && printf named || printf none )" named
	rigAssert "$rigTag: the reply is short, the report in the file" "$( [ "$( LC_ALL=C wc -c < "$rigTmp/$rigTag.1.out" | LC_ALL=C tr -d ' ' )" -lt 8192 ] && [ "$rigFirst" != none ] && printf short || printf whole )" short
	rigAssert "$rigTag: with its size in bytes"                 "$( [ "$rigFirst" != none ] && LC_ALL=C grep -q -w -- "$( LC_ALL=C wc -c < "$rigFirst" | LC_ALL=C tr -d ' ' )" "$rigTmp/$rigTag.1.out" && printf sized || printf not-sized )" sized
	echo "   2. within five minutes the same file, unchanged, though a source changed"
	rigFirstSum="$( [ "$rigFirst" != none ] && cksum < "$rigFirst" )"
	rigNewItem "task-rig-$rigTag-added"
	rigScan "$rigTag.2" "$rigOp" "$rigSession" "$rigRunA"
	rigAssert "$rigTag: the same file is named"                "$( rigFileOf "$rigTag.2" "$rigSession" no-file )" "$rigFirst"
	rigAssert "$rigTag: and it is unchanged"                   "$( [ "$rigFirst" != none ] && cksum < "$rigFirst" )" "${rigFirstSum:-none}"
	rigAssert "$rigTag: the item added since is not in it"     "$( rigShows "$rigTag.2" "task-rig-$rigTag-added" "$rigSession" )" hides
	echo "   3. a spawn joined to the same session is served the same file"
	rigScan "$rigTag.3" "$rigOp" "$rigSession" "$rigRunB"
	rigAssert "$rigTag: another run of the session gets the same file" "$( rigFileOf "$rigTag.3" "$rigSession" no-file )" "$rigFirst"
	echo "   4. control: a run of another session scans afresh"
	rigScan "$rigTag.4" "$rigOp" "rig-cache-$rigTag-other" "rig-cache-$rigTag-other-run"
	rigAssert "$rigTag: it shows the item added"               "$( rigShows "$rigTag.4" "task-rig-$rigTag-added" "rig-cache-$rigTag-other" )" shows
	echo "   5. older than five minutes, the next call scans afresh"
	[ "$rigFirst" = none ] || touch -t "$( rigStamp 6 )" "$rigFirst"
	rigScan "$rigTag.5" "$rigOp" "$rigSession" "$rigRunA"
	rigAssert "$rigTag: a file is named again, in the session's folder" "$( [ "$( rigFileOf "$rigTag.5" "$rigSession" )" != none ] && printf named || printf none )" named
	rigAssert "$rigTag: and it shows the item added"           "$( rigShows "$rigTag.5" "task-rig-$rigTag-added" "$rigSession" )" shows
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN CACHE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_CACHE: OK (%d assertions, offline)\n' "$rigPassCount"
