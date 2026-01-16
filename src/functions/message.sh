# To print messages to console, log and notifications
message(){
  # Get timestamp if that behavior is allowed using '--timestamps' option
  if [[ -n "$allow_timestamps" ]]; then
    local local_current_time='-1'
    local local_timestamp="%($timestamp_format)T %s\n"

    if [[ -n "$log_timestamp_format" ]]; then
      local local_log_timestamp="%($log_timestamp_format)T %s\n"
    fi
  else
    local local_current_time=''
    local local_timestamp="%s%s\n"
    local local_log_timestamp="%s%s\n"
  fi

  # Print message depending on passed option
  case "$1" in
  --error )
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_error $*" >&2
    local local_log_prefix="$log_prefix_error"
  ;;
  --error-opt )
    # Setting '$local_log_prefix' not needed, never logged
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_error $*" >&2
    echo "$prefix_info Try 'flux --help' for more information."
  ;;
  --info )
    shift 1
    if [[ -z "$quiet" ]]; then
      printf "$local_timestamp" "$local_current_time" "$prefix_info $*"
      local local_log_prefix="$log_prefix_info"
    else
      return 0
    fi
  ;;
  --verbose )
    shift 1
    if [[ -n "$verbose" ]]; then
      printf "$local_timestamp" "$local_current_time" "$prefix_verbose $*"
      local local_log_prefix="$log_prefix_verbose"
    else
      return 0
    fi
  ;;
  --warning )
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_warning $*" >&2
    local local_log_prefix="$log_prefix_warning"
  ;;
  --notification )
    if [[ -n "$allow_notifications" ]]; then
      shift 1
      notify-send "$*"
    fi

    # Should not be logged
    return 0
  esac

  if [[ -n "$allow_logging" ]]; then
    hide_stderr
    printf "$local_log_timestamp" "$local_current_time" "$local_log_prefix $*" >> "$log"
    restore_stderr
  fi
}
