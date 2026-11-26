#!/usr/bin/env bash
## Offline check of the two writers that turn a project's Provides rows into an index
## and into per-project files: a credential-class context-variable value never reaches
## either output, and every other row is left as written.
## Nothing outside the rig is written: source, cached and all scratch point at a tree made here.
## What the rows establish, one per statement of the declaration they serve:
##   - the shell writer replaces a password-class value with REDACTED, keeping the name and the operation;
##   - it keeps the array key of an operation that takes one;
##   - it leaves an import row alone, because that row holds a file reference and no literal;
##   - it leaves a host value as written;
##   - the index writer replaces the same value on a project's whole Provides line;
##   - neither output carries the literal;
##   - a known-positive control shows the probe can match at all.
## The rig refuses to report unless it found both writers, so a run that never reached its
## subject cannot print a pass line.
set -u

rigHere="$( cd "$( dirname "$0" )" && pwd -P )" || exit 1
rigTree="${RIG_WRITER_ROOT:-$( cd "$rigHere/../../.." && pwd -P )}"
rigShell="$rigTree/myx.distro-source/sh-lib/source-prepare/ParseSourceProjectInfToCached.fn.include"
rigAwk="$rigTree/myx.distro-system/sh-lib/system-context/BuildSingleIndex.awk"

rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigShell" ] || rigRefuse "no shell writer at $rigShell"
[ -f "$rigAwk" ] || rigRefuse "no index writer at $rigAwk"
grep -q 'ParseSourceProjectInfToCached()' "$rigShell" || rigRefuse "the shell writer defines no ParseSourceProjectInfToCached"
grep -q 'PRJ-PRV-' "$rigAwk" || rigRefuse "the index writer emits no PRJ-PRV row"

rigWork="$( mktemp -d "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp/AgentsProvidesRedactionCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigWork"' EXIT

rigPass=0
rigFail=0
rigCheck(){
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' "$1" "$3" "$2"
	fi
}

## The literal is one this rig invents, never a value taken from a real tree.
rigFixtureSecret="rigFixturePassw0rdValue"
rigProject="rig/fixture-project"
rigSrc="$rigWork/source"
rigCached="$rigWork/cached"

rigFresh(){
	rm -rf "$rigSrc" "$rigCached"
	mkdir -p "$rigSrc/$rigProject" "$rigCached"
	printf '%s\n' \
		'Name: fixture-project' \
		'Provides: \' \
		"	image-install:context-variable:VLOGS_PASSWORD:define:$rigFixtureSecret \\" \
		'	image-install:context-variable:AUTH_TOKEN:insert:promtail2:anotherFixtureValue \' \
		'	image-install:context-variable:VLOGS_HOST:define:vlogs.example.test \' \
		'	image-install:context-variable:HOST_KEY:import:.:ssh/rsa.pub \' \
		'	image-install:exec-update-before:host/install/setup.example.test.txt \' \
		'' \
		'Keywords: \' \
		'	fixture.key \' \
	> "$rigSrc/$rigProject/project.inf"
}

printf '\n== the shell writer ==\n'
rigFresh
(
	. "$rigShell"
	ParseSourceProjectInfToCached "$rigSrc" "$rigCached" "$rigProject"
) > "$rigWork/shell.out" 2> "$rigWork/shell.err"
rigRc=$?
rigCheck "the shell writer returns 0" "$rigRc" "0"
rigShellProvides="$rigCached/$rigProject/project-provides.txt"
[ -f "$rigShellProvides" ] || rigRefuse "the shell writer wrote no $rigShellProvides"
rigCheck "a password-class row keeps its name and its operation, and loses its value" \
	"$( grep -c 'context-variable:VLOGS_PASSWORD:define:REDACTED$' "$rigShellProvides" )" "1"
rigCheck "the array key of an insert row survives, and only its value goes" \
	"$( grep -c 'context-variable:AUTH_TOKEN:insert:promtail2:REDACTED$' "$rigShellProvides" )" "1"
rigCheck "a host value is left as written" \
	"$( grep -c 'context-variable:VLOGS_HOST:define:vlogs.example.test$' "$rigShellProvides" )" "1"
rigCheck "an import row keeps its file reference" \
	"$( grep -c 'context-variable:HOST_KEY:import:.:ssh/rsa.pub$' "$rigShellProvides" )" "1"
rigCheck "no row of the provides file carries the literal" \
	"$( grep -c -F -- "$rigFixtureSecret" "$rigShellProvides" )" "0"

printf '\n== the index writer ==\n'
printf '%s\n' "$rigProject" \
| LC_ALL=C awk -v source="$rigSrc" -f "$rigAwk" > "$rigWork/index.out" 2> "$rigWork/index.err"
rigRc=$?
rigCheck "the index writer returns 0" "$rigRc" "0"
rigCheck "the provides row carries the redacted value" \
	"$( grep -c 'VLOGS_PASSWORD\\:define\\:REDACTED' "$rigWork/index.out" )" "1"
rigCheck "the provides row keeps its declared project" \
	"$( grep -c "^PRJ-PRV-$rigProject=" "$rigWork/index.out" )" "1"
rigCheck "the index keeps the array key of an insert row" \
	"$( grep -c 'AUTH_TOKEN\\:insert\\:promtail2\\:REDACTED' "$rigWork/index.out" )" "1"
rigCheck "the host value is left as written in the index" \
	"$( grep -c 'VLOGS_HOST\\:define\\:vlogs.example.test' "$rigWork/index.out" )" "1"
rigCheck "no index row carries the literal" \
	"$( grep -c -F -- "$rigFixtureSecret" "$rigWork/index.out" )" "0"

printf '\n== a known-positive control ==\n'
## The same probe shape against a subject that must match, so a search that never looked
## cannot be read as a clean result.
printf 'control image-install:context-variable:CONTROL_PASSWORD:define:value\n' > "$rigWork/control.txt"
rigCheck "the probe matches a credential-class row it is given" \
	"$( grep -c 'context-variable:CONTROL_PASSWORD:' "$rigWork/control.txt" )" "1"

printf '\n%s passed, %s failed\n' "$rigPass" "$rigFail"
[ "$rigFail" = 0 ] || exit 1
