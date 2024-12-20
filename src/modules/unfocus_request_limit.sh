# Required to request CPU/FPS limit for process on unfocus
unfocus_request_limit(){
	# Do not apply limit if previous and current PIDs are exactly the same or previous window does not match with any section
	if [[ "$process_pid" != "$previous_process_pid" && -n "$previous_section" ]]; then
		# To be frozen if 'cpu-limit' key specified to zero
		if [[ "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
			# Request freezing of process if it is not limited
			if [[ -z "${is_frozen_pid_map["$previous_process_pid"]}" ]]; then
				request_freeze_map["$previous_process_pid"]='1'
			fi
		elif (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )); then # To be CPU limited if 'cpu-limit' greater than zero
			# Request CPU limit for process if it is not limited
			if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
				request_cpu_limit_map["$previous_process_pid"]='1'
			fi
		elif [[ -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then # To be FPS limited if 'fps-unfocus' is specified
			# Associate section with PID of process, required to unset FPS limit for all matching windows on focus event or if they have been terminated
			fps_limited_section_map["$previous_process_pid"]="$previous_section"
			# Do not request FPS limit for process FPS limit if current window matches with exactly the same section as previous one
			if [[ "$section" != "$previous_section" ]]; then
				request_fps_limit_map["$previous_section"]='1'
			fi
		fi
	fi
}