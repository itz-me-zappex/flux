# Required to stop 'background_minimize()' in case of daemon termination or focus event which appears earlier than 100ms
cancel_minimizing(){
	local local_background_minimize_pid
	# Simplify access to PID of background process
	local_background_minimize_pid="${background_minimize_pid_map["$passed_process_pid"]}"
	# Check for existence of background minimize process
	if check_pid_existence "$local_background_minimize_pid"; then
		# Attempt to terminate background process
		kill "$local_background_minimize_pid" > /dev/null 2>&1
		echo "Window minimization $passed_window_id of process '$passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
	fi
	# Forget background process PID
	unset background_minimize_pid_map["$passed_process_pid"]
}