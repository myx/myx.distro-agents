#!/usr/bin/env bash
## The registry row builders as they stood before the one-awk-pass rewrite, verbatim but
## for the Legacy name prefix, kept only as the reference side of
## AgentsRegistryRowsDiffCheck.test.sh. Never sourced by production code.

## One header value out of already-read frontmatter text. `-` where absent, and a
## value's own whitespace collapsed, because a column cannot carry the separator --
## a value that needed spaces would be detail, and detail is not in a registry.
AgentsToolsRegistryLegacyHeader(){ ## frontmatter text, header name
	local headerValue
	headerValue="$( printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '
		{
			line = $0
			pos = index(line, ":")
			if (pos < 2) next
			key = substr(line, 1, pos - 1)
			if (key != want) next
			val = substr(line, pos + 1)
			gsub(/^[ \t]+|[ \t]+$/, "", val)
			gsub(/[ \t]+/, "_", val)
			if (val != "") { print val ; exit ; }
		}
	' )" || headerValue=""
	[ -n "$headerValue" ] || headerValue="-"
	printf '%s\n' "$headerValue"
}

## Every `key: value` frontmatter line of one file, through this package's own
## frontmatter printer -- no second parser is written here.
AgentsToolsRegistryLegacyFrontmatter(){ ## file
	LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsBoardItemFrontmatterPrint.awk" "$1" 2>/dev/null || :
}
AgentsToolsRegistryLegacySpawnedSessionsRows(){
	local sandboxDir sessionFile headerText sawRecord
	local rowTracking rowRecordTracking rowSession rowParent rowHost rowOwner rowStatus rowExit
	local rowSpawn rowAgentLogThread rowSessionThread rowWorkspace
	for sandboxDir in "$MMDAPP/.local/agents/spawned"/*/ ; do
		[ -d "$sandboxDir" ] || continue
		## The sandbox root's own name is the tracking name, and is the fallback for
		## a record carrying no header of its own: a sandbox that exists is listable,
		## which is the whole reason it is created even when empty.
		rowTracking="${sandboxDir%/}"
		rowTracking="${rowTracking##*/}"
		sawRecord="false"
		for sessionFile in "$sandboxDir"*.md ; do
			[ -f "$sessionFile" ] || continue
			sawRecord="true"
			headerText="$( AgentsToolsRegistryLegacyFrontmatter "$sessionFile" )"
			rowSession="$( AgentsToolsRegistryLegacyHeader "$headerText" session-id )"
			rowParent="$( AgentsToolsRegistryLegacyHeader "$headerText" parent-session-id )"
			rowHost="$( AgentsToolsRegistryLegacyHeader "$headerText" host )"
			rowOwner="$( AgentsToolsRegistryLegacyHeader "$headerText" owner )"
			rowStatus="$( AgentsToolsRegistryLegacyHeader "$headerText" status )"
			rowExit="$( AgentsToolsRegistryLegacyHeader "$headerText" exit-code )"
			rowRecordTracking="$( AgentsToolsRegistryLegacyHeader "$headerText" tracking-name )"
			rowSpawn="$( AgentsToolsRegistryLegacyHeader "$headerText" spawn-id )"
			rowAgentLogThread="$( AgentsToolsRegistryLegacyHeader "$headerText" agent-log-thread )"
			rowSessionThread="$( AgentsToolsRegistryLegacyHeader "$headerText" session-thread )"
			rowWorkspace="$( AgentsToolsRegistryLegacyHeader "$headerText" workspace )"
			## The record's own tracking-name wins over the folder name where it has
			## one -- they agree unless a sandbox was moved by hand, and then the
			## record is what the spawn itself wrote.
			[ "$rowRecordTracking" = "-" ] || rowTracking="$rowRecordTracking"
			printf '%s %s %s %s %s %s %s %s %s %s %s\n' "$rowTracking" "$rowSession" "$rowParent" "$rowHost" "$rowOwner" "$rowStatus" "$rowExit" "$rowSpawn" "$rowAgentLogThread" "$rowSessionThread" "$rowWorkspace"
		done
		## An empty sandbox is a listed session, not a missing one. It has no session
		## id to be reached by, and saying so is the point.
		[ "$sawRecord" = "true" ] || printf '%s - - - - no-session-record - - - - -\n' "$rowTracking"
	done
	return 0
}
AgentsToolsRegistryLegacyPendingRepliesRows(){
	local askFile boardState boardFile headerText
	local rowBlocked rowSession rowOwner rowChannel rowStatus
	## The ask store first: the commonest source, and the one nothing else records.
	for askFile in "$MMDAPP/.local/agents/pending"/*.md ; do
		[ -f "$askFile" ] || continue
		headerText="$( AgentsToolsRegistryLegacyFrontmatter "$askFile" )"
		rowStatus="$( AgentsToolsRegistryLegacyHeader "$headerText" status )"
		rowSession="$( AgentsToolsRegistryLegacyHeader "$headerText" session-id )"
		rowOwner="$( AgentsToolsRegistryLegacyHeader "$headerText" owner )"
		rowBlocked="$( AgentsToolsRegistryLegacyHeader "$headerText" blocked-on )"
		rowChannel="$( AgentsToolsRegistryLegacyHeader "$headerText" communication-channel-id )"
		## Closed records stay listed rather than being dropped: a received reply is
		## what resumes the work and a timed-out one is what a re-ask is posted from,
		## so both are still wanted here. The status column is what tells them apart.
		printf '%s ask %s %s %s %s %s\n' "${askFile##*/}" "$rowSession" "$rowOwner" "$rowStatus" "$rowBlocked" "$rowChannel"
	done
	## Then the board items that became items, recognised by carrying `blocked-on`.
	## Both `running` and `blocked` are walked, because an item may be waiting
	## without having been moved.
	[ -n "${MDAT_DATA_ROOT:-}" ] || return 0
	for boardState in running blocked ; do
		[ -d "$MDAT_DATA_ROOT/board/$boardState" ] || continue
		for boardFile in "$MDAT_DATA_ROOT/board/$boardState"/*.md ; do
			[ -f "$boardFile" ] || continue
			headerText="$( AgentsToolsRegistryLegacyFrontmatter "$boardFile" )"
			rowBlocked="$( AgentsToolsRegistryLegacyHeader "$headerText" blocked-on )"
			## Not waiting on a reply, so not a pending reply. The registry lists what
			## is actually blocked, never every running item.
			[ "$rowBlocked" = "-" ] && continue
			rowStatus="$( AgentsToolsRegistryLegacyHeader "$headerText" status )"
			rowSession="$( AgentsToolsRegistryLegacyHeader "$headerText" session-id )"
			rowOwner="$( AgentsToolsRegistryLegacyHeader "$headerText" owner )"
			rowChannel="$( AgentsToolsRegistryLegacyHeader "$headerText" communication-channel-id )"
			printf '%s board-item %s %s %s %s %s\n' "${boardFile##*/}" "$rowSession" "$rowOwner" "$rowStatus" "$rowBlocked" "$rowChannel"
		done
	done
	return 0
}

