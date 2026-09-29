#!/usr/bin/env bash
## Behavioural check on Edit's integrity under two conditions the other rigs never
## create: a harness file cut short while a call starts (the live source is rewritten in
## place, and a call reading it mid-rewrite exited 0 with empty stdout -- the MCP
## server's "(no output)" -- having written nothing), and several Edits to one file at
## once (no lock around the read-modify-write, so a file was emptied or lost edits while
## every call reported OK). Runs a COPY of sh-lib under this rig's own temp tree; the
## live harness is never touched. Offline: --intern-tool reaches no endpoint.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHere/AgentsUniversalHarness.sh" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHere/AgentsUniversalHarness.sh"
rigTmp="$( mktemp -d -t AgentsHarnessEditIntegrityCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
cp -R "$rigHere" "$rigTmp/sh-lib" || rigRefuse "could not copy sh-lib into the rig"
rigHarness="$rigTmp/sh-lib/AgentsUniversalHarness.sh"
cp "$rigHarness" "$rigTmp/harness.intact"
mkdir -p "$rigTmp/ws/IN"

export HARNESS_PROVIDER_NAME="edit-integrity check rig"
export HARNESS_SELF_NAME="AgentsHarnessEditIntegrityCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-edit-integrity-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-edit-integrity-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"
unset MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_DATA_ROOT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One tool call through the copied harness, as the MCP server runs it. Writes the exit
## status then stdout into $3; a call still running after 60s is killed, so a hang shows
## as a non-zero status and never as a pass.
rigTool(){ ## tool, arguments JSON, result file
	printf '%s\n' "$2" | MMDAPP="$rigTmp/ws" bash "$rigHarness" --intern-tool "$1" \
		--access-read-root "$rigTmp/ws/IN" --access-write-root "$rigTmp/ws/IN" > "$3.out" 2>/dev/null &
	local toolPid=$! toolRc=0
	( sleep 60 ; kill -KILL "$toolPid" ) 2>/dev/null &
	local watchPid=$!
	wait "$toolPid" || toolRc=$?
	{ kill "$watchPid" ; wait "$watchPid" ; } 2>/dev/null
	printf '%s\n' "$toolRc" > "$3"
	cat "$3.out" >> "$3"
}
rigEdit(){ ## path, old, new, result file
	rigTool Edit "$( printf '{"path":"%s","old_text":"%s","new_text":"%s"}' "$1" "$2" "$3" )" "$4"
}

echo "-- control: the intact harness edits and says so --"
printf 'rig-orig\n' > "$rigTmp/ws/IN/t"
rigEdit "$rigTmp/ws/IN/t" rig-orig rig-new "$rigTmp/r.intact"
rigAssert "the intact harness exits 0"                 "$( head -1 "$rigTmp/r.intact" )" 0
rigAssert "it reports the replacement"                 "$( sed -n '2s/^\(OK: replaced\).*/\1/p' "$rigTmp/r.intact" )" "OK: replaced"
rigAssert "and the file was written"                   "$( cat "$rigTmp/ws/IN/t" )" rig-new

echo "-- a harness cut short before its tool dispatch --"
## The cut is where a call reading a half-rewritten harness runs out: every function is
## defined and nothing is dispatched. A cut the marker no longer locates is a rig fault.
rigCut="$( LC_ALL=C grep -n '^## --intern-tool ends here' "$rigTmp/harness.intact" | head -1 | cut -d: -f1 )"
[ -n "$rigCut" ] || rigRefuse "the --intern-tool dispatch marker is not in the harness, so no truncation point can be chosen"
head -n $(( rigCut - 1 )) "$rigTmp/harness.intact" > "$rigHarness"
printf 'rig-orig\n' > "$rigTmp/ws/IN/t"
rigEdit "$rigTmp/ws/IN/t" rig-orig rig-new "$rigTmp/r.cut"
## A cut harness never reaches its own clean exit, so it must leave non-zero -- the MCP
## server reports that as a failure, never as "(no output)".
rigAssert "a cut harness exits non-zero"               "$( [ "$( head -1 "$rigTmp/r.cut" )" != 0 ] && printf non-zero || printf zero )" non-zero
rigAssert "and the file is unchanged"                  "$( cat "$rigTmp/ws/IN/t" )" rig-orig

