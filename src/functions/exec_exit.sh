# To execute commands from 'exec-exit', 'exec-exit-focus' and
# 'exec-exit-unfocus' config keys
exec_exit(){
  local local_window_xid="$1" local_pid="$2" local_section="$3" local_process_name="$4" \
        local_process_owner="$5" local_process_owner_username="$6" local_process_command="$7" \
        local_focused_section="$8" local_end_of_msg="$9"

  if [[ -z "$local_section" ]]; then
    return 0
  fi

  export_unfocus_envvars "$local_window_xid" "$local_pid" "$local_process_name" \
                         "$local_process_owner" "$local_process_owner_username" \
                         "$local_process_command"

  if [[ -n "${config_key_exec_exit_map["$local_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" "$local_end_of_msg" \
                    'default' 'exit' "$local_temp_command"
    done <<< "${config_key_exec_exit_map["$local_section"]}"
  fi

  if [[ "$local_focused_section" == "$local_section" &&
        -n "${config_key_exec_exit_focus_map["$local_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" "$local_end_of_msg" \
                    'default' 'exit focus' "$local_temp_command"
    done <<< "${config_key_exec_exit_focus_map["$local_section"]}"
  fi

  if [[ "$local_focused_section" != "$local_section" && 
        -n "${config_key_exec_exit_unfocus_map["$local_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" "$local_end_of_msg" \
                    'default' 'exit unfocus' "$local_temp_command"
    done <<< "${config_key_exec_exit_unfocus_map["$local_section"]}"
  fi
  
  unset_envvars
}
