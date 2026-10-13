#!/usr/bin/env bash
## Behavioural check on the changeable settings of the console, run rather than read: the lines of
## --manager-config-digest --full that say a setting can be changed, and --manager-config-set <key> <value>, the
## one operation that saves a declared setting. Against a rig workspace built here WITH ITS OWN USER SETTINGS AND
## ITS OWN WORKSPACE SETTINGS: every call runs with MMDAPP at the rig, so what the user who runs this check and the
## real workspace have saved is never read and never written, which the last section asserts.
## Held: the declared few and no other line say `yes`, each with its kind, its scope, where its value comes from,
## what it takes and the file it is saved in. A SETTING OF THE USER (the history type of a console) is read from
## the user's own file ahead of the workspace's, is saved in the user's own file through the setting reader of the
## local tools, and is then what a console's own reading of it gives. A SETTING OF THE WORKSPACE (the two bounds of
## a control request, whole numbers) is saved in the settings of the team through the tooling's own operation,
## --agents-config-option, where every other line of that file, a secret among them, and its mode stay as they
## were, and is then what the tooling's own reading gives. A value outside the kind is refused: a word that is no
## choice, a number below the smallest or above the largest, a number written otherwise. A key that is not declared
## is refused, a real setting that is not mapped among them, and so is a wrong count of words. Nothing that was
## given is repeated in a refusal. From inside a member's session it is refused, magic-coordinator's too. The
## earlier name of the operation is gone. And the help pair. Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRead="--manager-config-digest"
rigWrite="--manager-config-set"
rigKeys="MDAT_MANAGER_STYLE, MDLT_CONSOLE_HISTORY, SESSION_CONTROL_REQUEST_SECONDS, SESSION_CONTROL_KILL_SECONDS"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d -t AgentsManagerConfigSetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/.local/home/rig-other-user" "$rigHome" "$rigSkills"

rigUser="$( id -un )" || rigRefuse "the name of the user who runs this check cannot be read"
[ -n "$rigUser" ] && [ "$rigUser" != "rig-other-user" ] || rigRefuse "the user who runs this check has no name of its own"
rigOwn="$rigWs/.local/home/$rigUser/MDLT.settings.env"
rigOther="$rigWs/.local/home/rig-other-user/MDLT.settings.env"
rigShared="$rigWs/.local/MDLT.settings.env"
rigTeam="$rigWs/.local/.agents/magic-team.agent.env"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigRealUser="${MMDAPP%/}/.local/home/$rigUser/MDLT.settings.env"
rigRealTeam="${MMDAPP%/}/.local/.agents/magic-team.agent.env"
## A value nobody may see again: it stands in the settings of the team, and is given to the writer as if pasted.
rigSecret="Hd3mTyRIGSECRET31Vq7zKe"
printf 'MDLT_CONSOLE_HISTORY=workspace-separate\n' > "$rigOther"
printf 'MDLT_CONSOLE_ORIGIN=.local\nMDLT_CONSOLE_HISTORY=workspace-shared\n' > "$rigShared"
printf '# a note of the owner\nSLACK_BOT_TOKEN=%s\nSPAWN_CLI_SERVICE=claude\n' "$rigSecret" > "$rigTeam"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; : > "$rigWs/.local/.agents/magic-coordinator.agent.env"
chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err, both kept in all
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigSum(){ ## file -- the sum of its bytes, or `absent`
	if [ -f "$1" ] ; then cksum < "$1" ; else echo absent ; fi
}
rigRefused(){ ## the one line of the refusal -- the last call: its rc, the bytes of its stdout, how many lines of its stderr are that line, and how many are an error at all
	printf '%s %s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( rigWhole "$rigTmp/err" "$1" )" "$( rigTroubles )"
}
rigLine(){ ## key -- that line of the last digest in full, its description left out: its other fourteen fields, a blank between them
	LC_ALL=C awk -F'\t' -v wantKey="$1" '$1 == "line" && $4 == wantKey { print $1, $2, $3, $4, $5, $6, $7, $9, $10, $11, $12, $13, $14, $15 ; }' "$rigTmp/out"
}
rigNow(){ ## key -- what that setting is now and where from, in a digest in full made at this call: its own line, not the line the scope that holds it has for the key
	rigRun "$rigRead" --full
	LC_ALL=C awk -F'\t' -v wantKey="$1" '$1 == "line" && $2 != "scopes" && $4 == wantKey { print $6, $12 ; }' "$rigTmp/out"
}
rigRealBefore="$( rigSum "$rigRealUser" ) $( rigSum "$rigRealTeam" )"
rigOtherBefore="$( rigSum "$rigOther" )"
rigHistory="workspace-personal=Per_User_In_This_Workspace,workspace-separate=Per_User_And_Per_Console,workspace-shared=Shared_By_All_Users,local-machine-home=In_The_Home_Of_The_User,bash-default=The_File_Bash_Uses,user-default=As_The_User_Has_It"

