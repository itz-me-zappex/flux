# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
	local local_temp_cpulimit_bgprocess_pid \
	local_cpulimit_bgprocesses_pids_array
	# Attempt to terminate CPU limit background process
	if ! kill "$passed_signal" "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
		message --warning "Process '$passed_process_name' with PID $passed_process_pid cannot be CPU unlimited!"
	fi
	# Remove PID of 'cpulimit' background process from array
	for local_temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		# Skip interrupted background process as I want remove it from array
		if [[ "$local_temp_cpulimit_bgprocess_pid" != "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" ]]; then
			local_cpulimit_bgprocesses_pids_array+=("$local_temp_cpulimit_bgprocess_pid")
		fi
	done
	# Store updated info into array
	cpulimit_bgprocesses_pids_array=("${local_cpulimit_bgprocesses_pids_array[@]}")
	# Unset details about CPU limiting
	unset is_cpu_limited_pid_map["$passed_process_pid"] \
	cpulimit_bgprocess_pid_map["$passed_process_pid"]
}