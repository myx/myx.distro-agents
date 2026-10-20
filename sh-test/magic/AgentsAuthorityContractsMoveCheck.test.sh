#!/usr/bin/env bash
## Behavioural check on F5.5 of the refactorings epic: the six authority contracts,
## `magic-team.authority.<type>.contract.md` (client, expert, keeper, oncall, partner, warden), live in
## skillset/magic-team/magic-team/contracts/ and not flat in the member folder, and every citation of them in this
## package was swept in the same change.
## Held:
##   1. the six are in contracts/, none stays flat in the member folder, and contracts/ holds nothing else
##   2. the seven `*.contract.format.md` shapes of templates/ are not moved
##   3. no citation names the old flat place: every spelling of an authority contract in the package is in `contracts/`,
##      as `magic-team/contracts/magic-team.authority.<type>.contract.md`, or relative to the member folder as
##      `contracts/...` (the <type> patterns too)
##   4. every named citation resolves, by the one validator (the self-check rule set `document`): no row of
##      report-citation names an authority contract in any skillset document
##   5. the controls: an old-form citation is found by the text check and by the validator
##   6. the harness serves a moved file as it serves any other file of the member folder: Read by path
## Red before F5.5: the six are flat and cited so (cases 1, 3, 4, 6 fail).
## Offline: rig files only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigMember="$rigPackage/skillset/magic-team/magic-team"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigMember" ] || rigRefuse "the member folder is not at the origin this workspace resolves: $rigMember"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAuthorityContractsMoveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/agents/members" "$rigTmp/home/.claude/skills" "$rigTmp/skills"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigTypes="client expert keeper oncall partner warden"

echo "-- 1. the six are in contracts/ --"
rigIn=0 rigFlat=0
for rigType in $rigTypes ; do
	[ ! -f "$rigMember/contracts/magic-team.authority.$rigType.contract.md" ] || rigIn=$(( rigIn + 1 ))
	[ ! -e "$rigMember/magic-team.authority.$rigType.contract.md" ] || rigFlat=$(( rigFlat + 1 ))
done
rigAssert "all six in magic-team/contracts/" "$rigIn" "6"
rigAssert "none flat in the member folder" "$rigFlat" "0"
rigAssert "contracts/ holds those six and nothing else" "$( ls "$rigMember/contracts" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "magic-team.authority.client.contract.md magic-team.authority.expert.contract.md magic-team.authority.keeper.contract.md magic-team.authority.oncall.contract.md magic-team.authority.partner.contract.md magic-team.authority.warden.contract.md "

echo "-- 2. the shapes of templates/ stay --"
rigShapes=0
for rigShape in basic human-owner keeper-warden oncall-expert partner-client routine team-member ; do
	[ ! -f "$rigMember/templates/$rigShape.contract.format.md" ] || rigShapes=$(( rigShapes + 1 ))
done
rigAssert "the seven *.contract.format.md shapes are still in templates/" "$rigShapes" "7"

echo "-- 3. no citation names the old place --"
rigSpell(){ ## the spellings of an authority contract in the files of the package, one a line, with the folder before it where it has one
	LC_ALL=C grep -r -o -h -E '([A-Za-z-]+/)*magic-team[.]authority[.][a-z<>]+[.]contract[.]md' "$rigPackage" --include='*.md' --include='*.include' --include='*.sh' --include='*.awk' --include='*.py' --include='*.inf' --exclude-dir=.git --exclude='AgentsAuthorityContractsMoveCheck.test.sh' 2> /dev/null
}
rigTotal="$( rigSpell | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigOld="$( rigSpell | LC_ALL=C grep -c -v -E '^(magic-team/)?contracts/magic-team[.]authority[.]' || : )"
rigAssert "every spelling is in contracts/ ($rigTotal in the package)" "$rigOld" "0"
rigAssert "the package cites them at all (the control that can return zero)" "$( [ "$rigTotal" -ge 10 ] && echo yes || echo no )" "yes"
rigAssert "the shared-files list names the folder" "$( LC_ALL=C grep -c -F '`contracts/`' "$rigMember/SKILL.md" || : )" "1"

echo "-- 4. every named citation resolves --"
rigValidate(){ ## file -- the rows of report-citation that name an authority contract
	( cd "$rigTmp/ws" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" --intern-doc-validate document "$1" 2> /dev/null < /dev/null ) | LC_ALL=C grep -c 'report-citation: .*authority' || :
}
rigBadFiles=0 rigChecked=0
while IFS= read -r rigFile ; do
	rigChecked=$(( rigChecked + 1 ))
	[ "$( rigValidate "$rigFile" )" = "0" ] || { rigBadFiles=$(( rigBadFiles + 1 )) ; printf '        unresolved in %s\n' "$rigFile" ; }
done <<< "$( LC_ALL=C grep -r -l -F 'magic-team.authority.' "$rigPackage/skillset" --include='*.md' | LC_ALL=C sort )"
rigAssert "no skillset document ($rigChecked of them cite one) has a citation of an authority contract that is not there" "$rigBadFiles" "0"

echo "-- 5. the controls --"
printf -- '---\ntype: note\n---\nAn old citation: `magic-team/magic-team.authority.client.contract.md`, and a good one: `magic-team/contracts/magic-team.authority.partner.contract.md`.\n' > "$rigTmp/planted.md"
rigAssert "the validator finds an old-form citation, and only it" "$( rigValidate "$rigTmp/planted.md" )" "1"
rigAssert "the text check finds it" "$( printf '%s\n' 'magic-team/magic-team.authority.client.contract.md' 'magic-team/contracts/magic-team.authority.partner.contract.md' | LC_ALL=C grep -c -v -E '^(magic-team/)?contracts/magic-team[.]authority[.]' || : )" "1"

echo "-- 6. the harness serves a moved file --"
ln -s "$rigMember" "$rigTmp/ws/.local/agents/members/magic-team"
ln -s "$rigMember" "$rigTmp/home/.claude/skills/magic-team"
rigCall(){ ## tool, argument object, text to find -- 'served' where it came back
	local rigOut
	rigOut="$( printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/ws/.local/agents/members" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		HARNESS_PROVIDER_NAME="authority check rig" HARNESS_SELF_NAME="AgentsAuthorityContractsMoveCheck.test.sh" HARNESS_ENDPOINT="https://authority-check.invalid/v1/chat/completions" HARNESS_HOST="authority-check.invalid" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none -- this check never reads one" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
		bash "$rigHarness" --intern-tool "$1" 2> /dev/null )" || :
	case "$rigOut" in *"$3"*) printf served ;; *) printf 'not-served' ;; esac
}
rigAssert "Read by path serves contracts/magic-team.authority.client.contract.md" "$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/magic-team/contracts/magic-team.authority.client.contract.md\"}" 'Client decision authority' )" "served"
rigAssert "as it serves reference/board-model.md (the control)" "$( rigCall Read "{\"path\":\"$rigTmp/home/.claude/skills/magic-team/reference/board-model.md\"}" 'Board states and lifecycle' )" "served"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AUTHORITY CONTRACTS MOVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AUTHORITY_CONTRACTS_MOVE: OK (%d assertions, offline)\n' "$rigPassCount"
