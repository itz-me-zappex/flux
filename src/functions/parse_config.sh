# Required to parse INI config file
parse_config(){
  # Parse INI config
  local local_temp_config_line
  while read -r local_temp_config_line; do
    # Skip cycle if line is commented or blank, regexp means comments which beginning from ';' or '#' symbols
    if [[ ! "$local_temp_config_line" =~ ^(\;|\#) &&
          -n "$local_temp_config_line" ]]; then
      # Exit with an error if first line is not a section, otherwise remember section name, regexp means any symbols in square brackes
      if [[ ! "$local_temp_config_line" =~ ^\[.*\]$ &&
            -z "$local_section" ]]; then
        message --error "Initial section is not found in '$config' config file!"
        exit 1
      elif [[ "$local_temp_config_line" =~ ^\[.*\]$ ]]; then # Regexp means any symbols in square brackes
        # Exit with an error if section repeated
        if [[ -n "${sections_array[*]}" ]]; then
          local local_temp_section
          for local_temp_section in "${sections_array[@]}"; do
            if [[ "[$local_temp_section]" == "$local_temp_config_line" ]]; then
              message --error "Section name '$local_temp_section' is repeated in '$config' config file!"
              exit 1
            fi
          done
        fi

        # Remove square brackets from section name and add it to array
        # Array required to check for repeating sections and find matching rule(s) for process in config
        local local_section="${local_temp_config_line/\[/}"
        local local_section="${local_section/%\]/}"
        sections_array+=("$local_section")
      elif [[ "${local_temp_config_line,,}" =~ ^(name|owner|cpu-limit|delay|(lazy-)?exec-(un)?focus|command|mangohud(-source)?-config|fps-unfocus|fps-focus|idle|minimize)([[:space:]]+)?=([[:space:]]+)?* ]]; then # Exit with an error if type of line cannot be defined, regexp means [key name][space(s)?]=[space(s)?][anything else]
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

        # Associate value with section if it is not blank
        if [[ -n "$local_config_value" ]]; then
          # Define type of key to associate value properly
          case "${local_temp_config_line,,}" in
          name* )
            config_key_name_map["$local_section"]="$local_config_value"
          ;;
          owner* )
            config_key_owner_map["$local_section"]="$local_config_value"
          ;;
          cpu-limit* )
            # Exit with an error if CPU limit is specified incorrectly or greater than maximum allowed, regexp - any number with optional '%' symbol
            if [[ "$local_config_value" =~ ^[0-9]+(\%)?$ ]] &&
               (( "${local_config_value/%\%/}" * cpu_threads <= max_cpu_limit )); then
              config_key_cpu_limit_map["$local_section"]="${local_config_value/%\%/}"
            else
              message --error "Value '$local_config_value' in key 'cpulimit' in section '$local_section' is invalid in '$config' config file! Allowed values are between 0 and 100."
              exit 1
            fi
          ;;
          delay* )
            # Exit with an error if value is neither an integer nor a float (that is what regexp means)
            if [[ "$local_config_value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
              config_key_delay_map["$local_section"]="$local_config_value"
            else
              message --error "Value '$local_config_value' in key 'delay' in section '$local_section' is neither integer nor float in '$config' config file!"
              exit 1
            fi
          ;;
          exec-focus* )
            config_key_exec_focus_map["$local_section"]="$local_config_value"
          ;;
          exec-unfocus* )
            config_key_exec_unfocus_map["$local_section"]="$local_config_value"
          ;;
          command* )
            config_key_command_map["$local_section"]="$local_config_value"
          ;;
          mangohud-source-config* | mangohud-config* )
            # Get absolute path to MangoHud config in case it is specified as relative
            local local_config_value="$(get_realpath "$local_config_value")"

            # Check for config file existence
            if [[ -f "$local_config_value" ]]; then
              # Set path to MangoHud config depending by specified key
              case "${local_temp_config_line,,}" in
              mangohud-source-config* )
                config_key_mangohud_source_config_map["$local_section"]="$local_config_value"
              ;;
              mangohud-config* )
                config_key_mangohud_config_map["$local_section"]="$local_config_value"
              esac
            else
              # Set key name depending by key name on line
              case "${local_temp_config_line,,}" in
              mangohud-source-config* )
                local local_key_name='mangohud-source-config'
              ;;
              mangohud-config* )
                local local_key_name='mangohud-config'
              esac

              # Exit with an error if specified MangoHud config file does not exist
              message --error "MangoHud config file '$local_config_value' specified in key '$local_key_name' in section '$local_section' in '$config' config file does not exist!"
              exit 1
            fi
          ;;
          fps-unfocus* )
            # Exit with an error if value is not integer, that is what regexp means
            if [[ "$local_config_value" =~ ^[0-9]+$ ]]; then
              # Exit with an error if value equal to zero
              if [[ "$local_config_value" != '0' ]]; then
                config_key_fps_unfocus_map["$local_section"]="$local_config_value"
              else
                message --error "Value $local_config_value in key 'fps-unfocus' in section '$local_section' in '$config' config file should be greater than zero!"
                exit 1
              fi
            else
              message --error "Value '$local_config_value' specified in key 'fps-unfocus' in section '$local_section' in '$config' config file is not an integer!"
              exit 1
            fi
          ;;
          fps-focus* )
            # Exit with an error if value is neither integer nor list of comma-separated integers
            if [[ "$local_config_value" =~ ^[0-9]+$ ||
                  "$local_config_value" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
              config_key_fps_focus_map["$local_section"]="$local_config_value"
            else
              message --error "Value '$local_config_value' specified in key 'fps-focus' in section '$local_section' in '$config' config file is not an integer!"
              exit 1
            fi
          ;;
          lazy-exec-focus* )
            config_key_lazy_exec_focus_map["$local_section"]="$local_config_value"
          ;;
          lazy-exec-unfocus* )
            config_key_lazy_exec_unfocus_map["$local_section"]="$local_config_value"
          ;;
          idle* )
            # Exit with an error if value is not boolean
            if ! is_bool "$local_config_value"; then
              message --error "Value '$local_config_value' specified in key 'idle' in section '$local_section' in '$config' config file is not boolean!"
              exit 1
            else
              config_key_idle_map["$local_section"]="$(bool_to_int "$local_config_value")"
            fi
          ;;
          minimize* )
            # Exit with an error if value is not boolean
            if ! is_bool "$local_config_value"; then
              message --error "Value '$local_config_value' specified in key 'minimize' in section '$local_section' in '$config' config file is not boolean!"
              exit 1
            else
              config_key_minimize_map["$local_section"]="$(bool_to_int "$local_config_value")"
            fi
          esac
        fi
      else
        # Print error message depending on whether section is defined or not
        if [[ -n "$local_section" ]]; then
          message --error "Unable to define type of line '$local_temp_config_line' in section '$local_section' in '$config' config file!"
        else
          message --error "Unable to define type of line '$local_temp_config_line' in '$config' config file!"
        fi

        exit 1
      fi
    fi
  done < "$config"

  unset max_cpu_limit
}
