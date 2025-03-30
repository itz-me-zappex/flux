# Required to validate config file
validate_config(){
  # Automatically set a path to config file if it is not specified
  if [[ -z "$config" ]]; then
    # Set XDG_CONFIG_HOME automatically if it is not specified
    if [[ -z "$XDG_CONFIG_HOME" ]]; then
      XDG_CONFIG_HOME="$HOME/.config"
    fi

    # Find a config
    local local_temp_config
    for local_temp_config in "$XDG_CONFIG_HOME/flux.ini" "$HOME/.config/flux.ini" '/etc/flux.ini'; do
      if [[ -f "$local_temp_config" ]]; then
        config="$local_temp_config"
        break
      fi
    done
  fi

  # Check for critical errors
  if [[ -z "$config" ]]; then
    # Exit with an error if config file is not found
    message --error "Config file is not found!"
    exit 1
  elif [[ -e "$config" &&
          ! -f "$config" ]]; then
    # Exit with an error if path exists but that is not a file
    message --error "Path '$config' specified in '--config' is not a file!"
    exit 1
  elif [[ ! -f "$config" ]]; then
    # Exit with an error if config file does not exist
    message --error "Config file '$config' does not exist!"
    exit 1
  elif ! check_ro "$config"; then
    # Exit with an error if config file is not readable
    message --error "Config file '$config' is not accessible for reading!"
    exit 1
  fi
}
