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
  # Workaround for case when new line character is passed as command (because of appending support using '+=')
  if [[ -z "$passed_event_command" ]]; then
    return 0
  fi

  # Run command separately from daemon in background
  passed_section='' \
  passed_event_command='' \
  passed_end_of_msg='' \
  nohup setsid bash -c "$passed_event_command" > /dev/null 2>&1 &

  # Notify user about execution
  if [[ "$passed_command_type" == 'default' ]]; then
    message --info "${passed_event_type^} command '$(bash -c "echo \"$passed_event_command\"")' from section '$passed_section' has been executed $passed_end_of_msg."
  elif [[ "$passed_command_type" == 'lazy' ]]; then
    message --info "Lazy $passed_event_type command '$(bash -c "echo \"$passed_event_command\"")' from section '$passed_section' has been executed $passed_end_of_msg."
  fi
}

# Required to convert relative paths to absolute ones
get_realpath(){
  local local_path="$1"
  local IFS='/'

  # 'local' + 'declare -a'
  local -a local_parts_map \
  local_stack_map

  # Append passed path to '$PWD' if it contains relative beginning and not begins with home path ('~')
  # Or if path begins with '~', then replace symbol with home path
  if [[ "$local_path" != '/'* &&
        "$local_path" != '~/'* ]]; then
    local local_path="${PWD}/${local_path}"
  elif [[ "$local_path" == '~/'* ]]; then
    local local_path="${local_path/'~'/"$HOME"}"
  fi

  # Replace double slashes with single one
  while [[ "$local_path" == *'//'* ]]; do
    local local_path="${local_path//'//'/'/'}"
  done

  # Convert path into associative array
  read -ra local_parts_map <<< "$local_path"

  # Handle levels in relative path
  local local_temp_part
  for local_temp_part in "${local_parts_map[@]}"; do
    case "$local_temp_part" in
    '.' )
      # Skip dot as that means current directory
      continue
    ;;
    '..' )
      # Remove last added element from map
      local local_stack_count="${#local_stack_map[@]}"
      if (( local_stack_count > 0 )); then
        unset local_stack_map[local_stack_count-1]
      fi
    ;;
    * )
      # Otherwise append to stack
      local local_stack_map+=("$local_temp_part")
    esac
  done

  # Summarize absolute path
  local local_absolute_path="${local_stack_map[*]}"

  # Output will be stored to variable from command substitution
  echo "$local_absolute_path"
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
  local local_variable_value="${local_variable_value}\e[0m"

  # Replace ANSI escapes with their interpreted form
  while [[ "$local_variable_value" =~ '\'([eE]|[uU]001[bB]|[xX]1[bB]|033)\[[0-9\;]+'m' ]]; do
    local local_ansi_interpretation="$(echo -e "${BASH_REMATCH[0]}")"
    local local_variable_value="${local_variable_value//"${BASH_REMATCH[0]}"/"$local_ansi_interpretation"}"
  done

  # Value will be stored to variable from command substitution
  echo "$local_variable_value"
}

# Required to shorten paths in messages if possible
shorten_path(){
  # Accepts path as a single argument
  local local_path="$1"

  # Define how to shorten path
  if [[ "$local_path" == "$PWD/"* &&
        "$PWD" != "$HOME" ]]; then
    # E.g. '/home/zappex/.config/flux.ini' -> 'flux.ini' (if current directory is '/home/zappex/.config')
    local local_path="${local_path/"$PWD/"/}"
  elif [[ "$local_path" == "$HOME"* ]]; then
    # E.g. '/home/zappex/.config/flux.ini' -> '~/.config/flux.ini' (if current directory is '/home/zappex')
    local local_path="${local_path/"$HOME"/'~'}"
  fi

  # Value will be printed in message from command substitution
  echo "$local_path"
}

# Required to detect whether section is a group or not
section_is_group(){
  local local_section="$1"
  if [[ "$local_section" =~ ^'@'.* ]]; then
    return 0
  else
    return 1
  fi
}

# Required to get number of line from section using key name
# get_key_line <section> - section line
# get_key_line <section> <key> - key line
get_key_line(){
  local local_section="$1"
  local local_key_name="$2"

  # Get section line if key name is not specified
  if [[ -z "$local_key_name" ]]; then
    get_key_line_result="${config_keys_order_map["$local_section"]/' '*/}"
  else
    # Get key line
    local local_temp_key
    for local_temp_key in ${config_keys_order_map["$local_section"]}; do
      if [[ "$local_temp_key" == *".$local_key_name" ]]; then
        get_key_line_result="${local_temp_key/'.'*/}"
        return 0
      fi
    done

    get_key_line_result='0'
  fi
}

# Needed to use environment variables with previous and focused window info in commands from 'exec-focus', `lazy-exec-focus` and 'exec-oneshot'
export_focus_envvars(){
  export WINDOW_XID="$window_xid" \
  PROCESS_PID="$process_pid" \
  PROCESS_NAME="$process_name" \
  PROCESS_OWNER="$process_owner" \
  PROCESS_OWNER_USERNAME="$process_owner_username" \
  PROCESS_COMMAND="$process_command" \
  PREV_WINDOW_XID="$previous_window_xid" \
  PREV_PROCESS_PID="$previous_process_pid" \
  PREV_PROCESS_NAME="$previous_process_name" \
  PREV_PROCESS_OWNER="$previous_process_owner" \
  PREV_PROCESS_OWNER_USERNAME="$previous_process_owner_username" \
  PREV_PROCESS_COMMAND="$previous_process_command"
}

# Needed to unset environment variables with previous and focused window info used in commands from 'exec-focus', `lazy-exec-focus` and 'exec-oneshot'
unset_focus_envvars(){
  unset WINDOW_XID \
  PROCESS_PID \
  PROCESS_NAME \
  PROCESS_OWNER \
  PROCESS_OWNER_USERNAME \
  PROCESS_COMMAND \
  PREV_WINDOW_XID \
  PREV_PROCESS_PID \
  PREV_PROCESS_NAME \
  PREV_PROCESS_OWNER \
  PREV_PROCESS_OWNER_USERNAME \
  PREV_PROCESS_COMMAND
}

# Needed to use environment variables with previous and focused window info in commands from 'exec-unfocus', `lazy-exec-unfocus` and 'exec-closure'
export_unfocus_envvars(){
  export NEW_WINDOW_XID="$window_xid" \
  NEW_PROCESS_PID="$process_pid" \
  NEW_PROCESS_NAME="$process_name" \
  NEW_PROCESS_OWNER="$process_owner" \
  NEW_PROCESS_OWNER_USERNAME="$process_owner_username" \
  NEW_PROCESS_COMMAND="$process_command" \
  WINDOW_XID="$passed_window_xid" \
  PROCESS_PID="$passed_process_pid" \
  PROCESS_NAME="$passed_process_name" \
  PROCESS_OWNER="$passed_process_owner" \
  PROCESS_OWNER_USERNAME="$passed_process_owner_username" \
  PROCESS_COMMAND="$passed_process_command"
}

# Needed to unset environment variables with previous and focused window info used in commands from 'exec-unfocus', `lazy-exec-unfocus` and 'exec-closure'
unset_unfocus_envvars(){
  unset NEW_WINDOW_XID \
  NEW_PROCESS_PID \
  NEW_PROCESS_NAME \
  NEW_PROCESS_OWNER \
  NEW_PROCESS_OWNER_USERNAME \
  NEW_PROCESS_COMMAND \
  WINDOW_XID \
  PROCESS_PID \
  PROCESS_NAME \
  PROCESS_OWNER \
  PROCESS_OWNER_USERNAME \
  PROCESS_COMMAND
}
