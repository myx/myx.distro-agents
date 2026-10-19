#!/usr/bin/env bash
## Behavioural check on the temp files of the package's own writers, and the guard over their names. The shell's
## process id, $$, is the id of the shell that was started and stays the same in every subshell of it, so a temp
## file named by it is one file for two writers that run as subshells of one shell: the members one call started,
## two calls a member's one command makes at once, a background job beside its starter. One then reads what the
## other wrote, or loses its file to the other's rename or removal. Held here:
##   1. THE GUARD. Every use of $$ in the package's shell files (sh-lib, sh-scripts, builders, the console
##      template among them) is on the one list below, each with the reason it cannot be shared or is no file
##      name at all. A new use that is not on the list fails this check, and so does a line of the list that no
##      longer matches the code. A temp file gets its name by mktemp; a $$ name is added to the list only with
##      the reason two writers of one shell cannot meet on it.
##   2. Each place that was named by $$ and could be shared makes its name by mktemp.
##   3. Two writers of one shell, made to meet: both calls run in subshells of the one shell a member's command
##      runs in (--intern-mcp-execute), and a tool of the rig first on PATH holds each between its temp file
##      being written and being read until both stand there, never on a clock. Each then has its own result:
##      the header change of a board item, of an inbox item marked processed and of a new inbox item, the
##      references a board rename rewrites, the message of an email, and the post a session takes for its own.
##   4. The lock: a dead lock is still broken, and the name it is moved to is not left behind, moved or not.
## Offline: one mktemp tree, every call through `env -i` whose child refuses to run outside it; a fake `curl`
## first on PATH would log a request, and none is made.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigRealAwk="$( command -v awk )" || rigRefuse "no awk on PATH"
rigRealCat="$( command -v cat )" || rigRefuse "no cat on PATH"
rigTmp="$( mktemp -d -t AgentsTempNamesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigData="$rigTmp/data" ; rigSkills="$rigTmp/skills" ; rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local" "$rigHome" "$rigSkills/rig-member" "$rigSkills/rig-other" "$rigData/board/backlog" "$rigData/inboxes/rig-member/incoming" "$rigData/inboxes/rig-other/incoming" "$rigTmp/held" \
	|| rigRefuse "could not create the rig"

## The tools of the rig, first on PATH for every call. awk and cat: a call that names the temp file of the scenario
## (RIG_HOLD_NAME) stands until two such calls stand there together, half a minute at most, and then goes on to
## the real tool; every other call goes straight on. curl: never meant to run.
for rigTool in awk cat ; do
	printf '%s\n' '#!/usr/bin/env bash' \
		'if [ -n "${RIG_HOLD_NAME:-}" ] ; then' \
		'	case " $* " in *"$RIG_HOLD_NAME"*)' \
		'		: > "$RIG_HOLD_DIR/arrived.$$"' \
		'		holdNo=0' \
		'		while [ "$( ls "$RIG_HOLD_DIR" 2> /dev/null | LC_ALL=C grep -c "^arrived\." )" -lt 2 ] && [ "$holdNo" -lt 150 ] ; do holdNo=$(( holdNo + 1 )) ; sleep 0.2 ; done' \
		'	;; esac' \
		'fi' \
		"exec \"\$RIG_REAL_$( printf '%s' "$rigTool" | LC_ALL=C tr 'a-z' 'A-Z' )\" \"\$@\"" > "$rigTmp/held/$rigTool"
done
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$RIG_CURL_LOG"' 'exit 7' > "$rigTmp/held/curl"
chmod +x "$rigTmp/held/awk" "$rigTmp/held/cat" "$rigTmp/held/curl"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## The value of one frontmatter field, bounded to the first --- block.
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if ( d >= 2 ) exit ; next ; } d == 1 && index( $0, f ": " ) == 1 { print substr( $0, length( f ) + 3 ) ; exit ; }' "$1" 2> /dev/null
}

