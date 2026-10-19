#!/usr/bin/env bash
## Guard over the include paths (F1.1 of the refactorings epic): there is no resolver and no map. An include stays a
## plain `$MDLT_ORIGIN/myx/<package>/sh-lib/<file>`, and a move of F1.3 rewrites the paths that name the moved file,
## by one mechanical replace in the same batch; this guard does the checking, the replace only replaces. It holds two
## things: every include is spelled in that one form, so a global replace finds them all -- an include of a shell file
## of the packages in any other form (a relative path, a path built from a variable, another root) is listed by its
## site -- and every `$MDLT_ORIGIN/myx/...` path the packages spell names a file that exists, so a path left behind by
## a move fails here.
## Read rather than run: every file of the myx.distro-* packages under the origin, their .git folders left out. A path
## counts when it is spelled whole: one that goes on into a variable, a glob, a brace or a parenthesis, also past a
## closing quote (`.../help/Help.$name`, `.../clone${kind}.Common`, `".../Help.Tools-setup-"*.help.md`), or that ends
## in a dash, is a pattern, not a path, and is not asked about. This check's own file, whose probe names no file on
## purpose, is not read.
## Offline: it reads the packages and writes nothing.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib" ] || rigRefuse "no myx.distro-agents at the origin this workspace resolves: $MDLT_ORIGIN"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsOriginPathsExistCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Every whole path spelled after $MDLT_ORIGIN, as `<file below the origin's packages>|<path>`, one a line.
( cd "$MDLT_ORIGIN/myx" && find -L myx.distro-* -name .git -prune -o -type f -print 2> /dev/null ) | LC_ALL=C sort > "$rigTmp/files"
[ "$( LC_ALL=C grep -c . "$rigTmp/files" )" -ge 100 ] 2> /dev/null || rigRefuse "too few files of the packages were found to be read right"
rigReader='while ( m{\$\{?MDLT_ORIGIN\}?/(myx/[A-Za-z0-9._/-]+)(?![A-Za-z0-9._/\$\{\*\?\[\(-])(?!["\x27][\*\$\{])}g ) { my $path = $1 ; $path =~ s{[.]+$}{} ; next if $path =~ m{[-/]$} ; print "$ARGV|$path\n" }'
while IFS= read -r rigFile ; do
	[ "${rigFile##*/}" != "${0##*/}" ] || continue
	perl -ne "$rigReader" -- "$MDLT_ORIGIN/myx/$rigFile" 2> /dev/null
done < "$rigTmp/files" | LC_ALL=C sort -u > "$rigTmp/paths"
rigCount="$( LC_ALL=C grep -c . "$rigTmp/paths" )"
rigAssert "control: the packages spell such paths, and the reader finds them" "$( [ "$rigCount" -ge 100 ] && printf found || printf "only $rigCount" )" found
rigMissing=""
while IFS='|' read -r rigWhere rigPath ; do
	[ -e "$MDLT_ORIGIN/$rigPath" ] || rigMissing="$rigMissing ${rigWhere#"$MDLT_ORIGIN/myx/"}:$rigPath"
done < "$rigTmp/paths"
rigAssert "every \$MDLT_ORIGIN/myx/... path the packages spell names a file that exists" "[${rigMissing# }]" "[]"
## The reader is not blind: a path to no file, as a package would spell it, is found missing.
printf '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsRigNoSuchFile.include"\n' > "$rigTmp/probe.sh"
rigProbe="$( perl -ne "$rigReader" -- "$rigTmp/probe.sh" | LC_ALL=C sed 's/^[^|]*|//' )"
rigAssert "control: the reader takes a spelled path whole, and it names no file" "$rigProbe:$( [ -e "$MDLT_ORIGIN/$rigProbe" ] && printf exists || printf missing )" "myx/myx.distro-agents/sh-lib/AgentsRigNoSuchFile.include:missing"
printf 'for f in "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.Rig-setup-"*.help.md ; do : ; done\n' > "$rigTmp/pattern.sh"
rigAssert "control: a path that goes on past its quote into a glob is a pattern, not asked about" "[$( perl -ne "$rigReader" -- "$rigTmp/pattern.sh" )]" "[]"

