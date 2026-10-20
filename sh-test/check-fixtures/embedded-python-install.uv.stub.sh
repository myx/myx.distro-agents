#!/bin/sh
## Stand-in for uv, packed by AgentsEmbeddedPythonInstallCheck into a fixture release archive (its version replaces the
## marker below). It does what the operation asks of the real uv and nothing else, and where the real uv would write it
## writes to the same place the real one is told, else to a default in HOME, so that a folder the operation forgot to
## name shows in the home of the rig:
##   --version                 says the version
##   python install <minor>    logs its call and its environment, takes the archive from UV_PYTHON_CACHE_DIR where one
##                             stands there (a download that needed no network), else "downloads" it (logs NETWORK and
##                             keeps it there), and installs a stub python in UV_PYTHON_INSTALL_DIR with a link in
##                             UV_PYTHON_BIN_DIR
##   python find <minor>       prints that python, or says none (rc 2)
## The log is RIG_UV_LOG (none if unset). Any other call is refused.
log="${RIG_UV_LOG:-/dev/null}"
case "$1 ${2:-}" in
	"--version "*)
		printf 'uv @UV_VERSION@ (rig stub)\n'
	;;
	"python install")
		minor="${3:?no minor given}"
		{ printf 'CALL python install %s\n' "$minor" ; env | LC_ALL=C grep -E '^(UV_|TMP|HOME=)' | LC_ALL=C sort ; } >> "$log"
		inst="${UV_PYTHON_INSTALL_DIR:-$HOME/.local/share/uv/python}"
		cache="${UV_PYTHON_CACHE_DIR:-$HOME/.cache/uv/python-archives}"
		bin="${UV_PYTHON_BIN_DIR:-$HOME/.local/bin}"
		uvcache="${UV_CACHE_DIR:-$HOME/.cache/uv}"
		archive="$cache/cpython-$minor.0-stub.tar.gz"
		if [ -f "$archive" ] ; then
			printf 'FROM-CACHE %s\n' "$archive" >> "$log"
		else
			printf 'NETWORK python-archive\n' >> "$log"
			mkdir -p "$cache" && printf 'stub python archive\n' > "$archive"
		fi
		mkdir -p "$inst/cpython-$minor.0-stub/bin" "$bin" "$uvcache" || exit 1
		printf '#!/bin/sh\necho "Python %s.0"\n' "$minor" > "$inst/cpython-$minor.0-stub/bin/python$minor"
		chmod +x "$inst/cpython-$minor.0-stub/bin/python$minor"
		ln -sf "$inst/cpython-$minor.0-stub/bin/python$minor" "$bin/python$minor"
		printf 'cache\n' > "$uvcache/CACHEDIR.TAG"
	;;
	"python find")
		minor="${3:?no minor given}"
		found="${UV_PYTHON_INSTALL_DIR:-$HOME/.local/share/uv/python}/cpython-$minor.0-stub/bin/python$minor"
		[ -x "$found" ] || { echo "stub uv: no managed python $minor" >&2 ; exit 2 ; }
		printf '%s\n' "$found"
	;;
	*)
		echo "stub uv: refused, not a call the operation makes: $*" >&2
		exit 64
	;;
esac
