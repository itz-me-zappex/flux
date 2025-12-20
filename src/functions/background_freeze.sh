# Required to freeze process on unfocus event, runs in background via '&'
background_freeze(){
  local local_limits_delay="${config_key_limits_delay_map["$passed_section"]}"

  if [[ "$local_limits_delay" != '0' ]]; then
    message --verbose "Process '$passed_process_name' ($passed_pid) will be frozen after $local_limits_delay second(s) on window $passed_window_xid unfocus event."
    sleep "$local_limits_delay"
  fi
  
  if check_pid_existence "$passed_pid"; then
    if ! kill -STOP "$passed_pid" > /dev/null 2>&1; then
      message --warning "Process '$passed_process_name' ($passed_pid) cannot be frozen on window $passed_window_xid unfocus event!"
    else
      if [[ "$local_limits_delay" == '0' ]]; then
        message --info "Process '$passed_process_name' ($passed_pid) has been frozen on window $passed_window_xid unfocus event."
      else
        message --info "Process '$passed_process_name' ($passed_pid) has been frozen after $local_limits_delay second(s) on window $passed_window_xid unfocus event."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' ($passed_pid) of window $passed_window_xid has been terminated before freezing!"
  fi
}
