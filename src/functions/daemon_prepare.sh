# Required to prepare daemon for event reading
daemon_prepare(){
  # Set specified timestamp format if any and handle ANSI escapes
  if [[ -n "$new_timestamp_format" ]]; then
    timestamp_format="$(echo -e "$new_timestamp_format\033[0m")"
    unset new_timestamp_format
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

  # Set specified prefixes for messages if any
  local local_temp_prefix_type
  for local_temp_prefix_type in error info verbose warning; do
    # Get name of variable with new prefix
    local local_variable_name="new_prefix_$local_temp_prefix_type"

    # Check for existence of value in variable indirectly
    if [[ -n "${!local_variable_name}" ]]; then
      # Replace old prefix with new one and handle ANSI-escapes
      eval "prefix_$local_temp_prefix_type"=\'"$(echo -e "${!local_variable_name}\033[0m")"\'
      unset "new_prefix_$local_temp_prefix_type"
    fi
  done

  # Remove colors from prefixes and timestamp using 'sed' tool, needed for logging
  if [[ -n "$log" ]]; then
    # Prefixes
    local local_temp_prefix_type
    for local_temp_prefix_type in error info verbose warning; do
      # Get variable name
      local local_variable_name="prefix_$local_temp_prefix_type"

      # Get log related variable name
      local local_log_variable_name="log_$local_variable_name"

      # Store value of current variable to log related variable
      eval "$local_log_variable_name"=\'"${!local_variable_name}"\'

      # Define whether daemon should remove colors or not
      if [[ "${!local_log_variable_name}" =~ $'\033'\[[0-9(\;)?]+'m' ]]; then
        # Remove first matching ANSI escape
        eval "$local_log_variable_name"=\'"${!local_log_variable_name//${BASH_REMATCH[0]}/}"\'

        # Remove other ANSI escapes
        while [[ "${!local_log_variable_name}" =~ $'\033'\[[0-9(\;)?]+'m' ]]; do
          eval "$local_log_variable_name"=\'"${!local_log_variable_name//${BASH_REMATCH[0]}/}"\'
        done
      fi
    done

    # Timestamp:
    # Store value of timestamp variable into log related one
    log_timestamp_format="$timestamp_format"

    # Define whether daemon should remove colors or not
    if [[ "$log_timestamp_format" =~ $'\033'\[[0-9(\;)?]+'m' ]]; then
      # Remove first matching ANSI escape
      log_timestamp_format="${log_timestamp_format//${BASH_REMATCH[0]}/}"

      # Remove other ANSI escapes
      while [[ "$log_timestamp_format" =~ $'\033'\[[0-9(\;)?]+'m' ]]; do
        log_timestamp_format="${log_timestamp_format//${BASH_REMATCH[0]}/}"
      done
    fi
  fi

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
