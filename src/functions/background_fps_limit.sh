# Required to set specified FPS on unfocus event, runs in background via '&'
background_fps_limit(){
  # Simplify access to delay specified in config
  local local_delay="${config_key_delay_map["$passed_section"]}"

  # Wait before set limit and notify user if delay is specified
  if [[ "$local_delay" != '0' ]]; then
    message --verbose "MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' will be FPS limited after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid."
    sleep "$local_delay"
  fi
  
  # Check for process existence before set FPS limit
  if check_pid_existence "$passed_process_pid"; then
    # Attempt to change 'fps_limit' in specified MangoHud config file
    if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_unfocus_map["$passed_section"]}"; then
      # Define message depending by whether delay is specified or not
      if [[ "$local_delay" == '0' ]]; then
        message --info "MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' has been limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS due to unfocus event of window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid."
      else
        message --info "MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' has been limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' with PID $passed_process_pid of window with XID $passed_window_xid matching with section '$passed_section' has been terminated before FPS limiting!"
  fi
}
