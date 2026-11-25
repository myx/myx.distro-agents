#!/usr/bin/env bash
## Behavioural check on `--confluence-page-render`, `--confluence-page-update --if-version` and
## `--google-doc-replace`: the render's determinism, its one-line change, its hand-edit report, and
## the two guards around a whole-body write. Every page read and every HTTP call is faked, so no
## socket is opened and no page is written.
##
## Held, in this order:
##  1. the green direction first: two renders of one source are byte-identical, so a difference
##     printed later is the change and not a render that never settles
##  2. one changed source line changes exactly one rendered line
##  3. the hand-edit report, both ways: a page carrying one extra line is reported and exits 1, and a
##     page differing only by the attributes a save adds is reported clean
##  4. a heading that is not in the source, and a source that does not resolve: each fails loudly and
##     prints no body
##  5. `--if-version`: a page that moved is a CONFLICT with nothing sent, and one that did not is
##     written against the version read
##  6. `--google-doc-replace`: the body is replaced in one batch that deletes then inserts, against
##     the revision that was read, and an empty body is refused
##  7. both operation names answer on their own roster, and `--if-version` is named there
##  8. an evidence mark with a detail, and a parenthetical naming a resolver list, render italic, and
##     a numbered run renders as an ordered list whose numerals are not written as item text
##  9. a list item's text and a table cell's render inside a `<p>`, header cells included, the way a
##     live body holds them
##
## Red recipe: an engine that emits a timestamp fails arm 1 on the second render, a render arm that
## ignores `#<heading>` fails arm 4, a `--if-version` that trusts its caller fails arm 5's
## CONFLICT, an inline grammar with no italic construct fails arm 8, and a render that writes an
## item or a cell bare fails arm 9.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRender="$rigPkg/sh-lib/atlassian/AgentsTools.ConfluencePageRender.include"
rigEngine="$rigPkg/sh-lib/atlassian/AgentsConfluencePageRender.py"
rigRequest="$rigPkg/sh-lib/atlassian/AgentsTools.AtlassianRequest.include"
rigUpdate="$rigPkg/sh-lib/atlassian/AgentsTools.InternOpAtlassianConfluencePageUpdate.include"
rigGoogle="$rigPkg/sh-lib/google/AgentsGoogleApiCall.py"
for rigNeed in "$rigRender" "$rigEngine" "$rigRequest" "$rigUpdate" "$rigGoogle" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConfluencePageRenderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/.local/temp" || exit 1
MDSC_CMD='DistroAgentsAtlassian'

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The source under test: the shape a real page's source has, one construct per line of the kind the
## render turns into a block. The section is deliberately shorter than the whole document, so a
## render that ignores `#<heading>` fails arm 4.
rigSource="$rigTmp/source.md"
cat > "$rigSource" <<'EOF'
---
type: planning
---
# The document

This paragraph is outside the section, and belongs to no render of it.

## The section that is rendered

- the first bullet
- the second bullet

A paragraph naming [[RMM2 — the plan]] and a code word `page-render`.

An evidence mark [M: `a.json` and `b.json`] and a resolver mark (dev G12), beside a parenthetical that names no resolver list (living draft).

- 1. **The first area.** Its text.
- 2. **The second area.** Its text.

| What | Why |
| --- | --- |
| a row | because |
EOF

## One render: rc in rigRc, body in rigOut, diagnostics in rigErr.
rigRenderRun(){ ## spec...
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- "$@" ;
		. "$rigRender" ;
		AgentsToolsAtlassianConfluencePageRender --member magic-developer "$@"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}

## 1. THE GREEN DIRECTION FIRST. One source, rendered twice, is one body.
rigRenderRun --source "$rigSource#The section that is rendered"
rigAssert "arm 1: a render of a named section answers 0" "$rigRc" "0"
rigAssert "arm 1: the render carries its source line" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n '1p' )" "<p>Source: $rigSource</p>"
rigAssert "arm 1: the render names no reviewer, so a page it writes is unconfirmed" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n '2p' )" "<p>AI-generated — not yet reviewed</p>"
rigAssert "arm 1: the paragraph outside the section is not rendered" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'outside the section' || : )" "0"
cp "$rigTmp/out" "$rigTmp/render-first"
rigRenderRun --source "$rigSource#The section that is rendered"
rigAssert "arm 1: the second render answers 0" "$rigRc" "0"
rigAssert "arm 1: two renders of one source are byte-identical" \
	"$( cmp -s "$rigTmp/render-first" "$rigTmp/out" && echo identical || echo different )" "identical"
rigAssert "arm 1: the twice-render diff is empty" \
	"$( diff "$rigTmp/render-first" "$rigTmp/out" | wc -l | LC_ALL=C tr -d ' ' )" "0"

