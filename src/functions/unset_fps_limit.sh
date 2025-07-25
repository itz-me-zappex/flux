# Required to terminate FPS limit background process or unset FPS limit if window becomes focused or terminated
unset_fps_limit(){
  local local_background_fps_limit_pid="${background_fps_limit_pid_map["$passed_section"]}"
  local local_config_delay="${config_key_delay_map["$passed_section"]}"

  # Check for existence of FPS limit background process
  if [[ "$local_config_delay" != '0' ]] &&
     check_pid_existence "$local_background_fps_limit_pid"; then
    if ! kill "$local_background_fps_limit_pid" > /dev/null 2>&1; then
      message --warning "Unable to cancel delayed for $local_config_delay second(s) FPS unlimiting of section '$passed_section' $passed_end_of_msg!"
    else
      message --info "Delayed for $local_config_delay second(s) FPS unlimiting of section '$passed_section' has been cancelled $passed_end_of_msg."
    fi
  fi

  # Set FPS from 'fps-focus' key
  if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_focus_map["$passed_section"]}"; then
    # Print message depending by FPS limit
    if [[ "${config_key_fps_focus_map["$passed_section"]}" == '0' ]]; then
      message --info "MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' has been FPS unlimited $passed_end_of_msg."
    elif [[ "${config_key_fps_focus_map["$passed_section"]}" =~ ^[0-9]+$ ]]; then
      message --info "MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' has been limited to ${config_key_fps_focus_map["$passed_section"]} FPS $passed_end_of_msg."
    else
      message --info "Config key 'fps_limit' in MangoHud config file '$(shorten_path "${config_key_mangohud_config_map["$passed_section"]}")' from section '$passed_section' has been changed to '${config_key_fps_focus_map["$passed_section"]}' $passed_end_of_msg."
    fi
  fi

  unset background_fps_limit_pid_map["$passed_section"]
}
