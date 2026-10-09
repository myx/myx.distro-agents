#!/usr/bin/env bash
## Behavioural check on the tooling's own tracking posts (--intern-op-event-track-post,
## AgentsTools.InternOpEventTrackPost.include) and where the event-track feed ends them
## (AgentsTools.EventTrackFeed.include): a post is blocks, each a subject header (member,
## session or system) then its lines; every kind renders from the template
## sh-lib/templates/event-track.post.format.md; every operation renders as one line by its own
## template; no post holds a code block or a raw transcript line; values are redacted and
## escaped; one post holds several subjects' blocks, the header repeated only when the subject
## changes, and an empty line before each but the first; a start post names short ids and
## nothing that only repeats another; a long post is cut into posts of at most 4000 characters, fixed (Slack's `text`
## limit, counted in characters, not bytes), a block's header repeated; the feed ends a post
## right after an immediate line, sends its posts one at a time and in order, and never edits
## one; the op posts through the shared Slack call (a rate limit is waited out), threads the
## later parts of a post under the first, logs each post, and has no edit option; a spawn's
## start post is made once, after its CLI is resolved, and what is learned later is a reply.
## Offline: a Slack-shaped fake curl first on PATH answers every call, and every op runs in a
## clean environment whose workspace and data root sit under this rig's own mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/event-track.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigTemplate" ] || rigRefuse "the template is not in the package: $rigTemplate"
rigTmp="$( mktemp -d -t AgentsEventTrackPostCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigYes(){ "$@" > /dev/null 2>&1 && printf yes || printf no ; }
rigCount(){ ## file, fixed line -- how many lines are exactly it
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2>/dev/null || :
}
rigPostCount(){ ls "$1" | LC_ALL=C awk 'END { print NR }' ; }
## The block headers of a post, one per line.
rigHeaders(){ LC_ALL=C grep -e '^👤 ' -e '^🧵 session ' -e '^⚙️ system' "$@" ; }

## The team's members, for a line's by=: two of them.
mkdir -p "$rigTmp/skills/magic-tester" "$rigTmp/skills/magic-coordinator"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"

## ---------------------------------------------------------------------------
echo "-- every kind renders from the template, as a block of its subject --"
## ---------------------------------------------------------------------------
set -- --rig-none
MDSC_CMD=rig
unset MDAT_SKILLSET_ROOT
. "$rigLib/AgentsTools.InternOpEventTrackPost.include"
## The render's own workspace, in the rig tree: a Slack account cache of its own, and no
## session directory unless a check below makes one.
rigRenderWs="$rigTmp/render-ws"
rigRenderSid="abcdef01-2345-4000-8000-000000000001"
mkdir -p "$rigRenderWs/.local/.agents"
printf '%s\n' 'rig-generation' 'human-owner=U0RIGOWNER=owner=Owner=Owner=rig' 'magic-devops=-' > "$rigRenderWs/.local/.agents/slack-mention-ids.cache"
rigRender(){ ## kind, out dir, lines file, name=value...
	local renderKind="$1" renderDir="$2" renderFrom="$3"
	shift 3
	rm -rf "$renderDir" ; mkdir -p "$renderDir"
	MMDAPP="$rigRenderWs" AgentsEventTrackPostRender "$renderKind" magic-tester "$rigRenderSid" "$renderDir" "$renderFrom" "$@"
}
rigSession='🧵 session `abcdef01` · *magic-tester*'
rigSystem='⚙️ system · `abcdef01`'
for rigKindLabel in "start|$rigSession|🚀 session start — rig-what" "end|$rigSession|🏁 session end" "handback|$rigSession|📦 handback: none posted" \
	"notice|$rigSession|⚠️ notice: rig-what" "refusal|$rigSystem|🚫 refusal: rig-what" "error|$rigSystem|⛔ error: rig-what" "activity|$rigSystem|📋 rig-what" ; do
	rigKind="${rigKindLabel%%|*}" ; rigRest="${rigKindLabel#*|}" ; rigHeader="${rigRest%%|*}" ; rigLabel="${rigRest#*|}"
	rigRender "$rigKind" "$rigTmp/k-$rigKind" /dev/null what=rig-what cli=rig-cli outcome=succeeded handback='none posted' \
		tokens='in=1100 cache-read=200 cache-write=300 out=1400 (incl. 1 sub-session)'
	rigPost="$rigTmp/k-$rigKind/000001"
	rigAssert "$rigKind: one post, its subject's header, then its own label" \
		"$( rigPostCount "$rigTmp/k-$rigKind" ):$( sed -n 1p "$rigPost" ):$( sed -n 2p "$rigPost" )" "1:$rigHeader:$rigLabel"
	rigAssert "$rigKind: no @here, no addressee line, no member-message author line" \
		"$( LC_ALL=C grep -c -e '@here' -e '^→' -e '\*_' "$rigPost" )" 0
done
rigAssert "the fields the caller gave fill their slots" "$( rigCount "$rigTmp/k-end/000001" 'cli: rig-cli' )" 1
rigAssert "a given tokens field reads as in, cache and out" "$( rigCount "$rigTmp/k-end/000001" 'tokens: in 1.1K · cache 500 · out 1.4K (incl. 1 sub-session)' )" 1
rigAssert "a line whose slots are all empty is left out" "$( cat "$rigTmp/k-error/000001" "$rigTmp/k-end/000001" | LC_ALL=C grep -c -e '^detail:' -e '^ended:' -e '^timed out' )" 0
rigAssert "an empty field on a kept line is left out, its label with it" "$( rigCount "$rigTmp/k-end/000001" 'outcome: succeeded' )" 1
rigAssert "no field anywhere reads as a placeholder" "$( cat "$rigTmp"/k-*/000001 | LC_ALL=C grep -c -e ': -$' -e ': - ' -e ' -$' )" 0
rigAssert "a line whose first field is empty opens with the next one, not its separator" \
	"$( rigRender start "$rigTmp/k-sep" /dev/null runs=native wait=true dispatch=none ; sed -n '3,4p' "$rigTmp/k-sep/000001" | LC_ALL=C tr '\n' '|' )" 'runs: native · wait: true|dispatch: `none`'
rigAssert "a value given as - is no value" "$( rigRender end "$rigTmp/k-dash" /dev/null outcome=- exit-code=0 ; sed -n 3p "$rigTmp/k-dash/000001" )" 'exit: 0'
rigRender start "$rigTmp/k-root" /dev/null cli=claude-native runs=native spawn-id=99d85f58 session-id=154edb9e parent-session-id=- tracking-name=- \
	session-thread=CRIG:1.2 host=rig-host workspace=rig-ws started-at='2030-01-01 00:00 +0000' output-file=rig-ws/session.log receipt=spawn-proxy-rig context=rig-context
rigAssert "a compact root: the short ids, no parent or tracking that only repeats the session, no output, receipt or context" \
	"$( LC_ALL=C tr '\n' '|' < "$rigTmp/k-root/000001" )" \
	'🧵 session `abcdef01` · *magic-tester*|🚀 session start|cli: claude-native · runs: native|spawn: `99d85f58` · session: `154edb9e`|session thread: `CRIG:1.2`|where: rig-host / rig-ws · started: 2030-01-01 00:00 +0000'
rigRender start "$rigTmp/k-root" /dev/null spawn-id=99d85f58 session-id=154edb9e parent-session-id=3f2488f9 tracking-name=rig-track
rigAssert "a parent or tracking name that differs from the session is kept" \
	"$( sed -n 3p "$rigTmp/k-root/000001" )" 'spawn: `99d85f58` · session: `154edb9e` · parent: `3f2488f9` · tracking: `rig-track`'
printf '%s\n' '2030-01-01T00:09:00Z TOOL Read path=/x/only.md -> ok 10B/1L 1ms' > "$rigTmp/lines.nowhat"
rigRender activity "$rigTmp/k-nowhat" "$rigTmp/lines.nowhat"
rigAssert "no header without a line under it: the activity block, its line left out, has none" \
	"$( LC_ALL=C tr '\n' '|' < "$rigTmp/k-nowhat/000001" )" '👤 *magic-tester* · 00:09:00 UTC|📖 Read `x/only.md` → 10 B'
for rigGone in state review dismissed nonesuch ; do
	rigRender "$rigGone" "$rigTmp/k-$rigGone" /dev/null ; rigNoneRc=$?
	rigAssert "a kind the template has no block for renders nothing: $rigGone" "$rigNoneRc:$( rigPostCount "$rigTmp/k-$rigGone" )" 3:0
done
mkdir -p "$rigTmp/k-nosession"
AgentsEventTrackPostRender error magic-tester "" "$rigTmp/k-nosession" /dev/null what=x
rigAssert "no session: the system header leaves it out" "$( head -1 "$rigTmp/k-nosession/000001" )" '⚙️ system'

