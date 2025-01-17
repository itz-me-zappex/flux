# Required to find matching section for process
find_matching_section(){
	local local_temp_section \
	local_name_match \
	local_owner_match \
	local_command_match
	# Find matching section if was not found previously and store it to cache
	if [[ -z "${cache_section_map["$process_pid"]}" ]]; then
		# Avoid searching for matching section if it was not found previously
		if [[ -z "${cache_mismatch_map["$process_pid"]}" ]]; then
			# Attempt to find a matching section in config
			for local_temp_section in "${sections_array[@]}"; do
				# Compare process name with specified in section
				if [[ -z "${config_key_name_map["$local_temp_section"]}" ]]; then
					local_name_match='1'
				else
					# Use soft match if name of process in 'name' config key longer than or equal to 16 symbols
					if [[ "${config_key_name_map["$local_temp_section"]}" == "$process_name" ]]; then
						local_name_match='1'
					elif [[ "${config_key_name_map["$local_temp_section"]}" == "$process_name"* && "${config_key_name_map["$local_temp_section"]}" =~ ^.{16,}$ ]]; then
						local_name_match='1'
					fi
				fi
				# Compare UID of process with specified in section
				if [[ -z "${config_key_owner_map["$local_temp_section"]}" || "${config_key_owner_map["$local_temp_section"]}" == "$process_owner" || "${config_key_owner_map["$local_temp_section"]}" == "$process_owner_username" ]]; then
					local_owner_match='1'
				fi
				# Compare process command with specified in section
				if [[ -z "${config_key_command_map["$local_temp_section"]}" || "${config_key_command_map["$local_temp_section"]}" == "$process_command" ]]; then
					local_command_match='1'
				fi
				# Mark as matching if all identifiers containing non-zero value
				if [[ -n "$local_name_match" && -n "$local_owner_match" && -n "$local_command_match" ]]; then
					section="$local_temp_section"
					cache_section_map["$process_pid"]="$local_temp_section"
					break
				fi
				unset local_name_match \
				local_owner_match \
				local_command_match
			done
			# Mark process as mismatched if matching section was not found
			if [[ -z "$section" ]]; then
				cache_mismatch_map["$process_pid"]='1'
			fi
		fi
	else
		# Obtain matching section from cache
		section="${cache_section_map["$process_pid"]}"
	fi
	# Print message about section match
	if [[ -n "$section" ]]; then
		message --verbose "Process '$process_name' with PID $process_pid of window $window_id matches with section '$section'."
	else
		message --verbose "Process '$process_name' with PID $process_pid of window $window_id does not match with any section."
		return 1
	fi
}