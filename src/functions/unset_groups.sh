# Required to unset groups to avoid false positives due to missing identifiers
unset_groups(){
  local local_temp_section
  for local_temp_section in "${sections_array[@]}"; do
    if section_is_group "$local_temp_section"; then
      unset config_key_cpu_limit_map["$local_temp_section"] \
      config_key_delay_map["$local_temp_section"] \
      config_key_exec_closure_map["$local_temp_section"] \
      config_key_exec_oneshot_map["$local_temp_section"] \
      config_key_exec_focus_map["$local_temp_section"] \
      config_key_exec_unfocus_map["$local_temp_section"] \
      config_key_lazy_exec_focus_map["$local_temp_section"] \
      config_key_lazy_exec_unfocus_map["$local_temp_section"] \
      config_key_mangohud_source_config_map["$local_temp_section"] \
      config_key_mangohud_config_map["$local_temp_section"] \
      config_key_fps_unfocus_map["$local_temp_section"] \
      config_key_fps_focus_map["$local_temp_section"] \
      config_key_idle_map["$local_temp_section"] \
      config_key_unfocus_minimize_map["$local_temp_section"] \
      config_key_focus_fullscreen_map["$local_temp_section"] \
      config_key_focus_cursor_grab_map["$local_temp_section"] \
      config_key_group_map["$local_temp_section"] \
      config_key_exec_exit_map["$local_temp_section"] \
      config_key_exec_exit_focus_map["$local_temp_section"] \
      config_key_exec_exit_unfocus_map["$local_temp_section"]
    else
      local local_sections_array+=("$local_temp_section")
    fi
  done

  sections_array=("${local_sections_array[@]}")
}