## ---------------------------------------------------------------------------
echo "-- every operation renders as one line by its own template --"
## ---------------------------------------------------------------------------
rigOps="$rigTmp/ops"
cat > "$rigOps" <<'RIG_OPS_EOF'
2030-01-01T00:01:00Z TOOL Read path=/w/source/myx/magic-team.shared.md offset=1 limit=200 -> ok 20480B/202L 12ms
2030-01-01T00:01:01Z TOOL Grep pattern=review-by path=/w/myx.distro-agents/sh-lib mode=content -> ok 2100B/31L 40ms
2030-01-01T00:01:02Z TOOL Glob pattern=**/*.routine.md -> ok 3000B/42L 8ms
2030-01-01T00:01:03Z TOOL Edit path=/w/sh-lib/AgentsTools.Member.include -> ok 40B/1L 10ms
2030-01-01T00:01:04Z TOOL mcp__myx_distro__Write path=/w/lib.tukaani-xz-java/README.md -> ok 86B/1L 551ms
2030-01-01T00:01:05Z TOOL execute cmd="bash -n sh-lib/AgentsTools.Member.include" -> ok 3B/1L 1.2s | "Syntax check"
2030-01-01T00:01:05Z TOOL Bash cmd="ls -la" -> ok 300B/9L 40ms | "Syntax check"
2030-01-01T00:01:06Z TOOL Skill name=magic-team file=magic-team.shared.md section="Nothing stops" -> ok 1965B/19L 725ms
2030-01-01T00:01:07Z TOOL SendMessage to=magic-coordinator -> ok 120B/2L 300ms
2030-01-01T00:01:07Z MSG-OUT to=magic-coordinator
> Done with the README pass, 2 files changed.
> Details follow.
2030-01-01T00:01:07Z MSG-OUT tool=ReportFindings to=magic-coordinator
> {"to":"magic-coordinator","subject":"Two READMEs","findings":"secret-ish body text"}
2030-01-01T00:01:07Z TOOL ReportFindings to=magic-coordinator subject="Two READMEs" -> ok 50B/1L 200ms
2030-01-01T00:01:08Z TOOL Wait sources=slack:C1:1.2 -> ok 1298B/18L 1m05s
2030-01-01T00:01:08Z WAIT-RESULT
> WAIT-RESULT: RECEIVED
> # arrived on: slack:C1:1.2
> 1791464258.897149 | U0RIGUSER | yes, go ahead
2030-01-01T00:01:09Z TOOL Wait mode=continue -> ok 60B/1L 28m20s
2030-01-01T00:01:09Z WAIT-RESULT
> WAIT-RESULT: TIMEOUT (1700s) NEXT: Wait mode=continue
2030-01-01T00:01:10Z SPAWN agent=keeper-myx
> RECEIPT_ID=r1
> SESSION_ID=7f12abcd-0000-4000-8000-000000000009
> STATUS=started
2030-01-01T00:01:10Z TOOL Agent agent=keeper-myx -> ok 200B/5L 3.0s
2030-01-01T00:01:11Z TOOL AskUserQuestion to=human-owner kind=permission -> ok 805B/14L 1m35s
2030-01-01T00:01:11Z ASK to=human-owner kind=permission
> May I write MAGIC.md in lib.tukaani-xz-java?
2030-01-01T00:01:11Z ANSWER
> VERDICT: YES
2030-01-01T00:01:12Z ROUND n=12 in=48000 cache-read=300000 cache-write=10000 out=1200
> Checking the template next.
2030-01-01T00:01:13Z TOOL WebFetch url=https://example.invalid/page -> ok 10B/1L 1.0s
2030-01-01T00:01:14Z NOTE by=magic-tester at=00:01
> a note to the transcript
2030-01-01T00:01:15Z REVIEW item=dispatch-20301001T0000Z-rig kind=handback by=magic-tester text="handback: done (item in running)"
2030-01-01T00:01:16Z VERDICT item=dispatch-20301001T0000Z-rig kind=verdict by=magic-coordinator text="accepted: fine"
2030-01-01T00:01:17Z FINAL
> All done here.
2030-01-01T00:01:18Z RESULT outcome=ok turns=7 in=1100 cache-read=200 cache-write=300 out=1400
> the result text
2030-01-01T00:01:19Z WIDGET colour=blue text="something new"
housekeeping: dispatch-x.md review-by -> magic-coordinator
2030-01-01T00:02:00Z TOOL Read path=/x/a.txt -> error "ERROR: no such file: /x/a.txt" 30B/1L 2ms
> ERROR: no such file: /x/a.txt
2030-01-01T00:02:01Z TOOL execute cmd="false" -> error "[exit code: 1]" 14B/1L 20ms
2030-01-01T00:02:02Z TOOL Write path=/x/README.md -> refused "ERROR: path not in the allowed write-root set" 548B/3L 6.8s
2030-01-01T00:02:03Z TOOL SubagentHandback to=magic-coordinator -> ok 9958B/19L 2.4s
2030-01-01T00:02:03Z HANDBACK to=magic-coordinator
> task: the README pass
> outcome: two files written, one refused
> findings: none
2030-01-01T00:02:04Z TOOL Wait -> ok 887B/13L 12.8s
2030-01-01T00:02:04Z DISMISSED
> WAIT-RESULT: DISMISSED
> WAIT-DISMISSED-BY: C1:1791464999.000100
2030-01-01T00:02:05Z ENDING item=dispatch-x kind=dismissed by=magic-coordinator text="shutdown: done"
2030-01-01T00:02:06Z MODEL model=claude-opus-5-5 service=claude-native cli_session=cli-1
2030-01-01T00:02:07Z RESTART n=1 summary=10240B
2030-01-01T00:02:08Z START session=abcdef01-2345 member=magic-tester item=dispatch-x.md
2030-01-01T00:02:09Z ERROR source=provider kind=overloaded_error
> Overloaded, try again
2030-01-01T00:02:10Z RESULT outcome=error turns=3 in=1 cache-read=0 cache-write=0 out=0
> The run ended on an error
2030-01-01T00:02:11Z END outcome=succeeded exit=0 tokens="in=1100 cache-read=200 cache-write=300 out=1400"
RIG_OPS_EOF
rigRender feed "$rigTmp/k-ops" "$rigOps"
rigPost="$rigTmp/k-ops/000001"
rigAssert "the operations make one post" "$( rigPostCount "$rigTmp/k-ops" )" 1
rigOpsCount=0
while IFS= read -r rigWant ; do
	[ -n "$rigWant" ] || continue
	rigOpsCount=$(( rigOpsCount + 1 ))
	rigAssert "renders: $rigWant" "$( rigCount "$rigPost" "$rigWant" )" 1
done <<'RIG_WANT_EOF'
📖 Read `magic-team.shared.md` · lines 1–200 → 20 KB
🔍 Grep `review-by` in `myx.distro-agents/sh-lib` → 31 lines
📁 Glob `**/*.routine.md` → 42 entries
✏️ Edit `AgentsTools.Member.include` → ok
📝 Write `lib.tukaani-xz-java/README.md` → ok
💻 Syntax check — execute `bash -n sh-lib/AgentsTools.Member.include` → exit 0 · 1.2 s
💻 Bash `ls -la` → exit 0 · 40 ms
📚 Skill `magic-team` · `magic-team.shared.md` § Nothing stops → 1.9 KB
✉️ SendMessage → *magic-coordinator*: "Done with the README pass, 2 files changed."
📊 ReportFindings → *magic-coordinator*: "Two READMEs"
⏳ Wait → RECEIVED from *U0RIGUSER*: "yes, go ahead" · on: reply · 1 m 5 s
⏳ Wait → TIMEOUT 1700 s · 28 m 20 s
🚀 Agent spawn → *keeper-myx* (session 7f12abcd…) · started
❔ AskUserQuestion → *human-owner* · permission: "May I write MAGIC.md in lib.tukaani-xz-java?"
🧠 round 12 · in 48K · cache 310K · out 1.2K
🌐 WebFetch `https://example.invalid/page` → 10 B
🗒️ note by *magic-tester*: "a note to the transcript"
🧾 review `dispatch-20301001T0000Z-rig` · handback by *magic-tester*: handback: done (item in running)
⚖️ verdict on `dispatch-20301001T0000Z-rig` by *magic-coordinator*: accepted: fine
💬 final answer: "All done here."
🧠 run ok · 7 turns · in 1.1K · cache 500 · out 1.4K
🔹 widget: something new
• housekeeping: dispatch-x.md review-by -&gt; magic-coordinator
⛔ Read `x/a.txt` → error: ERROR: no such file: /x/a.txt
⛔ execute `false` → error: [exit code: 1]
🚫 Write `x/README.md` → refused: ERROR: path not in the allowed write-root set
📦 handback → *magic-coordinator*: "two files written, one refused"
⏳ Wait → DISMISSED by *C1:1791464999.000100* · 12.8 s
🛑 dismissed `dispatch-x` by *magic-coordinator*: shutdown: done
🤖 model `claude-opus-5-5` · claude-native
♻️ restart 1 · summary 10 KB
🚀 session start · `dispatch-x.md`
⛔ error · provider · overloaded_error: Overloaded, try again
⛔ error · result: The run ended on an error
🏁 session end · succeeded · exit 0 · in 1.1K · cache 500 · out 1.4K
RIG_WANT_EOF
rigAssert "one line per operation, a call and its message events one line, nothing else" \
	"$( LC_ALL=C grep -c -v -e '^👤 ' -e '^🧵 session ' -e '^⚙️ system' -e '^$' "$rigPost" )" "$rigOpsCount"
