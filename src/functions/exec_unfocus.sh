# Required to execute command from 'exec-unfocus' and 'lazy-exec-unfocus' config keys
exec_unfocus(){
  # Set end of message to not duplicate it
  local local_end_of_msg="due to unfocus event of window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid"

  export_unfocus_envvars

  if [[ -n "${config_key_exec_unfocus_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="$local_end_of_msg" \
      passed_event_type='unfocus' \
      exec_on_event
    done <<< "${config_key_exec_unfocus_map["$passed_section"]}"
  fi

  # On next loop after handling implicitly opened windows
  if [[ -n "${config_key_lazy_exec_unfocus_map["$passed_section"]}" &&
        -n "$allow_lazy_commands" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='lazy' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="$local_end_of_msg" \
      passed_event_type='unfocus' \
      exec_on_event
    done <<< "${config_key_lazy_exec_unfocus_map["$passed_section"]}"
  fi
  
  unset_unfocus_envvars
}
