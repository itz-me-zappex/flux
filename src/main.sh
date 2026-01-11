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

daemon_version='1.34'

if [[ -z "$DISPLAY" ]]; then
  export DISPLAY=':0'
fi

# Set path to temporary directory and files
flux_temp_dir_path='/tmp/flux'
flux_lock_file_path="${flux_temp_dir_path}/flux.lock"
flux_temp_fifo_dir_path="${flux_temp_dir_path}/fifo"
flux_listener_fifo_path="${flux_temp_fifo_dir_path}/flux-listener"
flux_grab_cursor_fifo_path="${flux_temp_fifo_dir_path}/flux-grab-cursor"

# Define prefix where daemon has been installed using path to 'flux'
local_get_realpath_result=''
get_realpath "$0"
flux_path="$local_get_realpath_result"
unset local_get_realpath_result
case "$flux_path" in
*'/bin/flux'* )
  # Keep only prefix path
  daemon_prefix="${flux_path/%'/bin/flux'/}"

  flux_listener_path="${daemon_prefix}/lib/flux/flux-listener"
  window_minimize_path="${daemon_prefix}/lib/flux/window-minimize"
  window_fullscreen_path="${daemon_prefix}/lib/flux/window-fullscreen"
  select_window_path="${daemon_prefix}/lib/flux/select-window"
  flux_grab_cursor_path="${daemon_prefix}/lib/flux/flux-grab-cursor"
  validate_x11_session_path="${daemon_prefix}/lib/flux/validate-x11-session"
;;
* )
  # Keep only executable directory
  daemon_prefix="${flux_path/%'/flux'/}"

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
  # In case color mode will not be specified using '--color' config key, needed to handle both custom prefixes and timestamp
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

# 'get_process_info()' should print errors in '--get' and warnings at runtime
# changed in 'parse_options()'
get_process_info_msg_type='--warning'

# Needed to store values from config
declare -A config_key_name_map \
config_key_owner_map \
config_key_unfocus_cpu_limit_map \
config_key_unfocus_limits_delay_map \
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
config_key_unfocus_sched_idle_map \
config_key_unfocus_minimize_map \
config_key_focus_fullscreen_map \
config_key_focus_grab_cursor_map \
config_key_group_map \
config_key_exec_exit_map \
config_key_exec_exit_focus_map \
config_key_exec_exit_unfocus_map \
config_key_unfocus_mute_map

# Needed to remember line and order of keys in section, used to handle 'group' config key and print line in warnings after parsing (validation)
declare -A config_keys_order_map

# Needed to detect blank sections in config during parsing
declare -A is_section_blank_map

# Needed to remember whether regexp should be used to find matching identifiers or not
declare -A config_key_regexp_name_map \
config_key_regexp_command_map \
config_key_regexp_owner_map

# Needed to define whether commands to 'exec-closure'/'exec-exit' should be appended to inherited from 'lazy-exec-unfocus' or not
# Unneeded if first declaration has '=' instead of '+='
declare -A config_key_exec_closure_append_to_default_map \
config_key_exec_exit_append_to_default_map

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
request_exec_unfocus_general_map \
request_mute_map

# Declare associative arrays to store info about windows to avoid obtaining it every time to speed up code and reduce CPU-usage
declare -A cache_pid_map \
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

parse_options "$@"
shift "${#@}"
unset -f parse_options \
option_repeat_check \
cmdline_get

validate_options
unset -f validate_options

validate_config
unset -f validate_config

validate_log
unset -f validate_log

get_max_cpu_limit
unset -f get_max_cpu_limit

parse_config
unset -f parse_config \
get_realpath \
simplify_bool
unset max_cpu_limit

handle_groups
unset -f config_get_group_values
unset config_key_group_map

validate_config_keys
unset -f validate_config_keys
unset is_section_useful_map \
is_section_blank_map \
config \
get_key_line \
config_keys_order_map \
config_key_exec_closure_append_to_default_map \
config_key_exec_exit_append_to_default_map \
config_line_count

