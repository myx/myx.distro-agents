#!/usr/bin/env awk

# Renders --intern-op-check-configs's per-key OK/WARN/FAIL/SKIP lines as a
# compact, plain-language main-loop readiness report. Run under LC_ALL=C for
# byte safety.
#
# WHY THIS FILE EXISTS. Main-loop gates loop entry on a small readiness FLOOR
# and used to dump raw per-key verdicts plus fix-hint and `⛔ ERROR:` lines
# straight at the operator -- a wall to read at exactly the moment something is
# wrong. This renders the floor as one aligned, scannable list with a single
# verdict line, glossing each config key into plain words and hiding the noise.
#
# THE FLOOR IS GENERIC, NOT SLACK-SPECIFIC. The required items gate the loop: a
# team data directory, BASIC COMMS -- the loop's own ability to reach the
# human-owner -- and the agent CLI service every iteration spawns through,
# without which each spawn fails rc=5 and the backoff walks to its ceiling in
# silence. Basic comms is satisfied by ANY ONE transport (an OR over transport
# groups, each an AND over the keys that transport needs). Today the only
# transport is Slack (team channel + owner DM); a Telegram or email transport is
# added later by appending a group in BEGIN, never by redefining the floor. The
# activity-log and alert channels are NOT floor items -- their absence never
# gates the loop; the send path falls those over to the team channel instead.
#
# A DIAGNOSED ITEM IS NEITHER. It is a state the loop cannot fix and no config
# key holds -- today, whether the selected agent CLI is signed in, which the
# main-loop arm reads from the CLI itself and hands over as one more verdict
# line. It is named in the report so an unauthenticated machine is told so at
# entry instead of failing every iteration opaquely, and it never gates: the
# probe answers for one CLI only, so a machine it cannot read reports "not
# checked" rather than being refused. It carries no ph[]/keyScope[] entry
# either, since there is nothing for the operator to --upsert.
#
# It builds ON check-configs rather than re-reading config: it consumes only
# the `KEY: STATUS` verdict lines (any other line -- fix hints, warnings, error
# text -- is ignored), owns the floor policy itself, and the verdict it prints
# and the exit status it gates on are one computation. Exit 0 = ready, exit 1 =
# not ready, so a caller gates on this program's own status.

function keyPresent(key) { return (st[key] == "OK" || st[key] == "WARN") ; }
function keyWarn(key)    { return (st[key] == "WARN") ; }

# Evaluates a floor item's transport groups (groups by "|", keys within a group
# by ","). Satisfied when ANY one group has all its keys present. Results are
# returned through globals RES_SAT / RES_WARN, since awk returns one value.
function evalFloor(spec,   n, groups, g, m, keys, j, allPresent, anyWarn) {
	RES_SAT = 0 ; RES_WARN = 0
	n = split(spec, groups, "|")
	for (g = 1; g <= n; g++) {
		m = split(groups[g], keys, ",")
		allPresent = 1 ; anyWarn = 0
		for (j = 1; j <= m; j++) {
			if (!keyPresent(keys[j])) allPresent = 0
			if (keyWarn(keys[j]))     anyWarn = 1
		}
		if (allPresent) { RES_SAT = 1 ; if (anyWarn) RES_WARN = 1 ; return ; }
	}
}

function addItem(label, type, spec) {
	ni++
	ilabel[ni] = label ; itype[ni] = type ; ispec[ni] = spec
	if (length(label) > maxw) maxw = length(label)
}

function leader(text, width,   need, d, j) {
	need = width - length(text) + 4
	d = ""
	for (j = 0; j < need; j++) d = d "."
	return d
}

function padRight(text, width,   out) {
	out = text
	while (length(out) < width) out = out " "
	return out
}

