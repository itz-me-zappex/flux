# Required to validate log
validate_log(){
  # Run multiple checks related to logging if '--log' option is specified
  if [[ -n "$log_is_passed" ]]; then
    unset log_is_passed

    # Exit with an error if '--log' option is specified without path to log file
    if [[ -z "$log" ]]; then
      message --error-opt "Option '--log' is specified without path to log file!"
      exit 1
    fi
    
    # Check for critical errors
    if [[ -f "$log" ]] &&
       ! check_rw "$log"; then
      # Exit with an error if specified log file exists but not accessible for read-write operations
      local local_shorten_path_result
      shorten_path "$log"
      message --error "Log file '$local_shorten_path_result' is not accessible for read-write operations!"
      exit 1
    elif [[ -e "$log" &&
            ! -f "$log" ]]; then
      # Exit with an error if path to log exists and that is not a file
      local local_shorten_path_result
      shorten_path "$log"
      message --error "Path '$local_shorten_path_result' specified in '--log' option is expected to be a file!"
      exit 1
    elif [[ -d "${log%/*}" ]] &&
         ! check_rw "${log%/*}"; then
      # Exit with an error if log file directory is not accessible for read-write operations
      local local_shorten_path_result
      shorten_path "$log"
      message --error "Directory of log file '$local_shorten_path_result' is not accessible for read-write operations!"
      exit 1
    fi
  fi
}