echo "-- 1. the lines that can be changed, with nothing saved by the user --"
rigRun "$rigRead" --full
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the history type of a console: a choice, the user's own, now what the workspace's own file says, to be saved in the user's file" "$( rigLine MDLT_CONSOLE_HISTORY )" "line console history MDLT_CONSOLE_HISTORY set workspace-shared Console_History_Type yes choice user workspace $rigHistory $rigOwn settings"
rigAssert "where the consoles load their tools from and the debug output of the tools stand beside it, belong to the configuration and cannot be changed here" "$( rigLine MDLT_CONSOLE_ORIGIN ) / $( rigLine MDSC_DETAIL )" "line console origin MDLT_CONSOLE_ORIGIN set .local Console_Tooling_Origin no:set_at_deployment:_a_wizard_will_change_it - - - - - configuration / line console detail MDSC_DETAIL set off Debug_Output_Mode no:set_at_deployment:_a_wizard_will_change_it - - - - - configuration"
rigAssert "the two bounds of a control request: whole numbers with their smallest and largest, the workspace's, now their defaults, to be saved in the settings of the team" "$( rigLine SESSION_CONTROL_REQUEST_SECONDS ) / $( rigLine SESSION_CONTROL_KILL_SECONDS )" "line control request SESSION_CONTROL_REQUEST_SECONDS set 5 Control_Request_Seconds yes number workspace default 1..60 $rigTeam settings / line control kill SESSION_CONTROL_KILL_SECONDS set 30 Control_Kill_Seconds yes number workspace default 5..600 $rigTeam settings"
rigAssert "the style of the interface is one of them, in the same fields" "$( rigLine MDAT_MANAGER_STYLE )" "line interface style MDAT_MANAGER_STYLE set tv Interface_Style yes choice user default tv=Turbo_Vision,mc=MC_(Compact),bw=B/W $rigOwn settings"
rigAssert "these four and no other line of the digest say yes" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $9 == "yes" { printf "%s ", $4 }' "$rigTmp/out" )" "MDAT_MANAGER_STYLE MDLT_CONSOLE_HISTORY SESSION_CONTROL_REQUEST_SECONDS SESSION_CONTROL_KILL_SECONDS "
rigRun "$rigRead" console control
rigAssert "without --full the two subjects print their lines in the seven fields every line has, under their labels" "$rigRc $( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" | LC_ALL=C tr '\n' '/' )" "0 subject console 3 Console_Behaviour/line console history MDLT_CONSOLE_HISTORY set workspace-shared Console_History_Type/line console origin MDLT_CONSOLE_ORIGIN set .local Console_Tooling_Origin/line console detail MDSC_DETAIL set off Debug_Output_Mode/subject control 2 Session_Control/line control request SESSION_CONTROL_REQUEST_SECONDS set 5 Control_Request_Seconds/line control kill SESSION_CONTROL_KILL_SECONDS set 30 Control_Kill_Seconds/"

echo "-- 2. a setting of the user: the history type of a console --"
rigBad=""
for rigOne in workspace-personal workspace-separate local-machine-home workspace-shared user-default bash-default ; do
	rigRun "$rigWrite" MDLT_CONSOLE_HISTORY "$rigOne"
	[ "$rigRc $( rigTroubles ) $( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )" = "0 0 saved MDLT_CONSOLE_HISTORY $rigOne user $rigOwn" ] && [ "$( LC_ALL=C grep -c -x -e "MDLT_CONSOLE_HISTORY=$rigOne" "$rigOwn" )" = 1 ] && [ "$( rigNow MDLT_CONSOLE_HISTORY )" = "$rigOne user" ] || rigBad="$rigBad [$rigOne]"
