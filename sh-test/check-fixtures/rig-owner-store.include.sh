#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## rig-owner-store.include.sh -- the one way a check of sh-test makes a store, and puts an item into
## it: through the concern that owns the store, never by hand. A store made or written by hand carries
## the shape the check chose, so the check stays green when the store's own file contract moves, and
## the fixture and the code under test drift apart in silence. Sourced by the check, or by
## rig-temp.include.sh for every check that takes its rig from there:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-store.include.sh"
##
##   rigBoardStates <data-root> <state>...
##     the folders of those states, made by AgentsToolsBoardStateReady, the board concern's own maker
##     (sh-lib/board/AgentsTools.BoardStates.include).
##   rigInboxReady <data-root> <member>...
##     the folders of those inboxes, made by AgentsToolsInboxReady, the inbox concern's own maker
##     (sh-lib/inbox/AgentsTools.InboxPlace.include).
##   rigStoreItem <data-root> <board|inbox> <state|member> <item-name>      the item's text on stdin
##     one item, written by AgentsToolsItemUpsert (sh-lib/items/AgentsTools.InternOpItem.include), the
##     one call every writer of a store item makes. Silent on success, so it takes the text a command
##     prints: `printf ... | rigStoreItem "$rigData" board running task-rig.md`. The content is the
##     item's whole text, frontmatter included, written exactly as given. An inbox item's folder is
##     the owner's own answer, from its name and its processed stamp.
##
## THE WORKSPACE THE OWNER CALL RUNS IN is this helper's own, never the check's: a folder beside the
## store, inside the rig, so a rig's store is written and never this machine's team data. A store at
## `<ws>/.local/agents/team-data-root` is that workspace's own, and is written as that workspace.
## Each call works in an environment of its own, so no variable of the check reaches the store.
##

## The checked guard: a check's store lies in the check's own workspace, and never in the live store.
rigStoreIsRig(){ ## data-root
	local isData="${1:-}"
	[ -n "$isData" ] && [ -n "${MMDAPP:-}" ] || return 1
	case "$isData" in
		"${MMDAPP%/}/.local/agents/team-data-root") return 0 ;;
		"${MMDAPP%/}/.local/"?*) return 0 ;;
		"${MMDAPP%/}/"?*/.local/?*) return 0 ;;
		"${MMDAPP%/}/"?*/.local/agents/team-data-root) return 0 ;;
	esac
	echo "⛔ ERROR: rig-owner-store: $isData is no check's store -- a rig's store stands in ${MMDAPP:-<no MMDAPP>}/.local/, never in the team data" >&2
	return 1
}

## The workspace one call of an owner runs in: the store's own where the store is a workspace's, else a
## folder beside it.
rigStoreWorkspace(){ ## data-root
	local wsData="$1"
	case "$wsData" in
		*/.local/agents/team-data-root) printf '%s\n' "${wsData%/.local/agents/team-data-root}" ;;
		*) printf '%s\n' "${wsData%/*}/.owner-ws" ;;
	esac
}

## One call of an owner, in an environment of its own: the data root, and the shell text, which reads
## its own arguments. What it printed.
rigStoreRun(){ ## data-root, shell text, argument...
	local storeRc=0 storeOut="" storeData="$1" storeText="$2" storeWs
	shift 2
	storeWs="$( rigStoreWorkspace "$storeData" )"
	mkdir -p "$storeWs/.local/temp" "$storeWs/.local/agents/members" || return 1
	storeOut="$( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$storeWs/.local/temp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		GIT_CONFIG_NOSYSTEM=1 "MMDAPP=$storeWs" "MDAT_DATA_ROOT=$storeData" \
		"MDLT_ORIGIN=${MDLT_ORIGIN:?rig-owner-store: MDLT_ORIGIN is not set}" \
		"MDLT_OPTION=--run-from-path ${MDLT_ORIGIN}" \
		"MDAT_SKILLSET_ROOT=$storeWs/.local/agents/members" \
		MDAT_SPAWN_AGENT=rig-fixture MDAT_SESSION_ID=rig-fixture \
		bash -c "$storeText" rig "$@" 2>&1 )" || storeRc=$?
	[ "$storeRc" -eq 0 ] || { printf '%s\n' "$storeOut" | LC_ALL=C grep -v '^#' >&2 ; return 1 ; }
	printf '%s\n' "$storeOut" | LC_ALL=C grep -v '^#' || :
}

## The state folders of the board, made by the board's own maker.
rigBoardStates(){ ## data-root, state...
	local readyData="$1" readyState readyAll=""
	shift
	rigStoreIsRig "$readyData" || return 1
	for readyState in "$@" ; do readyAll="$readyAll $readyState" ; done
	[ -n "$readyAll" ] || return 0
	rigStoreRun "$readyData" '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include" || exit 1
		AgentsToolsBoardStateReady "$@" || exit 1
	' $readyAll > /dev/null
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

## One item of a store, written by the store's owner: the item's text on stdin. Silent on success.
rigStoreItem(){ ## data-root, board|inbox, state|member, item name
	local putData="$1" putWhere="$2" putPlace="$3" putName="$4"
	case "$putWhere" in board|inbox) ;; *) echo "⛔ ERROR: rig-owner-store: no such store: $putWhere -- it is board or inbox" >&2 ; return 1 ;; esac
	rigStoreIsRig "$putData" || return 1
	rigStoreRun "$putData" '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
		AgentsToolsItemUpsert rig-fixture --from-"$1" "$2" "$3" --upsert-from-stdin --context rig-owner-store || exit 1
	' "$putWhere" "$putPlace" "$putName" > /dev/null
}

## Where the owner keeps that item: the inbox folder its own name and stamp decide.
rigStoreItemPath(){ ## data-root, board|inbox, state|member, item name
	rigStoreIsRig "$1" || return 1
	rigStoreRun "$1" '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include" || exit 1
		AgentsToolsItemResolvePaths "$1" "$2" "$2" "$3"
		printf "%s/%s\n" "$itemWriteDir" "$3"
	' "$2" "$3" "$4"
}
