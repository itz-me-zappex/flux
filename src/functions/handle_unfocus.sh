# Required to set CPU/FPS limits for requested windows
handle_unfocus(){
  # Get focused window XID to avoid false positive in case unfocus actions should not happen before handling of focused window
  local local_focused_window_xid="${focused_window/'='*/}"

  # Remove PIDs from list of existing windows
  local local_temp_window
  for local_temp_window in $opened_windows; do
    local local_window_xids_array+=("${local_temp_window/'='*/}")
  done

  # Apply requested limits to existing windows
  local local_temp_window_xid
  for local_temp_window_xid in "${local_window_xids_array[@]}"; do
    # Skip cycle if info about window is not cached
    if [[ -n "${cache_pid_map["$local_temp_window_xid"]}" ]]; then
      # Simplify access to cached window info
      local local_pid="${cache_pid_map["$local_temp_window_xid"]}"
      local local_section="${cache_section_map["$local_pid"]}"
      local local_process_name="${cache_process_name_map["$local_temp_window_xid"]}"
      local local_process_owner="${cache_process_owner_map["$local_temp_window_xid"]}"
      local local_process_owner_username="${cache_process_owner_username_map["$local_temp_window_xid"]}"
      local local_process_command="${cache_process_command_map["$local_temp_window_xid"]}"

      # Minimize window if requested
      if [[ -n "${request_minimize_map["$local_pid"]}" ]]; then
        unset request_minimize_map["$local_pid"]
        window_minimize &
      fi

      # Return an error if daemon has insufficient rights to apply limit (except FPS limit, that does not require interaction with process)
      if (( UID != 0 &&
            local_process_owner != UID )); then
        # Check for limit requests which are requiring sufficient rights
        if [[ -n "${request_freeze_map["$local_pid"]}" ||
              -n "${request_cpu_limit_map["$local_pid"]}" ||
              -n "${request_sched_idle_map["$local_pid"]}" ]]; then
          # Decline requests
          unset request_freeze_map["$local_pid"] \
          request_cpu_limit_map["$local_pid"] \
          request_fps_limit_map["$local_section"] \
          request_sched_idle_map["$local_pid"]

          message --warning "Daemon has insufficient rights to apply limit for process '$local_process_name' with PID $local_pid on window $local_temp_window_xid unfocus event!"

          return 1
        fi
      fi

      # Check for request existence to apply one of limits
      if [[ -n "${request_freeze_map["$local_pid"]}" ]]; then
        unset request_freeze_map["$local_pid"]

        # Freeze process
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_pid="$local_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_freeze &
        background_freeze_pid_map["$local_pid"]="$!"
      elif [[ -n "${request_cpu_limit_map["$local_pid"]}" ]]; then
        unset request_cpu_limit_map["$local_pid"]

        # Apply CPU limit
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_pid="$local_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_cpu_limit &
        background_cpu_limit_pid_map["$local_pid"]="$!"
      elif [[ -n "$local_section" &&
              -n "${request_fps_limit_map["$local_section"]}" ]]; then
        unset request_fps_limit_map["$local_section"]

        # Set FPS limit
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_pid="$local_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_fps_limit &
        background_fps_limit_pid_map["$local_section"]="$!"
      fi

      # Check for 'SCHED_IDLE' scheduling policy request
      if [[ -n "${request_sched_idle_map["$local_pid"]}" &&
            -n "$sched_change_is_supported" ]]; then
        set_sched_idle
      elif [[ -n "${request_sched_idle_map["$local_pid"]}" &&
              -z "$sched_change_is_supported" ]]; then
        message --warning "Daemon has insufficient rights to restore scheduling policy for process '$local_process_name' with PID $local_pid, changing it to 'idle' on window $local_temp_window_xid unfocus event has been cancelled!"
      fi

      unset request_sched_idle_map["$local_pid"]

      # Cancel cursor grabbing for previously focused window
      if [[ -n "${background_focus_grab_cursor_map["$local_temp_window_xid"]}" &&
            "$local_focused_window_xid" != "$local_temp_window_xid" ]]; then
        passed_window_xid="$local_temp_window_xid" \
        passed_pid="$local_pid" \
        passed_process_name="$local_process_name" \
        passed_end_of_msg="on unfocus event" \
        cursor_ungrab
      fi

      # Mute process
      if [[ -n "${request_mute_map["$local_pid"]}" ]]; then
        unset request_mute_map["$local_pid"]

        passed_window_xid="$local_temp_window_xid" \
        passed_process_name="$local_process_name" \
        passed_pid="$local_pid" \
        passed_action='1' \
        passed_action_name='mute' \
        passed_end_of_msg="on window $local_temp_window_xid unfocus event" \
        pactl_set_mute &
      fi

      # Execute unfocus event command
      if [[ -n "${request_exec_unfocus_general_map["$local_pid"]}" ]]; then
        unset request_exec_unfocus_general_map["$local_pid"]

        passed_window_xid="$local_temp_window_xid" \
        passed_pid="$local_pid" \
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_process_owner="$local_process_owner" \
        passed_process_owner_username="$local_process_owner_username" \
        passed_process_command="$local_process_command" \
        exec_unfocus
      fi
    fi
  done
}
