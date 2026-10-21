#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The rig of the checks of the schedule's loop steps (AgentsScheduleLoopCheck, AgentsScheduleBudgetCheck): a workspace of its own with a roster
## (magic-coordinator, magic-librarian, an oncall member, human-owner as an identity record, and as many keepers as the check asks for), the real
## work-duty routine, routines that declare an autorun, the settings of a schedule (Etc/GMT-3, weekend sat,sun, worktime 09:00 to 17:00 on
## workdays), a console that ends at once, a Slack-shaped curl that logs every call, a process list of its own, and a clock of its own (now.epoch).
## Sourced by the check, after rig-processes.include.sh, rig-control-threads.include.sh and rig-temp.include.sh, with rigTmp made, rigRefuse and
## rigAssert defined:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-schedule-loop.include.sh"
##   rigScheduleSetup <number of keepers>    builds the rig under $rigTmp/loop
##   rigAt <epoch>  rigMentionCache  rigOneRun <name>  rigWaitStarts  rigDispatch <words...>  rigTool <words...>  rigSaid  rigStartsOf  rigRecordsOf  rigCalls  rigDutyCount  rigItem  rigLive
##

rigScheduleSetup(){ ## number of keepers (01 up)
	local rigNo rigMember rigName rigKeepers="$1"
	rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
	rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
	rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
	rigDir="$rigTmp/loop" rigWs="$rigTmp/loop/ws" rigData="$rigTmp/loop/data" rigSkills="$rigTmp/loop/home/.claude/skills" rigScn="$rigTmp/loop/scn"
	rigSp="$rigWs/.local/agents/spawned" rigStores="$rigWs/.local/agents/sessions"
	rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH"
	rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
	mkdir -p "$rigWs/.local/.agents" "$rigData" "$rigDir/bin" "$rigScn" "$rigSp" "$rigStores" "$rigSkills/magic-team" "$rigSkills/magic-coordinator" \
		"$rigSkills/magic-librarian" "$rigSkills/human-owner" "$rigSkills/oncall-rig"
	for rigMember in magic-coordinator magic-librarian oncall-rig ; do
		printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md" ; printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
		printf '# %s\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
	done
	printf -- '---\nstatus: reference-only\n---\n# human-owner\n' > "$rigSkills/human-owner/SKILL.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/human-owner/human-owner.basic.md"
	rigNames=""
	for rigNo in $( seq 1 "$rigKeepers" ) ; do
		rigNo="$( printf '%02d' "$rigNo" )"
		mkdir -p "$rigSkills/keeper-rig-$rigNo" "$rigData/inboxes/keeper-rig-$rigNo/incoming"
		printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/keeper-rig-$rigNo/keeper-rig-$rigNo.basic.md" ; printf '# rig armed\n' > "$rigSkills/keeper-rig-$rigNo/keeper-rig-$rigNo.armed.md"
		printf '# keeper-rig-%s\n' "$rigNo" > "$rigSkills/keeper-rig-$rigNo/SKILL.md"
		rigNames="$rigNames keeper-rig-$rigNo"
	done
	mkdir -p "$rigData/inboxes/magic-coordinator/incoming" "$rigData/inboxes/magic-librarian/incoming" "$rigData/inboxes/oncall-rig/incoming" "$rigData/inboxes/human-owner/incoming"
	## The real work-duty routine, but for its scan: the scan collects over a window and reads the Slack of the rig, which a check of the loop does
	## not need (the routine's own text is held by AgentsScheduleLoopCheck, section 0).
	LC_ALL=C sed -e 's/^input-scan-def: .*$/input-scan-def: none/' "$rigPackage/skillset/magic-team/magic-team/magic-team.work-duty.routine.md" > "$rigSkills/magic-team/magic-team.work-duty.routine.md" \
		|| rigRefuse "the work-duty routine is not in the package skillset"
	## The coordinator's own duty routine of the package too, but for its scan and the sections it includes (the rig holds no advance routine to take them of).
	LC_ALL=C sed -e 's/^input-scan-def: .*$/input-scan-def: none/' -e '/^includes: /d' "$rigPackage/skillset/magic-team/magic-coordinator/magic-coordinator.work-duty.routine.md" > "$rigSkills/magic-coordinator/magic-coordinator.work-duty.routine.md" \
		|| rigRefuse "the coordinator's work-duty routine is not in the package skillset"
	local rigBody="# Opening steps\n\nNone.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\nNone.\n\n# Routine's local procedures\n\nNone.\n"
	printf -- "---\ntype: routine\nexecutors: keeper-rig-01\nmaintainers: rig\nrequires-session-kind: standalone\nruns-at: daily 09:00\n---\n# keeper-rig-01.auto.routine\n\n$rigBody" > "$rigSkills/keeper-rig-01/keeper-rig-01.auto.routine.md"
	printf -- "---\ntype: routine\nexecutors: keeper-rig-01\nmaintainers: rig\nrequires-session-kind: standalone\nruns-at: daily 09:00\nruns-after: keeper-rig-01.auto\n---\n# keeper-rig-01.chain.routine\n\n$rigBody" > "$rigSkills/keeper-rig-01/keeper-rig-01.chain.routine.md"
	printf -- "---\ntype: routine\nexecutors: magic-team\nmaintainers: rig\nrequires-session-kind: standalone\nruns-at: daily 09:00\n---\n# keeper-rig-01.anyone.routine\n\n$rigBody" > "$rigSkills/keeper-rig-01/keeper-rig-01.anyone.routine.md"
	rigMentionCache
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSPAWN_CLI_SERVICE=rig-cli\nSESSION_CONTROL_TICK_SECONDS=1\nWAIT_COLLECT_SECONDS=2\nMDAT_SCHEDULE_TIMEZONE=Etc/GMT-3\nMDAT_SCHEDULE_WEEKEND=sat,sun\nMDAT_SCHEDULE_WORKTIME=09:00 17:00 workdays\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'MAIN_LOOP_RESTART_DELAY_SECONDS=2\nSLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
	for rigName in $rigNames magic-librarian ; do printf 'SLACK_USER_TOKEN=rig-user-token-%s\n' "${rigName##*-}" > "$rigWs/.local/.agents/$rigName.agent.env" ; done
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho "start $$ $MDAT_SPAWN_AGENT" >> "%s/console.log"\necho "end $$" >> "%s/console.log"\n' "$rigDir" "$rigDir" > "$rigWs/DistroAgentsConsole.sh"
	cp "$rigPackage/sh-test/check-fixtures/session-chat.curl.stub.sh" "$rigDir/bin/curl" || rigRefuse "the fake curl fixture is missing"
	ln -s "$rigRealPs" "$rigDir/bin/ps.real" ; : > "$rigDir/ps.list"
	cat > "$rigDir/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
	ln -s "$( command -v date )" "$rigDir/bin/date.real"
	cat > "$rigDir/bin/date" <<'RIGDATE'
#!/bin/sh
## The rig's clock: the instant in now.epoch, formatted by the real date as it would at that instant (TZ is the caller's).
real="${0%/*}/date.real"
epoch="$( cat "${0%/*}/../now.epoch" )"
case "$*" in
	+%s) echo "$epoch" ; exit 0 ;;
esac
case "$1" in
	+*) if "$real" -r 0 +%s > /dev/null 2>&1 ; then exec "$real" -r "$epoch" "$@" ; else exec "$real" -d "@$epoch" "$@" ; fi ;;
esac
exec "$real" "$@"
RIGDATE
	chmod +x "$rigWs/DistroAgentsConsole.sh" "$rigDir/bin/curl" "$rigDir/bin/ps" "$rigDir/bin/date"
	: > "$rigScn/calls" ; : > "$rigScn/history-empty"
}

rigLiveSpawn="" rigLivePid=""
rigLive(){ ## member, idle|working -- the run of that member's duty in the rig: a stand-in process, a record, a thread and a store; its spawn id in rigLiveSpawn
	local liveRecord liveSpawn liveLeft
	liveRecord="$( LC_ALL=C grep -l -x "owner: $1" $( LC_ALL=C grep -l -x 'routine: magic-team.work-duty.routine.md' "$rigSp"/*/*.spawn.md ) | head -1 )"
	liveSpawn="${liveRecord##*/}" ; liveSpawn="${liveSpawn%.spawn.md}"
	## The real start of this duty ends a moment after its record says so, with a last milestone of its own; the run of the rig is made after that, or it is written over.
	liveLeft=150
	while [ "$liveLeft" -gt 0 ] && ! LC_ALL=C grep -q ' end$' "$rigStores/$liveSpawn/milestones" 2> /dev/null ; do sleep 0.2 ; liveLeft=$(( liveLeft - 1 )) ; done
	LC_ALL=C sed -i.bak -e 's/^status: .*/status: spawn-started/' -e '/^resolved-at: /d' "$liveRecord" && rm -f "$liveRecord.bak"
	if ! LC_ALL=C grep -q '^session-thread: ' "$liveRecord" ; then
		LC_ALL=C awk '{ print } /^status: / { print "session-thread: CRIG00001:1760000000.0000" NR }' "$liveRecord" > "$liveRecord.next" && mv -f "$liveRecord.next" "$liveRecord"
	fi
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigLivePid="$!"
	rigProcNote "$!" ; rigStarted="$rigStarted $!"
	printf '%s claude --verbose --session-id %s --agent %s the brief\n' "$!" "$liveSpawn" "$1" >> "$rigDir/ps.list"
	disown "$!" 2> /dev/null || :
	mkdir -p "$rigStores/$liveSpawn"
	if [ "$2" = idle ] ; then printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z wait going idle\n' > "$rigStores/$liveSpawn/milestones"
	else printf '2026-10-19T10:00:00Z start\n2026-10-19T10:05:00Z message out\n' > "$rigStores/$liveSpawn/milestones" ; fi
	rigLiveSpawn="$liveSpawn"
}

