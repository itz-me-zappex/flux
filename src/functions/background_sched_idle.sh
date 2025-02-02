# Required to change scheduling policy of process to 'SCHED_IDLE' on unfocus event, runs in background via '&'
background_sched_idle(){
	local local_delay

	# Simplify access to delay specified in config
	local_delay="${config_key_delay_map["$passed_section"]}"

	# Wait before change scheduling policy and notify user if delay is specified
	if [[ "$local_delay" != '0' ]]; then
		message --verbose "Scheduling policy of process '$passed_process_name' with PID $passed_process_pid will be changed to 'idle' after $local_delay second(s) due to window $passed_window_id unfocus event."
		sleep "$local_delay"
	fi
	
	# Check for process existence before changing scheduling policy
	if check_pid_existence "$passed_process_pid"; then
		# Attempt to change scheduling policy to 'SCHED_IDLE' for process
		if ! chrt --idle --pid 0 "$passed_process_pid"; then
			message --warning "Scheduling policy of process '$passed_process_name' with PID $passed_process_pid cannot be changed to 'idle' due to window $passed_window_id unfocus event!"
		else
			# Define message depending by whether delay is specified or not
			if [[ "$local_delay" == '0' ]]; then
				message --info "Scheduling policy of process '$passed_process_name' with PID $passed_process_pid has been changed to 'idle' due to window $passed_window_id unfocus event."
			else
				message --info "Scheduling policy of process '$passed_process_name' with PID $passed_process_pid has been changed to 'idle' due to window $passed_window_id unfocus event after $local_delay second(s)."
			fi
		fi
	else
		message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before changing scheduling policy to 'idle'!"
	fi
}