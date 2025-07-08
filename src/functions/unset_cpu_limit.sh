# Required to terminate CPU limit background process if window becomes focused or terminated
unset_cpu_limit(){
  kill "$passed_signal" "${background_cpu_limit_pid_map["$passed_pid"]}" > /dev/null 2>&1
  unset background_cpu_limit_pid_map["$passed_pid"]
}
