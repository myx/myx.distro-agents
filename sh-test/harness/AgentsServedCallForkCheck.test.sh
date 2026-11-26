#!/usr/bin/env bash
## Three forks a served call paid for nothing are gone, and what each one answered is unchanged. A fork here is a `$( ... )`
## subshell. A trace marks the nesting by repeating the first character of PS4, so a line run inside a command substitution
## starts with two plus signs and the shell's own line with one. This holds on bash 3.2, which has no BASHPID.
##   1. THE CONTROL. A `cd` inside a command substitution is traced with two plus signs and the shell's own line with one, so a
##      trace that could not see a fork would fail here and not report a clean result below.
##   2. AgentsHarnessResolveDir on a path that is no directory enters no directory, and answers the path as it was given. A
##      directory reached through a link still resolves to its physical path.
##      Red before the cut: a `cd` is traced for the missing path.
##   3. AgentsHarnessRootsDec on text with no backslash does no `%b` conversion and answers the text. Escaped text decodes as
##      before, and an empty text stays empty.
##      Red before the cut: a `printf -v agentsRootsDec %b` is traced for plain text.
##   4. The memory-read hook resolves every directory in its own shell: each `cd -P` of its trace starts with one plus sign.
##      Its answers are unchanged: a Read into a memory store is denied, a Read elsewhere is allowed.
##      Red before the cut: its `cd -P` lines start with two plus signs.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsServedCallForkCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFail(){ echo "⛔ FAIL: $1" >&2 ; exit 1 ; }
for rigNeed in sh-lib/harness/AgentsHarnessAccess.include sh-lib/harness/AgentsHarnessRootsIndex.include sh-lib/client-hooks/deny-memory-md-read.sh ; do
	[ -f "$rigPackage/$rigNeed" ] || rigFail "the subject is not at $rigPackage/$rigNeed"
done

## 1. The control: the trace of a command substitution carries another id than the shell's own.
rigPs4='+:'
( PS4="$rigPs4" ; set -x ; rigCtl="$( cd -P "$rigTmp" && pwd -P )" ; cd -P "$rigTmp" ; : "$rigCtl" ) 2> "$rigTmp/ctl.trace"
rigCtlFork="$( LC_ALL=C grep -c '^++:cd -P' "$rigTmp/ctl.trace" || : )"
rigCtlOwn="$( LC_ALL=C grep -c '^+:cd -P' "$rigTmp/ctl.trace" || : )"
[ "$rigCtlFork" = 1 ] && [ "$rigCtlOwn" = 1 ] || rigFail "the control: a cd in a command substitution was traced $rigCtlFork time(s) with two plus signs and the shell's own cd $rigCtlOwn time(s) with one: this trace cannot tell a fork from the shell's own line"

## 2. AgentsHarnessResolveDir.
mkdir -p "$rigTmp/real" || rigFail "no folder"
ln -s "$rigTmp/real" "$rigTmp/linked" || rigFail "no link inside the rig"
rigReal="$( cd -P "$rigTmp/real" && pwd -P )"
rigResolve="$( bash -c '. "$1/sh-lib/harness/AgentsHarnessAccess.include" || exit 1 ; PS4="$3" ; set -x ; AgentsHarnessResolveDir "$2/absent-dir" rigMiss ; set +x ; AgentsHarnessResolveDir "$2/linked" rigHit ; printf "MISS=%s\nHIT=%s\n" "$rigMiss" "$rigHit" >&2' _ "$rigPackage" "$rigTmp" "$rigPs4" 2>&1 > /dev/null )" || rigFail "the resolve rig did not run: $rigResolve"
rigMissCds="$( printf '%s\n' "$rigResolve" | LC_ALL=C grep -c ':cd ' || : )"
[ "$rigMissCds" = 0 ] || rigFail "AgentsHarnessResolveDir entered a directory $rigMissCds time(s) for a path that is no directory: the fork it saved is back"
case "$( printf '%s\n' "$rigResolve" | LC_ALL=C grep '^MISS=' )" in "MISS=$rigTmp/absent-dir") ;; *) rigFail "a missing path no longer answers as it was given: $( printf '%s\n' "$rigResolve" | LC_ALL=C grep '^MISS=' )" ;; esac
case "$( printf '%s\n' "$rigResolve" | LC_ALL=C grep '^HIT=' )" in "HIT=$rigReal") ;; *) rigFail "a directory reached through a link no longer resolves to its physical path: $( printf '%s\n' "$rigResolve" | LC_ALL=C grep '^HIT=' )" ;; esac

