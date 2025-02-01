# Required to validate log
validate_log(){
	# Run multiple checks related to logging if '--log' option is specified
	if [[ -n "$log_is_passed" ]]; then
		unset log_is_passed
		# Exit with an error if '--log' option is specified without path to log file
		if [[ -z "$log" ]]; then
			message --error-opt "Option '--log' is specified without path to log file!"
			exit 1
		fi
		# Exit with an error if specified log file exists but not accessible for read-write operations
		if [[ -f "$log" ]] && ! check_rw "$log"; then
			message --error "Log file '$log' is not accessible for read-write operations!"
			exit 1
		elif [[ -e "$log" && ! -f "$log" ]]; then # Exit with an error if path to log exists and that is not a file
			message --error "Path '$log' specified in '--log' option is expected to be a file!"
			exit 1
		elif [[ -d "${log%/*}" ]] && ! check_rw "${log%/*}"; then # Exit with an error if log file directory is not accessible for read-write operations
			message --error "Directory of log file '$log' is not accessible for read-write operations!"
			exit 1
		fi
	fi
}