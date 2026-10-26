#!/usr/bin/env bash
## Behavioural check on the keys this account trusts, added and removed in its own authorized keys (C1 of the refactorings epic),
## run rather than read: --manager-keys-trust-add and --manager-keys-trust-delete, against a rig account built here (its HOME,
## where the tools look for the ssh home), with the real ssh-keygen. Nothing of this machine's own ssh home is read or written,
## which the last section asserts.
## Held (C1: "Server Keys: adding and deleting the keys we trust (the native authorized_keys)"):
##   1. trust-add reads one public key line from the standard input and appends it with a line end of its own to the account's
##      authorized keys, the folder made with mode 700 where it is not there, the file made 600; one row `added`, its number
##      among them, the file, the type and the fingerprint, and nothing of the private key; the list then reads it `present`
##   2. trust-add refuses: an empty line, a line that is no key, a second line, a key trusted already, and a wrong count of words
##   3. trust-delete removes the one line that holds the key, named trusted-<n> as the list prints it, and every other line,
##      options, comments and blanks, stays as it stands; one row `deleted`; the list then reads one fewer
##   4. trust-delete refuses: a word that is no trusted key, an n of 0, an n past the last, and where there is no file
##   5. from inside a member's session each is refused; the help pair of each
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
rigKeygen="$( PATH=/usr/bin:/bin command -v ssh-keygen )" || rigRefuse "this machine has no ssh-keygen"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerKeysTrustCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigHost="$rigTmp/etc-ssh"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigHost"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
[ "$rigHome" != "$HOME" ] || rigRefuse "the rig account is the real one"
rigRealBefore="$( cksum < "$HOME/.ssh/authorized_keys" 2> /dev/null || echo none )"
## two keys made up for the rig, whose public lines are what is added and what is trusted, with the real ssh-keygen
"$rigKeygen" -q -t ed25519 -N '' -C rig-trust-one -f "$rigTmp/trust-one" < /dev/null > /dev/null 2>&1 || rigRefuse "a made-up key could not be made"
"$rigKeygen" -q -t ed25519 -N '' -C rig-trust-two -f "$rigTmp/trust-two" < /dev/null > /dev/null 2>&1 || rigRefuse "a made-up key could not be made"
rigOne="$( cat "$rigTmp/trust-one.pub" )" ; rigTwo="$( cat "$rigTmp/trust-two.pub" )"
rigOnePrint="$( "$rigKeygen" -l -f "$rigTmp/trust-one.pub" | LC_ALL=C awk '{ print $2 }' )"
rigTwoPrint="$( "$rigKeygen" -l -f "$rigTmp/trust-two.pub" | LC_ALL=C awk '{ print $2 }' )"
rigFile="$rigHome/.ssh/authorized_keys"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace as the rig account, nothing on the standard input
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_MANAGER_KEYS_HOST_DIR="$rigHost" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigRunIn(){ ## text, tool arguments... -- one dispatcher call, with that text as its standard input
	rigRc=0
	( cd "$rigWs" && printf '%s' "$1" | env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_MANAGER_KEYS_HOST_DIR="$rigHost" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigMode(){ stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" ; }
rigKeys(){ ## what the list reads of the trusted group: key:state over the rows
	LC_ALL=C awk -F'\t' '$1 == "key" && $4 == "trusted" { printf "%s:%s ", $2, $10 }' "$rigTmp/out"
}

echo "-- 1. trust-add: a line appended to the account's authorized keys --"
rigRun --manager-keys-list
rigAssert "before it, the trusted group has no key and says why" "$( LC_ALL=C awk -F'\t' '$1 == "group" && $2 == "trusted" { print $3, $5 }' "$rigTmp/out" )" "0 no_authorized_keys_file_stands_at_$( printf '%s' "$rigFile" | LC_ALL=C tr ' ' '_' )"
rigRunIn "$rigOne"$'\n' --manager-keys-trust-add
rigAssert "the call ends 0, with no error, and prints one row: added, its number, the file, its type and its fingerprint" "$rigRc $( rigFlat "$rigTmp/out" )" "0 added trusted-1 $rigFile ssh-ed25519 $rigOnePrint/"
rigAssert "the file is the account's own, in its ssh home: the folder 700, the file 600" "$( rigMode "$rigHome/.ssh" ) $( rigMode "$rigFile" )" "700 600"
rigAssert "the file holds the line, whole, with a line end of its own, and nothing of the private key" "$( cat "$rigFile" ) $( LC_ALL=C grep -c -F -e 'PRIVATE KEY' -e "$( sed -n 2p "$rigTmp/trust-one" )" "$rigTmp/all" )" "$rigOne 0"
rigRun --manager-keys-list
rigAssert "the list now reads it present, trusted-1" "$( rigKeys )" "trusted-1:present "

echo "-- 2. trust-add: what is refused --"
rigSum="$( cksum "$rigFile" )"
rigRunIn "" --manager-keys-trust-add
rigAssert "an empty line is refused, nothing changed" "$rigRc $( [ "$( cksum "$rigFile" )" = "$rigSum" ] && echo same ) $( LC_ALL=C grep -c -F -- 'not one public key line' "$rigTmp/err" )" "1 same 1"
rigRunIn "not a key line" --manager-keys-trust-add
rigAssert "a line that is no key is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'not one public key line' "$rigTmp/err" )" "1 1"
rigRunIn "$rigOne"$'\n'"second" --manager-keys-trust-add
rigAssert "a second line is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'not one public key line' "$rigTmp/err" )" "1 1"
rigRunIn "$rigOne"$'\n' --manager-keys-trust-add
rigAssert "a key trusted already is refused, nothing changed" "$rigRc $( [ "$( cksum "$rigFile" )" = "$rigSum" ] && echo same ) $( LC_ALL=C grep -c -F -- 'trusted already' "$rigTmp/err" )" "1 same 1"
rigRunIn "$rigOne"$'\n' --manager-keys-trust-add extra
rigAssert "a word of argument is refused with its syntax" "$rigRc $( LC_ALL=C grep -c -F -- 'syntax is --manager-keys-trust-add, the public key line on the standard input' "$rigTmp/err" )" "1 1"

echo "-- 3. trust-delete: the one line removed, the rest as it stands --"
## a file with what must stay: a blank line, a comment and an options line, then the key to remove
printf '\n# kept comment\nrestrict,pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOTHINGATALL00000000000000000000000000000000000000000000000000 kept-option\n%s\n' "$rigOne" > "$rigFile"
chmod 600 "$rigFile"
rigRun --manager-keys-list
rigAssert "the list counts the keys it holds, the options line among them, the blank and the comment not" "$( LC_ALL=C awk -F'\t' '$1 == "key" && $4 == "trusted" { printf "%s ", $2 }' "$rigTmp/out" )" "trusted-1 trusted-2 "
rigRun --manager-keys-trust-delete trusted-2
rigAssert "trusted-2, the key rig-trust-one, is removed: one row deleted, and the blank, the comment and the options line stay as they stand" "$rigRc $( rigFlat "$rigTmp/out" )" "0 deleted trusted-2 $rigFile ssh-ed25519 $rigOnePrint/"
rigAssert "the file now holds the blank, the comment and the options line alone" "$( LC_ALL=C tr '\n' '|' < "$rigFile" )" "|# kept comment|restrict,pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOTHINGATALL00000000000000000000000000000000000000000000000000 kept-option|"
rigRun --manager-keys-list
rigAssert "the list then reads the one key that is left, renumbered" "$( rigKeys )" "trusted-1:present "

echo "-- 4. trust-delete: what is refused --"
rigSum="$( cksum "$rigFile" )"
rigRun --manager-keys-trust-delete trusted-2
rigAssert "an n past the last is refused, nothing changed" "$rigRc $( [ "$( cksum "$rigFile" )" = "$rigSum" ] && echo same ) $( LC_ALL=C grep -c -F -- 'holds no trusted key trusted-2' "$rigTmp/err" )" "1 same 1"
rigRun --manager-keys-trust-delete trusted-0
rigAssert "an n of 0 is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'no trusted key' "$rigTmp/err" )" "1 1"
rigRun --manager-keys-trust-delete deploy
rigAssert "a word that is no trusted key is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'no trusted key' "$rigTmp/err" )" "1 1"
rigRun --manager-keys-trust-delete
rigAssert "no word is refused with its syntax" "$rigRc $( LC_ALL=C grep -c -F -- 'syntax is --manager-keys-trust-delete <trusted-<n>>' "$rigTmp/err" )" "1 1"
rm -f "$rigFile"
rigRun --manager-keys-trust-delete trusted-1
rigAssert "where there is no file, it refuses" "$rigRc $( LC_ALL=C grep -c -F -- 'no authorized keys file stands at' "$rigTmp/err" )" "1 1"

echo "-- 5. from a member's session, and the help pair --"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigBad=""
for rigOp in --manager-keys-trust-add --manager-keys-trust-delete ; do
	if [ "$rigOp" = --manager-keys-trust-add ] ; then rigRunIn "$rigOne"$'\n' "$rigOp" ; else rigRun "$rigOp" trusted-1 ; fi
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [$rigOp]"
done
rigAssert "a member's session is refused each, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigPre=()
rigBad=""
for rigOp in --manager-keys-trust-add --manager-keys-trust-delete ; do
	case "$rigOp" in --manager-keys-trust-add) rigWant='--manager-keys-trust-add' ;; *) rigWant='--manager-keys-trust-delete <trusted-<n>>' ;; esac
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh $rigWant" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOp]"
	LC_ALL=C grep -q -E -- "^[[:space:]]+$rigWant\$" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOp]"
done
rigAssert "each of the two has its syntax line and its help entry" "${rigBad:- all paired}" " all paired"

echo "-- 6. nothing of the real account was touched --"
rigAssert "the real authorized keys are as they were" "$( cksum < "$HOME/.ssh/authorized_keys" 2> /dev/null || echo none )" "$rigRealBefore"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
