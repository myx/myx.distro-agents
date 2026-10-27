#!/usr/bin/env bash
## Behavioural check on the one enumeration of credentials (F11.8, sh-lib/manager/AgentsTools.ManagerConfig.include, AgentsToolsManagerConfigKeySecret,
## from the catalogue of the owner setup): the account passwords of Google and of Atlassian are credentials, as EMAIL_APP_PASSWORD is (F11.7, the small
## parts taken in), and print in the one form of a credential. A key that is none of them (its id, its user) is not one.
## Offline: the two includes are read in a shell of their own; nothing is run or requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/config/AgentsTools.OwnerSetupOptionSpec.include" ] && [ -f "$rigHere/manager/AgentsTools.ManagerConfig.include" ] || rigRefuse "the includes are not at the origin this workspace resolves: $MDLT_ORIGIN"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigIsCredential(){ ## key -- whether the enumeration names it
	(
		set +eu
		. "$rigHere/config/AgentsTools.OwnerSetupOptionSpec.include"
		. "$rigHere/manager/AgentsTools.ManagerConfig.include" --definitions-only > /dev/null 2>&1
		AgentsToolsManagerConfigKeySecret "$1" > /dev/null 2>&1 && printf yes || printf no
	)
}
rigShown(){ ## value -- the one form of a credential
	( . "$rigHere/config/AgentsTools.CredentialDisplay.include" && AgentsToolsCredentialShown "$1" )
}

echo "-- the account passwords are credentials --"
rigAssert "EMAIL_APP_PASSWORD, GOOGLE_ACCOUNT_PASSWORD and ATLASSIAN_ACCOUNT_PASSWORD are credentials" "$( rigIsCredential EMAIL_APP_PASSWORD ) $( rigIsCredential GOOGLE_ACCOUNT_PASSWORD ) $( rigIsCredential ATLASSIAN_ACCOUNT_PASSWORD )" "yes yes yes"
rigAssert "the id and the user beside them are not" "$( rigIsCredential GOOGLE_CLIENT_ID ) $( rigIsCredential EMAIL_USER ) $( rigIsCredential GOOGLE_ACCOUNT_NAME )" "no no no"
rigAssert "they print in the one form: the first quarter, then * for the rest" "$( rigShown 'hunter2hunter2hunter2hunter2' )" "hunter2*********************"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ACCOUNT CREDENTIALS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ACCOUNT_CREDENTIALS: OK (%d assertions, offline)\n' "$rigPassCount"
