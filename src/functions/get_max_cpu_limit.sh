# Required to get maximum allowed CPU limit by multiplying threads count to 100
get_max_cpu_limit(){
  # Count CPU threads
  local local_temp_cpuinfo_line
  cpu_threads='0'
  while read -r local_temp_cpuinfo_line ||
        [[ -n "$local_temp_cpuinfo_line" ]]; do
    if [[ "$local_temp_cpuinfo_line" == 'processor'* ]]; then
      (( cpu_threads++ ))
    fi
  done < '/proc/cpuinfo'

  # Get maximum CPU limit for all cores
  max_cpu_limit="$(( cpu_threads * 100 ))"
}
