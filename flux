#!/usr/bin/bash

# Print error (redirect to stderr)
print_error(){
	echo -e "$@" >&2
}

# Print in verbose mode
print_verbose(){
	if [[ -n "$verbose" ]]; then
		echo -e "$@"
	fi
}

# Do not print in quiet mode
print_info(){
	if [[ -z "$quiet" ]]; then
		echo -e "$@"
	fi
}

# Exit with an error if option repeated
option_repeat_check(){
	if [[ -n "${!1}" ]]; then
		print_error "$error_prefix Option '$2' is repeated!$advice_on_option_error"
		exit 1
	fi
}

# Extract window IDs from xprop events
xprop_event_reader(){
	local stacking_windows focused_window stacking_window
	# Print window IDs of open windows to apply limits immediately if '--hot' option was passed
	if [[ -n "$hot" ]]; then
		# Extract IDs of open windows
		stacking_windows="$(xprop -root _NET_CLIENT_LIST_STACKING)"
		stacking_windows="${stacking_windows/* \# /}"
		stacking_windows="${stacking_windows//\,/}"
		# Extract ID of focused window
		focused_window="$(xprop -root _NET_ACTIVE_WINDOW)"
		focused_window="${focused_window/* \# /}"
		# Print IDs of windows, but skip currently focused window
		for stacking_window in $stacking_windows; do
			if [[ "$stacking_window" != "$focused_window" ]]; then
				echo "$stacking_window"
			fi
		done
		unset stacking_windows focused_window stacking_window
		# Print event for unset '--hot' option since it becomes useless from this moment
		echo 'nohot'
	fi
	# Print event for unset '--lazy' option before reading events, otherwise focus and unfocus commands will not work
	if [[ -n "$lazy" ]]; then
		echo 'nolazy'
	fi
	# Read events from xprop and print IDs of windows
	while read -r xprop_event; do
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
	done < <(xprop -root -spy _NET_ACTIVE_WINDOW)
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
		# Extract name of process
		process_name="$(<"/proc/$process_pid/comm")"
		# Extract executable path of process
		process_executable="$(readlink "/proc/$process_pid/exe")"
		# Extract UID of process
		while read -r status_line; do
			if [[ "$status_line" == 'Uid:'* ]]; then
				column_count=0
				for status_column in $status_line; do
					if (( column_count == 3 )); then
						process_owner="$status_column"
					else
						column_count="$(( column_count + 1 ))"
					fi
				done
				unset status_column column_count
			fi
		done < "/proc/$process_pid/status"
		unset status_line
		# I did not get how to do that using built-in bash options
		# Extract command of process and replace '\0' (used as separator between options) with spaces
		process_command="$(cat "/proc/$process_pid/cmdline" | tr '\0' ' ')"
		# Remove last space since '\0' is a last symbol too
		process_command="${process_command/%\ /}"
	else
		process_pid=''
		return 1
	fi
}

# Change FPS-limit in specified MangoHud config
mangohud_fps_set(){
	local config_line config_content config_path="$1" fps_limit="$2" fps_limit_changed
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
				fps_limit_changed='1'
			else
				if [[ -n "$config_content" ]]; then
					config_content="$config_content\n$config_line"
				else
					config_content="$config_line"
				fi
			fi
		done < "$config_path"
		# Add 'fps_limit' line to config if it does not exist, i.e. was not found and changed
		if [[ -z "$fps_limit_changed" ]]; then
			echo "fps_limit=$fps_limit" >> "$config_path"
		else
			echo -e "$config_content" > "$config_path"
		fi
	else
		print_error "$warn_prefix Config file '$config_path' was not found!"
	fi
}

