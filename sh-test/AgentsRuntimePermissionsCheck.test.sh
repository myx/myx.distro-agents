#!/usr/bin/env bash
## Runtime permissions, run rather than read, against a rig HOME and a rig workspace under one
## mktemp tree:
##   1. a permission set entry naming a place (<tool>:@<name>:<glob>) resolves to its path; a path
##      in a place is shown as name:relative; an unknown name, a .. and a pattern glob are refused;
##      a write in a read-only place is refused at request time, naming its route;
##   2. the grant-open path: a write in a read-only place refused before anything is granted; a
##      path in a place answered and recorded with its name;
##   3. a session grant ends with its session: on read, through the session index and grant-read,
##      and dropped by the rebuild;
##   4. revoke: a marker, the next check refuses, the index drops it; again, an unknown ref, and a
##      member caller;
##   5. a task grant ends when its item closes, end to end;
##   6. the list: floor, standing, session, task and once rows with origin and expiry; revoked,
##      ended, used and closed ones left out; the member list checks its caller;
##   7. the members' read-only ops: the places by name, a path by name (.. refused), the
##      namespaces and projects by name;
##   8. revoking a task set takes its entries off the item's allows, on its Decisions, so a
##      later dispatch tracking the item does not get it;
##   9. a session pass: a keeper passes a held write, by place name and by path, to the tester
##      in its coworking session, and the tester's next check admits it; not held, a
##      non-participant receiver or passer, a read-only place and another member's name are refused; revoke
##      takes it, and it ends with the session.
## Offline: HOME, the workspace, every registry and the team data are this rig's own; a fake
## curl is first on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigHere/AgentsTools.Grants.include" "$rigHere/AgentsGrantsSessionIndex.awk" "$rigHere/AgentsTools.InternDirectory.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
rigTmp="$( mktemp -d -t AgentsRuntimePermissionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null || :
}
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\necho "rig fake curl: no request leaves this box" >&2\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

rigHome="$rigTmp/home" rigSkills="$rigTmp/skills" rigData="$rigTmp/data" rigMain="$rigTmp/ws-main"
mkdir -p "$rigHome" "$rigData/board/running" "$rigData/board/processed" "$rigTmp/ro-dir" "$rigTmp/rw-dir/sub"
for rigName in magic-coordinator magic-tester keeper-d ; do
	mkdir -p "$rigSkills/$rigName"
	printf '# %s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done
printf -- '---\nstatus: task\nowner: keeper-d\n---\n\n# Task\n' > "$rigData/board/running/task-rig.md"
for rigName in ro-dir/x.txt rw-dir/sub/a.md rw-dir/sub/b.md rw-dir/sub/c.md rw-dir/sub/o.md ; do printf 'rig-seed %s\n' "$rigName" > "$rigTmp/$rigName" ; done

## ws-main: one source project declaring two places and keeper-d's standing write in one.
mkdir -p "$rigMain/.local/agents" "$rigMain/.local/temp" "$rigMain/source/rig/rig-proj"
printf 'Name: rig\n' > "$rigMain/source/rig/repository.inf"
printf 'Name: rig-proj\n\nDeclares: \\\n\t%s \\\n\t%s \\\n\t%s \\\n\n' \
	"magic-team:directory:ro-dir:ceiling-read:$rigTmp/ro-dir:*" \
	"magic-team:directory:rw-dir:ceiling-write:$rigTmp/rw-dir:*" \
	"magic-team:permissions:directory:rw-dir:allow-write:keeper-d:*.md" > "$rigMain/source/rig/rig-proj/project.inf"
: > "$rigMain/.local/agents/members.registry"
## Spawn records: a running session of the coordinator and two of keeper-d, each with its sandbox.
rigSpawn(){ ## sandbox, session id, owner
	mkdir -p "$rigMain/.local/agents/spawned/$1/output"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' "$2" "$2" "$3" > "$rigMain/.local/agents/spawned/$1/$2.md"
}
rigSpawn sb-c s-coord magic-coordinator
rigSpawn sb-d s-d keeper-d
rigSpawn sb-k s-k keeper-d

RIG_AGENT="" RIG_SESSION=""
rigRun(){ ## op and arguments... -- the tool in ws-main as RIG_AGENT in RIG_SESSION, rig HOME, clean env; out, err, rigRc
	rigRc=0
	env -i HOME="$rigHome" PATH="$rigTmp/bin:${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} ${RIG_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_SESSION"} bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRun --intern-directory-register
