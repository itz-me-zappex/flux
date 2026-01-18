# To create temporary directory to store lock and FIFO files
create_temp_dirs(){
  # Exit with an error if something is wrong with either temporary
  # or FIFO's directory
  local local_temp_directory
  for local_temp_directory in "$flux_temp_dir_path" "$flux_temp_fifo_dir_path"; do
    if [[ -e "$local_temp_directory" &&
          ! -d "$local_temp_directory" ]]; then
      local local_shorten_path_result
      shorten_path "$local_temp_directory"
      message --error "Unable to continue, '$local_shorten_path_result' is expected to be a directory!"
      exit 1
    elif [[ ! -d "$local_temp_directory" ]] &&
         ! mkdir -p "$local_temp_directory" > /dev/null 2>&1; then
      local local_shorten_path_result
      shorten_path "$local_temp_directory"
      message --error "Unable to create '$local_shorten_path_result' temporary directory!"
      exit 1
    fi
  done
}
