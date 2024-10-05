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

# Exit with an error if option repeated
option_repeat_check(){
	if [[ -n "${!1}" ]]; then
		print_error "Option '$2' is repeated!$advice_on_option_error"
		exit 1
	fi
}

# Required to exit with an error if that is not a X11 session
x11_session_check(){
	# Exit with an error if that is not a X11 session
	if [[ ! "$DISPLAY" =~ ^\:[0-9]+(\.[0-9]+)?$ || "$XDG_SESSION_TYPE" != 'x11' ]]; then
		print_error "Flux is not meant to use it with anything but X11!"
		exit 1
	fi
}

# Extract window IDs from xprop events
xprop_event_reader(){
	local local_stacking_windows_id local_focused_window_id local_stacking_window_id
	# Print window IDs of open windows to apply limits immediately if '--hot' option was passed
	if [[ -n "$hot" ]]; then
		# Extract IDs of open windows
		local_stacking_windows_id="$(xprop -root _NET_CLIENT_LIST_STACKING 2>/dev/null)"
		if [[ "$local_stacking_windows_id" != '_NET_CLIENT_LIST_STACKING:  no such atom on any window.' ]]; then
			local_stacking_windows_id="${local_stacking_windows_id/* \# /}"
			local_stacking_windows_id="${local_stacking_windows_id//\,/}"
		else
			# Print event for safe exit if cannot obtain list of stacking windows
			print_error "Unable to get list of stacking windows!"
			echo 'exit'
		fi
		# Extract ID of focused window
		local_focused_window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
		if [[ "$local_focused_window_id" != '_NET_ACTIVE_WINDOW:  no such atom on any window.' ]]; then
			local_focused_window_id="${local_focused_window_id/* \# /}"
		else
			# Print event for safe exit if cannot obtain ID of focused window
			print_error "Unable to get ID of focused window!"
			echo 'exit'
		fi
		# Print IDs of windows, but skip currently focused window
		for local_stacking_window_id in $local_stacking_windows_id; do
			if [[ "$local_stacking_window_id" != "$local_focused_window_id" ]]; then
				echo "$local_stacking_window_id"
			fi
		done
		unset local_stacking_windows_id local_focused_window_id local_stacking_window_id
		# Print event for unset '--hot' option since it becomes useless from this moment
		echo 'nohot'
	fi
	# Print event for unset '--lazy' option before reading events, otherwise focus and unfocus commands will not work
	if [[ -n "$lazy" ]]; then
		echo 'nolazy'
	fi
	# Restart event reading if 'xprop' process has been terminated
	while true; do
		# Break loop if exit variable appears not blank
		if [[ -n "$exit" ]]; then
			break
		fi
		# Print warning in case loop was restarted
		if [[ -n "$first_loop" ]]; then
			print_warn "Process 'xprop' required for reading X11 events has been restarted by daemon after termination!"
		else
			first_loop='1'
		fi
		# Read events from xprop and print IDs of windows
		while read -r xprop_event; do
			# Print event for safe exit in case X server dies
			if [[ "$xprop_event" =~ 'X connection to :'[0-9]+' broken (explicit kill or server shutdown).' ]]; then
				print_error "X server on display $DISPLAY has been terminated!"
				echo 'exit'
				exit='1'
			fi
			# Extract ID from line
			window_id="${xprop_event/* \# /}"
			# Skip event if window ID is exactly the same as previous one, workaround required for some buggy WMs
			if [[ "$window_id" == "$previous_window_id" ]]; then
				continue
			else
				# Do not print bad events, workaround required for some buggy WMs
				if [[ "$window_id" =~ ^0x[0-9a-fA-F]{7}$ ]]; then
					echo "$window_id"
					# Remember ID to compare it with new one, if ID is exactly the same, then event will be skipped
					previous_window_id="$window_id"
				fi
			fi
		done < <(xprop -root -spy _NET_ACTIVE_WINDOW 2>&1)
	done
}

# Export variables for focus and unfocus commands
export_flux_variables(){
	export FLUX_WINDOW_ID="$1"
	export FLUX_PROCESS_PID="$2"
	export FLUX_PROCESS_NAME="$3"
	export FLUX_PROCESS_EXECUTABLE="$4"
	export FLUX_PROCESS_OWNER="$5"
	export FLUX_PROCESS_COMMAND="$6"
}

# Unset exported variables because those become useless after running command
unset_flux_variables(){
	unset FLUX_WINDOW_ID FLUX_PROCESS_PID FLUX_PROCESS_NAME FLUX_PROCESS_EXECUTABLE FLUX_PROCESS_OWNER FLUX_PROCESS_COMMAND
}

