#!/usr/bin/env bash
## Behavioural check on --manager-dashboard-read [<block>...], the dashboard of the console's own family --manager-*:
## the most vital figures of a workspace and of its machine, grouped in blocks, run rather than read, against a rig
## machine built here: a workspace with its two registries of sessions as an earlier call left them, the stores of
## its runs, its questions, its team data with a board, its main loop state and heartbeat note; a HOME with a
## retest queue; a member set; and, first on PATH, the rig's own clock, process list and system: `date`, `ps`,
## `uname`, `uptime`, `sysctl`, `vm_stat`, `df`, `du`. A second workspace has nothing but its `.local`.
## Held: each block prints one `block` row that counts its `figure` rows, each figure with its label, value, unit,
## level and share, by known stores. The sessions are counted as the list of sessions counts them, with no
## registry rebuilt: a session that runs, one that waits on an ask, one unclosed, one that finished today and two
## that finished long ago, which are in no total; the agents working and in a Wait; the control threads alive and
## gone, the one a session that finished long ago left behind among them; a death unanswered beside one settled
## and one answered. THE ONE THING THE LIST SEES AND THE DASHBOARD DOES NOT is held as it is: a session whose every
## record is closed is not asked for a process, so a process left behind a closed record makes no session run. The questions open, whose asker is gone, for the human-owner, and the age of the oldest; the ask of
## another host is counted and its asker not measured. The tokens of the running sessions and of today's finished
## ones, and how many are not whole. The members, those that can be started and those that run. The team data: its
## root, present or not, its size, its board by state, a state of no known name after the known ones. The main
## loop and the heartbeat as the digest reads them. The machine by the stand-ins of macOS and of FreeBSD: the load
## with a level by the processors, the memory, the uptime. The volumes, each once, one above the `warn` and one
## above the `bad` threshold, and a file system and a mount named with blanks. The retests that wait.
## A HOST WITH NO TEAM DATA ROOT says where the root would be and that it is not there, and prints no size and no
## board; a workspace with no registry of sessions has no block of sessions, tokens or questions.
## WHAT IS KEPT: the size of the team data and the counts of the members are read once and then for ten minutes
## from what was kept, by the rig's clock, and read again after them. NO FIGURE IS A SECRET: no value of a scope
## and no path of one is in any row or message. IT ONLY READS: every file of the rig but the two kept ones is as it
## was, no registry is rebuilt, nothing is left in the temp folder, and no git and no remote command is run. The
## names: a word that is no block refuses the call; named blocks come in the declared order. THE CALLER RULE of
## the family holds. And the help pair, with the row forms the output is checked against. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRead="--manager-dashboard-read"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigRealDate="$( command -v date )" || rigRefuse "no date on PATH"
rigTmp="$( mktemp -d -t AgentsManagerDashboardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws-here" ; rigBare="$rigTmp/ws-bare" ; rigHome="$rigTmp/home" ; rigHomeBare="$rigTmp/home-bare" ; rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents" ; rigData="$rigAgents/team-data-root" ; rigQueue="$rigHome/.agents/magic-team/retest-queue"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigAgents/pending" "$rigAgents/spawned/t-ask" "$rigBare/.local" "$rigHomeBare" "$rigQueue/waiting" "$rigQueue/done" \
	"$rigData/board/running" "$rigData/board/review" "$rigData/board/blocked" "$rigData/board/odd-state" "$rigData/inboxes/magic-coordinator/incoming" \
	|| rigRefuse "could not create the rig"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
## The rig's clock: 2026-10-13 12:00:00 UTC, in seconds since 1970, kept in a file so that a section moves it.
rigNow=1791892800
printf '%s\n' "$rigNow" > "$rigTmp/now"

## THE SESSIONS, as an earlier call left their registry. s-run runs, by two runs, one of them in a Wait. s-ask
## is closed and an ask of its run is open. s-open has an open record and no process. s-today closed today, s-old
## long ago, and s-linger long ago too, with a process still running as its closed record.
{
	printf 't-run s-run - %s keeper-rig spawn-started - sp-run - - ws-here 2026-10-13_10:00_+0000 - run-one - -\n' "$rigHost"
	printf 't-run2 s-run - %s magic-rig spawn-started - sp-run2 - - ws-here 2026-10-13_10:05_+0000 - - - -\n' "$rigHost"
	printf 't-ask s-ask - %s keeper-rig spawn-succeeded 0 sp-ask - - ws-here 2026-10-12_10:00_+0000 2026-10-12_11:00_+0000 - - -\n' "$rigHost"
	printf 't-open s-open - %s keeper-rig spawn-started - sp-open - - ws-here 2026-10-13_09:00_+0000 - - - -\n' "$rigHost"
	printf 't-today s-today - %s magic-rig spawn-succeeded 0 sp-today - - ws-here 2026-10-13_08:00_+0000 2026-10-13_09:00_+0000 - - -\n' "$rigHost"
	printf 't-old s-old - %s keeper-rig spawn-succeeded 0 sp-old - - ws-here 2026-10-01_08:00_+0000 2026-10-01_09:00_+0000 - - -\n' "$rigHost"
	printf 't-linger s-linger - %s keeper-rig spawn-succeeded 0 sp-linger - - ws-here 2026-10-01_10:00_+0000 2026-10-01_10:30_+0000 - - -\n' "$rigHost"
} > "$rigAgents/spawned-sessions.registry"
## The stores of the runs: their tokens, sp-run2 with none; the Wait of sp-run2; the control threads of s-run,
## which lives, and of s-ask and s-old, whose processes are gone; the deaths the threads keep.
for rigOne in "sp-run 100 200 300 400" "sp-linger 5 5 5 5" "sp-today 10 20 30 40" "sp-old 1 1 1 4997" ; do
	mkdir -p "$rigAgents/sessions/${rigOne%% *}" && printf '%s\n' "${rigOne#* }" > "$rigAgents/sessions/${rigOne%% *}/tokens"
