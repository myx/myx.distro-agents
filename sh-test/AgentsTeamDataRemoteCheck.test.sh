#!/usr/bin/env bash
## Behavioural check on the team data's remote: with TEAM_DATA_GIT_REMOTE set the store
## becomes a clone of it and stays one. A store made a repository before the remote was set
## is given it as origin, on the branch the setting names, and pushed; an absent or empty
## store is cloned; a plain folder with content is made a clone in place and no file of it
## is changed or lost; an origin other than the setting is set to it; a remote that is ahead
## is followed, one gone apart is left alone and said; a push is bounded and a remote that
## never answers holds no close; a refused key is named by its fingerprint, a host that is
## not known is refused at once and named; what happened is kept for the setup's check.
## With no remote set nothing of it happens.
## git and ssh-keygen run only on this rig's own mktemp tree; every remote is a bare
## repository of the rig. Where a scenario needs ssh, the ssh is a stand-in of the rig that
## runs the remote's command on this machine: the address names a host of .invalid that is
## never looked up, and no ssh of the system is started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMyx="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
command -v ssh-keygen > /dev/null || rigRefuse "ssh-keygen is not installed"
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
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
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

rigDir="" ; rigStore="" ; rigEnv=()
rigScenario(){ ## name, TEAM_DATA_GIT_REMOTE value (may be empty)
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store" ; rigEnv=()
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
## guarded: HOME, the workspace and the store are the rig's. Extra environment in rigEnv.
rigRun(){ ## result file, shell text
	env -i HOME="$rigDir/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MYXROOT="$rigMyx" GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_SSH_LOG="$rigDir/ssh.log" RIG_SSH_MODE="$rigDir/ssh.mode" RIG_SSH_PID="$rigDir/ssh.pid" ${rigEnv[@]+"${rigEnv[@]}"} RIG_TEXT="$2" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: HOME outside the rig tree" >&2 ; exit 99 ;; esac
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
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_SSH_LOG="$rigDir/ssh.log" RIG_SSH_MODE="$rigDir/ssh.mode" RIG_SSH_PID="$rigDir/ssh.pid" ${rigEnv[@]+"${rigEnv[@]}"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}
rigState(){ ## key of what the tooling keeps of the remote
	LC_ALL=C sed -n "s/^$1=//p" "$rigDir/ws/.local/agents/team-data-remote.state" 2> /dev/null | head -n 1
}

## THE STAND-IN FOR ssh. It writes down how it was called, then does what its mode file
## says: `pass` runs the remote's command on this machine; `hang` never answers; `refuse`
## answers as a git host that does not know the key; `unknown` is a host this account does
## not know, which asks its question for ever unless it runs in batch mode.
mkdir -p "$rigTmp/bin"
cat > "$rigTmp/bin/rig-ssh" << 'RIGSSH'
#!/bin/sh
printf '%s\n' "$*" >> "$RIG_SSH_LOG"
printf '%s\n' "$$" > "$RIG_SSH_PID"
for rigLast in "$@" ; do : ; done
case "$( cat "$RIG_SSH_MODE" 2> /dev/null )" in
	hang) sleep 40 ; exit 255 ;;
	refuse) echo "rig@standin.invalid: Permission denied (publickey)." >&2 ; exit 255 ;;
	unknown)
		case " $* " in
			*" BatchMode=yes "*) echo "Host key verification failed." >&2 ; exit 255 ;;
		esac
		sleep 40 ; exit 255
	;;
	*) exec sh -c "git ${rigLast#git-}" ;;
esac
RIGSSH
chmod 755 "$rigTmp/bin/rig-ssh"
## And the ssh of the system is never started from this rig: whoever asks for `ssh` by
## that name gets this, which only writes down that it was asked.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\necho "rig: the ssh of the system was asked for" >&2\nexit 255\n' "$rigTmp/system-ssh.asked" > "$rigTmp/bin/ssh"
chmod 755 "$rigTmp/bin/ssh"
rigSshUrl(){ ## remote name: the address of a rig remote as an ssh one, for the stand-in
	printf 'rig@standin.invalid:%s\n' "$rigTmp/$1.git"
}

rigRemote base

