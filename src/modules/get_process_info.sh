# Required to get process info from cache in 'get_process_info' function
cache_get_process_info(){
	process_pid="${cache_process_pid_map["$passed_window_id"]}"
	process_name="${cache_process_name_map["$passed_window_id"]}"
	process_executable="${cache_process_executable_map["$passed_window_id"]}"
	process_owner="${cache_process_owner_map["$passed_window_id"]}"
	process_command="${cache_process_command_map["$passed_window_id"]}"
}

# Required to get process info using window ID
get_process_info(){
	local local_temp_status_line \
	local_column_count='0' \
	local_status_column \
	local_matching_window_id \
	local_temp_cached_window_id
	# Use cache of window info if exists
	if [[ "${cache_event_type_map["$window_id"]}" == 'good' ]]; then
		# Get process info from cache
		passed_window_id="$window_id" cache_get_process_info
		message --verbose "Cache has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
	elif [[ -z "${cache_event_type_map["$window_id"]}" ]]; then # Extract process info if it is not cached
		# Attempt to obtain output with PID
		if ! process_pid="$(xprop -id "$window_id" _NET_WM_PID 2>/dev/null)" || [[ "$process_pid" == '_NET_WM_PID:  not found.' ]]; then
			cache_event_type_map["$window_id"]='bad'
			process_pid=''
		else
			# Extract PID from output
			process_pid="${process_pid/*= /}" # Remove everything before including '= '
		fi
		# Extract info about process if that is not bad event
		if [[ "${cache_event_type_map["$window_id"]}" != 'bad' ]]; then
			# Attempt to find cache with info about the same process
			for local_temp_cached_window_id in "${!cache_process_pid_map[@]}"; do
				# Compare parent PID with PID of process
				if [[ "${cache_process_pid_map[$local_temp_cached_window_id]}" == "$process_pid" ]]; then
					# Remember window ID of matching process
					local_matching_window_id="$local_temp_cached_window_id"
					break
				fi
			done
			# Check for match of cached PID info to define a way how to obtain process info
			if [[ -n "$local_matching_window_id" ]]; then
				# Get process info using cache of parent window
				passed_window_id="$local_matching_window_id" cache_get_process_info
				message --verbose "Cache of parent window with ID $local_matching_window_id has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
			else
				# Extract name of process
				if check_ro "/proc/$process_pid/comm"; then
					process_name="$(<"/proc/$process_pid/comm")"
				else
					return 2
				fi
				# Extract executable path of process
				if check_ro "/proc/$process_pid/exe"; then
					process_executable="$(readlink "/proc/$process_pid/exe")"
				else
					return 2
				fi
				# Extract effective UID of process
				if check_ro "/proc/$process_pid/status"; then
					while read -r local_temp_status_line; do
						# Find a line which contains UID
						if [[ "$local_temp_status_line" == 'Uid:'* ]]; then
							# Find 3rd column, which effective UID is
							for local_status_column in $local_temp_status_line; do
								# Current column number
								(( local_column_count++ ))
								# Remember UID and break cycle if that is effective UID
								if (( local_column_count == 3 )); then
									process_owner="$local_status_column"
									break
								fi
							done
						fi
					done < "/proc/$process_pid/status"
				else
					return 2
				fi
				# I did not get how to do that using built-in bash options
				# Extract command of process and replace '\0' (used as separator between options) with spaces
				if check_ro "/proc/$process_pid/cmdline"; then
					process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
					# Remove last space because '\0' (which is replaced with space) is last symbol too
					process_command="${process_command/%\ /}"
				else
					return 2
				fi
				message --verbose "Obtained info about window with ID $window_id and process '$process_name' with PID $process_pid has been cached."
			fi
			# Store info about window and process to cache
			cache_event_type_map["$window_id"]='good'
			cache_process_pid_map["$window_id"]="$process_pid"
			cache_process_name_map["$window_id"]="$process_name"
			cache_process_executable_map["$window_id"]="$process_executable"
			cache_process_owner_map["$window_id"]="$process_owner"
			cache_process_command_map["$window_id"]="$process_command"
		else
			return 1
		fi
	else
		return 1
	fi
}
