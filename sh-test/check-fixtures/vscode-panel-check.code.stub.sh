#!/usr/bin/env bash
## The fake `code` for AgentsVscodePanelInstallCheck. It starts no editor: every call is
## appended to $RIG_SCENARIO/code.log, one line per call, and exits 0.
set -u
printf '%s\n' "$*" >> "$RIG_SCENARIO/code.log"
exit 0
