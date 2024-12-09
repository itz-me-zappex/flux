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