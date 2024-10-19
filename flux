#!/usr/bin/bash

# Print error (redirect to stderr)
print_error(){
	echo -e "$error_prefix $*" >&2
}

# Print warning (redirect to stderr)
print_warn(){
	echo -e "$warn_prefix $*" >&2
}

# Print in verbose mode
print_verbose(){
	if [[ -n "$verbose" ]]; then
		echo -e "$verbose_prefix $*"
	fi
}

# Do not print in quiet mode
print_info(){
	if [[ -z "$quiet" ]]; then
		echo -e "$info_prefix $*"
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
	local local_fail
	# Check for $XDG_SESSION_TYPE and $DISPLAY environment variables
	if [[ ! "$DISPLAY" =~ ^\:[0-9]+(\.[0-9]+)?$ || "$XDG_SESSION_TYPE" != 'x11' ]]; then
		# Fail if $DISPLAY does not match with `:<number>` and `:<number>.<number>`
		# Or if $XDG_SESSION_TYPE is not equal to 'x11' (e.g. 'tty', 'wayland' etc.)
		local_fail='1'
	elif ! xprop -root > /dev/null 2>&1; then
		# Fail if something is wrong with X11 session
		local_fail='1'
	fi
	# Check for error
	if [[ -n "$local_fail" ]]; then
		# Return bad exit code
		return 1
	fi
}

