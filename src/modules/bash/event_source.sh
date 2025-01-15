# Required to get list of opened windows and print window IDs line by line if '--hot' option is specified
# To make daemon apply limits to them and run commands from 'exec-focus' and 'exec-unfocus' config keys
on_hot(){
	local local_event \
	local_events_count='0' \
	local_focused_window \
	local_opened_windows \
	local_temp_window
	# Do not do anything if '--hot' option is not specified
	if [[ -n "$hot" ]]; then
		# Get focused and opened windows
		while read -r local_event; do
			(( local_events_count++ ))
			# Collect events
			if (( local_events_count == 1 )); then
				local_focused_window="$local_event"
			else
				local_opened_windows="$local_event"
				break
			fi
		done < <("$flux_event_reader" 2>/dev/null)
		# Print opened windows info except focused one
		for local_temp_window in $local_opened_windows; do
			if [[ "$local_temp_window" != "$local_focused_window" ]]; then
				echo "$local_temp_window"
			fi
		done
	fi
	# Print event to unset '--hot' in main process as it becomes useless and set '$hot_is_unset' mark to make command from 'lazy-exec-unfocus' work
	echo 'unset_hot'
	unset hot
}

# Required to convert raw events into internal
event_reader(){
	local local_event \
	local_focused_window \
	local_opened_windows \
	local_events_count='0' \
	local_temp_window \
	local_previous_opened_windows \
	local_terminated_windows_array
	# Start event reading
	while read -r local_event; do
		(( local_events_count++ ))
		# Collect events
		if (( local_events_count == 1 )); then
			local_focused_window="$local_event"
			continue
		else
			local_opened_windows="$local_event"
		fi
		# Print info about focused window as event
		echo "$local_focused_window"
		# Find terminated windows and store those to an array
		for local_temp_window in $local_previous_opened_windows; do
			# Skip existing window id
			if [[ " $local_opened_windows " != *" $local_temp_window "* ]]; then
				local_terminated_windows_array+=("$local_temp_window")
			fi
		done
		unset local_temp_window
		# Print list of existing and terminated windows as event
		if [[ -n "${local_terminated_windows_array[@]}" ]]; then
			echo "terminated: ${local_terminated_windows_array[@]} ; existing: $local_opened_windows"
			unset local_terminated_windows_array
		fi
		# Remember opened windows to find terminated windows on next event
		local_previous_opened_windows="$local_opened_windows"
		# Print event with opened windows list as event to check requested limits
		echo "check_requests: $local_opened_windows"
		# Reset events count
		local_events_count='0'
	done < <("$flux_event_reader" 2>/dev/null)
	# Check for why loop has been breaked
	if [[ -z "$local_restart" ]]; then
		return 1
	fi
}

# Required to send events to 'flux' which reads events from this function
event_source(){
	# Print opened window IDs as events if '--hot' is specified
	on_hot
	# Handle events
	if ! event_reader; then
		message --warning "Event reader has been terminated!"
		echo 'error'
		break
	fi
}