echo "-- 1. the guard: every \$\$ of the shell files is on the list, with its reason --"
## THE LIST. One line a name: file|how many times it stands there|the text that holds the $$|the reason. A reason
## that starts `no file name` or `no temp file` is a use that names no temp file. Comment lines of the code are
## not read, and neither is a dollar that is escaped (\$).
rigList(){
	printf '%s\n' \
		'sh-lib/harness/AgentsHarnessContext.include|1|$harnessContextFile.$$|the context file of one session, written by its one harness process in its main shell' \
		'sh-lib/questions/AgentsTools.AskThread.include|3|$tagFile.$$|the counter of one addressee, taken under the ask-thread lock of that addressee' \
		'sh-lib/session/AgentsTools.EventTrackThread.include|3|event-track.thread.$$|the thread record of one session store, written under the event-track lock of that store' \
		'sh-lib/grants/AgentsTools.Grants.include|4|$regFile.tmp.$$|under the lock of the permissions registry' \
		'sh-lib/grants/AgentsTools.Grants.include|4|$regTagsFile.tmp.$$|under the lock of the permissions registry' \
		'sh-lib/config/AgentsTools.Install.include|2|$registryFile.tmp.$$|under the lock of the member registry' \
		'sh-lib/config/AgentsTools.Install.include|2|magic-skillset-report.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|mdat-member-home-scan.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|mdat-claude-permissions-grants.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|mdat-claude-permissions-members.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|mdat-ws-restrictions-hooks.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|mdat-ws-integrations-hooks.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|3|$settingsFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|3|$projectedFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$hookDstFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$fragmentFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$agentFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$HOME/.claude.json.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$mcpFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/config/AgentsTools.Install.include|1|$distroFile.tmp.$$|the installer: its operations are called one after another by their one caller, never two in subshells of one shell' \
		'sh-lib/common/AgentsTools.InternArtifact.include|1|${artSession:-no session} $$|no file name: the subject of a commit' \
		'sh-lib/common/AgentsTools.InternArtifact.include|1|$artRecord-$$|no temp file: the name of a record, where one of that title and minute stands already' \
		'sh-lib/common/AgentsTools.InternContact.include|1|no-session-$$|no temp file: stands for the calling shell where a refusal has no session to be logged under' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|1|mdat-main-loop-status.$$|the main loop is a process of its own, and this is its one status file for its whole run' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|1|spawn-proxy-[0-9TZ]+-$$(|no file name: the pattern of the receipt this loop gave its pass' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|3|pending-collect.last.$$|written by the main loop itself, a step after another in its own shell' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|3|pending-remind.last.$$|written by the main loop itself, a step after another in its own shell' \
		'sh-lib/mcp/AgentsTools.InternMcpServer.include|6|agent-mcp.$$|the scratch folder of one server process, which hands its own id to every request it serves' \
		'sh-lib/mcp/AgentsTools.InternMcpServer.include|1|pid=$$|no file name: said in a log line' \
		'sh-lib/mcp/AgentsTools.InternMcpServer.include|1|--intern-mcp-request "$$"|no file name: the server names itself to its request' \
		'sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include|1|spawn-proxy-$timestamp-$$-${MDAT_SPAWN_SESSION_ID:0:8}|no temp file: a receipt id, made its own by the first eight of the spawn id' \
		'sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include|1|dispatch-$timestamp-spawn-proxy-$$-${MDAT_SPAWN_SESSION_ID:0:8}|no temp file: a dispatch item name, made its own by the first eight of the spawn id' \
		'sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include|2|$sessionThreadRecord.$$.tmp|the thread record of one session, written under the session-thread lock of that session' \
		'sh-lib/grants/AgentsTools.InternOpChange.include|4|$holdDir/shown.$$|inside the folder of one held change, named by an id made for it' \
		'sh-lib/inbox/AgentsTools.InternOpInboxToProcessed.include|1|.inbox-to-processed.$$|beside the one inbox item it replaces: shared only by two marks of that one item at the same moment' \
		'sh-lib/questions/AgentsTools.InternOpPendingReply.include|4|$pendingRoot/.$pendingId.md.$$|named by the id made for this one new record' \
		'sh-lib/questions/AgentsTools.InternOpPendingReply.include|3|$pendingFile.$$|under the lock of that one pending reply' \
		'sh-lib/questions/AgentsTools.InternOpPendingReply.include|3|$clarFile.$$|under the lock of that one pending reply' \
		'sh-lib/questions/AgentsTools.InternOpPendingReply.include|3|$revFile.$$|under the lock of that one pending reply' \
		'sh-lib/grants/AgentsTools.InternOpPermission.include|1|mdat-permission-hook-held.$$.$RANDOM|a client hook is a process of its own for each call, and the mark is one another process makes, so it cannot be made beforehand' \
		'sh-lib/magic/AgentsTools.LocalLock.include|1|ln -s "$$"|no file name: the holder a lock names' \
		'sh-lib/magic/AgentsTools.LocalLock.include|1|!= "$$"|no file name: the holder a lock names' \
		'sh-lib/manager/AgentsTools.ManagerSession.include|3|$1.killed.$$|beside the one spawn record a kill marks: a kill marks a record after another' \
		'sh-lib/comms/AgentsTools.MemberCommsEmail.include|1|mdat-comms-email-boundary-$$-$RANDOM|no file name: the boundary inside one message' \
		'sh-lib/questions/AgentsTools.MemberEscalation.include|1|AgentsToolsEscalationClaimStart "$$"|no file name: a process asked about' \
		'sh-lib/questions/AgentsTools.MemberEscalation.include|3|$noteFile.$$.tmp|the note of one record, written by the holder of the claim on that record alone' \
		'sh-lib/questions/AgentsTools.MemberEscalation.include|3|${applyFile%.md}.set.$$|beside one record, written by the holder of the claim on that record alone' \
		'sh-lib/questions/AgentsTools.MemberEscalation.include|3|${addOpen%.md}.set.$$|under the claim on that one record and the lock of its pending reply' \
		'sh-lib/questions/AgentsTools.MemberEscalation.include|3|$addOpen.$$|under the claim on that one record and the lock of its pending reply' \
		'sh-lib/member/AgentsTools.MemberHomes.include|4|$writeFile.tmp.$$|under the lock of the member registry of the machine' \
		'sh-lib/member/AgentsTools.MemberHomes.include|4|$homesFile.tmp.$$|under the lock of the member homes registry' \
		'sh-lib/member/AgentsTools.MemberRetest.include|1|${queueId:-$$-$RANDOM}|no temp file: the id of a request, and only where the machine has no uuidgen' \
		'sh-lib/config/AgentsTools.Owner.include|1|selftest-$$-|no file name: a value written to a setting and read back' \
		'sh-lib/questions/AgentsTools.PendingReplyCollect.include|3|$2.$$|under the lock of that one pending reply' \
		'sh-lib/questions/AgentsTools.PendingReplyRemind.include|3|$2.$$|under the lock of that one pending reply' \
		'../myx.distro-.local/sh-lib/registry/AgentsTools.Places.include|3|$updateFile.tmp.$$|under the lock of that places registry' \
		'../myx.distro-.local/sh-lib/registry/AgentsTools.Places.include|3|$sharedFile.tmp.$$|under the lock of the places registry of the machine' \
		'../myx.distro-.local/sh-lib/registry/AgentsTools.Registries.include|2|${3:-$$}|no file name: the asking process, this one where none is given' \
		'../myx.distro-.local/sh-lib/registry/AgentsTools.Registries.include|3|$keepFile.$$.aside|the file of one run, named by its spawn id: a stop or a kill of one run is one call at a time' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|1|context.render.$$|inside the store of one session id, rendered by that session alone' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|2|$addDir/tokens.$$|inside the store of one session id, added to by its one harness process, a round after another' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|1|.conversation.read.$$|inside the input folder of one sandbox, which one start fills: two fills of one sandbox share that whole folder, whatever this is named' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|1|mdat-session-run-ops.$$.$1|made its own by the process id of the console just started' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|3|$runFile.run.$$|beside one spawn record, written by the launches of that spawn, which come one after another in its own proxy' \
		'sh-lib/harness/AgentsUniversalHarness.sh|1|.mdat-write.$$|under the write lock of that one target' \
		'sh-lib/harness/AgentsUniversalHarness.sh|1|.mdat-edit.$$|under the write lock of that one target' \
		'sh-lib/harness/AgentsUniversalHarness.sh|2|$keepFile.$$.tmp|the dismissal of one session, kept by its one harness process' \
		'sh-lib/harness/AgentsUniversalHarness.sh|3|$harnessToolSearchFloorFile.$$|inside the scratch folder this harness process made for itself by mktemp'
}
## Reads the list, then the files named after it: prints a line for every $$ the list does not hold, and for every
## line of the list that stands another number of times than it says.
rigGuard(){ ## list file, shell files...
	LC_ALL=C awk -F'|' '
		FILENAME == ARGV[1] {
			if ( $0 == "" ) { next ; }
			if ( NF != 4 || $2 !~ /^[0-9]+$/ || $3 == "" || $4 == "" ) { print "LIST: not `file|times|text|reason`: " $0 ; next ; }
			listTotal++ ; listFile[listTotal] = $1 ; listWant[listTotal] = $2 + 0 ; listText[listTotal] = $3 ; listGot[listTotal] = 0 ;
			next ;
		}
		{
			lineText = $0 ; sub( /^[ \t]+/, "", lineText ) ;
			if ( substr( lineText, 1, 1 ) == "#" ) { next ; }
			gsub( /\\\$/, "", lineText ) ;
			if ( ! index( lineText, "$$" ) ) { next ; }
			## the longest text of the list first, so no name is taken for the start of a longer one
			do {
				bestAt = 0 ; bestLen = 0 ;
				for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
					if ( listFile[listAt] == FILENAME && length( listText[listAt] ) > bestLen && index( lineText, listText[listAt] ) ) { bestAt = listAt ; bestLen = length( listText[listAt] ) ; }
				}
				if ( bestAt ) {
					textAt = index( lineText, listText[bestAt] ) ; listGot[bestAt]++ ;
					lineText = substr( lineText, 1, textAt - 1 ) " " substr( lineText, textAt + bestLen ) ;
				}
			} while ( bestAt ) ;
			if ( index( lineText, "$$" ) ) { print "NOT ON THE LIST: " FILENAME ":" FNR ": " $0 ; }
		}
		END {
			for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
				if ( listGot[listAt] != listWant[listAt] ) { print "LIST: " listFile[listAt] " holds `" listText[listAt] "` " listGot[listAt] " time(s), the list says " listWant[listAt] ; }
			}
		}
	' "$@"
}
rigList > "$rigTmp/list"
( cd "$rigPackage" && find sh-lib sh-scripts builders ../myx.distro-.local/sh-lib/markdown ../myx.distro-.local/sh-lib/output ../myx.distro-.local/sh-lib/registry ../myx.distro-.local/sh-lib/dashboard -type f \( -name '*.sh' -o -name '*.include' -o -name '*.rc' \) | LC_ALL=C sort ) > "$rigTmp/shell-files"
rigAssert "control: the shell files of the package are read, the console template and the builders among them" \
	"$( [ "$( wc -l < "$rigTmp/shell-files" | LC_ALL=C tr -d ' ' )" -ge 100 ] && echo many ) $( LC_ALL=C grep -c -x -F -e 'sh-lib/manager/AgentsConsoleShellScript.template.sh' -e 'sh-scripts/DistroAgentsTools.fn.sh' -e 'builders/source-prepare/1201-agents-indices.sh' "$rigTmp/shell-files" || : )" "many 3"
