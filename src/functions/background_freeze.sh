# Required to freeze process on unfocus event, runs in background via '&'
background_freeze(){
  local local_delay="${config_key_delay_map["$passed_section"]}"

  if [[ "$local_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' with PID $passed_process_pid will be frozen after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid."
    sleep "$local_delay"
  fi
  
  if check_pid_existence "$passed_process_pid"; then
    if ! kill -STOP "$passed_process_pid" > /dev/null 2>&1; then
      message --warning "Process '$passed_process_name' with PID $passed_process_pid cannot be frozen due to unfocus event of window with XID $passed_window_xid!"
    else
      if [[ "$local_delay" == '0' ]]; then
        message --info "Process '$passed_process_name' with PID $passed_process_pid has been frozen due to unfocus event of window with XID $passed_window_xid."
      else
        message --info "Process '$passed_process_name' with PID $passed_process_pid has been frozen after $local_delay second(s) due to unfocus event of window with XID $passed_window_xid."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' with PID $passed_process_pid of window with XID $passed_window_xid has been terminated before freezing!"
  fi
}
