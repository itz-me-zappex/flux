# Required to cancel cursor grabbing for window on daemon termination and/or unfocus event
cursor_ungrab(){
  if ! kill "${background_focus_cursor_grab_map["$passed_window_xid"]}" > /dev/null 2>&1; then
    message --warning "Unable to ungrab cursor for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
  else
    message --info "Cursor grabbing for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
  fi

  unset background_focus_cursor_grab_map["$passed_window_xid"]
}
