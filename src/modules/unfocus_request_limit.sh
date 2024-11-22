# Required to request CPU/FPS limit for process on unfocus
unfocus_request_limit(){
	# Do not apply limit if previous and current PIDs are exactly the same
	if [[ "$process_pid" != "$previous_process_pid" ]]; then
		# Avoid applying limit if owner has insufficient rights to do that
		if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit_map["$previous_section"]}" != '-1' ]]; then
			# To be frozen if previous window matches with section and 'cpu-limit' key specified to zero
			if [[ -n "$previous_section" && "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
				# Freeze process if it is not already frozen
				if [[ -z "${is_frozen_pid_map["$previous_process_pid"]}" ]]; then
					# Request freezing of process
					request_freeze_map["$previous_process_pid"]='1'
				fi
			elif [[ -n "$previous_section" ]] && (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )); then # To be CPU limited if previous window matches with section and 'cpu-limit' greater than zero
				# Apply CPU limit if it is not already applied
				if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
					# Request CPU limit for process
					request_cpu_limit_map["$previous_process_pid"]='1'
				fi
			elif [[ -n "$previous_section" && -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then # To be FPS limited if previous window matches with section and 'fps-limit' is specified
				# Associate section with PID of process, required to unset FPS limit for all matching windows on focus event or if they have been terminated
				fps_limited_section_map["$previous_process_pid"]="$previous_section"
				# Do not apply FPS limit if current window matches with exactly the same section as previous one
				if [[ "$section" != "$previous_section" ]]; then
					# Request FPS limit for process
					request_fps_limit_map["$previous_section"]='1'
				fi
			fi
		elif [[ -n "$previous_process_owner" ]]; then
			# I know that FPS limiting does not require root rights as it just should change 'fps_limit' value in MangoHud config
			# But who will run a game as root?
			# That is dumb and I am not looking for spend time on this
			message --warning "Unable to apply any kind of limit to process '$previous_process_name' with PID $previous_process_pid due to insufficient rights (process - $previous_process_owner, user - $UID)!"
		fi
	fi
}