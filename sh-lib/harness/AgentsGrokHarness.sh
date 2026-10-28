#!/usr/bin/env bash
set -e

## AgentsGrokHarness.sh -- xAI Grok's specifics, and nothing else: the endpoint,
## the tier models, the credential name and the wire it speaks. It then execs the
## universal harness, which holds the logic. The console and --owner-setup-grok
## both resolve `grok` to exactly this path; the vendor grok CLI is a different
## thing, reached as `grok-native`. It is not a preset and must not grow into a
## selector. See MAGIC.md for the split.

HARNESS_PROVIDER_NAME="xAI Grok"
HARNESS_SELF_NAME="AgentsGrokHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
HARNESS_ENDPOINT="https://api.x.ai/v1/chat/completions"
HARNESS_HOST="api.x.ai"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential name, which the core reports but never chooses -------
HARNESS_CREDENTIAL_NAMES="XAI_API_KEY"

## --- tier -> model, and tier -> credential -------------------------------
## Both ids are listed by this API's own /v1/models; MAGIC.md carries the evidence.
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of the leg's own: the console
## exports the model name of the preset a spawn runs on (F10.2), and nothing else does. The default is the leg's.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-grok-4.3}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-grok-4.7}"
HARNESS_TOKEN_LIGHT="${XAI_API_KEY:-}"
HARNESS_TOKEN_MAIN="${XAI_API_KEY:-}"

## Each model's own window, `context_length` in GET /v1/models/<id> on 2026-09-28. No
## output maximum is declared: that answer carries none, and one of 100000000 was accepted.
## The family table (AgentsHarnessLimits.include): one row a version this leg serves, the outputs the budgets this leg
## chose. The macros low and normal or high resolve to the two models above; a version of neither is refused at start.
## The effort none: grok-4.3 takes none (its page lists none to xhigh, read 2026-10-28); grok-4.7 has no none, so its lowest, low, is sent and the start line says so.
HARNESS_MODEL_TABLE="grok-4.3*|1000000|30000|effort:none|https://docs.x.ai/developers/models/grok-4.3.md context 1,000,000 and efforts none to xhigh, output not stated there so 30000 is a budget, read 2026-10-28
grok-4.7*|500000|65536|effort:low|https://docs.x.ai/developers/models/grok-4.7.md context 500,000 and efforts low to xhigh (no none), output not stated there so 65536 is a budget, read 2026-10-28"

## The service's own web search (AgentsHarnessSearchNative). xAI's docs (read 2026-10-27) offer the web_search tool of the Responses API, POST https://api.x.ai/v1/responses
## (https://docs.x.ai/developers/tools/web-search): filters allowed_domains or excluded_domains, 5 at most, never both; sources in citations. DuckDuckGo answers where it fails.
HARNESS_WEB_SEARCH="xai:web_search"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
