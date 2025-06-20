# Required to cancel cursor grabbing for window on daemon termination and/or unfocus event
cursor_ungrab(){
  local local_background_focus_grab_cursor_pid="${background_focus_grab_cursor_map["$passed_window_xid"]}"

  if check_pid_existence "$local_background_focus_grab_cursor_pid"; then
    if ! kill "$local_background_focus_grab_cursor_pid" > /dev/null 2>&1; then
      message --warning "Unable to ungrab cursor for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid $passed_end_of_msg!"
    else
      message --info "Cursor grabbing for window with XID $passed_window_xid of process '$passed_process_name' with PID $passed_process_pid has been cancelled $passed_end_of_msg."
    fi
  fi

  # FIXME: Should be done in less aggressive way
  killall flux-cursor-grab

  unset background_focus_grab_cursor_map["$passed_window_xid"]
}
