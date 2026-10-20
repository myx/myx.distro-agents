#!/bin/sh
## Stand-in for uname, for AgentsEmbeddedPythonInstallCheck: the system and the machine the rig says it is
## (RIG_UNAME_S, RIG_UNAME_M). Any other call is the real one.
case "$1" in
	-s) printf '%s\n' "${RIG_UNAME_S:?RIG_UNAME_S is not set}" ;;
	-m) printf '%s\n' "${RIG_UNAME_M:?RIG_UNAME_M is not set}" ;;
	*) exec /usr/bin/uname "$@" ;;
esac