rigAssert "a comment shows once, not again on the next line that has the same" "$( LC_ALL=C grep -c -F 'Syntax check' "$rigPost" )" 1
rigAssert "the blocks: a header each time the subject changes, a run of the same subject under one, the immediate operations too" \
	"$( rigHeaders "$rigPost" | LC_ALL=C awk '{ print $1 }' | LC_ALL=C tr '\n' ' ' )" \
	"👤 🧵 👤 ⚙️ 👤 🧵 👤 🧵 "
rigAssert "a member block's header names the member and its span" "$( sed -n 1p "$rigPost" )" '👤 *magic-tester* · 00:01:00–00:01:14 UTC'
rigAssert "a session block's header names the session, the member and its span" "$( rigCount "$rigPost" '🧵 session `abcdef01` · *magic-tester* · 00:01:15–00:01:16 UTC' )" 1
rigAssert "the handback, both dismissals, the model, the restart and the start, in a row, share one session header, its span theirs" \
	"$( rigCount "$rigPost" '🧵 session `abcdef01` · *magic-tester* · 00:02:03–00:02:08 UTC' ):$( LC_ALL=C awk '/^🧵 / { on = ( index( $0, "00:02:03" ) > 0 ) ; next } /^$/ { on = 0 } on { n++ } END { print n + 0 }' "$rigPost" )" 1:6
## Empty lines, then misplaced lines: a header after a non-empty line, or anything but a header after an empty one.
rigBlankCheck(){ LC_ALL=C awk '{ head = ( $0 ~ /^(👤 |🧵 session |⚙️ system)/ ) } NR == 1 && ! head { bad++ } NR > 1 && head != ( prev == "" ) { bad++ } $0 == "" { blank++ } { prev = $0 } END { print blank + 0 ":" bad + 0 }' "$1" ; }
rigAssert "an empty line before every header but the post's first, and nowhere else" \
	"$( rigBlankCheck "$rigPost" ):$( rigHeaders "$rigPost" | LC_ALL=C awk 'END { print NR - 1 }' )" "7:0:7"

echo "-- no code block and no raw transcript line in any post --"
rigAssert "no code fence" "$( LC_ALL=C grep -c -F '```' "$rigPost" )" 0
rigAssert "no transcript line as it came" "$( LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z ' "$rigPost" )" 0
rigAssert "no raw KIND key=val text" \
	"$( LC_ALL=C grep -c -E '(TOOL|ROUND|MSG-OUT|WAIT-RESULT|ASK|ANSWER|SPAWN|HANDBACK|MODEL|START|END|ERROR|RESULT|NOTE|REVIEW|VERDICT|FINAL|RESTART|ENDING) [a-z_-]+=' "$rigPost" )" 0
rigAssert "no body line, no size or outcome token, no message tool's own arguments" \
	"$( LC_ALL=C grep -c -E -e '^> ' -e '[0-9]+B/[0-9]+L' -e ' -> (ok|error|refused)' -e 'secret-ish' "$rigPost" )" 0

