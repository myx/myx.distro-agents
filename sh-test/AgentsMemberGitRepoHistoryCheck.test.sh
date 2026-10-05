#!/usr/bin/env bash
## Behavioural check on the read-only repository history operation, run rather than read, against repositories built
## here with fixed author and committer dates (test code may run git; members may not). Holds: a path inside the
## workspace and an absolute path inside a readable access root are read; a path outside the roots, a symlink that
## leaves them and a directory that is not a repository are refused with exit 1 and skipped, while the other paths still
## print; the history of a deleted file; --since and --until as whole days, --until inclusive of 23:59; --limit and its
## truncation line, 1000 the most; a malformed date, injected shell text and a bad limit refused with nothing run or
## created; one `## <path>` block per path; the line shape; the repository byte-unchanged; the help pair. Each refusal
## has an accepted sibling. Offline, a rig tree only: every call goes through one `env -i` whose child refuses to start
## unless MMDAPP sits under this rig's mktemp tree. The operation's name is spelled once, in rigOpName, because the
## name awaits the owner's approval.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHelpInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.include"
rigHelpManual="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.help.md"
rigOpName="--member-git-repo-history"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
command -v git > /dev/null 2>&1 || rigRefuse "no git on this machine, so no rig repository can be built"
rigTmp="$( mktemp -d -t AgentsMemberGitRepoHistoryCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwx "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigWs="$rigTmp/ws" ; rigRoot1="$rigTmp/root1" ; rigRoot2="$rigTmp/root2" ; rigOutside="$rigTmp/outside" ; rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigRoot1" "$rigRoot2" "$rigOutside" "$rigHome/.claude/skills"
## The access roots come through the same config key the access-root function reads: CLIENT_ACCESS_ROOTS_EXTRA, colon separated.
printf 'CLIENT_ACCESS_ROOTS_EXTRA=%s:%s\n' "$rigRoot1" "$rigRoot2" > "$rigWs/.local/.agents/magic-team.agent.env"

rigGit(){ ## repository, author date, subject, then the git commit arguments... -- one commit with both dates fixed
	local gitRepo="$1" gitDate="$2" gitSubject="$3" ; shift 3
	( cd "$gitRepo" && GIT_AUTHOR_DATE="$gitDate" GIT_COMMITTER_DATE="$gitDate" GIT_AUTHOR_NAME="Rig Author" GIT_AUTHOR_EMAIL="rig@example.invalid" \
		GIT_COMMITTER_NAME="Rig Author" GIT_COMMITTER_EMAIL="rig@example.invalid" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
		git -c commit.gpgsign=false commit -q -m "$gitSubject" "$@" )
}
rigInit(){ ## repository
	( cd "$1" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q . )
}
rigAdd(){ ## repository, path...
	local addRepo="$1" ; shift
	( cd "$addRepo" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git add -A -- "$@" )
}
rigLongSubject="$( LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 300 ; i++ ) printf "%s", substr("abcdefghij", ( i % 10 ) + 1, 1) }' )"

## The workspace repository: four commits, one file deleted, one subject far over 200.
rigInit "$rigWs"
printf '*\n!*.txt\n!.gitignore\n' > "$rigWs/.gitignore"
printf 'one\n' > "$rigWs/a.txt" ; rigAdd "$rigWs" a.txt .gitignore ; rigGit "$rigWs" "2026-03-01T10:00:00 +0000" "first commit"
printf 'two\n' > "$rigWs/a.txt" ; printf 'doomed\n' > "$rigWs/gone.txt" ; rigAdd "$rigWs" a.txt gone.txt ; rigGit "$rigWs" "2026-03-05T23:59:00 +0000" "second commit"
printf 'three\n' > "$rigWs/a.txt" ; rm -f "$rigWs/gone.txt" ; rigAdd "$rigWs" a.txt gone.txt ; rigGit "$rigWs" "2026-03-10T09:00:00 +0300" "third commit"
printf 'long\n' > "$rigWs/long.txt" ; rigAdd "$rigWs" long.txt ; rigGit "$rigWs" "2026-03-11T12:00:00 +0000" "$rigLongSubject"
## A readable root holding one repository, a readable root holding none, and a repository no root names.
rigInit "$rigRoot1" ; printf 'r\n' > "$rigRoot1/r.txt" ; rigAdd "$rigRoot1" r.txt ; rigGit "$rigRoot1" "2026-03-02T08:00:00 +0000" "root commit"
printf 'plain\n' > "$rigRoot2/plain.txt"
rigInit "$rigOutside" ; printf 'o\n' > "$rigOutside/o.txt" ; rigAdd "$rigOutside" o.txt ; rigGit "$rigOutside" "2026-03-03T08:00:00 +0000" "outside commit"
ln -s "$rigOutside" "$rigWs/link-out" ; ln -s "$rigRoot1" "$rigWs/link-root"

