#!/usr/bin/env bash
## Behavioural check on what one call of the tooling parses (code-craft "Each call runs only its own path"): the front door's
## error-only call, the permission gate, the ask, the start/spawn and the Wait round, each measured on a call of its own in a rig
## of its own, against the budget taken when each was measured. The entry's own body is read by bash as it goes, not sourced
## whole, so the budget counts the sourced files. Held, run and not read: the call is traced with bash -x, every
## `+ . <file>` line is a file the call parsed, and its bytes are the file's own.
## Red recipe: the unsplit shape sources AgentsTools.MemberWorkspace.include, AgentsTools.Settings.include and
## AgentsTools.CallerCheck.include on every call and reads 115,103 bytes against a budget of 80,000; a call that pipes a table
## through awk, greps a store or shells a `tr` reads as a process breach, which is what the fork rows hold; the control trace
## naming one large file must read as a breach, and the clean one as none.
## Offline: one traced call, one awk pass; no store is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigEntry="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigBudget=80000
rigFileCap=16000
## An error-only call never needs these: a member operation's workspace, the settings reader, the caller-check layer, the help text.
rigAbsent="AgentsTools.MemberWorkspace.include AgentsTools.Settings.include AgentsTools.CallerCheck.include Help.DistroAgentsTools.include"
rigPresent="AgentsContext.include AgentsContext.UseAgentsTools.include"

