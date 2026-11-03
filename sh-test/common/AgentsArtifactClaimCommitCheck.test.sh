#!/usr/bin/env bash
## Behavioural check on the artifact claim's commit: a number is secured where it is verified
## (AgentsTools.InternArtifact.include, AgentsToolsArtifactClaim). The claim writes its record,
## commits it, and reads the last commit back to compare the subject. A commit queued to the
## team-data thread answers before its commit exists, so a read-back made at once sees the commit
## before the claim's, the subject differs, and every claim refuses: no number is ever secured and
## no publish can follow. Held here, over a real git store cloned from a bare origin this rig makes:
##   1. THE INSTRUMENT. A fake `git` first on PATH logs every add and commit with the calling
##      process's own words. A commit of the rig's own is seen there, with the process that made it,
##      so a reading of who made the claim's commit is a measurement and not a blind instrument.
##   2. WHERE IT IS VERIFIED IT IS COMMITTED. The claim returns 0 and hands out ADR-001, and the
##      commit it read back is its own: the record's commit is made in the claim's own process, and
##      no add or commit of it is made by the team-data thread. This is the discriminating half: a
##      tree that queues the commit makes no commit in the caller at all.
##   3. THE RECORD SURVIVES, and the next claim takes the next number on the same store, so the
##      read-back is not reading a commit some earlier call left.
## Fault 1 of session 4fbfce66, measured by magic-coordinator at 2026-11-03 16:53Z and 16:54Z.
## Offline: the store, its bare origin, the fake `git`, the skills folder and the record are this
## rig's own; no socket is opened, and no live team data is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
[ -f "$rigPkg/sh-lib/common/AgentsTools.InternArtifact.include" ] || rigRefuse "the artifact include is missing from the package"
[ -f "$rigPkg/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ] || rigRefuse "the team-data commit include is missing from the package"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsArtifactClaimCommitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRealGit="$( command -v git )"
rigThreadLock=""
trap 'rigClaimThreadEnd ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigBin="$rigTmp/bin" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigBin" "$rigHome" "$rigSkills/magic-tester" || rigRefuse "could not create the rig"
printf 'rig\n' > "$rigSkills/magic-tester/magic-tester.basic.md"
printf 'rig\n' > "$rigSkills/magic-tester/magic-tester.armed.md"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid

## THE FAKE GIT: every add and commit logged with the calling process's own words, then passed to the real
## one. A commit the claim makes has the caller of the tooling as its parent; one the team-data thread makes
## has that thread, whose own words name --intern-team-data-commit. Nothing else of git is read here.
rigGitLog="$rigTmp/git.log"
: > "$rigGitLog"
cat > "$rigBin/git" <<'RIGSTUB'
#!/bin/sh
rigWrites=0
for rigArg in "$@" ; do
	case "$rigArg" in add|commit) rigWrites=1 ;; esac
done
[ "$rigWrites" = 1 ] || exec "$RIG_REAL_GIT" "$@"
printf '%s\t%s\t%s\n' "$PPID" "$( LC_ALL=C ps -o args= -p "$PPID" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "$*" >> "$RIG_GIT_LOG"
## A commit of this rig's own that touches no path: the team-data thread's commits, which take no lock
## against a claim and may land between the claim's commit and its read-back.
rigForeign=0
case "${RIG_GIT_FOREIGN:-0}:$*" in 1:*commit*intern-artifact-publish*) rigForeign=1 ;; esac
if [ "$rigForeign" = 0 ] ; then
	exec "$RIG_REAL_GIT" "$@"
fi
"$RIG_REAL_GIT" "$@" || exit $?
"$RIG_REAL_GIT" -C "$RIG_GIT_STORE" commit -q --allow-empty -m "rig-foreign commit by another writer" || exit $?
exit 0
RIGSTUB
chmod +x "$rigBin/git"

rigOriginRepo="$rigTmp/origin.git"
"$rigRealGit" init -q --bare "$rigOriginRepo" && "$rigRealGit" -C "$rigOriginRepo" symbolic-ref HEAD refs/heads/main \
	|| rigRefuse "could not make the rig origin"
