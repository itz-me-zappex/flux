# Required to run binary responsible for cursor grabbing, runs in background via '&'
background_grab_cursor(){
  # Do not grab cursor if something is wrong with named pipe
  if [[ -e "$flux_grab_cursor_fifo_path" &&
        ! -p "$flux_grab_cursor_fifo_path" ]]; then
    message --warning "Unable to grab cursor for window $passed_window_xid of process '$passed_process_name' with PID $passed_pid on focus event, '$(shorten_path "$flux_grab_cursor_fifo_path")' is not a FIFO file!"
    return 1
  elif [[ ! -e "$flux_grab_cursor_fifo_path" ]]; then
    message --warning "Unable to grab cursor for window $passed_window_xid of process '$passed_process_name' with PID $passed_pid on focus event, '$(shorten_path "$flux_grab_cursor_fifo_path")' FIFO file does not exist!"
    return 1
  else
    "$flux_grab_cursor_path" "$passed_window_xid" > "$flux_grab_cursor_fifo_path" &
    local local_flux_grab_cursor_pid="$!"
    trap 'kill "$local_flux_grab_cursor_pid"' SIGINT SIGTERM
  fi

  local local_flux_grab_cursor_line
  while read -r local_flux_grab_cursor_line ||
        [[ -n "$local_flux_grab_cursor_line" ]]; do
    case "$local_flux_grab_cursor_line" in
    'cursor_already_grabbed' )
      message --verbose "Waiting for when cursor become ungrabbed to assign it to window $passed_window_xid of process '$passed_process_name' with PID $passed_pid on focus event..."
    ;;
    'error' )
      message --warning "Unable to grab cursor for window $passed_window_xid of process '$passed_process_name' with PID $passed_pid on focus event!"
      break
    ;;
    'wine_window' )
      message --info "Window $passed_window_xid of process '$passed_process_name' with PID $passed_pid seems to be related to Wine/Proton, trying to grab cursor and redirect input to there workarounding hangs because of that..."
    ;;
    'wine_hang' )
      message --verbose "Detected hang of Wine/Proton process '$passed_process_name' with PID $passed_pid of window $passed_window_xid caused by cursor grabbing, still workarounding..."
    ;;
    'window' )
      message --info "Attempt to grab cursor and redirect input to window $passed_window_xid of process '$passed_process_name' with PID $passed_pid on focus event..."
    ;;
    'success' )
      message --info "Cursor for window $passed_window_xid of process '$passed_process_name' with PID $passed_pid has been grabbed fully on focus event."
    esac
  done < "$flux_grab_cursor_fifo_path"
}
