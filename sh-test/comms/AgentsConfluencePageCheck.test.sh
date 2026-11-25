#!/usr/bin/env bash
## Behavioural check on `--confluence-page-check`: the mechanical page rules of the documentation
## convention, over fixtures shaped like the real bodies, with a fake read and a fake space listing.
## No socket is opened, and no page is read or written.
##
## Held, in this order:
##  1. the green direction: a corrected page passes every rule, so a row printed later is the rule
##     firing and not the check refusing everything
##  2. the archive and the Russian older bodies, which the check must name red, rule by rule
##  3. a planted secret-shaped string on an otherwise green page, which only R11 may catch
##  4. one refusing arm per remaining rule: R4, R8, R9, R13, and a page that cannot be read
##  5. the default page set: no id and no setting is rc 6, naming the setting
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigCheckInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.ConfluencePageCheck.include"
rigEngine="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsConfluencePageCheck.py"
rigHelp="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsAtlassian.help.md"
for rigNeed in "$rigCheckInc" "$rigEngine" "$rigHelp" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConfluencePageCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPages="$rigTmp/pages" ; mkdir -p "$rigPages"
MDSC_CMD='DistroAgentsAtlassian'

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## The rules a run named for one page, in row order, space-separated: what the row set says about it.
rigRules(){ ## page id, the run's rows
	printf '%s\n' "$2" | LC_ALL=C awk -F'\t' -v id="$1" '$1 == id { printf "%s ", $2 }' | LC_ALL=C tr -s ' '
}

## The fake read: fixture header on stderr, fixture body on stdout, the way the real read answers,
## and a page with no fixture answers 8, the transport's own code for a 404.
AgentsToolsAtlassianConfluencePageRead(){
	local fakeId=""
	while [ $# -gt 0 ] ; do
		case "$1" in
			--page-id) fakeId="$2" ; shift 2 ;;
			*) shift ;;
		esac
	done
	[ -f "$rigPages/$fakeId.body" ] || { printf '%s\n' "🙋 WARNING: fake read: 404" >&2 ; return 8 ; }
	cat "$rigPages/$fakeId.head" >&2
	cat "$rigPages/$fakeId.body"
	return 0
}
## The fake space listing: every title R9 may compare a pin against, at its current version.
AgentsToolsAtlassianCall(){
	printf '{"results":['
	printf '{"title":"RMM 2","version":{"number":6}},'
	printf '{"title":"RMM2 rebuild","version":{"number":6}},'
	printf '{"title":"RMM2 \\u2014 the plan","version":{"number":12}},'
	printf '{"title":"Keenetic RMM 2 \\u2014 backend implementation requirements (living draft)","version":{"number":18}},'
	printf '{"title":"RMM2 backend \\u2014 implementation requirements (English translation of v0.9)","version":{"number":3}}'
	printf ']}'
	return 0
}
## One fixture page: id, title, version, then the body on stdin.
rigPage(){ ## id, title, version
	printf '# page %s: title=%s version=%s spaceId=4690313249 format=storage\n' "$1" "$2" "$3" > "$rigPages/$1.head"
	cat > "$rigPages/$1.body"
}
## One run of the check: rc in rigRc, rows in rigOut, notices in rigErr.
rigRun(){
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- "$@" ;
		. "$rigCheckInc" ;
		AgentsToolsAtlassianConfluencePageCheck "$@"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}

## 1. THE GREEN DIRECTION FIRST. A corrected page satisfies all eleven rules the check enforces.
rigPage 5000000001 'RMM2 — the plan' 12 <<'EOF'
<p><strong>Source:</strong> the RMM2 plan, held in the project's own repository.</p>
<p>Source: rmm2/docs/plan.md</p>
<p>AI-generated — reviewed by Anna Petrova</p>
<p>Status: LIVING</p>
<p>Type: plan</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<ul><li>the store is chosen first</li><li>the cutover is one step</li><li>the frontend is untouched</li></ul>
<h2>What the plan rests on</h2>
<p>The product that runs today is the authority, and every stage is proved against it.</p>
<p>See <ac:link><ri:page ri:content-title="RMM 2" ri:version-at-save="6" /><ac:link-body>the landing</ac:link-body></ac:link> for the people.</p>
<h2>Change log</h2>
<p>2026-11-20, v11, first published</p>
<p>2026-11-23, v12, split the requirements</p>
EOF
rigPage 5000000002 'RMM 2' 6 <<'EOF'
<p>Source: rmm2/docs/landing.md</p>
<p>AI-generated — not yet reviewed</p>
<p>Status: DRAFT</p>
<p>Type: landing</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
<h2>Where the work stands</h2>
<p>Nothing here is settled yet, and the plan beside this page says why.</p>
<h2>Change log</h2>
<p>2026-11-23, v6, the third revision</p>
EOF
rigRun --member magic-developer 5000000001 5000000002
rigAssert "a corrected page prints no row" "$rigOut" ""
rigAssert "and the green run exits 0" "$rigRc" "0"

