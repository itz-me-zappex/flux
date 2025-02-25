# Required to check option repeating and exit with an error if that happens
option_repeat_check(){
  if [[ -n "${!1}" ]]; then
    message --error-opt "Option '$2' is repeated!"
    exit 1
  fi
}

# Required to obtain values from command line options
cmdline_get(){
  # Remember that option is passed to check whether it is passed again or not 
  option_repeat_check "$passed_check" "$passed_option"
  eval "$passed_check"='1'

  # Define option type (short, long or long=value) and remember specified value
  case "$1" in
  "$passed_option" | "$passed_short_option" )
    # Remember value only if that is not an another option, regexp means long or short option
    if [[ -n "$2" &&
          ! "$2" =~ ^(--.*|-.*)$ ]]; then
      eval "$passed_set"=\'"$2"\'
      shift='2'
    else
      shift='1'
    fi
  ;;
  * )
    # Remove option name from string
    eval "$passed_set"=\'"${1/"$passed_option"=/}"\'
    shift='1'
  esac
}

# Requred to check process existence
check_pid_existence(){
  local local_pid="$1"

  if [[ -d "/proc/$local_pid" ]]; then
    return 0
  else
    return 1
  fi
}

# Required to check read-write access on file
check_rw(){
  local local_file="$1"

  if [[ -r "$local_file" &&
        -w "$local_file" ]]; then
    return 0
  else
    return 1
  fi
}

# Required to check read-only access on file
check_ro(){
  local local_file="$1"

  if [[ -r "$local_file" ]]; then
    return 0
  else
    return 1
  fi
}

# Used in 'exec_focus()' and 'exec_unfocus()' as wrapper to run commands
exec_on_event(){
  # Run command separately from daemon in background
  passed_section='' \
  passed_event_command='' \
  passed_end_of_msg='' \
  nohup setsid bash -c "$passed_event_command" > /dev/null 2>&1 &

  # Notify user about execution
  if [[ "$passed_command_type" == 'default' ]]; then
    message --info "Command '$(bash -c "echo \"$passed_event_command\"")' from section '$passed_section' has been executed $passed_end_of_msg."
  elif [[ "$passed_command_type" == 'lazy' ]]; then
    message --info "Lazy command '$(bash -c "echo \"$passed_event_command\"")' from section '$passed_section' has been executed $passed_end_of_msg."
  fi
}

# Required to convert relative paths to absolute
get_realpath(){
  local local_relative_path="$1"

  # Output will be stored to variable from command substitution
  realpath -m "${local_relative_path/'~'/"$HOME"}"
}

# Required to check whether value is boolean or not and simplify it
simplify_bool(){
  local local_value="$1"

  # Return an error if value is not boolean
  if [[ "${local_value,,}" =~ ^('true'|'t'|'yes'|'y'|'1'|'false'|'f'|'no'|'n'|'0')$ ]]; then
    # Value will be stored to variable from command substitution
    # No need to set value in case it is false
    if [[ "${local_value,,}" =~ ^('true'|'t'|'yes'|'y'|'1')$ ]]; then
      echo 1
    fi
  else
    return 1
  fi
}

# Required to interpret colors/formatting in specified variable using ANSI escapes
# That is needed because handling all escape characters with just 'echo -e' may break output
colors_interpret(){
  # Accepts variable names and gets value
  local local_variable_value="${!1}"

  # Disable formatting in the end of value
  local local_variable_value="${local_variable_value}\033[0m"

  # Replace ANSI escapes with their interpreted form
  while [[ "$local_variable_value" =~ '\033'\[[0-9(\;)?]+'m' ]]; do
    local local_ansi_interpretation="$(echo -e "${BASH_REMATCH[0]}")"
    local local_variable_value="${local_variable_value//"${BASH_REMATCH[0]}"/"$local_ansi_interpretation"}"
  done

  # Value will be stored to variable from command substitution
  echo "$local_variable_value"
}
