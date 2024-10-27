#!/usr/bin/bash

# Required to print errors (redirect to stderr)
print_error(){
	echo -e "[e] $*" >&2
}

# Required to print warnings (redirect to stderr)
print_warn(){
	echo -e "[w] $*" >&2
}

# Required to print messages in verbose mode
print_verbose(){
	if [[ -n "$verbose" ]]; then
		echo -e "[v] $*"
	fi
}

# Required to print messages if quiet mode is not specified
print_info(){
	if [[ -z "$quiet" ]]; then
		echo -e "[i] $*"
	fi
}

# Required to exit with an error if option repeated
option_repeat_check(){
	if [[ -n "${!1}" ]]; then
		print_error "Option '$2' is repeated!$advice_on_option_error"
		exit 1
	fi
}

# Required to exit with an error if that is not a X11 session
x11_session_check(){
	# Fail if $DISPLAY does not match with `:[number]` and `:[number].[number]`
	# Or if $XDG_SESSION_TYPE is not equal to 'x11' (e.g. 'tty', 'wayland' etc.)
	if [[ ! "$DISPLAY" =~ ^\:[0-9]+(\.[0-9]+)?$ || "$XDG_SESSION_TYPE" != 'x11' ]]; then
		return 1
	elif ! xprop -root > /dev/null 2>&1; then
		# Fail if something is wrong with X11 session
		return 1
	fi
}

