# To unset limit for focused process
handle_focus(){
  local local_end_of_msg="on window ($window_xid) focus event"

  # Define type of limit which should be unset
  if [[ -n "${background_freeze_pid_map["$pid"]}" ]]; then
    passed_pid="$pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unfreeze_process
  elif [[ -n "${background_cpu_limit_pid_map["$pid"]}" ]]; then
    passed_pid="$pid" \
    passed_signal='-SIGUSR1' \
    unset_cpu_limit
  elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then
    passed_section="$section" \
    passed_end_of_msg="on window ($window_xid) focus event of process '$process_name' ($pid)" \
    unset_fps_limit
  fi

  # Restore scheduling policy for process
  if [[ -n "${background_sched_idle_pid_map["$pid"]}" ]]; then
    passed_pid="$pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unset_sched_idle
  fi

  # Enforce fullscreen mode for window
  if [[ -n "${config_key_focus_fullscreen_map["$section"]}" ]]; then
    window_fullscreen &
  fi

  # Run subprocess which binds cursor to window if window
  # is explicitly opened
  if [[ -n "${config_key_focus_grab_cursor_map["$section"]}" &&
        -z "$hot" ]]; then
    passed_window_xid="$window_xid" \
    passed_process_name="$process_name" \
    passed_pid="$pid" \
    background_grab_cursor &
    background_focus_grab_cursor_map["$window_xid"]="$!"
  fi

  # Unmute process, even if not muted, just in case
  if [[ -n "${config_key_unfocus_mute_map["$section"]}" ]]; then
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
