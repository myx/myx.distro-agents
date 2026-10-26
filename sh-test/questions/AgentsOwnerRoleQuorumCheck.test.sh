#!/usr/bin/env bash
## Behavioural check on the owners role (epic T8, the predecessor's F6.11): human-owner is a role
## with members, each an authenticated account (HUMAN_OWNER_MEMBERS); a question to the role goes to
## a conversation of its members, so the members are the accounts a request is addressed to; each
## kind of decision carries a quorum rule (HUMAN_OWNER_QUORUM: all, first, any-approves, any-rejects,
## majority); and console users are never members -- a console mapping only routes confirmations,
## which AgentsOwnerConsoleAccountCheck already asserts. Offline; reads the package only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## The environment a --agents-config-option call resolves its origin from, defaulted so the check
## runs the way the harness invokes it and also standalone.
: "${MDSC_INMODE:=extern}"
: "${MDLT_OPTION:=--run-from-path $MDLT_ORIGIN}"
: "${MDSC_OPTION:=--run-from-path $MDLT_ORIGIN}"
export MDSC_INMODE MDLT_OPTION MDSC_OPTION MDLT_ORIGIN
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
rigWs="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsOwnerRoleQuorumCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigWs"' EXIT
mkdir -p "$rigWs/.local/.agents"

## Each call runs in a shell of its own, as the tool resolves its origin in one.
rigMembers(){ ## -- the role's members, one a line
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/questions/AgentsTools.Authority.include" ; AgentsToolsOwnerRoleMembers' _ "$rigHere" 2> /dev/null
}
rigRule(){ ## kind -- the quorum rule of that kind
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/questions/AgentsTools.Authority.include" ; AgentsToolsOwnerQuorumRule "$2"' _ "$rigHere" "$1" 2> /dev/null
}
rigDecide(){ ## rule, members (one a line), votes (one a line) -- APPROVED/DENIED/OPEN
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/questions/AgentsTools.Authority.include" ; AgentsToolsOwnerQuorumDecide "$2" "$3" "$4"' _ "$rigHere" "$1" "$2" "$3" 2> /dev/null
}
rigSet(){ ## key=value lines -- rewritten whole into the magic-team scope
	printf '%s\n' "$@" > "$rigWs/.local/.agents/magic-team.agent.env"
}

rigThree=$'M1\nM2\nM3'

echo "-- 1. human-owner is a role with members, one authenticated account each --"
rigSet 'HUMAN_OWNER_MEMBERS=URIGOWNER UOWNER2 owner@example.com' 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER'
check "the setting lists the members" "$( rigMembers | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "URIGOWNER UOWNER2 owner@example.com"

echo "-- 2. a console account is never a member --"
rigSet 'HUMAN_OWNER_MEMBERS=URIGOWNER user-myx UOWNER2' 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER' 'HUMAN_OWNER_CONSOLE_ACCOUNT=myx'
check "a user-* word in the setting is dropped, and the console mapping adds no member" \
	"$( rigMembers | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "URIGOWNER UOWNER2"

echo "-- 3. unset, the role is the one SLACK_CHANNEL_HUMAN_OWNER account --"
rigSet 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER'
check "no members setting: the single owner account" "$( rigMembers )" "URIGOWNER"

echo "-- 4. each kind of decision carries a quorum rule --"
rigSet 'HUMAN_OWNER_QUORUM=permission=majority decision=any-approves readback=all change=any-rejects'
check "permission -> majority" "$( rigRule permission )" "majority"
check "decision -> any-approves" "$( rigRule decision )" "any-approves"
check "readback -> all" "$( rigRule readback )" "all"
check "change -> any-rejects" "$( rigRule change )" "any-rejects"
check "question -> first, unset for the kind" "$( rigRule question )" "first"

echo "-- 5. unset, every kind is first (the single-owner rule) --"
rigSet ''
check "no quorum setting: first for every kind" "$( rigRule permission )" "first"

echo "-- 6. any-approves (permit overrides): an approve decides, and a reject falls back --"
check "one approve of three: approved" "$( rigDecide any-approves "$rigThree" $'M1=deny\nM2=allow-once' )" "APPROVED allow-once M2"
check "a reject with no approve: denied" "$( rigDecide any-approves "$rigThree" $'M1=deny' )" "DENIED deny M1"

echo "-- 7. any-rejects (deny overrides): a reject vetoes, and an approve falls back --"
check "one reject of three: denied" "$( rigDecide any-rejects "$rigThree" $'M1=allow-once\nM2=deny' )" "DENIED deny M2"
check "an approve with no reject: approved" "$( rigDecide any-rejects "$rigThree" $'M1=allow-once' )" "APPROVED allow-once M1"

echo "-- 8. all: every member must approve, and any reject vetoes --"
check "all approve: approved" "$( rigDecide all "$rigThree" $'M1=allow-once\nM2=allow-once\nM3=allow-once' )" "APPROVED allow-once M1"
check "one rejects: denied" "$( rigDecide all "$rigThree" $'M1=allow-once\nM2=deny\nM3=allow-once' )" "DENIED deny M2"
check "one has not answered: open" "$( rigDecide all "$rigThree" $'M1=allow-once\nM2=allow-once' )" "OPEN"

echo "-- 9. majority: more than half --"
check "two of three approve: approved" "$( rigDecide majority "$rigThree" $'M1=allow-once\nM2=allow-once\nM3=deny' )" "APPROVED allow-once M1"
check "two of three reject: denied" "$( rigDecide majority "$rigThree" $'M1=allow-once\nM2=deny\nM3=deny' )" "DENIED deny M2"
check "one of three: open" "$( rigDecide majority "$rigThree" $'M1=allow-once' )" "OPEN"

if [ "$fail" = 0 ] ; then printf 'OWNER_ROLE_QUORUM: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ OWNER_ROLE_QUORUM CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