echo "-- a harness that does not parse --"
## Opened before the dispatch, not appended: bash parses as it runs, so a fault past the
## dispatch is never reached and the call exits 0 as if intact.
{ head -n $(( rigCut - 1 )) "$rigTmp/harness.intact" ; printf 'fi\n' ; sed -n "$rigCut,\$p" "$rigTmp/harness.intact" ; } > "$rigHarness"
printf 'rig-orig\n' > "$rigTmp/ws/IN/t"
rigEdit "$rigTmp/ws/IN/t" rig-orig rig-new "$rigTmp/r.broken"
rigAssert "a harness that does not parse exits non-zero" "$( [ "$( head -1 "$rigTmp/r.broken" )" != 0 ] && printf non-zero || printf zero )" non-zero
cp "$rigTmp/harness.intact" "$rigHarness"

echo "-- four Edits to one file at once --"
## The race is not guaranteed to fire in one round, so rounds repeat; every round must
## end with all four changes, all four lines and four OK results.
rigRounds=10
rigBadRounds=0
rigBadDetail=""
for rigRound in $( seq 1 "$rigRounds" ) ; do
	printf 'a\nb\nc\nd\n' > "$rigTmp/ws/IN/p"
	for rigKey in a b c d ; do
		rigEdit "$rigTmp/ws/IN/p" "$rigKey" "${rigKey}X" "$rigTmp/r.par.$rigKey" &
	done
	wait
	rigLines="$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/ws/IN/p" )"
	## By content, per marker: a count of changed lines cannot tell a lost edit from a moved one.
	rigChanged=0
	for rigKey in a b c d ; do
		LC_ALL=C grep -qx "${rigKey}X" "$rigTmp/ws/IN/p" && rigChanged=$(( rigChanged + 1 ))
	done
	rigOks="$( cat "$rigTmp"/r.par.? | LC_ALL=C grep -c '^OK: replaced' )"
	if [ "$rigLines" != 4 ] || [ "$rigChanged" != 4 ] || [ "$rigOks" != 4 ] ; then
		rigBadRounds=$(( rigBadRounds + 1 ))
		rigBadDetail="$rigBadDetail round $rigRound: lines=$rigLines changed=$rigChanged ok=$rigOks;"
	fi
done
rigAssert "every round keeps all four lines and all four changes, each reported OK" "$rigBadRounds bad of $rigRounds${rigBadDetail:+ --$rigBadDetail}" "0 bad of $rigRounds"

echo "-- four Writes to one file at once --"
## Each writer's content is a distinct full line repeated, so a mix of two writers, a
## truncation and an empty file are all distinguishable from one writer's whole content.
rigBadRounds=0
rigBadDetail=""
for rigRound in $( seq 1 "$rigRounds" ) ; do
	printf 'seed\n' > "$rigTmp/ws/IN/w"
	for rigKey in a b c d ; do
		rigTool Write "{\"path\":\"$rigTmp/ws/IN/w\",\"content\":\"$rigKey$rigKey$rigKey\\n$rigKey$rigKey$rigKey\\n$rigKey$rigKey$rigKey\\n\"}" "$rigTmp/r.w.$rigKey" &
	done
	wait
	rigWhole="none"
	for rigKey in a b c d ; do
		[ "$( cat "$rigTmp/ws/IN/w" )" != "$rigKey$rigKey$rigKey"$'\n'"$rigKey$rigKey$rigKey"$'\n'"$rigKey$rigKey$rigKey" ] || rigWhole="$rigKey"
	done
	rigOks="$( cat "$rigTmp"/r.w.? | LC_ALL=C grep -c '^OK: wrote' )"
	if [ "$rigWhole" = none ] || [ "$rigOks" != 4 ] ; then
		rigBadRounds=$(( rigBadRounds + 1 ))
		rigBadDetail="$rigBadDetail round $rigRound: whole=$rigWhole bytes=$( wc -c < "$rigTmp/ws/IN/w" | tr -d ' ' ) ok=$rigOks;"
	fi
done
rigAssert "every round ends with exactly one writer's whole content, each call reported OK" "$rigBadRounds bad of $rigRounds${rigBadDetail:+ --$rigBadDetail}" "0 bad of $rigRounds"

