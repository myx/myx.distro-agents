#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## rig-owner-writes.include.sh -- the one way a check of sh-test puts a file into a team-data store: it drives the
## store's owner, so a change to the store's own write contract reddens the check. A check that writes the file by
## hand keeps passing when the contract moves, and then proves nothing. Sourced by the check, after its own rig
## folders are named and before its first write:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh"
##
## WHAT IT DRIVES. The board, the inbox and the vault are written by AgentsToolsItemUpsert, the one call site every
## writer of those stores uses (sh-lib/items/AgentsTools.InternOpItem.include); a board item changes state through
## --intern-op-board-upsert-move-edit. An inbox's own folders are made where that inbox's place rule puts a new item
## (AgentsToolsInboxNotePath, sh-lib/inbox/AgentsTools.InboxPlace.include). The session and spawn stores are written by
## the session store's own functions (sh-lib/session/AgentsTools.SessionStore.include). No store path is built here,
## so a check that uses this file carries none either.
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
## A failed write is one line on stderr naming this file, so a check shows it without reading its own output.
##
## THE CALLS, each writing what it is given, and returning the owner's own status:
##   rigOwnerBoardReady                                     the board's folders, ready to be written
##   rigOwnerBoardWrite <state> <item> <format> [args...]   one board item, its content by printf
##   rigOwnerBoardPut <state> <item>                        one board item, its content on stdin
##   rigOwnerBoardMove <from-state> <to-state> <item> [header operation...]
##                                                          one board item moved, with the owner's own header operations
##   rigOwnerInboxReady <member>                            that inbox's folder, ready to be written
##   rigOwnerInboxWrite <member> <item> <format> [args...]  one inbox item
##   rigOwnerInboxPut <member> <item>                       one inbox item, its content on stdin
##   rigOwnerVaultWrite <item> <format> [args...]           one vault item
##   rigOwnerVaultPut <item>                                one vault item, its content on stdin
##   rigOwnerSpawnPut <run>                                 one spawn record, its frontmatter on stdin
##   rigOwnerSessionFolder <session>                        that session's folder, by the session store's own writer
##   rigOwnerSessionThreadSet <session> <channel:ts>        the session's Slack thread
##   rigOwnerSessionActivity <run> <line>                   the session's activity word
##   rigOwnerLogAppend <session> <line>                     one line in the session's log
##   rigOwnerCloseRun <session> <run|-> <who> <when>        the session's control/closed
## The session store's other functions are reached with `rigOwnerStore <function> [arguments...]`.
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
## (sh-lib/harness/AgentsContext.UseAgentsTools.include). It makes the folder of the item it writes and no other, as the
## writer does: a check that needs every state folder of the board calls rigOwnerBoardReady, and a check that counts the
## board's states calls neither, so the states it does not fill stay unfilled.
rigOwnerItemsCall(){ ## the call's words, what failed
	rigOwnerWrap '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
'"$1" "$2"
}

## The board's folders, made ready to be written by the owner's own AgentsToolsBoardReady, which the one board
## operation calls: a folder for each state of the board's own list. A check that moves an item into a state it never
## wrote calls this first, so the move lands.
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

## One board item moved from one state to another, its headers changed by the board's own header operations: the move
## is the one operation every board item's state change goes through, so a fixture that moves one by hand keeps a stale
## item the moment the move gains a stamp.
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
