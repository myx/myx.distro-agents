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
##   6. NO SYSTEM TEMP FOLDER, by the owner's rule, over the code of every myx.distro-* package, myx.distro-.local among them
##      (a file by its name, its shebang, or its place among the templates; in sh-lib, sh-scripts, builders, actions,
##      sh-test or wherever it stands): no line names the root temp folder (`/` then `tmp`, also under `/private` and `/var`)
##      as a path of its own, nor the temp-dir variable by its name, comments included, but a data site of the second
##      list, each with its reason; no mktemp takes `-t`, goes without a template, or takes a bare name for one (its
##      template holds a `/` or starts at a variable: under the workspace, or beside a target), comment lines aside;
##      and no python tempfile call goes without `dir=`. Every site is listed. The words are built from parts here, so
##      this file is read like every other.
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
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTempNamesCheck )" || exit 1
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
		'sh-lib/magic/AgentsTools.InternMainLoop.include|3|main-loop.config-check.last.$$|written by the main loop itself, a step after another in its own shell' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|3|pending-collect.last.$$|written by the main loop itself, a step after another in its own shell' \
		'sh-lib/magic/AgentsTools.InternMainLoop.include|3|pending-remind.last.$$|written by the main loop itself, a step after another in its own shell' \
		'sh-lib/mcp/AgentsTools.InternMcpServer.include|8|agent-mcp.$$|the scratch folder of one server process, which hands its own id to every request it serves' \
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
		'../myx.distro-.local/sh-lib/places/LocalTools.Places.include|3|$updateFile.tmp.$$|under the lock of that places registry' \
		'../myx.distro-.local/sh-lib/places/LocalTools.Places.include|3|$sharedFile.tmp.$$|under the lock of the places registry of the machine' \
		'sh-lib/team-data/AgentsTools.Registries.include|2|${3:-$$}|no file name: the asking process, this one where none is given' \
		'sh-lib/team-data/AgentsTools.Registries.include|3|$keepFile.$$.aside|the file of one run, named by its spawn id: a stop or a kill of one run is one call at a time' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|1|context.render.$$|inside the store of one session id, rendered by that session alone' \
		'sh-lib/session/AgentsTools.SessionTranscript.include|2|$addDir/tokens.$$|inside the store of one session id, added to by its one harness process, a round after another' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|1|.conversation.read.$$|inside the input folder of one sandbox, which one start fills: two fills of one sandbox share that whole folder, whatever this is named' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|1|mdat-session-run-ops.$$.$1|made its own by the process id of the console just started' \
		'sh-lib/session/AgentsTools.SpawnSandbox.include|3|$runFile.run.$$|beside one spawn record, written by the launches of that spawn, which come one after another in its own proxy' \
		'sh-lib/harness/AgentsHarnessToolsFile.include|1|.mdat-write.$$|under the write lock of that one target' \
		'sh-lib/harness/AgentsHarnessToolsFile.include|1|.mdat-edit.$$|under the write lock of that one target' \
		'sh-lib/harness/AgentsHarnessSkills.include|3|$harnessToolSearchFloorFile.$$|inside the scratch folder this harness process made for itself by mktemp'
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
( cd "$rigPackage" && find sh-lib sh-scripts builders ../myx.distro-.local/sh-lib/markdown ../myx.distro-.local/sh-lib/output ../myx.distro-.local/sh-lib/places -type f \( -name '*.sh' -o -name '*.include' -o -name '*.rc' \) | LC_ALL=C sort ) > "$rigTmp/shell-files"
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
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/held:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
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
## the member are the rig's, and its recipient is a coordinate of a contact it holds.
mkdir -p "$rigWs/.local/.agents"
printf 'EMAIL_USER=rig@example.com\nEMAIL_APP_PASSWORD=rig-app-password\nEMAIL_SMTP_HOST=smtp.rig.invalid\nEMAIL_SMTP_PORT=587\n' > "$rigWs/.local/.agents/rig-member.agent.env"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
rigContactSeed "$rigData" rig-member rig-test - test@example.com
rigPair "$rigTmp/mail" mdat-comms-email-message "$( rigCall a 'printf "rig body alpha\n" | DistroAgentsMail --email-send rig-member test@example.com -- "rig subject alpha" -- --from-stdin' ; rigCall b 'printf "rig body beta\n" | DistroAgentsMail --email-send rig-member test@example.com -- "rig subject beta" -- --from-stdin' ; echo wait )" AGENTS_EMAIL_SEND_BUILD_ONLY=true
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

