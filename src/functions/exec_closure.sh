# To execute commands from 'exec-closure' config key
exec_closure(){
  if [[ -z "$passed_section" ]]; then
    return 0
  fi

  export_unfocus_envvars

  if [[ -n "${config_key_exec_closure_map["$passed_section"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$passed_section" \
                    "on window ($passed_window_xid) closure event of process '$passed_process_name' \
                    ($passed_pid)" \
                    'default' 'closure' "$local_temp_command"
    done <<< "${config_key_exec_closure_map["$passed_section"]}"
  fi
  
  unset_envvars
}