rigGuardOut="$( cd "$rigPackage" && rigGuard "$rigTmp/list" $( cat "$rigTmp/shell-files" ) )"
rigAssert "every \$\$ of the shell files is on the list, and every line of the list stands in the code as often as it says (a new temp name is made by mktemp, or listed with the reason two writers of one shell cannot share it)" "${rigGuardOut:-none}" "none"
rigAssert "every line of the list gives its reason" "$( LC_ALL=C awk -F'|' 'length( $4 ) < 20 { short++ } END { print NR " lines, " short + 0 " without a reason" }' "$rigTmp/list" )" "$( wc -l < "$rigTmp/list" | LC_ALL=C tr -d ' ' ) lines, 0 without a reason"
## control: the reader does find a new name, takes a listed one, and reads no comment and no escaped dollar
mkdir -p "$rigTmp/probe/sh-lib"
printf '%s\n' '	## a comment that says $$ is not read' '	echo "an escaped dollar before a name: \$$name"' '	probeOld="$probeFile.tmp.$$"' '	probeNew="$MMDAPP/.local/temp/mdat-probe-new.$$"' > "$rigTmp/probe/sh-lib/Probe.include"
printf '%s\n' 'sh-lib/Probe.include|1|$probeFile.tmp.$$|a reason long enough to stand in a control' > "$rigTmp/probe/list"
rigAssert "control: a name that is not on the list is found, with its file and line, and nothing else of that file is" \
	"$( cd "$rigTmp/probe" && rigGuard "$rigTmp/probe/list" sh-lib/Probe.include )" 'NOT ON THE LIST: sh-lib/Probe.include:4: 	probeNew="$MMDAPP/.local/temp/mdat-probe-new.$$"'