## The spawned-sessions render as it stood before its per-row state derivation stopped forking;

## only its own name changed, so it calls the current rebuild and AgentsToolsRegistryDeriveState.
AgentsToolsRegistryLegacyRenderSpawnedSessions(){ ## view, session-id filter, state filter
	local viewWanted="${1:-agents}" filterSession="${2:-}" filterState="${3:-}"
	local registryFile psText thisHost thisWorkspace
	local rowTracking rowSession rowParent rowHost rowOwner rowStatus rowExit rowSpawn rowAgentLogThread rowSessionThread rowWorkspace rowLive rowState
	local extendedRows="" registryRow sawRow="false" sawAny="false"
	registryFile="$( AgentsToolsRegistryFile spawned-sessions )"
	printf '%s\n\n' "## spawned sessions"
	if [ ! -d "$MMDAPP/.local/agents/spawned" ] ; then
		printf '%s\n\n' "**NOTE:** no scan was made -- no spawn sandbox root exists yet, so no spawn has ever run in this workspace"
		return 0
	fi
	if ! AgentsToolsRegistrySpawnedSessionsRebuild ; then
		printf '%s\n\n' "**NOTE:** no scan was made -- the registry could not be rebuilt at $registryFile"
		return 0
	fi
	AgentsToolsRegistryPendingRepliesRebuild || :
	thisHost="$( hostname -s 2>/dev/null )" || thisHost=""
	[ -n "$thisHost" ] || thisHost="unknown"
	thisWorkspace="$( basename "$MMDAPP" 2>/dev/null )" || thisWorkspace=""
	[ -n "$thisWorkspace" ] || thisWorkspace="unknown"
	printf 'registry: %s -- rebuilt by this scan\n' "$registryFile"
	printf 'this-host: %s\n' "$thisHost"
	printf 'this-workspace: %s\n' "$thisWorkspace"
	psText="$( ps -A -ww -o pid=,args= 2>/dev/null )" || psText=""
	while read -r rowTracking rowSession rowParent rowHost rowOwner rowStatus rowExit rowSpawn rowAgentLogThread rowSessionThread rowWorkspace ; do
		[ -n "$rowTracking" ] || continue
		sawAny="true"
		if [ "$rowSpawn" = "-" ] ; then
			## No spawn id, so there is no handle to ask about on any machine.
			rowLive="no-spawn-id"
		elif [ "$rowHost" = "-" ] ; then
			## Written before the host was recorded, or by hand. Not claimed as
			## either local or foreign, because nothing here knows which it is.
			rowLive="host-unrecorded"
		elif [ "$rowHost" != "$thisHost" ] ; then
			## Another machine's session. Its process list is not reachable from
			## here, so this is UNKNOWN and is never reported as a dead session.
			rowLive="other-host"
		else
			rowLive="no-process"
			case "$psText" in *"$rowSpawn"*) rowLive="running" ;; esac
		fi
		rowState="$( AgentsToolsRegistryDeriveState "$rowStatus" "$rowLive" "$rowSession" )"
		[ -z "$filterSession" ] || [ "$rowSession" = "$filterSession" ] || continue
		extendedRows="$extendedRows$rowTracking $rowSession $rowParent $rowHost $rowOwner $rowStatus $rowExit $rowSpawn $rowAgentLogThread $rowSessionThread $rowWorkspace $rowLive $rowState