rigC1="$( cd "$rigWs" && git log --format='%H%x09%s' | LC_ALL=C awk -F'\t' '$2 == "first commit" { print $1 }' )"
rigAssert "control: the rig workspace repository has the 3 commits that touch a.txt" "$( cd "$rigWs" && git log --format=%s -- a.txt | LC_ALL=C tr '\n' '|' )" "third commit|second commit|first commit|"
rigAssert "control: the root repository has its one commit"               "$( cd "$rigRoot1" && git log --format=%s | LC_ALL=C tr '\n' '|' )" "root commit|"

rigRun(){ ## result prefix, arguments of the operation... -- one call from the workspace; <prefix>.out .err .rc
	local runOut="$1" ; shift
	case "$rigWs" in "$rigTmp"/*) ;; *) rigRefuse "the workspace is outside this rig's own tree: $rigWs" ;; esac
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" TZ=UTC GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" "$rigOpName" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	printf '%s' "$?" > "$runOut.rc"
}
rigRc(){ ## prefix
	cat "$1.rc"
}
rigBlocks(){ ## prefix -- the number of `## ` block headings on stdout
	LC_ALL=C grep -c '^## ' "$1.out" || :
}
rigCommits(){ ## prefix -- the number of commit lines on stdout: lines with exactly three tabs
	LC_ALL=C awk -F'\t' 'NF == 4 { n++ } END { print n + 0 }' "$1.out"
}
rigOther(){ ## prefix -- stdout lines that are neither a heading, a commit line nor blank: the truncation line
	LC_ALL=C awk -F'\t' '$0 !~ /^## / && NF != 4 && $0 != "" { n++ } END { print n + 0 }' "$1.out"
}
rigSubjects(){ ## prefix -- the subject field of every commit line, joined
	LC_ALL=C awk -F'\t' 'NF == 4 { printf "%s|", $4 }' "$1.out"
}
rigErrLines(){ ## prefix -- stderr lines that are not the tool's own context start-up noise
	LC_ALL=C grep -v -e '^SystemContext' -e '^AgentsContext' -e '⛔ ERROR: SystemContext' "$1.err" 2> /dev/null | LC_ALL=C awk 'END { print NR }'
}
rigOpErrors(){ ## prefix -- the operation's own error lines
	LC_ALL=C grep -c "⛔ ERROR: DistroAgentsTools $rigOpName" "$1.err" || :
}
rigStderrHas(){ ## prefix, fixed text
	LC_ALL=C grep -c -F -- "$2" "$1.err" || :
}
rigTreeSum(){ ## repository -- one checksum over every file of its .git tree, names included
	( cd "$1/.git" && find . -type f | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}
rigNoLock(){ ## repository
	[ ! -e "$1/.git/index.lock" ] && printf none || printf present
}

echo "-- 1. a path inside the workspace --"
rigRun "$rigTmp/r1" a.txt
rigAssert "relative path: exit 0, one block headed by the path made absolute, 3 commit lines" "$( rigRc "$rigTmp/r1" ) $( rigBlocks "$rigTmp/r1" ) $( LC_ALL=C grep -c -x "## $rigWs/a.txt" "$rigTmp/r1.out" || : ) $( rigCommits "$rigTmp/r1" )" "0 1 1 3"
rigAssert "newest first"                                         "$( rigSubjects "$rigTmp/r1" )" "third commit|second commit|first commit|"
rigRun "$rigTmp/r1b" "$rigWs/a.txt"
rigAssert "the same file by its absolute path: exit 0, one block headed by that path, 3 commit lines" "$( rigRc "$rigTmp/r1b" ) $( rigBlocks "$rigTmp/r1b" ) $( LC_ALL=C grep -c -x "## $rigWs/a.txt" "$rigTmp/r1b.out" || : ) $( rigCommits "$rigTmp/r1b" )" "0 1 1 3"
rigRun "$rigTmp/r1c" a.txt
rigAssert "nothing is printed on stderr for an accepted path"    "$( rigErrLines "$rigTmp/r1c" )" 0

echo "-- 2. an absolute path inside a readable access root --"
rigRun "$rigTmp/r2" "$rigRoot1/r.txt"
rigAssert "inside the configured root: exit 0, one block, its one commit" "$( rigRc "$rigTmp/r2" ) $( rigBlocks "$rigTmp/r2" ) $( rigSubjects "$rigTmp/r2" )" "0 1 root commit|"

echo "-- 3. a path outside the roots --"
rigRun "$rigTmp/r3" "$rigOutside/o.txt"
rigAssert "outside every root: exit 1"                           "$( rigRc "$rigTmp/r3" )" 1
rigAssert "it is refused with an error naming CLIENT_ACCESS_ROOTS_EXTRA" "$( rigOpErrors "$rigTmp/r3" ) $( rigStderrHas "$rigTmp/r3" 'CLIENT_ACCESS_ROOTS_EXTRA' )" "1 1"
rigAssert "it is skipped: no block and no commit line on stdout" "$( rigBlocks "$rigTmp/r3" ) $( rigCommits "$rigTmp/r3" )" "0 0"
rigAssert "sibling: the same repository's history is read once its root is named" \
	"$( printf 'CLIENT_ACCESS_ROOTS_EXTRA=%s:%s:%s\n' "$rigRoot1" "$rigRoot2" "$rigOutside" > "$rigWs/.local/.agents/magic-team.agent.env" ; rigRun "$rigTmp/r3b" "$rigOutside/o.txt" ; printf '%s %s %s' "$( rigRc "$rigTmp/r3b" )" "$( rigBlocks "$rigTmp/r3b" )" "$( rigSubjects "$rigTmp/r3b" )" )" "0 1 outside commit|"
printf 'CLIENT_ACCESS_ROOTS_EXTRA=%s:%s\n' "$rigRoot1" "$rigRoot2" > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- 4. the history of a deleted file --"
rigRun "$rigTmp/r4" gone.txt
rigAssert "a file that no longer exists: exit 0 and its add and its delete"  "$( rigRc "$rigTmp/r4" ) $( rigSubjects "$rigTmp/r4" )" "0 third commit|second commit|"
rigRun "$rigTmp/r4b" never-existed.txt
rigAssert "control: a name that never existed in the repository prints a block with no commit line, exit 0" "$( rigRc "$rigTmp/r4b" ) $( rigBlocks "$rigTmp/r4b" ) $( rigCommits "$rigTmp/r4b" )" "0 1 0"

echo "-- 5. --since and --until, whole days, until inclusive --"
rigRun "$rigTmp/r5a" --until 2026-03-05 a.txt
rigAssert "--until 2026-03-05 includes the commit at 23:59 that day"       "$( rigSubjects "$rigTmp/r5a" )" "second commit|first commit|"
rigRun "$rigTmp/r5b" --until 2026-03-04 a.txt
rigAssert "control: --until the day before leaves that commit out"          "$( rigSubjects "$rigTmp/r5b" )" "first commit|"
rigRun "$rigTmp/r5c" --since 2026-03-05 a.txt
rigAssert "--since 2026-03-05 includes that day and after"                  "$( rigSubjects "$rigTmp/r5c" )" "third commit|second commit|"
rigRun "$rigTmp/r5d" --since 2026-03-06 a.txt
rigAssert "control: --since the day after leaves it out"                    "$( rigSubjects "$rigTmp/r5d" )" "third commit|"
rigRun "$rigTmp/r5e" --since 2026-03-05 --until 2026-03-05 a.txt
rigAssert "both on the same day: that day's commit alone"                   "$( rigSubjects "$rigTmp/r5e" )" "second commit|"
rigAssert "all exit 0"                                                      "$( rigRc "$rigTmp/r5a" )$( rigRc "$rigTmp/r5b" )$( rigRc "$rigTmp/r5c" )$( rigRc "$rigTmp/r5d" )$( rigRc "$rigTmp/r5e" )" 00000

echo "-- 6. --limit and the truncation line --"
rigRun "$rigTmp/r6a" --limit 2 a.txt
rigAssert "--limit 2 over 3 commits prints 2, the newest, and one truncation line on stdout" "$( rigCommits "$rigTmp/r6a" ) $( rigOther "$rigTmp/r6a" ) $( rigSubjects "$rigTmp/r6a" )" "2 1 third commit|second commit|"
rigRun "$rigTmp/r6b" --limit 3 a.txt
rigAssert "control: --limit 3 over 3 commits prints 3 and no truncation line" "$( rigCommits "$rigTmp/r6b" ) $( rigOther "$rigTmp/r6b" )" "3 0"
rigRun "$rigTmp/r6c" a.txt
rigAssert "control: no --limit prints all 3 and no truncation line"          "$( rigCommits "$rigTmp/r6c" ) $( rigOther "$rigTmp/r6c" )" "3 0"
rigRun "$rigTmp/r6d" --limit 1001 a.txt
rigAssert "--limit above 1000 is refused, with an error, nothing printed"    "$( [ "$( rigRc "$rigTmp/r6d" )" -ne 0 ] && printf refused || printf accepted ) $( rigOpErrors "$rigTmp/r6d" ) $( rigCommits "$rigTmp/r6d" )" "refused 1 0"
rigRun "$rigTmp/r6e" --limit 1000 a.txt
rigAssert "sibling: --limit 1000 is accepted"                               "$( rigRc "$rigTmp/r6e" ) $( rigCommits "$rigTmp/r6e" )" "0 3"
rigRun "$rigTmp/r6f" --limit abc a.txt
rigAssert "a --limit that is not a number is refused"                       "$( [ "$( rigRc "$rigTmp/r6f" )" -ne 0 ] && printf refused || printf accepted ) $( rigCommits "$rigTmp/r6f" )" "refused 0"
rigRun "$rigTmp/r6g" --limit 0 a.txt
rigAssert "a --limit of 0 is refused"                                       "$( [ "$( rigRc "$rigTmp/r6g" )" -ne 0 ] && printf refused || printf accepted ) $( rigCommits "$rigTmp/r6g" )" "refused 0"

echo "-- 7. a malformed date or injected text is refused and nothing is run --"
rigRun "$rigTmp/r7a" --since "x; touch $rigTmp/rig-injected" a.txt
rigAssert "--since with shell text: refused, an error, nothing printed"      "$( [ "$( rigRc "$rigTmp/r7a" )" -ne 0 ] && printf refused || printf accepted ) $( rigOpErrors "$rigTmp/r7a" ) $( rigCommits "$rigTmp/r7a" )" "refused 1 0"
rigAssert "and nothing was created"                                         "$( [ -e "$rigTmp/rig-injected" ] || [ -e "$rigWs/rig-injected" ] && printf created || printf none )" none
rigRun "$rigTmp/r7b" --until '$(touch '"$rigTmp"'/rig-injected2)' a.txt
rigAssert "--until with a command substitution: refused and nothing created" "$( [ "$( rigRc "$rigTmp/r7b" )" -ne 0 ] && printf refused || printf accepted ) $( [ -e "$rigTmp/rig-injected2" ] && printf created || printf none )" "refused none"
rigRun "$rigTmp/r7c" --since 2026-13-45 a.txt
rigAssert "an impossible date is refused"                                   "$( [ "$( rigRc "$rigTmp/r7c" )" -ne 0 ] && printf refused || printf accepted ) $( rigCommits "$rigTmp/r7c" )" "refused 0"
rigRun "$rigTmp/r7f" --until 2026-02-29 a.txt
rigAssert "February 29 in a year that is not a leap year is refused"        "$( [ "$( rigRc "$rigTmp/r7f" )" -ne 0 ] && printf refused || printf accepted ) $( rigCommits "$rigTmp/r7f" )" "refused 0"
rigRun "$rigTmp/r7g" --until 2024-02-29 a.txt
rigAssert "sibling: February 29 in a leap year is accepted"                 "$( rigRc "$rigTmp/r7g" )" 0
rigRun "$rigTmp/r7h" --since 2026-04-31 a.txt
rigAssert "April 31 is refused"                                             "$( [ "$( rigRc "$rigTmp/r7h" )" -ne 0 ] && printf refused || printf accepted )" refused
rigRun "$rigTmp/r7i" --since 2026-09-08 --until 2026-12-31 a.txt
rigAssert "sibling: 08 and 09 are read as decimal, 12-31 is accepted"       "$( rigRc "$rigTmp/r7i" )" 0
rigRun "$rigTmp/r7d" --since 20260301 a.txt
rigAssert "a date not written YYYY-MM-DD is refused"                        "$( [ "$( rigRc "$rigTmp/r7d" )" -ne 0 ] && printf refused || printf accepted )" refused
rigRun "$rigTmp/r7e" --since 2026-03-01 a.txt
rigAssert "sibling: a valid date is accepted"                               "$( rigRc "$rigTmp/r7e" ) $( rigCommits "$rigTmp/r7e" )" "0 3"

echo "-- 8. a directory that is not a repository --"
rigRun "$rigTmp/r8" "$rigRoot2/plain.txt"
rigAssert "inside a root but in no repository: exit 1, an error, skipped"    "$( rigRc "$rigTmp/r8" ) $( rigOpErrors "$rigTmp/r8" ) $( rigBlocks "$rigTmp/r8" ) $( rigCommits "$rigTmp/r8" )" "1 1 0 0"
rigAssert "sibling: a path inside a repository in a root is accepted"        "$( rigRc "$rigTmp/r2" )" 0

echo "-- 9. a symlink in the workspace --"
rigRun "$rigTmp/r9a" link-out
rigAssert "a symlink pointing outside the roots: exit 1, an error, skipped" "$( rigRc "$rigTmp/r9a" ) $( rigOpErrors "$rigTmp/r9a" ) $( rigBlocks "$rigTmp/r9a" ) $( rigCommits "$rigTmp/r9a" )" "1 1 0 0"
rigRun "$rigTmp/r9c" link-out/o.txt
rigAssert "and so is a path through it, never read from the repository it leads to" "$( rigBlocks "$rigTmp/r9c" ) $( rigCommits "$rigTmp/r9c" ) $( rigSubjects "$rigTmp/r9c" )" "0 0 "
rigAssert "sibling: that repository named by its real path is outside the roots too, refused with the hint, so the refusal is the symlink's own" "$( rigRc "$rigTmp/r3" ) $( rigStderrHas "$rigTmp/r3" 'CLIENT_ACCESS_ROOTS_EXTRA' )" "1 1"
rigRun "$rigTmp/r9b" "$rigRoot1/r.txt"
rigAssert "sibling: a real path inside a configured root is accepted"        "$( rigRc "$rigTmp/r9b" ) $( rigBlocks "$rigTmp/r9b" ) $( rigSubjects "$rigTmp/r9b" )" "0 1 root commit|"
rigRun "$rigTmp/r9d" link-root
rigAssert "pinned current behaviour: a symlink is refused whatever it points at, so one into a configured root is refused too" "$( rigRc "$rigTmp/r9d" ) $( rigBlocks "$rigTmp/r9d" ) $( rigStderrHas "$rigTmp/r9d" 'symbolic link' )" "1 0 1"

echo "-- 10. two paths, two repositories --"
rigRun "$rigTmp/r10a" a.txt "$rigRoot1/r.txt"
rigAssert "two repositories give two blocks, each headed by its path, exit 0" "$( rigRc "$rigTmp/r10a" ) $( rigBlocks "$rigTmp/r10a" ) $( LC_ALL=C grep -c -x -e "## $rigWs/a.txt" -e "## $rigRoot1/r.txt" "$rigTmp/r10a.out" || : ) $( rigCommits "$rigTmp/r10a" )" "0 2 2 4"
rigRun "$rigTmp/r10b" a.txt "$rigOutside/o.txt"
rigAssert "one skipped path gives exit 1 while the other still prints"       "$( rigRc "$rigTmp/r10b" ) $( rigBlocks "$rigTmp/r10b" ) $( rigCommits "$rigTmp/r10b" ) $( rigStderrHas "$rigTmp/r10b" 'CLIENT_ACCESS_ROOTS_EXTRA' )" "1 1 3 1"
rigRun "$rigTmp/r10c" "$rigOutside/o.txt" a.txt
rigAssert "and the order of the paths does not matter"                       "$( rigRc "$rigTmp/r10c" ) $( rigBlocks "$rigTmp/r10c" ) $( rigCommits "$rigTmp/r10c" )" "1 1 3"

echo "-- 11. the shape of a commit line --"
rigRun "$rigTmp/r11" a.txt
rigAssert "four tab separated fields: date, author, hash, subject"         "$( LC_ALL=C awk -F'\t' 'NF == 4 { n++ } END { print n + 0 }' "$rigTmp/r11.out" )" 3
rigAssert "the date is YYYY-MM-DD HH:MM +ZZZZ on every line"               "$( LC_ALL=C awk -F'\t' 'NF == 4 && $1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] [+-][0-9][0-9][0-9][0-9]$/ { n++ } END { print n + 0 }' "$rigTmp/r11.out" )" 3
rigAssert "the oldest commit's date, exactly"                              "$( LC_ALL=C awk -F'\t' 'NF == 4 && $4 == "first commit" { print $1 }' "$rigTmp/r11.out" )" "2026-03-01 10:00 +0000"
rigAssert "the author is the commit's author"                              "$( LC_ALL=C awk -F'\t' 'NF == 4 && $2 != "Rig Author" { n++ } END { print n + 0 }' "$rigTmp/r11.out" )" 0
rigAssert "the hash field is the start of the real commit hash"            "$( LC_ALL=C awk -F'\t' -v full="$rigC1" 'NF == 4 && $4 == "first commit" && length($3) >= 7 && substr(full, 1, length($3)) == $3 { n++ } END { print n + 0 }' "$rigTmp/r11.out" )" 1
rigRun "$rigTmp/r11b" long.txt
rigAssert "a subject over 200 characters is cut: a prefix of it, at most 200" "$( LC_ALL=C awk -F'\t' -v full="$rigLongSubject" 'NF == 4 { print ( length($4) <= 200 && length($4) >= 197 && substr(full, 1, length($4)) == $4 ) ? "cut" : "wrong:" length($4) }' "$rigTmp/r11b.out" )" cut
rigAssert "control: a short subject is not touched"                        "$( LC_ALL=C awk -F'\t' 'NF == 4 && $4 == "first commit" { n++ } END { print n + 0 }' "$rigTmp/r11.out" )" 1

echo "-- 12. the repository is byte-unchanged --"
rigBefore="$( rigTreeSum "$rigWs" ) $( rigTreeSum "$rigRoot1" )"
rigRun "$rigTmp/r12a" a.txt gone.txt long.txt "$rigRoot1/r.txt"
rigRun "$rigTmp/r12b" --limit 1 --since 2026-03-01 --until 2026-03-31 a.txt
rigRun "$rigTmp/r12c" "$rigOutside/o.txt" a.txt
rigAssert "control: those calls did run and print"                         "$( rigBlocks "$rigTmp/r12a" ) $( rigBlocks "$rigTmp/r12c" )" "4 1"
rigAssert "the .git trees of the workspace and the root are identical before and after" "$( rigTreeSum "$rigWs" ) $( rigTreeSum "$rigRoot1" )" "$rigBefore"
rigAssert "no index.lock was left in either"                               "$( rigNoLock "$rigWs" ) $( rigNoLock "$rigRoot1" )" "none none"
printf 'x\n' >> "$rigWs/.git/description"
rigAssert "control: the tree checksum does notice a one byte change"        "$( [ "$( rigTreeSum "$rigWs" ) $( rigTreeSum "$rigRoot1" )" = "$rigBefore" ] && printf blind || printf notices )" notices

echo "-- 13. the help pair --"
rigAssert "the syntax echo is in the help include, once"                   "$( LC_ALL=C grep -c "^echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOpName" "$rigHelpInclude" || : )" 1
rigAssert "the syntax line is in the manual's list, once"                  "$( LC_ALL=C grep -c "^📘 syntax: DistroAgentsTools.fn.sh $rigOpName" "$rigHelpManual" || : )" 1
rigAssert "the manual has the entry itself, once"                          "$( LC_ALL=C grep -c -E "^[[:space:]]+$rigOpName( |\$)" "$rigHelpManual" || : )" 1
rigAssert "control: the same three readers on --member-vault-item-read give 1 1 1" "$( LC_ALL=C grep -c "^echo \"📘 syntax: DistroAgentsTools.fn.sh --member-vault-item-read" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c "^📘 syntax: DistroAgentsTools.fn.sh --member-vault-item-read" "$rigHelpManual" || : ) $( LC_ALL=C grep -c -E "^[[:space:]]+--member-vault-item-read( |\$)" "$rigHelpManual" || : )" "1 1 1"
rigRun "$rigTmp/r13"
rigAssert "called with no path it refuses, exit non-zero, and says the syntax" "$( [ "$( rigRc "$rigTmp/r13" )" -ne 0 ] && printf refused || printf accepted ) $( LC_ALL=C grep -c -F -- "$rigOpName" "$rigTmp/r13.err" || : )" "refused 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER GIT REPO HISTORY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_GIT_REPO_HISTORY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
