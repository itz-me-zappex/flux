# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
  # Attempt to terminate CPU limit background process
  kill "$passed_signal" "${background_cpu_limit_pid_map["$passed_process_pid"]}" > /dev/null 2>&1
  
  # Unset details about CPU limiting
  unset is_cpu_limit_applied_map["$passed_process_pid"] \
  background_cpu_limit_pid_map["$passed_process_pid"]
}