echo "-- the rig that never reached its remote: a store made a repository before the remote was set --"
git init -q --bare "$rigTmp/fresh.git" || rigRefuse "could not init the empty remote"
rigScenario later "$rigTmp/fresh.git"
rigInitStore master
rigRun "$rigDir/p" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the store's origin is the remote the setting names"   "$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$rigTmp/fresh.git"
rigAssert "its branch is the one the setting names, by a rename" "$( git -C "$rigStore" symbolic-ref --short HEAD 2> /dev/null )" main
rigAssert "nothing of its history was lost by it"                "$( git -C "$rigStore" log -1 --format=%s 2> /dev/null )" "local work"
rigAssert "the commit reached the remote"                        "$( git -C "$rigTmp/fresh.git" rev-parse -q --verify refs/heads/main 2> /dev/null )" "$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "one line says the origin was set"                     "$( rigCount "$rigDir/p.err" "its origin is now TEAM_DATA_GIT_REMOTE $rigTmp/fresh.git" )" 1
rigAssert "and the push that succeeded is kept"                  "$( [ -n "$( rigState TEAM_DATA_REMOTE_LAST_PUSH_UTC )" ] && printf kept || printf none )" kept
rigRun "$rigDir/p2" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "a second close says nothing: the store is in step"    "$( LC_ALL=C grep -c -e WARNING -e 'origin is now' "$rigDir/p2.err" || : )" 0

echo "-- the same through the step that sets a workspace up --"
git init -q --bare "$rigTmp/setup.git" || rigRefuse "could not init the empty remote"
rigScenario setup ""
RIG_NO_ROOT=RIG_UNSET=1 rigOp "$rigDir/a1" --owner-setup-storage --workspace-root "$rigDir/ws" --apply
rigStore="$rigDir/ws/.local/agents/team-data-root"
rigAssert "with no remote the store is initialised, nothing more" "$( [ -d "$rigStore/.git" ] && printf repo || printf none ):$( git -C "$rigStore" remote 2> /dev/null | wc -l | LC_ALL=C tr -d ' ' ):$( [ -e "$rigDir/ws/.local/agents/team-data-remote.state" ] && printf state || printf nostate )" "repo:0:nostate"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "local work" || rigRefuse "could not commit into the set-up store"
RIG_NO_ROOT=RIG_UNSET=1 rigOp "$rigDir/a2" --owner-setup-storage --workspace-root "$rigDir/ws" --team-data-git-remote "$rigTmp/setup.git" --apply
rigAssert "the remote set afterwards becomes its origin"         "$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$rigTmp/setup.git"
rigAssert "and the set-up itself reaches it: the work is there"  "$( git -C "$rigTmp/setup.git" rev-parse -q --verify refs/heads/main 2> /dev/null )" "$( git -C "$rigStore" rev-parse HEAD )"
RIG_NO_ROOT=RIG_UNSET=1 rigOp "$rigDir/a3" --owner-setup-storage --check
rigAssert "the check says the sync is well"                      "$( LC_ALL=C grep -c '^TEAM_DATA_GIT_SYNC: OK' "$rigDir/a3" || : )" 1
RIG_NO_ROOT=RIG_UNSET=1 rigOp "$rigDir/a4" --manager-dashboard-read team-data
rigAssert "the dashboard has the remote as answering, and the age of the push" "$( LC_ALL=C awk -F'\t' '$1 == "figure" && $3 == "remote" { print $5 ":" $7 } $1 == "figure" && $3 == "remote-push-age" { print ( $5 ~ /^[0-9]+$/ ) ? "age:" $6 : "no-age" }' "$rigDir/a4" | LC_ALL=C tr '\n' ' ' )" "answers:ok age:seconds "

echo "-- an empty root is cloned --"
rigScenario empty "$rigTmp/base.git"
mkdir -p "$rigStore"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "the store is a clone holding the remote's content"    "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( cat "$rigStore/README.md" 2> /dev/null )" "$( rigRemoteHead base ):seed"

echo "-- a remote with no branch yet, and no root: a repository with it as origin --"
git init -q --bare "$rigTmp/unborn.git" || rigRefuse "could not init the empty remote"
rigScenario unborn "$rigTmp/unborn.git"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "the store is a repository on the branch, with the origin" "$( git -C "$rigStore" symbolic-ref --short HEAD 2> /dev/null ):$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "main:$rigTmp/unborn.git"
mkdir -p "$rigStore/board/running" && printf 'first\n' > "$rigStore/board/running/note-20261014T0101Z-first.md"
rigRun "$rigDir/c2" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0101Z-first.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "and its first commit makes the branch at the remote"  "$( git -C "$rigTmp/unborn.git" rev-parse -q --verify refs/heads/main 2> /dev/null )" "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null )"

