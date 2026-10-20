#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The rig's contacts (F7.10): a record of the contacts store written straight, as the files of a rig tree, so that a check which needs a
## recipient to be known to the outbound contact gate (AgentsToolsContactAssertKnown) has one without going through the tool that keeps the
## store. Sourced by the check:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh"
##   rigContactSeed <data-root> <member> <id> (<slack-id>|-) (<e-mail>|-)
## writes <data-root>/contacts/persons/<id>-<member>.md: a person the member holds, with a Slack coordinate of the member's own team (the identity
## scope of a member is its name) and an e-mail address, either left out with `-`. The record has the front matter the tool writes.
##

rigContactSeed(){ ## data root, member, id, slack id or -, e-mail or -
	local seedFile="$1/contacts/persons/$3-$2.md"
	mkdir -p "$1/contacts/persons" || return 1
	{
		printf -- '---\ntype: contact\ncontact-id: %s-%s\ndisplay-name: rig %s\nreached-by: %s\n' "$3" "$2" "$3" "$2"
		[ "$4" = "-" ] || printf 'slack-id: %s:%s\n' "$2" "$4"
		[ "$5" = "-" ] || printf 'email: %s\n' "$5"
		printf -- '---\n# Contact: rig %s\n\n## Log\n\n' "$3"
	} > "$seedFile"
}
