# Required to set specified FPS on unfocus event, runs in background via '&'
background_fps_limit(){
  local local_limits_delay="${config_key_limits_delay_map["$passed_section"]}"
  local local_mangohud_config="${config_key_mangohud_config_map["$passed_section"]}"
  local local_mangohud_source_config="${config_key_mangohud_source_config_map["$passed_section"]}"
  local local_fps_unfocus="${config_key_fps_unfocus_map["$passed_section"]}"

  if [[ "$local_limits_delay" != '0' ]]; then
    local local_shorten_path_result
    shorten_path "$local_mangohud_config"
    message --verbose "MangoHud config file ($local_shorten_path_result) ($passed_section) will be FPS limited after $local_limits_delay second(s) on window ($passed_window_xid) unfocus event of process '$passed_process_name' ($passed_pid)."
    sleep "$local_limits_delay"
  fi
  
  if check_pid_existence "$passed_pid"; then
    if mangohud_fps_set "$local_mangohud_config" "$local_mangohud_source_config" "$local_fps_unfocus"; then
      if [[ "$local_limits_delay" == '0' ]]; then
        local local_shorten_path_result
        shorten_path "$local_mangohud_config"
        message --info "MangoHud config file ($local_shorten_path_result) ($passed_section) has been limited to $local_fps_unfocus FPS on window ($passed_window_xid) unfocus event of process '$passed_process_name' ($passed_pid)."
      else
        local local_shorten_path_result
        shorten_path "$local_mangohud_config"
        message --info "MangoHud config file ($local_shorten_path_result) ($passed_section) has been limited to $local_fps_unfocus FPS after $local_limits_delay second(s) on window ($passed_window_xid) unfocus event of process '$passed_process_name' ($passed_pid)."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' ($passed_pid) of window ($passed_window_xid) matching with section '$passed_section' has been terminated before FPS limiting!"
  fi
}
