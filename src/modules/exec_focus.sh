# Required to execute command from 'exec-focus' and 'lazy-exec-focus' config keys
exec_focus(){
	# Execute command from 'exec-focus' key if it has been specified
	if [[ -n "${config_key_exec_focus_map["$section"]}" ]]; then
		passed_section="$section" \
		passed_event_command="${config_key_exec_focus_map["$section"]}" \
		passed_event='focus' \
		exec_on_event
	fi
	# Execute command from 'lazy-exec-focus' key if it has been specified and if '--hot' has been unset by daemon after processing opened windows
	if [[ -n "${config_key_lazy_exec_focus_map["$section"]}" && -z "$hot" ]]; then
		passed_section="$section" \
		passed_event_command="${config_key_lazy_exec_focus_map["$section"]}" \
		passed_event='focus' \
		exec_on_event
	fi
}