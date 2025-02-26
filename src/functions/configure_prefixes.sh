# Required to handle color mode with prefixes and timestamp specified by user
configure_prefixes(){
  # Define whether daemon should disable or enforce colors for default prefixes and timestamp
  if [[ "$color" == 'always' ]]; then
    prefix_error="$(echo -e "[\033[31mx\033[0m]")" # Red
    prefix_info="$(echo -e "[\033[32mi\033[0m]")" # Green
    prefix_verbose="$(echo -e "[\033[34m~\033[0m]")" # Blue
    prefix_warning="$(echo -e "[\033[33m!\033[0m]")" # Yellow
    timestamp_format="$(echo -e "[\033[35m%Y-%m-%dT%H:%M:%S%z\033[0m]")" # Pink
  elif [[ "$color" == 'never' ]]; then
    prefix_error='[x]'
    prefix_info='[i]'
    prefix_verbose='[~]'
    prefix_warning='[!]'
    timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'
  fi

  # Inherit log prefixes from default ones if enforced
  if [[ "$color" =~ ^('always'|'never')$ ]]; then
    log_prefix_error="$prefix_error"
    log_prefix_info="$prefix_info"
    log_prefix_verbose="$prefix_verbose"
    log_prefix_warning="$prefix_warning"
    log_timestamp_format="$timestamp_format"
  fi

  # Set specified prefixes for messages if any
  local local_temp_prefix_type
  for local_temp_prefix_type in error info verbose warning; do
    # Get name of variable with new prefix
    local local_variable_name="new_prefix_$local_temp_prefix_type"

    # Check for existence of value in variable indirectly
    if [[ -n "${!local_variable_name}" ]]; then
      eval "prefix_$local_temp_prefix_type"=\'"$(colors_interpret "$local_variable_name")"\'
      local local_is_prefixes_changed='1'
      unset "new_prefix_$local_temp_prefix_type"
    fi
  done

  # Set specified timestamp format if any and handle ANSI escapes
  if [[ -n "$new_timestamp_format" ]]; then
    timestamp_format="$(colors_interpret "new_timestamp_format")"
    local local_is_timestamp_format_changed='1'
    unset new_timestamp_format
  fi

  # Remove colors from prefixes and timestamp in log related variables
  # Those values will be set to main prefixes and timestamp if 'never' is enforced
  if [[ "$color" != 'always' && -n "$local_is_prefixes_changed" ]]; then
    # Prefixes
    local local_temp_prefix_type
    for local_temp_prefix_type in error info verbose warning; do
      # Get variable name
      local local_variable_name="prefix_$local_temp_prefix_type"

      # Get log related variable name
      local local_log_variable_name="log_$local_variable_name"

      # Store value of current variable to log related variable
      eval "$local_log_variable_name"=\'"${!local_variable_name}"\'

      # Remove ANSI escapes
      while [[ "${!local_log_variable_name}" =~ $'\033'\[[0-9(\;)?]+'m' ]]; do
        eval "$local_log_variable_name"=\'"${!local_log_variable_name//"${BASH_REMATCH[0]}"/}"\'
      done
    done
  fi

  # Remove colors timestamp in log related variable
  # This value will be set to main timestamp if 'never' is enforced
  if [[ "$color" != 'always' && -n "$local_is_timestamp_format_changed" ]]; then
    # Store value of timestamp variable into log related one
    log_timestamp_format="$timestamp_format"

    # Remove ANSI escapes
    while [[ "$log_timestamp_format" =~ $'\033'\[[0-9(\;)?]+'m' ]]; do
      log_timestamp_format="${log_timestamp_format//"${BASH_REMATCH[0]}"/}"
    done
  fi

  # Define whether daemon should enforce colorless or colorful prefixes and timestamp
  if [[ "$color" == 'never' ]]; then
    # Use colorless (log specific) as default too
    prefix_error="$log_prefix_error"
    prefix_info="$log_prefix_info"
    prefix_verbose="$log_prefix_verbose"
    prefix_warning="$log_prefix_warning"
    timestamp_format="$log_timestamp_format"
  elif [[ "$color" == 'always' ]]; then
    # Use colorful for logging too
    log_prefix_error="$prefix_error"
    log_prefix_info="$prefix_info"
    log_prefix_verbose="$prefix_verbose"
    log_prefix_warning="$prefix_warning"
    log_timestamp_format="$timestamp_format"
  fi
}
