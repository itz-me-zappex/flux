# Required to get process info from cache using window XID
cache_get_process_info(){
  process_name="${cache_process_name_map["$passed_window_xid"]}"
  process_owner="${cache_process_owner_map["$passed_window_xid"]}"
  process_command="${cache_process_command_map["$passed_window_xid"]}"
  process_owner_username="${cache_process_owner_username_map["$passed_window_xid"]}"
}

# Required to get process info using PID
get_process_info(){
  # Prefer using cache with process info if exists
  if [[ -n "${cache_pid_map["$window_xid"]}" ]]; then
    passed_window_xid="$window_xid" cache_get_process_info
  else
    # Attempt to find cache with info about the same process
    local local_temp_cached_window_xid
    for local_temp_cached_window_xid in "${!cache_pid_map[@]}"; do
      # Compare parent PID with PID of process
      if (( ${cache_pid_map["$local_temp_cached_window_xid"]} == pid )); then
        # Remember window XID of matching process
        local local_matching_window_xid="$local_temp_cached_window_xid"
        break
      fi
    done

    # Check for match of cached process info to define a way how to obtain it
    if [[ -n "$local_matching_window_xid" ]]; then
      # Get process info using cache
      passed_window_xid="$local_matching_window_xid" cache_get_process_info
    else
      # Get process name
      if ! process_name="$(<"/proc/$pid/comm")"; then
        return 1
      fi

      # Get process command by reading file ignoring '\0' and those are replaced with spaces automatically because of arrays nature :D
      local local_process_command_array
      if ! mapfile -d '' local_process_command_array < "/proc/$pid/cmdline"; then
        return 1
      else
        process_command="${local_process_command_array[*]}"
      fi

      # Bufferize to avoid failure from 'read' in case file will be removed during reading
      local local_status_content
      if ! local_status_content="$(<"/proc/$pid/status")"; then
        return 1
      fi

      # Get effective UID of process
      local local_temp_status_line
      local local_column_count
      local local_temp_status_column
      while read -r local_temp_status_line ||
            [[ -n "$local_temp_status_line" ]]; do
        # Find a line containing UID
        if [[ "$local_temp_status_line" == 'Uid:'* ]]; then
          # Find 3rd column
          for local_temp_status_column in $local_temp_status_line; do
            (( local_column_count++ ))

            # Remember effective UID and break loop
            if (( local_column_count == 3 )); then
              process_owner="$local_temp_status_column"
              break
            fi
          done
        fi
      done <<< "$local_status_content"

      # Obtain process owner username from '/etc/passwd' file using UID of process
      local local_temp_passwd_line
      while read -r local_temp_passwd_line ||
            [[ -n "$local_temp_passwd_line" ]]; do
        # Ignore line if it does not contain owner UID
        if [[ "$local_temp_passwd_line" =~ .*\:.*\:"$process_owner"\:.* ]]; then
          process_owner_username="${local_temp_passwd_line/\:*/}"
          break
        fi
      done < '/etc/passwd'
    fi

    # Store process info to cache to speed up its obtainance on next focus event and to use it implicitly using only window XID
    cache_pid_map["$window_xid"]="$pid"
    cache_process_name_map["$window_xid"]="$process_name"
    cache_process_owner_map["$window_xid"]="$process_owner"
    cache_process_command_map["$window_xid"]="$process_command"
    cache_process_owner_username_map["$window_xid"]="$process_owner_username"
  fi
}
