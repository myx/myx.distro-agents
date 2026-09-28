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
HARNESS_MODEL_LIGHT="claude-haiku-4-5"
HARNESS_MODEL_MAIN="claude-opus-5"

## Context budget, beside the models it describes, as on the Scaleway stub. This
## one number cannot describe both tiers -- the reference puts the main model's
## window at 1M and the light model's at 200K -- and the stub is read once,
## before the core resolves a tier, so the smaller window is the binding one.
## Set as a floor under the LIGHT tier rather than the ceiling of the main one:
## over-budgeting cannot be recovered from (the run walks into the model's own
## limit and reads exactly like a managed restart), while under-budgeting only
## summarises and restarts sooner than it had to. Still set well above this
## team's own instruction set -- the five files a heartbeat next-iteration reads
## total roughly 122k tokens -- so a pass is not restarted before it acts.
## Raise it once the tiers are confirmed, or once the light tier moves to a model
## with the larger window; nothing else has to change.
HARNESS_MODEL_CONTEXT_TOKENS="180000"
: "${MDAT_HARNESS_CONTEXT_TOKENS:=$HARNESS_MODEL_CONTEXT_TOKENS}"
export MDAT_HARNESS_CONTEXT_TOKENS

HARNESS_TOKEN_LIGHT="${ANTHROPIC_API_KEY:-${CLAUDE_CODE_OAUTH_TOKEN:-}}"
HARNESS_TOKEN_MAIN="${ANTHROPIC_API_KEY:-${CLAUDE_CODE_OAUTH_TOKEN:-}}"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES HARNESS_EXTRA_HEADERS
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh" "$@"
