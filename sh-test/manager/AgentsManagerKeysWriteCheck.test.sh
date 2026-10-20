#!/usr/bin/env bash
## Behavioural check on the server keys the console's configuration wizards make, replace and remove (F11.7 of the refactorings epic),
## run rather than read: --manager-keys-generate, --manager-keys-regenerate and --manager-keys-delete, against a rig account built
## here (its HOME, where the tools look for the ssh home), with the real ssh-keygen. Nothing of this machine's own ssh home or git
## settings is read or written, which the last section asserts.
## Held (F11.7: "`.local` generate server keys. `.local` delete or regenerate server keys, with warnings"; the coordinator's ruling:
## generate (ssh-keygen ed25519 no passphrase into the ssh home, refuses an existing file), regenerate (replaces the pair), delete
## (removes the pair), host keys under /etc/ssh never touched, each destructive step behind its warning and the typed confirm in the
## console):
##   1. generate makes the pair of the key where there is none, in the place the list names it: the ssh home of the account with
##      mode 700, the private file 600, the public file 644, ed25519 with no passphrase and the comment <account>@<host>; one row
##      `generated` with the key, the private file, the type and the fingerprint, and nothing of the private key; the list then
##      reads it present. Where a file of it is there already it refuses and changes nothing
##   2. the key git is set to use (core.sshCommand -i) is the key made and replaced and removed, in that place
##   3. regenerate replaces a pair that stands with a new one, in the same files, the fingerprint another, no file of its making left
##      beside it; where the key has no private file of its own, or a link in its place, it refuses and changes nothing
##   4. delete removes the pair; where there is no file it refuses
##   5. a host key of the server is none of these: refused whatever the operation, its files untouched. A name that is no key, a word
##      that is no name and a wrong count of words are refused, and the refusals repeat nothing of what was given
##   6. from inside a member's session each is refused; the help pair of each
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
rigKeygen="$( PATH=/usr/bin:/bin command -v ssh-keygen )" || rigRefuse "this machine has no ssh-keygen"
command -v git > /dev/null 2>&1 || rigRefuse "this machine has no git"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerKeysWriteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigHost="$rigTmp/etc-ssh"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigHost"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
rigUser="$( id -un )" ; rigHostName="$( hostname )"
[ "$rigHome" != "$HOME" ] || rigRefuse "the rig account is the real one"
## the real account's own ssh home and git settings, to prove they stay as they were
rigRealBefore="$( cksum < "$HOME/.ssh/id_ed25519.pub" 2> /dev/null || echo none ) $( cksum < "$HOME/.gitconfig" 2> /dev/null || echo none )"
## two made-up host keys of the server, which no operation here may touch
"$rigKeygen" -q -t ed25519 -N '' -C rig-host -f "$rigHost/ssh_host_ed25519_key" < /dev/null > /dev/null 2>&1 || rigRefuse "a made-up host key could not be made"
rigHostSum="$( cksum "$rigHost"/* | LC_ALL=C sort )"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace as the rig account; rc in rigRc, stdout in out, stderr in err, both kept in all
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_MANAGER_KEYS_HOST_DIR="$rigHost" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigMode(){ stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" ; }
rigPrint(){ ## public file -- the fingerprint of it
	"$rigKeygen" -l -f "$1" | LC_ALL=C awk '{ print $2 }'
}
rigPrivate="$rigHome/.ssh/id_ed25519"

echo "-- 1. generate: a pair where there is none --"
rigRun --manager-keys-list
rigAssert "before it, the key for git is absent" "$( LC_ALL=C awk -F'\t' '$1 == "key" && $2 == "deploy" { print $10 }' "$rigTmp/out" )" "absent"
rigRun --manager-keys-generate deploy
rigAssert "the call ends 0, with no error, and prints one row: generated, the key, its private file, its type and its fingerprint" "$rigRc $( rigTroubles ) $( rigFlat "$rigTmp/out" )" "0 0 generated deploy $rigPrivate ssh-ed25519 $( rigPrint "$rigPrivate.pub" )/"
rigAssert "the pair is in the ssh home of the account: the home mode 700, the private file 600, the public file 644" "$( rigMode "$rigHome/.ssh" ) $( rigMode "$rigPrivate" ) $( rigMode "$rigPrivate.pub" )" "700 600 644"
rigAssert "it is ed25519 with no passphrase, its comment <account>@<host>" "$( cut -d ' ' -f 1 "$rigPrivate.pub" ) $( cut -d ' ' -f 3 "$rigPrivate.pub" ) $( "$rigKeygen" -y -P '' -f "$rigPrivate" > /dev/null 2>&1 && echo opens )" "ssh-ed25519 $rigUser@$rigHostName opens"
rigAssert "nothing of the private key is in what the call printed" "$( LC_ALL=C grep -c -F -e 'PRIVATE KEY' -e "$( sed -n 2p "$rigPrivate" )" "$rigTmp/all" )" "0"
rigRun --manager-keys-list
rigAssert "the list now reads it present, and the key the tools connect out with, which is the same file by default, too" "$( LC_ALL=C awk -F'\t' '$1 == "key" && ( $2 == "deploy" || $2 == "outgoing" ) { printf "%s:%s ", $2, $10 }' "$rigTmp/out" )" "deploy:present outgoing:present "
rigSumBefore="$( cksum "$rigPrivate" "$rigPrivate.pub" )"
rigRun --manager-keys-generate deploy
rigAssert "where a file of it is there already it refuses, says how to replace it, and changes nothing" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- '--manager-keys-regenerate' "$rigTmp/err" ) $( [ "$( cksum "$rigPrivate" "$rigPrivate.pub" )" = "$rigSumBefore" ] && echo same )" "1 0 1 same"

