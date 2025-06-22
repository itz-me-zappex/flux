# Required to prevent multiple instances from running
validate_lock(){
  # Skip checks if file does not exist
  if [[ -f "$flux_lock_file_path" ]]; then
    # Exit with an error if lock file is not readable
    if ! check_ro "$flux_lock_file_path"; then
      message --error "Unable to read '$(shorten_path "$flux_lock_file_path")' lock file!"
      exit 1
    fi

    # Exit with an error if daemon already running
    local local_pid_from_lock_file="$(<"$flux_lock_file_path")"
    if check_pid_existence "$local_pid_from_lock_file"; then
      local local_process_name_from_lock_file="$(<"/proc/$local_pid_from_lock_file/comm")"
      if [[ "$local_process_name_from_lock_file" == 'flux' ]]; then
        message --error "Multiple instances are not allowed, make sure that daemon is not running before start!"
        exit 1
      fi
    fi

    # Exit with an error if lock file exists but not accessible for writing
    if ! check_rw "$flux_lock_file_path"; then
      message --error "Unable to overwrite '$(shorten_path "$flux_lock_file_path")' lock file!"
      exit 1
    fi
  elif [[ -e "$flux_lock_file_path" &&
          ! -f "$flux_lock_file_path" ]]; then
    message --error "Unable to handle '$(shorten_path "$flux_lock_file_path")', file is expected!"
    exit 1
  fi

  # Exit with an error if lock file directory is not writable
  if check_rw "$flux_temp_dir_path"; then
    # Store daemon PID to lock file to check its existence on next launch (if lock file still exists, e.g. after crash or SIGKILL)
    echo "$$" > "$flux_lock_file_path"
  else
    message --error "Unable to create '$(shorten_path "$flux_lock_file_path")' lock file, '$(shorten_path "$flux_temp_dir_path")' directory is not accessible for read-write operations!"
    exit 1
  fi
}
