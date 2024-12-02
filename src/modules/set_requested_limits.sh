# Required to set CPU/FPS limits for requested windows
set_requested_limits(){
	local local_temp_existing_window_id \
	local_existing_windows_ids \
	local_existing_process_pid \
	local_existing_section
	# Get list of existing windows
	local_existing_windows_ids="${event/'check_requests: '/}"
	# Apply requested limits to existing windows
	for local_temp_existing_window_id in $local_existing_windows_ids; do
		# Skip cycle if window has bad event type of not at all
		if [[ -n "${cache_event_type_map["$local_temp_existing_window_id"]}" && "${cache_event_type_map["$local_temp_existing_window_id"]}" != 'bad' ]]; then
			# Simplify access to PID of cached window info
			local_existing_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}"
			# Simplify access to matching section of cached window info
			local_existing_section="${cache_section_map["$local_existing_process_pid"]}"
			# Check for request existence to apply one of limits
			if [[ -n "${request_freeze_map["$local_existing_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				request_freeze_map["$local_existing_process_pid"]=''
				# Freeze process
				passed_section="$local_existing_section" \
				passed_process_name="${cache_process_name_map["$local_temp_existing_window_id"]}" \
				passed_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}" \
				background_freeze_process &
				# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
				freeze_bgprocess_pid_map["$local_existing_process_pid"]="$!"
				# Mark process as frozen
				is_frozen_pid_map["$local_existing_process_pid"]='1'
				# Store PID to array to unfreeze process in case daemon interruption
				frozen_processes_pids_array+=("$local_existing_process_pid")
			elif [[ -n "${request_cpu_limit_map["$local_existing_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				request_cpu_limit_map["$local_existing_process_pid"]=''
				# Apply CPU limit
				passed_section="$local_existing_section" \
				passed_process_name="${cache_process_name_map["$local_temp_existing_window_id"]}" \
				passed_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}" \
				background_cpu_limit &
				# Store PID of background process to array to interrupt it in case daemon exit
				cpulimit_bgprocesses_pids_array+=("$!")
				# Associate PID of background process with PID of process to interrupt it on focus event
				cpulimit_bgprocess_pid_map["$local_existing_process_pid"]="$!"
				# Mark process as CPU limited
				is_cpu_limited_pid_map["$local_existing_process_pid"]='1'
			elif [[ -n "$local_existing_section" && -n "${request_fps_limit_map["$local_existing_section"]}" ]]; then
				# Unset request as it becomes useless
				request_fps_limit_map["$local_existing_section"]=''
				# Set FPS limit
				passed_section="$local_existing_section" \
				passed_process_pid="${cache_process_pid_map["$local_temp_existing_window_id"]}" \
				background_mangohud_fps_set &
				# Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
				fps_limit_bgprocess_pid_map["$local_existing_section"]="$!"
				# Mark section as FPS limited, required to check FPS limit existence on focus event
				is_fps_limited_section_map["$local_existing_section"]='1'
				# Store section to array, required to unset FPS limits on daemon termination
				fps_limited_sections_array+=("$local_existing_section")
			fi
		fi
	done
}