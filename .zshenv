# Environment variables
. "/etc/profiles/per-user/bjeanes/etc/profile.d/hm-session-vars.sh"

# Only source this once
if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
  export __HM_ZSH_SESS_VARS_SOURCED=1
  export AUTOPAIR_INIT_INHIBIT="1"
export ZVM_INIT_MODE="sourcing"
fi
