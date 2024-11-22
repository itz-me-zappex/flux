# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
	local local_temp_frozen_process_pid \
	local_once_frozen_processes_pids_array
	# Check for existence of freeze background process
	if check_pid_existence "${freeze_bgprocess_pid_map["$passed_process_pid"]}"; then
		# Attempt to terminate background process
		if ! kill "${freeze_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				message --warning "Unable to cancel delayed for ${config_key_delay_map["$passed_section"]} second(s) freezing of process '$passed_process_name' with PID $passed_process_pid!"
			fi
		else
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) freezing of process $passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
			fi
		fi
	else
		# Attempt to unfreeze target process
		if ! kill -CONT "$passed_process_pid" > /dev/null 2>&1; then
			message --warning "Unable to unfreeze process '$passed_process_name' with PID $passed_process_pid!"
		else
			message --info "Process '$passed_process_name' with PID $passed_process_pid has been unfrozen $passed_end_of_msg."
		fi
	fi
	# Remove PID from array
	for local_temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Skip current PID as I want remove it from array
		if [[ "$local_temp_frozen_process_pid" != "$passed_process_pid" ]]; then
			local_once_frozen_processes_pids_array+=("$local_temp_frozen_process_pid")
		fi
	done
	# Store updated info into array
	frozen_processes_pids_array=("${local_once_frozen_processes_pids_array[@]}")
	# Unset details about freezing
	is_frozen_pid_map["$passed_process_pid"]=''
	freeze_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
	local local_temp_cpulimit_bgprocess_pid \
	local_once_cpulimit_bgprocesses_pids_array
	# Attempt to terminate CPU limit background process
	if ! kill "$passed_signal" "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
		message --warning "Process '$passed_process_name' with PID $passed_process_pid cannot be CPU unlimited!"
	fi
	# Remove PID of 'cpulimit' background process from array
	for local_temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		# Skip interrupted background process as I want remove it from array
		if [[ "$local_temp_cpulimit_bgprocess_pid" != "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" ]]; then
			local_once_cpulimit_bgprocesses_pids_array+=("$local_temp_cpulimit_bgprocess_pid")
		fi
	done
	# Store updated info into array
	cpulimit_bgprocesses_pids_array=("${local_once_cpulimit_bgprocesses_pids_array[@]}")
	# Unset details about CPU limiting
	is_cpu_limited_pid_map["$passed_process_pid"]=''
	cpulimit_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate FPS limit background process or unset FPS limit if window becomes focused or terminated
unset_fps_limit(){
	local local_temp_fps_limited_pid \
	local_temp_fps_limited_section \
	local_once_fps_limited_sections_array
	# Check for existence of FPS limit background process
	if check_pid_existence "${fps_limit_bgprocess_pid_map["$passed_section"]}"; then
		# Terminate background process
		if ! kill "${fps_limit_bgprocess_pid_map["$passed_section"]}" > /dev/null 2>&1; then
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				message --warning "Unable to cancel delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS unlimiting of section '$passed_section'!"
			fi
		else
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS unlimiting of section '$passed_section' has been cancelled $passed_end_of_msg."
			fi
		fi
	fi
	# Set FPS from 'fps-focus' key
	if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_focus_map["$passed_section"]}"; then
		# Print message depending by FPS limit
		if [[ "${config_key_fps_focus_map["$passed_section"]}" == '0' ]]; then
			message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been FPS unlimited $passed_end_of_msg."
		else
			message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been limited to ${config_key_fps_focus_map["$passed_section"]} FPS $passed_end_of_msg."
		fi
	fi
	# Forget that process(es) matching with current section have been FPS limited previously
	for local_temp_fps_limited_pid in "${!fps_limited_section_map[@]}"; do
		if [[ "${fps_limited_section_map["$local_temp_fps_limited_pid"]}" == "$passed_section" ]]; then
			fps_limited_section_map["$local_temp_fps_limited_pid"]=''
		fi
	done
	# Remove section from array
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Skip FPS unlimited section as I want remove it from array
		if [[ "$local_temp_fps_limited_section" != "$passed_section" ]]; then
			local_once_fps_limited_sections_array+=("$local_temp_fps_limited_section")
		fi
	done
	# Store updated info into array
	fps_limited_sections_array=("${local_once_fps_limited_sections_array[@]}")
	# Unset details about FPS limiting
	is_fps_limited_section_map["$passed_section"]=''
	fps_limit_bgprocess_pid_map["$passed_section"]=''
}