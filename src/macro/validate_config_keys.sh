# Required to validate config keys
validate_config_keys(){
  # Exit with an error if there is no any section specified
  if [[ -z "${sections_array[*]}" ]]; then
    message --warning "L$config_line_count: Config file does not contain any section!"
    (( parse_config_error_count++ ))
  fi

  # Check values in sections and exit with an error if something is wrong or set default values in some keys if those are not specified
  local local_temp_section_or_group
  for local_temp_section_or_group in "${groups_array[@]}" "${sections_array[@]}"; do
    # Get key lines of ones which will be checked for an errors
    local local_get_key_line_result
    get_key_line "$local_temp_section_or_group"
    local local_section_or_group_line="$local_get_key_line_result"

    local local_get_key_line_result
    get_key_line "$local_temp_section_or_group" 'fps-focus'
    local local_fps_focus_line="$local_get_key_line_result"

    local local_get_key_line_result
    get_key_line "$local_temp_section_or_group" 'fps-unfocus'
    local local_fps_unfocus_line="$local_get_key_line_result"

    local local_get_key_line_result
    get_key_line "$local_temp_section_or_group" 'mangohud-config'
    local local_mangohud_config_line="$local_get_key_line_result"

    local local_get_key_line_result
    get_key_line "$local_temp_section_or_group" 'mangohud-source-config'
    local local_mangohud_source_config_line="$local_get_key_line_result"

    # Define type of section to show in message
    if section_is_group "$local_temp_section_or_group"; then
      local local_section_msg=" in '$local_temp_section_or_group' group"
      local local_section_msg_head='Group'
    else
      local local_section_msg=" in '$local_temp_section_or_group' section"
      local local_section_msg_head='Section'
    fi

    # Exit with an error if section is blank
    if [[ -n "${is_section_blank_map["$local_temp_section_or_group"]}" ]]; then
      message --warning "L$local_section_or_group_line: $local_section_msg_head '$local_temp_section_or_group' is blank!"
      (( parse_config_error_count++ ))
    else
      # Exit with an error if neither identifier 'name' nor 'command' is specified
      if ! section_is_group "$local_temp_section_or_group" &&
         [[ -z "${config_key_name_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_command_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_section_or_group_line: At least one process identifier required$local_section_msg!"
        (( parse_config_error_count++ ))
      fi

      # Exit with an error if section contains only identifiers
      if [[ -z "${is_section_useful_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_section_or_group_line: $local_section_msg_head '$local_temp_section_or_group' is useless because there is no action specified!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if MangoHud FPS limit is not specified along with config path
    if [[ -n "$local_fps_focus_line" ]]; then
      if [[ -n "${config_key_fps_unfocus_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_mangohud_config_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_fps_focus_line: Value ${config_key_fps_unfocus_map["$local_temp_section_or_group"]} in 'fps-unfocus' key$local_section_msg is specified without 'mangohud-config' key!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if MangoHud FPS limit is specified along with CPU limit
    if [[ -n "$local_fps_unfocus_line" ]]; then
      if [[ -n "${config_key_fps_unfocus_map["$local_temp_section_or_group"]}" &&
            -n "${config_key_unfocus_cpu_limit_map["$local_temp_section_or_group"]}" &&
            "${config_key_unfocus_cpu_limit_map["$local_temp_section_or_group"]}" != '100' ]]; then
        message --warning "L$local_fps_unfocus_line: Do not use FPS limit along with CPU limit$local_section_msg!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if 'fps-focus' is specified without 'fps-unfocus'
    if [[ -n "$local_fps_focus_line" ]]; then
      if [[ -n "${config_key_fps_focus_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_fps_unfocus_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_fps_focus_line: Do not use 'fps-focus' key without 'fps-unfocus' key$local_section_msg!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if 'mangohud-config' is specified without 'fps-unfocus'
    if [[ -n "$local_mangohud_config_line" ]]; then
      if [[ -n "${config_key_mangohud_config_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_fps_unfocus_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_mangohud_config_line: Do not use 'mangohud-config' key without 'fps-unfocus' key$local_section_msg!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if 'mangohud-source-config' is specified without 'mangohud-config'
    if [[ -n "$local_mangohud_source_config_line" ]]; then
      if [[ -n "${config_key_mangohud_source_config_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_mangohud_config_map["$local_temp_section_or_group"]}" ]]; then
        message --warning "L$local_mangohud_source_config_line: Do not use 'mangohud-source-config' key without 'mangohud-config' key$local_section_msg!"
        (( parse_config_error_count++ ))
      fi
    fi

    # Exit with an error if there is another section which matches with the same process
    if ! section_is_group "$local_temp_section_or_group"; then
      if [[ -n "${config_key_name_map["$local_temp_section_or_group"]}" ||
            -n "${config_key_owner_map["$local_temp_section_or_group"]}" ||
            -n "${config_key_command_map["$local_temp_section_or_group"]}" ]]; then
        local local_temp_section
        local local_match
        for local_temp_section in "${sections_array[@]}"; do
          if [[ "$local_temp_section_or_group" == "$local_temp_section" ||
                -z "${config_key_name_map["$local_temp_section"]}" &&
                -z "${config_key_owner_map["$local_temp_section"]}" &&
                -z "${config_key_command_map["$local_temp_section"]}" ]]; then
            continue
          fi

          if [[ -z "${config_key_name_map["$local_temp_section"]}" ||
                -z "${config_key_name_map["$local_temp_section_or_group"]}" ||
                "${config_key_name_map["$local_temp_section_or_group"]}" == "${config_key_name_map["$local_temp_section"]}" ]]; then
            (( local_match++ ))
          fi

          if [[ -z "${config_key_owner_map["$local_temp_section"]}" ||
                -z "${config_key_owner_map["$local_temp_section_or_group"]}" ||
                "${config_key_owner_map["$local_temp_section_or_group"]}" == "${config_key_owner_map["$local_temp_section"]}" ]]; then
            (( local_match++ ))
          fi

          if [[ -z "${config_key_command_map["$local_temp_section"]}" ||
                -z "${config_key_command_map["$local_temp_section_or_group"]}" ||
                "${config_key_command_map["$local_temp_section_or_group"]}" == "${config_key_command_map["$local_temp_section"]}" ]]; then
            (( local_match++ ))
          fi

          local local_get_key_line_result
          get_key_line "$local_temp_section"
          local local_section_line_temp="$local_get_key_line_result"

          if (( local_match == 3 )) &&
             (( local_section_line_temp > local_section_or_group_line )); then
            message --warning "L$local_section_line_temp: Identifiers in '$local_temp_section' section are very similar to ones$local_section_msg!"
            (( parse_config_error_count++ ))
          fi

          unset local_match
        done
      fi
    fi

    # Autoset values if not a group
    if ! section_is_group "$local_temp_section_or_group"; then
      # Set 'fps-focus' to '0' (full FPS unlock) if it is not specified
      if [[ -n "${config_key_fps_unfocus_map["$local_temp_section_or_group"]}" &&
            -z "${config_key_fps_focus_map["$local_temp_section_or_group"]}" ]]; then
        config_key_fps_focus_map["$local_temp_section_or_group"]='0'
      fi

      # Set CPU limit to '100' (none) if it is not specified
      if [[ -z "${config_key_unfocus_cpu_limit_map["$local_temp_section_or_group"]}" ]]; then
        config_key_unfocus_cpu_limit_map["$local_temp_section_or_group"]='100'
      fi

      # Set 'delay' to '0' if it is not specified
      if [[ -z "${config_key_limits_delay_map["$local_temp_section_or_group"]}" ]]; then
        config_key_limits_delay_map["$local_temp_section_or_group"]='0'
      fi

      # Set 'mangohud-config' as 'mangohud-source-config' if it is not specified
      if [[ -z "${config_key_mangohud_source_config_map["$local_temp_section_or_group"]}" &&
            -n "${config_key_mangohud_config_map["$local_temp_section_or_group"]}" ]]; then
        config_key_mangohud_source_config_map["$local_temp_section_or_group"]="${config_key_mangohud_config_map["$local_temp_section_or_group"]}"
      fi

      # Inherit `exec-exit` and `exec-closure` from `lazy-exec-unfocus` if not specified
      if [[ -n "${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}" ]]; then
        if [[ -z "${config_key_exec_exit_map["$local_temp_section_or_group"]}" ]]; then
          config_key_exec_exit_map["$local_temp_section_or_group"]="${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}"
        elif [[ -n "${config_key_exec_exit_append_to_default_map["$local_temp_section_or_group"]}" ]]; then
          # Put commands to the end of inherited from 'lazy-exec-unfocus' ones
          local local_content="${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}"
          local local_content+=$'\n'"${config_key_exec_exit_map["$local_temp_section_or_group"]}"
          config_key_exec_exit_map["$local_temp_section_or_group"]="$local_content"
        fi

        if [[ -z "${config_key_exec_closure_map["$local_temp_section_or_group"]}" ]]; then
          config_key_exec_closure_map["$local_temp_section_or_group"]="${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}"
        elif [[ -n "${config_key_exec_closure_append_to_default_map["$local_temp_section_or_group"]}" ]]; then
          # Put commands to the end of inherited from 'lazy-exec-unfocus' ones
          local local_content="${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}"
          local local_content+=$'\n'"${config_key_exec_closure_map["$local_temp_section_or_group"]}"
          config_key_exec_closure_map["$local_temp_section_or_group"]="$local_content"
        fi
      fi

      # Request check for ability to change and restore scheduling policies if specified in config
      if [[ -z "$should_validate_sched" &&
            -n "${config_key_unfocus_sched_idle_map["$local_temp_section_or_group"]}" ]]; then
        should_validate_sched='1'
      fi

      # Request creation of FIFO file for 'flux-grab-cursor' if specified in config
      if [[ -z "$should_create_fifo_for_flux_grab_cursor" &&
            -n "${config_key_focus_grab_cursor_map["$local_temp_section_or_group"]}" ]]; then
        should_create_fifo_for_flux_grab_cursor='1'
      fi
    fi
  done

  if (( parse_config_error_count > 0 )); then
    if (( parse_config_error_count == 1 )); then
      local local_error_msg='1 error'
    else
      local local_error_msg="all $parse_config_error_count errors"
    fi

    local local_shorten_path_result
    shorten_path "$config"
    message --error "Unable to continue, fix $local_error_msg displayed above in '$local_shorten_path_result' config file before start!"
    exit 1
  fi
}
