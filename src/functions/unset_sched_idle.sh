# Required to terminate background process with delayed setting of 'SCHED_IDLE' or restore scheduling policy for process if window becomes focused or terminated
unset_sched_idle(){
	local local_background_sched_idle_pid \
	local_policy_option \
	local_policy_name \
	local_config_delay

	# Simplify access to PID of background process with delayed setting of 'SCHED_IDLE'
	local_background_sched_idle_pid="${background_sched_idle_pid_map["$passed_process_pid"]}"

	# Check for existence of background process with delayed setting of 'SCHED_IDLE'
	if check_pid_existence "$local_background_sched_idle_pid"; then
		# Simplify access to delay config key value
		local_config_delay="${config_key_delay_map["$passed_section"]}"

		# Attempt to terminate background process
		kill "$local_background_sched_idle_pid" > /dev/null 2>&1

		# Print message if delay is not zero
		if [[ "$local_config_delay" != '0' ]]; then
			# Define message depending by 'kill' exit code
			if (( $? > 0 )); then
				message --warning "Unable to cancel delayed for $local_config_delay second(s) delayed setting of idle scheduling policy for process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
			else
				message --info "Delayed for $local_config_delay second(s) setting of idle scheduling policy for process $passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
			fi
		fi
	else
		# Define option and scheduling policy name depending by scheduling policy
		case "${sched_previous_policy_map["$passed_process_pid"]}" in
		'SCHED_FIFO' )
			local_policy_option='--fifo'
			local_policy_name="'FIFO' (first in first out)"
		;;
		'SCHED_RR' )
			local_policy_option='--rr'
			local_policy_name="'RR' (round robin)"
		;;
		'SCHED_OTHER' )
			local_policy_option='--other'
			local_policy_name="'other'"
		;;
		'SCHED_BATCH' )
			local_policy_option='--batch'
			local_policy_name="'batch'"
		;;
		'SCHED_DEADLINE' ) # Setting option unneeded because command for deadline differs greatly
			local_policy_name="'deadline'"
		esac

		# Define how to restore scheduling policy depending by whether that is deadline or not
		if [[ "${sched_previous_policy_map["$passed_process_pid"]}" == 'SCHED_DEADLINE' ]]; then
			# Restore deadline scheduling policy and its parameters for process
			chrt --deadline \
			--sched-runtime "${sched_previous_runtime_map["$passed_process_pid"]}" \
			--sched-deadline "${sched_previous_deadline_map["$passed_process_pid"]}" \
			--sched-period "${sched_previous_period_map["$passed_process_pid"]}" \
			--pid 0 "$passed_process_pid" > /dev/null 2>&1
		else
			# Attempt to restore scheduling policy and priority for process
			chrt "$local_policy_option" --pid "${sched_previous_priority_map["$passed_process_pid"]}" "$passed_process_pid" > /dev/null 2>&1
		fi

		# Print message depending by 'chrt' exit code
		if (( $? > 0 )); then
			message --warning "Unable to restore $local_policy_name scheduling policy for process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
		else
			message --info "Scheduling policy $local_policy_name has been restored for process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg."
		fi
		
		# Unset details about previous and applied idle cheduling policies
		unset sched_previous_policy_map["$passed_process_pid"] \
		sched_previous_priority_map["$passed_process_pid"] \
		sched_previous_runtime_map["$passed_process_pid"] \
		sched_previous_deadline_map["$passed_process_pid"] \
		sched_previous_period_map["$passed_process_pid"] \
		sched_idle_applied_map["$passed_process_pid"] \
		background_sched_idle_pid_map["$passed_process_pid"]
	fi
}