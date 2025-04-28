# Required to unset limit for focused process
handle_focus(){
  # Set end of message to not duplicate it
  local local_end_of_msg="due to focus event of window with XID $window_xid"

  # Define type of limit which should be unset
  if [[ -n "${background_freeze_pid_map["$process_pid"]}" ]]; then
    # Unfreeze process if has been frozen
    passed_process_pid="$process_pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unfreeze_process
  elif [[ -n "${background_cpu_limit_pid_map["$process_pid"]}" ]]; then
    # Unset CPU limit if has been applied
    passed_process_pid="$process_pid" \
    passed_signal='-SIGUSR1' \
    unset_cpu_limit
  elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then
    # Unset FPS limit or update target config
    passed_section="$section" \
    passed_end_of_msg="due to focus event of window with XID $window_xid of process '$process_name' with PID $process_pid" \
    unset_fps_limit
  fi

  # Restore scheduling policy for process if it has been changed to idle
  if [[ -n "${background_sched_idle_pid_map["$process_pid"]}" ]]; then
    passed_process_pid="$process_pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unset_sched_idle
  fi

  # Execute command on focus event if specified in config
  exec_focus

  # Enforce fullscreen mode for window if specified in config
  if [[ -n "${config_key_focus_fullscreen_map["$section"]}" ]]; then
    # Send to background because there is 100ms delay before change child window size to match screen in case window/process did not do that automatically
    (
      if ! "$window_fullscreen_path" "$window_xid" > /dev/null 2>&1; then
        message --warning "Unable to expand to fullscreen window with XID $window_xid of process '$process_name' with PID $process_pid due to focus event!"
      else
        message --info "Window with XID $window_xid of process '$process_name' with PID $process_pid has been expanded into fullscreen due to focus event."
      fi
    ) &
  fi

  # Make window grab cursor if specified in config and that is not implicitly opened window
  if [[ -n "${config_key_focus_cursor_grab_map["$section"]}" &&
        -z "$hot" ]]; then
    # Send to background as that is daemonized process
    "$flux_cursor_grab" "$window_xid" > /dev/null 2>&1 &

    background_focus_cursor_grab_map["$window_xid"]="$!"

    # Print message about successful cursor grabbing if process still exists
    (
      sleep 0.2
      if check_pid_existence "${background_focus_cursor_grab_map["$window_xid"]}"; then
        message --info "Cursor for window with XID $window_xid of process '$process_name' with PID $process_pid has been grabbed due to focus event."
      else
        message --warning "Unable to grab cursor for window with XID $window_xid of process '$process_name' with PID $process_pid due to focus event!"
      fi
    ) &
  fi
}