done
mkdir -p "$rigAgents/sessions/sp-run2" "$rigAgents/sessions/s-run/control" "$rigAgents/sessions/s-ask/control" "$rigAgents/sessions/s-open/control" "$rigAgents/sessions/s-today/control" "$rigAgents/sessions/s-old/control"
printf '2026-10-13T11:00:00Z wait going idle\n' > "$rigAgents/sessions/sp-run2/milestones"
printf '5151 Tue_Oct_13_10:00:00_2026\n' > "$rigAgents/sessions/s-run/control/pid"
printf '6161 Tue_Oct_13_09:00:00_2026\n' > "$rigAgents/sessions/s-ask/control/pid"
printf '7171 Thu_Oct__1_08:00:00_2026\n' > "$rigAgents/sessions/s-old/control/pid"
printf 'sp-open member=keeper-rig role=executor found=2026-10-13T10:00:00Z told=2026-10-13T10:01:00Z asked=ask-9\n' > "$rigAgents/sessions/s-open/control/dead"
printf 'sp-today member=magic-rig role=executor found=2026-10-13T08:30:00Z told=2026-10-13T08:31:00Z asked=none settled=2026-10-13T08:31:00Z how=told\n' > "$rigAgents/sessions/s-today/control/dead"
printf 'sp-old member=keeper-rig role=executor found=2026-10-01T08:30:00Z told=2026-10-01T08:31:00Z asked=ask-8 answer=keep answered=2026-10-01T08:40:00Z\n' > "$rigAgents/sessions/s-old/control/dead"
## The process list of the rig: the two runs of s-run, the lingering one, and a tooling line that names a run.
{
	printf '4242 /usr/local/bin/fake-cli --session-id sp-run --agent keeper-rig\n'
	printf '4243 /usr/local/bin/fake-cli --session-id sp-run2 --agent magic-rig\n'
	printf '4244 /usr/local/bin/fake-cli --resume sp-linger\n'
	printf '4245 bash /rig/DistroAgentsTools.fn.sh --member-help keeper-rig --session-id sp-open\n'
} > "$rigTmp/ps.list"

## THE QUESTIONS: three open, one answered. ask-1 is for the human-owner and its asker has a closed record and no
## process; ask-2 is the oldest, its asker runs; ask-3 was asked on another host; ask-4 is answered.
{
	printf 'ask-1.md ask sp-ask keeper-rig reply-pending reply_from_human-owner slack:human-owner\n'
	printf 'ask-2.md ask sp-run keeper-rig reply-pending reply_from_magic-coordinator slack:magic-coordinator\n'
	printf 'ask-3.md ask sp-far keeper-rig reply-pending reply_from_magic-coordinator slack:magic-coordinator\n'
	printf 'ask-4.md ask sp-old keeper-rig reply-received reply_from_human-owner slack:human-owner\n'
} > "$rigAgents/pending-replies.registry"
rigAsk(){ ## id, status, host, asking id, address-to, asked-at
	printf -- '---\nstatus: %s\nowner: keeper-rig\nhost: %s\nsession-id: %s\nkind: question\naddress-to: %s\nasked-at: %s\n---\n\n# Question\n\nasked-at: 1999-01-01 00:00 +0000\n' "$2" "$3" "$4" "$5" "$6" > "$rigAgents/pending/$1.md"
}
rigAsk ask-1 reply-pending "$rigHost" sp-ask human-owner "2026-10-13 08:00 +0000"
rigAsk ask-2 reply-pending "$rigHost" sp-run magic-coordinator "2026-10-12 12:00 +0000"
rigAsk ask-3 reply-pending far-host sp-far magic-coordinator "2026-10-13 11:00 +0000"
rigAsk ask-4 reply-received "$rigHost" sp-old human-owner "2026-10-01 08:00 +0000"
printf -- '---\nstatus: spawn-succeeded\nhost: %s\n---\n' "$rigHost" > "$rigAgents/spawned/t-ask/sp-ask.md"

## THE MEMBERS: two that can be started, an identity record, and the team itself.
for rigOne in keeper-rig magic-rig human-owner magic-team ; do
	mkdir -p "$rigSkills/$rigOne" && printf -- '---\nname: %s\nstatus: active\n---\n# %s\n' "$rigOne" "$rigOne" > "$rigSkills/$rigOne/SKILL.md"
