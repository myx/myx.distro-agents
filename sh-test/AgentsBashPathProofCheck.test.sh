#!/usr/bin/env bash
## Behavioural proof that no start of a bash script of the package needs bash at one fixed path. A script whose
## first line names /bin/bash cannot be started where bash is kept elsewhere (FreeBSD: /usr/local/bin/bash): its
## starter gets status 126, "bad interpreter", and a hook that ends so is read as a refusal. Held here, with
## what cannot be assumed taken away:
##   1. EVERY CLIENT HOOK, AS A CLIENT STARTS IT: each record of the client tool policy, its script installed by
##      copying as the installer does, started by the command the installer registers for it
##      ("$CLAUDE_PROJECT_DIR"/.claude/hooks/<script> [argument]) on a PATH whose first `bash` is a stand-in that
##      writes down what it was asked to run and hands on to the real one. The stand-in is asked for each: the
##      first line of the script finds bash by the PATH. And each hook answers, status and output, exactly as the
##      same script does when the interpreter is given to it.
##   2. CONTROL: the same hook with a first line that names bash by a fixed path never asks the PATH.
##   3. THE HARNESS, WHICH RUNS THE HOOKS ITSELF: with copies of the hooks whose first line names an interpreter
##      that does not exist, which is what a fixed path is on such a host, a hook started by its path ends 126 or
##      127; the harness runs each with the bash it runs in, so the memory guards still deny and still allow, by
##      the watchdog and under a timeout command, and the PATH is asked for no bash at all.
##   4. THE GENERATED CONSOLE: the workspace's console command, made by the real generator, started by its path
##      finds bash by the PATH; and what it starts, the tool script, here one whose first line cannot work, it
##      starts with the bash it runs in.
##   5. A PATH THAT HOLDS NO BASH AT ALL, every tool of the system but that one: what a client hands down where
##      bash is kept outside its PATH. The tool, entered by its path with its bash given, puts the directory of
##      that bash at the END of the PATH, once, and hands the bash itself on (MDAT_BASH): a command of the member
##      finds bash, the hook that was refused runs by its path and denies, and the two starters that are no shell,
##      the manager screen's reader and the socket receiver's filing, start the tool script. Where the PATH holds
##      a bash nothing is put on it. Each starter alone, with nothing but the bash handed to it, starts the
##      script. And the harness and the generated console, each entered with its bash given and no tool before
##      it, run a Bash call and launch a leg.
## Red: with `#!/bin/bash` hooks, section 1 fails (the PATH is never asked); with the harness running a hook by
## its path, section 3 fails on status 126; with the console starting the tool by its path, section 4 fails;
## with an entry that leaves the PATH as it was given, or a starter that starts the script by its path, section 5.
## WHAT THIS DOES NOT SHOW: that a client on a given host can enter the tooling at all where neither its PATH nor
## its registered command names a bash, and anything else that differs there (the tools of the system, the rigs
## of other checks). Only a run on that host shows it.
## Offline: one mktemp tree, stand-ins of this check alone; the generator writes into the rig's own workspace.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigHere/harness/AgentsHarnessHooks.sh" "$rigHere/client/AgentsTools.ClientToolPolicy.include" "$rigHere/manager/AgentsConsoleShellScript.template.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigRealBash="$BASH"
case "$rigRealBash" in /*) ;; *) rigRefuse "the bash this check runs in is not known by its path: '$rigRealBash'" ;; esac
[ -x /usr/bin/env ] || rigRefuse "no /usr/bin/env on this host, which the first line of every bash script of the package names"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashPathProofCheck )" || exit 1
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

## The stand-in `bash`, first on the PATH of every run below: it writes down what it was asked to run and hands
## on to the bash this check runs in. A script that reaches bash by a fixed path never asks it. And a stand-in
## `timeout`, which hands straight on.
rigBin="$rigTmp/bin" ; rigHome="$rigTmp/home" ; rigProj="$rigTmp/proj"
mkdir -p "$rigBin" "$rigHome" "$rigProj/.claude/hooks" || rigRefuse "could not create the rig"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$RIG_BASH_ASKED"' 'exec "$RIG_REAL_BASH" "$@"' > "$rigBin/bash"
printf '%s\n' '#!/bin/sh' 'shift' 'exec "$@"' > "$rigBin/timeout"
chmod +x "$rigBin/bash" "$rigBin/timeout"
## A first line that cannot work on this host: what a fixed path to bash is where bash is kept elsewhere.
rigNoSuch='#!/nonexistent-interpreter/bash'
rigMemory="$rigHome/.claude/projects/rig/memory"

echo "-- 1. every client hook, started as a client starts it, finds bash by the PATH and answers as before --"
rigRecords="$( . "$rigHere/client/AgentsTools.ClientToolPolicy.include" && AgentsToolsClientToolPolicyHookRecords )" || rigRefuse "the client tool policy could not state its hook records"
for rigHook in "$rigHere/client-hooks"/* ; do
	## installed as the installer installs it: a copy, mode 0755
	cp -- "$rigHook" "$rigProj/.claude/hooks/${rigHook##*/}" && chmod 0755 "$rigProj/.claude/hooks/${rigHook##*/}" || rigRefuse "could not install ${rigHook##*/} into the rig"
done
rigPayload(){ ## tool name, file path -- one payload every hook can read
	printf '{"session_id":"rig-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"%s","path":"%s","pattern":"*.md"}}' "$rigProj" "$1" "$2" "${2%/*}"
}
rigStarted(){ ## run name, payload, command and its words... -- one start, in an environment of the rig alone
	local startedName="$1" startedPayload="$2" ; shift 2
	: > "$rigTmp/$startedName.asked"
	printf '%s' "$startedPayload" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" RIG_BASH_ASKED="$rigTmp/$startedName.asked" RIG_REAL_BASH="$rigRealBash" CLAUDE_PROJECT_DIR="$rigProj" \
		"$@" > "$rigTmp/$startedName.out" 2> "$rigTmp/$startedName.err"
	printf '%s' "$?" > "$rigTmp/$startedName.rc"
}
rigCount=0 rigAsked=0 rigSame=0 rigScripts="" rigTrouble=""
while IFS= read -r rigRecord ; do
	[ -n "$rigRecord" ] || continue
	rigRest="${rigRecord#*$'\t'}" ; rigRest="${rigRest#*$'\t'}"
	rigKey="${rigRest%%$'\t'*}" ; rigRest="${rigRest#*$'\t'}"
	rigMatcher="${rigRest%%$'\t'*}" ; rigRest="${rigRest#*$'\t'}"
	rigScript="${rigRest%%$'\t'*}" ; rigArg="${rigRest#*$'\t'}" ; rigArg="${rigArg%%$'\t'*}"
	rigTool="${rigMatcher%%|*}" ; [ -n "$rigTool" ] && [ "$rigTool" != resume ] || rigTool=Read
	rigCount=$(( rigCount + 1 ))
	case " $rigScripts " in *" $rigScript "*) ;; *) rigScripts="$rigScripts $rigScript" ;; esac
	rigBody="$( rigPayload "$rigTool" "$rigMemory/MEMORY.md" )"
	## as a client runs the command the installer registers: its shell, the project folder in its environment
	rigStarted "by-path.$rigCount" "$rigBody" /bin/sh -c "\"\$CLAUDE_PROJECT_DIR\"/$rigKey"
	## the same script of the package with the interpreter given: its first line is not used
	rigStarted "given.$rigCount" "$rigBody" "$rigRealBash" "$rigHere/client-hooks/$rigScript" ${rigArg:+"$rigArg"}
	if [ "$( wc -l < "$rigTmp/by-path.$rigCount.asked" | LC_ALL=C tr -d ' ' )" = 1 ] && [ "$( cat "$rigTmp/by-path.$rigCount.asked" )" = "$rigProj/.claude/hooks/$rigScript${rigArg:+ $rigArg}" ] ; then
		rigAsked=$(( rigAsked + 1 ))
	else
		rigTrouble="$rigTrouble [$rigKey: the PATH was asked for: $( LC_ALL=C tr '\n' ';' < "$rigTmp/by-path.$rigCount.asked" ) rc=$( cat "$rigTmp/by-path.$rigCount.rc" ) $( head -1 "$rigTmp/by-path.$rigCount.err" )]"
	fi
	if [ "$( cat "$rigTmp/by-path.$rigCount.rc" )" = "$( cat "$rigTmp/given.$rigCount.rc" )" ] && cmp -s "$rigTmp/by-path.$rigCount.out" "$rigTmp/given.$rigCount.out" ; then
		rigSame=$(( rigSame + 1 ))
	else
		rigTrouble="$rigTrouble [$rigKey: answers rc=$( cat "$rigTmp/by-path.$rigCount.rc" ), given the interpreter rc=$( cat "$rigTmp/given.$rigCount.rc" )]"
	fi
	[ "$rigKey" != ".claude/hooks/deny-memory-md-read.sh" ] || rigNamedRun="$rigCount"
