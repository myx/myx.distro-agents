#!/usr/bin/env bash
set -e

## AgentsAnthropicStub.sh -- STRUCTURE WITH NAMED GAPS. NOT RUNNABLE.
##
## Holds the SHAPE of an Anthropic stub and the constraints that shape has to
## satisfy, so whoever fills it in is not rediscovering them. It deliberately
## does not work: nothing here could be confirmed on the wire, vendor
## documentation is already wrong on one model in use, and lifting names from a
## neighbouring parser was refused as a shortcut. Honest and non-working beats
## plausible and wrong. Running it prints the gaps and exits non-zero.

harnessHere="$( cd "$( dirname -- "$0" )" && pwd )"

## --- identity: ours to choose, no external source needed -----------------
HARNESS_PROVIDER_NAME="Anthropic"
HARNESS_SELF_NAME="AgentsAnthropicStub.sh"

## --- credential: NOT a gap. This name is already carried in this repository,
## independently of vendor documentation -- AgentsTools.Owner.include's claude
## arm declares it and AgentsConsoleShellScript.template.sh exports it.
HARNESS_CREDENTIAL_NAMES="ANTHROPIC_API_KEY"

## --- GAP-1: the endpoint and its host. Left empty rather than transcribed --
## a URL reads as obviously-correct and is the reason a whole leg 404s.
HARNESS_ENDPOINT=""
HARNESS_HOST=""

## --- GAP-2: the wire adapter. The core sources Agents${HARNESS_WIRE}Wire.sh;
## the name below is chosen, the FILE is the gap. It cannot be written from the
## OpenAI adapter by analogy -- the schemas differ in shape, not spelling.
HARNESS_WIRE="AnthropicMessages"

## --- GAP-3: tier -> model. Exact strings, no tolerance, no way to derive them.
HARNESS_MODEL_LIGHT=""
HARNESS_MODEL_MAIN=""
HARNESS_TOKEN_LIGHT="${ANTHROPIC_API_KEY:-}"
HARNESS_TOKEN_MAIN="${ANTHROPIC_API_KEY:-}"

## =========================================================================
## CONSTRAINTS THE ADAPTER IN GAP-2 MUST SATISFY. Measured and load-bearing,
## recorded here because the adapter does not exist yet and writing it is not a
## transcription job.
##
## 1. STORE AND REPLAY, NEVER REGENERATE. Whatever was sent is replayed
##    byte-for-byte, never re-rendered from the same inputs. A re-rendered
##    `system` is an EDIT to a bound prefix even when the output looks
##    identical -- and "looks identical" is not the test applied to it.
## 2. THE PREFIX IS ESTABLISHED AT SESSION START AND NEVER TOUCHED WITHIN A
##    SESSION. Tool composition, system prompt and rendering all obey that one
##    line. There is no "just this once" amendment to it.
## 3. `system` AND `tools` ARE BOUND BY EVERY THINKING BLOCK PRODUCED AFTER
##    THEM. `tools` binds as a NAME-SORTED SET, not as bytes: reordering is
##    safe, adding or removing a tool mid-session is not. Consequence, and the
##    one most likely to be walked into: a harness that rebuilds its system
##    prompt per task PASSES ON SCALEWAY and 400s here the first time a task
##    thinks. The OpenAI-wire core is not a proof of correctness for this leg.
## 4. TAIL-TRUNCATION SURVIVES WHERE MID-HISTORY EDITING DOES NOT, and only for
##    a TRUE prefix: every retained record byte-identical to what was sent, in
##    the same order, with nothing removed from the middle.
## 5. BOTH OF THOSE SURFACE AT REPLAY, NOT AT THE EDIT. The request that breaks
##    is not the request that did the damage, so a test sending one round and
##    stopping cannot see either. Exercising this leg needs a multi-round
##    session with at least one thinking block in it.
## 6. THE TOOL-NAME-IN-PROSE HAZARD APPLIES HERE TOO. See the marked comments in
##    AgentsUniversalHarness.sh and AgentsOpenAiChatWire.sh: tool names appear
##    in instructions the model reads, where no structural check can see them.
## 7. THE ADAPTER INTERFACE IS A NAMING CONTRACT, AND THIS IS ITS ONLY ROSTER.
##    The `AgentsWire*` prefix deliberately does NOT encode the file name -- a
##    second adapter defines the SAME names, which is what lets the core source
##    one or the other without knowing which. The set is therefore discoverable
##    only by grepping the core's call sites, so it is written here, where
##    whoever writes that second adapter already stands. An adapter omitting any
##    one of these fails at the CALL, not at load, and no check catches it:
##      AgentsWireInitMessages              AgentsWireUserRecord
##      AgentsWireRequestBody
##      AgentsWireStreamConsume             AgentsWireSynthesizeResponse
##      AgentsWireErrorCode                 AgentsWireToolCallCount
##      AgentsWireFinalContent              AgentsWireFinishReason
##      AgentsWireToolCallId                AgentsWireToolCallName
##      AgentsWireToolCallArgs              AgentsWireToolCallEntry
##      AgentsWireAssistantToolCallsRecord  AgentsWireToolResultRecord
##    AgentsOpenAiChatWire.sh additionally defines AgentsWireResponseField, which
##    is INTERNAL to that adapter -- the core never calls it, and a second
##    adapter is under no obligation to define it or to address its response the
##    same way. Do not copy it in as though it were part of the contract.
##    A roster is a measurement of a moving thing and nothing verifies this one:
##    if the core grows a call this goes stale silently, so re-derive it from the
##    core's call sites rather than trusting the list.
## =========================================================================

## --- preflight: refuse, and say exactly what is missing -------------------
## This is the whole runtime behaviour of this file. It never execs the core,
## because doing so would mean contacting a host with invented values.
anthropicGaps=""
[ -n "$HARNESS_ENDPOINT" ]    || anthropicGaps="$anthropicGaps
  GAP-1 HARNESS_ENDPOINT   -- the request URL, unobserved"
[ -n "$HARNESS_HOST" ]        || anthropicGaps="$anthropicGaps
  GAP-1 HARNESS_HOST       -- the host named in refusal messages, unobserved"
[ -f "$harnessHere/Agents${HARNESS_WIRE}Wire.sh" ] || anthropicGaps="$anthropicGaps
  GAP-2 Agents${HARNESS_WIRE}Wire.sh -- the wire adapter, not written (see the constraints above)"
[ -n "$HARNESS_MODEL_LIGHT" ] || anthropicGaps="$anthropicGaps
  GAP-3 HARNESS_MODEL_LIGHT -- model id for the light tier, unobserved"
[ -n "$HARNESS_MODEL_MAIN" ]  || anthropicGaps="$anthropicGaps
  GAP-3 HARNESS_MODEL_MAIN  -- model id for the normal/heavy tiers, unobserved"

if [ -n "$anthropicGaps" ] ; then
	echo "⛔ ERROR: $HARNESS_SELF_NAME is STRUCTURE WITH NAMED GAPS and is not runnable." >&2
	echo "         It is deliberately non-working: the missing values could not be observed," >&2
	echo "         must not be taken from vendor documentation (already wrong on one model in" >&2
	echo "         use), and must not be invented or lifted from a neighbouring parser." >&2
	echo "         Unfilled:$anthropicGaps" >&2
	exit 1
fi

## Unreachable until every gap above is filled. Kept so the exec contract is
## visible and matches the Scaleway stub exactly.
export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
exec "$harnessHere/AgentsUniversalHarness.sh" "$@"
