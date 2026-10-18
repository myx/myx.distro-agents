#!/usr/bin/env bash
## Behavioural check on the team data's remote, reached by myx.common's own git/cloneSync
## and git/clonePull and the close push, as the user the tooling runs as: a store made a
## repository before the remote was set is given it as origin, its branch kept, and its work
## reaches the remote, by the close push and by the storage step; a folder holding content is
## handed to git/cloneSync by the storage step, which adopts it into an empty remote and
## re-attaches it to a filled one; a remote that cannot be reached leaves it as it was; an
## origin other than the setting is set to it; a remote that moved is integrated by
## git/cloneSync; two clones claiming one lock do not both take it. With no remote set
## nothing of it happens.
## git runs only on this rig's own mktemp tree, and every remote is a bare repository of the
## rig, named by its path: no ssh is started (an `ssh` of the rig stands first in the path,
## and only writes down that it was asked).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMyx="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsTeamDataRemoteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, text
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

## A bare remote with one seed commit on main, holding README.md and one board item.
rigRemote(){ ## name
	git init -q --bare "$rigTmp/$1.git" || rigRefuse "could not init the bare remote $1"
	git -C "$rigTmp/$1.git" symbolic-ref HEAD refs/heads/main
	rm -rf "$rigTmp/seed" ; git init -q "$rigTmp/seed" && git -C "$rigTmp/seed" symbolic-ref HEAD refs/heads/main
	mkdir -p "$rigTmp/seed/board/processed"
	printf 'seed\n' > "$rigTmp/seed/README.md" ; printf 'remote item\n' > "$rigTmp/seed/board/processed/note-20260101T0000Z-remote.md"
	git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed && git -C "$rigTmp/seed" push -q "$rigTmp/$1.git" main 2> /dev/null \
		|| rigRefuse "could not seed the bare remote $1"
}
## One more commit on a remote's main, made from a clone of the rig's own.
rigRemoteAdvance(){ ## remote name, file name
	rm -rf "$rigTmp/adv" ; git clone -q "$rigTmp/$1.git" "$rigTmp/adv" 2> /dev/null || rigRefuse "could not clone $1 to advance it"
	printf 'from elsewhere\n' > "$rigTmp/adv/$2"
	git -C "$rigTmp/adv" add -A && git -C "$rigTmp/adv" commit -q -m "elsewhere: $2" && git -C "$rigTmp/adv" push -q origin main 2> /dev/null || rigRefuse "could not advance $1"
}
rigRemoteHead(){ ## remote name
	git -C "$rigTmp/$1.git" rev-parse -q --verify refs/heads/main 2> /dev/null || printf none
}

rigDir="" ; rigStore=""
rigScenario(){ ## name, TEAM_DATA_GIT_REMOTE value (may be empty)
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/home/skills/magic-tester" "$rigDir/home/skills/magic-coordinator"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-tester/magic-tester.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/magic-coordinator/magic-coordinator.basic.md"
	: > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	[ -z "$2" ] || printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$2" > "$rigDir/ws/.local/.agents/magic-team.agent.env"
}
## A store that is a repository of its own with one commit, on the branch named, and no remote.
rigInitStore(){ ## branch
	mkdir -p "$rigStore/board/running" && git init -q "$rigStore" && git -C "$rigStore" symbolic-ref HEAD "refs/heads/$1" || rigRefuse "could not init the store"
	printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
	git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "local work" || rigRefuse "could not commit into the store"
}
## Runs a piece of shell with the team-data functions at hand, as the tooling has them,
## guarded: HOME, the workspace and the store are the rig's.
rigRun(){ ## result file, shell text
	env -i HOME="$rigDir/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MYXROOT="$rigMyx" GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_TEXT="$2" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			MDSC_CMD=DistroAgentsTools
			DistroAgentsTools(){ bash "$RIG_FN" "$@" ; }
			cd "$MMDAPP" || exit 98
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.TeamDataCommit.include"
			eval "$RIG_TEXT"
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}
## One op of the dispatcher itself, guarded the same way.
rigOp(){ ## result file, op and arguments...
	local rigResult="$1" ; shift
	env -i HOME="$rigDir/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" ${RIG_NO_ROOT:-MDAT_DATA_ROOT="$rigStore"} MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}
## The storage step of the set-up of the rig's workspace; its store is the workspace's own.
rigSetup(){ ## result file
	RIG_NO_ROOT=RIG_UNSET=1 rigOp "$1" --owner-setup-storage --workspace-root "$rigDir/ws" --apply
}

## The ssh of the system is never started from this rig: whoever asks for `ssh` by that name
## gets this, which only writes down that it was asked.
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexit 255\n' "$rigTmp/system-ssh.asked" > "$rigTmp/bin/ssh"
chmod 755 "$rigTmp/bin/ssh"

rigRemote base

