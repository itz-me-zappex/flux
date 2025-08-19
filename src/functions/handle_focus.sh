# Required to unset limit for focused process
handle_focus(){
  local local_end_of_msg="because of focus event of window with XID $window_xid"

  # Define type of limit which should be unset
  if [[ -n "${background_freeze_pid_map["$pid"]}" ]]; then
    # Unfreeze process if has been frozen
    passed_pid="$pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unfreeze_process
  elif [[ -n "${background_cpu_limit_pid_map["$pid"]}" ]]; then
    # Unset CPU limit if has been applied
    passed_pid="$pid" \
    passed_signal='-SIGUSR1' \
    unset_cpu_limit
  elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then
    # Unset FPS limit or update target config
    passed_section="$section" \
    passed_end_of_msg="because of focus event of window with XID $window_xid of process '$process_name' with PID $pid" \
    unset_fps_limit
  fi

  # Restore scheduling policy for process if it has been changed to idle
  if [[ -n "${background_sched_idle_pid_map["$pid"]}" ]]; then
    passed_pid="$pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unset_sched_idle
  fi

  # Enforce fullscreen mode for window if specified in config
  if [[ -n "${config_key_focus_fullscreen_map["$section"]}" ]]; then
    window_fullscreen &
  fi

  # Run subprocess which pins cursor to window if specified in config and that is not implicitly opened window
  if [[ -n "${config_key_focus_grab_cursor_map["$section"]}" &&
        -z "$hot" ]]; then
    passed_window_xid="$window_xid" \
    passed_process_name="$process_name" \
    passed_pid="$pid" \
    background_grab_cursor &
    background_focus_grab_cursor_map["$window_xid"]="$!"
  fi

  # Unmute process, even if it is not muted, just in case
  if [[ -n "${config_key_mute_map["$section"]}" ]]; then
    passed_window_xid="$window_xid" \
    passed_process_name="$process_name" \
    passed_pid="$pid" \
    passed_action='0' \
    passed_action_name='unmute' \
    passed_end_of_msg="$local_end_of_msg" \
    pactl_set_mute &
  fi

  exec_oneshot

  exec_focus
}
