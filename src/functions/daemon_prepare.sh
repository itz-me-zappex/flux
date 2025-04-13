# Required to prepare daemon for event reading
daemon_prepare(){
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
  if check_rw "$(dirname "$lock_file")"; then
    # Store daemon PID to lock file to check its existence on next launch (if lock file still exists, e.g. after crash or SIGKILL)
    echo "$$" > "$lock_file"
  else
    message --error "Unable to create lock file '$(shorten_path "$lock_file")' required to prevent multiple instances!"
    exit 1
  fi

  # Prepare for logging if log file is specified
  if [[ -n "$log" ]]; then
    # Allow logging before start event reading (checked by 'message()')
    allow_logging='1'

    # Remove content from log file if '--log-overwrite' option is specified or create a file if it does not exist
    if [[ -n "$log_overwrite" ||
          ! -f "$log" ]]; then
      echo -n > "$log"
      unset log_overwrite
    fi
  fi

  # Handle color mode with custom prefixes and timestamp
  configure_prefixes

  # Allow notifications if '--notifications' option is specified (checked by 'message()')
  if [[ -n "$notifications" ]]; then
    allow_notifications='1'
    unset notifications
  fi

  # Allow timestamps to be displayed
  if [[ -n "$timestamps" ]]; then
    allow_timestamps='1'
    unset timestamps
  fi

  # Check whether daemon able change and restore scheduling policies
  if [[ -n "$should_validate_sched" ]]; then
    sched_validate
    unset should_validate_sched
  fi
  unset -f sched_validate
  
  # Unset CPU and FPS limits on SIGTERM or SIGINT signals and print message about daemon termination
  trap 'safe_exit ; quiet="" message --info "Flux has been terminated successfully." ; exit 0' SIGTERM SIGINT

  # Ignore user related signals to avoid bash's output when 'background_cpu_limit()' receives those
  trap '' SIGUSR1 SIGUSR2
}
