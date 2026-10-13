#!/usr/bin/env bash
## Behavioural check on the interface settings of the console's user, run rather than read: the `interface` subject
## of --manager-config-digest, which reads them, and --manager-config-set <key> <value>, which saves one
## through the setting reader of the sibling package in its scope of the current user. Against a rig workspace
## built here WITH ITS OWN USER SETTINGS: every call runs with MMDAPP at the rig, so the file of the user who runs
## this check is the rig's own, and what that user saved in the real workspace is never read and never written,
## which the last section asserts.
## Held: with nothing saved the subject has one line, the interface style, with its key, the default as its value,
## `default` as where it comes from and the values to choose from with their labels, its two own fields after the
## six of the digest's row, and then the label every row ends with; the environment names a style ahead of a saved one, and a name that is no style counts
## as not given wherever it stands; a setting of the same key in the workspace's own file is not read. The writer
## saves each of the three styles, prints one row with the key, the value now saved and the file, keeps every other
## line of the user's file and leaves no temp file; a value that is no style, a key that is no interface setting
## and a wrong count of arguments are each refused in one line with nothing changed, and nothing that was given is
## repeated in a refusal, a pasted secret among it. The settings of another user of the workspace are never touched,
## also where the environment names that user. From inside a member's session the writer is refused. The values
## offered are the styles the screen declares. And the help pair, with the row forms the output is checked against.
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigScreen="$rigHere/AgentsManagerScreen.py"
rigRead="--manager-config-digest"
rigWrite="--manager-config-set"
rigKey="MDAT_MANAGER_STYLE"
rigChoices="tv=Turbo_Vision,mc=MC_(Compact),bw=B/W"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin this workspace resolves: $rigScreen"
rigTmp="$( mktemp -d -t AgentsManagerConfigInterfaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/.local/home/rig-other-user" "$rigHome" "$rigSkills"
rigTab="$( printf '\t' )"

## THE USERS. The one who runs this check, by the name the operating system gives, whose settings file in the rig
## does not exist yet; and another user of the rig workspace, who has saved a style and a setting of the console.
rigUser="$( id -un )" || rigRefuse "the name of the user who runs this check cannot be read"
[ -n "$rigUser" ] && [ "$rigUser" != "rig-other-user" ] || rigRefuse "the user who runs this check has no name of its own"
rigOwn="$rigWs/.local/home/$rigUser/MDLT.settings.env"
rigOther="$rigWs/.local/home/rig-other-user/MDLT.settings.env"
rigShared="$rigWs/.local/MDLT.settings.env"
printf '%s=mc\nMDLT_CONSOLE_HISTORY=bash-default\n' "$rigKey" > "$rigOther"
## The workspace's own settings file holds the key too: that file is everybody's, and is not where a user's style is kept.
printf 'MDLT_CONSOLE_ORIGIN=.local\n%s=bw\n' "$rigKey" > "$rigShared"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; : > "$rigWs/.local/.agents/magic-team.agent.env"
chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
## What that user saved in the REAL workspace, which no call of this check may reach.
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigReal="${MMDAPP%/}/.local/home/$rigUser/MDLT.settings.env"
## A value nobody may see again: given to the writer as if pasted by mistake.
rigSecret="Zk4pQeRIGSECRET21Hw8tUo"