done <<< "$rigRecords"
rigAssert "control: the policy registers a hook for each event it names, and every script of sh-lib/client-hooks is one of them" \
	"$( [ "$rigCount" -ge 8 ] && echo records ) $( printf '%s\n' $rigScripts | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "records $( cd "$rigHere/client-hooks" && ls | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "each registered command, run as a client runs it, finds bash by the PATH: the stand-in is asked once, for that hook" "$rigAsked of $rigCount$rigTrouble" "$rigCount of $rigCount"
rigAssert "and each answers, status and output, exactly as the same script does when the interpreter is given to it" "$rigSame of $rigCount" "$rigCount of $rigCount"
rigAssert "the read guard of the memory store, the hook that was refused with status 126, runs and denies the read: status 0 and a deny decision" \
	"$( cat "$rigTmp/by-path.${rigNamedRun:-0}.rc" 2> /dev/null ) $( LC_ALL=C grep -c '"permissionDecision": "deny"' "$rigTmp/by-path.${rigNamedRun:-0}.out" 2> /dev/null )" "0 1"
rigStarted "by-path.allow" "$( rigPayload Read "$rigProj/notes.md" )" /bin/sh -c '"$CLAUDE_PROJECT_DIR"/.claude/hooks/deny-memory-md-read.sh'
rigAssert "and lets a read outside the store through, as it did: status 0, nothing said, the PATH asked once" \
	"$( cat "$rigTmp/by-path.allow.rc" ) [$( cat "$rigTmp/by-path.allow.out" )] $( wc -l < "$rigTmp/by-path.allow.asked" | LC_ALL=C tr -d ' ' )" "0 [] 1"

echo "-- 2. control: a first line that names bash by a fixed path never asks the PATH --"
{ printf '%s\n' '#!/bin/bash' ; tail -n +2 "$rigHere/client-hooks/deny-memory-md-read.sh" ; } > "$rigProj/.claude/hooks/rig-fixed-path.sh"
chmod 0755 "$rigProj/.claude/hooks/rig-fixed-path.sh"
rigStarted "fixed" "$( rigPayload Read "$rigMemory/MEMORY.md" )" /bin/sh -c '"$CLAUDE_PROJECT_DIR"/.claude/hooks/rig-fixed-path.sh'
rigAssert "the stand-in is not asked: such a script runs only where bash is at that one path, and nowhere else" "$( wc -l < "$rigTmp/fixed.asked" | LC_ALL=C tr -d ' ' )" 0

echo "-- 3. the harness runs the hooks with the bash it runs in, whatever their first line names --"
rigLib="$rigTmp/lib"
mkdir -p "$rigLib/client-hooks" || rigRefuse "could not create the rig's copy of sh-lib"
for rigEntry in "$rigHere"/* ; do
	[ "${rigEntry##*/}" != client-hooks ] || continue
	ln -s "$rigEntry" "$rigLib/${rigEntry##*/}" || rigRefuse "could not link ${rigEntry##*/} into the rig's copy of sh-lib"
