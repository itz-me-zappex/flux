# Required to print info about focused/picked window in compatible with config way
print_template(){
	# Exit with an error if X11 session is invalid
	if ! x11_session_check; then
		if [[ "$1" =~ ^('--focus'|'-f')$ ]]; then
			message --error "Unable to get info about focused window, something is wrong with X11 session or window manager is EMHW incompatible!"
			exit 1
		else
			message --error "Unable to trigger window picker, something is wrong with X11 session or window manager is EMHW incompatible!"
			exit 1
		fi
	fi
	# Define way to obtain info about window depending by type of option
	case "$1" in
	--focus | -f )
		# Get output of 'xprop' tool containing window ID
		window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
		# Extract ID of focused window
		window_id="${window_id/*\# /}"
	;;
	--pick | -p )
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
	esac
	# Attempt to obtain process info
	get_process_info
	# Print template if possible, otherwise exit with an error
	case "$?" in
	'0' )
		echo "name = '"$process_name"'
command = '"$process_command"'
owner = '"$process_owner_username"'
"
	;;
	* )
		# Print error message depending by exit code
		case "$?" in
		'1' )
			message --error "Unable to obtain process PID of window ID $window_id! Probably window has been terminated before check."
		;;
		'2' )
			message --error "Unable to obtain info about process with PID $process_pid! Probably process has been terminated during check."
		;;
		'3' )
			message --error "Daemon has insufficient rights to interact with process '$process_name' with PID $process_pid!"
		esac
		return 1
	esac
}