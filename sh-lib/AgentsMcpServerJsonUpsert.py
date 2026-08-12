#!/usr/bin/env python3

# Upserts the "myx" stdio MCP server entry into a JSON config file, for
# DistroAgentsTools.fn.sh's --owner-install-vscode-integrations
# (myx.distro-agents/sh-lib/AgentsTools.Owner.include), externalized per
# this package's own externalize-awk/py convention (see
# AgentsBoardItemFrontmatterPrint.awk's own header comment for that name).
#
# argv[1]: path to the JSON config file to upsert into (created if it
#   doesn't exist yet). argv[2]: path to the myx MCP server script
#   (bin/lib/agentMcpServer.Common) to register as the "myx" entry's stdio
#   command. argv[3]: top-level object key the server entry lives under --
#   "servers" for VS Code/Copilot-Chat's .vscode/mcp.json schema,
#   "mcpServers" for Claude Code's own .mcp.json project-scope schema. Same
#   script, parameterized by target path + key name via argv, since the
#   caller .include runs this once per target in its own mcpTarget loop.
#   argv[4] (optional): a JSON array of launch args (e.g. ["--run"]) written
#   as the entry's own "args" field; omitted entirely when argv[4] isn't
#   given, which is the exact entry shape this script produced before the
#   field existed.
#
# argv[4] is not cosmetic: bin/lib/agentMcpServer.Common refuses to enter
# the server loop on a bare invocation (see its own header comment), so an
# entry registered without "args": ["--run"] is a command the MCP host can
# launch but that can never actually serve. Same argv contract as
# myx.common's own include/data/agentMcpServerJsonUpsert.py, deliberately --
# these two are parallel copies across a package boundary that neither side
# may reach across (see that file's header), so their signatures staying
# identical is what keeps the two registrations interchangeable.
#
# Non-destructive to unrelated entries: only the "myx" key under the given
# top-level key is set/overwritten -- every other existing server entry,
# and the rest of the file's top-level object, is preserved as-is. Writes
# via a temp file + atomic os.replace. Prints "OK" to stdout on success.

import json
import os
import sys
import tempfile

path = sys.argv[1]
server_script = sys.argv[2]
key = sys.argv[3]
args_json = sys.argv[4] if len(sys.argv) > 4 else None

data = {}
if os.path.exists(path):
	with open(path, "r", encoding="utf-8") as f:
		raw = f.read().strip()
	if raw:
		data = json.loads(raw)

if not isinstance(data, dict):
	raise SystemExit("%s top-level must be an object" % path)

servers = data.get(key)
if servers is None:
	servers = {}
if not isinstance(servers, dict):
	raise SystemExit("%s '%s' must be an object" % (path, key))

entry = {
	"type": "stdio",
	"command": server_script,
}
if args_json is not None:
	try:
		args = json.loads(args_json)
	except json.JSONDecodeError as e:
		raise SystemExit("argv[4] does not parse as JSON: %s" % e)
	if not isinstance(args, list):
		raise SystemExit("argv[4] must be a JSON array of args")
	entry["args"] = args

servers["myx"] = entry
data[key] = servers

# The temp file is created by mkstemp(), NOT at the predictable "<path>.tmp".
# A fixed name beside the target is a name an attacker who can write to that
# directory can pre-plant as a symlink, and open()/chmod()/replace() all follow
# it -- which would hand out a 0644 chmod and an overwrite of whatever the link
# pointed at. mkstemp() picks an unpredictable name and creates it O_EXCL, so
# there is nothing to pre-plant. dir= is the target's OWN directory on purpose:
# os.replace() is only atomic within one filesystem, so a temp file elsewhere
# (/tmp) would trade this bug for a cross-device failure.
fd, tmp = tempfile.mkstemp(
	dir=os.path.dirname(path) or ".",
	prefix=os.path.basename(path) + ".",
	suffix=".tmp",
)
try:
	with os.fdopen(fd, "w", encoding="utf-8") as f:
		json.dump(data, f, indent=2, ensure_ascii=True)
		f.write("\n")
		# The mode is ASSERTED, not inherited. os.replace() keeps the temp
		# file's own mode, and that mode came from the ambient umask of whoever
		# ran the install -- so the same config landed 0644 under umask 022 and
		# 0600 under umask 077, and a re-run under a restrictive umask silently
		# converted an existing world-readable config to owner-only. These MCP
		# config files are plain, non-secret registrations that every client of
		# this workspace has to be able to read, so 0644 is a property of the
		# file's role, not of the caller's environment. Asserted through the
		# open fd rather than the path, so it cannot resolve to anything but
		# the file we just created.
		os.fchmod(f.fileno(), 0o644)
	os.replace(tmp, path)
except BaseException:
	# Never leave the temp file behind on a failure path.
	try:
		os.unlink(tmp)
	except OSError:
		pass
	raise
print("OK")
