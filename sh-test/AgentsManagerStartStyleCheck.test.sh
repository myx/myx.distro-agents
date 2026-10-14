#!/usr/bin/env bash
## Behavioural check on the interface style a start of the manager screen is given, run rather than read:
## --intern-manager [--style <name>], which is what the console's --manager runs. NO SCREEN IS STARTED: a `python3`
## of the rig stands first on the rig's PATH, and writes down the arguments it was started with and the variable of
## the environment as it saw it. Against a rig workspace built here with its own user settings: every call runs
## with MMDAPP at the rig, so what the user who runs this check saved in the real workspace is never read.
## Held, step by step, the order a start takes its style in: an explicit --style on the command is handed on as it
## was given, whatever the environment and the saved setting say; with none, the style the environment names is
## left to the screen, which reads it itself, and no option is handed on; with neither, the style the user saved
## is handed on as --style; with nothing at all no option is handed on, and the screen takes its default. A name
## that is no style counts as not given, in the environment and in the saved setting. Another user's saved style
## and one in the workspace's own settings file are not taken. The start only reads: no file of the rig is
## written. What the screen ends with is what the start ends with. A word the start does not take, and --style
## with no name, are refused before anything is started. Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigScreen="$rigHere/AgentsManagerScreen.py"
rigOp="--intern-manager"
rigKey="MDAT_MANAGER_STYLE"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin this workspace resolves: $rigScreen"
rigTmp="$( mktemp -d -t AgentsManagerStartStyleCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/.local/home/rig-other-user" "$rigHome" "$rigSkills"

## THE USERS: the one who runs this check, by the name the operating system gives, and another user of the rig
## workspace who saved a style. The workspace's own settings file holds the key too.
rigUser="$( id -un )" || rigRefuse "the name of the user who runs this check cannot be read"
[ -n "$rigUser" ] && [ "$rigUser" != "rig-other-user" ] || rigRefuse "the user who runs this check has no name of its own"
rigOwn="$rigWs/.local/home/$rigUser/MDLT.settings.env"
printf '%s=bw\n' "$rigKey" > "$rigWs/.local/home/rig-other-user/MDLT.settings.env"
printf 'MDLT_CONSOLE_ORIGIN=.local\n%s=bw\n' "$rigKey" > "$rigWs/.local/MDLT.settings.env"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigReal="${MMDAPP%/}/.local/home/$rigUser/MDLT.settings.env"

