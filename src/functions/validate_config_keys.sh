# Required to validate config keys
validate_config_keys(){
  # Check values in sections and exit with an error if something is wrong or set default values in some keys if those are not specified
  local local_temp_section
  for local_temp_section in "${sections_array[@]}"; do
    # Exit with an error if neither identifier 'name' nor 'command' is specified
    if [[ -z "${config_key_name_map["$local_temp_section"]}" &&
          -z "${config_key_command_map["$local_temp_section"]}" ]]; then
      message --warning "At least one process identifier required in section '$local_temp_section'!"
      parse_config_error='1'
    fi

    # Exit with an error if MangoHud FPS limit is not specified along with config path
    if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" &&
          -z "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
      message --warning "Value ${config_key_fps_unfocus_map["$local_temp_section"]} in 'fps-unfocus' key in section '$local_temp_section' is specified without 'mangohud-config' key!"
      parse_config_error='1'
    fi

    # Exit with an error if MangoHud FPS limit is specified along with CPU limit
    if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" &&
          -n "${config_key_cpu_limit_map["$local_temp_section"]}" &&
          "${config_key_cpu_limit_map["$local_temp_section"]}" != '100' ]]; then
      message --warning "Do not use FPS limit along with CPU limit in section '$local_temp_section'!"
      parse_config_error='1'
    fi

    # Exit with an error if 'fps-focus' is specified without 'fps-unfocus'
    if [[ -n "${config_key_fps_focus_map["$local_temp_section"]}" &&
          -z "${config_key_fps_unfocus_map["$local_temp_section"]}" ]]; then
      message --warning "Do not use 'fps-focus' key without 'fps-unfocus' key in section '$local_temp_section'!"
      parse_config_error='1'
    fi

    # Exit with an error if 'mangohud-config' is specified without 'fps-unfocus'
    if [[ -n "${config_key_mangohud_config_map["$local_temp_section"]}" &&
          -z "${config_key_fps_unfocus_map["$local_temp_section"]}" ]]; then
      message --warning "Do not use 'mangohud-config' key without 'fps-unfocus' key in section '$local_temp_section'!"
      parse_config_error='1'
    fi

    # Exit with an error if 'mangohud-source-config' is specified without 'mangohud-config'
    if [[ -n "${config_key_mangohud_source_config_map["$local_temp_section"]}" &&
          -z "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
      message --warning "Do not use 'mangohud-source-config' key without 'mangohud-config' key in section '$local_temp_section'!"
      parse_config_error='1'
    fi

    # Exit with an error if section contains only identifiers
    if [[ -z "${is_section_useful_map["$local_temp_section"]}" ]]; then
      message --warning "Section '$local_temp_section' contains only identifiers!"
      parse_config_error='1'
    fi

    # Exit with an error if there is another section which matches with the same process
    local local_temp_section2
    local local_match
    for local_temp_section2 in "${sections_array[@]}"; do
      if [[ "$local_temp_section" == "$local_temp_section2" ]]; then
        continue
      fi

      if [[ -z "${config_key_name_map["$local_temp_section2"]}" ||
            -z "${config_key_name_map["$local_temp_section"]}" ||
            "${config_key_name_map["$local_temp_section"]}" == "${config_key_name_map["$local_temp_section2"]}" ]]; then
        (( local_match++ ))
      fi

      if [[ -z "${config_key_owner_map["$local_temp_section2"]}" ||
            -z "${config_key_owner_map["$local_temp_section"]}" ||
            "${config_key_owner_map["$local_temp_section"]}" == "${config_key_owner_map["$local_temp_section2"]}" ]]; then
        (( local_match++ ))
      fi

      if [[ -z "${config_key_command_map["$local_temp_section2"]}" ||
            -z "${config_key_command_map["$local_temp_section"]}" ||
            "${config_key_command_map["$local_temp_section"]}" == "${config_key_command_map["$local_temp_section2"]}" ]]; then
        (( local_match++ ))
      fi

      if (( local_match == 3 )); then
        message --warning "Identifiers in section '$local_temp_section2' are very similar to ones in '$local_temp_section' section!"
        parse_config_error='1'
      fi

      unset local_match
    done

    # Set 'fps-focus' to '0' (full FPS unlock) if it is not specified
    if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" &&
          -z "${config_key_fps_focus_map["$local_temp_section"]}" ]]; then
      config_key_fps_focus_map["$local_temp_section"]='0'
    fi

    # Set CPU limit to '100' (none) if it is not specified
    if [[ -z "${config_key_cpu_limit_map["$local_temp_section"]}" ]]; then
      config_key_cpu_limit_map["$local_temp_section"]='100'
    fi

    # Set 'delay' to '0' if it is not specified
    if [[ -z "${config_key_delay_map["$local_temp_section"]}" ]]; then
      config_key_delay_map["$local_temp_section"]='0'
    fi

    # Set 'mangohud-config' as 'mangohud-source-config' if it is not specified
    if [[ -z "${config_key_mangohud_source_config_map["$local_temp_section"]}" &&
          -n "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
      config_key_mangohud_source_config_map["$local_temp_section"]="${config_key_mangohud_config_map["$local_temp_section"]}"
    fi

    # Request check for ability to change and restore scheduling policies if specified in config
    if [[ -z "$should_validate_sched" &&
          -n "${config_key_idle_map["$local_temp_section"]}" ]]; then
      should_validate_sched='1'
    fi
  done

  if [[ -n "$parse_config_error" ]]; then
    message --error "Unable to continue, fix error(s) displayed above in '$config' config file before start!"
    exit 1
  fi

  unset config
}
