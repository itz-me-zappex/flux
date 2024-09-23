#!/usr/bin/bash

# Use built-in 'read -t <seconds>' instead of external '/usr/bin/sleep <seconds>' to minimize usage of external tools
# Also this method is more accurate and faster since we are not spending time on call external binary, which should load its libs etc.
# Except that, '/usr/bin/sleep' spawns separate process with its own PID while 'read' does not and everything happens directly in bash
# If you want to use external '/usr/bin/sleep' binary, just comment function out
sleep(){
	read -t "$1"
	return 0
}

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
do_not_print_quiet(){
	if [[ -z "$quiet" ]]; then
		echo -e "$@"
	fi
}

# Exit with error if option repeated
option_repeat_check(){
	if [[ -n "${!1}" ]]; then
		print_error "$error_prefix Option '$2' is repeated!$advice_on_option_error"
		exit 1
	fi
}

# Refresh PIDs in arrays containing frozen processes and cpulimit subprocesses by removing terminated PIDs
refresh_pids(){
	# Remove terminated PIDs from array containing frozen PIDs
	if [[ -n "${frozen_processes_array[*]}" ]]; then
		for frozen_process in "${frozen_processes_array[@]}"; do
			if [[ -d "/proc/$frozen_process" ]]; then
				frozen_processes_array_temp+=("$frozen_process")
			fi
		done
		unset frozen_process
		frozen_processes_array=("${frozen_processes_array_temp[@]}")
		unset frozen_processes_array_temp
	fi
	# Remove terminated PIDs from array containing cpulimit subprocesses
	if [[ -n "${cpulimit_subprocesses_array[*]}" ]]; then
		for cpulimit_subprocess in "${cpulimit_subprocesses_array[@]}"; do
			if [[ -d "/proc/$cpulimit_subprocess" ]]; then
				cpulimit_subprocesses_array_temp+=("$cpulimit_subprocess")
			fi
		done
		unset cpulimit_subprocess
		cpulimit_subprocesses_array=("${cpulimit_subprocesses_array_temp[@]}")
		unset cpulimit_subprocesses_array_temp
	fi
}

# Extract window IDs from xprop events
xprop_event_reader(){
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
		unset stacking_window stacking_windows hot focused_window
	fi
	# Print event for unset '--lazy' option before reading events, otherwise focus and unfocus commands will not work
	echo 'nolazy'
	# Read events from xprop and print IDs of windows
	while read -r xprop_event; do
		# Extract ID from line
		window_id="${xprop_event/* \# /}"
		# Skip cycle if window ID is exactly the same as previous one, workaround required for some buggy WMs
		if [[ "$window_id" == "$previous_window_id" ]]; then
			continue
		else
			# Do not print bad events, workaround required for some buggy WMs
			if [[ "$window_id" != '0x0' ]]; then
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

# Actions on TERM and INT signals
exit_on_term(){
	# Refresh PIDs in arrays containing frozen processes and cpulimit subprocesses by removing terminated PIDs
	refresh_pids
	# Unfreeze processes
	for frozen_process in "${frozen_processes_array[@]}"; do
		if ! kill -CONT "$frozen_process" > /dev/null 2>&1; then
			print_error "$warn_prefix Cannot unfreeze process with PID $frozen_process!"
		else
			print_verbose "$verbose_prefix Process with PID $frozen_process has been unfrozen."
		fi
	done
	# Kill cpulimit subprocesses
	for cpulimit_subprocess in "${cpulimit_subprocesses_array[@]}"; do
		if ! pkill -P "$cpulimit_subprocess" > /dev/null 2>&1; then
			print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID $cpulimit_subprocess!"
		else
			print_verbose "$verbose_prefix CPU-limit subprocess with PID '$cpulimit_subprocess' has been killed."
		fi
	done
	do_not_print_quiet "$info_prefix Terminated."
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
advice_on_option_error="\n$info_prefix Try '$0 --help' for more information."

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
		echo "flux - A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.
Usage: flux [option] <value>
Options and values:
    -c, --config     <path-to-config>    Specify path to config file
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -q, --quiet                          Print errors and warnings only
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
	--verbose | -v )
		option_repeat_check verbose --verbose
		verbose=1
		shift 1
	;;
	--version | -V )
		# Get Bash version from output, because variable "$BASH_VERSION" could be overwritten because it is not read-only
		while read -r bash_version_line; do
			# Remove 'GNU bash, version ' from line
			bash_version="${bash_version_line/GNU bash, version /}"
			# I need only first line, so break cycle
			break
		done < <(LC_ALL='C' bash --version)
		echo "flux 1.1 (bash $bash_version)
