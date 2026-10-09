#!/usr/bin/env bash
## Behavioural check that the Skill tool reaches all of a skillset file and names what a
## folder holds in the form it takes back: a line range past the byte cap, as Read gives
## one, and a listing whose every line is a valid `file` argument.
##
## Why it exists. The shared armed file runs to 160 KB and a client caps what one tool
## result may carry below that, so with no range the tail of a duty file was out of reach
## wherever Read is denied. A listing of absolute paths could not be fed back to `file`,
## which refuses an absolute path.
##
## Offline and unmetered: --intern-tool reaches no endpoint and needs no credential.
## HOME and MMDAPP are this rig's own fixtures, so no file of the real machine is read.
##
## Red recipe, run: drop offset and limit from the Skill dispatch arm, or the `cd` from
## the listing in AgentsHarnessToolSkill.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

export MDLT_ORIGIN="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigHarness="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"

rigTmp="$( mktemp -d -t AgentsHarnessSkillRangeCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## A member linked in from its owning tree, as on this machine, carrying a
## reference/ subfolder and a five-line typed file.
mkdir -p "$rigTmp/home/.claude/skills" "$rigTmp/ws/source" "$rigTmp/owners/rig-keeper/reference"
printf 'rig-boot\n' > "$rigTmp/owners/rig-keeper/SKILL.md"
printf 'rig-line-1\nrig-line-2\nrig-line-3\nrig-line-4\nrig-line-5\n' > "$rigTmp/owners/rig-keeper/rig-keeper.armed.md"
printf 'rig-reference\n' > "$rigTmp/owners/rig-keeper/reference/shell.md"
ln -s "$rigTmp/owners/rig-keeper" "$rigTmp/home/.claude/skills/rig-keeper"

export HARNESS_PROVIDER_NAME="skill-range check rig"
export HARNESS_SELF_NAME="AgentsHarnessSkillRangeCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-skill-range-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-skill-range-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

## One Skill call through the real core, as the MCP server makes it; stdout only.
rigSkill(){ ## argument object
	local rigOut
	rigOut="$( printf '%s' "$1" | HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/home/.claude/skills" \
		"$rigHarness" --intern-tool Skill 2>/dev/null )" || :
	[ -n "$rigOut" ] || rigRefuse "no output from Skill $1, so the tool was never exercised"
	printf '%s' "$rigOut"
}

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- a line range, as Read gives one --"
## The control that must differ from the range below: no range reads the whole file.
rigAssert "no range reads the whole file" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.armed.md"}' | tr '\n' ' ' )" \
	"rig-line-1 rig-line-2 rig-line-3 rig-line-4 rig-line-5"
rigAssert "offset and limit read that range and state the file length" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.armed.md","offset":3,"limit":2}' | tr '\n' ' ' )" \
	"rig-line-3 rig-line-4 ... read 2 line(s) from line 3; the file has 5 lines ..."
rigAssert "the <member>/<file> form takes a range too" \
	"$( rigSkill '{"name":"rig-keeper/rig-keeper.armed.md","offset":5}' | tr '\n' ' ' )" \
	"rig-line-5 ... read 1 line(s) from line 5; the file has 5 lines ..."
rigAssert "an offset that is not a line number is refused" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.armed.md","offset":0}' )" \
	"ERROR: offset must be a whole line number counting from 1, got: 0"

echo "-- a served whole-file read past the cap stays under the MCP client's limit --"
## 1000 lines of 90 bytes: 90000 bytes, past the served cap and under the model-run one.
LC_ALL=C awk 'BEGIN { for ( lineIndex = 1 ; lineIndex <= 1000 ; lineIndex++ ) printf "%089d\n", lineIndex ; }' > "$rigTmp/owners/rig-keeper/rig-keeper.big.md"
rigBigOut="$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.big.md"}' )"
rigAssert "it returns at most 48000 bytes" \
	"$( [ "$( printf '%s' "$rigBigOut" | wc -c | tr -d ' ' )" -le 48200 ] && printf under || printf over )" under
rigAssert "it names the offset to continue from" \
	"$( printf '%s\n' "$rigBigOut" | LC_ALL=C sed -n 's/.*; continue with offset \([0123456789]*\) \.\.\./\1/p' )" 534
rigAssert "that offset reads on from the next line" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.big.md","offset":534,"limit":1}' | head -1 )" \
	"$( printf '%089d' 534 )"
## One line past the cap is named as unreturnable, never offered back as its own next offset.
LC_ALL=C awk 'BEGIN { printf "short\n%049000d\nafter\n", 0 ; }' > "$rigTmp/owners/rig-keeper/rig-keeper.big.md"
rigAssert "a line past the cap is named, not offered back" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.big.md","offset":2}' | head -1 )" \
	"... line 2 alone is over the 48000-byte cap of this reader, so it cannot be returned here ..."
rm -f "$rigTmp/owners/rig-keeper/rig-keeper.big.md"

echo "-- section reads only the named headings --"
printf '# Top\nintro\n## Alpha: one, two\na-1\n### Alpha child\na-2\n```\n# not a heading\n```\n## Beta\nb-1\n# Second top\n## Gamma\ng-1\n' > "$rigTmp/owners/rig-keeper/rig-keeper.sections.md"
rigAssert "one section runs to the next heading of its level, children included" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Alpha: one, two"}' | tr '\n' ' ' )" \
	'## Alpha: one, two a-1 ### Alpha child a-2 ``` # not a heading ```'
rigAssert "a top-level section stops at the next top-level heading only" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Top"}' | LC_ALL=C grep -c '' )" 11
rigAssert "several sections, | separated, come back in the order asked" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Gamma|Beta"}' | tr '\n' ' ' )" \
	"## Gamma g-1  ## Beta b-1"
rigAssert "an unknown section is ERROR naming it" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Beta|Delta"}' | head -1 )" \
	"ERROR: Skill: no such section: Delta -- the headings in this file are:"
rigAssert "and it lists every heading, never a fenced line" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Delta"}' | tail -n +2 | tr '\n' ' ' )" \
	"# Top ## Alpha: one, two ### Alpha child ## Beta # Second top ## Gamma"
rigAssert "offset and limit page the section text" \
	"$( rigSkill '{"name":"rig-keeper","file":"rig-keeper.sections.md","section":"Gamma","offset":2,"limit":1}' | head -1 )" "g-1"
rm -f "$rigTmp/owners/rig-keeper/rig-keeper.sections.md"

echo "-- a listing names what the file argument takes --"
rigAssert "list prints names relative to the member folder" \
	"$( rigSkill '{"name":"rig-keeper","list":true}' | LC_ALL=C sort | tr '\n' ' ' )" \
	"SKILL.md reference/shell.md rig-keeper.armed.md "
rigAssert "a listed reference/ name reads back through file" \
	"$( rigSkill '{"name":"rig-keeper","file":"reference/shell.md"}' )" "rig-reference"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SKILL RANGE CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: the Skill tool cannot reach all of a skillset file, or lists names" >&2
	echo "        its own file argument refuses" >&2
	echo "  fix:  repair AgentsHarnessToolSkill or its dispatch arm in" >&2
	echo "        sh-lib/AgentsUniversalHarness.sh -- never the assertion" >&2
	exit 1
fi
echo "HARNESS_SKILL_RANGE: OK (line range, relative listing read back, offline)"
