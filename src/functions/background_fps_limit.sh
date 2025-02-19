# Required to set specified FPS on unfocus event, runs in background via '&'
background_fps_limit(){
  # Simplify access to delay specified in config
  local local_delay="${config_key_delay_map["$passed_section"]}"

  # Wait before set limit and notify user if delay is specified
  if [[ "$local_delay" != '0' ]]; then
    message --verbose "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' will be FPS limited after $local_delay second(s) due to window $passed_window_id unfocus event."
    sleep "$local_delay"
  fi
  
  # Check for process existence before set FPS limit
  if check_pid_existence "$passed_process_pid"; then
    # Attempt to change 'fps_limit' in specified MangoHud config file
    if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_unfocus_map["$passed_section"]}"; then
      # Define message depending by whether delay is specified or not
      if [[ "$local_delay" == '0' ]]; then
        message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS due to window $passed_window_id unfocus event."
      else
        message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS due to window $passed_window_id unfocus event after $local_delay second(s)."
      fi
    fi
  else
    message --warning "Process matching with section '$passed_section' has been terminated before FPS limiting!"
  fi
}
