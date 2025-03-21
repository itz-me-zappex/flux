# Required to execute command from 'exec-unfocus' and 'lazy-exec-unfocus' config keys
exec_unfocus(){
  # Export environment variables to interact with them using commands/scripts in 'exec-unfocus' and 'lazy-exec-unfocus' config keys
  export FLUX_NEW_WINDOW_XID="$window_xid" \
  FLUX_NEW_PROCESS_PID="$process_pid" \
  FLUX_NEW_PROCESS_NAME="$process_name" \
  FLUX_NEW_PROCESS_OWNER="$process_owner" \
  FLUX_NEW_PROCESS_OWNER_USERNAME="$process_owner_username" \
  FLUX_NEW_PROCESS_COMMAND="$process_command" \
  FLUX_WINDOW_XID="$passed_window_xid" \
  FLUX_PROCESS_PID="$passed_process_pid" \
  FLUX_PROCESS_NAME="$passed_process_name" \
  FLUX_PROCESS_OWNER="$passed_process_owner" \
  FLUX_PROCESS_OWNER_USERNAME="$passed_process_owner_username" \
  FLUX_PROCESS_COMMAND="$passed_process_command"

  # Execute command from 'exec-unfocus' key if it has been specified
  if [[ -n "${config_key_exec_unfocus_map["$passed_section"]}" ]]; then
    passed_command_type='default' \
    passed_section="$passed_section" \
    passed_event_command="${config_key_exec_unfocus_map["$passed_section"]}" \
    passed_end_of_msg="$passed_end_of_msg" \
    exec_on_event
  fi

  # Execute command from 'lazy-exec-unfocus' key if it has been specified and if '--hot' has been unset by daemon after processing opened windows
  if [[ -n "${config_key_lazy_exec_unfocus_map["$passed_section"]}" &&
        -n "$allow_lazy_commands" ]]; then
    passed_command_type='lazy' \
    passed_section="$passed_section" \
    passed_event_command="${config_key_lazy_exec_unfocus_map["$passed_section"]}" \
    passed_end_of_msg="$passed_end_of_msg" \
    exec_on_event
  fi
  
  # Unset exported variables
  unset FLUX_NEW_WINDOW_XID \
  FLUX_NEW_PROCESS_PID \
  FLUX_NEW_PROCESS_NAME \
  FLUX_NEW_PROCESS_OWNER \
  FLUX_NEW_PROCESS_OWNER_USERNAME \
  FLUX_NEW_PROCESS_COMMAND \
  FLUX_WINDOW_XID \
  FLUX_PROCESS_PID \
  FLUX_PROCESS_NAME \
  FLUX_PROCESS_OWNER \
  FLUX_PROCESS_OWNER_USERNAME \
  FLUX_PROCESS_COMMAND
}
