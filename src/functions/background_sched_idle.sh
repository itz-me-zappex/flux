# Required to change scheduling policy of process to 'SCHED_IDLE' on unfocus event, runs in background via '&'
background_sched_idle(){
  local local_delay="${config_key_delay_map["$passed_section"]}"

  if [[ "$local_delay" != '0' ]]; then
    message --verbose "Scheduling policy of process '$passed_process_name' with PID $passed_pid will be changed to 'idle' after $local_delay second(s) because of unfocus event of window with XID $passed_window_xid."
    sleep "$local_delay"
  fi
  
  if check_pid_existence "$passed_pid"; then
    if ! chrt --idle --pid 0 "$passed_pid"; then
      message --warning "Scheduling policy of process '$passed_process_name' with PID $passed_pid cannot be changed to 'idle' because of unfocus event of window with XID $passed_window_xid!"
    else
      if [[ "$local_delay" == '0' ]]; then
        message --info "Scheduling policy of process '$passed_process_name' with PID $passed_pid has been changed to 'idle' because of unfocus event of window with XID $passed_window_xid."
      else
        message --info "Scheduling policy of process '$passed_process_name' with PID $passed_pid has been changed to 'idle' after $local_delay second(s) because of unfocus event of window with XID $passed_window_xid."
      fi
    fi
  else
    message --warning "Process '$passed_process_name' with PID $passed_pid of window with XID $passed_window_xid has been terminated before changing scheduling policy to 'idle'!"
  fi
}
