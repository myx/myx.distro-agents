#!/usr/bin/env bash
## Behavioural check that a routine close (--magic-*-close-state-and-unlock, through
## AgentsToolsItemUpsert --unlock-lock) prints RELEASED only once its own close is on
## disk -- state finished, last-close-date stamped -- and committed/pushed as configured;
## and that every way the close cannot be recorded keeps the lock: no RELEASED, rc 1, a
## CLOSE_NOT_RECORDED error, and the note not left finished. Covers a plain store, a git
## store with no remote, and one with a temp bare origin: a missing note, a note with no
## frontmatter (one is added: released), an unwritable note, a failing commit, a concurrent push to the same note,
## an unrelated concurrent push (rebased and pushed: released), and an unreachable origin.
## Offline: MMDAPP, MDAT_DATA_ROOT and the git global config all point into a mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsCloseUnlockRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents"
printf '[user]\n\tname = rig\n\temail = rig@example.invalid\n[init]\n\tdefaultBranch = main\n' > "$rigTmp/gitconfig"
export GIT_CONFIG_GLOBAL="$rigTmp/gitconfig" GIT_CONFIG_NOSYSTEM=1 MMDAPP="$rigTmp/ws" MDLT_ORIGIN
rigToday="$( date +%Y-%m-%d )"
rigNoteName="note-20260809T154332Z-grooming-state-and-lock.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1" 2>/dev/null
}
rigStore=""
rigNote=""
rigUse(){ ## store dir
	rigStore="$1" ; rigNote="$1/inboxes/magic-coordinator/$rigNoteName"
	mkdir -p "$1/inboxes/magic-coordinator" "$1/audit"
	for rigState in backlog pending running review blocked parked ; do mkdir -p "$1/board/$rigState" ; done
}
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	case "$rigStore" in "$rigTmp"/*) ;; *) rigRefuse "store outside the rig: $rigStore" ;; esac
	( cd "$MMDAPP" && MDAT_DATA_ROOT="$rigStore" bash "$rigFn" "$@" ) > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigClose(){ ## result file
	rigOp "$1" --magic-grooming-close-state-and-unlock magic-coordinator
}
## rc:released-count:error-count, the shape every close outcome is asserted in.
rigOutcome(){ ## result file
	printf '%s:%s:%s' "$( cat "$1.rc" )" "$( LC_ALL=C grep -c -x 'RELEASED' "$1" )" "$( LC_ALL=C grep -c 'CLOSE_NOT_RECORDED' "$1" )"
}
rigRunningNote(){ ## session-id
	printf -- '---\ntype: note\nstate: grooming-running\nsession-id: %s\nrecheck-date: 2001-01-01 00:00 +0000\n---\n\nrunning\n' "$1" > "$rigNote"
}

echo "-- plain store (not a repository) --"
rigUse "$rigTmp/plain"
rigOp "$rigTmp/p0" --magic-grooming-lock-acquire magic-coordinator rig
rigAssert "acquired"                                  "$( cat "$rigTmp/p0.rc" ):$( LC_ALL=C grep -c -x ACQUIRED "$rigTmp/p0" )" "0:1"
rigClose "$rigTmp/p1"
rigAssert "close: RELEASED, rc 0"                     "$( rigOutcome "$rigTmp/p1" )" "0:1:0"
rigAssert "close: state and last-close-date on disk"  "$( rigField "$rigNote" state ) $( rigField "$rigNote" last-close-date )" "grooming-finished $rigToday"
rm -f "$rigNote"
rigClose "$rigTmp/p2"
rigAssert "no note: not released, rc 1, said"         "$( rigOutcome "$rigTmp/p2" )" "1:0:1"
printf 'no frontmatter here\n' > "$rigNote"
rigClose "$rigTmp/p3"
rigAssert "no frontmatter: one is added, the close in it, RELEASED" "$( rigOutcome "$rigTmp/p3" ) $( rigField "$rigNote" state ) $( rigField "$rigNote" last-close-date )" "0:1:0 grooming-finished $rigToday"
rigRunningNote rig
chmod 444 "$rigNote"
rigClose "$rigTmp/p4"
chmod 644 "$rigNote"
rigAssert "unwritable note: not released, rc 1, said" "$( rigOutcome "$rigTmp/p4" )" "1:0:1"
rigAssert "unwritable note: the lock is kept"         "$( rigField "$rigNote" state )" grooming-running

echo "-- git store, no remote --"
rigUse "$rigTmp/local"
git -C "$rigStore" init -q && printf 'seed\n' > "$rigStore/README.md" && git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the local store"
rigOp "$rigTmp/l0" --magic-grooming-lock-acquire magic-coordinator rig
rigClose "$rigTmp/l1"
rigAssert "close: RELEASED, rc 0"                     "$( rigOutcome "$rigTmp/l1" )" "0:1:0"
rigAssert "close: committed as finished"              "$( git -C "$rigStore" show "HEAD:inboxes/magic-coordinator/$rigNoteName" | LC_ALL=C grep -c -x -e 'state: grooming-finished' -e "last-close-date: $rigToday" )" 2
rigOp "$rigTmp/l2" --magic-grooming-lock-acquire magic-coordinator rig
rigHeadBefore="$( git -C "$rigStore" rev-parse HEAD )"
printf '#!/bin/sh\nexit 1\n' > "$rigStore/.git/hooks/pre-commit" ; chmod +x "$rigStore/.git/hooks/pre-commit"
rigClose "$rigTmp/l3"
rm -f "$rigStore/.git/hooks/pre-commit"
rigAssert "commit fails: not released, rc 1, said"    "$( rigOutcome "$rigTmp/l3" )" "1:0:1"
rigAssert "commit fails: the lock is kept on disk"    "$( rigField "$rigNote" state )" grooming-running
rigAssert "commit fails: no commit, nothing staged"   "$( git -C "$rigStore" rev-parse HEAD ):$( git -C "$rigStore" status --porcelain | wc -l | tr -d ' ' )" "$rigHeadBefore:0"

echo "-- git store with a temp bare origin --"
rigBare="$rigTmp/origin.git"
git init -q --bare "$rigBare" || rigRefuse "could not init the bare origin"
rigSeed="$rigTmp/seed"
git init -q "$rigSeed" && printf 'seed\n' > "$rigSeed/README.md" && git -C "$rigSeed" add -A && git -C "$rigSeed" commit -q -m seed && git -C "$rigSeed" push -q "$rigBare" HEAD:main 2>/dev/null || rigRefuse "could not seed the bare origin"
git clone -q "$rigBare" "$rigTmp/remote" 2>/dev/null || rigRefuse "could not clone the bare origin"
rigUse "$rigTmp/remote"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigBare" > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
rigOriginNote(){ git --git-dir="$rigBare" show "main:inboxes/magic-coordinator/$rigNoteName" 2>/dev/null ; }
rigOther="$rigTmp/other"
git clone -q "$rigBare" "$rigOther" 2>/dev/null || rigRefuse "could not clone the other host"
rigOtherPush(){ ## file relative to the store, content
	git -C "$rigOther" pull -q --no-rebase origin main 2>/dev/null
	mkdir -p "$( dirname "$rigOther/$1" )" && printf '%s\n' "$2" > "$rigOther/$1"
	git -C "$rigOther" add -A && git -C "$rigOther" commit -q -m other && git -C "$rigOther" push -q origin HEAD:main 2>/dev/null || rigRefuse "the other host could not push"
}

rigOp "$rigTmp/r0" --magic-grooming-lock-acquire magic-coordinator rig
rigAssert "acquired and pushed"                       "$( cat "$rigTmp/r0.rc" ):$( rigOriginNote | LC_ALL=C grep -c -x 'state: grooming-running' )" "0:1"
rigClose "$rigTmp/r1"
rigAssert "close: RELEASED, rc 0"                     "$( rigOutcome "$rigTmp/r1" )" "0:1:0"
rigAssert "close: the origin holds the close"         "$( rigOriginNote | LC_ALL=C grep -c -x -e 'state: grooming-finished' -e "last-close-date: $rigToday" )" 2

rigOp "$rigTmp/r2" --magic-grooming-lock-acquire magic-coordinator rig
rigOtherPush "inboxes/magic-coordinator/$rigNoteName" "$( printf -- '---\ntype: note\nstate: grooming-running\nsession-id: rig\nrecheck-date: 2999-01-01 00:00 +0000\n---\n\nedited on another host' )"
rigClose "$rigTmp/r3"
rigAssert "concurrent edit of the note: not released, rc 1, said" "$( rigOutcome "$rigTmp/r3" )" "1:0:1"
rigAssert "concurrent edit: the note on disk is not finished" "$( rigField "$rigNote" state )" grooming-running
rigAssert "concurrent edit: the origin is not finished"  "$( rigOriginNote | LC_ALL=C grep -c -x 'state: grooming-finished' )" 0
rigClose "$rigTmp/r4"
rigAssert "re-run after the sync: RELEASED, rc 0"       "$( rigOutcome "$rigTmp/r4" )" "0:1:0"
rigAssert "re-run: the origin holds the close"          "$( rigOriginNote | LC_ALL=C grep -c -x -e 'state: grooming-finished' -e "last-close-date: $rigToday" )" 2

rigOp "$rigTmp/r5" --magic-grooming-lock-acquire magic-coordinator rig
rigOtherPush "elsewhere/other-host.md" "unrelated"
git -C "$rigStore" config pull.rebase true
rigClose "$rigTmp/r6"
git -C "$rigStore" config --unset pull.rebase
rigAssert "unrelated concurrent push, rebased: RELEASED, rc 0" "$( rigOutcome "$rigTmp/r6" )" "0:1:0"
rigAssert "rebased: the origin holds the close"          "$( rigOriginNote | LC_ALL=C grep -c -x -e 'state: grooming-finished' -e "last-close-date: $rigToday" )" 2

rigOp "$rigTmp/r7" --magic-grooming-lock-acquire magic-coordinator rig
rigHeadBefore="$( git -C "$rigStore" rev-parse HEAD )"
git -C "$rigStore" remote set-url origin "$rigTmp/missing.git"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigTmp/missing.git" > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
rigClose "$rigTmp/r8"
rigAssert "unreachable origin: not released, rc 1, said" "$( rigOutcome "$rigTmp/r8" )" "1:0:1"
rigAssert "unreachable: the lock is kept on disk"       "$( rigField "$rigNote" state )" grooming-running
rigAssert "unreachable: the close's commit is dropped"  "$( git -C "$rigStore" rev-parse HEAD ):$( git -C "$rigStore" status --porcelain | wc -l | tr -d ' ' )" "$rigHeadBefore:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CLOSE-UNLOCK RECORD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CLOSE_UNLOCK_RECORD: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