done
printf -- '---\nname: human-owner\nstatus: reference-only\n---\n# human-owner\n' > "$rigSkills/human-owner/SKILL.md"

## THE TEAM DATA: a board with two running items and a file that is none, one in review, none blocked, and a
## state of no known name; the heartbeat's note. THE MAIN LOOP: the state its last iteration left.
: > "$rigData/board/running/one.md" ; : > "$rigData/board/running/two.md" ; : > "$rigData/board/running/notes.txt"
: > "$rigData/board/review/three.md" ; : > "$rigData/board/odd-state/four.md"
printf -- '---\nstate: heartbeat-running\nrecheck-date: 2026-10-13_12:30_+0000\nlast-iteration-timestamp: 2026-10-13T11:00:00Z\n---\n' > "$rigData/inboxes/magic-coordinator/incoming/note-20260809T155000Z-heartbeat-state-and-lock.md"
printf 'MAIN_LOOP_LAST_OUTCOME=ok\nMAIN_LOOP_LAST_ITERATION_UTC=2026-10-13T11:59:00Z\nMAIN_LOOP_CONSECUTIVE_FAILURES=0\n' > "$rigAgents/main-loop.state"

## THE RETESTS that wait, and one that is done.
printf 'id: retest-20261013T110000Z-aaaa\nasked: 2026-10-13T11:00:00Z\nby: rig\n' > "$rigQueue/waiting/retest-20261013T110000Z-aaaa.request"
printf 'id: retest-20261013T113000Z-bbbb\nasked: 2026-10-13T11:30:00Z\nby: rig\n' > "$rigQueue/waiting/retest-20261013T113000Z-bbbb.request"
printf 'id: retest-20261001T100000Z-cccc\nasked: 2026-10-01T10:00:00Z\n' > "$rigQueue/done/retest-20261001T100000Z-cccc.request"

## A SECRET of the workspace, which no row and no message may hold, by its value or by the path of its scope.
rigSecret="xoxb-rig-SECRET-0123456789"
printf 'SLACK_BOT_TOKEN=%s\n' "$rigSecret" > "$rigWs/.local/.agents/keeper-rig.agent.env"
## a full team rig: the mode its installer sets, and a git remote for its team data
printf 'MDAT_WORKSPACE_MODE=team-rig\nTEAM_DATA_GIT_REMOTE=git@rig.invalid:team-data.git\n' > "$rigWs/.local/.agents/magic-team.agent.env"
chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env

## THE RIG'S OWN PATH: its bin, then the system's own folders. Nothing remote and no git: each would log a call.
for rigOne in curl ssh scp git ; do
	printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/forbidden.calls"\nexit 7\n' "$rigOne" "$rigTmp" > "$rigTmp/bin/$rigOne"
done
## The clock: the two forms the tooling asks the time in read the rig's; any other is the system's own.
printf '#!/bin/sh\ncase "$*" in\n\t"+%%s %%Y-%%m-%%d") printf "%%s 2026-10-13\\n" "$( cat "%s/now" )" ;;\n\t"+%%s") cat "%s/now" ;;\n\t*) exec "%s" "$@" ;;\nesac\n' "$rigTmp" "$rigTmp" "$rigRealDate" > "$rigTmp/bin/date"
## The process list, and when the one control thread that lives began.
printf '#!/bin/sh\ncase " $* " in\n\t*" -A "*) cat "%s/ps.list" ;;\n\t*" -p "*) case "$*" in *5151*) printf "5151 S    Tue Oct 13 10:00:00 2026\\n" ;; esac ;;\nesac\nexit 0\n' "$rigTmp" > "$rigTmp/bin/ps"
## The system: which it is and what it says of itself, from the files of the rig.
printf '#!/bin/sh\ncat "%s/sys.uname"\n' "$rigTmp" > "$rigTmp/bin/uname"
printf '#!/bin/sh\ncat "%s/sys.uptime"\n' "$rigTmp" > "$rigTmp/bin/uptime"
printf '#!/bin/sh\ncat "%s/sys.vm_stat"\n' "$rigTmp" > "$rigTmp/bin/vm_stat"
printf '#!/bin/sh\n[ "$1" = "-n" ] || exit 1\nshift\nfor one in "$@" ; do\n\t[ -f "%s/sysctl.$one" ] || exit 1\n\tcat "%s/sysctl.$one"\ndone\n' "$rigTmp" "$rigTmp" > "$rigTmp/bin/sysctl"
## The volumes: a row for each folder asked, in the order asked. `three`: the workspace, its temp folder and the
## team data each on a volume of its own. `one`: all on one.
cat > "$rigTmp/bin/df" <<DF_EOF
#!/bin/sh
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
for one in "\$@" ; do
	case "\$one" in -*) continue ;; esac
	if [ "\$( cat "$rigTmp/df.mode" )" = "one" ] ; then printf '/dev/rig1 1000 500 500 50%% /rigvol/one\n' ; continue ; fi
	case "\$one" in
		*/.local/temp) printf '/dev/rig2 2000 1760 240 88%% /rigvol/two\n' ;;
		*/team-data-root) printf 'rig fs 4000 3840 160 96%% /rigvol/three space\n' ;;
		*) printf '/dev/rig1 1000 500 500 50%% /rigvol/one\n' ;;
	esac