"
	done < "$registryFile"
	if [ "$viewWanted" = "sessions" ] ; then
		AgentsToolsRegistryRenderSpawnedSessionsGrouped "$extendedRows" "$filterState"
		return 0
	fi
	printf '%s\n' "columns: tracking-name session-id parent-session-id host owner status exit-code spawn-id agent-log-thread session-thread workspace live state"
	printf '%s\n\n' "live and state: measured/derived during this scan and NOT stored in the registry file, which has the eleven columns before them. live matches spawn-id against this host's own process list, never session-id, which several rows can share. state is running/waiting/finished/unclosed/unknown-foreign -- finished is read straight from status and stands regardless of live."
	while IFS= read -r registryRow ; do
		[ -n "$registryRow" ] || continue
		rowState="${registryRow##* }"
		## running also keeps waiting rows -- a waiting agent is still in flight.
		case "$filterState" in
			"") ;;
			running) [ "$rowState" = "running" ] || [ "$rowState" = "waiting" ] || continue ;;
			*) [ "$rowState" = "$filterState" ] || continue ;;
		esac
		sawRow="true"
		printf '%s\n' "$registryRow"
	done <<< "$extendedRows"
	if [ "$sawRow" != "true" ] ; then
		if [ "$sawAny" != "true" ] ; then
			printf '%s\n' "**NOTE:** no spawned sessions -- the sandbox root exists and holds none"
		else
			printf '%s\n' "**NOTE:** no rows match this view's own session-id/state filter -- other spawned sessions exist, filtered out here"
		fi
	fi
	printf '\n'
	## Stated for the pass that reads this, because a row alone does not say what to
	## do with it.
	printf '%s\n\n' "Compare these rows against the board \`running/\` items before acting on either: a row whose status is still started with no live process and no open ask is state unclosed, a row running now is busy, a row on another host is unknown-foreign, and a \`running/\` item whose session appears in no row has no spawn record behind it at all."
	return 0
}
