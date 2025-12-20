# Required to unset groups to avoid false positives due to missing identifiers
unset_groups(){
  local local_temp_group
  for local_temp_group in "${groups_array[@]}"; do
    unset config_key_unfocus_cpu_limit_map["$local_temp_group"] \
    config_key_unfocus_limits_delay_map["$local_temp_group"] \
    config_key_exec_closure_map["$local_temp_group"] \
    config_key_exec_oneshot_map["$local_temp_group"] \
    config_key_exec_focus_map["$local_temp_group"] \
    config_key_exec_unfocus_map["$local_temp_group"] \
    config_key_lazy_exec_focus_map["$local_temp_group"] \
    config_key_lazy_exec_unfocus_map["$local_temp_group"] \
    config_key_mangohud_source_config_map["$local_temp_group"] \
    config_key_mangohud_config_map["$local_temp_group"] \
    config_key_fps_unfocus_map["$local_temp_group"] \
    config_key_fps_focus_map["$local_temp_group"] \
    config_key_unfocus_sched_idle_map["$local_temp_group"] \
    config_key_unfocus_minimize_map["$local_temp_group"] \
    config_key_focus_fullscreen_map["$local_temp_group"] \
    config_key_focus_grab_cursor_map["$local_temp_group"] \
    config_key_group_map["$local_temp_group"] \
    config_key_exec_exit_map["$local_temp_group"] \
    config_key_exec_exit_focus_map["$local_temp_group"] \
    config_key_exec_exit_unfocus_map["$local_temp_group"] \
    config_key_unfocus_mute_map["$local_temp_group"]
  done

  unset groups_array
}
