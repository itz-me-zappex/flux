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
  done

  # Execute command from 'lazy-exec-unfocus' if matching section for focused window is found and command is specified
  if [[ -n "$previous_section" &&
        -n "${config_key_lazy_exec_unfocus_map["$previous_section"]}" ]]; then
    # Pass environment variables to interact with them using commands/scripts in 'lazy-exec-unfocus' config key
    # There is no need to pass '$FLUX_NEW_*' because there is no focus event and info about new window respectively
    # And yes, info about focused window becomes previous immediately after processing it, check event handling in 'main.sh'
    FLUX_WINDOW_XID="$previous_window_xid" \
    FLUX_PROCESS_PID="$previous_process_pid" \
    FLUX_PROCESS_NAME="$previous_process_name" \
    FLUX_PROCESS_OWNER="$previous_process_owner" \
    FLUX_PROCESS_COMMAND="$previous_process_command" \
    passed_command_type='lazy' \
    passed_section="$previous_section" \
    passed_event_command="${config_key_lazy_exec_unfocus_map["$previous_section"]}" \
    passed_event="$local_end_of_msg" \
    exec_on_event
  fi

  # Remove lock file which prevents multiple instances of daemon from running
  if [[ -f "$lock_file" ]] &&
     ! rm "$lock_file" > /dev/null 2>&1; then
    message --warning "Unable to remove lock file '$lock_file' which prevents multiple instances from running!"
  fi

  # Terminate 'flux-event-reader'
  if check_pid_existence "$flux_event_reader_pid"; then
    kill "$flux_event_reader_pid" > /dev/null 2>&1
  fi
  
  # Wait a bit to avoid printing message about daemon termination earlier than messages from background functions appear
  sleep 0.1
}