printf '%s\n' 'sh-lib/Probe.include|2|$probeFile.tmp.$$|a reason long enough to stand in a control' 'sh-lib/Probe.include|1|mdat-probe-new.$$|a reason long enough to stand in a control' > "$rigTmp/probe/list"
rigAssert "control: a line of the list that the code holds another number of times is said" \
	"$( cd "$rigTmp/probe" && rigGuard "$rigTmp/probe/list" sh-lib/Probe.include )" 'LIST: sh-lib/Probe.include holds `$probeFile.tmp.$$` 1 time(s), the list says 2'

echo "-- 2. each place that could be shared makes its name by mktemp --"
rigMade=""
while IFS='|' read -r rigMadeFile rigMadeName ; do
	[ -n "$rigMadeFile" ] || continue
	[ "$( LC_ALL=C grep -v '^[[:space:]]*#' "$( ls -d "$rigLib"/*/"$rigMadeFile" "$rigLib"/../../myx.distro-.local/sh-lib/*/"$rigMadeFile" 2> /dev/null | head -1 )" | LC_ALL=C grep -c -F -- "$rigMadeName" || : )" = "1" ] || rigMade="$rigMade [$rigMadeFile $rigMadeName]"
done <<< 'AgentsTools.ApprovalCascade.include|mktemp "$MMDAPP/.local/temp/mdat-approval-cascade.XXXXXX"
AgentsTools.ClientComms.include|mktemp "$MMDAPP/.local/temp/mdat-snapshot.XXXXXX"
AgentsTools.EventTrackThread.include|mktemp "$MMDAPP/.local/temp/mdat-event-track-post.XXXXXX"
AgentsTools.InternOpBoardRename.include|mktemp "$MMDAPP/.local/temp/mdat-intern-op-rename.XXXXXX"
AgentsTools.InternOpBoardUpsertMoveEdit.include|mktemp "$MMDAPP/.local/temp/mdat-intern-op-headers.XXXXXX"
AgentsTools.InternOpInboxToProcessed.include|mktemp "$MMDAPP/.local/temp/mdat-inbox-to-processed-headers.XXXXXX"
AgentsTools.InternOpItem.include|mktemp "$MMDAPP/.local/temp/mdat-item-upsert-headers.XXXXXX"
AgentsTools.InternOpItemRename.include|mktemp "$MMDAPP/.local/temp/mdat-intern-op-item-rename.XXXXXX"
AgentsTools.InternOpMemberInboxUpsert.include|mktemp "$MMDAPP/.local/temp/mdat-intern-op-inbox-headers.XXXXXX"
AgentsTools.InternOpPendingReply.include|mktemp "$MMDAPP/.local/temp/mdat-pending-reply-ops.XXXXXX"
AgentsTools.InternOpPendingReply.include|mktemp "$MMDAPP/.local/temp/mdat-pending-reply-clarify-ops.XXXXXX"
AgentsTools.InternOpPendingReply.include|mktemp "$MMDAPP/.local/temp/mdat-pending-reply-revise-ops.XXXXXX"
AgentsTools.PendingReplyCollect.include|mktemp "$MMDAPP/.local/temp/mdat-pending-reply-mark.XXXXXX"
AgentsTools.PendingReplyRemind.include|mktemp "$MMDAPP/.local/temp/mdat-pending-reply-remind.XXXXXX"
AgentsTools.MagicSweep.include|mktemp -d "$MMDAPP/.local/temp/mdat-magic-sweep-clients.$callingMember.XXXXXX"
AgentsTools.MemberCommsEmail.include|mktemp "$MMDAPP/.local/temp/mdat-comms-email-message.XXXXXX"
AgentsTools.MemberCommsSlack.include|mktemp "$MMDAPP/.local/temp/mdat-slack-file-info-diag.XXXXXX"
AgentsTools.MemberCommsSlack.include|mktemp "$MMDAPP/.local/temp/mdat-slack-delete-diag.XXXXXX"
AgentsTools.MemberCommsSlack.include|mktemp "$MMDAPP/.local/temp/mdat-slack-share-stdin.XXXXXX"
AgentsTools.LocalLock.include|mktemp "$agentsLocalLockPath.stale.XXXXXX"'
rigAssert "the twenty places: each makes its name by mktemp, once" "${rigMade:-each by mktemp}" "each by mktemp"

