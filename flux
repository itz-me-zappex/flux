#!/usr/bin/bash

# Print error (redirect to stderr and exit)
print_error(){
	echo -e "$error_prefix $*" >&2
	exit 1
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
	fi
}

# Extract window IDs from xprop events
xprop_event_reader(){
	local stacking_windows_id focused_window_id stacking_window_id
	# Exit with an error if xprop fails (like in case when it unable to open display)
	if ! xprop -root > /dev/null 2>&1; then
		print_error "Cannot start daemon because process 'xprop' required for reading X11 events exits with an error!"
	fi
	# Print window IDs of open windows to apply limits immediately if '--hot' option was passed
	if [[ -n "$hot" ]]; then
		# Extract IDs of open windows
		stacking_windows_id="$(xprop -root _NET_CLIENT_LIST_STACKING)"
		stacking_windows_id="${stacking_windows_id/* \# /}"
		stacking_windows_id="${stacking_windows_id//\,/}"
		# Extract ID of focused window
		focused_window_id="$(xprop -root _NET_ACTIVE_WINDOW)"
		focused_window_id="${focused_window_id/* \# /}"
		# Print IDs of windows, but skip currently focused window
		for stacking_window_id in $stacking_windows_id; do
			if [[ "$stacking_window_id" != "$focused_window_id" ]]; then
				echo "$stacking_window_id"
			fi
		done
		unset stacking_windows_id focused_window_id stacking_window_id
		# Print event for unset '--hot' option since it becomes useless from this moment
		echo 'nohot'
	fi
	# Print event for unset '--lazy' option before reading events, otherwise focus and unfocus commands will not work
	if [[ -n "$lazy" ]]; then
		echo 'nolazy'
	fi
	# Dumbass protection, restart event reading if 'xprop' process has been terminated by ball between chair and monitor
	while true; do
		# Break loop if exit variable appears not blank
		if [[ -n "$exit" ]]; then
			break
		fi
		# Print warning in case loop was restarted
		if [[ -n "$first_loop" ]]; then
			print_warn "Process 'xprop' required for reading X11 events restarted after termination by user!"
		else
			first_loop='1'
		fi
		# Read events from xprop and print IDs of windows
		while read -r xprop_event; do
			# Print event for safe exit in case X server dies
			if [[ "$xprop_event" =~ 'X connection to :'[0-9]+' broken (explicit kill or server shutdown).' ]]; then
				echo 'exit'
				exit='1'
			fi
			# Extract ID from line
			window_id="${xprop_event/* \# /}"
			# Skip cycle if window ID is exactly the same as previous one, workaround required for some buggy WMs
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
	# Extract PID of process
	process_pid="$(xprop -id "$window_id" _NET_WM_PID)"
	if [[ "$process_pid" != "_NET_WM_PID:  not found." ]]; then
		process_pid="${process_pid/* = /}"
		# Check if info about process exists in cache
		if [[ -z "${cache_process_name["$process_pid"]}" ]]; then
			# Extract name of process
			process_name="$(<"/proc/$process_pid/comm")"
			# Extract executable path of process
			process_executable="$(readlink "/proc/$process_pid/exe")"
			# Extract UID of process
			while read -r status_line; do
				if [[ "$status_line" == 'Uid:'* ]]; then
					column_count='0'
					for status_column in $status_line; do
						if (( column_count == 3 )); then
							process_owner="$status_column"
						else
							(( column_count++ ))
						fi
					done
					unset status_column column_count
				fi
			done < "/proc/$process_pid/status"
			unset status_line
			# I did not get how to do that using built-in bash options
			# Extract command of process and replace '\0' (used as separator between options) with spaces
			process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
			# Remove last space since '\0' is a last symbol too
			process_command="${process_command/%\ /}"
			# Add all variables to cache
			cache_process_name["$process_pid"]="$process_name"
			cache_process_executable["$process_pid"]="$process_pid"
			cache_process_owner["$process_pid"]="$process_owner"
			cache_process_command["$process_pid"]="$process_command"
			# Save PID to array to make it easier to remove info from cache in case process does not exist
			cached_pids_array+=("$process_pid")
		else
			# Set values from cache
			process_name="${cache_process_name["$process_pid"]}"
			process_executable="${cache_process_executable["$process_pid"]}"
			process_owner="${cache_process_owner["$process_pid"]}"
			process_command="${cache_process_command["$process_pid"]}"
		fi
	else
		process_pid=''
		return 1
	fi
}

