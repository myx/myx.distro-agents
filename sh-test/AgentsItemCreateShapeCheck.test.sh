#!/usr/bin/env bash
## Behavioural check on the mechanical steps the tooling now does itself, against temp
## stores only: a created item's name (kept as given, a name off the Rule's shape still
## created with the Rule's warning, board and inbox alike) and its creation
## headers (type/from/date on a board create, type/from/date/owner on a new inbox item,
## never over a given value, never on an update); --member-inbox-to-processed (own inbox
## only, marked in place); the heartbeat state write refreshing a held lock; the heartbeat scan's board
## counts; and the sweep's per-message author:/addressees: lines. Every call goes through
## one `env -i` whose child refuses to run outside this rig's mktemp tree; no Slack, no mail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsItemCreateShapeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/rig-other" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/board/pending" "$rigData/board/backlog"

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
## The value of one frontmatter field, bounded to the first --- block.
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigFieldCount(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { n++ ; } END { print n + 0 ; }' "$1"
}
## One team op, guarded, against the rig's own stores; rc into <result>.rc. RIG_AGENT, when
## set, becomes MDAT_SPAWN_AGENT -- the spawned session's own member.
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}

echo "-- board create: names --"
rigB1=approval-20261006T0930Z-rig-matter.md
printf 'body one\n' | rigOp "$rigTmp/b1" --magic-board-create-running rig-member "$rigB1" --upsert-from-stdin
rigAssert "a well-formed name is created as given, rc 0"    "$( cat "$rigTmp/b1.rc" ):$( [ -f "$rigData/board/running/$rigB1" ] && echo yes || echo no ):$( rigHolds "$rigTmp/b1" 'naming Rule' )" "0:yes:no"
rigAssert "type from the prefix"                            "$( rigField "$rigData/board/running/$rigB1" type )" approval
rigAssert "from the creating member"                        "$( rigField "$rigData/board/running/$rigB1" from )" rig-member
rigAssert "date in the team date-time form"                 "$( rigField "$rigData/board/running/$rigB1" date | LC_ALL=C grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}$' )" 1
rigAssert "started-at is still stamped"                     "$( rigFieldCount "$rigData/board/running/$rigB1" started-at )" 1
rigAssert "the body is kept below the new frontmatter"      "$( rigHolds "$rigData/board/running/$rigB1" 'body one' )" yes

printf -- '---\ntype: task\nfrom: someone-else\n---\nbody two\n' | rigOp "$rigTmp/b2" --magic-board-create-running rig-member approval-20261006T0930Z-full.md --upsert-from-stdin --header:upsert:date:2001-01-01\ 00:00\ +0000
rigAssert "created"                                         "$( cat "$rigTmp/b2.rc" ):$( [ -f "$rigData/board/running/approval-20261006T0930Z-full.md" ] && echo created )" "0:created"
rigAssert "a given type is never overwritten"               "$( rigField "$rigData/board/running/approval-20261006T0930Z-full.md" type )" task
rigAssert "a given from is never overwritten"               "$( rigField "$rigData/board/running/approval-20261006T0930Z-full.md" from )" someone-else
rigAssert "a --header: date wins over the default"          "$( rigField "$rigData/board/running/approval-20261006T0930Z-full.md" date )" "2001-01-01 00:00 +0000"
rigAssert "each field once"                                 "$( rigFieldCount "$rigData/board/running/approval-20261006T0930Z-full.md" type )$( rigFieldCount "$rigData/board/running/approval-20261006T0930Z-full.md" from )$( rigFieldCount "$rigData/board/running/approval-20261006T0930Z-full.md" date )" 111

printf -- '---\n---\nbody three\n' | rigOp "$rigTmp/b3" --intern-op-board-upsert-move-edit pending task-2026-09-29-legacy.md --create --upsert-from-stdin --context rig
rigAssert "another shape is still created, rc 0"            "$( cat "$rigTmp/b3.rc" ):$( [ -f "$rigData/board/pending/task-2026-09-29-legacy.md" ] && echo created )" "0:created"
rigAssert "with the warning quoting the naming Rule"        "$( rigHolds "$rigTmp/b3" 'WARNING: --create: task-2026-09-29-legacy.md does not follow the naming Rule' )" yes
rigAssert "no from without an acting member"                "$( rigFieldCount "$rigData/board/pending/task-2026-09-29-legacy.md" from )" 0

