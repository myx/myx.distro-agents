#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## rig-owner-writes.include.sh -- the one way a check of sh-test puts a file into a team-data store: it drives the
## store's owner, so a change to the store's own write contract reddens the check. A check that writes the file by
## hand keeps passing when the contract moves, and then proves nothing.
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh"
##
## WHAT IT DRIVES. The board, the inbox and the vault are written by AgentsToolsItemUpsert, the one call site every
## writer of those stores uses (sh-lib/items/AgentsTools.InternOpItem.include); a board item changes state through
## --intern-op-board-upsert-move-edit. A folder is made by the concern that owns it: the board's by
## AgentsToolsBoardReady, an inbox's by AgentsToolsInboxReady. The session and spawn stores are written by the session
## store's own functions (sh-lib/session/AgentsTools.SessionStore.include). No store path is built here.
##
## WHERE IT WRITES, resolved at each call from the check's own rig variables, and overridable one by one:
##   rigOwnerWs        the rig workspace (MMDAPP),                 rigWs
##   rigOwnerData      the rig's team-data root (MDAT_DATA_ROOT), rigData
##   rigOwnerHome      the rig's HOME,                            rigHome
##   rigOwnerSkills    the rig's skillset root,                   rigSkills (unset where the rig has none)
##   rigOwnerOrigin    the tooling origin (MDLT_ORIGIN),          rigOrigin, else $MDLT_ORIGIN
##   rigOwnerMember    the acting member (MDAT_SPAWN_AGENT),      rigAs, else rig-member
##   rigOwnerPath      the PATH a write runs under,               /usr/bin:/bin:/usr/sbin:/sbin
##   rigOwnerLog       the owner's own account of a write,        /dev/null
##
## THE CALLS, each returning the owner's own status:
##   rigOwnerBoardReady                                     the board's folders, ready to be written
##   rigOwnerBoardPut <state> <item>                        one board item, its content on stdin
##   rigOwnerBoardWrite <state> <item> <format> [args...]   one board item, its content by printf
##   rigOwnerBoardMove <from-state> <to-state> <item> [header operation...]
##   rigOwnerBoardLegacyPut <item>                       one pending item as old data left it, its content on stdin
##   rigOwnerInboxReady <member>                            that inbox's folder, ready to be written
##   rigOwnerInboxPut <member> <item>                       one inbox item, its content on stdin
##   rigOwnerInboxWrite <member> <item> <format> [args...]  one inbox item, its content by printf
##   rigOwnerInboxPutHandled <member> <item> <stamp>        one already-handled inbox item, in processed/
##   rigOwnerVaultPut <item> / rigOwnerVaultWrite <item> <format> [args...]     one vault item
##   rigOwnerSpawnPut <run>                                 one spawn record, its frontmatter on stdin
##   rigOwnerSessionFolder <session>                        that session's folder, by the session store's own writer
##   rigOwnerSessionThreadSet <session> <channel:ts>        the session's Slack thread
##   rigOwnerSessionActivity <run> <line>                   the session's activity word
##   rigOwnerLogAppend <session> <line>                     one line in the session's log
##   rigOwnerCloseRun <session> <run|-> <who> <when>        the session's control/closed
##   rigOwnerStore <function> [arguments...]                any other function of the session store
##   rigBoardStates <data-root> <state>...                  the folders of those states
##   rigInboxReady <data-root> <member>...                  the folders of those inboxes
##   rigStoreItem <data-root> <board|inbox> <state|member> <item>              the item's text on stdin
##   rigStoreItem <rig root> <data root> <ws> <member> <selector> <body file> [operation words...]
##                                                          one item from a body file, the selector in the owner's
##                                                          own words: `board <state> <item>`, `inbox <member> <item>`,
##                                                          `inbox-processed <member> <item>`, `vault <item>`,
##                                                          `audit <item>`
## A failed write is one line on stderr naming this file, so a check shows it without reading its own output.
##

## One value of the rig, in this order: the name this file takes, the check's own rig variable, a default.
rigOwnerOf(){ ## variable, rig-variable, default
	local ownerName="$1" ownerRigName="$2" ownerFallback="${3:-}"
	if [ -n "${!ownerName:-}" ] ; then printf '%s' "${!ownerName}" ; return 0 ; fi
	if [ -n "$ownerRigName" ] && [ -n "${!ownerRigName:-}" ] ; then printf '%s' "${!ownerRigName}" ; return 0 ; fi
	printf '%s' "$ownerFallback"
}