# Actions on TERM and INT signals
exit_on_term(){
	# Unfreeze processes
	for frozen_process in "${frozen_processes_array[@]}"; do
		if [[ -d "/proc/$frozen_process" ]]; then
			if ! kill -CONT "$frozen_process" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot unfreeze process with PID $frozen_process!"
			else
				print_verbose "$verbose_prefix Process with PID $frozen_process has been unfrozen."
			fi
		fi
	done
	# Kill cpulimit subprocesses
	for cpulimit_subprocess in "${cpulimit_subprocesses_array[@]}"; do
		if [[ -d "/proc/$cpulimit_subprocess" ]]; then
			if ! pkill -P "$cpulimit_subprocess" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID $cpulimit_subprocess!"
			else
				print_verbose "$verbose_prefix CPU-limit subprocess with PID $cpulimit_subprocess has been terminated."
			fi
		fi
	done
	# Remove FPS-limits
	for fps_limited in "${fps_limited_array[@]}"; do
		mangohud_fps_set "${config_mangohud_config["$fps_limited"]}" "${config_mangohud_fps_unlimit["$fps_limited"]}"
		print_verbose "$verbose_prefix Process with PID ${fps_limited_pid["$fps_limited"]} has been FPS-unlimited."
	done
	print_info "$info_prefix Terminated."
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
	--config | -c | --config=* )
		# Remember that option was passed in case if path was not specified
		option_repeat_check config_option --config
		config_option=1
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
			shift 1
		esac
	;;
	--help | -h | --usage | -u )
		echo "Usage: flux [option] <value>
Options and values:
    -c, --config     <path-to-config>    Specify path to config file
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -q, --quiet                          Print errors and warnings only
    -t, --template                       Print template for config by picking window
    -u, --usage                          Same as '--help'
    -v, --verbose                        Detailed output
    -V, --version                        Display release information
"
		exit 0
	;;
	--hot | -H )
		option_repeat_check hot --hot
		hot=1
		shift 1
	;;
	--lazy | -l )
		option_repeat_check lazy --lazy
		lazy=1
		shift 1
	;;
	--quiet | -q )
		option_repeat_check quiet --quiet
		quiet=1
		shift 1
	;;
	--template | -t )
		# Obtain window ID using xwininfo picker
		if xwininfo_output="$(xwininfo 2>/dev/null)"; then
			while read -r xwininfo_output; do
				if [[ "$xwininfo_output" == 'xwininfo: Window id: '* ]]; then
					window_id="${xwininfo_output/*: /}"
					window_id="${window_id/ */}"
					break
				fi
			done <<< "$xwininfo_output"
			# Extract process info
			if extract_process_info; then
				echo "[$process_name]
name = $process_name
executable = $process_executable
command = $process_command
owner = $process_owner
cpulimit = -1
mangohud-config = ''
mangohud-fps-limit = ''
mangohud-fps-unlimit = 0
delay = 0
focus = ''
unfocus = ''
"
				exit 0
			else
				print_error "$error_prefix Cannot create template for window with ID $window_id since it does not report its PID!"
				exit 1
			fi
		else
			print_error "$error_prefix Cannot grab cursor to pick a window!"
			exit 1
		fi
	;;
	--verbose | -v )
		option_repeat_check verbose --verbose
		verbose=1
		shift 1
	;;
	--version | -V )
		# Get Bash version from output, because variable "$BASH_VERSION" could be overwritten because it is not protected from writing
		while read -r bash_version_line; do
			# Remove 'GNU bash, version ' from line
			bash_version="${bash_version_line/GNU bash, version /}"
			# I need only first line, so break cycle
			break
		done < <(LC_ALL='C' bash --version)
		echo "A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.
flux 1.3.2 (bash $bash_version)
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
			print_error "$error_prefix Unknown option '$1'!$advice_on_option_error"
			exit 1
		fi
	esac
done

# Exit with an error if verbose and quiet modes are specified at the same time
if [[ -n "$verbose" && -n "$quiet" ]]; then
	print_error "$error_prefix Do not use verbose and quiet modes at the same time!$advice_on_option_error"
fi

# Exit with an error if '--config' option is specified without a path to config file
if [[ -n "$config_option" && -z "$config" ]]; then
	print_error "$error_prefix Option '--config' is specified without path to config file!$advice_on_option_error"
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
	print_error "$error_prefix Config file was not found!$advice_on_option_error"
	exit 1
fi

# Calculate maximum allowable CPU-limit
cpu_threads='0'
while read -r cpuinfo_line; do
	if [[ "$cpuinfo_line" == 'processor'* ]]; then
		cpu_threads="$(( cpu_threads + 1 ))"
	fi
done < '/proc/cpuinfo'
max_cpulimit="$(( cpu_threads * 100 ))"
unset cpu_threads cpuinfo_line