## Two calls at once from one shell, as a member's one command makes them: the script runs where the tooling runs
## such a command (--intern-mcp-execute), and each call writes what it ended with into the scenario's folder.
rigPair(){ ## scenario folder, the temp name held, script -- then optional NAME=value settings of the call
	local pairDir="$1" pairHold="$2" pairScript="$3"
	shift 3
	mkdir -p "$pairDir/hold"
	env -i HOME="$rigHome" PATH="$rigTmp/held:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_OUT="$pairDir" RIG_HOLD_NAME="$pairHold" RIG_HOLD_DIR="$pairDir/hold" \
		RIG_REAL_AWK="$rigRealAwk" RIG_REAL_CAT="$rigRealCat" RIG_CURL_LOG="$rigTmp/curl.calls" RIG_SCRIPT="$pairScript" "$@" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && printf "%s\n" "$RIG_SCRIPT" | bash "$RIG_FN" --intern-mcp-execute
		' rig > "$pairDir/run.out" 2>&1
	printf '%s' "$?" > "$pairDir/run.rc"
}
## `<shells> <calls held together> <rc of one> <rc of the other>`: one shell for both, both held at the read, both ended 0.
rigPairMet(){ ## scenario folder
	printf '%s %s %s %s' "$( cat "$1/a.shell" "$1/b.shell" 2> /dev/null | LC_ALL=C sort -u | LC_ALL=C awk 'END { print NR + 0 }' )" \
		"$( ls "$1/hold" 2> /dev/null | LC_ALL=C grep -c '^arrived\.' || : )" "$( cat "$1/a.rc" 2> /dev/null )" "$( cat "$1/b.rc" 2> /dev/null )"
}
rigLeft(){ ## name -- how many temp files of that name are left in the workspace
	ls "$rigWs/.local/temp" 2> /dev/null | LC_ALL=C grep -c -F -- "$1" || :
}
## One call of a pair: its shell, the call with its output kept, its end.
rigCall(){ ## a|b, the call
	printf '( printf "%%s\\n" "$$" > "$RIG_OUT/%s.shell" ; %s > "$RIG_OUT/%s.out" 2>&1 ; printf "%%s\\n" "$?" > "$RIG_OUT/%s.rc" ) &\n' "$1" "$2" "$1" "$1"
}

