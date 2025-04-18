# Unset environment variables which are lowercase and may cause conflicts
while read -r temp_envvar_line ||
      [[ -n "$temp_envvar_line" ]]; do
  # Remove 'declare -x' from line
  temp_envvar_line="${temp_envvar_line/'declare -x '/}"

  # Get name
  envvar_name="${temp_envvar_line/%=*/}"

  # Unset variable if its name written in lowercase
  if [[ "$envvar_name" =~ ^[a-z0-9_]+$ ]]; then
    unset "$envvar_name"
  fi
done < <(declare -x)
unset temp_envvar_line \
envvar_name

# Version of daemon shown from 'parse_options()' if '--version' is specified
daemon_version='1.24.4'

# Set path to file containing daemon PID, needed to prevent multiple instances from running
# Hardcoded in 'flux-event-reader' and it is not supposed to be changeable
lock_file='/tmp/flux-lock'

# Define prefix where daemon has been installed using path to 'flux'
flux_path="$(get_realpath "$0")"
case "$flux_path" in
*'/bin/flux'* )
  # Keep just prefix path
  daemon_prefix="${flux_path/%'/bin/flux'/}"

  # Define paths to modules
  flux_event_reader_path="${daemon_prefix}/lib/flux/flux-event-reader"
  window_minimize_path="${daemon_prefix}/lib/flux/window-minimize"
  window_fullscreen_path="${daemon_prefix}/lib/flux/window-fullscreen"
  select_window_path="${daemon_prefix}/lib/flux/select-window"
  flux_cursor_grab="${daemon_prefix}/lib/flux/flux-cursor-grab"
;;
* )
  # Keep just executable directory
  daemon_prefix="${flux_path/%'/flux'/}"

  # Define paths to modules
  flux_event_reader_path="${daemon_prefix}/flux-event-reader"
  window_minimize_path="${daemon_prefix}/window-minimize"
  window_fullscreen_path="${daemon_prefix}/window-fullscreen"
  select_window_path="${daemon_prefix}/select-window"
  flux_cursor_grab="${daemon_prefix}/flux-cursor-grab"
esac
unset flux_path \
daemon_prefix