# Create associative arrays to store values from config
declare -A config_name \
config_executable \
config_owner \
config_cpulimit \
config_delay \
config_focus \
config_unfocus \
config_command \
config_mangohud_config \
config_mangohud_fps_limit \
config_mangohud_fps_unlimit

# INI parser
while read -r config_line || [[ -n "$config_line" ]]; do
	# Skip commented or blank line
	if [[ "$config_line" =~ ^(\;|\#) || -z "$config_line" ]]; then
		continue
	fi
	# Exit with an error if first line is not a section, otherwise remember section name
	if [[ ! "$config_line" =~ ^\[.*\]$ && -z "$section" ]]; then
		print_error "$error_prefix Initial section was not found in config '$config'!"
		exit 1
	elif [[ "$config_line" =~ ^\[.*\]$ ]]; then
		if [[ -n "${sections_array[*]}" ]]; then
			for section_from_array in "${sections_array[@]}"; do
				if [[ "[$section_from_array]" == "$config_line" ]]; then
					print_error "$error_prefix Section name '$section' is repeated!"
					exit 1
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
	if [[ "${config_line,,}" =~ ^(name|executable|owner|cpulimit|delay|focus|unfocus|command|mangohud-config|mangohud-fps-limit|mangohud-fps-unlimit)(\ )?=(\ )?.* ]]; then
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
			config_name["$section"]="$value"
		;;
		executable* )
			config_executable["$section"]="$value"
		;;
		owner* )
			# Exit with an error if UID is not numeric
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_owner["$section"]="$value"
			else
				print_error "$error_prefix Value '$value' in key 'owner' in section '$section' is not UID!"
				exit 1
			fi
		;;
		cpulimit* )
			# Exit with an error if CPU-limit is specified incorrectly
			if [[ "$value" =~ ^[0-9]+$ || "$value" == '-1' ]] && (( value <= max_cpulimit )); then
				config_cpulimit["$section"]="$value"
			else
				print_error "$error_prefix Value '$value' in key 'cpulimit' in section '$section' is invalid!"
				exit 1
			fi
		;;
		delay* )
			# Exit with an error if value is neither an integer nor a float (that is what regexp means)
			if [[ "$value" =~ ^[0-9]+((\.|\,)[0-9]+)?$ ]]; then
				# Replace comma with a dot if that is a float value, 'read -t <seconds>' used as alternative to '/usr/bin/sleep <seconds>' does not eat commas
				value="${value/\,/\.}"
				config_delay["$section"]="$value"
			else
				print_error "$error_prefix Value '$value' in key 'delay' in section '$section' is neither integer nor float!"
				exit 1
			fi
		;;
		focus* )
			config_focus["$section"]="$value"
		;;
		unfocus* )
			config_unfocus["$section"]="$value"
		;;
		command* )
			config_command["$section"]="$value"
		;;
		mangohud-config* )
			# Exit with an error if specified MangoHud config file does not exist
			if [[ -f "$value" ]]; then
				config_mangohud_config["$section"]="$value"
			else
				print_error "$error_prefix Config file specified in key 'mangohud-config' in section '$section' does not exist!"
				exit 1
			fi
		;;
		mangohud-fps-limit* )
			# Exit with an error if value is not integer
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_mangohud_fps_limit["$section"]="$value"
			else
				print_error "$error_prefix FPS specified in key 'mangohud-fps-limit' in section '$section' is not integer!"
				exit 1
			fi
		;;
		mangohud-fps-unlimit* )
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				config_mangohud_fps_unlimit["$section"]="$value"
			else
				print_error "$error_prefix FPS specified in key 'mangohud-fps-unlimit' in section '$section' is not integer!"
				exit 1
			fi
		esac
	else
		print_error "$error_prefix Cannot define type of line '$config_line'!"
		exit 1
	fi
done < "$config"
unset config_line value section

