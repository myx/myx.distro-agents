#!/usr/bin/env bash
## Offline check on the Atlassian credential read order (S20 item 3): the environment, then the
## acting member's own scope in the workspace the call runs from, then the rig's magic-team scope.
## A rung is taken whole, so a set is never put together from two places. A member's settings
## borrowed from the workspace it is set up in never outrank the team's. A client-side call takes
## no team rung. The Jira and Confluence sets stay apart.
## The fixture is one HOME holding the machine's member and workspace registries, two workspaces,
## and a fake `curl` first on PATH that records the host of the URL it was handed. Nothing here
## opens a socket, and no check prints any value of a key: a case reads the host and the status.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternOpAtlassianCall.include"
rigBare="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.BareName.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }
[ -f "$rigBare" ] || { echo "⛔ ERROR: no $rigBare" >&2 ; exit 1 ; }

. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianReadOrderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigHome="$rigTmp/home" ; rigBin="$rigTmp/bin" ; rigSkills="$rigTmp/skills"
rigHere="$rigTmp/ws/here" ; rigThere="$rigTmp/ws/there"
rigHosts="$rigTmp/hosts" ; rigErr="$rigTmp/err"
mkdir -p "$rigHere/.local/.agents" "$rigThere/.local/.agents" "$rigBin" "$rigHome/.agents/magic-team"
for rigMember in keeper-here keeper-none client-ndm keeper-there ; do
	mkdir -p "$rigSkills/$rigMember"
done

## The fake curl: it opens no socket, and records the host it was asked for.
cat > "$rigBin/curl" <<'RIGCURL'
#!/usr/bin/env bash
set -u
for rigArg in "$@" ; do
	case "$rigArg" in
		https://*) rigUrl="${rigArg#https://}" ; rigUrl="${rigUrl%%/*}" ; printf '%s\n' "$rigUrl" >> "$RIG_HOSTS" ;;
	esac
