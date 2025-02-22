# Required to terminate freeze background process or unfreeze process if window becomes focused or terminated
unfreeze_process(){
  # Simplify access to PID of freeze background process
  local local_background_freeze_pid="${background_freeze_pid_map["$passed_process_pid"]}"

  # Check for existence of freeze background process
  if [[ "$local_config_delay" != '0' ]] &&
     check_pid_existence "$local_background_freeze_pid"; then
    # Simplify access to delay config key value
    local_config_delay="${config_key_delay_map["$passed_section"]}"

    # Attempt to terminate background process
    if ! kill "$local_background_freeze_pid" > /dev/null 2>&1; then
      message --warning "Unable to cancel delayed for $local_config_delay second(s) freezing of process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
    else
      message --info "Delayed for $local_config_delay second(s) freezing of process $passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
    fi
  else
    # Attempt to unfreeze target process
    if ! kill -CONT "$passed_process_pid" > /dev/null 2>&1; then
      message --warning "Unable to unfreeze process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
    else
      message --info "Process '$passed_process_name' with PID $passed_process_pid has been unfrozen $passed_end_of_msg."
    fi
  fi
  
  # Unset details about freezing
  unset is_freeze_applied_map["$passed_process_pid"] \
  background_freeze_pid_map["$passed_process_pid"]
}
