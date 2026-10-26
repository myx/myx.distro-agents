#!/usr/bin/env bash
set -e

## AgentsCopilotHarness.sh -- GitHub Copilot's specifics, and nothing else: the endpoint,
## the tier models, the credential names and the wire it speaks. It then execs the
## universal harness, which holds the logic. It is not a preset and must not grow into a
## selector. See MAGIC.md for the split.

HARNESS_PROVIDER_NAME="GitHub Copilot"
HARNESS_SELF_NAME="AgentsCopilotHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
HARNESS_ENDPOINT="https://api.githubcopilot.com/chat/completions"
HARNESS_HOST="api.githubcopilot.com"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential names, which the core reports but never chooses ------
HARNESS_CREDENTIAL_NAMES="COPILOT_GITHUB_TOKEN"

## --- tier -> model, and tier -> credential -------------------------------
## THESE MODEL IDS ARE ANCHORED BY ELIMINATION, NOT BY MEASURED CAPABILITY. Both are read
## out of this machine's own vendor state, with no network touched: ~/.copilot/settings.json
## carries "model": "claude-fable-5" and ~/.copilot/config.json carries
## "recentModelIds": ["gpt-5.6-sol"]. config.json says of itself that it is managed
## automatically and that user settings belong in settings.json, so the first id is a
## declared choice and the second is machine-managed MRU state -- main is the tier doing the
## real work, so it takes the id actually selected. NEITHER ID IS YET CONFIRMED ACCEPTED BY
## THE ENDPOINT UNDER THIS SPELLING.
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of the leg's own: the console
## exports the model name of the preset a spawn runs on (F10.2), and nothing else does. The default is the leg's.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-gpt-5.6-sol}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-claude-fable-5}"
HARNESS_TOKEN_LIGHT="${COPILOT_GITHUB_TOKEN:-}"
HARNESS_TOKEN_MAIN="${COPILOT_GITHUB_TOKEN:-}"

## --- the family table: each model family's own limits and effort none ---------
## (AgentsHarnessLimits.include.) The macros low and normal or high resolve to the two models above; a model the
## preset names resolves through this table, and one of no family here is refused at start.
## Source: GitHub Copilot docs, models-and-pricing and supported-models (read 2026-10-26).
## gpt-5.6-sol: its Default price tier covers up to 272,000 input tokens; above that is the
## "Long context" tier, at twice the input price. So its context is the step, 272,000, not
## the window, and the output is 32,768, which keeps the restart threshold (context minus
## output, 239,232) under the price step.
## claude-fable-5: no long-context tier ("Not applicable", one flat price), and the 1M
## context is supported in Copilot CLI: 1,000,000 with a 65,536 output, the first restart
## near 934,464 tokens.
## A preset may still name a threshold of its own, PRESET_CONTEXT_MAX_SIZE, and the core
## warns at start when that is far below these numbers.
## The effort none: gpt-5.6-sol takes reasoning_effort none; a claude model behind this endpoint is sent its lowest,
## low, because the endpoint's own spelling of none for it is not observed (the start line says so).
HARNESS_MODEL_TABLE="gpt-5.6-sol*|272000|32768|effort:none|GitHub Copilot docs, models-and-pricing and supported-models, read 2026-10-26
claude-fable*|1000000|65536|effort:low|GitHub Copilot docs, models-and-pricing and supported-models, read 2026-10-26"

## --- credential exchange, and extra headers: both declared empty ----------
## Empty spends the stored credential itself as the bearer and adds no header. That path is
## untested against this endpoint, and the first live run is what settles it -- MAGIC.md
## carries the reasoning, the unresolved premise conflict and what was already searched.
## Set HARNESS_TOKEN_EXCHANGE="GithubCopilot" once sh-lib/AgentsGithubCopilotExchange.sh exists.
HARNESS_TOKEN_EXCHANGE=""
HARNESS_EXTRA_HEADERS=""

## --- prompt_cache_key: off by default here ---------------------------------
## UNOBSERVED: this endpoint has not yet accepted even a plain request, and it fronts
## non-OpenAI models, which may refuse a body field they do not know. Off until a live
## run shows it accepted; HARNESS_PROMPT_CACHE_KEY=on in the environment tries it.
HARNESS_PROMPT_CACHE_KEY="${HARNESS_PROMPT_CACHE_KEY:-off}"

export HARNESS_PROMPT_CACHE_KEY
## The service's own web search (AgentsHarnessSearchNative): none. GitHub's docs read 2026-10-27 offer model web search in Copilot chat on github.com only (changelog), and the
## Copilot SDK docs index (https://docs.github.com/en/copilot/how-tos/copilot-sdk) lists no search tool for the inference API; WebSearch is DuckDuckGo's.
HARNESS_WEB_SEARCH="none"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN
export HARNESS_TOKEN_EXCHANGE HARNESS_EXTRA_HEADERS

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
