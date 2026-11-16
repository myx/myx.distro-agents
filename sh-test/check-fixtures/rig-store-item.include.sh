#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## A check builds a fixture item of a team-data store through the store's own owner, never by hand: the board, a
## member's inbox, the vault and the audit are written by AgentsToolsItemUpsert, the write every item operation of the
## tooling goes through (AgentsTools.InternOpItem.include), and an inbox item that stands in processed/ is put there by
## --mark-inbox-processed, the operation that stamps and moves it. A hand-written fixture stays green when those writes'
## own file contracts change, so it proves nothing about the code the check is meant to hold.
##
##   . "$rigPkg/sh-test/check-fixtures/rig-store-item.include.sh" || exit 1
##   rigStoreItem "$rigTmp" "$rigData" "$rigWs" rig-member "board running task-x.md" "$rigTmp/body1" || rigRefuse "..."
##
## The selector is the owner's own, in its words: `board <state> <item>`, `inbox <member> <item>`,
## `inbox-processed <member> <item>`, `vault <item>`, `audit <item>`. The body comes from a file of the rig's own --
## the owner writes an item's content as given, so an item the check wants faulty is written faulty -- and the call's
## standard input carries the snippet that reaches the owner. The owner makes the item's folder, and it commits only
## where the store root is a repository. Words after the body file go to the operation as given.
##
## A caller that has members of its own hands their skillset root over in rigStoreSkills, for the one operation that reads
## it (--mark-inbox-processed). Empty, and no member is looked up.
##
## The workspace and the store are both held inside the rig's own folder, or are that folder: one outside it is refused
## before anything
## is written. Silent on success; on a failure it says what the owner said, so a fixture that could not be built stops
## the check instead of leaving it green over a store nobody wrote.
##

rigStoreSkills="${rigStoreSkills:-}"

## One item of a store, written through the store's own operations: rig root, data root, workspace, acting member, the
## item's selector, the body file, and any further words of the operation.
rigStoreItem(){ ## rig root, data root, workspace, member, selector, body file, [operation words...]
	local itemRig="$1" itemData="$2" itemWs="$3" itemMember="$4" itemSelect="$5" itemBody="$6"
	local itemExtra="${7:-}" itemFlags="" itemMark="" itemOut="" itemState="" itemName=""
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
	## The one operation that moves an item to processed/ resolves the member it acts for from the workspace's own
	## members folder: the rig stands that member up, as the workspace set-up does, and nothing of the store is written.
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

## The board's state folders, made by the board's own ready step (AgentsToolsBoardReady, the one call every board write
## and the workspace set-up make): rig root, data root, workspace.
rigStoreBoardReady(){ ## rig root, data root, workspace
	local readyOut=""
	case "$3/" in "$1"/*) ;; *) echo "⛔ ERROR: rigStoreBoardReady: workspace outside the rig: $3" >&2 ; return 1 ;; esac
	case "$2/" in "$1"/*) ;; *) echo "⛔ ERROR: rigStoreBoardReady: store outside the rig: $2" >&2 ; return 1 ;; esac
	readyOut="$( cd "$3" || exit 1
	  env -i MDAT_WORKSPACE_MODE=team-rig HOME="$3" PATH="/usr/bin:/bin" MMDAPP="$3" MDAT_DATA_ROOT="$2" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute 2>&1 <<< \
			". \"$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include\" && AgentsToolsBoardReady"
	)" || { echo "⛔ ERROR: rigStoreBoardReady: the board's own ready step failed: $readyOut" >&2 ; return 1 ; }
	return 0
}
