#!/usr/bin/env bash

##
## DistroAgentsContacts.fn.sh -- Contacts (F7.10): the people subsystem. A subsystem interface: results are read from it, by agent tools,
## the shell console and shell automation alike. Every member uses it, the coordinator and the client-* members most: they collect a
## contact, check one, escalate about one and record what that contact may ask for. The store is the team data root's `contacts/`, one record
## a person and one an organisation (sh-lib/common/AgentsTools.Contacts.include); the records are written by this file and kept by no one by hand.
##   --collect-contact, --collect-organisation   record or fill a contact, or an organisation
##   --find-contact, --all-contacts, --all-organisations, --contact-record   read them
##   --contacted-by, --reach-contact   the two scenarios: being contacted by a contact, and reaching one
##   --contact-access, --escalate-contact, --allow-contact   what a contact may ask for, asked of the permission model
## A contact's access is not stored here: it is read from the permission model, the grants given to `contact:<id>`.
##
## From DistroAgentsTools.fn.sh (F1.4, first stage): --send-contact-digest. They go on under their old names (sh-lib/harness/AgentsContext.FrontForward.include).
##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( ( cd "$( dirname "$0" )/../../../.." && pwd ) )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

## Every child finds the bash this runs in, as DistroAgentsTools.fn.sh does.
case "$BASH" in
	/*/bash)
		command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; }
		export MDAT_BASH="$BASH"
	;;
esac

DistroAgentsContacts(){
	local MDSC_CMD='DistroAgentsContacts'
	## F1.4, first stage: an operation that came here under a new name goes on under its old one (sh-lib/harness/AgentsContext.FrontForward.include).
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontForward.include"
	if AgentsToolsFrontKnows DistroAgentsContacts "$@" ; then
		AgentsToolsFrontForward DistroAgentsContacts "$@"
		return $?
	fi
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsContacts DistroAgentsContacts.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	## The data root, the skillset root and the bare-name gate, as every operation of the tooling settles them.
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"
	type AgentsToolsContactsCollectContact > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.Contacts.include"
	case "$1" in

		## --id <slug> [--name <text>] [--organisation <slug>] [--role <text>] [--relationship <text>] [--how-to-meet <text>] [--owner yes|no]
		## [--slack <team>:<id>]... [--slack-handle <team>:@<handle>]... [--slack-conversation <team>:<id>]... [--email <address>]...
		## [--drop <coordinate>]... [--note <text>] [--correct]: a contact recorded, or filled where it is recorded already; the calling member
		## is added to who holds it.
		--collect-contact)
			AgentsToolsContactsCollectContact "$@"
			return $?
		;;

		## --id <slug> [--name <text>] [--domain <text>] [--note <text>] [--correct]: an organisation recorded or filled.
		--collect-organisation)
			AgentsToolsContactsCollectOrganisation "$@"
			return $?
		;;

		## <value> [--team <scope>] [--reached-by <member>]: the contacts a value names; rows, rc 1 with none.
		--find-contact)
			AgentsToolsContactsFind "$@"
			return $?
		;;

		## [--organisation <slug>] [--reached-by <member>]: every contact, a row each.
		--all-contacts)
			AgentsToolsContactsAll "$@"
			return $?
		;;

		## Every organisation, a row each.
		--all-organisations)
			AgentsToolsContactsAllOrganisations "$@"
			return $?
		;;

		## <id>: the record, whole.
		--contact-record)
			AgentsToolsContactsRecord "$@"
			return $?
		;;

		## <value> [--team <scope>]: being contacted. The sender looked up: its record, what it holds, the tier and the next step.
		--contacted-by)
			AgentsToolsContactsContactedBy "$@"
			return $?
		;;

		## <id>: reaching one. Its coordinates by channel, how to meet it, the send lines.
		--reach-contact)
			AgentsToolsContactsReach "$@"
			return $?
		;;

		## <id> [--tool <tool> --target <target>] [--session-id <id>]: the permission model's answer for a call, or what the contact holds standing.
		--contact-access)
			AgentsToolsContactsAccess "$@"
			return $?
		;;

		## <id> --tool <tool> --target <target> --asked <text> [--session-id <id>]: what the contact asks for and holds no access to: the refusal recorded for
		## the contact, and the call that asks the human-owner (RequestPermission) printed.
		--escalate-contact)
			AgentsToolsContactsEscalate "$@"
			return $?
		;;

		## <id> --session-id <id> --refusal-id <id> --kind session|contact: a member gives the contact what the member holds (a stub over grant-open, signed by the member).
		--allow-contact)
			AgentsToolsContactsAllow "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: ${1:-}" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsContacts.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		## Copied from DistroAgentsTools.fn.sh: the tools this one calls find myx.common by it.
		if   [ -d "${MYXROOT:-}" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT
		elif   [ -f "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
		elif [ -f "/usr/local/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="/usr/local/share/myx.common"
		elif command -v myx.common 2>/dev/null && myx.common which lib/catMarkdown 2>/dev/null ; then
			export MYXROOT="$( myx.common which lib/catMarkdown )"
			export MYXROOT="${MYXROOT%/bin/lib/catMarkdown*}"
		else
			export MYXROOT=''
		fi

		DistroAgentsContacts "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsContacts.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsContacts.fn.sh." >&2
			exit 1
		fi
	;;
esac
