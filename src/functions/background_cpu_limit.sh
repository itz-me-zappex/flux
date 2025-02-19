# Required to set CPU limit using 'cpulimit' tool on unfocus event, runs in background via '&'
background_cpu_limit(){
  # Simplify access to delay specified in config
  local local_delay="${config_key_delay_map["$passed_section"]}"

  # Wait before set limit and notify user if delay is specified
  if [[ "$local_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be CPU limited after $local_delay second(s) due to window $passed_window_id unfocus event."

    # Run in background to make this subprocess interruptable
    sleep "$local_delay" &

    # Remember PID of 'sleep' to terminate it on SIGINT/SIGTERM
    local local_sleep_pid="$!"

    # Print relevant message on daemon termination and stop this subprocess
    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to daemon termination." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGINT SIGTERM

    # Print relevant message on focus event and stop this subprocess
    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window $passed_window_id focus event." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR1

    # Print relevant message on closure of target window and stop this subprocess
    trap 'message --info "Delayed for $local_delay second(s) CPU limiting of process '"'$passed_process_name'"' with PID $passed_process_pid has been cancelled due to window $passed_window_id closure." ; \
    kill "$local_sleep_pid"; \
    exit 0' SIGUSR2

    wait "$local_sleep_pid"
  fi

  # Check for process existence before set CPU limit
  if check_pid_existence "$passed_process_pid"; then
    # Define message depending by whether delay is specified or not
    if [[ "$local_delay" == '0' ]]; then
      message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to ${config_key_cpu_limit_map["$passed_section"]}% due to window $passed_window_id unfocus event."
    else
      message --info "Process '$passed_process_name' with PID $passed_process_pid has been CPU limited to ${config_key_cpu_limit_map["$passed_section"]}% due to window $passed_window_id unfocus event after $local_delay second(s)."
    fi

    # Run in background to make subprocess interruptable
    cpulimit --lazy --limit="$(( "${config_key_cpu_limit_map["$passed_section"]}" * cpu_threads ))" --pid="$passed_process_pid" > /dev/null 2>&1 &

    # Remember PID of 'cpulimit' to terminate it if needed
    local local_cpulimit_pid="$!"

    # Enforce 'SCHED_BATCH' to improve interval stability between interrupts
    if check_pid_existence "$local_cpulimit_pid" &&
       ! chrt --batch --pid 0 "$local_cpulimit_pid" > /dev/null 2>&1; then
      message --warning "Daemon has insufficient rights to change scheduling policy to 'batch' for 'cpulimit'!"
    fi

    # Terminate 'cpulimit' process and print relevant message on daemon termination
    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to daemon termination." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGINT SIGTERM

    # Terminate 'cpulimit' process on focus event and print relevant message
    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window $passed_window_id focus event." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR1

    # Terminate 'cpulimit' on closure of target window and print relevant message
    trap 'message --info "Process '"'$passed_process_name'"' with PID $passed_process_pid has been CPU unlimited due to window $passed_window_id closure." ; \
    kill "$local_cpulimit_pid" > /dev/null 2>&1 ; \
    exit 0' SIGUSR2

    wait "$local_cpulimit_pid"
  else
    message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before applying CPU limit!"
  fi
}
