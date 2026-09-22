# Required to execute command from 'exec-unfocus' and 'lazy-exec-unfocus' config keys
exec_unfocus(){
  local local_window_xid="$1" local_pid="$2" local_section="$3" \
        local_process_name="$4" local_process_owner="$5" local_process_owner_username="$6" \
        local_process_command="$7"

  local local_end_of_msg="on window ($local_window_xid) unfocus event of process '$local_process_name' ($local_pid)"

  export_unfocus_envvars "$local_window_xid" "$local_pid" "$local_process_name" \
                         "$local_process_owner" "$local_process_owner_username" \
                         "$local_process_command"

  if [[ -n "${config_key_exec_unfocus_map["$local_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" "$local_end_of_msg" \
                    'default' 'unfocus' "$local_temp_command"
    done <<< "${config_key_exec_unfocus_map["$local_section"]}"
  fi

  # On next loop after handling implicitly opened windows
  if [[ -n "${config_key_lazy_exec_unfocus_map["$local_section"]}" &&
        -n "$allow_lazy_commands" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" "$local_end_of_msg" \
                    'lazy' 'unfocus' "$local_temp_command"
    done <<< "${config_key_lazy_exec_unfocus_map["$local_section"]}"
  fi
  
  unset_envvars
}