echo "-- 2. the key git is told to use is the one --"
printf -v rigNamed '%s' "$rigTmp/named/key-for-git"
git config --file "$rigHome/.gitconfig" core.sshCommand "ssh -i $rigNamed -o IdentitiesOnly=yes"
rigRun --manager-keys-generate deploy
rigAssert "the key git names is made where git names it, in a folder made for it with mode 700; the generated default stays as it was" "$rigRc $( rigFlat "$rigTmp/out" | cut -d ' ' -f 1-3 ) $( rigMode "$rigTmp/named" ) $( [ "$( cksum "$rigPrivate" "$rigPrivate.pub" )" = "$rigSumBefore" ] && echo same )" "0 generated deploy $rigNamed 700 same"
rigNamedPrint="$( rigPrint "$rigNamed.pub" )"

echo "-- 3. regenerate: the pair replaced --"
rigRun --manager-keys-regenerate deploy
rigAssert "a pair that stands is replaced in the same files: one row, regenerated, another fingerprint than before, the modes as they were" "$rigRc $( rigFlat "$rigTmp/out" | cut -d ' ' -f 1-3 ) $( [ "$( rigPrint "$rigNamed.pub" )" != "$rigNamedPrint" ] && echo another ) $( rigMode "$rigNamed" ) $( rigMode "$rigNamed.pub" )" "0 regenerated deploy $rigNamed another 600 644"
rigAssert "the row's fingerprint is that of the new public file, and no file of its making is left beside the key" "$( rigFlat "$rigTmp/out" | cut -d ' ' -f 4-5 ) $( ls "$rigTmp/named" | LC_ALL=C tr '\n' ' ' )" "ssh-ed25519 $( rigPrint "$rigNamed.pub" )/ key-for-git key-for-git.pub "
rigRun --manager-keys-regenerate generated
rigAssert "the generated default, which stands too, is replaced by its own call and the named key is not touched" "$rigRc $( rigFlat "$rigTmp/out" | cut -d ' ' -f 1-3 ) $( [ "$( cksum "$rigPrivate" "$rigPrivate.pub" )" != "$rigSumBefore" ] && echo another )" "0 regenerated generated $rigPrivate another"
rm -f "$rigNamed" "$rigNamed.pub"
rigRun --manager-keys-regenerate deploy
rigAssert "a key with no private file of its own is not regenerated: refused, nothing made, and it points at generate" "$rigRc $( [ -e "$rigNamed" ] && echo made || echo none ) $( LC_ALL=C grep -c -F -- '--manager-keys-generate' "$rigTmp/err" )" "1 none 1"
ln -s "$rigPrivate" "$rigNamed"
rigRun --manager-keys-regenerate deploy
rigAssert "nor is a link in the place of the private file: refused, the link and what it points at stay" "$rigRc $( [ -L "$rigNamed" ] && echo link ) $( rigPrint "$rigPrivate.pub" | wc -l | LC_ALL=C tr -d ' ' )" "1 link 1"
rm -f "$rigNamed"

