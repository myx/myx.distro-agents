#!/usr/bin/env bash
## Behavioural check on --manager-console-list, the operation of the console's own family --manager-* that lists the
## consoles that can be started from this workspace right now, run rather than read, against a rig workspace built
## here. Held: the whole output, byte for byte -- one `console` row a console, with its key, its group for a menu,
## its label, whether it needs a terminal, the folder to start it in, and then its command, one field a word: the
## bash shell of the workspace, each vendor CLI the workspace's own console command names and that is usable here,
## and each of the four other Distro consoles whose command is in the workspace root and executable; the rows in
## the order of a menu. NOTHING IS LISTED THAT WOULD NOT START: with none of the Distro consoles there are no rows
## of theirs; one that is not executable, and a folder of that name, is no row; a CLI whose command is not on PATH
## is no row; with no console command, with one that is not executable, and with one that names no vendor CLI,
## there is no row of a CLI at all, and a console command that names one vendor CLI gives that one alone, whatever
## else is on PATH. A ROW'S COMMAND REALLY STARTS, handed word by word to exec with no shell, in the folder the row
## names, on a pseudo-terminal, with nothing in the environment but a home, a PATH and a terminal type: a stand-in
## Distro console that prints and ends; the vendor CLI, through the real generated console command, by its name;
## and the bash shell, which comes up as this workspace's, with the tooling's functions and its tools on PATH. The
## fields of the command are exact: a blank in the workspace's path stays a blank there, while the label carries
## `_`. The call reads only: no file of the rig changes. No field holds a secret of the settings or of the caller's
## environment. The caller rule of the family holds for it, its place in the family is one arm and one include,
## and its help pair gives the form the output is checked against.
## `claude`, `copilot` and `grok` on the rig's PATH are stubs that write down how they were started: no real CLI
## is started, and no request is made. Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigDriver="$rigPackage/sh-test/check-fixtures/manager-screen.driver.py"
rigScreenFile="$rigHere/AgentsManagerScreen.py"
rigOp="--manager-console-list"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigDriver" ] || rigRefuse "the driver that makes the pseudo-terminal is missing from the package: $rigDriver"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerConsoleListCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigHome" "$rigSkills" "$rigTmp/bin-all" "$rigTmp/bin-claude" "$rigTmp/bin-none"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigTab="$( printf '\t' )"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE RIG'S OWN PATHS: all three vendor CLIs, claude alone, none. Each CLI is a stub that writes down how it was
## started; the system's own folders hold none of them.
rigSystemPath="/usr/bin:/bin"
[ -z "$( PATH="$rigSystemPath" command -v claude )$( PATH="$rigSystemPath" command -v copilot )$( PATH="$rigSystemPath" command -v grok )" ] \
	|| rigRefuse "a vendor CLI stands in the system's own folders, so a row of this check could start a real one"
