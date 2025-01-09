# Required to unset limits and run command from 'lazy-exec-unfocus' config key on SIGTERM or SIGINT signal
actions_on_exit(){
	local local_temp_frozen_process_pid \
	local_temp_background_cpu_limit_pid \
	local_temp_fps_limited_section \
	local_temp_idle_process_pid \
	local_policy_option
	# Unfreeze processes
	for local_temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Check for existence of either delayed freezing background process or target process
		if check_pid_existence "${background_freeze_pid_map["$local_temp_frozen_process_pid"]}"; then
			# Terminate background process if exists
			kill "${background_freeze_pid_map["$local_temp_frozen_process_pid"]}" > /dev/null 2>&1
		elif check_pid_existence "$local_temp_frozen_process_pid"; then
			# Unfreeze process
			kill -CONT "$local_temp_frozen_process_pid" > /dev/null 2>&1
		fi
	done
	# Unset CPU limits
	for local_temp_background_cpu_limit_pid in "${background_cpu_limit_pids_array[@]}"; do
		# Terminate 'cpulimit' process which has been started by daemon if exists
		if check_pid_existence "$local_temp_background_cpu_limit_pid"; then
			kill "$local_temp_background_cpu_limit_pid" > /dev/null 2>&1
		fi
	done
	# Unset FPS limits
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Terminate process with delayed setting of FPS limit if exists
		if check_pid_existence "${background_fps_limit_pid_map["$local_temp_fps_limited_section"]}"; then
			kill "${background_fps_limit_pid_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
		fi
		# Set FPS from 'fps-focus' key to unset limit
		mangohud_fps_set "${config_key_mangohud_config_map["$local_temp_fps_limited_section"]}" "${config_key_mangohud_source_config_map["$local_temp_fps_limited_section"]}" "${config_key_fps_focus_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
	done
	# Restore scheduling policies
	for local_temp_idle_process_pid in "${idle_processes_pids_array[@]}"; do
		# Check for existence of either delayed setting of idle scheduling policy for process or target process
		if check_pid_existence "${background_sched_idle_pid_map["$local_temp_idle_process_pid"]}"; then
			kill "${background_sched_idle_pid_map["$local_temp_idle_process_pid"]}" > /dev/null 2>&1
		elif check_pid_existence "$local_temp_idle_process_pid"; then
			# Define how to restore scheduling policy depending by whether that is deadline or not
			if [[ "${sched_previous_policy_map["$local_temp_idle_process_pid"]}" != 'SCHED_DEADLINE' ]]; then
				# Define option depending by scheduling policy
				case "${sched_previous_policy_map["$local_temp_idle_process_pid"]}" in
				'SCHED_FIFO' )
					local_policy_option='--fifo'
				;;
				'SCHED_RR' )
					local_policy_option='--rr'
				;;
				'SCHED_OTHER' )
					local_policy_option='--other'
				;;
				'SCHED_BATCH' )
					local_policy_option='--batch'
				esac
				# Restore scheduling policy and priority for process
				chrt "$local_policy_option" --pid "${sched_previous_priority_map["$local_temp_idle_process_pid"]}" "$local_temp_idle_process_pid" > /dev/null 2>&1
			else
				# Restore deadline scheduling policy and its parameters for process
				chrt --deadline \
				--sched-runtime "${sched_previous_runtime_map["$local_temp_idle_process_pid"]}" \
				--sched-deadline "${sched_previous_deadline_map["$local_temp_idle_process_pid"]}" \
				--sched-period "${sched_previous_period_map["$local_temp_idle_process_pid"]}" \
				--pid 0 "$local_temp_idle_process_pid" > /dev/null 2>&1
			fi
		fi
	done
	# Execute command from 'lazy-exec-unfocus' if matching section for focused window is found and command is specified
	if [[ -n "$previous_section" && -n "${config_key_lazy_exec_unfocus_map["$previous_section"]}" ]]; then
		# Pass environment variables to interact with them using commands/scripts in 'lazy-exec-unfocus' config key
		# There is no need to pass '$FLUX_NEW_*' because there is no focus event and info about new window respectively
		# And yes, info about focused window becomes previous immediately after processing it, check event handling in 'main.sh'
		FLUX_WINDOW_ID="$previous_window_id" \
		FLUX_PROCESS_PID="$previous_process_pid" \
		FLUX_PROCESS_NAME="$previous_process_name" \
		FLUX_PROCESS_EXECUTABLE="$previous_process_executable" \
		FLUX_PROCESS_OWNER="$previous_process_owner" \
		FLUX_PROCESS_COMMAND="$previous_process_command" \
		passed_command_type='lazy' \
		passed_section="$previous_section" \
		passed_event_command="${config_key_lazy_exec_unfocus_map["$previous_section"]}" \
		passed_event='due to daemon termination' \
		exec_on_event
	fi
	# Remove lock file which prevents multiple instances of daemon from running
	if [[ -f "$lock_file" ]] && ! rm "$lock_file" > /dev/null 2>&1; then
		message --warning "Unable to remove lock file '$lock_file' which prevents multiple instances from running!"
	fi
	# Wait a bit to avoid printing message about daemon termination earlier than messages from 'background_*()' appear
	sleep 0.1
}