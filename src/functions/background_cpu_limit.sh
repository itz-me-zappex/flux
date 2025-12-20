# Required to set CPU limit using 'cpulimit' tool on unfocus event, runs in background via '&'
background_cpu_limit(){
  local local_limits_delay="${config_key_limits_delay_map["$passed_section"]}"
  local local_cpu_limit="${config_key_unfocus_cpu_limit_map["$passed_section"]}"
  local local_real_cpu_limit="$(( local_cpu_limit * cpu_threads ))"

  if [[ "$local_limits_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' ($passed_pid) will be CPU limited after $local_limits_delay second(s) on window ($passed_window_xid) unfocus event."

    sleep "$local_limits_delay" &
    local local_sleep_pid="$!"

    trap 'message --info "Delayed for $local_limits_delay second(s) CPU limiting of process '"'$passed_process_name'"' ($passed_pid) of window ($passed_window_xid) has been cancelled because of daemon termination." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGINT SIGTERM

    trap 'message --info "Delayed for $local_limits_delay second(s) CPU limiting of process '"'$passed_process_name'"' ($passed_pid) has been cancelled on window ($passed_window_xid) focus event." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR1

    trap 'message --info "Delayed for $local_limits_delay second(s) CPU limiting of process '"'$passed_process_name'"' ($passed_pid) has been cancelled on window ($passed_window_xid) closure event." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR2

    wait "$local_sleep_pid"
  fi

  if check_pid_existence "$passed_pid"; then
    if [[ "$local_limits_delay" == '0' ]]; then
      message --info "Process '$passed_process_name' ($passed_pid) has been CPU limited to $local_cpu_limit% on window ($passed_window_xid) unfocus event."
    else
      message --info "Process '$passed_process_name' ($passed_pid) has been CPU limited to $local_cpu_limit% after $local_limits_delay second(s) on window ($passed_window_xid) unfocus event."
    fi

    cpulimit --lazy --limit="$local_real_cpu_limit" --pid="$passed_pid" > /dev/null 2>&1 &
    local local_cpulimit_pid="$!"

    # Enforce 'SCHED_FIFO' to improve interval stability between interrupts
    if [[ -n "$sched_realtime_is_supported" ]]; then
      if ! chrt --fifo --pid 99 "$local_cpulimit_pid" > /dev/null 2>&1; then
        message --warning "Unable to change scheduling policy to 'FIFO' for 'cpulimit' ($local_cpulimit_pid) hooked to process '$passed_process_name' ($passed_pid) of window ($passed_window_xid)!"
      else
        message --info "Scheduling policy of 'cpulimit' ($local_cpulimit_pid) hooked to process '$passed_process_name' ($passed_pid) of window ($passed_window_xid) has been changed to 'FIFO'."
      fi
    fi

    trap 'message --info "Process '"'$passed_process_name'"' ($passed_pid) of window ($passed_window_xid) has been CPU unlimited because of daemon termination." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGINT SIGTERM

    trap 'message --info "Process '"'$passed_process_name'"' ($passed_pid) has been CPU unlimited on window ($passed_window_xid) focus event." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR1

    trap 'message --info "Process '"'$passed_process_name'"' ($passed_pid) has been CPU unlimited on window ($passed_window_xid) closure event." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR2

    wait "$local_cpulimit_pid"

    # To receive "SIGUSR2" signal after process termination
    sleep 0.15
  else
    message --warning "Process '$passed_process_name' ($passed_pid) of window ($passed_window_xid) has been terminated before applying CPU limit!"
  fi
}
