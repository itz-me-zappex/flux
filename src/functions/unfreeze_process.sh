# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
  local local_background_freeze_pid="${background_freeze_pid_map["$passed_pid"]}"
  local local_limits_delay="${config_key_limits_delay_map["$passed_section"]}"

  if [[ "$local_limits_delay" != '0' ]] &&
     check_pid_existence "$local_background_freeze_pid"; then
    if ! kill "$local_background_freeze_pid" > /dev/null 2>&1; then
      message --warning "Unable to cancel delayed for $local_limits_delay second(s) freezing of process '$passed_process_name' ($passed_pid) $passed_end_of_msg!"
    else
      message --info "Delayed for $local_limits_delay second(s) freezing of process $passed_process_name' ($passed_pid) has been cancelled $passed_end_of_msg."
    fi
  else
    if ! kill -CONT "$passed_pid" > /dev/null 2>&1; then
      message --warning "Unable to unfreeze process '$passed_process_name' ($passed_pid) $passed_end_of_msg!"
    else
      message --info "Process '$passed_process_name' ($passed_pid) has been unfrozen $passed_end_of_msg."
    fi
  fi

  unset background_freeze_pid_map["$passed_pid"]
}
