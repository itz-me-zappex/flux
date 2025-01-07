# Required to freeze process on unfocus event, runs in background via '&'
background_freeze_process(){
	# Wait before set limit and notify user if delay is specified
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