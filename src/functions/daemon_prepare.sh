# Required to prepare daemon for event reading
daemon_prepare(){
	local local_temp_prefix_type \
	local_variable_name

	# Exit with an error if lock file and process specified there exists
	lock_file='/tmp/flux-lock'
	if [[ -f "$lock_file" ]] && check_pid_existence "$(<"$lock_file")"; then
		message --error "Multiple instances are not allowed, make sure that daemon is not running before start, if you are really sure, then remove '$lock_file' file."
		exit 1
	else
		# Store PID to lock file to check its existence on next launch (if lock file still exists, e.g. after crash or SIGKILL)
		if ! echo "$$" > "$lock_file"; then
			message --error "Unable to create lock file '$lock_file' required to prevent multiple instances!"
			exit 1
		fi
	fi

	# Set specified timestamp format if exists
	if [[ -n "$new_timestamp_format" ]]; then
		timestamp_format="$new_timestamp_format"
		unset new_timestamp_format
	fi

	# Prepare for logging if log file is specified
	if [[ -n "$log" ]]; then
		# Allow logging before start event reading (checked by 'message()')
		allow_logging='1'

		# Remove content from log file if '--log-overwrite' option is specified or create a file if it does not exist
		if [[ -n "$log_overwrite" || ! -f "$log" ]]; then
			echo -n > "$log"
			unset log_overwrite
		fi
	fi

	# Set specified prefixes for messages if any
	for local_temp_prefix_type in error info verbose warning; do
		# Get name of variable with new prefix
		local_variable_name="new_prefix_$local_temp_prefix_type"

		# Check for existence of value in variable indirectly
		if [[ -n "${!local_variable_name}" ]]; then
			# Replace old prefix with new one
			eval "prefix_$local_temp_prefix_type"=\'"${!local_variable_name}"\'
			unset "new_prefix_$local_temp_prefix_type"
		fi
	done

	# Allow notifications if '--notifications' option is specified (checked by 'message()')
	if [[ -n "$notifications" ]]; then
		allow_notifications='1'
		unset notifications
	fi
	
	# Unset CPU and FPS limits on SIGTERM or SIGINT signals and print message about daemon termination
	trap 'safe_exit ; message --info "Flux has been terminated successfully." ; exit 0' SIGTERM SIGINT

	# Ignore user related signals to avoid bash's output when 'background_cpu_limit()' receives those
	trap '' SIGUSR1 SIGUSR2
}