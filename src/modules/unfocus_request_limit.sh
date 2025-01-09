# Required to request CPU/FPS limit for process on unfocus
unfocus_request_limit(){
	# Do not apply limit if previous and current PIDs are exactly the same or previous window does not match with any section
	if [[ "$process_pid" != "$previous_process_pid" && -n "$previous_section" ]]; then
		# Request limits to be applied on 'check_requests' internal event (from 'event_source()')
		if [[ "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
			# Request freezing of process if it is not limited
			if [[ -z "${freeze_applied_map["$previous_process_pid"]}" ]]; then
				request_freeze_map["$previous_process_pid"]='1'
			fi
		elif (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )); then
			# Request CPU limit for process if it is not limited
			if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
				request_cpu_limit_map["$previous_process_pid"]='1'
			fi
		elif [[ -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then
			# Request FPS limit for process FPS limit if current window does not match with exactly the same section as previous one
			if [[ "$section" != "$previous_section" ]]; then
				request_fps_limit_map["$previous_section"]='1'
			fi
		fi
		# Request 'SCHED_IDLE' scheduling policy for process if specified in config
		if [[ "${config_key_idle_map["$previous_section"]}" == '1' ]]; then
			# Do not request idle scheduling policy if CPU limit specified to zero because that is useless as process will not consume neither GPU nor CPU time
			if (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )) || [[ "${config_key_cpu_limit_map["$previous_section"]}" == '-1' ]]; then
				# Request idle scheduling policy if it is not set already
				if [[ -z "${is_sched_idle_map["$previous_process_pid"]}" ]]; then
					request_sched_idle_map["$previous_process_pid"]='1'
				fi
			else
				message --warning "Idle scheduling policy will not be set for process '$previous_process_name' with PID $previous_process_pid because CPU limit equal to zero!"
			fi
		fi
	fi
}