done
rigAssert "each of its six values is saved: one row with the key, the value now saved, the scope and the file; the user's file holds it; the digest reads it back as the user's own, ahead of the workspace's" "${rigBad:- each saved}" " each saved"
rigAssert "a console's own reading of it, the reader every console's rc asks, now gives the saved value" "$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" USER="$rigUser" bash -c 'ReadConfig(){ . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" ; } ; ReadConfig --.local-config-option-select-default MDLT_CONSOLE_HISTORY default' )" "bash-default"
rigAssert "the workspace's own file and the other user's file are as they were" "$( LC_ALL=C grep -c -x -e 'MDLT_CONSOLE_HISTORY=workspace-shared' "$rigShared" ) $( rigSum "$rigOther" )" "1 $rigOtherBefore"
rigOwnBefore="$( rigSum "$rigOwn" )"
rigRun "$rigWrite" MDLT_CONSOLE_HISTORY none
rigAssert "a word that is none of its values is refused, rc 1, in one line that lists them, and the user's file is as it was: no console would start with it" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: the value given is none of the values of MDLT_CONSOLE_HISTORY -- nothing was saved. Its values: workspace-personal, workspace-separate, workspace-shared, local-machine-home, bash-default, user-default" ) $( rigSum "$rigOwn" )" "1 0 1 1 $rigOwnBefore"

echo "-- 3. a setting of the workspace: the bounds of a control request --"
rigRun "$rigWrite" SESSION_CONTROL_REQUEST_SECONDS 12
rigAssert "a number in its range is saved in the settings of the team: one row with the key, the value, the scope and the file" "$rigRc $( rigTroubles ) [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )]" "0 0 [saved SESSION_CONTROL_REQUEST_SECONDS 12 workspace $rigTeam]"
rigAssert "every other line of that file stays as it was, the note and the secret among them, the key stands once, and the file keeps its mode" "$( LC_ALL=C tr '\n' '|' < "$rigTeam" ) $( ls -l "$rigTeam" | LC_ALL=C cut -c1-10 )" "# a note of the owner|SLACK_BOT_TOKEN=$rigSecret|SPAWN_CLI_SERVICE=claude|SESSION_CONTROL_REQUEST_SECONDS=12| -rw-rw----"
rigAssert "the digest reads it back as the workspace's, and the tooling's own reading of the setting gives it" "$( rigNow SESSION_CONTROL_REQUEST_SECONDS ) / $( rigRun --agents-config-option magic-team --select SESSION_CONTROL_REQUEST_SECONDS ; cat "$rigTmp/out" )" "12 workspace / 12"
rigRun "$rigWrite" SESSION_CONTROL_KILL_SECONDS 600
rigKill="$rigRc [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )]"
rigRun "$rigWrite" SESSION_CONTROL_KILL_SECONDS 5
rigAssert "the largest and the smallest of a range are taken" "$rigKill $rigRc [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )] $( LC_ALL=C grep -c -e '^SESSION_CONTROL_KILL_SECONDS=' "$rigTeam" )" "0 [saved SESSION_CONTROL_KILL_SECONDS 600 workspace $rigTeam] 0 [saved SESSION_CONTROL_KILL_SECONDS 5 workspace $rigTeam] 1"
rigTeamBefore="$( rigSum "$rigTeam" )"
rigBad=""
for rigOne in 0 61 -1 5.5 05 "" "12 " 1e1 123456789 twelve "$rigSecret" ; do
	rigRun "$rigWrite" SESSION_CONTROL_REQUEST_SECONDS "$rigOne"
	[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: the value given is no whole number from 1 to 60, which SESSION_CONTROL_REQUEST_SECONDS takes -- nothing was saved" )" = "1 0 1 1" ] && [ "$( rigSum "$rigTeam" )" = "$rigTeamBefore" ] || rigBad="$rigBad [$rigOne: $( rigRefused "-" )]"
done
rigRun "$rigWrite" SESSION_CONTROL_KILL_SECONDS 4
[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: the value given is no whole number from 5 to 600, which SESSION_CONTROL_KILL_SECONDS takes -- nothing was saved" )" = "1 0 1 1" ] && [ "$( rigSum "$rigTeam" )" = "$rigTeamBefore" ] || rigBad="$rigBad [kill 4]"
rigRun "$rigWrite" SESSION_CONTROL_KILL_SECONDS 601
[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: the value given is no whole number from 5 to 600, which SESSION_CONTROL_KILL_SECONDS takes -- nothing was saved" )" = "1 0 1 1" ] && [ "$( rigSum "$rigTeam" )" = "$rigTeamBefore" ] || rigBad="$rigBad [kill 601]"
rigAssert "a value outside the kind is refused, rc 1, in one line with the range, and the file is as it was: below the smallest, above the largest, a sign, a fraction, a leading nought, none, a blank, another notation, too many digits, a word, a pasted secret" "${rigBad:- each refused}" " each refused"
cp "$rigTeam" "$rigTmp/team.kept"
printf 'SESSION_CONTROL_REQUEST_SECONDS=120\n' >> "$rigTeam"
rigAssert "a number saved by hand outside the range is shown as it is, since the tooling reads it so" "$( rigNow SESSION_CONTROL_REQUEST_SECONDS )" "120 workspace"
printf 'SESSION_CONTROL_REQUEST_SECONDS=soon\n' >> "$rigTeam"
rigAssert "and what is no number counts as not saved: the default, as the tooling reads it" "$( rigNow SESSION_CONTROL_REQUEST_SECONDS )" "5 default"
cp "$rigTmp/team.kept" "$rigTeam" ; chmod 660 "$rigTeam"