unset_groups
unset -f unset_groups \
section_is_group

validate_x11_session
unset -f validate_x11_session

create_temp_dirs
unset -f create_temp_dirs

create_fifo_files
unset -f create_fifo_files

validate_lock
unset -f validate_lock

configure_prefixes
unset color_prefix_error \
color_prefix_info \
color_prefix_verbose \
color_prefix_warning \
color_timestamp_format \
colorless_prefix_error \
colorless_prefix_info \
colorless_prefix_verbose \
colorless_prefix_warning \
colorless_timestamp_format
unset -f configure_prefixes \
colors_interpret

daemon_prepare
unset -f daemon_prepare

validate_sched
unset -f validate_sched

# Read events from 'flux-listener' binary
"$flux_listener_path" > "$flux_listener_fifo_path" &
flux_listener_pid="$!"
quiet='' message --info "Flux started."
while read -r raw_event ||
      [[ -n "$raw_event" ]]; do
  (( events_count++ ))
  if (( events_count == 1 )); then
    focused_window="$raw_event"
    continue
  else
    opened_windows="$raw_event"
  fi
  events_count='0'

  if [[ -n "$hot" ]]; then
    # Handle implicitly opened windows at start if '--hot' is specified
    for temp_opened_window in $opened_windows; do
      if [[ "$temp_opened_window" != "$focused_window" ]]; then
        handle_window_event "$temp_opened_window"
      fi
    done
    unset temp_opened_window

    unset hot
  else
    if [[ -n "$previous_opened_windows" ]]; then
      # Attempt to find implicitly opened windows
      for temp_opened_window in $opened_windows; do
        # Handle if opened implicitly
        if [[ " $previous_opened_windows " != *" $temp_opened_window "* &&
              "$temp_opened_window" != "$focused_window" ]]; then
          if [[ -n "$allow_lazy_commands" ]]; then
            # Set '--hot' internally, to avoid execution of lazy commands
            hot='1'
            unset allow_lazy_commands

            # Remember focused window info to set it as previous after handling implicitly opened windows
            # Needed to make daemon able to handle requests after first unfocus event (after handling implicitly opened windows)
            explicit_window_xid="$window_xid"
            explicit_pid="$pid"
            explicit_process_name="$process_name"
            explicit_process_owner="$process_owner"
            explicit_process_command="$process_command"
            explicit_section="$section"
          fi

          handle_window_event "$temp_opened_window"
        fi
      done
      unset temp_opened_window

      if [[ -z "$allow_lazy_commands" ]]; then
        # Unset '--hot' to allow lazy commands execution after handling implicitly opened windows
        unset hot

        # Restore info about focused window after handling implicitly opened windows
        previous_window_xid="$explicit_window_xid"
        previous_pid="$explicit_pid"
        previous_process_name="$explicit_process_name"
        previous_process_owner="$explicit_process_owner"
        previous_process_command="$explicit_process_command"
        previous_section="$explicit_section"

        unset explicit_window_xid \
        explicit_pid \
        explicit_process_name \
        explicit_process_owner \
        explicit_process_command \
        explicit_section
      fi

      # Prevent focused window from being handled as unfocused
      disallow_request="$focused_window"
    fi
  fi

  if [[ "$previous_focused_window" != "$focused_window" ]]; then
    # Handle focused window if it does not repeat
    handle_window_event "$focused_window"

    # Remember focused window to skip handling it again if repeats
    previous_focused_window="$focused_window"
  fi

  handle_closure
  handle_unfocus

  # Needed to find implicitly opened windows next time
  previous_opened_windows="$opened_windows"

  if [[ -z "$hot" ]]; then
    allow_lazy_commands='1'
  fi

  if [[ -n "$disallow_request" ]]; then
    unset disallow_request
  fi
done < "$flux_listener_fifo_path"

# Only for case if event reader becomes terminated
message --warning "Event reader terminated!"
safe_exit
message --error "Flux terminated unexpectedly!"
exit 1
