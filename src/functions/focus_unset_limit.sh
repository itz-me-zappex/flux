# Required to unset limit for focused process
focus_unset_limit(){
  # Set end of message to not duplicate it
  local local_end_of_msg="due to window with XID $window_xid focus event"

  # Define type of limit which should be unset
  if [[ -n "${is_freeze_applied_map["$process_pid"]}" ]]; then
    # Unfreeze process if has been frozen
    passed_process_pid="$process_pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unfreeze_process
  elif [[ -n "${is_cpu_limit_applied_map["$process_pid"]}" ]]; then
    # Unset CPU limit if has been applied
    passed_process_pid="$process_pid" \
    passed_process_name="$process_name" \
    passed_signal='-SIGUSR1' \
    unset_cpu_limit
  elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then
    # Unset FPS limit or update target config
    passed_section="$section" \
    passed_end_of_msg="due to window with XID $window_xid focus event of process '$process_name' with PID $process_pid" \
    unset_fps_limit
  fi

  # Restore scheduling policy for process if it has been changed to idle
  if [[ -n "${is_sched_idle_applied_map["$process_pid"]}" ]]; then
    passed_process_pid="$process_pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="$local_end_of_msg" \
    unset_sched_idle
  fi
  
  # Terminate minimization background process
  if [[ -n "${background_minimize_pid_map["$process_pid"]}" ]]; then
    passed_window_xid="$window_xid" \
    passed_process_pid="$process_pid" \
    passed_section="$section" \
    passed_process_name="$process_name" \
    passed_end_of_msg="due to focus event" \
    cancel_minimization
  fi
}
