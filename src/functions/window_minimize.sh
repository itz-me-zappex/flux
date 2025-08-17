# Required to minimize window, runs in background via '&'
window_minimize(){
  if ! "$window_minimize_path" "$local_temp_window_xid" > /dev/null 2>&1; then
    message --warning "Unable to minimize window with XID $local_temp_window_xid of process '$local_process_name' with PID $local_pid because of unfocus event!"
  else
    message --info "Window with XID $local_temp_window_xid of process '$local_process_name' with PID $local_pid has been minimized because of unfocus event."
  fi
}
