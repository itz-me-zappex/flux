# Required to minimize window
window_minimize(){
  if ! window-minimize "$local_temp_window_xid" > /dev/null 2>&1; then
    message --warning "Unable to minimize window ($local_temp_window_xid) of process '$local_process_name' ($local_pid) on unfocus event!"
  else
    message --info "Window ($local_temp_window_xid) of process '$local_process_name' ($local_pid) minimized on unfocus event."
  fi
}