echo "-- a plain folder with content is made a clone in place, and loses nothing --"
rigScenario plain "$rigTmp/base.git"
mkdir -p "$rigStore/board/running" "$rigStore/inboxes/magic-tester"
printf 'local readme\n' > "$rigStore/README.md"
printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
printf 'local note\n' > "$rigStore/inboxes/magic-tester/note-rig.md"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "the folder is a clone of the remote now"              "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( git -C "$rigStore" remote get-url origin 2> /dev/null )" "$( rigRemoteHead base ):$rigTmp/base.git"
rigAssert "no file of it was changed"                            "$( cat "$rigStore/README.md" "$rigStore/board/running/note-20261014T0101Z-local.md" "$rigStore/inboxes/magic-tester/note-rig.md" 2> /dev/null | LC_ALL=C tr '\n' '/' )" "local readme/local item/local note/"
rigAssert "what the remote has and it lacked is there"           "$( cat "$rigStore/board/processed/note-20260101T0000Z-remote.md" 2> /dev/null )" "remote item"
rigAssert "its own paths stay uncommitted, the differing one too" "$( git -C "$rigStore" status --porcelain --untracked-files=all 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' '/' )" " M README.md/?? board/running/note-20261014T0101Z-local.md/?? inboxes/magic-tester/note-rig.md/"
rigAssert "one line says it, with what stays as it is"           "$( LC_ALL=C grep -c 'is now a clone of .*made in place.* 2 path(s) only this machine has and 1 path(s) that differ' "$rigDir/c.err" || : )" 1
rigAssert "nothing is left beside the store"                     "$( ls -A "$rigDir" | LC_ALL=C grep -c 'store\.' || : )" 0

echo "-- two starters at once make one clone of a plain folder --"
rigScenario twice "$rigTmp/base.git"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/a" 'AgentsToolsTeamDataEnsureClone rig' &
rigRun "$rigDir/b" 'AgentsToolsTeamDataEnsureClone rig' &
wait
rigAssert "exactly one of them made it"                          "$( cat "$rigDir/a.err" "$rigDir/b.err" | LC_ALL=C grep -c 'made in place' || : )" 1
rigAssert "and the store is one clone with its own file"         "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( cat "$rigStore/board/running/note-20261014T0101Z-local.md" )" "$( rigRemoteHead base ):local item"

echo "-- a plain folder whose remote cannot be reached is not touched --"
rigScenario unreach "$rigTmp/missing.git"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig ; AgentsToolsTeamDataEnsureClone rig'
rigAssert "it is no repository, and its file stands"             "$( [ -e "$rigStore/.git" ] && printf repo || printf plain ):$( cat "$rigStore/board/running/note-20261014T0101Z-local.md" )" "plain:local item"
rigAssert "one warning names the remote and that nothing changed" "$( LC_ALL=C grep -c "TEAM_DATA_GIT_REMOTE $rigTmp/missing.git is set and $rigStore is not a clone of it.*nothing of it was changed" "$rigDir/c.err" || : )" 1
rigAssert "and the failure is kept for the check"                "$( [ -n "$( rigState TEAM_DATA_REMOTE_LAST_FAILURE )" ] && printf kept || printf none )" kept
RIG_NO_ROOT= rigOp "$rigDir/k" --owner-setup-storage --check
rigAssert "the check warns that the store is no clone of it"     "$( LC_ALL=C grep -c '^TEAM_DATA_GIT_SYNC: WARN' "$rigDir/k" || : )" 1

