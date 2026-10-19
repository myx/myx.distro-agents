#!/usr/bin/env bash
## The guard over how the package names bash. A script whose first line names bash by a fixed path cannot be
## started where bash is kept elsewhere (FreeBSD: /usr/local/bin/bash): the client or the harness that starts
## such a hook gets status 126, "bad interpreter", and reads that as a refusal. Held here:
##   1. FIRST LINES. No file of the package starts with a line that names bash by a path. A bash script starts
##      `#!/usr/bin/env bash`, which finds bash on the PATH on every system the tooling runs on (macOS, Linux,
##      FreeBSD). `#!/bin/sh` is right as it is.
##   2. LITERALS. No line of the code (sh-lib, sh-scripts, sh-test, builders, vscode; the *.md texts and comment
##      lines are not read) holds a fixed path to bash, /bin/bash or any other. The few that stand are on the one
##      list below, each with its reason. A new one fails this check, and so does a line of the list that the
##      code no longer holds as often as it says.
##   3. STARTS BY PATH. The tooling's own bash code (sh-lib, sh-scripts, builders) starts the tool script with
##      the bash it runs in, `"$BASH" <script> ...`, never by the script's path alone, which leans on the
##      script's first line and on a bash on the PATH of whoever started the tooling. Read here: the tool script
##      as a command word, with an option or "$@" after it, named by its path or by a variable that an
##      assignment of the tooling gives that path ("$grantTools" --...). A start of another script, the console
##      or the harness, cannot be told from an argument by its text and is not read by this section;
##      AgentsBashPathProofCheck runs the hooks and the console that way.
## Red: a hook of sh-lib/client-hooks that starts with a fixed path to bash fails section 1; a fixed path to bash
## in a line of sh-lib fails section 2; the tool script started by its path alone in sh-lib fails section 3.
## Offline: reads the files of the package and nothing else.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/sh-lib/client-hooks" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigPackage"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashPathGuardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE READER OF FIRST LINES. A first line that starts `#!` and names bash is `#!/usr/bin/env bash`, exactly.
rigFirstLines(){ ## the files on stdin, one a line, read from the current directory
	local firstFile firstLine
	while IFS= read -r firstFile ; do
		firstLine=""
		IFS= LC_ALL=C read -r firstLine < "$firstFile" 2> /dev/null || :
		case "$firstLine" in
			'#!/usr/bin/env bash') ;;
			'#!'*bash|'#!'*bash[!A-Za-z0-9_.-]*) printf 'FIRST LINE: %s: %s\n' "$firstFile" "$firstLine" ;;
		esac
	done
}