BEGIN {
	ni = 0 ; maxw = 0
	# Display order. A "floor" item gates the loop; "optional" and "diagnosed"
	# items never do. A floor item's spec is transport groups (OR of AND); an
	# optional or diagnosed item's spec is its single backing key. Add a
	# transport to Basic comms by appending "|<key>,<key>" to its spec -- the
	# floor itself does not change.
	addItem("Team data directory",  "floor",      "TEAM_DATA_DIRECTORY")
	addItem("Basic comms",          "floor",      "SLACK_CHANNEL_MAGIC_TEAM,SLACK_CHANNEL_HUMAN_OWNER")
	addItem("Agent CLI service",    "floor",      "SPAWN_CLI_SERVICE")
	addItem("Agent CLI sign-in",    "diagnosed",  "SPAWN_CLI_AUTHENTICATED")
	addItem("Activity-log channel", "optional",   "SLACK_CHANNEL_EVENT_TRACK")
	addItem("Alert channel",        "optional",   "SLACK_CHANNEL_EVENT_ALERT")

	ph["TEAM_DATA_DIRECTORY"]       = "<path>"
	ph["SLACK_CHANNEL_MAGIC_TEAM"]  = "<channel-id>"
	ph["SLACK_CHANNEL_HUMAN_OWNER"] = "<user-id>"
	ph["SPAWN_CLI_SERVICE"]         = "<cli-name>"
	ph["SLACK_CHANNEL_EVENT_TRACK"] = "<channel-id>"
	ph["SLACK_CHANNEL_EVENT_ALERT"] = "<channel-id>"

	# The scope each key is actually stored under, so a fix hint names the one
	# that will be read back. The floor spans two, and writing SPAWN_CLI_SERVICE
	# into magic-coordinator leaves the console still unable to find it.
	keyScope["TEAM_DATA_DIRECTORY"]       = "magic-coordinator"
	keyScope["SLACK_CHANNEL_MAGIC_TEAM"]  = "magic-coordinator"
	keyScope["SLACK_CHANNEL_HUMAN_OWNER"] = "magic-coordinator"
	keyScope["SPAWN_CLI_SERVICE"]         = "magic-team"
	keyScope["SLACK_CHANNEL_EVENT_TRACK"] = "magic-coordinator"
	keyScope["SLACK_CHANNEL_EVENT_ALERT"] = "magic-coordinator"
}

/^[A-Z_]+:[ \t]+(OK|WARN|FAIL|SKIP)$/ {
	k = $1
	sub(/:$/, "", k)
	st[k] = $2
}

END {
	print ""
	print "Main-loop readiness"
	print ""
	fails = 0
	optionalUnset = 0
	signedOut = 0
	floorList = ""
	for (i = 1; i <= ni; i++) {
		if (itype[i] == "floor") {
			floorList = floorList (floorList == "" ? "" : ", ") ilabel[i]
			evalFloor(ispec[i])
			if (RES_SAT) word = RES_WARN ? "ready (check)" : "ready"
			else { word = "MISSING" ; fails++ ; }
		} else if (itype[i] == "diagnosed") {
			if (st[ispec[i]] == "OK") word = "signed in"
			else if (st[ispec[i]] == "FAIL") { word = "NOT SIGNED IN" ; signedOut++ ; }
			else word = "not checked"
		} else {
			if (keyPresent(ispec[i])) word = keyWarn(ispec[i]) ? "ready (check)" : "ready"
			else { word = "not set" ; optionalUnset++ ; }
		}
		printf "  %s %s %s\n", ilabel[i], leader(ilabel[i], maxw), word
	}
	if (optionalUnset > 0) {
		print ""
		print "  (optional channels left unset fall over to the team channel)"
	}
	# Named, never gated: claude is the one CLI whose sign-in state is readable,
	# so a FAIL can only have come from it and this is the command that fixes it.
	if (signedOut > 0) {
		print ""
		print "  (the selected agent CLI is installed and selected but signed out, so"
		print "   every spawn will fail -- sign in yourself with: claude auth login)"
	}
	print ""
	if (fails == 0) {
		printf "READY: required floor present (%s) -- starting the loop.\n", floorList
		exit 0
	}
	printf "NOT READY: required floor incomplete -- loop not started.\n"
	print ""
	print "Set each missing floor item, then start the loop again:"
	for (i = 1; i <= ni; i++) {
		if (itype[i] != "floor") continue
		evalFloor(ispec[i])
		if (RES_SAT) continue
		nG = split(ispec[i], grp, "|")
		mK = split(grp[1], kk, ",")
		for (j = 1; j <= mK; j++) {
			if (!keyPresent(kk[j]))
				printf "  %s  DistroAgentsTools.fn.sh --agents-config-option %s --upsert %s %s\n", padRight(ilabel[i], maxw), keyScope[kk[j]], kk[j], ph[kk[j]]
		}
	}
	exit 1
}
