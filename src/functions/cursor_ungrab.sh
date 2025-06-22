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

  if [[ -p "$flux_grab_cursor_fifo" ]]; then
    if ! rm "$flux_grab_cursor_fifo" > /dev/null 2>&1; then
      message --warning "Unable to remove '$(shorten_path "$flux_grab_cursor_fifo")' FIFO file, which is used to track status of cursor grabbing!"
    fi
  elif [[ -e "$flux_grab_cursor_fifo" &&
          ! -p "$flux_grab_cursor_fifo" ]]; then
    message --warning "Unable to remove '$(shorten_path "$flux_grab_cursor_fifo")', FIFO file is expected!"
  fi

  unset background_focus_grab_cursor_map["$passed_window_xid"]
}
