#!/usr/bin/env bash
## Behavioural check on the clone at dispatch: a missing team-data store with a remote
## set is cloned by the first op of any kind; two first ops at once clone once; a clone
## that fails warns once and the op goes on; an existing clone is never touched. Temp
## stores and temp bare remotes only -- git runs here on this rig's own mktemp trees --
## and every op goes through one `env -i` whose child refuses to run outside that tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsTeamDataCloneAtDispatchCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid

## The remote every scenario clones from: one seed commit on main.
git init -q --bare "$rigTmp/remote.git" || rigRefuse "could not init the bare remote"
git -C "$rigTmp" init -q -b main seed 2>/dev/null || { git -C "$rigTmp" init -q seed && git -C "$rigTmp/seed" checkout -q -b main ; }
printf 'seed\n' > "$rigTmp/seed/README.md"
git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed && git -C "$rigTmp/seed" push -q "$rigTmp/remote.git" main 2>/dev/null \
	|| rigRefuse "could not seed the bare remote"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigScenario(){ ## name, TEAM_DATA_GIT_REMOTE value
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/home/skills/magic-tester"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-tester/magic-tester.basic.md"
	printf 'TEAM_DATA_GIT_REMOTE=%s\nTEAM_DATA_BRANCH=main\n' "$2" > "$rigDir/ws/.local/.agents/magic-team.agent.env"
}
## One op writing a note, guarded; the store is $rigDir/store unless named.
rigOp(){ ## result file, store path
	printf 'rig note\n' | env -i HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$2" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --member-inbox-note-upsert magic-tester note-rig.md
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}

echo "-- a missing store with a remote set is cloned by the first op --"
rigScenario first "$rigTmp/remote.git"
rigOp "$rigDir/r" "$rigDir/store"
rigAssert "the store is now a clone"                   "$( [ -d "$rigDir/store/.git" ] && printf yes || printf no )" yes
rigAssert "holding the remote's content"               "$( cat "$rigDir/store/README.md" 2>/dev/null )" seed
rigAssert "and the op's own write landed in it"        "$( [ -f "$rigDir/store/inboxes/magic-tester/note-rig.md" ] && printf yes || printf no )" yes
rigAssert "the clone is said"                          "$( rigHolds "$rigDir/r.err" "no local board existed, cloned $rigTmp/remote.git (main) into $rigDir/store" )" yes

echo "-- two first ops at once clone once --"
rigScenario twice "$rigTmp/remote.git"
rigOp "$rigDir/a" "$rigDir/store" &
rigOp "$rigDir/b" "$rigDir/store" &
wait
rigAssert "exactly one of them cloned"                 "$( cat "$rigDir/a.err" "$rigDir/b.err" | LC_ALL=C grep -c 'no local board existed, cloned' || : )" 1
rigAssert "and the store is one clone"                 "$( git -C "$rigDir/store" rev-parse --is-inside-work-tree 2>/dev/null )" true

echo "-- a clone that fails warns once, and the op goes on --"
rigScenario fails "$rigTmp/missing.git"
rigOp "$rigDir/f" "$rigDir/store"
rigAssert "one warning"                                "$( LC_ALL=C grep -c 'cloning .* failed, so this write stays local and uncommitted' "$rigDir/f.err" || : )" 1
rigAssert "the op still wrote its note"                "$( [ -f "$rigDir/store/inboxes/magic-tester/note-rig.md" ] && printf yes || printf no )" yes

echo "-- control: an existing clone is not touched --"
rigScenario existing "$rigTmp/missing.git"
git clone -q "$rigTmp/remote.git" "$rigDir/store" 2>/dev/null || rigRefuse "could not make the existing clone"
rigOp "$rigDir/e" "$rigDir/store"
rigAssert "no clone is attempted against a remote that would fail" "$( LC_ALL=C grep -c -E 'cloned|cloning' "$rigDir/e.err" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA CLONE AT DISPATCH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_CLONE_AT_DISPATCH: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
