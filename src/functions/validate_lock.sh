# Required to prevent multiple instances from running
validate_lock(){
  # Handle already existing lock file
  if [[ -f "$lock_file" ]]; then
    # Exit with an error if file is not readable or daemon is already running
    if check_ro "$lock_file"; then
      # Do not read file if it is blank
      if [[ -n "$(<"$lock_file")" ]]; then
        # Open file and get daemon PID
        local local_temp_flux_lock_line
        while read -r local_temp_flux_lock_line ||
              [[ -n "$local_temp_flux_lock_line" ]]; do
          local local_flux_pid="$local_temp_flux_lock_line"
          break
        done < "$lock_file"

        # Exit with an error if daemon already running
        if check_pid_existence "$local_flux_pid"; then
          message --error "Multiple instances are not allowed, make sure that daemon is not running before start, but if you are really sure, then remove '$(shorten_path "$lock_file")' lock file."
          exit 1
        fi
      fi
    else
      message --error "Unable to read '$(shorten_path "$lock_file")' lock file!"
      exit 1
    fi
  fi

  # Exit with an error if lock file exists but not accessible for writing
  if [[ -f "$lock_file" ]] &&
     ! check_rw "$lock_file"; then
    message --error "Unable to overwrite '$(shorten_path "$lock_file")' lock file!"
    exit 1
  fi

  # Exit with an error with lock file directory is not writable
  local local_lock_file_dir="${lock_file%/*}"
  if check_rw "$local_lock_file_dir"; then
    # Store daemon PID to lock file to check its existence on next launch (if lock file still exists, e.g. after crash or SIGKILL)
    echo "$$" > "$lock_file"
  else
    message --error "Unable to create lock file '$(shorten_path "$lock_file")' required to prevent multiple instances because '$(shorten_path "$local_lock_file_dir")' directory is not accessible for read-write operations!"
    exit 1
  fi
}
