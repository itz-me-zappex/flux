# Required to prepare daemon for event reading
daemon_prepare(){
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
  unset color_prefix_error \
  color_prefix_info \
  color_prefix_verbose \
  color_prefix_warning \
  color_timestamp_format \
  colorless_prefix_error \
  colorless_prefix_info \
  colorless_prefix_verbose \
  colorless_prefix_warning \
  colorless_timestamp_format

  # Allow notifications if '--notifications' option is specified, checked by 'message()'
  if [[ -n "$notifications" ]]; then
    allow_notifications='1'
    unset notifications
  fi

  # Allow timestamps to be displayed, checked by 'message()'
  if [[ -n "$timestamps" ]]; then
    allow_timestamps='1'
    unset timestamps
  fi

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
