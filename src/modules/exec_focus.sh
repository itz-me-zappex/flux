# Required to execute command from 'exec-focus' key in config
exec_focus(){
	# Execute command from 'exec-focus' key if section matches, specified 'exec-focus' key and that is not lazy mode
	if [[ -n "${config_key_exec_focus_map["$section"]}" && -z "$lazy" ]]; then
		# Execute command from 'exec-focus' key
		passed_window_id="$window_id" \
		passed_process_pid="$process_pid" \
		passed_process_name="$process_name" \
		passed_process_executable="$process_executable" \
		passed_process_owner="$process_owner" \
		passed_process_command="$process_command" \
		passed_section="$section" \
		passed_event_command="${config_key_exec_focus_map["$section"]}" \
		passed_event='focus' \
		exec_on_event
	fi
}