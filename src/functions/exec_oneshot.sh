# Required to execute command from 'exec-oneshot' config key
exec_oneshot(){
  export_focus_envvars

  if [[ -n "${config_key_exec_oneshot_map["$section"]}" &&
        -z "${is_exec_oneshot_executed_map["$pid"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="because of appearance of window with XID $window_xid of process '$process_name' with PID $pid" \
      passed_event_type='oneshot' \
      exec_on_event
    done <<< "${config_key_exec_oneshot_map["$section"]}"

    is_exec_oneshot_executed_map["$pid"]='1'
  fi

  unset_envvars
}
