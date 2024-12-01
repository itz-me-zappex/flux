# Required to check for window(s) existence
check_windows(){
	local local_temp_windows_list
	# Check for existence of opened windows, if list appears blank, then wait for window(s) appearance
	if (( cycles_count > 1 )) || [[ "$(xprop -root _NET_CLIENT_LIST_STACKING)" != '_NET_CLIENT_LIST_STACKING(WINDOW): window id # 0x'* ]]; then
		message --warning "Opened windows were not found, waiting for their appearance…"
		# Wait for windows appearance
		while read -r local_temp_windows_list; do
			# Break loop if list with window IDs is not blank
			if [[ "$local_temp_windows_list" != '_NET_CLIENT_LIST_STACKING(WINDOW): window id #' ]]; then
				break
			fi
		done < <(xprop -root -spy _NET_CLIENT_LIST_STACKING)
	fi
}

# Required to get list of opened windows and print windows IDs line by line if '--hot' option is specified to make daemon apply limits to them and run commands from 'exec-focus' and 'exec-unfocus' config keys (if '--lazy' is not specified of course)
on_hot(){
	local local_stacking_windows \
	local_focused_window \
	local_temp_stacking_window
	# Do not do anything if '--hot' option is not specified
	if [[ -n "$hot" ]]; then
		# Extract IDs of opened windows
		local_stacking_windows="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null)"
		local_stacking_windows="${local_stacking_windows/* \# /}" # Remove everything before including '#'
		local_stacking_windows="${local_stacking_windows//\,/}" # Remove commas
		# Extract ID of focused window
		local_focused_window="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
		local_focused_window="${local_focused_window/* \# /}" # Remove everything before including '#'
		# Print IDs of windows, but skip currently focused window as it should appear as first event when 'xprop' starts
		for local_temp_stacking_window in $local_stacking_windows; do
			if [[ "$local_temp_stacking_window" != "$local_focused_window" ]]; then
				echo "$local_temp_stacking_window"
			fi
		done
		# Print event to unset '--hot' and '--lazy' options as those are becoming useless
		echo 'unset_hot'
		# Also useless since now
		unset hot \
		lazy
	fi
}

# Required to handle events from 'xprop' and print internal events
xprop_reader(){
	local local_event \
	local_previous_event \
	local_xprop_output \
	local_previous_xprop_output \
	local_temp_xprop_output_line \
	local_active_window \
	local_windows_list \
	local_restart \
	local_temp_window \
	local_previous_windows_list \
	local_temp_previous_window \
	local_previous_net_active_window \
	local_previous_net_client_list_stacking
	# Read output of 'xprop' line by line in realtime
	while read -r local_event; do
		# Do not do anything if event repeats
		if [[ "$local_previous_event" != "$local_event" ]]; then
			# Break loop if list of windows appears blank
			if [[ "$local_event" == '_NET_CLIENT_LIST_STACKING(WINDOW): window id #' ]]; then
				# Print event to prepare daemon for restart
				echo 'restart'
				# Set '--hot' and '--lazy' back to apply limits again as those have been unset
				hot='1'
				lazy='1'
				# Mark required to avoid loop breakage misunderstood as 'xprop' crash
				local_restart='1'
				# Break loop
				break
			fi
			# Get output of 'xprop' because events obtained in spy mode kinda buggy, e.g. it may print events in incorrect order and that breaks algorithm
			local_xprop_output="$(xprop -root _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING)"
			# Do not do anything if output of 'xprop' repeats
			if [[ "$local_previous_xprop_output" != "$local_xprop_output" ]]; then
				# Read output of 'xprop' line by line
				while read -r local_temp_xprop_output_line; do
					# Define actions depending by event type
					case "$local_temp_xprop_output_line" in
					'_NET_ACTIVE_WINDOW'* )
						# Do not do anything if event repeats
						if [[ "$local_previous_net_active_window" != "$local_temp_xprop_output_line" ]]; then
							# Remove everything before window ID itself
							local_active_window="${local_temp_xprop_output_line/* \# /}"
							# Remove everything after window ID, on XFCE4 for example this line contains '0x0' after comma
							local_active_window="${local_active_window/,*/}"
							# Print window ID as event
							echo "$local_active_window"
							# Remember event to compare it with next one and skip it if repeats
							local_previous_net_active_window="$local_temp_xprop_output_line"
						fi
					;;
					'_NET_CLIENT_LIST_STACKING'* )
						# Do not do anything if event repeats
						if [[ "$local_previous_net_client_list_stacking" != "$local_temp_xprop_output_line" ]]; then
							# Remove everything before list of windows IDs
							local_windows_list="${local_temp_xprop_output_line/*\# /}"
							# Remove commas which are used as separators
							local_windows_list="${local_windows_list//\,/}"
							# Find terminated windows and store them to array
							for local_temp_previous_window in $local_previous_windows_list; do
								# Skip existing windows IDs
								if [[ " $local_windows_list " != *" $local_temp_previous_window "* ]]; then
									local_terminated_windows+="$local_temp_previous_window "
								fi
							done
							unset local_temp_previous_window
							# Print list of terminated and existing windows as event if terminated windows have been detected
							if [[ -n "$local_terminated_windows" ]]; then
								echo "terminated: $local_terminated_windows; existing: $local_windows_list"
								unset local_terminated_windows
							fi
							# Send event with list of windows to check limit requests
							echo "check_requests: $local_windows_list"
							# Remember list of windows to use it for detection of terminated windows on next cycle
							local_previous_windows_list="$local_windows_list"
							# Remember event to compare it with next one and skip it if repeats
							local_previous_net_client_list_stacking="$local_temp_xprop_output_line"
						fi
					esac
				done <<< "$local_xprop_output"
				unset local_temp_xprop_output_line
				# Remember to skip action if output repeats on next cycle
				local_previous_xprop_output="$local_xprop_output"
			fi
			# Remember to skip event if repeats on next cycle
			local_previous_event="$local_event"
		fi
	done < <(xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING 2>/dev/null)
	# Check for why loop has been breaked
	if [[ -z "$local_restart" ]]; then
		return 1
	fi
}

# Required to send events to loop in 'flux' executable which reads events from this function
event_source(){
	local cycles_count='0'
	# Infinite loop required to make daemon able to restart event reading if list of windows becomes blank, happens on Cinnamon when DE restarts
	while :; do
		# Increase count of cycles, required for 'check_windows()' which checks for '$cycles_count' being greater than 2 to avoid running 'xprop' for check windows existence after restart of loop
		(( cycles_count++ ))
		# Check for window(s) existence
		check_windows
		# To avoid memory leak if loop restarts extremely often, no idea how and why that may happen
		cycles_count='1'
		# Print IDs of opened windows if '--hot' is specified
		on_hot
		# Handle events from 'xprop' tool
		if ! xprop_reader; then
			message --warning "Process 'xprop' required to read X11 events has been terminated!"
			echo 'error'
			break
		fi
	done
}