## ---------------------------------------------------------------------------
echo "-- values are redacted as the transcript redacts them, and escaped --"
## ---------------------------------------------------------------------------
cat > "$rigTmp/lines.redact" <<'RIG_REDACT_EOF'
2030-01-01T00:03:00Z TOOL execute cmd="export GH_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123 && make" -> ok 3B/1L 1s
2030-01-01T00:03:01Z TOOL SendMessage to=magic-coordinator -> ok 3B/1L 1s
2030-01-01T00:03:01Z MSG-OUT to=magic-coordinator
> token xoxb-123456789012-abcdefghijkl <!here> <@U123> & `code` here
2030-01-01T00:03:02Z TOOL Read path=/x/we`ird<name>.md -> ok 3B/1L 1ms
RIG_REDACT_EOF
rigRender refusal "$rigTmp/k-redact" "$rigTmp/lines.redact" what=x reason='curl -H "Authorization: Bearer abc.def.ghi" with sk-abcdefghijklmnopqrstuvwxyz'
rigPost="$rigTmp/k-redact/000001"
rigAssert "no token is left: in an argument, a message body, a given field" \
	"$( LC_ALL=C grep -c -e 'ghp_abc' -e 'xoxb-1234' -e 'abc.def.ghi' -e 'sk-abcdef' "$rigPost" )" 0
rigAssert "each one reads [redacted], the name or scheme before it kept" \
	"$( rigCount "$rigPost" '💻 execute `export GH_TOKEN=[redacted] &amp;&amp; make` → exit 0 · 1 s' ):$( rigCount "$rigPost" 'reason: curl -H "Authorization: Bearer [redacted]" with [redacted]' )" 1:1
rigAssert "Slack's control characters are escaped, so nothing mentions anyone" \
	"$( rigCount "$rigPost" '✉️ SendMessage → *magic-coordinator*: "token [redacted] &lt;!here&gt; &lt;@U123&gt; &amp; %60code%60 here"' )" 1
rigAssert "a backtick in a value is %60, so no code span breaks" "$( rigCount "$rigPost" '📖 Read `we%60ird&lt;name&gt;.md` → 3 B' )" 1
rigAssert "the operations given to a kind follow its own block" "$( rigHeaders "$rigPost" | LC_ALL=C awk '{ print $1 }' | LC_ALL=C tr '\n' ' ' )" "⚙️ 👤 "

## ---------------------------------------------------------------------------
echo "-- one post holds several subjects' blocks, a header each time the subject changes --"
## ---------------------------------------------------------------------------
cat > "$rigTmp/lines.blocks" <<'RIG_BLOCKS_EOF'
2030-01-01T00:04:00Z TOOL Read path=/x/one-of-them.md -> ok 10B/1L 1ms
2030-01-01T00:04:01Z NOTE by=magic-coordinator
> the coordinator notes
2030-01-01T00:04:02Z NOTE by=tooling
> no member wrote this one
2030-01-01T00:04:03Z VERDICT item=rig-item kind=verdict by=magic-coordinator text="accepted: ok"
2030-01-01T00:04:04Z TOOL Glob pattern=*.md -> ok 10B/2L 1ms
housekeeping: one line of the tooling
2030-01-01T00:04:05Z TOOL Read path=/x/two-of-them.md -> ok 10B/1L 1ms
2030-01-01T00:04:05Z TOOL Read path=/x/three-of-them.md -> ok 10B/1L 1ms
2030-01-01T00:04:06Z TOOL Edit path=/x/two-of-them.md -> error "ERROR: old_string not found" 30B/1L 1ms
RIG_BLOCKS_EOF
MDAT_SKILLSET_ROOT="$rigTmp/skills" rigRender feed "$rigTmp/k-blocks" "$rigTmp/lines.blocks"
rigPost="$rigTmp/k-blocks/000001"
rigAssert "one post: no split on a change of member or subject" "$( rigPostCount "$rigTmp/k-blocks" )" 1
rigAssert "the headers, in order: the same member again after another member, the session and the system" \
	"$( rigHeaders "$rigPost" )" "$( printf '%s\n' '👤 *magic-tester* · 00:04:00 UTC' '👤 *magic-coordinator* · 00:04:01 UTC' '👤 *magic-tester* · 00:04:02 UTC' \
		'🧵 session `abcdef01` · *magic-tester* · 00:04:03 UTC' '👤 *magic-tester* · 00:04:04 UTC' '⚙️ system · `abcdef01`' '👤 *magic-tester* · 00:04:05–00:04:06 UTC' )"
rigAssert "each block's lines follow its header, in the order given" \
	"$( LC_ALL=C awk '/^$/ { next } /^👤 |^🧵 |^⚙️ / { printf "%s|", $1 ; next } { printf "%s ", $1 } END { print "" }' "$rigPost" )" \
	'👤|📖 👤|🗒️ 👤|🗒️ 🧵|⚖️ 👤|📁 ⚙️|• 👤|📖 📖 ⛔ '
rigAssert "each block stands apart: an empty line before every header but the first, and nowhere else" "$( rigBlankCheck "$rigPost" )" "6:0"
rigAssert "a by= naming no member of the team stays in the post's member's block" \
	"$( LC_ALL=C awk '/^👤 |^🧵 |^⚙️ / { header = $0 ; next } index( $0, "by *tooling*" ) > 0 { print header }' "$rigPost" )" '👤 *magic-tester* · 00:04:02 UTC'
## A session's close as a real transcript has it: the dismissal, the Wait it ended, then the end, in a row.
printf '%s\n' '2030-01-01T00:04:10Z TOOL Wait mode=continue -> ok 52B/1L 7m34s' '2030-01-01T00:04:10Z WAIT-RESULT' '> WAIT-RESULT: TIMEOUT (455s) NEXT: Wait mode=continue' \
	'2030-01-01T00:04:11Z ENDING item=rig-item kind=dismissed by=magic-coordinator text="review-wait-expired"' \
	'2030-01-01T00:04:11Z TOOL Wait mode=continue -> ok 203B/3L 424ms' '2030-01-01T00:04:11Z DISMISSED' '> WAIT-RESULT: DISMISSED' '> WAIT-DISMISSED-BY: tooling (review-wait-expired)' \
	'2030-01-01T00:04:12Z END outcome=succeeded exit=0' > "$rigTmp/lines.close"
rigRender activity "$rigTmp/k-close" "$rigTmp/lines.close" what=rig-close
rigAssert "the dismissal, its Wait and the end share one session header; a header repeats only after another subject" \
	"$( LC_ALL=C tr '\n' '|' < "$rigTmp/k-close/000001" )" \
	'⚙️ system · `abcdef01`|📋 rig-close||👤 *magic-tester* · 00:04:10 UTC|⏳ Wait → TIMEOUT 455 s · 7 m 34 s||🧵 session `abcdef01` · *magic-tester* · 00:04:11–00:04:12 UTC|🛑 dismissed `rig-item` by *magic-coordinator*: review-wait-expired|⏳ Wait → DISMISSED by *tooling*: "review-wait-expired" · 424 ms|🏁 session end · succeeded · exit 0'

## ---------------------------------------------------------------------------
echo "-- the agent's own description leads the line, and a command reads without its boilerplate --"
## ---------------------------------------------------------------------------
cat > "$rigTmp/lines.intent" <<'RIG_INTENT_EOF'
2030-01-01T00:07:00Z TOOL execute cmd="DistroSystemContext --distro-from-source ; Require DistroAgentsTools ; Distro DistroAgentsTools --member-board-item-read magic-tester task-x.md" -> ok 30B/2L 64ms | "Reading the task item"
2030-01-01T00:07:01Z TOOL execute cmd="DistroSystemContext --distro-from-source ; Require DistroAgentsTools ; Distro DistroAgentsTools --member-help magic-tester" -> ok 30B/2L 60ms
2030-01-01T00:07:02Z TOOL mcp__myx_distro__Skill name=magic-team file=magic-team.board.md -> ok 5701B/66L 49ms | "Checking the board rules"
2030-01-01T00:07:03Z TOOL Agent agent=keeper-myx -> ok 200B/5L 3.0s | "Spawn the README keeper"
2030-01-01T00:07:03Z SPAWN agent=keeper-myx
> SESSION_ID=7f12abcd-0000-4000-8000-000000000009
> STATUS=started
2030-01-01T00:07:04Z TOOL SendMessage to=human-owner message="Blocked on the registry, need your call." -> error "ERROR: the send failed (rc=1) and nothing was posted." 60B/1L 66ms | "Ask the owner"
2030-01-01T00:07:05Z TOOL SendMessage to=human-owner message="from the line" -> ok 10B/1L 1.2s
2030-01-01T00:07:05Z MSG-OUT to=human-owner
>
> First real line of the body.
> second line
2030-01-01T00:07:06Z TOOL TodoWrite args=120B -> ok 10B/1L 2ms | "Writing the tests"
2030-01-01T00:07:07Z TOOL execute cmd="DistroSystemContext --distro-from-source" -> ok 1B/1L 5ms
RIG_INTENT_EOF
rigRender feed "$rigTmp/k-intent" "$rigTmp/lines.intent"
while IFS= read -r rigWant ; do
	[ -n "$rigWant" ] || continue
	rigAssert "renders: $rigWant" "$( cat "$rigTmp/k-intent"/* | LC_ALL=C grep -c -x -F -- "$rigWant" )" 1
done <<'RIG_INTENT_WANT_EOF'
💻 Reading the task item — execute `DistroAgentsTools --member-board-item-read magic-tester task-x.md` → exit 0 · 64 ms
💻 execute `DistroAgentsTools --member-help magic-tester` → exit 0 · 60 ms
📚 Checking the board rules — Skill `magic-team` · `magic-team.board.md` → 5.6 KB
🚀 Spawn the README keeper — Agent spawn → *keeper-myx* (session 7f12abcd…) · started
⛔ Ask the owner — SendMessage `human-owner`: "Blocked on the registry, need your call." → error: ERROR: the send failed (rc=1) and nothing was posted.
✉️ SendMessage → *human-owner*: "First real line of the body."
🔧 Writing the tests — TodoWrite → ok
💻 execute `DistroSystemContext --distro-from-source` → exit 0 · 5 ms
RIG_INTENT_WANT_EOF

## ---------------------------------------------------------------------------
echo "-- every tool's own description leads its line, ahead of the model's text --"
## ---------------------------------------------------------------------------
## Each line is made by the transcript's own formatter from a served call carrying a
## description, the model's text before it given too: for every tool on the floor, and the
## server's own execute, the description is what leads. Names from the mirror.
rigFloorNames="$( bash "$rigLib/AgentsHarnessMcpMirror.sh" 2>/dev/null | LC_ALL=C grep -o '{"name":"[A-Za-z]*"' | sed 's/.*"name":"//; s/"$//' ) execute"
: > "$rigTmp/lines.every"
rigEveryTotal=0
for rigName in $rigFloorNames ; do
	rigEveryTotal=$(( rigEveryTotal + 1 ))
	printf '%s' '{"description":"Intent for '"$rigName"'"}' | STL_TS="2030-01-01T00:10:00Z" STL_TOOL="mcp__myx_distro__$rigName" STL_OUTCOME=ok STL_BYTES=10 STL_LINES=1 STL_COMMENT='RIG model text' \
		LC_ALL=C awk -v stlStandalone=tool -f "$rigLib/AgentsSessionTranscriptFormat.awk" >> "$rigTmp/lines.every"
done
rigRender feed "$rigTmp/k-every" "$rigTmp/lines.every"
rigEveryLed=0
for rigName in $rigFloorNames ; do
	if [ "$( cat "$rigTmp/k-every"/* | LC_ALL=C grep -c -F -- "Intent for $rigName — " )" = 1 ] ; then rigEveryLed=$(( rigEveryLed + 1 )) ; else printf '        not led: %s\n' "$rigName" ; fi
done
rigAssert "every tool's line leads with its own description (read from the floor, so never vacuous)" \
	"$rigEveryLed:$( [ "$rigEveryTotal" -gt 20 ] && echo floor-read )" "$rigEveryTotal:floor-read"
rigAssert "and the model's text before the call is on none of them" "$( cat "$rigTmp/k-every"/* | LC_ALL=C grep -c -F 'RIG model text' )" 0
rigAssert "a read line, exactly: the description, then the tool" "$( cat "$rigTmp/k-every"/* | LC_ALL=C grep -c -x -F '📖 Intent for Read — Read → 10 B' )" 1

## ---------------------------------------------------------------------------
echo "-- a Wait says how it resolved, from whom, and what it waited on where that changed --"
## ---------------------------------------------------------------------------
cat > "$rigTmp/lines.wait" <<'RIG_WAIT_EOF'
2030-01-01T00:08:00Z TOOL Wait sources="slack:magic-team ask:2dc1d732-8ee1-4438-94e7-9d8148c8e71b" -> ok 900B/12L 30.0s
2030-01-01T00:08:00Z WAIT-RESULT
> WAIT-RESULT: RECEIVED
> # sources: slack:magic-team ask:2dc1d732-8ee1-4438-94e7-9d8148c8e71b
> # --- what that source holds now follows ---
> 1791523076.323569 | U0BOT | [sender: magic-devops] :wrench: *_magic-devops_* @magic-devops → @here. Handback  the &lt;b&gt; check, see <https://example.invalid/x|the board>
> more text of it
> 1791523076.325939 | U0BOT | [sender: magic-architect] *_magic-architect_* @magic-architect → @here. armed
> # --- end ---
2030-01-01T00:08:01Z TOOL Wait mode=continue -> ok 900B/12L 10.0s
2030-01-01T00:08:01Z WAIT-RESULT
> WAIT-RESULT: RECEIVED
> # sources: slack:magic-team ask:2dc1d732-8ee1-4438-94e7-9d8148c8e71b
> 1791523580.607129 | U0RIGOWNER | 
> 1. recheck
> # --- pending reply 2dc1d732, as the asking call would take it ---
> ASK-RESULT: RECEIVED
> VERDICT: YES
2030-01-01T00:08:02Z TOOL Wait sources="slack:CRIG:1791524417.723279:conversation slack:DRIG:1791524417.723279" -> ok 60B/1L 5.0s
2030-01-01T00:08:02Z WAIT-RESULT
> WAIT-RESULT: TIMEOUT (5s) NEXT: Wait mode=continue
2030-01-01T00:08:03Z TOOL Wait -> ok 200B/3L 1.0s
2030-01-01T00:08:03Z DISMISSED
> WAIT-RESULT: DISMISSED
> WAIT-DISMISSED-BY: CRIG:1791525000.000100
> 1791525000.000100 | U0BOT | [sender: magic-coordinator] DISMISSED
2030-01-01T00:08:04Z TOOL Wait -> ok 200B/3L 1.0s
2030-01-01T00:08:04Z DISMISSED
> WAIT-RESULT: DISMISSED
> WAIT-DISMISSED-BY: tooling (review-wait-expired: no verdict within 3600s)
RIG_WAIT_EOF
rigRender feed "$rigTmp/k-wait" "$rigTmp/lines.wait"
while IFS= read -r rigWant ; do
	[ -n "$rigWant" ] || continue
	rigAssert "renders: $rigWant" "$( cat "$rigTmp/k-wait"/* | LC_ALL=C grep -c -x -F -- "$rigWant" )" 1
done <<'RIG_WAIT_WANT_EOF'
⏳ Wait → RECEIVED from *magic-devops*: "Handback  the &lt;b&gt; check, see the board" (+1 more) · on: magic-team, ask:2dc1d732 · 30.0 s
⏳ Wait → answered YES from *human-owner*: "1. recheck" · 10.0 s
⏳ Wait → TIMEOUT 5 s · on: +thread +DM reply −magic-team −ask:2dc1d732 · 5.0 s
⏳ Wait → DISMISSED by *magic-coordinator* · 1.0 s
⏳ Wait → DISMISSED by *tooling*: "review-wait-expired: no verdict within 3600s" · 1.0 s
RIG_WAIT_WANT_EOF
rigAssert "no member-send author line and no raw Slack link reach a post" "$( cat "$rigTmp/k-wait"/* | LC_ALL=C grep -c -e '\[sender:' -e '\*_' -e 'https://example' )" 0
## A feed post's session keeps its last set, so the next post shows a Wait's set only where it changed.
mkdir -p "$rigRenderWs/.local/agents/sessions/$rigRenderSid"
rigRender feed "$rigTmp/k-wait" "$rigTmp/lines.wait"
rigAssert "a feed post leaves its session's last Wait set beside its feed" "$( cat "$rigRenderWs/.local/agents/sessions/$rigRenderSid/event-track.wait-on" )" 'thread|DM reply'
printf '%s\n' '2030-01-01T00:09:00Z TOOL Wait sources="slack:CRIG:1791524999.000001:conversation slack:DRIG:1791524999.000001" -> ok 60B/1L 2.0s' \
	'2030-01-01T00:09:01Z TOOL Wait sources="slack:CRIG:1791524999.000001:conversation inbox:magic-tester" -> ok 60B/1L 2.0s' > "$rigTmp/lines.wait2"
rigRender feed "$rigTmp/k-wait2" "$rigTmp/lines.wait2"
rigAssert "the next post: the same set says nothing, a changed one only the change" \
	"$( LC_ALL=C grep '^⏳' "$rigTmp/k-wait2/000001" | LC_ALL=C tr '\n' '|' )" '⏳ Wait · 2.0 s|⏳ Wait · on: +inbox −DM reply · 2.0 s|'
rigRender activity "$rigTmp/k-wait3" "$rigTmp/lines.wait2" what=x
rigAssert "only a feed post reads or keeps it: any other shows its first Wait's set whole" \
	"$( LC_ALL=C grep -c -F '⏳ Wait · on: thread, DM reply · 2.0 s' "$rigTmp/k-wait3/000001" ):$( cat "$rigRenderWs/.local/agents/sessions/$rigRenderSid/event-track.wait-on" )" '1:thread|inbox'
rm -rf "$rigRenderWs/.local/agents"

## ---------------------------------------------------------------------------
echo "-- a long post is cut into posts of at most 4000 characters, fixed in code --"
## ---------------------------------------------------------------------------
## The characters of a file as Slack counts a message's text: bytes less UTF-8 continuation
## bytes, a character outside the BMP twice (UTF-16), the last newline not part of the text.
rigChars(){ LC_ALL=C awk '{ line = $0 ; gsub( /[\200-\277]/, "", line ) ; astral = gsub( /[\360-\367]/, "", line ) ; n += length( line ) + 2 * astral + 1 } END { print n - 1 }' "$1" ; }
rigLongCount=300
rigLong="$rigTmp/lines.long"
LC_ALL=C awk -v total="$rigLongCount" 'BEGIN { for ( n = 1 ; n <= total ; n++ ) { printf "2030-01-01T00:%02d:%02dZ TOOL Read path=/a/long/enough/path/file-number-%03d.md -> ok 10B/1L 1ms\n", 5 + int( n / 60 ), n % 60, n ; if ( n % 25 == 0 ) printf "2030-01-01T00:%02d:%02dZ VERDICT item=rig-item-%03d by=magic-tester text=\"accepted\"\n", 5 + int( n / 60 ), n % 60, n } }' > "$rigLong"
rigRender feed "$rigTmp/k-long" "$rigLong"
rigCheckOver=0 ; rigCheckHead=0 ; rigCheckFence=0
for rigCheckPost in "$rigTmp/k-long"/* ; do
	[ "$( rigChars "$rigCheckPost" )" -le 4000 ] || rigCheckOver=$(( rigCheckOver + 1 ))
	[ -n "$( head -1 "$rigCheckPost" | rigHeaders )" ] || rigCheckHead=$(( rigCheckHead + 1 ))
	[ "$( LC_ALL=C grep -c -F '```' "$rigCheckPost" )" = 0 ] || rigCheckFence=$(( rigCheckFence + 1 ))