# Required to extract window IDs from xprop events and make '--hot' option work
xprop_event_reader(){
	local local_stacking_windows_id \
	local_focused_window_id \
	local_temp_stacking_window_id \
	local_window_id \
	local_previous_window_id \
	local_temp_xprop_event \
	local_client_list_stacking_count \
	local_temp_client_list_stacking_column \
	local_previous_client_list_stacking_count \
	local_windows_ids \
	local_previous_windows_ids \
	local_once_terminated_windows_array \
	local_temp_previous_local_window_id
	# Print windows IDs of opened windows to apply limits immediately if '--hot' option was passed
	if [[ -n "$hot" ]]; then
		# Extract IDs of opened windows
		local_stacking_windows_id="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null)"
		if [[ "$local_stacking_windows_id" != '_NET_CLIENT_LIST_STACKING:  no such atom on any window.' ]]; then
			local_stacking_windows_id="${local_stacking_windows_id/* \# /}" # Remove everything before including '#'
			local_stacking_windows_id="${local_stacking_windows_id//\,/}" # Remove commas
		else
			# Print event for safe exit if cannot obtain list of stacking windows
			print_warn "Unable to get list of stacking windows!"
			echo 'exit'
		fi
		# Extract ID of focused window
		local_focused_window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
		if [[ "$local_focused_window_id" != '_NET_ACTIVE_WINDOW:  no such atom on any window.' ]]; then
			local_focused_window_id="${local_focused_window_id/* \# /}" # Remove everything before including '#'
		else
			# Print event for safe exit if cannot obtain ID of focused window
			print_warn "Unable to get ID of focused window!"
			echo 'exit'
		fi
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
		echo 'nohot'
	fi
	# Print event for unset '--lazy' option before read events, otherwise focus and unfocus commands will not work
	if [[ -n "$lazy" ]]; then
		echo 'nolazy'
	fi
	# Read events from 'xprop' and print IDs of windows
	while read -r local_temp_xprop_event; do
		# Get window ID
		if [[ "$local_temp_xprop_event" == '_NET_ACTIVE_WINDOW(WINDOW):'* ]]; then
			# Extract ID from line
			local_window_id="${local_temp_xprop_event/* \# /}"
			# Skip event if window ID is exactly the same as previous one, workaround required for some buggy WMs
			if [[ "$local_window_id" == "$local_previous_window_id" ]]; then
				continue
			else
				echo "$local_window_id"
				# Remember ID to compare it with new one, if ID is exactly the same, then event will be skipped
				local_previous_window_id="$local_window_id"
			fi
		elif [[ "$local_temp_xprop_event" != "$local_previous_client_list_stacking" && "$local_temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW):'* ]]; then # Get count of columns in output with list of stacking windows and skip event if it repeats
			# Count columns in event
			local_client_list_stacking_count='0'
			for local_temp_client_list_stacking_column in $local_temp_xprop_event; do
				(( local_client_list_stacking_count++ ))
			done
			unset local_temp_client_list_stacking_column
			# Extract windows IDs from current event
			local_windows_ids="${local_temp_xprop_event/*\# /}" # Remove everything before including '#'
			local_windows_ids="${local_windows_ids//\,/}" # Remove commas
			# Compare count of columns and if previous event contains more columns (windows IDs), then print event to refresh PIDs in arrays and cache
			if [[ -n "$local_previous_client_list_stacking_count" ]] && (( local_previous_client_list_stacking_count > local_client_list_stacking_count )); then
				# Extract windows IDs from previous event
				local_previous_windows_ids="${local_previous_client_list_stacking/*\# /}" # Remove everything before including '#'
				local_previous_windows_ids="${local_previous_windows_ids//\,/}" # Remove commas
				# Find terminated windows
				for local_temp_previous_local_window_id in $local_previous_windows_ids; do
					if [[ " $local_windows_ids " != *" $local_temp_previous_local_window_id "* ]]; then
						local_once_terminated_windows_array+=("$local_temp_previous_local_window_id")
					fi
				done
				unset local_temp_previous_local_window_id
				# Print event with terminated (required to remove info about them from cache) and existing (required to determine whether all windows matching woth section are closed or not in order to remove FPS limit) windows IDs
				echo "refresh -- terminated: ${local_once_terminated_windows_array[*]} existing: $local_windows_ids"
				unset local_once_terminated_windows_array
			fi
			# Required to compare columns count in previous and current events
			local_previous_client_list_stacking_count="$local_client_list_stacking_count"
			# Required to skip exactly the same event, happens when window opens from taskbar on Cinnamon DE for example
			local_previous_client_list_stacking="$local_temp_xprop_event"
		fi
		# Print event to apply limits to requested windows if any
		if [[ "$local_temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW):'* ]]; then
			echo "check_requests: $local_windows_ids"
		fi
	done < <(xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING 2>&1)
	unset local_temp_xprop_event
	# Print event for safe exit if 'xprop' has been terminated
	print_warn "Process 'xprop' required to read X11 events has been terminated!"
	echo 'exit'
}

# Required to run commands on focus and unfocus events
exec_on_event(){
	# Export environment variables to interact with them using commands/scripts in 'focus'/'unfocus' key
	export FLUX_WINDOW_ID="$passed_window_id" \
	FLUX_PROCESS_PID="$passed_process_pid" \
	FLUX_PROCESS_NAME="$passed_process_name" \
	FLUX_PROCESS_EXECUTABLE="$passed_process_executable" \
	FLUX_PROCESS_OWNER="$passed_process_owner" \
	FLUX_PROCESS_COMMAND="$passed_process_command"
	# Run command on event
	nohup setsid bash -c "$passed_event_command" > /dev/null 2>&1 &
	# Unset environment variables exported above
	unset FLUX_WINDOW_ID \
	FLUX_PROCESS_PID \
	FLUX_PROCESS_NAME \
	FLUX_PROCESS_EXECUTABLE \
	FLUX_PROCESS_OWNER \
	FLUX_PROCESS_COMMAND
	print_verbose "Command '$passed_event_command' from section '$passed_section' has been executed on $passed_event event."
}

# Required to get process info from cache in 'get_process_info' function
cache_get_process_info(){
	process_pid="${cache_process_pid_map["$passed_window_id"]}"
	process_name="${cache_process_name_map["$passed_window_id"]}"
	process_executable="${cache_process_executable_map["$passed_window_id"]}"
	process_owner="${cache_process_owner_map["$passed_window_id"]}"
	process_command="${cache_process_command_map["$passed_window_id"]}"
}

# Required to get process info using window ID
get_process_info(){
	local local_temp_status_line \
	local_column_count='0' \
	local_status_column \
	local_matching_window_id \
	local_temp_cached_window_id
	# Use cache of window info if exists
	if [[ "${cache_event_type_map["$window_id"]}" == 'good' ]]; then
		# Get process info from cache
		passed_window_id="$window_id" cache_get_process_info
		print_verbose "Cache has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
	elif [[ -z "${cache_event_type_map["$window_id"]}" ]]; then # Extract process info if it is not cached
		# Attempt to obtain output with PID
		if ! process_pid="$(xprop -id "$window_id" _NET_WM_PID 2>/dev/null)" || [[ "$process_pid" == '_NET_WM_PID:  not found.' ]]; then
			cache_event_type_map["$window_id"]='bad'
			process_pid=''
		else
			# Extract PID from output
			process_pid="${process_pid/*= /}" # Remove everything before including '= '
		fi
		# Extract info about process if that is not bad event
		if [[ "${cache_event_type_map["$window_id"]}" != 'bad' ]]; then
			# Attempt to find cache with info about the same process
			for local_temp_cached_window_id in "${!cache_process_pid_map[@]}"; do
				# Compare parent PID with PID of process
				if [[ "${cache_process_pid_map[$local_temp_cached_window_id]}" == "$process_pid" ]]; then
					# Remember window ID of matching process
					local_matching_window_id="$local_temp_cached_window_id"
					break
				fi
			done
			# Check for match of cached PID info to define a way how to obtain process info
			if [[ -n "$local_matching_window_id" ]]; then
				# Get process info using cache of parent window
				passed_window_id="$local_matching_window_id" cache_get_process_info
				print_verbose "Cache of parent window with ID $local_matching_window_id has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
			else
				# Extract name of process
				process_name="$(<"/proc/$process_pid/comm")"
				# Extract executable path of process
				process_executable="$(readlink "/proc/$process_pid/exe")"
				# Extract effective UID of process
				while read -r local_temp_status_line; do
					# Find a line which contains UID
					if [[ "$local_temp_status_line" == 'Uid:'* ]]; then
						# Find 3rd column, which effective UID is
						for local_status_column in $local_temp_status_line; do
							# Current column number
							(( local_column_count++ ))
							# Remember UID and break cycle if that is effective UID
							if (( local_column_count == 3 )); then
								process_owner="$local_status_column"
								break
							fi
						done
					fi
				done < "/proc/$process_pid/status"
				# I did not get how to do that using built-in bash options
				# Extract command of process and replace '\0' (used as separator between options) with spaces
				process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
				# Remove last space because '\0' (which is replaced with space) is last symbol too
				process_command="${process_command/%\ /}"
				print_verbose "Obtained from '/proc/$process_pid' info about window with ID $window_id and process '$process_name' with PID $process_pid has been cached."
			fi
			# Store info about window and process to cache
			cache_event_type_map["$window_id"]='good'
			cache_process_pid_map["$window_id"]="$process_pid"
			cache_process_name_map["$window_id"]="$process_name"
			cache_process_executable_map["$window_id"]="$process_executable"
			cache_process_owner_map["$window_id"]="$process_owner"
			cache_process_command_map["$window_id"]="$process_command"
		else
			return 1
		fi
	else
		return 1
	fi
}

# Required to change FPS limit in specified MangoHud config
mangohud_fps_set(){
	local local_temp_config_line \
	local_config_content \
	local_new_config_content \
	local_config="$1" \
	local_fps_to_set="$2" \
	local_fps_limit_is_changed \
	local_temp_column \
	local_temp_line_buffer \
	local_once_ignore_numbers
	# Check if config file exists before continue in case it has been removed
	if [[ -f "$local_config" ]]; then
		# Attempt to read MangoHud config file
		if check_rw "$local_config"; then
			local_config_content="$(<"$local_config")"
		else
			print_warn "Unable to read MangoHud config file '$local_config'!"
			return 1
		fi
		# Replace 'fps_limit' value in config if exists
		while read -r local_temp_config_line || [[ -n "$local_temp_config_line" ]]; do
			# Find 'fps_limit' line, regexp means 'fps_limit[space(s)?]=[space(s)?][integer][anything else]'
			if [[ "$local_temp_config_line" =~ ^fps_limit([[:space:]]+)?=([[:space:]]+)?[0-9]+* ]]; then
				# Find and replace FPS limit value in line by splitting it to columns, shell parameter expansion replaces spaces with regexp to make it easier to restore them after changing value
				for local_temp_column in ${local_temp_config_line//' '/' [[:space:]] '}; do
					# Define type of column, regexp means any integer
					if [[ "$local_temp_column" =~ ^[0-9]+$ && -z "$local_once_ignore_numbers" ]]; then
						local_temp_line_buffer+="$local_fps_to_set"
						local_once_ignore_numbers='1'
					else
						local_temp_line_buffer+="$local_temp_column"
					fi
				done
				# Set specified FPS limit, shell parameter expansion replaces regexp with regular spaces
				local_new_config_content+="${local_temp_line_buffer//'[[:space:]]'/' '}\n"
				# Set mark which signals about successful setting of FPS limit
				local_fps_limit_is_changed='1'
			else
				# Add line to processed text
				local_new_config_content+="$local_temp_config_line\n"
			fi
		done <<< "$local_config_content"
		# Pass key with FPS limit if line does not exist in config
		if check_rw "$local_config"; then
			# Check whether FPS limit has been set or not
			if [[ -z "$local_fps_limit_is_changed" ]]; then
				# Pass key with FPS limit if line does not exist in config
				echo "fps_limit = $local_fps_to_set" >> "$local_config"
			else
				# Pass config content if FPS has been already changed
				echo -e "$local_new_config_content" > "$local_config"
			fi
		else
			print_warn "Unable to modify MangoHud config file '$local_config'!"
			return 1
		fi
	else
		print_warn "MangoHud config file '$local_config' was not found!"
		return 1
	fi
}

# Freeze process on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_freeze_process(){
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		print_verbose "Process '$passed_process_name' with PID $passed_process_pid will be frozen after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}"
	fi
	# Check for process existence before freezing
	if check_pid_existence "$passed_process_pid"; then
		# Attempt to send 'SIGSTOP' signal to freeze process completely
		if ! kill -STOP "$passed_process_pid" > /dev/null 2>&1; then
			print_warn "Process '$passed_process_name' with PID $passed_process_pid cannot be frozen on unfocus event!"
		else
			print_info "Process '$passed_process_name' with PID $passed_process_pid has been frozen on unfocus event."
		fi
	else
		print_warn "Process '$passed_process_name' with PID $passed_process_pid has been terminated before freezing!"
	fi
}

# Apply CPU limit via 'cpulimit' tool on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_cpulimit(){
	local local_cpulimit_pid \
	local_sleep_pid
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		print_verbose "Process '$passed_process_name' with PID $passed_process_pid will be CPU limited after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}" &
		# Remember PID of 'sleep' sent into background, required to print message about cancelling CPU limit and terminate 'sleep' process on SIGINT/SIGTERM signal
		local_sleep_pid="$!"
		# Terminate 'sleep' process quietly on daemon termination
		trap 'kill "$local_sleep_pid" > /dev/null 2>&1' SIGINT SIGTERM
		# Terminate 'sleep' process on focus event and print relevant message (SIGUSR1)
		trap 'print_info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled on focus event." ; kill "$local_sleep_pid" > /dev/null 2>&1 ; return 0' SIGUSR1
		# Terminate 'sleep' process on termination of target process and print relevant message (SIGUSR2)
		trap 'print_info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window termination." ; kill "$local_sleep_pid" > /dev/null 2>&1 ; return 0' SIGUSR2
		wait "$local_sleep_pid"
	fi
	# Apply CPU limit if process still exists, otherwise throw warning
	if check_pid_existence "$passed_process_pid"; then
		print_info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to $(( ${config_key_cpu_limit_map["$passed_section"]} / cpu_threads ))% on unfocus event."
		# Apply CPU limit
		cpulimit --lazy --limit="${config_key_cpu_limit_map["$passed_section"]}" --pid="$passed_process_pid" > /dev/null 2>&1 &
		# Remember PID of 'cpulimit' sent into background, required to print message about CPU unlimiting and terminate 'cpulimit' process on SIGINT/SIGTERM signal
		local_cpulimit_pid="$!"
		# Terminate 'cpulimit' process quietly on daemon termination
		trap 'kill "$local_cpulimit_pid" > /dev/null 2>&1' SIGINT SIGTERM
		# Terminate 'cpulimit' process on focus event and print relevant message (SIGUSR1)
		trap 'print_info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited on focus event." ; kill "$local_cpulimit_pid" > /dev/null 2>&1 ; return 0' SIGUSR1
		# Terminate 'cpulimit' process on termination of target process and print relevant message (SIGUSR2)
		trap 'print_info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window termination." ; kill "$local_cpulimit_pid" > /dev/null 2>&1 ; return 0' SIGUSR2
		wait "$local_cpulimit_pid"
	else
		print_warn "Process '$passed_process_name' with PID $passed_process_pid has been terminated before applying CPU limit!"
	fi
}

# Set specified FPS on unfocus, required to run it on background to avoid stopping a whole code if delay specified
background_mangohud_fps_set(){
	# Wait for N seconds if delay is specified
	if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
		print_verbose "Section '$passed_section' will be FPS limited after ${config_key_delay_map["$passed_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$passed_section"]}"
	fi
	# Check for process existence before set FPS limit
	if check_pid_existence "$passed_process_pid"; then
		# Attempt to change 'fps_limit' in specified MangoHud config file
		if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_fps_unfocus_map["$passed_section"]}"; then
			print_info "Section '$passed_section' has been FPS limited to ${config_key_fps_unfocus_map["$passed_section"]} FPS on unfocus event."
		fi
	else
		print_warn "Process matching with section '$passed_section' has been terminated before FPS limiting!"
	fi
}

# Requred to check for process existence
check_pid_existence(){
	local local_pid="$1"
	# Check for process existence by checking PID directory in '/proc'
	if [[ -d "/proc/$local_pid" ]]; then
		return 0
	else
		return 1
	fi
}

# Required to check read-write access on file
check_rw(){
	local local_file="$1"
	# Check for read-write access
	if [[ -r "$local_file" && -w "$local_file" ]]; then
		return 0
	else
		return 1
	fi
}

# Required to check read-only access on file
check_ro(){
	local local_file="$1"
	# Check for read-only access
	if [[ -r "$local_file" ]]; then
		return 0
	else
		return 1
	fi
}

# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
	local local_temp_frozen_process_pid \
	local_once_frozen_processes_pids_array
	# Check for existence of freeze background process
	if check_pid_existence "${freeze_bgprocess_pid_map["$passed_process_pid"]}"; then
		# Attempt to terminate background process
		if ! kill "${freeze_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				print_warn "Unable to cancel delayed for ${config_key_delay_map["$passed_section"]} second(s) freezing of process '$passed_process_name' with PID $passed_process_pid!"
			fi
		else
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				print_info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) freezing of process $passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
			fi
		fi
	else
		# Attempt to unfreeze target process
		if ! kill -CONT "$passed_process_pid" > /dev/null 2>&1; then
			print_warn "Unable to unfreeze process '$passed_process_name' with PID $passed_process_pid!"
		else
			print_info "Process '$passed_process_name' with PID $passed_process_pid has been unfrozen $passed_end_of_msg."
		fi
	fi
	# Remove PID from array
	for local_temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Skip current PID as I want remove it from array
		if [[ "$local_temp_frozen_process_pid" != "$passed_process_pid" ]]; then
			local_once_frozen_processes_pids_array+=("$local_temp_frozen_process_pid")
		fi
	done
	# Store updated info into array
	frozen_processes_pids_array=("${local_once_frozen_processes_pids_array[@]}")
	# Unset details about freezing
	is_frozen_pid_map["$passed_process_pid"]=''
	freeze_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
	local local_temp_cpulimit_bgprocess_pid \
	local_once_cpulimit_bgprocesses_pids_array
	# Attempt to terminate CPU limit background process
	if ! kill "$passed_signal" "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
		print_warn "Process '$passed_process_name' with PID $passed_process_pid cannot be CPU unlimited!"
	fi
	# Remove PID of 'cpulimit' background process from array
	for local_temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		# Skip interrupted background process as I want remove it from array
		if [[ "$local_temp_cpulimit_bgprocess_pid" != "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" ]]; then
			local_once_cpulimit_bgprocesses_pids_array+=("$local_temp_cpulimit_bgprocess_pid")
		fi
	done
	# Store updated info into array
	cpulimit_bgprocesses_pids_array=("${local_once_cpulimit_bgprocesses_pids_array[@]}")
	# Unset details about CPU limiting
	is_cpu_limited_pid_map["$passed_process_pid"]=''
	cpulimit_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate FPS limit background process or unset FPS limit if window becomes focused or terminated
unset_fps_limit(){
	local local_temp_fps_limited_pid \
	local_temp_fps_limited_section \
	local_once_fps_limited_sections_array
	# Check for existence of FPS limit background process
	if check_pid_existence "${fps_limit_bgprocess_pid_map["$passed_section"]}"; then
		# Terminate background process
		if ! kill "${fps_limit_bgprocess_pid_map["$passed_section"]}" > /dev/null 2>&1; then
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				print_warn "Unable to cancel delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS limiting of section '$passed_section'!"
			fi
		else
			# Avoid printing this message if delay is not specified
			if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
				print_info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS limiting of section '$passed_section' has been cancelled $passed_end_of_msg."
			fi
		fi
	fi
	# Set FPS from 'fps-focus' key
	if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_fps_focus_map["$passed_section"]}"; then
		print_info "Section '$passed_section' has been FPS unlimited $passed_end_of_msg."
	fi
	# Forget that process(es) matching with current section have been FPS limited previously
	for local_temp_fps_limited_pid in "${!fps_limited_section_map[@]}"; do
		if [[ "${fps_limited_section_map["$local_temp_fps_limited_pid"]}" == "$passed_section" ]]; then
			fps_limited_section_map["$local_temp_fps_limited_pid"]=''
		fi
	done
	# Remove section from array
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Skip FPS unlimited section as I want remove it from array
		if [[ "$local_temp_fps_limited_section" != "$passed_section" ]]; then
			local_once_fps_limited_sections_array+=("$local_temp_fps_limited_section")
		fi
	done
	# Store updated info into array
	fps_limited_sections_array=("${local_once_fps_limited_sections_array[@]}")
	# Unset details about FPS limiting
	is_fps_limited_section_map["$passed_section"]=''
	fps_limit_bgprocess_pid_map["$passed_section"]=''
}

