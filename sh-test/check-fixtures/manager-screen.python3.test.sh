#!/usr/bin/env bash
## The `python3` that cannot load `curses`, for the tests of the manager screen: put first on PATH, it is the
## real interpreter ($RIG_REAL_PYTHON3) for everything, except that `import curses` fails in what it runs, as
## it does on a Python built without that module. It takes the options a caller gives ahead of the script.
set -u
: "${RIG_REAL_PYTHON3:?⛔ ERROR: RIG_REAL_PYTHON3 is not set}"
rigOptions=()
while [ $# -gt 0 ] ; do
	case "$1" in
		-c) exec "$RIG_REAL_PYTHON3" ${rigOptions[@]+"${rigOptions[@]}"} "$@" ;;
		-*) rigOptions+=( "$1" ) ; shift ;;
		*) break ;;
	esac
done
[ $# -gt 0 ] || exec "$RIG_REAL_PYTHON3" ${rigOptions[@]+"${rigOptions[@]}"}
exec "$RIG_REAL_PYTHON3" ${rigOptions[@]+"${rigOptions[@]}"} -c 'import runpy, sys
sys.modules["curses"] = None
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")' "$@"