# Set default prefixes and timestamp format for messages automatically
if [[ -t 1 &&
      -t 2 ]]; then
  # Assuming stdout/stderr is a terminal
  prefix_error="$(echo -e "[\e[31mx\e[0m]")" # Red
  prefix_info="$(echo -e "[\e[32mi\e[0m]")" # Green
  prefix_verbose="$(echo -e "[\e[34m~\e[0m]")" # Blue
  prefix_warning="$(echo -e "[\e[33m!\e[0m]")" # Yellow
  timestamp_format="$(echo -e "[\e[35m%Y-%m-%dT%H:%M:%S%z\e[0m]")" # Pink

  log_prefix_error='[x]'
  log_prefix_info='[i]'
  log_prefix_verbose='[~]'
  log_prefix_warning='[!]'
  log_timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'
else
  # For case color mode will not be specified using '--color', needed to handle custom prefixes and timestamp
  color='never'

  # Assuming stdout/stderr is redirected
  prefix_error='[x]'
  prefix_info='[i]'
  prefix_verbose='[~]'
  prefix_warning='[!]'
  timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'

  log_prefix_error="$prefix_error"
  log_prefix_info="$prefix_info"
  log_prefix_verbose="$prefix_verbose"
  log_prefix_warning="$prefix_warning"
  log_timestamp_format="$timestamp_format"
fi

# Create associative arrays to store values from config
declare -A config_key_name_map \
config_key_owner_map \
config_key_cpu_limit_map \
config_key_delay_map \
config_key_exec_oneshot_map \
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
config_key_unfocus_minimize_map \
config_key_focus_fullscreen_map \
config_key_focus_cursor_grab_map

# Needed to detect blank sections in config during parsing
declare -A is_section_blank_map

# Declare associative arrays to store info about backgrounded limits
declare -A background_freeze_pid_map \
background_cpu_limit_pid_map \
background_fps_limit_pid_map \
background_sched_idle_pid_map \
background_focus_cursor_grab_map

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

# Needed to define section with just identifiers specified, i.e. with no any action
declare -A is_section_useful_map

# Needed to remember that 'exec-oneshot' command has been executed
declare -A is_exec_oneshot_executed_map

# Options parsing and forget cmdline options
parse_options "$@"
shift "${#@}"
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

# Get maximum CPU limit
get_max_cpu_limit
unset -f get_max_cpu_limit

# Config parsing
parse_config
unset -f parse_config \
get_realpath \
simplify_bool
unset max_cpu_limit

# Config keys validation
validate_config_keys
unset -f validate_config_keys
unset is_section_useful_map \
is_section_blank_map \
config

# Preparation for event reading
daemon_prepare
unset -f daemon_prepare \
colors_interpret \
configure_prefixes

# Set initial events count
events_count='0'

# Read events from 'flux-event-reader' binary
while read -r raw_event ||
      [[ -n "$raw_event" ]]; do
  (( events_count++ ))

  # Collect events
  if (( events_count == 1 )); then
    focused_window="$raw_event"
    continue
  else
    opened_windows="$raw_event"
  fi

  # Remember that daemon received events to print proper message on event reading tool termination
  # And to print message about daemon start
  if [[ -z "$display_has_been_opened" ]]; then
    quiet='' message --info "Flux has been started."
    display_has_been_opened='1'
  fi

  # Add opened windows as focus events once if '--hot' is specified, otherwise find implicitly opened windows and add those as focus events
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
  else
    # Do not do anything if list of opened windows from previous event is blank
    if [[ -n "$previous_opened_windows" ]]; then
      # Attempt to find implicitly opened windows
      for temp_window in $opened_windows; do
        # Add window as event if opened implicitly
        if [[ " $previous_opened_windows " != *" $temp_window "* &&
              "$temp_window" != "$focused_window" ]]; then
          # Add event to set '--hot' temporary, to avoid execution of lazy commands
          if [[ "${events_array[*]}" != 'disallow_lazy_commands'* ]]; then
            events_array+=('disallow_lazy_commands')
          fi

          # Add window as focus event
          events_array+=("$temp_window")
        fi
      done
      unset temp_window

      # Add event to unset '--hot'
      if [[ "${events_array[*]}" == 'disallow_lazy_commands'* ]]; then
        events_array+=('allow_lazy_commands')
      fi

      # Prevent focused window from being handled as unfocused
      disallow_request="$focused_window"
    fi
  fi

  # Add info about focused window to array as event if it does not repeat
  if [[ "$previous_focused_window" != "$focused_window" ]]; then
    events_array+=("$focused_window")
    # Remember focused window XID to skip adding it to array as event if repeats
    previous_focused_window="$focused_window"
  fi

  # Add opened windows list as event to array to find terminated windows and check requests
  events_array+=("windows_list: $opened_windows")

  # Reset events count
  events_count='0'

  # Remember list of previously opened windows to find implicitly opened ones next time
  previous_opened_windows="$opened_windows"

  # Handle events
  for event in "${events_array[@]}"; do
    # Apply actions depending by event type
    case "$event" in
    'set_hot' )
      # Set '--hot' temporary to process implicitly opened windows
      hot='1'

      # Prevent lazy commands in matching sections of implicitly opened windows from working
      unset allow_lazy_commands
    ;;
    'unset_hot' )
      # Unset '--hot' as it becomes useless from this moment
      unset hot
    ;;
    'disallow_lazy_commands' )
      # Disallow lazy commands before handle implicitly opened windows
      hot='1'
      unset allow_lazy_commands

      # Remember focused window info to set it as previous after handling implicitly opened windows
      # Needed to make daemon able to handle requests after first unfocus event (after handling implicitly opened windows)
      explicit_window_xid="$window_xid"
      explicit_process_pid="$process_pid"
      explicit_process_name="$process_name"
      explicit_process_owner="$process_owner"
      explicit_process_command="$process_command"
      explicit_section="$section"
    ;;
    'allow_lazy_commands' )
      # Unset '--hot' to allow lazy commands after handling all internal events
      unset hot

      # Restore info about focused window after handling implicitly opened windows
      previous_window_xid="$explicit_window_xid"
      previous_process_pid="$explicit_process_pid"
      previous_process_name="$explicit_process_name"
      previous_process_owner="$explicit_process_owner"
      previous_process_command="$explicit_process_command"
      previous_section="$explicit_section"

      unset explicit_window_xid \
      explicit_process_pid \
      explicit_process_name \
      explicit_process_owner \
      explicit_process_command \
      explicit_section
    ;;
    'windows_list'* )
      # Unset CPU/FPS limits for terminated windows and remove info about them from cache
      handle_closure

      # Apply CPU/FPS limits for process which have been requested to be limited
      handle_requests
    ;;
    * )
      # Unset info about process to avoid using it by an accident
      unset window_xid \
      process_pid \
      process_name \
      process_owner \
      process_command \
      section

      # Get window XID
      window_xid="${event/'='*/}"

      # Get process PID of focused window
      process_pid="${event/*'='/}"

      # Cancel cursor grabbing for previously focused window
      if [[ -n "$previous_window_xid" &&
            -n "${background_focus_cursor_grab_map["$previous_window_xid"]}" ]]; then
        passed_window_xid="$previous_window_xid"
        passed_process_pid="$previous_process_pid" \
        passed_process_name="$previous_process_name" \
        passed_end_of_msg="due to unfocus event" \
        cursor_ungrab
      fi

      # Hide error messages, even standart ones which are appearing directly from Bash (https://unix.stackexchange.com/a/184807)
      exec 3>&2
      exec 2>/dev/null

      # Attempt to obtain info about process using window XID
      get_process_info
      get_process_info_exit_code="$?"

      # Restore stderr
      exec 2>&3

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

          # Enforce fullscreen mode for window if specified in config
          if [[ -n "${config_key_focus_fullscreen_map["$section"]}" ]]; then
            # Send to background because there is 100ms delay before change child window size to match screen in case window/process did not do that automatically
            (
              if ! "$window_fullscreen_path" "$window_xid" > /dev/null 2>&1; then
                message --warning "Unable to expand to fullscreen window with XID $window_xid of process '$process_name' with PID $process_pid due to focus event!"
              else
                message --info "Window with XID $window_xid of process '$process_name' with PID $process_pid has been expanded into fullscreen due to focus event."
              fi
            ) &
          fi

          # Make window grab cursor if specified in config and that is not implicitly opened window
          if [[ -n "${config_key_focus_cursor_grab_map["$section"]}" &&
                -z "$hot" ]]; then
            # Send to background as that is daemonized process
            "$flux_cursor_grab" "$window_xid" > /dev/null 2>&1 &

            background_focus_cursor_grab_map["$window_xid"]="$!"

            # Print message about successful cursor grabbing if process still exists
            (
              sleep 0.1
              if check_pid_existence "${background_focus_cursor_grab_map["$window_xid"]}"; then
                message --info "Cursor for window with XID $window_xid of process '$process_name' with PID $process_pid has been grabbed due to focus event."
              else
                message --warning "Unable to grab cursor for window with XID $window_xid of process '$process_name' with PID $process_pid due to focus event!"
              fi
            ) &
          fi
        fi

        # Remember info about process for next event to run commands on unfocus event and apply CPU/FPS limit, also for pass variables to command in 'exec-unfocus' key
        previous_window_xid="$window_xid"
        previous_process_pid="$process_pid"
        previous_process_name="$process_name"
        previous_process_owner="$process_owner"
        previous_process_command="$process_command"
        previous_section="$section"
      else
        # Forget info about previous window/process because it is not changed
        unset previous_window_xid \
        previous_process_pid \
        previous_process_name \
        previous_process_owner \
        previous_process_command \
        previous_section

        message --warning "Unable to obtain info about process with PID $process_pid of window with XID $window_xid! Probably process has been terminated during check."
      fi

      unset get_process_info_exit_code
    esac
  done

  # Allow lazy commands
  if [[ -z "$hot" ]]; then
    allow_lazy_commands='1'
  fi

  # Unset request lock
  if [[ -n "$disallow_request" ]]; then
    unset disallow_request
  fi
  
  # Unset events
  unset events_array
done < <("$flux_event_reader_path" 2>/dev/null)

# Exit with an error if loop has been broken and daemon did not exit because of 'SIGTERM' or 'SIGINT'
if [[ -n "$display_has_been_opened" ]]; then
  message --warning "Event reader has been terminated!"
  safe_exit
  message --error "Flux has been terminated unexpectedly!"
else
  message --error "Something is wrong with X11 session or EWMH-compatible window manager is not running!"
fi
exit 1
