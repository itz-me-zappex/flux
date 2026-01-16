# To terminate background process with delayed setting of 'SCHED_IDLE'
# or restore scheduling policy for process on focus or closure
unset_sched_idle(){
  local local_background_sched_idle_pid="${background_sched_idle_pid_map["$passed_pid"]}"
  local local_unfocus_limits_delay="${config_key_unfocus_limits_delay_map["$passed_section"]}"

  # Check for existence of background process with delayed
  # setting of 'SCHED_IDLE'
  if [[ "$local_unfocus_limits_delay" != '0' ]] &&
     check_pid_existence "$local_background_sched_idle_pid"; then
    if ! kill "$local_background_sched_idle_pid" > /dev/null 2>&1; then
      message --warning "Unable to cancel delayed for $local_unfocus_limits_delay second(s) delayed setting of 'idle' scheduling policy for process '$passed_process_name' ($passed_pid) $passed_end_of_msg!"
    else
      message --info "Delayed for $local_unfocus_limits_delay second(s) setting of 'idle' scheduling policy for process $passed_process_name' ($passed_pid) cancelled $passed_end_of_msg."
    fi
  else
    # Define option and scheduling policy name depending on
    # scheduling policy
    case "${sched_previous_policy_map["$passed_pid"]}" in
    'SCHED_FIFO' )
      local local_policy_option='--fifo'
      local local_policy_name="'FIFO'"
    ;;
    'SCHED_RR' )
      local local_policy_option='--rr'
      local local_policy_name="'RR'"
    ;;
    'SCHED_OTHER' )
      local local_policy_option='--other'
      local local_policy_name="'other'"
    ;;
    'SCHED_BATCH' )
      local local_policy_option='--batch'
      local local_policy_name="'batch'"
    ;;
    'SCHED_DEADLINE' )
      # Setting '$local_policy_option' useless because command
      # for deadline differs greatly
      local local_policy_name="'deadline'"
    esac

    # Define how to restore scheduling policy depending on
    # whether that is deadline or not
    if [[ "${sched_previous_policy_map["$passed_pid"]}" == 'SCHED_DEADLINE' ]]; then
      # Restore deadline scheduling policy and its parameters for process
      chrt --deadline \
      --sched-runtime "${sched_previous_runtime_map["$passed_pid"]}" \
      --sched-deadline "${sched_previous_deadline_map["$passed_pid"]}" \
      --sched-period "${sched_previous_period_map["$passed_pid"]}" \
      --pid 0 "$passed_pid" > /dev/null 2>&1
    else
      chrt "$local_policy_option" --pid "${sched_previous_priority_map["$passed_pid"]}" "$passed_pid" > /dev/null 2>&1
    fi

    # Print message depending on 'chrt' exit code
    if (( $? > 0 )); then
      message --warning "Unable to restore $local_policy_name scheduling policy for process '$passed_process_name' ($passed_pid) $passed_end_of_msg!"
    else
      message --info "Scheduling policy $local_policy_name restored for process '$passed_process_name' ($passed_pid) $passed_end_of_msg."
    fi
    
    # Unset details about previous and applied 'idle' cheduling policies
    unset sched_previous_policy_map["$passed_pid"] \
    sched_previous_priority_map["$passed_pid"] \
    sched_previous_runtime_map["$passed_pid"] \
    sched_previous_deadline_map["$passed_pid"] \
    sched_previous_period_map["$passed_pid"] \
    background_sched_idle_pid_map["$passed_pid"]
  fi
}