## THE LIST OF LITERALS. One line a place: file, under the package|how many times it stands there|the text that
## holds the fixed path|the reason it is left.
rigLiteralList(){
	printf '%s\n' \
		'sh-test/AgentsAdvanceInputScanStatesCheck.test.sh|1|rigDlBash=/bin/bash|the old bash a system keeps at that one path (macOS: 3.2), which is what that row of the check is about; where no bash is there, the bash the check runs in stands in for it on the same line' \
		'sh-test/AgentsBashPathProofCheck.test.sh|1|'"'"'#!/bin/bash'"'"'|the control of the proof: a copy of a hook with the first line this guard forbids, started to show that it never asks the PATH for bash' \
		'sh-test/AgentsBashPathProofCheck.test.sh|1|rigNoSuch='"'"'#!/nonexistent-interpreter/bash'"'"'|the first line of the stand-ins of the proof: an interpreter that is on no host, which is what a fixed path to bash is where bash is kept elsewhere' \
		'sh-test/AgentsClaudeSettingsHooksCheck.test.sh|1|printf '"'"'#!/bin/bash\n## the old hand-wired copy|a stand-in for the hook file an earlier install left under .claude/hooks, with the first line those had; it is never run: the check asserts that the install puts the script of the package in its place'
}
## THE LIST OF STARTS BY PATH. The same form: the tool script named by its path as a command, left so on purpose.
rigStartList(){
	printf '%s\n' \
		'sh-lib/AgentsConsoleShellScript.template.sh|1|DistroAgentsTools(){ "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }|the name by which a command of the member reaches the tooling: its body runs in whatever shell that command runs in, where BASH may name a shell in sh mode or nothing at all, so it starts the script by its path and its first line finds bash' \
		'sh-lib/AgentsUniversalHarness.sh|1|DistroAgentsTools(){ "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }|the name by which a command of the member reaches the tooling, exported to the shells its commands run in: its body runs in whatever shell that is, where BASH may name a shell in sh mode or nothing at all, so it starts the script by its path and its first line finds bash'
}
## THE READER OF THE CODE. mode literal: a fixed path to bash, a word that starts with / and ends in /bash and is
## not the tail of a longer word or of an expansion ("$rigBin/bash" is no fixed path). mode start: the tool script
## as a command word, an option or "$@" after it, with no "$BASH" before the word: named by its path, or by one
## of the variables that hold that path (rigGuardNames, which rigToolNames reads out of the files). What the
## list holds for the file is taken out of the line first; what is left and is still one is not on the list.
rigToolNames(){ ## the files -- the variables an assignment gives the path of the tool script, a space between them
	cat "$@" | LC_ALL=C grep -o -E '[A-Za-z_][A-Za-z0-9_]*="[^"]*/sh-scripts/DistroAgentsTools\.fn\.sh"' | LC_ALL=C sed 's/=.*//' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigGuardNames=""
rigGuard(){ ## mode, list file, then the files -- a reader that could not read says so, and never reads as nothing found
	local guardMode="$1" ; shift
	LC_ALL=C awk -F'|' -v guardMode="$guardMode" -v guardNames="$rigGuardNames" '
		function guardLiteral( text ) {
			return ( text ~ "(^|[^A-Za-z0-9_.$}/-])(/[A-Za-z0-9_.-]+)+/bash([^A-Za-z0-9_.-]|$)" ) ;
		}
		function guardStart( text,    wordEnd, at, rest, pre, quoteAt ) {
			wordEnd = "/sh-scripts/DistroAgentsTools.fn.sh\" " ;
			while ( ( at = index( text, wordEnd ) ) > 0 ) {
				pre = substr( text, 1, at - 1 ) ;
				rest = substr( text, at + length( wordEnd ) ) ;
				text = rest ;
				if ( index( rest, "--" ) != 1 && index( rest, "\"$@\"" ) != 1 ) { continue ; }
				quoteAt = length( pre ) ;
				while ( quoteAt > 0 && substr( pre, quoteAt, 1 ) != "\"" ) { quoteAt-- ; }
				if ( quoteAt < 9 || substr( pre, quoteAt - 8, 8 ) != "\"$BASH\" " ) { return 1 ; }
			}
			return 0 ;
		}
		function guardNamedStart( text,    nameAt, word, at, rest, pre ) {
			for ( nameAt = 1 ; nameAt <= guardNameTotal ; nameAt++ ) {
				word = "\"$" guardName[nameAt] "\" " ;
				rest = text ;
				while ( ( at = index( rest, word ) ) > 0 ) {
					pre = substr( rest, 1, at - 1 ) ;
					rest = substr( rest, at + length( word ) ) ;
					if ( index( rest, "--" ) != 1 && index( rest, "\"$@\"" ) != 1 ) { continue ; }
					if ( length( pre ) < 8 || substr( pre, length( pre ) - 7 ) != "\"$BASH\" " ) { return 1 ; }
				}
			}
			return 0 ;
		}
		function guardNamed( text,    nameAt ) {
			for ( nameAt = 1 ; nameAt <= guardNameTotal ; nameAt++ ) { if ( index( text, "\"$" guardName[nameAt] "\"" ) ) { return 1 ; } }
			return 0 ;
		}
		BEGIN { guardNameTotal = split( guardNames, guardName, " " ) ; }
		FNR == NR {
			if ( $0 == "" ) { next ; }
			if ( NF != 4 || $2 !~ /^[0-9]+$/ || $3 == "" || $4 == "" ) { print "LIST: not `file|times|text|reason`: " $0 ; next ; }
			listTotal++ ; listFile[listTotal] = $1 ; listWant[listTotal] = $2 + 0 ; listText[listTotal] = $3 ; listGot[listTotal] = 0 ;
			next ;
		}
		{
			lineText = $0 ; sub( /^[ \t]+/, "", lineText ) ;
			if ( substr( lineText, 1, 1 ) == "#" ) { next ; }
			if ( guardMode == "literal" ? index( lineText, "/bash" ) == 0 : ( index( lineText, "DistroAgentsTools.fn.sh" ) == 0 && ! guardNamed( lineText ) ) ) { next ; }
			## the longest text of the list first
			do {
				bestAt = 0 ; bestLen = 0 ;
				for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
					if ( listFile[listAt] == FILENAME && length( listText[listAt] ) > bestLen && index( lineText, listText[listAt] ) ) { bestAt = listAt ; bestLen = length( listText[listAt] ) ; }
				}
				if ( bestAt ) {
					textAt = index( lineText, listText[bestAt] ) ; listGot[bestAt]++ ;
					lineText = substr( lineText, 1, textAt - 1 ) " " substr( lineText, textAt + bestLen ) ;
				}
			} while ( bestAt ) ;
			if ( guardMode == "literal" ? guardLiteral( lineText ) : ( guardStart( lineText ) || guardNamedStart( lineText ) ) ) { print "NOT ON THE LIST: " FILENAME ":" FNR ": " $0 ; }
		}
		END {
			for ( listAt = 1 ; listAt <= listTotal ; listAt++ ) {
				if ( listGot[listAt] != listWant[listAt] ) { print "LIST: " listFile[listAt] " holds `" listText[listAt] "` " listGot[listAt] " time(s), the list says " listWant[listAt] ; }
			}
		}
	' "$@" || printf 'THE READER DID NOT RUN (%s)\n' "$guardMode"
}
rigSelf="sh-test/${0##*/}"

