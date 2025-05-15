# Required to check groups and store values to config keys from them
handle_groups(){
  # Get section name
  local local_temp_section
  for local_temp_section in "${sections_array[@]}"; do
    local local_group="${config_key_group_map["$local_temp_section"]}"

    # Skip if 'group' is not specified
    if [[ -z "$local_group" ]]; then
      continue
    fi

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

        local local_group_key_line="$(get_key_line "$local_temp_section" 'group')"

        # Store values from group to section
        local local_key_line="$(get_key_line "$local_temp_section" 'cpu-limit')"
        if [[ -n "${config_key_cpu_limit_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_cpu_limit_map["$local_temp_section"]="${config_key_cpu_limit_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'delay')"
        if [[ -n "${config_key_delay_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_delay_map["$local_temp_section"]="${config_key_delay_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'exec-oneshot')"
        local local_group_key_value="${config_key_exec_oneshot_map["$local_group"]}"
        local local_key_value="${config_key_exec_oneshot_map["$local_temp_section"]}"
        if [[ -n "$local_group_key_value" ]]; then
          if (( local_key_line == 0 )) ||
             (( local_group_key_line > local_key_line )); then
            if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
              config_key_exec_oneshot_map["$local_temp_section"]+="$local_group_key_value"
            else
              config_key_exec_oneshot_map["$local_temp_section"]="$local_group_key_value"
            fi
          elif (( local_group_key_line < local_key_line )) &&
               [[ "$local_key_value" =~ ^$'\n' ]]; then
            local local_group_key_value+=$'\n'"$local_key_value"
            config_key_exec_oneshot_map["$local_temp_section"]="$local_group_key_value"
          fi
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'exec-focus')"
        local local_group_key_value="${config_key_exec_focus_map["$local_group"]}"
        local local_key_value="${config_key_exec_focus_map["$local_temp_section"]}"
        if [[ -n "$local_group_key_value" ]]; then
          if (( local_key_line == 0 )) ||
             (( local_group_key_line > local_key_line )); then
            if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
              config_key_exec_focus_map["$local_temp_section"]+="$local_group_key_value"
            else
              config_key_exec_focus_map["$local_temp_section"]="$local_group_key_value"
            fi
          elif (( local_group_key_line < local_key_line )) &&
               [[ "$local_key_value" =~ ^$'\n' ]]; then
            local local_group_key_value+=$'\n'"$local_key_value"
            config_key_exec_focus_map["$local_temp_section"]="$local_group_key_value"
          fi
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'exec-unfocus')"
        local local_group_key_value="${config_key_exec_unfocus_map["$local_group"]}"
        local local_key_value="${config_key_exec_unfocus_map["$local_temp_section"]}"
        if [[ -n "$local_group_key_value" ]]; then
          if (( local_key_line == 0 )) ||
             (( local_group_key_line > local_key_line )); then
            if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
              config_key_exec_unfocus_map["$local_temp_section"]+="$local_group_key_value"
            else
              config_key_exec_unfocus_map["$local_temp_section"]="$local_group_key_value"
            fi
          elif (( local_group_key_line < local_key_line )) &&
               [[ "$local_key_value" =~ ^$'\n' ]]; then
            local local_group_key_value+=$'\n'"$local_key_value"
            config_key_exec_unfocus_map["$local_temp_section"]="$local_group_key_value"
          fi
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'lazy-exec-focus')"
        local local_group_key_value="${config_key_lazy_exec_focus_map["$local_group"]}"
        local local_key_value="${config_key_lazy_exec_focus_map["$local_temp_section"]}"
        if [[ -n "$local_group_key_value" ]]; then
          if (( local_key_line == 0 )) ||
             (( local_group_key_line > local_key_line )); then
            if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
              config_key_lazy_exec_focus_map["$local_temp_section"]+="$local_group_key_value"
            else
              config_key_lazy_exec_focus_map["$local_temp_section"]="$local_group_key_value"
            fi
          elif (( local_group_key_line < local_key_line )) &&
               [[ "$local_key_value" =~ ^$'\n' ]]; then
            local local_group_key_value+=$'\n'"$local_key_value"
            config_key_lazy_exec_focus_map["$local_temp_section"]="$local_group_key_value"
          fi
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'lazy-exec-unfocus')"
        local local_group_key_value="${config_key_lazy_exec_unfocus_map["$local_group"]}"
        local local_key_value="${config_key_lazy_exec_unfocus_map["$local_temp_section"]}"
        if [[ -n "$local_group_key_value" ]]; then
          if (( local_key_line == 0 )) ||
             (( local_group_key_line > local_key_line )); then
            if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
              config_key_lazy_exec_unfocus_map["$local_temp_section"]+="$local_group_key_value"
            else
              config_key_lazy_exec_unfocus_map["$local_temp_section"]="$local_group_key_value"
            fi
          elif (( local_group_key_line < local_key_line )) &&
               [[ "$local_key_value" =~ ^$'\n' ]]; then
            local local_group_key_value+=$'\n'"$local_key_value"
            config_key_lazy_exec_unfocus_map["$local_temp_section"]="$local_group_key_value"
          fi
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'mangohud-source-config')"
        if [[ -n "${config_key_mangohud_source_config_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_mangohud_source_config_map["$local_temp_section"]="${config_key_mangohud_source_config_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'mangohud-config')"
        if [[ -n "${config_key_mangohud_config_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_mangohud_config_map["$local_temp_section"]="${config_key_mangohud_config_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'fps-unfocus')"
        if [[ -n "${config_key_fps_unfocus_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_fps_unfocus_map["$local_temp_section"]="${config_key_fps_unfocus_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'fps-focus')"
        if [[ -n "${config_key_fps_focus_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_fps_focus_map["$local_temp_section"]="${config_key_fps_focus_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'idle')"
        if [[ -n "${config_key_idle_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_idle_map["$local_temp_section"]="${config_key_idle_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'unfocus-minimize')"
        if [[ -n "${config_key_unfocus_minimize_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_unfocus_minimize_map["$local_temp_section"]="${config_key_unfocus_minimize_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'focus-fullscreen')"
        if [[ -n "${config_key_focus_fullscreen_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_focus_fullscreen_map["$local_temp_section"]="${config_key_focus_fullscreen_map["$local_group"]}"
        fi

        local local_key_line="$(get_key_line "$local_temp_section" 'focus-cursor-grab')"
        if [[ -n "${config_key_focus_cursor_grab_map["$local_group"]}" ]] &&
           (( local_key_line == 0 )) ||
           (( local_group_key_line > local_key_line )); then
          config_key_focus_cursor_grab_map["$local_temp_section"]="${config_key_focus_cursor_grab_map["$local_group"]}"
        fi

        # Group key specified in section is no longer needed
        unset config_key_group_map["$local_temp_section"]
      fi
    fi
  done
}
