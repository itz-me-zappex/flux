# To create temporary directory to store lock and FIFO files
create_temp_dirs(){
  # Exit with an error if something is wrong with temporary directory
  if [[ -e "$flux_temp_dir_path" &&
     ! -d "$flux_temp_dir_path" ]]; then
    local local_shorten_path_result
    shorten_path "$flux_temp_dir_path"
    message --error "Unable to continue, '$local_shorten_path_result' is expected to be a directory!"
    exit 1
  elif [[ ! -d "$flux_temp_dir_path" ]] &&
       ! mkdir -p "$flux_temp_dir_path" > /dev/null 2>&1; then
    local local_shorten_path_result
    shorten_path "$flux_temp_dir_path"
    message --error "Unable to create '$local_shorten_path_result' temporary directory!"
    exit 1
  fi

  # If it did not fail above, then it should work too, right?...
  if [[ ! -d "$flux_temp_fifo_dir_path" ]]; then
    mkdir -p "$flux_temp_fifo_dir_path" > /dev/null 2>&1
  fi
}
