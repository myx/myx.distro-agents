#!/usr/bin/env bash
set -e

## AgentsDeepseekHarness.sh -- DeepSeek's official paid service, and nothing else: the endpoint,
## the tier models, the credential name and the wire it speaks. It then execs the universal
## harness, which holds the logic. The console resolves `deepseek` to exactly this path. It is
## not a preset and must not grow into a selector.
##
## THE SERVICE IS THE SUBJECT, NOT A MODEL. DeepSeek speaks the OpenAI chat wire at its own
## host, and the same account also serves the Anthropic Messages wire under `/anthropic`, so
## a preset may point PRESET_ENDPOINT_URL at https://api.deepseek.com/anthropic and the core
## switches the wire and appends `/v1/messages` itself (AgentsUniversalHarness.sh, "THE
## ENDPOINT A PRESET NAMES"). Nothing here changes for either path.

HARNESS_PROVIDER_NAME="DeepSeek"
HARNESS_SELF_NAME="AgentsDeepseekHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
## The OpenAI-compatible surface of the paid service. `/v1` is the versioned alias of the
## same endpoint, and the preset URL may name either base.
HARNESS_ENDPOINT="https://api.deepseek.com/v1/chat/completions"
HARNESS_HOST="api.deepseek.com"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential name, which the core reports but never chooses -------
HARNESS_CREDENTIAL_NAMES="DEEPSEEK_API_KEY"

## --- tier -> model, and tier -> credential -------------------------------
## BOTH IDS WERE OBSERVED ON THE WIRE on 2026-10-26: GET https://api.deepseek.com/models
## lists `deepseek-flash` (DeepSeek-V4.1-Flash) and `deepseek-v4-pro` (DeepSeek-V4-Pro), a
## 1,048,576-token context and 393,216 output tokens on each. Re-verify there before trusting
## these numbers again; a value the API refuses is corrected here and nowhere else.
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of the
## leg's own: the console exports the model name of the preset a spawn runs on (F10.2), and
## nothing else does. The default is the leg's. Best effort, as the service is: a model this
## account cannot reach fails at the wire, not here.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-deepseek-flash}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-deepseek-v4-pro}"
HARNESS_TOKEN_LIGHT="${DEEPSEEK_API_KEY:-}"
HARNESS_TOKEN_MAIN="${DEEPSEEK_API_KEY:-}"

## Each model's own window, as the service reports it on the wire: 1,048,576 tokens of
## context (2026-10-26). The output height is a workable budget, not the model's 393,216
## maximum: max_tokens is a cap and only generated tokens are billed, while the restart
## threshold is context minus output, so reserving the full maximum would restart a run at
## 655,360 tokens and re-send its prompt four times sooner than needed. 32,768 light and
## 65,536 main keep long answers possible and the first restart near 983,040 tokens.
## The family table (AgentsHarnessLimits.include): flash and pro, as above, source GET /models on 2026-10-26.
## The macros low and normal or high resolve to the two models above; a model of neither family is refused at start.
## The effort none is this service's non-thinking mode: the thinking switched off.
HARNESS_MODEL_TABLE="*flash*|1048576|384000|thinking:disabled|https://api-docs.deepseek.com/quick_start/pricing deepseek-flash: context 1M, max output 384K, read 2026-10-28
*pro*|1048576|384000|thinking:disabled|https://api-docs.deepseek.com/quick_start/pricing deepseek-pro: context 1M, max output 384K, read 2026-10-28"

## The service's own web search (AgentsHarnessSearchNative): DeepSeek's Search API (docs read 2026-10-27), POST https://api.deepseek.com/v1/tools/search with the same bearer.
## Domain limits go in as site: and -site: operators of the query (https://api-docs.deepseek.com/guides/search_and_fetch); DuckDuckGo answers where it fails.
HARNESS_WEB_SEARCH="deepseek:search"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
