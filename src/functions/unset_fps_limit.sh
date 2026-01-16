# To terminate FPS limit background process or unset FPS limit
# on focus or closure
unset_fps_limit(){
  local local_background_fps_limit_pid="${background_fps_limit_pid_map["$passed_section"]}"
  local local_unfocus_limits_delay="${config_key_unfocus_limits_delay_map["$passed_section"]}"

  # Check for existence of FPS limit background process
  if [[ "$local_unfocus_limits_delay" != '0' ]] &&
     check_pid_existence "$local_background_fps_limit_pid"; then
    if ! kill "$local_background_fps_limit_pid" > /dev/null 2>&1; then
      message --warning "Unable to cancel delayed for $local_unfocus_limits_delay second(s) FPS unlimiting ($passed_section) $passed_end_of_msg!"
    else
      message --info "Delayed for $local_unfocus_limits_delay second(s) FPS unlimiting ($passed_section) cancelled $passed_end_of_msg."
    fi
  fi

  # Set FPS from 'fps-focus' key
  if passed_section="$passed_section" mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_focus_map["$passed_section"]}"; then
    # Print message depending on FPS limit
    if [[ "${config_key_fps_focus_map["$passed_section"]}" == '0' ]]; then
      local local_shorten_path_result
      shorten_path "${config_key_mangohud_config_map["$passed_section"]}"
      message --info "MangoHud config file ($local_shorten_path_result) ($passed_section) FPS unlimited $passed_end_of_msg."
    elif [[ "${config_key_fps_focus_map["$passed_section"]}" =~ ^[0-9]+$ ]]; then
      local local_shorten_path_result
      shorten_path "${config_key_mangohud_config_map["$passed_section"]}"
      message --info "MangoHud config file ($local_shorten_path_result) ($passed_section) limited to ${config_key_fps_focus_map["$passed_section"]} FPS $passed_end_of_msg."
    else
      local local_shorten_path_result
      shorten_path "${config_key_mangohud_config_map["$passed_section"]}"
      message --info "Config key 'fps_limit' in MangoHud config file ($local_shorten_path_result) ($passed_section) changed to '${config_key_fps_focus_map["$passed_section"]}' $passed_end_of_msg."
    fi
  fi

  unset background_fps_limit_pid_map["$passed_section"]
}
