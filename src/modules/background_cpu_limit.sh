# Apply CPU limit via 'cpulimit' tool on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_cpu_limit(){
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
		# Enforce 'SCHED_BATCH' to improve interval stability between interrupts
		chrt --batch --pid 0 "$local_cpulimit_pid" > /dev/null 2>&1
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