printf -- '---\nopen\n' | rigOp "$rigTmp/b4" --intern-op-board-upsert-move-edit pending task-20261006T0930Z-open.md --create --upsert-from-stdin --context rig
rigAssert "an unclosed frontmatter is written as before"    "$( cat "$rigTmp/b4.rc" ):$( cat "$rigData/board/pending/task-20261006T0930Z-open.md" 2>/dev/null | tr '\n' '|' )" "0:---|open|"

rigB5=task-20261006T0930Z-rig-groomed.md
printf 'grooming body\n' | rigOp "$rigTmp/b5" --magic-grooming-create-backlog rig-member "$rigB5" --owner-header-value rig-other --upsert-from-stdin
rigAssert "a grooming create gets the headers too"                 "$( cat "$rigTmp/b5.rc" ):$( rigField "$rigData/board/backlog/$rigB5" type ):$( rigField "$rigData/board/backlog/$rigB5" from ):$( rigField "$rigData/board/backlog/$rigB5" owner )" "0:task:rig-member:rig-other"

echo "-- inbox: names and headers --"
rigI1=inquiry-20261006T0930Z-rig-question.md
printf 'Please look.\n' | RIG_AGENT=rig-other rigOp "$rigTmp/i1" --member-upsert-member-inquiry rig-member "$rigI1"
rigI1Path="$rigData/inboxes/rig-member/$rigI1"
rigAssert "a new inquiry is written as named, rc 0"         "$( cat "$rigTmp/i1.rc" ):$( [ -f "$rigI1Path" ] && echo written ):$( rigHolds "$rigTmp/i1" 'naming Rule' )" "0:written:no"
rigAssert "type, from (the spawned member), owner"          "$( rigField "$rigI1Path" type ):$( rigField "$rigI1Path" from ):$( rigField "$rigI1Path" owner )" "inquiry:rig-other:rig-member"
rigAssert "and a date"                                      "$( rigFieldCount "$rigI1Path" date )" 1
rigAssert "the content follows"                             "$( rigHolds "$rigI1Path" 'Please look.' )" yes

printf -- '---\nowner: magic-coordinator\n---\nnote text\n' | RIG_AGENT=rig-other rigOp "$rigTmp/i2" --member-inbox-note-upsert rig-member note-20261006T0930Z-given.md --from-member magic-coordinator
rigI2Path="$rigData/inboxes/rig-member/note-20261006T0930Z-given.md"
rigAssert "--from-member wins over the session's member"   "$( cat "$rigTmp/i2.rc" ):$( rigField "$rigI2Path" from )" "0:magic-coordinator"
rigAssert "a given owner is never overwritten"              "$( rigField "$rigI2Path" owner ):$( rigFieldCount "$rigI2Path" owner )" "magic-coordinator:1"

printf -- '---\ntype: note\n---\nrewritten\n' | rigOp "$rigTmp/i3" --member-inbox-note-upsert rig-member note-20261006T0930Z-given.md
rigAssert "an update is not stamped"                        "$( cat "$rigTmp/i3.rc" ):$( rigFieldCount "$rigI2Path" from ):$( rigFieldCount "$rigI2Path" date ):$( rigFieldCount "$rigI2Path" owner )" "0:0:0:0"

printf 'legacy\n' | rigOp "$rigTmp/i4" --member-inbox-note-upsert rig-member 2026-07-22-note-legacy.md
rigAssert "an old-shape name is still written, warned"     "$( cat "$rigTmp/i4.rc" ):$( [ -f "$rigData/inboxes/rig-member/2026-07-22-note-legacy.md" ] && echo written ):$( rigHolds "$rigTmp/i4" 'does not follow the naming Rule' )" "0:written:yes"

printf 'misfiled\n' | rigOp "$rigTmp/i5" --member-inbox-note-upsert rig-member warning-20261006T0930Z-rig-misfiled.md
rigAssert "a board type in an inbox is written, warned"    "$( cat "$rigTmp/i5.rc" ):$( rigHolds "$rigTmp/i5" 'is not an inbox type' )" "0:yes"

