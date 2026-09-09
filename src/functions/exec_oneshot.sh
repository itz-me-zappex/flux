# To execute commands from 'exec-oneshot' config key
exec_oneshot(){
  export_focus_envvars

  if [[ -n "${config_key_exec_oneshot_map["$section"]}" &&
        -z "${is_exec_oneshot_executed_map["$pid"]}" ]]; then
    local local_temp_command
    while read -r local_temp_command ||
          [[ -n "$local_temp_command" ]]; do
      exec_on_event "$section" \
                    "on window ($window_xid) appearance event of process '$process_name' ($pid)" \
                    'default' 'oneshot' "$local_temp_command"
    done <<< "${config_key_exec_oneshot_map["$section"]}"

    is_exec_oneshot_executed_map["$pid"]='1'
  fi

  unset_envvars
}