# Extract process info
extract_process_info(){
	local local_status_line local_column_count local_status_column
	# Extract PID of process
	if ! process_pid="$(xprop -id "$window_id" _NET_WM_PID 2>/dev/null)"; then
		process_pid=''
	elif [[ "$process_pid" == '_NET_WM_PID:  not found.' ]]; then
		process_pid=''
	fi
	if [[ -n "$process_pid" ]]; then
		process_pid="${process_pid/* = /}"
		# Check if info about process exists in cache
		if [[ -z "${cache_process_name["$process_pid"]}" ]]; then
			# Extract name of process
			process_name="$(<"/proc/$process_pid/comm")"
			# Extract executable path of process
			process_executable="$(readlink "/proc/$process_pid/exe")"
			# Extract UID of process
			while read -r local_status_line; do
				if [[ "$local_status_line" == 'Uid:'* ]]; then
					local_column_count='0'
					for local_status_column in $local_status_line; do
						if (( local_column_count == 3 )); then
							process_owner="$local_status_column"
						else
							(( local_column_count++ ))
						fi
					done
				fi
			done < "/proc/$process_pid/status"
			# I did not get how to do that using built-in bash options
			# Extract command of process and replace '\0' (used as separator between options) with spaces
			process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
			# Remove last space since '\0' is a last symbol too
			process_command="${process_command/%\ /}"
			# Add all variables to cache
			cache_process_name["$process_pid"]="$process_name"
			cache_process_executable["$process_pid"]="$process_executable"
			cache_process_owner["$process_pid"]="$process_owner"
			cache_process_command["$process_pid"]="$process_command"
			# Store PID to array to make it easier to remove info from cache in case process does not exist
			cached_pids_array+=("$process_pid")
		else
			# Set values from cache
			process_name="${cache_process_name["$process_pid"]}"
			process_executable="${cache_process_executable["$process_pid"]}"
			process_owner="${cache_process_owner["$process_pid"]}"
			process_command="${cache_process_command["$process_pid"]}"
		fi
	else
		return 1
	fi
}

