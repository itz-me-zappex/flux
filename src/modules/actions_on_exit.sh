# Required to unset limits on SIGTERM and SIGINT signals
actions_on_exit(){
	local local_temp_frozen_process_pid \
	local_temp_cpulimit_bgprocess_pid \
	local_temp_fps_limited_section
	# Unfreeze processes
	for local_temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Check for existence of either delayed freezing background process or target process
		if check_pid_existence "${freeze_bgprocess_pid_map["$local_temp_frozen_process_pid"]}"; then
			# Terminate background process if exists
			kill "${freeze_bgprocess_pid_map["$local_temp_frozen_process_pid"]}" > /dev/null 2>&1
		elif check_pid_existence "$local_temp_frozen_process_pid"; then
			# Unfreeze process if exists
			kill -CONT "$local_temp_frozen_process_pid" > /dev/null 2>&1
		fi
	done
	# Unset CPU limits
	for local_temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		# Terminate 'cpulimit' process which has been started by daemon
		if check_pid_existence "$local_temp_cpulimit_bgprocess_pid"; then
			kill "$local_temp_cpulimit_bgprocess_pid" > /dev/null 2>&1
		fi
	done
	# Unset FPS limits
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Terminate background process if exists
		if check_pid_existence "${fps_limit_bgprocess_pid_map["$local_temp_fps_limited_section"]}"; then
			kill "${fps_limit_bgprocess_pid_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
		fi
		# Set FPS from 'fps-focus' key to remove limit
		mangohud_fps_set "${config_key_mangohud_config_map["$local_temp_fps_limited_section"]}" "${config_key_mangohud_source_config_map["$local_temp_fps_limited_section"]}" "${config_key_fps_focus_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
	done
	# Remove lock file which prevents multiple instances of daemon from running
	if [[ -f "$lock_file" ]] && ! rm "$lock_file" > /dev/null 2>&1; then
		message --warning "Unable to remove lock file '$lock_file' which prevents multiple instances from running!"
	fi
	# Wait a bit to avoid delayed messages from functions in background after termination
	sleep 0.1
}