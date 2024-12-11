# Required to get process info from cache
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
	# Use cache with window info if exists and is not bad
	if [[ "${cache_event_type_map["$window_id"]}" == 'good' ]]; then
		# Get process info from cache
		passed_window_id="$window_id" cache_get_process_info
		message --verbose "Cache has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
	elif [[ -z "${cache_event_type_map["$window_id"]}" ]]; then # Get process info from procfs if not cached
		# Obtain output with process PID using window ID
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
			# Check for match of cached process info to define a way how to obtain it
			if [[ -n "$local_matching_window_id" ]]; then
				# Get process info using cache of parent window
				passed_window_id="$local_matching_window_id" cache_get_process_info
				message --verbose "Cache of parent window with ID $local_matching_window_id has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
			else
				# Get executable path of process, fails if daemon has insufficient rights to interact with process by sending SIGSTOP/SIGCONT signals
				if check_ro "/proc/$process_pid/exe"; then
					process_executable="$(readlink "/proc/$process_pid/exe")"
				else
					return 3
				fi
				# Get name of process
				if check_ro "/proc/$process_pid/comm"; then
					process_name="$(<"/proc/$process_pid/comm")"
				else
					return 2
				fi
				# Get effective UID of process
				if check_ro "/proc/$process_pid/status"; then
					while read -r local_temp_status_line; do
						# Find a line which contains UID
						if [[ "$local_temp_status_line" == 'Uid:'* ]]; then
							# Find 3rd column, which effective UID is
							for local_status_column in $local_temp_status_line; do
								# Increase column count
								(( local_column_count++ ))
								# Remember effective UID and break loop (3rd column)
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
				# Get command of process and replace '\0' (used as separator between options) with spaces
				if check_ro "/proc/$process_pid/cmdline"; then
					process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
					# Remove last space because '\0' which is replaced with space is last symbol too
					process_command="${process_command/%\ /}"
				else
					return 2
				fi
				message --verbose "Obtained info about window with ID $window_id and process '$process_name' with PID $process_pid has been cached."
			fi
			# Associate info about window and process with cache-related associative arrays to use it next time
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