# Change FPS-limit in specified MangoHud config
mangohud_fps_set(){
	local config_line config_content config_path="$1" fps_limit="$2" fps_limit_is_changed
	# Dumbass protection, check if config file exists before continue in case ball between chair and monitor removed it on fly
	if [[ -f "$config_path" ]]; then
		# Replace 'fps_limit' value in config if exists
		while read -r config_line || [[ -n "$config_line" ]]; do
			# Find 'fps_limit' line
			if [[ "$config_line" == 'fps_limit='* ]]; then
				# Set specified FPS-limit
				if [[ -n "$config_content" ]]; then
					config_content="$config_content\nfps_limit=$fps_limit"
				else
					config_content="$fps_limit=$fps_limit"
				fi
				fps_limit_is_changed='1'
			else
				if [[ -n "$config_content" ]]; then
					config_content="$config_content\n$config_line"
				else
					config_content="$config_line"
				fi
			fi
		done < "$config_path"
		# Add 'fps_limit' line to config if it does not exist, i.e. was not found and changed
		if [[ -z "$fps_limit_is_changed" ]]; then
			echo "fps_limit=$fps_limit" >> "$config_path"
		else
			echo -e "$config_content" > "$config_path"
		fi
	else
		print_warn "Config file '$config_path' was not found!"
	fi
}

# Actions on TERM and INT signals
exit_on_term(){
	# Unfreeze processes
	for frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
		if [[ -d "/proc/$frozen_process_pid" ]]; then
			if ! kill -CONT "$frozen_process_pid" > /dev/null 2>&1; then
				print_warn "Cannot unfreeze process with PID $frozen_process_pid on daemon termination!"
			else
				print_verbose "Process with PID $frozen_process_pid has been unfrozen on daemon termination."
			fi
		fi
	done
	# Kill cpulimit subprocesses
	for cpulimit_subprocess_pid in "${cpulimit_subprocesses_pids_array[@]}"; do
		if [[ -d "/proc/$cpulimit_subprocess_pid" ]]; then
			if ! pkill -P "$cpulimit_subprocess_pid" > /dev/null 2>&1; then
				print_warn "Cannot stop 'cpulimit' subprocess with PID $cpulimit_subprocess_pid on daemon termination!"
			else
				print_verbose "CPU-limit subprocess with PID $cpulimit_subprocess_pid has been terminated on daemon termination."
			fi
		fi
	done
	# Remove FPS-limits
	for fps_limited_section in "${fps_limited_sections_array[@]}"; do
		mangohud_fps_set "${config_key_mangohud_config["$fps_limited_section"]}" "${config_key_fps_unlimit["$fps_limited_section"]}"
		print_verbose "Process with PID ${fps_limited_pid["$fps_limited_section"]} has been FPS-unlimited on daemon termination."
	done
	print_info "Daemon terminated."
	exit 0
}

# Remove CPU-limit for processes on exit
trap 'exit_on_term' SIGTERM SIGINT

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
	--changelog | -c )
		echo 'Changelog for flux 1.5.2:
- Fixed issues with output of `--focus` and `--pick` options in some cases.
- Added check for ability to obtain window ID before template creation.
- Removed displaying of bash version in output of `--version` option because of its uselessness.
- Fixed a bug when daemon attempts to restart `xprop` process infinitely when X server on current display dies.
- Small fixes and improvements.

Changelog for flux 1.5.1:
- Added check for ability to read X11 events before start.

