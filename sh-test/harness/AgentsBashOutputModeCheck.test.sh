#!/usr/bin/env bash
## The output mode of the Bash tool: a call's own stdout and stderr told apart (epic S17 row 15, sketch 3.3:
## "add output mode prefixes each line to tell stderr from stdout ... like line numbers in read").
## Every call is a real one through the harness's own served entry point, `--intern-tool Bash`, against this
## check's own rig workspace, with a real shell and real streams. Held:
##   1. output_mode prefixed marks every line of the call's own output: > for stdout and ! for stderr, no line
##      left bare, neither stream wearing the other's mark, both streams present, stdout's lines before
##      stderr's, and the exit status after them
##   2. control: the same command with no output_mode joins the two streams as this tool always has -- no mark
##      on any line, each stream's lines in the order they were written -- so section 1 can fail
##   3. output_mode merged, named aloud, is that same joined rendering
##   4. a value the mode does not know is refused before anything runs, and the command did not run
##   5. the caller's stdin is still read in prefixed mode
##   6. a prefixed call that runs past its timeout returns its marked output, with the timeout said
##   7. a call with no bound of its own marks its streams the same way
## Red: with no output_mode in the Bash tool, section 1 finds no marked line at all, because the two streams
## arrive joined. Offline: a shell of this box, no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashOutputModeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" "$rigTmp/work" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## tool, argument object, session, call name -- what the call printed in <name>.out, its status in <name>.rc
	local rigStatus=0 rigName="$4"
	( cd "$rigTmp/ws" && printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$3" \
		MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigHarness" --intern-tool "$1" --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err" || rigStatus=$?
	printf '%s' "$rigStatus" > "$rigTmp/$rigName.rc"
}
rigSaid(){ ## fixed whole line, call name -- how many lines of what that call printed are exactly it
	LC_ALL=C grep -c -x -F -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigSaidRe(){ ## regular expression, call name -- how many lines of what that call printed match it
	LC_ALL=C grep -c -E -- "$1" "$rigTmp/$2.out" 2> /dev/null || :
}
rigLineOf(){ ## fixed whole line, call name -- the number of its first line, or 0
	LC_ALL=C grep -n -x -F -- "$1" "$rigTmp/$2.out" 2> /dev/null | LC_ALL=C head -1 | LC_ALL=C cut -d : -f 1
}
rigEarlier(){ ## fixed text, fixed text, call name -- yes where the first stands above the second
	local rigFirst rigSecond
	rigFirst="$( rigLineOf "$1" "$3" )" ; rigSecond="$( rigLineOf "$2" "$3" )"
	[ -n "$rigFirst" ] && [ -n "$rigSecond" ] && [ "$rigFirst" -lt "$rigSecond" ] && printf 'yes' || printf 'no'
}

## The one command every section but the last runs: a line on each stream, twice over, so the marks can be
## counted, the order within a stream shown, and the two streams told apart.
rigMixed="echo RIG-OUT-ONE; echo RIG-ERR-ONE >&2; echo RIG-OUT-TWO; echo RIG-ERR-TWO >&2"

## ---- 1. prefixed marks every line, and tells the two streams apart ----
echo "-- 1. output_mode prefixed marks each line, > for stdout and ! for stderr --"
rigSession1="rig-mode-prefixed"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"$rigMixed\",\"output_mode\":\"prefixed\"}" "$rigSession1" pre1
rigAssert "each line carries its own stream's mark: both stdout lines >, both stderr lines !" \
	"$( rigSaid '>RIG-OUT-ONE' pre1 ):$( rigSaid '>RIG-OUT-TWO' pre1 ):$( rigSaid '!RIG-ERR-ONE' pre1 ):$( rigSaid '!RIG-ERR-TWO' pre1 )" "1:1:1:1"
rigAssert "neither stream wears the other's mark, and no line of the command is left bare" \
	"$( rigSaid '!RIG-OUT-ONE' pre1 ):$( rigSaid '>RIG-ERR-ONE' pre1 ):$( rigSaidRe '^RIG-' pre1 )" "0:0:0"
rigAssert "both streams are in the one rendering, four marked lines of them" "$( rigSaidRe '^[>!]RIG-' pre1 )" "4"
rigAssert "stdout's lines come before stderr's, and the exit status stands after them both" \
	"$( rigEarlier '>RIG-OUT-TWO' '!RIG-ERR-ONE' pre1 ):$( rigEarlier '!RIG-ERR-TWO' '(exit status 0)' pre1 )" "yes:yes"

## ---- 2. control: with no mode the streams are joined, as they always were ----
echo "-- 2. control: no output_mode joins the two streams, and marks nothing --"
rigSession2="rig-mode-default"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"$rigMixed\"}" "$rigSession2" pre2
rigAssert "control: the same command marks no line, so the lines section 1 found marked are the mode's own" \
	"$( rigSaidRe '^[>!]RIG-' pre2 ):$( rigSaidRe '^RIG-' pre2 )" "0:4"
rigAssert "control: the joined stream keeps the order the two streams were written in" \
	"$( rigEarlier 'RIG-OUT-ONE' 'RIG-ERR-ONE' pre2 ):$( rigEarlier 'RIG-ERR-ONE' 'RIG-OUT-TWO' pre2 )" "yes:yes"
rigAssert "control: the exit status stands last, as it always has" "$( rigSaid '(exit status 0)' pre2 )" "1"

## ---- 3. merged, named aloud, is that same joined rendering ----
echo "-- 3. output_mode merged is the joined rendering, named aloud --"
rigSession3="rig-mode-merged"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"$rigMixed\",\"output_mode\":\"merged\"}" "$rigSession3" pre3
rigAssert "merged marks no line either, and keeps both streams" \
	"$( rigSaidRe '^[>!]RIG-' pre3 ):$( rigSaidRe '^RIG-' pre3 ):$( rigSaid '(exit status 0)' pre3 )" "0:4:1"

## ---- 4. a value the mode does not know is refused before anything runs ----
echo "-- 4. a value the mode does not know is refused, and the command does not run --"
rigSession4="rig-mode-refused"
rm -f "$rigTmp/work/RIG-REFUSED-RAN"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo RIG-REFUSED-RAN > RIG-REFUSED-RAN\",\"output_mode\":\"split\"}" "$rigSession4" pre4
rigAssert "the refusal names the value it was given and the two it takes" \
	"$( rigSaidRe '^ERROR: output_mode must be merged or prefixed, got: split. Nothing was run.$' pre4 )" "1"
rigAssert "the command did not run: the file it would have written is not there" \
	"$( [ -f "$rigTmp/work/RIG-REFUSED-RAN" ] && printf there || printf absent )" "absent"

## ---- 5. the caller's stdin is still read in prefixed mode ----
echo "-- 5. prefixed mode still reads the caller's stdin --"
rigSession5="rig-mode-stdin"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"cat\",\"stdin\":\"RIG-IN-ONE\\nRIG-IN-TWO\\n\",\"output_mode\":\"prefixed\"}" "$rigSession5" pre5
rigAssert "cat reads the caller's stdin, line for line, and each line comes back marked as stdout" \
	"$( rigSaid '>RIG-IN-ONE' pre5 ):$( rigSaid '>RIG-IN-TWO' pre5 ):$( rigSaid '(exit status 0)' pre5 )" "1:1:1"

## ---- 6. a call past its timeout returns its marked output, with the timeout said ----
echo "-- 6. a prefixed call that times out returns what it wrote, marked, and says it timed out --"
rigSession6="rig-mode-timeout"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"echo RIG-SLOW-OUT; echo RIG-SLOW-ERR >&2; sleep 25\",\"timeout\":2,\"output_mode\":\"prefixed\"}" "$rigSession6" pre6
rigAssert "the lines written before the bound come back marked, one on each stream" \
	"$( rigSaid '>RIG-SLOW-OUT' pre6 ):$( rigSaid '!RIG-SLOW-ERR' pre6 )" "1:1"
rigAssert "and the call says the bound ended it" "$( rigSaidRe '^\.\.\. TIMED OUT after 2 seconds \.\.\.$' pre6 )" "1"

## ---- 7. an unbounded call marks its streams too ----
echo "-- 7. a call with no bound of its own marks its lines as the bounded one does --"
rigSession7="rig-mode-unbounded"
rigCall Bash "{\"cwd\":\"$rigTmp/work\",\"command\":\"$rigMixed\",\"timeout\":0,\"output_mode\":\"prefixed\"}" "$rigSession7" pre7
rigAssert "with no bound of its own the call still keeps the two streams apart, both marks present" \
	"$( rigSaid '>RIG-OUT-ONE' pre7 ):$( rigSaid '!RIG-ERR-ONE' pre7 ):$( rigSaidRe '^RIG-' pre7 )" "1:1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH OUTPUT MODE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BASH_OUTPUT_MODE: OK (%d assertions, offline)\n' "$rigPassCount"