done
DF_EOF
## The size of a folder: 123 blocks of 1024, and each walk logged.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/du.calls"\nfor one in "$@" ; do last="$one" ; done\nprintf "123\\t%%s\\n" "$last"\n' "$rigTmp" > "$rigTmp/bin/du"
chmod +x "$rigTmp/bin"/*
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
rigSystem(){ ## darwin or freebsd -- what the stand-ins of the system say
	rm -f "$rigTmp"/sysctl.* "$rigTmp"/sys.*
	case "$1" in
		darwin)
			printf 'Darwin\n' > "$rigTmp/sys.uname"
			printf '12:00  up 1 day,  1:00, 2 users, load averages: 4.00 12.50 25.00\n' > "$rigTmp/sys.uptime"
			printf '10\n' > "$rigTmp/sysctl.hw.ncpu" ; printf '16000000000\n' > "$rigTmp/sysctl.hw.memsize"
			printf '{ sec = %s, usec = 0 } Mon Oct 12 11:00:00 2026\n' "$(( rigNow - 90000 ))" > "$rigTmp/sysctl.kern.boottime"
			printf 'Mach Virtual Memory Statistics: (page size of 16384 bytes)\nPages free:                                1000.\nPages active:                            900000.\nPages inactive:                            2000.\nPages speculative:                          500.\nPages wired down:                         70000.\n' > "$rigTmp/sys.vm_stat"
		;;
		freebsd)
			printf 'FreeBSD\n' > "$rigTmp/sys.uname"
			printf '12:00PM  up 3 days,  1:00, 1 user, load averages: 0.50, 0.25, 0.10\n' > "$rigTmp/sys.uptime"
			printf '4\n' > "$rigTmp/sysctl.hw.ncpu" ; printf '8000000000\n' > "$rigTmp/sysctl.hw.physmem" ; printf '4096\n' > "$rigTmp/sysctl.hw.pagesize"
			printf '500000\n' > "$rigTmp/sysctl.vm.stats.vm.v_free_count" ; printf '250000\n' > "$rigTmp/sysctl.vm.stats.vm.v_inactive_count"
			printf '{ sec = %s, usec = 0 } Mon Oct 12 11:00:00 2026\n' "$(( rigNow - 90000 ))" > "$rigTmp/sysctl.kern.boottime"
		;;
	esac
}
rigSystem darwin
printf 'three\n' > "$rigTmp/df.mode"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigPre=() ; rigRunWs="$rigWs" ; rigRunHome="$rigHome"
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigRunWs" && env -i HOME="$rigRunHome" PATH="$rigPath" MMDAPP="$rigRunWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigBlock(){ ## block, file (the last output where not given) -- its `block` row and its figures, TABs as blanks, a `/` after each row
	LC_ALL=C awk -F'\t' -v wantBlock="$1" '$2 == wantBlock { gsub( /\t/, " " ) ; printf "%s/", $0 ; }' "${2:-$rigTmp/out}"
}
rigBlocks(){ ## file (the last output where not given) -- the blocks printed, in their order
	LC_ALL=C awk -F'\t' '$1 == "block" { printf "%s%s", ( said++ ? " " : "" ), $2 ; }' "${1:-$rigTmp/out}"
}
rigTree(){ ## -- every file of the rig's workspaces, homes and member set but the temp folders, each with the sum of its bytes, and every folder
	( cd "$rigTmp" && { find ws-here ws-bare home home-bare skills -type f ! -path '*/.local/temp/*' 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ; find ws-here ws-bare home home-bare skills -type d ! -path '*/.local/temp' 2> /dev/null | LC_ALL=C sort ; } ) | cksum
}
rigTreeBefore="$( rigTree )"

echo "-- 1. every block, by known stores --"
rigRun "$rigRead"
cp "$rigTmp/out" "$rigTmp/whole" ; cp "$rigTmp/err" "$rigTmp/whole.err"
rigAssert "the read ends rc 0 with no error and no warning, and prints its nine blocks in the declared order" "$rigRc $( rigTroubles ) $( rigBlocks )" "0 0 sessions pending tokens team team-data loop machine disk testing"
rigAssert "sessions: one runs, one waits on an ask, one is unclosed, and a process left behind a closed record makes none run; one agent works and one waits; a control thread alive and two gone, one of them of a session that ended long ago; one death unanswered" "$( rigBlock sessions )" \
	"block sessions Sessions_And_Agents 9/figure sessions sessions-running Sessions_Running 1 count - -/figure sessions sessions-waiting Sessions_Waiting 1 count - -/figure sessions sessions-unclosed Sessions_Unclosed 1 count warn -/figure sessions sessions-paused Sessions_Paused 0 count - -/figure sessions agents-working Agents_Working 1 count - 50/figure sessions agents-waiting Agents_Waiting 1 count - 50/figure sessions control-alive Control_Threads_Alive 1 count - -/figure sessions control-gone Control_Threads_Gone 2 count warn -/figure sessions deaths-unanswered Deaths_Unanswered 1 count warn -/"
