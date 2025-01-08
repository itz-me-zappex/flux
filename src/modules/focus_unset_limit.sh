# Required to unset CPU/FPS limit for focused process
focus_unset_limit(){
	local local_end_of_msg='on focus event'
	# Unfreeze process if it has been frozen
	if [[ -n "${is_frozen_pid_map["$process_pid"]}" ]]; then
		passed_process_pid="$process_pid" \
		passed_section="$section" \
		passed_process_name="$process_name" \
		passed_end_of_msg="$local_end_of_msg" \
		unfreeze_process
	elif [[ -n "${is_cpu_limited_pid_map["$process_pid"]}" ]]; then # Unset CPU limit if has been applied
		# Unset CPU limit
		passed_process_pid="$process_pid" \
		passed_process_name="$process_name" \
		passed_signal='-SIGUSR1' \
		unset_cpu_limit
	elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then # Unset FPS limit or update target config on focus
		# Unset FPS limit
		passed_section="$section" \
		passed_end_of_msg="$local_end_of_msg" \
		unset_fps_limit
	fi
	# Restore scheduling policy for process if it has been changed to idle
	if [[ -n "${is_sched_idle_map["$process_pid"]}" ]]; then
		passed_process_pid="$process_pid" \
		passed_section="$section" \
		passed_process_name="$process_name" \
		passed_end_of_msg="$local_end_of_msg" \
		unset_sched_idle
	fi
}