## 2. ONE SOURCE LINE CHANGED CHANGES ONE RENDERED LINE. The source keeps its own path and its
## content is edited in place, so the Source: line is unchanged and the edit is the only difference.
cp "$rigSource" "$rigTmp/source.orig"
LC_ALL=C sed 's/the second bullet/the second bullet, reworded/' "$rigTmp/source.orig" > "$rigSource"
rigRenderRun --source "$rigSource#The section that is rendered"
cp "$rigTmp/out" "$rigTmp/render-changed"
rigAssert "arm 2: the render of the changed source answers 0" "$rigRc" "0"
rigAssert "arm 2: the Source line is the same in both, so it is not the difference" \
	"$( diff "$rigTmp/render-first" "$rigTmp/render-changed" | LC_ALL=C grep -c 'Source:' || : )" "0"
rigAssert "arm 2: the change diffs exactly one line" \
	"$( diff "$rigTmp/render-first" "$rigTmp/render-changed" | LC_ALL=C grep -c '^>' || : )" "1"
rigAssert "arm 2: and one line leaves, so no line was inserted beside it" \
	"$( diff "$rigTmp/render-first" "$rigTmp/render-changed" | LC_ALL=C grep -c '^<' || : )" "1"
rigAssert "arm 2: the one changed line is the reworded bullet, and nothing else" \
	"$( diff "$rigTmp/render-first" "$rigTmp/render-changed" | LC_ALL=C grep -c '^[<>]' || : )" "2"
cp "$rigTmp/source.orig" "$rigSource"

## 3. THE HAND-EDIT REPORT, BOTH WAYS. The live body is faked, so the page is never read.
rigLive=""
AgentsToolsAtlassianConfluencePageRead(){ printf '%s' "$rigLive" ; return 0 ; }
rigLive="$( cat "$rigTmp/render-first" )
<p>A paragraph a person added to the page by hand.</p>"
rigRenderRun --source "$rigSource#The section that is rendered" --page-id 5000000001
rigAssert "arm 3: a hand-edited page exits 1, so a write cannot follow it unnoticed" "$rigRc" "1"
rigAssert "arm 3: the hand edit is reported, naming the line" \
	"$( printf '%s\n' "$rigErr" | LC_ALL=C grep -c 'HAND EDIT, only in the live page: <p>A paragraph a person added' || : )" "1"
rigAssert "arm 3: the body still prints, and only the report refuses" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'AI-generated' || : )" "1"
## The control, the other way: a page whose only difference is what a save adds is clean.
rigLive="$( printf '%s\n' "$( cat "$rigTmp/render-first" )" | LC_ALL=C sed 's|<p>Source:|<p local-id="a1b2">Source:|; s|ri:content-title="RMM2 — the plan" />|ri:content-title="RMM2 — the plan" ri:version-at-save="12" />|' )"
rigRenderRun --source "$rigSource#The section that is rendered" --page-id 5000000001
rigAssert "arm 3: a page differing only by local-id and a save pin is clean" "$rigRc" "0"
rigAssert "arm 3: the clean direction reports no hand edit" \
	"$( printf '%s\n' "$rigErr" | LC_ALL=C grep -c 'HAND EDIT' || : )" "0"

## 4. A SUBJECT IT CANNOT REACH FAILS LOUDLY AND PRINTS NO BODY.
rigRenderRun --source "$rigSource#A heading the source does not hold"
rigAssert "arm 4: an absent heading exits non-zero" "$rigRc" "1"
rigAssert "arm 4: an absent heading prints no body" "$rigOut" ""
rigAssert "arm 4: the refusal names the heading it could not reach" \
	"$( printf '%s\n' "$rigErr" | LC_ALL=C grep -c 'holds no heading' || : )" "1"
rigRenderRun --source "vault:no-such-vault-item-name"
rigAssert "arm 4: an unresolved source exits non-zero" "$rigRc" "1"
rigAssert "arm 4: an unresolved source prints no body" "$rigOut" ""