## The one environment a store write runs under: the rig's own, never the check's.
rigOwnerWrap(){ ## snippet, what failed -- the write's status
	local ownerWs ownerData ownerHome ownerSkills ownerOrigin ownerMember ownerPath ownerLog
	ownerWs="$( rigOwnerOf rigOwnerWs rigWs )"
	ownerData="$( rigOwnerOf rigOwnerData rigData )"
	ownerHome="$( rigOwnerOf rigOwnerHome rigHome "$ownerData" )"
	ownerSkills="$( rigOwnerOf rigOwnerSkills rigSkills )"
	ownerOrigin="$( rigOwnerOf rigOwnerOrigin rigOrigin "${MDLT_ORIGIN:-}" )"
	ownerMember="$( rigOwnerOf rigOwnerMember rigAs rig-member )"
	ownerPath="$( rigOwnerOf rigOwnerPath "" '/usr/bin:/bin:/usr/sbin:/sbin' )"
	ownerLog="$( rigOwnerOf rigOwnerLog "" '/dev/null' )"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$ownerHome" PATH="$ownerPath" \
		MMDAPP="$ownerWs" MDAT_DATA_ROOT="$ownerData" ${ownerSkills:+MDAT_SKILLSET_ROOT="$ownerSkills"} \
		MDLT_ORIGIN="$ownerOrigin" "MDLT_OPTION=--run-from-path $ownerOrigin" MDAT_SPAWN_AGENT="$ownerMember" \
		bash -c "$1" >> "$ownerLog" 2>&1 || {
		echo "⛔ ERROR: rig-owner-writes: the owner could not $2; its own account is in $ownerLog" >&2 ; return 1 ; }
}

## One call of the item writer of the board, the inbox and the vault, in the rig's own environment. The operations
## context is taken first, as every caller of the item writer takes it: the writer's own name checks come from there
## (sh-lib/harness/AgentsContext.UseAgentsTools.include). It makes the folder of the item it writes and no other: a
## check that needs every state folder of the board calls rigOwnerBoardReady, and a check that counts the board's
## states calls neither, so the states it does not fill stay unfilled.
rigOwnerItemsCall(){ ## the call's words, what failed
	rigOwnerWrap '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
'"$1" "$2"
}

## The board's folders, made ready to be written by the owner's own AgentsToolsBoardReady: a folder for each state of
## the board's own list. A check that moves an item into a state it never wrote calls this first, so the move lands.
rigOwnerBoardReady(){
	rigOwnerWrap '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 1
AgentsToolsBoardReady' "make the board ready to be written"
}

rigOwnerBoardPut(){ ## state, item -- the item's content on stdin
	rigOwnerItemsCall "AgentsToolsItemUpsert \"\$MDAT_SPAWN_AGENT\" --from-board '$1' '$2' --upsert-from-stdin --context rig" "write board/$1/$2"
}

rigOwnerBoardWrite(){ ## state, item, format, arguments...
	local ownerState="$1" ownerItem="$2" ownerFormat="$3"
	shift 3
	[ "$ownerFormat" != "--" ] || { ownerFormat="${1:-}" ; shift || true ; }
	printf -- "$ownerFormat" "$@" | rigOwnerBoardPut "$ownerState" "$ownerItem"
}

## A pending item the writers no longer produce, for a reader's handling of old data: a recheck-date beside no unmet `condition:`.
## Every writer into board-pending drops that date (AgentsToolsRecheckPendingBody), so the owner writes the item into
## board-blocked and the file is moved into board-pending.
rigOwnerBoardLegacyPut(){ ## item -- the item's content on stdin
	local legacyData
	legacyData="$( rigOwnerOf rigOwnerData rigData )"
	rigOwnerBoardPut blocked "$1" || return 1
	mkdir -p "$legacyData/board/pending" && mv -f "$legacyData/board/blocked/$1" "$legacyData/board/pending/$1"
}