rigAssert "pending: three open, the answered one not counted; one asker gone, the ask of another host not measured; one for the human-owner; the oldest a day old, by its header and not by its text" "$( rigBlock pending )" \
	"block pending Pending_Questions 4/figure pending open Questions_Open 3 count - -/figure pending asker-gone Asker_Is_Gone 1 count warn 33/figure pending human-owner For_The_Human_Owner 1 count - 33/figure pending oldest-age Oldest_Question_Age 86400 seconds - -/"
rigAssert "tokens: the running session, today's finished one, and one session not whole; the sessions that ended long ago are in no total" "$( rigBlock tokens )" \
	"block tokens Session_Tokens 3/figure tokens running Running_Sessions_Tokens 1000 count - -/figure tokens finished-today Finished_Today_Tokens 100 count - -/figure tokens not-whole Sessions_Not_Whole 1 count - -/"
rigAssert "team: three members, the team itself not counted; two can be started, the identity record cannot; two run" "$( rigBlock team )" \
	"block team Team_Members 3/figure team members Members_Known 3 count - -/figure team startable Members_To_Start 2 count - 66/figure team running Members_Running_Now 2 count - 100/"
rigAssert "team data: its root, present, its size from the stand-in, the board by state, a file that is no item not counted, a state of no known name last" "$( rigBlock team-data )" \
	"block team-data Team_Data 7/figure team-data root Team_Data_Root $rigData - - -/figure team-data present Team_Data_Present yes - ok -/figure team-data size Team_Data_Size 125952 bytes - -/figure team-data board-running Board_Items_Running 2 count - -/figure team-data board-review Board_Items_Review 1 count - -/figure team-data board-blocked Board_Items_Blocked 0 count - -/figure team-data board-odd-state Board_Items_Odd_State 1 count - -/"
rigAssert "loop: the last outcome of the main loop, its age and its failures; the heartbeat's state, the age of its last iteration, and that it runs" "$( rigBlock loop )" \
	"block loop Main_Loop_And_Heartbeat 6/figure loop main-loop-outcome Main_Loop_Last_Outcome ok - ok -/figure loop main-loop-age Main_Loop_Last_Iteration 60 seconds - -/figure loop main-loop-failures Main_Loop_Consecutive_Failures 0 count ok -/figure loop heartbeat-state Heartbeat_State heartbeat-running - - -/figure loop heartbeat-age Heartbeat_Last_Iteration 3600 seconds - -/figure loop heartbeat-running Heartbeat_Running yes - - -/"
rigAssert "machine, by the stand-ins of macOS: a load under the processors ok, over them warn, over twice them bad, each share stopped at 100; the memory in use above its bad threshold; the uptime" "$( rigBlock machine )" \
	"block machine The_Machine 7/figure machine load-1 Load_One_Minute 4.00 - ok 40/figure machine load-5 Load_Five_Minutes 12.50 - warn 100/figure machine load-15 Load_Fifteen_Minutes 25.00 - bad 100/figure machine processors Processors_Online 10 count - -/figure machine memory-used Memory_In_Use 15942656000 bytes bad 99/figure machine memory-free Memory_To_Use 57344000 bytes - -/figure machine uptime Machine_Up_For 90000 seconds - -/"
rigAssert "disk: three volumes, the workspace's ok, its temp folder's above the warn threshold, the team data's above the bad one, its file system and mount named with blanks" "$( rigBlock disk )" \
	"block disk Disk_Space 9/figure disk workspace-size Workspace_Volume_Size 1024000 bytes - -/figure disk workspace-used Workspace_Volume_Used 512000 bytes ok 50/figure disk workspace-free Workspace_Volume_Free 512000 bytes - -/figure disk temp-size Temp_Folder_Volume_Size 2048000 bytes - -/figure disk temp-used Temp_Folder_Volume_Used 1802240 bytes warn 88/figure disk temp-free Temp_Folder_Volume_Free 245760 bytes - -/figure disk team-data-size Team_Data_Volume_Size 4096000 bytes - -/figure disk team-data-used Team_Data_Volume_Used 3932160 bytes bad 96/figure disk team-data-free Team_Data_Volume_Free 163840 bytes - -/"
rigAssert "testing: two retests wait, the one that is done not counted, and the oldest has waited an hour" "$( rigBlock testing )" \
	"block testing Retest_Queue 2/figure testing waiting Retests_Waiting 2 count - -/figure testing oldest-age Oldest_Retest_Age 3600 seconds - -/"

