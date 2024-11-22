# Required to calculate maximum CPU limit
calculate_max_limit(){
	local local_temp_cpuinfo_line
	# Calculate maximum allowable CPU limit and CPU threads
	cpu_threads='0'
	while read -r local_temp_cpuinfo_line; do
		if [[ "$local_temp_cpuinfo_line" == 'processor'* ]]; then
			(( cpu_threads++ ))
		fi
	done < '/proc/cpuinfo'
	max_cpu_limit="$(( cpu_threads * 100 ))"
}