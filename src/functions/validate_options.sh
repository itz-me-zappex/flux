# Required to validate options
validate_options(){
  # Exit with an error if verbose and quiet modes are specified at the same time
  if [[ -n "$verbose" &&
        -n "$quiet" ]]; then
    message --error-opt "Do not use '--verbose' and '--quiet' options at the same time!"
    exit 1
  fi

  # Exit with an error if '--log-overwrite' option is specified without '--log' option
  if [[ -z "$log_is_passed" &&
        -n "$log_overwrite" ]]; then
    message --error-opt "Do not use '--log-overwrite' without '--log' option!"
    exit 1
  fi

  # Exit with an error if '--timestamp-format' is specified without '--timestamps'
  if [[ -n "$new_timestamp_format" &&
        -z "$timestamps" ]]; then
    message --error-opt "Do not use '--timestamp-format' without '--timestamps' option!"
    exit 1
  fi

  # Exit with an error if '--config' option is specified without a path to config file
  if [[ -n "$config_is_passed" &&
        -z "$config" ]]; then
    message --error-opt "Option '--config' requires a path to config file!"
    exit 1
  else
    unset config_is_passed
  fi

  # Exit with error if at least one prefix option is specified without prefix
  local local_temp_prefix_type
  for local_temp_prefix_type in error info verbose warning; do
    # Set proper variables names to obtain their values using indirectly
    local local_is_passed="prefix_${local_temp_prefix_type}_is_passed"
    local local_new_prefix="new_prefix_$local_temp_prefix_type"

    # Exit with an error if option is passed but value does not exist
    if [[ -n "${!local_is_passed}" &&
          -z "${!local_new_prefix}" ]]; then
      message --error-opt "Option '--prefix-$local_temp_prefix_type' requires a prefix value!"
      exit 1
    fi
  done

  # Exit with an error if '--timestamp-format' option is specified without timestamp format
  if [[ -n "$timestamp_is_passed" &&
        -z "$new_timestamp_format" ]]; then
    message --error-opt "Option '--timestamp-format' requires a timestamp format value!"
    exit 1
  else
    unset timestamp_is_passed
  fi

  # Exit with an error if '--color' option is specified behavior or has wrong value
  if [[ -n "$color_is_passed" &&
        -z "$color" ]]; then
    message --error-opt "Option '--color' requires a mode value!"
    exit 1
  elif [[ -n "$color" &&
          ! "${color,,}" =~ ^('always'|'auto'|'never')$ ]]; then
    message --error-opt "Specified mode '$color' in '--color' option is not supported!"
    exit 1
  else
    unset color_is_passed
  fi

  # Exit with an error if '--notifications' option is specified but 'notify-send' command is not found
  if [[ -n "$notifications" ]] &&
     ! type notify-send > /dev/null 2>&1; then
    message --error "Command 'notify-send' required for notifications support is not found!"
    exit 1
  fi
}
