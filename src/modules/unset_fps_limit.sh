# Required to terminate FPS limit background process or unset FPS limit if window becomes focused or terminated
unset_fps_limit(){
	local local_temp_fps_limited_pid \
	local_temp_fps_limited_section \
	local_fps_limited_sections_array \
	local_fps_limit_bgprocess_pid
	# Simplify access to PID of background process with delayed setting of FPS limit
	local_fps_limit_bgprocess_pid="${fps_limit_bgprocess_pid_map["$passed_section"]}"
	# Check for existence of FPS limit background process
	if check_pid_existence "$local_fps_limit_bgprocess_pid"; then
		# Attempt to terminate background process
		kill "$local_fps_limit_bgprocess_pid" > /dev/null 2>&1
		# Print message if delay is not zero
		if [[ "${config_key_delay_map["$passed_section"]}" != '0' ]]; then
			# Define message depending by 'kill' exit code
			if (( $? > 0 )); then
				message --warning "Unable to cancel delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS unlimiting of section '$passed_section'!"
			else
				message --info "Delayed for ${config_key_delay_map["$passed_section"]} second(s) FPS unlimiting of section '$passed_section' has been cancelled $passed_end_of_msg."
			fi
		fi
	fi
	# Set FPS from 'fps-focus' key
	if mangohud_fps_set "${config_key_mangohud_config_map["$passed_section"]}" "${config_key_mangohud_source_config_map["$passed_section"]}" "${config_key_fps_focus_map["$passed_section"]}"; then
		# Print message depending by FPS limit
		if [[ "${config_key_fps_focus_map["$passed_section"]}" == '0' ]]; then
			message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been FPS unlimited $passed_end_of_msg."
		elif [[ "${config_key_fps_focus_map["$passed_section"]}" =~ ^[0-9]+$ ]]; then
			message --info "MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been limited to ${config_key_fps_focus_map["$passed_section"]} FPS $passed_end_of_msg."
		else
			message --info "Config key 'fps_limit' in MangoHud config file '${config_key_mangohud_config_map["$passed_section"]}' from section '$passed_section' has been changed to '${config_key_fps_focus_map["$passed_section"]}' $passed_end_of_msg."
		fi
	fi
	# Remove section from array
	for local_temp_fps_limited_section in "${fps_limited_sections_array[@]}"; do
		# Skip FPS unlimited section as I want remove it from array
		if [[ "$local_temp_fps_limited_section" != "$passed_section" ]]; then
			local_fps_limited_sections_array+=("$local_temp_fps_limited_section")
		fi
	done
	# Store updated info into array
	fps_limited_sections_array=("${local_fps_limited_sections_array[@]}")
	# Unset details about FPS limiting
	unset is_fps_limited_section_map["$passed_section"] \
	fps_limit_bgprocess_pid_map["$passed_section"]
}