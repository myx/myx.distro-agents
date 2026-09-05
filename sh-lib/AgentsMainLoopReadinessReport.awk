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
# THE FLOOR IS GENERIC, NOT SLACK-SPECIFIC. Exactly two required items gate the
# loop: a team data directory, and BASIC COMMS -- the loop's own ability to
# reach the human-owner. Basic comms is satisfied by ANY ONE transport (an OR
# over transport groups, each an AND over the keys that transport needs). Today
# the only transport is Slack (team channel + owner DM); a Telegram or email
# transport is added later by appending a group in BEGIN, never by redefining
# the floor. The activity-log and alert channels are NOT floor items -- their
# absence never gates the loop; the send path falls those over to the team
# channel instead.
#
# It builds ON check-configs rather than re-reading config: it consumes only
# the `KEY: STATUS` verdict lines (any other line -- fix hints, warnings, error
# text -- is ignored), owns the floor policy itself, and the verdict it prints
# and the exit status it gates on are one computation. Exit 0 = ready, exit 1 =
# not ready, so a caller gates on this program's own status.

function keyPresent(key) { return (st[key] == "OK" || st[key] == "WARN") }
function keyWarn(key)    { return (st[key] == "WARN") }

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
		if (allPresent) { RES_SAT = 1 ; if (anyWarn) RES_WARN = 1 ; return }
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
	# Display order. A "floor" item gates the loop; an "optional" item never
	# does. A floor item's spec is transport groups (OR of AND); an optional
	# item's spec is its single backing key. Add a transport to Basic comms by
	# appending "|<key>,<key>" to its spec -- the floor itself does not change.
	addItem("Team data directory",  "floor",    "TEAM_DATA_DIRECTORY")
	addItem("Basic comms",          "floor",    "SLACK_CHANNEL_MAGIC_TEAM,SLACK_CHANNEL_HUMAN_OWNER")
	addItem("Activity-log channel", "optional", "SLACK_CHANNEL_EVENT_TRACK")
	addItem("Alert channel",        "optional", "SLACK_CHANNEL_EVENT_ALERT")

	ph["TEAM_DATA_DIRECTORY"]       = "<path>"
	ph["SLACK_CHANNEL_MAGIC_TEAM"]  = "<channel-id>"
	ph["SLACK_CHANNEL_HUMAN_OWNER"] = "<user-id>"
	ph["SLACK_CHANNEL_EVENT_TRACK"] = "<channel-id>"
	ph["SLACK_CHANNEL_EVENT_ALERT"] = "<channel-id>"
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
	floorList = ""
	for (i = 1; i <= ni; i++) {
		if (itype[i] == "floor") {
			floorList = floorList (floorList == "" ? "" : ", ") ilabel[i]
			evalFloor(ispec[i])
			if (RES_SAT) word = RES_WARN ? "ready (check)" : "ready"
			else { word = "MISSING" ; fails++ }
		} else {
			if (keyPresent(ispec[i])) word = keyWarn(ispec[i]) ? "ready (check)" : "ready"
			else { word = "not set" ; optionalUnset++ }
		}
		printf "  %s %s %s\n", ilabel[i], leader(ilabel[i], maxw), word
	}
	if (optionalUnset > 0) {
		print ""
		print "  (optional channels left unset fall over to the team channel)"
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
				printf "  %s  DistroAgentsTools.fn.sh --agents-config-option magic-coordinator --upsert %s %s\n", padRight(ilabel[i], maxw), kk[j], ph[kk[j]]
		}
	}
	exit 1
}
