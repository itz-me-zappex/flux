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

# Required to execute command from 'exec-unfocus' key in config
exec_unfocus(){
	# Check for previous section match, existence of command in 'exec-unfocus' key, status of '--lazy' and bool related to unsetting of '--lazy'
	if [[ -n "$previous_section" && -n "${config_key_exec_unfocus_map["$previous_section"]}" && -z "$lazy" && -z "$lazy_is_unset" ]]; then
		# Execute command from 'exec-unfocus' key
		passed_window_id="$previous_window_id" \
		passed_process_pid="$previous_process_pid" \
		passed_process_name="$previous_process_name" \
		passed_process_executable="$previous_process_executable" \
		passed_process_owner="$previous_process_owner" \
		passed_process_command="$previous_process_command" \
		passed_section="$previous_section" \
		passed_event_command="${config_key_exec_unfocus_map["$previous_section"]}" \
		passed_event='unfocus' \
		exec_on_event
	elif [[ -n "$lazy_is_unset" ]]; then # Check for existence of variable which signals about unsetting of '--lazy' option
		# Unset variable which signals about unsetting of '--lazy' option, required to make 'exec-unfocus' commands work after hot run (using '--hot')
		unset lazy_is_unset
	fi
}