## One board item moved from one state to another, its headers changed by the board's own header operations: the move
## is the one operation every board item's state change goes through.
rigOwnerBoardMove(){ ## from-state, to-state, item, header operation...
	local ownerFrom="$1" ownerTo="$2" ownerItem="$3" ownerCall ownerHeader
	shift 3
	ownerCall="bash \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh\" --intern-op-board-upsert-move-edit '$ownerTo' '$ownerItem' --from-state:'$ownerFrom' --context rig"
	for ownerHeader in "$@" ; do ownerCall="$ownerCall --header:$ownerHeader" ; done
	rigOwnerWrap "printf '{ print ; }\n' | $ownerCall" "move board/$ownerFrom/$ownerItem to $ownerTo"
}

rigOwnerInboxReady(){ ## member -- that inbox's folder, made where the inbox's own place rule puts a new item
	rigOwnerWrap '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/inbox/AgentsTools.InboxPlace.include" || exit 1
mkdir -p "$( dirname "$( AgentsToolsInboxNotePath "'"$1"'" note-rig-placeholder.md )" )"' "make the inbox of $1 ready to be written"
}

rigOwnerInboxPut(){ ## member, item -- the item's content on stdin
	rigOwnerItemsCall "AgentsToolsItemUpsert \"\$MDAT_SPAWN_AGENT\" --from-inbox '$1' '$2' --upsert-from-stdin --context rig" "write inboxes/$1/$2"
}

rigOwnerInboxWrite(){ ## member, item, format, arguments...
	local ownerMember="$1" ownerItem="$2" ownerFormat="$3"
	shift 3
	[ "$ownerFormat" != "--" ] || { ownerFormat="${1:-}" ; shift || true ; }
	printf -- "$ownerFormat" "$@" | rigOwnerInboxPut "$ownerMember" "$ownerItem"
}

## An item put in an inbox reaches incoming/ whatever its body says: the store places it by its own answer, not by
## the text a caller handed it. So a handled item is the write, then the mark, and this is that pair as one form.
## The commit is taken here rather than handed to the team-data thread, as rigStoreItem's own call does, so a check
## reads the commit it caused.
rigOwnerInboxPutHandled(){ ## member, item, stamp -- the item's content on stdin
	local ownerMember="$1" ownerItem="$2" ownerStamp="$3"
	rigOwnerInboxPut "$ownerMember" "$ownerItem" || return 1
	rigOwnerWrap "MDAT_TEAM_DATA_COMMIT_THREAD=off bash \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh\" --mark-inbox-processed --team-member '$ownerMember' '$ownerItem' --header:$( printf '%q' "upsert:processed-at:$ownerStamp" )" \
		"mark inboxes/$ownerMember/$ownerItem handled"
}

rigOwnerVaultPut(){ ## item -- the item's content on stdin
	rigOwnerItemsCall "AgentsToolsItemUpsert \"\$MDAT_SPAWN_AGENT\" --from-vault '$1' --upsert-from-stdin --context rig" "write vault/$1"
}

rigOwnerVaultWrite(){ ## item, format, arguments...
	local ownerItem="$1" ownerFormat="$2"
	shift 2
	[ "$ownerFormat" != "--" ] || { ownerFormat="${1:-}" ; shift || true ; }
	printf -- "$ownerFormat" "$@" | rigOwnerVaultPut "$ownerItem"
}

## The session store's own functions, sourced for this shell: its writers, never a hand-built file under a session's
## or a spawn's folder.
rigOwnerStoreFns(){
	local ownerOrigin
	ownerOrigin="$( rigOwnerOf rigOwnerOrigin rigOrigin "${MDLT_ORIGIN:-}" )"
	type AgentsSpawnRecordWrite > /dev/null 2>&1 || . "$ownerOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.include" || return 1
	MMDAPP="$( rigOwnerOf rigOwnerWs rigWs )"
}

rigOwnerStore(){ ## function and arguments -- the function's own status
	rigOwnerStoreFns || return 1
	"$@"
}

rigOwnerSpawnPut(){ ## run -- its frontmatter on stdin
	rigOwnerStore AgentsSpawnRecordWrite "$1"
}

rigOwnerSessionFolder(){ ## session -- its folder, made by the session store's own thread writer
	rigOwnerStore AgentsSessionThreadSet "$1" "${rigOwnerThread:-RIG00000:1700000000.000000}"
}

rigOwnerSessionThreadSet(){ ## session, channel:ts
	rigOwnerStore AgentsSessionThreadSet "$1" "$2"
}