## THE RIG'S OWN PATH: its bin, then the system's own folders; a curl that would log a request.
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
rigStyle(){ ## -- the line of the interface style in the last output: its value, where it comes from and its choices, a space between them
	LC_ALL=C awk -F'\t' -v wantKey="$rigKey" '$1 == "line" && $2 == "interface" && $3 == "style" && $4 == wantKey && $5 == "set" { print $6, $7, $8 ; }' "$rigTmp/out"
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
rigTree(){ ## -- every file of the rig's workspace, home and skills but the settings of the user who runs this check, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws home skills -type f ! -path "ws/.local/home/$rigUser/*" 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}
rigRefused(){ ## the one line of the refusal -- the last call: its rc, the bytes of its stdout, how many lines of its stderr are that line, and how many are an error at all
	printf '%s %s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( rigWhole "$rigTmp/err" "$1" )" "$( rigTroubles )"
}
rigRealBefore="$( rigSum "$rigReal" )"
rigTreeBefore="$( rigTree )"
rigOtherBefore="$( rigSum "$rigOther" )"

echo "-- 1. the subject of the interface, with nothing saved --"
rigRun "$rigRead" interface
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the subject has one line, the interface style: its key, the default as its value, where the value comes from, and the values to choose from with their labels, its two own fields after the value; and each row ends with its label" "$( cat "$rigTmp/out" )" "$( printf 'subject\tinterface\t1\tInterface_Settings\nline\tinterface\tstyle\t%s\tset\ttv\tdefault\t%s\tInterface_Style' "$rigKey" "$rigChoices" )"
rigAssert "reading made nothing: the user has no settings file and no folder, and the rig is as it was" "$( rigSum "$rigOwn" ) $( [ -e "${rigOwn%/*}" ] && echo folder || echo no-folder ) $( rigTree )" "absent no-folder $rigTreeBefore"
rigAssert "control: the workspace's own settings file holds the key, and another user has saved one: neither is the user's own" "$( LC_ALL=C grep -c -x -e "$rigKey=bw" "$rigShared" ) $( LC_ALL=C grep -c -x -e "$rigKey=mc" "$rigOther" )" "1 1"
cp "$rigTmp/out" "$rigTmp/alone"
rigRun "$rigRead"
rigAssert "in the whole digest it stands after the scopes, with the same rows" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s ", $2 }' "$rigTmp/out" )/ $( LC_ALL=C awk -F'\t' '$2 == "interface"' "$rigTmp/out" | cksum )" "0 workspace cli systems loop scopes interface console control / $( cksum < "$rigTmp/alone" )"
rigAssert "every other line of the digest has the six fields it had, and its label" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 != "interface" { rows++ ; if ( NF != 7 ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" )" "rows:0"

echo "-- 2. the environment names a style --"
rigPre=( "$rigKey=mc" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "the style the environment names is the value, and the line says that it comes from there" "$rigRc [$( rigStyle )]" "0 [mc environment $rigChoices]"
rigPre=( "$rigKey=zz" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "a name in the environment that is no style counts as not given: the default" "$rigRc [$( rigStyle )]" "0 [tv default $rigChoices]"
rigPre=( "$rigKey=" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "and so does an empty one" "$rigRc [$( rigStyle )]" "0 [tv default $rigChoices]"

echo "-- 3. the writer saves each of the three styles --"
for rigOne in mc bw tv ; do
	rigRun "$rigWrite" "$rigKey" "$rigOne"
	rigSaved="$rigRc $( rigTroubles ) [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )] [$( cat "$rigOwn" 2> /dev/null )]"
	rigRun "$rigRead" interface
	rigAssert "$rigOne: rc 0 and no error, one row with the key, the value now saved, its scope and the file it is saved in; the user's file holds it on its one line; the digest reads it back as the user's own" "$rigSaved [$( rigStyle )]" "0 0 [saved $rigKey $rigOne user $rigOwn] [$rigKey=$rigOne] [$rigOne user $rigChoices]"
done
rigAssert "the row of the writer has exactly the fields of its form, TAB between them" "$( rigRun "$rigWrite" "$rigKey" tv ; LC_ALL=C awk -F'\t' '{ print NR, NF, $1 }' "$rigTmp/out" )" "1 5 saved"
printf '# a note of the user\nMDLT_CONSOLE_HISTORY=workspace-shared\n' >> "$rigOwn"
rigRun "$rigWrite" "$rigKey" mc
rigAssert "another setting of the user and a comment stay as they were, and the key stands once, with the new value" "$rigRc $( LC_ALL=C sort "$rigOwn" | LC_ALL=C tr '\n' '|' )" "0 # a note of the user|$rigKey=mc|MDLT_CONSOLE_HISTORY=workspace-shared|"
rigRun "$rigWrite" "$rigKey" mc
rigAssert "saving the value that is saved already is no error and leaves one line" "$rigRc [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )] $( LC_ALL=C grep -c -e "^$rigKey=" "$rigOwn" )" "0 [saved $rigKey mc user $rigOwn] 1"
rigAssert "no temp file is left beside the user's file" "$( ls -A "${rigOwn%/*}" | LC_ALL=C tr '\n' ' ' )" "MDLT.settings.env "

echo "-- 4. the environment ahead of the saved style --"
rigPre=( "$rigKey=bw" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "with a style saved and another in the environment, the environment's is the value" "$rigRc [$( rigStyle )]" "0 [bw environment $rigChoices]"
rigPre=( "$rigKey=zz" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "a name in the environment that is no style leaves the saved one" "$rigRc [$( rigStyle )]" "0 [mc user $rigChoices]"
cp "$rigOwn" "$rigTmp/own.kept"
printf '%s=zz\n' "$rigKey" > "$rigOwn"
rigRun "$rigRead" interface
rigAssert "a saved name that is no style, written by hand, counts as not saved: the default, and the name is not printed" "$rigRc [$( rigStyle )] $( LC_ALL=C grep -c -e 'zz' "$rigTmp/out" "$rigTmp/err" | LC_ALL=C awk -F: '{ n += $2 } END { print n + 0 }' )" "0 [tv default $rigChoices] 0"
cp "$rigTmp/own.kept" "$rigOwn"

echo "-- 5. a value that is no style is refused --"
rigOwnBefore="$( rigSum "$rigOwn" )"
rigNoValue="⛔ ERROR: DistroAgentsTools $rigWrite: the value given is none of the values of $rigKey -- nothing was saved. Its values: tv, mc, bw"
rigBad=""
for rigOne in zz TV "tv " " tv" "tv=Turbo Vision" "Turbo Vision,mc" "Turbo_Vision" "*" "" "$rigSecret" ; do
	rigRun "$rigWrite" "$rigKey" "$rigOne"
	[ "$( rigRefused "$rigNoValue" )" = "1 0 1 1" ] && [ "$( rigSum "$rigOwn" )" = "$rigOwnBefore" ] || rigBad="$rigBad [$rigOne: $( rigRefused "$rigNoValue" )]"
done
rigAssert "each is refused, rc 1, nothing on stdout, in one line that lists the values, and the user's file is as it was: a name that is none, one in capitals, one with a space, a label, a pair, a pattern, an empty one, a pasted secret" "${rigBad:- each refused}" " each refused"
rigAssert "nothing that was given is repeated in a refusal: the pasted secret stands nowhere in what any call printed" "$( LC_ALL=C grep -c -F -e 'RIGSECRET' "$rigTmp/all" || : )" "0"

echo "-- 6. a key that is no interface setting is refused, and so is a wrong count of arguments --"
rigNoKey="⛔ ERROR: DistroAgentsTools $rigWrite: the key given is none of the changeable settings -- nothing was saved. Its keys: $rigKey, MDLT_CONSOLE_HISTORY, SESSION_CONTROL_REQUEST_SECONDS, SESSION_CONTROL_KILL_SECONDS"
rigBad=""
for rigOne in MDLT_CONSOLE_ORIGIN SLACK_BOT_TOKEN style mdat_manager_style "$rigKey=bw" "$rigKey " "*" "" ; do
	rigRun "$rigWrite" "$rigOne" bw
	[ "$( rigRefused "$rigNoKey" )" = "1 0 1 1" ] && [ "$( rigSum "$rigOwn" )" = "$rigOwnBefore" ] || rigBad="$rigBad [$rigOne: $( rigRefused "$rigNoKey" )]"
done
rigAssert "each is refused, rc 1, nothing on stdout, in one line that lists the keys, and the user's file is as it was: a setting of the console, the key of a secret, the short name, small letters, a key with its value, a pattern, an empty one" "${rigBad:- each refused}" " each refused"
rigRun "$rigWrite" SLACK_BOT_TOKEN "$rigSecret"
rigAssert "the key of a secret with a value is refused like any other, and nothing of it is saved in the user's file or anywhere in the rig" "$( rigRefused "$rigNoKey" ) $( LC_ALL=C grep -r -l -F -e 'RIGSECRET' "$rigWs" "$rigHome" 2> /dev/null | wc -l | LC_ALL=C tr -d ' ' )" "1 0 1 1 0"
rigBad=""
rigRun "$rigWrite"
[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 0 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad none"
rigRun "$rigWrite" "$rigKey"
[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 1 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad one"
rigRun "$rigWrite" "$rigKey" bw tv
[ "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigWrite: syntax is $rigWrite <key> <value>, got 3 argument(s) -- nothing was saved" )" = "1 0 1 1" ] || rigBad="$rigBad three"
rigAssert "no argument, a key alone and a third word are refused with the syntax, and the user's file is as it was" "${rigBad:- each refused} $( rigSum "$rigOwn" )" " each refused $rigOwnBefore"

echo "-- 7. the settings of another user are never touched --"
rigAssert "after every call so far the other user's file is as it was, byte for byte, and so is every other file of the rig: the workspace's own settings, the scopes" "$( rigSum "$rigOther" ) $( rigTree )" "$rigOtherBefore $rigTreeBefore"
rigPre=( "USER=rig-other-user" "LOGNAME=rig-other-user" ) ; rigRun "$rigWrite" "$rigKey" bw ; rigPre=()
rigAssert "with the environment naming the other user, the style is still saved for the user who runs the call, and the row names that user's file" "$rigRc [$( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" )] $( LC_ALL=C grep -c -x -e "$rigKey=bw" "$rigOwn" )" "0 [saved $rigKey bw user $rigOwn] 1"
rigAssert "and the other user's file is as it was" "$( rigSum "$rigOther" ) $( LC_ALL=C grep -c -x -e "$rigKey=mc" "$rigOther" )" "$rigOtherBefore 1"
rigPre=( "USER=rig-other-user" "LOGNAME=rig-other-user" ) ; rigRun "$rigRead" interface ; rigPre=()
rigAssert "it is read from the same user's file too: the other user's style is not shown" "$rigRc [$( rigStyle )]" "0 [bw user $rigChoices]"
rigAssert "nothing but the one file of the user who runs the calls was written in the rig, and no folder was made beside the two users'" "$( rigTree ) $( ls -A "$rigWs/.local/home" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "$rigTreeBefore $( printf '%s\n' rig-other-user "$rigUser" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"

echo "-- 8. the place of the writer in its family --"
rigOwnBefore="$( rigSum "$rigOwn" )"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigWrite" "$rigKey" tv
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, by the one rule of the family, and nothing is saved" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigWrite#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" ) $( rigSum "$rigOwn" )" "1 0 1 $rigOwnBefore"
rigAssert "the include of the settings names the writer of the scope of the current user once, beside the one of the scope of the team, and no form of the reader that removes a setting" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -e '--upsert' -e '--delete' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -F -e '--custom-config-option --upsert "$1" "$2"' || : )" "2 1"
rigAssert "and the writer makes no temp file of its own: the include names no \$\$ and no mktemp" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -e '\$\$' -e 'mktemp' || : )" "0"

echo "-- 9. the values offered are the styles of the screen --"
rigAssert "each value and its label is a style the screen declares, in the screen's order, and there is no other" "$( LC_ALL=C awk '/^STYLES = \($/ { on = 1 ; next } on && /^\)$/ { exit } on' "$rigScreen" | LC_ALL=C sed -n 's/^    ("\([^"]*\)", {"label": "\([^"]*\)".*$/\1=\2/p' | LC_ALL=C tr ' ' '_' | LC_ALL=C tr '\n' ',' )" "$rigChoices,"
rigAssert "a changeable setting cannot come without its label and its description: each row of the declaration of the settings has a row of its own in the one declaration of the labels" "$( rigLacking="" ; rigCount=0 ; while IFS='|' read -r rigOwner rigGroup rigOne rigRest ; do [ -n "$rigOne" ] || continue ; rigCount=$(( rigCount + 1 )) ; LC_ALL=C sed -n '/^agentsManagerConfigLabels="/,/"$/p' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -q -e "^$rigOwner|$rigGroup|$rigOne|[A-Z][^|]*|[^|]*|[A-Z]" || rigLacking="$rigLacking $rigOne" ; done <<< "$( LC_ALL=C sed -n '/^agentsManagerConfigSettings="/,/"$/p' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C sed -e 's/^agentsManagerConfigSettings="//' -e 's/"$//' )" ; printf '%s%s' "$rigCount" "${rigLacking:- none-lacking}" )" "4 none-lacking"
rigAssert "the default is the style the screen starts in, and the key is the variable of the environment the screen reads" "$( LC_ALL=C sed -n 's/^STYLE_FIRST = "\(.*\)"$/\1/p' "$rigScreen" ) $( LC_ALL=C sed -n 's/^STYLE_VARIABLE = "\(.*\)"$/\1/p' "$rigScreen" )" "tv $rigKey"

echo "-- 10. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigWrite <key> <value>"
rigEntry(){ ## heading -- that operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigForm(){ ## heading, row kind -- the form line of that row in that entry, its back quotes and its indent taken off
	rigEntry "$1" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$2"' <.*>\)`$/\1/p'
}
rigAssert "the writer has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s <key> <value>' "$rigWrite" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigWrite" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigWrite" "$rigHelpMd" || : )" "1 1 1 1 1"
rigAssert "its entry gives the form of its row, which is the row it prints" "$( rigForm "$rigWrite <key> <value>" saved )" "saved <key> <value> <scope> <where>"
rigAssert "its entry says whose setting it saves, that the others' are not touched, and names the refusals" "$( for rigWord in 'the user who runs' 'another user' 'nothing was saved' 'MDLT.settings.env' ; do rigEntry "$rigWrite <key> <value>" | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e "$rigWord" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyy"
rigAssert "the entry of the digest gives the form of a line of the interface, with its two fields after the value and its label the last" "$( rigForm "$rigRead [--full] [<subject>...]" 'line interface' )" "line interface <group> <key> <state> <value> <source> <choices> <label>"
rigRun "$rigRead" interface
rigAssert "and each line of the interface printed has exactly those fields" "$( LC_ALL=C awk -F'\t' -v wantFields="$( rigForm "$rigRead [--full] [<subject>...]" 'line interface' | LC_ALL=C awk '{ print NF }' )" '$1 == "line" { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" )" "rows:0"
rigAssert "the entry of the digest names the subject, the three places a value comes from, and the key of the style" "$( for rigWord in interface user environment default "$rigKey" ; do rigEntry "$rigRead [--full] [<subject>...]" | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyy"
rigRun --help-syntax
rigAssert "--help-syntax prints the writer's line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

echo "-- 11. the real workspace and the network were never reached --"
rigAssert "what the user who runs this check saved in the real workspace is as it was" "$( rigSum "$rigReal" )" "$rigRealBefore"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER CONFIG INTERFACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_CONFIG_INTERFACE: OK (%d assertions, offline)\n' "$rigPasses"
