# Required to minimize window on unfocus event
background_minimize(){
	# Wait a bit to give daemon a time to interrupt this subprocess in case unfocused window appears focused very quickly (e.g. because of changing window mode)
	sleep 0.1
	
	# Attempt to minimize window using xdotool, window ID should be converted to numeric value from hexadecimal
	if ! xdotool windowminimize "$(("$passed_window_id"))" > /dev/null 2>&1; then
		message --warning "Unable to forcefully minimize window '$passed_window_id' of process '$passed_process_name' with PID $passed_process_pid on unfocus event!"
	else
		message --info "Window '$passed_window_id' of process '$passed_process_name' with PID $passed_process_pid has been forcefully minimized on unfocus event."
	fi
}
