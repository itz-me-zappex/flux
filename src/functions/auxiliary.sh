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

# Required to check process existence
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

  local local_expand_variables_result
  expand_variables "$passed_event_command"

  # Notify user about execution
  if [[ "$passed_command_type" == 'default' ]]; then
    message --info "${passed_event_type^} command ($local_expand_variables_result) ($passed_section) executed $passed_end_of_msg."
  elif [[ "$passed_command_type" == 'lazy' ]]; then
    message --info "Lazy $passed_event_type command ($local_expand_variables_result) ($passed_section) executed $passed_end_of_msg."
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

  # Should be declared as local outside
  local_get_realpath_result="${local_stack_map[*]}"
}

# Required to check whether value is boolean or not and simplify it
simplify_bool(){
  local local_value="$1"

  # Return an error if value is not boolean
  if [[ "${local_value,,}" =~ ^('true'|'t'|'yes'|'y'|'1'|'false'|'f'|'no'|'n'|'0')$ ]]; then
    # No need to set value in case it is false
    if [[ "${local_value,,}" =~ ^('true'|'t'|'yes'|'y'|'1')$ ]]; then
      # Should be declared as local outside
      local_simplify_bool_result='1'
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

  # Should be declared as local outside
  local_colors_interpret_result="$local_variable_value"
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

  # Should be declared as local outside
  local_shorten_path_result="$local_path"
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
    local_get_key_line_result="${config_keys_order_map["$local_section"]/' '*/}"
  else
    # Get key line
    local local_temp_key
    for local_temp_key in ${config_keys_order_map["$local_section"]}; do
      if [[ "$local_temp_key" == *".$local_key_name" ]]; then
        # Should be declared as local outside
        local_get_key_line_result="${local_temp_key/'.'*/}"
        return 0
      fi
    done

    # Should be declared as local outside
    local_get_key_line_result='0'
  fi
}

# Needed to use environment variables with previous and focused window info in commands from 'exec-focus', `lazy-exec-focus` and 'exec-oneshot'
export_focus_envvars(){
  export FOCUSED_WINDOW_XID="$window_xid" \
  FOCUSED_PID="$pid" \
  FOCUSED_PROCESS_NAME="$process_name" \
  FOCUSED_PROCESS_OWNER="$process_owner" \
  FOCUSED_PROCESS_OWNER_USERNAME="$process_owner_username" \
  FOCUSED_PROCESS_COMMAND="$process_command" \
  UNFOCUSED_WINDOW_XID="$previous_window_xid" \
  UNFOCUSED_PID="$previous_pid" \
  UNFOCUSED_PROCESS_NAME="$previous_process_name" \
  UNFOCUSED_PROCESS_OWNER="$previous_process_owner" \
  UNFOCUSED_PROCESS_OWNER_USERNAME="$previous_process_owner_username" \
  UNFOCUSED_PROCESS_COMMAND="$previous_process_command"
}

# Needed to use environment variables with previous and focused window info in commands from 'exec-unfocus', `lazy-exec-unfocus` and 'exec-closure'
export_unfocus_envvars(){
  export FOCUSED_WINDOW_XID="$window_xid" \
  FOCUSED_PID="$pid" \
  FOCUSED_PROCESS_NAME="$process_name" \
  FOCUSED_PROCESS_OWNER="$process_owner" \
  FOCUSED_PROCESS_OWNER_USERNAME="$process_owner_username" \
  FOCUSED_PROCESS_COMMAND="$process_command" \
  UNFOCUSED_WINDOW_XID="$passed_window_xid" \
  UNFOCUSED_PID="$passed_pid" \
  UNFOCUSED_PROCESS_NAME="$passed_process_name" \
  UNFOCUSED_PROCESS_OWNER="$passed_process_owner" \
  UNFOCUSED_PROCESS_OWNER_USERNAME="$passed_process_owner_username" \
  UNFOCUSED_PROCESS_COMMAND="$passed_process_command"
}

# Needed to unset environment variables which were exported to commands in execution related config keys
unset_envvars(){
  unset FOCUSED_WINDOW_XID \
  FOCUSED_PID \
  FOCUSED_PROCESS_NAME \
  FOCUSED_PROCESS_OWNER \
  FOCUSED_PROCESS_OWNER_USERNAME \
  FOCUSED_PROCESS_COMMAND \
  UNFOCUSED_WINDOW_XID \
  UNFOCUSED_PID \
  UNFOCUSED_PROCESS_NAME \
  UNFOCUSED_PROCESS_OWNER \
  UNFOCUSED_PROCESS_OWNER_USERNAME \
  UNFOCUSED_PROCESS_COMMAND
}

# Needed to replace variables in commands from config file with actual values
# Result used to print messages about execution
expand_variables(){
  local local_command="$1"
  local -a local_random_map

  # Regexp means variable with optional '\' (escaping)
  while [[ "$local_command" =~ ('\')+?'$'[a-zA-Z0-9_]+ ]]; do
    local local_rematch="${BASH_REMATCH[0]}"

    local local_first_backslashes="${local_rematch/[^'\']*/}"
    local local_first_backslash_count="${#local_first_backslashes}"

    # '0' if even, '1' if odd
    local local_backslash_count_is_odd="$(( local_first_backslash_count - local_first_backslash_count / 2 * 2 ))"

    if (( local_backslash_count_is_odd == 1 )); then
      # Since we want to ignore escaped variables, we should replace those temporary with something
      # Just in case random value will match one in command string
      while true; do
        local local_random="$SRANDOM"
        if [[ "$local_command" == *"$local_random"* ]]; then
          continue
        else
          break
        fi
      done

      local local_random_map["$local_random"]="$local_rematch"
      local local_command="${local_command/"$local_rematch"/"$local_random"}"
    else
      # Replace variable with its value
      local local_variable_name="${local_rematch#"$local_first_backslashes\$"}"
      local local_command="${local_command/"$local_rematch"/"$local_first_backslashes${!local_variable_name}"}"
    fi
  done

  # Now we need to restore escaped variables back
  local local_temp_random
  for local_temp_random in "${!local_random_map[@]}"; do
    local local_command="${local_command/"$local_temp_random"/"${local_random_map["$local_temp_random"]}"}"
  done

  # Should be declared as local outside
  local_expand_variables_result="$local_command"
}

# Hide/restore error messages, even standart ones which appear directly from Bash
# Source: https://unix.stackexchange.com/a/184807
hide_stderr(){
  exec 3>&2
  exec 2>/dev/null
}
restore_stderr(){
  exec 2>&3
}
