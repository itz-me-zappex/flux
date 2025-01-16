# Required to unset limits for terminated windows and remove info about them from cache
handle_terminated_windows(){
	local local_terminated_windows \
	local_terminated_window_ids_array \
	local_existing_windows \
	local_existing_window_ids_array \
	local_terminated_process_pid \
	local_terminated_section \
	local_terminated_process_name \
	local_temp_terminated_window_id \
	local_existing_process_pid \
	local_temp_existing_window_id \
	local_found \
	local_temp_terminated_window \
	local_temp_existing_window
	# Obtain list of terminated window IDs
	local_terminated_windows="${event/'terminated: '/}" # Remove everything before including type name of list with window IDs
	local_terminated_windows="${local_terminated_windows/' ; existing: '*/}" # Remove list of existing window IDs
	# Obtain list of existing window IDs
	local_existing_windows="${event/*'existing: '/}" # Remove everything including type name of list with window IDs
	# Remove PIDs from list of terminated windows
	for local_temp_terminated_window in $local_terminated_windows; do
		local_terminated_window_ids_array+=("${local_temp_terminated_window/'='*/}")
	done
	# Remove PIDs from list of existing windows
	for local_temp_existing_window in $local_terminated_windows; do
		local_existing_window_ids_array+=("${local_temp_existing_window/'='*/}")
	done
	# Unset limits for terminated windows
	for local_temp_terminated_window_id in "${local_terminated_window_ids_array[@]}"; do
		# Skip window ID if info about it does not exist in cache
		if [[ -n "${cache_process_pid_map["$local_temp_terminated_window_id"]}" ]]; then
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
			elif [[ -n "$local_terminated_section" && -n "${fps_limit_applied_map["$local_terminated_section"]}" ]]; then # Unset FPS limit if limited
				# Do not remove FPS limit if one of existing windows matches with the same section
				for local_temp_existing_window_id in "${local_existing_window_ids_array[@]}"; do
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
			if [[ -n "${sched_idle_applied_map["$local_terminated_process_pid"]}" ]]; then
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
			# Print message about window termination
			message --verbose "Window $local_temp_terminated_window_id of process $local_terminated_process_name with PID $local_terminated_process_pid has been terminated."
			# Unset data in cache related to terminated window
			unset cache_mismatch_map["$local_terminated_process_pid"] \
			cache_section_map["$local_terminated_process_pid"] \
			cache_process_pid_map["$local_temp_terminated_window_id"] \
			cache_process_name_map["$local_temp_terminated_window_id"] \
			cache_process_owner_map["$local_temp_terminated_window_id"] \
			cache_process_command_map["$local_temp_terminated_window_id"] \
			cache_process_owner_username_map["$local_temp_terminated_window_id"]
		fi
	done
}