echo "-- 4. what is refused --"
rigOwnBefore="$( rigSum "$rigOwn" )" ; rigTeamBefore="$( rigSum "$rigTeam" )"
rigNoKey="⛔ ERROR: DistroAgentsTools $rigWrite: the key given is none of the changeable settings -- nothing was saved. Its keys: $rigKeys"
rigBad=""
for rigOne in SPAWN_CLI_SERVICE SPAWN_HARNESS_TIER WAIT_ROUND_SECONDS MDLT_CONSOLE_ORIGIN MDSC_DETAIL SESSION_CONTROL_TICK_SECONDS SLACK_BOT_TOKEN history "" ; do
	rigRun "$rigWrite" "$rigOne" "$rigSecret"
	[ "$( rigRefused "$rigNoKey" )" = "1 0 1 1" ] || rigBad="$rigBad [$rigOne]"
done
rigAssert "a key that is none of the changeable settings is refused, rc 1, in one line that lists them: every key of the configuration, the CLI service, the tier, the wait round, the origin of the consoles, the debug output, the key of a secret; a tick no line shows; a short name; none" "${rigBad:- each refused}" " each refused"
rigBad=""
rigRun "$rigWrite" ; [ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 0 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad none"
rigRun "$rigWrite" MDLT_CONSOLE_HISTORY ; [ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 1 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad one"
rigRun "$rigWrite" MDLT_CONSOLE_HISTORY bash-default more ; [ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 3 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad three"
rigAssert "no word, a key alone and a third word are refused with the syntax" "${rigBad:- each refused}" " each refused"
rigCallerBad=""
for rigOne in keeper-rig magic-coordinator ; do
	rigPre=( "MDAT_SPAWN_AGENT=$rigOne" )
	rigRun "$rigWrite" SESSION_CONTROL_REQUEST_SECONDS 7
	rigPre=()
	[ "$rigRc" = 1 ] && [ ! -s "$rigTmp/out" ] && [ "$( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigWrite#--}: ⛔ ERROR: this session acts as $rigOne, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" = 1 ] || rigCallerBad="$rigCallerBad [$rigOne]"
done
rigAssert "a change of the workspace's is the console's alone to make: from inside a member's session it is refused by the one rule of the family, magic-coordinator's too" "${rigCallerBad:-each refused}" "each refused"
rigRun --manager-config-interface-set MDAT_MANAGER_STYLE mc
rigAssert "the earlier name of the operation is gone: it is no option, and saves nothing" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-config-interface-set" )" "1 1"
rigAssert "after every refusal the user's file and the settings of the team are as they were, and nothing that was given stands in what any call printed" "$( rigSum "$rigOwn" ) $( rigSum "$rigTeam" ) $( LC_ALL=C grep -c -F -e 'RIGSECRET' "$rigTmp/all" || : )" "$rigOwnBefore $rigTeamBefore 0"

echo "-- 5. the help pair, and what was never reached --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigWrite <key> <value>"
rigEntry(){ ## -- the writer's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s <key> <value>' "$rigWrite" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the writer has its syntax echo, its syntax line and its entry, once each, and the earlier name stands nowhere in the help" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s <key> <value>' "$rigWrite" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -e 'manager-config-interface-set' "$rigHelpInclude" "$rigHelpMd" | LC_ALL=C awk -F: '{ n += $2 } END { print n + 0 }' )" "1 1 1 0"
rigAssert "its entry names each key it takes, the two kinds and the two scopes" "$( for rigWord in MDAT_MANAGER_STYLE MDLT_CONSOLE_HISTORY SESSION_CONTROL_REQUEST_SECONDS SESSION_CONTROL_KILL_SECONDS choice number user workspace ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyy"
rigAssert "what the user who runs this check and the real workspace have saved is as it was" "$( rigSum "$rigRealUser" ) $( rigSum "$rigRealTeam" )" "$rigRealBefore"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER CONFIG SET CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_CONFIG_SET: OK (%d assertions, offline)\n' "$rigPasses"
