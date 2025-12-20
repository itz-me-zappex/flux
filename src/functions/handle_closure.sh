# Required to unset limits for terminated windows and remove info about them from cache
handle_closure(){
  # Remove PIDs from list of existing windows
  local local_temp_existing_window
  for local_temp_existing_window in $opened_windows; do
    local local_existing_window_xids_array+=("${local_temp_existing_window/'='*/}")
  done

  # Obtain list of terminated window XIDs
  local local_temp_window_xid
  for local_temp_window_xid in "${!cache_pid_map[@]}"; do
    # Add window XID to array with terminated windows if it does not exist in '_NET_CLIENT_LIST_STACKING'
    if [[ " ${local_existing_window_xids_array[*]} " != *" $local_temp_window_xid "* ]]; then
      local local_terminated_window_xids_array+=("$local_temp_window_xid")
    fi
  done

  # Unset limits for terminated windows
  local local_temp_terminated_window_xid
  for local_temp_terminated_window_xid in "${local_terminated_window_xids_array[@]}"; do
    # Skip window XID if info about it does not exist in cache
    if [[ -n "${cache_pid_map["$local_temp_terminated_window_xid"]}" ]]; then
      local local_closure_notify='1'

      local local_terminated_pid="${cache_pid_map["$local_temp_terminated_window_xid"]}"
      local local_terminated_section="${cache_section_map["$local_terminated_pid"]}"
      local local_terminated_process_name="${cache_process_name_map["$local_temp_terminated_window_xid"]}"
      local local_terminated_process_owner="${cache_process_owner_map["$local_temp_terminated_window_xid"]}"
      local local_terminated_process_owner_username="${cache_process_owner_username_map["$local_temp_terminated_window_xid"]}"
      local local_terminated_process_command="${cache_process_command_map["$local_temp_terminated_window_xid"]}"

      # Skip window XID if there is another window of the same process still exists
      local local_temp_cached_window_xid
      for local_temp_cached_window_xid in "${!cache_pid_map[@]}"; do
        if [[ "$local_terminated_pid" == "${cache_pid_map["$local_temp_cached_window_xid"]}" &&
              "$local_temp_cached_window_xid" != "$local_temp_terminated_window_xid" ]]; then
          local local_do_not_handle='1'
          break
        fi
      done

      if [[ -n "$local_do_not_handle" ]]; then
        unset local_do_not_handle

        # Forget info about window
        unset cache_pid_map["$local_temp_terminated_window_xid"] \
        cache_process_name_map["$local_temp_terminated_window_xid"] \
        cache_process_owner_map["$local_temp_terminated_window_xid"] \
        cache_process_command_map["$local_temp_terminated_window_xid"] \
        cache_process_owner_username_map["$local_temp_terminated_window_xid"]

        continue
      fi

      local local_end_of_msg="on window $local_temp_terminated_window_xid closure event"

      # Unset applied limits
      if [[ -n "${background_freeze_pid_map["$local_terminated_pid"]}" ]]; then
        # Unfreeze process if frozen
        passed_pid="$local_terminated_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="$local_end_of_msg" \
        unfreeze_process

        unset local_closure_notify
      elif [[ -n "${background_cpu_limit_pid_map["$local_terminated_pid"]}" ]]; then
        # Unset CPU limit if limited
        passed_pid="$local_terminated_pid" \
        passed_signal='-SIGUSR2' \
        unset_cpu_limit

        unset local_closure_notify
      elif [[ -n "$local_terminated_section" &&
              -n "${background_fps_limit_pid_map["$local_terminated_section"]}" ]]; then
        # Do not remove FPS limit if one of existing windows matches with the same section
        local local_temp_existing_window_xid
        for local_temp_existing_window_xid in "${local_existing_window_xids_array[@]}"; do
          local local_existing_pid="${cache_pid_map["$local_temp_existing_window_xid"]}"

          # Mark to not unset FPS limit if there is another window which matches with same section
          if [[ "${cache_section_map["$local_existing_pid"]}" == "$local_terminated_section" ]]; then
            local local_found='1'
            break
          fi
        done

        # Unset FPS limit if there is no any matching windows except target
        if [[ -z "$local_found" ]]; then
          passed_section="$local_terminated_section" \
          passed_end_of_msg="on window $local_temp_terminated_window_xid closure event of process '$local_terminated_process_name' ($local_terminated_pid)" \
          unset_fps_limit

          unset local_closure_notify
        else
          unset local_found
        fi
      fi

      # Restore scheduling policy if was changed
      if [[ -n "${background_sched_idle_pid_map["$local_terminated_pid"]}" ]]; then
        passed_pid="$local_terminated_pid" \
        passed_section="$local_terminated_section" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="$local_end_of_msg" \
        unset_sched_idle

        unset local_closure_notify
      fi

      # Cancel cursor grabbing for previously focused window
      if [[ -n "${background_focus_grab_cursor_map["$local_temp_terminated_window_xid"]}" ]]; then
        local local_cursor_has_been_ungrabbed='1'

        passed_window_xid="$local_temp_terminated_window_xid" \
        passed_pid="$local_terminated_pid" \
        passed_process_name="$local_terminated_process_name" \
        passed_end_of_msg="on window closure event" \
        cursor_ungrab

        unset local_closure_notify
      fi

      # Execute closure event command
      passed_window_xid="$local_temp_terminated_window_xid" \
      passed_pid="$local_terminated_pid" \
      passed_section="$local_terminated_section" \
      passed_process_name="$local_terminated_process_name" \
      passed_process_owner="$local_terminated_process_owner" \
      passed_process_owner_username="$local_terminated_process_owner_username" \
      passed_process_command="$local_terminated_process_command" \
      exec_closure

      if [[ -n "$local_terminated_section" &&
            -n "${config_key_exec_closure_map["$local_terminated_section"]}" ]]; then
        unset local_closure_notify
      fi

      # Unset limit request
      if [[ -n "${request_freeze_map["$local_terminated_pid"]}" ]]; then
        unset request_freeze_map["$local_terminated_pid"]
        message --verbose "Freezing of process '$local_terminated_process_name' ($local_terminated_pid) has been cancelled on window $local_temp_terminated_window_xid closure event."

        unset local_closure_notify
      elif [[ -n "${request_cpu_limit_map["$local_terminated_pid"]}" ]]; then
        unset request_cpu_limit_map["$local_terminated_pid"]
        message --verbose "CPU limiting of process '$local_terminated_process_name' ($local_terminated_pid) has been cancelled on window $local_temp_terminated_window_xid closure event."

        unset local_closure_notify
      elif [[ -n "$local_terminated_section" &&
              -n "${request_fps_limit_map["$local_terminated_section"]}" ]]; then
        unset request_fps_limit_map["$local_terminated_section"]

        local local_shorten_path_result
        shorten_path "${config_key_mangohud_config_map["$local_terminated_section"]}"
        message --verbose "MangoHud config file '$local_shorten_path_result' FPS limiting from section '$local_terminated_section' has been cancelled on window $local_temp_terminated_window_xid closure event of process '$local_terminated_process_name' ($local_terminated_pid)."

        unset local_closure_notify
      fi

      # Unset 'SCHED_IDLE' request
      if [[ -n "${request_sched_idle_map["$local_terminated_pid"]}" ]]; then
        unset request_sched_idle_map["$local_terminated_pid"]
        message --verbose "Changing scheduling policy to 'idle' for process '$local_terminated_process_name' ($local_terminated_pid) has been cancelled on window $local_temp_terminated_window_xid closure event."

        unset local_closure_notify
      fi

      # Unset window minimization request
      if [[ -n "${request_minimize_map["$local_terminated_pid"]}" ]]; then
        unset request_minimize_map["$local_terminated_pid"]
        message --verbose "Window $local_temp_terminated_window_xid minimization of process '$local_terminated_process_name' ($local_terminated_pid) has been cancelled on window closure event."

        unset local_closure_notify
      fi

      # Unset mute request
      if [[ -n "${request_mute_map["$local_terminated_pid"]}" ]]; then
        unset request_mute_map["$local_terminated_pid"]
        message --verbose "Muting of process '$local_terminated_process_name' ($local_terminated_pid) of window $local_temp_terminated_window_xid has been cancelled on window closure event."

        unset local_closure_notify
      fi

      unset is_exec_oneshot_executed_map["$local_terminated_pid"]
      unset request_exec_unfocus_general_map["$local_terminated_pid"]

      # Remove data related to terminated window from cache
      unset cache_pid_map["$local_temp_terminated_window_xid"] \
      cache_process_name_map["$local_temp_terminated_window_xid"] \
      cache_process_owner_map["$local_temp_terminated_window_xid"] \
      cache_process_command_map["$local_temp_terminated_window_xid"] \
      cache_process_owner_username_map["$local_temp_terminated_window_xid"]

      # Check for windows of the same process PID
      local local_temp_cached_pid
      for local_temp_cached_pid in "${cache_pid_map[@]}"; do
        # Mark to avoid unset of matching section if that is not last window of process
        if (( local_temp_cached_pid == local_terminated_pid )); then
          local local_found='1'
          break
        fi
      done
      
      # Remove matching section associated with PID if there is no other window processes with the same PID
      if [[ -z "$local_found" ]]; then
        unset cache_mismatch_map["$local_terminated_pid"] \
        cache_section_map["$local_terminated_pid"]
      else
        unset local_found
      fi

      # Print message about window closure if it was not before
      if [[ -n "$local_closure_notify" ]]; then
        message --verbose "Window $local_temp_terminated_window_xid of process '$local_terminated_process_name' ($local_terminated_pid) has been closed."
      fi
    fi
  done
}
