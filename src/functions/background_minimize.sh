# Required to minimize window on unfocus event
background_minimize(){
  # Wait a bit to give daemon a time to interrupt this subprocess in case unfocused window appears focused very quickly (e.g. because of changing window mode)
  sleep 0.1
  
  # Attempt to minimize window
  if ! "${PREFIX}/lib/flux/window-minimize" "$passed_window_xid" > /dev/null 2>&1; then
    message --warning "Unable to minimize window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid on unfocus event!"
  else
    message --info "Window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid has been minimized on unfocus event."
  fi
}