echo "-- a write lock left by a dead holder is reclaimed; a live holder's is not --"
## The lock is a symlink whose target is the holder's pid, keyed by the resolved target
## through cksum. A pid this rig started and reaped is dead; this rig's own pid is alive.
mkdir -p "$rigTmp/ws/.local/agents/locks"
rigLockPath="$rigTmp/ws/.local/agents/locks/$( printf '%s' "$rigTmp/ws/IN/lk" | LC_ALL=C cksum | LC_ALL=C tr ' ' '-' )"
sleep 0 & rigDeadPid=$! ; wait "$rigDeadPid"
ln -s "$rigDeadPid" "$rigLockPath"
printf 'rig-orig\n' > "$rigTmp/ws/IN/lk"
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.stale"
rigAssert "a dead holder's lock is broken and the edit lands" "$( cat "$rigTmp/ws/IN/lk" )" rig-new
rigAssert "and the lock is released afterwards"       "$( [ -e "$rigLockPath" ] || [ -L "$rigLockPath" ] && printf held || printf released )" released
ln -s "$$" "$rigLockPath"
printf 'rig-orig\n' > "$rigTmp/ws/IN/lk"
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.live"
rigAssert "control: a live holder's lock refuses the edit" "$( sed -n '2s/^\(ERROR: could not take the write lock\).*/\1/p' "$rigTmp/r.live" )" "ERROR: could not take the write lock"
rigAssert "and nothing was written"                   "$( cat "$rigTmp/ws/IN/lk" )" rig-orig
rm -f "$rigLockPath"
## The earlier directory form, pid file or not, is stale by definition and removed once.
mkdir -p "$rigLockPath"
printf '%s\n' "$$" > "$rigLockPath/pid"
printf 'rig-orig\n' > "$rigTmp/ws/IN/lk"
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.oldform"
rigAssert "an old directory-form lock is reclaimed and the edit lands" "$( cat "$rigTmp/ws/IN/lk" )" rig-new
rigAssert "and nothing of it is left"                 "$( [ -e "$rigLockPath" ] || [ -L "$rigLockPath" ] && printf held || printf released )" released
## A stale lock the caller cannot remove must end in the busy ERROR within the bound; a
## retry that never counts spins until the watchdog kills it, which shows as a hang.
rm -rf "$rigLockPath"
ln -s "$rigDeadPid" "$rigLockPath"
chmod 555 "$rigTmp/ws/.local/agents/locks"
printf 'rig-orig\n' > "$rigTmp/ws/IN/lk"
rigStuckStart="$( date +%s )"
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.stuck"
rigStuckSecs=$(( $( date +%s ) - rigStuckStart ))
chmod 755 "$rigTmp/ws/.local/agents/locks"
## An ERROR result exits 1; the watchdog's kill would show as 137.
rigAssert "an unremovable stale lock is not a hang -- the refusal's own exit 1" "$( head -1 "$rigTmp/r.stuck" )" 1
rigAssert "it returns well inside the bound"          "$( [ "$rigStuckSecs" -lt 45 ] && printf yes || printf "no, ${rigStuckSecs}s" )" yes
rigAssert "it ends in the busy ERROR"                 "$( sed -n '2s/^\(ERROR: could not take the write lock\).*/\1/p' "$rigTmp/r.stuck" )" "ERROR: could not take the write lock"
rigAssert "and nothing was written"                   "$( cat "$rigTmp/ws/IN/lk" )" rig-orig
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.unstuck"
rigAssert "control: with the mode restored the edit lands" "$( cat "$rigTmp/ws/IN/lk" )" rig-new
rm -f "$rigLockPath"
## The same for an old directory-form lock, whose removal is the other retry path.
mkdir -p "$rigLockPath"
chmod 555 "$rigTmp/ws/.local/agents/locks"
printf 'rig-orig\n' > "$rigTmp/ws/IN/lk"
rigStuckStart="$( date +%s )"
rigEdit "$rigTmp/ws/IN/lk" rig-orig rig-new "$rigTmp/r.stuckdir"
rigStuckSecs=$(( $( date +%s ) - rigStuckStart ))
chmod 755 "$rigTmp/ws/.local/agents/locks"
rigAssert "an unremovable old-form lock is not a hang -- the refusal's own exit 1" "$( head -1 "$rigTmp/r.stuckdir" )" 1
rigAssert "it returns well inside the bound"          "$( [ "$rigStuckSecs" -lt 45 ] && printf yes || printf "no, ${rigStuckSecs}s" )" yes
rigAssert "and nothing was written"                   "$( cat "$rigTmp/ws/IN/lk" )" rig-orig
rm -rf "$rigLockPath"

