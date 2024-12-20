# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
	local local_temp_frozen_process_pid \
	local_frozen_processes_pids_array
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
			local_frozen_processes_pids_array+=("$local_temp_frozen_process_pid")
		fi
	done
	# Store updated info into array
	frozen_processes_pids_array=("${local_frozen_processes_pids_array[@]}")
	# Unset details about freezing
	is_frozen_pid_map["$passed_process_pid"]=''
	freeze_bgprocess_pid_map["$passed_process_pid"]=''
}