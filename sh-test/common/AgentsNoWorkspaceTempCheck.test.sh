#!/usr/bin/env bash
## Behavioural check on the two places that run where a workspace may not exist, and keep their scratch in the running
## user's own home and never in the system's temp folder (the owner's rule, held for every package by
## AgentsTempNamesCheck; the folder is shared with every user of the machine). Run rather than read, offline: no deploy,
## no ssh, no host. Held:
##   1. the prefix of the deploy script, which runs on the target host (myx.distro-deploy ImageDeploy.prefix.include):
##      its working folder is made under the home's .local/temp, the script works in it, and its own cleanup removes it
##      at the end; with no HOME it stops with that said, and makes nothing
##   2. the control-socket block of the emitted sync script (myx.distro-system DistroImage.SyncScriptMaker.include,
##      --intern-ssh-mx-root-temp-block): the workspace path comes first; with no workspace the folder is the home's
##      .ssh/cmx, made private (700) where it was missing; a path over 60 characters (a socket path must stay under about
##      104 bytes) is shortened by a link named .ssh/cmx-<pid> in the home, which the run removes when it ends (the
##      trap names the link as the emitted script runs, not as it is generated); with no HOME it stops with that said.
##      What the block emits holds no path of the system's temp folder, and no temp-dir variable.
## Red before: the prefix made its folder by mktemp -t, and the block fell back to the system's temp folder.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPrefix="$MDLT_ORIGIN/myx/myx.distro-deploy/sh-lib/ImageDeploy.prefix.include"
rigMaker="$MDLT_ORIGIN/myx/myx.distro-system/sh-lib/DistroImage.SyncScriptMaker.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPrefix" ] || rigRefuse "the deploy prefix is not at the origin this workspace resolves: $rigPrefix"
[ -f "$rigMaker" ] || rigRefuse "the sync script maker is not at the origin this workspace resolves: $rigMaker"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsNoWorkspaceTempCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## The words that must not be emitted, from parts, so that this file is read like every other.
rigRoot="/t""mp"
rigVar="TMP""DIR"
## A logger of the rig first on PATH: the prefix posts a debug line through it, and the rig posts none.
mkdir -p "$rigTmp/bin" "$rigTmp/cwd"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$rigTmp/bin/logger"
chmod +x "$rigTmp/bin/logger"
rigMode(){ ## path -- its mode string
	ls -ld "$1" 2> /dev/null | LC_ALL=C cut -c1-10
}

