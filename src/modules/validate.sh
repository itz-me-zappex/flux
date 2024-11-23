# Required to validate config file
validate_config(){
	local local_temp_config
	# Automatically set a path to config file if it is not specified
	if [[ -z "$config" ]]; then
		# Set XDG_CONFIG_HOME automatically if it is not specified
		if [[ -z "$XDG_CONFIG_HOME" ]]; then
			XDG_CONFIG_HOME="$HOME/.config"
		fi
		# Find a config
		for local_temp_config in "$XDG_CONFIG_HOME/flux.ini" "$HOME/.config/flux.ini" '/etc/flux.ini'; do
			if [[ -f "$local_temp_config" ]]; then
				config="$local_temp_config"
				break
			fi
		done
	fi
	# Exit with an error if config file is not found
	if [[ -z "$config" ]]; then
		message --error "Config file is not found!"
		exit 1
	elif [[ -e "$config" && ! -f "$config" ]]; then # Exit with an error if path exists but that is not a file
		message --error "Path '$config' specified in '--config' is not a file!"
		exit 1
	elif [[ ! -f "$config" ]]; then # Exit with an error if config file does not exist
		message --error "Config file '$config' does not exist!"
		exit 1
	elif ! check_ro "$config"; then # Exit with an error if config file is not readable
		message --error "Config file '$config' is not accessible for reading!"
		exit 1
	fi
	# Exit with an error if '--notifications' option is specified but 'notify-send' command is not found
	if [[ -n "$notifications" ]] && ! type notify-send > /dev/null 2>&1; then
		message --error "Command 'notify-send' required to print notifications is not found!"
		exit 1
	fi
}

