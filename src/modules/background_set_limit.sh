# Freeze process on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_freeze_process(){
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be frozen after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}"
	fi
	# Check for process existence before freezing
	if check_pid_existence "$passed_process_pid"; then
		# Attempt to send 'SIGSTOP' signal to freeze process completely
		if ! kill -STOP "$passed_process_pid" > /dev/null 2>&1; then
			message --warning "Process '$passed_process_name' with PID $passed_process_pid cannot be frozen on unfocus event!"
		else
			message --info "Process '$passed_process_name' with PID $passed_process_pid has been frozen on unfocus event."
		fi
	else
		message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before freezing!"
	fi
}

# Apply CPU limit via 'cpulimit' tool on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_cpulimit(){
	local local_cpulimit_pid \
	local_sleep_pid
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be CPU limited after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}" &
		# Remember PID of 'sleep' sent into background, required to print message about cancelling CPU limit and terminate 'sleep' process on SIGINT/SIGTERM signal
		local_sleep_pid="$!"
		# Terminate 'sleep' process quietly on daemon termination
		trap 'kill "$local_sleep_pid" > /dev/null 2>&1' SIGINT SIGTERM
		# Terminate 'sleep' process on focus event and print relevant message (SIGUSR1)
		trap 'message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled on focus event." ; kill "$local_sleep_pid" > /dev/null 2>&1 ; return 0' SIGUSR1
		# Terminate 'sleep' process on termination of target process and print relevant message (SIGUSR2)
		trap 'message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window termination." ; kill "$local_sleep_pid" > /dev/null 2>&1 ; return 0' SIGUSR2
		wait "$local_sleep_pid"
	fi
	# Apply CPU limit if process still exists, otherwise throw warning
	if check_pid_existence "$passed_process_pid"; then
		message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to $(( ${config_key_cpu_limit_map["$passed_section"]} / cpu_threads ))% on unfocus event."
		# Apply CPU limit
		cpulimit --lazy --limit="${config_key_cpu_limit_map["$passed_section"]}" --pid="$passed_process_pid" > /dev/null 2>&1 &
		# Remember PID of 'cpulimit' sent into background, required to print message about CPU unlimiting and terminate 'cpulimit' process on SIGINT/SIGTERM signal
		local_cpulimit_pid="$!"
		# Terminate 'cpulimit' process quietly on daemon termination
		trap 'kill "$local_cpulimit_pid" > /dev/null 2>&1' SIGINT SIGTERM
		# Terminate 'cpulimit' process on focus event and print relevant message (SIGUSR1)
		trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited on focus event." ; kill "$local_cpulimit_pid" > /dev/null 2>&1 ; return 0' SIGUSR1
		# Terminate 'cpulimit' process on termination of target process and print relevant message (SIGUSR2)
		trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window termination." ; kill "$local_cpulimit_pid" > /dev/null 2>&1 ; return 0' SIGUSR2
		wait "$local_cpulimit_pid"
	else
		message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before applying CPU limit!"
	fi
}

# Set specified FPS on unfocus, required to run it on background to avoid stopping a whole code if delay specified
background_mangohud_fps_set(){
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		message --verbose "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' will be FPS limited after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}"
	fi
	# Check for process existence before set FPS limit
	if check_pid_existence "$passed_process_pid"; then
		# Attempt to change 'fps_limit' in specified MangoHud config file
		if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_unfocus_map["$passed_section"]}"; then
			message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS on unfocus event."
		fi
	else
		message --warning "Process matching with section '$passed_section' has been terminated before FPS limiting!"
	fi
}