## 5. `--if-version`: the page is read, and a page that moved is a CONFLICT with nothing sent.
rigBody="$rigTmp/update.body" rigCalls="$rigTmp/update.calls"
## The gates around the transport are not what is under test here: the two writes are faked at the
## transport itself, so the bare-name check passes no scope is read. The include is sourced before the
## stubs because it is where the transport function is defined.
. "$rigRequest"
AgentsToolsAssertBareName(){ return 0 ; }
rigLiveVersion=""
AgentsToolsAtlassianConfluencePageRead(){ printf '# page 5000000002: title=fake version=%s spaceId=1 format=storage\n' "$rigLiveVersion" >&2 ; return 0 ; }
AgentsToolsAtlassianCall(){ printf '%s %s\n' "$3" "$4" >> "$rigCalls" ; printf '%s' "$6" > "$rigBody" ; return 0 ; }
rigUpdateRun(){ ## version args...
	rigRc=0 rigOut="" rigErr=""
	: > "$rigBody" ; : > "$rigCalls"
	rigErr="$( rigUpdateCall "$@" 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}
## The operation's include declares locals, so it is sourced inside a function with its own name in $1.
rigUpdateCall(){ ## version args...
	set -- --intern-op-atlassian-confluence-page-update --member magic-developer --page-id 5000000002 --title 'RMM2 — the plan' --status current --body-storage '<p>x</p>' "$@"
	. "$rigUpdate"
}
rigLiveVersion=12
rigUpdateRun --if-version 12
rigAssert "arm 5: a page still at the read version answers 0" "$rigRc" "0"
rigAssert "arm 5: it writes exactly one PUT to that page" \
	"$( LC_ALL=C grep -c '^PUT /wiki/api/v2/pages/5000000002$' "$rigCalls" || : )" "1"
rigAssert "arm 5: the version submitted is the read one plus one" \
	"$( LC_ALL=C grep -c '"version":{"number":13}' "$rigBody" || : )" "1"
rigLiveVersion=13
rigUpdateRun --if-version 12
rigAssert "arm 5: a page that moved is CONFLICT, exit 10" "$rigRc" "10"
rigAssert "arm 5: a CONFLICT sends nothing at all" "$( wc -l < "$rigCalls" | LC_ALL=C tr -d ' ' )" "0"
rigAssert "arm 5: the CONFLICT names both versions" \
	"$( printf '%s\n' "$rigErr" | LC_ALL=C grep -c 'CONFLICT -- --if-version is 12 and the page stands at 13' || : )" "1"
## The guard is the caller's number, not a second read of its own: a plain --version still writes.
rigLiveVersion=13
rigUpdateRun --version 13
rigAssert "arm 5: plain --version still writes, so the guard is the new form alone" "$rigRc" "0"

## 6. `--google-doc-replace`: one batch, delete then insert, against the revision read.
cat > "$rigTmp/driver.py" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("worker", sys.argv[1])
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)
worker.exchange_refresh_token = lambda a, b, c: "token"
worker.api_get = lambda token, url, question: {
    "revisionId": "rev-7", "body": {"content": [{"endIndex": 1}, {"endIndex": 26}]}}
def api_send(token, url, payload, question, method=None):
    sys.stderr.write("SENT %s\n" % json.dumps(payload))
    return {"writeControl": {"requiredRevisionId": "rev-8"}}
worker.api_send = api_send
worker.main()
PY
rigGoogleRun(){ ## body file
	rigRc=0
	AGENTS_GOOGLE_CLIENT_ID=cid AGENTS_GOOGLE_CLIENT_SECRET=csecret AGENTS_GOOGLE_REFRESH_TOKEN=rtoken \
	AGENTS_GOOGLE_OP=doc-replace AGENTS_GOOGLE_DOC_ID=doc-1 \
	python3 "$rigTmp/driver.py" "$rigGoogle" < "$1" > "$rigTmp/google.out" 2> "$rigTmp/google.err" || rigRc=$?
}
printf 'The replacement body.\n' > "$rigTmp/body.txt"
rigGoogleRun "$rigTmp/body.txt"
rigAssert "arm 6: a replace answers 0" "$rigRc" "0"
rigAssert "arm 6: one batch is sent" \
	"$( LC_ALL=C grep -c '^SENT ' "$rigTmp/google.err" || : )" "1"
rigAssert "arm 6: the batch deletes the old body before it inserts the new one" \
	"$( LC_ALL=C grep -c '"requests": \[{"deleteContentRange": {"range": {"startIndex": 1, "endIndex": 25}}}, {"insertText": {"location": {"index": 1}' "$rigTmp/google.err" || : )" "1"
rigAssert "arm 6: the write is pinned to the revision that was read" \
	"$( LC_ALL=C grep -c '"writeControl": {"requiredRevisionId": "rev-7"}' "$rigTmp/google.err" || : )" "1"
: > "$rigTmp/empty.txt"
printf '   \n\n' > "$rigTmp/blank.txt"
rigGoogleRun "$rigTmp/blank.txt"
rigAssert "arm 6: a body of spaces and newlines alone is refused, not written" "$rigRc" "1"
rigAssert "arm 6: the refusal says nothing was written" \
	"$( LC_ALL=C grep -c 'nothing was written' "$rigTmp/google.err" || : )" "1"
