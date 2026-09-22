# To execute commands from 'exec-closure' config key
exec_closure(){
  local local_window_xid="$1" local_pid="$2" local_section="$3" local_process_name="$4" \
        local_process_owner="$5" local_process_owner_username="$6" local_process_command="$7"

  if [[ -z "$local_section" ]]; then
    return 0
  fi

  export_unfocus_envvars "$local_window_xid" "$local_pid" "$local_process_name" \
                         "$local_process_owner" "$local_process_owner_username" \
                         "$local_process_command"

  if [[ -n "${config_key_exec_closure_map["$local_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$local_section" \
                    "on window ($local_window_xid) closure event of process '$local_process_name' ($local_pid)" \
                    'default' 'closure' "$local_temp_command"
    done <<< "${config_key_exec_closure_map["$local_section"]}"
  fi
  
  unset_envvars
}