## THE ONE FORM of an include of a file of a myx.distro-* package's sh-lib: a statement `. <target>` or `source
## <target>` in a shell file of a package (its sh-lib, sh-scripts and builders: *.sh, *.include, *.rc), outside a
## comment, whose target spells `myx/<package>/sh-lib/<file>` literally after `$MDLT_ORIGIN` or a `${MDLT_ORIGIN:-...}`
## or `${MDLT_ORIGIN:=...}` default, quoted or not. A target that names such a file in another form -- a path built from a variable, one
## relative to the script -- is a site, listed as `<file>:<line>: <target>`. An include of any other file (myx.common,
## $HOME, $MMDAPP, $BUILDER) is out of the rule's scope.
( cd "$MDLT_ORIGIN/myx" && find -L myx.distro-*/sh-lib -name .git -prune -o -type f -print 2> /dev/null ) | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort -u > "$rigTmp/shlib-names"
export RIG_SHLIB_NAMES="$rigTmp/shlib-names"
rigFormReader='BEGIN { open( my $names, "<", $ENV{RIG_SHLIB_NAMES} ) or die ; while ( <$names> ) { chomp ; $shlib{$_} = 1 } } next if /^\s*#/ ; while ( m@(?:^|[;&|({]|\bthen|\bdo|\belse)\s*(?:\.|source)\s+("[^"]*"|\x27[^\x27]*\x27|[^\s;&|)]+)@g ) { my $target = $1 ; my $bare = $target ; $bare =~ s{^["\x27]|["\x27]$}{}g ; next if $bare =~ m@^(?:\$MDLT_ORIGIN|\$\{MDLT_ORIGIN(?::[-=][^}]*)?\})/myx/[A-Za-z0-9._-]+/sh-lib/[A-Za-z0-9._/-]+$@ ; my $name = $bare ; $name =~ s{.*/}{} ; next unless $name =~ m{^[A-Za-z0-9._-]+$} && $shlib{$name} ; print "$ARGV:$.: $target\n" } close ARGV if eof'
( cd "$MDLT_ORIGIN/myx" && find -L myx.distro-*/sh-lib myx.distro-*/sh-scripts myx.distro-*/builders -name .git -prune -o -type f \( -name '*.sh' -o -name '*.include' -o -name '*.rc' \) -print 2> /dev/null ) | LC_ALL=C sort > "$rigTmp/shells"
( cd "$MDLT_ORIGIN/myx" && while IFS= read -r rigShell ; do perl -ne "$rigFormReader" -- "$rigShell" 2> /dev/null ; done < "$rigTmp/shells" ) > "$rigTmp/forms"
rigAssert "control: the shell files of the packages are read"  "$( LC_ALL=C grep -c . "$rigTmp/shells" | LC_ALL=C awk '{ print ( $1 >= 100 ) ? "read" : "only " $1 }' )" read
rigAssert "every include of a package's sh-lib file spells myx/<package>/sh-lib/<file> after \$MDLT_ORIGIN: the sites in another form ($( LC_ALL=C grep -c . "$rigTmp/forms" ))" "[$( LC_ALL=C tr '\n' '|' < "$rigTmp/forms" | LC_ALL=C sed 's/|$//' )]" "[]"
printf '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"\n. "$rigLib/AgentsTools.Member.include"\n## . "$rigLib/AgentsTools.Member.include"\n. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"\n. "$MYXROOT/bin/lib/parallel.Common"\n. "$( dirname $0 )/../sh-lib/member/AgentsTools.Member.include"\n' > "$rigTmp/forms-probe.sh"
rigAssert "control: the reader passes the one form and its default, lists a variable-built and a script-relative include, and no comment and no other file" "$( perl -ne "$rigFormReader" -- "$rigTmp/forms-probe.sh" | LC_ALL=C sed 's/^[^:]*://' | LC_ALL=C tr '\n' '|' )" '2: "$rigLib/AgentsTools.Member.include"|6: "$( dirname $0 )/../sh-lib/member/AgentsTools.Member.include"|'

## The one broken path of before: LocalContext.include sources LocalConsole.CompletionFunction.include when bash asks
## `Local` for its completions, and F1.1 adds that file, modelled on the agents console's own. So tab completion of
## `Local` works: the completion is asked as bash asks it, in a rig workspace, and answers with no missing file.
mkdir -p "$rigTmp/ws/.local"
( cd "$rigTmp/ws" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalContext.include" || exit 97
	COMP_WORDS=( Local "" ) ; COMP_CWORD=1 ; COMP_LINE="Local " ; COMPREPLY=()
	Local ; completeRc=$?
	printf "rc=%s replies=%s\n" "$completeRc" "${#COMPREPLY[@]}"
' ) > "$rigTmp/complete.out" 2> "$rigTmp/complete.err" < /dev/null
rigAssert "tab completion of Local: no missing-file error"   "$( LC_ALL=C grep -c -i -e 'No such file' -e 'not found' "$rigTmp/complete.err" )" 0
rigAssert "and it answers with completions, exit 0"          "$( LC_ALL=C sed -n 's/^rc=\([0-9]*\) replies=\([0-9]*\)$/\1 \2/p' "$rigTmp/complete.out" | LC_ALL=C awk '{ print ( $1 == 0 && $2 >= 1 ) ? "completes" : "rc " $1 ", " $2 " replies" }' )" completes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ORIGIN PATHS EXIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ORIGIN_PATHS_EXIST: OK (%d assertions, %d paths, offline)\n' "$rigPassCount" "$rigCount"
