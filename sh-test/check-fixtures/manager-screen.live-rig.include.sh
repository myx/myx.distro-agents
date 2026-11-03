#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The rig of the manager screen's checks that drive the REAL dispatcher (S7.28 of the refactorings epic): a scratch
## workspace of the check's own, with its own HOME and its own team data, and `DistroAgentsTools.fn.sh` of the origin behind
## a wrapper that notes every call and passes it through. The screen's own code runs through the stand-in terminal of
## manager-screen.driver.py, in a clean `env -i` as the console operator runs it (the team rig pattern of
## rig-retest-machine.include.sh), so no member identity is in it, and nothing reaches this machine's workspace, team data
## or sessions. A check that drives the screen against manager-screen.tools.stub.sh instead proves the screen against a
## stand-in, which is what S7.28 is about; these are the ones that cannot pass against a dummy.
##
## Sourced by the check, after rig-temp.include.sh, with rigTmp made and rigRefuse defined:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.live-rig.include.sh"
##
##   rigLiveSetup                   builds the rig; sets rigWs rigHome rigStore rigLog rigTools rigOut, rigScreen,
##                                  rigDriver, rigFn, rigPython
##   rigLiveDrive                   reads the driver's script on standard input, and keeps everything it printed in $rigOut
##   rigLiveVal <tag> [<name>]      a value the screen printed, `<tag>.<name>=`
##   rigLiveCalls <pattern>         how many lines of the call log match, as grep -E reads them
##   rigLiveRows <tag>              the ids of the rows at the level the screen is at, as `<tag>=<id> <id>...`
##   rigLiveSession <id> [<member>] a session of the scratch workspace: a spawn record, and one process the registry
##                                  finds by `--session-id <id>` (the audit's own recipe, S7.16)
##   rigLiveSkill <member> <name>   a skillset file of the rig's own member folder, `<name>` its file name
##   rigLivePreset <name> <body>    a preset of the scratch workspace: `.local/.agents/preset-<name>.agent.env`
##   rigLiveEnd                     ends the processes it started
##

## What the checks run, all of it from the origin they run in.
rigScreen="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalManagerScreen.py"
rigDriver="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.driver.py"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
## A rig's process is noted as it began, so a pid the system gives again is never signalled (rig-processes.include.sh).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigLiveProcs=()
rigLiveEnd(){
	local endPid
	for endPid in ${rigLiveProcs[@]+"${rigLiveProcs[@]}"} ; do
		rigProcSignal TERM "$endPid" 2> /dev/null || :
		wait "$endPid" 2> /dev/null || :
	done
	rigLiveProcs=()
}

