# Required to execute command from 'exec-closure' config key
exec_closure(){
  if [[ -z "$passed_section" ]]; then
    return 0
  fi

  export_unfocus_envvars

  if [[ -n "${config_key_exec_closure_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="due to closure of window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid" \
      passed_event_type='closure' \
      exec_on_event
    done <<< "${config_key_exec_closure_map["$passed_section"]}"
  fi
  
  unset_envvars
}
