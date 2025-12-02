# Needed to create FIFO files used to read output of 'flux-listener' and 'flux-grab-cursor'
create_fifo_files(){
  # Needed to read output of and to kill 'flux-listener' process
  if [[ -e "$flux_listener_fifo_path" &&
        ! -p "$flux_listener_fifo_path" ]]; then
    local local_shorten_path_result
    shorten_path "$flux_listener_fifo_path"
    message --error "Unable to continue, '$local_shorten_path_result' is expected to be a FIFO file!"
    exit 1
  elif [[ ! -p "$flux_listener_fifo_path" ]] &&
       ! mkfifo "$flux_listener_fifo_path" > /dev/null 2>&1; then
    local local_shorten_path_result
    shorten_path "$flux_listener_fifo_path"
    message --error "Unable to create '$local_shorten_path_result' FIFO file!"
    exit 1
  fi

  # Needed to read output of 'flux-grab-cursor' process
  if [[ -n "$should_create_fifo_for_flux_grab_cursor" ]]; then
    if [[ -e "$flux_grab_cursor_fifo_path" &&
          ! -p "$flux_grab_cursor_fifo_path" ]]; then
      local local_shorten_path_result
      shorten_path "$flux_grab_cursor_fifo_path"
      message --error "Unable to continue, '$local_shorten_path_result' is expected to be a FIFO file!"
      exit 1
    elif [[ ! -p "$flux_grab_cursor_fifo_path" ]] &&
         ! mkfifo "$flux_grab_cursor_fifo_path" > /dev/null 2>&1; then
      local local_shorten_path_result
      shorten_path "$flux_grab_cursor_fifo_path"
      message --warning "Unable to create '$local_shorten_path_result' FIFO file!"
      exit 1
    fi

    unset should_create_fifo_for_flux_grab_cursor
  fi
}
