# Required to set CPU/FPS limits for requested windows
set_requested_limits(){
	local local_temp_window_id \
	local_windows \
	local_process_pid \
	local_section \
	local_process_name \
	local_sched_info \
	local_temp_sched_info_line \
	local_deadline_parameters \
	local_temp_deadline_parameter \
	local_count \
	local_idle_cancelled \
	local_process_owner \
	local_temp_window \
	local_window_ids_array \
	local_test_sleep_pid
	# Get list of existing windows
	local_windows="${event/'check_requests: '/}"
	# Remove PIDs from list of existing windows
	for local_temp_window in $local_windows; do
		local_window_ids_array+=("${local_temp_window/'='*/}")
	done
	# Apply requested limits to existing windows
	for local_temp_window_id in "${local_window_ids_array[@]}"; do
		# Skip cycle if info about window is not cached
		if [[ -n "${cache_process_pid_map["$local_temp_window_id"]}" ]]; then
			# Simplify access to PID of cached window info
			local_process_pid="${cache_process_pid_map["$local_temp_window_id"]}"
			# Simplify access to matching section of cached window info
			local_section="${cache_section_map["$local_process_pid"]}"
			# Simplify access to process name of cached window info
			local_process_name="${cache_process_name_map["$local_temp_window_id"]}"
			# Simplify access to process owner UID of cached window info
			local_process_owner="${cache_process_owner_map["$local_temp_window_id"]}"
			# Minimize window if requested
			if [[ -n "${request_minimize_map["$local_process_pid"]}" ]]; then
				# Unset as it becomes useless
				unset request_minimize_map["$local_process_pid"]
				# Minimize window
				passed_window_id="$local_temp_window_id" \
				passed_process_name="$local_process_name" \
				passed_process_pid="$local_process_pid" \
				background_minimize &
			fi
			# Return an error if daemon has insufficient rights to apply limit (except FPS limit, that does not require interaction with process)
			if [[ "$local_process_owner" != "$UID" && "$UID" != '0' ]]; then
				# Check for limit requests which are requiring sufficient rights
				if [[ -n "${request_freeze_map["$local_process_pid"]}" ||
							-n "${request_cpu_limit_map["$local_process_pid"]}" ||
							-n "${request_sched_idle_map["$local_process_pid"]}" ]]; then
					# Decline requests
					unset request_freeze_map["$local_process_pid"] \
					request_cpu_limit_map["$local_process_pid"] \
					request_fps_limit_map["$local_section"] \
					request_sched_idle_map["$local_process_pid"]
					message --warning "Daemon has insufficient rights to apply limit for process '$local_process_name' with PID '$local_process_pid'!"
					return 1
				fi
			fi
			# Check for request existence to apply one of limits
			if [[ -n "${request_freeze_map["$local_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				unset request_freeze_map["$local_process_pid"]
				# Freeze process
				passed_section="$local_section" \
				passed_process_name="$local_process_name" \
				passed_process_pid="$local_process_pid" \
				passed_window_id="$local_temp_window_id" \
				background_freeze &
				# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
				background_freeze_pid_map["$local_process_pid"]="$!"
				# Mark process as frozen
				freeze_applied_map["$local_process_pid"]='1'
			elif [[ -n "${request_cpu_limit_map["$local_process_pid"]}" ]]; then
				# Unset request as it becomes useless
				unset request_cpu_limit_map["$local_process_pid"]
				# Apply CPU limit
				passed_section="$local_section" \
				passed_process_name="$local_process_name" \
				passed_process_pid="$local_process_pid" \
				passed_window_id="$local_temp_window_id" \
				background_cpu_limit &
				# Associate PID of background process with PID of process to interrupt it on focus event
				background_cpu_limit_pid_map["$local_process_pid"]="$!"
				# Mark process as CPU limited
				cpu_limit_applied_map["$local_process_pid"]='1'
			elif [[ -n "$local_section" && -n "${request_fps_limit_map["$local_section"]}" ]]; then
				# Unset request as it becomes useless
				unset request_fps_limit_map["$local_section"]
				# Set FPS limit
				passed_section="$local_section" \
				passed_process_pid="$local_process_pid" \
				passed_window_id="$local_temp_window_id" \
				background_fps_limit &
				# Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
				background_fps_limit_pid_map["$local_section"]="$!"
				# Mark section as FPS limited, required to check FPS limit existence on focus event
				fps_limit_applied_map["$local_section"]='1'
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
				# Attempt to change scheduling policy to idle and restore it to check whether daemon can restore it on focus or not
				if [[ -z "$sched_change_is_supported" ]]; then
					sleep 999 &
					local_test_sleep_pid="$!"
					chrt --idle --pid 0 "$local_test_sleep_pid" > /dev/null 2>&1
					if ! chrt --other --pid 0 "$local_test_sleep_pid" > /dev/null 2>&1; then
						sched_change_is_supported='0'
					else
						sched_change_is_supported='1'
					fi
					kill "$local_test_sleep_pid" > /dev/null 2>&1
				fi
				# Print warning if daemon has insufficient rights to set realtime/deadline scheduling policy, otherwise - change it to idle not set already
				if [[ "$sched_realtime_is_supported" == '0' && "${sched_previous_policy_map["$local_process_pid"]}" =~ ^('SCHED_RR'|'SCHED_FIFO')$ ]]; then
					message --warning "Daemon has insufficient rights to restore realtime scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to idle due to window $local_temp_window_id unfocus event cancelled!"
					local_idle_cancelled='1'
				elif [[ "$UID" != '0' && "${sched_previous_policy_map["$local_process_pid"]}" == 'SCHED_DEADLINE' ]]; then
					message --warning "Daemon has insufficient rights to restore deadline scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to idle due to window $local_temp_window_id unfocus event cancelled!"
					local_idle_cancelled='1'
				elif [[ "$sched_change_is_supported" == '0' ]]; then
					message --warning "Daemon has insufficient rights to restore scheduling policy for process '$local_process_name' with PID $local_process_pid, changing it to idle due to window $local_temp_window_id unfocus event cancelled!"
					local_idle_cancelled='1'
				elif [[ "${sched_previous_policy_map["$local_process_pid"]}" != 'SCHED_IDLE' ]]; then # Do not do anything if scheduling policy already idle
					# Change scheduling policy to 'SCHED_IDLE'
					passed_section="$local_section" \
					passed_process_name="$local_process_name" \
					passed_process_pid="$local_process_pid" \
					passed_window_id="$local_temp_window_id" \
					background_sched_idle &
					# Associate PID of background process with PID of process to interrupt it on focus event
					background_sched_idle_pid_map["$local_process_pid"]="$!"
					# Mark process as idle
					sched_idle_applied_map["$local_process_pid"]='1'
				else
					message --info "Process '$local_process_name' with PID $local_process_pid already has scheduling policy set to idle, changing it to idle on unfocus event cancelled."
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