# Required to execute command from 'exec-unfocus' and 'lazy-exec-unfocus' config keys
exec_unfocus(){
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
}