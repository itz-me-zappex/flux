# Required to execute command from 'exec-unfocus' key in config
exec_unfocus(){
	# Check for previous section match, existence of command in 'exec-unfocus' key, status of '--lazy' and bool related to unsetting of '--lazy'
	if [[ -n "$previous_section" && -n "${config_key_exec_unfocus_map["$previous_section"]}" ]]; then
		# Execute command from 'exec-unfocus' key
		passed_section="$previous_section" \
		passed_event_command="${config_key_exec_unfocus_map["$previous_section"]}" \
		passed_event='unfocus' \
		exec_on_event
	fi
}