"$rigRealGit" clone -q "$rigOriginRepo" "$rigTmp/seed" 2> /dev/null && printf 'rig team data\n' > "$rigTmp/seed/README.md" \
	&& "$rigRealGit" -C "$rigTmp/seed" add -A && "$rigRealGit" -C "$rigTmp/seed" commit -q -m seed \
	&& "$rigRealGit" -C "$rigTmp/seed" push -q origin HEAD:main || rigRefuse "could not seed the rig origin"
"$rigRealGit" clone -q "$rigOriginRepo" "$rigData" || rigRefuse "could not clone the rig origin as the store"
mkdir -p "$rigData/audit"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\nTEAM_DATA_GIT_REMOTE=%s\n' "$rigOriginRepo" \
	> "$rigWs/.local/.agents/magic-team.agent.env"
rigThreadLock="$rigData/.git/team-data-commit/thread.lock"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigThreadEndMarked(){ [ -f "$rigThreadLock" ] && printf held || printf given ; }
## The store's thread ends by itself once no entry comes for the idle seconds the rig gives it, and the
## lock it leaves behind is signalled only while it is still the process that took it.
rigClaimThreadEnd(){
	[ -n "$rigThreadLock" ] || return 0
	[ -f "$rigThreadLock" ] || return 0
	rigProcSignalKept TERM "$rigThreadLock" > /dev/null 2>&1 || :
	return 0
}

## The claim, reached the way in-context code reaches it: the tooling's own shell, in this rig's environment.
## The body comes on stdin, so the words a case runs are the case's own. The thread is left ON -- the rig sets
## no off switch -- because that is the state the defect lives in, and its idle time is short so it ends by itself.
rigClaim(){ ## result name -- stdin: the shell body
	local claimName="$1"
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDSC_CMD=DistroAgentsTools MDAT_SPAWN_AGENT=magic-tester MDAT_SKILLSET_ROOT="$rigSkills" \
			RIG_GIT_LOG="$rigGitLog" RIG_REAL_GIT="$rigRealGit" RIG_GIT_STORE="$rigData" RIG_GIT_FOREIGN="${rigGitForeign:-0}" \
			MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS=2 \
			MYXROOT="${MYXROOT:-}" \
			bash "$rigFn" --intern-mcp-execute
	) > "$rigTmp/$claimName.out" 2> "$rigTmp/$claimName.err"
	printf '%s' "$?" > "$rigTmp/$claimName.rc"
}
rigClaimBody(){
	printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.LocalLock.include" > /dev/null 2>&1'
	printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include" > /dev/null 2>&1'
	printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternArtifact.include" > /dev/null 2>&1'
	printf '%s\n' 'artCmd=rig-claim ; artMember=magic-tester ; artCode=ADR ; artTitle="Rig decision" ; artSession=rig-session'
	printf '%s\n' 'AgentsToolsArtifactClaim ; printf "CLAIM_RC=%s\nCLAIM_NUMBER=%s\n" "$?" "$artNumber"'
	printf '%s\n' 'printf "LAST_COMMIT=%s\n" "$( git -C "$MDAT_DATA_ROOT" log -1 --format=%s 2> /dev/null )"'
}
rigLastSubject(){ "$rigRealGit" -C "$rigData" log -1 --format=%s 2> /dev/null ; }
## The newest commit that touched the claim's own record: the read the fix makes, and the one a check of it
## must make too. HEAD is not that read, so a check built on HEAD cannot see the defect it would guard.
rigRecordSubject(){ "$rigRealGit" -C "$rigData" log -1 --format=%s -- "audit" 2> /dev/null ; }
## Add and commit calls whose calling process's own words hold the fixed text given.
rigCallsBy(){ LC_ALL=C awk -F'\t' -v want="$1" 'index( $2, want ) > 0 { n++ } END { print n + 0 }' "$rigGitLog" 2> /dev/null || printf '0' ; }
rigAnyCalls(){ LC_ALL=C wc -l < "$rigGitLog" 2> /dev/null | LC_ALL=C tr -d ' ' || printf '0' ; }
## The state the claim left its record in, read off the record's own frontmatter; `none` when no record is there.
rigRecordState(){
	local recordFile="" recordCount
	recordCount="$( ls "$rigData/audit"/artifact-*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
	[ "$recordCount" = 1 ] || { printf '%s records' "$recordCount" ; return 0 ; }
	recordFile="$( ls "$rigData/audit"/artifact-*.md 2> /dev/null )"
	LC_ALL=C awk '$0 == "---" { if ( ++fence > 1 ) exit ; next } fence == 1 && index( $0, "state: " ) == 1 { print substr( $0, 8 ) ; exit }' "$recordFile" 2> /dev/null
}