echo "-- 1. first lines: no file of the package names bash by a path --"
( cd "$rigPackage" && find . -type f ! -path './.git/*' | LC_ALL=C sed 's|^\./||' | LC_ALL=C sort ) > "$rigTmp/all.files"
rigAssert "control: the files of the package are read, the hooks, the tool script, the console template, the builders and the checks among them" \
	"$( [ "$( wc -l < "$rigTmp/all.files" | LC_ALL=C tr -d ' ' )" -ge 600 ] && echo many ) $( LC_ALL=C grep -c -x -F -e 'sh-lib/client-hooks/deny-memory-md-read.sh' -e 'sh-scripts/DistroAgentsTools.fn.sh' -e 'sh-lib/AgentsConsoleShellScript.template.sh' -e 'builders/source-prepare/1201-agents-indices.sh' -e 'sh-test/AgentsRunTests.sh' -e 'sh-test/check-fixtures/AgentsHarnessHooks.legacy.sh' "$rigTmp/all.files" || : )" "many 6"
rigAssert "control: every hook a client is given is a file that starts with a first line" "$( cd "$rigPackage" && for rigHook in sh-lib/client-hooks/* ; do IFS= read -r rigHookLine < "$rigHook" ; case "$rigHookLine" in ('#!'*) ;; (*) printf '%s ' "$rigHook" ;; esac ; done )" ""
rigFirstOut="$( cd "$rigPackage" && rigFirstLines < "$rigTmp/all.files" )"
rigAssert "no file of the package starts with a line that names bash by a path: a bash script starts #!/usr/bin/env bash" "${rigFirstOut:-none}" "none"

echo "-- 2. literals: no line of the code holds a fixed path to bash that is not on the list --"
( cd "$rigPackage" && find sh-lib sh-scripts sh-test builders vscode -type f ! -name '*.md' ! -name '.DS_Store' | LC_ALL=C grep -v -x -F -e "$rigSelf" | LC_ALL=C sort ) > "$rigTmp/code.files"
rigAssert "control: the code is read, the harness, the awk files, the checks and their fixtures among it, and no name has a space in it" \
	"$( [ "$( wc -l < "$rigTmp/code.files" | LC_ALL=C tr -d ' ' )" -ge 500 ] && echo many ) $( LC_ALL=C grep -c -x -F -e 'sh-lib/AgentsUniversalHarness.sh' -e 'sh-lib/AgentsClaudeStreamJsonTranscript.awk' -e 'sh-lib/workspace-commands.list' -e 'sh-test/AgentsAdvanceInputScanStatesCheck.test.sh' -e 'sh-test/check-fixtures/AgentsHarnessHooks.legacy.sh' "$rigTmp/code.files" || : ) $( LC_ALL=C grep -c ' ' "$rigTmp/code.files" || : )" "many 5 0"
rigLiteralList > "$rigTmp/literal.list"
rigLiteralOut="$( cd "$rigPackage" && rigGuard literal "$rigTmp/literal.list" $( cat "$rigTmp/code.files" ) )"
rigAssert "every fixed path to bash in the code is on the list, and every line of the list stands in the code as often as it says (the running bash is \"\$BASH\", bash from the PATH is \`bash\`)" "${rigLiteralOut:-none}" "none"
rigAssert "every line of the list gives its reason" "$( LC_ALL=C awk -F'|' 'length( $4 ) < 40 { bad++ ; } END { print NR + 0 " lines, " bad + 0 " without a reason" ; }' "$rigTmp/literal.list" )" "4 lines, 0 without a reason"