done
rigAssert "several posts" "$( [ "$( rigPostCount "$rigTmp/k-long" )" -gt 2 ] && printf yes || printf no )" yes
rigAssert "none over 4000 characters, each opening with its block's header, none with a code fence" "$rigCheckOver:$rigCheckHead:$rigCheckFence" 0:0:0
rigAssert "the operations, joined again, are every one given, in order, once" \
	"$( LC_ALL=C awk 1 "$rigTmp/k-long"/* | LC_ALL=C grep -o -e 'file-number-[0-9]*' -e 'rig-item-[0-9]*' | LC_ALL=C sed -e 's/^file-number-0*//' -e 's/^rig-item-0*/v/' | LC_ALL=C tr '\n' ' ' )" \
	"$( LC_ALL=C awk -v total="$rigLongCount" 'BEGIN { for ( n = 1 ; n <= total ; n++ ) { printf "%d ", n ; if ( n % 25 == 0 ) printf "v%d ", n } }' )"
rigAssert "and nothing else: one line per operation, besides the headers and the empty line before each" \
	"$( LC_ALL=C awk 1 "$rigTmp/k-long"/* | LC_ALL=C grep -c -v -e '^👤 ' -e '^🧵 session ' -e '^⚙️ system' -e '^$' )" "$(( rigLongCount + rigLongCount / 25 ))"