Changelog for flux 1.5:
- Added option `--focus` to create template for config from focused window, `--template` option is renamed to `--pick`.
- Config keys `mangohud-fps-limit` and `mangohud-fps-unlimit` are renamed to `fps-limit` and `fps-unlimit` respectively.
- Added `--changelog` option to display changelog.
- Short option for `--config` is renamed from `-c` to `-C`, because `--changelog` has higher alphabetical order, so now `-c` equal to `--changelog`.
- Small fixes and improvements.
'
		exit 0
	;;
	--config | -C | --config=* )
		# Remember that option was passed in case if path was not specified
		option_repeat_check config_is_passed --config
		config_is_passed='1'
		# Define option type (short, long or long+value) and remember specified path
		case "$1" in
		--config | -C )
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
		# Exit with an error if xprop unable to open display, I don't really care, both xprop and xwininfo will fail in this case
		if ! xprop -root > /dev/null 2>&1; then
			print_error "Cannot obtain process info because process 'xprop' or 'xwininfo' required to obtain window ID exits with an error!"
		fi
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
				print_error "Cannot grab cursor to pick a window!"
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
fps-limit = 
fps-unlimit = 
delay = 
focus = 
unfocus = 
"
			exit 0
		else
			print_error "Cannot create template for window with ID $window_id since it does not report its PID!"
		fi
	;;
	--help | -h | --usage | -u )
		echo "Usage: flux [option] <value>
Options and values:
    -c, --changelog                      Display changelog
    -C, --config     <path-to-config>    Specify path to config file
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
		echo "A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.
flux 1.5.2
License: GPL-3.0
Repository: https://github.com/itz-me-zappex/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
		exit 0
	;;
	* )
		# Regexp means 2+ symbols after hyphen (combined short options)
		if [[ "$1" =~ ^-.{2,}$ ]]; then
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
		fi
	esac
done

# Exit with an error if verbose and quiet modes are specified at the same time
if [[ -n "$verbose" && -n "$quiet" ]]; then
	print_error "Do not use verbose and quiet modes at the same time!$advice_on_option_error"
fi

# Exit with an error if '--config' option is specified without a path to config file
if [[ -n "$config_is_passed" && -z "$config" ]]; then
	print_error "Option '--config' is specified without path to config file!$advice_on_option_error"
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
fi

# Calculate maximum allowable CPU-limit
cpu_threads='0'
while read -r cpuinfo_line; do
	if [[ "$cpuinfo_line" == 'processor'* ]]; then
		(( cpu_threads++ ))
	fi
done < '/proc/cpuinfo'
max_cpu_limit="$(( cpu_threads * 100 ))"
unset cpu_threads cpuinfo_line

# Create associative arrays to store values from config
declare -A config_key_name \
config_key_executable \
config_key_owner \
config_key_cpu_limit \
config_key_delay \
config_key_focus \
config_key_unfocus \
config_key_command \
config_key_mangohud_config \
config_key_fps_limit \
config_key_fps_unlimit