echo "-- the rig that never reached its remote: a store made a repository before the remote was set --"
git init -q --bare "$rigTmp/fresh.git" || rigRefuse "could not init the empty remote"
rigScenario later "$rigTmp/fresh.git"
rigInitStore main
rigRun "$rigDir/p" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the store's origin is the remote the setting names"   "$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$rigTmp/fresh.git"
rigAssert "its branch is kept as it was"                        "$( git -C "$rigStore" symbolic-ref --short HEAD 2> /dev/null )" main
rigAssert "the close push brings its work to the remote"         "$( git -C "$rigTmp/fresh.git" rev-parse -q --verify refs/heads/main 2> /dev/null )" "$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "one line says the origin was set"                     "$( rigCount "$rigDir/p.err" "its origin is now TEAM_DATA_GIT_REMOTE $rigTmp/fresh.git" )" 1
rigRun "$rigDir/p2" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "a second close says nothing: the store is in step"    "$( LC_ALL=C grep -c -e WARNING -e 'origin is now' "$rigDir/p2.err" || : )" 0

echo "-- the same through the storage step of the set-up --"
git init -q --bare "$rigTmp/setup.git" || rigRefuse "could not init the empty remote"
rigScenario setup ""
rigSetup "$rigDir/a1"
rigStore="$rigDir/ws/.local/agents/team-data-root"
rigAssert "with no remote the store is initialised, nothing more" "$( [ -d "$rigStore/.git" ] && printf repo || printf none ):$( git -C "$rigStore" remote 2> /dev/null | wc -l | LC_ALL=C tr -d ' ' )" "repo:0"
rigSetupBranch="$( git -C "$rigStore" symbolic-ref --short HEAD 2> /dev/null )"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "local work" || rigRefuse "could not commit into the set-up store"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigTmp/setup.git" > "$rigDir/ws/.local/.agents/magic-team.agent.env"
rigSetup "$rigDir/a2"
rigAssert "the remote set afterwards becomes its origin"         "$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$rigTmp/setup.git"
rigAssert "and the set-up itself pushes the work, its branch kept" "$( git -C "$rigTmp/setup.git" rev-parse -q --verify "refs/heads/$rigSetupBranch" 2> /dev/null ):$( git -C "$rigStore" symbolic-ref --short HEAD )" "$( git -C "$rigStore" rev-parse HEAD ):$rigSetupBranch"

echo "-- an empty root is cloned by git/clonePull at the first use --"
rigScenario empty "$rigTmp/base.git"
mkdir -p "$rigStore"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "the store is a clone holding the remote's content"    "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( cat "$rigStore/README.md" 2> /dev/null )" "$( rigRemoteHead base ):seed"

echo "-- a folder with content and a filled remote: the storage step hands it to git/cloneSync, no file of it lost --"
rigRemote filled
rigScenario plain "$rigTmp/filled.git"
rigStore="$rigDir/ws/.local/agents/team-data-root"
mkdir -p "$rigStore/board/running" "$rigStore/inboxes/magic-tester"
printf 'local readme\n' > "$rigStore/README.md"
printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
printf 'local note\n' > "$rigStore/inboxes/magic-tester/note-rig.md"
rigSetup "$rigDir/a"
rigAssert "the folder is a clone of the remote now"              "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$( rigRemoteHead filled ):$rigTmp/filled.git"
rigAssert "no file of it was changed"                            "$( cat "$rigStore/README.md" "$rigStore/board/running/note-20261014T0101Z-local.md" "$rigStore/inboxes/magic-tester/note-rig.md" 2> /dev/null | LC_ALL=C tr '\n' '/' )" "local readme/local item/local note/"
rigAssert "one line says git/cloneSync made it a clone"          "$( rigCount "$rigDir/a.err" "git/cloneSync made $rigStore a clone of TEAM_DATA_GIT_REMOTE" )" 1

echo "-- a folder with content and an empty remote: handed to git/cloneSync, which adopts it --"
## myx.common git/cloneSync commits such a folder and pushes it into an empty remote: the
## folder becomes a clone of the remote, its file stands, and the file is in the remote.
git init -q --bare "$rigTmp/unborn.git" || rigRefuse "could not init the empty remote"
rigScenario unborn "$rigTmp/unborn.git"
rigStore="$rigDir/ws/.local/agents/team-data-root"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigSetup "$rigDir/a"
rigAssert "git/cloneSync adopted it: a clone of the remote, its file stands and is in the remote" "$( [ -e "$rigStore/.git" ] && printf repo || printf folder ):$( cat "$rigStore/board/running/note-20261014T0101Z-local.md" 2> /dev/null ):$( git -C "$rigStore" remote get-url origin 2> /dev/null ):$( git --git-dir="$rigTmp/unborn.git" log --all --format= --name-only 2> /dev/null | LC_ALL=C grep -c -x -F 'board/running/note-20261014T0101Z-local.md' )" "repo:local item:$rigTmp/unborn.git:1"
rigAssert "and the step says git/cloneSync made it a clone"      "$( rigCount "$rigDir/a.err" "git/cloneSync made $rigStore a clone of TEAM_DATA_GIT_REMOTE" ):$( rigCount "$rigDir/a.err" "is not a clone of TEAM_DATA_GIT_REMOTE yet" ):$( rigCount "$rigDir/a.err" "fatal: not a git repository" )" "1:0:0"

