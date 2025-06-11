# Needed to check whether X11 session is valid or not
validate_x11_session(){
  # Wayland check
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    # Wayland is not supported
    return 1
  else
    local WAYLAND_DISPLAY='wayland-0'

    # If there is Wayland socket, then exit with an error
    if (( UID > 0 )); then
      if [[ -f "/run/user/$UID/$WAYLAND_DISPLAY" ]]; then
        # Wayland is not supported
        return 1
      fi
    else
      # Go through all active users
      local local_temp_uid
      for local_temp_uid in /run/user/*; do
        local local_temp_uid="${local_temp_uid/'/run/user/'/}"
        if [[ -f "/run/user/$local_temp_uid/$WAYLAND_DISPLAY" ]]; then
          # Wayland is not supported
          return 1
        fi
      done
    fi
  fi

  # EWMH-compatibility and X11 session existence check (binary module)
  "$validate_x11_session_path" > /dev/null 2>&1
  local local_validate_x11_session_exit_code="$?"
  if (( local_validate_x11_session_exit_code > 0 )); then
    case "$local_validate_x11_session_exit_code" in
    '1' )
      # X11 server is not running
      return 2
    ;;
    '2' )
      # EWMH-compatible window manager is not running
      return 3
    esac
  fi
}
