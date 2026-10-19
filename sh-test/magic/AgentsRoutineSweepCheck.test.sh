#!/usr/bin/env bash
## Check over the single routine-file sweep (F6.7 of the refactorings epic), read rather than run: it is a check of the
## documents the sweep edits, every `*.routine.md` of this package's skillset. In one pass per file the sweep applies
## F5.4's three section headings (`# Opening steps`, `# Steps`, `# Closure steps`) and `type:`; F6.1's
## `requires-session-kind:`, its one mandatory key, `session:` renamed in the same pass (its other keys,
## `tracking-item:`, `operations:` and `start-context:`, are optional, and there is no `requires:` line); and F6.4's
## removal of the scan operation name from each file's own tooling. F5.4 also removes `default-for-session-kind:`.
## Held, for every routine file of the package:
##   1. the three headings stand, in that order, each once
##   2. its frontmatter carries type: and requires-session-kind:, and none of session:, default-for-session-kind: and
##      requires:
##   3. its body names no `--*-input-scan` operation: a routine declares its scans in its frontmatter (`input-scan-def:`), it does not call one
## And a control: the files are found, and each has the frontmatter block and the # Steps heading it has today.
## Red before F6.7: no file has `# Opening steps` or `requires-session-kind:` (1 and 2 fail for every file).
## Offline: it reads the package's skillset and writes nothing.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigSkillset="$MDLT_ORIGIN/myx/myx.distro-agents/skillset"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigSkillset" ] || rigRefuse "no skillset at the origin this workspace resolves: $rigSkillset"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsRoutineSweepCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
find "$rigSkillset" -name '*.routine.md' -type f | LC_ALL=C sort > "$rigTmp/files"
rigFiles="$( LC_ALL=C grep -c . "$rigTmp/files" )"
[ "$rigFiles" -ge 20 ] 2> /dev/null || rigRefuse "too few routine files found to be the package's skillset: $rigFiles"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigFront(){ ## file -- its first frontmatter block
	LC_ALL=C awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"
}
## The files failing a rule, by their names below the skillset, joined by spaces.
rigFailing(){ ## rule function
	local failingFile failingList=""
	while IFS= read -r failingFile ; do
		"$1" "$failingFile" || failingList="$failingList ${failingFile#"$rigSkillset"/}"
	done < "$rigTmp/files"
	printf '%s' "${failingList# }"
}
rigHeadings(){ ## file -- rc 0 where the three headings stand once each, in order
	[ "$( LC_ALL=C grep -E -x '# (Opening steps|Steps|Closure steps)' "$1" | LC_ALL=C tr '\n' '|' )" = "# Opening steps|# Steps|# Closure steps|" ]
}
rigKeys(){ ## file -- rc 0 where the frontmatter carries the new keys and none of the old ones
	local keysFront
	keysFront="$( rigFront "$1" )"
	printf '%s\n' "$keysFront" | LC_ALL=C grep -q '^type: ' && printf '%s\n' "$keysFront" | LC_ALL=C grep -q '^requires-session-kind: ' \
		&& ! printf '%s\n' "$keysFront" | LC_ALL=C grep -q -E '^(session|default-for-session-kind|requires): '
}
rigNoScanOp(){ ## file -- rc 0 where its body, below the frontmatter, names no input-scan operation (the frontmatter declares scans: `input-scan-def: <scan>`)
	! LC_ALL=C awk 'NR == 1 && $0 == "---" { inFront = 1 ; next } inFront && $0 == "---" { inFront = 0 ; next } ! inFront { print }' "$1" | LC_ALL=C grep -q -E -- '--[a-z-]+-input-scan\b'
}
rigControl(){ ## file -- rc 0 where it has a frontmatter block and a # Steps heading, as every routine does today
	[ -n "$( rigFront "$1" )" ] && LC_ALL=C grep -q -x '# Steps' "$1"
}

echo "-- control: the $rigFiles routine files are read --"
rigAssert "each has its frontmatter block and its # Steps heading" "[$( rigFailing rigControl )]" "[]"
echo "-- 1. the three section headings, in order, each once --"
rigAssert "every routine file"                                "[$( rigFailing rigHeadings )]" "[]"
echo "-- 2. type: and requires-session-kind:; no session:, no default-for-session-kind:, no requires: --"
rigAssert "every routine file"                                "[$( rigFailing rigKeys )]" "[]"
echo "-- 3. no input-scan operation named --"
rigAssert "every routine file"                                "[$( rigFailing rigNoScanOp )]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE SWEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_SWEEP: OK (%d assertions, %d routine files, offline)\n' "$rigPassCount" "$rigFiles"