rigCheckBad=0
for rigCheckPost in "$rigTmp/k-long"/* ; do [ "$( rigBlankCheck "$rigCheckPost" | LC_ALL=C cut -d: -f2 )" = 0 ] || rigCheckBad=$(( rigCheckBad + 1 )) ; done
rigAssert "cut into posts, each still opens with its header, an empty line only before its later ones" "$rigCheckBad" 0
## Characters, not bytes: 40 lines of two-byte letters are about 3100 characters and 5500 bytes.
rigWide="$rigTmp/lines.wide"
rigWideLine="housekeeping: $( LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 60 ; n++ ) printf "\321\217" }' )"
for rigN in $( seq 1 40 ) ; do printf '%s\n' "$rigWideLine" ; done > "$rigWide"
rigRender feed "$rigTmp/k-wide" "$rigWide"
rigAssert "counted in characters: over 4000 bytes and under 4000 characters is one post" \
	"$( rigPostCount "$rigTmp/k-wide" ):$( [ "$( LC_ALL=C wc -c < "$rigTmp/k-wide/000001" | tr -d ' ' )" -gt 4000 ] && printf over || printf under ):$( [ "$( rigChars "$rigTmp/k-wide/000001" )" -le 4000 ] && printf within || printf over )" \
	"1:over:within"
for rigN in $( seq 1 20 ) ; do printf '%s\n' "$rigWideLine" ; done >> "$rigWide"
rigRender feed "$rigTmp/k-wide" "$rigWide"
rigAssert "control: 60 such lines, over 4000 characters, are two posts, each within" \
	"$( rigPostCount "$rigTmp/k-wide" ):$( for rigCheckPost in "$rigTmp/k-wide"/* ; do [ "$( rigChars "$rigCheckPost" )" -le 4000 ] && printf within || printf over ; printf ' ' ; done )" "2:within within "
echo "-- the knobs are gone: the chunk size and the poll interval are fixed in code --"
head -40 "$rigWide" > "$rigTmp/lines.wide40"
MDAT_EVENT_TRACK_CHUNK_BYTES=300 rigRender feed "$rigTmp/k-wide" "$rigTmp/lines.wide40"
rigAssert "MDAT_EVENT_TRACK_CHUNK_BYTES changes nothing: still one post" "$( rigPostCount "$rigTmp/k-wide" )" 1
rigAssert "neither knob is read anywhere in sh-lib" \
	"$( LC_ALL=C grep -r -l -e 'MDAT_EVENT_TRACK_CHUNK_BYTES' -e 'MDAT_EVENT_TRACK_POLL_SECONDS' -e 'ETP_CAP' "$rigLib" | LC_ALL=C awk 'END { print NR }' )" 0
rigAssert "the feed polls every 4 s: with the 5 s window, under 10 s from a line to its send" \
	"$( LC_ALL=C grep -c -e '^	local runFeed .* runPoll=4 ' "$rigLib/AgentsTools.EventTrackFeed.include" )" 1

## ---------------------------------------------------------------------------
echo "-- the feed ends a post right after an immediate line, and sends its posts in order --"
## ---------------------------------------------------------------------------
. "$rigLib/AgentsTools.EventTrackFeed.include"
rigPlan(){ ## all (1|0), lines... -- the planner's posts and open post, marks as #POST and #OPEN, lines as their third word
	local planAll="$1"
	shift
	printf '2030-01-01T00:00:00Z %s\n' "$@" | ETF_ALL="$planAll" LC_ALL=C awk -f "$rigLib/AgentsEventTrackFeedPlan.awk" \
		| LC_ALL=C tr '\001' '#' | LC_ALL=C awk '/^#/ { printf "%s ", $0 ; next } { printf "%s ", $2 }'
}
rigAssert "ordinary lines stay in the open post" "$( rigPlan 0 'TOOL Read path=/x -> ok' 'ROUND n=1' 'VERDICT item=x' )" '#OPEN TOOL ROUND VERDICT '
rigAssert "an immediate line ends the post right after it: the lines before it go with it, the ones after stay open" \
	"$( rigPlan 0 'TOOL Read path=/x -> ok' 'TOOL Edit path=/x -> refused "x"' 'TOOL Glob pattern=* -> ok' )" '#POST TOOL TOOL #OPEN TOOL '
rigAssert "fixed in code: errors, refusals and session events end a post; nothing else does" \
	"$( for rigKind in 'ERROR source=cli' 'TOOL Read -> error "x"' 'TOOL Edit -> refused "x"' 'RESULT outcome=error' 'START session=x' 'END outcome=failed' 'MODEL model=m' 'RESTART n=1' 'HANDBACK to=x' 'DISMISSED' 'ENDING item=x' \
		'TOOL Read -> ok' 'ROUND n=1' 'FINAL' 'RESULT outcome=ok' 'REVIEW item=x' 'VERDICT item=x' 'NOTE by=x' 'MSG-OUT to=x' 'WAIT-RESULT' ; do
		rigGot="$( rigPlan 0 "$rigKind" )" ; [ "${rigGot#\#POST}" != "$rigGot" ] && printf 'now ' || printf 'open ' ; done )" \
	'now now now now now now now now now now now open open open open open open open open open '
MDAT_EVENT_TRACK_BATCH_SECONDS=1 MDAT_EVENT_TRACK_IMMEDIATE_KINDS=ROUND
rigAssert "the knobs are gone: MDAT_EVENT_TRACK_IMMEDIATE_KINDS changes nothing" "$( rigPlan 0 'ROUND n=1' )" '#OPEN ROUND '
unset MDAT_EVENT_TRACK_BATCH_SECONDS MDAT_EVENT_TRACK_IMMEDIATE_KINDS
rigAssert "a call is one unit: a handback's TOOL line goes with it" \
	"$( rigPlan 0 'TOOL Read -> ok' 'TOOL SubagentHandback to=x -> ok' 'HANDBACK to=x' )" '#POST TOOL TOOL HANDBACK #OPEN '
rigAssert "a failed ask takes its ASK and ANSWER with it" \
	"$( rigPlan 0 'TOOL AskUserQuestion to=x -> error "e"' 'ASK to=x' 'ANSWER' 'TOOL Read -> ok' )" '#POST TOOL ASK ANSWER #OPEN TOOL '
rigAssert "with all, the open post goes too" "$( rigPlan 1 'TOOL Read -> ok' 'ROUND n=1' )" '#POST TOOL ROUND #OPEN '
## Every send recorded, begun and ended, its lines kept: the order and one at a time show.
rigSends="$rigTmp/sends"
: > "$rigSends"
AgentsEventTrackFeedSend(){ { printf 'BEGIN %s %s %s\n' "$1" "$2" "$3" ; cat ; } >> "$rigSends" ; sleep 1 ; printf 'END\n' >> "$rigSends" ; }
rigFeedIn="$( printf '2030-01-01T00:06:%02dZ %s\n' 1 'TOOL Read path=/x/1 -> ok' 2 'NOTE by=x' 3 'TOOL Edit path=/x/3 -> error "e"' 4 'TOOL Read path=/x/4 -> ok' \
	5 'HANDBACK to=x' 6 'TOOL Read path=/x/6 -> ok' 7 'ROUND n=7' )"
rigOpen="$( AgentsEventTrackFeedPost magic-tester "CRIG:9.9" "$rigFeedIn" rig-sid 0 )"
rigAssert "two posts, each ending at its immediate line; the rest stays open" \
	"$( LC_ALL=C grep -c '^BEGIN magic-tester CRIG:9.9 rig-sid$' "$rigSends" ):$( printf '%s\n' "$rigOpen" | LC_ALL=C awk '{ print $1 }' | LC_ALL=C tr '\n' ' ' )" \
	'2:2030-01-01T00:06:06Z 2030-01-01T00:06:07Z '
rigAssert "one at a time: each send ends before the next begins" "$( LC_ALL=C awk '{ print $1 }' "$rigSends" | LC_ALL=C grep -e '^BEGIN$' -e '^END$' | LC_ALL=C tr '\n' ' ' )" 'BEGIN END BEGIN END '
rigAssert "strict order: what was sent, then what stays open, is every line given, in order, once" \
	"$( { LC_ALL=C grep -v -e '^BEGIN ' -e '^END$' "$rigSends" ; printf '%s\n' "$rigOpen" ; } | cksum )" "$( printf '%s\n' "$rigFeedIn" | cksum )"
## The real send, its op a fake: what the feed hands the post op.
. "$rigLib/AgentsTools.EventTrackFeed.include"
cat > "$rigTmp/fake-tools" <<'RIG_FAKE_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RIG_ARGS"
cat > /dev/null
RIG_FAKE_EOF
chmod +x "$rigTmp/fake-tools"
agentsEventTrackFeedTools="$rigTmp/fake-tools"
RIG_ARGS="$rigTmp/send.args" ; export RIG_ARGS
AgentsEventTrackFeedPost magic-tester "CRIG:9.9" "$rigFeedIn" rig-sid 1 > /dev/null
rigAssert "every feed post goes to the post op as a new feed post, never an edit" \
	"$( LC_ALL=C grep -c -x -F -e '--intern-op-event-track-post magic-tester CRIG:9.9 --kind feed --session-id rig-sid --from-stdin' "$rigTmp/send.args" ):$( LC_ALL=C grep -c -e '--update' "$rigTmp/send.args" )" 3:0

## ---------------------------------------------------------------------------
echo "-- the op posts through the shared Slack call, offline --"
## ---------------------------------------------------------------------------
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/data" "$rigTmp/home" "$rigTmp/scenario"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
## A Slack-shaped curl: logs each method, keeps each body, answers by method; a scenario file
## makes the next call (ratelimit-once) or a numbered call (ratelimit-call) rate-limited, with
## status and Retry-After where -D names a file, or every post refused.
cat > "$rigTmp/bin/curl" <<'RIGEOF'
#!/usr/bin/env bash
set -u
cat > /dev/null
rigMethod="no-method" rigBody="" rigHeaders="" rigPrev=""
for rigArg in "$@" ; do
	case "$rigPrev" in -D) rigHeaders="$rigArg" ;; esac
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
		@-) ;;
		@*) rigBody="${rigArg#@}" ;;
	esac
	rigPrev="$rigArg"
done
printf '%s\n' "$rigMethod" >> "$RIG_SCENARIO/calls"
rigCallNo="$( awk 'END { print NR }' "$RIG_SCENARIO/calls" )"
if [ -f "$RIG_SCENARIO/ratelimit-once" ] || { [ -f "$RIG_SCENARIO/ratelimit-call" ] && [ "$( cat "$RIG_SCENARIO/ratelimit-call" )" = "$rigCallNo" ] ; } ; then
	rm -f "$RIG_SCENARIO/ratelimit-once"
	[ -z "$rigHeaders" ] || printf 'HTTP/2 429\r\nretry-after: 1\r\n\r\n' > "$rigHeaders"
	printf '{"ok":false,"error":"ratelimited"}\n'
	exit 0
fi
[ -z "$rigHeaders" ] || printf 'HTTP/2 200\r\n\r\n' > "$rigHeaders"
case "$rigMethod" in
	chat.postMessage|chat.update)
		if [ -f "$RIG_SCENARIO/refuse" ] ; then printf '{"ok":false,"error":"channel_not_found"}\n' ; exit 0 ; fi
		rigN=$(( $( cat "$RIG_SCENARIO/posts" 2>/dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigN" > "$RIG_SCENARIO/posts"
		[ -z "$rigBody" ] || cp "$rigBody" "$RIG_SCENARIO/post.$rigN"
		printf '{"ok":true,"channel":"CRIGTRACK","ts":"1700000001.%06d","message":{"ts":"1700000001.%06d"}}\n' "$(( 100 + rigN ))" "$(( 100 + rigN ))"
	;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
RIGEOF
chmod +x "$rigTmp/bin/curl"
rigOp(){ ## stdin file, op arguments... -- stdout to op.out, stderr to op.err, rc to rigOpRc
	local opIn="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigTmp" \
		MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-sender-session RIG_SCENARIO="$rigTmp/scenario" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" < "$opIn" > "$rigTmp/op.out" 2> "$rigTmp/op.err"
	rigOpRc=$?
}
rigReset(){ rm -f "$rigTmp/scenario"/* ; }
rigCalls(){ LC_ALL=C grep -c -x -F "$1" "$rigTmp/scenario/calls" 2>/dev/null || : ; }
rigLog(){ cat "$rigTmp/ws/.local/agents"/comms-slack-send.*.log 2>/dev/null ; }
rigLines="$rigTmp/lines"
printf '%s\n' '2030-01-01T00:01:00Z TOOL Read path=/x/the-file.md -> ok 3B/1L 2ms' '2030-01-01T00:01:02Z ROUND n=4 in=1 cache-read=2 cache-write=0 out=3' > "$rigLines"

rigReset
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind feed --session-id abcdef01-2345 --from-stdin
rigAssert "a feed post succeeds"                         "$rigOpRc" 0
rigAssert "one chat.postMessage, no edit, and no addressee lookup" "$( rigCalls chat.postMessage ):$( rigCalls chat.update ):$( rigCalls conversations.info ):$( rigCalls auth.test )" 1:0:0:0
rigBody="$rigTmp/scenario/post.1"
rigAssert "to the event-track channel, top level"        "$( rigYes env LC_ALL=C grep -q -F '"channel":"CRIGTRACK","text":"' "$rigBody" ):$( rigYes env LC_ALL=C grep -q -F 'thread_ts' "$rigBody" )" yes:no
rigAssert "its text is the block: the member's header, then one line per operation" \
	"$( rigYes env LC_ALL=C grep -q -F '"text":"👤 *magic-tester* · 00:01:00–00:01:02 UTC\n📖 Read `the-file.md` → 3 B\n🧠 round 4 · in 1 · cache 2 · out 3"' "$rigBody" )" yes
rigAssert "no code fence, no raw line, no @here and no addressee line" \
	"$( LC_ALL=C grep -c -e '```' -e 'TOOL Read' -e '@here' -e '\\n→' "$rigBody" )" 0
rigAssert "the sender is named in its metadata, with the kind" "$( rigYes env LC_ALL=C grep -q -F '"metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-tester","tracking":"feed"}}' "$rigBody" )" yes
rigAssert "the post is reported as the member send reports one" "$( LC_ALL=C grep -c -e '^SENT_MESSAGE_CHANNEL=CRIGTRACK$' -e '^SENT_MESSAGE_TS=1700000001.000101$' "$rigTmp/op.err" )" 2
rigAssert "one ok line in the monthly send log, as the bot" "$( rigLog | LC_ALL=C awk -F'\t' '$2 == "magic-tester" && $3 == "event-track" && $4 == "CRIGTRACK" && $5 == "bot" && $6 == "ok" && $8 == "rig-sender-session" { n++ } END { print n + 0 }' )" 1

echo "-- a long post to a conversation threads its later parts under the first, in order --"
rigReset
rigOp "$rigLong" --intern-op-event-track-post magic-tester event-track --kind feed --session-id abcdef01-2345 --from-stdin
rigPosts="$( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 )"
rigAssert "several posts, no edit"                       "$rigOpRc:$( [ "$rigPosts" -gt 2 ] && printf yes || printf no ):$( rigCalls chat.update )" 0:yes:0
rigAssert "the first opens the thread, every later one is in it" \
	"$( rigYes env LC_ALL=C grep -q -F 'thread_ts' "$rigTmp/scenario/post.1" ):$( LC_ALL=C grep -l -F '"thread_ts":"1700000001.000101"' "$rigTmp/scenario"/post.[0-9]* | LC_ALL=C awk 'END { print NR }' )" "no:$(( rigPosts - 1 ))"
rigOrder(){ for rigN in $( seq 1 "$1" ) ; do LC_ALL=C grep -o 'file-number-[0-9]*' "$rigTmp/scenario/post.$rigN" ; done | LC_ALL=C sed 's/^file-number-0*//' | LC_ALL=C tr '\n' ' ' ; }
rigAssert "every operation posted once, in order"        "$( rigOrder "$rigPosts" )" "$( seq 1 "$rigLongCount" | LC_ALL=C tr '\n' ' ' )"

