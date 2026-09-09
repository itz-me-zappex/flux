# To execute commands from 'exec-focus' and 'lazy-exec-focus' config keys
exec_focus(){
  local local_end_of_msg="on window ($window_xid) focus event of process '$process_name' ($pid)"

  if (( pid != previous_pid )); then
    export_focus_envvars

    if [[ -n "${config_key_exec_focus_map["$section"]}" ]]; then
      local local_temp_command
      while read -r local_temp_command ||
            [[ -n "$local_temp_command" ]]; do
        exec_on_event "$section" "$local_end_of_msg" \
                      'default' 'focus' "$local_temp_command"
      done <<< "${config_key_exec_focus_map["$section"]}"
    fi

    # Only after handling implicitly opened windows
    if [[ -n "${config_key_lazy_exec_focus_map["$section"]}" &&
          -z "$hot" ]]; then
      local local_temp_command
      while read -r local_temp_command ||
            [[ -n "$local_temp_command" ]]; do
        exec_on_event "$section" "$local_end_of_msg" \
                      'lazy' 'focus' "$local_temp_command"
      done <<< "${config_key_lazy_exec_focus_map["$section"]}"
    fi
    
    unset_envvars
  fi
}