## 3. AgentsHarnessRootsDec.
rigDec="$( bash -c '. "$1/sh-lib/harness/AgentsHarnessRootsIndex.include" || exit 1 ; PS4="$2" ; set -x ; AgentsHarnessRootsDec "/plain/root" ; set +x ; rigPlain="$agentsRootsDec" ; AgentsHarnessRootsDec "a\\nb" ; rigEscaped="$agentsRootsDec" ; AgentsHarnessRootsDec "" ; printf "PLAIN=%s\nESCAPED=%s\nEMPTY=%s\n" "$rigPlain" "$rigEscaped" "$agentsRootsDec" >&2' _ "$rigPackage" "$rigPs4" 2>&1 > /dev/null )" || rigFail "the decode rig did not run: $rigDec"
rigConversions="$( printf '%s\n' "$rigDec" | LC_ALL=C grep -c "printf -v agentsRootsDec %b" || : )"
[ "$rigConversions" = 0 ] || rigFail "AgentsHarnessRootsDec converted plain text $rigConversions time(s): the cut is gone"
[ "$( printf '%s\n' "$rigDec" | LC_ALL=C grep '^PLAIN=' )" = "PLAIN=/plain/root" ] || rigFail "plain text no longer decodes to itself"
[ "$( printf '%s\n' "$rigDec" | LC_ALL=C sed -n '/^ESCAPED=a$/{n;p;}' )" = "b" ] || rigFail "escaped text no longer decodes: its newline is gone"
[ "$( printf '%s\n' "$rigDec" | LC_ALL=C grep '^EMPTY=' )" = "EMPTY=" ] || rigFail "an empty text no longer decodes to empty"

## 4. The memory-read hook, run against a rig's own configuration folder with one memory store.
mkdir -p "$rigTmp/cfg/projects/rig-project/memory" "$rigTmp/home" "$rigTmp/elsewhere"
: > "$rigTmp/cfg/projects/rig-project/memory/MEMORY.md" ; : > "$rigTmp/elsewhere/note.txt"
rigHookRun(){ ## file to read, trace file -- prints the hook's answer
	printf '{"tool_name":"Read","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$rigTmp" | \
		env -i PATH="$PATH" HOME="$rigTmp/home" CLAUDE_CONFIG_DIR="$rigTmp/cfg" PS4="$rigPs4" "$BASH" -x "$rigPackage/sh-lib/client-hooks/deny-memory-md-read.sh" 2> "$2"
}
rigDenied="$( rigHookRun "$rigTmp/cfg/projects/rig-project/memory/MEMORY.md" "$rigTmp/hook-deny.trace" )"
rigAllowed="$( rigHookRun "$rigTmp/elsewhere/note.txt" "$rigTmp/hook-allow.trace" )"
case "$rigDenied" in *deny*) ;; *) rigFail "the hook no longer denies a Read into a memory store: [$rigDenied]" ;; esac
[ -z "$rigAllowed" ] || rigFail "the hook now answers a Read outside the memory store: [$rigAllowed]"
rigHookForks="$( LC_ALL=C cat "$rigTmp/hook-deny.trace" "$rigTmp/hook-allow.trace" | LC_ALL=C grep -c '^++:cd -P' || : )"
[ "$rigHookForks" = 0 ] || rigFail "the hook resolved a directory in $rigHookForks subshell(s): the forks it saved are back"
rigHookOwn="$( LC_ALL=C cat "$rigTmp/hook-deny.trace" "$rigTmp/hook-allow.trace" | LC_ALL=C grep -c '^+:cd -P' || : )"
[ "$rigHookOwn" -ge 2 ] || rigFail "the hook trace holds only $rigHookOwn cd -P line(s) of the hook's own shell: the trace did not reach the resolves"

echo "PASS: the resolve miss, the plain decode and the memory-read hook run with no fork, and each answers as before"
exit 0
