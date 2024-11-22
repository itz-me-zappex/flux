# Required to unset CPU/FPS limit for terminated windows
unset_terminated_limits(){
	local local_once_terminated_process_pid \
	local_temp_terminated_window_id \
	local_once_existing_process_pid \
	local_temp_existing_window_id \
	local_once_found
	# Unset info about freezing and CPU limits of terminated windows
	for local_temp_terminated_window_id in $local_once_terminated_windows_ids; do
		# Skip window ID if that is bad event or info about it does not exist in cache
		if [[ -n "${cache_event_type_map["$local_temp_terminated_window_id"]}" && "${cache_event_type_map["$local_temp_terminated_window_id"]}" != 'bad' ]]; then
			# Obtain PID of terminated process using cache, required to check and unset FPS limit
			local_once_terminated_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}"
			# Do not do anything if window is not frozen
			if [[ -n "${is_frozen_pid_map["${cache_process_pid_map["$local_temp_terminated_window_id"]}"]}" ]]; then
				# Unfreeze process
				passed_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}" \
				passed_section="${cache_section_map["$local_once_terminated_process_pid"]}" \
				passed_process_name="${cache_process_name_map["$local_temp_terminated_window_id"]}" \
				passed_end_of_msg='due to window termination' \
				unfreeze_process
			elif [[ -n "${is_cpu_limited_pid_map["${cache_process_pid_map["$local_temp_terminated_window_id"]}"]}" ]]; then # Do not do anything if window is not CPU limited
				# Unset CPU limit
				passed_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}" \
				passed_process_name="${cache_process_name_map["$local_temp_terminated_window_id"]}" \
				passed_signal='-SIGUSR2' \
				unset_cpu_limit
			elif [[ -n "${cache_section_map["$local_once_terminated_process_pid"]}" && -n "${is_fps_limited_section_map["${cache_section_map["$local_once_terminated_process_pid"]}"]}" ]]; then # Do not do anything if window is not FPS limited
				# Do not remove FPS limit if one of existing windows matches with the same section
				for local_temp_existing_window_id in $local_once_existing_windows_ids; do
					# Obtain PID of terminated process using cache
					local_once_existing_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}"
					# Mark to not unset FPS limit if there is another window which matches with same section
					if [[ "${cache_section_map["$local_once_existing_process_pid"]}" == "${cache_section_map["$local_once_terminated_process_pid"]}" ]]; then
						local_once_found='1'
						break
					fi
				done
				# Unset FPS limit if there is no any matching windows except target
				if [[ -z "$local_once_found" ]]; then
					passed_section="${cache_section_map["$local_once_terminated_process_pid"]}" \
					passed_end_of_msg='due to matching window(s) termination' \
					unset_fps_limit
				fi
			fi
		fi
	done
}

# Required to remove cached info about terminated windows
cache_collect_garbage(){
	local local_temp_terminated_window_id \
	local_once_terminated_process_pid \
	local_once_terminated_section
	# Remove cached info about terminated windows
	for local_temp_terminated_window_id in $local_once_terminated_windows_ids; do
		# Check for event type before unset cache
		if [[ "${cache_event_type_map["$local_temp_terminated_window_id"]}" == 'bad' ]]; then
			# Unset only event type for bad window, otherwise bash will fail
			message --verbose "Cached info about bad window with ID $local_temp_terminated_window_id has been removed as it has been terminated."
			cache_event_type_map["$local_temp_terminated_window_id"]=''
		elif [[ "${cache_event_type_map["$local_temp_terminated_window_id"]}" == 'good' ]]; then
			# Simplify access to PID of cached window info
			local_once_terminated_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}"
			# Simplify access to matching section of cached window info
			local_once_terminated_section="${cache_section_map["$local_once_terminated_process_pid"]}"
			# Unset limit request
			if [[ -n "${request_freeze_map["$local_once_terminated_process_pid"]}" ]]; then
				request_freeze_map["$local_once_terminated_process_pid"]=''
				message --info "Freezing of process '${cache_process_name_map["$local_temp_terminated_window_id"]}' with PID $local_once_terminated_process_pid has been cancelled due to window termination."
			elif [[ -n "${request_cpu_limit_map["$local_once_terminated_process_pid"]}" ]]; then
				request_cpu_limit_map["$local_once_terminated_process_pid"]=''
				message --info "CPU limiting of process '${cache_process_name_map["$local_temp_terminated_window_id"]}' with PID $local_once_terminated_process_pid has been cancelled due to window termination."
			elif [[ -n "$local_once_terminated_section" && -n "${request_fps_limit_map["$local_once_terminated_section"]}" ]]; then
				request_fps_limit_map["$local_once_terminated_section"]=''
				message --info "FPS limiting of section '$local_once_terminated_section' has been cancelled due to termination of matching window(s)."
			fi
			# Unset data in cache related to terminated window
			message --verbose "Cached info about window with ID $local_temp_terminated_window_id and process '${cache_process_name_map["$local_temp_terminated_window_id"]}' with PID ${cache_process_pid_map["$local_temp_terminated_window_id"]} has been removed as it has been terminated."
			cache_mismatch_map["$local_once_terminated_process_pid"]=''
			cache_section_map["$local_once_terminated_process_pid"]=''
			cache_event_type_map["$local_temp_terminated_window_id"]=''
			cache_process_pid_map["$local_temp_terminated_window_id"]=''
			cache_process_name_map["$local_temp_terminated_window_id"]=''
			cache_process_executable_map["$local_temp_terminated_window_id"]=''
			cache_process_owner_map["$local_temp_terminated_window_id"]=''
			cache_process_command_map["$local_temp_terminated_window_id"]=''
		fi
	done
}

# Required to unset CPU/FPS limit for terminated windows and remove info about them from cache
handle_terminated_windows(){
	# Obtain list of terminated windows IDs
	local local_once_terminated_windows_ids="${event/'terminated: '/}" # Remove everything before including type name of list with windows IDs
	local local_once_terminated_windows_ids="${local_once_terminated_windows_ids/'; existing: '*/}" # Remove list of existing windows IDs
	# Obtain list of existing windows IDs
	local local_once_existing_windows_ids="${event/*'existing: '/}" # Remove everything including type name of list with windows IDs
	# Unset CPU/FPS limit for terminated window, useful mostly to unset FPS limit in MangoHud config, but ability to unset all limits saves my ass from being burned
	unset_terminated_limits
	# Remove cached info about terminated windows
	cache_collect_garbage
}