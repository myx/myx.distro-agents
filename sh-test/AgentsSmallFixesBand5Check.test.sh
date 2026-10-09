#!/usr/bin/env bash
## Band 5 group B small fixes, each by behaviour against temp stores only:
## 5691 item names (a warning quoting the naming Rule, and the dispatch receipt read from
## both name forms), 1383 --untrash, 4421 one-path owner-workspace ops, 267 a same-folder
## member install is a note, 5687 the announce cap, 5689 the announce icons. Every call
## goes through one `env -i` whose child refuses to run outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"
rigBundle="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -d "$rigBundle/magic-tester" ] || rigRefuse "the bundled skillset has no magic-tester folder: $rigBundle"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsSmallFixesBand5Check )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
## One team op, guarded, against a named data root; rc into <result>.rc.
rigOp(){ ## result file, data root, op and arguments...
	local opOut="$1" opData="$2" ; shift 2
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$opData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}

echo "-- 5691: item names --"
rigData="$rigTmp/data"
mkdir -p "$rigData/board/pending"
rigCreate(){ ## result file, item name
	printf -- '---\ntype: task\n---\n' | rigOp "$1" "$rigData" --intern-op-board-upsert-move-edit pending "$2" --create --upsert-from-stdin --context rig
}
rigCreate "$rigTmp/n1" task-2026-09-29-foo.md
rigAssert "a bad name is still created, rc 0"          "$( cat "$rigTmp/n1.rc" ):$( [ -f "$rigData/board/pending/task-2026-09-29-foo.md" ] && printf created || printf absent )" "0:created"
rigAssert "with a warning quoting the naming Rule"     "$( rigHolds "$rigTmp/n1" "WARNING: --create: task-2026-09-29-foo.md does not follow the naming Rule" )" yes
rigCreate "$rigTmp/n2" task-20260929T0930Z-good.md
rigAssert "a good name gives no warning"               "$( rigHolds "$rigTmp/n2" 'does not follow the naming Rule' )" no
rigCreate "$rigTmp/n3" dispatch-20260929T093012Z-spawn-proxy-15463.md
rigAssert "the proxy's seconds form gives no warning"  "$( rigHolds "$rigTmp/n3" 'does not follow the naming Rule' )" no

## The dispatch receipt, read from each name form: TaskOutput finds the audit log by it.
mkdir -p "$rigData/audit/2026-09"
printf -- '---\nstatus: dispatch-succeeded\n---\n' > "$rigData/board/pending/dispatch-20260929T015541-spawn-proxy-15463.md"
printf 'rig old-form log\n' > "$rigData/audit/2026-09/spawn-proxy-20260929T015541-15463.output.log"
printf -- '---\nstatus: dispatch-succeeded\n---\n' > "$rigData/board/pending/dispatch-20260929T015542Z-spawn-proxy-15464.md"
printf 'rig new-form log\n' > "$rigData/audit/2026-09/spawn-proxy-20260929T015542Z-15464.output.log"
rigTaskOutput(){ ## result file, handle
	printf '{"handle":"%s"}' "$2" | env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		bash -c '
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool TaskOutput --access-read-root "$RIG_TMP"
		' > "$1" 2>/dev/null
}
rigTaskOutput "$rigTmp/r1" dispatch-20260929T015541-spawn-proxy-15463.md
rigAssert "an old-form receipt finds its log"          "$( rigHolds "$rigTmp/r1" 'rig old-form log' )" yes
rigTaskOutput "$rigTmp/r2" dispatch-20260929T015542Z-spawn-proxy-15464.md
rigAssert "a new-form receipt finds its log"           "$( rigHolds "$rigTmp/r2" 'rig new-form log' )" yes

echo "-- 1383: --untrash --"
rigPlain="$rigTmp/plain"
mkdir -p "$rigPlain/trash" "$rigPlain/board/pending"
printf 'rig trashed\n' > "$rigPlain/trash/task-20260929T0931Z-t.md"
rigOp "$rigTmp/u1" "$rigPlain" --intern-op-board-trash magic-coordinator pending task-20260929T0931Z-t.md --untrash
rigAssert "a non-git store restores the item"          "$( cat "$rigTmp/u1.rc" ):$( cat "$rigPlain/board/pending/task-20260929T0931Z-t.md" 2>/dev/null )" "0:rig trashed"
rigAssert "and trash/ no longer holds it"              "$( [ -e "$rigPlain/trash/task-20260929T0931Z-t.md" ] && printf still || printf gone )" gone
printf 'rig second\n' > "$rigPlain/trash/task-20260929T0931Z-t.md"
rigOp "$rigTmp/u2" "$rigPlain" --intern-op-board-trash magic-coordinator pending task-20260929T0931Z-t.md --untrash
rigAssert "a name clash is refused"                    "$( cat "$rigTmp/u2.rc" ):$( rigHolds "$rigTmp/u2" 'the board already holds that name, refusing to overwrite it' )" "1:yes"
rigAssert "and the board copy is untouched"            "$( cat "$rigPlain/board/pending/task-20260929T0931Z-t.md" )" "rig trashed"
rigGitStore="$rigTmp/gitstore"
mkdir -p "$rigGitStore/board/pending" "$rigGitStore/trash"
git -C "$rigGitStore" init -q || rigRefuse "could not init the temp git store"
printf 'rig\n' > "$rigGitStore/trash/task-20260929T0932Z-g.md"
rigOp "$rigTmp/u3" "$rigGitStore" --intern-op-board-trash magic-coordinator pending task-20260929T0932Z-g.md --untrash
rigAssert "a git store refuses, non-zero"              "$( [ "$( cat "$rigTmp/u3.rc" )" != 0 ] && printf non-zero || printf zero )" non-zero
rigAssert "saying where trashed items live"            "$( rigHolds "$rigTmp/u3" 'a git store keeps trashed items only in its history; no tooling op restores from it; ask the coordinator' )" yes
rigAssert "and changes nothing"                        "$( [ -e "$rigGitStore/board/pending/task-20260929T0932Z-g.md" ] && printf changed || printf unchanged )" unchanged