# Change FPS limit in specified MangoHud config
mangohud_fps_set(){
	local local_config_line local_config_content local_new_config_content local_config="$1" local_fps_to_set="$2" local_fps_limit_is_changed
	# Check if config file exists before continue in case it has been removed
	if [[ -f "$local_config" ]]; then
		# Return an error if file is not readable
		if ! local_config_content="$(<"$local_config")"; then
			print_warn "Unable to read MangoHud config file '$local_config'!"
			return 1
		fi
		# Replace 'fps_limit' value in config if exists
		while read -r local_config_line || [[ -n "$local_config_line" ]]; do
			# Find 'fps_limit' line
			if [[ "$local_config_line" == 'fps_limit='* ]]; then
				# Set specified FPS limit
				if [[ -n "$local_new_config_content" ]]; then
					local_new_config_content="$local_new_config_content\nfps_limit=$local_fps_to_set"
				else
					local_new_config_content="fps_limit=$local_fps_to_set"
				fi
				local_fps_limit_is_changed='1'
			else
				if [[ -n "$local_new_config_content" ]]; then
					local_new_config_content="$local_new_config_content\n$local_config_line"
				else
					local_new_config_content="$local_config_line"
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

# Apply CPU limit via 'cpulimit' tool on unfocus event, function required to run it on background to avoid stopping a whole code if delay specified
background_cpulimit(){
	local local_cpulimit_pid
	# Wait for delay if specified
	if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be CPU limited after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
		sleep "${config_key_delay["$previous_section_name"]}"
	fi
	print_verbose "Process '$previous_process_name' with PID $previous_process_pid has been CPU limited to $(( ${config_key_cpu_limit["$previous_section_name"]} / cpu_threads ))% on unfocus event."
	# Apply CPU limit
	cpulimit --lazy --limit="${config_key_cpu_limit["$previous_section_name"]}" --pid="$previous_process_pid" > /dev/null 2>&1 &
	# Remember PID, set action to kill it on INT/TERM signals and wait until it done
	local_cpulimit_pid="$!"
	trap "kill $local_cpulimit_pid > /dev/null 2>&1" SIGINT SIGTERM
	wait "$local_cpulimit_pid"
}

# Freeze process on unfocus event, function required to run it on background to avoid stopping a whole code if delay specified
background_freeze_process(){
	# Freeze process with delay if specified, otherwise freeze process immediately
	if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be frozen after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
		sleep "${config_key_delay["$previous_section_name"]}"
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

# Set specified FPS on unfocus, function required to run it on background to avoid stopping a whole code if delay specified
background_mangohud_fps_set(){
	# Wait in case delay is specified
	if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
		print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be FPS limited after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
		sleep "${config_key_delay["$previous_section_name"]}"
	fi
	# Apply FPS limit if target still exists, otherwise throw warning
	if [[ -d "/proc/$previous_process_pid" ]]; then
		if mangohud_fps_set "${config_key_mangohud_config["$previous_section_name"]}" "${config_key_fps_unfocus["$previous_section_name"]}"; then
			print_info "Process '$previous_process_name' with PID $previous_process_pid has been FPS limited to ${config_key_fps_unfocus["$previous_section_name"]} FPS on unfocus event."
		fi
	fi
	# Wait for process termination to unset FPS limit
	print_verbose "Waiting for termination of process '$previous_process_name' with PID $previous_process_pid to unset FPS limit..."
	sleep 1 # Wait a bit in case process terminates immediately after unfocus to avoid waiting for 5 seconds
	while true; do
		if [[ -d "/proc/$previous_process_pid" ]]; then
			# Yes, I know, there is no better way, 'wait' does not work for processes started outside of current shell
			sleep 5
		else
			break
		fi
	done
	# Unset FPS limit
	if mangohud_fps_set "${config_key_mangohud_config["$previous_section_name"]}" "${config_key_fps_focus["$previous_section_name"]}"; then
		print_info "Process '$previous_process_name' with PID $previous_process_pid has been FPS unlimited after termination."
	fi
}

# Actions on SIGTERM and SIGINT signals
actions_on_sigterm(){
	# Unfreeze processes
	for frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Terminate background process if exists
		if [[ -d "/proc/${freeze_bgprocess_pid["$frozen_process_pid"]}" ]]; then
			if ! kill "${freeze_bgprocess_pid["$frozen_process_pid"]}" > /dev/null 2>&1; then
				print_warn "Unable to cancel delayed for ${config_key_delay["${cache_section["$frozen_process_pid"]}"]} second(s) freezing of process '${cache_process_name["$frozen_process_pid"]}' with PID $frozen_process_pid!"
			else
				# Avoid printing this message if delay is not specified
				if [[ "${config_key_delay["${cache_section["$frozen_process_pid"]}"]}" != '0' ]]; then
					print_verbose "Delayed for ${config_key_delay["${cache_section["$frozen_process_pid"]}"]} second(s) freezing of process '${cache_process_name["$frozen_process_pid"]}' with PID $frozen_process_pid has been cancelled on daemon termination."
				fi
			fi
		elif [[ -d "/proc/$frozen_process_pid" ]]; then # Unfreeze process
			if ! kill -CONT "$frozen_process_pid" > /dev/null 2>&1; then
				print_warn "Process '${cache_process_name["$frozen_process_pid"]}' with PID $frozen_process_pid cannot be unfrozen on daemon termination!"
			else
				print_verbose "Process '${cache_process_name["$frozen_process_pid"]}' with PID $frozen_process_pid has been unfrozen on daemon termination."
			fi
		fi
	done
	# Kill cpulimit background process
	for cpulimit_bgprocess_pid_var in "${cpulimit_bgprocesses_pids_array[@]}"; do
		if [[ -d "/proc/$cpulimit_bgprocess_pid_var" ]]; then
			if ! kill "$cpulimit_bgprocess_pid_var" > /dev/null 2>&1; then
				print_warn "Process '${cache_process_name["${cpu_limited_pid["${cpulimit_bgprocess_pid_var}"]}"]}' with PID ${cpu_limited_pid["${cpulimit_bgprocess_pid_var}"]} cannot be CPU unlimited on daemon termination!"
			else
				print_verbose "Process '${cache_process_name["${cpu_limited_pid["${cpulimit_bgprocess_pid_var}"]}"]}' with PID ${cpu_limited_pid["${cpulimit_bgprocess_pid_var}"]} has been CPU unlimited on daemon termination."
			fi
		fi
	done
	# Remove FPS limits
	for fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Terminate background process if exists
		if [[ -d "/proc/${fps_limit_bgprocess_pid["${fps_limited_pid["$fps_limited_section"]}"]}" ]]; then
			if ! kill "${fps_limit_bgprocess_pid["${fps_limited_pid["$fps_limited_section"]}"]}" > /dev/null 2>&1; then
				print_warn "Unable to stop FPS limit background process with PID ${fps_limit_bgprocess_pid["${fps_limited_pid["$fps_limited_section"]}"]}!"
			else
				print_verbose "FPS limit background process related to process '${cache_process_name["${fps_limited_pid["$fps_limited_section"]}"]}' with PID ${fps_limited_pid["$fps_limited_section"]} has been terminated on daemon termination."
			fi
		fi
		# Set FPS from 'fps-focus' key to remove limit
		if mangohud_fps_set "${config_key_mangohud_config["$fps_limited_section"]}" "${config_key_fps_focus["$fps_limited_section"]}"; then
			print_verbose "Process '${cache_process_name["${fps_limited_pid["$fps_limited_section"]}"]}' with PID ${fps_limited_pid["$fps_limited_section"]} has been FPS unlimited on daemon termination."
		fi
	done
}

# Remove CPU limits and FPS limits of processes on exit
trap 'actions_on_sigterm ; print_info "Daemon has been terminated successfully." ; exit 0' SIGTERM SIGINT

# Prefixes for output
error_prefix="[x]"
info_prefix="[i]"
verbose_prefix="[v]"
warn_prefix="[!]"

# Additional text for errors related to option parsing
advice_on_option_error="\n$info_prefix Try 'flux --help' for more information."

# Read options
while (( $# > 0 )); do
	case "$1" in
	--config | -c | --config=* )
		# Remember that option was passed in case if path was not specified
		option_repeat_check config_is_passed --config
		config_is_passed='1'
		# Define option type (short, long or long+value) and remember specified path
		case "$1" in
		--config | -c )
			# Remember config path only if path was specified, otherwise shift option
			if [[ -n "$2" && -f "$2" ]]; then
				config="$2"
				shift 2
			else
				shift 1
			fi
		;;
		* )
			# Shell parameter expansion, remove '--config=' from string
			config="${1/--config=/}"
			# Unset config path if file does not exist
			if [[ ! -f "$config" ]]; then
				unset config
			fi
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
			if ! window_id="$(xwininfo 2>/dev/null)"; then
				print_error "Unable to grab cursor to pick a window!"
				exit 1
			else
				# Extract ID of focused window
				while read -r window_id_line; do
					if [[ "$window_id_line" == 'xwininfo: Window id: '* ]]; then
						window_id="${window_id_line/*: /}"
						window_id="${window_id/ */}"
						break
					fi
				done <<< "$window_id"
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
			print_error "Unable to create template for window with ID $window_id since it does not report its PID!"
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
		echo "flux 1.6.11
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

# Automatically set a path to config file if it is not specified
if [[ -z "$config" ]]; then
	# Set XDG_CONFIG_HOME automatically if it is not specified
	if [[ -z "$XDG_CONFIG_HOME" ]]; then
		XDG_CONFIG_HOME="$HOME/.config"
	fi
	# Find a config
	for config_path in '/etc/flux.ini' "$XDG_CONFIG_HOME/flux.ini" "$HOME/.config/flux.ini"; do
		if [[ -f "$config_path" ]]; then
			config="$config_path"
			break
		fi
	done
	unset config_path
fi

# Exit with an error if config file is not found
if [[ -z "$config" ]]; then
	print_error "Config file is not found!$advice_on_option_error"
	exit 1
fi

# Calculate maximum allowable CPU limit and CPU threads
cpu_threads='0'
while read -r cpuinfo_line; do
	if [[ "$cpuinfo_line" == 'processor'* ]]; then
		(( cpu_threads++ ))
	fi
done < '/proc/cpuinfo'
max_cpu_limit="$(( cpu_threads * 100 ))"
unset cpuinfo_line

# Create associative arrays to store values from config
declare -A \
config_key_name \
config_key_executable \
config_key_owner \
config_key_cpu_limit \
config_key_delay \
config_key_focus \
config_key_unfocus \
config_key_command \
config_key_mangohud_config \
config_key_fps_unfocus \
config_key_fps_focus

# INI parser
while read -r temp_config_line || [[ -n "$temp_config_line" ]]; do
	# Skip commented or blank line
	if [[ "$temp_config_line" =~ ^(\;|\#) || -z "$temp_config_line" ]]; then
		continue
	fi
	# Exit with an error if first line is not a section, otherwise remember section name
	if [[ ! "$temp_config_line" =~ ^\[.*\]$ && -z "$section" ]]; then
		print_error "Initial section is not found in config '$config'!"
		exit 1
	elif [[ "$temp_config_line" =~ ^\[.*\]$ ]]; then
		# Exit with an error if section repeated
		if [[ -n "${sections_array[*]}" ]]; then
			for section_from_array in "${sections_array[@]}"; do
				if [[ "[$section_from_array]" == "$temp_config_line" ]]; then
					print_error "Section name '$section' is repeated!"
					exit 1
				fi
			done
			unset section_from_array
		fi
		# Remove square brackets from section name and add it to array
		# Array required to check for repeating sections and find matching rule(s) for process in config
		section="${temp_config_line/\[/}"
		section="${section/%\]/}"
		sections_array+=("$section")
		# Forward to next line
		continue
	fi
	# Exit with an error if type of line cannot be defined
	if [[ "${temp_config_line,,}" =~ ^(name|executable|owner|cpu-limit|delay|focus|unfocus|command|mangohud-config|fps-unfocus|fps-focus)(\ )?=(\ )?.* ]]; then
		# Extract value from key by removing key and equal symbol
		if [[ "$temp_config_line" == *'= '* ]]; then
			value="${temp_config_line/*= /}" # <-
		elif [[ "$temp_config_line" == *'='* ]]; then
			value="${temp_config_line/*=/}" # <-
		fi
		# Remove comments from value
		if [[ "$value" =~ \ (\#|\;) && ! "$value" =~ ^(\".*\"|\'.*\')$ ]]; then
			if [[ "$value" =~ \# ]]; then
				value="${value/ \#*/}"
			else
				value="${value/ \;*/}"
			fi
		fi
		# Remove single/double quotes
		if [[ "$value" =~ ^(\".*\"|\'.*\')$ ]]; then
			if [[ "$value" =~ ^\".*\"$ ]]; then
				value="${value/\"/}"
				value="${value/%\"/}"
			else
				value="${value/\'/}"
				value="${value/%\'/}"
			fi
		fi
		# Associate value with section
		case "${temp_config_line,,}" in
		name* )
			config_key_name["$section"]="$value"
		;;
		executable* )
			config_key_executable["$section"]="$value"
		;;
		owner* )
			# Exit with an error if UID is not numeric
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_key_owner["$section"]="$value"
			else
				print_error "Value '$value' in key 'owner' in section '$section' is not UID!"
				exit 1
			fi
		;;
		cpu-limit* )
			# Exit with an error if CPU limit is specified incorrectly
			if [[ "$value" =~ ^[0-9]+(\%)?$ || "$value" =~ ^('-1'|'-1%')$ ]] && (( "${value/%\%/}" * cpu_threads <= max_cpu_limit )); then
				if [[ "$value" =~ ^('-1'|'-1%')$ ]]; then
					config_key_cpu_limit["$section"]="${value/%\%/}"
				else
					config_key_cpu_limit["$section"]="$(( "${value/%\%/}" * cpu_threads ))"
				fi
			else
				print_error "Value '$value' in key 'cpulimit' in section '$section' is invalid! Allowed values are 0-100%."
				exit 1
			fi
		;;
		delay* )
			# Exit with an error if value is neither an integer nor a float (that is what regexp means)
			if [[ "$value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
				config_key_delay["$section"]="$value"
			else
				print_error "Value '$value' in key 'delay' in section '$section' is neither integer nor float!"
				exit 1
			fi
		;;
		focus* )
			config_key_focus["$section"]="$value"
		;;
		unfocus* )
			config_key_unfocus["$section"]="$value"
		;;
		command* )
			config_key_command["$section"]="$value"
		;;
		mangohud-config* )
			# Exit with an error if specified MangoHud config file does not exist
			if [[ -f "$value" ]]; then
				config_key_mangohud_config["$section"]="$value"
			else
				print_error "Config file '$value' specified in key 'mangohud-config' in section '$section' does not exist!"
				exit 1
			fi
		;;
		fps-unfocus* )
			# Exit with an error if value is not integer
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				# Exit with an error if value equal to zero
				if [[ "$value" != '0' ]]; then
					config_key_fps_unfocus["$section"]="$value"
				else
					print_error "Value $value in key 'fps-unfocus' in section '$section' should be greater than zero!"
					exit 1
				fi
			else
				print_error "Value '$value' specified in key 'fps-unfocus' in section '$section' is not an integer!"
				exit 1
			fi
		;;
		fps-focus* )
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_key_fps_focus["$section"]="$value"
			else
				print_error "Value '$value' specified in key 'fps-focus' in section '$section' is not an integer!"
				exit 1
			fi
		esac
	else
		print_error "Unable to define type of line '$temp_config_line'!"
		exit 1
	fi
done < "$config"
unset temp_config_line value section

# Check values in sections
for section_from_array in "${sections_array[@]}"; do
	# Exit with an error if neither identifier 'name' nor 'executable' nor 'command' is specified
	if [[ -z "${config_key_name["$section_from_array"]}" && -z "${config_key_executable["$section_from_array"]}" && -z "${config_key_command["$section_from_array"]}" ]]; then
		print_error "At least one process identifier required in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS limit is not specified along with config path
	if [[ -n "${config_key_fps_unfocus["$section_from_array"]}" && -z "${config_key_mangohud_config["$section_from_array"]}" ]]; then
		print_error "Value ${config_key_fps_unfocus["$section_from_array"]} in key 'fps-unfocus' in section '$section_from_array' is specified without path to MangoHud config!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS limit is specified along with CPU limit
	if [[ -n "${config_key_fps_unfocus["$section_from_array"]}" && -n "${config_key_cpu_limit["$section_from_array"]}" && "${config_key_cpu_limit["$section_from_array"]}" != '-1' ]]; then
		print_error "Do not use FPS limit along with CPU limit in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if 'fps-focus' is specified without 'fps-unfocus'
	if [[ -n "${config_key_fps_focus["$section_from_array"]}" && -z "${config_key_fps_unfocus["$section_from_array"]}" ]]; then
		print_error "Do not use 'fps-focus' key without 'fps-unfocus' key in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if 'mangohud-config' is specified without 'fps-unfocus'
	if [[ -n "${config_key_mangohud_config["$section_from_array"]}" && -z "${config_key_fps_unfocus["$section_from_array"]}" ]]; then
		print_error "Do not use 'mangohud-config' key without 'fps-unfocus' key in section '$section_from_array'!"
		exit 1
	fi
	# Set 'fps-focus' to '0' (none) if it is not specified
	if [[ -n "${config_key_fps_unfocus["$section_from_array"]}" && -z "${config_key_fps_focus["$section_from_array"]}" ]]; then
		config_key_fps_focus["$section_from_array"]='0'
	fi
	# Set CPU limit to '-1' (none) if it is not specified
	if [[ -z "${config_key_cpu_limit["$section_from_array"]}" ]]; then
		config_key_cpu_limit["$section_from_array"]='-1'
	fi
	# Set 'delay' to '0' if it is not specified
	if [[ -z "${config_key_delay["$section_from_array"]}" ]]; then
		config_key_delay["$section_from_array"]='0'
	fi
done
unset section_from_array

# Declare associative arrays to store info about applied actions
declare -A \
is_frozen_pid \
freeze_bgprocess_pid \
is_cpu_limited_pid \
cpulimit_bgprocess_pid \
cpu_limited_pid \
is_fps_limited_section \
fps_limit_bgprocess_pid \
fps_limited_pid

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A \
cache_process_name \
cache_process_executable \
cache_process_owner \
cache_process_command \
cache_section \
cache_mismatch

# Exit with an error if that is not a X11 session
x11_session_check

# Read IDs of windows and apply actions
while read -r window_id; do
	# Exit with an error in case 'exit' event appears
	if [[ "$window_id" == 'exit' ]]; then
		actions_on_sigterm
		print_error "Daemon has been terminated unexpectedly!"
		exit 1
	elif [[ "$window_id" == 'nolazy' ]]; then # Unset '--lazy' option if event was passed, otherwise focus and unfocus commands will not work
		unset lazy
		lazy_is_unset='1'
		continue
	elif [[ "$window_id" == 'nohot' ]]; then # Unset '--hot' since it becomes useless from this moment
		unset hot
		continue
	fi
	# Clean up cache to remove terminated PIDs which will not appear anymore
	for cached_pid in "${cached_pids_array[@]}"; do
		# Remove info about process if it does not exist anymore
		if [[ ! -d "/proc/$cached_pid" ]]; then
			print_verbose "Cache of process '${cache_process_name["$cached_pid"]}' with PID $cached_pid has been removed."
			cache_process_name["$cached_pid"]=''
			cache_process_executable["$cached_pid"]=''
			cache_process_owner["$cached_pid"]=''
			cache_process_command["$cached_pid"]=''
			cache_section["$cached_pid"]=''
			cache_mismatch["$cached_pid"]=''
			cached_pids_to_remove_array+=("$cached_pid")
		fi
	done
	# Remove terminated PIDs from array as their info has been removed above
	if [[ -n "${cached_pids_to_remove_array[*]}" ]]; then 
		# Read array with PIDs
		for cached_pid in "${cached_pids_array[@]}"; do
			# Unset flag which responds for matching of PID I want remove from main array to avoid false positive
			unset found
			# Read array with PIDs I want remove
			for cached_pid_to_remove in "${cached_pids_to_remove_array[@]}"; do
				# Mark PID as found if it matches
				if [[ "$cached_pid" == "$cached_pid_to_remove" ]]; then
					found='1'
					break
				fi
			done
			# Add PID to temporary array if it does not match
			if [[ -z "$found" ]]; then
				cached_pids_array_temp+=("$cached_pid")
			fi
		done
		cached_pids_array=("${cached_pids_array_temp[@]}")
		unset cached_pid cached_pid_to_remove cached_pids_array_temp cached_pids_to_remove_array found
	fi
	# Refresh frozen PIDs to remove processes which have been terminated implicitly, i.e. limits should not be removed as this PID won't repeat
	for frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		# Store to array only existing PIDs, otherwise unset info about them
		if [[ -d "/proc/$frozen_process_pid" ]]; then
			frozen_processes_pids_array_temp+=("$frozen_process_pid")
		else
			is_frozen_pid["$frozen_process_pid"]=''
			freeze_bgprocess_pid["$frozen_process_pid"]=''
		fi
	done
	frozen_processes_pids_array=("${frozen_processes_pids_array_temp[@]}")
	unset frozen_process_pid frozen_processes_pids_array_temp
	# Refresh CPU limited PIDs to remove processes which have been terminated implicitly, i.e. limits should not be removed as this PID won't repeat
	for cpulimit_bgprocess_pid_var in "${cpulimit_bgprocesses_pids_array[@]}"; do
		if [[ -d "/proc/$cpulimit_bgprocess_pid_var" ]]; then
			cpulimit_bgprocesses_pids_array_temp+=("$cpulimit_bgprocess_pid_var")
		else
			is_cpu_limited_pid["${cpu_limited_pid["$cpulimit_bgprocess_pid_var"]}"]=''
			cpulimit_bgprocess_pid["${cpu_limited_pid["$cpulimit_bgprocess_pid_var"]}"]=''
			cpu_limited_pid["$cpulimit_bgprocess_pid_var"]=''
		fi
	done
	cpulimit_bgprocesses_pids_array=("${cpulimit_bgprocesses_pids_array_temp[@]}")
	unset cpulimit_bgprocess_pid_var cpulimit_bgprocesses_pids_array_temp
	# Refresh FPS limited PIDs to remove processes which have been terminated implicitly, i.e. limits should not be removed as this PID won't repeat
	for fps_limited_section in "${fps_limited_sections_array[@]}"; do
		if [[ -d "/proc/${fps_limited_pid["$fps_limited_section"]}" ]]; then
			fps_limited_sections_array_temp+=("$fps_limited_section")
		else
			is_fps_limited_section["$fps_limited_section"]=''
			fps_limit_bgprocess_pid["${fps_limited_pid["$fps_limited_section"]}"]=''
			fps_limited_pid["$fps_limited_section"]=''
		fi
	done
	fps_limited_sections_array=("${fps_limited_sections_array_temp[@]}")
	unset fps_limited_section fps_limited_sections_array_temp
	# Run command on unfocus event for previous window if specified
	if [[ -n "$previous_section_name" && -n "${config_key_unfocus["$previous_section_name"]}" && -z "$lazy" ]]; then
		# Required to avoid running unfocus command when new event appears after previous matching one when '--hot' option is used along with '--lazy'
		if [[ -z "$lazy_is_unset" ]]; then
			print_verbose "Running command on unfocus event '${config_key_unfocus["$previous_section_name"]}' from section '$previous_section_name'."
			# Variables passthrough to interact with them using custom commands in 'unfocus' key
			export_flux_variables "$previous_window_id" "$previous_process_pid" "$previous_process_name" "$previous_process_executable" "$previous_process_owner" "$previous_process_command"
			nohup setsid bash -c "${config_key_unfocus["$previous_section_name"]}" > /dev/null 2>&1 &
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
		if [[ -z "${cache_section["$process_pid"]}" ]]; then
			# Avoid searching for matching section if it was not found previously
			if [[ -z "${cache_mismatch["$process_pid"]}" ]]; then
				# Attempt to find a matching section in config
				for section_from_array in "${sections_array[@]}"; do
					# Compare process name with specified in section
					if [[ -n "${config_key_name["$section_from_array"]}" && "${config_key_name["$section_from_array"]}" != "$process_name" ]]; then
						continue
					else
						name_match='1'
					fi
					# Compare process executable path with specified in section
					if [[ -n "${config_key_executable["$section_from_array"]}" && "${config_key_executable["$section_from_array"]}" != "$process_executable" ]]; then
						continue
					else
						executable_match='1'
					fi
					# Compare UID of process with specified in section
					if [[ -n "${config_key_owner["$section_from_array"]}" && "${config_key_owner["$section_from_array"]}" != "$process_owner" ]]; then
						continue
					else
						owner_match='1'
					fi
					# Compare process command with specified in section
					if [[ -n "${config_key_command["$section_from_array"]}" && "${config_key_command["$section_from_array"]}" != "$process_command" ]]; then
						continue
					else
						command_match='1'
					fi
					# Mark as matching if all identifiers containing non-zero value
					if [[ -n "$name_match" && -n "$executable_match" && -n "$owner_match" && -n "$command_match" ]]; then
						section_name="$section_from_array"
						cache_section["$process_pid"]="$section_from_array"
						break
					fi
					unset name_match executable_match owner_match command_match
				done
				unset section_from_array name_match executable_match owner_match command_match
				# Mark process as mismatched if matching section was not found
				if [[ -z "$section_name" ]]; then
					cache_mismatch["$process_pid"]='1'
				fi
			fi
		else # Obtain matching section from cache
			section_name="${cache_section["$process_pid"]}"
		fi
		if [[ -n "$section_name" ]]; then
			print_info "Process '$process_name' with PID $process_pid matches with section '$section_name'."
		else
			print_verbose "Process '$process_name' with PID $process_pid does not match with any section."
		fi
	fi
	# Check if PID is not the same as previous one
	if [[ "$process_pid" != "$previous_process_pid" ]]; then
		# Avoid applying CPU limit if owner does not have rights
		if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit["$previous_section_name"]}" != '-1' ]]; then
			# Check for existence of previous match and if CPU limit is set to 0
			if [[ -n "$previous_section_name" && "${config_key_cpu_limit["$previous_section_name"]}" == '0' ]]; then
				# Freeze process if it has not been frozen
				if [[ -z "${is_frozen_pid["$previous_process_pid"]}" ]]; then
					# Mark process as frozen
					is_frozen_pid["$previous_process_pid"]='1'
					# Store PID to array to unfreeze process in case daemon interruption
					frozen_processes_pids_array+=("$previous_process_pid")
					# Freeze process
					background_freeze_process &
					# Associate PID of background process with PID of process to interrupt it in case focus event appears earlier than delay ends
					freeze_bgprocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_name" ]] && (( "${config_key_cpu_limit["$previous_section_name"]}" > 0 )); then # Check for existence of previous match and CPU limit specified greater than 0
				# Run 'cpulimit' on background if CPU limit has not been applied
				if [[ -z "${is_cpu_limited_pid["$previous_process_pid"]}" ]]; then
					# Mark process as CPU limited
					is_cpu_limited_pid["$previous_process_pid"]='1'
					# Apply CPU limit
					background_cpulimit &
					# Store PID of background process to array to interrupt it in case daemon exit
					cpulimit_bgprocesses_pids_array+=("$!")
					# Associate PID of background process with PID of process to interrupt it on focus event
					cpulimit_bgprocess_pid["$previous_process_pid"]="$!"
					# Associate PID of process with PID of background process to print a proper process name in output on daemon termination
					cpu_limited_pid["$!"]="$previous_process_pid"
				fi
			elif [[ -n "$previous_section_name" && -n "${config_key_fps_unfocus["$previous_section_name"]}" ]]; then # Check for existence of previous match and FPS limit
				# Apply FPS limit if was not applied before
				if [[ -z "${is_fps_limited_section["$previous_section_name"]}" ]]; then
					# Mark process as FPS limited
					is_fps_limited_section["$previous_section_name"]='1'
					# Store matching section name of process to array to unset FPS limits on daemon exit
					fps_limited_sections_array+=("$previous_section_name")
					# Associate PID of process with section name to print it in case daemon exit
					fps_limited_pid["$previous_section_name"]="$previous_process_pid"
					# Set FPS limit
					background_mangohud_fps_set &
					# Associate PID of background process with PID of process to interrupt it on focus event
					fps_limit_bgprocess_pid["$previous_process_pid"]="$!"
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
		if [[ -n "${is_frozen_pid["$process_pid"]}" ]]; then
			# Do not terminate background process if it does not exist anymore
			if [[ -d "/proc/${freeze_bgprocess_pid["$process_pid"]}" ]]; then
				# Terminate background process
				if ! kill "${freeze_bgprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_warn "Unable to cancel delayed for ${config_key_delay["$section_name"]} second(s) freezing of process '$process_name' with PID $process_pid!"
				else
					# Avoid printing this message if delay is not specified
					if [[ "${config_key_delay["$section_name"]}" != '0' ]]; then
						print_info "Delayed for ${config_key_delay["$section_name"]} second(s) freezing of process '$process_name' with PID $process_pid has been cancelled."
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
			for frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
				# Skip current PID since I want remove it from array
				if [[ "$frozen_process_pid" != "$process_pid" ]]; then
					frozen_processes_pids_array_temp+=("$frozen_process_pid")
				fi
			done
			frozen_processes_pids_array=("${frozen_processes_pids_array_temp[@]}")
			unset frozen_process_pid frozen_processes_pids_array_temp
			is_frozen_pid["$process_pid"]=''
			freeze_bgprocess_pid["$process_pid"]=''
		elif [[ -n "${is_cpu_limited_pid["$process_pid"]}" ]]; then # Check for CPU limit via 'cpulimit' background process
			# Terminate 'cpulimit' background process
			if ! kill "${cpulimit_bgprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
				print_warn "Process '$process_name' with PID $process_pid cannot be CPU unlimited!"
			else
				print_info "Process '$process_name' with PID $process_pid has been CPU unlimited on focus event."
			fi
			# Remove PID of 'cpulimit' background process from array
			for cpulimit_bgprocess in "${cpulimit_bgprocesses_pids_array[@]}"; do
				# Skip interrupted background process since I want remove it from array
				if [[ "$cpulimit_bgprocess" != "${cpulimit_bgprocess_pid["$process_pid"]}" ]]; then
					cpulimit_bgprocesses_pids_array_temp+=("$cpulimit_bgprocess")
				fi
			done
			cpulimit_bgprocesses_pids_array=("${cpulimit_bgprocesses_pids_array_temp[@]}")
			unset cpulimit_bgprocess cpulimit_bgprocesses_pids_array_temp
			is_cpu_limited_pid["$process_pid"]=''
			cpu_limited_pid["${cpulimit_bgprocess_pid["$process_pid"]}"]=''
			cpulimit_bgprocess_pid["$process_pid"]=''
		elif [[ -n "$section_name" && -n "${is_fps_limited_section["$section_name"]}" && -n "${fps_limited_pid["$section_name"]}" ]]; then
			# Terminate FPS limit background process if exists, checking variable for not being blank is required for unknown reason
			# Otherwise 'kill' will exit with an error because of blank value
			# And that is including checking for process existence in the same 'if' statement which returns 'true'
			if [[ -n "${fps_limit_bgprocess_pid["$process_pid"]}" && -d "/proc/${fps_limit_bgprocess_pid["$process_pid"]}" ]]; then
				if ! kill "${fps_limit_bgprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_warn "Unable to stop FPS limit background process with PID ${fps_limit_bgprocess_pid["$process_pid"]}!"
				else
					print_verbose "FPS limit background process related to process '$process_name' with PID $process_pid has been terminated."
				fi
			fi
			# Unset FPS limit
			if mangohud_fps_set "${config_key_mangohud_config["$section_name"]}" "${config_key_fps_focus["$section_name"]}"; then
				print_info "Process '$process_name' with PID $process_pid has been FPS unlimited on focus event."
			fi
			# Remove section from from array
			for fps_limited_section in "${fps_limited_sections_array[@]}"; do
				# Skip FPS unlimited section since I want remove it from array
				if [[ "$fps_limited_section" != "$section_name" ]]; then
					fps_limited_sections_array_temp+=("$fps_limited_section")
				fi
			done
			fps_limited_sections_array=("${fps_limited_sections_array_temp[@]}")
			unset fps_limited_section fps_limited_sections_array_temp
			is_fps_limited_section["$section_name"]=''
			fps_limit_bgprocess_pid["$process_pid"]=''
			fps_limited_pid["$section_name"]=''
		fi
	fi
	# Run command on focus event if exists
	if [[ -n "$section_name" && -n "${config_key_focus["$section_name"]}" && -z "$lazy" ]]; then
		# Variables passthrough to interact with them using custom commands in 'focus' key
		export_flux_variables "$window_id" "$process_pid" "$process_name" "$process_executable" "$process_owner" "$process_command"
		nohup setsid bash -c "${config_key_focus["$section_name"]}" > /dev/null 2>&1 &
		unset_flux_variables
		print_verbose "Running command on focus event '${config_key_focus["$section_name"]}' from section '$section_name'."
	fi
	# Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'unfocus' key
	previous_window_id="$window_id"
	previous_process_pid="$process_pid"
	previous_process_name="$process_name"
	previous_process_executable="$process_executable"
	previous_process_owner="$process_owner"
	previous_section_name="$section_name"
	previous_process_command="$process_command"
	# Unset to avoid false positive on next event
	unset section_name
	# Unset info about process to avoid using it in some rare cases (idk why that happens, noticed that only once after a few hours of using daemon)
	process_pid=''
	process_name=''
	process_executable=''
	process_owner=''
	process_command=''
done < <(xprop_event_reader)