## 2. THE TWO OLDER BODIES, shaped as they stand: no source, no review state, no header block,
## an approval block on a record, Slack identifiers and member names, and a stale pin.
rigPage 4861362189 'RMM2 — research archive v0.11 (evidence)' 3 <<'EOF'
<p><strong>Archived research draft.</strong> This is v0.11 of the RMM2 requirements page, kept word for word because the requirements page was restructured on 2026-11-03.</p>
<p>This archive merges three drafts: magic-architect's, magic-developer's and magic-librarian's.</p>
<p>The owner's instruction of <code>D0BT7S5M7N2:1793612567.067789</code> is what moved it here.</p>
<h2>0. Status and how to read this</h2>
<p>Every statement carries one of three marks.</p>
<p>See <ac:link><ri:page ri:content-title="RMM 2" ri:version-at-save="2" /><ac:link-body>RMM 2</ac:link-body></ac:link> for the section front page.</p>
<h2>Owner and approval</h2>
<table><tbody><tr><th>Owner</th><td>Alex Kharichev.</td></tr><tr><th>Confirmed by</th><td>Alex Kharichev.</td></tr><tr><th>Confirmation record</th><td>Empty.</td></tr></tbody></table>
<h2>RMM 2 pages</h2>
<ul><li>the section front page</li></ul>
EOF
rigPage 4861198339 'RMM2 backend — требования к реализации (перевод v0.9)' 1 <<'EOF'
<h1>RMM2 backend — требования к реализации, объединённый черновик v0.9</h1>
<p>Это единственный документ по бэкенду RMM2. Он объединяет три черновика: magic-architect, magic-developer и magic-librarian.</p>
<p>Указание владельца <code>C0C4DLJJ4F7:1793692249.984859</code> перенесло страницу сюда.</p>
<ul><li>[M] измерено</li><li>[D] документ</li><li>[I] вывод</li></ul>
<h2>1. Решения владельца на сегодня</h2>
<p>Каждое закрывает пробел.</p>
<h2>11. Журнал правок</h2>
<p>v0.9, 2026-11-03 09:55 +0200: страница перенесена в собственное пространство команды MAGIC.</p>
EOF
rigRun --member magic-developer 4861362189 4861198339
rigAssert "the archive is red, and the rules it fails are named" "$( rigRules 4861362189 "$rigOut" )" "R1 R2 R3 R4 R5 R9 R10 R13 "
rigAssert "the Russian body is red, and its own rules are named" "$( rigRules 4861198339 "$rigOut" )" "R1 R2 R3 R5 R10 "
rigAssert "and the red run exits non-zero" "$rigRc" "1"
case "$rigOut" in
	*"magic-architect"*) rigAssert "the archive row names the member it mentions" yes yes ;;
	*) rigAssert "the archive row names the member it mentions" "$rigOut" "a row naming magic-architect" ;;
esac
case "$rigOut" in
	*"D0BT7S5M7N2:1793612567.067789"*) rigAssert "and the Slack identifier it carries" yes yes ;;
	*) rigAssert "and the Slack identifier it carries" "$rigOut" "a row naming the Slack identifier" ;;
esac
case "$rigOut" in
	*"RMM 2 v2 of v6"*) rigAssert "the archive's stale pin is named with both versions" yes yes ;;
	*) rigAssert "the archive's stale pin is named with both versions" "$rigOut" "a row naming RMM 2 v2 of v6" ;;
esac

## 3. A PLANTED SECRET-SHAPED STRING, on an otherwise green page: only R11 may catch it.
rigPage 5000000003 'RMM2 — how we prove it' 5 <<'EOF'
<p>Source: rmm2/docs/prove-it.md</p>
<p>AI-generated — reviewed by Anna Petrova</p>
<p>Status: APPROVED</p>
<p>Type: how-to</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
<h2>Three kinds of check</h2>
<p>The call uses Authorization: Bearer eyJhbGciOiJIUzI1NiJ9c2VjcmV0LXRva2VuLXZhbHVlLTEyMw in the header.</p>
<h2>Change log</h2>
<p>2026-11-23, v5, the secret test</p>
EOF
rigRun --member magic-developer 5000000003
rigAssert "a planted secret-shaped string fails R11, and nothing else" "$( rigRules 5000000003 "$rigOut" )" "R11 "