done
for rigHook in "$rigHere/client-hooks"/* ; do
	{ printf '%s\n' "$rigNoSuch" ; tail -n +2 "$rigHook" ; } > "$rigLib/client-hooks/${rigHook##*/}" && chmod 0755 "$rigLib/client-hooks/${rigHook##*/}" || rigRefuse "could not make the rig's copy of ${rigHook##*/}"
done
rigStarted "nosuch" "$( rigPayload Read "$rigMemory/MEMORY.md" )" "$rigLib/client-hooks/deny-memory-md-read.sh"
rigAssert "control: started by its path, a hook whose first line names an interpreter that is not there cannot run: status 126 or 127, no answer" \
	"$( case "$( cat "$rigTmp/nosuch.rc" )" in (126|127) echo not-startable ;; (*) cat "$rigTmp/nosuch.rc" ;; esac ) [$( cat "$rigTmp/nosuch.out" )]" "not-startable []"
## The argument-table functions the refusal reads through, lifted out of the harness.
rigLift="$( LC_ALL=C awk '
	/^(AgentsHarnessWholeNumber|AgentsHarnessArgParse|AgentsHarnessArgFind|AgentsHarnessArgValue)\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 4 ) exit 1 ; }
' "$rigHarness" )" || rigRefuse "the argument-table functions were not all found in $rigHarness"
rigRefusal(){ ## run name, timeout command or "", tool name, raw arguments -- the harness's own decision, its hooks from the rig's copy of sh-lib
	local refusalDir="$rigTmp/$1"
	mkdir -p "$refusalDir" ; : > "$refusalDir/asked"
	(
		export HOME="$rigHome" RIG_BASH_ASKED="$refusalDir/asked" RIG_REAL_BASH="$rigRealBash"
		PATH="$rigBin:$PATH" ; export PATH
		cd "$rigProj" || exit 1
		MMDAPP="$rigProj" harnessHere="$rigLib" harnessScratch="$refusalDir" harnessSelfName=rig
		harnessSessionId='rig-session'
		harnessDim='' harnessTool='' harnessValue='' harnessWarn='' harnessBad='' harnessOff=''
		harnessTimeoutCmd="$2"
		harnessArgRaw="" harnessArgParsed=0 harnessArgPaths=() harnessArgEncs=() harnessArgFound=""
		eval "$rigLift"
		. "$rigLib/harness/AgentsHarnessHooks.sh" 2> "$refusalDir/source.err"
		printf '%s' "$harnessHooksList" > "$refusalDir/list"
		printf '%s' "$( AgentsHarnessHooksRefusal "$3" "$4" )" > "$refusalDir/refusal"
	)
}
rigSaid(){ ## run name -- the first 60 characters of the refusal
	LC_ALL=C cut -c1-60 "$rigTmp/$1/refusal" | head -1
}
rigDenied='ERROR: blocked by a PreToolUse hook: the machine-local agent'
rigRefusal read-deny "" Read "{\"file_path\":\"$rigMemory/MEMORY.md\"}"
rigAssert "a read of the memory store is denied by its hook, not refused because the hook could not run" "$( rigSaid read-deny )" "$rigDenied"
rigBashWord="$( printf '%q' "$rigRealBash" )" ; rigLibWord="$( printf '%q' "$rigLib/client-hooks/" )"
rigAssert "each hook of the harness's list is a hook of the package run by the bash the harness runs in" \
	"$( LC_ALL=C awk -F'\t' -v want="$rigBashWord $rigLibWord" 'index( $2, want ) == 1 { own++ ; } END { print NR + 0, own + 0 ; }' "$rigTmp/read-deny/list" )" "4 4"
