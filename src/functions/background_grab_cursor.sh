# Required to run binary responsible for cursor grabbing, runs in background via '&'
background_grab_cursor(){
  local local_flux_grab_cursor_line
  while read -r local_flux_grab_cursor_line ||
        [[ -n "$local_flux_grab_cursor_line" ]]; do
    case "$local_flux_grab_cursor_line" in
    'cursor_already_grabbed' )
      message --warning "Waiting for when cursor become ungrabbed to assign it to window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid due to focus event..."
    ;;
    'error' )
      message --warning "Unable to grab cursor for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid due to focus event!"
      break
    ;;
    'wine_window' )
      message --verbose "Window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid seems to be related to Wine/Proton, workarounding hangs caused by cursor grabbing..."
    ;;
    'window' )
      message --verbose "Trying to grab cursor and redirect input to window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid due to focus event..."
    ;;
    'success' )
      message --info "Cursor for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid has been grabbed due to focus event."
    esac
  done < <("$flux_grab_cursor_path" "$passed_window_xid" 2>/dev/null)
}
