#!/usr/bin/env bash
## The fake `python3` for AgentsClientSystemsCheck: the other half of its offline guarantee, beside the fake `curl`.
## The three scripts of the package that open a connection of their own are answered here and never run. Each appends
## one line to $RIG_SCENARIO/calls that names whose settings it was given, never a secret:
##   google <operation> <client id>      imap-read <host> <user> <uid>      imap-sweep <host> <user>
## and gives the least its caller takes as an answer. Every other script is the real interpreter's
## ($RIG_REAL_PYTHON3), unchanged.
set -u
for rigArg in "$@" ; do
	case "$rigArg" in
		*/AgentsGoogleApiCall.py)
			cat > /dev/null
			printf 'google %s %s\n' "${AGENTS_GOOGLE_OP:-none}" "${AGENTS_GOOGLE_CLIENT_ID:-none}" >> "$RIG_SCENARIO/calls"
			printf 'RIG_GOOGLE_ANSWER=%s\n' "${AGENTS_GOOGLE_OP:-none}"
			exit 0
		;;
		*/AgentsImapFetchMessage.py)
			printf 'imap-read %s %s %s\n' "${AGENTS_IMAP_HOST:-none}" "${AGENTS_IMAP_USER:-none}" "${AGENTS_IMAP_UID:-none}" >> "$RIG_SCENARIO/calls"
			printf 'RIG MESSAGE\n'
			exit 0
		;;
		*/AgentsImapSweepFetch.py)
			printf 'imap-sweep %s %s\n' "${AGENTS_IMAP_HOST:-none}" "${AGENTS_IMAP_USER:-none}" >> "$RIG_SCENARIO/calls"
			exit 0
		;;
	esac
done
exec "$RIG_REAL_PYTHON3" "$@"
