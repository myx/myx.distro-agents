#!/usr/bin/env bash
## Behavioural check on access-root containment, in BOTH polarities. A parse
## check and a structural check cannot see behaviour: a change that
## canonicalised the candidate path but not the roots passed both and still
## broke `--access-root <symlink>`. This exercises the real function PAIR --
## the defect lived in their composition -- against a real symlink fixture,
## offline: no host, no network, no credential.
set -u
rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "⛔ ERROR: harness not found beside this check: $rigHarness" >&2 ; exit 1 ; }

rigExtract(){
	awk -v fnName="$1" '
		$0 ~ "^" fnName "\\(\\)\\{" { inFn=1 }
		inFn { print }
		inFn && /^\}/ { exit }
	' "$rigHarness"
}
## Refusing to report is this block's whole job. A guard naming only one of the
## two functions let a rename through and printed PASS lines for a run that
## tested nothing; and a name is not a function, so `type -t` below is the only
## test that asks bash what it actually ended up with.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

## A definition, not a fragment: opens with the name asked for and closes on the
## column-0 brace rigExtract stops at.
rigBraceTail=$'\n}'
rigRequireWhole(){ ## name, extracted source
	case "$2" in
		"$1"'(){'*) ;;
		*) rigRefuse "could not extract $1 from $rigHarness" ;;
	esac
	case "$2" in
		*"$rigBraceTail") ;;
		*) rigRefuse "extracted $1 stops before its closing brace -- a fragment, not a definition" ;;
	esac
}

rigResolveDirSrc="$( rigExtract AgentsHarnessResolveDir )"
rigPathAllowedSrc="$( rigExtract AgentsHarnessPathAllowed )"
rigRequireWhole AgentsHarnessResolveDir "$rigResolveDirSrc"
rigRequireWhole AgentsHarnessPathAllowed "$rigPathAllowedSrc"

## rigRun supplies the root through $harnessRoots, the name the harness reads
## it from; renaming that in the harness lands here as well as in the self-check.
case "$rigPathAllowedSrc" in
	*harnessRoots*) ;;
	*) rigRefuse "the extracted AgentsHarnessPathAllowed no longer reads \$harnessRoots, which is the name this rig supplies the roots under" ;;
esac

rigSrc="$rigResolveDirSrc"$'\n'"$rigPathAllowedSrc"
eval "$rigSrc" || rigRefuse "the extracted source did not evaluate"

## Only bash can say whether what was eval'd is callable; the guards above exist
## to name WHICH way the extraction went wrong.
for rigFn in AgentsHarnessResolveDir AgentsHarnessPathAllowed ; do
	[ "$( type -t "$rigFn" 2>/dev/null )" = function ] || rigRefuse "$rigFn is not a function after evaluating the extracted source"
done

rigTmp="$( mktemp -d -t AgentsHarnessContainmentCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/real" "$rigTmp/outside"
echo MARKER > "$rigTmp/real/target.txt"
echo SECRET > "$rigTmp/outside/secret.txt"
ln -s real "$rigTmp/link"

rigFails=0
rigRun(){ ## root, path, expected
	harnessRoots="$( AgentsHarnessResolveDir "$1" )"
	if AgentsHarnessPathAllowed "$2" ; then rigGot=ALLOW ; else rigGot=REFUSE ; fi
	if [ "$rigGot" = "$3" ] ; then
		printf '  PASS  %-6s  root=%-12s path=%s\n' "$rigGot" "${1#$rigTmp/}" "${2#$rigTmp/}"
	else
		printf '  FAIL  got=%-6s want=%-6s root=%-12s path=%s\n' "$rigGot" "$3" "${1#$rigTmp/}" "${2#$rigTmp/}"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- MUST ALLOW (a refusal here locks an agent out of its own grant) --"
rigRun "$rigTmp/real" "$rigTmp/real/target.txt" ALLOW
rigRun "$rigTmp/link" "$rigTmp/link/target.txt" ALLOW
rigRun "$rigTmp/link" "$rigTmp/real/target.txt" ALLOW
rigRun "$rigTmp/real" "$rigTmp/link/target.txt" ALLOW
rigRun "$rigTmp/real" "$rigTmp/real" ALLOW
echo "-- MUST REFUSE (an allow here is an escape) --"
rigRun "$rigTmp/real" "/" REFUSE
rigRun "$rigTmp/real" "/etc/passwd" REFUSE
rigRun "$rigTmp/real" "$rigTmp" REFUSE
rigRun "$rigTmp/real" "$rigTmp/outside/secret.txt" REFUSE
rigRun "$rigTmp/real" "$rigTmp/real/../outside/secret.txt" REFUSE
rigRun "$rigTmp/real" "relative/path" REFUSE
rigRun "$rigTmp/real" "" REFUSE

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTAINMENT CHECK FAILED: $rigFails case(s)" >&2 ; exit 1
fi
echo "CONTAINMENT: OK (both polarities)"
