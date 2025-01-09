# Required to unset limits for terminated windows and remove info about them from cache
handle_terminated_windows(){
	local local_terminated_window_ids \
	local_terminated_window_ids \
	local_existing_window_ids \
	local_terminated_process_pid \
	local_terminated_section \
	local_terminated_process_name \
	local_temp_terminated_window_id \
	local_existing_process_pid \
	local_temp_existing_window_id \
	local_found
	# Obtain list of terminated window IDs
	local_terminated_window_ids="${event/'terminated: '/}" # Remove everything before including type name of list with window IDs
	local_terminated_window_ids="${local_terminated_window_ids/'; existing: '*/}" # Remove list of existing window IDs
	# Obtain list of existing window IDs
	local_existing_window_ids="${event/*'existing: '/}" # Remove everything including type name of list with window IDs
	# Unset limits for terminated windows
	for local_temp_terminated_window_id in $local_terminated_window_ids; do
		# Skip window ID if that is bad event or info about it does not exist in cache
		if [[ -n "${cache_event_type_map["$local_temp_terminated_window_id"]}" && "${cache_event_type_map["$local_temp_terminated_window_id"]}" != 'bad' ]]; then
			# Simplify access to PID of cached window info
			local_terminated_process_pid="${cache_process_pid_map["$local_temp_terminated_window_id"]}"
			# Simplify access to matching section of cached window info
			local_terminated_section="${cache_section_map["$local_terminated_process_pid"]}"
			# Simplify access to process name of cached window info
			local_terminated_process_name="${cache_process_name_map["$local_temp_terminated_window_id"]}"
			# Unset applied limits
			if [[ -n "${freeze_applied_map["$local_terminated_process_pid"]}" ]]; then # Unfreeze process if frozen
				passed_process_pid="$local_terminated_process_pid" \
				passed_section="$local_terminated_section" \
				passed_process_name="$local_terminated_process_name" \
				passed_end_of_msg='due to window termination' \
				unfreeze_process
			elif [[ -n "${cpu_limit_applied_map["$local_terminated_process_pid"]}" ]]; then # # Unset CPU limit if limited
				passed_process_pid="$local_terminated_process_pid" \
				passed_process_name="$local_terminated_process_name" \
				passed_signal='-SIGUSR2' \
				unset_cpu_limit
			elif [[ -n "$local_terminated_section" && -n "${is_fps_limited_section_map["$local_terminated_section"]}" ]]; then # Unset FPS limit if limited
				# Do not remove FPS limit if one of existing windows matches with the same section
				for local_temp_existing_window_id in $local_existing_window_ids; do
					# Simplify access to PID of terminated process using cache
					local_existing_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}"
					# Mark to not unset FPS limit if there is another window which matches with same section
					if [[ "${cache_section_map["$local_existing_process_pid"]}" == "$local_terminated_section" ]]; then
						local_found='1'
						break
					fi
				done
				# Unset FPS limit if there is no any matching windows except target
				if [[ -z "$local_found" ]]; then
					passed_section="$local_terminated_section" \
					passed_end_of_msg='due to matching window(s) termination' \
					unset_fps_limit
				fi
			fi
			# Restore scheduling policy if was changed
			if [[ -n "${is_sched_idle_map["$local_terminated_process_pid"]}" ]]; then
				passed_process_pid="$local_terminated_process_pid" \
				passed_section="$local_terminated_section" \
				passed_process_name="$local_terminated_process_name" \
				passed_end_of_msg='due to window termination' \
				unset_sched_idle
			fi
			# Unset limit request
			if [[ -n "${request_freeze_map["$local_terminated_process_pid"]}" ]]; then
				unset request_freeze_map["$local_terminated_process_pid"]
				message --info "Freezing of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window termination."
			elif [[ -n "${request_cpu_limit_map["$local_terminated_process_pid"]}" ]]; then
				unset request_cpu_limit_map["$local_terminated_process_pid"]
				message --info "CPU limiting of process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window termination."
			elif [[ -n "$local_terminated_section" && -n "${request_fps_limit_map["$local_terminated_section"]}" ]]; then
				unset request_fps_limit_map["$local_terminated_section"]
				message --info "FPS limiting of section '$local_terminated_section' has been cancelled due to termination of matching window(s)."
			fi
			# Unset 'SCHED_IDLE' request
			if [[ -n "${request_sched_idle_map["$local_terminated_process_pid"]}" ]]; then
				unset request_sched_idle_map["$local_terminated_process_pid"]
				message --info "Changing scheduling policy to idle for process '$local_terminated_process_name' with PID $local_terminated_process_pid has been cancelled due to window termination."
			fi
		fi
		# Check for event type before unset cache
		if [[ "${cache_event_type_map["$local_temp_terminated_window_id"]}" == 'bad' ]]; then
			# Unset only event type for bad window, otherwise bash will fail
			message --verbose "Cached info about bad window with ID $local_temp_terminated_window_id has been removed as it has been terminated."
			unset cache_event_type_map["$local_temp_terminated_window_id"]
		elif [[ "${cache_event_type_map["$local_temp_terminated_window_id"]}" == 'good' ]]; then
			# Unset data in cache related to terminated window
			message --verbose "Cached info about window with ID $local_temp_terminated_window_id and process '$local_terminated_process_name' with PID ${cache_process_pid_map["$local_temp_terminated_window_id"]} has been removed as it has been terminated."
			unset cache_mismatch_map["$local_terminated_process_pid"] \
			cache_section_map["$local_terminated_process_pid"] \
			cache_event_type_map["$local_temp_terminated_window_id"] \
			cache_process_pid_map["$local_temp_terminated_window_id"] \
			cache_process_name_map["$local_temp_terminated_window_id"] \
			cache_process_executable_map["$local_temp_terminated_window_id"] \
			cache_process_owner_map["$local_temp_terminated_window_id"] \
			cache_process_command_map["$local_temp_terminated_window_id"] \
			cache_process_owner_username_map["$local_temp_terminated_window_id"]
		fi
	done
}