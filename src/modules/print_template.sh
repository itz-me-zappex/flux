# Required to print info about focused/picked window in compatible with config way
print_template(){
	# Check for X11 session
	if ! x11_session_check; then
		# Fail if something wrong with X server
		fail='1'
	fi
	# Define way to obtain info about window depending by type of option
	case "$1" in
	--focus | -f )
		# Check for failure related to X server check
		if [[ -n "$fail" ]]; then
			# Exit with an error if something wrong with X server
			message --error "Unable to get info about focused window, something is wrong with X11 session!"
			exit 1
		else
			# Get output of 'xprop' tool containing window ID
			window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
			# Extract ID of focused window
			window_id="${window_id/*\# /}"
		fi
	;;
	--pick | -p )
		# Exit with an error if something wrong with X server
		if [[ -n "$fail" ]]; then
			message --error "Unable to trigger window picker, something is wrong with X11 session!"
			exit 1
		else
			# Get output of 'xwininfo' tool containing window ID
			if ! xwininfo_output="$(xwininfo 2>/dev/null)"; then
				message --error "Unable to grab cursor to pick a window!"
				exit 1
			else
				# Extract ID of focused window from output
				while read -r temp_xwininfo_output_line; do
					if [[ "$temp_xwininfo_output_line" == 'xwininfo: Window id: '* ]]; then
						window_id="${temp_xwininfo_output_line/xwininfo: Window id: /}"
						window_id="${window_id/ */}"
						break
					fi
				done <<< "$xwininfo_output"
				unset temp_xwininfo_output_line
			fi
		fi
	esac
	# Get process info and print it in compatible with config way
	if get_process_info; then
		echo "name = '"$process_name"'
executable = '"$process_executable"'
command = '"$process_command"'
owner = '"$process_owner_username"'
"
		exit 0
	else
		message --error "Unable to create template for window with ID $window_id as it does not report its PID!"
		exit 1
	fi
}