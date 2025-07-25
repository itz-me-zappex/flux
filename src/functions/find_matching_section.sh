# Required to find matching section for process
find_matching_section(){
  # Find matching section if was not found previously and store it to cache
  if [[ -z "${cache_section_map["$pid"]}" ]]; then
    # Avoid searching for matching section if it was not found previously
    if [[ -z "${cache_mismatch_map["$pid"]}" ]]; then
      # Attempt to find a matching section in config
      local local_temp_section
      local local_match
      for local_temp_section in "${sections_array[@]}"; do
        # Compare process name with specified in section
        if [[ -z "${config_key_name_map["$local_temp_section"]}" ]]; then
          (( local_match++ ))
        else
          if [[ -z "${config_key_regexp_name_map["$local_temp_section"]}" ]]; then
            # Compare process name with specified in config, use soft match if process name is stripped to 15 symbols (16th is '\n' character) and a full name is specified in config
            if [[ "${config_key_name_map["$local_temp_section"]}" == "$process_name" ||
                  "${config_key_name_map["$local_temp_section"]}" == "$process_name"* &&
                  "$process_name" =~ ^.{15}$ &&
                  "${config_key_name_map["$local_temp_section"]}" =~ ^.{16,}$ ]]; then
              (( local_match++ ))
            fi
          else
            # Use regexp to define whether process name matches with one from section or not
            if [[ "$process_name" =~ ${config_key_name_map["$local_temp_section"]} ||
                  "'$process_name'" =~ ${config_key_name_map["$local_temp_section"]} ||
                  "\"$process_name\"" =~ ${config_key_name_map["$local_temp_section"]} ]]; then
              (( local_match++ ))
            fi
          fi
        fi

        # Compare process owner with specified in section
        if [[ -z "${config_key_owner_map["$local_temp_section"]}" ]]; then
          (( local_match++ ))
        else
          if [[ -z "${config_key_regexp_owner_map["$local_temp_section"]}" ]]; then
            if [[ "${config_key_owner_map["$local_temp_section"]}" == "$process_owner" ||
                  "${config_key_owner_map["$local_temp_section"]}" == "$process_owner_username" ]]; then
              (( local_match++ ))
            fi
          else
            if [[ "$process_owner" =~ ${config_key_owner_map["$local_temp_section"]} ||
                  "'$process_owner'" =~ ${config_key_owner_map["$local_temp_section"]} ||
                  "\"$process_owner\"" =~ ${config_key_owner_map["$local_temp_section"]} ||
                  "$process_owner_username" =~ ${config_key_owner_map["$local_temp_section"]} ||
                  "'$process_owner_username'" =~ ${config_key_owner_map["$local_temp_section"]} ||
                  "\"$process_owner_username\"" =~ ${config_key_owner_map["$local_temp_section"]} ]]; then
              (( local_match++ ))
            fi
          fi
        fi

        # Compare process command with specified in section
        if [[ -z "${config_key_command_map["$local_temp_section"]}" ]]; then
          (( local_match++ ))
        else
          if [[ -z "${config_key_regexp_command_map["$local_temp_section"]}" ]]; then
            if [[ "${config_key_command_map["$local_temp_section"]}" == "$process_command" ]]; then
              (( local_match++ ))
            fi
          else
            if [[ "$process_command" =~ ${config_key_command_map["$local_temp_section"]} ||
                  "'$process_command'" =~ ${config_key_command_map["$local_temp_section"]} ||
                  "\"$process_command\"" =~ ${config_key_command_map["$local_temp_section"]} ]]; then
              (( local_match++ ))
            fi
          fi
        fi

        # Mark section as matching if matching section is found
        if (( local_match == 3 )); then
          section="$local_temp_section"
          cache_section_map["$pid"]="$local_temp_section"
          break
        fi

        unset local_match
      done

      # Mark process as mismatched if matching section was not found
      if [[ -z "$section" ]]; then
        cache_mismatch_map["$pid"]='1'
      fi
    fi
  else
    section="${cache_section_map["$pid"]}"
  fi

  if [[ -n "$hot" ]]; then
    local local_window_type_text='opened window'
  else
    local local_window_type_text='focused window'
  fi
  
  if [[ -n "$section" ]]; then
    message --verbose "Process '$process_name' with PID $pid of $local_window_type_text with XID $window_xid matches section '$section'."
  else
    message --verbose "Process '$process_name' with PID $pid of $local_window_type_text with XID $window_xid does not match any section."
    return 1
  fi
}
