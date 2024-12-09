# Required to exit with an error if option repeated
option_repeat_check(){
	if [[ -n "${!1}" ]]; then
		message --error "Option '$2' is repeated!$advice_on_option_error"
		exit 1
	fi
}

# Required to obtain values from command line options
cmdline_get(){
	# Remember that option is passed in case value is not specified
	option_repeat_check "$passed_check" "$passed_option"
	eval "$passed_check"='1'
	# Define option type (short, long or long+value) and remember specified value
	case "$1" in
	"$passed_option" | "$passed_short_option" )
		# Remember value only if that is not an another option, regexp means long or short option
		if [[ -n "$2" && ! "$2" =~ ^(--.*|-.*)$ ]]; then
			eval "$passed_set"=\'"$2"\'
			shift='2'
		else
			shift='1'
		fi
	;;
	* )
		# Shell parameter expansion, remove option name from string
		eval "$passed_set"=\'"${1/"$passed_option"=/}"\'
		shift='1'
	esac
}

# Required to exit with an error if that is not a X11 session
x11_session_check(){
	# Fail if $DISPLAY does not match with `:[number]` and `:[number].[number]`
	# Or if $XDG_SESSION_TYPE is not equal to 'x11' (e.g. 'tty', 'wayland' etc.)
	if [[ ! "$DISPLAY" =~ ^\:[0-9]+(\.[0-9]+)?$ || "$XDG_SESSION_TYPE" != 'x11' ]]; then
		return 1
	elif ! xprop -root > /dev/null 2>&1; then # Fail if 'xprop' unable to get info about any opened window
		return 1
	fi
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
		message --verbose "Cache has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
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
				message --verbose "Cache of parent window with ID $local_matching_window_id has been used to obtain info about window with ID $window_id and process '$process_name' with PID $process_pid."
			else
				# Extract name of process
				if check_ro "/proc/$process_pid/comm"; then
					process_name="$(<"/proc/$process_pid/comm")"
				else
					return 2
				fi
				# Extract executable path of process
				if check_ro "/proc/$process_pid/exe"; then
					process_executable="$(readlink "/proc/$process_pid/exe")"
				else
					return 2
				fi
				# Extract effective UID of process
				if check_ro "/proc/$process_pid/status"; then
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
				else
					return 2
				fi
				# I did not get how to do that using built-in bash options
				# Extract command of process and replace '\0' (used as separator between options) with spaces
				if check_ro "/proc/$process_pid/cmdline"; then
					process_command="$(tr '\0' ' ' < "/proc/$process_pid/cmdline")"
					# Remove last space because '\0' (which is replaced with space) is last symbol too
					process_command="${process_command/%\ /}"
				else
					return 2
				fi
				message --verbose "Obtained info about window with ID $window_id and process '$process_name' with PID $process_pid has been cached."
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
	local_new_config_content \
	local_target_config="$1" \
	local_source_config="$2" \
	local_fps_to_set="$3" \
	local_fps_limit_is_changed
	# Check if config file exists before continue in case it has been removed
	if [[ -f "$local_target_config" ]]; then
		# Check for readability of source config only if it differs from target config
		if [[ "$local_target_config" != "$local_source_config" ]]; then
			# Check readability of source MangoHud config file
			if ! check_ro "$local_source_config"; then
				message --warning "Source MangoHud config file '$local_target_config' is not readable!"
				return 1
			fi
		fi
		# Check read-write ability of target MangoHud config file
		if ! check_rw "$local_target_config"; then
			message --warning "Target MangoHud config file '$local_target_config' is not rewritable!"
			return 1
		else
			# Replace 'fps_limit' value in config if exists
			while read -r local_temp_config_line || [[ -n "$local_temp_config_line" ]]; do
				# Find 'fps_limit' line, regexp means 'fps_limit[space(s)?]=[space(s)?][integer][anything else]'
				if [[ "$local_temp_config_line" =~ ^fps_limit([[:space:]]+)?=([[:space:]]+)?[0-9]+* ]]; then
					# Set specified FPS limit, shell parameter expansion replaces first number on line with specified new one
					local_new_config_content+="${local_temp_config_line/[0-9]*/"$local_fps_to_set"}\n"
					# Set mark which signals about successful setting of FPS limit
					local_fps_limit_is_changed='1'
				else
					# Add line to processed text
					local_new_config_content+="$local_temp_config_line\n"
				fi
			done < "$local_source_config"
			# Check whether FPS limit has been set or not
			if [[ -z "$local_fps_limit_is_changed" ]]; then
				# Pass config content with 'fps_limit' key if line does not exist in config
				echo -e "${local_new_config_content/%'\n'/}\nfps_limit = $local_fps_to_set" > "$local_target_config"
			else
				# Pass config content if FPS has been already changed
				echo -e "${local_new_config_content/%'\n'/}" > "$local_target_config"
			fi
		fi
	else
		message --warning "Target MangoHud config file '$local_target_config' does not exist!"
		return 1
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

# Required to run commands on focus and unfocus events
exec_on_event(){
	# Pass environment variables to interact with them using commands/scripts in 'exec-focus' or 'exec-unfocus' key and run command on passed event
	FLUX_FOCUSED_WINDOW_ID="$window_id" \
	FLUX_FOCUSED_PROCESS_PID="$process_pid" \
	FLUX_FOCUSED_PROCESS_NAME="$process_name" \
	FLUX_FOCUSED_PROCESS_EXECUTABLE="$process_executable" \
	FLUX_FOCUSED_PROCESS_OWNER="$process_owner" \
	FLUX_FOCUSED_PROCESS_COMMAND="$process_command" \
	FLUX_UNFOCUSED_WINDOW_ID="$previous_window_id" \
	FLUX_UNFOCUSED_PROCESS_PID="$previous_process_pid" \
	FLUX_UNFOCUSED_PROCESS_NAME="$previous_process_name" \
	FLUX_UNFOCUSED_PROCESS_EXECUTABLE="$previous_process_executable" \
	FLUX_UNFOCUSED_PROCESS_OWNER="$previous_process_owner" \
	FLUX_UNFOCUSED_PROCESS_COMMAND="$previous_process_command" \
	passed_section='' \
	passed_event_command='' \
	passed_event='' \
	nohup setsid bash -c "$passed_event_command" > /dev/null 2>&1 &
	message --info "Command '$passed_event_command' from section '$passed_section' has been executed on $passed_event event."
}