# Required to unset limits on SIGTERM and SIGINT signals
actions_on_sigterm(){
	local local_temp_frozen_process_pid \
	local_temp_cpulimit_bgprocess_pid \
	local_temp_fps_limited_section
	# Unfreeze processes
	for local_temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Check for existence of either delayed freezing background process or target process
		if check_pid_existence "${freeze_bgprocess_pid_map["$local_temp_frozen_process_pid"]}"; then
			# Terminate background process if exists
			kill "${freeze_bgprocess_pid_map["$local_temp_frozen_process_pid"]}" > /dev/null 2>&1
		elif check_pid_existence "$local_temp_frozen_process_pid"; then
			# Unfreeze process if exists
			kill -CONT "$local_temp_frozen_process_pid" > /dev/null 2>&1
		fi
	done
	unset local_temp_frozen_process_pid
	# Terminate 'cpulimit' background processes
	for local_temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		if check_pid_existence "$local_temp_cpulimit_bgprocess_pid"; then
			kill "$local_temp_cpulimit_bgprocess_pid" > /dev/null 2>&1
		fi
	done
	unset local_temp_cpulimit_bgprocess_pid
	# Remove FPS limits
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		echo "$local_temp_fps_limited_section"
		# Terminate background process if exists
		if check_pid_existence "${fps_limit_bgprocess_pid_map["$local_temp_fps_limited_section"]}"; then
			kill "${fps_limit_bgprocess_pid_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
		fi
		# Set FPS from 'fps-focus' key to remove limit
		mangohud_fps_set "${config_key_mangohud_config_map["$local_temp_fps_limited_section"]}" "${config_key_fps_focus_map["$local_temp_fps_limited_section"]}" > /dev/null 2>&1
	done
	unset local_temp_fps_limited_section
	# Wait a bit to avoid delayed messages after termination
	sleep 0.1
	# Remove lock file which prevents multiple instances of daemon from running
	if [[ -f "$lock_file" ]] && ! rm "$lock_file" > /dev/null 2>&1; then
		print_warn "Unable to remove lock file '$lock_file' which prevents multiple instances from running!"
	fi
}