# Check values in sections
for section_from_array in "${sections_array[@]}"; do
	# Exit with an error if neither identifier 'name' nor 'executable' nor 'command' is specified
	if [[ -z "${config_name["$section_from_array"]}" && -z "${config_executable["$section_from_array"]}" && -z "${config_command["$section_from_array"]}" ]]; then
		print_error "$error_prefix At least one process identifier required in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS-limit is not specified along with config path (for the fuck should I know which config should be modified then?)
	if [[ -n "${config_mangohud_fps_limit["$section_from_array"]}" && -z "${config_mangohud_config["$section_from_array"]}" ]]; then
		print_error "$error_prefix FPS-limit in key 'mangohud-fps-limit' in section '$section_from_array' is specified without path to MangoHud config!"
		exit 1
	fi
	# Exit with an error if MangoHud FPS-limit is specified along with CPU-limit
	if [[ -n "${config_mangohud_fps_limit["$section_from_array"]}" && -n "${config_cpulimit["$section_from_array"]}" ]]; then
		print_error "$error_prefix Do not use FPS-limit along with CPU-limit in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if 'mangohud-fps-unlimit' is specified without 'mangohud-fps-limit'
	if [[ -n "${config_mangohud_fps_unlimit["$section_from_array"]}" && -z "${config_mangohud_fps_limit["$section_from_array"]}" ]]; then
		print_error "$error_prefix Do not use 'mangohud-fps-unlimit' key without 'mangohud-fps-limit' key in section '$section_from_array'!"
		exit 1
	fi
	# Exit with an error if 'mangohud-config' is specified without 'mangohud-fps-limit'
	if [[ -n "${config_mangohud_config["$section_from_array"]}" && -z "${config_mangohud_fps_limit["$section_from_array"]}" ]]; then
		print_error "$error_prefix Do not use 'mangohud-config' key without 'mangohud-fps-limit' key in section '$section_from_array'!"
		exit 1
	fi
	# Set 'mangohud-fps-unlimit' to '0' (none) if it is not specified
	if [[ -n "${config_mangohud_fps_limit["$section_from_array"]}" && -z "${config_mangohud_fps_unlimit["$section_from_array"]}" ]]; then
		config_mangohud_fps_unlimit["$section_from_array"]=0
	fi
	# Set CPU-limit to '-1' (none) if it is not specified
	if [[ -z "${config_cpulimit["$section_from_array"]}" ]]; then
		config_cpulimit["$section_from_array"]='-1'
	fi
	# Set 'delay' to '0' if it is not specified
	if [[ -z "${config_delay["$section_from_array"]}" ]]; then
		config_delay["$section_from_array"]='0'
	fi
done
unset section_from_array

# Declare associative arrays
declare -A is_frozen # For marking frozen processes (PIDs)
declare -A freeze_subrocess_pid # For subprocesses to freeze with delay
declare -A is_cpulimited # For marking CPU-limited processes (PIDs)
declare -A cpulimit_subprocess_pid # For cpulimit subprocesses
declare -A is_fps_limited # For marking FPS-limited processes (sections)
declare -A fps_limit_subprocess_pid # For subprocesses to apply FPS-limit with delay
declare -A fps_limited_pid # To print PID of process in case daemon exit

# Dumbass protection, exit with an error if that is not a X11 session
if [[ "$XDG_SESSION_TYPE" != 'x11' ]]; then
	print_error "$error_prefix Flux was not meant for usage with anything but X11!"
	exit 1
fi

