. "$RIG_INCLUDE" || exit 1
DistroAgentsTools(){ printf "start %s\n" "$*" >> "$RIG_CALLS" ; printf "SESSION_ID=rig-session\n" ; return 0 ; }
