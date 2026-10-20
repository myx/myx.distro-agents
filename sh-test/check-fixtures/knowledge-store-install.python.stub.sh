#!/bin/sh
## Stand-in for the embedded Python, for AgentsKnowledgeStoreInstallCheck: the one Python the rig's uv hands out. It does
## what the installer of the knowledge store asks of Python and pip, and nothing else, and logs each call and the
## variables that name where it may write (RIG_PY_LOG):
##   pip download ... -d <folder> ...   puts the fixture wheels (RIG_WHEELS) in the folder; with RIG_NO_BINARY set it says,
##                                      as pip does, that no matching distribution exists, and fails
##   venv <folder>                      makes <folder>/bin/python, a Python of that environment (this same stand-in)
##   pip install --no-index --find-links <folder> ...   in an environment alone: needs wheels in the folder, and marks it
##   -c "import lancedb ..."            in an environment: says the version where the marker stands (and RIG_NO_IMPORT is
##                                      not set), else fails as a missing module does
## Any other call is refused. Every line it says on standard error starts PYSTUB, so that a check reads, in the order of
## the one error stream, what the installer said before it asked for this.
log="${RIG_PY_LOG:-/dev/null}"
venv="${RIG_VENV:-}"
{ printf 'CALL %s\n' "$*" ; env | LC_ALL=C grep -E '^(PIP_|TMP|HOME=)' | LC_ALL=C sort | LC_ALL=C sed -e 's/^/ENV /' ; } >> "$log"
case "$*" in
	"--version"|"-I --version")
		echo "Python 3.12.0"
	;;
	*"-m pip download"*)
		if [ -n "${RIG_NO_BINARY:-}" ] ; then
			echo "ERROR: Could not find a version that satisfies the requirement lancedb==0.40.0 (from versions: none)" >&2
			echo "ERROR: No matching distribution found for lancedb==0.40.0" >&2
			exit 1
		fi
		dest="" ; prev=""
		for word in "$@" ; do
			[ "$prev" != "-d" ] || dest="$word"
			prev="$word"
		done
		[ -n "$dest" ] || { echo "stub python: pip download with no -d" >&2 ; exit 64 ; }
		case "$*" in *"--only-binary=:all:"*) ;; *) echo "stub python: pip download without --only-binary=:all:" >&2 ; exit 64 ;; esac
		mkdir -p "$dest" && cp "${RIG_WHEELS:?RIG_WHEELS is not set}"/*.whl "$dest/"
		echo "PYSTUB pip download" >&2
	;;
	*"-m venv"*)
		for word in "$@" ; do dir="$word" ; done
		echo "PYSTUB venv $dir" >&2
		mkdir -p "$dir/bin" || exit 1
		printf '#!/bin/sh\nRIG_VENV="%s" exec "%s" "$@"\n' "$dir" "$0" > "$dir/bin/python"
		chmod +x "$dir/bin/python"
	;;
	*"-m pip install"*)
		[ -n "$venv" ] || { echo "stub python: pip install outside an environment" >&2 ; exit 64 ; }
		case "$*" in *"--no-index"*) ;; *) echo "stub python: pip install without --no-index" >&2 ; exit 64 ;; esac
		links="" ; prev=""
		for word in "$@" ; do
			[ "$prev" != "--find-links" ] || links="$word"
			prev="$word"
		done
		ls "$links"/*.whl > /dev/null 2>&1 || { echo "stub python: no wheel in the folder to install from: $links" >&2 ; exit 1 ; }
		echo "PYSTUB pip install" >&2
		printf '%s\n' "$links" > "$venv/installed"
	;;
	*"import lancedb"*)
		if [ -z "${RIG_NO_IMPORT:-}" ] && [ -n "$venv" ] && [ -f "$venv/installed" ] ; then
			echo "0.40.0"
		else
			echo "ModuleNotFoundError: No module named 'lancedb'" >&2
			exit 1
		fi
	;;
	*)
		echo "stub python: refused, not a call the installer makes: $*" >&2
		exit 64
	;;
esac