echo "-- --member-inbox-to-processed --"
rigOp "$rigTmp/p1" --member-inbox-to-processed rig-member "$rigI1"
rigAssert "the member's own item is marked in place"        "$( cat "$rigTmp/p1.rc" ):$( [ -f "$rigI1Path" ] && echo still || echo gone ):$( [ -e "$rigData/inboxes/rig-member/processed" ] && echo folder || echo nofolder )" "0:still:nofolder"
rigAssert "with processed-at stamped"                       "$( rigFieldCount "$rigI1Path" processed-at )" 1
RIG_AGENT=rig-other rigOp "$rigTmp/p2" --member-inbox-to-processed rig-member note-20261006T0930Z-given.md
rigAssert "another member's session is refused"             "$( cat "$rigTmp/p2.rc" ):$( [ -f "$rigI2Path" ] && echo kept ):$( rigFieldCount "$rigI2Path" processed-at )" "1:kept:0"
RIG_AGENT=rig-member rigOp "$rigTmp/p3" --member-inbox-to-processed rig-member note-20261006T0930Z-given.md
rigAssert "its own session is not"                          "$( cat "$rigTmp/p3.rc" ):$( rigFieldCount "$rigI2Path" processed-at )" "0:1"
rigOp "$rigTmp/p4" --librarian-inbox-to-processed rig-member 2026-07-22-note-legacy.md
rigAssert "the librarian op still works"                    "$( cat "$rigTmp/p4.rc" ):$( rigFieldCount "$rigData/inboxes/rig-member/2026-07-22-note-legacy.md" processed-at )" "0:1"

echo "-- heartbeat: state write refreshes a held lock; board counts --"
rigLock="$rigData/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md"
mkdir -p "${rigLock%/*}"
printf -- '---\ntype: note\nstate: heartbeat-running\nrecheck-date: 2001-01-01 00:00 +0000\nsession-id: rig-session\n---\n\nold state\n' > "$rigLock"
printf -- '---\nlast-iteration-date: 2026-10-06\n---\n\nnew state\n' | rigOp "$rigTmp/h1" --magic-heartbeat-state-upsert magic-coordinator
rigAssert "the state write succeeds"                        "$( cat "$rigTmp/h1.rc" ):$( rigHolds "$rigLock" 'new state' )" "0:yes"
rigAssert "recheck-date is moved forward, once"             "$( rigFieldCount "$rigLock" recheck-date ):$( [ "$( rigField "$rigLock" recheck-date )" \> "$( date -u +%Y-%m-%d )" ] && echo future || rigField "$rigLock" recheck-date )" "1:future"
rigAssert "the caller's own fields are written"             "$( rigField "$rigLock" last-iteration-date )" 2026-10-06
printf -- '---\ntype: note\nstate: heartbeat-finished\nrecheck-date: 2001-01-01 00:00 +0000\nsession-id: rig-session\n---\n\nold state\n' > "$rigLock"
printf -- 'closed state\n' | rigOp "$rigTmp/h2" --magic-heartbeat-state-upsert magic-coordinator
rigAssert "a finished note's recheck-date is untouched"    "$( cat "$rigTmp/h2.rc" ):$( rigField "$rigLock" recheck-date )" "0:2001-01-01 00:00 +0000"
rigOp "$rigTmp/h3" --magic-heartbeat-input-scan magic-coordinator
rigAssert "the scan has a board counts section"             "$( LC_ALL=C grep -c -x '## board counts' "$rigTmp/h3" )" 1
rigAssert "counting each state's items"                     "$( LC_ALL=C grep -x -E '(running|pending|backlog|review): [0-9]+' "$rigTmp/h3" | tr '\n' ' ' )" "backlog: 1 pending: 2 running: 2 review: 0 "

echo "-- sweep item blocks: author and addressees --"
printf '%s\n' '{"ok":true,"messages":[{"ts":"1.000001","user":"U1","text":":m: *_magic-coordinator_* @Magic → :k: *_rig-member_* <@U9>; <@U7>.\nbody. more"},{"ts":"1.000002","bot_id":"B1","text":"*_magic-team_* @Team → @here.\nbody"},{"ts":"1.000003","user":"U2","text":"hey <@U5> look"},{"ts":"1.000004","user":"U3","text":"<!channel> all"},{"ts":"1.000005","user":"U3","text":"plain"}]}' \
	| COMMS_USER_HANDLES=$'U5\talice' LC_ALL=C awk -v kind=slack -v source=magic-team -v channel=CRIG -f "$rigLib/AgentsSessionContextCommsItems.awk" > "$rigTmp/s1"
rigLines(){ LC_ALL=C grep -E '^(author|addressees): ' "$rigTmp/s1" | tr '\n' '|' ; }
rigAssert "header, platform and @here forms"                "$( rigLines )" "author: magic-coordinator|addressees: rig-member, U7|author: magic-team|addressees: @here (unaddressed)|author: U2|addressees: U5 (alice)|author: U3|addressees: @here (unaddressed)|author: U3|addressees: (none stated)|"
rigAssert "placed right after user:"                        "$( LC_ALL=C awk '/^user: / { u = NR ; } /^author: / { print ( NR == u + 1 ) ? "ok" : "bad" ; exit ; }' "$rigTmp/s1" )" ok

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ITEM CREATE SHAPE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ITEM_CREATE_SHAPE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