echo "-- a folder with content whose remote cannot be reached is left as it was --"
rigScenario unreach "$rigTmp/missing.git"
rigStore="$rigDir/ws/.local/agents/team-data-root"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigSetup "$rigDir/a"
rigAssert "it is no repository, and its file stands"             "$( [ -e "$rigStore/.git" ] && printf repo || printf plain ):$( cat "$rigStore/board/running/note-20261014T0101Z-local.md" )" "plain:local item"
rigAssert "one warning says it is no clone of the remote yet"    "$( rigCount "$rigDir/a.err" "is not a clone of TEAM_DATA_GIT_REMOTE yet" )" 1

echo "-- a clone whose origin is another address than the setting --"
rigRemote movedfrom
git clone -q --bare "$rigTmp/movedfrom.git" "$rigTmp/moved.git" || rigRefuse "could not copy the remote"
rigScenario moved "$rigTmp/moved.git"
git clone -q "$rigTmp/movedfrom.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/p" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0101Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the origin is the setting's, said in one line"        "$( git -C "$rigStore" remote get-url origin ):$( rigCount "$rigDir/p.err" "its origin is now TEAM_DATA_GIT_REMOTE $rigTmp/moved.git" )" "$rigTmp/moved.git:1"
rigAssert "the commit went to it, and not to the old address"    "$( [ "$( git -C "$rigTmp/moved.git" rev-parse refs/heads/main )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf new || printf not ):$( [ "$( rigRemoteHead movedfrom )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf old || printf untouched )" "new:untouched"

echo "-- a commit is followed by a push at the close --"
rigRemote pushed
rigScenario pushed "$rigTmp/pushed.git"
git clone -q "$rigTmp/pushed.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/p" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0101Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the remote has the commit"                            "$( rigRemoteHead pushed )" "$( git -C "$rigStore" rev-parse HEAD )"

echo "-- both sides moved from one commit: git/cloneSync integrates, both kept, pushed --"
rigRemoteAdvance pushed elsewhere-2.md
printf 'local two\n' > "$rigStore/board/running/note-20261014T0102Z-local.md"
rigRun "$rigDir/m" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0102Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "both sides' files are in the store and on the remote" "$( cat "$rigStore/elsewhere-2.md" "$rigStore/board/running/note-20261014T0102Z-local.md" 2> /dev/null | LC_ALL=C tr '\n' '/' ):$( [ "$( rigRemoteHead pushed )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf pushed || printf not )" "from elsewhere/local two/:pushed"

echo "-- two clones claim one lock: the second sees the first's claim on the remote and does not take it --"
rigRemote claims
rigScenario claimb "$rigTmp/claims.git"
git clone -q "$rigTmp/claims.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the second clone"
rigClaimDirB="$rigDir" ; rigClaimStoreB="$rigStore"
rigScenario claima "$rigTmp/claims.git"
git clone -q "$rigTmp/claims.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the first clone"
rigClaimNote="inboxes/magic-coordinator/note-20260809T154332Z-grooming-state-and-lock.md"
rigOp "$rigDir/a" --magic-grooming-lock-acquire magic-coordinator rig-a
rigAssert "the first takes it, and its claim is on the remote's main" "$( cat "$rigDir/a.rc" ):$( LC_ALL=C grep -c -x ACQUIRED "$rigDir/a" ):$( git -C "$rigTmp/claims.git" show "main:$rigClaimNote" 2> /dev/null | LC_ALL=C grep -c -x 'session-id: rig-a' )" "0:1:1"
rigDir="$rigClaimDirB" ; rigStore="$rigClaimStoreB"
rigOp "$rigDir/b" --magic-grooming-lock-acquire magic-coordinator rig-b
rigAssert "the second does not take it"                          "$( [ "$( cat "$rigDir/b.rc" )" != 0 ] && printf refused || printf took ):$( LC_ALL=C grep -c -x ACQUIRED "$rigDir/b" )" "refused:0"
rigAssert "the remote's main still holds the first's claim"      "$( git -C "$rigTmp/claims.git" show "main:$rigClaimNote" 2> /dev/null | LC_ALL=C grep -c -x 'session-id: rig-a' )" 1

echo "-- control: with no remote set nothing of this happens --"
rigScenario none ""
rigInitStore master
rigRun "$rigDir/p" 'AgentsToolsTeamDataEnsureClone rig ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "no word, no origin, no branch change"                 "$( cat "$rigDir/p" "$rigDir/p.err" | wc -c | LC_ALL=C tr -d ' ' ):$( git -C "$rigStore" remote | wc -l | LC_ALL=C tr -d ' ' ):$( git -C "$rigStore" symbolic-ref --short HEAD )" "0:0:master"

echo "-- the ssh of the system was never started by any of it --"
rigAssert "no ssh was asked for"                                 "$( [ -e "$rigTmp/system-ssh.asked" ] && wc -l < "$rigTmp/system-ssh.asked" | LC_ALL=C tr -d ' ' || printf 0 )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA REMOTE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_REMOTE: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