echo "-- 3a. two header changes of board items at once --"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item alpha\n' > "$rigData/board/backlog/task-rig-alpha.md"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item beta\n' > "$rigData/board/backlog/task-rig-beta.md"
rigPair "$rigTmp/board" mdat-intern-op-headers "$( rigCall a 'DistroAgentsTools --intern-op-board-upsert-move-edit backlog task-rig-alpha.md --from-state:backlog --header:upsert:rig-word:alpha' ; rigCall b 'DistroAgentsTools --intern-op-board-upsert-move-edit backlog task-rig-beta.md --from-state:backlog --header:upsert:rig-word:beta' ; echo wait )"
rigAssert "control: both ran in subshells of one shell, stood at the read of their header changes together, and ended 0" "$( rigPairMet "$rigTmp/board" )" "1 2 0 0"
rigAssert "each item carries its own change, and not the other's" "$( rigField "$rigData/board/backlog/task-rig-alpha.md" rig-word ) $( rigField "$rigData/board/backlog/task-rig-beta.md" rig-word )" "alpha beta"
rigAssert "and no temp file is left" "$( rigLeft mdat-intern-op-headers )" "0"

echo "-- 3b. two inbox items marked processed at once --"
printf -- '---\ntype: note\n---\n\n# Rig note alpha\n' > "$rigData/inboxes/rig-member/incoming/note-rig-alpha.md"
printf -- '---\ntype: note\n---\n\n# Rig note beta\n' > "$rigData/inboxes/rig-member/incoming/note-rig-beta.md"
rigPair "$rigTmp/inbox" mdat-inbox-to-processed-headers "$( rigCall a 'DistroAgentsTools --intern-op-inbox-to-processed rig-member note-rig-alpha.md --header:upsert:rig-word:alpha' ; rigCall b 'DistroAgentsTools --intern-op-inbox-to-processed rig-member note-rig-beta.md --header:upsert:rig-word:beta' ; echo wait )"
rigAssert "control: both ran in subshells of one shell, stood at the read of their header changes together, and ended 0" "$( rigPairMet "$rigTmp/inbox" )" "1 2 0 0"
rigAssert "each item carries its own change and is marked" "$( rigField "$rigData/inboxes/rig-member/processed/note-rig-alpha.md" rig-word ) $( rigField "$rigData/inboxes/rig-member/processed/note-rig-beta.md" rig-word ) $( LC_ALL=C grep -l '^processed-at: ' "$rigData/inboxes/rig-member/processed/note-rig-alpha.md" "$rigData/inboxes/rig-member/processed/note-rig-beta.md" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' )" "alpha beta 2"
rigAssert "and no temp file is left" "$( rigLeft mdat-inbox-to-processed-headers )" "0"

echo "-- 3c. two new inbox items at once --"
rigPair "$rigTmp/upsert" mdat-intern-op-inbox-headers "$( rigCall a 'printf "rig body alpha\n" | DistroAgentsTools --intern-op-member-inbox-upsert rig-member note-rig-new-alpha.md --from-member rig-other' ; rigCall b 'printf "rig body beta\n" | DistroAgentsTools --intern-op-member-inbox-upsert rig-other note-rig-new-beta.md --from-member rig-member' ; echo wait )"
rigAssert "control: both ran in subshells of one shell, stood at the read of their headers together, and ended 0" "$( rigPairMet "$rigTmp/upsert" )" "1 2 0 0"
rigAssert "each new item names its own owner and its own sender" "$( rigField "$rigData/inboxes/rig-member/incoming/note-rig-new-alpha.md" owner ) $( rigField "$rigData/inboxes/rig-member/incoming/note-rig-new-alpha.md" from ) $( rigField "$rigData/inboxes/rig-other/incoming/note-rig-new-beta.md" owner ) $( rigField "$rigData/inboxes/rig-other/incoming/note-rig-new-beta.md" from )" "rig-member rig-other rig-other rig-member"
rigAssert "and no temp file is left" "$( rigLeft mdat-intern-op-inbox-headers )" "0"

