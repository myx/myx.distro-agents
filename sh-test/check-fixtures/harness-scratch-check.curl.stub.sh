#!/usr/bin/env bash
## The fake `curl` for AgentsCredentialExposureCheck's harness section. It opens no
## socket. On each model round it records what the workspace's scratch folder holds
## while the harness is in flight -- the harness's own scratch has to be there -- then
## answers with one canned text round, so the run ends after it.
set -u
cat > /dev/null
printf 'ROUND\n' >> "$RIG_SCENARIO/rounds.log"
ls -1 "$MMDAPP/.local/agents/scratch" >> "$RIG_SCENARIO/scratch.log" 2>/dev/null
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-FINAL-MARKER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n'
printf 'data: [DONE]\n'