[ "$rigRc" = 0 ] || rigRefuse "the places of ws-main could not be registered: $( head -3 "$rigTmp/err" )"
rigRun --make-agents-indices
[ "$rigRc" = 0 ] || rigRefuse "--make-agents-indices failed in the rig: $( LC_ALL=C grep -m3 -e ERROR -e WARNING "$rigTmp/err" )"
[ "$( rigN "$rigMain/.local/agents/grants.index" "$rigTmp/rw-dir/*.md" )" = 1 ] || rigRefuse "keeper-d's standing row is not in the grants index"

## One served call, as the MCP server makes it; output in call.out.
rigCall(){ ## member, session, tool, argument object
	( cd "$rigMain" && printf '%s' "$4" | env -i HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" \
		bash "$rigHarness" --intern-tool "$3" ) > "$rigTmp/call.out" 2> "$rigTmp/call.err"
}
rigRead(){ ## member, session, path -- read or refused
	rigCall "$1" "$2" Read "{\"path\":\"$3\"}"
	case "$( cat "$rigTmp/call.out" )" in
		*'not in the allowed access-root set'*) printf refused ;;
		*rig-seed*) printf read ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigWrite(){ ## member, session, path -- wrote, refused or ceiling
	rigCall "$1" "$2" Write "{\"file_path\":\"$3\",\"content\":\"rig-seed written\\n\"}"
	case "$( cat "$rigTmp/call.out" )" in
		OK:*) printf wrote ;;
		*'not in the allowed write-root set'*) printf refused ;;
		*'is a read-only place'*) printf ceiling ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigRefusalId(){
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1
}
rigGrant(){ ## session, refusal id, kind, [task] -- the GRANT kind, or rc:<rc>
	rigRun --intern-op-permission-grant-open human-owner --session-id "$1" --refusal-id "$2" --kind "$3" ${4:+--task "$4"}
	if [ "$rigRc" = 0 ] ; then LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/out" ; else printf 'rc:%s' "$rigRc" ; fi
}
rigGrantRead(){ ## member, session, tool, target -- the GRANT kind, or none
	rigRun --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/out" | head -1 | LC_ALL=C grep . || printf none
}
rigSessionRows(){ ## session, member, ref -- index rows naming it
	LC_ALL=C awk -F'\t' -v r="$3" '( $1 == "session" || $1 == "once" || $1 == "task" ) && ( $4 == r || $5 == r ) { n++ ; } END { print n + 0 ; }' "$rigMain/.local/agents/sessions/$1/permissions.$2.index" 2>/dev/null
}

echo "-- 1. place names in a permission set request --"
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@rw-dir:sub/**" --entry "Read:$rigTmp/rw-dir/sub/a.md" --scope task --session-id s-coord
rigAssert "an @name entry resolves to the place's path"         "$( rigN "$rigTmp/out" "PLACE: Read:$rigTmp/rw-dir/sub/** is rw-dir:sub/**" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigTmp/rw-dir/sub/**" )" "1:1"
rigAssert "an absolute path in a place shows its name:relative" "$( rigN "$rigTmp/out" "PLACE: Read:$rigTmp/rw-dir/sub/a.md is rw-dir:sub/a.md" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigTmp/rw-dir/sub/a.md" )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@ro-dir" --scope task --session-id s-coord
rigAssert "a read in a read-only place is asked for, the whole place" "$( rigN "$rigTmp/out" "PLACE: Read:$rigTmp/ro-dir/** is ro-dir:**" ):$( rigN "$rigTmp/err" 'read-only place' )" "1:0"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@rw-dir:**" --entry "Edit:@ro-dir:notes/**" --scope task --session-id s-coord
rigAssert "a write in a read-only place is refused at request time" "$rigRc:$( rigN "$rigTmp/err" "ro-dir is a read-only place, so no write is granted there: Edit:@ro-dir:notes/**" ):$( rigN "$rigTmp/out" 'PARTICIPANTS:' )" "1:1:0"
rigAssert "naming the session sandbox output/ as the route"   "$( rigN "$rigTmp/err" "write to the session sandbox output/ instead, or a folder under it: $rigMain/.local/agents/spawned/sb-c/output/" )" 1
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Write:$rigTmp/ro-dir/x.txt" --scope task --session-id s-none
rigAssert "an absolute path too; with no sandbox, another location" "$rigRc:$( rigN "$rigTmp/err" "ro-dir is a read-only place, so no write is granted there: Write:$rigTmp/ro-dir/x.txt -- find another suitable location" )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@no-such:**" --scope task --session-id s-coord
rigAssert "an unknown name is refused, said"                  "$rigRc:$( rigN "$rigTmp/err" 'unknown place: no-such' ):$( rigN "$rigTmp/out" 'PARTICIPANTS:' )" "1:1:0"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@rw-dir:../ro-dir/**" --scope task --session-id s-coord
rigAssert "a .. in the glob is refused"                        "$rigRc:$( rigN "$rigTmp/err" 'has a .. segment' )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@rw-dir:*.md" --scope task --session-id s-coord
rigAssert "a pattern glob the matcher cannot read is refused" "$rigRc:$( rigN "$rigTmp/err" 'no other pattern' )" "1:1"
RIG_AGENT="" RIG_SESSION=""

echo "-- 2. the grant-open path --"
rigRun --intern-op-permission-refusal-log keeper-d --session-id s-d --tool Write --target "$rigTmp/ro-dir/x.txt" --reason rig
rigId="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/out" | head -1 )"
[ -n "$rigId" ] || rigRefuse "no refusal could be recorded"
rigAssert "a write in a read-only place is not granted, even by the human-owner" "$( rigGrant s-d "$rigId" session ):$( cat "$rigMain/.local/agents/sessions/s-d/grants" 2>/dev/null | LC_ALL=C grep -c -F -- "$rigId" )" "rc:1:0"
rigAssert "naming its route"                                   "$( rigN "$rigTmp/err" "write to the session sandbox output/ instead, or a folder under it: $rigMain/.local/agents/spawned/sb-d/output/" )" 1
rigAssert "control: no grant, the read is refused"             "$( rigRead keeper-d s-d "$rigTmp/rw-dir/sub/a.md" )" refused
rigIdD="$( rigRefusalId )"
rigAssert "a path in a place is granted, with its name"        "$( rigGrant s-d "$rigIdD" session ):$( rigN "$rigTmp/out" 'PLACE: rw-dir:sub/a.md' )" "session:1"
rigAssert "the name is recorded with the grant"                "$( cat "$rigMain/.local/agents/sessions/s-d/$rigIdD.places" 2>/dev/null )" "$rigTmp/rw-dir/sub/a.md"$'\t'"rw-dir:sub/a.md"

echo "-- 3. a session grant ends with its session --"
## A second on, so the index built next is strictly newer than the grant and stays current.
sleep 1
rigAssert "the session grant admits while the session runs"   "$( rigRead keeper-d s-d "$rigTmp/rw-dir/sub/a.md" ):$( rigSessionRows s-d keeper-d "$rigIdD" )" "read:1"
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
LC_ALL=C sed 's/^status: spawn-started$/status: spawn-succeeded/' "$rigMain/.local/agents/spawned/sb-d/s-d.md" > "$rigTmp/rec" && cat "$rigTmp/rec" > "$rigMain/.local/agents/spawned/sb-d/s-d.md"
rigAssert "ended: refused on read, the index not rebuilt"      "$( rigRead keeper-d s-d "$rigTmp/rw-dir/sub/a.md" ):$( [ "$rigMain/.local/agents/sessions/s-d/permissions.keeper-d.index" -nt "$rigTmp/marker" ] && printf rebuilt || printf kept )" "refused:kept"
rigAssert "and by grant-read"                                  "$( rigGrantRead keeper-d s-d Read "$rigTmp/rw-dir/sub/a.md" )" none
touch "$rigMain/.local/agents/sessions/s-d/grants"
rigRead keeper-d s-d "$rigTmp/rw-dir/sub/a.md" > /dev/null
rigAssert "the rebuild drops the ended session's grant"        "$( rigSessionRows s-d keeper-d "$rigIdD" )" 0

echo "-- 4. revoke --"
rigRead keeper-d s-k "$rigTmp/rw-dir/sub/b.md" > /dev/null
rigIdR="$( rigRefusalId )"
rigAssert "a session grant admits"                             "$( rigGrant s-k "$rigIdR" session ):$( rigRead keeper-d s-k "$rigTmp/rw-dir/sub/b.md" )" "session:read"
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-revoke "$rigIdR"
rigAssert "revoked: a marker in its store"                     "$rigRc:$( cat "$rigTmp/out" ):$( [ -f "$rigMain/.local/agents/sessions/s-k/revoked/$rigIdR" ] && printf marker || printf none )" "0:REVOKED: $rigIdR:marker"
rigAssert "the next check refuses"                             "$( rigRead keeper-d s-k "$rigTmp/rw-dir/sub/b.md" ):$( rigGrantRead keeper-d s-k Read "$rigTmp/rw-dir/sub/b.md" )" "refused:none"
rigAssert "the index was rebuilt without it"                   "$( rigSessionRows s-k keeper-d "$rigIdR" )" 0
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-revoke "$rigIdR"
rigAssert "revoked again: said, no fault"                      "$rigRc:$( cat "$rigTmp/out" )" "0:REVOKED: $rigIdR already"
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-revoke refusal-no-such
rigAssert "an unknown reference is refused"                    "$rigRc:$( rigN "$rigTmp/err" 'no grant refusal-no-such is recorded' )" "1:1"
RIG_AGENT=keeper-d RIG_SESSION=s-k rigRun --magic-permission-revoke "$rigIdR"
rigAssert "a member caller is refused"                         "$rigRc:$( rigN "$rigTmp/err" "magic-coordinator's only" )" "1:1"

echo "-- 5. a task grant ends when its item closes --"
rigWrite keeper-d s-k "$rigTmp/rw-dir/sub/t.txt" > /dev/null
rigIdT="$( rigRefusalId )"
rigAssert "a task grant on an open item admits the write"      "$( rigGrant s-k "$rigIdT" task task-rig ):$( rigWrite keeper-d s-k "$rigTmp/rw-dir/sub/t.txt" )" "task:wrote"

echo "-- 6. the list --"
rigRead keeper-d s-k "$rigTmp/rw-dir/sub/c.md" > /dev/null
rigIdS="$( rigRefusalId )"
rigGrant s-k "$rigIdS" session > /dev/null
rigRead keeper-d s-k "$rigTmp/rw-dir/sub/o.md" > /dev/null
rigIdO="$( rigRefusalId )"
rigGrant s-k "$rigIdO" once > /dev/null
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-list --member keeper-d
cp "$rigTmp/out" "$rigTmp/list"
rigRow(){ ## kind, what, target -- the rest of its list row
	LC_ALL=C awk -F'\t' -v k="$1" -v w="$2" -v t="$3" '$1 == k && $2 == w && $3 == t { print $4 "|" $5 "|" $6 ; }' "$rigTmp/list"
}
rigAssert "listed"                                             "$rigRc" 0
rigAssert "the standing row: place, origin, no expiry"         "$( rigRow standing write "$rigTmp/rw-dir/*.md" )" "rw-dir:*.md|ws-main:directory|none"
rigAssert "a floor row"                                        "$( rigRow floor write "$rigMain/.local/temp/**" )" "ws-main:.local/temp/**|floor|none"
rigAssert "the session row: origin and end"                    "$( rigRow session Read "$rigTmp/rw-dir/sub/c.md" )" "rw-dir:sub/c.md|$rigIdS by human-owner|until session s-k ends"
rigAssert "the task row"                                       "$( rigRow task Write "$rigTmp/rw-dir/sub/t.txt" )" "rw-dir:sub/t.txt|$rigIdT by human-owner|while item task-rig is open"
rigAssert "the once row, lapsing"                              "$( rigRow once Read "$rigTmp/rw-dir/sub/o.md" | LC_ALL=C sed 's/lapses in [0-9]*s unless used$/lapses in Ns unless used/' )" "rw-dir:sub/o.md|$rigIdO by human-owner|lapses in Ns unless used"
rigAssert "revoked and ended grants are not listed"           "$( rigN "$rigTmp/list" "$rigIdR" ):$( rigN "$rigTmp/list" "$rigIdD" )" "0:0"
rigAssert "control: the once grant admits once"               "$( rigRead keeper-d s-k "$rigTmp/rw-dir/sub/o.md" )" read
mv "$rigData/board/running/task-rig.md" "$rigData/board/processed/task-rig.md"
rigAssert "the closed item: the write is refused"              "$( rigWrite keeper-d s-k "$rigTmp/rw-dir/sub/t.txt" ):$( rigGrantRead keeper-d s-k Write "$rigTmp/rw-dir/sub/t.txt" )" "refused:none"
RIG_AGENT=keeper-d RIG_SESSION=s-k rigRun --member-permission-list keeper-d
cp "$rigTmp/out" "$rigTmp/list"
rigAssert "the member lists its own"                           "$rigRc:$( rigRow session Read "$rigTmp/rw-dir/sub/c.md" | LC_ALL=C cut -d'|' -f3 )" "0:until session s-k ends"
rigAssert "used and closed grants are not listed"              "$( rigN "$rigTmp/list" "$rigIdO" ):$( rigN "$rigTmp/list" "$rigIdT" )" "0:0"
RIG_AGENT=magic-tester RIG_SESSION=s-coord rigRun --member-permission-list keeper-d
rigAssert "another member's list is refused"                   "$rigRc:$( rigN "$rigTmp/err" 'acts as magic-tester, so it cannot act as keeper-d' ):$( LC_ALL=C grep -c . "$rigTmp/out" )" "1:1:0"
RIG_AGENT=keeper-d RIG_SESSION=s-k rigRun --magic-permission-list --member keeper-d
rigAssert "the coordinator list is the coordinator's"         "$rigRc:$( rigN "$rigTmp/err" "magic-coordinator's only" )" "1:1"
rigRun --magic-permission-list
rigAssert "a list names its member"                           "$rigRc:$( rigN "$rigTmp/err" 'syntax is --member <member>' )" "1:1"

echo "-- 7. the members' read-only ops --"
RIG_AGENT=keeper-d RIG_SESSION=s-k
rigRun --member-directory-list
rigAssert "places by name, kind and ceiling"                   "$rigRc:$( LC_ALL=C sort "$rigTmp/out" | LC_ALL=C tr '\t\n' ' |' )" "0:ro-dir directory read-only|rw-dir directory read-write|ws-main workspace read-write|"
rigAssert "and no path"                                        "$( LC_ALL=C grep -c / "$rigTmp/out" )" 0
rigRun --member-directory-path rw-dir
rigAssert "a place's path by name"                             "$rigRc:$( cat "$rigTmp/out" )" "0:$rigTmp/rw-dir"
rigRun --member-directory-path rw-dir/sub/a.md
rigAssert "a path under it"                                    "$rigRc:$( cat "$rigTmp/out" )" "0:$rigTmp/rw-dir/sub/a.md"
rigRun --member-directory-path rw-dir/../ro-dir
rigAssert "a .. segment is refused"                            "$rigRc:$( rigN "$rigTmp/err" 'a .. segment is refused' ):$( LC_ALL=C grep -c . "$rigTmp/out" )" "1:1:0"
rigRun --member-directory-path rw-dir//etc
rigAssert "an absolute part is refused"                        "$rigRc:$( rigN "$rigTmp/err" 'relative to it' )" "1:1"
rigRun --member-directory-path no-such
rigAssert "an unknown name is refused"                         "$rigRc:$( rigN "$rigTmp/err" 'unknown place: no-such' )" "1:1"
rigRun --member-namespace-list
rigAssert "the namespaces and projects, by name"              "$rigRc:$( LC_ALL=C tr '\t\n' ' |' < "$rigTmp/out" )" "0:rig rig/rig-proj|"
rigRun --member-namespace-list rig
rigAssert "one namespace"                                      "$rigRc:$( LC_ALL=C tr '\t\n' ' |' < "$rigTmp/out" )" "0:rig rig/rig-proj|"
rigRun --member-namespace-list other
rigAssert "a namespace with no project: nothing"               "$rigRc:$( LC_ALL=C grep -c . "$rigTmp/out" )" "0:0"
rigRun --member-namespace-list ../rig
rigAssert "a namespace that is no bare name is refused"        "$rigRc" 1
RIG_AGENT="" RIG_SESSION=""

echo "-- 8. revoking a task set takes it off its item --"
rigAllowsLines(){ ## item path -- its frontmatter allows: lines
	LC_ALL=C awk 'NR == 1 && $0 == "---" { inFm = 1 ; next ; } inFm && $0 == "---" { exit ; } inFm && /^allows: / { n++ ; } END { print n + 0 ; }' "$1"
}
rigSetItem="$rigData/board/running/task-set.md"
printf -- '---\nstatus: task\nowner: keeper-d\n---\n\n# Task\n' > "$rigSetItem"
rigSpawn sb-s s-set keeper-d
mkdir -p "$rigMain/.local/agents/pending"
printf 'scope: task\nitem: task-set\nsession-id: s-set\nparticipants: keeper-d\nentry: Write:%s\n' "$rigTmp/rw-dir/sub/s.txt" > "$rigMain/.local/agents/pending/set-ask-rig.set"
rigRun --intern-op-permission-set-apply set-ask-rig human-owner
rigSetRef="$( LC_ALL=C sed -n 's/^task:Write:[^:]*:human-owner:[^:]*:\(set-[0-9a-f-]*\)$/\1/p' "$rigMain/.local/agents/sessions/s-set/grants" 2>/dev/null | head -1 )"
rigAssert "control: the set is granted and is the item's allows" "$rigRc:$( [ -n "$rigSetRef" ] && printf ref || printf none ):$( rigN "$rigSetItem" "allows: task:Write:$rigTmp/rw-dir/sub/s.txt:human-owner:" )" "0:ref:1"
printf -- '---\nstatus: dispatch-started\nowner: keeper-d\nsession-id: s-later\ntracks: task-set\n---\n\n# Dispatch\n' > "$rigData/board/running/dispatch-20261009T1200Z-later.md"
rigAssert "control: a later dispatch tracking the item gets it" "$( rigGrantRead keeper-d s-later Write "$rigTmp/rw-dir/sub/s.txt" )" planned
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-revoke "$rigSetRef"
rigAssert "revoked, and taken off the item"                    "$rigRc:$( LC_ALL=C tr '\n' '|' < "$rigTmp/out" )" "0:REVOKED: $rigSetRef|ALLOWS-REMOVED: task-set|"
rigAssert "the item carries no allows any more"                "$( rigAllowsLines "$rigSetItem" )" 0
rigAssert "the revoke is on the item's Decisions"              "$( rigN "$rigSetItem" "magic-coordinator verdict: task grant $rigSetRef revoked: Write:$rigTmp/rw-dir/sub/s.txt" )" 1
rigAssert "a later dispatch tracking the item does not get it" "$( rigGrantRead keeper-d s-later Write "$rigTmp/rw-dir/sub/s.txt" )" none
rigAssert "nor does the set's own session"                     "$( rigGrantRead keeper-d s-set Write "$rigTmp/rw-dir/sub/s.txt" )" none

echo "-- 9. a session pass: a keeper passes what it holds to a participant, for the session only --"
## Coworking session s-cw: keeper-d started it (its standing write holds rw-dir/*.md), magic-tester joined it.
rigSpawn sb-cw s-cw keeper-d
mkdir -p "$rigMain/.local/agents/spawned/sb-cwt/output"
printf -- '---\nsession-id: s-cw\nspawn-id: s-cw-t\nowner: magic-tester\nstatus: spawn-started\n---\n\n# Spawn session\n' > "$rigMain/.local/agents/spawned/sb-cwt/s-cw-t.md"
for rigName in rw-dir/p.md rw-dir/q.md ; do printf 'rig-seed %s\n' "$rigName" > "$rigTmp/$rigName" ; done
rigAssert "control: the tester does not write there unpassed"  "$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/p.md" )" refused
RIG_AGENT=keeper-d RIG_SESSION=s-cw
rigPassRef(){ ## -- the pass reference GRANT: session printed, or empty
	LC_ALL=C sed -n 's/^GRANT: session \(pass-[0-9a-f-]*\)$/\1/p' "$rigTmp/out" | head -1
}
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "@rw-dir:p.md" --kind session
rigPassP="$( rigPassRef )"
rigAssert "passed by place name, said with its name:relative"  "$rigRc:$( [ -n "$rigPassP" ] && printf ref || printf none ):$( rigN "$rigTmp/out" "PLACE: Write:$rigTmp/rw-dir/p.md is rw-dir:p.md" )" "0:ref:1"
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "$rigTmp/rw-dir/q.md" --kind session
rigPassQ="$( rigPassRef )"
rigAssert "and by path, its own, with the same hint"           "$rigRc:$( [ -n "$rigPassQ" ] && [ "$rigPassQ" != "$rigPassP" ] && printf ref || printf none ):$( rigN "$rigTmp/out" "PLACE: Write:$rigTmp/rw-dir/q.md is rw-dir:q.md" )" "0:ref:1"
rigAssert "a session grant signed by the passer, in its store" "$( LC_ALL=C grep -c -E "^session:Write:[^:]*:keeper-d:[0-9TZ]*:$rigPassP\$" "$rigMain/.local/agents/sessions/s-cw/grants" ):$( rigN "$rigMain/.local/agents/sessions/s-cw/$rigPassP.md" 'owner: magic-tester' ):$( rigN "$rigMain/.local/agents/sessions/s-cw/$rigPassP.md" 'passed-by: keeper-d' ):$( cat "$rigMain/.local/agents/sessions/s-cw/$rigPassP.places" 2>/dev/null )" "1:1:1:$rigTmp/rw-dir/p.md"$'\t'"rw-dir:p.md"
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "@rw-dir:sub/**" --kind session
rigAssert "what it does not hold is refused"                   "$rigRc:$( rigN "$rigTmp/err" 'keeper-d does not hold Write' ):$( LC_ALL=C grep -c '^GRANT:' "$rigTmp/out" )" "1:1:0"
rigRun --member-permission-pass keeper-d --to magic-coordinator --tool Write --target "@rw-dir:p.md" --kind session
rigAssert "a member outside the session is refused"            "$rigRc:$( rigN "$rigTmp/err" 'magic-coordinator takes no part in session s-cw' )" "1:1"
## Session s-solo: magic-tester alone. keeper-d holds the write, the tester takes part, keeper-d does not.
rigSpawn sb-solo s-solo magic-tester
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "@rw-dir:p.md" --kind session --session-id s-solo
rigAssert "a session pass by a passer outside that session is refused" "$rigRc:$( rigN "$rigTmp/err" 'keeper-d takes no part in session s-solo, so it cannot pass a permission for it' ):$( LC_ALL=C grep -c '^GRANT:' "$rigTmp/out" ):$( [ -e "$rigMain/.local/agents/sessions/s-solo/grants" ] && printf written || printf none )" "1:1:0:none"
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "@ro-dir:x.txt" --kind session
rigAssert "a write in a read-only place is refused, its route named" "$rigRc:$( rigN "$rigTmp/err" "ro-dir is a read-only place, so no write is granted there: Write:@ro-dir:x.txt -- write to the session sandbox output/ instead, or a folder under it: $rigMain/.local/agents/spawned/sb-cw/output/" )" "1:1"
RIG_AGENT=magic-tester RIG_SESSION=s-cw-t
rigRun --member-permission-pass keeper-d --to magic-tester --tool Write --target "@rw-dir:p.md" --kind session
rigAssert "a member cannot pass as another"                    "$rigRc:$( rigN "$rigTmp/err" 'acts as magic-tester, so it cannot act as keeper-d' )" "1:1"
RIG_AGENT="" RIG_SESSION=""
rigAssert "the refused passes wrote nothing"                   "$( LC_ALL=C grep -c . "$rigMain/.local/agents/sessions/s-cw/grants" )" 2
rigAssert "the tester's next check admits both"                "$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/p.md" ):$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/q.md" )" "wrote:wrote"
RIG_AGENT=magic-tester RIG_SESSION=s-cw-t rigRun --member-permission-list magic-tester --session-id s-cw-t
cp "$rigTmp/out" "$rigTmp/list"
rigAssert "listed with the passer as origin, until the session ends" "$( rigRow session Write "$rigTmp/rw-dir/p.md" )" "rw-dir:p.md|$rigPassP by keeper-d|until session s-cw ends"
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord rigRun --magic-permission-revoke "$rigPassP"
rigAssert "revoke takes it"                                    "$rigRc:$( cat "$rigTmp/out" )" "0:REVOKED: $rigPassP"
rigAssert "the next check refuses it, the other still writes"  "$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/p.md" ):$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/q.md" )" "refused:wrote"
LC_ALL=C sed 's/^status: spawn-started$/status: spawn-succeeded/' "$rigMain/.local/agents/spawned/sb-cw/s-cw.md" > "$rigTmp/rec" && cat "$rigTmp/rec" > "$rigMain/.local/agents/spawned/sb-cw/s-cw.md"
rigAssert "it ends with the session"                           "$( rigWrite magic-tester s-cw-t "$rigTmp/rw-dir/q.md" ):$( rigGrantRead magic-tester s-cw-t Write "$rigTmp/rw-dir/q.md" )" "refused:none"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ RUNTIME PERMISSIONS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'RUNTIME_PERMISSIONS: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