# Required to validate config keys
validate_config_keys(){
	local local_temp_section
	# Check values in sections and exit with an error if something is wrong or set default values in some keys if is not specified
	for local_temp_section in "${sections_array[@]}"; do
		# Exit with an error if neither identifier 'name' nor 'executable' nor 'command' is specified
		if [[ -z "${config_key_name_map["$local_temp_section"]}" && -z "${config_key_executable_map["$local_temp_section"]}" && -z "${config_key_command_map["$local_temp_section"]}" ]]; then
			message --error "At least one process identifier required in section '$local_temp_section' in '$config' config file!"
			exit 1
		fi
		# Exit with an error if MangoHud FPS limit is not specified along with config path
		if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" && -z "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
			message --error "Value ${config_key_fps_unfocus_map["$local_temp_section"]} in 'fps-unfocus' key in section '$local_temp_section' is specified without 'mangohud-config' key in '$config' config file!"
			exit 1
		fi
		# Exit with an error if MangoHud FPS limit is specified along with CPU limit
		if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" && -n "${config_key_cpu_limit_map["$local_temp_section"]}" && "${config_key_cpu_limit_map["$local_temp_section"]}" != '-1' ]]; then
			message --error "Do not use FPS limit along with CPU limit in section '$local_temp_section' in '$config' config file!"
			exit 1
		fi
		# Exit with an error if 'fps-focus' is specified without 'fps-unfocus'
		if [[ -n "${config_key_fps_focus_map["$local_temp_section"]}" && -z "${config_key_fps_unfocus_map["$local_temp_section"]}" ]]; then
			message --error "Do not use 'fps-focus' key without 'fps-unfocus' key in section '$local_temp_section' in '$config' config file!"
			exit 1
		fi
		# Exit with an error if 'mangohud-config' is specified without 'fps-unfocus'
		if [[ -n "${config_key_mangohud_config_map["$local_temp_section"]}" && -z "${config_key_fps_unfocus_map["$local_temp_section"]}" ]]; then
			message --error "Do not use 'mangohud-config' key without 'fps-unfocus' key in section '$local_temp_section' in '$config' config file!"
			exit 1
		fi
		# Exit with an error if 'mangohud-source-config' is specified without 'mangohud-config'
		if [[ -n "${config_key_mangohud_source_config_map["$local_temp_section"]}" && -z "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
			message --error "Do not use 'mangohud-source-config' key without 'mangohud-config' key in section '$local_temp_section' in '$config' config file!"
			exit 1
		fi
		# Set 'fps-focus' to '0' (full FPS unlock) if it is not specified
		if [[ -n "${config_key_fps_unfocus_map["$local_temp_section"]}" && -z "${config_key_fps_focus_map["$local_temp_section"]}" ]]; then
			config_key_fps_focus_map["$local_temp_section"]='0'
		fi
		# Set CPU limit to '-1' (none) if it is not specified
		if [[ -z "${config_key_cpu_limit_map["$local_temp_section"]}" ]]; then
			config_key_cpu_limit_map["$local_temp_section"]='-1'
		fi
		# Set 'delay' to '0' if it is not specified
		if [[ -z "${config_key_delay_map["$local_temp_section"]}" ]]; then
			config_key_delay_map["$local_temp_section"]='0'
		fi
		# Set 'mangohud-config' as 'mangohud-source-config' if it is not specified
		if [[ -z "${config_key_mangohud_source_config_map["$local_temp_section"]}" && -n "${config_key_mangohud_config_map["$local_temp_section"]}" ]]; then
			config_key_mangohud_source_config_map["$local_temp_section"]="${config_key_mangohud_config_map["$local_temp_section"]}"
		fi
	done
	unset config
}

# Required to validate log
validate_log(){
	# Run multiple checks related to logging if '--log' option is specified
	if [[ -n "$log_is_passed" ]]; then
		unset log_is_passed
		# Exit with an error if '--log-timestamp' option is specified without timestamp format
		if [[ -n "$log_timestamp_is_passed" && -z "$new_log_timestamp" ]]; then
			message --error "Option '--log-timestamp' is specified without timestamp!$advice_on_option_error"
			exit 1
		fi
		unset log_timestamp_is_passed
		# Exit with an error if '--log' option is specified without path to log file
		if [[ -z "$log" ]]; then
			message --error "Option '--log' is specified without path to log file!$advice_on_option_error"
			exit 1
		fi
		# Exit with an error if specified log file exists but not accessible for read-write operations
		if [[ -f "$log" ]] && ! check_rw "$log"; then
			message --error "Log file '$log' is not accessible for read-write operations!"
			exit 1
		elif [[ -e "$log" && ! -f "$log" ]]; then # Exit with an error if path to log exists and that is not a file
			message --error "Path '$log' specified in '--log' option is expected to be a file!"
			exit 1
		elif [[ -d "${log%/*}" ]] && ! check_rw "${log%/*}"; then # Exit with an error if log file directory is not accessible for read-write operations
			message --error "Directory of log file '$log' is not accessible for read-write operations!"
			exit 1
		fi
	fi
}

# Required to validate options
validate_options(){
	local local_temp_prefix_type \
	local_once_is_passed \
	local_once_new_prefix
	# Exit with an error if verbose and quiet modes are specified at the same time
	if [[ -n "$verbose" && -n "$quiet" ]]; then
		message --error "Do not use verbose and quiet modes at the same time!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--lazy' option is specified without '--hot'
	if [[ -n "$lazy" && -z "$hot" ]]; then
		message --error "Do not use '--lazy' option without '--hot'!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if logging specific options are specified without '--log' option
	if [[ -z "$log_is_passed" ]] && [[ -n "$log_no_timestamps" || -n "$log_overwrite" || -n "$log_timestamp_is_passed" ]]; then
		message --error "Do not use options related to logging without '--log' options!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--log-timestamp' and '--log-no-timestamps' options are specified at the same time
	if [[ -n "$log_timestamp_is_passed" && -n "$log_no_timestamps" ]]; then
		message --error "Do not use '--log-timestamp' and '--log-no-timestamps' options at the same time!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--config' option is specified without a path to config file
	if [[ -n "$config_is_passed" && -z "$config" ]]; then
		message --error "Option '--config' is specified without path to config file!$advice_on_option_error"
		exit 1
	fi
	unset config_is_passed
	# Exit with error if at least one prefix option is specified without prefix
	for local_temp_prefix_type in error info verbose warning; do
		# Set proper variables names to obtain their values using indirectly
		local_once_is_passed="prefix_${local_temp_prefix_type}_is_passed"
		local_once_new_prefix="new_prefix_$local_temp_prefix_type"
		# Exit with an error if option is passed but value does not exist
		if [[ -n "${!local_once_is_passed}" && -z "${!local_once_new_prefix}" ]]; then
			message --info "Option '--prefix-$local_temp_prefix_type' is specified without prefix!$advice_on_option_error"
			exit 1
		fi
	done
}