#!/bin/sh
## Stand-in for ps, for AgentsSuperviseCloseOrphansCheck: the began reader's read (`-o pid=,stat=,lstart=`) shows the process
## RIG_SURVIVOR as running since RIG_SURVIVOR_BEGAN (the began moment as one word), whatever the host says, so a process that
## KILL ended reads as one that survived it. Any other call is the real one.
case "$*" in
	*pid=,stat=,lstart=*)
		/bin/ps "$@" | LC_ALL=C awk -v survivor="${RIG_SURVIVOR:?RIG_SURVIVOR is not set}" '$1 != survivor { print ; }'
		printf '%s S %s\n' "$RIG_SURVIVOR" "$( printf '%s' "${RIG_SURVIVOR_BEGAN:?RIG_SURVIVOR_BEGAN is not set}" | LC_ALL=C tr '_' ' ' )"
	;;
	*) exec /bin/ps "$@" ;;
esac
