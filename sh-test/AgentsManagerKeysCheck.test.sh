#!/usr/bin/env bash
## Behavioural check on --manager-keys-list and --manager-keys-read <key>, the public keys a server shows to
## others, run rather than read, against a rig stand-in built here WITH MADE-UP KEYS: a home of the rig's account
## (MDCI_HOME) with its deploy key and its generated default, a folder of host keys in place of /etc/ssh, and the
## list of repositories the rig keeps. Every key pair is made here, and each PRIVATE file is then written over with
## a mark of its own: a private key that was opened would put its mark into what a call printed, or would be given
## to ssh-keygen, whose every call a stand-in on the rig's PATH writes down.
## Held: the keys are those mdci-public-keys prints, found where it finds them: the key the account uses for git
## and the generated default beside it, both `add-to-git`, then each host key, `trust-on-connect`; each row has its
## label, what it is for, its type, the fingerprint of its public file, the key in short, its file and that it is
## present. NO PRIVATE KEY IS OPENED: ssh-keygen is given public files alone, no mark of a private file stands in
## any output, and where the public file of the deploy key is gone, the case in which that command derives it from
## the private key, the row reads absent and the private file is still not given to anything. The key the ssh
## command of the account names is taken ahead of the deploy key. The read of one key adds the line as one pastes
## it, blanks kept, the public key line for git and the known hosts line for those who connect, and for the deploy
## key the repositories of the rig's list, one with a password in its address left out. A name that is no key is
## refused. From inside a member's session both are refused. And the help pair. Offline; nothing asks a git host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigList="--manager-keys-list" ; rigRead="--manager-keys-read"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
rigKeygen="$( PATH=/usr/bin:/bin command -v ssh-keygen )" || rigRefuse "this machine has no ssh-keygen to make the rig's keys with"
rigTmp="$( mktemp -d -t AgentsManagerKeysCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigMdci="$rigTmp/mdci" ; rigHost="$rigTmp/etc-ssh"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills" "$rigMdci/deploy-keys" "$rigMdci/.ssh" "$rigHost"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
## THE MADE-UP KEYS: the deploy key of the account (mdci where the machine names no other), the generated default,
## a key an ssh command may name, two host keys. Then every private file is written over with its mark.
rigAccount="$( sysrc -n mdcid_user 2> /dev/null || echo mdci )"
rigMake(){ ## file, type, comment
	"$rigKeygen" -q -t "$2" -N '' -C "$3" -f "$1" < /dev/null > /dev/null 2>&1 && [ -s "$1.pub" ] || rigRefuse "a made-up key could not be made: $1"
}
rigMake "$rigMdci/deploy-keys/$rigAccount" ed25519 rig-deploy
rigMake "$rigMdci/.ssh/id_ed25519" ed25519 rig-generated
rigMake "$rigTmp/named-key" ed25519 rig-named
rigMake "$rigHost/ssh_host_ed25519_key" ed25519 rig-host
rigMake "$rigHost/ssh_host_ecdsa_key" ecdsa rig-host
rigNumber=0
for rigOne in "$rigMdci/deploy-keys/$rigAccount" "$rigMdci/.ssh/id_ed25519" "$rigTmp/named-key" "$rigHost/ssh_host_ed25519_key" "$rigHost/ssh_host_ecdsa_key" ; do
	rigNumber=$(( rigNumber + 1 ))
	printf 'RIGPRIVATE-%s-NEVER-TO-BE-READ\n' "$rigNumber" > "$rigOne"
