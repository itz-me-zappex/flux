# Required to parse INI config file
parse_config(){
  # Parse INI config
  local local_temp_config_line
  while read -r local_temp_config_line ||
        [[ -n "$local_temp_config_line" ]]; do
    # Get current line count and add postfix
    (( config_line_count++ ))

    local local_line_count_msg="L${config_line_count}:"

    # Skip cycle if line is commented or blank, regexp means comments which beginning from ';' or '#' symbols
    if [[ ! "$local_temp_config_line" =~ ^(\;|\#) &&
          -n "$local_temp_config_line" ]]; then
      # Exit with an error if first line is not a section, otherwise remember section name, regexp means any symbols in square brackes
      if [[ ! "$local_temp_config_line" =~ ^\[.*\]$ &&
            -z "$local_section" &&
            -z "$local_no_init_section" ]]; then
        message --warning "$local_line_count_msg There is '$local_temp_config_line' instead of initial section!"
        local local_no_init_section='1'
        (( parse_config_error_count++ ))
      elif [[ "$local_temp_config_line" =~ ^\[.*\]$ ]]; then
        # Regexp above means any symbols in square brackes
        # Exit with an error if section is repeated
        if [[ -n "${sections_array[*]}" ]]; then
          local local_temp_section
          for local_temp_section in "${sections_array[@]}"; do
            if [[ "[$local_temp_section]" == "$local_temp_config_line" ]]; then
              message --warning "$local_line_count_msg Section name '$local_temp_section' is repeated!"
              (( parse_config_error_count++ ))
            fi
          done
        fi

        # Exit with an error if group is repeated
        if [[ -n "${groups_array[*]}" ]]; then
          local local_temp_group
          for local_temp_group in "${groups_array[@]}"; do
            if [[ "[$local_temp_group]" == "$local_temp_config_line" ]]; then
              message --warning "$local_line_count_msg Group name '$local_temp_group' is repeated!"
              (( parse_config_error_count++ ))
            fi
          done
        fi

        # Remove square brackets from section name and add it to array
        # Array required to check for repeating sections and find matching rule(s) for process in config
        local local_section="${local_temp_config_line/\[/}"
        local local_section="${local_section/%\]/}"

        # Splitting groups and section is needed to make groups inside groups work, also I need to define type of section to show in message
        if section_is_group "$local_section"; then
          groups_array+=("$local_section")
          local local_section_msg=" in '$local_section' group"
        else
          sections_array+=("$local_section")
          local local_section_msg=" in '$local_section' section"
        fi

        # Needed to detect blank sections, if at least one key specified, this map is unset
        is_section_blank_map["$local_section"]='1'

        # Remember section line
        config_keys_order_map["$local_section"]+="$config_line_count"
      elif [[ "${local_temp_config_line,,}" =~ ^[^[:space:]]+([[:space:]]+)?(\+|\~)?=([[:space:]]+)?* ]]; then
        # Remove equal symbol and key value to keep just key name
        if [[ "${local_temp_config_line,,}" =~ ^[^[:space:]]+([[:space:]]+)?\+=([[:space:]]+)?* ]]; then
          local local_append='1'
          unset local_regexp
          local local_config_key="${local_temp_config_line/%+=*/}"
        elif [[ "${local_temp_config_line,,}" =~ ^[^[:space:]]+([[:space:]]+)?\~=([[:space:]]+)?* ]]; then
          local local_regexp='1'
          unset local_append
          local local_config_key="${local_temp_config_line/%\~=*/}"
        else
          unset local_append
          unset local_regexp
          local local_config_key="${local_temp_config_line/%=*/}"
        fi

        # Remove all spaces before and after string, internal shell parameter expansion required to get spaces supposed to be removed
        local local_config_key="${local_config_key#"${local_config_key%%[![:space:]]*}"}" # Remove spaces in beginning for string
        local local_config_key="${local_config_key%"${local_config_key##*[![:space:]]}"}" # Remove spaces in end of string

        # Use lowercase for key name
        local local_config_key="${local_config_key,,}"

        # Remove key name and equal symbol
        local local_config_value="${local_temp_config_line#*=}"

        # Remove all spaces before and after string, internal shell parameter expansion required to get spaces supposed to be removed
        local local_config_value="${local_config_value#"${local_config_value%%[![:space:]]*}"}" # Remove spaces in beginning for string
        local local_config_value="${local_config_value%"${local_config_value##*[![:space:]]}"}" # Remove spaces in end of string

        # Remove single or double quotes from strings, that is what regexp means
        if [[ "$local_config_value" =~ ^(\".*\"|\'.*\')$ ]]; then
          # Regexp means double quoted string
          if [[ "$local_config_value" =~ ^\".*\"$ ]]; then
            local local_config_value="${local_config_value/\"/}" # Remove first double quote
            local local_config_value="${local_config_value/%\"/}" # And last one
          else
            local local_config_value="${local_config_value/\'/}" # Remove first single quote
            local local_config_value="${local_config_value/%\'/}" # And last one
          fi
        fi

        # Print warning and mark as an error if appending to unsupported key
        if [[ -n "$local_append" &&
              ! "$local_config_key" =~ ^('exec-exit'|'exec-exit-focus'|'exec-exit-unfocus'|'exec-closure'|'exec-oneshot'|'exec-focus'|'exec-unfocus'|'lazy-exec-focus'|'lazy-exec-unfocus')$ ]]; then
          message --warning "$local_line_count_msg Appending values$local_section_msg to '$local_config_key' config key is not supported!"
          (( parse_config_error_count++ ))
        fi

        # Print warning and mark as an error if regexp used in unsupported key
        if [[ -n "$local_regexp" &&
              ! "$local_config_key" =~ ^('name'|'command'|'owner')$ ]]; then
          message --warning "$local_line_count_msg Regexp$local_section_msg in '$local_config_key' config key is not supported!"
          (( parse_config_error_count++ ))
        fi

        # Print warning and mark as an error if identifiers appear used in group
        if section_is_group "$local_section" &&
           [[ "$local_config_key" =~ ^('name'|'owner'|'command')$ ]]; then
          message --warning "$local_line_count_msg Identifiers, including '$local_config_key' config key are not supported in groups!"
          (( parse_config_error_count++ ))
        fi

        # Associate value with section if it is not blank
        if [[ -n "$local_config_value" ]]; then
          # Define type of key to associate value properly
          case "$local_config_key" in
          name )
            config_key_name_map["$local_section"]="$local_config_value"
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.name"
            config_key_regexp_name_map["$local_section"]="$local_regexp"
          ;;
          owner )
            config_key_owner_map["$local_section"]="$local_config_value"
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.owner"
            config_key_regexp_owner_map["$local_section"]="$local_regexp"
          ;;
          cpu-limit )
            config_key_cpu_limit_map["$local_section"]="${local_config_value/%\%/}"
            is_section_useful_map["$local_section"]='1'

            # Exit with an error if CPU limit is specified incorrectly or greater than maximum allowed, regexp - any number with optional '%' symbol
            if [[ ! "$local_config_value" =~ ^[0-9]+(\%)?$ ]] ||
               ! (( "${local_config_value/%\%/}" * cpu_threads <= max_cpu_limit )); then
              message --warning "$local_line_count_msg Value '$local_config_value' in '$local_config_key' config key$local_section_msg is invalid! Allowed values are between 0 and 100."
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.cpu-limit"
          ;;
          delay )
            config_key_delay_map["$local_section"]="$local_config_value"

            # Exit with an error if value is neither an integer nor a float (that is what regexp means)
            if [[ ! "$local_config_value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
              message --warning "$local_line_count_msg Value '$local_config_value' in '$local_config_key' config key$local_section_msg is neither integer nor float!"
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.delay"
          ;;
          exec-exit )
            if [[ -z "$local_append" ]]; then
              config_key_exec_exit_map["$local_section"]="$local_config_value"
            else
              # Needed to append commands in key to inherited from 'lazy-exec-unfocus' config key
              if [[ -z "${config_key_exec_exit_map["$local_section"]}" ]]; then
                config_key_exec_exit_append_to_default_map["$local_section"]='1'
              fi

              config_key_exec_exit_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-exit"
          ;;
          exec-exit-focus )
            if [[ -z "$local_append" ]]; then
              config_key_exec_exit_focus_map["$local_section"]="$local_config_value"
            else
              config_key_exec_exit_focus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-exit-focus"
          ;;
          exec-exit-unfocus )
            if [[ -z "$local_append" ]]; then
              config_key_exec_exit_unfocus_map["$local_section"]="$local_config_value"
            else
              config_key_exec_exit_unfocus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-exit-unfocus"
          ;;
          exec-closure )
            if [[ -z "$local_append" ]]; then
              config_key_exec_closure_map["$local_section"]="$local_config_value"
            else
              # Needed to append commands in key to inherited from 'lazy-exec-unfocus' config key
              if [[ -z "${config_key_exec_closure_map["$local_section"]}" ]]; then
                config_key_exec_closure_append_to_default_map["$local_section"]='1'
              fi

              config_key_exec_closure_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-closure"
          ;;
          exec-oneshot )
            if [[ -z "$local_append" ]]; then
              config_key_exec_oneshot_map["$local_section"]="$local_config_value"
            else
              config_key_exec_oneshot_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-oneshot"
          ;;
          exec-focus )
            if [[ -z "$local_append" ]]; then
              config_key_exec_focus_map["$local_section"]="$local_config_value"
            else
              config_key_exec_focus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-focus"
          ;;
          exec-unfocus )
            if [[ -z "$local_append" ]]; then
              config_key_exec_unfocus_map["$local_section"]="$local_config_value"
            else
              config_key_exec_unfocus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-unfocus"
          ;;
          command )
            config_key_command_map["$local_section"]="$local_config_value"
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.exec-command"
            config_key_regexp_command_map["$local_section"]="$local_regexp"
          ;;
          mangohud-source-config | mangohud-config )
            # Get absolute path to MangoHud config in case it is specified as relative
            local local_config_value="$(get_realpath "$local_config_value")"

            # Set path to MangoHud config depending by specified key
            case "$local_config_key" in
            mangohud-source-config )
              config_key_mangohud_source_config_map["$local_section"]="$local_config_value"
              config_keys_order_map["$local_section"]+=" $config_line_count.mangohud-source-config"
            ;;
            mangohud-config )
              config_key_mangohud_config_map["$local_section"]="$local_config_value"
              config_keys_order_map["$local_section"]+=" $config_line_count.mangohud-source"
            esac

            # Check for config file existence
            if [[ ! -f "$local_config_value" ]]; then
              # Exit with an error if specified MangoHud config file does not exist
              message --warning "$local_line_count_msg MangoHud config file '$(shorten_path "$local_config_value")' specified in '$local_config_key' config key$local_section_msg does not exist!"
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
          ;;
          fps-unfocus )
            config_key_fps_unfocus_map["$local_section"]="$local_config_value"
            is_section_useful_map["$local_section"]='1'

            # Exit with an error if value equal to zero
            if [[ "$local_config_value" == '0' ]]; then
              message --warning "$local_line_count_msg Value $local_config_value in '$local_config_key' config key$local_section_msg should be greater than zero!"
              (( parse_config_error_count++ ))
            elif [[ ! "$local_config_value" =~ ^[0-9]+$ ]]; then
              # Exit with an error if value is not integer, that is what regexp means
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not an integer!"
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.fps-unfocus"
          ;;
          fps-focus )
            config_key_fps_focus_map["$local_section"]="$local_config_value"
            is_section_useful_map["$local_section"]='1'

            # Exit with an error if value is neither integer nor list of comma-separated integers
            if [[ ! "$local_config_value" =~ ^[0-9]+$ ||
                  ! "$local_config_value" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not an integer!"
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.fps-focus"
          ;;
          lazy-exec-focus )
            if [[ -z "$local_append" ]]; then
              config_key_lazy_exec_focus_map["$local_section"]="$local_config_value"
            else
              config_key_lazy_exec_focus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.lazy-exec-focus"
          ;;
          lazy-exec-unfocus )
            if [[ -z "$local_append" ]]; then
              config_key_lazy_exec_unfocus_map["$local_section"]="$local_config_value"
            else
              config_key_lazy_exec_unfocus_map["$local_section"]+=$'\n'"$local_config_value"
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.lazy-exec-unfocus"
          ;;
          idle )
            # Exit with an error if value is not boolean
            if ! config_key_idle_map["$local_section"]="$(simplify_bool "$local_config_value")"; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not boolean!"
              (( parse_config_error_count++ ))
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.idle"
          ;;
          unfocus-minimize )
            # Exit with an error if value is not boolean
            if ! config_key_unfocus_minimize_map["$local_section"]="$(simplify_bool "$local_config_value")"; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not boolean!"
              (( parse_config_error_count++ ))
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.unfocus-minimize"
          ;;
          focus-fullscreen )
            # Exit with an error if value is not boolean
            if ! config_key_focus_fullscreen_map["$local_section"]="$(simplify_bool "$local_config_value")"; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not boolean!"
              (( parse_config_error_count++ ))
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.focus-fullscreen"
          ;;
          focus-grab-cursor )
            # Exit with an error if value is not boolean
            if ! config_key_focus_grab_cursor_map["$local_section"]="$(simplify_bool "$local_config_value")"; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not boolean!"
              (( parse_config_error_count++ ))
            fi

            is_section_useful_map["$local_section"]='1'
            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.focus-grab-cursor"
          ;;
          group )
            config_key_group_map["$local_section"]="$local_config_value"
            is_section_useful_map["$local_section"]='1'

            # Exit with an error if group specified without '@' at the beginning of name
            if ! section_is_group "$local_config_value"; then
              message --warning "$local_line_count_msg Value '$local_config_value' specified in '$local_config_key' config key$local_section_msg is not a group!"
              (( parse_config_error_count++ ))
            fi

            unset is_section_blank_map["$local_section"]
            config_keys_order_map["$local_section"]+=" $config_line_count.group"
          ;;
          * )
            message --warning "$local_line_count_msg Unknown '$local_config_key' config key$local_section_msg!"
            (( parse_config_error_count++ ))
          esac
        else
          message --warning "$local_line_count_msg Config key '$local_config_key' is specified without value$local_section_msg!"
          (( parse_config_error_count++ ))
        fi
      else
        # Print error message depending on whether section is defined or not
        if [[ -n "$local_section" ]]; then
          message --warning "$local_line_count_msg Unable to define type of '$local_temp_config_line' line$local_section_msg!"
        else
          message --warning "$local_line_count_msg Unable to define type of '$local_temp_config_line' line!"
        fi

        (( parse_config_error_count++ ))
      fi
    fi
  done < "$config"
}