# INI parser
while read -r config_line || [[ -n "$config_line" ]]; do
	# Skip commented or blank line
	if [[ "$config_line" =~ ^(\;|\#) || -z "$config_line" ]]; then
		continue
	fi
	# Exit with an error if first line is not a section, otherwise remember section name
	if [[ ! "$config_line" =~ ^\[.*\]$ && -z "$section" ]]; then
		print_error "Initial section is not found in config '$config'!"
	elif [[ "$config_line" =~ ^\[.*\]$ ]]; then
		# Exit with an error if section repeated
		if [[ -n "${sections_array[*]}" ]]; then
			for section_from_array in "${sections_array[@]}"; do
				if [[ "[$section_from_array]" == "$config_line" ]]; then
					print_error "Section name '$section' is repeated!"
				fi
			done
			unset section_from_array
		fi
		# Remove square brackets from section name and add it to array
		# Array required to check for repeating sections and find matching rule(s) for process in config
		section="${config_line/\[/}"
		section="${section/%\]/}"
		sections_array+=("$section")
		# Forward to next line
		continue
	fi
	# Exit with an error if type of line cannot be defined
	if [[ "${config_line,,}" =~ ^(name|executable|owner|cpu-limit|delay|focus|unfocus|command|mangohud-config|fps-limit|fps-unlimit)(\ )?=(\ )?.* ]]; then
		# Extract value from key by removing key and equal symbol
		if [[ "$config_line" == *'= '* ]]; then
			value="${config_line/*= /}" # <-
		elif [[ "$config_line" == *'='* ]]; then
			value="${config_line/*=/}" # <-
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
		case "${config_line,,}" in
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
			fi
		;;
		cpu-limit* )
			# Exit with an error if CPU-limit is specified incorrectly
			if [[ "$value" =~ ^[0-9]+$ || "$value" == '-1' ]] && (( value <= max_cpu_limit )); then
				config_key_cpu_limit["$section"]="$value"
			else
				print_error "Value '$value' in key 'cpulimit' in section '$section' is invalid!"
			fi
		;;
		delay* )
			# Exit with an error if value is neither an integer nor a float (that is what regexp means)
			if [[ "$value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
				# Replace comma with a dot if that is a float value, 'read -t <seconds>' used as alternative to '/usr/bin/sleep <seconds>' does not eat commas
				value="${value/\,/\.}"
				config_key_delay["$section"]="$value"
			else
				print_error "Value '$value' in key 'delay' in section '$section' is neither integer nor float!"
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
				print_error "Config file specified in key 'mangohud-config' in section '$section' does not exist!"
			fi
		;;
		fps-limit* )
			# Exit with an error if value is not integer
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_key_fps_limit["$section"]="$value"
			else
				print_error "FPS specified in key 'fps-limit' in section '$section' is not an integer!"
			fi
		;;
		fps-unlimit* )
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_key_fps_unlimit["$section"]="$value"
			else
				print_error "FPS specified in key 'fps-unlimit' in section '$section' is not an integer!"
			fi
		esac
	else
		print_error "Cannot define type of line '$config_line'!"
	fi
done < "$config"
unset config_line value section

# Check values in sections
for section_from_array in "${sections_array[@]}"; do
	# Exit with an error if neither identifier 'name' nor 'executable' nor 'command' is specified
	if [[ -z "${config_key_name["$section_from_array"]}" && -z "${config_key_executable["$section_from_array"]}" && -z "${config_key_command["$section_from_array"]}" ]]; then
		print_error "At least one process identifier required in section '$section_from_array'!"
	fi
	# Exit with an error if MangoHud FPS-limit is not specified along with config path (for the fuck should I know which config should be modified then?)
	if [[ -n "${config_key_fps_limit["$section_from_array"]}" && -z "${config_key_mangohud_config["$section_from_array"]}" ]]; then
		print_error "FPS-limit in key 'fps-limit' in section '$section_from_array' is specified without path to MangoHud config!"
	fi
	# Exit with an error if MangoHud FPS-limit is specified along with CPU-limit
	if [[ -n "${config_key_fps_limit["$section_from_array"]}" && -n "${config_key_cpu_limit["$section_from_array"]}" ]]; then
		print_error "Do not use FPS-limit along with CPU-limit in section '$section_from_array'!"
	fi
	# Exit with an error if 'fps-unlimit' is specified without 'fps-limit'
	if [[ -n "${config_key_fps_unlimit["$section_from_array"]}" && -z "${config_key_fps_limit["$section_from_array"]}" ]]; then
		print_error "Do not use 'fps-unlimit' key without 'fps-limit' key in section '$section_from_array'!"
	fi
	# Exit with an error if 'mangohud-config' is specified without 'fps-limit'
	if [[ -n "${config_key_mangohud_config["$section_from_array"]}" && -z "${config_key_fps_limit["$section_from_array"]}" ]]; then
		print_error "Do not use 'mangohud-config' key without 'fps-limit' key in section '$section_from_array'!"
	fi
	# Set 'fps-unlimit' to '0' (none) if it is not specified
	if [[ -n "${config_key_fps_limit["$section_from_array"]}" && -z "${config_key_fps_unlimit["$section_from_array"]}" ]]; then
		config_key_fps_unlimit["$section_from_array"]='0'
	fi
	# Set CPU-limit to '-1' (none) if it is not specified
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
declare -A is_frozen_pid # For marking frozen processes (PIDs)
declare -A freeze_subrocess_pid # For subprocesses to freeze with delay
declare -A is_cpu_limited_pid # For marking CPU-limited processes (PIDs)
declare -A cpulimit_subprocess_pid # For cpulimit subprocesses
declare -A is_fps_limited_section # For marking FPS-limited processes (sections)
declare -A fps_limit_subprocess_pid # For subprocesses to apply FPS-limit with delay
declare -A fps_limited_pid # To print PID of process in case daemon exit

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_process_name cache_process_executable cache_process_owner cache_process_command

# Dumbass protection, exit with an error if that is not a X11 session
if [[ "$XDG_SESSION_TYPE" != 'x11' ]]; then
	print_error "Flux is not meant to use it with anything but X11!"
fi

# Set cycle counter to zero, required to clean up cache per N cycles
cycle_counter='0'

# Read IDs of windows and apply actions
while read -r window_id; do
	# Exit in case X11 server termination
	if [[ "$window_id" == 'exit' ]]; then
		print_warn "X server on display '$DISPLAY' has been terminated!"
		exit_on_term
	fi
	# Unset '--lazy' option if event was passed, otherwise focus and unfocus commands will not work
	if [[ "$window_id" == 'nolazy' ]]; then
		unset lazy
		lazy_is_unset='1'
		continue
	elif [[ "$window_id" == 'nohot' ]]; then # Unset '--hot' since it becomes useless from this moment
		unset hot
		continue
	fi
	# Increase count of cycles
	if [[ -z "$hot" ]]; then
		(( cycle_counter++ ))
	fi
	# Clean cache which stores info about processes every 1000th cycle to avoid memory leak
	if (( cycle_counter != 0 && cycle_counter % 1000 == 0 )); then
		# Read PIDs from array
		for cached_pid in "${cached_pids_array[@]}"; do
			# Remove info about process if it does not exist anymore
			if [[ ! -d "/proc/$cached_pid" ]]; then
				print_verbose "Cache of process '${cache_process_name["$cached_pid"]}' with PID $cached_pid has been removed."
				cache_process_name["$cached_pid"]=''
				cache_process_executable["$cached_pid"]=''
				cache_process_owner["$cached_pid"]=''
				cache_process_command["$cached_pid"]=''
				cached_pids_to_remove_array+=("$cached_pid")
			fi
		done
		# Remove terminated PIDs from array
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
		print_info "Cache of process information has been cleaned up."
	fi
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
		print_warn "Cannot obtain PID of window with ID $window_id! Getting process info skipped."
	fi
	# Do not find matching section if window does not report its PID
	if [[ -n "$process_pid" ]]; then
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
				break
			fi
			unset name_match executable_match owner_match command_match
		done
		unset section_from_array name_match executable_match owner_match command_match
		if [[ -n "$section_name" ]]; then
			print_verbose "Process '$process_name' with PID $process_pid matches with section '$section_name'."
		else
			print_verbose "Process '$process_name' with PID $process_pid does not match with any section."
		fi
	fi
	# Check if PID is not the same as previous one
	if [[ "$process_pid" != "$previous_process_pid" ]]; then
		# Avoid applying CPU-limit if owner does not have rights
		if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_key_cpu_limit["$previous_section_name"]}" != '-1' ]]; then
			# Check for existence of previous match and if CPU-limit is set to 0
			if [[ -n "$previous_section_name" && "${config_key_cpu_limit["$previous_section_name"]}" == '0' ]]; then
				# Freeze process if it has not been frozen
				if [[ -z "${is_frozen_pid["$previous_process_pid"]}" ]]; then
					# Mark process as frozen
					is_frozen_pid["$previous_process_pid"]='1'
					# Save PID to array to unfreeze process in case daemon interruption
					frozen_processes_pids_array+=("$previous_process_pid")
					(	
						# Freeze process with delay if specified, otherwise freeze process immediately
						if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
							print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be frozen after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
							sleep "${config_key_delay["$previous_section_name"]}"
						fi
						# Freeze process if it still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							if ! kill -STOP "$previous_process_pid" > /dev/null 2>&1; then
								print_warn "Cannot freeze process '$previous_process_name' with PID $previous_process_pid!"
							else
								print_info "Process '$previous_process_name' with PID $previous_process_pid has been frozen on unfocus event."
							fi
						else
							print_warn "Process '$previous_process_name' with PID $previous_process_pid has been terminated before freezing!"
						fi
					) &
					# Save PID of subprocess to interrupt it in case focus event appears earlier than delay ends
					freeze_subrocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_name" ]] && (( "${config_key_cpu_limit["$previous_section_name"]}" > 0 )); then # Check for existence of previous match and CPU-limit specified greater than 0
				# Run cpulimit subprocess if CPU-limit has not been applied
				if [[ -z "${is_cpu_limited_pid["$previous_process_pid"]}" ]]; then
					# Mark process as CPU-limited
					is_cpu_limited_pid["$previous_process_pid"]='1'
					# Run cpulimit subprocess
					(
						# Ignore SIGTERM signal to avoid termination of parent subprocess while keeping child process which cpulimit is, that should be processed with 'exit_on_term' function via trap in beginning of code
						trap '' SIGTERM
						# Wait in case delay is specified
						if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
							print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be CPU-limited after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
							sleep "${config_key_delay["$previous_section_name"]}"
						fi
						# Run cpulimit if target process still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							print_info "Process '$previous_process_name' with PID $previous_process_pid has been CPU-limited to ${config_key_cpu_limit["$previous_section_name"]}/$max_cpu_limit on unfocus event."
							if ! cpulimit --limit="${config_key_cpu_limit["$previous_section_name"]}" --pid="$previous_process_pid" --lazy > /dev/null 2>&1; then
								print_warn "Cannot apply CPU-limit to process '$previous_process_name' with PID $previous_process_pid, 'cpulimit' returned error!"
							fi
						else
							print_warn "Process '$previous_process_name' with PID $previous_process_pid has been terminated before applying CPU-limit!"
						fi
					) &
					# Save PID of subprocess to array to interrupt it in case daemon exit
					cpulimit_subprocesses_pids_array+=("$!")
					# Save PID of subprocess to interrupt it on focus event
					cpulimit_subprocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_name" && -n "${config_key_fps_limit["$previous_section_name"]}" ]]; then # Check for existence of previous match and FPS-limit
				# Apply FPS-limit if was not applied before
				if [[ -z "${is_fps_limited_section["$previous_section_name"]}" ]]; then
					# Mark process as FPS-limited
					is_fps_limited_section["$previous_section_name"]='1'
					# Save matching section name of process to array to unset FPS-limits on daemon exit
					fps_limited_sections_array+=("$previous_section_name")
					# Save PID to print it in case daemon exit
					fps_limited_pid["$previous_section_name"]="$previous_process_pid"
					# Set FPS-limit
					(
						# Wait in case delay is specified
						if [[ "${config_key_delay["$previous_section_name"]}" != '0' ]]; then
							print_verbose "Process '$previous_process_name' with PID $previous_process_pid will be FPS-limited after ${config_key_delay["$previous_section_name"]} second(s) on unfocus event."
							sleep "${config_key_delay["$previous_section_name"]}"
						fi
						# Apply FPS-limit if target still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							print_info "Process '$previous_process_name' with PID $previous_process_pid has been FPS-limited to ${config_key_fps_limit["$previous_section_name"]} FPS on unfocus event."
							mangohud_fps_set "${config_key_mangohud_config["$previous_section_name"]}" "${config_key_fps_limit["$previous_section_name"]}"
						fi
					) &
					# Save PID of subprocess to interrupt it on focus event
					fps_limit_subprocess_pid["$previous_process_pid"]="$!"
				fi
			fi
		elif [[ -n "$previous_process_owner" ]]; then
			print_warn "Cannot apply CPU-limit to process '$previous_process_name' with PID $previous_process_pid, UID of process - $previous_process_owner, UID of user - $UID!"
		fi
	fi
	# Do not apply actions if window does not report its PID
	if [[ -n "$process_pid" ]]; then
		# Unfreeze process if window is focused
		if [[ -n "${is_frozen_pid["$process_pid"]}" ]]; then
			# Do not terminate subprocess if it does not exist anymore
			if [[ -d "/proc/${freeze_subrocess_pid["$process_pid"]}" ]]; then
				# Terminate subprocess
				if ! kill "${freeze_subrocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_warn "Cannot stop 'cpulimit' subprocess with PID '${freeze_subrocess_pid["$process_pid"]}'!"
				else
					print_info "Delayed for ${config_key_delay["$section_name"]} second(s) freezing of process '$process_name' with PID $process_pid has been cancelled."
				fi
			fi
			freeze_subrocess_pid["$process_pid"]=''
			# Unfreeze process
			if ! kill -CONT "$process_pid" > /dev/null 2>&1; then
				print_warn "Cannot unfreeze process '$process_name' with PID $process_pid!"
			else
				print_info "Process '$process_name' with PID $process_pid has been unfrozen on focus event."
			fi
			is_frozen_pid["$process_pid"]=''
			fps_limited_pid["$section_name"]=''
			# Remove PID from array
			for frozen_process_pid in "${frozen_processes_pids_array[@]}"; do
				# Skip current PID since I want remove it from array
				if [[ "$frozen_process_pid" != "$process_pid" ]]; then
					frozen_processes_pids_array_temp+=("$frozen_process_pid")
				fi
			done
			frozen_processes_pids_array=("${frozen_processes_pids_array_temp[@]}")
			unset frozen_process_pid frozen_processes_pids_array_temp
		elif [[ -n "${is_cpu_limited_pid["$process_pid"]}" ]]; then # Check for CPU-limit via 'cpulimit' subprocess
			# Terminate 'cpulimit' subprocess
			if ! pkill -P "${cpulimit_subprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
				print_warn "Cannot stop 'cpulimit' subprocess with PID ${cpulimit_subprocess_pid["$process_pid"]}!"
			else
				print_info "Process '$process_name' with PID $process_pid has been CPU unlimited on focus event."
			fi
			is_cpu_limited_pid["$process_pid"]=''
			# Remove PID of 'cpulimit' subprocess from array
			for cpulimit_subprocess in "${cpulimit_subprocesses_pids_array[@]}"; do
				# Skip interrupted subprocess since I want remove it from array
				if [[ "$cpulimit_subprocess" != "${cpulimit_subprocess_pid["$process_pid"]}" ]]; then
					cpulimit_subprocesses_pids_array_temp+=("$cpulimit_subprocess")
				fi
			done
			cpulimit_subprocess_pid["$process_pid"]=''
			cpulimit_subprocesses_pids_array=("${cpulimit_subprocesses_pids_array_temp[@]}")
			unset cpulimit_subprocess cpulimit_subprocesses_pids_array_temp
		elif [[ -n "$section_name" && -n "${is_fps_limited_section["$section_name"]}" ]]; then
			# Do not terminate FPS-limit subprocess if it does not exist anymore
			if [[ -d "/proc/${fps_limit_subprocess_pid["$process_pid"]}" ]]; then
				if ! kill "${fps_limit_subprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_warn "Cannot stop FPS-limit subprocess with PID ${fps_limit_subprocess_pid["$process_pid"]}!"
				else
					print_info "Delayed for ${config_key_delay["$section_name"]} second(s) FPS-limiting of process '$process_name' with PID $process_pid has been cancelled."
				fi
			fi
			# Unset FPS-limit
			print_info "Process '$process_name' with PID $process_pid has been FPS-unlimited on focus event."
			mangohud_fps_set "${config_key_mangohud_config["$section_name"]}" "${config_key_fps_unlimit["$section_name"]}"
			is_fps_limited_section["$section_name"]=''
			# Remove section from from array
			for fps_limited_section in "${fps_limited_sections_array[@]}"; do
				# Skip FPS-unlimited section since I want remove it from array
				if [[ "$fps_limited_section" != "$section_name" ]]; then
					fps_limited_sections_array_temp+=("$fps_limited_section")
				fi
			done
			fps_limited_sections_array=("${fps_limited_sections_array_temp[@]}")
			unset fps_limited_section fps_limited_sections_array_temp
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
	# Remember info of process to next cycle to run commands on unfocus and apply CPU-limit, also for pass variables to command in 'unfocus' key
	previous_window_id="$window_id"
	previous_process_pid="$process_pid"
	previous_process_name="$process_name"
	previous_process_executable="$process_executable"
	previous_process_owner="$process_owner"
	previous_section_name="$section_name"
	previous_process_command="$process_command"
	# Unset to avoid false positive on next cycle
	unset section_name
done < <(xprop_event_reader)