rigRefusal read-allow "" Read "{\"file_path\":\"$rigProj/notes.md\"}"
rigAssert "a read outside the store is let through: the hook ran and said nothing" "[$( cat "$rigTmp/read-allow/refusal" )]" "[]"
rigRefusal edit-deny "" Edit "{\"file_path\":\"$rigMemory/topic.md\"}"
rigAssert "a write into the memory store is denied by its hook" "$( rigSaid edit-deny )" "$rigDenied"
rigRefusal glob-deny "" Glob "{\"path\":\"$rigMemory\",\"pattern\":\"*.md\"}"
rigAssert "a hook that takes an argument, the read guard for Glob, is run with it and denies" "$( rigSaid glob-deny )" "$rigDenied"
rigRefusal timed-deny "$rigBin/timeout" Read "{\"file_path\":\"$rigMemory/MEMORY.md\"}"
rigRefusal timed-allow "$rigBin/timeout" Read "{\"file_path\":\"$rigProj/notes.md\"}"
rigAssert "the same under a timeout command: denied, and let through" "$( rigSaid timed-deny ) [$( cat "$rigTmp/timed-allow/refusal" )]" "$rigDenied []"
rigAssert "and in all of it the PATH was asked for no bash: neither for the command line of a hook nor for the hook" \
	"$( cat "$rigTmp/read-deny/asked" "$rigTmp/read-allow/asked" "$rigTmp/edit-deny/asked" "$rigTmp/glob-deny/asked" "$rigTmp/timed-deny/asked" "$rigTmp/timed-allow/asked" | wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 4. the generated console finds bash by the PATH, and starts the tool with the bash it runs in --"
