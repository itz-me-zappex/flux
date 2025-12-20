# Required to minimize window, runs in background via '&'
window_minimize(){
  if ! "$window_minimize_path" "$local_temp_window_xid" > /dev/null 2>&1; then
    message --warning "Unable to minimize window ($local_temp_window_xid) of process '$local_process_name' ($local_pid) on unfocus event!"
  else
    message --info "Window ($local_temp_window_xid) of process '$local_process_name' ($local_pid) has been minimized on unfocus event."
  fi
}