rigModeFile="$( cat "$rigWs/.local/.agents/magic-team.agent.env" )"
printf 'MDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigRun "$rigRead" loop
rigAssert "a team rig whose team data has no git remote shows its loop plain: no figure of it is judged" "$( rigBlock loop )" \
	"block loop Main_Loop_And_Heartbeat 6/figure loop main-loop-outcome Main_Loop_Last_Outcome ok - - -/figure loop main-loop-age Main_Loop_Last_Iteration 60 seconds - -/figure loop main-loop-failures Main_Loop_Consecutive_Failures 0 count - -/figure loop heartbeat-state Heartbeat_State heartbeat-running - - -/figure loop heartbeat-age Heartbeat_Last_Iteration 3600 seconds - -/figure loop heartbeat-running Heartbeat_Running yes - - -/"
for rigOne in just-agents rig-client ; do
	printf 'MDAT_WORKSPACE_MODE=%s\nTEAM_DATA_GIT_REMOTE=git@rig.invalid:team-data.git\n' "$rigOne" > "$rigWs/.local/.agents/magic-team.agent.env"
	rigRun "$rigRead" loop team-data
	rigAssert "a workspace in the mode $rigOne has no main loop: no loop block, though its team data is there" "$rigRc $( rigBlocks )" "0 team-data"
done
printf '%s\n' "$rigModeFile" > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- 2. the names --"
rigRun "$rigRead" disk sessions machine
rigAssert "named blocks alone are printed, in the declared order whatever the order given, each as the whole read has it" "$rigRc $( rigBlocks ) $( [ "$( rigBlock sessions )$( rigBlock machine )$( rigBlock disk )" = "$( rigBlock sessions "$rigTmp/whole" )$( rigBlock machine "$rigTmp/whole" )$( rigBlock disk "$rigTmp/whole" )" ] && echo same )" "0 sessions machine disk same"
rigRun "$rigRead" disk no-such-block
rigAssert "a word that is no block refuses the call, rc 1, nothing on stdout, in one line that lists the blocks and does not repeat the word" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigRead: a word given is none of its blocks -- nothing was printed. Its blocks: sessions, pending, tokens, team, team-data, team-data-git, loop, machine, disk, testing" ) $( rigTroubles ) $( LC_ALL=C grep -c -F -e 'no-such-block' "$rigTmp/err" || : )" "1 0 1 1 0"

echo "-- 3. the machine by the stand-ins of FreeBSD, and the volumes on one --"
rigSystem freebsd ; printf 'one\n' > "$rigTmp/df.mode"
rigRun "$rigRead" machine disk
rigAssert "machine, by the stand-ins of FreeBSD: its load averages written with commas, its processors, its memory by pages free and inactive, its uptime" "$rigRc $( rigBlock machine )" \
	"0 block machine The_Machine 7/figure machine load-1 Load_One_Minute 0.50 - ok 12/figure machine load-5 Load_Five_Minutes 0.25 - ok 6/figure machine load-15 Load_Fifteen_Minutes 0.10 - ok 2/figure machine processors Processors_Online 4 count - -/figure machine memory-used Memory_In_Use 4928000000 bytes ok 61/figure machine memory-free Memory_To_Use 3072000000 bytes - -/figure machine uptime Machine_Up_For 90000 seconds - -/"
rigAssert "the three folders on one volume: that volume once, under the workspace" "$( rigBlock disk )" \
	"block disk Disk_Space 3/figure disk workspace-size Workspace_Volume_Size 1024000 bytes - -/figure disk workspace-used Workspace_Volume_Used 512000 bytes ok 50/figure disk workspace-free Workspace_Volume_Free 512000 bytes - -/"
rm -f "$rigTmp"/sysctl.* "$rigTmp"/sys.vm_stat ; printf 'Plan9\n' > "$rigTmp/sys.uname" ; printf '12:00 up 1 day\n' > "$rigTmp/sys.uptime"
rigRun "$rigRead" machine
rigAssert "a system that gives no answer has no block of the machine: nothing is guessed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigTroubles )" "0 0 0"
rigSystem darwin ; printf 'three\n' > "$rigTmp/df.mode"

echo "-- 4. a host with no team data root, no registry of sessions and no queue --"
rigRunWs="$rigBare" ; rigRunHome="$rigHomeBare"
rigRun "$rigRead"
rigAssert "it prints what it has: the members, the team data, the machine, the volume; no sessions, no questions, no tokens, no loop, no retests" "$rigRc $( rigTroubles ) $( rigBlocks )" "0 0 team team-data machine disk"
rigAssert "the team data says where its root would be and that it is not there, bad, with no size and no board" "$( rigBlock team-data )" "block team-data Team_Data 2/figure team-data root Team_Data_Root $rigBare/.local/agents/team-data-root - - -/figure team-data present Team_Data_Present no - bad -/"
rigAssert "the members with no figure of who runs, since no session was read; and the folder that is not there has no volume" "$( rigBlock team )|$( LC_ALL=C grep -c -e 'team-data-size' "$rigTmp/out" || : )" "block team Team_Members 2/figure team members Members_Known 3 count - -/figure team startable Members_To_Start 2 count - 66/|0"
rigRunWs="$rigWs" ; rigRunHome="$rigHome"