done
printf 'rig/project-one\tgit@git.rig.invalid:rig/project-one.git\nrig/project-two\thttps://rigname:rigpass@git.rig.invalid/rig/project-two.git\n' > "$rigMdci/.mdci-source-repos.txt"
## THE RIG'S OWN PATH: an ssh-keygen that writes down each call and then is the real one; a git that would log.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/keygen.calls"\nexec "%s" "$@"\n' "$rigTmp" "$rigKeygen" > "$rigTmp/bin/ssh-keygen"
for rigOne in ssh curl ; do printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/remote.calls"\nexit 7\n' "$rigOne" "$rigTmp" > "$rigTmp/bin/$rigOne" ; done
chmod +x "$rigTmp/bin"/*
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all" ; : > "$rigTmp/keygen.calls"
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err, both kept in all
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDCI_HOME="$rigMdci" MDAT_MANAGER_KEYS_HOST_DIR="$rigHost" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigWhole(){ LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || : ; }
rigRow(){ ## key -- its row in the last output, TAB written |
	LC_ALL=C awk -F'\t' -v wantKey="$1" '$1 == "key" && $2 == wantKey { gsub( /\t/, "|" ) ; print }' "$rigTmp/out"
}
rigWant(){ ## key, label, group, what it is for, public file -- the row a present key of that file must have, by the real ssh-keygen and the file itself
	local wantType wantText
	wantType="$( cut -d ' ' -f 1 "$5" )" ; wantText="$( cut -d ' ' -f 2 "$5" )"
	printf 'key|%s|%s|%s|%s|%s|%s|%s|%s|present' "$1" "$2" "$3" "$4" "$wantType" "$( "$rigKeygen" -l -f "$5" | LC_ALL=C awk '{ print $2 }' )" "$( printf '%s' "$wantText" | LC_ALL=C awk '{ print ( length( $0 ) > 24 ) ? substr( $0, 1, 12 ) "..." substr( $0, length( $0 ) - 7 ) : $0 }' )" "$5"
}
rigDeployFor="the_deploy_key_of_this_server,_to_list_as_a_deploy_key_on_each_git_repository_it_reads"
rigHostFor="an_ssh_host_key_of_this_server,_for_the_known_hosts_of_those_who_connect_to_it"

echo "-- 1. the list: the keys mdci-public-keys prints, in its two kinds --"
rigRun "$rigList"
rigAssert "the call ends 0 with no error, and the keys come in that command's order: the key for git, the generated default, each host key" "$rigRc $( LC_ALL=C grep -c -E 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C awk '{ print ( $1 > 1 ) ? "errors" : "clean" }' ) $( LC_ALL=C awk -F'\t' '{ printf "%s:%s ", $2, $4 ; if ( $1 != "key" || NF != 10 ) bad++ } END { print "/ " bad + 0 }' "$rigTmp/out" )" "0 clean deploy:add-to-git generated:add-to-git host-ecdsa:trust-on-connect host-ed25519:trust-on-connect / 0"
rigAssert "the deploy key of the account: its label, what it is for, its type, the fingerprint of its public file, the key in short, its file, present" "$( rigRow deploy )" "$( rigWant deploy Deploy_Key_To_Add_To_Git add-to-git "$rigDeployFor" "$rigMdci/deploy-keys/$rigAccount.pub" )"
rigAssert "the generated default beside it, since it is another key" "$( rigRow generated )" "$( rigWant generated Generated_Key_Not_Used_For_Git add-to-git "another_key_the_account_generated,_not_used_for_git_unless_a_repository_is_set_up_with_it" "$rigMdci/.ssh/id_ed25519.pub" )"
rigAssert "a host key by the name of its file, to trust on connecting" "$( rigRow host-ed25519 ) / $( rigRow host-ecdsa )" "$( rigWant host-ed25519 Host_Key_ED25519_To_Trust_On_Connect trust-on-connect "$rigHostFor" "$rigHost/ssh_host_ed25519_key.pub" ) / $( rigWant host-ecdsa Host_Key_ECDSA_To_Trust_On_Connect trust-on-connect "$rigHostFor" "$rigHost/ssh_host_ecdsa_key.pub" )"
rigAssert "the whole key stands in no row of the list: its short form alone" "$( LC_ALL=C grep -c -F -e "$( cut -d ' ' -f 2 "$rigMdci/deploy-keys/$rigAccount.pub" )" "$rigTmp/out" || : )" "0"

echo "-- 2. the read of one key --"
rigRun "$rigRead" deploy
rigAssert "the key for git: its row, the public key line as its file has it, blanks kept, and the repository of the rig's list, the one with a password in its address left out" "$rigRc $( LC_ALL=C sed -n '2,$p' "$rigTmp/out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' '/' ) $( LC_ALL=C sed -n '1p' "$rigTmp/out" | LC_ALL=C tr '\t' '|' )" "0 paste|$( cat "$rigMdci/deploy-keys/$rigAccount.pub" )/register|rig/project-one|git@git.rig.invalid:rig/project-one.git/ $( rigWant deploy Deploy_Key_To_Add_To_Git add-to-git "$rigDeployFor" "$rigMdci/deploy-keys/$rigAccount.pub" )"
rigRun "$rigRead" host-ed25519
rigAssert "a host key: its row, and the line of a known hosts file, the name of this host ahead of the type and the key" "$rigRc $( LC_ALL=C sed -n '2,$p' "$rigTmp/out" | LC_ALL=C tr '\t' '|' | LC_ALL=C tr '\n' '/' )" "0 paste|$( hostname ) $( cut -d ' ' -f 1,2 "$rigHost/ssh_host_ed25519_key.pub" )/"

echo "-- 3. no private key is opened --"
mv "$rigMdci/deploy-keys/$rigAccount.pub" "$rigTmp/deploy.pub.kept"
rigRun "$rigList"
rigAssert "where the public file of the deploy key is gone, the case in which mdci-public-keys derives it from the private key, the row reads absent, with no type, no fingerprint and no key" "$rigRc $( rigRow deploy )" "0 key|deploy|Deploy_Key_To_Add_To_Git|add-to-git|$rigDeployFor|-|-|-|$rigMdci/deploy-keys/$rigAccount.pub|absent"
rigRun "$rigRead" deploy
rigAssert "and its read prints its row alone: nothing to paste" "$rigRc $( wc -l < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "0 1"
mv "$rigTmp/deploy.pub.kept" "$rigMdci/deploy-keys/$rigAccount.pub"
printf '[core]\n\tsshCommand = ssh -i %s -o IdentitiesOnly=yes\n' "$rigTmp/named-key" > "$rigHome/.gitconfig"
rigRun "$rigList"
rigAssert "the key the ssh command of the account names is the key for git, ahead of the deploy key, as that command takes it" "$rigRc $( rigRow deploy )" "0 $( rigWant deploy Deploy_Key_To_Add_To_Git add-to-git "$rigDeployFor" "$rigTmp/named-key.pub" )"
rm -f "$rigHome/.gitconfig"
mkdir -p "$rigTmp/etc-none"
rigPre=( "MDAT_MANAGER_KEYS_HOST_DIR=$rigTmp/etc-none" ) ; rigRun "$rigList" ; rigPre=()
rigAssert "a place with no host key says so: one row for the host keys, absent" "$rigRc $( rigRow host )" "0 key|host|Host_Key_To_Trust_On_Connect|trust-on-connect|$rigHostFor|-|-|-|$rigTmp/etc-none/ssh_host_key.pub|absent"
rigAssert "in every call so far ssh-keygen was given a public file and no other, the private files among them never" "$( LC_ALL=C awk '{ calls++ ; if ( $0 !~ /^-l -f .*\.pub$/ ) bad++ } END { print ( calls > 8 ? "calls" : "few" ) ":" bad + 0 }' "$rigTmp/keygen.calls" )" "calls:0"
rigAssert "no mark of a private file stands anywhere in what any call printed, each private file is as it was written, and nothing was asked of another host" "$( LC_ALL=C grep -c -F -e 'RIGPRIVATE' "$rigTmp/all" || : ) $( LC_ALL=C grep -l -F -e 'NEVER-TO-BE-READ' "$rigMdci/deploy-keys/$rigAccount" "$rigMdci/.ssh/id_ed25519" "$rigTmp/named-key" "$rigHost/ssh_host_ed25519_key" "$rigHost/ssh_host_ecdsa_key" | wc -l | LC_ALL=C tr -d ' ' ) $( [ -e "$rigTmp/remote.calls" ] && echo asked || echo not-asked )" "0 5 not-asked"
rigInclude="$rigHere/AgentsTools.ManagerKeys.include"
rigAssert "the include opens a file in two places alone, a public key by the one reader that refuses a name that is no .pub, and the rig's list of repositories; and it never asks ssh-keygen to derive a key" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -E -e '[^<]< "' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -F -e 'case "$1" in *.pub) ;; *) return 1 ;; esac' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -e 'ssh-keygen -y' -e 'cat ' || : )" "2 1 0"

echo "-- 4. what is refused, and the help pair --"
rigRun "$rigRead" nonesuch
rigAssert "a name that is no key is refused, rc 1, nothing printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigRead: no key is named 'nonesuch' -- nothing is shown. The keys are those $rigList prints" )" "1 0 1"
rigRun "$rigRead" "../deploy-keys/$rigAccount"
rigAssert "and a word that is no name of a key, a path among them, without being repeated" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigRead: syntax is $rigRead <key>, and the word given is no name of a key -- nothing is shown" )" "1 0 1"
rigCallerBad=""
for rigOne in "$rigList" "$rigRead deploy" ; do
	rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
	# shellcheck disable=SC2086
	rigRun $rigOne
	rigPre=()
	[ "$rigRc" = 1 ] && [ ! -s "$rigTmp/out" ] && [ "$( rigWhole "$rigTmp/err" "DistroAgentsTools: $( printf '%s' "${rigOne%% *}" | LC_ALL=C sed -e 's/^--//' ): ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" = 1 ] || rigCallerBad="$rigCallerBad [${rigOne%% *}]"
done
rigAssert "from inside a member's session both are refused by the one rule of the family" "${rigCallerBad:-each refused}" "each refused"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigEntry(){ LC_ALL=C awk -v head="$( printf '\t\t%s' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd" ; }
rigAssert "each of the two has its syntax echo, its syntax line and its entry, and the entries give the three row forms" "$( for rigOne in "$rigList" "$rigRead <key>" ; do printf '%s%s%s ' "$( LC_ALL=C grep -c -x -F -- "echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOne\" >&2" "$rigHere/help/Help.DistroAgentsTools.include" || : )" "$( LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigOne" "$rigHelpMd" || : )" "$( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigOne" )" "$rigHelpMd" || : )" ; done )$( rigEntry "$rigList" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(key <.*>\)`$/\1/p' ) | $( rigEntry "$rigRead <key>" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(paste <.*>\)`$/\1/p' -e 's/^[[:space:]]*`\(register <.*>\)`$/\1/p' | LC_ALL=C tr '\n' '|' )" "111 111 key <key> <label> <group> <purpose> <type> <fingerprint> <short> <file> <state> | paste <line>|register <project> <address>|"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER KEYS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_KEYS: OK (%d assertions, offline, made-up keys)\n' "$rigPasses"
