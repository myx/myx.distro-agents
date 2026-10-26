#!/usr/bin/env bash
set -e

## AgentsClaudeHarness.sh -- Anthropic's specifics, and nothing else: the
## endpoint, the tier models, the credential name and the wire it speaks. It then
## execs the universal harness, which holds the logic. Same shape as
## AgentsScalewayHarness.sh, deliberately: it is not a preset and must not grow
## into a selector.
##
## The filename IS the console's own selection name: `claude` selects this file,
## and --owner-setup-claude configures it. The vendor claude CLI is a different
## thing, reached as `claude-native` and configured by --owner-setup-claude-native.
## Both read the same credential name out of the process environment, which is the
## only thing they share. HARNESS_PROVIDER_NAME below names the provider, Anthropic;
## the selection name and the provider name are deliberately not the same string.

## --- Anthropic's identity, as it appears in diagnostics -------------------
HARNESS_PROVIDER_NAME="Anthropic"
HARNESS_SELF_NAME="AgentsClaudeHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
## The native Messages API. The chat-completions-shaped endpoint beside it on the same
## host does not cache prompts at all -- the compatibility page of Anthropic says so --
## so every round of a long run was paid in full there. MEASURED: this path takes the
## key as a Bearer the way the core sends it -- an unauthenticated POST answers
## "x-api-key header is required", the same POST with the Bearer passes auth.
HARNESS_ENDPOINT="https://api.anthropic.com/v1/messages"
HARNESS_HOST="api.anthropic.com"

## --- which wire this endpoint speaks: resolves to AgentsAnthropicMessagesWire.sh,
## GAP-2 of AgentsAnthropicStub.sh. Its envelope is {"type":"error","error":{...}},
## which that wire reads, so a refusal is reported rather than read as a round.
HARNESS_WIRE="AnthropicMessages"

## --- the one header this API requires beyond auth, on the channel the core owns ---
HARNESS_EXTRA_HEADERS="anthropic-version: 2023-06-01"

## --- the credential names, which the core reports but never chooses ------
HARNESS_CREDENTIAL_NAMES="ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN"

## --- tier -> model, and tier -> credential -------------------------------
## THESE MODEL IDS ARE REFERENCE-DERIVED AND HAVE NOT BEEN OBSERVED ON THE WIRE.
## That is a weaker claim than the endpoint above and is stated as such rather
## than rounded up. Anthropic's model list is behind authentication -- GET
## /v1/models answers 401 unauthenticated -- so confirming an id costs a live
## key, and no key was used, requested or invented in writing this file.
## They are the current generation as this package's own bundled Anthropic
## reference states it, and a neighbouring stub in this same directory carries a
## warning that vendor documentation has already been wrong on one model in use.
## VERIFY BEFORE TRUSTING, with a key already on the machine and never pasted
## into a session:
##   curl -s https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" -H 'anthropic-version: 2023-06-01'
## An id this endpoint does not list is corrected here, and nothing else changes.
##
## The split follows the Scaleway precedent rather than inventing one: light
## anchors on the genuinely smaller and cheaper model, and the capable model
## carries normal and heavy, heavy differing only by the core's own
## reasoning_effort. Which model belongs on which tier is the human-owner's call,
## and this is a proposal, not a decision taken here.
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of the leg's own: the console
## exports the model name of the preset a spawn runs on (F10.2), and nothing else does. The default is the leg's.
## The macros low and normal or high resolve to the two models below; a name the preset gives resolves through the table.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-claude-sonnet-5-5}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-claude-opus-5-5}"

## The family table (AgentsHarnessLimits.include): the limits and the effort none of every model family this leg serves.
## sonnet and opus: max_input_tokens is the context window, max_tokens the output maximum, as GET /v1/models/<id>
## returned them on 2026-09-28. fable: GitHub Copilot's supported-models page of 2026-10-26 (its 1M context, and the
## output the Copilot leg uses for it), the API's own figure not read. haiku: 200000 and 64000 as Anthropic's models
## overview gave them when last read, NOT re-read for this table. The effort none is the thinking switched off.
HARNESS_MODEL_TABLE="*haiku*|200000|64000|thinking:disabled|Anthropic models overview, not re-read for this table
*sonnet*|1000000|128000|thinking:disabled|GET /v1/models/<id> on 2026-09-28
*opus*|1000000|128000|thinking:disabled|GET /v1/models/<id> on 2026-09-28
*fable*|1000000|65536|thinking:disabled|GitHub Copilot supported-models on 2026-10-26"

HARNESS_TOKEN_LIGHT="${ANTHROPIC_API_KEY:-${CLAUDE_CODE_OAUTH_TOKEN:-}}"
HARNESS_TOKEN_MAIN="${ANTHROPIC_API_KEY:-${CLAUDE_CODE_OAUTH_TOKEN:-}}"

## The service's own web search (AgentsHarnessSearchNative): the Messages API server-side web search tool; WebSearch uses it, and DuckDuckGo answers where it fails.
HARNESS_WEB_SEARCH="anthropic:web_search_20250305"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES HARNESS_EXTRA_HEADERS
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
