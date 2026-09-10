#!/usr/bin/env python3

## AgentsAtlassianJsonObjectMerge.py -- validates a caller-supplied JSON object
## (--fields-json/--update-json/etc. on a Jira write operation) against a base
## JSON object the shell arm already built from its own known flags, and
## prints the merged object back out through json.dumps -- never a text
## splice, since a value inside the overlay may itself contain "{" or "}" and
## corrupt a naive brace-strip. The base is trusted (built by this package's
## own code); the overlay is not.
##
## argv: <base-json> <overlay-json> [<forbidden-key>...]
## Exit: 0 merged object on stdout, 1 invalid or non-object JSON,
## 2 overlay key collides with a base key, 3 overlay carries a forbidden key.

import json
import sys


def loadObject(label, text):
	try:
		value = json.loads(text)
	except ValueError as parseError:
		sys.stderr.write("⛔ ERROR: AgentsAtlassianJsonObjectMerge.py: %s is not valid JSON: %s\n" % (label, parseError))
		sys.exit(1)
	if not isinstance(value, dict):
		sys.stderr.write("⛔ ERROR: AgentsAtlassianJsonObjectMerge.py: %s must be a JSON object, got %s\n" % (label, type(value).__name__))
		sys.exit(1)
	return value


base = loadObject("the base", sys.argv[1])
overlay = loadObject("the JSON passed in", sys.argv[2])
forbidden = sys.argv[3:]

for forbiddenKey in forbidden:
	if forbiddenKey in overlay:
		sys.stderr.write("⛔ ERROR: AgentsAtlassianJsonObjectMerge.py: '%s' is not a legal key here -- see this operation's own help text for where it belongs\n" % forbiddenKey)
		sys.exit(3)

for overlayKey in overlay:
	if overlayKey in base:
		sys.stderr.write("⛔ ERROR: AgentsAtlassianJsonObjectMerge.py: key '%s' is already set by this operation's own flags -- remove it from the JSON passed in\n" % overlayKey)
		sys.exit(2)

base.update(overlay)
json.dump(base, sys.stdout)
