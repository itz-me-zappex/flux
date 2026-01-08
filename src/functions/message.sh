# Required to print messages to console, log and notifications
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

  # Print message depending by passed option
  case "$1" in
  --error )
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_error $*" >&2
    local local_log_prefix="$log_prefix_error"
    local local_notification_icon='emblem-error'
  ;;
  --error-opt )
    # Setting '$local_log_prefix' is unneeded because this message will not be logged ever
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_error $*" >&2
    echo "$prefix_info Try 'flux --help' for more information."
  ;;
  --info )
    shift 1
    if [[ -z "$quiet" ]]; then
      printf "$local_timestamp" "$local_current_time" "$prefix_info $*"
      local local_log_prefix="$log_prefix_info"
      local local_notification_icon='emblem-information'
    else
      return 0
    fi
  ;;
  --verbose )
    shift 1
    if [[ -n "$verbose" ]]; then
      printf "$local_timestamp" "$local_current_time" "$prefix_verbose $*"
      local local_log_prefix="$log_prefix_verbose"
      local local_notification_icon='emblem-added'
    else
      return 0
    fi
  ;;
  --warning )
    shift 1
    printf "$local_timestamp" "$local_current_time" "$prefix_warning $*" >&2
    local local_log_prefix="$log_prefix_warning"
    local local_notification_icon='emblem-warning'
  esac

  # Print message with timestamp to log file if responding option is specified and logging has been allowed before event reading
  if [[ -n "$allow_logging" ]]; then
    # All I need is just write log to file
    # Previously check with warning was added
    # But warnings are useless if daemon runs in background
    # And it is better to try recreate log file in case it becomes removed at runtime
    hide_stderr
    printf "$local_log_timestamp" "$local_current_time" "$local_log_prefix $*" >> "$log"
    restore_stderr
  fi

  # Print message as notification if '--notifications' option is specified and those have been allowed (before start event reading)
  if [[ -n "$allow_notifications" ]]; then
    notify-send --icon="$local_notification_icon" "$*"
  fi
}
