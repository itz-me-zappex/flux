# Version of daemon shown from 'parse_options()' if '--version' is specified
daemon_version='1.20.8'

# Set default prefixes for messages
prefix_error='[x]'
prefix_info='[i]'
prefix_verbose='[~]'
prefix_warning='[!]'

# Set default timestamp format for logger
timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'

# Find path to `flux-event-reader` binary depending by main executable path
flux_event_reader="$(get_realpath "$0")"
case "$flux_event_reader" in
*'/bin/'* )
	# Replace '/bin/<executable>' with path to 'flux-event-reader' binary
	flux_event_reader="${flux_event_reader/%'/bin/'*/'/lib/flux/flux-event-reader'}"
;;
* )
	# Replace executable name with 'flux-event-reader' binary
	flux_event_reader="${flux_event_reader%/*}/flux-event-reader"
esac

# Create associative arrays to store values from config
declare -A config_key_name_map \
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

# Declare associative arrays to store info about applied limits
declare -A freeze_applied_map \
background_freeze_pid_map \
cpu_limit_applied_map \
background_cpu_limit_pid_map \
fps_limit_applied_map \
background_fps_limit_pid_map \
sched_idle_applied_map \
background_sched_idle_pid_map \
background_minimize_pid_map

# Declare associative arrays to store info about requested limits
declare -A request_freeze_map \
request_cpu_limit_map \
request_fps_limit_map \
request_sched_idle_map \
request_minimize_map \
request_exec_unfocus_general_map

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_process_pid_map \
cache_process_name_map \
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

# Config parsing
parse_config
unset -f parse_config \
get_realpath \
check_bool \
check_true

# Config keys validation
validate_config_keys
unset -f validate_config_keys

# Preparation for event reading
daemon_prepare
unset -f daemon_prepare

# Set initial events count
events_count='0'

# Read events from 'flux-event-reader' binary
while read -r raw_event; do
	(( events_count++ ))
	# Collect events
	if (( events_count == 1 )); then
		focused_window="$raw_event"
		continue
	elif (( events_count == 2 )); then
		opened_windows="$raw_event"
	fi
	# Remember that daemon received events to print proper message on event reading tool termination
	# And to print message about daemon start
	if [[ -z "$display_has_been_opened" ]]; then
		message --info "Flux has been started."
		display_has_been_opened='1'
	fi
	# Do nothing if '--hot' is not specified
	if [[ -n "$hot" ]]; then
		# Add opened windows info except focused one to array as events to apply actions to already opened windows
		for temp_window in $opened_windows; do
			if [[ "$temp_window" != "$focused_window" ]]; then
				events_array+=("$temp_window")
			fi
		done
		unset temp_window
		# Add event to unset '--hot'
		events_array+=('unset_hot')
	fi
	# Add info about focused window to array as event if it does not repeat
	if [[ "$previous_focused_window" != "$focused_window" ]]; then
		events_array+=("$focused_window")
		# Remember focused window ID to skip adding it to array as event if repeats
		previous_focused_window="$focused_window"
	fi
	# Add opened windows list as event to array to find terminated windows and check requests
	events_array+=("windows_list: $opened_windows")
	# Reset events count
	events_count='0'
	# Handle events
	for event in "${events_array[@]}"; do
		# Apply actions depending by event type
		case "$event" in
		'unset_hot' )
			# Unset '--hot' as it becomes useless from this moment
			unset hot
			# Needed to make commands from 'lazy-exec-unfocus' keys work properly, 'exec_unfocus()' skips execution 'lazy-exec-unfocus' first time and increases value to '2'
			hot_is_unset='1'
		;;
		'windows_list'* )
			# Unset CPU/FPS limits for terminated windows and remove info about them from cache
			handle_closure
			# Apply CPU/FPS limits for process which have been requested to be limited
			handle_requests
		;;
		* )
			# Unset info about process to avoid using it by an accident
			unset window_id \
			process_pid \
			process_name \
			process_owner \
			process_command \
			section
			# Get window ID
			window_id="${event/'='*/}"
			# Get process PID of focused window
			process_pid="${event/*'='/}"
			# Attempt to obtain info about process using window ID
			get_process_info
			get_process_info_exit_code="$?"
			# Request CPU/FPS limit for unfocused process if it matches with section
			unfocus_request_limit
			# Actions depending by exit code of 'get_process_info()'
			if (( get_process_info_exit_code == 0 )); then
				# Find matching section for process in config
				if find_matching_section; then
					# Unset CPU/FPS limit for focused process if it has been limited on unfocus
					focus_unset_limit
					# Execute command on focus event if specified in config
					exec_focus
				fi
			else
				if (( get_process_info_exit_code == 1 )); then
					message --warning "Unable to obtain info about process with PID $process_pid! Probably process has been terminated during check."
				elif (( get_process_info_exit_code == 2 )); then
					message --warning "Unable to obtain owner username of process $process_name with PID $process_pid!"
				fi
			fi
			# Define what to do with info about previous window depending by exit code (overwrite or unset)
			if (( get_process_info_exit_code == 0 )); then
				# Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'exec-unfocus' key
				previous_window_id="$window_id"
				previous_process_pid="$process_pid"
				previous_process_name="$process_name"
				previous_process_owner="$process_owner"
				previous_process_command="$process_command"
				previous_section="$section"
			else
				# Forget info about previous window/process because it is not changed
				unset previous_window_id \
				previous_process_pid \
				previous_process_name \
				previous_process_owner \
				previous_process_command \
				previous_section
			fi
			unset get_process_info_exit_code
		esac
	done
	# Unset events
	unset events_array
done < <("$flux_event_reader" 2>/dev/null)

# Exit with an error if loop has been broken and daemon did not exit because of 'SIGTERM' or 'SIGINT'
if [[ -n "$display_has_been_opened" ]]; then
	message --warning "Event reader has been terminated!"
	safe_exit
	message --error "Flux has been terminated unexpectedly!"
else
	message --error "Unable to open display, something is wrong with X11 session or window manager is not running!"
fi
exit 1