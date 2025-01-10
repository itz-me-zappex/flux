# Version of daemon shown from 'parse_options()' if '--version' is specified
daemon_version='1.18.2'

# Set default prefixes for messages
prefix_error='[x]'
prefix_info='[i]'
prefix_verbose='[~]'
prefix_warning='[!]'

# Set default timestamp format for logger
timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'

# Options parsing and forget cmdline options
parse_options "$@" && shift "${#@}"
unset -f parse_options \
option_repeat_check \
cmdline_get

# Options validation
validate_options
unset -f validate_options

# Config validation
validate_config
unset -f validate_config

# Log validation
validate_log
unset -f validate_log

# Calculation of maximum CPU limit
calculate_max_limit
unset -f calculate_max_limit

# Create associative arrays to store values from config
declare -A config_key_name_map \
config_key_executable_map \
config_key_owner_map \
config_key_cpu_limit_map \
config_key_delay_map \
config_key_exec_focus_map \
config_key_exec_unfocus_map \
config_key_lazy_exec_focus_map \
config_key_lazy_exec_unfocus_map \
config_key_command_map \
config_key_mangohud_source_config_map \
config_key_mangohud_config_map \
config_key_fps_unfocus_map \
config_key_fps_focus_map \
config_key_idle_map \
config_key_minimize_map

# Config parsing
parse_config
unset -f parse_config \
get_realpath

# Config keys validation
validate_config_keys
unset -f validate_config_keys

# Declare associative arrays to store info about applied limits
declare -A freeze_applied_map \
background_freeze_pid_map \
cpu_limit_applied_map \
background_cpu_limit_pid_map \
fps_limit_applied_map \
background_fps_limit_pid_map \
sched_idle_applied_map \
background_sched_idle_pid_map

# Declare associative arrays to store info about requested limits
declare -A request_freeze_map \
request_cpu_limit_map \
request_fps_limit_map \
request_sched_idle_map \
request_minimize_map

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_event_type_map \
cache_process_pid_map \
cache_process_name_map \
cache_process_executable_map \
cache_process_owner_map \
cache_process_command_map \
cache_section_map \
cache_mismatch_map \
cache_process_owner_username_map

# Declare associative arrays to remember previous process scheduling policy, priority and parameters of 'SCHED_DEADLINE' scheduling policy
declare -A sched_previous_policy_map \
sched_previous_priority_map \
sched_previous_runtime_map \
sched_previous_deadline_map \
sched_previous_period_map

# Exit with an error if that is not a X11 session
if ! x11_session_check; then
	# Exit with an error if X11 session is invalid
	message --error "Unable to start daemon, something is wrong with X11 session or window manager is EMHW incompatible!"
	exit 1
else
	# Will not be used anymore
	unset -f x11_session_check
	# Preparation for event reading
	daemon_prepare
	unset -f daemon_prepare
	# Read events
	while read -r event; do
		# These functions are not needed anymore since reading from 'event_source()' subprocess has been started
		# And I can not unset them before start of 'event_source()'
		if [[ -z "$event_source_is_unset" ]]; then
			unset -f check_windows \
			on_hot \
			event_source
			event_source_is_unset='1'
		fi
		# Apply actions depending by event type
		case "$event" in
		'error' )
			# Exit with an error in case 'error' event appears
			actions_on_exit
			message --error "Flux has been terminated unexpectedly!"
			exit 1
		;;
		'unset_hot' )
			# Unset '--hot' as it becomes useless from this moment
			unset hot
			# Needed to make commands from 'lazy-exec-unfocus' keys work properly, 'exec_unfocus()' skips execution 'lazy-exec-unfocus' first time and increases value to '2'
			hot_is_unset='1'
		;;
		'terminated'* )
			# Unset CPU/FPS limits for terminated windows and remove info about them from cache
			handle_terminated_windows
		;;
		'check_requests'* )
			# Apply CPU/FPS limits for process which have been requested to be limited
			set_requested_limits
		;;
		'restart' )
			# Prepare daemon to reapply limits on 'event_source()' restart event which appears if list of window IDs becomes blank
			hot='1'
			unset hot_is_unset
			# Unset info about processes to avoid using it by accident
			unset window_id \
			process_pid \
			process_name \
			process_executable \
			process_owner \
			process_command \
			section \
			previous_window_id \
			previous_process_pid \
			previous_process_name \
			previous_process_executable \
			previous_process_owner \
			previous_process_command \
			previous_section
		;;
		* )
			# Set window ID variable if event does not match with statements above
			window_id="$event"
			# Get process info using window ID if ID is not '0x0'
			case "$window_id" in
			'0x0' )
				message --verbose "Bad event with window ID 0x0 appeared, getting process info skipped."
			;;
			* )
				# Attempt to obtain info about process using window ID
				get_process_info
				get_process_info_exit_code="$?"
			esac
			# Request CPU/FPS limit for unfocused process if it matches with section
			unfocus_request_limit
			# Actions depending by exit code of 'get_process_info()'
			case "$get_process_info_exit_code" in
			'0' )
				# Find matching section for process in config
				if find_matching_section; then
					# Unset CPU/FPS limit for focused process if it has been limited on unfocus
					focus_unset_limit
					# Execute command on focus event if specified in config
					exec_focus
				fi
			;;
			* )
				# Print message depending by exit code of 'get_process_info()'
				case "$get_process_info_exit_code" in
				'1' )
					message --warning "Bad window with ID $window_id appeared, unable to obtain process info!"
				;;
				'2' )
					message --warning "Unable to obtain info about process with PID $process_pid!"
				;;
				'3' )
					message --warning "Daemon does not have sufficient rights to get info about process with PID $process_pid!"
				esac
			esac
			# Execute command on unfocus event if specified in config
			exec_unfocus
			# Define what to do with info about previous window depending by exit code (overwrite or unset)
			case "$get_process_info_exit_code" in
			'0' )
				# Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'exec-unfocus' key
				previous_window_id="$window_id"
				previous_process_pid="$process_pid"
				previous_process_name="$process_name"
				previous_process_executable="$process_executable"
				previous_process_owner="$process_owner"
				previous_process_command="$process_command"
				previous_section="$section"
			;;
			* )
				# Forget info about previous window/process because it is not changed
				unset previous_window_id \
				previous_process_pid \
				previous_process_name \
				previous_process_executable \
				previous_process_owner \
				previous_process_command \
				previous_section
			esac
			unset get_process_info_exit_code
			# Unset info about process to avoid using it by an accident
			unset window_id \
			process_pid \
			process_name \
			process_executable \
			process_owner \
			process_command \
			section
		esac
	done < <(event_source)
fi