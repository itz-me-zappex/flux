# To unset applied limits for windows on SIGTERM/SIGINT signal
safe_exit(){
  local local_end_of_msg='because of daemon termination'

  # Get list of all cached windows
  local local_temp_window_xid
  for local_temp_window_xid in "${!cache_pid_map[@]}"; do
    local local_pid="${cache_pid_map["$local_temp_window_xid"]}"
    local local_section="${cache_section_map["$local_pid"]}"
    local local_process_name="${cache_process_name_map["$local_temp_window_xid"]}"
    local local_process_command="${cache_process_command_map["$local_temp_window_xid"]}"
    local local_process_owner="${cache_process_owner_map["$local_temp_window_xid"]}"
    local local_process_owner_username="${cache_process_owner_username_map["$local_temp_window_xid"]}"

    # Define type of limit which should be unset
    if [[ -n "${background_freeze_pid_map["$local_pid"]}" ]]; then
      passed_pid="$local_pid" \
      passed_section="$local_section" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      unfreeze_process
    elif [[ -n "${background_cpu_limit_pid_map["$local_pid"]}" ]]; then
      passed_pid="$local_pid" \
      passed_process_name="$local_process_name" \
      passed_signal='-SIGTERM' \
      unset_cpu_limit
    elif [[ -n "$local_section" &&
            -n "${config_key_mangohud_config_map["$local_section"]}" ]]; then
      passed_section="$local_section" \
      passed_end_of_msg="$local_end_of_msg" \
      unset_fps_limit
    fi

    # Restore scheduling policy for process
    if [[ -n "${background_sched_idle_pid_map["$local_pid"]}" ]]; then
      passed_pid="$local_pid" \
      passed_section="$local_section" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      unset_sched_idle
    fi

    # Cancel cursor grabbing for window
    if [[ -n "${background_focus_grab_cursor_map["$local_temp_window_xid"]}" ]]; then
      passed_window_xid="$local_temp_window_xid"
      passed_pid="$local_pid" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      cursor_ungrab
    fi

    # Unmute process, even if not muted, just in case
    if [[ -n "$local_section" && 
          -n "${config_key_unfocus_mute_map["$local_section"]}" ]]; then
      passed_window_xid="$local_temp_window_xid" \
      passed_process_name="$local_process_name" \
      passed_pid="$local_pid" \
      passed_action='0' \
      passed_action_name='unmute' \
      passed_end_of_msg="$local_end_of_msg" \
      pactl_set_mute &
    fi

    # Execute 'exec-exit', 'exec-exit-focus' and 'exec-exit-unfocus' commands
    # Previous section here is currently focused window matching section
    # It is moved to previous because daemon does that after handling event
    passed_window_xid="$local_temp_window_xid" \
    passed_pid="$local_pid" \
    passed_section="$local_section" \
    passed_process_name="$local_process_name" \
    passed_process_owner="$local_process_owner" \
    passed_process_owner_username="$local_process_owner_username" \
    passed_process_command="$local_process_command" \
    passed_focused_section="$previous_section" \
    passed_end_of_msg="$local_end_of_msg" \
    exec_exit
  done

  # Terminate 'flux-listener'
  if check_pid_existence "$flux_listener_pid"; then
    if ! kill "$flux_listener_pid" > /dev/null 2>&1; then
      message --warning "Unable to terminate 'flux-listener' process!"
    fi
  fi

  # Remove temporary directory
  if [[ -d "$flux_temp_dir_path" ]] &&
     ! rm -rf "$flux_temp_dir_path" > /dev/null 2>&1; then
    local local_shorten_path_result
    shorten_path "$flux_listener_fifo_path"
    message --warning "Unable to remove '$local_shorten_path_result' temporary directory!"
  elif [[ -e "$flux_temp_dir_path" &&
          ! -d "$flux_temp_dir_path" ]]; then
    local local_shorten_path_result
    shorten_path "$flux_listener_fifo_path"
    message --warning "Unable to remove '$local_shorten_path_result', directory is expected!"
  fi
  
  # Wait a bit to avoid printing message about daemon termination
  # earlier than ones from backgrounded functions appear
  sleep 0.1
}