echo "-- a rate limit is waited out by the shared call, and the order holds --"
rigReset
: > "$rigTmp/scenario/ratelimit-once"
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind feed --from-stdin
rigAssert "two calls, one post"                          "$rigOpRc:$( rigCalls chat.postMessage ):$( cat "$rigTmp/scenario/posts" )" 0:2:1
rigAssert "the wait was said"                            "$( LC_ALL=C grep -c 'waiting 1s as Retry-After asks' "$rigTmp/op.err" )" 1
rigReset
printf '3' > "$rigTmp/scenario/ratelimit-call"
rigOp "$rigLong" --intern-op-event-track-post magic-tester event-track --kind feed --session-id abcdef01-2345 --from-stdin
rigPosts="$( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 )"
rigAssert "a part held back by Retry-After is posted once it may, the parts still in order" \
	"$rigOpRc:$( LC_ALL=C grep -c 'waiting 1s as Retry-After asks' "$rigTmp/op.err" ):$( rigOrder "$rigPosts" )" "0:1:$( seq 1 "$rigLongCount" | LC_ALL=C tr '\n' ' ' )"

echo "-- into a thread; and no post is ever edited: the op has no edit option --"
rigReset
rigOp /dev/null --intern-op-event-track-post magic-tester CRIGTRACK:1699999999.000001 --kind end --session-id abcdef01-2345 --field outcome=succeeded
rigAssert "a post into a thread names it"                "$rigOpRc:$( rigYes env LC_ALL=C grep -q -F '"thread_ts":"1699999999.000001"' "$rigTmp/scenario/post.1" )" 0:yes
rigReset
rigOp /dev/null --intern-op-event-track-post magic-tester CRIGTRACK:1699999999.000001 --kind start --session-id abcdef01-2345 --field cli=rig-cli --update
rigAssert "--update is refused as an unknown option, and no Slack call is made" \
	"$rigOpRc:$( LC_ALL=C grep -c -F 'invalid option: --update' "$rigTmp/op.err" ):$( [ -s "$rigTmp/scenario/calls" ] && printf called || printf none )" 1:1:none
rigAssert "no tracking-post path in sh-lib calls chat.update or passes --update" \
	"$( LC_ALL=C grep -l -e 'chat\.update' -e 'event-track-post.*--update' "$rigLib"/AgentsTools.InternOpEventTrackPost.include "$rigLib"/AgentsTools.InternOpAgentSpawnProxy.include "$rigLib"/AgentsTools.EventTrackFeed.include | LC_ALL=C awk 'END { print NR }' )" 0