License: GPL-3.0
Repository: https://github.com/itz-me-zappex/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
		exit 0
	;;
	* )
		# Regexp means 2+ symbols after hyphen (combined short options)
		if [[ "$1" =~ ^-([A-Z]|[a-z]|[0-9]|.){2,}+$ ]]; then
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
declare -A config_name config_executable config_owner config_cpulimit config_delay config_focus config_unfocus config_command

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
	if [[ "${config_line,,}" =~ ^(name|executable|owner|cpulimit|delay|focus|unfocus|command)(\ )?=(\ )?.* ]]; then
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

# Declare associative arrays for frozen processes and subprocesses to freeze with delay
declare -A is_frozen freeze_subrocess_pid

# Declare associative arrays for CPU-limited processes and cpulimit subprocesses
declare -A is_cpulimited cpulimit_subprocess_pid

# Read IDs of windows and apply actions
while read -r window_id; do
	# Unset '--lazy' option if event was passed, otherwise focus and unfocus commands will not work
	if [[ "$window_id" == 'nolazy' ]]; then
		unset lazy
		continue
	fi
	# Refresh PIDs in arrays containing frozen processes and cpulimit subprocesses by removing terminated PIDs
	refresh_pids
	# Run command on unfocus event for previous window if specified
	if [[ -n "$previous_section_match" && -n "${config_unfocus["$previous_section_match"]}" && -z "$lazy" ]]; then
		print_verbose "$verbose_prefix Running command on unfocus event '${config_unfocus["$previous_section_match"]}' from section '$previous_section_match'."
		# Variables passthrough to interact with them using custom commands in 'unfocus' key
		export_flux_variables "$previous_window_id" "$previous_process_pid" "$previous_process_name" "$previous_process_executable" "$previous_process_owner" "$previous_process_command"
		nohup setsid bash -c "${config_unfocus["$previous_section_match"]}" > /dev/null 2>&1 &
		unset_flux_variables
	fi
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
		# Extract command of process, a bit complicated to avoid warning about zero bytes trying read file using subshell
		IFS=$'\0' read -r -a process_command_array < "/proc/$process_pid/cmdline"
		process_command="${process_command_array[*]}"
		unset process_command_array IFS
	else
		print_error "$warn_prefix Cannot obtain PID of window with ID '$window_id'! Getting process info skipped."
		process_pid=''
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
		unset section_from_array
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
								do_not_print_quiet "$info_prefix Process '$previous_process_name' with PID $previous_process_pid has been frozen on unfocus event."
							fi
						else
							print_error "$warn_prefix Process '$previous_process_name' with PID $previous_process_pid has been terminated before freezing!"
						fi
					) &
					# Save PID to array to unfreeze process in case daemon interruption
					frozen_processes_array+=("$previous_process_pid")
					# Save PID of subprocess to interrupt it in case focus event appears earlier than delay ends
					freeze_subrocess_pid["$previous_process_pid"]="$!"
				fi
			elif [[ -n "$previous_section_match" ]] && (( "${config_cpulimit["$previous_section_match"]}" > 0 )); then # Check for existence of previous match and CPU-limit specified greater than 0
				# Run cpulimit subprocess if CPU-limit has not been applied
				if [[ -z "${is_cpulimited["$previous_process_pid"]}" ]]; then
					# Mark process as CPU-limited
					is_cpulimited["$previous_process_pid"]='1'
					# Run cpulimit subprocess
					if [[ "${config_delay["$previous_section_match"]}" != '0' ]]; then
						print_verbose "$verbose_prefix Process '$previous_process_name' with PID $previous_process_pid will be CPU-limited after ${config_delay["$previous_section_match"]} second(s) on unfocus event."
					fi
					(
						# Ignore SIGTERM signal to avoid killing parent subprocess while keeping child process which cpulimit is, that should be processed with 'exit_on_term' function via trap in beginning of code
						trap '' SIGTERM
						# Wait in case delay is specified
						if [[ "${config_delay["$previous_section_match"]}" != '0' ]]; then
							sleep "${config_delay["$previous_section_match"]}"
						fi
						# Run cpulimit if target process still exists, otherwise throw warning
						if [[ -d "/proc/$previous_process_pid" ]]; then
							do_not_print_quiet "$info_prefix Process '$previous_process_name' with PID $previous_process_pid has been CPU-limited to ${config_cpulimit["$previous_section_match"]}/$max_cpulimit on unfocus event."
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
			fi
		elif [[ -n "$previous_process_owner" ]]; then
			print_error "$warn_prefix Cannot apply CPU-limit to process '$previous_process_name' with PID $previous_process_pid, UID of process - $previous_process_owner, UID of user - $UID!"
		fi
	fi
	# Do not apply actions if window does not report its PID
	if [[ -n "$process_pid" ]]; then
		# Unfreeze process if window is focused
		if [[ -n "${is_frozen["$process_pid"]}" ]]; then
			# Kill subprocess with delayed freeze command if exists
			if [[ -n "${freeze_subrocess_pid["$process_pid"]}" ]]; then
				if [[ -d "/proc/${freeze_subrocess_pid["$process_pid"]}" ]]; then
					if ! kill "${freeze_subrocess_pid["$process_pid"]}" > /dev/null 2>&1; then
						print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID '${freeze_subrocess_pid["$process_pid"]}'!"
					else
						do_not_print_quiet "$info_prefix Delayed for ${config_delay["$section_match"]} second(s) freezing of process '$process_name' with PID $process_pid was cancelled."
					fi
				fi
				freeze_subrocess_pid["$process_pid"]=''
			fi
			# Unfreeze process
			if ! kill -CONT "$process_pid" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot unfreeze process '$process_name' with PID $process_pid!"
			else
				do_not_print_quiet "$info_prefix Process '$process_name' with PID $process_pid was unfrozen on focus event."
			fi
			is_frozen["$process_pid"]=''
			# Remove PID from array
			for frozen_process in "${frozen_processes_array[@]}"; do
				if [[ "$frozen_process" != "$process_pid" ]]; then
					frozen_processes_array_temp+=("$frozen_process")
				fi
			done
			unset frozen_process
			frozen_processes_array=("${frozen_processes_array_temp[@]}")
			unset frozen_processes_array_temp
		elif [[ -n "${is_cpulimited["$process_pid"]}" ]]; then # Kill cpulimit subprocess if window is focused
			if ! pkill -P "${cpulimit_subprocess_pid["$process_pid"]}" > /dev/null 2>&1; then
				print_error "$warn_prefix Cannot stop 'cpulimit' subprocess with PID ${cpulimit_subprocess_pid["$process_pid"]}!"
			else
				do_not_print_quiet "$info_prefix Process '$process_name' with PID $process_pid was CPU unlimited on focus event."
			fi
			is_cpulimited["$process_pid"]=''
			# Remove PID of cpulimit subprocess from array
			for cpulimit_subprocess in "${cpulimit_subprocesses_array[@]}"; do
				if [[ "$cpulimit_subprocess" != "${cpulimit_subprocess_pid["$process_pid"]}" ]]; then
					cpulimit_subprocesses_array_temp+=("$cpulimit_subprocess")
				fi
			done
			unset cpulimit_subprocess
			cpulimit_subprocess_pid["$process_pid"]=''
			cpulimit_subprocesses_array=("${cpulimit_subprocesses_array_temp[@]}")
			unset cpulimit_subprocesses_array_temp
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
	# Unset for avoid false positive on next cycle
	unset section_match
done < <(xprop_event_reader)
