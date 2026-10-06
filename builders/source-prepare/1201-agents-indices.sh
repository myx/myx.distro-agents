#!/bin/sh
###
### this script is included from builder
###

echo "Build: make agents indices" >&2
DistroAgentsTools.fn.sh --make-agents-indices