# Additional text for errors related to option parsing
advice_on_option_error="\n[i] Try 'flux --help' for more information."

# Option parsing
while (( $# > 0 )); do
	case "$1" in
	--config | -c | --config=* )
		# Remember that option is passed in case path is not specified
		option_repeat_check config_is_passed --config
		config_is_passed='1'
		# Define option type (short, long or long+value) and remember specified path
		case "$1" in
		--config | -c )
			# Remember config path only if that is not an another option, regexp means long or short option
			if [[ -n "$2" && ! "$2" =~ ^(--.*|-.*)$ ]]; then
				config="$2"
				shift 2
			else
				shift 1
			fi
		;;
		* )
			# Shell parameter expansion, remove '--config=' from string
			config="${1/--config=/}"
			shift 1
		esac
	;;
	--focus | -f | --pick | -p )
		# Check for X11 session
		if ! x11_session_check; then
			# Fail if something wrong with X server
			once_fail='1'
		fi
		# Select command depending by type of option
		case "$1" in
		--focus | -f )
			# Check for failure related to X server check
			if [[ -n "$once_fail" ]]; then
				# Exit with an error if something wrong with X server
				print_error "Unable to get info about focused window, invalid X11 session."
				exit 1
			else
				# Get output of xprop containing window ID
				window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
				# Extract ID of focused window
				window_id="${window_id/*\# /}"
			fi
		;;
		--pick | -p )
			# Exit with an error if something wrong with X server
			if [[ -n "$once_fail" ]]; then
				print_error "Unable to call window picker, invalid X11 session."
				exit 1
			else
				# Get xwininfo output containing window ID
				if ! xwininfo_output="$(xwininfo 2>/dev/null)"; then
					print_error "Unable to grab cursor to pick a window!"
					exit 1
				else
					# Extract ID of focused window
					while read -r temp_xwininfo_output_line; do
						if [[ "$temp_xwininfo_output_line" == 'xwininfo: Window id: '* ]]; then
							window_id="${temp_xwininfo_output_line/*: /}"
							window_id="${window_id/ */}"
							break
						fi
					done <<< "$xwininfo_output"
					unset temp_xwininfo_output_line
				fi
			fi
		esac
		# Get process info and print it in a way to easy use it in config
		if get_process_info; then
			echo "name = '"$process_name"'
executable = '"$process_executable"'
command = '"$process_command"'
owner = "$process_owner"
"
			exit 0
		else
			print_error "Unable to create template for window with ID $window_id as it does not report its PID!"
			exit 1
		fi
	;;
	--help | -h | --usage | -u )
		echo "Usage: flux [option] <value>
Options and values:
    -c, --config     /path/to/config    Specify path to config file
    -f, --focused                       Display info about focused window in usable for config file way
    -h, --help                          Display this help
    -H, --hot                           Apply actions to already unfocused windows before handling events
    -l, --lazy                          Avoid focus and unfocus commands on hot
    -p, --pick                          Display info about picked window in usable for config file way
    -q, --quiet                         Display errors and warnings only
    -u, --usage                         Same as '--help'
    -v, --verbose                       Detailed output
    -V, --version                       Display release information
"
		exit 0
	;;
	--hot | -H )
		option_repeat_check hot --hot
		hot='1'
		shift 1
	;;
	--lazy | -l )
		option_repeat_check lazy --lazy
		lazy='1'
		shift 1
	;;
	--quiet | -q )
		option_repeat_check quiet --quiet
		quiet='1'
		shift 1
	;;
	--verbose | -v )
		option_repeat_check verbose --verbose
		verbose='1'
		shift 1
	;;
	--version | -V )
		author_github_link='https://github.com/itz-me-zappex'
		echo "flux 1.7.8
