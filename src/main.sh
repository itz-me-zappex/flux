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
daemon_version='1.29.2'

# Set X11 display if not set
if [[ -z "$DISPLAY" ]]; then
  export DISPLAY=':0'
fi

# Set path to file containing daemon PID, needed to prevent multiple instances from running
flux_lock_file_path='/tmp/flux-lock'

# Needed to read output of 'flux-listener'
flux_listener_fifo='/tmp/flux-listener-fifo'

# Needed to read output of 'flux-grab-cursor'
flux_grab_cursor_fifo='/tmp/flux-grab-cursor-fifo'

# Define prefix where daemon has been installed using path to 'flux'
flux_path="$(get_realpath "$0")"
case "$flux_path" in
*'/bin/flux'* )
  # Keep just prefix path
  daemon_prefix="${flux_path/%'/bin/flux'/}"

  # Define paths to modules
  flux_listener_path="${daemon_prefix}/lib/flux/flux-listener"
  window_minimize_path="${daemon_prefix}/lib/flux/window-minimize"
  window_fullscreen_path="${daemon_prefix}/lib/flux/window-fullscreen"
  select_window_path="${daemon_prefix}/lib/flux/select-window"
  flux_grab_cursor_path="${daemon_prefix}/lib/flux/flux-grab-cursor"
  validate_x11_session_path="${daemon_prefix}/lib/flux/validate-x11-session"
;;
* )
  # Keep just executable directory
  daemon_prefix="${flux_path/%'/flux'/}"

  # Define paths to modules
  flux_listener_path="${daemon_prefix}/flux-listener"
  window_minimize_path="${daemon_prefix}/window-minimize"
  window_fullscreen_path="${daemon_prefix}/window-fullscreen"
  select_window_path="${daemon_prefix}/select-window"
  flux_grab_cursor_path="${daemon_prefix}/flux-grab-cursor"
  validate_x11_session_path="${daemon_prefix}/validate-x11-session"
esac
unset flux_path \
daemon_prefix

# Define default prefixes
color_prefix_error="$(echo -e "[\e[31mx\e[0m]")" # Red
color_prefix_info="$(echo -e "[\e[32mi\e[0m]")" # Green
color_prefix_verbose="$(echo -e "[\e[34m~\e[0m]")" # Blue
color_prefix_warning="$(echo -e "[\e[33m!\e[0m]")" # Yellow
color_timestamp_format="$(echo -e "[\e[35m%Y-%m-%dT%H:%M:%S%z\e[0m]")" # Pink
colorless_prefix_error='[x]'
colorless_prefix_info='[i]'
colorless_prefix_verbose='[~]'
colorless_prefix_warning='[!]'
colorless_timestamp_format='[%Y-%m-%dT%H:%M:%S%z]'

# Set default prefixes and timestamp format for messages automatically
if [[ -t 1 &&
      -t 2 ]]; then
  # Assuming stdout/stderr is a terminal
  prefix_error="$color_prefix_error"
  prefix_info="$color_prefix_info"
  prefix_verbose="$color_prefix_verbose"
  prefix_warning="$color_prefix_warning"
  timestamp_format="$color_timestamp_format"

  log_prefix_error="$colorless_prefix_error"
  log_prefix_info="$colorless_prefix_info"
  log_prefix_verbose="$colorless_prefix_verbose"
  log_prefix_warning="$colorless_prefix_warning"
  log_timestamp_format="$colorless_timestamp_format"
else
  # For case color mode will not be specified using '--color', needed to handle custom prefixes and timestamp
  color='never'

  # Assuming stdout/stderr is redirected
  prefix_error="$colorless_prefix_error"
  prefix_info="$colorless_prefix_info"
  prefix_verbose="$colorless_prefix_verbose"
  prefix_warning="$colorless_prefix_warning"
  timestamp_format="$colorless_timestamp_format"

  log_prefix_error="$colorless_prefix_error"
  log_prefix_info="$colorless_prefix_info"
  log_prefix_verbose="$colorless_prefix_verbose"
  log_prefix_warning="$colorless_prefix_warning"
  log_timestamp_format="$colorless_timestamp_format"
fi

# Create associative arrays to store values from config
declare -A config_key_name_map \
config_key_owner_map \
config_key_cpu_limit_map \
config_key_delay_map \
config_key_exec_closure_map \
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
config_key_focus_grab_cursor_map \
config_key_group_map \
config_key_exec_exit_map \
config_key_exec_exit_focus_map \
config_key_exec_exit_unfocus_map

# Needed to remember line and order of keys in section, used to handle 'group' config key and print line in warnings after parsing (validation)
declare -A config_keys_order_map

# Needed to detect blank sections in config during parsing
declare -A is_section_blank_map

# Needed to remember whether regexp should be used to find matching identifiers or not
declare -A config_key_regexp_name_map \
config_key_regexp_command_map \
config_key_regexp_owner_map

# Declare associative arrays to store info about backgrounded limits
declare -A background_freeze_pid_map \
background_cpu_limit_pid_map \
background_fps_limit_pid_map \
background_sched_idle_pid_map \
background_focus_grab_cursor_map

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

# Get values from groups
handle_groups
unset -f config_get_group_values
unset config_key_group_map

# Config keys validation
validate_config_keys
unset -f validate_config_keys
unset is_section_useful_map \
is_section_blank_map \
config \
get_key_line \
config_keys_order_map \
config_line_count \
get_key_line_result

# Unset groups to avoid false positives due to missing identifiers (overwrites sections array)
unset_groups
unset -f unset_groups \
section_is_group

# Validate X11 session
validate_x11_session
validate_x11_session_exit_code="$?"

# Define message depending by exit code
if (( validate_x11_session_exit_code > 0 )); then
  case "$validate_x11_session_exit_code" in
  1 )
    message --error "Unable to start daemon, Wayland is not supported!"
  ;;
  2 )
    message --error "Unable to start daemon, X11 session is not running!"
  ;;
  3 )
    message --error "Unable to start daemon, EWMH-compatible window manager is not running!"
  esac

  exit 1
else
  unset -f validate_x11_session
  unset validate_x11_session_exit_code
fi

# Validate lock file
validate_lock
unset -f validate_lock

# Needed to kill 'flux-listener' process when daemon receives 'SIGINT'/'SIGTERM'
mkfifo "$flux_listener_fifo"
"$flux_listener_path" > "$flux_listener_fifo" &
flux_listener_pid="$!"

# Preparation for event reading
daemon_prepare
unset -f daemon_prepare \
colors_interpret \
configure_prefixes

quiet='' message --info "Flux has been started."

# Set initial events count
events_count='0'

# Read events from 'flux-listener' binary
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
      # Unset CPU/FPS limits for processes of terminated windows and remove info about those from cache and execute commands
      handle_closure

      # Apply CPU/FPS limits for processes which have been requested to be limited and execute commands
      handle_unfocus
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
          # Unset CPU/FPS limit for process of focused window if it has been limited on unfocus and execute commands
          handle_focus
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
done < "$flux_listener_fifo"

# Only for case if event reader appears terminated
message --warning "Event reader has been terminated!"
safe_exit
message --error "Flux has been terminated unexpectedly!"
exit 1