rigOwnerSessionActivity(){ ## run, line
	rigOwnerStore AgentsSessionActivityWrite "$1" "$2"
}

rigOwnerLogAppend(){ ## session, line
	rigOwnerStore AgentsSessionLogAppend "$1" "$2"
}

rigOwnerCloseRun(){ ## session, run (`-` for the session itself), who, when
	rigOwnerStore AgentsSessionCloseRun "$1" "$2" "$3" "$4"
}

## The checked guard of the narrower calls: a check's store lies in the check's own workspace, and never in the live store.
rigStoreIsRig(){ ## data-root
	local isData="${1:-}"
	[ -n "$isData" ] && [ -n "${MMDAPP:-}" ] || return 1
	case "$isData" in
		"${MMDAPP%/}/.local/agents/team-data-root") return 0 ;;
		"${MMDAPP%/}/.local/"?*) return 0 ;;
		"${MMDAPP%/}/"?*/.local/?*) return 0 ;;
		"${MMDAPP%/}/"?*/.local/agents/team-data-root) return 0 ;;
	esac
	echo "⛔ ERROR: rig-owner-writes: $isData is no check's store -- a rig's store stands in ${MMDAPP:-<no MMDAPP>}/.local/, never in the team data" >&2
	return 1
}

## One call of an owner, in an environment of its own: the data root, and the shell text, which reads its own arguments.
## What it printed.
rigStoreRun(){ ## data-root, shell text, argument...
	local storeRc=0 storeOut="" storeData="$1" storeText="$2" storeWs
	shift 2
	storeWs="$( rigStoreWorkspace "$storeData" )"
	mkdir -p "$storeWs/.local/temp" "$storeWs/.local/agents/members" || return 1
	storeOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$storeWs/.local/temp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		GIT_CONFIG_NOSYSTEM=1 "MMDAPP=$storeWs" "MDAT_DATA_ROOT=$storeData" \
		"MDLT_ORIGIN=${MDLT_ORIGIN:?rig-owner-writes: MDLT_ORIGIN is not set}" \
		"MDLT_OPTION=--run-from-path ${MDLT_ORIGIN}" \
		"MDAT_SKILLSET_ROOT=$storeWs/.local/agents/members" \
		MDAT_SPAWN_AGENT=rig-fixture MDAT_SESSION_ID=rig-fixture \
		bash -c "$storeText" rig "$@" 2>&1 )" || storeRc=$?
	[ "$storeRc" -eq 0 ] || { printf '%s\n' "$storeOut" | LC_ALL=C grep -v '^#' >&2 ; return 1 ; }
	printf '%s\n' "$storeOut" | LC_ALL=C grep -v '^#' || :
}

## The workspace one call of an owner runs in: the store's own where the store is a workspace's, else a folder beside it.
rigStoreWorkspace(){ ## data-root
	local wsData="$1"
	case "$wsData" in
		*/.local/agents/team-data-root) printf '%s\n' "${wsData%/.local/agents/team-data-root}" ;;
		*) printf '%s\n' "${wsData%/*}/.owner-ws" ;;
	esac
}

## The state folders of the board, made by the board's own maker: those named, or every state of the one list when none
## is named.
rigBoardStates(){ ## data-root, state...
	local readyData="$1" readyAll=""
	shift
	rigStoreIsRig "$readyData" || return 1
	for readyState in "$@" ; do readyAll="$readyAll $readyState" ; done
	rigStoreRun "$readyData" '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 1
		AgentsToolsBoardReady "$@" || exit 1
	' ${readyAll:+$readyAll} > /dev/null
}

## The folders of an inbox, made by the inbox's own maker.
rigInboxReady(){ ## data-root, member...
	local readyData="$1" readyMember readyAll=""
	shift
	rigStoreIsRig "$readyData" || return 1
	for readyMember in "$@" ; do readyAll="$readyAll $readyMember" ; done
	[ -n "$readyAll" ] || return 0
	rigStoreRun "$readyData" '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/inbox/AgentsTools.InboxPlace.include" || exit 1
		for readyOne in "$@" ; do AgentsToolsInboxReady "$readyOne" || exit 1 ; done
	' $readyAll > /dev/null
}

rigStoreSkills="${rigStoreSkills:-}"

