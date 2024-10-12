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
	local local_exit
	# Set 'exit' variable if something is wrong with X11 session
	if [[ ! "$DISPLAY" =~ ^\:[0-9]+(\.[0-9]+)?$ || "$XDG_SESSION_TYPE" != 'x11' ]]; then
		local_exit='1'
	elif ! xprop -root > /dev/null 2>&1; then
		local_exit='1'
	fi
	# Exit with an error if something is wrong with X11 session
	if [[ -n "$local_exit" ]]; then
		print_error "Flux is not meant to use it with anything but X11! Make sure everything is fine with your current X11 session."
		exit 1
	fi
}

# Required to extract window IDs from xprop events and make '--hot' option work
xprop_event_reader(){
	local local_stacking_windows_id \
	local_focused_window_id \
	temp_stacking_window_id \
	local_exit \
	local_window_id \
	local_previous_window_id \
	temp_xprop_event \
	local_client_list_stacking_count \
	temp_client_list_stacking_column \
	local_previous_client_list_stacking_count \
	local_sleep_pid
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
				# Do not print bad events, workaround required for some buggy WMs
				if [[ "$local_window_id" =~ ^0x[0-9a-fA-F]{7}$ ]]; then
					echo "$local_window_id"
					# Remember ID to compare it with new one, if ID is exactly the same, then event will be skipped
					local_previous_window_id="$local_window_id"
				fi
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
				# Check for delayed event existence and terminate it to run new one
				if [[ -d "/proc/$local_sleep_pid" ]]; then
					kill "$local_sleep_pid" > /dev/null 2>&1
				fi
				# Wait a bit for termination of processes as that does not happen immediately, otherwise terminated PIDs will be recognized as not terminated on refresh of cache and arrays
				(sleep 2 ; echo 'refresh') &
				# Remember PID of subprocess to avoid multiple instances
				local_sleep_pid="$!"
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

# Required to pass variables with process info for focus and unfocus commands
export_flux_variables(){
	export FLUX_WINDOW_ID="$1" \
	FLUX_PROCESS_PID="$2" \
	FLUX_PROCESS_NAME="$3" \
	FLUX_PROCESS_EXECUTABLE="$4" \
	FLUX_PROCESS_OWNER="$5" \
	FLUX_PROCESS_COMMAND="$6"
}

# Required to unset exported variables because those become useless after running command
unset_flux_variables(){
	unset FLUX_WINDOW_ID \
	FLUX_PROCESS_PID \
	FLUX_PROCESS_NAME \
	FLUX_PROCESS_EXECUTABLE \
	FLUX_PROCESS_OWNER \
	FLUX_PROCESS_COMMAND
}

# Required to obtain process info using window ID
extract_process_info(){
	local temp_status_line \
	local_column_count \
	local_status_column
	# Extract PID of process
	if ! process_pid="$(xprop -id "$window_id" _NET_WM_PID 2>/dev/null)"; then
		process_pid=''
	elif [[ "$process_pid" == '_NET_WM_PID:  not found.' ]]; then
		process_pid=''
	fi
	if [[ -n "$process_pid" ]]; then
		process_pid="${process_pid/* = /}"
		# Check if info about process exists in cache
		if [[ -z "${cache_process_name_map["$process_pid"]}" ]]; then
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
			# Add all variables to cache
			cache_process_name_map["$process_pid"]="$process_name"
			cache_process_executable_map["$process_pid"]="$process_executable"
			cache_process_owner_map["$process_pid"]="$process_owner"
			cache_process_command_map["$process_pid"]="$process_command"
			# Store PID to array to make it easier to remove info from cache in case process does not exist
			cached_pids_array+=("$process_pid")
		else
			# Set values from cache
			process_name="${cache_process_name_map["$process_pid"]}"
			process_executable="${cache_process_executable_map["$process_pid"]}"
			process_owner="${cache_process_owner_map["$process_pid"]}"
			process_command="${cache_process_command_map["$process_pid"]}"
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
					local_new_config_content="$local_new_config_content\nfps_limit=$local_fps_to_set"
				else
					local_new_config_content="fps_limit=$local_fps_to_set"
				fi
				local_fps_limit_is_changed='1'
			else
				if [[ -n "$local_new_config_content" ]]; then
					local_new_config_content="$local_new_config_content\n$temp_config_line"
				else
					local_new_config_content="$temp_config_line"
				fi
			fi
		done <<< "$local_config_content"
		# Add 'fps_limit' line to config if it does not exist, i.e. was not found and changed
		if [[ -z "$local_fps_limit_is_changed" ]]; then
			echo "fps_limit=$local_fps_to_set" >> "$local_config"
		else
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
		trap 'print_info "Delayed for ${config_key_delay_map["$previous_section"]} second(s) CPU limiting of process '"'$previous_process_name'"' with PID $previous_process_pid has been cancelled." ; kill "$local_sleep_pid" > /dev/null 2>&1 ; return 0' SIGINT SIGTERM
		wait "$local_sleep_pid"
	fi
	print_verbose "Process '$previous_process_name' with PID $previous_process_pid has been CPU limited to $(( ${config_key_cpu_limit_map["$previous_section"]} / cpu_threads ))% on unfocus event."
	# Apply CPU limit
	cpulimit --lazy --limit="${config_key_cpu_limit_map["$previous_section"]}" --pid="$previous_process_pid" > /dev/null 2>&1 &
	# Remember PID of 'cpulimit' sent into background, required to print message about CPU unlimiting and terminate 'cpulimit' process on SIGINT/SIGTERM signal
	local_cpulimit_pid="$!"
	trap 'print_info "Process '"'$previous_process_name'"' with PID $previous_process_pid has been CPU unlimited on focus event." ; kill "$local_cpulimit_pid" > /dev/null 2>&1' SIGINT SIGTERM
	wait "$local_cpulimit_pid"
}

# Freeze process on unfocus event, required to run it on background to avoid stopping a whole code if delay specified
background_freeze_process(){
	# Freeze process with delay if specified, otherwise freeze process immediately
	if [[ "${config_key_delay_map["$previous_section"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be frozen after ${config_key_delay_map["$previous_section"]} second(s) on unfocus event."
		sleep "${config_key_delay_map["$previous_section"]}"
	fi
	# Freeze process if it still exists, otherwise throw warning
	if [[ -d "/proc/$previous_process_pid" ]]; then
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
	if [[ -d "/proc/$previous_process_pid" ]]; then
		if mangohud_fps_set "${config_key_mangohud_config_map["$previous_section"]}" "${config_key_fps_unfocus_map["$previous_section"]}"; then
			print_info "Section '$previous_section' has been FPS limited to ${config_key_fps_unfocus_map["$previous_section"]} FPS on unfocus event."
		fi
	else
		print_warn "Process matching with section '$previous_section' has been terminated before FPS limiting!"
	fi
}

# Required to unset limits on SIGTERM and SIGINT signals
actions_on_sigterm(){
	local temp_frozen_process_pid \
	temp_cpulimit_bgprocess_pid \
	temp_fps_limited_section
	# Unfreeze processes
	for temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Terminate background process if exists
		if [[ -d "/proc/${freeze_bgprocess_pid_map["$temp_frozen_process_pid"]}" ]]; then
			kill "${freeze_bgprocess_pid_map["$temp_frozen_process_pid"]}" > /dev/null 2>&1
		elif [[ -d "/proc/$temp_frozen_process_pid" ]]; then # Unfreeze process
			kill -CONT "$temp_frozen_process_pid" > /dev/null 2>&1
		fi
	done
	unset temp_frozen_process_pid
	# Terminate 'cpulimit' background processes
	for temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
		if [[ -d "/proc/$temp_cpulimit_bgprocess_pid" ]]; then
			kill "$temp_cpulimit_bgprocess_pid" > /dev/null 2>&1
		fi
	done
	unset temp_cpulimit_bgprocess_pid
	# Remove FPS limits
	for temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Terminate background process if exists
		if [[ -d "/proc/${fps_limit_bgprocess_pid_map["$temp_fps_limited_section"]}" ]]; then
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
		# Exit with an error if that is not a X11 session
		x11_session_check
		# Select command depending by type of option
		case "$1" in
		--focus | -f )
			# Get output of xprop containing window ID
			window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
			# Extract ID of focused window
			window_id="${window_id/*\# /}"
		;;
		--pick | -p )
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
		esac
		# Extract process info
		if extract_process_info; then
			echo "["$process_name"]
name = "$process_name"
executable = "$process_executable"
command = "$process_command"
owner = "$process_owner"
cpu-limit = 
mangohud-config = 
fps-unfocus = 
fps-focus = 
delay = 
focus = 
unfocus = 
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
		echo "flux 1.6.18
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
		# Regexp means 2+ symbols after hyphen (combined short options)
		if [[ "$1" =~ ^-.{2,}$ && ! "$1" =~ ^--.* ]]; then
			# Split combined option and add result to array
			for (( i = 0; i < ${#1} ; i++ )); do
				options+=("-${1:i:1}")
			done
			# Forget current option
			shift 1
			# Set split options
			set "${options[@]}" "$@"
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
	# Skip commented or blank line
	if [[ "$temp_config_line" =~ ^(\;|\#) || -z "$temp_config_line" ]]; then
		continue
	fi
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
cpu_limited_pid_map \
is_fps_limited_section_map \
fps_limit_bgprocess_pid_map \
fps_limited_section_map

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_process_name_map \
cache_process_executable_map \
cache_process_owner_map \
cache_process_command_map \
cache_section_map \
cache_mismatch_map

# Exit with an error if that is not a X11 session
x11_session_check

# Check for another instance and exit with an error if it exists
lock_file='/tmp/flux-lock'
if [[ -f "$lock_file" ]]; then
	print_error "Multiple instances are not allowed, make sure that daemon is not running before start, if you are really sure, then remove '$lock_file' file."
	exit 1
else
	touch "$lock_file"
fi

# Remove CPU and FPS limits of processes on exit
trap 'actions_on_sigterm ; print_info "Daemon has been terminated successfully." ; exit 0' SIGTERM SIGINT

# Read IDs of windows and apply actions
while read -r window_id; do
	# Exit with an error in case 'exit' event appears
	if [[ "$window_id" == 'exit' ]]; then
		actions_on_sigterm
		print_error "Daemon has been terminated unexpectedly!"
		exit 1
	elif [[ "$window_id" == 'nolazy' ]]; then # Unset '--lazy' option if responding event appears, otherwise focus and unfocus commands will not work
		unset lazy
		lazy_is_unset='1'
		continue
	elif [[ "$window_id" == 'nohot' ]]; then # Unset '--hot' if responding event appears, as it becomes useless from this moment
		unset hot
		continue
	elif [[ "$window_id" == 'refresh' ]]; then # Refresh PIDs and cache if responding event appears
		# Clean up cache to remove info about terminated PIDs which will not appear anymore
		for temp_cached_pid in "${cached_pids_array[@]}"; do
			# Remove info about process if it does not exist anymore
			if [[ ! -d "/proc/$temp_cached_pid" ]]; then
				print_verbose "Cache of process info '${cache_process_name_map["$temp_cached_pid"]}' with PID $temp_cached_pid has been removed as it has been terminated."
				cache_process_name_map["$temp_cached_pid"]=''
				cache_process_executable_map["$temp_cached_pid"]=''
				cache_process_owner_map["$temp_cached_pid"]=''
				cache_process_command_map["$temp_cached_pid"]=''
				cache_section_map["$temp_cached_pid"]=''
				cache_mismatch_map["$temp_cached_pid"]=''
				temp_cached_pids_to_remove_array+=("$temp_cached_pid")
			fi
		done
		unset temp_cached_pid
		# Remove terminated PIDs from array as their info has been removed above
		if [[ -n "${temp_cached_pids_to_remove_array[*]}" ]]; then 
			# Read array with PIDs
			for temp_cached_pid in "${cached_pids_array[@]}"; do
				# Unset flag which responds for matching of PID I want remove from main array to avoid false positive
				unset temp_found
				# Read array with PIDs I want remove
				for temp_cached_pid_to_remove in "${temp_cached_pids_to_remove_array[@]}"; do
					# Mark PID as found if it matches
					if [[ "$temp_cached_pid" == "$temp_cached_pid_to_remove" ]]; then
						temp_found='1'
						break
					fi
				done
				# Add PID to temporary array if it does not match
				if [[ -z "$temp_found" ]]; then
					temp_cached_pids_array+=("$temp_cached_pid")
				fi
			done
			cached_pids_array=("${temp_cached_pids_array[@]}")
			unset temp_cached_pid \
			temp_cached_pid_to_remove \
			temp_cached_pids_array \
			temp_cached_pids_to_remove_array \
			temp_found
		fi
		# Refresh frozen PIDs to remove processes which have been terminated implicitly, i.e. limits should not be removed as this PID will not appear again
		for temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
			# Store to array only existing PIDs, otherwise unset info about them
			if [[ -d "/proc/$temp_frozen_process_pid" ]]; then
				temp_frozen_processes_pids_array+=("$temp_frozen_process_pid")
			else
				is_frozen_pid_map["$temp_frozen_process_pid"]=''
				freeze_bgprocess_pid_map["$temp_frozen_process_pid"]=''
			fi
		done
		frozen_processes_pids_array=("${temp_frozen_processes_pids_array[@]}")
		unset temp_frozen_process_pid \
		temp_frozen_processes_pids_array
		# Refresh CPU limited PIDs to remove processes which have been terminated implicitly, i.e. limits should not be removed as this PID will not appear again
		for temp_cpulimit_bgprocess in "${cpulimit_bgprocesses_pids_array[@]}"; do
			if [[ -d "/proc/$temp_cpulimit_bgprocess" ]]; then
				temp_cpulimit_bgprocesses_pids_array+=("$temp_cpulimit_bgprocess")
			else
				is_cpu_limited_pid_map["${cpu_limited_pid_map["$temp_cpulimit_bgprocess"]}"]=''
				cpulimit_bgprocess_pid_map["${cpu_limited_pid_map["$temp_cpulimit_bgprocess"]}"]=''
				cpu_limited_pid_map["$temp_cpulimit_bgprocess"]=''
			fi
		done
		cpulimit_bgprocesses_pids_array=("${temp_cpulimit_bgprocesses_pids_array[@]}")
		unset temp_cpulimit_bgprocess \
		temp_cpulimit_bgprocesses_pids_array
		# Refresh FPS limited PIDs to remove processes which have been terminated
		for temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
			# Extract FPS limited PIDs
			for temp_fps_limited_pid in "${!fps_limited_section_map[@]}"; do
				# Check if section of FPS limited process matches with current
				if [[ "${fps_limited_section_map["$temp_fps_limited_pid"]}" == "$temp_fps_limited_section" ]]; then
					# Set mark to avoid unsetting FPS limit if matching process(es) still exist
					if [[ -d "/proc/$temp_fps_limited_pid" ]]; then
						temp_do_not_unset_fps_limit='1'
					else
						# Remove process from FPS limited by deassociating it with section
						fps_limited_section_map["$temp_fps_limited_pid"]=''
					fi
				fi
			done
			unset temp_fps_limited_pid
			# Unset FPS limit and if matching process(es) does not exist
			if [[ -z "$temp_do_not_unset_fps_limit" ]]; then
				# Set FPS from 'fps-focus' key
				if mangohud_fps_set "${config_key_mangohud_config_map["$temp_fps_limited_section"]}" "${config_key_fps_focus_map["$temp_fps_limited_section"]}"; then
					print_info "Section '$temp_fps_limited_section' has been FPS unlimited due to termination of matching process(es)."
				fi
				# Remove section from array
				for temp_sub_fps_limited_section in "${fps_limited_sections_array[@]}"; do
					# Skip FPS unlimited section as I want remove it from array
					if [[ "$temp_sub_fps_limited_section" != "$temp_fps_limited_section" ]]; then
						temp_fps_limited_sections_array+=("$temp_sub_fps_limited_section")
					fi
				done
				fps_limited_sections_array=("${temp_fps_limited_sections_array[@]}")
				unset temp_sub_fps_limited_section \
				temp_fps_limited_sections_array
				is_fps_limited_section_map["$temp_fps_limited_section"]=''
				fps_limit_bgprocess_pid_map["$temp_fps_limited_section"]=''
			fi
			unset temp_do_not_unset_fps_limit
		done
		unset temp_fps_limited_section
		# Skip cycle after refresh
		continue
	fi
	# Run command on unfocus event for previous window if specified in 'unfocus' key in config file
	if [[ -n "$previous_section" && -n "${config_key_unfocus_map["$previous_section"]}" && -z "$lazy" ]]; then
		# Required to avoid running unfocus command when new event appears after previous matching one when '--hot' option is used along with '--lazy'
		if [[ -z "$lazy_is_unset" ]]; then
			print_verbose "Running command on unfocus event '${config_key_unfocus_map["$previous_section"]}' from section '$previous_section'."
			# Pass variables to interact with them using custom commands in 'unfocus' key
			export_flux_variables "$previous_window_id" "$previous_process_pid" "$previous_process_name" "$previous_process_executable" "$previous_process_owner" "$previous_process_command"
			nohup setsid bash -c "${config_key_unfocus_map["$previous_section"]}" > /dev/null 2>&1 &
			unset_flux_variables
		else
			unset lazy_is_unset
		fi
	fi
	# Extract process info
	if ! extract_process_info; then
		print_warn "Unable to obtain PID of window with ID $window_id! Getting process info skipped."
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
		else # Obtain matching section from cache
			section="${cache_section_map["$process_pid"]}"
		fi
		if [[ -n "$section" ]]; then
			print_info "Process '$process_name' with PID $process_pid matches with section '$section'."
		else
			print_verbose "Process '$process_name' with PID $process_pid does not match with any section."
		fi
	fi
	# Check if PID is not the same as previous one
	if [[ "$process_pid" != "$previous_process_pid" ]]; then
		# Avoid applying CPU limit if owner does not have rights
		if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit_map["$previous_section"]}" != '-1' ]]; then
			# Check for existence of previous match and if CPU limit is set to 0
			if [[ -n "$previous_section" && "${config_key_cpu_limit_map["$previous_section"]}" == '0' ]]; then
				# Freeze process if it has not been frozen
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
				# Run 'cpulimit' on background if CPU limit has not been applied
				if [[ -z "${is_cpu_limited_pid_map["$previous_process_pid"]}" ]]; then
					# Apply CPU limit
					background_cpulimit &
					# Store PID of background process to array to interrupt it in case daemon exit
					cpulimit_bgprocesses_pids_array+=("$!")
					# Associate PID of background process with PID of process to interrupt it on focus event
					cpulimit_bgprocess_pid_map["$previous_process_pid"]="$!"
					# Associate PID of process with PID of background process, required to check process existence when refreshing array with CPU limited PIDs
					cpu_limited_pid_map["$!"]="$previous_process_pid"
					# Mark process as CPU limited
					is_cpu_limited_pid_map["$previous_process_pid"]='1'
				fi
			elif [[ -n "$previous_section" && -n "${config_key_fps_unfocus_map["$previous_section"]}" ]]; then # Check for existence of previous match and FPS limit
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
			print_warn "Unable to apply CPU or FPS limit to process '$previous_process_name' with PID $previous_process_pid, UID of process - $previous_process_owner, UID of user - $UID!"
		fi
	fi
	# Do not apply actions if window does not report its PID
	if [[ -n "$process_pid" ]]; then
		# Unfreeze process if window is focused
		if [[ -n "${is_frozen_pid_map["$process_pid"]}" ]]; then
			# Do not terminate background process if it does not exist anymore
			if [[ -d "/proc/${freeze_bgprocess_pid_map["$process_pid"]}" ]]; then
				# Terminate background process
				if ! kill "${freeze_bgprocess_pid_map["$process_pid"]}" > /dev/null 2>&1; then
					# Avoid printing this message if delay is not specified
					if [[ "${config_key_delay_map["$section"]}" != '0' ]]; then
						print_warn "Unable to cancel delayed for ${config_key_delay_map["$section"]} second(s) freezing of process '$process_name' with PID $process_pid!"
					fi
				else
					# Avoid printing this message if delay is not specified
					if [[ "${config_key_delay_map["$section"]}" != '0' ]]; then
						print_info "Delayed for ${config_key_delay_map["$section"]} second(s) freezing of process '$process_name' with PID $process_pid has been cancelled."
					fi
				fi
			else
				# Unfreeze process
				if ! kill -CONT "$process_pid" > /dev/null 2>&1; then
					print_warn "Unable to unfreeze process '$process_name' with PID $process_pid!"
				else
					print_info "Process '$process_name' with PID $process_pid has been unfrozen on focus event."
				fi
			fi
			# Remove PID from array
			for temp_frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
				# Skip current PID as I want remove it from array
				if [[ "$temp_frozen_process_pid" != "$process_pid" ]]; then
					temp_frozen_processes_pids_array+=("$temp_frozen_process_pid")
				fi
			done
			frozen_processes_pids_array=("${temp_frozen_processes_pids_array[@]}")
			unset temp_frozen_process_pid \
			temp_frozen_processes_pids_array
			is_frozen_pid_map["$process_pid"]=''
			freeze_bgprocess_pid_map["$process_pid"]=''
		elif [[ -n "${is_cpu_limited_pid_map["$process_pid"]}" ]]; then # Check for CPU limit existence and unset it
			# Terminate 'cpulimit' background process
			if ! kill "${cpulimit_bgprocess_pid_map["$process_pid"]}" > /dev/null 2>&1; then
				print_warn "Process '$process_name' with PID $process_pid cannot be CPU unlimited!"
			fi
			# Remove PID of 'cpulimit' background process from array
			for temp_cpulimit_bgprocess_pid in "${cpulimit_bgprocesses_pids_array[@]}"; do
				# Skip interrupted background process as I want remove it from array
				if [[ "$temp_cpulimit_bgprocess_pid" != "${cpulimit_bgprocess_pid_map["$process_pid"]}" ]]; then
					temp_cpulimit_bgprocesses_pids_array+=("$temp_cpulimit_bgprocess_pid")
				fi
			done
			cpulimit_bgprocesses_pids_array=("${temp_cpulimit_bgprocesses_pids_array[@]}")
			unset temp_cpulimit_bgprocess_pid \
			temp_cpulimit_bgprocesses_pids_array
			is_cpu_limited_pid_map["$process_pid"]=''
			cpu_limited_pid_map["${cpulimit_bgprocess_pid_map["$process_pid"]}"]=''
			cpulimit_bgprocess_pid_map["$process_pid"]=''
		elif [[ -n "$section" && -n "${is_fps_limited_section_map["$section"]}" ]]; then # Check for FPS limit existence and unset it
			# Terminate delayed FPS limit background process if exists
			if [[ -d "${fps_limit_bgprocess_pid_map["$section"]}" ]]; then
				if ! kill "${fps_limit_bgprocess_pid_map["$section"]}" > /dev/null 2>&1; then
					# Avoid printing this message if delay is not specified
					if [[ "${config_key_delay_map["$section"]}" != '0' ]]; then
						print_warn "Unable to cancel delayed for ${config_key_delay_map["$section"]} second(s) FPS limiting of section '$section'!"
					fi
				else
					# Avoid printing this message if delay is not specified
					if [[ "${config_key_delay_map["$section"]}" != '0' ]]; then
						print_info "Delayed for ${config_key_delay_map["$section"]} second(s) FPS limiting of section '$section' has been cancelled."
					fi
				fi
			fi
			# Set FPS from 'fps-focus' key
			if mangohud_fps_set "${config_key_mangohud_config_map["$section"]}" "${config_key_fps_focus_map["$section"]}"; then
				print_info "Section '$section' has been FPS unlimited on focus event."
			fi
			# Forget that process(es) matching with current section have been FPS limited previously
			for temp_fps_limited_pid in "${!fps_limited_section_map[@]}"; do
				if [[ "${fps_limited_pid_map["$temp_fps_limited_pid"]}" == "$section" ]]; then
					fps_limited_pid_map["$temp_fps_limited_pid"]=''
				fi
			done
			unset temp_fps_limited_pid
			# Remove section from array
			for temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
				# Skip FPS unlimited section as I want remove it from array
				if [[ "$temp_fps_limited_section" != "$section" ]]; then
					temp_fps_limited_sections_array+=("$temp_fps_limited_section")
				fi
			done
			fps_limited_sections_array=("${temp_fps_limited_sections_array[@]}")
			unset temp_fps_limited_section \
			temp_fps_limited_sections_array
			is_fps_limited_section_map["$section"]=''
			fps_limit_bgprocess_pid_map["$section"]=''
		fi
	fi
	# Run command on focus event if specified in 'focus' key in config file
	if [[ -n "$section" && -n "${config_key_focus_map["$section"]}" && -z "$lazy" ]]; then
		# Pass variables to interact with them using custom commands in 'focus' key
		export_flux_variables "$window_id" "$process_pid" "$process_name" "$process_executable" "$process_owner" "$process_command"
		nohup setsid bash -c "${config_key_focus_map["$section"]}" > /dev/null 2>&1 &
		unset_flux_variables
		print_verbose "Running command on focus event '${config_key_focus_map["$section"]}' from section '$section'."
	fi
	# Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'unfocus' key
	previous_window_id="$window_id"
	previous_process_pid="$process_pid"
	previous_process_name="$process_name"
	previous_process_executable="$process_executable"
	previous_process_owner="$process_owner"
	previous_process_command="$process_command"
	previous_section="$section"
	# Unset info about process to avoid using it in some rare cases (idk why that happens, noticed that only once after a few hours of using daemon)
	unset window_id \
	process_pid \
	process_name \
	process_executable \
	process_owner \
	process_command
	# Unset to avoid false positive on next event
	unset section
done < <(xprop_event_reader)