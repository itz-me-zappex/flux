# Required to set CPU/FPS limits for requested windows
handle_unfocus(){
  # Get list of existing windows
  local local_windows="${event/'windows_list: '/}"

  # Get focused window XID to avoid false positive in case unfocus actions should not happen before handling of focused window
  local local_focused_window_xid="${focused_window/'='*/}"

  # Remove PIDs from list of existing windows
  local local_temp_window
  for local_temp_window in $local_windows; do
    local local_window_xids_array+=("${local_temp_window/'='*/}")
  done

  # Apply requested limits to existing windows
  local local_temp_window_xid
  for local_temp_window_xid in "${local_window_xids_array[@]}"; do
    # Skip cycle if info about window is not cached
    if [[ -n "${cache_process_pid_map["$local_temp_window_xid"]}" ]]; then
      # Simplify access to cached window info
      local local_process_pid="${cache_process_pid_map["$local_temp_window_xid"]}"
      local local_section="${cache_section_map["$local_process_pid"]}"
      local local_process_name="${cache_process_name_map["$local_temp_window_xid"]}"
      local local_process_owner="${cache_process_owner_map["$local_temp_window_xid"]}"
      local local_process_owner_username="${cache_process_owner_username_map["$local_temp_window_xid"]}"
      local local_process_command="${cache_process_command_map["$local_temp_window_xid"]}"

      # Minimize window if requested
      if [[ -n "${request_minimize_map["$local_process_pid"]}" ]]; then
        unset request_minimize_map["$local_process_pid"]
        
        # Minimize window, send to background to avoid slowdown because of external binary execution
        (
          if ! "$window_minimize_path" "$local_temp_window_xid" > /dev/null 2>&1; then
            message --warning "Unable to minimize window with XID $local_temp_window_xid of process '$local_process_name' with PID $local_process_pid due to unfocus event!"
          else
            message --info "Window with XID $local_temp_window_xid of process '$local_process_name' with PID $local_process_pid has been minimized due to unfocus event."
          fi
        ) &
      fi

      # Return an error if daemon has insufficient rights to apply limit (except FPS limit, that does not require interaction with process)
      if (( UID != 0 &&
            local_process_owner != UID )); then
        # Check for limit requests which are requiring sufficient rights
        if [[ -n "${request_freeze_map["$local_process_pid"]}" ||
              -n "${request_cpu_limit_map["$local_process_pid"]}" ||
              -n "${request_sched_idle_map["$local_process_pid"]}" ]]; then
          # Decline requests
          unset request_freeze_map["$local_process_pid"] \
          request_cpu_limit_map["$local_process_pid"] \
          request_fps_limit_map["$local_section"] \
          request_sched_idle_map["$local_process_pid"]

          message --warning "Daemon has insufficient rights to apply limit for process '$local_process_name' with PID $local_process_pid due to unfocus event of window with XID $local_temp_window_xid!"

          return 1
        fi
      fi

      # Check for request existence to apply one of limits
      if [[ -n "${request_freeze_map["$local_process_pid"]}" ]]; then
        unset request_freeze_map["$local_process_pid"]

        # Freeze process
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_process_pid="$local_process_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_freeze &

        # Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
        background_freeze_pid_map["$local_process_pid"]="$!"
      elif [[ -n "${request_cpu_limit_map["$local_process_pid"]}" ]]; then
        unset request_cpu_limit_map["$local_process_pid"]

        # Apply CPU limit
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_process_pid="$local_process_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_cpu_limit &

        # Associate PID of background process with PID of process to interrupt it on focus event
        background_cpu_limit_pid_map["$local_process_pid"]="$!"
      elif [[ -n "$local_section" &&
              -n "${request_fps_limit_map["$local_section"]}" ]]; then
        unset request_fps_limit_map["$local_section"]

        # Set FPS limit
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_process_pid="$local_process_pid" \
        passed_window_xid="$local_temp_window_xid" \
        background_fps_limit &

        # Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
        background_fps_limit_pid_map["$local_section"]="$!"
      fi

      # Check for 'SCHED_IDLE' scheduling policy request
      if [[ -n "${request_sched_idle_map["$local_process_pid"]}" &&
            -n "$sched_change_is_supported" ]]; then
        # Remember scheduling policy and priority before change it
        if ! local local_sched_info="$(chrt --pid "$local_process_pid" 2>/dev/null)"; then
          local local_chrt_error='1'
        fi

        # Skip handling 'chrt' output if it returned an error
        if [[ -z "$local_chrt_error" ]]; then
          # Read output of 'chrt' tool line-by-line and remember scheduling policy with priority of process to restore it on daemon exit or window focus event
          local local_temp_sched_info_line
          while read -r local_temp_sched_info_line ||
                [[ -n "$local_temp_sched_info_line" ]]; do
            # Define associative array which should store value depending by what line contains
            case "$local_temp_sched_info_line" in
            *'scheduling policy'* )
              # Extract scheduling policy name from string and remember it
              sched_previous_policy_map["$local_process_pid"]="${local_temp_sched_info_line/*': '/}"
            ;;
            *'scheduling priority'* )
              # Extract scheduling priority value from string and remember it
              sched_previous_priority_map["$local_process_pid"]="${local_temp_sched_info_line/*': '/}"
            ;;
            *'runtime/deadline/period parameters'* )
              # Extract parameters from string
              local local_deadline_parameters="${local_temp_sched_info_line/*': '/}"
              # Remove slashes and remember 'SCHED_DEADLINE' parameters
              local local_count='0'
              local local_temp_deadline_parameter
              for local_temp_deadline_parameter in ${local_deadline_parameters//'/'/' '}; do
                (( local_count++ ))
                case "$local_count" in
                '1' )
                  sched_previous_runtime_map["$local_process_pid"]="$local_temp_deadline_parameter"
                ;;
                '2' )
                  sched_previous_deadline_map["$local_process_pid"]="$local_temp_deadline_parameter"
                ;;
                '3' )
                  sched_previous_period_map["$local_process_pid"]="$local_temp_deadline_parameter"
                esac
              done
            esac
          done <<< "$local_sched_info"

          # Print warning if daemon unable to change scheduling policy, otherwise - change it to 'SCHED_IDLE' if not set already
          if [[ -z "$sched_realtime_is_supported" &&
                "${sched_previous_policy_map["$local_process_pid"]}" =~ ^('SCHED_RR'|'SCHED_FIFO')$ ]]; then
            message --warning "Daemon has insufficient rights to restore realtime scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to 'idle' due to unfocus event of window with XID $local_temp_window_xid has been cancelled!"
            local local_idle_cancelled='1'
          elif (( UID != 0 )) &&
               [[ "${sched_previous_policy_map["$local_process_pid"]}" == 'SCHED_DEADLINE' ]]; then
            message --warning "Daemon has insufficient rights to restore deadline scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to 'idle' due to unfocus event of window with XID $local_temp_window_xid has been cancelled!"
            local local_idle_cancelled='1'
          elif [[ "${sched_previous_policy_map["$local_process_pid"]}" != 'SCHED_IDLE' ]]; then
            # Change scheduling policy to 'SCHED_IDLE' if not already set
            passed_section="$local_section" \
            passed_process_name="$local_process_name" \
            passed_process_pid="$local_process_pid" \
            passed_window_xid="$local_temp_window_xid" \
            background_sched_idle &

            # Associate PID of background process with PID of process to interrupt it on focus event
            background_sched_idle_pid_map["$local_process_pid"]="$!"
          else
            message --warning "Process '$local_process_name' with PID $local_process_pid already has scheduling policy set to 'idle', changing it due to unfocus event of window with XID $local_temp_window_xid has been cancelled!"
            local local_idle_cancelled='1'
          fi

          # Unset info about scheduling policy if changing it to 'idle' is cancelled
          if [[ -n "$local_idle_cancelled" ]]; then
            unset sched_previous_policy_map["$local_process_pid"] \
            sched_previous_priority_map["$local_process_pid"] \
            sched_previous_runtime_map["$local_process_pid"] \
            sched_previous_deadline_map["$local_process_pid"] \
            sched_previous_period_map["$local_process_pid"]
          fi
        else
          message --warning "Unable to obtain scheduling policy info of process '$local_process_name' with PID $local_process_pid, changing it to 'idle' due to unfocus event of window with XID $local_temp_window_xid has been cancelled!"
        fi
      elif [[ -n "${request_sched_idle_map["$local_process_pid"]}" &&
              -z "$sched_change_is_supported" ]]; then
        message --warning "Daemon has insufficient rights to restore scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to 'idle' due to unfocus event of window with XID $local_temp_window_xid has been cancelled!"
      fi

      unset request_sched_idle_map["$local_process_pid"]
      
      # Execute unfocus event command
      if [[ -n "${request_exec_unfocus_general_map["$local_process_pid"]}" ]]; then
        unset request_exec_unfocus_general_map["$local_process_pid"]

        passed_window_xid="$local_temp_window_xid" \
        passed_process_pid="$local_process_pid" \
        passed_section="$local_section" \
        passed_process_name="$local_process_name" \
        passed_process_owner="$local_process_owner" \
        passed_process_owner_username="$local_process_owner_username" \
        passed_process_command="$local_process_command" \
        exec_unfocus
      fi

      # Cancel cursor grabbing for previously focused window
      if [[ -n "${background_focus_cursor_grab_map["$local_temp_window_xid"]}" &&
            "$local_focused_window_xid" != "$local_temp_window_xid" ]]; then
        passed_window_xid="$local_temp_window_xid" \
        passed_process_pid="$local_process_pid" \
        passed_process_name="$local_process_name" \
        passed_end_of_msg="due to unfocus event" \
        cursor_ungrab
      fi
    fi
  done
}
