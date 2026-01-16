# To change FPS limit in specified MangoHud config
mangohud_fps_set(){
  local local_target_config="$1"
  local local_source_config="$2"
  local local_fps_to_set="$3"

  # Check whether config file exists or not before continue
  if [[ -f "$local_target_config" ]]; then
    # Check for source config readability
    if [[ "$local_target_config" != "$local_source_config" ]]; then
      if ! check_ro "$local_source_config"; then
        local local_shorten_path_result
        shorten_path "$local_source_config"
        message --warning "Source MangoHud config file ($local_shorten_path_result) ($passed_section) is not readable!"
        return 1
      fi
    fi

    # Check read-write access of target MangoHud config file
    if ! check_rw "$local_target_config"; then
      local local_shorten_path_result
      shorten_path "$local_target_config"
      message --warning "Target MangoHud config file ($local_shorten_path_result) ($passed_section) is not rewritable!"
      return 1
    else
      # Replace "fps_limit" string if exists in config content
      # in memory, not in file as this is source
      local local_temp_config_line
      while read -r local_temp_config_line ||
            [[ -n "$local_temp_config_line" ]]; do
        if [[ "$local_temp_config_line" =~ ^'fps_limit' ]]; then
          # Replace "fps_limit" config key and value with new ones
          local local_new_config_content+="fps_limit=$local_fps_to_set"$'\n'
          local local_fps_limit_has_been_changed='1'
        else
          # Just append to other lines
          local local_new_config_content+="$local_temp_config_line"$'\n'
        fi
      done < "$local_source_config"

      # Append "fps_limit" config key with value
      if [[ -z "$local_fps_limit_has_been_changed" ]]; then
        local local_new_config_content+="fps_limit=$local_fps_to_set"$'\n'
      fi

      # Overwrite config file with changes
      echo "$local_new_config_content" > "$local_target_config"
    fi
  else
    local local_shorten_path_result
    shorten_path "$local_target_config"
    message --warning "Target MangoHud config file ($local_shorten_path_result) ($passed_section) does not exist!"
    return 1
  fi
}
