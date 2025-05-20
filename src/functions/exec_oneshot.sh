# Required to execute command from 'exec-oneshot' config key
exec_oneshot(){
  export_focus_envvars

  # Execute command from 'exec-oneshot' key if it has been specified and was not executed before
  if [[ -n "${config_key_exec_oneshot_map["$section"]}" &&
        -z "${is_exec_oneshot_executed_map["$process_pid"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="due to appearance of window with XID $window_xid of process '$process_name' with PID $process_pid" \
      passed_event_type='oneshot' \
      exec_on_event
    done <<< "${config_key_exec_oneshot_map["$section"]}"

    is_exec_oneshot_executed_map["$process_pid"]='1'
  fi
  
  # Unset exported variables
  unset_focus_envvars
}