## 4. ONE REFUSING ARM PER REMAINING RULE.
## R4: no TL;DR before the first heading.
rigPage 5000000004 'RMM2 — findings register' 10 <<'EOF'
<p>Source: rmm2/docs/findings.md</p>
<p>AI-generated — not yet reviewed</p>
<p>Status: DRAFT</p>
<p>Type: register</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<h2>Findings</h2>
<p>One finding, and it is open.</p>
<h2>Change log</h2>
<p>2026-11-23, v10, the tenth revision</p>
EOF
## R13: an archived page that still asks to be confirmed, and names no successor.
rigPage 5000000005 'RMM2 — research archive v0.10 (evidence)' 4 <<'EOF'
<p>Source: rmm2/docs/archive-v0.10.md</p>
<p>AI-generated — not yet reviewed</p>
<p>Status: ARCHIVED</p>
<p>Type: archive</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-22</p>
<p>Jira: MAGIC-15</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
<h2>The measurements</h2>
<p>Archived research draft, frozen 2026-11-22 at version 4.</p>
<table><tbody><tr><th>Confirmed by</th><td>Alex Kharichev.</td></tr><tr><th>Confirmation record</th><td>Empty.</td></tr></tbody></table>
<h2>Change log</h2>
<p>2026-11-22, v4, the freeze</p>
EOF
## R8: two pages of one set sharing a title.
rigPage 5000000006 'RMM2 — assumptions and gaps' 26 <<'EOF'
<p>Source: rmm2/docs/gaps.md</p>
<p>AI-generated — not yet reviewed</p>
<p>Status: DRAFT</p>
<p>Type: register</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
<h2>Gaps</h2>
<p>One gap, and it is open.</p>
<h2>Change log</h2>
<p>2026-11-23, v26, the twenty-sixth revision</p>
EOF
rigPage 5000000007 'RMM2 — assumptions and gaps' 4 <<'EOF'
<p>Source: rmm2/docs/gaps-copy.md</p>
<p>AI-generated — not yet reviewed</p>
<p>Status: DRAFT</p>
<p>Type: register</p>
<p>Owner: Alex Kharichev</p>
<p>Approver: Alex Kharichev</p>
<p>Last reviewed: 2026-11-23</p>
<p>Jira: MAGIC-15</p>
<ul><li>one</li><li>two</li><li>three</li></ul>
<h2>Gaps</h2>
<p>A second copy of the same title.</p>
<h2>Change log</h2>
<p>2026-11-23, v4, the copy</p>
EOF
rigRun --member magic-developer 5000000004 5000000005 5000000006 5000000007
rigAssert "no TL;DR fails R4, and that page fails nothing else" "$( rigRules 5000000004 "$rigOut" )" "R4 "
rigAssert "an archived page that asks to be confirmed fails R13" "$( rigRules 5000000005 "$rigOut" )" "R13 "
rigAssert "two pages sharing a title fail R8, both of them" "$( rigRules 5000000006 "$rigOut" )$( rigRules 5000000007 "$rigOut" )" "R8 R8 "

## A page the check cannot read is a failing row, never a skip.
rigRun --member magic-developer 5000000009
rigAssert "a page the read answers 404 for is a row, not a skip" "$( rigRules 5000000009 "$rigOut" )" "read "
case "$rigOut" in
	*"missing or this identity may not see it"*|*404*) rigAssert "and the row says the 404 is both a missing page and an invisible one" yes yes ;;
	*) rigAssert "and the row says the 404 is both a missing page and an invisible one" "$rigOut" "a row naming the 404 and both its meanings" ;;
esac

## 5. THE DEFAULT PAGE SET: no id, and a setting holding none, is rc 6 naming the setting.
AgentsToolsConfigOption(){ return 1 ; }
rigRun --member magic-developer
rigAssert "no page id and no setting is a designed refusal, rc 6" "$rigRc" "6"
case "$rigErr" in
	*CONFLUENCE_PAGE_CHECK_PAGES*) rigAssert "and it names the setting a workspace sets" yes yes ;;
	*) rigAssert "and it names the setting a workspace sets" "$rigErr" "a line naming CONFLUENCE_PAGE_CHECK_PAGES" ;;
esac

## CONTROL: the engine itself is the instrument, and a run over an empty stream prints nothing.
rigAssert "control: the engine over an empty stream prints no row" "$( printf '' | python3 "$rigEngine" )" ""

if [ "$rigFail" = 0 ] ; then printf 'CONFLUENCE_PAGE_CHECK: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ CONFLUENCE PAGE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
