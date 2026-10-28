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
## The two legacy rows (Haiku 4.5, Opus 4.5) come first and are each model's own page, 200K and 64K; Opus 4.6 and Sonnet 4.6 and later are 1M and 128K on their pages
## (opus-4-6 and sonnet-4-6 read 2026-10-28; the other legacy 4.x, 5 and 5.x pages not read one by one). Every other row is Anthropic's own models overview, https://platform.claude.com/docs/en/models/overview.md, read 2026-10-28: the context window row and the max output row of the
## current model of the family (Haiku 5.5, Sonnet 5.5, Opus 5.5, Fable 5.1: each 1M tokens of context and 128K of output, the synchronous Messages API limit).
## The effort none is the thinking switched off (`thinking:disabled`) where the model takes that, and REFUSED (`refuse`, an error naming the model and the efforts it
## takes) where the vendor page says it cannot be: Fable 5 and 5.1 and Opus 5.5 are "Adaptive (always on)" (their pages, read 2026-10-28), and the Models API reports
## thinking.types.disabled.supported false for Sonnet 5.5 (the overview). A model whose page was not read for this (Haiku 5.5, Sonnet 5, Opus 5 and 4.7 or 4.8) keeps
## `thinking:disabled`.
HARNESS_MODEL_TABLE="*haiku-4*|200000|64000|thinking:disabled|https://platform.claude.com/docs/en/models/haiku-4-5/overview.md Claude Haiku 4.5 (legacy): context 200K, max output 64K, read 2026-10-28
*opus-4-5*|200000|64000|thinking:disabled|https://platform.claude.com/docs/en/models/opus-4-5/overview.md Claude Opus 4.5 (legacy): context 200K, max output 64K, read 2026-10-28
*haiku*|1000000|128000|thinking:disabled|https://platform.claude.com/docs/en/models/overview.md Claude Haiku 5.5 read 2026-10-28
*sonnet-5-5*|1000000|128000|refuse|https://platform.claude.com/docs/en/models/overview.md Claude Sonnet 5.5: the Models API reports thinking.types.disabled.supported false, read 2026-10-28; context 1M, max output 128K
*sonnet*|1000000|128000|thinking:disabled|https://platform.claude.com/docs/en/models/overview.md Claude Sonnet 5.5 read 2026-10-28
*opus-5-5*|1000000|128000|refuse|https://platform.claude.com/docs/en/models/overview.md Claude Opus 5.5: thinking is adaptive and always on, read 2026-10-28; context 1M, max output 128K
*opus*|1000000|128000|thinking:disabled|https://platform.claude.com/docs/en/models/overview.md Claude Opus 5.5 read 2026-10-28
*fable*|1000000|128000|refuse|https://platform.claude.com/docs/en/models/overview.md Claude Fable 5.1 and .../fable-5/overview.md Claude Fable 5, thinking is adaptive and always on, read 2026-10-28"

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
