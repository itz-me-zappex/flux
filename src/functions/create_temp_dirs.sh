# Needed to create temporary directory to store lock and FIFO files
create_temp_dirs(){
  # Exit with an error if something is wrong with temporary directory
  if [[ -e "$flux_temp_dir_path" &&
     ! -d "$flux_temp_dir_path" ]]; then
    message --error "Unable to continue, '$(shorten_path "$flux_temp_dir_path")' is expected to be a directory, which is used to store temporary files like lock and FIFO files!"
    exit 1
  elif [[ ! -d "$flux_temp_dir_path" ]] &&
       ! mkdir -p "$flux_temp_dir_path" > /dev/null 2>&1; then
    message --error "Unable to create '$(shorten_path "$flux_temp_dir_path")' temporary directory, which is used to store temporary files like lock and FIFO files!"
    exit 1
  fi

  # If it did not fail above, then it should work too, right?...
  if [[ ! -d "$flux_temp_fifo_dir_path" ]]; then
    mkdir -p "$flux_temp_fifo_dir_path" > /dev/null 2>&1
  fi
}
