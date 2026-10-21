#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The rig of the checks of the testing system (AgentsTestbedCheck, AgentsRetestQueueOptionsCheck, AgentsRequestTestsCheck): a machine of its own,
## built under $rigTmp -- a HOME, whose .agents/magic-team/retest-queue is the machine's one queue; a workspace whose own tree (source/) is a copy of
## the tooling as it stands at the origin, with three tiny tests and the test runner in place of the package's tests, and beside it a scratch copy with
## two; a team data root with the inbox of magic-tester and of two members; and a skillset root with those members. Every call goes through one
## `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's tree, so nothing reaches outside it.
## Sourced by the check, after rig-processes.include.sh and rig-temp.include.sh, with rigTmp made, rigRefuse and rigAssert defined:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-retest-machine.include.sh"
##   rigMachineSetup                  builds the rig
##   rigCall <prefix> <words...>      one call of the script in rigScript (DistroAgentsTools, DistroAgentsTesting or AgentTestingTools), in the background;
##                                    <prefix>.out .err, its pid in rigLast         rigEnd <pid>  rigOp <prefix> <words...>  (rigRc)
##   rigAs <member>                   the member the calls act as (MDAT_SPAWN_AGENT); empty for the console
##   rigDirective <sh-test path|off> [host glob]   the testing directive in the project.inf of the rig's package (sh-test, any host, to begin with): the folders eligible for the nightly and the oldest untested
##   rigFresh   rigRoot   rigTests   rigUntil   rigBegins   rigBegun   rigHolds   rigLine   rigStands   rigInbox
##