echo "-- 3d. two board renames at once: the references each rewrites --"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item to rename, one\n' > "$rigData/board/backlog/task-rig-old-one.md"
printf -- '---\ntype: task\nowner: rig\n---\n\nrig item to rename, two\n' > "$rigData/board/backlog/task-rig-old-two.md"
printf -- '---\ntype: task\nowner: rig\n---\n\nthe first referrer names task-rig-old-one.md and nothing else\n' > "$rigData/board/backlog/task-rig-refers-one.md"
printf -- '---\ntype: task\nowner: rig\n---\n\nthe second referrer names task-rig-old-two.md and nothing else\n' > "$rigData/board/backlog/task-rig-refers-two.md"
rigPair "$rigTmp/rename" mdat-intern-op-rename "$( rigCall a 'DistroAgentsTools --intern-op-board-rename task-rig-old-one.md task-rig-new-one.md --do-not-track' ; rigCall b 'DistroAgentsTools --intern-op-board-rename task-rig-old-two.md task-rig-new-two.md --do-not-track' ; echo wait )"
rigAssert "control: both ran in subshells of one shell, stood at the read of their rewritten references together, and ended 0" "$( rigPairMet "$rigTmp/rename" )" "1 2 0 0"
rigAssert "each referrer is its own text, with the new name of the item it names" \
	"$( LC_ALL=C grep -c -x -F -- 'the first referrer names task-rig-new-one.md and nothing else' "$rigData/board/backlog/task-rig-refers-one.md" || : ) $( LC_ALL=C grep -c -x -F -- 'the second referrer names task-rig-new-two.md and nothing else' "$rigData/board/backlog/task-rig-refers-two.md" || : )" "1 1"
rigAssert "and no temp file is left" "$( rigLeft mdat-intern-op-rename )" "0"

echo "-- 3e. two emails at once: the message each sends --"
## The send as the email check runs it offline: built whole and printed, never handed to curl. The mail settings of
## the member are the rig's, and its recipient stands in its own contacts note.
mkdir -p "$rigWs/.local/.agents"
printf 'EMAIL_USER=rig@example.com\nEMAIL_APP_PASSWORD=rig-app-password\nEMAIL_SMTP_HOST=smtp.rig.invalid\nEMAIL_SMTP_PORT=587\n' > "$rigWs/.local/.agents/rig-member.agent.env"
printf '%s\n' '| slack-id | contact | handle | email | organisation | permission level |' '| --- | --- | --- | --- | --- | --- |' '| <unresolved> | rig-test | @rig-test | test@example.com | rig | unset |' \
	> "$rigData/inboxes/rig-member/incoming/note-rig-contacts.md"
rigPair "$rigTmp/mail" mdat-comms-email-message "$( rigCall a 'printf "rig body alpha\n" | DistroAgentsTools --member-comms-email-send rig-member test@example.com -- "rig subject alpha" -- --from-stdin' ; rigCall b 'printf "rig body beta\n" | DistroAgentsTools --member-comms-email-send rig-member test@example.com -- "rig subject beta" -- --from-stdin' ; echo wait )" AGENTS_EMAIL_SEND_BUILD_ONLY=true
rigAssert "control: both ran in subshells of one shell, stood at the read of their message together, and ended 0" "$( rigPairMet "$rigTmp/mail" )" "1 2 0 0"
rigAssert "each sends its own message: its subject and its body, and not the other's" \
	"$( LC_ALL=C grep -c -x -F -- 'Subject: rig subject alpha' "$rigTmp/mail/a.out" || : )$( LC_ALL=C grep -c -x -F -- 'rig body alpha' "$rigTmp/mail/a.out" || : )$( LC_ALL=C grep -c -F -- 'beta' "$rigTmp/mail/a.out" || : ) $( LC_ALL=C grep -c -x -F -- 'Subject: rig subject beta' "$rigTmp/mail/b.out" || : )$( LC_ALL=C grep -c -x -F -- 'rig body beta' "$rigTmp/mail/b.out" || : )$( LC_ALL=C grep -c -F -- 'alpha' "$rigTmp/mail/b.out" || : )" "110 110"
rigAssert "and no temp file is left" "$( rigLeft mdat-comms-email-message )" "0"