# Required to extract window IDs from xprop events and make '--hot' option work
xprop_event_reader(){
	local local_stacking_windows_id \
	local_focused_window_id \
	temp_stacking_window_id \
	local_window_id \
	local_previous_window_id \
	temp_xprop_event \
	local_client_list_stacking_count \
	temp_client_list_stacking_column \
	local_previous_client_list_stacking_count \
	local_windows_ids \
	local_previous_windows_ids \
	temp_terminated_windows_array
	# Print windows IDs of opened windows to apply limits immediately if '--hot' option was passed
	if [[ -n "$hot" ]]; then
		# Extract IDs of opened windows
		local_stacking_windows_id="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null)"
		if [[ "$local_stacking_windows_id" != '_NET_CLIENT_LIST_STACKING:  no such atom on any window.' ]]; then
			local_stacking_windows_id="${local_stacking_windows_id/* \# /}" # Remove everything before including '#'
			local_stacking_windows_id="${local_stacking_windows_id//\,/}" # Remove commas
		else
			# Print event for safe exit if cannot obtain list of stacking windows
			print_error "Unable to get list of stacking windows!"
			echo 'exit'
		fi
		# Extract ID of focused window
		local_focused_window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
		if [[ "$local_focused_window_id" != '_NET_ACTIVE_WINDOW:  no such atom on any window.' ]]; then
			local_focused_window_id="${local_focused_window_id/* \# /}" # Remove everything before including '#'
		else
			# Print event for safe exit if cannot obtain ID of focused window
			print_error "Unable to get ID of focused window!"
			echo 'exit'
		fi
		# Print IDs of windows, but skip currently focused window as it should appear as first event when 'xprop' starts
		for temp_stacking_window_id in $local_stacking_windows_id; do
			if [[ "$temp_stacking_window_id" != "$local_focused_window_id" ]]; then
				echo "$temp_stacking_window_id"
			fi
		done
		unset local_stacking_windows_id \
		local_focused_window_id \
		temp_stacking_window_id
		# Print event to unset '--hot' option as it becomes useless from this moment
		echo 'nohot'
	fi
	# Print event for unset '--lazy' option before read events, otherwise focus and unfocus commands will not work
	if [[ -n "$lazy" ]]; then
		echo 'nolazy'
	fi
	# Read events from 'xprop' and print IDs of windows
	while read -r temp_xprop_event; do
		# Get window ID
		if [[ "$temp_xprop_event" == '_NET_ACTIVE_WINDOW(WINDOW):'* ]]; then
			# Extract ID from line
			local_window_id="${temp_xprop_event/* \# /}"
			# Skip event if window ID is exactly the same as previous one, workaround required for some buggy WMs
			if [[ "$local_window_id" == "$local_previous_window_id" ]]; then
				continue
			else
				echo "$local_window_id"
				# Remember ID to compare it with new one, if ID is exactly the same, then event will be skipped
				local_previous_window_id="$local_window_id"
			fi
		elif [[ "$temp_xprop_event" != "$local_previous_client_list_stacking" && "$temp_xprop_event" == '_NET_CLIENT_LIST_STACKING(WINDOW):'* ]]; then # Get count of columns in output with list of stacking windows and skip event if it repeats
			# Count columns in event
			local_client_list_stacking_count='0'
			for temp_client_list_stacking_column in $temp_xprop_event; do
				(( local_client_list_stacking_count++ ))
			done
			unset temp_client_list_stacking_column
			# Compare count of columns and if previous event contains more columns (windows IDs), then print event to refresh PIDs in arrays and cache
			if [[ -n "$local_previous_client_list_stacking_count" ]] && (( local_previous_client_list_stacking_count > local_client_list_stacking_count )); then
				# Extract windows IDs from current event
				local_windows_ids="${temp_xprop_event/*\# /}" # Remove everything before including '#'
				local_windows_ids="${local_windows_ids//\,/}" # Remove commas
				# Extract windows IDs from previous event
				local_previous_windows_ids="${local_previous_client_list_stacking/*\# /}" # Remove everything before including '#'
				local_previous_windows_ids="${local_previous_windows_ids//\,/}" # Remove commas
				# Find terminated windows
				for temp_previous_local_window_id in $local_previous_windows_ids; do
					if [[ " $local_windows_ids " != *" $temp_previous_local_window_id "* ]]; then
						temp_terminated_windows_array+=("$temp_previous_local_window_id")
					fi
				done
				unset temp_previous_local_window_id
				# Print event with terminated (required to remove info about them from cache) and existing (required to determine whether all windows matching woth section are closed or not in order to remove FPS limit) windows IDs
				echo "refresh -- terminated: ${temp_terminated_windows_array[*]} existing: $local_windows_ids"
				unset temp_terminated_windows_array
			fi
			# Required to compare columns count in previous and current events
			local_previous_client_list_stacking_count="$local_client_list_stacking_count"
			# Required to skip exactly the same event, happens when window opens from taskbar on Cinnamon DE for example
			local_previous_client_list_stacking="$temp_xprop_event"
		fi
	done < <(xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING 2>&1)
	unset temp_xprop_event
	# Print event for safe exit if 'xprop' has been terminated
	print_error "Process 'xprop' required to read X11 events has been terminated!"
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

# Required to get process info from cache
cache_get_process_info(){
	process_pid="${cache_process_pid_map["$passed_window_id"]}"
	process_name="${cache_process_name_map["$passed_window_id"]}"
	process_executable="${cache_process_executable_map["$passed_window_id"]}"
	process_owner="${cache_process_owner_map["$passed_window_id"]}"
	process_command="${cache_process_command_map["$passed_window_id"]}"
}

# Required to obtain process info using window ID
extract_process_info(){
	local temp_status_line \
	local_column_count \
	local_status_column \
	local_matching_window_id
	# Check for existence of window info in cache and use it if exists
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
			for temp_cached_window_id in "${!cache_process_pid_map[@]}"; do
				# Compare parent PID with PID of process
				if [[ "${cache_process_pid_map[$temp_cached_window_id]}" == "$process_pid" ]]; then
					# Remember window ID of matching process
					local_matching_window_id="$temp_cached_window_id"
					break
				fi
			done
			# Check for match of cached PID info to define a way how to obtain process info
			if [[ -n "$local_matching_window_id" ]]; then
				# Get process info using cache of parent window
				passed_window_id="$local_matching_window_id" cache_get_process_info
				print_verbose "Cache of parent window with ID $local_matching_window_id has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
				unset local_matching_window_id
			else
				# Extract name of process
				process_name="$(<"/proc/$process_pid/comm")"
				# Extract executable path of process
				process_executable="$(readlink "/proc/$process_pid/exe")"
				# Extract UID of process
				while read -r temp_status_line; do
					if [[ "$temp_status_line" == 'Uid:'* ]]; then
						local_column_count='0'
						for local_status_column in $temp_status_line; do
							if (( local_column_count == 3 )); then
								process_owner="$local_status_column"
							else
								(( local_column_count++ ))
							fi
						done
					fi
				done < "/proc/$process_pid/status"
				unset temp_status_line
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
	local temp_config_line \
	local_config_content \
	local_new_config_content \
	local_config="$1" \
	local_fps_to_set="$2" \
	local_fps_limit_is_changed
	# Check if config file exists before continue in case it has been removed
	if [[ -f "$local_config" ]]; then
		# Return an error if file is not readable
		if ! local_config_content="$(<"$local_config")"; then
			print_warn "Unable to read MangoHud config file '$local_config'!"
			return 1
		fi
		# Replace 'fps_limit' value in config if exists
		while read -r temp_config_line || [[ -n "$temp_config_line" ]]; do
			# Find 'fps_limit' line
			if [[ "$temp_config_line" =~ ^fps_limit*=* ]]; then
				# Set specified FPS limit
				if [[ -n "$local_new_config_content" ]]; then
					# Add 'fps_limit=<fps-limit>' to processed text if part of it has been processed
					local_new_config_content="$local_new_config_content\nfps_limit=$local_fps_to_set"
				else
					# Add 'fps_limit=<fps-limit>' as first line in case no text has been processed
					local_new_config_content="fps_limit=$local_fps_to_set"
				fi
				# Set mark which signals about successful setting of FPS limit
				local_fps_limit_is_changed='1'
			else
				# Check for existence of processed text in config
				if [[ -n "$local_new_config_content" ]]; then
					# Add line to processed text from config if part of it has been processed
					local_new_config_content="$local_new_config_content\n$temp_config_line"
				else
					# Add first line in case no text has been processed
					local_new_config_content="$temp_config_line"
				fi
			fi
		done <<< "$local_config_content"
		# Check whether FPS limit has been set or not
		if [[ -z "$local_fps_limit_is_changed" ]]; then
			# Pass key with FPS limit if line does not exist in config
			echo "fps_limit=$local_fps_to_set" >> "$local_config"
		else
			# Pass config content if FPS has been already changed
			echo -e "$local_new_config_content" > "$local_config"
		fi
		# Return an error if something gone wrong
		if (( $? > 0 )); then
			print_warn "Unable to modify MangoHud config file '$local_config'!"
			return 1
		fi
	else
		print_warn "MangoHud config file '$local_config' was not found!"
		return 1
	fi
}

# Apply CPU limit via 'cpulimit' tool on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_cpulimit(){
	local local_cpulimit_pid local_sleep_pid
	# Wait for delay if specified
	if [[ "${config_key_delay_map["$previous_section"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be CPU limited after ${config_key_delay_map["$previous_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$previous_section"]}" &
		# Remember PID of 'sleep' sent into background, required to print message about cancelling CPU limit and terminate 'sleep' process on SIGINT/SIGTERM signal
		local_sleep_pid="$!"
		trap 'print_info "Delayed for ${config_key_delay_map["$previous_section"]} second(s) CPU limiting of process '"'$previous_process_name'"' with PID $previous_process_pid has been cancelled." ; kill "$local_sleep_pid" > /dev/null 2>&1' SIGINT SIGTERM
		wait "$local_sleep_pid"
	fi
	# Apply CPU limit if process still exists, otherwise throw warning
	if check_pid_existence "$previous_process_pid"; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid has been CPU limited to $(( ${config_key_cpu_limit_map["$previous_section"]} / cpu_threads ))% on unfocus event."
		# Apply CPU limit
		cpulimit --lazy --limit="${config_key_cpu_limit_map["$previous_section"]}" --pid="$previous_process_pid" > /dev/null 2>&1 &
		# Remember PID of 'cpulimit' sent into background, required to print message about CPU unlimiting and terminate 'cpulimit' process on SIGINT/SIGTERM signal
		local_cpulimit_pid="$!"
		trap 'print_info "Process '"'$previous_process_name'"' with PID $previous_process_pid has been CPU unlimited on focus event." ; kill "$local_cpulimit_pid" > /dev/null 2>&1' SIGINT SIGTERM
		wait "$local_cpulimit_pid"
	else
		print_warn "Process '$previous_process_name' with PID $previous_process_pid has been terminated before applying CPU limit!"
	fi
}

# Freeze process on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_freeze_process(){
	# Freeze process with delay if specified, otherwise freeze process immediately
	if [[ "${config_key_delay_map["$previous_section"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be frozen after ${config_key_delay_map["$previous_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$previous_section"]}"
	fi
	# Freeze process if it still exists, otherwise throw warning
	if check_pid_existence "$previous_process_pid"; then
		if ! kill -STOP "$previous_process_pid" > /dev/null 2>&1; then
			print_warn "Process '$previous_process_name' with PID $previous_process_pid cannot be frozen on unfocus event!"
		else
			print_info "Process '$previous_process_name' with PID $previous_process_pid has been frozen on unfocus event."
		fi
	else
		print_warn "Process '$previous_process_name' with PID $previous_process_pid has been terminated before freezing!"
	fi
}

# Set specified FPS on unfocus, required to run it on background to avoid stopping a whole code if delay specified
background_mangohud_fps_set(){
	# Wait in case delay is specified
	if [[ "${config_key_delay_map["$previous_section"]}" != '0' ]]; then
		print_verbose "Section '$previous_section' will be FPS limited after ${config_key_delay_map["$previous_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$previous_section"]}"
	fi
	# Apply FPS limit if target process still exists, otherwise throw warning
	if check_pid_existence "$previous_process_pid"; then
		if mangohud_fps_set "${config_key_mangohud_config_map["$previous_section"]}" "${config_key_fps_unfocus_map["$previous_section"]}"; then
			print_info "Section '$previous_section' has been FPS limited to ${config_key_fps_unfocus_map["$previous_section"]} FPS on unfocus event."
		fi
	else
		print_warn "Process matching with section '$previous_section' has been terminated before FPS limiting!"
	fi
}

# Requred to check for process existence
check_pid_existence(){
	if [[ -d "/proc/$1" ]]; then
		return 0
	else
		return 1
	fi
}

# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
	local temp_frozen_process_pid \
	temp_frozen_processes_pids_array
	# Check for existence of freeze background process
	if check_pid_existence "${freeze_bgprocess_pid_map["$passed_process_pid"]}"; then
		# Terminate background process
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
		# Unfreeze process
		if ! kill -CONT "$passed_process_pid" > /dev/null 2>&1; then
			print_warn "Unable to unfreeze process '$passed_process_name' with PID $passed_process_pid!"
		else
			print_info "Process '$passed_process_name' with PID $passed_process_pid has been unfrozen $passed_end_of_msg."
		fi
	fi
	# Remove PID from array
	for temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Skip current PID as I want remove it from array
		if [[ "$temp_frozen_process_pid" != "$passed_process_pid" ]]; then
			temp_frozen_processes_pids_array+=("$temp_frozen_process_pid")
		fi
	done
	# Store updated info into array
	frozen_processes_pids_array=("${temp_frozen_processes_pids_array[@]}")
	# Unset details about freezing
	is_frozen_pid_map["$passed_process_pid"]=''
	freeze_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
	local temp_cpulimit_bgprocess_pid \
	temp_cpulimit_bgprocesses_pids_array
	# Check CPU limit background process for existence
	if ! kill "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" > /dev/null 2>&1; then
		# Terminate background process
		print_warn "Process '$passed_process_name' with PID $passed_process_pid cannot be CPU unlimited!"
	fi
	# Remove PID of 'cpulimit' background process from array
	for temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		# Skip interrupted background process as I want remove it from array
		if [[ "$temp_cpulimit_bgprocess_pid" != "${cpulimit_bgprocess_pid_map["$passed_process_pid"]}" ]]; then
			temp_cpulimit_bgprocesses_pids_array+=("$temp_cpulimit_bgprocess_pid")
		fi
	done
	# Store updated info into array
	cpulimit_bgprocesses_pids_array=("${temp_cpulimit_bgprocesses_pids_array[@]}")
	# Unset details about CPU limiting
	is_cpu_limited_pid_map["$passed_process_pid"]=''
	cpulimit_bgprocess_pid_map["$passed_process_pid"]=''
}

# Required to terminate FPS limit background process or unset FPS limit if window becomes focused or terminated
unset_fps_limit(){
	local temp_fps_limited_pid \
	temp_fps_limited_section \
	temp_fps_limited_sections_array
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
		print_info "Section '$passed_section' has been FPS unlimited on $passed_end_of_msg."
	fi
	# Forget that process(es) matching with current section have been FPS limited previously
	for temp_fps_limited_pid in "${!fps_limited_section_map[@]}"; do
		if [[ "${fps_limited_section_map["$temp_fps_limited_pid"]}" == "$passed_section" ]]; then
			fps_limited_section_map["$temp_fps_limited_pid"]=''
		fi
	done
	# Remove section from array
	for temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Skip FPS unlimited section as I want remove it from array
		if [[ "$temp_fps_limited_section" != "$passed_section" ]]; then
			temp_fps_limited_sections_array+=("$temp_fps_limited_section")
		fi
	done
	# Store updated info into array
	fps_limited_sections_array=("${temp_fps_limited_sections_array[@]}")
	# Unset details about FPS limiting
	is_fps_limited_section_map["$passed_section"]=''
	fps_limit_bgprocess_pid_map["$passed_section"]=''
}

# Required to unset limits on SIGTERM and SIGINT signals
actions_on_sigterm(){
	local temp_frozen_process_pid \
	temp_cpulimit_bgprocess_pid \
	temp_fps_limited_section
	# Unfreeze processes
	for temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Terminate background process if exists
		if check_pid_existence "${freeze_bgprocess_pid_map["$temp_frozen_process_pid"]}"; then
			kill "${freeze_bgprocess_pid_map["$temp_frozen_process_pid"]}" > /dev/null 2>&1
		elif check_pid_existence "$temp_frozen_process_pid"; then # Unfreeze process
			kill -CONT "$temp_frozen_process_pid" > /dev/null 2>&1
		fi
	done
	unset temp_frozen_process_pid
	# Terminate 'cpulimit' background processes
	for temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		if check_pid_existence "$temp_cpulimit_bgprocess_pid"; then
			kill "$temp_cpulimit_bgprocess_pid" > /dev/null 2>&1
		fi
	done
	unset temp_cpulimit_bgprocess_pid
	# Remove FPS limits
	for temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Terminate background process if exists
		if check_pid_existence "${fps_limit_bgprocess_pid_map["$temp_fps_limited_section"]}"; then
			kill "${fps_limit_bgprocess_pid_map["$temp_fps_limited_section"]}" > /dev/null 2>&1
		fi
		# Set FPS from 'fps-focus' key to remove limit
		mangohud_fps_set "${config_key_mangohud_config_map["$temp_fps_limited_section"]}" "${config_key_fps_focus_map["$temp_fps_limited_section"]}" > /dev/null 2>&1
	done
	unset temp_fps_limited_section
	# Remove lock file which prevents multiple daemon instance from running
	if [[ -f "$lock_file" ]]; then
		rm "$lock_file"
	fi
	# Wait a bit to avoid delayed messages after termination
	sleep 0.1
}

# Prefixes for output
error_prefix="[x]"
info_prefix="[i]"
verbose_prefix="[v]"
warn_prefix="[!]"

# Additional text for errors related to option parsing
advice_on_option_error="\n$info_prefix Try 'flux --help' for more information."

# Option parsing
while (( $# > 0 )); do
	case "$1" in
	--config | -c | --config=* )
		# Remember that option was passed in case if path was not specified
		option_repeat_check config_is_passed --config
		config_is_passed='1'
		# Define option type (short, long or long+value) and remember specified path
		case "$1" in
		--config | -c )
			# Remember config path only if that is not an another option
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
			temp_fail='1'
		fi
		# Select command depending by type of option
		case "$1" in
		--focus | -f )
			# Check for failure related to X server check
			if [[ -n "$temp_fail" ]]; then
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
			# Check for failure related to X server check
			if [[ -n "$temp_fail" ]]; then
				# Exit with an error if something wrong with X server
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
		# Extract process info and print it in a way to easy use it in config
		if extract_process_info; then
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
    -c, --config     <path-to-config>    Specify path to config file
    -f, --focused                        Display template for config from focused window
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -p, --pick                           Display template for config by picking window
    -q, --quiet                          Display errors and warnings only
    -u, --usage                          Same as '--help'
    -v, --verbose                        Detailed output
    -V, --version                        Display release information
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
		echo "flux 1.7.3
A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.
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
			# Split combined option and add result to array
			for (( i = 0; i < ${#1} ; i++ )); do
				# Skip double hyphen which appears because of splitting option and adding another one
				# Required to pass '--' to 'set' command explicitly
				if [[ "-${1:i:1}" != '--' ]]; then
					options+=("-${1:i:1}")
				fi
			done
			# Forget current option
			shift 1
			# Set options obtained after splitting
			set -- "${options[@]}" "$@"
			unset options i
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
	print_error "Do not use '--lazy' option without '--hot'!"
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
	for temp_config in '/etc/flux.ini' "$XDG_CONFIG_HOME/flux.ini" "$HOME/.config/flux.ini"; do
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
elif [[ ! -f "$config" ]]; then
	print_error "Config file '$config' does not exist!"
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
	# Check for comments and content on current line
	if [[ "$temp_config_line" =~ ^(\;|\#) || -z "$temp_config_line" ]]; then
		# Skip if line is commented or blank
		continue
	else
		# Exit with an error if first line is not a section, otherwise remember section name
		if [[ ! "$temp_config_line" =~ ^\[.*\]$ && -z "$temp_section" ]]; then
			print_error "Initial section is not found in config '$config'!"
			exit 1
		elif [[ "$temp_config_line" =~ ^\[.*\]$ ]]; then
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
			temp_section="${temp_config_line/\[/}"
			temp_section="${temp_section/%\]/}"
			sections_array+=("$temp_section")
			# Forward to next line
			continue
		fi
		# Exit with an error if type of line cannot be defined
		if [[ "${temp_config_line,,}" =~ ^(name|executable|owner|cpu-limit|delay|focus|unfocus|command|mangohud-config|fps-unfocus|fps-focus)(\ )?=(\ )?.* ]]; then
			# Extract value from key by removing key and equal symbol
			if [[ "$temp_config_line" == *'= '* ]]; then
				temp_value="${temp_config_line/*= /}" # <-
			elif [[ "$temp_config_line" == *'='* ]]; then
				temp_value="${temp_config_line/*=/}" # <-
			fi
			# Remove comments from value
			if [[ "$temp_value" =~ \ (\#|\;) && ! "$temp_value" =~ ^(\".*\"|\'.*\')$ ]]; then
				if [[ "$temp_value" =~ \# ]]; then
					temp_value="${temp_value/ \#*/}"
				else
					temp_value="${temp_value/ \;*/}"
				fi
			fi
			# Remove single/double quotes
			if [[ "$temp_value" =~ ^(\".*\"|\'.*\')$ ]]; then
				if [[ "$temp_value" =~ ^\".*\"$ ]]; then
					temp_value="${temp_value/\"/}"
					temp_value="${temp_value/%\"/}"
				else
					temp_value="${temp_value/\'/}"
					temp_value="${temp_value/%\'/}"
				fi
			fi
			# Associate value with section
			case "${temp_config_line,,}" in
			name* )
				config_key_name_map["$temp_section"]="$temp_value"
			;;
			executable* )
				config_key_executable_map["$temp_section"]="$temp_value"
			;;
			owner* )
				# Exit with an error if UID is not numeric
				if [[ "$temp_value" =~ ^[0-9]+$ ]]; then
					config_key_owner_map["$temp_section"]="$temp_value"
				else
					print_error "Value '$temp_value' in key 'owner' in section '$temp_section' is not UID!"
					exit 1
				fi
			;;
			cpu-limit* )
				# Exit with an error if CPU limit is specified incorrectly
				if [[ "$temp_value" =~ ^[0-9]+(\%)?$ || "$temp_value" =~ ^('-1'|'-1%')$ ]] && (( "${temp_value/%\%/}" * cpu_threads <= max_cpu_limit )); then
					if [[ "$temp_value" =~ ^('-1'|'-1%')$ ]]; then
						config_key_cpu_limit_map["$temp_section"]="${temp_value/%\%/}"
					else
						config_key_cpu_limit_map["$temp_section"]="$(( "${temp_value/%\%/}" * cpu_threads ))"
					fi
				else
					print_error "Value '$temp_value' in key 'cpulimit' in section '$temp_section' is invalid! Allowed values are 0-100%."
					exit 1
				fi
			;;
			delay* )
				# Exit with an error if value is neither an integer nor a float (that is what regexp means)
				if [[ "$temp_value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
					config_key_delay_map["$temp_section"]="$temp_value"
				else
					print_error "Value '$temp_value' in key 'delay' in section '$temp_section' is neither integer nor float!"
					exit 1
				fi
			;;
			focus* )
				config_key_focus_map["$temp_section"]="$temp_value"
			;;
			unfocus* )
				config_key_unfocus_map["$temp_section"]="$temp_value"
			;;
			command* )
				config_key_command_map["$temp_section"]="$temp_value"
			;;
			mangohud-config* )
				# Exit with an error if specified MangoHud config file does not exist
				if [[ -f "$temp_value" ]]; then
					config_key_mangohud_config_map["$temp_section"]="$temp_value"
				else
					print_error "Config file '$temp_value' specified in key 'mangohud-config' in section '$temp_section' does not exist!"
					exit 1
				fi
			;;
			fps-unfocus* )
				# Exit with an error if value is not integer
				if [[ "$temp_value" =~ ^[0-9]+$ ]]; then
					# Exit with an error if value equal to zero
					if [[ "$temp_value" != '0' ]]; then
						config_key_fps_unfocus_map["$temp_section"]="$temp_value"
					else
						print_error "Value $temp_value in key 'fps-unfocus' in section '$temp_section' should be greater than zero!"
						exit 1
					fi
				else
					print_error "Value '$temp_value' specified in key 'fps-unfocus' in section '$temp_section' is not an integer!"
					exit 1
				fi
			;;
			fps-focus* )
				if [[ "$temp_value" =~ ^[0-9]+$ ]]; then
					config_key_fps_focus_map["$temp_section"]="$temp_value"
				else
					print_error "Value '$temp_value' specified in key 'fps-focus' in section '$temp_section' is not an integer!"
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
temp_value \
temp_section

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
fps_limited_section_map

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
	# Check for another instance and exit with an error if it exists
	lock_file='/tmp/flux-lock'
	if [[ -f "$lock_file" ]]; then
		print_error "Multiple instances are not allowed, make sure that daemon is not running before start, if you are really sure, then remove '$lock_file' file."
		exit 1
	else
		echo > "$lock_file"
	fi
	# Remove CPU and FPS limits of processes on exit
	trap 'actions_on_sigterm ; print_info "Daemon has been terminated successfully." ; exit 0' SIGTERM SIGINT
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
			temp_terminated_windows_ids="${event/*' terminated: '/}" # Remove everything before including type name of list with windows IDs
			temp_terminated_windows_ids="${temp_terminated_windows_ids/' existing: '*/}" # Remove list of existing windows IDs
			# Obtain list of existing windows IDs
			temp_existing_windows_ids="${event/*' existing: '/}" # Remove everything including type name of list with windows IDs
			# Unset info about freezing and CPU limits of terminated windows
			for temp_terminated_window_id in $temp_terminated_windows_ids; do
				# Check for event type
				if [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'bad' ]]; then
					# Skip window ID if that is bad event, otherwise bash will fail
					continue
				elif [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'good' ]]; then
					# Obtain PID of terminated process using cache, required to check and unset FPS limit
					temp_terminated_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}"
					# Do not do anything if window is not frozen
					if [[ -n "${is_frozen_pid_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]}" ]]; then
						# Unfreeze process
						passed_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}" \
						passed_section="${cache_section_map["$temp_terminated_process_pid"]}" \
						passed_process_name="${cache_process_name_map["$temp_terminated_window_id"]}" \
						passed_end_of_msg='due to process termination' \
						unfreeze_process
					elif [[ -n "${is_cpu_limited_pid_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]}" ]]; then # Do not do anything if window is not CPU limited
						# Unset CPU limit
						passed_process_pid="${cache_process_pid_map["$temp_terminated_window_id"]}" \
						passed_process_name="${cache_process_name_map["$temp_terminated_window_id"]}" \
						unset_cpu_limit
					elif [[ -n "${cache_section_map["$temp_terminated_process_pid"]}" && -n "${is_fps_limited_section_map["${cache_section_map["$temp_terminated_process_pid"]}"]}" ]]; then # Do not do anything if window is not FPS limited
						# Check if one of existing windows matches with same section, if yes, then FPS limit will not be removed
						for temp_existing_window_id in $temp_existing_windows_ids; do
							# Obtain PID of terminated process using cache
							temp_existing_process_pid="${cache_process_pid_map["$temp_existing_window_id"]}"
							# Mark to not unset FPS limit if there is another window which matches with same section
							if [[ "${cache_section_map["$temp_existing_process_pid"]}" == "${cache_section_map["$temp_terminated_process_pid"]}" ]]; then
								temp_found='1'
								break
							fi
						done
						unset temp_existing_process_pid
						# Check for abscence of existing windows which matching with section
						if [[ -z "$temp_found" ]]; then
							# Unset FPS limit
							passed_section="${cache_section_map["$temp_terminated_process_pid"]}" \
							passed_end_of_msg='due to termination of matching process(es)' \
							unset_fps_limit
						fi
						unset temp_found
					fi
				fi
			done
			unset temp_terminated_process_pid
			# Remove cached info about terminated windows
			for temp_terminated_window_id in $temp_terminated_windows_ids; do
				# Check for event type before unset cache
				if [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'bad' ]]; then
					# Unset only event type for bad window, otherwise bash will fail
					print_verbose "Cached info about bad window with ID $temp_terminated_window_id has been removed as it has been terminated."
					cache_event_type_map["$temp_terminated_window_id"]=''
					continue
				elif [[ "${cache_event_type_map["$temp_terminated_window_id"]}" == 'good' ]]; then
					# Unset data in cache related to terminated window
					print_verbose "Cached info about window with ID $temp_terminated_window_id and process '${cache_process_name_map["$temp_terminated_window_id"]}' with PID ${cache_process_pid_map["$temp_terminated_window_id"]} has been removed as it has been terminated."
					cache_mismatch_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]=''
					cache_section_map["${cache_process_pid_map["$temp_terminated_window_id"]}"]=''
					cache_event_type_map["$temp_terminated_window_id"]=''
					cache_process_pid_map["$temp_terminated_window_id"]=''
					cache_process_name_map["$temp_terminated_window_id"]=''
					cache_process_executable_map["$temp_terminated_window_id"]=''
					cache_process_owner_map["$temp_terminated_window_id"]=''
					cache_process_command_map["$temp_terminated_window_id"]=''
				fi
			done
			unset temp_terminated_window_id \
			temp_terminated_windows_ids
		else # Set window ID variable if event does not match with statements above
			window_id="$event"
		fi
		# Check for window ID existence
		if [[ -z "$window_id" ]]; then
			# Skip event if it does not contain window ID
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
			# Extract process info using window ID if ID is not '0x0'
			if [[ "$window_id" != '0x0' ]]; then
				if ! extract_process_info; then
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
								temp_name_match='1'
							fi
							# Compare process executable path with specified in section
							if [[ -n "${config_key_executable_map["$temp_section"]}" && "${config_key_executable_map["$temp_section"]}" != "$process_executable" ]]; then
								continue
							else
								temp_executable_match='1'
							fi
							# Compare UID of process with specified in section
							if [[ -n "${config_key_owner_map["$temp_section"]}" && "${config_key_owner_map["$temp_section"]}" != "$process_owner" ]]; then
								continue
							else
								temp_owner_match='1'
							fi
							# Compare process command with specified in section
							if [[ -n "${config_key_command_map["$temp_section"]}" && "${config_key_command_map["$temp_section"]}" != "$process_command" ]]; then
								continue
							else
								temp_command_match='1'
							fi
							# Mark as matching if all identifiers containing non-zero value
							if [[ -n "$temp_name_match" && -n "$temp_executable_match" && -n "$temp_owner_match" && -n "$temp_command_match" ]]; then
								section="$temp_section"
								cache_section_map["$process_pid"]="$temp_section"
								break
							fi
							unset temp_name_match \
							temp_executable_match \
							temp_owner_match \
							temp_command_match
						done
						unset temp_section \
						temp_name_match \
						temp_executable_match \
						temp_owner_match \
						temp_command_match
						# Mark process as mismatched if matching section was not found
						if [[ -z "$section" ]]; then
							cache_mismatch_map["$process_pid"]='1'
						fi
					fi
				else
					# Obtain matching section from cache
					section="${cache_section_map["$process_pid"]}"
				fi
				# Check for match and print message about that
				if [[ -n "$section" ]]; then
					print_info "Process '$process_name' with PID $process_pid matches with section '$section'."
				else
					print_verbose "Process '$process_name' with PID $process_pid does not match with any section."
				fi
			fi
			# Check if PID is not the same as previous one
			if [[ "$process_pid" != "$previous_process_pid" ]]; then
				# Avoid applying limit if owner has insufficient rights to do that
				if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit_map["$previous_section"]}" != '-1' ]]; then
					# Check for existence of previous match and if CPU limit is set to 0
					if [[ -n "$previous_section" && "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
						# Check whether process is frozen
						if [[ -z "${is_frozen_pid_map["$previous_process_pid"]}" ]]; then
							# Freeze process
							background_freeze_process &
							# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
							freeze_bgprocess_pid_map["$previous_process_pid"]="$!"
							# Mark process as frozen
							is_frozen_pid_map["$previous_process_pid"]='1'
							# Store PID to array to unfreeze process in case daemon interruption
							frozen_processes_pids_array+=("$previous_process_pid")
						fi
					elif [[ -n "$previous_section" ]] && (( "${config_key_cpu_limit_map["$previous_section"]}" > 0 )); then # Check for existence of previous match and CPU limit specified greater than 0
						# Check for CPU limit existence
						if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
							# Apply CPU limit
							background_cpulimit &
							# Store PID of background process to array to interrupt it in case daemon exit
							cpulimit_bgprocesses_pids_array+=("$!")
							# Associate PID of background process with PID of process to interrupt it on focus event
							cpulimit_bgprocess_pid_map["$previous_process_pid"]="$!"
							# Mark process as CPU limited
							is_cpu_limited_pid_map["$previous_process_pid"]='1'
						fi
					elif [[ -n "$previous_section" && -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then # Check for existence of previous match and FPS limit specified in config
						# Associate section with PID of process, required to unset FPS limit for all matching windows on focus event or if they have been terminated
						fps_limited_section_map["$previous_process_pid"]="$previous_section"
						# Do not apply FPS limit if current window matches with exactly the same section as previous one
						if [[ "$section" != "$previous_section" ]]; then
							# Set FPS limit
							background_mangohud_fps_set &
							# Associate PID of background process with section to interrupt in case focus event appears earlier than delay ends
							fps_limit_bgprocess_pid_map["$previous_section"]="$!"
							# Mark section as FPS limited, required to check FPS limit existence on focus event
							is_fps_limited_section_map["$previous_section"]='1'
							# Store section to array, required to unset FPS limits on daemon termination
							fps_limited_sections_array+=("$previous_section")
						fi
					fi
				elif [[ -n "$previous_process_owner" ]]; then
					# I know that FPS limiting does not require root rights as it just should change 'fps_limit' value in MangoHud config
					# But who will run a game as root?
					# That is dumb and I'm not looking for spend time on this
					print_warn "Unable to apply any kind of limit to process '$previous_process_name' with PID $previous_process_pid due to insufficient rights (process - $previous_process_owner, user - $UID)!"
				fi
			fi
			# Do not apply actions if window does not report its PID
			if [[ -n "$process_pid" ]]; then
				# Check whether process is frozen
				if [[ -n "${is_frozen_pid_map["$process_pid"]}" ]]; then
					# Unfreeze process
					passed_process_pid="$process_pid" \
					passed_section="$section" \
					passed_process_name="$process_name" \
					passed_end_of_msg='on focus event' \
					unfreeze_process
				elif [[ -n "${is_cpu_limited_pid_map["$process_pid"]}" ]]; then # Check for CPU limit existence
					# Unset CPU limit
					passed_process_pid="$process_pid" \
					passed_process_name="$process_name" \
					unset_cpu_limit
				elif [[ -n "$section" && -n "${is_fps_limited_section_map["$section"]}" ]]; then # Check for FPS limit existence
					# Unset FPS limit
					passed_section="$section" \
					passed_end_of_msg='on focus event' \
					unset_fps_limit
				fi
			fi
			# Check for section match, existence of command in 'focus' keys and disabled lazy mode
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