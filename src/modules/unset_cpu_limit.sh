# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
	local local_temp_background_cpu_limit_pid \
	local_background_cpu_limit_pids_array
	# Attempt to terminate CPU limit background process
	kill "$passed_signal" "${background_cpu_limit_pid_map["$passed_process_pid"]}" > /dev/null 2>&1
	# Remove PID of 'cpulimit' background process from array
	for local_temp_background_cpu_limit_pid in "${background_cpu_limit_pids_array[@]}"; do
		# Skip interrupted background process as I want remove it from array
		if [[ "$local_temp_background_cpu_limit_pid" != "${background_cpu_limit_pid_map["$passed_process_pid"]}" ]]; then
			local_background_cpu_limit_pids_array+=("$local_temp_background_cpu_limit_pid")
		fi
	done
	# Store updated info into array
	background_cpu_limit_pids_array=("${local_background_cpu_limit_pids_array[@]}")
	# Unset details about CPU limiting
	unset cpu_limit_applied_map["$passed_process_pid"] \
	background_cpu_limit_pid_map["$passed_process_pid"]
}