# Required to track events related to window focus and changes in count of opened windows in 'event_source()' function
# Pretty complicated because of buggyness of 'xprop' tool which in spy mode prints events in random order, which sometimes repeats or not valid at all
# To fix that, despite performance impact I prefered to call 'xprop' tool manually every event to get proper info, because I did not find better way yet
# That is still is not perfect solution, because from time to time there is a chance to get multiple events because of one action like openning window from panel
# But at least that works and does not cause critical issues like previous event reading implementaions
xprop_wrapper(){
	local local_temp_xprop_event \
	local_previous_xprop_event \
	local_xprop_output \
	local_previous_xprop_output
	# Track events related to window focus and changes in count of opened windows
	while read -r local_temp_xprop_event; do
		# Skip event if it repeats for some reason
		if [[ -z "$local_previous_xprop_event" || "$local_temp_xprop_event" != "$local_previous_xprop_event" ]]; then
			# Obtain ID of focused window and list of opened windows
			local_xprop_output="$(xprop -root _NET_CLIENT_LIST_STACKING _NET_ACTIVE_WINDOW)"
			# Do not send event to 'event_source()' it it repeats for some reason
			if [[ -z "$local_previous_xprop_output" || "$local_xprop_output" != "$local_previous_xprop_output" ]]; then
				# Send event to 'event_source()'
				echo "$local_xprop_output"
				# Remember obtained info to compare it on next event and skip if it repeats
				local_previous_xprop_output="$local_xprop_output"
			fi
			# Remember current event to compare it next time
			local_previous_xprop_event="$local_temp_xprop_event"
		fi
	done < <(xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING 2>/dev/null)
}

