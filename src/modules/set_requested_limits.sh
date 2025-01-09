# Required to set CPU/FPS limits for requested windows
set_requested_limits(){
	local local_temp_window_id \
	local_window_ids \
	local_process_pid \
	local_section \
	local_process_name \
	local_sched_info \
	local_temp_sched_info_line \
	local_deadline_parameters \
	local_temp_deadline_parameter \
	local_count \
	local_idle_cancelled
	# Get list of existing windows
	local_window_ids="${event/'check_requests: '/}"
	# Apply requested limits to existing windows
	for local_temp_window_id in $local_window_ids; do
		# Skip cycle if window has bad event type of not at all
		if [[ -n "${cache_event_type_map["$local_temp_window_id"]}" && "${cache_event_type_map["$local_temp_window_id"]}" != 'bad' ]]; then
			# Simplify access to PID of cached window info
			local_process_pid="${cache_process_pid_map["$local_temp_window_id"]}"
			# Simplify access to matching section of cached window info
			local_section="${cache_section_map["$local_process_pid"]}"
			# Simplify access to process name of cached window info
			local_process_name="${cache_process_name_map["$local_temp_window_id"]}"
			# Check for request existence to apply one of limits
			if [[ -n "${request_freeze_map["$local_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				unset request_freeze_map["$local_process_pid"]
				# Freeze process
				passed_section="$local_section" \
				passed_process_name="$local_process_name" \
				passed_process_pid="$local_process_pid" \
				background_freeze &
				# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
				freeze_bgprocess_pid_map["$local_process_pid"]="$!"
				# Mark process as frozen
				freeze_applied_map["$local_process_pid"]='1'
				# Store PID to array to unfreeze process in case daemon termination
				frozen_processes_pids_array+=("$local_process_pid")
			elif [[ -n "${request_cpu_limit_map["$local_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				unset request_cpu_limit_map["$local_process_pid"]
				# Apply CPU limit
				passed_section="$local_section" \
				passed_process_name="$local_process_name" \
				passed_process_pid="$local_process_pid" \
				background_cpu_limit &
				# Store PID of background process to array to interrupt it in case daemon exit
				cpulimit_bgprocesses_pids_array+=("$!")
				# Associate PID of background process with PID of process to interrupt it on focus event
				cpulimit_bgprocess_pid_map["$local_process_pid"]="$!"
				# Mark process as CPU limited
				is_cpu_limited_pid_map["$local_process_pid"]='1'
			elif [[ -n "$local_section" && -n "${request_fps_limit_map["$local_section"]}" ]]; then
				# Unset request as it becomes useless
				unset request_fps_limit_map["$local_section"]
				# Set FPS limit
				passed_section="$local_section" \
				passed_process_pid="$local_process_pid" \
				background_fps_limit &
				# Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
				fps_limit_bgprocess_pid_map["$local_section"]="$!"
				# Mark section as FPS limited, required to check FPS limit existence on focus event
				is_fps_limited_section_map["$local_section"]='1'
				# Store section to array, required to unset FPS limits on daemon termination
				fps_limited_sections_array+=("$local_section")
			fi
			# Check for 'SCHED_IDLE' scheduling policy request
			if [[ -n "${request_sched_idle_map["$local_process_pid"]}" ]]; then
				# Unset as it becomes useless
				unset request_sched_idle_map["$local_process_pid"]
				# Remember scheduling policy and priority before change it
				local_sched_info="$(chrt --pid "$local_process_pid")"
				# Read output of 'chrt' tool line-by-line and remember scheduling policy with priority of process to restore it on daemon exit or window focus event
				while read -r local_temp_sched_info_line; do
					# Define associative array which should store value depending by what line contains
					case "$local_temp_sched_info_line" in
					*'scheduling policy'* )
						# Extract scheduling policy name from string and remember it
						sched_previous_policy_map["$local_process_pid"]="${local_temp_sched_info_line/*': '/}"
					;;
					*'scheduling priority'* )
						# Extract scheduling priority value from string and remember it
						sched_previous_priority_map["$local_process_pid"]="${local_temp_sched_info_line/*': '/}"
					;;
					*'runtime/deadline/period parameters'* )
						# Extract parameters from string
						local_deadline_parameters="${local_temp_sched_info_line/*': '/}"
						# Remove slashes and remember 'SCHED_DEADLINE' parameters
						local_count='0'
						for local_temp_deadline_parameter in ${local_deadline_parameters//'/'/' '}; do
							(( local_count++ ))
							case "$local_count" in
							'1' )
								sched_previous_runtime_map["$local_process_pid"]="$local_temp_deadline_parameter"
							;;
							'2' )
								sched_previous_deadline_map["$local_process_pid"]="$local_temp_deadline_parameter"
							;;
							'3' )
								sched_previous_period_map["$local_process_pid"]="$local_temp_deadline_parameter"
							esac
						done
					esac
				done <<< "$local_sched_info"
				# Attempt to execute command with realtime scheduling policy to check whether daemon can restore it on focus or not
				if [[ -z "$sched_realtime_is_supported" && "${sched_previous_policy_map["$local_process_pid"]}" =~ ^('SCHED_RR'|'SCHED_FIFO')$ ]]; then
					if ! chrt --fifo 1 echo > /dev/null 2>&1; then
						sched_realtime_is_supported='0'
					else
						sched_realtime_is_supported='1'
					fi
				fi
				# Print warning if daemon has insufficient rights to set realtime/deadline scheduling policy, otherwise - change it to idle not set already
				if [[ "$sched_realtime_is_supported" == '0' && "${sched_previous_policy_map["$local_process_pid"]}" =~ ^('SCHED_RR'|'SCHED_FIFO')$ ]]; then
					message --warning "Daemon has insufficient rights to restore realtime scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to idle cancelled!"
					local_idle_cancelled='1'
				elif [[ "$UID" != '0' && "${sched_previous_policy_map["$local_process_pid"]}" == 'SCHED_DEADLINE' ]]; then
					message --warning "Daemon has insufficient rights to restore deadline scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to idle cancelled!"
					local_idle_cancelled='1'
				elif [[ "${sched_previous_policy_map["$local_process_pid"]}" != 'SCHED_IDLE' ]]; then # Do not do anything if scheduling policy already idle
					# Change scheduling policy to 'SCHED_IDLE'
					passed_section="$local_section" \
					passed_process_name="$local_process_name" \
					passed_process_pid="$local_process_pid" \
					background_sched_idle &
					# Associate PID of background process with PID of process to interrupt it on focus event
					sched_idle_bgprocess_pid_map["$local_process_pid"]="$!"
					# Mark process as idle
					is_sched_idle_map["$local_process_pid"]='1'
					# Store PID to array to restore scheduling policy of process in case daemon termination
					idle_processes_pids_array+=("$local_process_pid")
				else
					message --info "Process '$local_process_name' with PID $local_process_pid already has scheduling policy set to idle, changing it to idle cancelled."
					local_idle_cancelled='1'
				fi
				# Unset info about scheduling policy if changing it to idle is cancelled
				if [[ -n "$local_idle_cancelled" ]]; then
					unset sched_previous_policy_map["$local_process_pid"] \
					sched_previous_priority_map["$local_process_pid"] \
					sched_previous_runtime_map["$local_process_pid"] \
					sched_previous_deadline_map["$local_process_pid"] \
					sched_previous_period_map["$local_process_pid"]
				fi
			fi
		fi
	done
}