done
printf '{"id":"1"}\n200'
exit 0
RIGCURL
chmod +x "$rigBin/curl"
PATH="$rigBin:$PATH"
[ "$( command -v curl )" = "$rigBin/curl" ] || { echo "⛔ ERROR: the fake curl is not first on PATH, so this check would issue real requests" >&2 ; exit 1 ; }

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## The three keys of one product, each value naming whose it is: WHOSE names the holder.
rigKeys(){ ## whose, product, prefix (may be empty)
	case "$2" in
		jira) printf '%s\n' "${3:-}JIRA_SITE=jira-$1.invalid" "${3:-}JIRA_USER=us@$1.invalid" "${3:-}JIRA_API_TOKEN=rig-token-$1" ;;
		confluence) printf '%s\n' "${3:-}CONFLUENCE_SITE=confluence-$1.invalid" "${3:-}CONFLUENCE_USER=us@$1.invalid" "${3:-}CONFLUENCE_API_TOKEN=rig-token-$1" ;;
	esac
}
rigScope(){ ## workspace, scope, the lines as one argument -- that scope's file there
	mkdir -p "$1/.local/.agents"
	printf '%s\n' "$3" > "$1/.local/.agents/$2.agent.env"
}
rigEnv(){ ## -- a fresh machine: no scope holds a credential, and no borrowed workspace is known yet
	: > "$rigHome/.agents/magic-team/members.registry"
	printf '%s\n%s\n' "$rigHere" "$rigThere" > "$rigHome/.agents/magic-team/known-workspaces.registry"
	: > "$rigHere/.local/.agents/magic-team.agent.env"
	for rigMember in keeper-here keeper-none client-ndm ; do : > "$rigHere/.local/.agents/$rigMember.agent.env" ; done
	: > "$rigThere/.local/.agents/keeper-there.agent.env"
}
## One call of the helper under test, from the workspace everything runs from: rc in rigRc, the
## host curl was asked for in rigHostSeen (none where it was never called), stderr in rigErr.
rigCall(){ ## member, product, side
	: > "$rigHosts"
	rigRc=0
	( cd "$rigHere" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigHere" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_SIDE="$3" MDSC_CMD=DistroAgentsTools RIG_HOSTS="$rigHosts" \
		bash -c 'set +u ; . "$1" ; . "$2" ; AgentsToolsAtlassianCall "$3" "$4" GET /rest/api/3/issue/TEST-1 atlassian-read-order ""' \
			_ "$rigBare" "$rigInc" "$1" "$2" ) > /dev/null 2> "$rigErr" || rigRc=$?
	rigHostSeen="$( cat "$rigHosts" )"
	rigHostSeen="${rigHostSeen:-none}"
}
rigEnvCall(){ ## member, product, side, then KEY=value... -- the same, with keys in the environment
	local envMember="$1" envProduct="$2" envSide="$3" ; shift 3
	: > "$rigHosts"
	rigRc=0
	( cd "$rigHere" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigHere" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_COMMS_SIDE="$envSide" MDSC_CMD=DistroAgentsTools RIG_HOSTS="$rigHosts" "$@" \
		bash -c 'set +u ; . "$1" ; . "$2" ; AgentsToolsAtlassianCall "$3" "$4" GET /rest/api/3/issue/TEST-1 atlassian-read-order ""' \
			_ "$rigBare" "$rigInc" "$envMember" "$envProduct" ) > /dev/null 2> "$rigErr" || rigRc=$?
	rigHostSeen="$( cat "$rigHosts" )"
	rigHostSeen="${rigHostSeen:-none}"
}

echo "-- 1. the environment comes first --"
rigEnv
rigEnvCall keeper-none jira own JIRA_SITE=jira-ENV.invalid JIRA_USER=us@ENV.invalid JIRA_API_TOKEN=rig-token-ENV
rigAssert "a member whose own scope holds nothing is answered from the environment" "$rigRc $rigHostSeen" "0 jira-ENV.invalid"
rigScope "$rigHere" keeper-none "$( rigKeys HERE jira )"
rigEnvCall keeper-none jira own JIRA_SITE=jira-ENV.invalid JIRA_USER=us@ENV.invalid JIRA_API_TOKEN=rig-token-ENV
rigAssert "and the environment outranks the member's own scope, as it always has" "$rigRc $rigHostSeen" "0 jira-ENV.invalid"

echo "-- 2. the member's own scope in this workspace comes next --"
rigEnv
rigScope "$rigHere" keeper-here "$( rigKeys HERE jira )"
rigCall keeper-here jira own
rigAssert "a member holding its own Jira set here is answered from it" "$rigRc $rigHostSeen" "0 jira-HERE.invalid"
rigScope "$rigHere" magic-team "$( rigKeys TEAM jira )"
rigCall keeper-here jira own
rigAssert "and its own set still wins over the rig's team set" "$rigRc $rigHostSeen" "0 jira-HERE.invalid"

echo "-- 3. the rig's magic-team scope comes last, and a member that holds nothing here reaches it --"
rigCall keeper-none jira own
rigAssert "a member holding no Jira set here reaches the rig's magic-team set" "$rigRc $rigHostSeen" "0 jira-TEAM.invalid"
rigScope "$rigHere" keeper-none "$( rigKeys HALF jira | LC_ALL=C sed -n 1p )"
rigCall keeper-none jira own
rigAssert "a member holding one key of the set here takes the whole set from there, never two places" "$rigRc $rigHostSeen $( LC_ALL=C grep -c -F 'JIRA_USER/JIRA_API_TOKEN missing' "$rigErr" )" "6 none 1"

echo "-- 4. a client-* call never reaches the team's set --"
rigEnv
rigScope "$rigHere" magic-team "$( rigKeys TEAM jira )"
rigCall client-ndm jira own
rigAssert "a client-* member on our own side is refused with nothing sent" "$rigRc $rigHostSeen" "6 none"
rigAssert "and the refusal names the way to the other organisation" "$( LC_ALL=C grep -c -F 'has no Jira settings on our own organisation' "$rigErr" )" 1
rigCall client-ndm jira client
rigAssert "on the client side with no set of its own, the team's set stands in for nothing" "$rigRc $rigHostSeen" "6 none"
rigScope "$rigHere" client-ndm "$( rigKeys NDM jira CLIENT_ )"
rigCall client-ndm jira client
rigAssert "and with its own CLIENT_ set it is that one which answers" "$rigRc $rigHostSeen" "0 jira-NDM.invalid"

echo "-- 5. a set borrowed from the member's own workspace never outranks the team's --"
rigEnv
printf 'keeper-there\t%s\tsource-symlink\tpkg/skillset/keeper-there\t%s/pkg/skillset/keeper-there\n' "$rigThere" "$rigThere" > "$rigHome/.agents/magic-team/members.registry"
printf 'keeper-here\t%s\tsource-symlink\tpkg/skillset/keeper-here\t%s/pkg/skillset/keeper-here\n' "$rigHere" "$rigHere" >> "$rigHome/.agents/magic-team/members.registry"
rigScope "$rigThere" keeper-there "$( rigKeys THERE jira )"
rigCall keeper-there jira own
rigAssert "control: with no team key here, the borrowed set is read, as it is today" "$rigRc $rigHostSeen" "0 jira-THERE.invalid"
rigScope "$rigHere" magic-team "$( rigKeys TEAM jira )"
rigCall keeper-there jira own
rigAssert "with a team key here the borrowed set does not outrank it" "$rigRc $rigHostSeen" "0 jira-TEAM.invalid"

echo "-- 6. the Jira and Confluence sets stay apart --"
rigEnv
rigScope "$rigHere" magic-team "$( rigKeys TEAM jira )"
rigCall keeper-none confluence own
rigAssert "a team holding only Jira is no Confluence credential: refused, naming the three" "$rigRc $rigHostSeen $( LC_ALL=C grep -c -F 'CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN missing' "$rigErr" )" "6 none 1"
rigScope "$rigHere" magic-team "$( rigKeys TEAM jira )" ; rigScope "$rigHere" magic-team "$( rigKeys TEAM jira ; rigKeys TEAMCONF confluence )"
rigCall keeper-none confluence own
rigAssert "with the Confluence set in team scope too, the same member reads Confluence" "$rigRc $rigHostSeen" "0 confluence-TEAMCONF.invalid"

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN_READ_ORDER: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN READ ORDER CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