echo "-- 6. no system temp folder, in any package: no path to it, no temp-dir variable, no mktemp or tempfile that falls back to it --"
## The words, from parts.
rigNoTmpRoot="/t""mp"
rigNoTmpVar="TMP""DIR"
rigNoTmpMk="mk""temp"
## THE SECOND LIST: the sites that stand, each with its reason. One line a site: package/file|how many lines hold it|
## a text of those lines|the reason. `data:` is a site where the root temp folder is data and no place anything is
## written.
rigNoTmpList(){
	printf '%s\n' \
		"myx.distro-agents/sh-test/harness/AgentsHarnessArgTableCheck.test.sh|1|\"cwd\" : \"$rigNoTmpRoot\"|data: the cwd a fixture hands the argument table, read and never written" \
		"myx.distro-agents/sh-test/harness/AgentsHarnessPermissionCheck.test.sh|2|rm -rf $rigNoTmpRoot/rig  x|data: the text of a command the permission hook records, never run" \
		"myx.distro-agents/sh-test/harness/AgentsHarnessPermissionCheck.test.sh|1|rm -rf $rigNoTmpRoot/rig x|data: the text of a command the permission hook records, never run" \
		"myx.distro-agents/sh-test/harness/AgentsWireStreamDiffCheck.test.sh|1|\"input_json_delta\",\"partial_json\"|data: a path inside a streamed tool call of a fixture, never a place written" \
		"myx.distro-agents/sh-test/harness/AgentsRunRuleReadersCheck.test.sh|1|rig-sw-ended-\$\$$rigNoTmpRoot|data: the tmp folder inside a spawn sandbox of the rig, a path of the rig and never the system's" \
		"myx.distro-.local/sh-lib/python/LocalTools.EmbeddedPython.include|1|$rigNoTmpVar=\"\$embeddedBase/tmp\"|data: the temp-dir variable handed to uv's own process, set to the tmp folder of .local/embedded-python so that uv never writes in the system's" \
		"myx.distro-agents/sh-test/mcp/AgentsMcpServerEndsHandlersCheck.test.sh|1|$rigNoTmpVar=\"\$runDir\" bash|data: the temp-dir variable handed to one spawned server, set to its own run folder under the rig's tmp so it never writes in the system's"
}
## Rule 1: the root temp folder as a path of its own -- at the start, or after anything that ends no other path (not a
## letter, digit, `_`, `.`, `}` or `)`), and not followed by a letter, digit or `_` -- or under /private or /var; or
## the variable's name as a word.
rigNoTmpPattern="(^|[^A-Za-z0-9_.})])$rigNoTmpRoot([^A-Za-z0-9_]|\$)|/private$rigNoTmpRoot([^A-Za-z0-9_]|\$)|/var$rigNoTmpRoot([^A-Za-z0-9_]|\$)|(^|[^A-Za-z0-9_])$rigNoTmpVar([^A-Za-z0-9_]|\$)"
## Rule 2: each mktemp in the place of a command -- at the start of a line, or after `$(`, `(`, a backtick, `;`, `|`,
## `&`, `=`, `then`, `do` or `exec` -- read to the end of its command, its words split at blanks. A site where a word
## ahead of the template is an option holding `t`, where there is no template, or where the template holds no `/` and
## starts at no variable. Comment lines are prose, and are not read for it. The files are given after the word.
rigNoTmpMkReader="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-mktemp-sites.py"
## Rule 3: a python tempfile call with no `dir=` on its line.
rigNoTmpPy="tempfile\.(gettempdir|mkstemp|mkdtemp|$rigNoTmpMk|NamedTemporaryFile|TemporaryFile|TemporaryDirectory|SpooledTemporaryFile)\("
## The files read, as package/path: every file of every myx.distro-* package that is code by its name or its shebang, and
## every template, the .git folders and the generated __pycache__ folders left out.
rigNoTmpOrigin="$MDLT_ORIGIN/myx"
( cd "$rigNoTmpOrigin" && ls -d myx.distro-* ) | while IFS= read -r rigNoTmpPkg ; do
	( cd "$rigNoTmpOrigin/$rigNoTmpPkg" && find . -type f ! -path './.git/*' ! -path '*/__pycache__/*' 2> /dev/null | LC_ALL=C sort ) | while IFS= read -r rigNoTmpRel ; do
		rigNoTmpRel="${rigNoTmpRel#./}"
		case "$rigNoTmpRel" in
			sh-lib/templates/*|*.sh|*.include|*.rc|*.py|*.awk) printf '%s/%s\n' "$rigNoTmpPkg" "$rigNoTmpRel" ;;
			*) [ "$( head -c 2 "$rigNoTmpOrigin/$rigNoTmpPkg/$rigNoTmpRel" 2> /dev/null )" != '#!' ] || printf '%s/%s\n' "$rigNoTmpPkg" "$rigNoTmpRel" ;;
		esac
	done
done > "$rigTmp/notmp-files"
( cd "$rigNoTmpOrigin" && LC_ALL=C tr '\n' '\0' < "$rigTmp/notmp-files" | xargs -0 grep -n -H -E -- "$rigNoTmpPattern" 2> /dev/null ) > "$rigTmp/notmp-root"
( cd "$rigNoTmpOrigin" && LC_ALL=C tr '\n' '\0' < "$rigTmp/notmp-files" | xargs -0 python3 -I -B "$rigNoTmpMkReader" "$rigNoTmpMk" 2> /dev/null ) > "$rigTmp/notmp-mktemp"
( cd "$rigNoTmpOrigin" && LC_ALL=C tr '\n' '\0' < "$rigTmp/notmp-files" | xargs -0 grep -n -H -E -- "$rigNoTmpPy" 2> /dev/null | LC_ALL=C grep -v -F 'dir=' ) > "$rigTmp/notmp-python"
## The sites of the three rules against the second list: each site a line of the list takes is no site; every line of the
## list that takes another number of sites than it says is said.
rigNoTmpList > "$rigTmp/notmp-list"
rigNoTmpGuard(){ ## list file, sites file
	LC_ALL=C awk -F'|' '
		FILENAME == ARGV[1] {
			if ( NF != 4 || $2 !~ /^[0-9]+$/ || $3 == "" || length( $4 ) < 20 ) { print "LIST: not `file|lines|text|reason`: " $0 ; next ; }
			n++ ; lFile[n] = $1 ; lWant[n] = $2 + 0 ; lText[n] = $3 ; lGot[n] = 0 ; next ;
		}
		{
			siteFile = substr( $0, 1, index( $0, ":" ) - 1 ) ; taken = 0 ;
			for ( i = 1 ; i <= n && !taken ; i++ ) if ( lFile[i] == siteFile && index( $0, lText[i] ) ) { lGot[i]++ ; taken = 1 ; }
			if ( !taken ) print "SITE: " $0 ;
		}
		END { for ( i = 1 ; i <= n ; i++ ) if ( lGot[i] != lWant[i] ) print "LIST: " lFile[i] " holds `" lText[i] "` on " lGot[i] " line(s), the list says " lWant[i] ; }
	' "$1" "$2"
}
LC_ALL=C cat "$rigTmp/notmp-root" "$rigTmp/notmp-mktemp" "$rigTmp/notmp-python" > "$rigTmp/notmp-sites"
rigNoTmpGuard "$rigTmp/notmp-list" "$rigTmp/notmp-sites" > "$rigTmp/notmp-left"
rigNoTmpSiteLeft="$( LC_ALL=C grep -c '^SITE: ' "$rigTmp/notmp-left" )"
rigNoTmpListLeft="$( LC_ALL=C grep -c '^LIST: ' "$rigTmp/notmp-left" )"
rigNoTmpMissing=""
for rigNoTmpPkg in $( cd "$rigNoTmpOrigin" && ls -d myx.distro-* ) ; do
	[ "$( LC_ALL=C grep -c "^$rigNoTmpPkg/" "$rigTmp/notmp-files" )" -gt 0 ] || rigNoTmpMissing="$rigNoTmpMissing $rigNoTmpPkg"
done
rigAssert "control: the code of every myx.distro-* package is read, myx.distro-.local among them" \
	"$( [ "$( LC_ALL=C grep -c . "$rigTmp/notmp-files" )" -ge 400 ] && echo many ) [${rigNoTmpMissing# }] $( LC_ALL=C grep -c -x -F -e 'myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh' -e 'myx.distro-agents/sh-test/config/AgentsTempNamesCheck.test.sh' -e 'myx.distro-deploy/sh-scripts/InstallPrepareFiles.fn.sh' -e 'myx.distro-source/sh-scripts/RebuildActions.fn.sh' -e 'myx.distro-system/sh-lib/DistroImage.SyncScriptMaker.include' "$rigTmp/notmp-files" )" "many [] 5"
printf '%s\n' "x=$rigNoTmpRoot/a" "y=\"$rigNoTmpRoot\"" "z=\${$rigNoTmpVar:-$rigNoTmpRoot}" "w=/private$rigNoTmpRoot/b" "v=\$$rigNoTmpVar/c" > "$rigTmp/notmp-probe.sites"
printf '%s\n' "x=\$rigTmp/a" "y=\"\$dir$rigNoTmpRoot\"" "z=\${base}$rigNoTmpRoot/b" "w=.local/temp/c" "v=${rigNoTmpVar}X" "u=$rigNoTmpRoot""file" > "$rigTmp/notmp-probe.clean"
printf '%s\n' "a=\"\$( $rigNoTmpMk -d -t RigName )\"" "b=\$($rigNoTmpMk)" "c=\"\$( $rigNoTmpMk -d )\"" "$rigNoTmpMk -dt RigName" "d=\"\$( $rigNoTmpMk rig.XXXXXX )\"" > "$rigTmp/notmp-probe.mk"
printf '%s\n' "a=\"\$( $rigNoTmpMk -d \"\$MMDAPP/.local/temp/RigName.XXXXXX\" )\"" "b=\"\$( $rigNoTmpMk \"\$target.XXXXXX\" )\"" "c=\$($rigNoTmpMk -d \"\${rigTmp}/x.XXXX\")" "## made by $rigNoTmpMk -t in prose" "echo \"$rigNoTmpMk failed\"" > "$rigTmp/notmp-probe.mkclean"
rigAssert "control: each matcher finds the five sites of a probe that has them, and none in one that has not" \
	"$( LC_ALL=C grep -c -E -- "$rigNoTmpPattern" "$rigTmp/notmp-probe.sites" ):$( LC_ALL=C grep -c -E -- "$rigNoTmpPattern" "$rigTmp/notmp-probe.clean" ) $( python3 -I -B "$rigNoTmpMkReader" "$rigNoTmpMk" "$rigTmp/notmp-probe.mk" | LC_ALL=C grep -c . ):$( python3 -I -B "$rigNoTmpMkReader" "$rigNoTmpMk" "$rigTmp/notmp-probe.mkclean" | LC_ALL=C grep -c . )" "5:0 5:0"
printf '%s\n' "rig/Probe.sh|1|probe text|a reason long enough to stand in a control" > "$rigTmp/notmp-probe.list"
printf '%s\n' "rig/Probe.sh:3:a line of the probe text" "rig/Probe.sh:4:a line the list does not hold" > "$rigTmp/notmp-probe.found"
rigAssert "control: a site the list holds is no site, one it does not hold is said, and a line of the list that takes no site is said" \
	"$( rigNoTmpGuard "$rigTmp/notmp-probe.list" "$rigTmp/notmp-probe.found" | LC_ALL=C tr '\n' '~' )" "SITE: rig/Probe.sh:4:a line the list does not hold~"
rigAssert "no line of any package names the root temp folder or the variable, no mktemp takes -t, goes without a template or takes a bare name, and no python tempfile call goes without dir=, but the sites of the second list" "$rigNoTmpSiteLeft" "0"
rigAssert "every line of the second list takes as many sites as it says" "$rigNoTmpListLeft" "0"
[ "$rigNoTmpSiteLeft" -eq 0 ] || { echo "-- the sites --" ; LC_ALL=C grep '^SITE: ' "$rigTmp/notmp-left" | LC_ALL=C cut -c1-260 | LC_ALL=C sed -e 's/^/  /' ; }
[ "$rigNoTmpListLeft" -eq 0 ] || { echo "-- the list --" ; LC_ALL=C grep '^LIST: ' "$rigTmp/notmp-left" | LC_ALL=C sed -e 's/^/  /' ; }

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TEMP NAMES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TEMP_NAMES: OK (%d assertions, offline)\n' "$rigPasses"
