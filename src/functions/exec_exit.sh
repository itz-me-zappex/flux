# To execute commands from 'exec-exit', 'exec-exit-focus' and
# 'exec-exit-unfocus' config keys
exec_exit(){
  if [[ -z "$passed_section" ]]; then
    return 0
  fi

  export_unfocus_envvars

  if [[ -n "${config_key_exec_exit_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$passed_section" "$passed_end_of_msg" \
                    'default' 'exit' "$local_temp_command"
    done <<< "${config_key_exec_exit_map["$passed_section"]}"
  fi

  if [[ "$passed_focused_section" == "$passed_section" &&
        -n "${config_key_exec_exit_focus_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$passed_section" "$passed_end_of_msg" \
                    'default' 'exit focus' "$local_temp_command"
    done <<< "${config_key_exec_exit_focus_map["$passed_section"]}"
  fi

  if [[ "$passed_focused_section" != "$passed_section" && 
        -n "${config_key_exec_exit_unfocus_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$passed_section" "$passed_end_of_msg" \
                    'default' 'exit unfocus' "$local_temp_command"
    done <<< "${config_key_exec_exit_unfocus_map["$passed_section"]}"
  fi
  
  unset_envvars
}