## THE RIG'S OWN PATH: its bin, then the system's own folders. Its python3 is no Python: it writes down how it
## was started and ends with the status in RIG_SCREEN_RC, 0 where none is given.
printf '#!/bin/sh\n{ printf "start" ; for rigArg in "$@" ; do printf "\\t%%s" "$rigArg" ; done ; printf "\\n" ; printf "environment\\t%%s\\n" "${%s-none}" ; } >> "%s/starts"\nexit "${RIG_SCREEN_RC:-0}"\n' "$rigKey" "$rigTmp" > "$rigTmp/bin/python3"
chmod +x "$rigTmp/bin/python3"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( PATH="$rigPath" command -v python3 )" = "$rigTmp/bin/python3" ] || rigRefuse "the rig's own python3 is not first on the rig's PATH"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigPre=()
rigStart(){ ## words after the operation... -- one start from the rig workspace; rc in rigRc, stdout in out, stderr in err, what the rig's python3 wrote down in starts
	rigRc=0
	: > "$rigTmp/starts"
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$rigOp" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigHanded(){ ## -- what the last start handed the screen after its workspace and its tools: `nothing`, or the words, a space between them; `other-start` where the screen was not started as the start starts it, `starts:<n>` where it was not started once
	LC_ALL=C awk -F'\t' -v wantScreen="$rigScreen" -v wantWs="$rigWs" -v wantTool="$rigTool" '
		$1 == "start" {
			starts++
			if ( $2 != "-I" || $3 != "-B" || $4 != wantScreen || $5 != "--workspace" || $6 != wantWs || $7 != "--tools" || $8 != wantTool ) { said = "other-start" ; next }
			said = ""
			for ( field = 9 ; field <= NF ; field++ ) said = said ( said == "" ? "" : " " ) $field
			if ( said == "" ) said = "nothing"
		}
		END { print ( starts == 1 ) ? said : "starts:" starts + 0 }' "$rigTmp/starts"
}
rigSeen(){ ## -- the variable of the environment as the screen saw it in the last start, `none` where it was not set
	LC_ALL=C awk -F'\t' '$1 == "environment" { print $2 }' "$rigTmp/starts"
}
rigSave(){ ## value -- the style the user saved, written by hand; with no value, nothing saved
	rm -rf "${rigOwn%/*}"
	[ $# -eq 0 ] || { mkdir -p "${rigOwn%/*}" && printf 'MDLT_CONSOLE_HISTORY=workspace-shared\n%s=%s\n' "$rigKey" "$1" > "$rigOwn" ; }
}
rigTree(){ ## -- every file of the rig's workspace, home and skills, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws home skills -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}
rigSum(){ ## file -- the sum of its bytes, or `absent`
	if [ -f "$1" ] ; then cksum < "$1" ; else echo absent ; fi
}
rigRealBefore="$( rigSum "$rigReal" )"

echo "-- 1. nothing names a style: the screen takes its default --"
rigSave
rigTreeBefore="$( rigTree )"
rigStart
rigAssert "the screen is started once, for the rig workspace, with the tool as its way to the tooling, and no style is handed on" "$rigRc $( rigHanded ) $( rigSeen )" "0 nothing none"
rigAssert "another user's saved style and the one in the workspace's own settings file are not taken, and the start wrote nothing" "$( LC_ALL=C grep -c -x -e "$rigKey=bw" "$rigWs/.local/home/rig-other-user/MDLT.settings.env" "$rigWs/.local/MDLT.settings.env" | LC_ALL=C awk -F: '{ n += $2 } END { print n + 0 }' ) $( rigTree )" "2 $rigTreeBefore"

echo "-- 2. the user's saved style is the look of the next start --"
for rigOne in magic bw tv ; do
	rigSave "$rigOne"
	rigStart
	rigAssert "$rigOne is saved: it is handed on as --style" "$rigRc $( rigHanded ) $( rigSeen )" "0 --style $rigOne none"
done
rigSave zz
rigStart
rigAssert "a saved name that is no style counts as not saved: no style is handed on" "$rigRc $( rigHanded ) $( rigSeen )" "0 nothing none"
rigSave mc
rigStart
rigAssert "so does a saved compact style, which is retired: the screen takes its default" "$rigRc $( rigHanded ) $( rigSeen )" "0 nothing none"

echo "-- 3. the environment ahead of the saved style --"
rigSave magic
rigTreeBefore="$( rigTree )"
rigPre=( "$rigKey=bw" ) ; rigStart ; rigPre=()
rigAssert "with a style in the environment no option is handed on: the screen reads the environment itself, and sees it" "$rigRc $( rigHanded ) $( rigSeen )" "0 nothing bw"
rigPre=( "$rigKey=zz" ) ; rigStart ; rigPre=()
rigAssert "a name in the environment that is no style counts as not given: the saved style is handed on, ahead of it" "$rigRc $( rigHanded ) $( rigSeen )" "0 --style magic zz"
rigSave
rigPre=( "$rigKey=bw" ) ; rigStart ; rigPre=()
rigAssert "with nothing saved the environment's style is left to the screen as before" "$rigRc $( rigHanded ) $( rigSeen )" "0 nothing bw"

echo "-- 4. an explicit --style ahead of both --"
rigSave magic
rigStart --style tv
rigAssert "with a style saved, the one on the command is handed on" "$rigRc $( rigHanded ) $( rigSeen )" "0 --style tv none"
rigPre=( "$rigKey=bw" ) ; rigStart --style tv ; rigPre=()
rigAssert "with a style saved and another in the environment, the one on the command is handed on" "$rigRc $( rigHanded ) $( rigSeen )" "0 --style tv bw"
rigSave
rigStart --style bw
rigAssert "with nothing saved and nothing in the environment, the one on the command is handed on" "$rigRc $( rigHanded ) $( rigSeen )" "0 --style bw none"
rigSave magic
rigStart --style zz
rigAssert "a name on the command is handed on as it was given, also one that is no style: the screen says what it does with it" "$rigRc $( rigHanded )" "0 --style zz"

echo "-- 5. the start only reads, and ends as the screen ends --"
rigSave magic
rigTreeBefore="$( rigTree )"
rigStart
rigPre=( "$rigKey=bw" ) ; rigStart ; rigPre=()
rigStart --style tv
rigAssert "three starts, by the saved style, by the environment and by the command, wrote no file of the rig" "$( rigTree )" "$rigTreeBefore"
rigPre=( "RIG_SCREEN_RC=7" ) ; rigStart ; rigPre=()
rigAssert "the status the screen ends with is the status of the start" "$rigRc $( rigHanded )" "7 --style magic"

echo "-- 6. what the start does not take --"
rigRefusedStart(){ ## -- the last start: its rc, how often the screen was started, whether the syntax of the start was said
	printf '%s %s %s' "$rigRc" "$( LC_ALL=C grep -c -e '^start' "$rigTmp/starts" || : )" "$( LC_ALL=C grep -c -x -F -e "  DistroAgentsTools $rigOp [--style <name>]" "$rigTmp/err" || : )"
}
rigStart --style
rigAssert "--style with no name is refused, rc 1, with the syntax, and nothing is started" "$( rigRefusedStart )" "1 0 1"
rigStart --style ""
rigAssert "and so is an empty name" "$( rigRefusedStart )" "1 0 1"
rigStart --style tv more
rigAssert "and a word after the name" "$( rigRefusedStart )" "1 0 1"
rigStart --look tv
rigAssert "and an option the start does not have" "$( rigRefusedStart )" "1 0 1"
rigStart tv
rigAssert "and a bare word" "$( rigRefusedStart )" "1 0 1"

echo "-- 7. the real workspace was never reached --"
rigAssert "what the user who runs this check saved in the real workspace is as it was" "$( rigSum "$rigReal" )" "$rigRealBefore"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER START STYLE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_START_STYLE: OK (%d assertions, offline)\n' "$rigPasses"