echo "-- a reader never sees a half-written file --"
## Write and Edit replace the file atomically, so a reader started at any moment gets one
## whole version. A large body widens the in-place truncate-then-fill window this catches.
rigBody="$( LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 4000 ; lineNo++ ) printf "rig-line-%05d-padding-padding-padding\\n", lineNo ; }' )"
rigTool Write "{\"path\":\"$rigTmp/ws/IN/big\",\"content\":\"rig-state-A\\n$rigBody\"}" "$rigTmp/r.bigA"
cp "$rigTmp/ws/IN/big" "$rigTmp/big.A"
sed '1s/rig-state-A/rig-state-B/' "$rigTmp/big.A" > "$rigTmp/big.B"
( while [ ! -f "$rigTmp/reader.stop" ] ; do
	## One open per read: comparing the live path twice lets a rename land between the two.
	cat "$rigTmp/ws/IN/big" > "$rigTmp/big.snap"
	cmp -s "$rigTmp/big.snap" "$rigTmp/big.A" || cmp -s "$rigTmp/big.snap" "$rigTmp/big.B" || printf 'torn\n' >> "$rigTmp/reader.log"
	printf 'read\n' >> "$rigTmp/reader.log"
done ) &
rigReaderPid=$!
for rigRound in $( seq 1 10 ) ; do
	rigEdit "$rigTmp/ws/IN/big" rig-state-A rig-state-B "$rigTmp/r.bigE"
	rigTool Write "{\"path\":\"$rigTmp/ws/IN/big\",\"content\":\"rig-state-A\\n$rigBody\"}" "$rigTmp/r.bigW"
done
: > "$rigTmp/reader.stop"
wait "$rigReaderPid"
rigAssert "the reader really read while the file changed" "$( [ "$( LC_ALL=C grep -c '^read$' "$rigTmp/reader.log" )" -gt 20 ] && printf yes || printf no )" yes
rigAssert "every read was one whole version"           "$( LC_ALL=C grep -c '^torn$' "$rigTmp/reader.log" ) torn reads" "0 torn reads"

echo "-- an atomic replace keeps the file's own mode --"
printf 'rig-orig\n' > "$rigTmp/ws/IN/mode"
chmod 600 "$rigTmp/ws/IN/mode"
rigEdit "$rigTmp/ws/IN/mode" rig-orig rig-new "$rigTmp/r.modeE"
rigAssert "Edit keeps a 600 file at 600"               "$( ls -l "$rigTmp/ws/IN/mode" | cut -c1-10 )" "-rw-------"
rigTool Write "{\"path\":\"$rigTmp/ws/IN/mode\",\"content\":\"rig-w\\n\"}" "$rigTmp/r.modeW"
rigAssert "Write keeps a 600 file at 600"              "$( ls -l "$rigTmp/ws/IN/mode" | cut -c1-10 )" "-rw-------"

echo "-- Write is byte-exact at the end of its content --"
## Both directions, so a fix that appends a newline to everything fails as surely as today's strip.
rigTool Write "{\"path\":\"$rigTmp/ws/IN/nl\",\"content\":\"a\\n\"}" "$rigTmp/r.nl"
rigAssert "content ending in a newline keeps it"      "$( od -An -c "$rigTmp/ws/IN/nl" | tr -d ' ' )" 'a\n'
rigTool Write "{\"path\":\"$rigTmp/ws/IN/nonl\",\"content\":\"a\"}" "$rigTmp/r.nonl"
rigAssert "content with no final newline stays without one" "$( od -An -c "$rigTmp/ws/IN/nonl" | tr -d ' ' )" 'a'

echo "-- control: the same four Edits one after another --"
printf 'a\nb\nc\nd\n' > "$rigTmp/ws/IN/s"
for rigKey in a b c d ; do
	rigEdit "$rigTmp/ws/IN/s" "$rigKey" "${rigKey}X" "$rigTmp/r.seq.$rigKey"
done
rigAssert "sequential Edits keep all four lines"       "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/ws/IN/s" )" 4
rigAssert "and all four changes"                       "$( LC_ALL=C grep -c X "$rigTmp/ws/IN/s" )" 4

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EDIT INTEGRITY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_EDIT_INTEGRITY: OK (%d assertions, offline)\n' "$rigPassCount"