echo "-- 4421: one path only --"
rigOp "$rigTmp/w1" "$rigData" --owner-workspace-upsert "$rigTmp/a" "$rigTmp/b"
rigAssert "upsert with two paths is refused"           "$( cat "$rigTmp/w1.rc" ):$( rigHolds "$rigTmp/w1" 'takes exactly one <path>, and more followed it' )" "1:yes"
rigOp "$rigTmp/w2" "$rigData" --owner-workspace-forget rig-a rig-b
rigAssert "forget with two names is refused"           "$( cat "$rigTmp/w2.rc" ):$( rigHolds "$rigTmp/w2" 'takes exactly one <name>, and more followed it' )" "1:yes"
rigAssert "and nothing was written under HOME"         "$( find "$rigTmp/home" -type f | LC_ALL=C grep -c . || : )" 0

echo "-- 267: a member bundled and declared from the same folder --"
rigInstall(){ ## result file, declared source folder
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDSC_SKILLSET_PRESCAN=1 MDSC_SKILLSET_MEMBERNAMES="magic-tester" MDSC_SKILLSET_MEMBERSOURCES="magic-tester $2" \
		MDSC_SKILLSET_DISCOVERY_TRUSTED=1 RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			rm -rf "$RIG_TMP/skills-target" ; mkdir -p "$RIG_TMP/skills-target"
			cd "$MMDAPP" && exec bash "$RIG_FN" --install-skillset-symlinks --scope user-home --target-root "$RIG_TMP/skills-target"
		' > "$1" 2>&1
}
rigInstall "$rigTmp/i1" "$rigBundle/magic-tester"
rigAssert "same folder: a note, one member"            "$( rigHolds "$rigTmp/i1" 'magic-tester is bundled and declared from the same folder -- one member, not a collision' )" yes
rigAssert "and no collision warning"                   "$( rigHolds "$rigTmp/i1" 'NAME COLLISION on team-member magic-tester' )" no
mkdir -p "$rigTmp/elsewhere/magic-tester"
rigInstall "$rigTmp/i2" "$rigTmp/elsewhere/magic-tester"
rigAssert "control: another folder is a collision warning" "$( rigHolds "$rigTmp/i2" 'NAME COLLISION on team-member magic-tester' )" yes

echo "-- 5687 and 5689: the announce line --"
rigLong="$rigTmp/ws/$( printf 'very-long-directory-name-segment-%02d/' 1 2 3 4 5 | tr -d '\n' )"
mkdir -p "$rigLong"
: > "$rigLong/target-file-name.txt"
rigAnnounce(){ ## tool, arguments JSON -- prints the tool's announce line, colour removed
	printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig \
		RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		bash -c 'cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool "$1" --access-read-root "$MMDAPP"' rig "$1" 2>&1 > /dev/null \
		| LC_ALL=C sed 's/\x1b\[[0-9;]*m//g' | LC_ALL=C grep -m1 -F " $1 "
}
rigReadLine="$( rigAnnounce Read "{\"path\":\"$rigLong/target-file-name.txt\"}" )"
rigReadDetail="$( printf '%s' "$rigReadLine" | LC_ALL=C sed 's/^.*Read *//' )"
rigAssert "a long path is cut to 110 bytes"            "$( printf '%s' "$rigReadDetail" | LC_ALL=C awk '{ print length($0) ; }' )" 110
rigAssert "keeping its end, which names the file"      "$( case "$rigReadDetail" in (*target-file-name.txt) printf yes ;; (*) printf no ;; esac )" yes
rigAssert "Glob announces with 📁"                     "$( case "$( rigAnnounce Glob '{"pattern":"*.txt"}' )" in (*'📁 Glob'*) printf yes ;; (*) printf no ;; esac )" yes
rigAssert "SendMessage announces with ✉️"              "$( case "$( rigAnnounce SendMessage '{"to":"magic-team","message":"rig"}' )" in (*'✉️ SendMessage'*) printf yes ;; (*) printf no ;; esac )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SMALL FIXES BAND 5 CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SMALL_FIXES_BAND5: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
