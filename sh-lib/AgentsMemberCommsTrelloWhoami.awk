#!/usr/bin/env awk
# Prints TRELLO_USER_ID/TRELLO_USERNAME parsed out of a Trello members/me JSON response.
function field(k,   v) {
	if (!match(body, "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"")) return ""
	v = substr(body, RSTART, RLENGTH)
	sub(/^"[^"]*"[ \t]*:[ \t]*"/, "", v)
	sub(/"$/, "", v)
	return v
}
{ body = body $0 ; }
END {
	id = field("id") ; user = field("username")
	if (id == "" || user == "") {
		printf("⛔ ERROR: --member-comms-trello-whoami: members/me carried no id/username -- the acting identity is UNKNOWN, not absent\n") > "/dev/stderr"
		exit 1
	}
	printf("TRELLO_USER_ID=%s\nTRELLO_USERNAME=%s\n", id, user)
}
