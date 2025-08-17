# Required to mute and unmute processes, runs in background via '&'
pactl_set_mute(){
  local local_process_name="$1"
  local local_pid="$2"
  local local_action="$3" # 1/0/toggle

  local -A local_application_name_map \
  local_application_id_map \
  local_application_icon_name_map \
  local_application_process_id_map \
  local_application_process_binary_map \
  local_current_sink_input

  local -a local_sink_inputs_array

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
  done < <(pactl list sink-inputs)

  # Go through sink inputs and try find matching one
  local local_temp_sink_input
  for local_temp_sink_input in "${local_sink_inputs_array[@]}"; do
    # Pulseaudio (and pipewire-pulse) relies on clients, those may give weird information, or may not at all
    if [[ "$local_pid" == "${local_application_process_id_map["$local_temp_sink_input"]}" ]]; then
      local local_matching_sink="$local_temp_sink_input"
      break
    elif [[ -n "${local_application_process_binary_map["$local_temp_sink_input"]}" &&
            "${local_process_name,,}" == *"${local_application_process_binary_map["$local_temp_sink_input"],,}"* ]]; then
      local local_matching_sink="$local_temp_sink_input"
      break
    elif [[ -n "${local_application_name_map["$local_temp_sink_input"]}" &&
            "${local_process_name,,}" == *"${local_application_name_map["$local_temp_sink_input"],,}"* ]]; then
      local local_matching_sink="$local_temp_sink_input"
      break
    elif [[ -n "${local_application_id_map["$local_temp_sink_input"]}" &&
            "${local_process_name,,}" == *"${local_application_id_map["$local_temp_sink_input"],,}"* ]]; then
      local local_matching_sink="$local_temp_sink_input"
      break
    elif [[ -n "${local_application_icon_name_map["$local_temp_sink_input"]}" &&
            "${local_process_name,,}" == *"${local_application_icon_name_map["$local_temp_sink_input"],,}"* ]]; then
      local local_matching_sink="$local_temp_sink_input"
      break
    fi
  done

  # Change mute status if there is a match
  if [[ -n "$local_matching_sink" ]]; then
    #message --info "good"
    pactl set-sink-input-mute "$local_matching_sink" "$local_action"
  else
    #message --warning "bad"
  fi
}
