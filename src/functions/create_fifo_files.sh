# Needed to create FIFO files used to read output of 'flux-listener' and 'flux-grab-cursor'
create_fifo_files(){
  # Needed to read output of and to kill 'flux-listener' process
  if [[ -e "$flux_listener_fifo" &&
        ! -p "$flux_listener_fifo" ]]; then
    message --error "Unable to continue, '$(shorten_path "$flux_listener_fifo")' is expected to be a FIFO file, which is used to read events from 'flux-listener' process!"
    exit 1
  elif [[ ! -p "$flux_listener_fifo" ]] &&
       ! mkfifo "$flux_listener_fifo" > /dev/null 2>&1; then
    message --error "Unable to create '$(shorten_path "$flux_listener_fifo")' FIFO file, which is used to read events from 'flux-listener' process!"
    exit 1
  fi

  # Needed to read output of 'flux-grab-cursor' process
  if [[ -e "$flux_grab_cursor_fifo" &&
        ! -p "$flux_grab_cursor_fifo" ]]; then
    message --error "Unable to continue, '$(shorten_path "$flux_grab_cursor_fifo")' is expected to be a FIFO file, which is used to track status of cursor grabbing!"
    exit 1
  elif [[ ! -p "$flux_grab_cursor_fifo" ]] &&
       ! mkfifo "$flux_grab_cursor_fifo" > /dev/null 2>&1; then
    message --warning "Unable to create '$(shorten_path "$flux_grab_cursor_fifo")' FIFO file, which is used to track status of cursor grabbing!"
    exit 1
  fi
}
