# Required to unset applied limits for windows on SIGTERM/SIGINT signal
safe_exit(){
  # Specify end of message passed to functions
  local local_end_of_msg='due to daemon termination'

  # Get list of all cached windows
  local local_temp_window_xid
  for local_temp_window_xid in "${!cache_process_pid_map[@]}"; do
    # Simplify access to cached process info
    local local_process_pid="${cache_process_pid_map["$local_temp_window_xid"]}"
    local local_section="${cache_section_map["$local_process_pid"]}"
    local local_process_name="${cache_process_name_map["$local_temp_window_xid"]}"
    local local_process_command="${cache_process_command_map["$local_temp_window_xid"]}"
    local local_process_owner="${cache_process_owner_map["$local_temp_window_xid"]}"
    local local_process_owner_username="${cache_process_owner_username_map["$local_temp_window_xid"]}"

    # Define type of limit which should be unset
    if [[ -n "${background_freeze_pid_map["$local_process_pid"]}" ]]; then
      # Unfreeze process if has been frozen
      passed_process_pid="$local_process_pid" \
      passed_section="$local_section" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      unfreeze_process
    elif [[ -n "${background_cpu_limit_pid_map["$local_process_pid"]}" ]]; then
      # Unset CPU limit if has been applied
      passed_process_pid="$local_process_pid" \
      passed_process_name="$local_process_name" \
      passed_signal='-SIGTERM' \
      unset_cpu_limit
    elif [[ -n "$local_section" &&
            -n "${config_key_mangohud_config_map["$local_section"]}" ]]; then
      # Unset FPS limit
      passed_section="$local_section" \
      passed_end_of_msg="$local_end_of_msg" \
      unset_fps_limit
    fi

    # Restore scheduling policy for process if it has been changed to idle
    if [[ -n "${background_sched_idle_pid_map["$local_process_pid"]}" ]]; then
      passed_process_pid="$local_process_pid" \
      passed_section="$local_section" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      unset_sched_idle
    fi

    # Cancel cursor grabbing for window
    if [[ -n "${background_focus_grab_cursor_map["$local_temp_window_xid"]}" ]]; then
      passed_window_xid="$local_temp_window_xid"
      passed_process_pid="$local_process_pid" \
      passed_process_name="$local_process_name" \
      passed_end_of_msg="$local_end_of_msg" \
      cursor_ungrab
    fi

    # Execute commands from 'exec-exit', 'exec-exit-focus' and 'exec-exit-unfocus' if possible
    # Previous section here is matching section for focused window
    # It just moved to previous because of end of loop before next event in 'src/main.sh'
    passed_window_xid="$local_temp_window_xid" \
    passed_process_pid="$local_process_pid" \
    passed_section="$local_section" \
    passed_process_name="$local_process_name" \
    passed_process_owner="$local_process_owner" \
    passed_process_owner_username="$local_process_owner_username" \
    passed_process_command="$local_process_command" \
    passed_focused_section="$previous_section" \
    passed_end_of_msg="$local_end_of_msg" \
    exec_exit
  done

  # Obtain 'flux-listener' PID from lock file to terminate it and remove lock file
  if [[ -f "$lock_file" ]]; then
    # Check whether lock file is readable or not
    if check_ro "$lock_file"; then
      # Do not get 'flux-listener' PID from lock file if it is blank
      if [[ -n "$(<"$lock_file")" ]]; then
        # Get 'flux-listener' PID (2nd line)
        local local_temp_flux_lock_line
        local local_lines_count
        while read -r local_temp_flux_lock_line ||
              [[ -n "$local_temp_flux_lock_line" ]]; do
          # Skip first line
          if (( local_lines_count == 0 )); then
            (( local_lines_count++ ))
            continue
          else
            local_flux_listener_pid="$local_temp_flux_lock_line"
            break
          fi
        done < "$lock_file"

        # Terminate 'flux-listener'
        if check_pid_existence "$local_flux_listener_pid"; then
          kill "$local_flux_listener_pid" > /dev/null 2>&1
        fi
      else
        message --warning "Unable to handle '$(shorten_path "$lock_file")' lock file because it is blank!"
      fi
    else
      message --warning "Unable to read '$(shorten_path "$lock_file")' lock file to obtain 'flux-listener' PID!"
    fi

    # Remove lock file which prevents multiple instances of daemon from running
    if ! rm "$lock_file" > /dev/null 2>&1; then
      message --warning "Unable to remove '$(shorten_path "$lock_file")' lock file which normally contains daemon and event reader PIDs and prevents multiple instances from running!"
    fi
  fi
  
  # Wait a bit to avoid printing message about daemon termination earlier than messages from background functions appear
  sleep 0.1
}
