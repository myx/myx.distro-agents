#!/usr/bin/env bash
set -e

## AgentsAnthropicHarness.sh -- Anthropic's specifics, and nothing else: the
## endpoint, the tier models, the credential name and the wire it speaks. It then
## execs the universal harness, which holds the logic. Same shape as
## AgentsScalewayHarness.sh, deliberately: it is not a preset and must not grow
## into a selector.
##
## THIS IS THE HARNESS LEG, NOT THE CLI LEG. `claude` in the console is the claude
## CLI and is configured by --owner-setup-claude; that is a different thing which
## this file neither replaces nor touches. Both legs read the same credential name
## out of the process environment, which is the only thing they share.

harnessHere="$( cd "$( dirname -- "$0" )" && pwd )"

## --- Anthropic's identity, as it appears in diagnostics -------------------
HARNESS_PROVIDER_NAME="Anthropic"
HARNESS_SELF_NAME="AgentsAnthropicHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
## MEASURED, not transcribed. Anthropic serves an OpenAI-chat-completions-shaped
## endpoint beside its own native Messages API, and this is it. Three
## unauthenticated POSTs, carrying their own control, established it:
##   /v1/chat/completions                    -> 401 authentication_error
##   /v1/messages            (known present) -> 401 authentication_error
##   /v1/chat/completions-no-such-path-zzz   -> 404 not_found_error
## The fake path answering 404 is what makes the 401 mean something: the
## instrument demonstrably distinguishes a routed path from an absent one.
## No credential was sent in any of the three.
HARNESS_ENDPOINT="https://api.anthropic.com/v1/chat/completions"
HARNESS_HOST="api.anthropic.com"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
## MEASURED as OpenAI-shaped rather than assumed. The refusal body from
## /v1/chat/completions is the OpenAI error envelope
##   {"error":{"code":...,"message":...,"type":...,"param":null}}
## while the SAME host's native /v1/messages answers its own envelope
##   {"type":"error","error":{"type":...,"message":...},"request_id":...}
## Two different envelopes from one host is the compatibility layer being a
## distinct handler, not the native router wearing a second path. So no
## Anthropic-native Messages wire is required for this leg, which is what
## AgentsAnthropicStub.sh's GAP-2 assumed before this was measured.
HARNESS_WIRE="OpenAiChat"

## ####################################################################
## KNOWN DEFECT ON THIS LEG -- MEASURED, NOT YET FIXED, AND NOT FIXABLE HERE.
##
## AgentsOpenAiChatWire.sh's AgentsWireErrorCode reads the error code from a
## FLAT top-level `error` string: Scaleway answers {"status":n,"error":"CODE",
## "message":"..."} and that reader returns rc=0 with the code. Anthropic's
## compatibility layer NESTS it -- the code is at `error.code` and top-level
## `error` is an object. Run against the captured bodies, that reader gives:
##   Scaleway-shaped flat body   path=error       -> rc=0  "invalid_request_error"
##   Anthropic compat 401 body   path=error       -> rc=3  ""
##   Anthropic compat 401 body   path=error.code  -> rc=0  "authentication_error"
##   a successful response body  path=error       -> rc=3  ""
## The control is the first line: the reader works where it is known to work, so
## the third and fourth lines are a result and not a broken instrument.
##
## Why it matters: the core treats rc=3 as THE SUCCESS CASE
## (AgentsUniversalHarness.sh, the harnessErrorRc branch). An Anthropic refusal
## and a clean response are therefore the same answer to this harness. A 400 on
## this leg is not reported loudly -- it falls through as a round that produced
## no content and no tool calls. That is a silent wrong answer, the worst shape a
## wrong answer takes, and it is exactly the shape a first-run test of a new leg
## walks into.
##
## The fix is one field in AgentsOpenAiChatWire.sh, which is SHARED by every
## provider speaking this wire and is held by other live work. It is deliberately
## not made here, and must not be worked around by copying that adapter: a second
## copy of a shared wire is a worse defect than the one it patches.
## ####################################################################

## --- the credential name, which the core reports but never chooses -------
## Not a gap and not a new convention: this name is already carried in this
## package independently of this file -- AgentsTools.Owner.include's claude arm
## declares it and AgentsConsoleShellScript.template.sh names it. The core reads
## it out of its own process environment, exactly as claude does. No value is
## stored here, and none ever should be.
HARNESS_CREDENTIAL_NAMES="ANTHROPIC_API_KEY"

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

## One credential reaches both models -- Anthropic scopes a key by workspace and
## policy, not by model -- so both tiers read the same name and neither falls
## back to anything. An absent key is the core's own refusal, naming
## HARNESS_CREDENTIAL_NAMES, rather than a refusal invented here.
HARNESS_TOKEN_LIGHT="${ANTHROPIC_API_KEY:-}"
HARNESS_TOKEN_MAIN="${ANTHROPIC_API_KEY:-}"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN

## exec, not source: the core becomes this process, so $0 resolves to the core's
## own directory for its helper lookups and the console keeps one invoker.
exec "$harnessHere/AgentsUniversalHarness.sh" "$@"
