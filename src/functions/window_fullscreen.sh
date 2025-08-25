# Required to fullscreenize window, runs in background via '&'
window_fullscreen(){
  if ! "$window_fullscreen_path" "$window_xid" > /dev/null 2>&1; then
    message --warning "Unable to expand to fullscreen window $window_xid of process '$process_name' with PID $pid on focus event!"
  else
    message --info "Window $window_xid of process '$process_name' with PID $pid has been expanded into fullscreen on focus event."
  fi
}