echo "-- 5. what is kept, by the rig's clock --"
rigAssert "the whole read walked the team data once" "$( wc -l < "$rigTmp/du.calls" | LC_ALL=C tr -d ' ' )" "1"
mkdir -p "$rigSkills/keeper-new" && printf -- '---\nname: keeper-new\nstatus: active\n---\n' > "$rigSkills/keeper-new/SKILL.md"
printf '%s\n' "$(( rigNow + 599 ))" > "$rigTmp/now"
rigRun "$rigRead" team team-data
rigAssert "within ten minutes the size and the counts of the members are read from what was kept: no walk, and a member set up since is not counted yet" "$rigRc $( wc -l < "$rigTmp/du.calls" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C awk -F'\t' '$3 == "size" || $3 == "members" { printf "%s=%s ", $3, $5 }' "$rigTmp/out" )" "0 1 members=3 size=125952 "
printf '%s\n' "$(( rigNow + 600 ))" > "$rigTmp/now"
rigRun "$rigRead" team team-data
rigAssert "after ten minutes both are read again: one more walk, and the new member is counted" "$rigRc $( wc -l < "$rigTmp/du.calls" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C awk -F'\t' '$3 == "size" || $3 == "members" || $3 == "startable" { printf "%s=%s ", $3, $5 }' "$rigTmp/out" )" "0 2 members=4 startable=3 size=125952 "
rm -rf "$rigSkills/keeper-new"
printf '%s\n' "$rigNow" > "$rigTmp/now"
rigAssert "what is kept lies in the temp folder of the workspace, two files, and nothing else is left there" "$( cd "$rigWs/.local/temp" && ls | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "mdat-manager-dashboard.team-data-size mdat-manager-dashboard.team-members "
chmod 555 "$rigWs/.local/temp" ; rm -f "$rigTmp/du.calls"
printf '%s\n' "$(( rigNow + 5000 ))" > "$rigTmp/now"
rigRun "$rigRead" team-data
rigKeptBad="$( [ -w "$rigWs/.local/temp" ] && echo writable )"
chmod 755 "$rigWs/.local/temp" ; printf '%s\n' "$rigNow" > "$rigTmp/now"
if [ -z "$rigKeptBad" ] ; then
	rigAssert "where the answer cannot be kept the team data is not walked at all, and has no size" "$rigRc $( [ -f "$rigTmp/du.calls" ] && echo walked || echo no-walk ) $( LC_ALL=C grep -c -e 'Team_Data_Size' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -e 'Team_Data_Present' "$rigTmp/out" || : )" "0 no-walk 0 1"
else
	printf '  NOTE  whoever runs this check writes into a folder no mode lets it: the read with nowhere to keep its answer is not held here\n'
fi

echo "-- 6. no figure is a secret, and it only reads --"
rigAssert "no row and no message of the whole read holds the value of a setting or the path of a scope" "$( LC_ALL=C grep -c -F -e "$rigSecret" -e '.agent.env' -e '.local/.agents' "$rigTmp/whole" "$rigTmp/whole.err" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e "s|$rigTmp/||g" )" "whole:0 whole.err:0 "
rm -rf "$rigBare/.local/temp"
rigAssert "every file of the rig but the two kept ones is as it was: no registry rebuilt, no record and no store touched" "$( rigTree )" "$rigTreeBefore"
rigAssert "no git command and nothing remote was run" "$( [ -f "$rigTmp/forbidden.calls" ] && cat "$rigTmp/forbidden.calls" || echo none )" "none"

echo "-- 6b. the audit and the vault of the team data, and its git state, named alone --"
mkdir -p "$rigData/audit/2026-10" "$rigData/audit/2026-09" "$rigData/vault/notes"
: > "$rigData/audit/artifact-20261013T1100Z-one.md" ; : > "$rigData/audit/2026-10/transcript-20261012T0900Z-two.md" ; : > "$rigData/audit/2026-09/transcript-20260930T0900Z-three.md"
: > "$rigData/vault/fact-one.md" ; : > "$rigData/vault/notes/fact-two" ; : > "$rigData/audit/2026-10/session-20261013T0800Z-four.log"
touch -t 202610010000 "$rigData/vault/fact-one.md" "$rigData/vault/notes/fact-two"
rigRun "$rigRead" team-data
rigAssert "the audit by its items, those of this month, and the age of its newest by the stamp of its name; the vault by its files" "$( rigBlock team-data | LC_ALL=C tr '/' '\n' | LC_ALL=C grep -e audit -e vault | LC_ALL=C sed 's/vault-newest Vault_Newest_Item [0-9]* /vault-newest Vault_Newest_Item N /' | LC_ALL=C tr '\n' '/' )" "figure team-data audit-items Audit_Items 4 count - -/figure team-data audit-month Audit_Items_This_Month 3 count - -/figure team-data audit-newest Audit_Newest_Item 3600 seconds - -/figure team-data vault-items Vault_Items 2 count - -/figure team-data vault-newest Vault_Newest_Item N seconds - -/"
rigRun "$rigRead" team-data-git
rigAssert "the git state is a block of its own, printed only where it is named: where git says the store is no repository, that alone" "$rigRc $( rigBlock team-data-git )" "0 block team-data-git Team_Data_Git 1/figure team-data-git repository Team_Data_Repository no - - -/"