echo "-- 1. the instrument: a commit of the rig's own is seen, with the process that made it --"
( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" \
	RIG_GIT_LOG="$rigGitLog" RIG_REAL_GIT="$rigRealGit" \
	bash -c 'printf "probe\n" > "$MDAT_DATA_ROOT/audit/probe.md" ; git -C "$MDAT_DATA_ROOT" add -A > /dev/null && git -C "$MDAT_DATA_ROOT" commit -q -m "rig known positive"' ) > /dev/null 2>&1
rigAssert "the known positive: the log holds the add and the commit, and names the process that made them" \
	"$( rigAnyCalls ):$( rigCallsBy 'rig known positive' )" "2:2"
rigAssert "and the store's last subject is that commit"                        "$( rigLastSubject )" "rig known positive"

echo "-- 2. where the number is verified, the claim's commit is made in the claim's own process --"
: > "$rigGitLog"
rigClaimBody | rigClaim first
rigAssert "the claim returned 0"                                              "$( cat "$rigTmp/first.rc" )" 0
rigAssert "and handed out the first number"                                   "$( LC_ALL=C sed -n 's/^CLAIM_NUMBER=//p' "$rigTmp/first.out" )" "ADR-001"
rigAssert "the commit it read back is its own claim, not an earlier one"       "$( rigLastSubject | LC_ALL=C sed 's/, rig-session [0-9]*$//' )" "* intern-artifact-publish: ADR-001 claimed by magic-tester"
rigAssert "the claim made an add and a commit in its own process"             "$( rigCallsBy '--intern-mcp-execute' )" "2"
rigAssert "and the team-data thread made none of them"                        "$( rigCallsBy '--intern-team-data-commit' )" "0"
rigAssert "so the number was secured before anything was published"           "$( LC_ALL=C grep -c -F 'could not be committed to the team data' "$rigTmp/first.err" )" "0"

echo "-- 3. the record survives, and the next claim takes the next number --"
rigAssert "the reservation it wrote is still on disk, as reserved"            "$( rigRecordState )" "reserved"
: > "$rigGitLog"
rigClaimBody | rigClaim second
rigAssert "the second claim returned 0, on the next number"                   "$( cat "$rigTmp/second.rc" ):$( LC_ALL=C sed -n 's/^CLAIM_NUMBER=//p' "$rigTmp/second.out" )" "0:ADR-002"
rigAssert "and its own commit is what the read-back found"                     "$( rigLastSubject | LC_ALL=C sed 's/, rig-session [0-9]*$//' )" "* intern-artifact-publish: ADR-002 claimed by magic-tester"
rigAssert "no commit of either claim was made by the team-data thread"        "$( rigCallsBy '--intern-team-data-commit' )" "0"

echo "-- 4. another writer's commit between the claim's commit and its read-back --"
## The thread's commits take no lock against a claim, so one lands inside that window and HEAD is no longer
## the claim. The number is secured all the same, and its record survives: the read is of the claim's own path.
rigGitForeign=1
: > "$rigGitLog"
rigClaimBody | rigClaim third
rigGitForeign=0
rigAssert "the claim returned 0 behind another writer's commit"               "$( cat "$rigTmp/third.rc" )" 0
rigAssert "and handed out the next number"                                    "$( LC_ALL=C sed -n 's/^CLAIM_NUMBER=//p' "$rigTmp/third.out" )" "ADR-003"
rigAssert "and did not report the number unsecured"                           "$( LC_ALL=C grep -c -F 'could not be committed to the team data' "$rigTmp/third.err" )" "0"
rigAssert "the claim's own record is the newest commit touching it"            "$( rigRecordSubject | LC_ALL=C sed 's/, rig-session [0-9]*$//' )" "* intern-artifact-publish: ADR-003 claimed by magic-tester"
rigAssert "and its record is still on disk"                                   "$( ls "$rigData/audit"/artifact-*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "3"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ARTIFACT CLAIM COMMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ARTIFACT_CLAIM_COMMIT: OK (%d assertions, offline)\n' "$rigPassCount"