# Required to extract window IDs from xprop events and make '--hot' option work
event_source(){
	local local_stacking_windows_id \
	local_focused_window_id \
	local_temp_stacking_window_id \
	local_temp_xprop_event \
	local_client_list_stacking_count \
	local_temp_client_list_stacking_column \
	local_previous_client_list_stacking_count \
	local_windows_ids \
	local_previous_windows_ids \
	local_once_terminated_windows_array \
	local_temp_previous_local_window_id \
	local_previous_active_window \
	local_previous_client_list_stacking \
	local_xprop_net_client_list_stacking \
	local_restart \
	local_list_is_not_blank \
	local_active_window_id
	# Run in loop to make daemon able restart event reading and apply limits again if list of stacking windows becomes blank
	while :; do
		unset local_list_is_not_blank
		# Wait for window appearance if list of windows IDs appears blank
		if [[ -n "$local_restart" || "$(xprop -root _NET_CLIENT_LIST_STACKING)" != '_NET_CLIENT_LIST_STACKING(WINDOW): window id # 0x'* ]]; then
			message --warning "Opened windows were not found, waiting for their appearance…"
			# Wait for windows appearance
			while read -r local_xprop_net_client_list_stacking; do
				# Break loop if list of stacking windows is not blank
				if [[ "$local_xprop_net_client_list_stacking" != '_NET_CLIENT_LIST_STACKING(WINDOW): window id #' ]]; then
					local_list_is_not_blank='1'
					break
				fi
			done < <(xprop -root -spy _NET_CLIENT_LIST_STACKING)
			unset local_xprop_net_client_list_stacking \
			local_restart
		else
			local_list_is_not_blank='1'
		fi
		# Do not do anything if 'xprop' process died and loop did not return '$local_list_is_not_blank'
		if [[ -n "$local_list_is_not_blank" ]]; then
			# Print windows IDs of opened windows to apply limits immediately if '--hot' option was passed
			if [[ -n "$hot" ]]; then
				# Extract IDs of opened windows
				local_stacking_windows_id="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null)"
				local_stacking_windows_id="${local_stacking_windows_id/* \# /}" # Remove everything before including '#'
				local_stacking_windows_id="${local_stacking_windows_id//\,/}" # Remove commas
				# Extract ID of focused window
				local_focused_window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
				local_focused_window_id="${local_focused_window_id/* \# /}" # Remove everything before including '#'
				# Print IDs of windows, but skip currently focused window as it should appear as first event when 'xprop' starts
				for local_temp_stacking_window_id in $local_stacking_windows_id; do
					if [[ "$local_temp_stacking_window_id" != "$local_focused_window_id" ]]; then
						echo "$local_temp_stacking_window_id"
					fi
				done
				unset local_stacking_windows_id \
				local_focused_window_id \
				local_temp_stacking_window_id
				# Print event to unset '--hot' option as it becomes useless from this moment
				echo 'unset_hot'
				unset hot \
				lazy
			fi
			# Read events from 'xprop' and print IDs of windows
			while read -r local_temp_xprop_event; do
				# Extract windows IDs from current event
				if [[ "$local_temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW):'* ]]; then
					local_windows_ids="${local_temp_xprop_event/*\# /}" # Remove everything before including '#'
					local_windows_ids="${local_windows_ids//\,/}" # Remove commas
				fi
				# Print window ID if that is responding event and it does not repeat
				if [[ "$local_temp_xprop_event" == '_NET_ACTIVE_WINDOW(WINDOW):'* && "$local_temp_xprop_event" != "$local_previous_active_window" ]]; then
					# Remember current event to compare it with new one and skip if it repeats
					local_previous_active_window="$local_temp_xprop_event"
					# Extract window ID from line and print it
					local_active_window_id="${local_temp_xprop_event/* \# /}"
					local_active_window_id="${local_active_window_id/,*/}"
					echo "$local_active_window_id"
					unset local_active_window_id
				elif [[ "$local_temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW):'* && "$local_temp_xprop_event" != "$local_previous_client_list_stacking" ]]; then # Get count of columns in output with list of stacking windows and skip event if it repeats
					# Count columns in event if that is not KDE Plasma (because of workaround, that type of detection of terminated windows does not work there)
					if [[ "$DESKTOP_SESSION" != 'plasmax11' ]]; then
						local_client_list_stacking_count='0'
						for local_temp_client_list_stacking_column in $local_temp_xprop_event; do
							(( local_client_list_stacking_count++ ))
						done
						unset local_temp_client_list_stacking_column
					fi
					# Compare count of columns and if previous event contains more columns (windows IDs) or workaround for KDE Plasma has been applied, then print event to refresh PIDs in arrays and cache
					if [[ "$DESKTOP_SESSION" == 'plasmax11' ]] || [[ -n "$local_previous_client_list_stacking_count" && "$local_previous_client_list_stacking_count" -gt "$local_client_list_stacking_count" ]]; then
						# Extract windows IDs from previous event
						local_previous_windows_ids="${local_previous_client_list_stacking/*\# /}" # Remove everything before including '#'
						local_previous_windows_ids="${local_previous_windows_ids//\,/}" # Remove commas
						# Find terminated windows
						for local_temp_previous_local_window_id in $local_previous_windows_ids; do
							# Skip existing window ID as I want to store IDs of terminated windows to array
							if [[ " $local_windows_ids " != *" $local_temp_previous_local_window_id "* ]]; then
								local_once_terminated_windows_array+=("$local_temp_previous_local_window_id")
							fi
						done
						unset local_temp_previous_local_window_id \
						local_previous_windows_ids
						# Print event with terminated and existing windows IDs if array with terminated windows IDs is not blank, required to check limit requests and unset cached info about terminated windows
						if [[ -n "${local_once_terminated_windows_array[*]}" ]]; then
							echo "terminated: ${local_once_terminated_windows_array[*]}; existing: $local_windows_ids"
							unset local_once_terminated_windows_array
						fi
					fi
					# Required to compare columns count in previous and current events
					if [[ "$DESKTOP_SESSION" != 'plasmax11' ]]; then
						local_previous_client_list_stacking_count="$local_client_list_stacking_count"
					fi
					# Required to find terminated windows comparing previous list with new one
					local_previous_client_list_stacking="$local_temp_xprop_event"
				fi
				# Print event to check requests and apply limits if that is ID of focused window
				if [[ "$local_temp_xprop_event" == '_NET_ACTIVE_WINDOW(WINDOW):'* && -n "$local_previous_client_list_stacking" ]]; then
					echo "check_requests: $local_windows_ids"
					unset local_windows_ids
				fi
				# Handle blank list of stacking windows
				if [[ "$local_temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW): window id #' ]]; then
					# Print event to set '--hot' and '--lazy' options in event reader (outside of 'pipe_read'), required to apply limits again in case list appears blank
					echo 'restart'
					# Set '--hot' and '--lazy' here to handle list of already opened windows
					hot='1'
					lazy='1'
					# Unset variables which storing info about previous event to avoid ignoring of focused window after restart
					unset local_previous_client_list_stacking_count \
					local_previous_windows_ids \
					local_temp_previous_local_window_id \
					local_previous_active_window \
					local_previous_client_list_stacking
					# Restart event reader
					local_restart='1'
					break
				fi
			done < <(xprop_wrapper)
			unset local_temp_xprop_event
		fi
		# Print event for safe exit if 'xprop' has been terminated
		if [[ -z "$local_restart" ]]; then
			message --warning "Process 'xprop' required to read X11 events has been terminated!"
			echo 'error'
			break
		fi
	done
}