echo "-- a refused post fails, said and logged --"
rigReset
: > "$rigTmp/scenario/refuse"
rigLogBefore="$( rigLog | LC_ALL=C awk 'END { print NR }' )"
rigOp "$rigLines" --intern-op-event-track-post magic-tester event-track --kind feed --from-stdin
rigAssert "the op fails with one ERROR line"             "$rigOpRc:$( LC_ALL=C grep -c '^⛔ ERROR: .*--intern-op-event-track-post: the feed post, part 1 of 1, was not posted' "$rigTmp/op.err" )" 1:1
rigAssert "and logs it failed"                           "$( rigLog | LC_ALL=C awk -F'\t' -v from="$rigLogBefore" 'NR > from && $6 == "failed" { n++ } END { print n + 0 }' )" 1

## ---------------------------------------------------------------------------
echo "-- a spawn announces itself once, resolved first; what comes later is a reply --"
## ---------------------------------------------------------------------------
## The console the proxy starts: the strings its vintage guard looks for, then a launch on
## the CLI RIG_LAUNCH_CLI names, which a real console would only do on a fallback.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) stand-in: launches RIG_LAUNCH_CLI.' \
	'cat > /dev/null' \
	'printf "%s\n" "${RIG_LAUNCH_CLI:-rig-cli}" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "📦 SubagentHandback\n"' > "$rigTmp/ws/DistroAgentsConsole.sh"
chmod +x "$rigTmp/ws/DistroAgentsConsole.sh"
printf 'RIG-SPAWN-BRIEF\n' > "$rigTmp/spawn.brief"
rigEnvFile="$rigTmp/ws/.local/.agents/magic-team.agent.env"
cp "$rigEnvFile" "$rigTmp/agent.env.base"
## No parent session: env -i, so the spawn is a lone one, and its session thread is its event-track thread.
## Given a parent spawn id and a session, it is spawned from that parent and joins that session instead.
rigSpawn(){ ## the CLI the stand-in launches[, parent spawn id, session id] -- stdout to op.out, stderr to op.err, rc to rigOpRc
	local spawnThreadArg="--session-thread:event-track"
	[ -z "${3:-}" ] || spawnThreadArg=""
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigTmp" \
		MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp/scenario" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_LAUNCH_CLI="$1" \
		RIG_THREAD_ARG="$spawnThreadArg" ${2:+"MDAT_SPAWN_SESSION_ID=$2"} ${3:+"MDAT_SESSION_ID=$3"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:none --wait ${RIG_THREAD_ARG:+"$RIG_THREAD_ARG"} --context rig-spawn-track
		' < "$rigTmp/spawn.brief" > "$rigTmp/op.out" 2> "$rigTmp/op.err"
	rigOpRc=$?
}
## The posts in the order they were made, one line each: n, thread_ts or "root", and its first label.
rigPostsMade(){
	local madeN madeTotal madeThread
	madeTotal="$( cat "$rigTmp/scenario/posts" 2>/dev/null || echo 0 )"
	for madeN in $( seq 1 "$madeTotal" ) ; do
		madeThread="$( LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigTmp/scenario/post.$madeN" | head -1 )"
		printf '%s %s %s\n' "$madeN" "${madeThread:-root}" \
			"$( LC_ALL=C grep -o -e '🚀 session start' -e '⚠️ notice' -e '🏁 session end' -e '📦 handback' "$rigTmp/scenario/post.$madeN" | head -1 | LC_ALL=C tr ' ' '_' )"
	done
}

rigReset
{ cat "$rigTmp/agent.env.base" ; printf 'SPAWN_CLI_SERVICE=rig-cli\n' ; } > "$rigEnvFile"
rigSpawn rig-cli
rigAssert "the spawn ran and launched"                    "$rigOpRc:$( LC_ALL=C grep -c '^LAUNCHED=true$' "$rigTmp/op.out" )" 0:1
rigAssert "one start post, the first post, a root, with the CLI resolved before it: no placeholder" \
	"$( rigPostsMade | LC_ALL=C awk '$3 == "🚀_session_start" { print $1 ":" $2 }' ):$( LC_ALL=C grep -l -F 'cli: configured' "$rigTmp/scenario"/post.[0-9]* 2>/dev/null | LC_ALL=C awk 'END { print NR }' )" "1:root:0"
rigAssert "it names the resolved CLI, how it runs, and everything else settled before it" \
	"$( rigYes env LC_ALL=C grep -q -F '\n🚀 session start\ncli: rig-cli · runs: native · wait: true\ndispatch: `none`\nspawn: ' "$rigTmp/scenario/post.1" ):$( rigYes env LC_ALL=C grep -q -F '\nsession thread: `this thread`\n' "$rigTmp/scenario/post.1" )" yes:yes
rigAssert "and leaves out what is not known, with no placeholder" "$( LC_ALL=C grep -c -e 'tier: -' -e 'routine: -' -e ': - ' "$rigTmp/scenario/post.1" )" 0
rigAssert "a compact root: each id its first 8 characters, no parent when there is none, no tracking name that is the session's own, no output, receipt or context" \
	"$( rigYes env LC_ALL=C grep -q -E '\\nspawn: `[0-9a-f]{8}` · session: `[0-9a-f]{8}`\\n' "$rigTmp/scenario/post.1" ):$( LC_ALL=C grep -c -e 'tracking: ' -e 'output: ' -e 'receipt: ' -e 'context: ' "$rigTmp/scenario/post.1" )" yes:0
rigAssert "no chat.update call is ever made"              "$( rigCalls chat.update )" 0
rigAssert "the launch agreed with it, so the only reply is the end post, in its thread" \
	"$( rigPostsMade | LC_ALL=C awk 'NR > 1 { printf "%s %s ", $2, $3 }' )" "1700000001.000101 🏁_session_end "

rigReset
{ cat "$rigTmp/agent.env.base" ; printf 'SPAWN_CLI_SERVICE=scaleway\nSPAWN_HARNESS_TIER=light\n' ; } > "$rigEnvFile"
rigSpawn rig-other
rigAssert "a harness leg: the start post says so, with its tier" \
	"$rigOpRc:$( rigYes env LC_ALL=C grep -q -F '\ncli: scaleway · runs: harness · tier: light · wait: true\n' "$rigTmp/scenario/post.1" )" 0:yes
rigAssert "a fact learned after the start (another CLI launched) is a reply in its thread, never an edit" \
	"$( rigCalls chat.update ):$( rigPostsMade | LC_ALL=C awk '$3 == "⚠️_notice" { print $2 }' ):$( rigYes env LC_ALL=C grep -q -F '⚠️ notice: launched on rig-other, not on scaleway as resolved for the start post' "$rigTmp/scenario/post.2" )" \
	"0:1700000001.000101:yes"
rigAssert "the root post comes before any reply: the start, then the launch fact, then the end, each later one in the root's thread" \
	"$( rigPostsMade | LC_ALL=C awk '{ printf "%s %s %s; ", $1, $2, $3 }' )" \
	"1 root 🚀_session_start; 2 1700000001.000101 ⚠️_notice; 3 1700000001.000101 🏁_session_end; "

echo "-- a joining spawn's root names the parent only where it differs from the session --"
rigJoinSession="154edb9e-3291-4654-a4bf-c15968a2c588"
rigReset
{ cat "$rigTmp/agent.env.base" ; printf 'SPAWN_CLI_SERVICE=rig-cli\n' ; } > "$rigEnvFile"
rigSpawn rig-cli "$rigJoinSession" "$rigJoinSession"
rigAssert "spawned from the session's own spawn: the session, short, and no parent or tracking that only repeat it" \
	"$rigOpRc:$( rigYes env LC_ALL=C grep -q -E '\\nspawn: `[0-9a-f]{8}` · session: `154edb9e`\\n' "$rigTmp/scenario/post.1" ):$( LC_ALL=C grep -c -e 'parent: ' -e 'tracking: ' "$rigTmp/scenario/post.1" )" 0:yes:0
rigReset
rigSpawn rig-cli "3f2488f9-2c54-4b8c-9f92-f1e330e00d14" "$rigJoinSession"
rigAssert "spawned from another spawn in it: that parent is kept, short" \
	"$rigOpRc:$( rigYes env LC_ALL=C grep -q -E '\\nspawn: `[0-9a-f]{8}` · session: `154edb9e` · parent: `3f2488f9`\\n' "$rigTmp/scenario/post.1" )" 0:yes
cp "$rigTmp/agent.env.base" "$rigEnvFile"

echo "-- no request left for a real host --"
rigAssert "every call was a Slack method the fake answered" "$( cat "$rigTmp/scenario/calls" 2>/dev/null | LC_ALL=C grep -c -e '^url:' -e '^no-method$' || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EVENT TRACK POST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'EVENT_TRACK_POST: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