[ -f "$rigEntry" ] || { echo "⛔ ERROR: AgentsCallPathIsolationCheck: no front door at $rigEntry -- refusing to report a result" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCallPathIsolationCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The classifier: the call's verbatim sources, counted once each, with the total, the files past the cap, the absent ones the
## call did parse, and the present ones it did not. One awk process, no fork a file.
rigClassify(){ ## trace file, budget, cap, absent names, present names
	LC_ALL=C awk -v budget="$2" -v cap="$3" -v absent="$4" -v present="$5" '
		/^[+]+ (\.|source) / {
			path = $0 ; sub(/^[+]+ (\.|source) /, "", path) ; gsub(/"/, "", path)
			sub(/^[ \t]+/, "", path) ; sub(/[ \t]+$/, "", path)
			if ( path == "" || (path in seenName) ) next
			seenName[path] = 1
			size = 0
			while ( (getline rec < path) > 0 ) size += length(rec) + 1
			close(path)
			name = path ; sub(/^.*\//, "", name)
			seenFile[name] = 1
			total += size
			if ( size > cap ) over = over " " name
		}
		END {
			printf "bytes=%d", total
			printf " budget=%s", ( total <= budget ? "kept" : "over" )
			printf " over-cap=%d%s", split(over, tmp, " "), over
			n = 0 ; split(absent, want, " ") ; for ( i in want ) if ( want[i] != "" && (want[i] in seenFile) ) n++
			printf " parsed-what-it-should-not=%d", n
			n = 0 ; split(present, want, " ") ; for ( i in want ) if ( want[i] == "" || (want[i] in seenFile) ) n++
			printf " parsed-what-it-must=%d", n
		}' "$1"
}

## The call: one error-only run, traced. Nothing of it is run besides the dispatch and its refusal.
( cd "$MMDAPP" && env -i HOME="${HOME:-$MMDAPP/.local/temp}" PATH="$PATH" MMDAPP="$MMDAPP" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="${MDLT_OPTION:-}" MYXROOT="${MYXROOT:-}" \
	bash -x "$rigEntry" --intern-no-such-operation ) > /dev/null 2> "$rigTmp/trace" || :

rigSaid="$( rigClassify "$rigTmp/trace" "$rigBudget" "$rigFileCap" "$rigAbsent" "$rigPresent" )" || rigSaid="the classifier did not run"
echo "  -- the call: $rigSaid"

## THE INSTRUMENT: the classifier's two directions, on traces made here: one naming a file past the cap, one naming none.
head -c $(( rigBudget + 1024 )) /dev/zero | LC_ALL=C tr '\0' 'x' > "$rigTmp/big.include"
printf '++ . %s\n++ . %s\n' "$rigTmp/big.include" "$rigTmp/missing.include" > "$rigTmp/trace.breach"
printf '++ . %s\n' "$rigPackage/sh-lib/harness/AgentsContext.include" > "$rigTmp/trace.clean"
rigSaidBreach="$( rigClassify "$rigTmp/trace.breach" "$rigBudget" "$rigFileCap" "" "" )" || rigSaidBreach="the classifier did not run"
rigSaidClean="$( rigClassify "$rigTmp/trace.clean" "$rigBudget" "$rigFileCap" "" "" )" || rigSaidClean="the classifier did not run"
echo "  -- control, a file past the cap: $rigSaidBreach"
echo "  -- control, a trace within it:   $rigSaidClean"

## THE WORST PATH, START/SPAWN: measured in a rig of its own, since a working workspace takes a different branch of it (a store it has,
## the rig does not). The budget is what the rig measured when this section was written, plus 30,000 bytes.
## The processes a path's traced call started: an external command a builtin could do is a breach of "a call path starts no process".
rigForksOf(){ ## store name
	LC_ALL=C grep -cE '^[+]+ (awk|grep|sed|wc|cut|sort|head|tail|tr|find|cat|date|ps) ' "$rigTmp/store.$1/trace"
}

## A CALL ON A PATH OF ITS OWN: a fresh store per call, since a working workspace takes a different branch of some of them, and the
## call refuses for its missing arguments, so only the load and the refusal run. Prints the classifier's line.
rigPathCall(){ ## tool script, store name, budget, arguments...
	local callTool="$rigPackage/sh-scripts/$1" callStore="$rigTmp/store.$2" callBudget="$3"
	shift 3
	mkdir -p "$callStore/.local/agents" "$callStore/home" || return 1
	( cd "$callStore" && env -i HOME="$callStore/home" PATH="$PATH" MMDAPP="$callStore" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="${MDLT_OPTION:-}" MYXROOT="${MYXROOT:-}" bash -x "$callTool" "$@" ) > /dev/null 2> "$callStore/trace" || :
	rigClassify "$callStore/trace" "$callBudget" "$rigFileCap" "" ""
}
rigSpawnBudget=575000 rigPermissionBudget=190000 rigAskBudget=150000 rigWaitBudget=285000 rigScheduleBudget=185000
rigSaidSpawn="$( rigPathCall DistroAgentsTools.fn.sh spawn "$rigSpawnBudget" --intern-op-agent-spawn-proxy )" ; echo "  -- start/spawn: $rigSaidSpawn forks=$( rigForksOf "spawn" )"
rigSaidPermission="$( rigPathCall DistroAgentsTools.fn.sh permission "$rigPermissionBudget" --intern-op-permission-grant-consume )" ; echo "  -- permission gate: $rigSaidPermission forks=$( rigForksOf "permission" )"
rigSaidAsk="$( rigPathCall DistroAgentsTools.fn.sh ask "$rigAskBudget" --intern-op-pending-reply-collect )" ; echo "  -- ask: $rigSaidAsk forks=$( rigForksOf "ask" )"
rigSaidWait="$( rigPathCall DistroAgentsSession.fn.sh wait "$rigWaitBudget" --wait-for-input )" ; echo "  -- Wait round: $rigSaidWait forks=$( rigForksOf "wait" )"
rigSaidSchedule="$( rigPathCall DistroAgentsDispatcher.fn.sh schedule "$rigScheduleBudget" --spawn-prompt )" ; echo "  -- schedule operation: $rigSaidSchedule forks=$( rigForksOf "schedule" )"

rigPasses=0 rigFails=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigField(){ ## the classifier's line, the field's name -- its value
	printf '%s\n' "$1" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sed -n "s/^$2=//p" | LC_ALL=C sed -n 1p
}
rigAssert "an error-only call sources no more than ${rigBudget} bytes (the unsplit shape sourced 115,103)" "$( rigField "$rigSaid" budget )" "kept"
rigAssert "no file it parses is past the ${rigFileCap}-byte cap" "$( rigField "$rigSaid" over-cap )" "0"
rigAssert "it parses nothing of a member operation, the settings reader, the caller check or the help" "$( rigField "$rigSaid" parsed-what-it-should-not )" "0"
rigAssert "it parses the front door and the harness context" "$( rigField "$rigSaid" parsed-what-it-must )" "2"
rigAssert "control: a trace naming a file past the cap reads as a breach" "$( rigField "$rigSaidBreach" over-cap )/$( rigField "$rigSaidBreach" budget )" "1/over"
rigAssert "the start/spawn path sources no more than ${rigSpawnBudget} bytes in a rig (485,387 in a working workspace)" "$( rigField "$rigSaidSpawn" budget )" "kept"
rigAssert "the permission gate sources no more than ${rigPermissionBudget} bytes in a rig (161,820 measured)" "$( rigField "$rigSaidPermission" budget )" "kept"
rigAssert "the ask path sources no more than ${rigAskBudget} bytes in a rig (136,846 measured)" "$( rigField "$rigSaidAsk" budget )" "kept"
rigAssert "the Wait round sources no more than ${rigWaitBudget} bytes in a rig (211,356 measured)" "$( rigField "$rigSaidWait" budget )" "kept"
rigAssert "no error-only call starts a process of its own" "$( LC_ALL=C grep -cE '^[+]+ (awk|grep|sed|wc|cut|sort|head|tail|tr|find|cat|date|ps) ' "$rigTmp/trace" )" "0"
rigAssert "the permission gate and the ask start no process" "$( rigForksOf permission )$( rigForksOf ask )" "00"
rigAssert "the start/spawn path starts at most the one date it stamps with" "$( rigForksOf spawn )" "1"
rigAssert "the schedule operation sources no more than ${rigScheduleBudget} bytes in a rig (160,162 measured)" "$( rigField "$rigSaidSchedule" budget )" "kept"
rigAssert "the Wait round and the schedule operation start at most their two" "$( rigForksOf wait )$( rigForksOf schedule )" "22"
rigAssert "control: a trace within the cap reads as clean" "$( rigField "$rigSaidClean" over-cap )/$( rigField "$rigSaidClean" budget )" "0/kept"

if [ "$rigFails" -ne 0 ] ; then echo "⛔ CALL-PATH ISOLATION CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "CALL_PATH_ISOLATION: OK ($rigPasses assertions, offline, one traced call)"