A daemon for X11 designed to automatically limit FPS or CPU usage of unfocused windows and run commands on focus and unfocus events.
License: GPL-3.0-only
Author: $author_github_link
Repository: ${author_github_link}/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
		exit 0
	;;
	* )
		# First regexp means 2+ symbols after hyphen (combined short options)
		# Second regexp avoids long options
		if [[ "$1" =~ ^-.{2,}$ && ! "$1" =~ ^--.* ]]; then
			# Split combined option and add result to array, also skip first symbol as that is hypen
			for (( i = 1; i < ${#1} ; i++ )); do
				once_options_array+=("-${1:i:1}")
			done
			# Forget current option
			shift 1
			# Set options obtained after splitting
			set -- "${once_options_array[@]}" "$@"
			unset once_options_array i
		else
			print_error "Unknown option '$1'!$advice_on_option_error"
			exit 1
		fi
	esac
done

# Exit with an error if verbose and quiet modes are specified at the same time
if [[ -n "$verbose" && -n "$quiet" ]]; then
	print_error "Do not use verbose and quiet modes at the same time!$advice_on_option_error"
	exit 1
fi

# Exit with an error if '--lazy' option is specified without '--hot'
if [[ -n "$lazy" && -z "$hot" ]]; then
	print_error "Do not use '--lazy' option without '--hot'!$advice_on_option_error"
	exit 1
fi

# Exit with an error if '--config' option is specified without a path to config file
if [[ -n "$config_is_passed" && -z "$config" ]]; then
	print_error "Option '--config' is specified without path to config file!$advice_on_option_error"
	exit 1
fi
unset config_is_passed

# Automatically set a path to config file if it is not specified
if [[ -z "$config" ]]; then
	# Set XDG_CONFIG_HOME automatically if it is not specified
	if [[ -z "$XDG_CONFIG_HOME" ]]; then
		XDG_CONFIG_HOME="$HOME/.config"
	fi
	# Find a config
	for temp_config in "$XDG_CONFIG_HOME/flux.ini" "$HOME/.config/flux.ini" '/etc/flux.ini'; do
		if [[ -f "$temp_config" ]]; then
			config="$temp_config"
			break
		fi
	done
	unset temp_config
fi

# Exit with an error if config file is not found
if [[ -z "$config" ]]; then
	print_error "Config file is not found!$advice_on_option_error"
	exit 1
elif [[ ! -f "$config" ]]; then # Exit with an error if config file does not exist
	print_error "Config file '$config' does not exist!"
	exit 1
elif ! check_ro "$config"; then # Exit with an error if config file is not readable
	print_error "Config file '$config' is not accessible for reading!"
	exit 1
fi

# Calculate maximum allowable CPU limit and CPU threads
cpu_threads='0'
while read -r temp_cpuinfo_line; do
	if [[ "$temp_cpuinfo_line" == 'processor'* ]]; then
		(( cpu_threads++ ))
	fi
done < '/proc/cpuinfo'
max_cpu_limit="$(( cpu_threads * 100 ))"
unset temp_cpuinfo_line

# Create associative arrays to store values from config
declare -A config_key_name_map \
config_key_executable_map \
config_key_owner_map \
config_key_cpu_limit_map \
config_key_delay_map \
config_key_focus_map \
config_key_unfocus_map \
config_key_command_map \
config_key_mangohud_config_map \
config_key_fps_unfocus_map \
config_key_fps_focus_map

# Parse INI config
while read -r temp_config_line || [[ -n "$temp_config_line" ]]; do
	# Skip cycle if line is commented or blank, regexp means comments which beginning from ';' or '#' symbols
	if [[ "$temp_config_line" =~ ^(\;|\#) || -z "$temp_config_line" ]]; then
		continue
	else
		# Exit with an error if first line is not a section, otherwise remember section name, regexp means any symbols in square brackes
		if [[ ! "$temp_config_line" =~ ^\[.*\]$ && -z "$once_section" ]]; then
			print_error "Initial section is not found in config '$config'!"
			exit 1
		elif [[ "$temp_config_line" =~ ^\[.*\]$ ]]; then # Regexp means any symbols in square brackes
			# Exit with an error if section repeated
			if [[ -n "${sections_array[*]}" ]]; then
				for temp_section in "${sections_array[@]}"; do
					if [[ "[$temp_section]" == "$temp_config_line" ]]; then
						print_error "Section name '$temp_section' is repeated!"
						exit 1
					fi
				done
				unset temp_section
			fi
			# Remove square brackets from section name and add it to array
			# Array required to check for repeating sections and find matching rule(s) for process in config
			once_section="${temp_config_line/\[/}"
			once_section="${once_section/%\]/}"
			sections_array+=("$once_section")
			# Forward to next line
			continue
		fi
		# Exit with an error if type of line cannot be defined, regexp means [key name][space(s)?]=[space(s)?][anything else]
		if [[ "${temp_config_line,,}" =~ ^(name|executable|owner|cpu-limit|delay|focus|unfocus|command|mangohud-config|fps-unfocus|fps-focus)([[:space:]]+)?=([[:space:]]+)?* ]]; then
			# Remove key name and equal symbol
			once_config_value="${temp_config_line/*=/}"
			# Remove comments from value, 1st regexp means comments after '#' or ';' symbols, 2nd - single or double quoted strings
			if [[ "$once_config_value" =~ \ (\#|\;) && ! "$once_config_value" =~ ^(\".*\"|\'.*\')$ ]]; then
				# Regexp means comment after '#' symbol
				if [[ "$once_config_value" =~ \# ]]; then
					once_config_value="${once_config_value/ \#*/}"
				else
					once_config_value="${once_config_value/ \;*/}"
				fi
			fi
			# Remove all spaces before and after string, internal shell parameter expansion required to get spaces supposed to be removed
			once_config_value="${once_config_value#"${once_config_value%%[![:space:]]*}"}" # Remove spaces in beginning for string
			once_config_value="${once_config_value%"${once_config_value##*[![:space:]]}"}" # Remove spaces in end of string
			# Remove single or double quotes from strings, that is what regexp means
			if [[ "$once_config_value" =~ ^(\".*\"|\'.*\')$ ]]; then
				# Regexp means double quoted string
				if [[ "$once_config_value" =~ ^\".*\"$ ]]; then
					once_config_value="${once_config_value/\"/}" # Remove first double quote
					once_config_value="${once_config_value/%\"/}" # And last one
				else
					once_config_value="${once_config_value/\'/}" # Remove first single quote
					once_config_value="${once_config_value/%\'/}" # And last one
				fi
			fi
			# Associate value with section
			case "${temp_config_line,,}" in
			name* )
				config_key_name_map["$once_section"]="$once_config_value"
			;;
			executable* )
				config_key_executable_map["$once_section"]="$once_config_value"
			;;
			owner* )
				# Exit with an error if UID is not numeric, regexp means any number
				if [[ "$once_config_value" =~ ^[0-9]+$ ]]; then
					config_key_owner_map["$once_section"]="$once_config_value"
				else
					print_error "Value '$once_config_value' in key 'owner' in section '$once_section' is not UID!"
					exit 1
				fi
			;;
			cpu-limit* )
				# Exit with an error if CPU limit is specified incorrectly, 1st regexp - any number with optional '%' symbol, 2nd - '-1' or '-1%'
				if [[ "$once_config_value" =~ ^[0-9]+(\%)?$ || "$once_config_value" =~ ^('-1'|'-1%')$ ]] && (( "${once_config_value/%\%/}" * cpu_threads <= max_cpu_limit )); then
					# Regexp means '-1' or '-1%'
					if [[ "$once_config_value" =~ ^('-1'|'-1%')$ ]]; then
						config_key_cpu_limit_map["$once_section"]="${once_config_value/%\%/}"
					else
						config_key_cpu_limit_map["$once_section"]="$(( "${once_config_value/%\%/}" * cpu_threads ))"
					fi
				else
					print_error "Value '$once_config_value' in key 'cpulimit' in section '$once_section' is invalid! Allowed values are 0-100%."
					exit 1
				fi
			;;
			delay* )
				# Exit with an error if value is neither an integer nor a float (that is what regexp means)
				if [[ "$once_config_value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
					config_key_delay_map["$once_section"]="$once_config_value"
				else
					print_error "Value '$once_config_value' in key 'delay' in section '$once_section' is neither integer nor float!"
					exit 1
				fi
			;;
			focus* )
				config_key_focus_map["$once_section"]="$once_config_value"
			;;
			unfocus* )
				config_key_unfocus_map["$once_section"]="$once_config_value"
			;;
			command* )
				config_key_command_map["$once_section"]="$once_config_value"
			;;
			mangohud-config* )
				# Exit with an error if specified MangoHud config file does not exist
				if [[ -f "$once_config_value" ]]; then
					config_key_mangohud_config_map["$once_section"]="$once_config_value"
				else
					print_error "Config file '$once_config_value' specified in key 'mangohud-config' in section '$once_section' does not exist!"
					exit 1
				fi
			;;
			fps-unfocus* )
				# Exit with an error if value is not integer, that is what regexp means
				if [[ "$once_config_value" =~ ^[0-9]+$ ]]; then
					# Exit with an error if value equal to zero
					if [[ "$once_config_value" != '0' ]]; then
						config_key_fps_unfocus_map["$once_section"]="$once_config_value"
					else
						print_error "Value $once_config_value in key 'fps-unfocus' in section '$once_section' should be greater than zero!"
						exit 1
					fi
				else
					print_error "Value '$once_config_value' specified in key 'fps-unfocus' in section '$once_section' is not an integer!"
					exit 1
				fi
			;;
			fps-focus* )
				# Exit with an error if value is not integer, that is what regexp means
				if [[ "$once_config_value" =~ ^[0-9]+$ ]]; then
					config_key_fps_focus_map["$once_section"]="$once_config_value"
				else
					print_error "Value '$once_config_value' specified in key 'fps-focus' in section '$once_section' is not an integer!"
					exit 1
				fi
			esac
		else
			print_error "Unable to define type of line '$temp_config_line'!"
			exit 1
		fi
	fi
done < "$config"
unset temp_config_line \
once_config_value \
once_section

# Check values in sections and exit with an error if something is wrong or set default values in some keys if is not specified
for temp_section in "${sections_array[@]}"; do
	# Exit with an error if neither identifier 'name' nor 'executable' nor 'command' is specified
	if [[ -z "${config_key_name_map["$temp_section"]}" && -z "${config_key_executable_map["$temp_section"]}" && -z "${config_key_command_map["$temp_section"]}" ]]; then
		print_error "At least one process identifier required in section '$temp_section'!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS limit is not specified along with config path
	if [[ -n "${config_key_fps_unfocus_map["$temp_section"]}" && -z "${config_key_mangohud_config_map["$temp_section"]}" ]]; then
		print_error "Value ${config_key_fps_unfocus_map["$temp_section"]} in key 'fps-unfocus' in section '$temp_section' is specified without path to MangoHud config!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS limit is specified along with CPU limit
	if [[ -n "${config_key_fps_unfocus_map["$temp_section"]}" && -n "${config_key_cpu_limit_map["$temp_section"]}" && "${config_key_cpu_limit_map["$temp_section"]}" != '-1' ]]; then
		print_error "Do not use FPS limit along with CPU limit in section '$temp_section'!"
		exit 1
	fi
	# Exit with an error if 'fps-focus' is specified without 'fps-unfocus'
	if [[ -n "${config_key_fps_focus_map["$temp_section"]}" && -z "${config_key_fps_unfocus_map["$temp_section"]}" ]]; then
		print_error "Do not use 'fps-focus' key without 'fps-unfocus' key in section '$temp_section'!"
		exit 1
	fi
	# Exit with an error if 'mangohud-config' is specified without 'fps-unfocus'
	if [[ -n "${config_key_mangohud_config_map["$temp_section"]}" && -z "${config_key_fps_unfocus_map["$temp_section"]}" ]]; then
		print_error "Do not use 'mangohud-config' key without 'fps-unfocus' key in section '$temp_section'!"
		exit 1
	fi
	# Set 'fps-focus' to '0' (full FPS unlock) if it is not specified
	if [[ -n "${config_key_fps_unfocus_map["$temp_section"]}" && -z "${config_key_fps_focus_map["$temp_section"]}" ]]; then
		config_key_fps_focus_map["$temp_section"]='0'
	fi
	# Set CPU limit to '-1' (none) if it is not specified
	if [[ -z "${config_key_cpu_limit_map["$temp_section"]}" ]]; then
		config_key_cpu_limit_map["$temp_section"]='-1'
	fi
	# Set 'delay' to '0' if it is not specified
	if [[ -z "${config_key_delay_map["$temp_section"]}" ]]; then
		config_key_delay_map["$temp_section"]='0'
	fi
done
unset temp_section

# Declare associative arrays to store info about applied limits
declare -A is_frozen_pid_map \
freeze_bgprocess_pid_map \
is_cpu_limited_pid_map \
cpulimit_bgprocess_pid_map \
is_fps_limited_section_map \
fps_limit_bgprocess_pid_map \
fps_limited_section_map \
request_freeze_map \
request_cpu_limit_map \
request_fps_limit_map

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_event_type_map \
cache_process_pid_map \
cache_process_name_map \
cache_process_executable_map \
cache_process_owner_map \
cache_process_command_map \
cache_section_map \
cache_mismatch_map

# Exit with an error if that is not a X11 session
if ! x11_session_check; then
	# Exit with an error if X11 session is invalid
	print_error "Unable to start daemon, invalid X11 session."
	exit 1
else
	# Exit with an error if daemon already running
	lock_file='/tmp/flux-lock'
	if [[ -f "$lock_file" ]] && check_pid_existence "$(<"$lock_file")"; then
		print_error "Multiple instances are not allowed, make sure that daemon is not running before start, if you are really sure, then remove '$lock_file' file."
		exit 1
	else
		# Store PID to lock file to check its existence on next launch (if lock file exists, e.g. after crash or SIGKILL)
		if ! echo "$$" > "$lock_file"; then
			print_error "Unable to create lock file '$lock_file' required to prevent multiple instances!"
			exit 1
		fi
	fi
	# Remove CPU and FPS limits of processes on exit
	trap 'actions_on_sigterm ; print_info "Daemon has been terminated successfully." ; exit 0' SIGTERM SIGINT
	# Ignore user signals as they used in 'background_cpulimit' function to avoid next output ('X' - path to 'flux', 'Y' - line, 'Z' - PID of 'background_cpulimit'):
	# X: line Y: Z User defined signal 2   background_cpulimit
	trap '' SIGUSR1 SIGUSR2
	# Read IDs of windows and apply actions
	while read -r event; do
		# Exit with an error in case 'exit' event appears
		if [[ "$event" == 'exit' ]]; then
			actions_on_sigterm
			print_error "Daemon has been terminated unexpectedly!"
			exit 1
		elif [[ "$event" == 'nolazy' ]]; then # Unset '--lazy' option if responding event appears, otherwise focus and unfocus commands will not work
			unset lazy
			lazy_is_unset='1'
		elif [[ "$event" == 'nohot' ]]; then # Unset '--hot' if responding event appears, as it becomes useless from this moment
			unset hot
		elif [[ "$event" == 'refresh'* ]]; then # Unset info about terminated windows from arrays and cache if responding event appears
			# Obtain list of terminated windows IDs
			once_terminated_windows_ids="${event/*' terminated: '/}" # Remove everything before including type name of list with windows IDs
			once_terminated_windows_ids="${once_terminated_windows_ids/' existing: '*/}" # Remove list of existing windows IDs
			# Obtain list of existing windows IDs
			once_existing_windows_ids="${event/*' existing: '/}" # Remove everything including type name of list with windows IDs
			# Unset info about freezing and CPU limits of terminated windows
			for temp_terminated_window_id in $once_terminated_windows_ids; do
				# Skip window ID if that is bad event or info about it does not exist in cache
				if [[ -z "${cache_event_type_map["$temp_terminated_window_id"]}" || "${cache_event_type_map["$temp_terminated_window_id"]}" == 'bad' ]]; then
					continue
				else
					# Obtain PID of terminated process using cache, required to check and unset FPS limit
					once_terminated_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}"
					# Do not do anything if window is not frozen
					if [[ -n "${is_frozen_pid_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]}" ]]; then
						# Unfreeze process
						passed_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}" \
						passed_section="${cache_section_map["$once_terminated_process_pid"]}" \
						passed_process_name="${cache_process_name_map["$temp_terminated_window_id"]}" \
						passed_end_of_msg='due to window termination' \
						unfreeze_process
					elif [[ -n "${is_cpu_limited_pid_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]}" ]]; then # Do not do anything if window is not CPU limited
						# Unset CPU limit
						passed_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}" \
						passed_process_name="${cache_process_name_map["$temp_terminated_window_id"]}" \
						passed_signal='-SIGUSR2' \
						unset_cpu_limit
					elif [[ -n "${cache_section_map["$once_terminated_process_pid"]}" && -n "${is_fps_limited_section_map["${cache_section_map["$once_terminated_process_pid"]}"]}" ]]; then # Do not do anything if window is not FPS limited
						# Do not remove FPS limit if one of existing windows matches with the same section
						for temp_existing_window_id in $once_existing_windows_ids; do
							# Obtain PID of terminated process using cache
							once_existing_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}"
							# Mark to not unset FPS limit if there is another window which matches with same section
							if [[ "${cache_section_map["$once_existing_process_pid"]}" == "${cache_section_map["$once_terminated_process_pid"]}" ]]; then
								once_found='1'
								break
							fi
						done
						unset once_existing_process_pid \
						temp_existing_window_id
						# Unset FPS limit if there is no any matching windows except target
						if [[ -z "$once_found" ]]; then
							passed_section="${cache_section_map["$once_terminated_process_pid"]}" \
							passed_end_of_msg='due to matching window(s) termination' \
							unset_fps_limit
						fi
						unset once_found
					fi
				fi
			done
			unset once_terminated_process_pid \
			once_existing_windows_ids \
			temp_terminated_window_id
			# Remove cached info about terminated windows
			for temp_terminated_window_id in $once_terminated_windows_ids; do
				# Check for event type before unset cache
				if [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'bad' ]]; then
					# Unset only event type for bad window, otherwise bash will fail
					print_verbose "Cached info about bad window with ID $temp_terminated_window_id has been removed as it has been terminated."
					cache_event_type_map["$temp_terminated_window_id"]=''
					continue
				elif [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'good' ]]; then
					# Simplify access to PID of cached window info
					once_terminated_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}"
					# Simplify access to matching section of cached window info
					once_terminated_section="${cache_section_map["$once_terminated_process_pid"]}"
					# Unset limit request
					if [[ -n "${request_freeze_map["$once_terminated_process_pid"]}" ]]; then
						request_freeze_map["$once_terminated_process_pid"]=''
						print_info "Freezing of process '${cache_process_name_map["$temp_terminated_window_id"]}' with PID $once_terminated_process_pid has been cancelled due to window termination."
					elif [[ -n "${request_cpu_limit_map["$once_terminated_process_pid"]}" ]]; then
						request_cpu_limit_map["$once_terminated_process_pid"]=''
						print_info "CPU limiting of process '${cache_process_name_map["$temp_terminated_window_id"]}' with PID $once_terminated_process_pid has been cancelled due to window termination."
					elif [[ -n "$once_terminated_section" && -n "${request_fps_limit_map["$once_terminated_section"]}" ]]; then
						request_fps_limit_map["$once_terminated_section"]=''
						print_info "FPS limiting of section '$once_terminated_section' has been cancelled due to termination of matching window(s)."
					fi
					# Unset data in cache related to terminated window
					print_verbose "Cached info about window with ID $temp_terminated_window_id and process '${cache_process_name_map["$temp_terminated_window_id"]}' with PID ${cache_process_pid_map["$temp_terminated_window_id"]} has been removed as it has been terminated."
					cache_mismatch_map["$once_terminated_process_pid"]=''
					cache_section_map["$once_terminated_process_pid"]=''
					cache_event_type_map["$temp_terminated_window_id"]=''
					cache_process_pid_map["$temp_terminated_window_id"]=''
					cache_process_name_map["$temp_terminated_window_id"]=''
					cache_process_executable_map["$temp_terminated_window_id"]=''
					cache_process_owner_map["$temp_terminated_window_id"]=''
					cache_process_command_map["$temp_terminated_window_id"]=''
				fi
			done
			unset temp_terminated_window_id \
			once_terminated_process_pid \
			once_terminated_section \
			once_terminated_windows_ids
		elif [[ "$event" == 'check_requests'* ]]; then
			# Get list of existing windows
			once_existing_windows_ids="${event/'check_requests: '/}"
			# Apply requested limits to existing windows
			for temp_existing_window_id in $once_existing_windows_ids; do
				# Skip cycle if window has bad event type of not at all
				if [[ -z "${cache_event_type_map["$temp_existing_window_id"]}" || "${cache_event_type_map["$temp_existing_window_id"]}" == 'bad' ]]; then
					continue
				fi
				# Simplify access to PID of cached window info
				once_existing_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}"
				# Simplify access to matching section of cached window info
				once_existing_section="${cache_section_map["$once_existing_process_pid"]}"
				# Check for request existence to apply one of limits
				if [[ -n "${request_freeze_map["$once_existing_process_pid"]}" ]]; then
					# Unset request as it becomes useless
					request_freeze_map["$once_existing_process_pid"]=''
					# Freeze process
					passed_section="$once_existing_section" \
					passed_process_name="${cache_process_name_map["$temp_existing_window_id"]}" \
					passed_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}" \
					background_freeze_process &
					# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
					freeze_bgprocess_pid_map["$once_existing_process_pid"]="$!"
					# Mark process as frozen
					is_frozen_pid_map["$once_existing_process_pid"]='1'
					# Store PID to array to unfreeze process in case daemon interruption
					frozen_processes_pids_array+=("$once_existing_process_pid")
				elif [[ -n "${request_cpu_limit_map["$once_existing_process_pid"]}" ]]; then
					# Unset request as it becomes useless
					request_cpu_limit_map["$once_existing_process_pid"]=''
					# Apply CPU limit
					passed_section="$once_existing_section" \
					passed_process_name="${cache_process_name_map["$temp_existing_window_id"]}" \
					passed_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}" \
					background_cpulimit &
					# Store PID of background process to array to interrupt it in case daemon exit
					cpulimit_bgprocesses_pids_array+=("$!")
					# Associate PID of background process with PID of process to interrupt it on focus event
					cpulimit_bgprocess_pid_map["$once_existing_process_pid"]="$!"
					# Mark process as CPU limited
					is_cpu_limited_pid_map["$once_existing_process_pid"]='1'
				elif [[ -n "$once_existing_section" && -n "${request_fps_limit_map["$once_existing_section"]}" ]]; then
					# Unset request as it becomes useless
					request_fps_limit_map["$once_existing_section"]=''
					# Set FPS limit
					passed_section="$once_existing_section" \
					passed_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}" \
					background_mangohud_fps_set &
					# Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
					fps_limit_bgprocess_pid_map["$once_existing_section"]="$!"
					# Mark section as FPS limited, required to check FPS limit existence on focus event
					is_fps_limited_section_map["$once_existing_section"]='1'
					# Store section to array, required to unset FPS limits on daemon termination
					fps_limited_sections_array+=("$once_existing_section")
				fi
			done
			unset temp_existing_window_id \
			once_existing_windows_ids \
			once_existing_process_pid \
			once_existing_section
		else # Set window ID variable if event does not match with statements above
			window_id="$event"
		fi
		# Skip event if event does not contain window ID
		if [[ -z "$window_id" ]]; then
			continue
		else
			# Check for previous section match, existence of command in 'unfocus' key, status of '--lazy' and signal about unsetting '--lazy'
			if [[ -n "$previous_section" && -n "${config_key_unfocus_map["$previous_section"]}" && -z "$lazy" && -z "$lazy_is_unset" ]]; then
				# Execute command from 'unfocus' key
				passed_window_id="$previous_window_id" \
				passed_process_pid="$previous_process_pid" \
				passed_process_name="$previous_process_name" \
				passed_process_executable="$previous_process_executable" \
				passed_process_owner="$previous_process_owner" \
				passed_process_command="$previous_process_command" \
				passed_section="$previous_section" \
				passed_event_command="${config_key_unfocus_map["$previous_section"]}" \
				passed_event='unfocus' \
				exec_on_event
			elif [[ -n "$lazy_is_unset" ]]; then # Check for existence of variable which signals about unsetting of '--lazy' option
				# Unset variable which signals about unsetting of '--lazy' option, required to make 'unfocus' commands work after hot run (using '--hot')
				unset lazy_is_unset
			fi
			# Get process info using window ID if ID is not '0x0'
			if [[ "$window_id" != '0x0' ]]; then
				# Attempt to obtain info about process using window ID
				if ! get_process_info; then
					print_warn "Unable to obtain PID of window with ID $window_id, getting process info skipped!"
				fi
			else
				print_warn "Bad event with window ID 0x0 appeared, getting process info skipped!"
			fi
			# Do not find matching section if window does not report its PID
			if [[ -n "$process_pid" ]]; then
				# Find matching section if was not found previously and store it to cache
				if [[ -z "${cache_section_map["$process_pid"]}" ]]; then
					# Avoid searching for matching section if it was not found previously
					if [[ -z "${cache_mismatch_map["$process_pid"]}" ]]; then
						# Attempt to find a matching section in config
						for temp_section in "${sections_array[@]}"; do
							# Compare process name with specified in section
							if [[ -n "${config_key_name_map["$temp_section"]}" && "${config_key_name_map["$temp_section"]}" != "$process_name" ]]; then
								continue
							else
								once_name_match='1'
							fi
							# Compare process executable path with specified in section
							if [[ -n "${config_key_executable_map["$temp_section"]}" && "${config_key_executable_map["$temp_section"]}" != "$process_executable" ]]; then
								continue
							else
								once_executable_match='1'
							fi
							# Compare UID of process with specified in section
							if [[ -n "${config_key_owner_map["$temp_section"]}" && "${config_key_owner_map["$temp_section"]}" != "$process_owner" ]]; then
								continue
							else
								once_owner_match='1'
							fi
							# Compare process command with specified in section
							if [[ -n "${config_key_command_map["$temp_section"]}" && "${config_key_command_map["$temp_section"]}" != "$process_command" ]]; then
								continue
							else
								once_command_match='1'
							fi
							# Mark as matching if all identifiers containing non-zero value
							if [[ -n "$once_name_match" && -n "$once_executable_match" && -n "$once_owner_match" && -n "$once_command_match" ]]; then
								section="$temp_section"
								cache_section_map["$process_pid"]="$temp_section"
								break
							fi
							unset once_name_match \
							once_executable_match \
							once_owner_match \
							once_command_match
						done
						unset temp_section \
						once_name_match \
						once_executable_match \
						once_owner_match \
						once_command_match
						# Mark process as mismatched if matching section was not found
						if [[ -z "$section" ]]; then
							cache_mismatch_map["$process_pid"]='1'
						fi
					fi
				else
					# Obtain matching section from cache
					section="${cache_section_map["$process_pid"]}"
				fi
				# Print message about section match
				if [[ -n "$section" ]]; then
					print_verbose "Process '$process_name' with PID $process_pid matches with section '$section'."
				else
					print_verbose "Process '$process_name' with PID $process_pid does not match with any section."
				fi
			fi
			# Do not apply limit if previous and current PIDs are exactly the same
			if [[ "$process_pid" != "$previous_process_pid" ]]; then
				# Avoid applying limit if owner has insufficient rights to do that
				if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit_map["$previous_section"]}" != '-1' ]]; then
					# To be frozen if previous window matches with section and 'cpu-limit' key specified to zero
					if [[ -n "$previous_section" && "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
						# Freeze process if it is not already frozen
						if [[ -z "${is_frozen_pid_map["$previous_process_pid"]}" ]]; then
							# Request freezing of process
							request_freeze_map["$previous_process_pid"]='1'
						fi
					elif [[ -n "$previous_section" ]] && (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )); then # To be CPU limited if previous window matches with section and 'cpu-limit' greater than zero
						# Apply CPU limit if it is not already applied
						if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
							# Request CPU limit for process
							request_cpu_limit_map["$previous_process_pid"]='1'
						fi
					elif [[ -n "$previous_section" && -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then # To be FPS limited if previous window matches with section and 'fps-limit' is specified
						# Associate section with PID of process, required to unset FPS limit for all matching windows on focus event or if they have been terminated
						fps_limited_section_map["$previous_process_pid"]="$previous_section"
						# Do not apply FPS limit if current window matches with exactly the same section as previous one
						if [[ "$section" != "$previous_section" ]]; then
							# Request FPS limit for process
							request_fps_limit_map["$previous_section"]='1'
						fi
					fi
				elif [[ -n "$previous_process_owner" ]]; then
					# I know that FPS limiting does not require root rights as it just should change 'fps_limit' value in MangoHud config
					# But who will run a game as root?
					# That is dumb and I am not looking for spend time on this
					print_warn "Unable to apply any kind of limit to process '$previous_process_name' with PID $previous_process_pid due to insufficient rights (process - $previous_process_owner, user - $UID)!"
				fi
			fi
			# Do not apply actions if window does not report its PID
			if [[ -n "$process_pid" ]]; then
				# Unfreeze process if it has been frozen
				if [[ -n "${is_frozen_pid_map["$process_pid"]}" ]]; then
					passed_process_pid="$process_pid" \
					passed_section="$section" \
					passed_process_name="$process_name" \
					passed_end_of_msg='on focus event' \
					unfreeze_process
				elif [[ -n "${is_cpu_limited_pid_map["$process_pid"]}" ]]; then # Unset CPU limit if has been applied
					# Unset CPU limit
					passed_process_pid="$process_pid" \
					passed_process_name="$process_name" \
					passed_signal='-SIGUSR1' \
					unset_cpu_limit
				elif [[ -n "$section" && -n "${is_fps_limited_section_map["$section"]}" ]]; then # Unset FPS limit if has been applied
					# Unset FPS limit
					passed_section="$section" \
					passed_end_of_msg='on focus event' \
					unset_fps_limit
				fi
			fi
			# Execute command from 'focus' key if section matches, specified 'focus' key and that is not lazy mode
			if [[ -n "$section" && -n "${config_key_focus_map["$section"]}" && -z "$lazy" ]]; then
				# Execute command from 'focus' key
				passed_window_id="$window_id" \
				passed_process_pid="$process_pid" \
				passed_process_name="$process_name" \
				passed_process_executable="$process_executable" \
				passed_process_owner="$process_owner" \
				passed_process_command="$process_command" \
				passed_section="$section" \
				passed_event_command="${config_key_focus_map["$section"]}" \
				passed_event='focus' \
				exec_on_event
			fi
			# Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'unfocus' key
			previous_window_id="$window_id"
			previous_process_pid="$process_pid"
			previous_process_name="$process_name"
			previous_process_executable="$process_executable"
			previous_process_owner="$process_owner"
			previous_process_command="$process_command"
			previous_section="$section"
			# Unset info about process to avoid using it by an accident
			unset window_id \
			process_pid \
			process_name \
			process_executable \
			process_owner \
			process_command
			# Unset to avoid false positive on next event
			unset section
		fi
	done < <(xprop_event_reader)
fi