rigMentionCache(){ ## -- the Slack ids of the members of the rig (URIG<last word of the name>), as the tooling keeps them; the tooling rewrites the file, so a check that reads it sets it again
	local cacheName
	for cacheName in $rigNames magic-coordinator magic-librarian ; do printf '%s=URIG%s=m=M=M=d\n' "$cacheName" "${cacheName##*-}" ; done > "$rigWs/.local/.agents/slack-mention-ids.cache"
}
rigAt(){ printf '%s' "$1" > "$rigDir/now.epoch" ; }

rigOneRc=0
rigOneRun(){ ## name of its output files -- one iteration of the real loop
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-main-loop --one
		' > "$rigDir/$1.out" 2> "$rigDir/$1.err" < /dev/null
	rigOneRc=$?
}
rigWaitStarts(){ ## -- until the starts the loop made in the background have ended (at most 200 seconds)
	local waitLeft=1000
	while [ -n "$( LC_ALL=C ls "$rigWs/.local/agents/schedule/starting" 2> /dev/null | LC_ALL=C grep -v -e '\.rc$' -e '\.out$' )" ] && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	## The record of a start (spawn-started) is closed a moment after the start, by the run that ended (its exit-code is the mark): the loop no longer holds the check for the
	## time a pass took, so the close is waited for here (at most 60 seconds), or a check that closes a record by hand has it closed again under it.
	local waitRecord waitOpen
	waitLeft=300
	while [ "$waitLeft" -gt 0 ] ; do
		waitOpen=""
		for waitRecord in $( LC_ALL=C grep -l '^status: spawn-started$' "$rigSp"/*/*.spawn.md 2> /dev/null ) ; do
			LC_ALL=C grep -q '^exit-code: ' "$waitRecord" || waitOpen=1
		done
		[ -n "$waitOpen" ] || break
		sleep 0.2 ; waitLeft=$(( waitLeft - 1 ))
	done
	return 0
}
rigTool(){ ## words... -- one tooling call from the rig workspace
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" bash "$rigFn" "$@" ) > /dev/null 2>&1 < /dev/null
}
rigDispatch(){ ## words... -- one call of DistroAgentsDispatcher.fn.sh from the rig workspace
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScn" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" "$@" ) > /dev/null 2>&1 < /dev/null
}
rigSaid(){ ## name of a run, fixed text -- how many lines of its errors hold it
	LC_ALL=C grep -c -F -- "$2" "$rigDir/$1.err" || :
}
rigStartsOf(){ ## member -- how many starts of that member the console of the rig logged
	[ -f "$rigDir/console.log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^start [0-9]+ $1\$" "$rigDir/console.log" || :
}
rigRecordsOf(){ ## routine file name -- how many spawn records of the rig name that routine
	LC_ALL=C grep -l -x "routine: $1" "$rigSp"/*/*.spawn.md 2> /dev/null | wc -l | tr -d ' '
}
rigCalls(){ ## method -- how many calls of that Slack method the fake curl logged
	[ -f "$rigScn/calls" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^$1 " "$rigScn/calls" || :
}
rigDutyCount(){ ## member -- how many records of the work-duty routine that member owns
	local dutyR dutyN=0
	for dutyR in $( LC_ALL=C grep -l -E '^routine: [A-Za-z0-9-]+\.work-duty\.routine\.md$' "$rigSp"/*/*.spawn.md 2> /dev/null ) ; do
		[ "$( LC_ALL=C grep -c -x "owner: $1" "$dutyR" )" = 0 ] || dutyN=$(( dutyN + 1 ))
	done
	printf '%s\n' "$dutyN"
}
rigItem(){ ## member -- one inbox item not yet processed, for that member to work on
	printf -- '---\ntype: note\nfrom: rig\nowner: %s\n---\n# Note: work\n\nwork\n' "$1" > "$rigData/inboxes/$1/incoming/note-20261019T0900Z-rig-work.md"
}
