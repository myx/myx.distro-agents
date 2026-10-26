#!/usr/bin/env bash
## Behavioural check on the limits and the effort a harness run judges for the model it runs (AgentsHarnessLimits.include),
## from the family table each thin wrapper supplies (Agents{Claude,Copilot,Grok,Scaleway,Deepseek,StandardV1}Harness.sh).
## Each wrapper is sourced with exec stubbed, so its table is read as the core would get it. Held, per wrapper:
##   1. a model of each family gets the window, the output maximum and the restart threshold (window less output) of that family
##   2. the preset's PRESET_CONTEXT_MAX_SIZE sets the threshold ahead of the family's, and the operator's override ahead of that;
##      the window and the output stay the family's
##   3. a model of no family is refused with rc 1, and the refusal lists the families the leg knows
##   4. a leg with no table keeps the pair it declares
##   5. the effort: unset sends nothing, normal is medium, low and high are themselves, and none is sent as the family says
##      (its none, its lowest with the start line saying so, the thinking off, or nothing for a model that does not reason)
## Offline by construction: nothing is run but the wrappers' own assignments.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigLimits="$rigHere/harness/AgentsHarnessLimits.include"
[ -f "$rigLimits" ] || { echo "⛔ ERROR: not found at the origin this workspace resolves: $rigLimits -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 rigFailCount=0
rigAssert(){ ## label, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; echo "  PASS  $1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; echo "  FAIL  $1" ; echo "        got:  $2" ; echo "        want: $3"
	fi
}
## The table a wrapper states, as the core would receive it: the wrapper sourced with exec stubbed and dummy credentials.
rigTable(){ ## wrapper file name
	( exec(){ return 0 ; }
	  export MDLT_ORIGIN ANTHROPIC_API_KEY=rig OPENAI_API_KEY=rig HARNESS_ENDPOINT_URL=https://rig.example/v1 HARNESS_MODEL_LIGHT=rig-model HARNESS_MODEL_MAIN=rig-model
	  unset HARNESS_MODEL_TABLE
	  . "$rigHere/harness/$1" > /dev/null 2>&1
	  printf '%s' "${HARNESS_MODEL_TABLE:-}" )
}
## window, output, threshold and none form that the table gives a model; or REFUSED and the refusal.
rigJudge(){ ## table, model [env assignments...]
	local judgeTable="$1" judgeModel="$2" ; shift 2
	( export HARNESS_MODEL_TABLE="$judgeTable" harnessSelfName=rig-leg harnessBad="" harnessOff=""
	  unset PRESET_CONTEXT_MAX_SIZE MDAT_HARNESS_CONTEXT_TOKENS
	  while [ $# -gt 0 ] ; do export "$1" ; shift ; done
	  . "$rigLimits"
	  if AgentsHarnessLimitsResolve "$judgeModel" "" "" 2> /dev/null ; then
		printf '%s %s %s %s' "$harnessWindowTokens" "$harnessOutputTokens" "$harnessContextTokens" "$harnessNoneForm"
	  else
		printf 'REFUSED %s' "$( AgentsHarnessLimitsResolve "$judgeModel" "" "" 2>&1 > /dev/null )"
	  fi )
}
rigEffort(){ ## none form, effort -- what the wire is given: reasoning effort, thinking off, the note
	( . "$rigLimits" ; harnessNoneForm="$1" ; harnessEffort="$2" ; AgentsHarnessEffortApply
	  printf '[%s] [%s] [%s]' "$harnessReasoningEffort" "$harnessThinkingOff" "$harnessEffortNote" )
}

rigCase(){ ## wrapper, table, model, want "window output threshold noneform"
	rigAssert "$1: $3" "$( rigJudge "$2" "$3" )" "$4"
}

echo "-- 1. each family of each wrapper --"
rigClaude="$( rigTable AgentsClaudeHarness.sh )"
rigCase claude "$rigClaude" claude-haiku-4-5  "200000 64000 136000 thinking:disabled"
rigCase claude "$rigClaude" claude-sonnet-5-5 "1000000 128000 872000 thinking:disabled"
rigCase claude "$rigClaude" claude-opus-5-5   "1000000 128000 872000 thinking:disabled"
rigCase claude "$rigClaude" claude-fable-5    "1000000 65536 934464 thinking:disabled"
rigCopilot="$( rigTable AgentsCopilotHarness.sh )"
rigCase copilot "$rigCopilot" gpt-5.6-sol    "272000 32768 239232 effort:none"
rigCase copilot "$rigCopilot" claude-fable-5 "1000000 65536 934464 effort:low"
rigDeepseek="$( rigTable AgentsDeepseekHarness.sh )"
rigCase deepseek "$rigDeepseek" deepseek-flash   "1048576 32768 1015808 thinking:disabled"
rigCase deepseek "$rigDeepseek" deepseek-v4-pro  "1048576 65536 983040 thinking:disabled"
rigGrok="$( rigTable AgentsGrokHarness.sh )"
rigCase grok "$rigGrok" grok-4.3 "1000000 30000 970000 effort:low"
rigCase grok "$rigGrok" grok-4.7 "500000 65536 434464 effort:low"
rigScaleway="$( rigTable AgentsScalewayHarness.sh )"
rigCase scaleway "$rigScaleway" deepseek-v4-flash-0731 "256000 32768 223232 effort:low"
rigCase scaleway "$rigScaleway" gemma-3-27b-it         "40000 8192 31808 omit"
rigStandard="$( rigTable AgentsStandardV1Harness.sh )"
rigCase standard-v1 "$rigStandard" qwen3-4b          "32768 4096 28672 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3.5-9b-q8_0   "262144 32768 229376 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3.8-27b-q8_0  "262144 131072 131072 thinking:disabled"
rigLocal="$( rigTable AgentsLocalHarness.sh )"
rigCase local "$rigLocal" qwen3.5-9b-q8_0             "262144 32768 229376 thinking:disabled"
rigCase local "$rigLocal" qwen3.8-27b-q8_0            "262144 131072 131072 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3:8b          "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" Qwen3_14B-Instruct "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3-14b         "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3-32b         "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" gemma3:4b         "131072 4096 126976 omit"
rigCase standard-v1 "$rigStandard" gemma3:12b        "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" gemma-3-27b-it    "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" deepseek-r1:14b   "131072 16384 114688 thinking:disabled"
rigCase standard-v1 "$rigStandard" deepseek-r1       "131072 32768 98304 thinking:disabled"
rigCase standard-v1 "$rigStandard" llama3.1:8b       "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" Llama-3.3-70B     "131072 8192 122880 omit"
rigAssert "every wrapper states a table" "$( for rigOne in "$rigClaude" "$rigCopilot" "$rigDeepseek" "$rigGrok" "$rigScaleway" "$rigStandard" ; do [ -n "$rigOne" ] && printf y || printf n ; done )" yyyyyy

echo "-- 2. the preset's size, and the operator's --"
for rigWrapper in claude:claude-opus-5-5:1000000:128000 copilot:gpt-5.6-sol:272000:32768 deepseek:deepseek-flash:1048576:32768 grok:grok-4.3:1000000:30000 scaleway:gemma-3-27b-it:40000:8192 standard-v1:qwen3-8b:32768:8192 ; do
	IFS=: read -r rigName rigModel rigWindow rigOutput <<< "$rigWrapper"
	case "$rigName" in claude) rigT="$rigClaude" ;; copilot) rigT="$rigCopilot" ;; deepseek) rigT="$rigDeepseek" ;; grok) rigT="$rigGrok" ;; scaleway) rigT="$rigScaleway" ;; *) rigT="$rigStandard" ;; esac
	rigAssert "$rigName: the preset's 50000 is the threshold, the family's window and output stay" "$( rigJudge "$rigT" "$rigModel" PRESET_CONTEXT_MAX_SIZE=50000 | LC_ALL=C awk '{ print $1, $2, $3 }' )" "$rigWindow $rigOutput 50000"
	rigAssert "$rigName: the operator's 40000 stands ahead of the preset's" "$( rigJudge "$rigT" "$rigModel" PRESET_CONTEXT_MAX_SIZE=50000 MDAT_HARNESS_CONTEXT_TOKENS=40000 | LC_ALL=C awk '{ print $3 }' )" 40000
