#!/usr/bin/env bash
## Behavioural check on a cross-member inbox write: a member in any session posts an item into any
## member's inbox, whatever its own member-set view holds and wherever that member is set up.
## The inbox write is the tooling's own, into the team data of the workspace the call runs from;
## it reads no skillset of the member whose inbox it is, so a member set up in a workspace the
## caller's view does not cover is no obstacle. Held, against a scratch team data store:
##   1. an inquiry reaches a member set up only in a workspace neither the caller's view nor its
##      root covers, and it lands in the caller's own store
##   2. a note and a reflection do the same from a session whose own member is set up there alone
##   3. a member record is still owed: a name the machine holds no record of is refused, and
##      nothing is written for it
##   4. the caller's own member-set view is not a gate: the same member is unknown to it and the
##      write still lands
## Rig: ws-a is where every call runs, ws-b is the workspace whose member view a session carries as
## its root, ws-c is where the members written to are set up. Offline; no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxCrossMemberWriteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigHome="$rigTmp/home"
rigWsA="$rigTmp/ws-a"
rigWsB="$rigTmp/ws-b"
rigWsC="$rigTmp/ws-c"
rigData="$rigTmp/data"
rigViewA="$rigWsA/.local/agents/members"
rigViewB="$rigWsB/.local/agents/members"
rigViewC="$rigWsC/.local/agents/members"
rigIndex="$rigHome/.agents/magic-team/members.registry"
mkdir -p "$rigHome/.agents/magic-team" "$rigViewA/rig-here" "$rigViewB/rig-elsewhere" \
	"$rigViewC/rig-there" "$rigData/inboxes/rig-there/incoming"
printf 'rig\n' > "$rigViewA/rig-here/rig-here.basic.md"
printf 'rig\n' > "$rigViewB/rig-elsewhere/rig-elsewhere.basic.md"
printf 'rig\n' > "$rigViewC/rig-there/rig-there.basic.md"
## the machine's member index: ws-a and ws-b are workspaces the caller knows, ws-c holds the members
## every call below writes to. A row for each workspace is what tells the resolver the caller's own
## workspace is tracked at all.
printf '%s\t%s\tsource-symlink\tx\t%s\n' rig-here "$rigWsA" "$rigViewA/rig-here" > "$rigIndex"
printf '%s\t%s\tsource-symlink\tx\t%s\n' rig-elsewhere "$rigWsB" "$rigViewB/rig-elsewhere" >> "$rigIndex"
printf '%s\t%s\tsource-symlink\tx\t%s\n' rig-there "$rigWsC" "$rigViewC/rig-there" >> "$rigIndex"
printf '%s\n' "$rigWsA" "$rigWsB" "$rigWsC" > "$rigHome/.agents/magic-team/known-workspaces.registry"
printf 'rig-here\t%s\n' "$rigWsA" > "$rigHome/.agents/magic-team/member-homes.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One inbox write from the ws-a session, whose member-set root is ws-b's view: the shape keeper-ae3
## hit on a live rig. The acting member is rig-elsewhere, which ws-b's view holds and ws-c's does not.
rigOp(){ ## acting member, args... -- stdout and stderr in out, rc in rigRc
	local opActing="$1" ; shift
	rigRc=0
	( cd "$rigWsA" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" \
		MMDAPP="$rigWsA" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigViewB" MDAT_SPAWN_AGENT="$opActing" \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_WAIT_REMIND=off \
		bash "$rigFn" "$@" ) > "$rigTmp/out" 2>&1 < /dev/null || rigRc=$?
}
rigIn(){ ## item filename -- yes where it is in rig-there's incoming/, no otherwise
	[ -f "$rigData/inboxes/rig-there/incoming/$1" ] && printf yes || printf no
}
rigSaid(){ ## fixed text -- how many lines of the last call's output hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/out" 2> /dev/null || :
}

printf -- '---\ntype: inquiry\n---\n\nRIG-CROSS-ASK\n' > "$rigTmp/inq.md"
printf -- '---\ntype: note\n---\n\nRIG-OWN-NOTE\n' > "$rigTmp/note.md"
printf -- '---\ntype: reflection\n---\n\n# Reflection: rig\n\n## What happened\nrig\n\n## What this is worth\nrig\n' > "$rigTmp/refl.md"

echo "-- 1. an inquiry reaches a member set up where the session's view does not look --"
rigOp rig-elsewhere --upsert-inbox-inquiry rig-there inquiry-20261104T0900Z-rig-cross.md --from-file "$rigTmp/inq.md"
rigAssert "the call succeeds" "$rigRc" 0
rigAssert "the item is in that member's inbox" "$( rigIn inquiry-20261104T0900Z-rig-cross.md )" yes
rigAssert "and it is the caller's own store that holds it: the workspace it runs from, not the member's" \
	"$( [ -f "$rigWsC/.local/agents/team-data-root/inboxes/rig-there/incoming/inquiry-20261104T0900Z-rig-cross.md" ] && printf member-store || printf caller-store )" caller-store
rigAssert "no refusal was said" "$( rigSaid x 'cannot be brought into the workspace' )" 0
rigAssert "the write stamped the writer's workspace on it (S12.18)" "$( LC_ALL=C awk 'NR > 1 && $0 == "---" { exit } index($0, "from-workspace: ") == 1 { print substr($0, 17) }' "$rigData/inboxes/rig-there/incoming/inquiry-20261104T0900Z-rig-cross.md" )" "${rigWsA##*/}"

echo "-- 2. a note and a reflection from a session whose own member is set up there alone --"
rigOp rig-there --upsert-inbox-note note-20261104T0901Z-rig-own.md --from-file "$rigTmp/note.md"
rigAssert "the note succeeds" "$rigRc" 0
rigAssert "the note is in the writer's own inbox, in the caller's store" \
	"$( [ -f "$rigData/inboxes/rig-there/incoming/note-20261104T0901Z-rig-own.md" ] && printf yes || printf no )" yes
rigOp rig-there --upsert-inbox-reflection reflection-20261104T0902Z-rig.md --from-file "$rigTmp/refl.md"
rigAssert "the reflection succeeds" "$rigRc" 0
rigAssert "the reflection is in the writer's own inbox" \
	"$( [ -f "$rigData/inboxes/rig-there/incoming/reflection-20261104T0902Z-rig.md" ] && printf yes || printf no )" yes

echo "-- 3. a member record is still owed: a name the machine holds none of is refused --"
rigOp rig-elsewhere --upsert-inbox-inquiry rig-nobody inquiry-20261104T0903Z-rig.md --from-file "$rigTmp/inq.md"
rigAssert "an unknown member is refused" "$rigRc" 1
rigAssert "the refusal names it" "$( rigSaid x "rig-nobody" )" 1
rigAssert "and nothing is written for it" "$( ls "$rigData/inboxes" 2> /dev/null | LC_ALL=C grep -c rig-nobody || : )" 0

echo "-- 4. the caller's own member-set view is not the gate --"
rigAssert "control: the member written to is unknown to the root the session carries" \
	"$( [ -d "$rigViewB/rig-there" ] && printf known || printf unknown )" unknown
rigAssert "control: and it is unknown to the caller's own view as well" \
	"$( [ -d "$rigViewA/rig-there" ] && printf known || printf unknown )" unknown
rigAssert "the write above landed all the same" "$( rigIn inquiry-20261104T0900Z-rig-cross.md )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX CROSS-MEMBER WRITE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_CROSS_MEMBER_WRITE: OK (%d assertions, offline)\n' "$rigPassCount"
