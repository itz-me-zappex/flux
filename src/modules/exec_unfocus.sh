# Required to execute command from 'exec-unfocus' and 'lazy-exec-unfocus' config keys
exec_unfocus(){
	# Export environment variables to interact with them using commands/scripts in 'exec-unfocus' and 'lazy-exec-unfocus' config keys
	export FLUX_NEW_WINDOW_ID="$window_id" \
	FLUX_NEW_PROCESS_PID="$process_pid" \
	FLUX_NEW_PROCESS_NAME="$process_name" \
	FLUX_NEW_PROCESS_EXECUTABLE="$process_executable" \
	FLUX_NEW_PROCESS_OWNER="$process_owner" \
	FLUX_NEW_PROCESS_COMMAND="$process_command" \
	FLUX_WINDOW_ID="$previous_window_id" \
	FLUX_PROCESS_PID="$previous_process_pid" \
	FLUX_PROCESS_NAME="$previous_process_name" \
	FLUX_PROCESS_EXECUTABLE="$previous_process_executable" \
	FLUX_PROCESS_OWNER="$previous_process_owner" \
	FLUX_PROCESS_COMMAND="$previous_process_command"
	# Check for previous section match and execute command from 'exec-unfocus' key if it has been specified
	if [[ -n "$previous_section" && -n "${config_key_exec_unfocus_map["$previous_section"]}" ]]; then
		passed_section="$previous_section" \
		passed_event_command="${config_key_exec_unfocus_map["$previous_section"]}" \
		passed_event='unfocus' \
		exec_on_event
	fi
	# Check for previous section match and execute command from 'lazy-exec-unfocus' key if it has been specified and if '--hot' has been unset by daemon after processing opened windows
	if [[ -n "$previous_section" && -n "${config_key_lazy_exec_unfocus_map["$previous_section"]}" && "$hot_is_unset" == '2' ]]; then
		passed_section="$previous_section" \
		passed_event_command="${config_key_lazy_exec_unfocus_map["$previous_section"]}" \
		passed_event='unfocus' \
		exec_on_event
	elif [[ "$hot_is_unset" == '1' ]]; then # Needed to avoid execution of lazy unfocus command immediately after unsetting '--hot' option
		hot_is_unset='2'
	fi
	# Unset exported variables
	unset FLUX_NEW_WINDOW_ID \
	FLUX_NEW_PROCESS_PID \
	FLUX_NEW_PROCESS_NAME \
	FLUX_NEW_PROCESS_EXECUTABLE \
	FLUX_NEW_PROCESS_OWNER \
	FLUX_NEW_PROCESS_COMMAND \
	FLUX_WINDOW_ID \
	FLUX_PROCESS_PID \
	FLUX_PROCESS_NAME \
	FLUX_PROCESS_EXECUTABLE \
	FLUX_PROCESS_OWNER \
	FLUX_PROCESS_COMMAND
}