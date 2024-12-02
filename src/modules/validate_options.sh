# Required to validate options
validate_options(){
	local local_temp_prefix_type \
	local_is_passed \
	local_new_prefix
	# Exit with an error if verbose and quiet modes are specified at the same time
	if [[ -n "$verbose" && -n "$quiet" ]]; then
		message --error "Do not use verbose and quiet modes at the same time!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--lazy' option is specified without '--hot'
	if [[ -n "$lazy" && -z "$hot" ]]; then
		message --error "Do not use '--lazy' option without '--hot'!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if logging specific options are specified without '--log' option
	if [[ -z "$log_is_passed" ]] && [[ -n "$log_no_timestamps" || -n "$log_overwrite" || -n "$log_timestamp_is_passed" ]]; then
		message --error "Do not use options related to logging without '--log' options!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--log-timestamp' and '--log-no-timestamps' options are specified at the same time
	if [[ -n "$log_timestamp_is_passed" && -n "$log_no_timestamps" ]]; then
		message --error "Do not use '--log-timestamp' and '--log-no-timestamps' options at the same time!$advice_on_option_error"
		exit 1
	fi
	# Exit with an error if '--config' option is specified without a path to config file
	if [[ -n "$config_is_passed" && -z "$config" ]]; then
		message --error "Option '--config' is specified without path to config file!$advice_on_option_error"
		exit 1
	fi
	unset config_is_passed
	# Exit with error if at least one prefix option is specified without prefix
	for local_temp_prefix_type in error info verbose warning; do
		# Set proper variables names to obtain their values using indirectly
		local_is_passed="prefix_${local_temp_prefix_type}_is_passed"
		local_new_prefix="new_prefix_$local_temp_prefix_type"
		# Exit with an error if option is passed but value does not exist
		if [[ -n "${!local_is_passed}" && -z "${!local_new_prefix}" ]]; then
			message --info "Option '--prefix-$local_temp_prefix_type' is specified without prefix!$advice_on_option_error"
			exit 1
		fi
	done
}