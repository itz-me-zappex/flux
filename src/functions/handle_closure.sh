# Required to unset limits for terminated windows and remove info about them from cache
handle_closure(){
  local local_terminated_window_ids_array \
  local_existing_windows \
  local_existing_window_ids_array \
  local_terminated_process_pid \
  local_terminated_section \
  local_terminated_process_name \
  local_temp_terminated_window_id \
  local_existing_process_pid \
  local_temp_existing_window_id \
  local_found \
  local_temp_existing_window \
  local_end_of_msg \
  local_temp_cached_pid \
  local_temp_window_id \
  local_terminated_process_owner \
  local_terminated_process_owner_username \
  local_terminated_process_command

  # Remove everything including event type name, to obtain list of existing windows
  local_existing_windows="${event/'windows_list: '/}"

  # Remove PIDs from list of existing windows
  for local_temp_existing_window in $local_existing_windows; do
    local_existing_window_ids_array+=("${local_temp_existing_window/'='*/}")
  done

  # Obtain list of terminated windows and remove PIDs
  for local_temp_window_id in "${!cache_process_pid_map[@]}"; do
    # Add window ID to array with terminated windows if it does not exist in '_NET_CLIENT_LIST_STACKING'
    if [[ " ${local_existing_window_ids_array[*]} " != *" $local_temp_window_id "* ]]; then
      local_terminated_window_ids_array+=("$local_temp_window_id")
    fi
  done

  # Unset limits for terminated windows
  for local_temp_terminated_window_id in "${local_terminated_window_ids_array[@]}"; do
    # Skip window ID if info about it does not exist in cache
    if [[ -n "${cache_process_pid_map["$local_temp_terminated_window_id"]}" ]]; then
      # Simplify access to cached info about terminated window
      local_terminated_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}"
      local_terminated_section="${cache_section_map["$local_terminated_process_pid"]}"
      local_terminated_process_name="${cache_process_name_map["$local_temp_terminated_window_id"]}"
      local_terminated_process_owner="${cache_process_owner_map["$local_temp_terminated_window_id"]}"
      local_terminated_process_owner_username="${cache_process_owner_username_map["$local_temp_terminated_window_id"]}"
      local_terminated_process_command="${cache_process_command_map["$local_temp_terminated_window_id"]}"

      # Set end of message with actual window ID to not duplicate it
      local_end_of_msg="due to window $local_temp_window_id closure"

      # Unset applied limits
      if [[ -n "${freeze_applied_map["$local_terminated_process_pid"]}" ]]; then # Unfreeze process if frozen
        passed_process_pid="$local_terminated_process_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="$local_end_of_msg" \
        unfreeze_process
      elif [[ -n "${cpu_limit_applied_map["$local_terminated_process_pid"]}" ]]; then # # Unset CPU limit if limited
        passed_process_pid="$local_terminated_process_pid" \
        passed_process_name="$local_terminated_process_name" \
        passed_signal='-SIGUSR2' \
        unset_cpu_limit
      elif [[ -n "$local_terminated_section" &&
              -n "${fps_limit_applied_map["$local_terminated_section"]}" ]]; then # Unset FPS limit if limited
        # Do not remove FPS limit if one of existing windows matches with the same section
        for local_temp_existing_window_id in "${local_existing_window_ids_array[@]}"; do
          # Simplify access to PID of terminated process using cache
          local_existing_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}"

          # Mark to not unset FPS limit if there is another window which matches with same section
          if [[ "${cache_section_map["$local_existing_process_pid"]}" == "$local_terminated_section" ]]; then
            local_found='1'
            break
          fi
        done

        # Unset FPS limit if there is no any matching windows except target
        if [[ -z "$local_found" ]]; then
          passed_section="$local_terminated_section" \
          passed_end_of_msg="$local_end_of_msg" \
          unset_fps_limit
        else
          unset local_found
        fi
      fi

      # Restore scheduling policy if was changed
      if [[ -n "${sched_idle_applied_map["$local_terminated_process_pid"]}" ]]; then
        passed_process_pid="$local_terminated_process_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="$local_end_of_msg" \
        unset_sched_idle
      fi
      # Terminate background process with minimization
      if [[ -n "${background_minimize_pid_map["$local_terminated_process_pid"]}" ]]; then
        passed_window_id="$local_temp_terminated_window_id" \
        passed_process_pid="$local_terminated_process_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="due to window closure" \
        cancel_minimization
      fi

      # Execute unfocus event command
      if [[ -n "${request_exec_unfocus_general_map["$local_terminated_process_pid"]}" ]]; then
        passed_window_id="$local_temp_terminated_window_id" \
        passed_process_pid="$local_terminated_process_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_process_owner="$local_terminated_process_owner" \
        passed_process_owner_username="$local_terminated_process_owner_username" \
        passed_process_command="$local_terminated_process_command" \
        passed_end_of_msg="$local_end_of_msg" \
        exec_unfocus
      fi

      # Unset limit request
      if [[ -n "${request_freeze_map["$local_terminated_process_pid"]}" ]]; then
        unset request_freeze_map["$local_terminated_process_pid"]
        message --verbose "Freezing of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window $local_temp_terminated_window_id closure."
      elif [[ -n "${request_cpu_limit_map["$local_terminated_process_pid"]}" ]]; then
        unset request_cpu_limit_map["$local_terminated_process_pid"]
        message --verbose "CPU limiting of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window $local_temp_terminated_window_id closure."
      elif [[ -n "$local_terminated_section" &&
              -n "${request_fps_limit_map["$local_terminated_section"]}" ]]; then
        unset request_fps_limit_map["$local_terminated_section"]
        message --verbose "FPS limiting of section '$local_terminated_section' has been cancelled due to window $local_temp_terminated_window_id closure."
      elif [[ -z "${request_sched_idle_map["$local_terminated_process_pid"]}" &&
              -z "${request_minimize_map["$local_terminated_process_pid"]}" ]]; then
        # Print verbose message about window termination if there is no limits specified for it in config file
        message --verbose "Window $local_temp_terminated_window_id of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been terminated."
      fi

      # Unset 'SCHED_IDLE' request
      if [[ -n "${request_sched_idle_map["$local_terminated_process_pid"]}" ]]; then
        unset request_sched_idle_map["$local_terminated_process_pid"]
        message --verbose "Changing scheduling policy to idle for process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window $local_temp_terminated_window_id closure."
      fi

      # Unset window minimization request
      if [[ -n "${request_minimize_map["$local_terminated_process_pid"]}" ]]; then
        message --verbose "Window $local_temp_window_id minimization of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window closure."
      fi

      # Unset unfocus event command execution request
      unset request_exec_unfocus_general_map["$local_terminated_process_pid"]

      # Remove data related to terminated window from cache
      unset cache_process_pid_map["$local_temp_terminated_window_id"] \
      cache_process_name_map["$local_temp_terminated_window_id"] \
      cache_process_owner_map["$local_temp_terminated_window_id"] \
      cache_process_command_map["$local_temp_terminated_window_id"] \
      cache_process_owner_username_map["$local_temp_terminated_window_id"]

      # Check for windows of the same process PID
      for local_temp_cached_pid in "${cache_process_pid_map[@]}"; do
        # Mark to avoid unset of matching section if that is not last window of process
        if [[ "$local_temp_cached_pid" == "$local_terminated_process_pid" ]]; then
          local_found='1'
          break
        fi
      done
      
      # Remove matching section associated with PID if there is no other window processes with the same PID
      if [[ -z "$local_found" ]]; then
        unset cache_mismatch_map["$local_terminated_process_pid"] \
        cache_section_map["$local_terminated_process_pid"]
      else
        unset local_found
      fi
    fi
  done
}