## One item of a store, written through the store's own writes. The narrow form takes the item's text on stdin; the wide
## form takes a body file, the workspace and the member, and the check's own rig root for its guard.
rigStoreItem(){ ## see the two forms in this file's header
	local itemRig itemData itemWs itemMember itemSelect itemBody itemExtra itemFlags itemMark itemOut putWhere putPlace putName
	case "$#" in
		4)
			putWhere="$2" ; putPlace="$3" ; putName="$4"
			case "$putWhere" in board|inbox) ;; *) echo "⛔ ERROR: rig-owner-writes: no such store: $putWhere -- it is board or inbox" >&2 ; return 1 ;; esac
			rigStoreIsRig "$1" || return 1
			rigStoreRun "$1" '
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" || exit 1
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
				AgentsToolsItemUpsert rig-fixture --from-"$1" "$2" "$3" --upsert-from-stdin --context rig-owner-writes || exit 1
			' "$putWhere" "$putPlace" "$putName" > /dev/null
			return $?
		;;
		6|7) ;;
		*) echo "⛔ ERROR: rig-owner-writes: rigStoreItem takes 4 words, or 6 with a body file; it was given $#" >&2 ; return 1 ;;
	esac
	itemRig="$1" itemData="$2" itemWs="$3" itemMember="$4" itemSelect="$5" itemBody="$6"
	itemExtra="${7:-}" itemFlags="" itemMark=""
	case "$itemWs/" in "$itemRig"/*) ;; *) echo "⛔ ERROR: rigStoreItem: workspace outside the rig: $itemWs" >&2 ; return 1 ;; esac
	case "$itemData/" in "$itemRig"/*) ;; *) echo "⛔ ERROR: rigStoreItem: store outside the rig: $itemData" >&2 ; return 1 ;; esac
	[ -f "$itemBody" ] || { echo "⛔ ERROR: rigStoreItem: no body file at $itemBody" >&2 ; return 1 ; }
	case "$itemSelect" in
		board\ *) set -- ${itemSelect#board } ; itemFlags="--from-board $1 $2" ;;
		inbox\ *) set -- ${itemSelect#inbox } ; itemFlags="--from-inbox $1 $2" ;;
		inbox-processed\ *) set -- ${itemSelect#inbox-processed } ; itemFlags="--from-inbox $1 $2" ; itemMark="$1 $2" ;;
		vault\ *) itemFlags="--from-vault ${itemSelect#vault }" ;;
		audit\ *) itemFlags="--from-audit ${itemSelect#audit }" ;;
		*) echo "⛔ ERROR: rigStoreItem: no such store: $itemSelect" >&2 ; return 1 ;;
	esac
	itemOut="$( cd "$itemWs" || exit 1
	  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$itemWs" PATH="/usr/bin:/bin" MMDAPP="$itemWs" \
		MDAT_DATA_ROOT="$itemData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		${rigStoreSkills:+MDAT_SKILLSET_ROOT="$rigStoreSkills"} \
		MDAT_SPAWN_AGENT="$itemMember" MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute 2>&1 <<< \
			". \"$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include\" && AgentsToolsItemUpsert $itemMember $itemFlags --from-file \"$itemBody\" --no-push --context rig-fixture $itemExtra"
	)" || { echo "⛔ ERROR: rigStoreItem: the owner did not write $itemSelect: $itemOut" >&2 ; return 1 ; }
	[ -n "$itemMark" ] || return 0
	set -- $itemMark
	[ -d "$itemWs/.local/agents/members/$1" ] || {
		mkdir -p "$itemWs/.local/agents/members/$1" || { echo "⛔ ERROR: rigStoreItem: could not stand the member $1 up" >&2 ; return 1 ; }
		printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$itemWs/.local/agents/members/$1/$1.basic.md"
	}
	itemOut="$( cd "$itemWs" || exit 1
	  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$itemWs" PATH="/usr/bin:/bin" MMDAPP="$itemWs" \
		MDAT_DATA_ROOT="$itemData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		${rigStoreSkills:+MDAT_SKILLSET_ROOT="$rigStoreSkills"} \
		MDAT_SPAWN_AGENT="$1" MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh" --mark-inbox-processed --team-member "$1" "$2"
	)" 2>&1 || { echo "⛔ ERROR: rigStoreItem: the inbox item was written but not marked processed: $itemOut" >&2 ; return 1 ; }
	return 0
}
