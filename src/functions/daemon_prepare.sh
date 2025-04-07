# Required to prepare daemon for event reading
daemon_prepare(){
  # Exit with an error if lock file and process specified there exists
  if [[ -f "$lock_file" ]] &&
     check_pid_existence "$(<"$lock_file")"; then
    message --error "Multiple instances are not allowed, make sure that daemon is not running before start, if you are really sure, then remove '$(shorten_path "$lock_file")' file."
    exit 1
  else
    # Store PID to lock file to check its existence on next launch (if lock file still exists, e.g. after crash or SIGKILL)
    if ! echo "$$" > "$lock_file"; then
      message --error "Unable to create lock file '$(shorten_path "$lock_file")' required to prevent multiple instances!"
      exit 1
    fi
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
  trap 'safe_exit ; message --info "Flux has been terminated successfully." ; exit 0' SIGTERM SIGINT

  # Ignore user related signals to avoid bash's output when 'background_cpu_limit()' receives those
  trap '' SIGUSR1 SIGUSR2
}
