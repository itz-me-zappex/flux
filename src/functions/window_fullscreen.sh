# Required to fullscreenize window, runs in background via '&'
window_fullscreen(){
  if ! "$window_fullscreen_path" "$window_xid" > /dev/null 2>&1; then
    message --warning "Unable to expand to fullscreen window with XID $window_xid of process '$process_name' with PID $pid because of focus event!"
  else
    message --info "Window with XID $window_xid of process '$process_name' with PID $pid has been expanded into fullscreen because of focus event."
  fi
}
