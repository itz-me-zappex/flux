# Required to handle windows obtained from 'flux-listener'
handle_window_event(){
  local local_window_event="$1"

  # Unset info about process to avoid using it by an accident
  unset window_xid \
  pid \
  process_name \
  process_owner \
  process_command \
  section

  window_xid="${local_window_event/'='*/}"
  pid="${local_window_event/*'='/}"

  # Hide error messages, even standart ones which are appearing directly from Bash (https://unix.stackexchange.com/a/184807)
  exec 3>&2
  exec 2>/dev/null

  get_process_info
  local local_get_process_info_exit_code="$?"

  # Restore stderr
  exec 2>&3

  # Request CPU/FPS limit for unfocused process if it matches with section
  unfocus_request_limit

  if (( local_get_process_info_exit_code == 0 )); then
    if find_matching_section; then
      handle_focus
    fi

    # Remember info about process until next event to run commands on unfocus and apply CPU/FPS limit, and, to pass variables to command in 'exec-unfocus' key
    previous_window_xid="$window_xid"
    previous_pid="$pid"
    previous_process_name="$process_name"
    previous_process_owner="$process_owner"
    previous_process_command="$process_command"
    previous_section="$section"
  else
    # Forget info about previous window/process because it is not changed
    unset previous_window_xid \
    previous_pid \
    previous_process_name \
    previous_process_owner \
    previous_process_command \
    previous_section

    message --warning "Unable to obtain info about process ($pid) of window ($window_xid)! Probably process has been terminated during check."
  fi
}
