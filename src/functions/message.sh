# Required to print messages to console, log and notifications
message(){
	local local_timestamp \
	local_log_prefix \
	local_notification_icon
	
	# Get timestamp if that behavior is allowed using '--timestamps' option
	if [[ -n "$timestamps" ]]; then
		local_timestamp="$(printf "%($timestamp_format)T") "
	fi
	# Print message depending by passed option
	case "$1" in
	--error )
		shift 1
		echo "$local_timestamp$prefix_error $*" >&2
		local_log_prefix="$prefix_error"
		local_notification_icon='emblem-error'
	;;
	--error-opt )
		# Setting '$local_log_prefix' is unneeded because this message will not be logged ever
		shift 1
		echo "$local_timestamp$prefix_error $*" >&2
		echo "$prefix_info Try 'flux --help' for more information."
	;;
	--info )
		shift 1
		if [[ -z "$quiet" ]]; then
			echo "$local_timestamp$prefix_info $*"
			local_log_prefix="$prefix_info"
			local_notification_icon='emblem-information'
		else
			return 0
		fi
	;;
	--verbose )
		shift 1
		if [[ -n "$verbose" ]]; then
			echo "$local_timestamp$prefix_verbose $*"
			local_log_prefix="$prefix_verbose"
			local_notification_icon='emblem-added'
		else
			return 0
		fi
	;;
	--warning )
		shift 1
		echo "$local_timestamp$prefix_warning $*" >&2
		local_log_prefix="$prefix_warning"
		local_notification_icon='emblem-warning'
	esac

	# Print message with timestamp to log file if responding option is specified and logging has been allowed before event reading
	if [[ -n "$allow_logging" ]]; then
		# Check log file for read-write access before store message to log
		if check_rw "$log"; then
			echo "$local_timestamp$local_log_prefix $*" >> "$log"
		else
			allow_logging='' message --warning "Unable to write message to log file '$log', recreate it or check read-write access!"
		fi
	fi

	# Print message as notification if '--notifications' option is specified and those have been allowed (before start event reading)
	if [[ -n "$allow_notifications" ]]; then
		notify-send --icon="$local_notification_icon" "$(echo "$*")"
	fi
}