echo "-- 1. the prefix of the deploy script keeps its folder in the home of the running user --"
rigHome1="$rigTmp/home1" ; mkdir -p "$rigHome1"
rigRc1=0
( cd "$rigTmp/cwd" && env -i HOME="$rigHome1" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" sh -c '. "$1" ; echo "RIG-DIR:$(pwd -P)" ; echo "RIG-VAR:$MDSC_IMAGE_UNPACK_DIR"' rig "$rigPrefix" ) > "$rigTmp/prefix.out" 2> "$rigTmp/prefix.err" || rigRc1=$?
rigDir1="$( LC_ALL=C sed -n 's/^RIG-DIR://p' "$rigTmp/prefix.out" | head -1 )"
rigVar1="$( LC_ALL=C sed -n 's/^RIG-VAR://p' "$rigTmp/prefix.out" | head -1 )"
rigRealHome1="$( cd "$rigHome1" && pwd -P )"
rigAssert "the script ran to its end, rc 0" "$rigRc1" "0"
rigAssert "it worked in a folder made under the home's .local/temp, named mdsc-deploy-remote-..." "$( case "$rigDir1" in ("$rigRealHome1/.local/temp/mdsc-deploy-remote-"?*) printf yes ;; (*) printf '%s' "$rigDir1" ;; esac )" yes
rigAssert "the folder the script names for its unpacking is that one" "$( [ -n "$rigVar1" ] && [ "$rigVar1" = "$rigDir1" ] && printf same || printf '%s' "$rigVar1" )" same
rigAssert "its own cleanup removed the folder at the end, and the home holds nothing else than .local/temp" "$( [ ! -e "$rigDir1" ] && printf gone ) $( cd "$rigHome1" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "gone ./.local ./.local/temp "
rigAssert "the prefix text takes no -t mktemp, and holds no path of the system's temp folder and no temp-dir variable" "$( LC_ALL=C grep -c -E -e "(^|[^A-Za-z0-9_.})])$rigRoot([^A-Za-z0-9_]|\$)" -e "(^|[^A-Za-z0-9_])$rigVar([^A-Za-z0-9_]|\$)" -e 'mk''temp -[a-z]*t' "$rigPrefix" || : )" "0"
rigRc1b=0
( cd "$rigTmp/cwd" && env -i PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" sh -c '. "$1" ; echo "RIG-REACHED"' rig "$rigPrefix" ) > "$rigTmp/prefix-nohome.out" 2> "$rigTmp/prefix-nohome.err" || rigRc1b=$?
rigAssert "with no HOME it stops, says HOME, and reaches nothing after" "$( [ "$rigRc1b" -ne 0 ] && printf stopped ) $( LC_ALL=C grep -c 'HOME' "$rigTmp/prefix-nohome.err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( LC_ALL=C grep -c 'RIG-REACHED' "$rigTmp/prefix-nohome.out" )" "stopped said 0"
rigAssert "and it made nothing where it stood" "$( find "$rigTmp/cwd" -mindepth 1 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

echo "-- 2. the control-socket block of the emitted sync script --"
rigRcE=0
bash -c '. "$1" --intern-ssh-mx-root-temp-block' rig "$rigMaker" > "$rigTmp/block.sh" 2> "$rigTmp/block.err" || rigRcE=$?
rigAssert "the block is emitted, rc 0, and holds no path of the system's temp folder and no temp-dir variable" "$rigRcE $( [ -s "$rigTmp/block.sh" ] && printf emitted ) $( LC_ALL=C grep -c -E -e "(^|[^A-Za-z0-9_.})])$rigRoot([^A-Za-z0-9_]|\$)" -e "(^|[^A-Za-z0-9_])$rigVar([^A-Za-z0-9_]|\$)" "$rigTmp/block.sh" || : )" "0 emitted 0"
rigAssert "it names the workspace folder first, then the home's .ssh/cmx, and the link .ssh/cmx-\$\$ of the shortening" "$( LC_ALL=C grep -c -F -e 'tmpdir="$MMDAPP/.local/temp/ssh"' -e 'tmpdir="${HOME:?}/.ssh/cmx"' -e 'shorttmp="${HOME:?}/.ssh/cmx-$$"' "$rigTmp/block.sh" )" "3"
## no workspace: the home's own folder. The home of a rig lies under a long path, so the block shortens it by the link
## too (a home of a user is short: there the folder itself is the socket path).
rigHome2="$rigTmp/home2" ; mkdir -p "$rigHome2"
rigRc2=0
( cd "$rigTmp/cwd" && env -i HOME="$rigHome2" PATH="/usr/bin:/bin:/usr/sbin:/sbin" sh -c '. "$1" ; echo "RIG-SOCK:$tmpdir" ; echo "RIG-PID:$$" ; echo "RIG-LINK:$( cd "$tmpdir" && pwd -P )" ; echo "RIG-HOME:$( cd "$HOME" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr "\n" " " )"' rig "$rigTmp/block.sh" ) > "$rigTmp/block2.out" 2> "$rigTmp/block2.err" || rigRc2=$?
rigSock2="$( LC_ALL=C sed -n 's/^RIG-SOCK://p' "$rigTmp/block2.out" | head -1 )"
rigPid2="$( LC_ALL=C sed -n 's/^RIG-PID://p' "$rigTmp/block2.out" | head -1 )"
rigAssert "with no workspace the folder is the home's .ssh/cmx, made private, and .ssh with it; the socket path is the link beside it" "$rigRc2 [${rigSock2#$rigHome2/}] $( rigMode "$rigHome2/.ssh/cmx" ) $( rigMode "$rigHome2/.ssh" ) $( LC_ALL=C sed -n 's/^RIG-LINK://p' "$rigTmp/block2.out" | head -1 )" "0 [.ssh/cmx-$rigPid2] drwx------ drwx------ $( cd "$rigHome2/.ssh/cmx" && pwd -P )"
rigAssert "while it runs the home holds .ssh, the folder and the link, and nothing else" "$( LC_ALL=C sed -n 's/^RIG-HOME://p' "$rigTmp/block2.out" | head -1 )" "./.ssh ./.ssh/cmx ./.ssh/cmx-$rigPid2 "
rigAssert "when the run ends the link it made is gone, and the private folder stays" "$( cd "$rigHome2" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "./.ssh ./.ssh/cmx "
## a folder that stands is left as it is
chmod 750 "$rigHome2/.ssh/cmx"
( cd "$rigTmp/cwd" && env -i HOME="$rigHome2" PATH="/usr/bin:/bin:/usr/sbin:/sbin" sh -c '. "$1"' rig "$rigTmp/block.sh" ) > /dev/null 2>&1
rigAssert "a folder that stands is not touched again" "$( rigMode "$rigHome2/.ssh/cmx" )" "drwxr-x---"
## a workspace, whose path is over 60 characters: the socket folder is the workspace's, and a link in the home stands for it
rigHome3="$rigTmp/home3" ; mkdir -p "$rigHome3" "$rigTmp/workspace-with-a-path-long-enough-to-pass-sixty-characters/.local"
rigWs3="$rigTmp/workspace-with-a-path-long-enough-to-pass-sixty-characters"
rigRc3=0
( cd "$rigTmp/cwd" && env -i HOME="$rigHome3" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs3" sh -c '. "$1" ; echo "RIG-SOCK:$tmpdir" ; echo "RIG-PID:$$" ; echo "RIG-LINK:$( cd "$tmpdir" && pwd -P )" ; echo "RIG-MODE:$( ls -ld "$HOME/.ssh" | cut -c1-10 )" ; echo "RIG-HOME:$( cd "$HOME" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr "\n" " " )"' rig "$rigTmp/block.sh" ) > "$rigTmp/block3.out" 2> "$rigTmp/block3.err" || rigRc3=$?
rigSock3="$( LC_ALL=C sed -n 's/^RIG-SOCK://p' "$rigTmp/block3.out" | head -1 )"
rigPid3="$( LC_ALL=C sed -n 's/^RIG-PID://p' "$rigTmp/block3.out" | head -1 )"
rigAssert "with a long workspace path the socket path is the link .ssh/cmx-<pid> in the home" "$rigRc3 [${rigSock3#$rigHome3/}] [.ssh/cmx-$rigPid3]" "0 [.ssh/cmx-$rigPid3] [.ssh/cmx-$rigPid3]"
rigAssert "the link leads to the workspace's own folder, and .ssh is private" "$( LC_ALL=C sed -n 's/^RIG-LINK://p' "$rigTmp/block3.out" | head -1 ) $( LC_ALL=C sed -n 's/^RIG-MODE://p' "$rigTmp/block3.out" | head -1 )" "$( cd "$rigWs3/.local/temp/ssh" && pwd -P ) drwx------"
rigAssert "while it runs the home holds only .ssh and that link" "$( LC_ALL=C sed -n 's/^RIG-HOME://p' "$rigTmp/block3.out" | head -1 )" "./.ssh ./.ssh/cmx-$rigPid3 "
rigAssert "when the run ends no cmx-<pid> link is left in the home, and the workspace folder stays" "$( cd "$rigHome3" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' ) $( [ -d "$rigWs3/.local/temp/ssh" ] && printf stays )" "./.ssh  stays"
## no HOME and no workspace: stops with that said
rigHome4="$rigTmp/home4" ; mkdir -p "$rigHome4"
rigRc4=0
( cd "$rigHome4" && env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" sh -c '. "$1" ; echo "RIG-REACHED"' rig "$rigTmp/block.sh" ) > "$rigTmp/block4.out" 2> "$rigTmp/block4.err" || rigRc4=$?
rigAssert "with no HOME and no workspace it stops, says HOME, reaches nothing after, and makes nothing" "$( [ "$rigRc4" -ne 0 ] && printf stopped ) $( LC_ALL=C grep -c 'HOME' "$rigTmp/block4.err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( LC_ALL=C grep -c 'RIG-REACHED' "$rigTmp/block4.out" ) $( find "$rigHome4" -mindepth 1 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "stopped said 0 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ NO WORKSPACE TEMP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'NO_WORKSPACE_TEMP: OK (%d assertions, offline)\n' "$rigPasses"