rigMachineSetup(){
	local rigSkill
	rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws" ; rigLive="$rigWs/source" ; rigData="$rigTmp/data" ; rigSkills="$rigTmp/skills"
	rigQueue="$rigHome/.agents/magic-team/retest-queue"
	rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
	rigScript=DistroAgentsTools ; rigAs=""
	mkdir -p "$rigHome" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigLive/myx/myx.distro-agents" "$rigLive/myx/myx.common/os-myx.common/host/tarball/share" "$rigData/inboxes" "$rigSkills/magic-team"
	for rigSkill in magic-tester rig-member rig-other ; do
		mkdir -p "$rigSkills/$rigSkill" "$rigData/inboxes/$rigSkill/incoming"
		printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigSkill/$rigSkill.basic.md" ; printf '# rig armed\n' > "$rigSkills/$rigSkill/$rigSkill.armed.md"
		printf '# %s\n' "$rigSkill" > "$rigSkills/$rigSkill/SKILL.md"
	done
	: > "$rigTmp/log"
	rigTake myx/myx.distro-agents/sh-lib myx/myx.distro-agents/sh-lib || rigRefuse "the tooling's sh-lib could not be copied into the rig"
	rigTake myx/myx.distro-agents/sh-scripts myx/myx.distro-agents/sh-scripts || rigRefuse "the tooling's sh-scripts could not be copied into the rig"
	printf '# a repository of a sh-test rig\nName: myx\n' > "$rigLive/myx/repository.inf"
	rigDirective sh-test
	for rigSkill in myx.distro-.local myx.distro-source myx.distro-system ; do rigTake "myx/$rigSkill" "myx/$rigSkill" || rigRefuse "the tooling's $rigSkill could not be copied into the rig" ; done
	rigTake myx/myx.common/os-myx.common/host/tarball/share/myx.common myx/myx.common/os-myx.common/host/tarball/share/myx.common || rigRefuse "myx.common could not be copied into the rig"
	rigTests live RigOne RigTwo RigThree
	rigTests rig-scratch-a RigOne RigTwo
}
rigDirective(){ ## sh-test path or `off`, [host glob, default *] -- the rig's package as the package is, with a testing directive naming that sh-test folder of it (the folders eligible for the testing system), or none
	local directiveFile="$rigLive/myx/myx.distro-agents/project.inf" directiveTemp
	directiveTemp="$( mktemp "$directiveFile.XXXXXX" )" || return 1
	LC_ALL=C awk -v line="$( [ "$1" = off ] || printf '\tmagic-team:testing:myx.distro-agents:%s:%s \\' "$1" "${2:-*}" )" '{ print } /^Declares: \\$/ && line != "" { print line }' "$rigPackage/project.inf" > "$directiveTemp" && mv -f "$directiveTemp" "$directiveFile"
}
rigTake(){ ## folder below the origin, folder below the rig's tree -- that folder copied whole, links followed, .git left out
	mkdir -p "$rigLive/$2" && tar -C "$MDLT_ORIGIN/$1" --exclude .git -chf - . 2> /dev/null | tar -C "$rigLive/$2" -xf - 2> /dev/null
}
rigRoot(){ ## copy -- its source root: `live` is the workspace's own tree, any other name a scratch folder of that name
	if [ "$1" = live ] ; then printf '%s\n' "$rigLive" ; else printf '%s\n' "$rigWs/.local/temp/$1/source" ; fi
}
rigTests(){ ## copy, test... -- that copy's tests: the runner under test and the tiny tests named. Each says in the shared log when it begins and ends and which copy it ran in; it ends only once the rig lets it where the rig holds it (hold.<test>), and fails where the rig says so (fail.<test>)
	local testsDir testsName ; testsDir="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test" ; shift
	rm -rf "$testsDir" ; mkdir -p "$testsDir"
	cp "$rigPackage/sh-test/AgentsRunTests.sh" "$testsDir/AgentsRunTests.sh"
	for testsName in "$@" ; do
		cat > "$testsDir/$testsName.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyName="${0##*/}" ; rigTinyName="${rigTinyName%.test.sh}"
case "$MDLT_ORIGIN" in */.local/temp/*) rigTinyCopy="${MDLT_ORIGIN##*/.local/temp/}" ; rigTinyCopy="${rigTinyCopy%%/*}" ;; *) rigTinyCopy=live ;; esac
printf 'BEGIN %s %s\n' "$rigTinyCopy" "$rigTinyName" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -e "$RIG_SHARED/hold.$rigTinyName" ] && [ ! -e "$RIG_SHARED/let.$rigTinyName" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s %s\n' "$rigTinyCopy" "$rigTinyName" >> "$RIG_SHARED/log"
[ ! -e "$RIG_SHARED/fail.$rigTinyName" ] || { echo "RIG_TINY: FAILED" ; exit 1 ; }
echo "RIG_TINY: OK"
RIGTINY
	done
}
rigCall(){ ## result prefix, words... -- one call of the script in rigScript from the workspace, in the background; <prefix>.out .err, its pid in rigLast
	local callOut="$1" callTool ; shift
	callTool="$rigLive/myx/myx.distro-agents/sh-scripts/$rigScript.fn.sh"
	case "$rigWs" in "$rigTmp"/*) ;; *) rigRefuse "the workspace is outside this rig's own tree: $rigWs" ;; esac
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigLive" MDLT_OPTION="--run-from-path $rigLive" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_TMP="$rigTmp" RIG_SHARED="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$callTool" "$@" ) > "$callOut.out" 2> "$callOut.err" < /dev/null &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigEnd(){ ## pid -- waits for that call, its rc in rigRc
	rigRc=0 ; wait "$1" 2> /dev/null || rigRc=$?
}
rigOp(){ ## result prefix, words... -- one call from start to end, its rc in rigRc
	rigCall "$@" ; rigEnd "$rigLast"
}
rigUntil(){ ## fixed text, file -- waits for a line of the file to hold the text, however long a busy host takes, up to four minutes; rc 1 when it never does
	local untilLeft=1200
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigBegins(){ ## test, copy (default: any) -- how many times that test has really begun, by the shared log
	LC_ALL=C grep -c -E "^BEGIN ${2:-[a-z-]+} $1\$" "$rigTmp/log" || :
}
rigBegun(){ ## -- every test that has begun, with its copy, in the order they began, on one line
	LC_ALL=C sed -n 's/^BEGIN //p' "$rigTmp/log" | LC_ALL=C tr ' ' ':' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigHolds(){ ## folder of the queue -- how many requests or results stand in it
	ls "$rigQueue/$1" 2> /dev/null | LC_ALL=C grep -c -e '\.request$' -e '\.result$' || :
}
rigLine(){ ## result prefix, request id -- the line a drain printed for that request, its id put as <id>
	LC_ALL=C grep -F -- "RETEST $2 " "$1.out" | LC_ALL=C sed "s/$2/<id>/" | LC_ALL=C tr '\n' '|' | LC_ALL=C sed 's/|$//'
}
rigStands(){ ## request id -- where the result operation says that request stands: the word after its id
	local standsScript="$rigScript" ; rigScript=DistroAgentsTools
	rigOp "$rigTmp/stands" --retest-result "$1"
	rigScript="$standsScript"
	LC_ALL=C sed -n "1s/^RETEST $1 \([A-Z]*\) .*/\1/p" "$rigTmp/stands.out"
}
rigWaitingFile(){ ## -- the one request that waits in the queue (its path), or nothing
	ls "$rigQueue/waiting"/*.request 2> /dev/null | LC_ALL=C sed -n 1p
}
rigField(){ ## request file, field -- the value of the field in that request
	LC_ALL=C sed -n "s/^$2: //p" "$1" | LC_ALL=C sed -n 1p
}
rigInbox(){ ## member -- the inquiries in that member's inbox, one name a line
	ls "$rigData/inboxes/$1/incoming" 2> /dev/null | LC_ALL=C grep '^inquiry-' || :
}
rigFresh(){ ## -- an empty queue, no pass on record, no testbed, an empty log, no run folders, nothing held or failing, empty inboxes
	rm -rf "$rigHome/.agents" "$rigWs/.local/agents" "$rigWs/.local/temp/mdat-tests" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/hold.* "$rigTmp"/let.* "$rigTmp"/fail.* ; rigAs=""
	rm -f "$rigData"/inboxes/*/incoming/inquiry-*
}
