# Required to execute command from 'exec-focus' and 'lazy-exec-focus' config keys
exec_focus(){
  # Set end of message to not duplicate it
  local local_end_of_msg="due to window with XID $window_xid focus event"

  # Do not do anything if focused window process PID is exacly the same as previous one
  if (( process_pid != previous_process_pid )); then
    # Export environment variables to interact with those using commands/scripts in 'exec-focus' and 'lazy-exec-focus' config keys
    export FLUX_WINDOW_XID="$window_xid" \
    FLUX_PROCESS_PID="$process_pid" \
    FLUX_PROCESS_NAME="$process_name" \
    FLUX_PROCESS_OWNER="$process_owner" \
    FLUX_PROCESS_OWNER_USERNAME="$process_owner_username" \
    FLUX_PROCESS_COMMAND="$process_command" \
    FLUX_PREV_WINDOW_XID="$previous_window_xid" \
    FLUX_PREV_PROCESS_PID="$previous_process_pid" \
    FLUX_PREV_PROCESS_NAME="$previous_process_name" \
    FLUX_PREV_PROCESS_OWNER="$previous_process_owner" \
    FLUX_PREV_PROCESS_OWNER_USERNAME="$previous_process_owner_username" \
    FLUX_PREV_PROCESS_COMMAND="$previous_process_command"

    # Execute command from 'exec-oneshot' key if it has been specified and was not executed before
    if [[ -n "${config_key_exec_oneshot_map["$section"]}" &&
          -z "${is_exec_oneshot_executed_map["$process_pid"]}" ]]; then
      passed_command_type='default' \
      passed_section="$section" \
      passed_event_command="${config_key_exec_oneshot_map["$section"]}" \
      passed_end_of_msg="due to window with XID $window_xid appearance" \
      exec_on_event

      is_exec_oneshot_executed_map["$process_pid"]='1'
    fi

    # Execute command from 'exec-focus' key if it has been specified
    if [[ -n "${config_key_exec_focus_map["$section"]}" ]]; then
      passed_command_type='default' \
      passed_section="$section" \
      passed_event_command="${config_key_exec_focus_map["$section"]}" \
      passed_end_of_msg="$local_end_of_msg" \
      exec_on_event
    fi

    # Execute command from 'lazy-exec-focus' key if it has been specified and if '--hot' has been unset by daemon after processing opened windows
    if [[ -n "${config_key_lazy_exec_focus_map["$section"]}" &&
          -z "$hot" ]]; then
      passed_command_type='lazy' \
      passed_section="$section" \
      passed_event_command="${config_key_lazy_exec_focus_map["$section"]}" \
      passed_end_of_msg="$local_end_of_msg" \
      exec_on_event
    fi
    
    # Unset exported variables
    unset FLUX_WINDOW_XID \
    FLUX_PROCESS_PID \
    FLUX_PROCESS_NAME \
    FLUX_PROCESS_OWNER \
    FLUX_PROCESS_OWNER_USERNAME \
    FLUX_PROCESS_COMMAND \
    FLUX_PREV_WINDOW_XID \
    FLUX_PREV_PROCESS_PID \
    FLUX_PREV_PROCESS_NAME \
    FLUX_PREV_PROCESS_OWNER \
    FLUX_PREV_PROCESS_OWNER_USERNAME \
    FLUX_PREV_PROCESS_COMMAND
  fi
}
