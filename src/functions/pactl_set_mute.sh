# Required to mute and unmute processes, runs in background via '&'
pactl_set_mute(){
  local -A local_application_name_map \
  local_application_id_map \
  local_application_icon_name_map \
  local_application_process_id_map \
  local_application_process_binary_map \
  local_current_sink_input

  local -a local_sink_inputs_array \
  local_matching_sink_inputs_array

  local local_pactl_output
  if ! local_pactl_output="$(pactl list sink-inputs 2>/dev/null)"; then
    message --warning "Unable to get list of sink inputs to $passed_action_name process '$passed_process_name' ($passed_pid) $passed_end_of_msg!"
    return 0
  fi

  # Get info about existing sink inputs
  local local_temp_line
  while read -r local_temp_line ||
        [[ -n "$local_temp_line" ]]; do
    # Extract values from strings and put them into respective maps
    case "$local_temp_line" in
    'Sink Input #'* )
      local_current_sink_input="${local_temp_line#'Sink Input #'}"
      local_sink_inputs_array+=("$local_current_sink_input")
    ;;
    'application.name'* )
      local_application_name_map["$local_current_sink_input"]="${local_temp_line#'application.name = '}"
      local_application_name_map["$local_current_sink_input"]="${local_application_name_map["$local_current_sink_input"]//\"/}"
    ;;
    'application.id'* )
      local_application_id_map["$local_current_sink_input"]="${local_temp_line#'application.id = '}"
      local_application_id_map["$local_current_sink_input"]="${local_application_id_map["$local_current_sink_input"]//\"/}"
    ;;
    'application.icon_name'* )
      local_application_icon_name_map["$local_current_sink_input"]="${local_temp_line#'application.icon_name = '}"
      local_application_icon_name_map["$local_current_sink_input"]="${local_application_icon_name_map["$local_current_sink_input"]//\"/}"
    ;;
    'application.process.id'* )
      local_application_process_id_map["$local_current_sink_input"]="${local_temp_line#'application.process.id = '}"
      local_application_process_id_map["$local_current_sink_input"]="${local_application_process_id_map["$local_current_sink_input"]//\"/}"
    ;;
    'application.process.binary'* )
      local_application_process_binary_map["$local_current_sink_input"]="${local_temp_line#'application.process.binary = '}"
      local_application_process_binary_map["$local_current_sink_input"]="${local_application_process_binary_map["$local_current_sink_input"]//\"/}"
    esac
  done <<< "$local_pactl_output"

  # Go through sink inputs and try find matching one
  local local_temp_sink_input
  for local_temp_sink_input in "${local_sink_inputs_array[@]}"; do
    # Pulseaudio (and pipewire-pulse) relies on clients, those may give weird information, or may not at all
    if [[ "$passed_pid" == "${local_application_process_id_map["$local_temp_sink_input"]}" ]]; then
      local local_matching_sink_inputs_array+=("$local_temp_sink_input")
    elif [[ -n "${local_application_process_binary_map["$local_temp_sink_input"]}" &&
            "${local_application_process_binary_map["$local_temp_sink_input"],,}" == *"${passed_process_name,,}"* ]]; then
      local local_matching_sink_inputs_array+=("$local_temp_sink_input")
    elif [[ -n "${local_application_name_map["$local_temp_sink_input"]}" &&
            "${local_application_name_map["$local_temp_sink_input"],,}" == *"${passed_process_name,,}"* ]]; then
      local local_matching_sink_inputs_array+=("$local_temp_sink_input")
    elif [[ -n "${local_application_id_map["$local_temp_sink_input"]}" &&
            "${local_application_id_map["$local_temp_sink_input"],,}" == *"${passed_process_name,,}"* ]]; then
      local local_matching_sink_inputs_array+=("$local_temp_sink_input")
    elif [[ -n "${local_application_icon_name_map["$local_temp_sink_input"]}" &&
            "${local_application_icon_name_map["$local_temp_sink_input"],,}" == *"${passed_process_name,,}"* ]]; then
      local local_matching_sink_inputs_array+=("$local_temp_sink_input")
    fi
  done

  # Change mute status if there is a match
  if [[ -n "${local_matching_sink_inputs_array[*]}" ]]; then
    # Mute all matching sink inputs
    local local_temp_matching_sink_input
    for local_temp_matching_sink_input in "${local_matching_sink_inputs_array[@]}"; do
      if ! pactl set-sink-input-mute "$local_temp_matching_sink_input" "$passed_action" > /dev/null 2>&1; then
        message --warning "Unable to $passed_action_name sink input #$local_temp_matching_sink_input $passed_end_of_msg of process '$passed_process_name' ($passed_pid)!"
      else
        message --info "Sink input #$local_temp_matching_sink_input has been ${passed_action_name}d $passed_end_of_msg of process '$passed_process_name' ($passed_pid)."
      fi
    done
  else
    message --warning "Unable to find sink input related to process '$passed_process_name' ($passed_pid) to $passed_action_name it $passed_end_of_msg!"
  fi
}
