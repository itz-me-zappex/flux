# Required to set CPU limit using 'cpulimit' tool on unfocus event, runs in background via '&'
background_cpu_limit(){
  local local_delay="${config_key_delay_map["$passed_section"]}"
  local local_cpu_limit="${config_key_cpu_limit_map["$passed_section"]}"
  local local_real_cpu_limit="$(( local_cpu_limit * cpu_threads ))"

  if [[ "$local_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be CPU limited after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid."

    sleep "$local_delay" &
    local local_sleep_pid="$!"

    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid of window with XID $passed_window_xid has been cancelled due to daemon termination." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGINT SIGTERM

    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to focus event of window with XID $passed_window_xid." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR1

    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to closure of window with XID $passed_window_xid." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR2

    wait "$local_sleep_pid"
  fi

  if check_pid_existence "$passed_process_pid"; then
    if [[ "$local_delay" == '0' ]]; then
      message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to $local_cpu_limit% due to unfocus event of window with XID $passed_window_xid."
    else
      message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to $local_cpu_limit% after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid."
    fi

    cpulimit --lazy --limit="$local_real_cpu_limit" --pid="$passed_process_pid" > /dev/null 2>&1 &
    local local_cpulimit_pid="$!"

    # Enforce 'SCHED_BATCH' to improve interval stability between interrupts
    if check_pid_existence "$local_cpulimit_pid" &&
       ! chrt --batch --pid 0 "$local_cpulimit_pid" > /dev/null 2>&1; then
      message --warning "Daemon has insufficient rights to change scheduling policy to 'batch' for 'cpulimit' which is hooked to process '$passed_process_name' with PID $passed_process_pid of window with XID $passed_window_xid!"
    fi

    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid of window with XID $passed_window_xid has been CPU unlimited due to daemon termination." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGINT SIGTERM

    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to focus event of window with XID $passed_window_xid." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR1

    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to closure of window with XID $passed_window_xid." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR2

    wait "$local_cpulimit_pid"
  else
    message --warning "Process '$passed_process_name' with PID $passed_process_pid of window with XID $passed_window_xid has been terminated before applying CPU limit!"
  fi
}