# Read IDs of windows and apply actions
while read -r window_id; do
	# Unset '--lazy' option if event was passed, otherwise focus and unfocus commands will not work
	if [[ "$window_id" == 'nolazy' ]]; then
		unset lazy
		lazy_was_unset=1
		continue
	elif [[ "$window_id" == 'nohot' ]]; then # Unset '--hot' since it becomes useless from this moment
		unset hot
		continue
	fi
	# Run command on unfocus event for previous window if specified
	if [[ -n "$previous_section_match" && -n "${config_unfocus["$previous_section_match"]}" && -z "$lazy" ]]; then
		# Required to avoid running unfocus command when new event appears after previous matching one when '--hot' option is used along with '--lazy'
		if [[ -z "$lazy_was_unset" ]]; then
			print_verbose "$verbose_prefix Running command on unfocus event '${config_unfocus["$previous_section_match"]}' from section '$previous_section_match'."
			# Variables passthrough to interact with them using custom commands in 'unfocus' key
			export_flux_variables "$previous_window_id" "$previous_process_pid" "$previous_process_name" "$previous_process_executable" "$previous_process_owner" "$previous_process_command"
			nohup setsid bash -c "${config_unfocus["$previous_section_match"]}" > /dev/null 2>&1 &
			unset_flux_variables
		else
			unset lazy_was_unset
		fi
	fi
	# Extract process info
	if ! extract_process_info; then
		print_error "$warn_prefix Cannot obtain PID of window with ID $window_id! Getting process info skipped."
	fi
	# Do not find matching section if window does not report its PID
	if [[ -n "$process_pid" ]]; then
		# Attempt to find a matching section in config
		for section_from_array in "${sections_array[@]}"; do
			# Compare process name with specified in section
			if [[ -n "${config_name["$section_from_array"]}" && "${config_name["$section_from_array"]}" != "$process_name" ]]; then
				continue
			else
				name_match='1'
			fi
			# Compare process executable path with specified in section
			if [[ -n "${config_executable["$section_from_array"]}" && "${config_executable["$section_from_array"]}" != "$process_executable" ]]; then
				continue
			else
				executable_match='1'
			fi
			# Compare UID of process with specified in section
			if [[ -n "${config_owner["$section_from_array"]}" && "${config_owner["$section_from_array"]}" != "$process_owner" ]]; then
				continue
			else
				owner_match='1'
			fi
			# Compare process command with specified in section
			if [[ -n "${config_command["$section_from_array"]}" && "${config_command["$section_from_array"]}" != "$process_command" ]]; then
				continue
			else
				command_match='1'
			fi
			# Mark as matching if all identifiers containing non-zero value
			if [[ -n "$name_match" && -n "$executable_match" && -n "$owner_match" && -n "$command_match" ]]; then
				section_match="$section_from_array"
				break
			fi
			unset name_match executable_match owner_match command_match
		done
		unset section_from_array name_match executable_match owner_match command_match
		if [[ -n "$section_match" ]]; then
			print_verbose "$verbose_prefix Process '$process_name' with PID $process_pid matches with section '$section_match'."
		else
			print_verbose "$verbose_prefix Process '$process_name' with PID $process_pid does not match with any section."
		fi
	fi
	# Check if PID is not the same as previous one
	if [[ "$process_pid" != "$previous_process_pid" ]]; then
		# Avoid applying CPU-limit if owner does not have rights
		if [[ -n "$previous_process_owner" && "$previous_process_owner" == "$UID" || "$UID" == '0' && "${config_cpulimit["$previous_section_match"]}" != '-1' ]]; then
			# Check for existence of previous match and if CPU-limit is set to 0
			if [[ -n "$previous_section_match" && "${config_cpulimit["$previous_section_match"]}" == '0' ]]; then
				# Freeze process if it has not been frozen
				if [[ -z "${is_frozen["$previous_process_pid"]}" ]]; then
					# Mark process as frozen
					is_frozen["$previous_process_pid"]='1'
					# Save PID to array to unfreeze process in case daemon interruption
					frozen_processes_array+=("$previous_process_pid")
					(	
						# Freeze process with delay if specified, otherwise freeze process immediately
						if [[ "${config_delay["$previous_section_match"]}" != '0' ]]; then
							print_verbose "$verbose_prefix Process '$previous_process_name' with PID $previous_process_pid will be frozen after ${config_delay["$previous_section_match"]} second(s) on unfocus event."
							sleep "${config_delay["$previous_section_match"]}"
						fi
						# Freeze process if it still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							if ! kill -STOP "$previous_process_pid" > /dev/null 2>&1; then
								print_error "$warn_prefix Cannot freeze process '$previous_process_name' with PID $previous_process_pid!"
							else
								print_info "$info_prefix Process '$previous_process_name' with PID $previous_process_pid has been frozen on unfocus event."
							fi
						else
							print_error "$warn_prefix Process '$previous_process_name' with PID $previous_process_pid has been terminated before freezing!"
						fi
					) &
					# Save PID of subprocess to interrupt it in case focus event appears earlier than delay ends
					freeze_subrocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_match" ]] && (( "${config_cpulimit["$previous_section_match"]}" > 0 )); then # Check for existence of previous match and CPU-limit specified greater than 0
				# Run cpulimit subprocess if CPU-limit has not been applied
				if [[ -z "${is_cpulimited["$previous_process_pid"]}" ]]; then
					# Mark process as CPU-limited
					is_cpulimited["$previous_process_pid"]='1'
					# Run cpulimit subprocess
					(
						# Ignore SIGTERM signal to avoid termination of parent subprocess while keeping child process which cpulimit is, that should be processed with 'exit_on_term' function via trap in beginning of code
						trap '' SIGTERM
						# Wait in case delay is specified
						if [[ "${config_delay["$previous_section_match"]}" != '0' ]]; then
							print_verbose "$verbose_prefix Process '$previous_process_name' with PID $previous_process_pid will be CPU-limited after ${config_delay["$previous_section_match"]} second(s) on unfocus event."
							sleep "${config_delay["$previous_section_match"]}"
						fi
						# Run cpulimit if target process still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							print_info "$info_prefix Process '$previous_process_name' with PID $previous_process_pid has been CPU-limited to ${config_cpulimit["$previous_section_match"]}/$max_cpulimit on unfocus event."
							if ! cpulimit --limit="${config_cpulimit["$previous_section_match"]}" --pid="$previous_process_pid" --lazy > /dev/null 2>&1; then
								print_error "$warn_prefix Cannot apply CPU-limit to process '$previous_process_name' with PID $previous_process_pid, 'cpulimit' returned error!"
							fi
						else
							print_error "$warn_prefix Process '$previous_process_name' with PID $previous_process_pid has been terminated before applying CPU-limit!"
						fi
					) &
					# Save PID of subprocess to array to interrupt it in case daemon exit
					cpulimit_subprocesses_array+=("$!")
					# Save PID of subprocess to interrupt it on focus event
					cpulimit_subprocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_match" && -n "${config_mangohud_fps_limit["$previous_section_match"]}" ]]; then # Check for existence of previous match and FPS-limit
				# Apply FPS-limit if was not applied before
				if [[ -z "${is_fps_limited["$previous_section_match"]}" ]]; then
					# Mark process as FPS-limited
					is_fps_limited["$previous_process_pid"]='1'
					# Save matching section name of process to array to unset FPS-limits on daemon exit
					fps_limited_array+=("$previous_section_match")
					# Save PID to print it in case daemon exit
					fps_limited_pid["$previous_section_match"]="$previous_process_pid"
					# Set FPS-limit
					(
						# Wait in case delay is specified
						if [[ "${config_delay["$previous_section_match"]}" != '0' ]]; then
							print_verbose "$verbose_prefix Process '$previous_process_name' with PID $previous_process_pid will be FPS-limited after ${config_delay["$previous_section_match"]} second(s) on unfocus event."
							sleep "${config_delay["$previous_section_match"]}"
						fi
						# Apply FPS-limit if target still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							print_info "$info_prefix Process '$previous_process_name' with PID $previous_process_pid has been FPS-limited to ${config_mangohud_fps_limit["$previous_section_match"]} FPS on unfocus event."
							mangohud_fps_set "${config_mangohud_config["$previous_section_match"]}" "${config_mangohud_fps_limit["$previous_section_match"]}"
						fi
					) &
					# Save PID of subprocess to interrupt it on focus event
					fps_limit_subprocess_pid["$previous_process_pid"]="$!"
				fi
			fi
		elif [[ -n "$previous_process_owner" ]]; then
			print_error "$warn_prefix Cannot apply CPU-limit to process '$previous_process_name' with PID $previous_process_pid, UID of process - $previous_process_owner, UID of user - $UID!"
		fi
	fi
	# Do not apply actions if window does not report its PID
	if [[ -n "$process_pid" ]]; then
		# Unfreeze process if window is focused
		if [[ -n "${is_frozen["$process_pid"]}" ]]; then
			# Do not terminate subprocess if it does not exist anymore
			if [[ -d "/proc/${freeze_subrocess_pid["$process_pid"]}" ]]; then
				# Terminate subprocess
				if ! kill "${freeze_subrocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID '${freeze_subrocess_pid["$process_pid"]}'!"
				else
					print_info "$info_prefix Delayed for ${config_delay["$section_match"]} second(s) freezing of process '$process_name' with PID $process_pid has been cancelled."
				fi
			fi
			freeze_subrocess_pid["$process_pid"]=''
			# Unfreeze process
			if ! kill -CONT "$process_pid" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot unfreeze process '$process_name' with PID $process_pid!"
			else
				print_info "$info_prefix Process '$process_name' with PID $process_pid has been unfrozen on focus event."
			fi
			is_frozen["$process_pid"]=''
			fps_limited_pid["$section_match"]=''
			# Remove PID from array
			for frozen_process in "${frozen_processes_array[@]}"; do
				# Skip current PID since I want remove it from array
				if [[ "$frozen_process" != "$process_pid" ]]; then
					frozen_processes_array_temp+=("$frozen_process")
				fi
			done
			frozen_processes_array=("${frozen_processes_array_temp[@]}")
			unset frozen_process frozen_processes_array_temp
		elif [[ -n "${is_cpulimited["$process_pid"]}" ]]; then # Check for CPU-limit via 'cpulimit' subprocess
			# Terminate 'cpulimit' subprocess
			if ! pkill -P "${cpulimit_subprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID ${cpulimit_subprocess_pid["$process_pid"]}!"
			else
				print_info "$info_prefix Process '$process_name' with PID $process_pid has been CPU unlimited on focus event."
			fi
			is_cpulimited["$process_pid"]=''
			# Remove PID of 'cpulimit' subprocess from array
			for cpulimit_subprocess in "${cpulimit_subprocesses_array[@]}"; do
				# Skip interrupted subprocess since I want remove it from array
				if [[ "$cpulimit_subprocess" != "${cpulimit_subprocess_pid["$process_pid"]}" ]]; then
					cpulimit_subprocesses_array_temp+=("$cpulimit_subprocess")
				fi
			done
			cpulimit_subprocess_pid["$process_pid"]=''
			cpulimit_subprocesses_array=("${cpulimit_subprocesses_array_temp[@]}")
			unset cpulimit_subprocess cpulimit_subprocesses_array_temp
		elif [[ -n "${is_fps_limited["$process_pid"]}" ]]; then
			# Do not terminate FPS-limit subprocess if it does not exist anymore
			if [[ -d "/proc/${fps_limit_subprocess_pid["$process_pid"]}" ]]; then
				if ! kill "${fps_limit_subprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
					print_error "$warn_prefix Cannot stop FPS-limit subprocess with PID ${fps_limit_subprocess_pid["$process_pid"]}!"
				else
					print_info "$info_prefix Delayed for ${config_delay["$section_match"]} second(s) FPS-limiting of process '$process_name' with PID $process_pid has been cancelled."
				fi
			fi
			# Unset FPS-limit
			print_info "$info_prefix Process '$process_name' with PID $process_pid has been FPS-unlimited on focus event."
			mangohud_fps_set "${config_mangohud_config["$section_match"]}" "${config_mangohud_fps_unlimit["$section_match"]}"
			is_fps_limited["$process_pid"]=''
			# Remove section from from array
			for fps_limited in "${fps_limited_array[@]}"; do
				# Skip FPS-unlimited section since I want remove it from array
				if [[ "$fps_limited" != "$section_match" ]]; then
					fps_limited_array_temp+=("$fps_limited")
				fi
			done
			fps_limited_array=("${fps_limited_array_temp[@]}")
			unset fps_limited fps_limited_array_temp
		fi
	fi
	# Run command on focus event if exists
	if [[ -n "$section_match" && -n "${config_focus["$section_match"]}" && -z "$lazy" ]]; then
		# Variables passthrough to interact with them using custom commands in 'focus' key
		export_flux_variables "$window_id" "$process_pid" "$process_name" "$process_executable" "$process_owner" "$process_command"
		nohup setsid bash -c "${config_focus["$section_match"]}" > /dev/null 2>&1 &
		unset_flux_variables
		print_verbose "$verbose_prefix Running command on focus event '${config_focus["$section_match"]}' from section '$section_match'."
	fi
	# Remember info of process to next cycle to run commands on unfocus and apply CPU-limit, also for pass variables to command in 'unfocus' key
	previous_window_id="$window_id"
	previous_process_pid="$process_pid"
	previous_process_name="$process_name"
	previous_process_executable="$process_executable"
	previous_process_owner="$process_owner"
	previous_section_match="$section_match"
	previous_process_command="$process_command"
	# Unset to avoid false positive on next cycle
	unset section_match
done < <(xprop_event_reader)