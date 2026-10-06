#!/bin/sh
###
### this script is included from builder
###

echo "Build: make harness indices" >&2
DistroAgentsTools.fn.sh --make-harness-indices