echo "-- 3. starts by path: the tooling starts the tool script with the bash it runs in --"
( cd "$rigPackage" && find sh-lib sh-scripts builders -type f ! -name '*.md' ! -name '.DS_Store' | LC_ALL=C sort ) > "$rigTmp/tooling.files"
rigAssert "control: the files of the tooling are read, the harness, the spawn proxy, the hooks and the console template among them" \
	"$( [ "$( wc -l < "$rigTmp/tooling.files" | LC_ALL=C tr -d ' ' )" -ge 150 ] && echo many ) $( LC_ALL=C grep -c -x -F -e 'sh-lib/AgentsUniversalHarness.sh' -e 'sh-lib/AgentsTools.InternOpAgentSpawnProxy.include' -e 'sh-lib/client-hooks/allow-granted-native-tool.sh' -e 'sh-lib/AgentsConsoleShellScript.template.sh' "$rigTmp/tooling.files" || : )" "many 4"
rigStartList > "$rigTmp/start.list"
rigGuardNames="$( cd "$rigPackage" && rigToolNames $( cat "$rigTmp/tooling.files" ) )"
rigAssert "control: the variables that hold the path of the tool script are read out of the tooling, those of the harness, of the hooks and of the console among them" \
	"$( [ "$( printf '%s\n' $rigGuardNames | LC_ALL=C grep -c . )" -ge 15 ] && echo many ) $( printf '%s\n' $rigGuardNames | LC_ALL=C grep -c -x -e grantTools -e hookTools -e DAGC_MANAGER_TOOLS -e startTool )" "many 4"
rigStartOut="$( cd "$rigPackage" && rigGuard start "$rigTmp/start.list" $( cat "$rigTmp/tooling.files" ) )"
rigAssert "every start of the tool script, by its path or through a variable that holds it, is \"\$BASH\" <script>, or is on the list, and every line of the list stands in the code as often as it says" "${rigStartOut:-none}" "none"
rigAssert "every line of that list gives its reason" "$( LC_ALL=C awk -F'|' 'length( $4 ) < 40 { bad++ ; } END { print NR + 0 " lines, " bad + 0 " without a reason" ; }' "$rigTmp/start.list" )" "2 lines, 0 without a reason"
rigAssert "control: the tooling does start the tool script that way, many times, the harness among the files that do" \
	"$( cd "$rigPackage" && cat $( cat "$rigTmp/tooling.files" ) | LC_ALL=C grep -c -F '"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --' | LC_ALL=C awk '{ print ( $1 >= 30 ) ? "many" : $1 ; }' ) $( LC_ALL=C grep -c -F '"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --' "$rigPackage/sh-lib/AgentsUniversalHarness.sh" | LC_ALL=C awk '{ print ( $1 >= 10 ) ? "many" : $1 ; }' )" "many many"

echo "-- 4. the readers find what they must, and nothing else --"
## CONTROL LINES: each reader finds a new fault, in each shape, takes a listed one, and reads no comment and no other text
mkdir -p "$rigTmp/probe"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$rigTmp/probe/a.sh"
printf '%s\n' '#!/usr/local/bin/bash' 'exit 0' > "$rigTmp/probe/b.sh"
printf '%s\n' '#! /bin/bash -e' 'exit 0' > "$rigTmp/probe/c.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$rigTmp/probe/d.sh"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$rigTmp/probe/e.sh"
printf '%s\n' 'no first line of a script: bash is only a word here' > "$rigTmp/probe/f.txt"
rigAssert "control: a first line that names bash by a path is found, whatever the path, and no other first line is" \
	"$( cd "$rigTmp/probe" && printf '%s\n' a.sh b.sh c.sh d.sh e.sh f.txt | rigFirstLines | LC_ALL=C tr '\n' ' ' )" "FIRST LINE: a.sh: #!/bin/bash FIRST LINE: b.sh: #!/usr/local/bin/bash FIRST LINE: c.sh: #! /bin/bash -e "
printf '%s\n' '#!/usr/bin/env bash' \
	'	## a comment that names /bin/bash is not read' \
	'	SHELL=/bin/bash' \
	'	exec /usr/local/bin/bash -c "$probeLine"' \
	'	printf '"'"'#!/bin/bash\n'"'"' > "$probeOut"' \
	'	"$probeDir/bin/bash" -c "$probeLine"' \
	'	command -v bash > /dev/null' \
	'	probeCmd="/bin/bash -c '"'"'. \"$0\"'"'"' "' \
	'	PATH="$probeDir/bin:/usr/bin:/bin"' \
	'	exec bash "$probeScript"' \
	'	"${probeDir}/bash" "$probeScript"' > "$rigTmp/probe/Literal.sh"
