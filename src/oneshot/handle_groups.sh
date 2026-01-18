# To check groups and store values to config keys from them
handle_groups(){
  # Get section name
  local local_temp_section_or_group
  for local_temp_section_or_group in "${groups_array[@]}" "${sections_array[@]}"; do
    # Do not handle if section repeats
    if [[ "${sections_array[*]}" =~ "$local_temp_section_or_group".*"$local_temp_section_or_group" ]]; then
      continue
    fi

    # Do not handle if group repeats
    if [[ "${groups_array[*]}" =~ "$local_temp_section_or_group".*"$local_temp_section_or_group" ]]; then
      continue
    fi

    local local_group="${config_key_group_map["$local_temp_section_or_group"]}"

    # Skip if 'group' is not specified or does not begin with '@'
    if [[ -z "$local_group" ]] ||
       ! section_is_group "$local_group"; then
      continue
    fi

    # Check whether group exists or not
    local local_temp_group
    for local_temp_group in "${groups_array[@]}"; do
      if [[ "$local_temp_group" == "$local_group" ]]; then
        local local_group_exists='1'
      fi
    done

    # Print warning and mark as an error if group does not exist
    if [[ -z "$local_group_exists" ]]; then
      if section_is_group "$local_temp_section_or_group"; then
        local local_section_type_msg='group'
      else
        local local_section_type_msg='section'
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'group'
      message --warning "L$local_get_key_line_result: Group '$local_group' specified in '$local_temp_section_or_group' $local_section_type_msg does not exist!"

      (( parse_config_error_count++ ))
    else
      unset local_group_exists

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'group'
      local local_group_key_line="$local_get_key_line_result"

      # Store values from group to section
      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'unfocus-cpu-limit'
      local local_group_key_value="${config_key_unfocus_cpu_limit_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_unfocus_cpu_limit_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'unfocus-limits-delay'
      local local_group_key_value="${config_key_unfocus_limits_delay_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_unfocus_limits_delay_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-exit'
      local local_group_key_value="${config_key_exec_exit_map["$local_group"]}"
      local local_key_value="${config_key_exec_exit_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_exit_append_to_default_map["$local_temp_section_or_group"]='1'
            config_key_exec_exit_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_exit_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          config_key_exec_exit_append_to_default_map["$local_temp_section_or_group"]='1'
          local local_group_key_value+="$local_key_value"
          config_key_exec_exit_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-exit-focus'
      local local_group_key_value="${config_key_exec_exit_focus_map["$local_group"]}"
      local local_key_value="${config_key_exec_exit_focus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_exit_focus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_exit_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_exec_exit_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-exit-unfocus'
      local local_group_key_value="${config_key_exec_exit_unfocus_map["$local_group"]}"
      local local_key_value="${config_key_exec_exit_unfocus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_exit_unfocus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_exit_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_exec_exit_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-closure'
      local local_group_key_value="${config_key_exec_closure_map["$local_group"]}"
      local local_key_value="${config_key_exec_closure_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_closure_append_to_default_map["$local_temp_section_or_group"]='1'
            config_key_exec_closure_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_closure_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          config_key_exec_closure_append_to_default_map["$local_temp_section_or_group"]='1'
          local local_group_key_value+="$local_key_value"
          config_key_exec_closure_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-oneshot'
      local local_group_key_value="${config_key_exec_oneshot_map["$local_group"]}"
      local local_key_value="${config_key_exec_oneshot_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_oneshot_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_oneshot_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_exec_oneshot_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-focus'
      local local_group_key_value="${config_key_exec_focus_map["$local_group"]}"
      local local_key_value="${config_key_exec_focus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_focus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_exec_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'exec-unfocus'
      local local_group_key_value="${config_key_exec_unfocus_map["$local_group"]}"
      local local_key_value="${config_key_exec_unfocus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_exec_unfocus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_exec_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_exec_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'lazy-exec-focus'
      local local_group_key_value="${config_key_lazy_exec_focus_map["$local_group"]}"
      local local_key_value="${config_key_lazy_exec_focus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_lazy_exec_focus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_lazy_exec_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_lazy_exec_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'lazy-exec-unfocus'
      local local_group_key_value="${config_key_lazy_exec_unfocus_map["$local_group"]}"
      local local_key_value="${config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]}"
      if [[ -n "$local_group_key_value" ]]; then
        if (( local_group_key_line > local_get_key_line_result )); then
          if [[ "$local_group_key_value" =~ ^$'\n' ]]; then
            config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]+="$local_group_key_value"
          else
            config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
          fi
        elif (( local_group_key_line < local_get_key_line_result )) &&
             [[ "$local_key_value" =~ ^$'\n' ]]; then
          local local_group_key_value+="$local_key_value"
          config_key_lazy_exec_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
        fi
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'mangohud-source-config'
      local local_group_key_value="${config_key_mangohud_source_config_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_mangohud_source_config_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'mangohud-config'
      local local_group_key_value="${config_key_mangohud_config_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_mangohud_config_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'fps-unfocus'
      local local_group_key_value="${config_key_fps_unfocus_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_fps_unfocus_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'fps-focus'
      local local_group_key_value="${config_key_fps_focus_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_fps_focus_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'unfocus-sched-idle'
      local local_group_key_value="${config_key_unfocus_sched_idle_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_unfocus_sched_idle_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'unfocus-minimize'
      local local_group_key_value="${config_key_unfocus_minimize_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_unfocus_minimize_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'focus-fullscreen'
      local local_group_key_value="${config_key_focus_fullscreen_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_focus_fullscreen_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'focus-grab-cursor'
      local local_group_key_value="${config_key_focus_grab_cursor_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_focus_grab_cursor_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi

      local local_get_key_line_result
      get_key_line "$local_temp_section_or_group" 'unfocus-mute'
      local local_group_key_value="${config_key_unfocus_mute_map["$local_group"]}"
      if [[ -n "$local_group_key_value" ]] &&
         (( local_group_key_line > local_get_key_line_result )); then
        config_key_unfocus_mute_map["$local_temp_section_or_group"]="$local_group_key_value"
      fi
    fi
  done
}
