# To terminate CPU limit background process on focus or closure
unset_cpu_limit(){
  kill "$passed_signal" "${background_cpu_limit_pid_map["$passed_pid"]}" > /dev/null 2>&1
  unset background_cpu_limit_pid_map["$passed_pid"]
}
