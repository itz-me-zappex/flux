# Required to set CPU limit using 'cpulimit' tool on unfocus event, runs in background via '&'
background_cpu_limit(){
	local local_cpulimit_pid \
	local_sleep_pid
	# Wait before set limit and notify user if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be CPU limited after ${config_key_delay_map["$passed_section"]} second(s) due to window $passed_window_id unfocus event."
		# Run in background to make subprocess interruptable
		sleep "${config_key_delay_map["$passed_section"]}" &
		# Remember PID of 'sleep' to terminate it if needed
		local_sleep_pid="$!"
		# Print relevant message on daemon termination and stop this subprocess
		trap 'message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to daemon termination." ; \
		kill "$local_sleep_pid"; \
		exit 0' SIGINT SIGTERM
		# Print relevant message on focus event and stop this subprocess
		trap 'message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window $passed_window_id focus event." ; \
		kill "$local_sleep_pid"; \
		exit 0' SIGUSR1
		# Print relevant message on target process termination and stop this subprocess
		trap 'message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window $passed_window_id termination." ; \
		kill "$local_sleep_pid"; \
		exit 0' SIGUSR2
		# Wait for 'sleep' termination
		wait "$local_sleep_pid"
	fi
	# Check for process existence before set CPU limit
	if check_pid_existence "$passed_process_pid"; then
		message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to ${config_key_cpu_limit_map["$passed_section"]}% due to window $passed_window_id unfocus event."
		# Run in background to make subprocess interruptable
		cpulimit --lazy --limit="$(( "${config_key_cpu_limit_map["$passed_section"]}" * cpu_threads ))" --pid="$passed_process_pid" > /dev/null 2>&1 &
		# Remember PID of 'cpulimit' to terminate it if needed
		local_cpulimit_pid="$!"
		# Enforce 'SCHED_BATCH' to improve interval stability between interrupts
		chrt --batch --pid 0 "$local_cpulimit_pid" > /dev/null 2>&1
		# Terminate 'cpulimit' process and print relevant message on daemon termination
		trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to daemon termination." ; \
		kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
		exit 0' SIGINT SIGTERM
		# Terminate 'cpulimit' process on focus event and print relevant message
		trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window $passed_window_id focus event." ; \
		kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
		exit 0' SIGUSR1
		# Terminate 'cpulimit' on termination of target and print relevant message
		trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window $passed_window_id termination." ; \
		kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
		exit 0' SIGUSR2
		# Wait for 'cpulimit' termination
		wait "$local_cpulimit_pid"
	else
		message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before applying CPU limit!"
	fi
}