#!/usr/bin/env awk
# Fills the macros of one word of a routine's `input-scan-def:` (F6.3): `{{<option-name>}}` over the five names of
# the common option set (F2.2), the values of the spawn's own context, handed in the environment. By the shared filler
# (AgentsToolingTemplateFill.awk, loaded ahead of this file with -f): by position, so & and \ in a value pass through.
# A name that is none of the five stays as written, and the caller refuses the definition for it.
function ttSlot( name ) {
	if ( name == "team-member" ) { return ENVIRON["SCAN_TEAM_MEMBER"] ; }
	if ( name == "session-id" ) { return ENVIRON["SCAN_SESSION_ID"] ; }
	if ( name == "spawn-id" ) { return ENVIRON["SCAN_SPAWN_ID"] ; }
	if ( name == "select-workspace" ) { return ENVIRON["SCAN_SELECT_WORKSPACE"] ; }
	if ( name == "tooling-origin" ) { return ENVIRON["SCAN_TOOLING_ORIGIN"] ; }
	return "{{" name "}}" ;
}
{ printf "%s", ttFillSlots( $0, 0 ) ; }