echo "-- 4. delete: the pair removed --"
rigRun --manager-keys-generate deploy
rigRun --manager-keys-delete deploy
rigAssert "both files of the key are removed: one row, deleted, the key and its private file, nothing else of the other key" "$rigRc $( rigFlat "$rigTmp/out" | cut -d ' ' -f 1-3 ) $( [ -e "$rigNamed" ] || [ -e "$rigNamed.pub" ] && echo left || echo gone ) $( [ -f "$rigPrivate" ] && echo other-stays )" "0 deleted deploy $rigNamed gone other-stays"
rigRun --manager-keys-delete deploy
rigAssert "where there is no file of it, it refuses" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"

echo "-- 5. the host keys are none of these, and what is no key --"
rigBad=""
for rigOp in generate regenerate delete ; do
	rigRun --manager-keys-$rigOp host-ed25519
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] && [ "$( cksum "$rigHost"/* | LC_ALL=C sort )" = "$rigHostSum" ] || rigBad="$rigBad [$rigOp]"
done
rigAssert "a host key of the server is refused by each, its files as they were" "${rigBad:- all refused}" " all refused"
rigRun --manager-keys-generate no-such-key
rigAssert "a name that is no key is refused, and not repeated" "$rigRc $( LC_ALL=C grep -c -F -- 'no-such-key' "$rigTmp/err" || : ) $( LC_ALL=C grep -c -F -- 'no key is named' "$rigTmp/err" )" "1 1 1"
rigRun --manager-keys-delete 'bad;name'
rigAssert "a word that is no name of a key is refused and not repeated" "$rigRc $( LC_ALL=C grep -c -F -- 'bad;name' "$rigTmp/err" || : )" "1 0"
rigRun --manager-keys-generate
rigAssert "no word is refused with its syntax" "$rigRc $( LC_ALL=C grep -c -F -- 'syntax is --manager-keys-generate <key>' "$rigTmp/err" )" "1 1"
rigRun --manager-keys-regenerate deploy extra
rigAssert "a second word is refused" "$rigRc" "1"

echo "-- 6. from a member's session, and the help pair --"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigBad=""
for rigOp in generate regenerate delete ; do
	rigRun --manager-keys-$rigOp deploy
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [$rigOp]"
done
rigAssert "a member's session is refused each, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigPre=()
rigBad=""
for rigOp in generate regenerate delete ; do
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh --manager-keys-$rigOp <key>" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOp]"
	LC_ALL=C grep -q -E -- "^[[:space:]]+--manager-keys-$rigOp <key>\$" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOp]"
done
rigAssert "each of the three has its syntax line and its help entry" "${rigBad:- all paired}" " all paired"

echo "-- 7. nothing of the real account was touched --"
rigAssert "the real ssh key and the real git settings are as they were" "$( cksum < "$HOME/.ssh/id_ed25519.pub" 2> /dev/null || echo none ) $( cksum < "$HOME/.gitconfig" 2> /dev/null || echo none )" "$rigRealBefore"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
