# Required to prepare daemon for event reading
daemon_prepare(){
  # Prepare for logging if log file is specified
  if [[ -n "$log" ]]; then
    # Allow logging before start event reading (checked by 'message()')
    allow_logging='1'

    # Remove content from log file if '--log-overwrite' option
    # is specified or create a file if it does not exist
    if [[ -n "$log_overwrite" ||
          ! -f "$log" ]]; then
      echo -n > "$log"
      unset log_overwrite
    fi
  fi

  # Allow notifications if '--notifications' option is specified,
  # checked by 'message()'
  if [[ -n "$notifications" ]]; then
    allow_notifications='1'
    unset notifications
  fi

  # Allow timestamps to be displayed, checked by 'message()'
  if [[ -n "$timestamps" ]]; then
    allow_timestamps='1'
    unset timestamps
  fi
  
  # Unset CPU and FPS limits on SIGTERM or SIGINT signals and
  # print message about daemon termination
  trap 'safe_exit;\
        quiet="" message --info "Flux terminated successfully.";\
        message --notification "Flux daemon has been terminated successfully.";\
        exit 0' SIGTERM SIGINT

  # Ignore user related signals to avoid Bash's output when
  # 'background_cpu_limit()' receives those, weird
  trap '' SIGUSR1 SIGUSR2
}