rigAssert "arm 6: and nothing was sent" \
	"$( LC_ALL=C grep -c '^SENT ' "$rigTmp/google.err" || : )" "0"
rigGoogleRun "$rigTmp/empty.txt"
rigAssert "arm 6: no body at all is refused too" "$rigRc" "1"

## 7. BOTH NAMES ANSWER, AND THE GUARD IS NAMED ON THE ROSTER THE COORDINATOR READS.
rigTab=$'\t'
rigAssert "arm 7: the render names itself on the Atlassian roster" \
	"$( LC_ALL=C grep -c -- 'DistroAgentsAtlassian.fn.sh --confluence-page-render \[--team-member <team-member>\] --source <spec>' "$rigPkg/sh-lib/help/Help.DistroAgentsAtlassian.help.md" || : )" "1"
rigAssert "arm 7: the page update names --if-version on its own syntax line" \
	"$( LC_ALL=C grep -c -- '--confluence-page-update \[--team-member <team-member>\] <page-id> (--version <n>|--if-version <n>)' "$rigPkg/sh-lib/help/Help.DistroAgentsAtlassian.help.md" || : )" "1"
rigAssert "arm 7: the replace names itself on the Google roster" \
	"$( LC_ALL=C grep -c -- 'DistroAgentsGoogle.fn.sh --google-doc-replace \[--team-member <team-member>\] <doc-id> (--from-stdin|--from-file <path>)' "$rigPkg/sh-lib/help/Help.DistroAgentsGoogle.help.md" || : )" "1"
rigAssert "arm 7: the render is registered as a member operation" \
	"$( LC_ALL=C grep -c -- "DistroAgentsAtlassian${rigTab}--confluence-page-render${rigTab}member" "$rigPkg/sh-lib/harness/AgentsContext.FrontTable.include" || : )" "1"
rigAssert "arm 7: the replace is registered as a member operation" \
	"$( LC_ALL=C grep -c -- "DistroAgentsGoogle${rigTab}--google-doc-replace${rigTab}member" "$rigPkg/sh-lib/harness/AgentsContext.FrontTable.include" || : )" "1"

## 8. THE EVIDENCE MARK AND THE NUMBERED LIST. The page's italic runs are an evidence mark with a
## detail, and a parenthetical naming a resolver list. Its numbered run is an ordered list, whose
## numerals the list carries and the item text does not.
rigRenderRun --source "$rigSource#The section that is rendered"
rigAssert "arm 8: the render of the mark fixture answers 0" "$rigRc" "0"
rigAssert "arm 8: an evidence mark renders italic, broken at each code span as the page has it" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<em>\[M: </em><code>a.json</code><em> and </em><code>b.json</code><em>\]</em>' || : )" "1"
rigAssert "arm 8: a resolver parenthetical renders italic, as one run" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<em>(dev G12)</em>' || : )" "1"
rigAssert "arm 8: a parenthetical naming no resolver list is rendered" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '(living draft)' || : )" "1"
rigAssert "arm 8: and that one carries no italic at all, so the construct is the mark alone" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<em>(living draft)</em>' || : )" "0"
rigAssert "arm 8: a numbered run renders as an ordered list" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<ol start="1"><li><p><strong>The first area.</strong> Its text.</p></li><li><p><strong>The second area.</strong> Its text.</p></li></ol>' || : )" "1"
rigAssert "arm 8: the item numerals are the list's, and not the item's text" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<li>1\. ' || : )" "0"
rigAssert "arm 8: the bullets beside it stay an unordered list" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '<ul><li><p>the first bullet</p></li>' || : )" "1"

## 9. THE PARAGRAPH INSIDE AN ITEM AND A CELL. A live body holds an item's text inside a `<p>`, and a
## cell's text too, header cells included, so a render that writes them bare reshapes the page when its
## body is written. Each arm counts what the render holds against what it wraps, so a rig that reached
## no item and no cell fails rather than passes.
rigRenderRun --source "$rigSource#The section that is rendered"
rigAssert "arm 9: the render of the item and cell fixture answers 0" "$rigRc" "0"
rigAssert "arm 9: the four items the fixture holds are in the render, each inside a paragraph" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<li>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<li><p>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "4:4"
rigAssert "arm 9: both header cells are in the render, each inside a paragraph" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<th>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<th><p>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "2:2"
rigAssert "arm 9: both body cells are in the render, each inside a paragraph" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<td>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -o -F '<td><p>' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "2:2"

printf '\n%s assertion(s) failed of %s\n' "$rigFail" "$(( rigPass + rigFail ))"
[ "$rigFail" -eq 0 ] || exit 1
exit 0
