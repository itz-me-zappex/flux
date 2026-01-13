# Required to fullscreenize window, runs in background via '&'
window_fullscreen(){
  if ! window-fullscreen "$window_xid" > /dev/null 2>&1; then
    message --warning "Unable to expand to fullscreen window ($window_xid) of process '$process_name' ($pid) on focus event!"
  else
    message --info "Window ($window_xid) of process '$process_name' ($pid) expanded into fullscreen on focus event."
  fi
}
