# Required to check groups store values to config keys from them
handle_groups(){
  # Get section name
  local local_temp_section
  for local_temp_section in "${sections_array[@]}"; do
    local local_group="${config_key_group_map["$local_temp_section"]}"
    # Check whether section contains 'group' config key or not
    if section_is_group "$local_group"; then
      # Check whether group exits or not
      local local_temp_section2
      for local_temp_section2 in "${sections_array[@]}"; do
        if [[ "$local_temp_section2" == "$local_group" ]]; then
          local local_group_exists='1'
        fi
      done

      # Print warning and mark as an error if group does not exist
      if [[ -z "$local_group_exists" ]]; then
        message --warning "Group '$local_group' specified in '$local_temp_section' section does not exist!"
        (( parse_config_error_count++ ))
      else
        unset local_group_exists

        # Store values from group to section
        config_key_cpu_limit_map["$local_temp_section"]="${config_key_cpu_limit_map["$local_group"]}"
        config_key_delay_map["$local_temp_section"]="${config_key_delay_map["$local_group"]}"
        config_key_exec_oneshot_map["$local_temp_section"]="${config_key_exec_oneshot_map["$local_group"]}"
        config_key_exec_focus_map["$local_temp_section"]="${config_key_exec_focus_map["$local_group"]}"
        config_key_exec_unfocus_map["$local_temp_section"]="${config_key_exec_unfocus_map["$local_group"]}"
        config_key_lazy_exec_focus_map["$local_temp_section"]="${config_key_lazy_exec_focus_map["$local_group"]}"
        config_key_lazy_exec_unfocus_map["$local_temp_section"]="${config_key_lazy_exec_unfocus_map["$local_group"]}"
        config_key_mangohud_source_config_map["$local_temp_section"]="${config_key_mangohud_source_config_map["$local_group"]}"
        config_key_mangohud_config_map["$local_temp_section"]="${config_key_mangohud_config_map["$local_group"]}"
        config_key_fps_unfocus_map["$local_temp_section"]="${config_key_fps_unfocus_map["$local_group"]}"
        config_key_fps_focus_map["$local_temp_section"]="${config_key_fps_focus_map["$local_group"]}"
        config_key_idle_map["$local_temp_section"]="${config_key_idle_map["$local_group"]}"
        config_key_unfocus_minimize_map["$local_temp_section"]="${config_key_unfocus_minimize_map["$local_group"]}"
        config_key_focus_fullscreen_map["$local_temp_section"]="${config_key_focus_fullscreen_map["$local_group"]}"
        config_key_focus_cursor_grab_map["$local_temp_section"]="${config_key_focus_cursor_grab_map["$local_group"]}"
        config_key_group_map["$local_temp_section"]="${config_key_group_map["$local_group"]}"
      fi
    fi
  done
}
