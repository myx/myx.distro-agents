#!/usr/bin/env python3

# Sequential exact-literal-substring patch applier for
# DistroAgentsTools.fn.sh's --edit-patch-from-stdin body-input mode
# (myx.distro-agents/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include),
# externalized per this package's own externalize-awk/py convention (see
# AgentsBoardItemFrontmatterPrint.awk's own header comment for that name).
#
# Reads both inputs from a single stdin stream, in this framing: the JSON
#   array of patch objects first, the existing board-item body text (empty
#   on --create) immediately after it. A JSON array is self-delimiting, so
#   the array is decoded from the front of the stream and everything past
#   its closing bracket is taken verbatim as the body -- one unambiguous
#   stream, no separator the body could collide with, and nothing for the
#   caller to create and clean up. stdin also sidesteps the ARG_MAX and
#   shell-escaping limits a bare-argv body/patch set would otherwise hit.
#
#   Each patch object: {"old": <text>, "new": <text>, "replace_all": <bool,
#   default false>}.
#
# Applies each patch in order against the result of the previous one --
# same as running several literal-substring edits in sequence. Each `old`
# must match the current text exactly once unless `replace_all` is true, in
# which case every occurrence is replaced. Prints the final text to stdout
# on success -- nothing else on stdout, ever.
#
# On any failure (invalid JSON, wrong shape, `old` not found, `old`
# ambiguous without replace_all) prints exactly one "⛔ ERROR: ..." line to
# stderr, matching this tool family's own error-message shape, and exits 1
# with no stdout output at all -- so the caller's own `body="$( ... )"`
# assignment fails cleanly under `set -e` before any file on disk is
# touched; the original board-item is never partially written.

import json
import sys

PREFIX = "⛔ ERROR: DistroAgentsTools --intern-op-board-upsert-move-edit: --edit-patch-from-stdin:"


def fail(message):
	sys.stderr.write("{} {}\n".format(PREFIX, message))
	sys.exit(1)


def main():
	raw = sys.stdin.read()

	# Patch array leads the stream; the body follows its closing bracket.
	# Decode the array from the front, keep the remainder verbatim as body.
	start = len(raw) - len(raw.lstrip(" \t\r\n"))
	try:
		patches, end = json.JSONDecoder().raw_decode(raw, start)
	except Exception as e:
		fail("invalid JSON: {}".format(e))
		return

	text = raw[end:]

	if not isinstance(patches, list):
		fail("patch input must be a JSON array")

	for i, p in enumerate(patches):
		if not isinstance(p, dict) or "old" not in p or "new" not in p:
			fail('patch[{}] must be an object with "old" and "new"'.format(i))
		old, new = p["old"], p["new"]
		replace_all = bool(p.get("replace_all", False))
		if not isinstance(old, str) or not isinstance(new, str):
			fail('patch[{}]: "old"/"new" must be strings'.format(i))
		if old == "":
			fail('patch[{}]: "old" must not be empty'.format(i))
		count = text.count(old)
		if count == 0:
			fail("patch[{}]: old text not found: {!r}".format(i, old))
		if count > 1 and not replace_all:
			fail(
				'patch[{}]: old text matches {} times, not unique -- pass '
				'"replace_all": true or narrow the match: {!r}'.format(i, count, old)
			)
		text = text.replace(old, new) if replace_all else text.replace(old, new, 1)

	sys.stdout.write(text)


if __name__ == "__main__":
	main()