rigLiveSetup(){
	[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
	[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
	[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
	rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigStore="$rigTmp/store"
	rigLog="$rigTmp/calls.log" ; rigTools="$rigTmp/tools" ; rigOut="$rigTmp/screen.out"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/scratch" "$rigWs/.local/temp" \
		"$rigHome/skills/magic-tester" \
		"$rigStore/board" "$rigStore/audit" "$rigStore/contacts" "$rigStore/inboxes" "$rigStore/vault" \
		|| rigRefuse "the rig could not be made: $rigTmp"
	: > "$rigWs/.local/MDLT.settings.env"
	printf -- '---\nname: magic-tester\n---\nrig identity\n' > "$rigHome/skills/magic-tester/magic-tester.basic.md"
	printf '#!/usr/bin/env bash\n## the dispatcher this rig gives the screen: the real one, every call noted first\nprintf "%%s\\n" "$*" >> "%s"\nexec bash "%s" "$@"\n' \
		"$rigLog" "$rigFn" > "$rigTools" || rigRefuse "the dispatcher wrapper could not be written"
	chmod +x "$rigTools" || rigRefuse "the dispatcher wrapper could not be made executable"
	: > "$rigLog"
}

## Where one drive keeps what it called and what the screen held. The wrapper notes every call in one file, `calls.log`;
## a drive empties it first and keeps its own copy under its tag, so a check that drives twice can say which drive called
## what. These are read in the caller's shell, never in the drive's subshell.
rigLiveWhere(){ ## tag
	rigDriveTag="$1"
	rigOut="$rigTmp/screen-$1.out"
	: > "$rigLog"
}
## One drive of the screen: the driver's own script on the caller's standard input.
rigLiveDrive(){
	{ printf 'size 130 34\nworkspace %s\ntools bash %s\n' "$rigWs" "$rigTools" ; cat ; } \
	| ( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TERM=xterm-256color LC_ALL=en_US.UTF-8 PYTHONDONTWRITEBYTECODE=1 \
		MDAT_WORKSPACE_MODE=team-rig MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigStore" \
		MDAT_SKILLSET_ROOT="$rigHome/skills" MDAT_BASH=/bin/bash MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		"$rigPython" -I -B "$rigDriver" "$rigScreen" script ) > "$rigOut" 2>&1
	cp "$rigLog" "$rigTmp/calls-$rigDriveTag.log" 2> /dev/null || :
}
## The tag a caller names is the drive tag; `screen-` ahead of it is accepted too, since the files carry it.
rigLiveTag(){ ## tag
	case "$1" in screen-*) printf '%s' "${1#screen-}" ;; *) printf '%s' "$1" ;; esac
}
rigLiveVal(){ ## tag, name, [drive] -- what `<tag>.<name>=` printed in that drive's screen text
	local liveTag="$1" liveName="${2:-}" liveWhat
	liveWhat="$( rigLiveTag "${3:-$rigDriveTag}" )"
	LC_ALL=C sed -n "s/^$liveTag\.$liveName=//p" "$rigTmp/screen-$liveWhat.out" | head -1
}
rigLiveCalls(){ ## extended regular expression, [drive]
	local liveWhat
	liveWhat="$( rigLiveTag "${2:-$rigDriveTag}" )"
	LC_ALL=C grep -c -E -- "$1" "$rigTmp/calls-$liveWhat.log" || :
}
## Whether a drive left a dialog open, and which: `opened` with the dialog's name in rigDialogName, or `not-opened`. It is a
## function since a `case` inside a command substitution is not read as one.
rigDialogKind="" ; rigDialogName=""
rigDialog(){ ## drive, tag
	rigDialogName="$( rigLiveVal "$2" dialog "$1" )"
	rigDialogKind="not-opened"
	case "$rigDialogName" in *:*) rigDialogKind="opened" ;; esac
}
## Whether the frame a drive drew holds those words anywhere, as their own run of characters: yes or no. It is the pane as
## drawn, so words under its fold are not in it, and a check of the pane names what stands above the fold.
rigLiveHolds(){ ## drive, words
	case "$( cat "$rigTmp/screen-$( rigLiveTag "$1" ).out" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}
rigLiveOp(){ ## the dispatcher itself, in the rig, as the console operator calls it -- a known positive for a control
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TERM=xterm-256color LC_ALL=en_US.UTF-8 \
		MDAT_WORKSPACE_MODE=team-rig MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigStore" \
		MDAT_SKILLSET_ROOT="$rigHome/skills" MDAT_BASH=/bin/bash MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" "$@" ) 2>&1
}
rigLiveSession(){ ## id, member
	local liveId="$1" liveMember="${2:-magic-tester}" liveDir="$rigWs/.local/agents/spawned/$1" livePid
	mkdir -p "$liveDir" || rigRefuse "the spawn record folder could not be made: $liveDir"
	cat > "$liveDir/$liveId.spawn.md" <<EOF || rigRefuse "the spawn record could not be written"
---
session-id: $liveId
spawn-id: $liveId
tracking-name: $liveId
host: $( hostname -s 2>/dev/null )
workspace: ws-live-rig
owner: $liveMember
status: spawn-started
started-at: $( date '+%Y-%m-%d %H:%M %z' )
reports-to: magic-coordinator
session-comment: $liveId
---

# Spawn session: $liveId
EOF
	## a command line that carries `--session-id <id>`: `bash -c 'sleep N'` alone execs the sleep and loses it, so `; :` keeps bash
	bash -c 'sleep 600; :' "$liveId" --session-id "$liveId" > /dev/null 2>&1 &
	livePid=$!
	rigProcNote "$livePid"
	rigLiveProcs+=( "$livePid" )
	sleep 1
	[ "$( ps -o pid= -p "$livePid" 2> /dev/null | tr -d ' ' )" = "$livePid" ] || rigRefuse "the stand-in session did not start: $liveId"
}
rigLiveSkill(){ ## member, file name
	mkdir -p "$rigHome/skills/$1" || rigRefuse "the member folder could not be made: $rigHome/skills/$1"
	cat > "$rigHome/skills/$1/$2"
}
rigLivePreset(){ ## name, body
	mkdir -p "$rigWs/.local/.agents" || rigRefuse "the preset folder could not be made"
	printf '%s\n' "$2" > "$rigWs/.local/.agents/preset-$1.agent.env" || rigRefuse "the preset could not be written: $1"
}
## A subsystem of the scratch workspace, made installed: the tooling counts one installed where its installed copy stands in
## `.local/myx` of the workspace (LocalTools.ManagerSubsystem.include). The console's own subsystem then offers update alone.
rigLiveSubsystemInstalled(){ ## name
	mkdir -p "$rigWs/.local/myx/myx.distro-$1/sh-scripts" || rigRefuse "the installed copy could not be made: $1"
	printf '#!/bin/sh\n' > "$rigWs/.local/myx/myx.distro-$1/sh-scripts/rig.sh" || rigRefuse "the installed copy could not be written: $1"
}
## The host the tooling's own feature checks see: the rig's `uname`, put ahead on PATH, so a feature's state can be made what
## a case needs. `uname -s` and `uname -m` read the two words given.
rigLiveUname(){ ## system, machine
	mkdir -p "$rigTmp/bin" || rigRefuse "the rig's bin folder could not be made"
	printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -m) echo %s ;; *) echo %s ;; esac\n' "$1" "$2" "$1" > "$rigTmp/bin/uname" \
		|| rigRefuse "the rig's uname could not be written"
	chmod +x "$rigTmp/bin/uname" || rigRefuse "the rig's uname could not be made executable"
}
## The dispatcher the screen is given, with the kill it asks for held for that many seconds: a loaded machine's answer, made
## certain, so a case about the wait is not a race. Every other call passes straight through.
rigLiveSlowKill(){ ## seconds
	local slowTools="$rigTmp/tools-slow.sh"
	printf '#!/usr/bin/env bash\n## the rig dispatcher: a real kill is held, every other call passes through\nprintf "%%s\\n" "$*" >> "%s"\ncase "$1" in\n\t--manager-session-kill)\n\t\tcase " $* " in *" --plan "*) ;; *) sleep %s ;; esac\n\t;;\nesac\nexec bash "%s" "$@"\n' \
		"$rigLog" "$1" "$rigFn" > "$slowTools" || rigRefuse "the slow dispatcher could not be written"
	chmod +x "$slowTools" || rigRefuse "the slow dispatcher could not be made executable"
	rigTools="$slowTools"
}
