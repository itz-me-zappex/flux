# Required to freeze process on unfocus event, runs in background via '&'
background_freeze(){
  # Simplify access to delay specified in config
  local local_delay="${config_key_delay_map["$passed_section"]}"

  # Wait before set limit and notify user if delay is specified
  if [[ "$local_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be frozen after $local_delay second(s) due to window with XID $passed_window_xid unfocus event."
    sleep "$local_delay"
  fi
  
  # Check for process existence before freezing
  if check_pid_existence "$passed_process_pid"; then
    # Attempt to send 'SIGSTOP' signal to freeze process completely
    if ! kill -STOP "$passed_process_pid" > /dev/null 2>&1; then
      message --warning "Process '$passed_process_name' with PID $passed_process_pid cannot be frozen due to window with XID $passed_window_xid unfocus event!"
    else
      # Define message depending by whether delay is specified or not
      if [[ "$local_delay" == '0' ]]; then
        message --info "Process '$passed_process_name' with PID $passed_process_pid has been frozen due to window with XID $passed_window_xid unfocus event."
      else
        message --info "Process '$passed_process_name' with PID $passed_process_pid has been frozen after $local_delay second(s) due to window with XID $passed_window_xid unfocus event."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' with PID $passed_process_pid has been terminated before freezing!"
  fi
}