done

echo "-- 3. a model of no family is refused, with the families listed --"
for rigName in claude copilot deepseek grok scaleway standard-v1 ; do
	case "$rigName" in claude) rigT="$rigClaude" ;; copilot) rigT="$rigCopilot" ;; deepseek) rigT="$rigDeepseek" ;; grok) rigT="$rigGrok" ;; scaleway) rigT="$rigScaleway" ;; *) rigT="$rigStandard" ;; esac
	rigOut="$( rigJudge "$rigT" mystery-model-9 )"
	rigFirst="$( printf '%s\n' "$rigT" | LC_ALL=C awk -F'|' 'NR == 1 { print $1 }' )"
	rigRefusal="no: $rigOut"
	case "$rigOut" in
		REFUSED*mystery-model-9*"$rigFirst"*) rigRefusal=yes ;;
	esac
	rigAssert "$rigName: refused, naming the model and the first family" "$rigRefusal" yes
done
rigAssert "the preset's size does not make a model of no family known" "$( rigJudge "$rigClaude" mystery-model-9 PRESET_CONTEXT_MAX_SIZE=50000 | LC_ALL=C cut -c1-7 )" REFUSED

echo "-- 4. a leg with no table --"
rigAssert "it keeps the pair it declares, and its threshold is the window less the output" "$( ( unset HARNESS_MODEL_TABLE PRESET_CONTEXT_MAX_SIZE MDAT_HARNESS_CONTEXT_TOKENS ; . "$rigLimits" ; AgentsHarnessLimitsResolve anything-1 128000 16384 && printf '%s %s %s' "$harnessWindowTokens" "$harnessOutputTokens" "$harnessContextTokens" ) )" "128000 16384 111616"

echo "-- 5. the effort --"
rigAssert "unset sends nothing"                       "$( rigEffort effort:none unset )"        "[] [] [effort unset, the model's default]"
rigAssert "low is low"                                "$( rigEffort effort:none low )"          "[low] [] [effort low]"
rigAssert "high is high"                              "$( rigEffort effort:none high )"         "[high] [] [effort high]"
rigAssert "normal is medium"                          "$( rigEffort effort:none normal )"       "[medium] [] [effort normal, sent as medium]"
rigAssert "none of a family that has none: its none"  "$( rigEffort effort:none none )"         "[none] [] [effort none, sent as none]"
rigAssert "none of a family with no none: its lowest, said so"  "$( rigEffort effort:low none )"  "[low] [] [effort none, sent as low: this service has no none, so its lowest]"
rigAssert "none of a family that switches thinking off"  "$( rigEffort thinking:disabled none )"  "[] [1] [effort none, the thinking is off]"
rigAssert "none of a model that does not reason: nothing sent"  "$( rigEffort omit none )"     "[] [] [effort none, nothing to send: this model does not reason]"

if [ "$rigFailCount" -gt 0 ] ; then
	printf '⛔ HARNESS MODEL LIMITS CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'HARNESS_MODEL_LIMITS: OK (%d assertions, offline)\n' "$rigPassCount"
