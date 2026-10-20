#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test builds a myx.distro workspace of its own: a rig where `ListDistroProjects`, the
## project.inf declares and `--make-workspace-integrations` run as they do in a set-up workspace, over projects the
## check writes. Sourced by the check:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-distro-workspace.include.sh"
##
## WHAT IT HOLDS, and nothing more. The rig copies nothing of the tooling: it reads the tooling of the origin the check
## runs from. What ListDistroProjects needs of the workspace itself is made here:
##   <ws>/source/<repo>/repository.inf           the repository of the check's own projects
##   <ws>/source/<repo>/<project>/project.inf    each project the check writes (rigDistroProject)
##   <ws>/.local/myx/<package>                   a link to each package of the origin's myx/ folder, the place a set-up
##                                               workspace holds its tooling (LocalContext.include is looked for there)
## and the myx.common command on PATH, which the source scan calls (rigDistroPath). The rig lives under
## `$MMDAPP/.local/temp/sh-test/`, and its HOME is its own, so nothing of the integrations reaches this machine's.
##
##   rigDistroTmp <check name>                      makes the rig's root, `$MMDAPP/.local/temp/sh-test/<name>.XXXXXX`,
##                                                  and prints it, physical
##   rigDistroWorkspace <ws> <repo>                 makes the workspace: its repository and its tooling links
##   rigDistroProject <ws> <repo> <project> <body>  writes a project's project.inf: `Name: <project>`, then the body
##   rigDistroPath                                  prints a PATH for the rig: myx.common's folder, then the system's
##   rigDistroRun <ws> <home> <words...>            runs DistroAgentsTools.fn.sh in the workspace, as its console,
##                                                  output on the caller's streams, under a five-minute bound

rigDistroTmp(){ ## check name
	mkdir -p "$MMDAPP/.local/temp/sh-test" || return 1
	local distroTmp
	distroTmp="$( mktemp -d "$MMDAPP/.local/temp/sh-test/$1.XXXXXX" )" || return 1
	( cd "$distroTmp" && pwd -P )
}
rigDistroWorkspace(){ ## workspace, repository
	local distroPackage
	mkdir -p "$1/source/$2" "$1/.local/myx" "$1/.local/.agents" "$1/.local/agents" || return 1
	printf '# a repository of a sh-test rig\nName: %s\n' "$2" > "$1/source/$2/repository.inf"
	for distroPackage in "$MDLT_ORIGIN"/myx/* ; do
		[ -d "$distroPackage" ] || continue
		case "${distroPackage##*/}" in
			myx.*|mdci-packages-*) ln -s "$( cd "$distroPackage" && pwd -P )" "$1/.local/myx/${distroPackage##*/}" || return 1 ;;
		esac
	done
}
rigDistroProject(){ ## workspace, repository, project, project.inf body after its Name line
	mkdir -p "$1/source/$2/$3" || return 1
	printf 'Name: %s\n%s' "$3" "$4" > "$1/source/$2/$3/project.inf"
}
rigDistroPath(){
	local distroCommon
	distroCommon="$( command -v myx.common 2> /dev/null )" || return 1
	printf '%s:/usr/bin:/bin:/usr/sbin:/sbin' "${distroCommon%/*}"
}
rigDistroRun(){ ## workspace, home, words...
	local distroWs="$1" distroHome="$2" distroPathText
	shift 2
	distroPathText="$( rigDistroPath )" || { echo "rig-distro-workspace: no myx.common on PATH, which the source scan needs" >&2 ; return 97 ; }
	( cd "$distroWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$distroHome" PATH="$distroPathText" MMDAPP="$distroWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		perl -e 'alarm 300 ; exec @ARGV' bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) < /dev/null
}