rigGen="$rigTmp/gen" ; rigWs="$rigTmp/ws" ; rigOrigin="$rigTmp/origin"
mkdir -p "$rigGen/ws/.local" "$rigGen/home" "$rigWs/.local" "$rigOrigin/myx/myx.distro-agents/sh-scripts" || rigRefuse "could not create the rig's workspaces"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigGen/ws/.local/MDLT.settings.env"
env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigGen/home" PATH="/usr/bin:/bin:${rigRealBash%/*}" MMDAPP="$rigGen/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
	"$rigRealBash" -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac ; cd "$MMDAPP" && exec "$BASH" "$0" --make-console-command --quiet' "$rigFn" \
	> /dev/null 2> "$rigGen/make.err"
[ -f "$rigGen/ws/DistroAgentsConsole.sh" ] || rigRefuse "no console was generated: $( tail -2 "$rigGen/make.err" 2> /dev/null )"
rigAssert "the generator makes the console executable, and its first line names bash by no path" "$( [ -x "$rigGen/ws/DistroAgentsConsole.sh" ] && echo executable ) $( head -1 "$rigGen/ws/DistroAgentsConsole.sh" )" "executable #!/usr/bin/env bash"
## The origin the console resolves: the real tree by symlink, and a tool script of the rig whose first line cannot work.
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do
	[ "${rigEntry##*/}" != "myx.distro-agents" ] || continue
	ln -s "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}"
done
for rigEntry in "$rigPackage"/* ; do
	[ "${rigEntry##*/}" != "sh-scripts" ] || continue
	ln -s "$rigEntry" "$rigOrigin/myx/myx.distro-agents/${rigEntry##*/}"
done
printf '%s\n' "$rigNoSuch" 'printf "RIG-TOOL %s\n" "$*"' > "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
chmod +x "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
cp -p "$rigGen/ws/DistroAgentsConsole.sh" "$rigWs/DistroAgentsConsole.sh" || rigRefuse "could not place the generated console in the rig's workspace"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$rigOrigin" > "$rigWs/.local/MDLT.settings.env"
rigStarted "tool" "" "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --manager
rigAssert "control: the rig's tool script cannot be started by its path: status 126 or 127" "$( case "$( cat "$rigTmp/tool.rc" )" in (126|127) echo not-startable ;; (*) cat "$rigTmp/tool.rc" ;; esac )" "not-startable"
rigStarted "console" "" "$rigWs/DistroAgentsConsole.sh" --manager
rigAssert "the console, started by its path, finds bash by the PATH: the stand-in is asked once, for the console" "$( cat "$rigTmp/console.asked" )" "$rigWs/DistroAgentsConsole.sh --manager"
rigAssert "and it starts the tool script with the bash it runs in: the tool ran, status 0" "$( cat "$rigTmp/console.rc" ) [$( cat "$rigTmp/console.out" )] $( LC_ALL=C grep -c -i -e 'bad interpreter' -e 'not found' -e 'No such file' "$rigTmp/console.err" )" "0 [RIG-TOOL --manager] 0"