printf '%s\n' 'Literal.sh|0|nothing of this file is listed|a reason long enough to stand in a control of this check' > "$rigTmp/probe/list"
rigAssert "control: each fixed path to bash in a line of code is found, with its file and line, and nothing else of that file is" \
	"$( cd "$rigTmp/probe" && rigGuard literal "$rigTmp/probe/list" Literal.sh | LC_ALL=C sed 's/^\(NOT ON THE LIST: [^:]*:[0-9]*\):.*/\1/' | LC_ALL=C tr '\n' ' ' )" \
	"NOT ON THE LIST: Literal.sh:3 NOT ON THE LIST: Literal.sh:4 NOT ON THE LIST: Literal.sh:5 NOT ON THE LIST: Literal.sh:8 "
printf '%s\n' 'Literal.sh|1|SHELL=/bin/bash|a reason long enough to stand in a control of this check' 'Literal.sh|1|exec /usr/local/bin/bash|a reason long enough to stand in a control of this check' \
	'Literal.sh|2|'"'"'#!/bin/bash\n'"'"'|a reason long enough to stand in a control of this check' 'Literal.sh|1|probeCmd="/bin/bash -c|a reason long enough to stand in a control of this check' > "$rigTmp/probe/list"
rigAssert "control: with each of them listed nothing is found, and a line of the list that the code holds another number of times is said" \
	"$( cd "$rigTmp/probe" && rigGuard literal "$rigTmp/probe/list" Literal.sh )" 'LIST: Literal.sh holds `'"'"'#!/bin/bash\n'"'"'` 1 time(s), the list says 2'
printf '%s\n' '#!/usr/bin/env bash' \
	'	"$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-one' \
	'	"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-two' \
	'	probeOut="$( printf x | "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-three )"' \
	'	exec "$1/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@"' \
	'	set -- "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-four' \
	'	[ -x "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] || exit 1' \
	'	echo "fix: $MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --probe-five"' \
	'	local probeTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" probeRc=0' \
	'	## "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-six, in a comment' \
	'	"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-seven | "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --probe-eight' \
	'	"$probeTools" --probe-nine' \
	'	"$BASH" "$probeTools" --probe-ten' \
	'	[ -x "$probeTools" ] || exit 1' \
	'	probeOut="$( printf x | "$probeTools" "$@" )"' \
	'	"$probeOther" --probe-eleven' > "$rigTmp/probe/Start.sh"
rigGuardNames="$( cd "$rigTmp/probe" && rigToolNames Start.sh )"
printf '%s\n' 'Start.sh|1|"$1/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@"|a reason long enough to stand in a control of this check' > "$rigTmp/probe/list"
rigAssert "control: each start of the tool script by its path alone or through a variable that holds it is found, a listed one is taken, and one with \"\$BASH\" before it, a test of the file, a message, an assignment, a comment and a variable that holds something else are not" \
	"$rigGuardNames: $( cd "$rigTmp/probe" && rigGuard start "$rigTmp/probe/list" Start.sh | LC_ALL=C sed 's/^\(NOT ON THE LIST: [^:]*:[0-9]*\):.*/\1/' | LC_ALL=C tr '\n' ' ' )" "probeTools : NOT ON THE LIST: Start.sh:2 NOT ON THE LIST: Start.sh:4 NOT ON THE LIST: Start.sh:11 NOT ON THE LIST: Start.sh:12 NOT ON THE LIST: Start.sh:15 "
## END OF CONTROL LINES
## This check itself: its lists and its control lines are the texts of what it forbids and are taken out before it
## is read; nothing else of it names bash by a path or starts the tool script.
LC_ALL=C sed -e '/^rigLiteralList(){$/,/^}$/d' -e '/^rigStartList(){$/,/^}$/d' -e '/^## CONTROL LINES/,/^## END OF CONTROL LINES/d' "$0" > "$rigTmp/Self.test.sh"
printf '%s\n' 'Self.test.sh|0|nothing of this check is listed|whatever it reads it reads as text, and it starts nothing' > "$rigTmp/self.list"
rigGuardNames="$( cd "$rigTmp" && rigToolNames Self.test.sh )"
rigAssert "this check itself holds no fixed path to bash and starts nothing by its path" "$( cd "$rigTmp" && rigGuard literal "$rigTmp/self.list" Self.test.sh ; cd "$rigTmp" && rigGuard start "$rigTmp/self.list" Self.test.sh ; cd "$rigTmp" && printf '%s\n' Self.test.sh | rigFirstLines )" ""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ BASH PATH GUARD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'BASH_PATH_GUARD: OK (%d assertions, offline)\n' "$rigPasses"