echo "-- 7. the caller rule of the family, and its place in it --"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigRead"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: manager-dashboard-read: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"
rigAssert "the family's include has one arm for the dashboard, which sources its include" "$( LC_ALL=C grep -c -x -e '	--manager-dashboard-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/dashboard/AgentsTools.ManagerDashboard.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"
rigRun --manager-dashboard-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-dashboard-no-such" )" "1 1"
rigAssert "the blocks have one declaration, and each names a reader the include has" "$( LC_ALL=C grep -c -e '^agentsManagerDashboardBlocks=' "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/dashboard/AgentsTools.ManagerDashboard.include" || : ) $( LC_ALL=C sed -n -e '/^agentsManagerDashboardBlocks=/,/"$/p' "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/dashboard/AgentsTools.ManagerDashboard.include" | LC_ALL=C tr -d '"\t' | LC_ALL=C sed -e 's/^agentsManagerDashboardBlocks=//' | while IFS=: read -r rigOne rigLabel rigReader ; do [ -z "$rigOne" ] || LC_ALL=C grep -c -e "^$rigReader(){" "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/dashboard/AgentsTools.ManagerDashboard.include" || : ; done | LC_ALL=C tr -d '\n' )" "1 1111111111"

echo "-- 8. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigEntry(){ ## heading -- that operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigForm(){ ## heading, row kind -- the form line of that row in that entry, its back quotes and its indent taken off
	rigEntry "$1" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$2"' <.*>\)`$/\1/p'
}
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigRead [<block>...]"
rigAssert "it has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigRead [<block>...]" )" "$rigHelpMd" || : )" "1 1 1"
rigAssert "the entry gives the forms of its two rows" "$( rigForm "$rigRead [<block>...]" block ) | $( rigForm "$rigRead [<block>...]" figure )" "block <block> <label> <figures> | figure <block> <figure> <label> <value> <unit> <level> <share>"
rigAssert "and every row of the whole read has exactly the fields its form names, each block counting its figures" "$( for rigOne in block figure ; do LC_ALL=C awk -F'\t' -v wantKind="$rigOne" -v wantFields="$( rigForm "$rigRead [<block>...]" "$rigOne" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s:%s ", wantKind, ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/whole" ; done ; LC_ALL=C awk -F'\t' '$1 == "block" { if ( open != "" && left != 0 ) bad++ ; open = $2 ; left = $4 ; next } $1 == "figure" { if ( $2 != open ) bad++ ; left-- ; next } { bad++ } END { if ( left != 0 ) bad++ ; printf "counts:%s", bad + 0 }' "$rigTmp/whole" )" "block:rows:0 figure:rows:0 counts:0"
rigAssert "every unit and every level of the whole read is one the entry names, and every share a whole number from 0 to 100 or -" "$( LC_ALL=C awk -F'\t' '$1 == "figure" { if ( $6 != "count" && $6 != "bytes" && $6 != "seconds" && $6 != "-" ) bad++ ; if ( $7 != "ok" && $7 != "warn" && $7 != "bad" && $7 != "-" ) bad++ ; if ( $8 != "-" && ( $8 !~ /^[0-9]+$/ || $8 + 0 > 100 ) ) bad++ ; } END { print bad + 0 }' "$rigTmp/whole" ) $( for rigWord in count bytes seconds ok warn bad ; do rigEntry "$rigRead [<block>...]" | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "0 yyyyyy"
rigAssert "the entry names each block by its key and its label, and says that it only reads, runs no git command, and what it keeps" "$( for rigOne in "sessions:Sessions And Agents" "pending:Pending Questions" "tokens:Session Tokens" "team:Team Members" "team-data:Team Data" "loop:Main Loop And Heartbeat" "machine:The Machine" "disk:Disk Space" "testing:Retest Queue" ; do rigEntry "$rigRead [<block>...]" | LC_ALL=C grep -c -F -- "\`${rigOne%%:*}\`, ${rigOne#*:}:" | LC_ALL=C awk '{ printf "%s", ( $1 == 1 ) ? "y" : "n" }' ; done ) $( rigEntry "$rigRead [<block>...]" | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'no git command is run' || : ) $( rigEntry "$rigRead [<block>...]" | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'is kept for ten minutes' || : )" "yyyyyyyyy 1 1"
rigAssert "the labels of the blocks in the entry are those the read prints" "$( LC_ALL=C awk -F'\t' '$1 == "block" { gsub( /_/, " ", $3 ) ; printf "%s:%s/", $2, $3 }' "$rigTmp/whole" )" "sessions:Sessions And Agents/pending:Pending Questions/tokens:Session Tokens/team:Team Members/team-data:Team Data/loop:Main Loop And Heartbeat/machine:The Machine/disk:Disk Space/testing:Retest Queue/"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"
[ "$( uname -s 2> /dev/null )" = "Linux" ] || printf '  NOTE  the reader of the machine for Linux reads /proc of the host itself and is not run by this check on a host that is not Linux\n'

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER DASHBOARD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_DASHBOARD: OK (%d assertions, offline)\n' "$rigPasses"
