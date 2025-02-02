# Required to validate options
validate_options(){
	local local_temp_prefix_type \
	local_is_passed \
	local_new_prefix

	# Exit with an error if verbose and quiet modes are specified at the same time
	if [[ -n "$verbose" && -n "$quiet" ]]; then
		message --error-opt "Do not use verbose and quiet modes at the same time!"
		exit 1
	fi

	# Exit with an error if '--log-overwrite' option is specified without '--log' option
	if [[ -z "$log_is_passed" && -n "$log_overwrite" ]]; then
		message --error-opt "Do not use '--log-overwrite' without '--log' option!"
		exit 1
	fi

	# Exit with an error if '--timestamp-format' is specified without '--timestamps'
	if [[ -n "$new_timestamp_format" && -z "$timestamps" ]]; then
		message --error "Do not use '--timestamp-format' without '--timestamps' option!"
		exit 1
	fi

	# Exit with an error if '--config' option is specified without a path to config file
	if [[ -n "$config_is_passed" && -z "$config" ]]; then
		message --error-opt "Option '--config' is specified without path to config file!"
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
			message --error-opt "Option '--prefix-$local_temp_prefix_type' is specified without prefix!"
			exit 1
		fi
	done

	# Exit with an error if '--timestamp-format' option is specified without timestamp format
	if [[ -n "$timestamp_is_passed" && -z "$new_timestamp_format" ]]; then
		message --error-opt "Option '--timestamp-format' is specified without timestamp format!"
		exit 1
	fi
	
	unset timestamp_is_passed
}