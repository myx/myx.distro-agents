#!/usr/bin/env bash
## Behavioural check on the testing directive (F13.5 of the refactorings epic, open-names 54): a project.inf directive,
## in the place directive's form, `magic-team:testing:<project-glob>:<sh-test-path>:<host-glob>`, allows magic-tester to
## work with the sh-test folder of the projects it names. One mechanism: it gives the grant a permissions directive
## gives, magic-tester's write over `source/<repo>/<project>/<sh-test-path>/**`. The verb is added to the parser before
## any project.inf relies on it, though an unknown verb fails safe.
## Run in a myx.distro workspace of the rig's own (check-fixtures/rig-distro-workspace.include.sh), through
## --make-workspace-integrations, which reads the declares into .local/agents/permissions.registry.
## Held:
##   1. control: a permissions directive gives magic-tester its Edit over the path it names
##   2. a testing directive for rig.beta gives magic-tester its Edit over source/rig/rig.beta/sh-test/**, the same row
##   3. a directive for a host that is not this one gives nothing
##   4. control: a project the directive does not name gets no such grant
## Red before F13.5: the verb is read by nothing (2 fails; 1, 3 and 4 hold today).
## Offline: the rig's own workspace and HOME, under $MMDAPP/.local/temp/sh-test/.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigFixtures/rig-distro-workspace.include.sh" || rigRefuse "the rig's distro workspace fixture is missing from the package: sh-test/check-fixtures/rig-distro-workspace.include.sh"
rigDistroPath > /dev/null || rigRefuse "no myx.common on PATH, which the source scan of a distro workspace needs"
rigTmp="$( rigDistroTmp AgentsTestingDirectiveCheck )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigHome="$rigTmp/home"
mkdir -p "$rigHome"
rigDistroWorkspace "$rigWs" rig || rigRefuse "could not make the rig's distro workspace"
rigDistroProject "$rigWs" rig rig.alpha "$( printf 'Declares: \\\n\tmagic-team:permissions:workspace:.:allow-write:magic-tester:source/rig/rig.alpha/docs/** \\\n\tmagic-team:testing:rig.beta:sh-test:* \\\n\tmagic-team:testing:rig.gamma:sh-test:rig-no-such-host\n' )" || rigRefuse "could not write the rig's project"
rigDistroProject "$rigWs" rig rig.beta "" || rigRefuse "could not write the rig's project"
rigDistroProject "$rigWs" rig rig.gamma "" || rigRefuse "could not write the rig's project"
rigDistroProject "$rigWs" rig rig.delta "" || rigRefuse "could not write the rig's project"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigEdit(){ ## path below the workspace -- `granted` where magic-tester holds an Edit over it in the permissions registry
	if LC_ALL=C grep -q -F -- "Edit(/$rigWs/$1)" "$rigWs/.local/agents/permissions.registry" 2> /dev/null && \
		LC_ALL=C grep -F -- "Edit(/$rigWs/$1)" "$rigWs/.local/agents/permissions.registry" | LC_ALL=C grep -q '^magic-tester:' ; then
		printf granted
	else
		printf none
	fi
}

rigDistroRun "$rigWs" "$rigHome" --make-workspace-integrations > "$rigTmp/make.out" 2>&1
rigAssert "control: the integrations end 0, and the permissions registry stands" "$?:$( [ -f "$rigWs/.local/agents/permissions.registry" ] && echo registry || echo none )" "0:registry"
echo "-- 1. control: a permissions directive gives its Edit --"
rigAssert "magic-tester's Edit over source/rig/rig.alpha/docs/**" "$( rigEdit 'source/rig/rig.alpha/docs/**' )" "granted"
echo "-- 2. the testing directive gives the same grant over the project's sh-test --"
rigAssert "magic-tester's Edit over source/rig/rig.beta/sh-test/**" "$( rigEdit 'source/rig/rig.beta/sh-test/**' )" "granted"
echo "-- 3. a directive for another host gives nothing --"
rigAssert "no Edit over source/rig/rig.gamma/sh-test/**"        "$( rigEdit 'source/rig/rig.gamma/sh-test/**' )" "none"
echo "-- 4. control: a project not named gets no such grant --"
rigAssert "no Edit over source/rig/rig.delta/sh-test/**"        "$( rigEdit 'source/rig/rig.delta/sh-test/**' )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TESTING DIRECTIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TESTING_DIRECTIVE: OK (%d assertions, offline, a distro workspace of the rig)\n' "$rigPassCount"
