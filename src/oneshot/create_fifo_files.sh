# To create FIFO files used to read output of 'flux-listener' and
# 'flux-grab-cursor'
create_fifo_files(){
  # Needed to read output of and to kill 'flux-listener' process
  local local_fifo_files_array+=("$flux_listener_fifo_path")

  # Needed to read output of 'flux-grab-cursor' process
  if [[ -n "$should_create_fifo_for_flux_grab_cursor" ]]; then
    unset should_create_fifo_for_flux_grab_cursor
    local local_fifo_files_array+=("$flux_grab_cursor_fifo_path")
  fi

  local local_temp_fifo
  for local_temp_fifo in "${local_fifo_files_array[@]}"; do
    if [[ -e "$local_temp_fifo" &&
          ! -p "$local_temp_fifo" ]]; then
      local local_shorten_path_result
      shorten_path "$local_temp_fifo"
      message --error "Unable to continue, '$local_shorten_path_result' is expected to be a FIFO file!"
      exit 1
    elif [[ ! -p "$local_temp_fifo" ]] &&
        ! mkfifo "$local_temp_fifo" > /dev/null 2>&1; then
      local local_shorten_path_result
      shorten_path "$local_temp_fifo"
      message --error "Unable to create '$local_shorten_path_result' FIFO file!"
      exit 1
    fi
  done
}
