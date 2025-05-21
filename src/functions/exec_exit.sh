# Required to execute command from 'exec-exit', 'exec-exit-focus' and 'exec-exit-unfocus' config keys
exec_exit(){
  # Return if currently handled window did not match any section
  if [[ -z "$passed_section" ]]; then
    return 0
  fi

  export_unfocus_envvars

  # Execute command from 'exec-exit' key if it has been specified
  if [[ -n "${config_key_exec_exit_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="$passed_end_of_msg" \
      passed_event_type='exit' \
      exec_on_event
    done <<< "${config_key_exec_exit_map["$passed_section"]}"
  fi

  # Execute command from 'exec-exit-focus' key if it has been specified and window is focused
  if [[ "$passed_focused_section" == "$passed_section" &&
        -n "${config_key_exec_exit_focus_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="$passed_end_of_msg" \
      passed_event_type='exit focus' \
      exec_on_event
    done <<< "${config_key_exec_exit_focus_map["$passed_section"]}"
  fi

  # Execute command from 'exec-exit-unfocus' key if it has been specified and window is unfocused
  if [[ "$passed_focused_section" != "$passed_section" && 
        -n "${config_key_exec_exit_unfocus_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      passed_command_type='default' \
      passed_section="$passed_section" \
      passed_event_command="$local_temp_command" \
      passed_end_of_msg="$passed_end_of_msg" \
      passed_event_type='exit unfocus' \
      exec_on_event
    done <<< "${config_key_exec_exit_unfocus_map["$passed_section"]}"
  fi
  
  unset_unfocus_envvars
}
