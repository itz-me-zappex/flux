# Required to get maximum allowed CPU limit by multiplying threads count to 100
get_max_cpu_limit(){
  # Instead of 'nproc' tool
  local local_temp_cpuinfo_line
  cpu_threads='0'
  while read -r local_temp_cpuinfo_line ||
        [[ -n "$local_temp_cpuinfo_line" ]]; do
    if [[ "$local_temp_cpuinfo_line" == 'processor'* ]]; then
      (( cpu_threads++ ))
    fi
  done < '/proc/cpuinfo'

  max_cpu_limit="$(( cpu_threads * 100 ))"
}
