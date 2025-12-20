# Required to get info about current scheduling policy and figure out with either it is possible to restore scheduling policy or not
# If possible, then it runs 'background_sched_idle()'
set_sched_idle(){
  # Remember scheduling policy and priority before change it
  local local_sched_info
  if ! local_sched_info="$(chrt --pid "$local_pid" 2>/dev/null)"; then
    local local_chrt_error='1'
  fi

  # Skip handling 'chrt' output if it returned an error
  if [[ -z "$local_chrt_error" ]]; then
    # Read output of 'chrt' tool line-by-line and remember scheduling policy with priority of process to restore it on daemon exit or window focus event
    local local_temp_sched_info_line
    while read -r local_temp_sched_info_line ||
          [[ -n "$local_temp_sched_info_line" ]]; do
      # Define associative array which should store value depending by what line contains
      case "$local_temp_sched_info_line" in
      *'scheduling policy'* )
        # Extract scheduling policy name from string and remember it
        sched_previous_policy_map["$local_pid"]="${local_temp_sched_info_line/*': '/}"
      ;;
      *'scheduling priority'* )
        # Extract scheduling priority value from string and remember it
        sched_previous_priority_map["$local_pid"]="${local_temp_sched_info_line/*': '/}"
      ;;
      *'runtime/deadline/period parameters'* )
        # Extract parameters from string
        local local_deadline_parameters="${local_temp_sched_info_line/*': '/}"
        # Remove slashes and remember 'SCHED_DEADLINE' parameters
        local local_count='0'
        local local_temp_deadline_parameter
        for local_temp_deadline_parameter in ${local_deadline_parameters//'/'/' '}; do
          (( local_count++ ))
          case "$local_count" in
          '1' )
            sched_previous_runtime_map["$local_pid"]="$local_temp_deadline_parameter"
          ;;
          '2' )
            sched_previous_deadline_map["$local_pid"]="$local_temp_deadline_parameter"
          ;;
          '3' )
            sched_previous_period_map["$local_pid"]="$local_temp_deadline_parameter"
          esac
        done
      esac
    done <<< "$local_sched_info"

    # Print warning if daemon unable to change scheduling policy, otherwise - change it to 'SCHED_IDLE' if not set already
    if [[ -z "$sched_realtime_is_supported" &&
          "${sched_previous_policy_map["$local_pid"]}" =~ ^('SCHED_RR'|'SCHED_FIFO')$ ]]; then
      message --warning "Daemon has insufficient rights to restore realtime scheduling policy for process '$local_process_name' ($local_pid), changing it to 'idle' on window ($local_temp_window_xid) unfocus event cancelled!"
      local local_idle_cancelled='1'
    elif (( UID != 0 )) &&
         [[ "${sched_previous_policy_map["$local_pid"]}" == 'SCHED_DEADLINE' ]]; then
      message --warning "Daemon has insufficient rights to restore deadline scheduling policy for process '$local_process_name' ($local_pid), changing it to 'idle' on window ($local_temp_window_xid) unfocus event cancelled!"
      local local_idle_cancelled='1'
    elif [[ "${sched_previous_policy_map["$local_pid"]}" != 'SCHED_IDLE' ]]; then
      # Change scheduling policy to 'SCHED_IDLE' if not already set
      passed_section="$local_section" \
      passed_process_name="$local_process_name" \
      passed_pid="$local_pid" \
      passed_window_xid="$local_temp_window_xid" \
      background_sched_idle &
      background_sched_idle_pid_map["$local_pid"]="$!"
    else
      message --warning "Process '$local_process_name' ($local_pid) already has scheduling policy set to 'idle', changing it on window ($local_temp_window_xid) unfocus event cancelled!"
      local local_idle_cancelled='1'
    fi

    # Unset info about scheduling policy if changing it to 'idle' is cancelled
    if [[ -n "$local_idle_cancelled" ]]; then
      unset sched_previous_policy_map["$local_pid"] \
      sched_previous_priority_map["$local_pid"] \
      sched_previous_runtime_map["$local_pid"] \
      sched_previous_deadline_map["$local_pid"] \
      sched_previous_period_map["$local_pid"]
    fi
  else
    message --warning "Unable to obtain scheduling policy info of process '$local_process_name' ($local_pid), changing it to 'idle' on window ($local_temp_window_xid) unfocus event cancelled!"
  fi
}
