# Required to change FPS limit in specified MangoHud config
mangohud_fps_set(){
	local local_temp_config_line \
	local_new_config_content \
	local_target_config="$1" \
	local_source_config="$2" \
	local_fps_to_set="$3" \
	local_fps_limit_is_changed
	# Check if config file exists before continue in case it has been removed
	if [[ -f "$local_target_config" ]]; then
		# Check for readability of source config only if it differs from target config
		if [[ "$local_target_config" != "$local_source_config" ]]; then
			# Check readability of source MangoHud config file
			if ! check_ro "$local_source_config"; then
				message --warning "Source MangoHud config file '$local_target_config' is not readable!"
				return 1
			fi
		fi
		# Check read-write ability of target MangoHud config file
		if ! check_rw "$local_target_config"; then
			message --warning "Target MangoHud config file '$local_target_config' is not rewritable!"
			return 1
		else
			# Replace 'fps_limit' value in config if exists
			while read -r local_temp_config_line; do
				# Find 'fps_limit' line, regexp means 'fps_limit[space(s)?]=[space(s)?][integer][anything else]'
				if [[ "$local_temp_config_line" =~ ^fps_limit([[:space:]]+)?=([[:space:]]+)?[0-9]+* ]]; then
					# Set specified FPS limit, shell parameter expansion replaces first number on line with specified new one
					local_new_config_content+="${local_temp_config_line/[0-9]*/"$local_fps_to_set"}\n"
					# Set mark which signals about successful setting of FPS limit
					local_fps_limit_is_changed='1'
				else
					# Add line to processed text
					local_new_config_content+="$local_temp_config_line\n"
				fi
			done < "$local_source_config"
			# Check whether FPS limit has been set or not
			if [[ -z "$local_fps_limit_is_changed" ]]; then
				# Pass config content with 'fps_limit' key if line does not exist in config
				if [[ -n "$local_new_config_content" ]]; then
					echo -e "${local_new_config_content/%'\n'/}\nfps_limit = $local_fps_to_set" > "$local_target_config"
				else
					echo "fps_limit = $local_fps_to_set" > "$local_target_config"
				fi
			else
				# Pass config content if FPS has been already changed
				echo -e "${local_new_config_content/%'\n'/}" > "$local_target_config"
			fi
		fi
	else
		message --warning "Target MangoHud config file '$local_target_config' does not exist!"
		return 1
	fi
}