rigCliStub(){ ## folder, name
	printf '#!/bin/sh\nif [ "$1" = auth ] ; then echo "{\\"loggedIn\\":true}" ; exit 0 ; fi\nrigTty=no ; [ -t 0 ] && [ -t 1 ] && rigTty=yes\n{ printf "started %s tty=%%s args=" "$rigTty" ; for rigArg in "$@" ; do printf "[%%s]" "$rigArg" ; done ; printf "\\n" ; } >> "%s/cli.log"\n' "$2" "$rigTmp" > "$1/$2"
	chmod +x "$1/$2"
}
rigCliStub "$rigTmp/bin-all" claude ; rigCliStub "$rigTmp/bin-all" copilot ; rigCliStub "$rigTmp/bin-all" grok
rigCliStub "$rigTmp/bin-claude" claude
rigPathAll="$rigTmp/bin-all:$rigSystemPath" ; rigPathClaude="$rigTmp/bin-claude:$rigSystemPath" ; rigPathNone="$rigTmp/bin-none:$rigSystemPath"
rigPath="$rigPathAll"
rigBash="$( PATH="$rigSystemPath" command -v bash )" ; rigEnv="$( PATH="$rigSystemPath" command -v env )"
case "$rigBash$rigTab$rigEnv" in /*"$rigTab"/*) ;; *) rigRefuse "bash and env are not both found in the system's own folders: [$rigBash] [$rigEnv]" ;; esac

## THE RIG WORKSPACE: its settings name the origin under test, and hold what would be a secret. Its console command
## is generated by the real generator; the four other consoles are stand-ins that write down how they were started,
## print one line and end.
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigWs/.local/MDLT.settings.env"
printf 'ANTHROPIC_API_KEY=rig-sentinel-stored-1\nSLACK_BOT_TOKEN=rig-sentinel-stored-2\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" COPILOT_GITHUB_TOKEN=rig-sentinel-environment-3 ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRun --make-console-command --quiet
[ "$rigRc" = 0 ] && [ -x "$rigWs/DistroAgentsConsole.sh" ] || rigRefuse "no console command was generated into the rig workspace: $( tail -2 "$rigTmp/err" 2> /dev/null )"
cp -p "$rigWs/DistroAgentsConsole.sh" "$rigTmp/console.generated"
rigStandIn(){ ## workspace, name (Source, Local, Deploy, Remote)
	printf '#!/bin/sh\nrigTty=no ; [ -t 0 ] && [ -t 1 ] && rigTty=yes\nprintf "%s console started in=%%s tty=%%s words=%%s\\n" "$( pwd -P )" "$rigTty" "$#" >> "%s/started.log"\necho "RIG-%s-CONSOLE"\n' "$2" "$rigTmp" "$2" > "$1/Distro$2Console.sh"
	chmod +x "$1/Distro$2Console.sh"
}
rigStandIns(){ ## workspace -- all four
	for rigName in Source Local Deploy Remote ; do rigStandIn "$1" "$rigName" ; done
}
rigStandIns "$rigWs"

rigReason="this is the bash shell of the workspace, started by its own name from the list of consoles."
rigRc="$rigHere/console-agents-bashrc.rc"
rigRowBash(){ ## workspace
	printf 'console\tbash\tshell\tBash_Shell\tterminal\t%s\t%s\tMMDAPP=%s\tMDLT_ORIGIN=%s\tMDAT_CONSOLE_FALLBACK_REASON=%s\t%s\t--rcfile\t%s\t-i\n' "$1" "$rigEnv" "$1" "$MDLT_ORIGIN" "$rigReason" "$rigBash" "$rigHere/console-agents-bashrc.rc"
}
rigRowCli(){ ## workspace, name, label
	printf 'console\t%s\tagents\t%s\tterminal\t%s\t%s/DistroAgentsConsole.sh\t--cli\t%s\n' "$2" "$3" "$1" "$1" "$2"
}
rigRowDistro(){ ## workspace, key, label, name
	printf 'console\t%s\tdistro\t%s\tterminal\t%s\t%s/Distro%sConsole.sh\n' "$2" "$3" "$1" "$1" "$4"
}
rigRowsCli(){ ## workspace -- the three vendor CLIs, in the order the console command names them
	rigRowCli "$1" copilot-native Copilot_Native_Console
	rigRowCli "$1" claude-native Claude_Native_Console
	rigRowCli "$1" grok-native Grok_Native_Console
}
rigRowsDistro(){ ## workspace -- the four other consoles, in the order of the menu
	rigRowDistro "$1" source Source_Console Source
	rigRowDistro "$1" local Local_Tools_Console Local
	rigRowDistro "$1" deploy Deploy_Console Deploy
	rigRowDistro "$1" remote Remote_Console Remote
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigKeys(){ ## -- the keys of the rows of the last output, in their order, in one line
	LC_ALL=C awk -F'\t' '$1 == "console" { printf "%s ", $2 }' "$rigTmp/out"
}
rigMachine(){ ## -- every file of the rig, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws home skills -type f | LC_ALL=C sort | while IFS= read -r machineFile ; do printf '%s %s\n' "$machineFile" "$( cksum < "$machineFile" )" ; done ) | cksum
}

echo "-- 1. everything is there: the bash shell, three vendor CLIs, four other consoles, in the order of a menu --"
rigMachineBefore="$( rigMachine )"
rigRun "$rigOp"
cp "$rigTmp/out" "$rigTmp/list.kept"
rigAssert "the whole list, byte for byte, rc 0" "$rigRc $( cat "$rigTmp/out" )" "0 $( rigRowBash "$rigWs" ; rigRowsCli "$rigWs" ; rigRowsDistro "$rigWs" )"
rigAssert "nothing on stderr is an error or a warning"                  "$( rigTroubles )" 0
rigAssert "the call reads only: no file of the rig changed"             "$( rigMachine )" "$rigMachineBefore"
rigAssert "no field holds a secret of the settings or of the caller's environment" "$( LC_ALL=C grep -c -e 'rig-sentinel' "$rigTmp/out" "$rigTmp/err" | LC_ALL=C tr '\n' ' ' )" "$rigTmp/out:0 $rigTmp/err:0 "

echo "-- 2. nothing is listed that would not start: the other Distro consoles --"
rm -f "$rigWs"/Distro{Source,Local,Deploy,Remote}Console.sh
rigRun "$rigOp"
rigAssert "with none of them, the bash shell and the vendor CLIs are the whole list" "$rigRc $( cat "$rigTmp/out" )" "0 $( rigRowBash "$rigWs" ; rigRowsCli "$rigWs" )"
rigStandIn "$rigWs" Source ; rigStandIn "$rigWs" Deploy ; chmod 644 "$rigWs/DistroDeployConsole.sh" ; mkdir "$rigWs/DistroRemoteConsole.sh"
rigRun "$rigOp"
rigAssert "one that is there and executable is a row; one that is not executable, and a folder of that name, is none" "$rigRc $( rigKeys )" "0 bash copilot-native claude-native grok-native source "
rmdir "$rigWs/DistroRemoteConsole.sh" ; rigStandIns "$rigWs"

echo "-- 3. nothing is listed that would not start: the vendor CLIs --"
rigPath="$rigPathClaude" ; rigRun "$rigOp"
rigAssert "with claude alone on PATH, claude-native is the one row of a CLI" "$rigRc $( rigKeys )" "0 bash claude-native source local deploy remote "
rigPath="$rigPathNone" ; rigRun "$rigOp"
rigAssert "with no vendor CLI on PATH there is no row of a CLI"         "$rigRc $( rigKeys )" "0 bash source local deploy remote "
rigPath="$rigPathAll"
rm -f "$rigWs/DistroAgentsConsole.sh" ; rigRun "$rigOp"
rigAssert "with no console command there is no row of a CLI, whatever is on PATH" "$rigRc $( rigKeys )" "0 bash source local deploy remote "
cp -p "$rigTmp/console.generated" "$rigWs/DistroAgentsConsole.sh" ; chmod 644 "$rigWs/DistroAgentsConsole.sh" ; rigRun "$rigOp"
rigAssert "nor with one that is not executable"                         "$rigRc $( rigKeys )" "0 bash source local deploy remote "
printf '#!/bin/sh\necho "RIG-OLD-CONSOLE"\n' > "$rigWs/DistroAgentsConsole.sh" ; chmod 755 "$rigWs/DistroAgentsConsole.sh" ; rigRun "$rigOp"
rigAssert "nor with one that names no vendor CLI, which could start none by its name" "$rigRc $( rigKeys )" "0 bash source local deploy remote "
printf '#!/bin/sh\nDAGC_VENDOR_CLIS="claude-native"\necho "RIG-OLDER-CONSOLE"\n' > "$rigWs/DistroAgentsConsole.sh" ; rigRun "$rigOp"
rigAssert "a console command that names one vendor CLI gives that one alone, whatever else is on PATH" "$rigRc $( rigKeys )" "0 bash claude-native source local deploy remote "
cp -p "$rigTmp/console.generated" "$rigWs/DistroAgentsConsole.sh" ; chmod 770 "$rigWs/DistroAgentsConsole.sh"
rigRun "$rigOp"
rigAssert "control: with the generated console command back, the list is the whole list again" "$( cat "$rigTmp/out" )" "$( cat "$rigTmp/list.kept" )"

echo "-- 4. a row's command really starts: its words to exec with no shell, in its folder, on a pseudo-terminal --"
## The driver hands the words it is given to exec as they are. The environment is a home, a PATH and a terminal
## type, and nothing else: what a row needs beyond that, its own words carry.
rigStart(){ ## key, the text to wait for, the keys -- starts that row of the kept list; what the driver says is kept in rigPty
	local startRow startFolder
	startRow="$( LC_ALL=C awk -F'\t' -v wantKey="$1" '$1 == "console" && $2 == wantKey' "$rigTmp/list.kept" )"
	rigFields=()
	IFS="$rigTab" read -r -a rigFields <<< "$startRow"
	[ "${#rigFields[@]}" -ge 7 ] || { rigPty="pty.rc=no-row" ; return 0 ; }
	startFolder="${rigFields[5]}"
	case "${rigFields[6]}" in "$rigTmp"/*|"$rigEnv") ;; *) rigRefuse "the command of row $1 is outside the rig tree: ${rigFields[6]}" ;; esac
	rigPty="$( cd "$startFolder" && python3 -I -B "$rigDriver" "$rigScreenFile" pty 100 30 "$2" "$3" 60 -- \
		env -i HOME="$rigHome" PATH="$rigPathAll" TERM=xterm "${rigFields[@]:6}" 2>&1 )"
}
rigPtyVal(){ ## name
	printf '%s\n' "$rigPty" | LC_ALL=C sed -n "s/^pty\.$1=//p" | head -1
}
: > "$rigTmp/started.log" ; : > "$rigTmp/cli.log"
rigStart source - -
rigAssert "the stand-in Source console is started once, in the workspace root, on the terminal, with no word after its name, and ends with 0" \
	"$( rigPtyVal rc ) [$( cat "$rigTmp/started.log" )]" "0 [Source console started in=$rigWs tty=yes words=0]"
rigStart claude-native - -
rigAssert "the claude-native row starts the vendor claude through the generated console command, once, on the terminal" \
	"$( rigPtyVal rc ) $( LC_ALL=C grep -c '^started claude tty=yes ' "$rigTmp/cli.log" || : ) $( LC_ALL=C grep -c '^started ' "$rigTmp/cli.log" || : )" "0 1 1"
rigAssert "as a console and no spawn: no prompt option among its words"  "$( LC_ALL=C grep -c -F -- '[-p]' "$rigTmp/cli.log" || : )" 0
rigStart bash "started by its own name from the list of consoles" 'echo "$MMDAPP|$PWD|$( type -t Agents )|$( type -t Help )|$( command -v DistroAgentsTools.fn.sh )" > "$MMDAPP/../shell.log" ; exit 0\r'
rigAssert "the bash shell comes up and says why it is one, and ends with the status it is told to end with" "$( rigPtyVal frame ) $( rigPtyVal rc )" "yes 0"
rigAssert "it is this workspace's shell, in its root, with the tooling's functions and its tools on PATH" \
	"$( cat "$rigTmp/shell.log" 2> /dev/null )" "$rigWs|$rigWs|function|function|$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

echo "-- 5. the fields of the command are exact: a blank in the workspace's path --"
rigBlank="$rigTmp/ws blank"
mkdir -p "$rigBlank/.local/.agents"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigBlank/.local/MDLT.settings.env"
rigStandIn "$rigBlank" Source
rigKept="$rigWs" ; rigWs="$rigBlank" ; rigRun "$rigOp" ; rigWs="$rigKept"
rigAssert "the folder and the words carry the blank as it is, and the label its \`_\`: the bash shell and the one console there" \
	"$rigRc $( cat "$rigTmp/out" )" "0 $( rigRowBash "$rigBlank" ; rigRowDistro "$rigBlank" source Source_Console Source )"
cp "$rigTmp/out" "$rigTmp/list.kept" ; : > "$rigTmp/started.log"
rigStart source - -
rigAssert "and that row starts its console in that folder"              "$( rigPtyVal rc ) [$( cat "$rigTmp/started.log" )]" "0 [Source console started in=$rigBlank tty=yes words=0]"

echo "-- 6. the caller rule, and the place in the family --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family's rule" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"
rigRun "$rigOp" --all
rigAssert "an argument is refused, rc 1, nothing on stdout, in one line with its syntax: the list takes none" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is no argument, got: --all" )" "1 0 1"
rigRun --manager-console-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-console-no-such" )" "1 1"
rigAssert "the family has one arm for the consoles, which sources their include, and that include asks nobody who calls" \
	"$( LC_ALL=C grep -c -x -e '	--manager-console-\*)' "$rigHere/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ManagerConsole.include"' "$rigHere/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConsole.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 1 0"
rigAssert "which CLI is usable is asked of the digest of the settings, and of no second test of its own" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConsole.include" 2> /dev/null | LC_ALL=C grep -c -F -e '--manager-config-digest cli' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConsole.include" 2> /dev/null | LC_ALL=C grep -c -e 'command -v claude' -e 'command -v copilot' -e 'command -v grok' -e '%-native' || : )" "1 0"

echo "-- 7. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm="$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(console <.*\)`$/\1/p' )"
rigAssert "its entry gives the form of a row" "$rigForm" "console <key> <group> <label> <terminal> <directory> <word>..."
rigRun "$rigOp"
rigAssert "and every row printed has the six fields that form names and at least one word of a command, none of them empty" \
	"$( LC_ALL=C awk -F'\t' '{ rows++ ; if ( NF < 7 ) bad++ ; for ( fieldAt = 1 ; fieldAt <= NF ; fieldAt++ ) if ( $fieldAt == "" ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" )" "rows:0"
rigAssert "the entry names the three groups, the word of <terminal>, the keys that are no CLI's, and how a CLI is started" "$( for rigWord in shell agents distro terminal bash source local deploy remote 'DistroAgentsConsole.sh --cli <name>' ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyyyy"
rigAssert "control: the entry was cut up to the next operation's heading, and holds its own text" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C awk 'END { print ( NR > 0 && NR < 70 ) ? "cut" : "not cut: " NR " lines" }' )" "1 cut"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER CONSOLE LIST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_CONSOLE_LIST: OK (%d assertions, offline)\n' "$rigPasses"