echo "-- 3f. the tracking posts of two sessions at once: the post each takes for its own --"
## The package's own function, with the post operation of this check: it says where it posted, in the lines the
## real one says it in, and stands until the other post stands there too. Both run in subshells of this one shell.
rigTrack="$rigTmp/track" ; mkdir -p "$rigTrack/ws/.local/agents/sessions"
(
	MMDAPP="$rigTrack/ws" ; export MMDAPP
	DistroAgentsTools(){
		local toolNo=0
		case "$1" in
			--agents-config-option) printf 'C0RIGTRACK\n' ;;
			--intern-op-event-track-post)
				printf 'SENT_MESSAGE_CHANNEL=C0RIGTRACK\nSENT_MESSAGE_TS=%s\n' "$rigTrackTs" >&2
				: > "$rigTrack/posted.$rigTrackTs"
				while [ "$( ls "$rigTrack" | LC_ALL=C grep -c '^posted\.' )" -lt 2 ] && [ "$toolNo" -lt 150 ] ; do toolNo=$(( toolNo + 1 )) ; sleep 0.2 ; done
			;;
		esac
		return 0
	}
	. "$rigLib/session/AgentsTools.EventTrackThread.include"
	( rigTrackTs=1111.000001 ; printf '%s\n' "$$" > "$rigTrack/a.shell" ; AgentsToolsEventTrackThreadPost rig-member "$MMDAPP/.local/agents/sessions/rig-session-a" --kind start < /dev/null ; printf '%s %s\n' "$?" "$agentsEventTrackPost" > "$rigTrack/a.result" ) &
	( rigTrackTs=2222.000002 ; printf '%s\n' "$$" > "$rigTrack/b.shell" ; AgentsToolsEventTrackThreadPost rig-other "$MMDAPP/.local/agents/sessions/rig-session-b" --kind start < /dev/null ; printf '%s %s\n' "$?" "$agentsEventTrackPost" > "$rigTrack/b.result" ) &
	wait
) > "$rigTrack/run.out" 2>&1
rigAssert "control: both posts ran in subshells of one shell and stood posted together" "$( cat "$rigTrack/a.shell" "$rigTrack/b.shell" 2> /dev/null | LC_ALL=C sort -u | LC_ALL=C awk 'END { print NR + 0 }' ) $( ls "$rigTrack" | LC_ALL=C grep -c '^posted\.' || : )" "1 2"
rigAssert "each took its own post for its own" "$( cat "$rigTrack/a.result" 2> /dev/null ) | $( cat "$rigTrack/b.result" 2> /dev/null )" "0 C0RIGTRACK:1111.000001 | 0 C0RIGTRACK:2222.000002"
rigAssert "and each session's thread is the one its own post opened" "$( cat "$rigTrack/ws/.local/agents/sessions/rig-session-a/event-track.thread" 2> /dev/null ) $( cat "$rigTrack/ws/.local/agents/sessions/rig-session-b/event-track.thread" 2> /dev/null )" "C0RIGTRACK:1111.000001 C0RIGTRACK:2222.000002"
rigAssert "and no temp file is left" "$( ls "$rigTrack/ws/.local/temp" 2> /dev/null | LC_ALL=C grep -c -F -- mdat-event-track-post || : )" "0"

echo "-- 4. the lock: a dead lock is broken, and the name it is moved to is not left behind --"
rigLock="$rigTmp/lock" ; mkdir -p "$rigLock/ws/.local/agents/locks"
## a process that has ended: its id names nobody
( exit 0 ) & rigDeadPid=$! ; wait "$rigDeadPid" 2> /dev/null
(
	MMDAPP="$rigLock/ws" ; export MMDAPP
	. "$rigLib/magic/AgentsTools.LocalLock.include"
	ln -s "$rigDeadPid" "$MMDAPP/.local/agents/locks/rig-broken"
	AgentsToolsLocalLockTake rig-broken 3 "the rig lock" 2> "$rigLock/broken.err" ; printf '%s %s\n' "$?" "$( [ "$( readlink "$MMDAPP/.local/agents/locks/rig-broken" 2> /dev/null )" = "$$" ] && echo held-by-this-shell )" > "$rigLock/broken.result"
	## the move lost to another breaker: nothing is moved, whatever the reason
	ln -s "$rigDeadPid" "$MMDAPP/.local/agents/locks/rig-lost"
	mv(){ return 1 ; }
	AgentsToolsLocalLockTake rig-lost 2 "the rig lock" 2> "$rigLock/lost.err" ; printf '%s\n' "$?" > "$rigLock/lost.result"
) > /dev/null 2>&1
rigAssert "a dead lock is broken and taken, and said" "$( cat "$rigLock/broken.result" 2> /dev/null ) $( LC_ALL=C grep -c -F -- 'broke a stale lock on the rig lock' "$rigLock/broken.err" || : )" "0 held-by-this-shell 1"
rigAssert "a breaker whose move did not happen takes nothing" "$( cat "$rigLock/lost.result" 2> /dev/null ) $( readlink "$rigLock/ws/.local/agents/locks/rig-lost" 2> /dev/null )" "1 $rigDeadPid"
rigAssert "and the lock folder holds the two locks and no other name" "$( ls "$rigLock/ws/.local/agents/locks" | LC_ALL=C tr '\n' ' ' )" "rig-broken rig-lost "

echo "-- 5. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TEMP NAMES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TEMP_NAMES: OK (%d assertions, offline)\n' "$rigPasses"