echo "-- 5. a PATH that holds no bash at all: the tooling, entered with its bash given, hands that bash on --"
## What a client hands down where bash is kept outside its PATH (FreeBSD: /usr/local/bin): every tool of the system
## by symlink, python3 among them, and no bash.
[ "${rigRealBash##*/}" = bash ] || rigRefuse "the bash this check runs in is not named bash: $rigRealBash"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH, which the two starters of this section are run by"
rigNoBash="$rigTmp/no-bash"
mkdir -p "$rigNoBash/own" "$rigNoBash/usr-bin" "$rigNoBash/bin" "$rigTmp/data" "$rigTmp/skills" "$rigTmp/exec-ws/.local" || rigRefuse "could not create the rig of section 5"
ln -s /usr/bin/* "$rigNoBash/usr-bin/" 2> /dev/null ; ln -s /bin/* "$rigNoBash/bin/" 2> /dev/null
rm -f "$rigNoBash/usr-bin/bash" "$rigNoBash/bin/bash"
ln -s "$rigPython" "$rigNoBash/own/python3" || rigRefuse "could not place python3 on the rig's PATH"
rigNoBashPath="$rigNoBash/own:$rigNoBash/usr-bin:$rigNoBash/bin"
rigExecWs="$rigTmp/exec-ws"
rigAssert "control: that PATH holds no bash, and it holds the tools, python3 among them" \
	"$( env -i MDAT_WORKSPACE_MODE=team-rig PATH="$rigNoBashPath" /bin/sh -c 'command -v bash > /dev/null 2>&1 && echo bash-found || echo no-bash ; command -v python3 > /dev/null 2>&1 && command -v awk > /dev/null 2>&1 && echo tools' | LC_ALL=C tr '\n' ' ' )" "no-bash tools "
## A stand-in for the tool script, a bash script as that one is, and the two starters that are no shell, each
## started as its own code starts the tool: the screen's reader as the screen's start makes it, the receiver's filing.
printf '%s\n' '#!/usr/bin/env bash' 'printf "RIG-TOOL %s\n" "$*"' 'printf "%s\n" "$*" >> "$RIG_FILED.words"' 'cat >> "$RIG_FILED"' > "$rigTmp/stand-tool.sh"
chmod +x "$rigTmp/stand-tool.sh"
cat > "$rigTmp/starters.py" <<'RIGPY'
import importlib.util, sys, time
kind, modulePath, toolPath = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("rig_starter", modulePath)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
if kind == "screen":
    maker = getattr(module, "toolsCommandOf", None)
    reader = module.OperationReader(maker(toolPath) if maker else [toolPath])
    reader.start("probe", "rig", ["--rig-operation", "one"])
    results = []
    for turn in range(400):
        results = reader.collect()
        if results:
            break
        time.sleep(0.05)
    for result in results:
        sys.stdout.write("status=%s text=%s\n" % (result["status"], result["text"].strip()))
else:
    sys.argv[1:] = ["rig-app"]
    module.fileInquiry({"channel": "CRIG00001", "ts": "1700000000.000100", "user": "URIG", "text": "RIG-MENTION"}, toolPath)
RIGPY
rigStarter(){ ## run folder, screen|socket, environment settings... -- one start by that starter, on the PATH without bash
	local starterDir="$1" starterKind="$2" starterFile="$rigHere/manager/AgentsManagerScreen.py"
	shift 2
	[ "$starterKind" = screen ] || starterFile="$rigHere/comms/AgentsSlackSocketMode.py"
	mkdir -p "$starterDir"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigNoBashPath" MMDAPP="$rigTmp" RIG_FILED="$starterDir/$starterKind.filed" SOCKET_MODE_LOG_DIR="$starterDir/log" "$@" \
		"$rigPython" -I -B "$rigTmp/starters.py" "$starterKind" "$starterFile" "$rigTmp/stand-tool.sh" > "$starterDir/$starterKind.out" 2>&1
}
## A member's command, where the tooling runs one (--intern-mcp-execute), the tool entered by its path with its bash given.
rigCommand='
	printf "%s\n" "$( command -v bash )" > "$RIG_OUT/which"
	printf "%s\n" "$PATH" > "$RIG_OUT/path"
	printf "%s\n" "${MDAT_BASH:-}" > "$RIG_OUT/handed"
	"$RIG_HOOK" < "$RIG_OUT/payload" > "$RIG_OUT/hook.out" 2> "$RIG_OUT/hook.err" ; printf "%s" "$?" > "$RIG_OUT/hook.rc"
	RIG_FILED="$RIG_OUT/screen.filed" python3 -I -B "$RIG_TMP/starters.py" screen "$RIG_LIB/manager/AgentsManagerScreen.py" "$RIG_TMP/stand-tool.sh" > "$RIG_OUT/screen.out" 2>&1
	RIG_FILED="$RIG_OUT/socket.filed" SOCKET_MODE_LOG_DIR="$RIG_OUT/log" python3 -I -B "$RIG_TMP/starters.py" socket "$RIG_LIB/comms/AgentsSlackSocketMode.py" "$RIG_TMP/stand-tool.sh" > "$RIG_OUT/socket.out" 2>&1
	:
'
rigEntered(){ ## run name, the PATH it is entered with
	local enteredDir="$rigTmp/$1"
	mkdir -p "$enteredDir"
	rigPayload Read "$rigMemory/MEMORY.md" > "$enteredDir/payload"
	( cd "$rigExecWs" && printf '%s\n' "$rigCommand" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$2" MMDAPP="$rigExecWs" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_OUT="$enteredDir" RIG_LIB="$rigHere" RIG_HOOK="$rigProj/.claude/hooks/deny-memory-md-read.sh" \
		RIG_BASH_ASKED="$enteredDir/asked" RIG_REAL_BASH="$rigRealBash" CLAUDE_PROJECT_DIR="$rigProj" \
		"$rigRealBash" "$rigFn" --intern-mcp-execute ) > "$enteredDir/run.out" 2>&1
	printf '%s' "$?" > "$enteredDir/run.rc"
}
rigPathSays(){ ## run name -- how often the directory of the running bash stands on the PATH the command saw, and whether after everything the caller gave
	LC_ALL=C tr ':' '\n' < "$rigTmp/$1/path" | LC_ALL=C awk -v bashDir="${rigRealBash%/*}" -v lastGiven="$rigNoBash/bin" '
		$0 == bashDir { bashCount++ ; bashAt = NR ; } $0 == lastGiven { givenAt = NR ; }
		END { print bashCount + 0, ( bashCount && givenAt && bashAt > givenAt ) ? "after-what-was-given" : "-" ; }'
}
rigStarted "no-bash.hook" "$( rigPayload Read "$rigMemory/MEMORY.md" )" /bin/sh -c 'PATH="$1" ; export PATH ; "$CLAUDE_PROJECT_DIR"/.claude/hooks/deny-memory-md-read.sh' rig "$rigNoBashPath"
rigAssert "control: on that PATH a hook started by its path alone finds no bash: status 126 or 127, no answer" \
	"$( case "$( cat "$rigTmp/no-bash.hook.rc" )" in (126|127) echo not-startable ;; (*) cat "$rigTmp/no-bash.hook.rc" ;; esac ) [$( cat "$rigTmp/no-bash.hook.out" )]" "not-startable []"
rigEntered entered "$rigNoBashPath"
rigAssert "the tool, entered with its bash given, puts the directory of that bash on the PATH: a command of the member finds bash, and it is the running one" \
	"$( cat "$rigTmp/entered/run.rc" ) $( cat "$rigTmp/entered/which" 2> /dev/null )" "0 $rigRealBash"
rigAssert "at the END of the PATH and once: after everything the caller gave, so nothing of his is shadowed" "$( rigPathSays entered )" "1 after-what-was-given"
rigAssert "and it hands the running bash on to a starter that is no shell" "$( cat "$rigTmp/entered/handed" 2> /dev/null )" "$rigRealBash"
rigAssert "the read guard of the memory store, started by its path from that command, runs and denies: status 0 and a deny decision" \
	"$( cat "$rigTmp/entered/hook.rc" 2> /dev/null ) $( LC_ALL=C grep -c '"permissionDecision": "deny"' "$rigTmp/entered/hook.out" 2> /dev/null )" "0 1"
rigAssert "the manager screen's reader starts the tool script and has its answer" "$( cat "$rigTmp/entered/screen.out" 2> /dev/null )" "status=0 text=RIG-TOOL --rig-operation one"
rigAssert "the socket receiver files its inquiry through the tool script: the words and the body reached it" \
	"$( LC_ALL=C grep -c '^--upsert-inbox-inquiry magic-coordinator inquiry-' "$rigTmp/entered/socket.filed.words" 2> /dev/null ) $( LC_ALL=C grep -c -x 'RIG-MENTION' "$rigTmp/entered/socket.filed" 2> /dev/null )" "1 1"
rigEntered found "$rigBin:$rigNoBashPath"
rigAssert "where the PATH holds a bash nothing is put on it: the member's command finds that one, and the running one is handed on all the same" \
	"$( cat "$rigTmp/found/run.rc" ) $( cat "$rigTmp/found/which" 2> /dev/null ) $( rigPathSays found ) $( cat "$rigTmp/found/handed" 2> /dev/null )" "0 $rigBin/bash 0 - $rigRealBash"
## The two starters with nothing but the bash handed to them: the PATH is as the client gave it, no bash on it.
rigStarter "$rigTmp/handed" screen MDAT_BASH="$rigRealBash"
rigStarter "$rigTmp/handed" socket MDAT_BASH="$rigRealBash"
rigAssert "each starter starts the tool script with the bash handed to it, a name on the PATH never looked up" \
	"$( cat "$rigTmp/handed/screen.out" ) / $( LC_ALL=C grep -c -x 'RIG-MENTION' "$rigTmp/handed/socket.filed" 2> /dev/null )" "status=0 text=RIG-TOOL --rig-operation one / 1"
rigStarter "$rigTmp/unhanded" screen
rigAssert "control: handed none, a starter starts the script by its path as before, which on that PATH finds no bash" "$( cat "$rigTmp/unhanded/screen.out" )" "status=127 text="
rigAssert "the screen's own start makes its reader that way" "$( LC_ALL=C grep -c -F 'reader = OperationReader(toolsCommandOf(options["--tools"]), options["--workspace"])' "$rigHere/manager/AgentsManagerScreen.py" )" 1
## The harness entered with its bash given and no tool before it: a call that names `bash`, the Bash tool with a
## timeout of its own, which runs its command in a bash of its own.
mkdir -p "$rigTmp/harness-call"
printf '{"command":"echo RIG-RAN-$(( 6 * 7 ))","cwd":"%s","timeout":30}' "$rigExecWs" \
	| ( cd "$rigExecWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigNoBashPath" MMDAPP="$rigExecWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		HARNESS_PROVIDER_NAME="bash-path proof rig" HARNESS_SELF_NAME="AgentsBashPathProofCheck.test.sh" HARNESS_ENDPOINT="https://bash-path-proof-check.invalid/v1/chat/completions" \
		HARNESS_HOST="bash-path-proof-check.invalid" HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none -- this check never reads one" \
		HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		"$rigRealBash" "$rigHarness" --intern-tool Bash --access-root "$rigExecWs" ) > "$rigTmp/harness-call/out" 2> "$rigTmp/harness-call/err"
rigAssert "the harness, entered with its bash given, runs a Bash call under a timeout: the command ran" "$( LC_ALL=C grep -c -x 'RIG-RAN-42' "$rigTmp/harness-call/out" )" 1
## The generated console entered with its bash given: a spawn on the claude leg, which the console starts by its path.
rigLegWs="$rigTmp/leg-ws"
mkdir -p "$rigLegWs/.local/.agents" "$rigTmp/leg-home" || rigRefuse "could not create the workspace of the console launch"
cp -p "$rigGen/ws/DistroAgentsConsole.sh" "$rigLegWs/DistroAgentsConsole.sh" || rigRefuse "could not place the generated console"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigLegWs/.local/MDLT.settings.env"
printf 'SPAWN_CLI_SERVICE=claude\n' > "$rigLegWs/.local/.agents/magic-team.agent.env"
printf '%s\n' '#!/usr/bin/env bash' 'HARNESS_CREDENTIAL_NAMES="RIG_NO_SUCH_CREDENTIAL"' '{ printf "leg args=" ; for rigArg in "$@" ; do printf "[%s]" "$rigArg" ; done ; printf "\n" ; } >> "$RIG_LEG_LOG"' > "$rigTmp/leg-stand-in"
chmod +x "$rigTmp/leg-stand-in"
: > "$rigTmp/leg.log"
env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/leg-home" PATH="$rigNoBashPath" RIG_LEG_LOG="$rigTmp/leg.log" MDAT_CLAUDE_HARNESS="$rigTmp/leg-stand-in" \
	"$rigRealBash" "$rigLegWs/DistroAgentsConsole.sh" --cli-configured --non-interactive RIG-PROMPT < /dev/null > "$rigTmp/leg.out" 2> "$rigTmp/leg.err"
rigAssert "the console, entered with its bash given, launches its leg: the leg ran with the prompt" "$( LC_ALL=C grep -c -F '[RIG-PROMPT]' "$rigTmp/leg.log" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ BASH PATH PROOF CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'BASH_PATH_PROOF: OK (%d assertions, offline)\n' "$rigPasses"