echo "-- a clone whose origin is another address than the setting --"
git clone -q --bare "$rigTmp/base.git" "$rigTmp/moved.git" || rigRefuse "could not copy the remote"
rigScenario moved "$rigTmp/moved.git"
git clone -q "$rigTmp/base.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/p" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0101Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the origin is the setting's, said in one line"        "$( git -C "$rigStore" remote get-url origin ):$( rigCount "$rigDir/p.err" "its origin is now TEAM_DATA_GIT_REMOTE $rigTmp/moved.git" )" "$rigTmp/moved.git:1"
rigAssert "the commit went to it, and not to the old address"    "$( [ "$( git -C "$rigTmp/moved.git" rev-parse refs/heads/main )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf new || printf not ):$( [ "$( rigRemoteHead base )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf old || printf untouched )" "new:untouched"

echo "-- a commit is followed by a push --"
rigRemote pushed
rigScenario pushed "$rigTmp/pushed.git"
git clone -q "$rigTmp/pushed.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
rigRun "$rigDir/p" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0101Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the remote has the commit"                            "$( rigRemoteHead pushed )" "$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "the push is kept, and no failure"                     "$( [ -n "$( rigState TEAM_DATA_REMOTE_LAST_PUSH_UTC )" ] && printf kept || printf none ):$( rigState TEAM_DATA_REMOTE_LAST_FAILURE )" "kept:"

echo "-- a remote that is ahead is followed, where the store has nothing it lacks --"
rigRemoteAdvance pushed elsewhere-1.md
rigRun "$rigDir/f0" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "not within the minute of its last answer: a close does not ask it again" "$( git -C "$rigStore" rev-parse HEAD ):$( cat "$rigDir/f0" "$rigDir/f0.err" | wc -c | LC_ALL=C tr -d ' ' )" "$( git -C "$rigStore" rev-parse HEAD ):0"
## A minute later: the record of that answer is put a minute back.
LC_ALL=C sed -i.bak 's/^\(TEAM_DATA_REMOTE_LAST_ANSWER_EPOCH\)=.*/\1=1000000000/' "$rigDir/ws/.local/agents/team-data-remote.state" && rm -f "$rigDir/ws/.local/agents/team-data-remote.state.bak"
rigRun "$rigDir/f" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the store is at the remote's commit"                  "$( git -C "$rigStore" rev-parse HEAD )" "$( rigRemoteHead pushed )"
rigAssert "with the file from elsewhere, said in one line"       "$( cat "$rigStore/elsewhere-1.md" 2> /dev/null ):$( rigCount "$rigDir/f.err" "fast-forwarded" )" "from elsewhere:1"

echo "-- both sides moved from one commit: what the code did before, a merge that keeps both --"
rigRemoteAdvance pushed elsewhere-2.md
printf 'local two\n' > "$rigStore/board/running/note-20261014T0102Z-local.md"
rigRun "$rigDir/m" 'AgentsToolsTeamDataCommitPaths "rig write" "$MDAT_DATA_ROOT/board/running/note-20261014T0102Z-local.md" ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "both sides' files are in the store and on the remote" "$( cat "$rigStore/elsewhere-2.md" "$rigStore/board/running/note-20261014T0102Z-local.md" 2> /dev/null | LC_ALL=C tr '\n' '/' ):$( [ "$( rigRemoteHead pushed )" = "$( git -C "$rigStore" rev-parse HEAD )" ] && printf pushed || printf not )" "from elsewhere/local two/:pushed"

echo "-- histories with no commit in common: nothing is done, one warning names both ends --"
rigScenario apart "$rigTmp/base.git"
rigInitStore main
git -C "$rigStore" remote add origin "$rigTmp/base.git"
rigApartHead="$( git -C "$rigStore" rev-parse HEAD )"
rigBaseHead="$( rigRemoteHead base )"
rigRun "$rigDir/p" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the store's commit stands and the remote is as it was" "$( git -C "$rigStore" rev-parse HEAD ):$( git -C "$rigStore" status --porcelain | wc -l | LC_ALL=C tr -d ' ' ):$( rigRemoteHead base )" "$rigApartHead:0:$rigBaseHead"
rigAssert "one warning names both ends, and no other"            "$( LC_ALL=C grep -c "have no commit in common" "$rigDir/p.err" || : ):$( LC_ALL=C grep -c WARNING "$rigDir/p.err" || : ):$( rigHolds "$rigDir/p.err" "${rigApartHead:0:7}" )" "1:1:yes"

echo "-- a remote that never answers holds no close --"
rigRemote slow
rigScenario slow "$( rigSshUrl slow )"
git clone -q "$rigTmp/slow.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
git -C "$rigStore" remote set-url origin "$( rigSshUrl slow )"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "local work"
rigSlowHead="$( git -C "$rigStore" rev-parse HEAD )"
printf 'hang\n' > "$rigDir/ssh.mode"
rigEnv=( GIT_SSH_COMMAND="$rigTmp/bin/rig-ssh" MDAT_TEAM_DATA_REMOTE_BOUND=2 )
rigSlowFrom="$SECONDS"
rigRun "$rigDir/p" 'AgentsToolsTeamDataPushIfAhead "agent-spawn-proxy close"'
rigSlowTook=$(( SECONDS - rigSlowFrom ))
rigAssert "the close's push ends within its bound, not the remote's" "$( [ "$rigSlowTook" -lt 25 ] && printf bounded || printf "held ${rigSlowTook}s" )" bounded
rigAssert "one warning says the bound, the commit stays here"    "$( LC_ALL=C grep -c 'no answer within 2s' "$rigDir/p.err" || : ):$( LC_ALL=C grep -c WARNING "$rigDir/p.err" || : ):$( git -C "$rigStore" rev-parse HEAD )" "1:1:$rigSlowHead"
rigAssert "what the push started was stopped with it"            "$( kill -0 "$( cat "$rigDir/ssh.pid" 2> /dev/null )" 2> /dev/null && printf running || printf stopped )" stopped
rigSlowFrom="$SECONDS"
rigRun "$rigDir/p2" 'AgentsToolsTeamDataPushIfAhead "agent-spawn-proxy close"'
rigAssert "the next close does not ask a remote that just hung"  "$( [ $(( SECONDS - rigSlowFrom )) -lt 2 ] && printf at-once || printf waited ):$( LC_ALL=C grep -c 'not asked again' "$rigDir/p2.err" || : )" "at-once:1"
printf 'pass\n' > "$rigDir/ssh.mode" ; rm -f "$rigDir/ws/.local/agents/team-data-remote.state"
rigRun "$rigDir/p3" 'AgentsToolsTeamDataPushIfAhead "agent-spawn-proxy close"'
rigAssert "once the remote answers, the push carries the commit" "$( rigRemoteHead slow )" "$rigSlowHead"
rigAssert "over the ssh command this account has, in batch mode" "$( LC_ALL=C grep -c -e '-o BatchMode=yes' "$rigDir/ssh.log" | LC_ALL=C sed 's/[1-9][0-9]*/some/' )" "some"

echo "-- a remote that refuses the key: its fingerprint, and that it must be let in with write --"
rigRemote refuse
rigScenario refuse "$( rigSshUrl refuse )"
mkdir -p "$rigDir/home/.ssh" && ssh-keygen -q -t ed25519 -N '' -C rig@rig.invalid -f "$rigDir/home/.ssh/id_ed25519" > /dev/null 2>&1 || rigRefuse "could not generate the rig's own key"
rigPrint="$( ssh-keygen -l -f "$rigDir/home/.ssh/id_ed25519.pub" | LC_ALL=C awk '{ print $2 ; exit }' )"
git clone -q "$rigTmp/refuse.git" "$rigStore" 2> /dev/null || rigRefuse "could not make the clone"
git -C "$rigStore" remote set-url origin "$( rigSshUrl refuse )"
mkdir -p "$rigStore/board/running" && printf 'local item\n' > "$rigStore/board/running/note-20261014T0101Z-local.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "local work"
printf 'refuse\n' > "$rigDir/ssh.mode"
rigEnv=( GIT_SSH_COMMAND="$rigTmp/bin/rig-ssh" )
rigRun "$rigDir/p" 'AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "the warning names the key that was offered"           "$( rigHolds "$rigDir/p.err" "$rigPrint" ):$( LC_ALL=C grep -c 'must be let in at .* with write' "$rigDir/p.err" || : )" "yes:1"
rigAssert "no part of a private key is in what was said"         "$( LC_ALL=C grep -c -e 'PRIVATE KEY' -e "$( LC_ALL=C sed -n '2p' "$rigDir/home/.ssh/id_ed25519" )" "$rigDir/p" "$rigDir/p.err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" 0
rigAssert "the stand-in was handed no identity: ssh picks its own" "$( LC_ALL=C grep -c -e ' -i ' "$rigDir/ssh.log" || : )" 0
RIG_NO_ROOT= rigOp "$rigDir/k" --owner-setup-storage --check
rigAssert "the check warns, with what failed last"               "$( LC_ALL=C grep -c '^TEAM_DATA_GIT_SYNC: WARN' "$rigDir/k" || : ):$( rigHolds "$rigDir/k" "$rigPrint" )" "1:yes"
RIG_NO_ROOT= rigOp "$rigDir/d" --manager-dashboard-read team-data
rigAssert "and the dashboard has the remote as failing"          "$( LC_ALL=C awk -F'\t' '$1 == "figure" && $3 == "remote" { print $5 ":" $7 }' "$rigDir/d" )" "last_call_failed:bad"

echo "-- the ssh command the account's git has is kept, with its identity --"
rigRemote named
rigScenario named "$( rigSshUrl named )"
mkdir -p "$rigDir/home/keys" && : > "$rigDir/home/keys/rig-deploy"
printf '[core]\n\tsshCommand = %s -i %s -o UserKnownHostsFile=%s\n' "$rigTmp/bin/rig-ssh" "$rigDir/home/keys/rig-deploy" "$rigDir/home/keys/known_hosts" > "$rigDir/home/.gitconfig"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "the clone went over it, in batch mode"                "$( git -C "$rigStore" rev-parse HEAD 2> /dev/null ):$( LC_ALL=C grep -c -e "^-i $rigDir/home/keys/rig-deploy -o UserKnownHostsFile=$rigDir/home/keys/known_hosts -o BatchMode=yes" "$rigDir/ssh.log" | LC_ALL=C sed 's/[1-9][0-9]*/some/' )" "$( rigRemoteHead named ):some"

echo "-- a git host this account does not know: refused at once, and named --"
rigScenario unknown "$( rigSshUrl base )"
printf 'unknown\n' > "$rigDir/ssh.mode"
rigEnv=( GIT_SSH_COMMAND="$rigTmp/bin/rig-ssh" )
rigSlowFrom="$SECONDS"
rigRun "$rigDir/c" 'AgentsToolsTeamDataEnsureClone rig'
rigAssert "it does not wait for an answer nobody can give"       "$( [ $(( SECONDS - rigSlowFrom )) -lt 25 ] && printf at-once || printf waited )" at-once
rigAssert "one warning names the host and where it is made known" "$( LC_ALL=C grep -c "the git host standin.invalid is not known to this account.*$rigDir/home/.ssh/known_hosts" "$rigDir/c.err" || : )" 1
rigAssert "and nothing was made of the store"                    "$( [ -e "$rigStore" ] && printf made || printf none )" none

echo "-- control: with no remote set nothing of this happens --"
rigScenario none ""
rigInitStore master
rigRun "$rigDir/p" 'AgentsToolsTeamDataEnsureClone rig ; AgentsToolsTeamDataPushIfAhead "rig close"'
rigAssert "no word, no origin, no branch change, nothing kept"   "$( cat "$rigDir/p" "$rigDir/p.err" | wc -c | LC_ALL=C tr -d ' ' ):$( git -C "$rigStore" remote | wc -l | LC_ALL=C tr -d ' ' ):$( git -C "$rigStore" symbolic-ref --short HEAD ):$( [ -e "$rigDir/ws/.local/agents/team-data-remote.state" ] && printf state || printf nostate )" "0:0:master:nostate"
RIG_NO_ROOT= rigOp "$rigDir/k" --owner-setup-storage --check
rigAssert "and the check has no line of the sync"                "$( LC_ALL=C grep -c '^TEAM_DATA_GIT_SYNC' "$rigDir/k" || : )" 0
RIG_NO_ROOT= rigOp "$rigDir/d" --manager-dashboard-read team-data
rigAssert "nor the dashboard a figure of a remote"               "$( LC_ALL=C grep -c 'remote' "$rigDir/d" || : )" 0

echo "-- the ssh of the system was never started by any of it --"
rigAssert "every call to a remote went over the ssh command the account's git has" "$( [ -e "$rigTmp/system-ssh.asked" ] && wc -l < "$rigTmp/system-ssh.asked" | LC_ALL=C tr -d ' ' || printf 0 )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA REMOTE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_REMOTE: OK (%d assertions, offline, temp stores and a stand-in ssh only)\n' "$rigPassCount"
