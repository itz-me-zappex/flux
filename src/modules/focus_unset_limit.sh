# Required to unset limit for focused process
focus_unset_limit(){
	local local_end_of_msg='on focus event'
	# Define type of limit which should be unset
	if [[ -n "${freeze_applied_map["$process_pid"]}" ]]; then
		# Unfreeze process if has been frozen
		passed_process_pid="$process_pid" \
		passed_section="$section" \
		passed_process_name="$process_name" \
		passed_end_of_msg="$local_end_of_msg" \
		unfreeze_process
	elif [[ -n "${cpu_limit_applied_map["$process_pid"]}" ]]; then
		# Unset CPU limit if has been applied
		passed_process_pid="$process_pid" \
		passed_process_name="$process_name" \
		passed_signal='-SIGUSR1' \
		unset_cpu_limit
	elif [[ -n "${config_key_mangohud_config_map["$section"]}" ]]; then
		# Unset FPS limit or update target config
		passed_section="$section" \
		passed_end_of_msg="$local_end_of_msg" \
		unset_fps_limit
	fi
	# Restore scheduling policy for process if it has been changed to idle
	if [[ -n "${sched_idle_applied_map["$process_pid"]}" ]]; then
		passed_process_pid="$process_pid" \
		passed_section="$section" \
		passed_process_name="$process_name" \
		passed_end_of_msg="$local_end_of_msg" \
		unset_sched_idle
	fi
}